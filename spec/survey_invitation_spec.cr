require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Survey::Invitation.clear
  end

  describe Survey::Invitation do
    test_round_trip(Survey::Invitation)

    it "saves an invitation" do
      invitation = Generator.invitation.save!

      invitation.should_not be_nil
      invitation.persisted?.should be_true
      Survey::Invitation.find!(invitation.id).id.should eq invitation.id
    end
  end
end
