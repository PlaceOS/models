require "./helper"

module PlaceOS::Model
  describe Playlist::Item do
    Spec.before_each do
      Playlist::Item.clear
      Playlist.clear
      ControlSystem.clear
    end

    it "create a playlist item" do
      upload = Generator.upload.save!
      media_id = upload.id.as(String)

      example_json = %({
          "created_at": 1723440666,
          "updated_at": 1723440666,
          "name": "Screenshot 2024-08-12 at 12.51.43 PM.png",
          "animation": "cut",
          "media_type": "image",
          "orientation": "landscape",
          "media_uri": "https://s3-ap-southeast-2.amazonaws.com/17234316461372523291.png",
          "media_id": "#{media_id}",
          "thumbnail_id": "#{media_id}",
          "valid_from": 1723440666,
          "valid_until": 17234406666
      })

      object = Playlist::Item.from_json example_json
      item = Playlist::Item.new
      item.clear_changes_information
      item.assign_attributes_from_json(example_json)

      authority = Authority.find_by_domain("localhost").as(Authority)
      item.authority_id = authority.id

      item.save.should eq true
    end

    it "cleans up playlists when an item is deleted" do
      revision = Generator.revision

      item = Generator.item
      item.save!
      item1_id = item.id.as(String)
      item2 = Generator.item
      item2.save!
      item2_id = item2.id.as(String)

      revision.items = [item1_id, item2_id]
      revision.save!
      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item1_id, item2_id]

      playlist = revision.playlist.not_nil!
      updated = playlist.updated_at
      sleep 1
      item.destroy

      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item2_id]
      playlist = revision.playlist.not_nil!

      updated.should_not eq playlist.updated_at
    end
  end
end
