require "./helper"

module PlaceOS::Model
  describe Playlist::ItemSchedule do
    Spec.before_each do
      Playlist::ItemSchedule.clear
      Playlist::Revision.clear
      Playlist::Item.clear
      Playlist.clear
    end

    test_round_trip(Playlist::ItemSchedule)

    it "defaults to a single schedule" do
      schedule = Generator.item_schedule
      schedule.save.should eq true

      schedule = Playlist::ItemSchedule.find!(schedule.id.as(String))
      schedule.schedules.size.should eq 1
      schedule.schedules.first.play_cron.should eq "0 0 * * *"
    end

    it "requires a playlist and an item" do
      schedule = Playlist::ItemSchedule.new
      schedule.schedules = [Playlist::Schedule.new]
      schedule.save.should eq false
      schedule.errors.map(&.field).should contain :playlist_id
      schedule.errors.map(&.field).should contain :item_id
    end

    it "requires at least one schedule" do
      schedule = Generator.item_schedule
      schedule.schedules = [] of Playlist::Schedule
      schedule.save.should eq false
      schedule.errors.first.field.should eq :schedules
    end

    it "validates each schedule's cron" do
      schedule = Generator.item_schedule
      schedule.schedules = [Playlist::Schedule.new(play_cron: "not valid")]
      schedule.save.should eq false
      schedule.errors.first.field.should eq :schedules

      schedule.schedules = [Playlist::Schedule.new(play_cron: "*/2 * * * *")]
      schedule.save.should eq true
    end

    it "requires the item and playlist to share an authority" do
      playlist = Generator.playlist(distribution: true).save!

      other_authority = Generator.authority(domain: "http://other.example.com").save!
      item = Generator.item(authority: other_authority).save!

      schedule = Generator.item_schedule(playlist: playlist, item: item)
      schedule.save.should eq false
      schedule.errors.first.field.should eq :item_id
    end

    it "is removed when the owning playlist is deleted" do
      playlist = Generator.playlist(distribution: true).save!
      schedule = Generator.item_schedule(playlist: playlist).save!
      schedule_id = schedule.id.as(String)

      playlist.destroy
      Playlist::ItemSchedule.find?(schedule_id).should be_nil
    end

    it "is removed when the underlying item is deleted" do
      item = Generator.item.save!
      schedule = Generator.item_schedule(item: item).save!
      schedule_id = schedule.id.as(String)

      item.destroy
      Playlist::ItemSchedule.find?(schedule_id).should be_nil
    end
  end
end
