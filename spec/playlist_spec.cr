require "./helper"

module PlaceOS::Model
  describe Playlist do
    Spec.before_each do
      Playlist.clear
      ControlSystem.clear
    end

    test_round_trip(Playlist)

    it "can query which systems are using a playlist" do
      playlist = Generator.playlist
      playlist.save!

      cs = Generator.control_system
      Generator.control_system.save!
      Generator.control_system.save!
      cs.playlists = [playlist.id.as(String)]
      cs.save!

      playlist.systems.map(&.id).should eq [cs.id]
    end

    it "can query which zones are using a playlist" do
      playlist = Generator.playlist
      playlist.save!

      zone = Generator.zone
      Generator.control_system.save!
      Generator.control_system.save!
      zone.playlists = [playlist.id.as(String)]
      zone.save!

      playlist.zones.map(&.id).should eq [zone.id]
    end

    it "cleans up playlists lazily when systems are saved" do
      playlist = Generator.playlist
      playlist.save!
      play_id = playlist.id.as(String)

      cs = Generator.control_system
      cs.playlists = [play_id]
      cs.save!
      cs_id = cs.id.as(String)

      playlist.destroy

      cs = ControlSystem.find(cs_id)
      cs.playlists.first.should eq play_id
      cs.save!

      cs = ControlSystem.find(cs_id)
      cs.playlists.size.should eq 0
    end

    it "finds all the playlist ids associated with a system" do
      playlist = Generator.playlist
      playlist.save!
      play_id = playlist.id.as(String)

      playlist = Generator.playlist
      playlist.save!
      play_id2 = playlist.id.as(String)

      cs = Generator.control_system
      cs.playlists = [play_id2]

      zone = Generator.zone
      zone.playlists = [play_id]
      zone.save!

      zone2 = Generator.zone
      zone2.playlists = [play_id2]
      zone2.save!

      cs.zones = [zone.id.as(String), zone2.id.as(String)]
      cs.save!
      cs_id = cs.id.as(String)

      trigger = Generator.trigger_instance control_system: cs
      trigger.playlists = [play_id]
      trigger.save!

      trigger2 = Generator.trigger_instance control_system: cs
      trigger2.playlists = [play_id2]
      trigger2.save!

      cs = ControlSystem.find(cs_id)
      cs.all_playlists.should eq({
        cs_id                  => [play_id2],
        zone.id.as(String)     => [play_id],
        zone2.id.as(String)    => [play_id2],
        trigger.id.as(String)  => [play_id],
        trigger2.id.as(String) => [play_id2],
      })

      # playlists default to this orientation
      cs.orientation = PlaceOS::Model::Playlist::Orientation::Portrait
      cs.save!
      cs.all_playlists.should eq({
        cs_id                  => [play_id2],
        zone.id.as(String)     => [play_id],
        zone2.id.as(String)    => [play_id2],
        trigger.id.as(String)  => [play_id],
        trigger2.id.as(String) => [play_id2],
      })

      # playlists directly assigned to the display should not be filtered
      playlist.orientation = PlaceOS::Model::Playlist::Orientation::Landscape
      playlist.save!
      cs.all_playlists.should eq({
        cs_id                 => [play_id2],
        zone.id.as(String)    => [play_id],
        trigger.id.as(String) => [play_id],
      })
    end

    it "defaults to a single schedule" do
      playlist = Generator.playlist
      playlist.save.should eq true

      playlist = Playlist.find!(playlist.id.as(String))
      playlist.schedules.size.should eq 1
      schedule = playlist.schedules.first
      schedule.play_cron.should eq "0 0 * * *"
      schedule.play_period.should eq 1440
      schedule.play_takeover.should eq false
      schedule.play_at.should be_nil
      schedule.valid_until.should be_nil
      schedule.valid_from.should be_nil
      schedule.mask.should be_nil
    end

    it "round-trips play_at, valid_from and valid_until" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(play_at: 1_700_000_000_i64, valid_from: 1_650_000_000_i64, valid_until: 1_800_000_000_i64)]
      playlist.save.should eq true

      schedule = Playlist.find!(playlist.id.as(String)).schedules.first
      schedule.play_at.should eq 1_700_000_000_i64
      schedule.valid_from.should eq 1_650_000_000_i64
      schedule.valid_until.should eq 1_800_000_000_i64
    end

    it "requires valid_until to be after valid_from when both are set" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_800_000_000_i64, valid_until: 1_700_000_000_i64)]
      playlist.save.should eq false
      playlist.errors.first.field.should eq :schedules
      playlist.errors.first.message.to_s.should contain "valid_until must be greater than valid_from"

      # equal bounds are rejected, the range must be strictly increasing
      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_800_000_000_i64, valid_until: 1_800_000_000_i64)]
      playlist.save.should eq false
      playlist.errors.first.field.should eq :schedules

      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_800_000_000_i64, valid_until: 1_800_000_001_i64)]
      playlist.save.should eq true
    end

    it "round-trips a mask" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_700_000_000_i64, mask: "1010011")]
      playlist.save.should eq true

      schedule = Playlist.find!(playlist.id.as(String)).schedules.first
      schedule.mask.should eq "1010011"
      schedule.valid_from.should eq 1_700_000_000_i64
    end

    it "requires valid_from when a mask is set" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(mask: "101")]
      playlist.save.should eq false
      playlist.errors.first.field.should eq :schedules
      playlist.errors.first.message.to_s.should contain "valid_from is required when mask is set"

      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_700_000_000_i64, mask: "101")]
      playlist.save.should eq true
    end

    it "treats an empty mask as inactive" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(mask: "")]
      playlist.save.should eq true
    end

    it "only allows 0's and 1's in a mask" do
      playlist = Generator.playlist
      ["102", "1 0", "abc", "1,0", "１0"].each do |bits|
        playlist.schedules = [Playlist::Schedule.new(valid_from: 1_700_000_000_i64, mask: bits)]
        playlist.save.should eq false
        playlist.errors.first.field.should eq :schedules
        playlist.errors.first.message.to_s.should contain "mask can only contain 0's and 1's"
      end
    end

    it "limits the mask to 128 characters" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_700_000_000_i64, mask: "1" * 129)]
      playlist.save.should eq false
      playlist.errors.first.field.should eq :schedules
      playlist.errors.first.message.to_s.should contain "mask must not exceed 128 characters"

      playlist.schedules = [Playlist::Schedule.new(valid_from: 1_700_000_000_i64, mask: "01" * 64)]
      playlist.save.should eq true
    end

    it "allows valid_from or valid_until to be set independently" do
      playlist = Generator.playlist
      playlist.schedules = [
        Playlist::Schedule.new(valid_from: 1_800_000_000_i64),
        Playlist::Schedule.new(valid_until: 1_700_000_000_i64),
      ]
      playlist.save.should eq true
    end

    it "validates each schedule's cron" do
      playlist = Generator.playlist
      playlist.schedules = [Playlist::Schedule.new(play_cron: "not valid")]
      playlist.save.should eq false
      playlist.errors.first.field.should eq :schedules

      playlist.schedules = [Playlist::Schedule.new(play_cron: "*/2 * * * *")]
      playlist.save.should eq true
    end

    it "requires at least one schedule" do
      playlist = Generator.playlist
      playlist.schedules = [] of Playlist::Schedule
      playlist.save.should eq false
      playlist.errors.first.field.should eq :schedules
    end

    it "does not require a schedule for distribution playlists" do
      playlist = Generator.playlist(distribution: true)
      playlist.schedules = [] of Playlist::Schedule
      playlist.save.should eq true
    end

    it "prevents the distribution flag from changing after creation" do
      playlist = Generator.playlist
      playlist.save.should eq true

      playlist.distribution = true
      playlist.save.should eq false
      playlist.errors.first.field.should eq :distribution

      # unrelated updates that leave the flag untouched are still allowed
      playlist = Playlist.find!(playlist.id.as(String))
      playlist.name = "renamed"
      playlist.save.should eq true
    end

    it "can calculate the last time the display was updated" do
      revision1 = Generator.revision.save!
      sleep 500.milliseconds
      revision2 = Generator.revision.save!
      sleep 500.milliseconds
      revision3 = Generator.revision.save!
      sleep 500.milliseconds

      cs = Generator.control_system
      cs.playlists = [revision1.playlist_id.as(String), revision2.playlist_id.as(String), revision3.playlist_id.as(String)]
      cs.save!

      cs.playlists_last_updated.should eq cs.created_at
    end

    it "updates playlist play count" do
      playlist1 = Generator.playlist
      playlist1.save!
      playlist1_id = playlist1.id.as(String)
      playlist2 = Generator.playlist
      playlist2.save!
      playlist2_id = playlist2.id.as(String)

      Playlist.update_counts({
        playlist1_id => 5,
        playlist2_id => 1,
      }).should eq 2

      Playlist.find(playlist1_id).play_count.should eq 5
      Playlist.find(playlist2_id).play_count.should eq 1

      Playlist.update_counts({
        playlist1_id => 2,
        playlist2_id => 3,
      }).should eq 2

      Playlist.find(playlist1_id).play_count.should eq 7
      Playlist.find(playlist2_id).play_count.should eq 4
    end

    it "updates playlist play through count" do
      playlist1 = Generator.playlist
      playlist1.save!
      playlist1_id = playlist1.id.as(String)
      playlist2 = Generator.playlist
      playlist2.save!
      playlist2_id = playlist2.id.as(String)

      Playlist.update_through_counts({
        playlist1_id => 5,
        playlist2_id => 1,
      }).should eq 2

      Playlist.find(playlist1_id).play_through_count.should eq 5
      Playlist.find(playlist2_id).play_through_count.should eq 1

      Playlist.update_through_counts({
        playlist1_id => 2,
        playlist2_id => 3,
      }).should eq 2

      Playlist.find(playlist1_id).play_through_count.should eq 7
      Playlist.find(playlist2_id).play_through_count.should eq 4
    end
  end
end
