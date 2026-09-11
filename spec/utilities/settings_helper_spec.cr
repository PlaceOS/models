require "../helper"

module PlaceOS::Model
  macro test_settings(klass)
    describe {{ klass }} do
      {% klass_name = klass.id.split("::").last.underscore.id %}
      describe "#settings_at" do
        Encryption::Level.values.each do |level|
          it "retrieves #{level} settings" do
            Settings.clear
            model = Generator.{{klass_name}}.save!

            old_settings = %({"secret_key": "secret1234"})
            settings = Generator.settings(parent: model, settings_string: old_settings, encryption_level: level).save!
            found_settings = model.settings_at(level)
            found_settings.id.should eq settings.id

            if level.none?
                found_settings.settings_string.should eq old_settings
            else
                found_settings.settings_string.should_not eq old_settings
            end

            model.destroy
            # Testing the destruction methods
            Settings.find?(settings.id.as(String)).should be_nil
          end
        end
      end
    end
  end

  describe Utilities::SettingsHelper do
    test_settings(ControlSystem)
    test_settings(Module)
    test_settings(Zone)
    test_settings(Driver)

    describe "#settings_at with settings at every level" do
      it "returns the setting matching the requested level, not the most privileged" do
        Settings.clear
        model = Generator.module.save!

        by_level = Encryption::Level.values.to_h do |level|
          setting = Generator.settings(parent: model, settings_string: %({"level": "#{level}"}), encryption_level: level).save!
          {level, setting}
        end

        Encryption::Level.values.each do |level|
          found = model.settings_at?(level)
          found.should_not be_nil
          found.not_nil!.id.should eq by_level[level].id
          found.not_nil!.encryption_level.should eq level
        end

        model.destroy
      end

      it "returns nil when no setting exists at the requested level" do
        Settings.clear
        model = Generator.module.save!
        Generator.settings(parent: model, encryption_level: Encryption::Level::Admin).save!

        model.settings_at?(Encryption::Level::None).should be_nil
        model.settings_at?(Encryption::Level::Admin).should_not be_nil
        expect_raises(IndexError) { model.settings_at(Encryption::Level::None) }

        model.destroy
      end
    end

    describe "Settings.for_parent" do
      it "yields the query so callers can narrow the results" do
        Settings.clear
        model = Generator.module.save!
        none = Generator.settings(parent: model, encryption_level: Encryption::Level::None).save!
        Generator.settings(parent: model, encryption_level: Encryption::Level::Admin).save!

        all = Settings.for_parent(model.id.as(String))
        all.size.should eq 2
        # Most privileged first
        all.first.encryption_level.should eq Encryption::Level::Admin

        narrowed = Settings.for_parent(model.id.as(String)) do |q|
          q.where(encryption_level: Encryption::Level::None.to_i)
        end
        narrowed.map(&.id).should eq [none.id]

        model.destroy
      end
    end

    describe "#all_settings" do
      it "merges settings, in favour of lower privilege" do
        Settings.clear
        model = Generator.driver.save!
        key = "secret_key"
        Encryption::Level.values.each do |level|
          settings_string = {key => level}.to_json
          Generator.settings(parent: model, settings_string: settings_string, encryption_level: level).save!
        end

        Encryption::Level.parse(model.all_settings[YAML::Any.new(key)].as_s).none?.should be_true
        model.destroy
      end
    end
  end
end
