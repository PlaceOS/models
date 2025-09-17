require "./helper"

module PlaceOS::Model
  describe Alert do
    test_round_trip(Alert)

    it "saves an alert" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!
      inst = Generator.alert(alert_dashboard_id: dashboard.id).save!
      Alert.find!(inst.id.as(String)).id.should eq inst.id
    end

    it "validates required fields" do
      invalid_model = Generator.alert
      invalid_model.name = ""
      invalid_model.alert_dashboard_id = nil

      invalid_model.valid?.should be_false
      invalid_model.errors.size.should eq 2
      invalid_model.errors.map(&.field).should contain(:name)
      invalid_model.errors.map(&.field).should contain(:alert_dashboard_id)
    end

    it "belongs to alert dashboard" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!
      alert = Generator.alert(alert_dashboard_id: dashboard.id).save!

      alert.alert_dashboard.should_not be_nil
      alert.alert_dashboard.try(&.id).should eq dashboard.id
    end

    it "has default values" do
      alert = Generator.alert
      alert.enabled.should be_true
      alert.severity.should eq Alert::Severity::MEDIUM
      alert.alert_type.should eq Alert::AlertType::THRESHOLD
      alert.check_interval.should eq 60000
    end

    it "validates conditions" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!
      model = Generator.alert(alert_dashboard_id: dashboard.id)

      valid = Trigger::Conditions::TimeDependent.new(
        type: Trigger::Conditions::TimeDependent::Type::At,
        time: Time.utc,
      )

      invalid = Trigger::Conditions::TimeDependent.new(
        cron: "5 * * * *",
      )
      model.conditions.try &.time_dependents = [valid, invalid]

      model.valid?.should be_false
      model.errors.size.should eq 1
      model.errors.first.to_s.should end_with "type should not be nil"
    end

    describe "severity helpers" do
      it "identifies critical alerts" do
        alert = Generator.alert
        alert.severity = Alert::Severity::CRITICAL
        alert.critical?.should be_true

        alert.severity = Alert::Severity::HIGH
        alert.critical?.should be_false
      end

      it "identifies high priority alerts" do
        alert = Generator.alert

        alert.severity = Alert::Severity::CRITICAL
        alert.high_priority?.should be_true

        alert.severity = Alert::Severity::HIGH
        alert.high_priority?.should be_true

        alert.severity = Alert::Severity::MEDIUM
        alert.high_priority?.should be_false

        alert.severity = Alert::Severity::LOW
        alert.high_priority?.should be_false
      end
    end

    describe "enum validation" do
      it "works with valid severity values" do
        authority = Generator.authority.save!
        dashboard = Generator.alert_dashboard(authority_id: authority.id).save!

        Alert::Severity.values.each do |severity|
          alert = Generator.alert(alert_dashboard_id: dashboard.id)
          alert.severity = severity
          alert.valid?.should be_true
        end
      end

      it "works with valid alert type values" do
        authority = Generator.authority.save!
        dashboard = Generator.alert_dashboard(authority_id: authority.id).save!

        Alert::AlertType.values.each do |alert_type|
          alert = Generator.alert(alert_dashboard_id: dashboard.id)
          alert.alert_type = alert_type
          alert.valid?.should be_true
        end
      end
    end
  end
end
