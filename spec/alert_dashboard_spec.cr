require "./helper"

module PlaceOS::Model
  describe AlertDashboard do
    test_round_trip(AlertDashboard)

    it "saves an alert dashboard" do
      authority = Generator.authority.save!
      inst = Generator.alert_dashboard(authority_id: authority.id).save!
      AlertDashboard.find!(inst.id.as(String)).id.should eq inst.id
    end

    it "validates required fields" do
      invalid_model = Generator.alert_dashboard
      invalid_model.name = ""
      invalid_model.authority_id = nil

      invalid_model.valid?.should be_false
      invalid_model.errors.size.should eq 2
      invalid_model.errors.map(&.field).should contain(:name)
      invalid_model.errors.map(&.field).should contain(:authority_id)
    end

    it "belongs to authority" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!

      dashboard.authority.should_not be_nil
      dashboard.authority.try(&.id).should eq authority.id
    end

    it "has many alerts" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!
      alert1 = Generator.alert(alert_dashboard_id: dashboard.id).save!
      alert2 = Generator.alert(alert_dashboard_id: dashboard.id).save!

      dashboard.alerts.size.should eq 2
      dashboard.alerts.map(&.id).should contain(alert1.id)
      dashboard.alerts.map(&.id).should contain(alert2.id)
    end

    it "counts alerts" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!
      Generator.alert(alert_dashboard_id: dashboard.id).save!
      Generator.alert(alert_dashboard_id: dashboard.id).save!

      dashboard.alerts.count.should eq 2
    end

    it "filters active alerts" do
      authority = Generator.authority.save!
      dashboard = Generator.alert_dashboard(authority_id: authority.id).save!
      active_alert = Generator.alert(alert_dashboard_id: dashboard.id, enabled: true).save!
      Generator.alert(alert_dashboard_id: dashboard.id, enabled: false).save!

      active_alerts = dashboard.active_alerts
      active_alerts.size.should eq 1
      active_alerts.first.id.should eq active_alert.id
    end
  end
end
