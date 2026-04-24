require "./helper"

module PlaceOS::Model
  describe GroupPlaylistItem do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      GroupPlaylistItem.clear
      GroupPlaylist.clear
      GroupApplicationDoorkeeper.clear
      GroupApplicationMembership.clear
      Group.clear
      GroupApplication.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      item = Generator.item(authority: authority).save!

      link = Generator.group_playlist_item(group: group, playlist_item: item).save!
      link.persisted?.should be_true

      found = GroupPlaylistItem.find!({group.id.not_nil!, item.id.not_nil!})
      found.group_id.should eq group.id
      found.playlist_item_id.should eq item.id
    end

    it "prevents duplicate (group_id, playlist_item_id)" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      item = Generator.item(authority: authority).save!

      Generator.group_playlist_item(group: group, playlist_item: item).save!
      expect_raises(::PgORM::Error) do
        Generator.group_playlist_item(group: group, playlist_item: item).save!
      end
    end

    it "rejects a link whose group and item are in different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      group = Generator.group(authority: auth1).save!
      item = Generator.item(authority: auth2).save!

      link = GroupPlaylistItem.new(
        group_id: group.id.not_nil!,
        playlist_item_id: item.id.not_nil!,
      )
      link.valid?.should be_false
      link.errors.map(&.field).should contain(:playlist_item_id)
    end

    it "cascades when the group is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      item = Generator.item(authority: authority).save!

      Generator.group_playlist_item(group: group, playlist_item: item).save!
      group.destroy
      GroupPlaylistItem.where(playlist_item_id: item.id).to_a.should be_empty
    end

    it "cascades when the playlist item is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      item = Generator.item(authority: authority).save!

      Generator.group_playlist_item(group: group, playlist_item: item).save!
      item.destroy
      GroupPlaylistItem.where(group_id: group.id).to_a.should be_empty
    end
  end
end
