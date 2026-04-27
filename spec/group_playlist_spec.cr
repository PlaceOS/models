require "./helper"

module PlaceOS::Model
  describe GroupPlaylist do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      GroupPlaylistItem.clear
      GroupPlaylist.clear
      Group.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      playlist = Generator.playlist(authority: authority).save!

      link = Generator.group_playlist(group: group, playlist: playlist).save!
      link.persisted?.should be_true

      found = GroupPlaylist.find!({group.id.not_nil!, playlist.id.not_nil!})
      found.group_id.should eq group.id
      found.playlist_id.should eq playlist.id
    end

    it "prevents duplicate (group_id, playlist_id)" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      playlist = Generator.playlist(authority: authority).save!

      Generator.group_playlist(group: group, playlist: playlist).save!
      expect_raises(::PgORM::Error) do
        Generator.group_playlist(group: group, playlist: playlist).save!
      end
    end

    it "rejects a link whose group and playlist are in different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      group = Generator.group(authority: auth1).save!
      playlist = Generator.playlist(authority: auth2).save!

      link = GroupPlaylist.new(
        group_id: group.id.not_nil!,
        playlist_id: playlist.id.not_nil!,
      )
      link.valid?.should be_false
      link.errors.map(&.field).should contain(:playlist_id)
    end

    it "cascades when the group is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      playlist = Generator.playlist(authority: authority).save!

      Generator.group_playlist(group: group, playlist: playlist).save!
      group.destroy
      GroupPlaylist.where(playlist_id: playlist.id).to_a.should be_empty
    end

    it "cascades when the playlist is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      playlist = Generator.playlist(authority: authority).save!

      Generator.group_playlist(group: group, playlist: playlist).save!
      playlist.destroy
      GroupPlaylist.where(group_id: group.id).to_a.should be_empty
    end
  end
end
