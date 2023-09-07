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

    it "validates safe file names" do
      Upload.safe_filename?("test ing.txt").should be_true
      Upload.safe_filename?("لْأَبْجَدِيَّالْعَرَبِ.txt").should be_true
      Upload.safe_filename?("test\nfilename.txt").should be_false
      Upload.safe_filename?("CON.txt").should be_false
      Upload.safe_filename?("test#file.txt").should be_false
      Upload.safe_filename?("test?file.txt").should be_false
      Upload.safe_filename?("test/file..txt").should be_false
      Upload.safe_filename?("..test.txt").should be_false
      Upload.safe_filename?("test..txt").should be_false
      Upload.safe_filename?("test..file.txt").should be_false
      Upload.safe_filename?("test file.txt").should be_false
      Upload.safe_filename?("test&e.txt").should be_false
      Upload.safe_filename?("test=e.txt").should be_false
      Upload.safe_filename?("test%e.txt").should be_false
    end
  end
end
