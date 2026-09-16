require "./helper"

module PlaceOS::Model
  private def self.receive_signage_notification(notifications : Channel(String)) : String
    select
    when message = notifications.receive
      message
    when timeout(5.seconds)
      raise "Timed out waiting for signage CDC notification"
    end
  end

  private def self.signage_cdc_actions(id : String) : Array(String)
    PgORM::Database.connection do |db|
      db.query_all("SELECT event_action FROM public.eventbus_cdc_events WHERE event_table = 'sys' AND row_id = $1 ORDER BY id", args: [id], as: String)
    end
  end

  describe "ControlSystem signage changefeed" do
    it "persists heartbeats without CDC rows or notifications and retains configuration events" do
      system = Generator.control_system
      item = Generator.item.save!
      driver = Generator.driver(role: Driver::Role::Device).save!
      mod = Generator.module(driver: driver).save!
      notifications = Channel(String).new(32)
      barrier = "signage-barrier-#{RANDOM.hex(8)}"
      listener = PG::ListenConnection.new(ENV["PG_DATABASE_URL"], ["cdc_events", "signage_spec_barrier"]) do |notification|
        payload = notification.payload
        if payload == barrier || (JSON.parse(payload)["table"].as_s == "sys" && JSON.parse(payload)["id"].as_s == system.id)
          notifications.send(payload)
        end
      end
      feed = ControlSystem.changes
      system.save!
      id = system.id.as(String)
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("insert")
      signage_cdc_actions(id).should eq(["insert"])

      # Repeated items and both forms of clearing must persist without CDC work.
      {item.id, item.id, nil, item.id, ""}.each do |item_id|
        previous = system.signage_last_seen
        system.update_last_seen_time(item_id)
        system.reload!
        system.signage_last_seen.should be > previous
        system.playlist_item_id.should eq(item_id.presence)
        signage_cdc_actions(id).should eq(["insert"])
      end
      # A committed notification to the same listener proves prior writes emitted none.
      PgORM::Database.connection { |db| db.exec("SELECT pg_notify('signage_spec_barrier', $1)", args: [barrier]) }
      receive_signage_notification(notifications).should eq(barrier)

      system.modules = [mod.id.as(String)]
      system.save!
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")

      # Other inputs to the generated search vector still require notifications.
      system.code = "room-#{RANDOM.hex(8)}"
      system.save!
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")

      PgORM::Database.connection do |db|
        db.exec("UPDATE sys SET modules = ARRAY[]::text[], name = $3, description = 'mixed update', display_name = 'Display', version = version + 1, signage_last_seen = now(), playlist_item_id = $2 WHERE id = $1", args: [id, item.id, "mixed-#{RANDOM.hex(8)}"])
      end
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")
      system.reload!
      system.modules.should be_empty
      system.description.should eq("mixed update")
      system.playlist_item_id.should eq(item.id)
      system.destroy
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("delete")
      signage_cdc_actions(id).should eq(["insert", "update", "update", "update", "delete"])
    ensure
      listener.try &.close
      feed.try &.stop
      system.try &.delete
      item.try &.delete
      mod.try &.delete
      driver.try &.delete
    end

    {"name", "description", "version"}.each do |column|
      it "persists #{column}-only changes without CDC rows or notifications" do
        system = Generator.control_system.save!
        id = system.id.as(String)
        notifications = Channel(String).new(4)
        barrier = "metadata-barrier-#{RANDOM.hex(8)}"
        listener = PG::ListenConnection.new(ENV["PG_DATABASE_URL"], ["cdc_events", "metadata_spec_barrier"]) do |notification|
          payload = notification.payload
          if payload == barrier || (JSON.parse(payload)["table"].as_s == "sys" && JSON.parse(payload)["id"].as_s == id)
            notifications.send(payload)
          end
        end
        feed = ControlSystem.changes
        before = signage_cdc_actions(id)
        value = column == "version" ? "7" : "metadata-#{RANDOM.hex(8)}"
        previous_updated_at = system.updated_at
        case column
        when "name"        then system.name = value
        when "description" then system.description = value
        when "version"     then system.version = value.to_i
        end
        system.save!
        system.reload!
        system.updated_at.should be > previous_updated_at
        PgORM::Database.connection do |db|
          db.query_one("SELECT #{column}::text FROM sys WHERE id = $1", args: [id], as: String).should eq(value)
        end
        signage_cdc_actions(id).should eq(before)
        PgORM::Database.connection { |db| db.exec("SELECT pg_notify('metadata_spec_barrier', $1)", args: [barrier]) }
        receive_signage_notification(notifications).should eq(barrier)
      ensure
        listener.try &.close
        feed.try &.stop
        system.try &.delete
      end
    end

    it "notifies when display_name is set or cleared alongside ignored metadata" do
      system = Generator.control_system.save!
      id = system.id.as(String)
      feed = ControlSystem.changes
      notifications = Channel(String).new(4)
      listener = PG::ListenConnection.new(ENV["PG_DATABASE_URL"], ["cdc_events"]) do |notification|
        payload = JSON.parse(notification.payload)
        if payload["table"].as_s == "sys" && payload["id"].as_s == id
          notifications.send(notification.payload)
        end
      end
      expected_actions = signage_cdc_actions(id)
      {"Updated display", nil}.each do |display_name|
        system.display_name = display_name
        system.description = "metadata with #{display_name || "cleared display"}"
        system.save!
        system.reload!
        system.display_name.should eq(display_name)
        expected_actions << "update"
        signage_cdc_actions(id).should eq(expected_actions)
        JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")
      end
    ensure
      listener.try &.close
      feed.try &.stop
      system.try &.delete
    end

    it "keeps runtime Zone update notifications" do
      zone = Generator.zone.save!
      notifications = Channel(String).new(4)
      listener = PG::ListenConnection.new(ENV["PG_DATABASE_URL"], ["cdc_events"]) do |notification|
        payload = JSON.parse(notification.payload)
        if payload["table"].as_s == "zone" && payload["id"].as_s == zone.id
          notifications.send(notification.payload)
        end
      end
      feed = Zone.changes(zone.id)
      zone.code = "updated-#{RANDOM.hex(8)}"
      zone.save!
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")
      PgORM::Database.connection do |db|
        db.query_all("SELECT event_action FROM public.eventbus_cdc_events WHERE event_table = 'zone' AND row_id = $1 AND event_action = 'update'", args: [zone.id], as: String).should eq(["update"])
      end
    ensure
      listener.try &.close
      feed.try &.stop
      zone.try &.delete
    end
  end
end
