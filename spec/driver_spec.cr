require "./helper"

module PlaceOS::Model
  describe Driver do
    test_round_trip(Driver)

    it "creates a driver" do
      driver = Generator.driver(role: Driver::Role::Service)
      driver.save!

      driver.persisted?.should be_true

      driver.id.try &.should start_with "driver-"
      driver.role.should eq Driver::Role::Service
    end

    it "finds modules by driver" do
      mod = Generator.module.save!
      driver = mod.driver!

      driver.persisted?.should be_true
      mod.persisted?.should be_true

      Module.by_driver_id(driver.id.as(String)).first.id.should eq mod.id
    end

    it "triggers a recompile event" do
      commit = "fake-commit"
      driver = Generator.driver(role: Driver::Role::Service)
      driver.commit = "fake-commit"
      driver.save!

      driver.recompile
      driver.reload!

      driver.commit.should eq(Driver::RECOMPILE_PREFIX + commit)
      driver.recompile_commit?.should eq commit
    end

    it "return a list of drivers requiring updates" do
      driver = Generator.driver(role: Driver::Role::Service)
      driver.commit = "abcdefg"
      driver.save!

      driver2 = Generator.driver(role: Driver::Role::Service)
      driver2.commit = "abcdefh"
      driver2.save!

      info = Driver::UpdateInfo.new("abcdefhijkl", "new fake version", "fake author")
      driver.process_update_info(info)
      driver2.process_update_info(info)

      list = Driver.require_updates
      list.size.should eq(1)
    end

    describe "callbacks" do
      it "#cleanup_modules removes driver modules" do
        mod = Generator.module.save!
        driver = mod.driver!

        driver.persisted?.should be_true
        mod.persisted?.should be_true

        Module.by_driver_id(driver.id.as(String)).first.id.should eq mod.id
        driver.destroy
        Module.find?(mod.id.as(String)).should be_nil
      end

      it "#update_modules updates dependent modules' driver metadata" do
        driver = Generator.driver(role: Driver::Role::Device).save!
        mod = Generator.module(driver: driver).save!

        driver.persisted?.should be_true
        mod.persisted?.should be_true

        driver.role = Driver::Role::SSH
        driver.save!
        driver.persisted?.should be_true

        Module.find!(mod.id.as(String)).role.should eq Driver::Role::SSH
      end
    end

    describe "update_info" do
      it "properly handles update_info data" do
        json = <<-J
        {"id": "driver-HPfHrDuS_d_", "name": "Floorsense Desk Tracking (WS)", "role": 3, "commit": "01fad928c508f66d4444106d3b98ec98c19b8d8a", "file_name": "drivers/floorsense/desks_websocket.cr", "created_at": "2021-06-03T18:49:37+10:00", "updated_at": "2023-12-22T15:10:44.486961+11:00", "default_uri": "wss://_your_subdomain_.floorsense.com.au", "description": "", "json_schema": {}, "module_name": "Floorsense", "update_info": {"date": "2023-10-12T12:29:10+11:00", "author": "Stephen von Takach", "commit": "01fad928c508f66d4444106d3b98ec98c19b8d8a", "message": "feat(floorsense): improve error response"}, "default_port": 1, "repository_id": "repo-Fhwr6Ovf5z0", "ignore_connected": false, "update_available": true, "compilation_output": null}
        J
        Model::Driver.from_json(json).should_not be_nil
      end
    end
  end
end
