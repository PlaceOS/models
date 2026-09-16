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

      system.name = "renamed-#{RANDOM.hex(8)}"
      system.save!
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")

      PgORM::Database.connection do |db|
        db.exec("UPDATE sys SET description = 'mixed update', signage_last_seen = now(), playlist_item_id = $2 WHERE id = $1", args: [id, item.id])
      end
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("update")
      system.reload!
      system.description.should eq("mixed update")
      system.playlist_item_id.should eq(item.id)
      system.destroy
      JSON.parse(receive_signage_notification(notifications))["action"].as_s.should eq("delete")
      signage_cdc_actions(id).should eq(["insert", "update", "update", "delete"])
    ensure
      listener.try &.close
      feed.try &.stop
      system.try &.delete
      item.try &.delete
    end

    it "keeps other models' update notifications" do
      zone = Generator.zone.save!
      feed = Zone.changes(zone.id)
      events = Channel(PgORM::ChangeReceiver::Event).new(4)
      spawn { feed.on { |change| events.send(change.event) } }
      Fiber.yield
      zone.name = "updated-#{RANDOM.hex(8)}"
      zone.save!
      select
      when event = events.receive
        event.updated?.should be_true
      when timeout(5.seconds)
        fail "Zone update did not notify"
      end
    ensure
      feed.try &.stop
      zone.try &.delete
    end
  end
end
