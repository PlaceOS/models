require "./helper"

module PlaceOS::Model
  describe DoorkeeperApplication do
    it "saves an app with a HTTP style" do
      app = DoorkeeperApplication.new
      app.name = RANDOM.hex(10)
      app.redirect_uri = "http://test.redirect.com.au/#{RANDOM.hex(3)}"
      app.owner_id = RANDOM.hex(10)

      begin
        app.save!
      rescue e : PgORM::Error::RecordInvalid
        inspect_error(e)
        raise e
      end

      app.persisted?.should be_true
      app.uid.should eq(Digest::MD5.hexdigest(app.redirect_uri))
    end

    it "no duplicate app uris" do
      expect_raises(PgORM::Error::RecordInvalid) do
        uri = "appuri://test.redirect.com.au/#{RANDOM.hex(3)}"
        app1 = DoorkeeperApplication.new
        app1.name = RANDOM.hex(10)
        app1.redirect_uri = uri
        app1.owner_id = RANDOM.hex(10)
        app1.save!
        app2 = DoorkeeperApplication.new
        app2.name = RANDOM.hex(10)
        app2.redirect_uri = uri
        app2.owner_id = app1.owner_id
        app2.save!
      end
    end

    it "no duplicate app names" do
      expect_raises(PgORM::Error::RecordInvalid) do
        name = RANDOM.hex(3)
        app1 = DoorkeeperApplication.new
        app1.name = name
        app1.redirect_uri = "appuri://test.redirect.com.au/#{RANDOM.hex(3)}"
        app1.owner_id = RANDOM.hex(10)
        app1.save!
        app2 = DoorkeeperApplication.new
        app2.name = name
        app2.redirect_uri = "appuri://test.redirect.com.au/#{RANDOM.hex(3)}"
        app2.owner_id = app1.owner_id
        app2.save!
      end
    end

    it "saves an app with a random UID" do
      app = DoorkeeperApplication.new
      app.name = RANDOM.hex(10)
      app.redirect_uri = "appuri://test.redirect.com.au/#{RANDOM.hex(3)}"
      app.owner_id = RANDOM.hex(10)

      begin
        app.save!
      rescue e : PgORM::Error::RecordInvalid
        inspect_error(e)
        raise e
      end

      app.persisted?.should be_true
      app.uid.should_not eq(Digest::MD5.hexdigest(app.redirect_uri))
    end

    it "saves an app with a specified UID" do
      DoorkeeperApplication.clear
      app = DoorkeeperApplication.new
      app.name = RANDOM.hex(10)
      app.redirect_uri = "http://test.redirect.com.au/#{RANDOM.hex(3)}"
      app.uid = "my-special-uid"
      app.owner_id = RANDOM.hex(10)

      begin
        app.save!
      rescue e : PgORM::Error::RecordInvalid
        inspect_error(e)
        raise e
      end

      app.persisted?.should be_true
      app.uid.should eq("my-special-uid")
    end
  end
end
