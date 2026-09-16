require "./helper"

module PlaceOS::Model
  # Observe committed SQL events directly, independently of EventBus worker timing.
  private class RuntimeCDCProbe
    @notifications = Channel(String).new(32)
    @barrier = "runtime-barrier-#{RANDOM.hex(8)}"
    @listener : PG::ListenConnection
    @count : Int64

    def initialize(@table : String, @id : String)
      @listener = PG::ListenConnection.new(ENV["PG_DATABASE_URL"], ["cdc_events", "runtime_spec_barrier"]) do |notification|
        if notification.channel == "runtime_spec_barrier"
          @notifications.send(notification.payload) if notification.payload == @barrier
        else
          payload = JSON.parse(notification.payload)
          if payload["table"].as_s == @table && payload["id"].as_s == @id
            @notifications.send(notification.payload)
          end
        end
      end
      @count = event_count
    end

    def event_count
      PgORM::Database.connection do |db|
        db.query_one("SELECT count(*) FROM public.eventbus_cdc_events WHERE event_table = $1 AND row_id = $2", args: [@table, @id], as: Int64)
      end
    end

    def expect_quiet
      event_count.should eq(@count)
      PgORM::Database.connection { |db| db.exec("SELECT pg_notify('runtime_spec_barrier', $1)", args: [@barrier]) }
      receive.should eq(@barrier)
    end

    def expect_action(action : String)
      JSON.parse(receive)["action"].as_s.should eq(action)
      @count += 1
      event_count.should eq(@count)
    end

    def close
      @listener.close
    end

    private def receive
      select
      when payload = @notifications.receive
        payload
      when timeout(5.seconds)
        raise "Timed out waiting for #{@table} CDC notification"
      end
    end
  end

  describe "runtime changefeed policies" do
    {"name", "description", "update_available", "update_info", "compilation_output", "updated_at"}.each do |field|
      it "persists Driver #{field} without notifying drivers or modules" do
        driver = Generator.driver(role: Driver::Role::Device).save!
        mod = Generator.module(driver: driver).save!
        feed = Driver.changes
        module_feed = Module.changes
        probe = RuntimeCDCProbe.new("driver", driver.id.as(String))
        module_probe = RuntimeCDCProbe.new("mod", mod.id.as(String))
        previous_updated_at = driver.updated_at
        case field
        when "name"               then driver.name = "updated name"
        when "description"        then driver.description = "updated description"
        when "update_available"   then driver.update_available = true
        when "update_info"        then driver.update_info = Driver::UpdateInfo.new("new-commit", "new release")
        when "compilation_output" then driver.compilation_output = "compiled"
        when "updated_at"         then driver.updated_at = Time.utc
        end
        driver.save!
        driver.reload!
        driver.updated_at.should be > previous_updated_at
        case field
        when "name"               then driver.name.should eq("updated name")
        when "description"        then driver.description.should eq("updated description")
        when "update_available"   then driver.update_available.should be_true
        when "update_info"        then driver.update_info.should eq(Driver::UpdateInfo.new("new-commit", "new release"))
        when "compilation_output" then driver.compilation_output.should eq("compiled")
        end
        # Check modules first so the regression also catches the after_save bypass.
        module_probe.expect_quiet
        probe.expect_quiet
      ensure
        probe.try &.close
        module_probe.try &.close
        feed.try &.stop
        module_feed.try &.stop
        mod.try &.delete
        driver.try &.delete
      end
    end

    {"name", "description", "display_name", "playlists", "images", "updated_at"}.each do |field|
      it "persists Zone #{field} without notifying services" do
        playlist = Generator.playlist.save!
        zone = Generator.zone.save!
        feed = Zone.changes
        probe = RuntimeCDCProbe.new("zone", zone.id.as(String))
        previous_updated_at = zone.updated_at
        case field
        when "name"         then zone.name = "updated name"
        when "description"  then zone.description = "updated description"
        when "display_name" then zone.display_name = "updated display"
        when "playlists"    then zone.playlists = [playlist.id.as(String)]
        when "images"       then zone.images = ["https://example.com/image.png"]
        when "updated_at"   then zone.updated_at = Time.utc
        end
        zone.save!
        zone.reload!
        zone.updated_at.should be > previous_updated_at
        case field
        when "name"         then zone.name.should eq("updated name")
        when "description"  then zone.description.should eq("updated description")
        when "display_name" then zone.display_name.should eq("updated display")
        when "playlists"    then zone.playlists.should eq([playlist.id.as(String)])
        when "images"       then zone.images.should eq(["https://example.com/image.png"])
        end
        probe.expect_quiet
      ensure
        probe.try &.close
        feed.try &.stop
        zone.try &.delete
        playlist.try &.delete
      end
    end

    {"playlists", "orientation"}.each do |field|
      it "persists ControlSystem #{field} without notifying services" do
        playlist = Generator.playlist.save!
        system = Generator.control_system.save!
        feed = ControlSystem.changes
        probe = RuntimeCDCProbe.new("sys", system.id.as(String))
        if field == "playlists"
          system.playlists = [playlist.id.as(String)]
        else
          system.orientation = Playlist::Orientation::Portrait
        end
        system.save!
        system.reload!
        if field == "playlists"
          system.playlists.should eq([playlist.id.as(String)])
        else
          system.orientation.should eq(Playlist::Orientation::Portrait)
        end
        probe.expect_quiet
      ensure
        probe.try &.close
        feed.try &.stop
        system.try &.delete
        playlist.try &.delete
      end
    end

    it "preserves Driver runtime updates and repairs associated module metadata" do
      feed = Driver.changes
      driver = Generator.driver(role: Driver::Role::Device).save!
      probe = RuntimeCDCProbe.new("driver", driver.id.as(String))
      probe.event_count.should eq(1)
      mod = Generator.module(driver: driver).save!
      module_feed = Module.changes
      module_probe = RuntimeCDCProbe.new("mod", mod.id.as(String))
      driver.module_name = "UpdatedModule"
      driver.description = "mixed runtime and metadata"
      driver.save!
      probe.expect_action("update")
      module_probe.expect_action("update")
      mod.reload!
      mod.name.should eq(driver.module_name)
      driver.role = Driver::Role::SSH
      driver.save!
      probe.expect_action("update")
      module_probe.expect_action("update")
      mod.reload!
      mod.role.should eq(Driver::Role::SSH)
      driver.commit = "updated-commit"
      driver.save!
      probe.expect_action("update")
      module_probe.expect_quiet

      # Preserve repair of persisted module metadata even on an ignored driver save.
      PgORM::Database.connection do |db|
        db.exec("UPDATE mod SET name = 'stale' WHERE id = $1", args: [mod.id])
      end
      module_probe.expect_action("update")
      driver.description = "repair stale module"
      driver.save!
      probe.expect_quiet
      module_probe.expect_action("update")
      mod.reload!
      mod.name.should eq(driver.module_name)
      driver.destroy
      probe.expect_action("delete")
      module_probe.expect_action("delete")
    ensure
      probe.try &.close
      module_probe.try &.close
      feed.try &.stop
      module_feed.try &.stop
      mod.try &.delete
      driver.try &.delete
    end

    it "preserves Zone runtime and mixed updates, inserts and deletes" do
      feed = Zone.changes
      zone = Generator.zone.save!
      probe = RuntimeCDCProbe.new("zone", zone.id.as(String))
      probe.event_count.should eq(1)
      zone.tags = Set{"building"}
      zone.save!
      probe.expect_action("update")
      zone.tags = Set{"floor"}
      zone.name = "mixed zone metadata"
      zone.save!
      probe.expect_action("update")
      zone.destroy
      probe.expect_action("delete")
    ensure
      probe.try &.close
      feed.try &.stop
      zone.try &.delete
    end

    {"updated_at", "has_runtime_error", "error_timestamp"}.each do |field|
      it "persists Module #{field} without notifying services" do
        driver = Generator.driver(role: Driver::Role::Device).save!
        mod = Generator.module(driver: driver)
        mod.running = true
        mod.save!
        feed = Module.changes
        probe = RuntimeCDCProbe.new("mod", mod.id.as(String))
        previous_updated_at = mod.updated_at
        error_time = Time.utc
        case field
        when "updated_at"        then mod.updated_at = Time.utc
        when "has_runtime_error" then mod.has_runtime_error = true
        when "error_timestamp"   then mod.error_timestamp = error_time
        end
        mod.save!
        mod.reload!
        mod.updated_at.should be > previous_updated_at
        case field
        when "has_runtime_error"
          mod.has_runtime_error.should be_true
        when "error_timestamp"
          mod.error_timestamp.not_nil!.to_unix.should eq(error_time.to_unix)
          mod.error_timestamp = nil
          mod.save!
          mod.reload!
          mod.error_timestamp.should be_nil
        end
        probe.expect_quiet
      ensure
        probe.try &.close
        feed.try &.stop
        mod.try &.delete
        driver.try &.delete
      end
    end

    it "preserves Module name changes, mixed updates, inserts and deletes" do
      driver = Generator.driver(role: Driver::Role::Device).save!
      feed = Module.changes
      mod = Generator.module(driver: driver).save!
      probe = RuntimeCDCProbe.new("mod", mod.id.as(String))
      probe.event_count.should eq(1)
      # Raw writes avoid the ORM callback that restores the driver's module_name.
      PgORM::Database.connection do |db|
        db.exec("UPDATE mod SET name = 'renamed-module' WHERE id = $1", args: [mod.id])
      end
      probe.expect_action("update")
      mod.reload!
      mod.name.should eq("renamed-module")
      PgORM::Database.connection do |db|
        db.exec("UPDATE mod SET name = 'mixed-module', has_runtime_error = true, error_timestamp = now(), updated_at = now() WHERE id = $1", args: [mod.id])
      end
      probe.expect_action("update")
      mod.reload!
      mod.name.should eq("mixed-module")
      mod.has_runtime_error.should be_true
      mod.error_timestamp.should_not be_nil
      mod.destroy
      probe.expect_action("delete")
    ensure
      probe.try &.close
      feed.try &.stop
      mod.try &.delete
      driver.try &.delete
    end

    it "keeps unconfigured Repository metadata updates" do
      repo = Generator.repository.save!
      feed = Repository.changes
      probe = RuntimeCDCProbe.new("repo", repo.id.as(String))
      repo.name = "updated repository"
      repo.save!
      probe.expect_action("update")
    ensure
      probe.try &.close
      feed.try &.stop
      repo.try &.delete
    end
  end
end
