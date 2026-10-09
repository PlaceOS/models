require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Survey::Question.clear
  end

  describe Survey::Question do
    test_round_trip(Survey::Question)

    # a survey using the question, with an answer to it
    answered = ->(question : Survey::Question) do
      survey = Generator.survey(pages: [Generator.page(question_order: [question.id.as(Int64)])]).save!
      Survey::Answer.new(question_id: question.id, survey_id: survey.id, type: question.type, answer_json: JSON.parse(%({"text": "yes"}))).save!
      survey
    end

    it "saves a question" do
      question = Generator.question.save!

      question.should_not be_nil
      question.persisted?.should be_true
      Survey::Question.find!(question.id).id.should eq question.id
    end

    it "requires an authority" do
      question = Generator.question
      question.authority_id = nil
      question.valid?.should be_false
      question.errors.map(&.field).should contain(:authority_id)
    end

    it "lists its answers" do
      question = Generator.question.save!
      answered.call(question)
      question.answers.to_a.size.should eq 1
    end

    describe "versioning" do
      it "edits in place when the change doesn't alter what is asked" do
        question = Generator.question.save!
        answered.call(question)
        original_id = question.id

        question.title = "Better wording"
        question.tags = ["tidy"]
        question.save!

        question.id.should eq original_id
        question.previous_question_id.should be_nil
        Survey::Question.find!(original_id).deleted_at.should be_nil
        Survey::Answer.where(question_id: original_id).count.should eq 1
      end

      it "edits in place when the question has no answers" do
        question = Generator.question.save!
        original_id = question.id

        question.choices = JSON.parse(%([{"title": "Red"}]))
        question.save!
        question.id.should eq original_id
      end

      it "creates a new version when an answered question's meaning changes" do
        question = Generator.question.save!
        survey = answered.call(question)
        old_id = question.id.as(Int64)

        question.choices = JSON.parse(%([{"title": "Red"}, {"title": "Blue"}]))
        question.save!
        new_id = question.id.as(Int64)

        new_id.should_not eq old_id
        question.previous_question_id.should eq old_id
        Survey::Question.find!(old_id).deleted_at.should_not be_nil
        Survey::Question.find!(new_id).deleted_at.should be_nil
        # answers keep the version they were given against
        Survey::Answer.where(question_id: old_id).count.should eq 1
        Survey::Answer.where(question_id: new_id).count.should eq 0
        # the authority's surveys use the new version
        Survey.find!(survey.id).question_ids.should eq [new_id]
      end

      it "only repoints surveys of the question's authority" do
        question = Generator.question.save!
        answered.call(question)
        other = Generator.authority(domain: "question-other-#{RANDOM.hex(4)}.dev").save!
        old_id = question.id.as(Int64)
        theirs = Generator.survey(authority: other, pages: [Generator.page(question_order: [old_id])]).save!

        question.required = true
        question.save!

        Survey.find!(theirs.id).question_ids.should eq [old_id]
      end

      it "leaves the old version untouched when the new one is invalid" do
        question = Generator.question.save!
        survey = answered.call(question)
        old_id = question.id.as(Int64)

        question.type = "rating"
        question.title = ""
        expect_raises(PgORM::Error::RecordInvalid) { question.save! }

        Survey::Question.find!(old_id).deleted_at.should be_nil
        Survey::Question.where(previous_question_id: old_id).count.should eq 0
        Survey.find!(survey.id).question_ids.should eq [old_id]
      end

      it "can move the previous version's answers to the new version" do
        question = Generator.question.save!
        answered.call(question)
        old_id = question.id.as(Int64)

        question.max_rating = 10
        question.save!
        question.migrate_answers_from(old_id)

        Survey::Answer.where(question_id: question.id).count.should eq 1
        Survey::Answer.where(question_id: old_id).count.should eq 0
      end
    end

    describe "foreign keys" do
      it "is deleted, with its answers, when its authority is deleted" do
        authority = Generator.authority(domain: "question-cascade-#{RANDOM.hex(4)}.dev").save!
        question = Generator.question(authority: authority).save!
        survey = Generator.survey(authority: authority, pages: [Generator.page(question_order: [question.id.as(Int64)])]).save!
        answer = Survey::Answer.new(question_id: question.id, survey_id: survey.id, type: "text", answer_json: JSON.parse(%({"text": "yes"}))).save!

        authority.delete
        Survey::Question.find?(question.id).should be_nil
        Survey::Answer.find?(answer.id).should be_nil
      end

      it "clears previous_question_id when the previous version is deleted" do
        first = Generator.question.save!
        second = Generator.question.tap(&.previous_question_id = first.id).save!

        first.delete
        Survey::Question.find!(second.id).previous_question_id.should be_nil
      end
    end

    it "adopts questions that have no authority" do
      question = Generator.question.save!
      Survey::Question.where(id: question.id).update_all(authority_id: nil)

      authority_id = Generator.localhost_authority.id.as(String)
      Survey::Question.adopt_unowned(authority_id)
      Survey::Question.find!(question.id).authority_id.should eq authority_id
    end

    it "lists the questions of an authority" do
      mine = Generator.question.save!
      other = Generator.authority(domain: "question-list-#{RANDOM.hex(4)}.dev").save!
      Generator.question(authority: other).save!

      Survey::Question.list(authority_id: mine.authority_id).map(&.id).should eq [mine.id]
    end
  end
end
