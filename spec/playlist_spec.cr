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

    it "validates play_hours are valid" do
      playlist = Generator.playlist
      playlist.play_hours = "25:00-16:00"
      playlist.save.should eq false

      playlist.play_hours = "10:75-16:00"
      playlist.save.should eq false

      playlist.play_hours = " 00:30-16:00"
      playlist.save.should eq false

      playlist.play_hours = "00:30 - 16:00"
      playlist.save.should eq false

      playlist.errors.first.field.should eq :play_hours

      playlist.play_hours = "10:30-16:00"
      playlist.save.should eq true
    end

    it "validates CRONs are valid" do
      playlist = Generator.playlist
      playlist.play_cron = "not valid"
      playlist.save.should eq false

      playlist.errors.first.field.should eq :play_cron

      playlist.play_cron = "*/2 * * * *"
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
