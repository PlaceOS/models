require "./helper"

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
            Settings.find(settings.id.as(String)).should be_nil
          end
        end
      end
    end
  end

  describe SettingsHelper do
    test_settings(ControlSystem)
    test_settings(Module)
    test_settings(Zone)
    test_settings(Driver)

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
