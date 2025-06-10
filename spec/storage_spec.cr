require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Storage.clear
    Authority.clear
  end

  describe Storage do
    test_round_trip(Upload)

    it "saves a Storage" do
      inst = Generator.storage.save!
      Storage.find?(inst.id.as(String)).try &.id.should eq inst.id
    end

    it "saves mimes and extension" do
      storage = PlaceOS::Model::Generator.storage
      storage.mime_filter = ["image/bmp", "image/jpeg", "image/tiff"]
      storage.ext_filter = [".bmp", ".jpg", ".tiff"]
      storage.save!
      inst = Storage.find(storage.id.as(String))
      inst.mime_filter.should eq(storage.mime_filter)
      inst.ext_filter.should eq(["bmp", "jpg", "tiff"])
    end

    it "ensures uniquness of storage type, service, authority" do
      s1 = Generator.storage.save!
      expect_raises(Exception, "authority_id need to be unique") do
        Generator.storage(bucket: s1.bucket_name).save!
      end
    end

    it "ensures secret key is encrypted" do
      s1 = Generator.storage
      secret = s1.access_secret
      s1.save!
      s1.secret_encrypted?.should be_true
      s1.decrypt_secret.should eq(secret)
    end

    it "should return default storage when no storage is associated with Authority" do
      s1 = Generator.storage.save!
      s1.authority_id.should be_nil
      Storage.storage_or_default("NOT-DEFINED-AUTHORITY").should_not be_nil
    end

    it "should return default storage when flagged" do
      authority = Generator.authority.save!

      def1 = Generator.storage.save!
      def1.authority_id.should be_nil
      def2 = Generator.storage.save!
      def2.authority_id.should be_nil
      def1.reload!
      def2.reload!

      def1.is_default.should be_false
      def2.is_default.should be_true

      s2 = Generator.storage
      s2.authority_id = authority.id
      s2.is_default = false
      s2.save!
      ret_store = Storage.storage_or_default(authority.id).id.should eq s2.id

      s3 = Generator.storage
      s3.authority_id = authority.id
      s3.is_default = true
      s3.save!
      s3.reload!
      s3.is_default.should be_true
      Storage.storage_or_default(authority.id).id.should eq s3.id

      s2.is_default = true
      s2.save!
      s2.reload!
      s2.is_default.should be_true

      s3.reload!
      s3.is_default.should be_false
      ret_store = Storage.storage_or_default(authority.id).id.should eq s2.id
    end

    it "should handle extension and mime whitelist" do
      s1 = Generator.storage.save!
      s1.check_file_ext("something")
      s1.check_file_mime("application/some-mime")

      s1.ext_filter << "jpg"
      s1.mime_filter << "application/jpeg"
      s1.save!

      expect_raises(Model::Error, "File extension not allowed") do
        s1.check_file_ext("something")
      end

      expect_raises(Model::Error, "File mimetype not allowed") do
        s1.check_file_mime("application/some-mime")
      end
    end
  end
end
