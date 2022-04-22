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

    describe "callbacks" do
      it "#cleanup_modules removes driver modules" do
        mod = Generator.module.save!
        driver = mod.driver!

        driver.persisted?.should be_true
        mod.persisted?.should be_true

        Module.by_driver_id(driver.id.as(String)).first.id.should eq mod.id
        driver.destroy
        Module.find(mod.id.as(String)).should be_nil
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
  end
end
