require "./helper"

module PlaceOS::Model
  describe ControlSystem do
    test_round_trip(ControlSystem)

    it "saves a control system" do
      cs = Generator.control_system
      begin
        cs.save!
      rescue e : PgORM::Error::RecordInvalid
        inspect_error(e)
        raise e
      end

      cs.should_not be_nil
      id = cs.id
      id.should start_with "sys-" if id
      cs.persisted?.should be_true
    end

    it "no duplicate control system names" do
      expect_raises(PgORM::Error::RecordInvalid) do
        name = RANDOM.base64(10)
        cs1 = ControlSystem.new(
          name: name,
        )
        cs1.save!
        cs2 = ControlSystem.new(
          name: name,
        )
        cs2.save!
      end
    end

    it "removes modules with only self as parent on destroy" do
      control_system = Generator.control_system
      control_system.save!

      driver = Generator.driver(role: Driver::Role::Logic)
      mod = Generator.module(driver: driver, control_system: control_system).save!
      mod.control_system!.modules.should contain(mod.id)

      control_system = ControlSystem.find!(control_system.id.as(String))
      control_system.destroy

      Module.find?(mod.id.as(String)).should be_nil
      driver.destroy
    end

    it "removes modules only when there is a single instance of it remaining" do
      device_driver = Generator.driver(role: Driver::Role::Device)
      device_mod2 = Generator.module(driver: device_driver).save!
      device_mod = Generator.module(driver: device_driver).save!

      control_system = Generator.control_system
      control_system.modules = [device_mod.id.as(String), device_mod2.id.as(String)]
      control_system.save!

      driver = Generator.driver(role: Driver::Role::Logic)
      mod = Generator.module(driver: driver, control_system: control_system).save!
      control_system = mod.control_system!
      control_system.modules.should contain(mod.id)
      control_system.modules.size.should eq 3

      control_system2 = Generator.control_system
      control_system2.modules = [device_mod2.id.as(String)]
      control_system2.save!

      control_system = ControlSystem.find!(control_system.id.as(String))
      control_system.destroy

      Module.find?(mod.id.as(String)).should be_nil
      Module.find?(device_mod.id.as(String)).should be_nil
      Module.find!(device_mod2.id.as(String)).id.should eq device_mod2.id
      device_driver.destroy
      driver.destroy
    end

    describe "generation of json data" do
      it "#module_data" do
        cs = Generator.control_system.save!
        modules = [Driver::Role::Logic, Driver::Role::SSH, Driver::Role::Device].map do |role|
          driver = Generator.driver(role: role)
          Generator.module(driver: driver, control_system: cs).save!
        end

        driver_names = modules.compact_map(&.driver.try &.name).sort!

        module_ids = modules.compact_map(&.id)
        cs.modules = module_ids

        data = cs.module_data
        module_anys = data.map do |d|
          any = JSON.parse(d).as_h
          any.merge({"driver" => any["driver"].as_h})
        end

        data_driver_names = module_anys.map(&.["driver"]["name"].to_s).sort!
        data_driver_names.should eq driver_names

        ids = module_anys.map &.["id"].to_s
        ids.sort.should eq module_ids.sort
      end

      it "#zone_data" do
        cs = Generator.control_system.save!
        zones = Array(Zone).new(3) { Generator.zone.save! }
        zone_ids = zones.compact_map(&.id)
        cs.zones = zone_ids

        data = cs.zone_data
        data.size.should eq 3

        ids = data.map { |d| JSON.parse(d).as_h["id"].to_s }
        ids.sort.should eq zone_ids.sort
      end
    end

    describe "validation" do
      it "rejects invalid support URI" do
        sys = Generator.control_system
        sys.support_url = "string"
        sys.valid?.should be_false
      end

      it "rejects module_ids that don't exist" do
        control_system = Generator.control_system
        control_system.save!

        driver = Generator.driver(role: Driver::Role::Logic)
        mod = Generator.module(driver: driver, control_system: control_system).save!
        control_system = mod.control_system!
        control_system.modules.should contain(mod.id)

        control_system.modules += ["mod-no-exist", "mod-breaking"]
        control_system.modules.size.should eq 3
        control_system.save!
        control_system.modules.size.should eq 1
        control_system.modules.should contain(mod.id)

        control_system = ControlSystem.find!(control_system.id.as(String))
        control_system.destroy

        Module.find?(mod.id.as(String)).should be_nil
        driver.destroy
      end
    end

    describe "add_module" do
      it "adds a module if not already present" do
        control_system = Generator.control_system
        control_system.save!

        control_system_id = control_system.id.as(String)

        driver = Generator.driver(role: Driver::Role::SSH).save!
        mod = Generator.module(driver: driver).save!
        module_id = mod.id.as(String)

        version = control_system.version
        control_system.add_module(module_id)

        cs = ControlSystem.find!(control_system_id)
        cs.modules.should contain module_id
        cs.version.should eq(version + 1)

        {control_system, driver, mod}.each &.destroy
      end
    end

    describe "camera_snapshot_urls" do
      it "setting camera_snapshot_url updates camera_snapshot_urls" do
        control_system = Generator.control_system
        control_system.camera_snapshot_url = "https://placeos.com/"
        control_system.save!
        control_system.reload!
        control_system.camera_snapshot_urls[0]?.should eq control_system.camera_snapshot_url
        control_system.destroy
      end

      it "setting camera_snapshot_urls updates camera_snapshot_url" do
        control_system = Generator.control_system
        control_system.camera_snapshot_urls = ["https://placeos.com/"]
        control_system.save!
        control_system.reload!
        control_system.camera_snapshot_url.should eq control_system.camera_snapshot_urls[0]
        control_system.destroy
      end
    end

    describe "remove_module" do
      it "removes a module if present" do
        control_system = Generator.control_system
        control_system.save!

        control_system_id = control_system.id.as(String)

        driver = Generator.driver(role: Driver::Role::SSH)
        mod = Generator.module(driver: driver).save!
        module_id = mod.id.as(String)

        control_system.modules = [module_id]
        control_system.save

        cs = ControlSystem.find!(control_system_id)

        version = cs.version

        cs.modules.should contain module_id

        control_system.remove_module(module_id)
        control_system.save!

        cs = ControlSystem.find!(control_system_id)
        cs.modules.should_not contain module_id
        cs.version.should eq(version + 1)

        {control_system, driver, mod}.each &.destroy
      end

      it "deletes module if no longer referenced" do
        control_system = Generator.control_system
        control_system.save!

        control_system_id = control_system.id.as(String)

        driver = Generator.driver(role: Driver::Role::SSH)
        mod = Generator.module(driver: driver).save!
        module_id = mod.id.as(String)

        control_system.modules = [module_id]
        control_system.save!

        cs = ControlSystem.find!(control_system_id)

        version = cs.version

        cs.modules.should contain module_id

        control_system.remove_module(module_id)

        cs = ControlSystem.find!(control_system_id)
        cs.modules.should_not contain module_id
        cs.version.should eq(version + 1)

        Module.exists?(module_id).should be_false

        {control_system, driver, mod}.each &.destroy
      end
    end

    it "should create triggers when added and removed from a zone" do
      begin
        zone2 = Generator.zone.save!

        cs = Generator.control_system
        zone2_id = zone2.id
        if zone2_id
          cs.zones = [zone2_id]
        end

        cs.save!

        trigger = Trigger.create!(name: "trigger test")
        zone = Generator.zone
        trigger_id = trigger.id
        if trigger_id
          zone.triggers = [trigger_id]
        end
        zone.save!
        zone_id = zone.id
      rescue e : PgORM::Error::RecordInvalid
        inspect_error(e)
        raise e
      end

      cs.triggers.to_a.size.should eq 0

      # Set zones on the ControlSystem
      cs.zones = [zone_id, zone2_id] if zone_id && zone2_id
      cs.save!
      cs_id = cs.id.as(String)

      cs = ControlSystem.find!(cs_id)
      cs.triggers.to_a.size.should eq 1
      cs.triggers.to_a[0].zone_id.should eq zone.id

      cs.zones = [zone2_id] if zone2_id
      cs.save!

      cs = ControlSystem.find!(cs_id)
      cs.triggers.to_a.size.should eq 0
      zone.trigger_instances.to_a.size.should eq 0

      {cs, zone, zone2, trigger}.each &.destroy
    end
  end
end
