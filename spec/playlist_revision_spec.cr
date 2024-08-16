require "./helper"

module PlaceOS::Model
  describe Playlist::Revision do
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

      item.delete
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

    it "returns the latest version of playlist revisions" do
      revision1 = Generator.revision.save!
      revision2 = Generator.revision.save!
      revision3 = Generator.revision.save!

      rev2_old_id = revision2.id.as(String)
      sleep 2
      rev2_new = revision2.clone
      rev2_new.user = Generator.user.save!
      rev2_new.save!
      rev2_new_id = rev2_new.id.as(String)

      rev_ids = Playlist::Revision.revisions([
        revision1.playlist_id.as(String),
        revision2.playlist_id.as(String),
        revision3.playlist_id.as(String),
      ]).map(&.id.as(String))

      rev_ids.includes?(revision1.id).should be_true
      rev_ids.includes?(rev2_old_id).should be_false
      rev_ids.includes?(rev2_new_id).should be_true
      rev_ids.includes?(revision3.id).should be_true
    end

    it "updates playlist item play count" do
      item1 = Generator.item
      item1.save!
      item1_id = item1.id.as(String)
      item2 = Generator.item
      item2.save!
      item2_id = item2.id.as(String)

      Playlist::Item.update_counts({
        item1_id => 5,
        item2_id => 1,
      }).should eq 2

      Playlist::Item.find(item1_id).play_count.should eq 5
      Playlist::Item.find(item2_id).play_count.should eq 1

      Playlist::Item.update_counts({
        item1_id => 2,
        item2_id => 3,
      }).should eq 2

      Playlist::Item.find(item1_id).play_count.should eq 7
      Playlist::Item.find(item2_id).play_count.should eq 4
    end
  end
end
