require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Survey::Question.clear
  end

  describe Survey::Question do
    test_round_trip(Survey::Question)

    it "saves a question" do
      question = Generator.question.save!

      question.should_not be_nil
      question.persisted?.should be_true
      Survey::Question.find!(question.id).id.should eq question.id
    end
  end
end
