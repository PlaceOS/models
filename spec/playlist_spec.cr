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

      cs = Generator.control_system
      cs.playlists = [play_id]

      zone = Generator.zone
      zone.playlists = [play_id]
      zone.save!

      zone2 = Generator.zone
      zone2.playlists = [play_id]
      zone2.save!

      cs.zones = [zone.id.as(String), zone2.id.as(String)]
      cs.save!
      cs_id = cs.id.as(String)

      trigger = Generator.trigger_instance control_system: cs
      trigger.playlists = [play_id]
      trigger.save!

      trigger2 = Generator.trigger_instance control_system: cs
      trigger2.playlists = [play_id]
      trigger2.save!

      cs = ControlSystem.find(cs_id)
      cs.all_playlists.should eq({
        cs_id                  => [play_id],
        zone.id.as(String)     => [play_id],
        zone2.id.as(String)    => [play_id],
        trigger.id.as(String)  => [play_id],
        trigger2.id.as(String) => [play_id],
      })
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
      sleep 0.5
      revision2 = Generator.revision.save!
      sleep 0.5
      revision3 = Generator.revision.save!
      sleep 0.5

      cs = Generator.control_system
      cs.playlists = [revision1.playlist_id.as(String), revision2.playlist_id.as(String), revision3.playlist_id.as(String)]
      cs.save!

      cs.playlists_last_updated.should eq cs.created_at
    end
  end
end
