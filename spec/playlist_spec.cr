require "./helper"

module PlaceOS::Model
  describe Playlist, focus: true do
    Spec.before_each do
      Playlist.clear
      ControlSystem.clear
    end

    test_round_trip(Playlist)

    it "can query which systems are using a playlist" do
      playlist = Generator.playlist
      playlist.save!

      cs = Generator.control_system
      cs.playlists = [playlist.id.as(String)]
      cs.save!

      playlist.systems.map(&.id).should eq [cs.id]
    end

    it "can query which zones are using a playlist" do
      playlist = Generator.playlist
      playlist.save!

      zone = Generator.zone
      zone.playlists = [playlist.id.as(String)]
      zone.save!

      playlist.zones.map(&.id).should eq [zone.id]
    end
  end
end
