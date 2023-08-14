require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Storage.clear
  end

  describe Storage do
    test_round_trip(Upload)

    it "saves a Storage" do
      inst = Generator.storage.save!
      Storage.find?(inst.id.as(String)).try &.id.should eq inst.id
    end

    it "ensures uniquness of storage type, service, authority" do
      s1 = Generator.storage.save!
      expect_raises(PgORM::Error::RecordInvalid) do
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
  end
end
