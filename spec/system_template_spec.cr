require "./helper"

module PlaceOS::Model
  describe SignageTemplate::SystemTemplate do
    Spec.before_each do
      SignageTemplate::SystemTemplate.clear
      SignageTemplate.clear
      ControlSystem.clear
    end

    test_round_trip(SignageTemplate::SystemTemplate)

    it "requires a control system and a template" do
      sys_template = SignageTemplate::SystemTemplate.new
      sys_template.save.should eq false
      sys_template.errors.map(&.field).should contain :control_system_id
      sys_template.errors.map(&.field).should contain :template_id
    end

    it "attaches a template to a system as the default when no schedule is set" do
      sys_template = Generator.system_template.save!
      sys_template.default?.should eq true

      found = SignageTemplate::SystemTemplate.find!(sys_template.id.as(UUID))
      found.schedule.should be_nil
      found.default?.should eq true
    end

    it "round-trips a schedule" do
      schedule = Playlist::Schedule.new(play_cron: "*/5 * * * *", play_period: 60)
      sys_template = Generator.system_template(schedule: schedule).save!
      sys_template.default?.should eq false

      found = SignageTemplate::SystemTemplate.find!(sys_template.id.as(UUID))
      reloaded = found.schedule.as(Playlist::Schedule)
      reloaded.play_cron.should eq "*/5 * * * *"
      reloaded.play_period.should eq 60
    end

    it "validates the schedule when present" do
      sys_template = Generator.system_template(schedule: Playlist::Schedule.new(play_cron: "not a cron"))
      sys_template.save.should eq false
      sys_template.errors.first.field.should eq :schedule
    end

    it "allows a default and multiple scheduled rows for the same pairing" do
      template = Generator.signage_template.save!
      sys = Generator.control_system.save!

      Generator.system_template(template: template, control_system: sys).save!
      Generator.system_template(template: template, control_system: sys, schedule: Playlist::Schedule.new(play_cron: "0 9 * * *")).save!
      Generator.system_template(template: template, control_system: sys, schedule: Playlist::Schedule.new(play_cron: "0 17 * * *")).save!

      SignageTemplate::SystemTemplate.where(control_system_id: sys.id.as(String)).count.should eq 3
    end

    it "rejects a second default for the same pairing" do
      template = Generator.signage_template.save!
      sys = Generator.control_system.save!

      Generator.system_template(template: template, control_system: sys).save!

      duplicate = Generator.system_template(template: template, control_system: sys)
      duplicate.save.should eq false
      duplicate.errors.first.field.should eq :schedule

      # the same template can still be the default on another system
      other_sys = Generator.control_system.save!
      Generator.system_template(template: template, control_system: other_sys).save.should eq true
    end

    it "allows re-saving the existing default" do
      sys_template = Generator.system_template.save!

      found = SignageTemplate::SystemTemplate.find!(sys_template.id.as(UUID))
      found.save.should eq true
    end

    it "enforces the single default constraint at the database level" do
      template = Generator.signage_template.save!
      sys = Generator.control_system.save!

      Generator.system_template(template: template, control_system: sys).save!
      scheduled = Generator.system_template(template: template, control_system: sys, schedule: Playlist::Schedule.new).save!

      # bypass model validation with a raw update; the partial unique index fires
      expect_raises(::Exception) do
        SignageTemplate::SystemTemplate
          .where("id = ?", scheduled.id.as(UUID))
          .update_all({:schedule => nil})
      end
    end

    it "is removed when the control system is deleted" do
      sys = Generator.control_system.save!
      sys_template = Generator.system_template(control_system: sys).save!
      id = sys_template.id.as(UUID)

      sys.destroy
      SignageTemplate::SystemTemplate.find?(id).should be_nil
    end

    it "is removed when the template is deleted" do
      template = Generator.signage_template.save!
      sys_template = Generator.system_template(template: template).save!
      id = sys_template.id.as(UUID)

      template.destroy
      SignageTemplate::SystemTemplate.find?(id).should be_nil
    end

    it "exposes attached systems via the template" do
      template = Generator.signage_template.save!
      sys = Generator.control_system.save!
      Generator.system_template(template: template, control_system: sys).save!

      template.system_templates.count.should eq 1
      template.systems.to_a.map(&.id).should eq [sys.id]
    end
  end
end
