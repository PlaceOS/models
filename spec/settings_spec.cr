require "./helper"

module PlaceOS::Model
  mock_data = {
    {Encryption::Level::None, %({"sla": "99.?"})},
    {Encryption::Level::Support, %({"whales": "victor mcwhale"})},
    {Encryption::Level::Admin, %({"tax_haven": "seychelles"})},
    {Encryption::Level::NeverDisplay, %({"secret_key": "secret1234"})},
  }

  describe Settings do
    it "saves a settings" do
      settings = Generator.settings
      begin
        settings.save!
      rescue e : RethinkORM::Error::DocumentInvalid
        inspect_error(e)
        raise e
      end

      settings.should_not be_nil
      settings.persisted?.should be_true
      settings.id.as(String).should start_with "sets-"
    end

    it "accepts empty settings strings" do
      settings = Generator.settings
      settings.settings_string = ""
      begin
        settings.save!
      rescue e : RethinkORM::Error::DocumentInvalid
        inspect_error(e)
        raise e
      end

      settings.should_not be_nil
      settings.persisted?.should be_true
      settings.keys.should be_empty
    end

    it "encrypts on save" do
      unencrypted = %({"secret_key": "secret1234"})
      settings = Generator.settings(settings_string: unencrypted, encryption_level: Encryption::Level::Admin).save!
      encrypted = settings.settings_string.as(String)

      encrypted.should_not eq unencrypted
      encrypted.should start_with '\e'
    end

    it "generates top-level settings keys on save" do
      unencrypted = %({"secret_key": "secret1234"})
      settings = Generator.settings(settings_string: unencrypted).save!
      settings.keys.should eq ["secret_key"]
    end

    it "creates versions on updates to the master Settings" do
      settings_history = ["a: 0\n", "a: 1\n", "a: 2\n", "a: 3\n"]
      settings = Generator.settings(
        encryption_level: Encryption::Level::None,
        settings_string: settings_history.first
      ).save!

      settings_history[1..].each_with_index(offset: 1) do |string, i|
        Timecop.freeze(i.seconds.from_now) do
          settings.settings_string = string
          settings.save!
        end
      end

      settings.history.map(&.any["a"]).should eq [3, 2, 1, 0]

      settings.history(limit: 3).size.should eq 3
    end

    describe "#for_parent" do
      it "queries for a single parent_ids" do
        Settings.clear

        id = "sys-1234"
        settings = mock_data.map do |level, string|
          Settings.new(encryption_level: level, settings_string: string, parent_id: id).save!
        end.to_a

        ids = settings.map(&.id.as(String)).sort
        Settings.for_parent(id).map(&.id.as(String)).sort.should eq ids
        settings.each &.destroy
      end

      it "queries for a collection of parent_ids" do
        Settings.clear

        mock_ids = Array.new(mock_data.size) { "sys-#{rand(9999)}" }
        settings = mock_data.zip(mock_ids).map do |(level, string), id|
          Settings.new(encryption_level: level, settings_string: string, parent_id: id).save!
        end.to_a

        ids = settings.map(&.id.as(String)).sort
        Settings.for_parent(mock_ids).map(&.id.as(String)).sort.should eq ids
        settings.each &.destroy
      end
    end

    describe "#dependent_modules" do
      it "gets modules dependent on setting for Driver" do
        driver = Generator.driver(role: Driver::Role::SSH).save!
        settings = Generator.settings(driver: driver).save!
        mod = Generator.module(driver: driver).save!

        settings
          .dependent_modules
          .first
          .id
          .should eq mod.id

        {mod, driver}.each &.destroy
      end

      it "gets modules dependent on setting for Module" do
        mod = Generator.module.save!
        settings = Generator.settings(mod: mod).save!

        settings
          .dependent_modules
          .first
          .id
          .should eq mod.id

        mod.destroy
      end

      it "gets logic modules dependent on setting for ControlSystem" do
        control_system = Generator.control_system.save!
        settings = Generator.settings(control_system: control_system).save!
        driver = Generator.driver(role: Driver::Role::Logic).save!
        mod = Generator.module(driver: driver).save!

        control_system.modules = [mod.id.as(String)]
        control_system.save!

        settings
          .dependent_modules
          .first
          .id
          .should eq mod.id

        {control_system, driver, mod}.each &.destroy
      end

      it "gets logic modules dependent on setting for Zone" do
        control_system = Generator.control_system.save!
        zone = Generator.zone.save!
        settings = Generator.settings(zone: zone).save!
        driver = Generator.driver(role: Driver::Role::Logic).save!
        mod = Generator.module(driver: driver).save!

        control_system.zones = [zone.id.as(String)]
        control_system.modules = [mod.id.as(String)]
        control_system.save!

        settings
          .dependent_modules
          .first
          .id
          .should eq mod.id

        {control_system, zone, driver, mod}.each &.destroy
      end
    end

    it "#get_setting_for" do
      settings = mock_data.map do |level, string|
        sets = Settings.new(encryption_level: level, settings_string: string, parent_id: "1234")
        sets.build_keys
        sets.encrypt!
      end

      Settings.get_setting_for?(Generator.user, "tax_haven", settings.to_a).should be_nil
      Settings.get_setting_for?(Generator.user(admin: true), "tax_haven", settings.to_a).should eq "seychelles"
    end

    describe "#decrypt_for" do
      mock_data.each do |level, string|
        it "decrypts for #{level}" do
          user = Generator.user
          support = Generator.user(support: true)
          admin = Generator.user(admin: true)

          settings = Settings.new(encryption_level: level, parent_id: "1234", settings_string: string)
          settings.encrypt!

          case level
          in .none?
            settings.decrypt_for(user).should eq string
            settings.decrypt_for(support).should eq string
            settings.decrypt_for(admin).should eq string
            is_encrypted?(settings.decrypt_for(user)).should be_false
            is_encrypted?(settings.decrypt_for(support)).should be_false
            is_encrypted?(settings.decrypt_for(admin)).should be_false
          in .support?
            settings.decrypt_for(user).should_not eq string
            settings.decrypt_for(support).should eq string
            settings.decrypt_for(admin).should eq string
            is_encrypted?(settings.decrypt_for(user)).should be_true
            is_encrypted?(settings.decrypt_for(support)).should be_false
            is_encrypted?(settings.decrypt_for(admin)).should be_false
          in .admin?
            settings.decrypt_for(user).should_not eq string
            settings.decrypt_for(support).should_not eq string
            settings.decrypt_for(admin).should eq string
            is_encrypted?(settings.decrypt_for(user)).should be_true
            is_encrypted?(settings.decrypt_for(support)).should be_true
            is_encrypted?(settings.decrypt_for(admin)).should be_false
          in .never_display?
            settings.decrypt_for(user).should_not eq string
            settings.decrypt_for(support).should_not eq string
            settings.decrypt_for(admin).should_not eq string
            is_encrypted?(settings.decrypt_for(user)).should be_true
            is_encrypted?(settings.decrypt_for(support)).should be_true
            is_encrypted?(settings.decrypt_for(admin)).should be_true
          end
        end
      end
    end
  end
end
