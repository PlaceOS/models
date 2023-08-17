require "./helper"

module PlaceOS::Model
  describe Module do
    test_round_trip(Module)

    describe "persistence" do
      Driver::Role.values.each do |role|
        it "saves a #{role} module" do
          driver = Generator.driver(role: role)
          mod = Generator.module(driver: driver)
          begin
            mod.save!
          rescue error : PgORM::Error::RecordInvalid
            inspect_error(error)
          end
          mod.persisted?.should be_true
        end
      end

      it "adds a Logic module to parent system" do
        driver = Generator.driver(role: Driver::Role::Logic)
        mod = Generator.module(driver: driver).save!
        mod.persisted?.should be_true

        mod.control_system!.modules.should contain(mod.id)
      end

      it "removes module from parent system on destroy" do
        control_system = Generator.control_system
        control_system.modules = [random_id]
        control_system.save!
        control_system_id = control_system.id.as(String)

        driver = Generator.driver(role: Driver::Role::Logic)
        mod_remain = Generator.module(driver: driver, control_system: control_system).save!
        mod_remain.persisted?.should be_true

        mod = Generator.module(driver: driver, control_system: control_system).save!
        mod.persisted?.should be_true
        control_system = mod.control_system!
        control_system.modules.should contain(mod.id)
        control_system.modules.should contain(mod_remain.id)

        mod.destroy

        control_system_modules = ControlSystem.find!(control_system_id).modules

        # Removes the module reference on destroy
        control_system_modules.should_not contain(mod.id)
        # Preserves the existing modules
        control_system_modules.should contain(mod_remain.id)
      end

      Driver::Role.values.reject(Driver::Role::Logic).each do |role|
        it "invalidates a #{role} modules with a parent system" do
          driver = Generator.driver(role: role)
          mod = Generator.module(driver: driver)
          mod.control_system_id = "cs-d0esN073xi57"
          mod.valid?.should be_false
          mod.errors.first.to_s.should eq "control_system should not be associated for #{role} modules"
        end
      end

      describe "validation mutation post-conditions" do
        it Driver::Role::SSH do
          driver = Generator.driver(role: Driver::Role::SSH)
          mod = Generator.module(driver: driver)

          mod.valid?.should be_true
          mod.role.should eq(Driver::Role::SSH)
        end

        it Driver::Role::Device do
          driver = Generator.driver(role: Driver::Role::Device)
          mod = Generator.module(driver: driver)

          mod.valid?.should be_true
          mod.role.should eq(Driver::Role::Device)
        end

        it Driver::Role::Service do
          driver = Generator.driver(role: Driver::Role::Service)
          mod = Generator.module(driver: driver)

          mod.valid?.should be_true
          mod.udp.should be_false
          mod.role.should eq(Driver::Role::Service)
        end

        it Driver::Role::Websocket do
          driver = Generator.driver(role: Driver::Role::Websocket)
          mod = Generator.module(driver: driver)

          mod.valid?.should be_true
          mod.udp.should be_false
          mod.role.should eq(Driver::Role::Websocket)
        end

        it Driver::Role::Logic do
          driver = Generator.driver(role: Driver::Role::Logic)
          mod = Generator.module(driver: driver)

          mod.valid?.should be_true
          mod.udp.should be_false
          mod.tls.should be_false
          mod.connected.should be_true
          mod.control_system_id.should_not be_nil
          mod.role.should eq(Driver::Role::Logic)
        end
      end
    end

    describe "locating modules" do
      it "logic_for" do
        control_system = Generator.control_system.save!
        driver = Generator.driver(role: Driver::Role::Logic).save!

        expected_ids = Array.new(2) {
          Generator.module(driver: driver, control_system: control_system).save!.id.as(String)
        }.sort

        fetched_ids = Module.logic_for(control_system.id.as(String)).compact_map(&.id).to_a.sort

        fetched_ids.should eq expected_ids
      end

      it "in_zone" do
        control_system = Generator.control_system.save!
        begin
          zone = Generator.zone.save!
        rescue e : PgORM::Error::RecordInvalid
          inspect_error(e)
          raise e
        end
        mod = Generator.module(control_system: control_system).save!
        control_system.zones = [zone.id.as(String)]
        control_system.modules = [mod.id.as(String)]
        control_system.save!

        Module
          .in_zone(zone.id.as(String))
          .first
          .id
          .should eq mod.id
      end

      it "in_control_system" do
        control_system = Generator.control_system.save!
        mod = Generator.module(control_system: control_system).save!
        control_system.modules = [mod.id.as(String)]
        control_system.save!

        Module
          .in_control_system(control_system.id.as(String))
          .first
          .id
          .should eq mod.id
      end
    end

    describe "resolved_name" do
      it "is the module name if no custom_name" do
        mod = Generator.module
        mod.resolved_name.should eq mod.name
      end

      it "is the module name if custom_name is empty" do
        mod = Generator.module
        mod.custom_name = ""
        mod.resolved_name.should eq mod.name
      end

      it "is the custom_name if set" do
        mod = Generator.module
        mod.custom_name = UUID.random.to_s
        mod.resolved_name.should eq mod.custom_name
      end
    end

    describe "edge module" do
      it "has_edge_hint?" do
        driver = Generator.driver(role: Driver::Role::Service)
        mod = Generator.module(driver: driver)
        mod.edge_id = "edge-123"
        mod.save!

        Module.has_edge_hint?(mod.id.as(String)).should be_true
      end

      it "on_edge?" do
        mod = Module.new
        mod.on_edge?.should be_false
        mod.edge_id = "edge-123"
        mod.on_edge?.should be_true
      end

      it "cannot be a logic module" do
        driver = Generator.driver(role: Driver::Role::Logic).save!
        edge = Generator.edge.save!
        mod = Generator.module(driver: driver)
        mod.edge = edge

        mod.valid?.should be_false
        mod.errors.first.message.should eq "logic module cannot be allocated to an edge"
      end
    end

    describe "settings_hierarchy" do
      it "obeys logic module settings hierarchy" do
        driver = Generator.driver(role: Driver::Role::Logic).save!
        driver_settings_string = %(value: 0\nscreen: 0\nfrangos: 0\nchop: 0)
        begin
          Generator.settings(driver: driver, settings_string: driver_settings_string).save!
        rescue e : PgORM::Error::RecordInvalid
          inspect_error(e)
          raise e
        end

        control_system = Generator.control_system.save!
        control_system_settings_string = %(frangos: 1)
        Generator.settings(control_system: control_system, settings_string: control_system_settings_string).save!

        zone = Generator.zone.save!
        zone_settings_string = %(screen: 1)
        Generator.settings(zone: zone, settings_string: zone_settings_string).save!

        control_system.zones = [zone.id.as(String)]
        control_system.save!

        mod = Generator.module(driver: driver, control_system: control_system).save!
        module_settings_string = %(value: 2\n)
        Generator.settings(mod: mod, settings_string: module_settings_string).save!

        expected_settings_ids = [
          mod.settings,
          control_system.settings,
          zone.settings,
          driver.settings,
        ].flat_map(&.compact_map(&.id))

        settings_hierarchy_ids = mod.settings_hierarchy.compact_map(&.id)

        settings_hierarchy_ids.should eq expected_settings_ids

        {mod, control_system, zone, driver}.each &.destroy
      end
    end

    describe "merge_settings" do
      it "obeys logic module settings hierarchy" do
        driver = Generator.driver(role: Driver::Role::Logic).save!
        driver_settings_string = %(value: 0\nscreen: 0\nfrangos: 0\nchop: 0)
        driver_settings = Generator.settings(driver: driver, settings_string: driver_settings_string).save!

        control_system = Generator.control_system.save!
        control_system_settings_string = %(frangos: 1)
        control_system_settings = Generator.settings(control_system: control_system, settings_string: control_system_settings_string).save!

        zone = Generator.zone.save!
        zone_settings_string = %(screen: 1)
        zone_settings = Generator.settings(zone: zone, settings_string: zone_settings_string).save!

        control_system.zones = [zone.id.as(String)]
        control_system.save!

        mod = Generator.module(driver: driver, control_system: control_system).save!

        module_settings_string = %(value: 2\n)
        module_settings = Generator.settings(mod: mod, settings_string: module_settings_string).save!

        merged_settings = JSON.parse(mod.merge_settings).as_h.transform_values &.as_i

        # Module > Driver
        merged_settings["value"].should eq 2
        # Module > Zone > Driver
        merged_settings["screen"].should eq 1
        # Module > ControlSystem > Driver
        merged_settings["frangos"].should eq 1
        # Driver
        merged_settings["chop"].should eq 0

        # Reset the parent association reference through `reload!`
        {driver, zone, control_system, mod.reload!}.each &.destroy
        {control_system_settings, driver_settings, module_settings, zone_settings}.each do |setting|
          Settings.find?(setting.id.as(String)).should be_nil
        end
      end

      it "obeys driver-module settings hierarchy" do
        driver = Generator.driver(role: Model::Driver::Role::Service).save!
        driver_settings_string = %(value: 0\nscreen: 0\nfrangos: 0\nchop: 0)
        driver_settings = Generator.settings(driver: driver, settings_string: driver_settings_string).save!

        control_system = Generator.control_system.save!
        control_system_settings_string = %(frangos: 1)
        control_system_settings = Generator.settings(control_system: control_system, settings_string: control_system_settings_string).save!

        zone = Generator.zone.save!
        zone_settings_string = %(screen: 1)
        zone_settings = Generator.settings(zone: zone, settings_string: zone_settings_string).save!

        control_system.zones = [zone.id.as(String)]
        control_system.save!

        mod = Generator.module(driver: driver, control_system: control_system).save!

        module_settings_string = %(value: 2\n)
        module_settings = Generator.settings(mod: mod, settings_string: module_settings_string).save!

        merged_settings = JSON.parse(mod.merge_settings).as_h.transform_values &.as_i

        # Module > Driver
        merged_settings["value"].should eq 2
        # Module > Driver
        merged_settings["screen"].should eq 0
        # Module > Driver
        merged_settings["frangos"].should eq 0
        # Driver
        merged_settings["chop"].should eq 0

        # Reset the parent association reference through `reload!`
        {driver, zone, control_system, mod.reload!}.each &.destroy
        {control_system_settings, driver_settings, module_settings, zone_settings}.each do |setting|
          Settings.find?(setting.id.as(String)).should be_nil
        end
      end
    end
  end
end
