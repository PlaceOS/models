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

    it "lists invitations" do
      invitation_one = Generator.invitation(sent: true).save!
      invitation_two = Generator.invitation(sent: false).save!
      invitation_three = Generator.invitation(sent: nil).save!

      surveys = Survey::Invitation.list(sent: nil)
      surveys.size.should eq 3
      surveys.map(&:id).should contain(invitation_one.id)
      surveys.map(&:id).should contain(invitation_two.id)
      surveys.map(&:id).should contain(invitation_three.id)
    end

    it "lists invitations with sent = true" do
      invitation_one = Generator.invitation(sent: true).save!
      invitation_two = Generator.invitation(sent: false).save!
      invitation_three = Generator.invitation(sent: nil).save!

      surveys = Survey::Invitation.list(sent: true)
      surveys.size.should eq 1
      surveys.first.id.should eq invitation_one.id
    end

    it "lists invitations with sent != true" do
      invitation_one = Generator.invitation(sent: true).save!
      invitation_two = Generator.invitation(sent: false).save!
      invitation_three = Generator.invitation(sent: nil).save!

      surveys = Survey::Invitation.list(sent: false)
      surveys.size.should eq 2
      surveys.map(&:id).should contain(invitation_two.id)
      surveys.map(&:id).should contain(invitation_three.id)
    end
  end
end
