require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Upload.clear
  end

  describe Upload do
    test_round_trip(Upload)

    it "saves an Upload" do
      inst = Generator.upload.save!
      Upload.find!(inst.id.as(String)).id.should eq inst.id
    end
  end
end
