require "./helper"

module PlaceOS::Model
  describe TriggerInstance do
    test_round_trip(TriggerInstance)

    it "saves a TriggerInstance" do
      trigger = Generator.trigger.save!

      inst = Generator.trigger_instance(trigger).save!
      id = TriggerInstance.find!(inst.id.as(String)).id
      id.should eq inst.id
    end

    it "sets importance before create" do
      trigger = Generator.trigger
      trigger.important = true

      trigger_instance = Generator.trigger_instance(trigger.save!)

      trigger_instance.important.should be_false
      trigger_instance.save!
      trigger_instance.important.should be_true

      trigger.destroy
      trigger_instance.destroy
    end

    describe "start/stop helpers" do
      it "stop" do
        inst = Generator.trigger_instance.save!
        inst.enabled.should be_true
        inst.stop

        inst.enabled.should be_false
        TriggerInstance.find!(inst.id.as(String)).enabled.should be_false

        inst.destroy
      end

      it "start" do
        inst = Generator.trigger_instance
        inst.enabled = false
        inst.save!

        inst.enabled.should be_false
        inst.start
        inst.enabled.should be_true

        TriggerInstance.find!(inst.id.as(String)).enabled.should be_true
        inst.destroy
      end
    end

    describe "index view" do
      it "#of finds TriggerInstance by parent Trigger" do
        inst = Generator.trigger_instance.save!
        trigger = inst.trigger.as(Trigger)

        id = TriggerInstance.of(trigger.id.as(String)).first?.try(&.id)
        id.should eq inst.id
      end

      it "#for finds TriggerInstance by parent ControlSystem" do
        inst = Generator.trigger_instance.save!
        cs = inst.control_system.as(ControlSystem)

        id = TriggerInstance.for(cs.id.as(String)).first?.try(&.id)
        id.should eq inst.id
      end
    end
  end
end
