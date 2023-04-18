module PlaceOS::Model
  class Survey < ModelWithAutoKey
    class Question < ModelWithAutoKey
      table :questions
      attribute title : String
      attribute description : String?
      attribute type : String
      attribute options : JSON::Any = JSON::Any.new({} of String => JSON::Any)
      attribute required : Bool = false
      attribute choices : JSON::Any = JSON::Any.new({} of String => JSON::Any)
      attribute max_rating : Int32?
      attribute tags : Array(String) = [] of String
      attribute deleted_at : Int64?

      attribute deleted : Bool, persistence: false, show: true, ignore_deserialize: true

      has_many(
        child_class: Survey::Answer,
        collection_name: "answers",
        foreign_key: "answer_id",
        dependent: :destroy
      )

      def save!(**options)
        # If the question is in the database and has answers, we need to insert a new question and soft delete the old one
        if persisted? && Survey::Answer.where(question_id: id).count > 0
          soft_delete
          clear_persisted
        end
        super
      end

      def soft_delete
        PgORM::Database.exec_sql("UPDATE questions SET deleted_at = $1 WHERE id = $2", Time.local.to_unix, self.id)
      end

      def maybe_soft_delete
        # Check if the question has any answers or is used in any surveys
        if Survey::Answer.where(question_id: id).count > 0 || Survey.where(%(pages @> '[{"question_order": [#{self.id}]}]')).count > 0
          soft_delete
        else
          delete
        end
      end

      def clear_persisted
        self.new_record = true
        @id = nil
        @deleted_at = nil
      end

      validates :title, :type, presence: true

      def self.list(survey_id : Int64? = nil, deleted : Bool? = nil)
        query = Question.select("id, title, description, type, options, required, choices, max_rating, tags, deleted_at")

        # filter
        if survey_id
          question_ids = Survey.find(survey_id).question_ids
          query = query.where(id: question_ids)
        end
        query = deleted ? query.where_not({:deleted_at => nil}) : query.where({:deleted_at => nil}) unless deleted.nil?
        query.to_a
      end

      def patch(changes : self)
        {% for key in [:title, :description, :type, :options, :required, :choices, :max_rating, :tags] %}
        begin
          self.{{key.id}} = changes.{{key.id}} if changes.{{key.id}}_present? || self.{{key.id}}.nil?
        rescue NilAssertionError
        end
        {% end %}
        save!
      end

      def self.required_question_ids(survey_id : Int64)
        all_survey_questions = Survey.find(survey_id).question_ids
        Question.select("id")
          .where(id: all_survey_questions)
          .where(required: true)
          .to_a.map(&.id)
      end

      def to_json(json : ::JSON::Builder)
        @deleted = !deleted_at.nil?
        super
      end
    end
  end
end
