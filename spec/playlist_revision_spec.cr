require "./helper"

module PlaceOS::Model
  describe Playlist::Revision, focus: true do
    Spec.before_each do
      Playlist::Revision.clear
      Playlist::Item.clear
    end

    test_round_trip(Playlist::Revision)

    it "cleans up items lazily when revisions are saved" do
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

      item.destroy
      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item1_id, item2_id]
      revision.save!

      revision.items.should eq [item2_id]
      revision = Playlist::Revision.find(revision.id.as(String))
      revision.items.should eq [item2_id]
    end

    it "validates media is configured" do
      item = Generator.item
      item.media_uri = ""
      item.save.should eq false
      item.errors.first.field.should eq :media_uri

      item = Generator.item
      item.media_type = Playlist::Item::MediaType::Image
      item.save.should eq false
      item.errors.first.field.should eq :media_id
    end

    it "cleans up items lazily when revisions are saved" do
      revision = Generator.revision

      item = Generator.item
      item.save!
      item1_id = item.id.as(String)
      item2 = Generator.item
      item2.save!
      item2_id = item2.id.as(String)

      revision.items = [item1_id, item2_id]
      revision.save!

      items = revision.fetch_items
      items.size.should eq 2
      items.map(&.id).should eq [item1_id, item2_id]
    end
  end
end
