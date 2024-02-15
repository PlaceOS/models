require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Survey.clear
  end

  describe Survey do
    test_round_trip(Survey)

    it "saves a Survey" do
      survey = Generator.survey.save!

      survey.should_not be_nil
      survey.persisted?.should be_true
      Survey.find!(survey.id).id.should eq survey.id
    end
  end
end
