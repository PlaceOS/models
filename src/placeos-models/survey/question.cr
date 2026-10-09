module PlaceOS::Model
  class Survey < ModelWithAutoKey
    class Question < ModelWithAutoKey
      table :questions
      attribute title : String, sanitize: :text
      attribute description : String?, sanitize: :common
      attribute type : String
      attribute options : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
      attribute required : Bool = false
      attribute choices : JSON::Any = JSON::Any.new({} of String => JSON::Any), sanitize: :common
      attribute max_rating : Int32?
      attribute tags : Array(String) = [] of String, sanitize: :text
      attribute deleted_at : Int64?

      # the version of this question that it replaced, see `save!`
      attribute previous_question_id : Int64?

      attribute deleted : Bool, persistence: false, show: true, ignore_deserialize: true

      # NOTE: nilable at the DB level so existing questions can be adopted by an authority,
      # but required at the model level (see the presence validation below)
      belongs_to Authority, foreign_key: "authority_id"

      has_many(
        child_class: Survey::Answer,
        collection_name: "answers",
        foreign_key: "question_id",
        dependent: :destroy
      )

      # Changing what a question asks, once it has answers, saves it as a new version so existing
      # answers keep the question they were given against: the old version is soft deleted, the
      # new one records it in `previous_question_id` and the authority's surveys are repointed to
      # it. Other changes (title, description, options, tags) are made in place.
      def save!(**options)
        return super unless persisted? && versioned_change? && answered?

        ::PgORM::Database.transaction do
          previous_id = id.as(Int64)
          soft_delete
          clear_persisted
          self.previous_question_id = previous_id
          super
          repoint_surveys(previous_id, id.as(Int64))
        end
        self
      end

      # changes that alter the meaning of an answer
      def versioned_change? : Bool
        type_changed? || choices_changed? || max_rating_changed? || required_changed?
      end

      def answered? : Bool
        Survey::Answer.where(question_id: id).count > 0
      end

      # replaces the question id in the pages of the authority's surveys
      protected def repoint_surveys(from : Int64, to : Int64) : Nil
        Survey.where(authority_id: authority_id)
          .where("pages @> ?::jsonb", [{question_order: [from]}].to_json)
          .to_a.each do |survey|
          pages = survey.pages.map do |page|
            page.question_order = page.question_order.map { |question_id| question_id == from ? to : question_id }
            page
          end
          ::PgORM::Database.connection &.exec("UPDATE surveys SET pages = $1::jsonb WHERE id = $2", args: [pages.to_json, survey.id])
        end
      end

      # moves the answers of another version of this question to it, see `previous_question_id`
      def migrate_answers_from(question_id : Int64) : Nil
        Survey::Answer.where(question_id: question_id).update_all(question_id: id)
      end

      # runs on the current connection, so it takes part in any open transaction
      def soft_delete
        Question.where(id: id).update_all(deleted_at: Time.local.to_unix)
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

      validates :title, :type, :authority_id, presence: true

      # assigns questions created before questions belonged to an authority, skipping validation
      def self.adopt_unowned(authority_id : String) : Nil
        Question.where(authority_id: nil).update_all(authority_id: authority_id)
      end

      def self.list(survey_id : Int64? = nil, deleted : Bool? = nil, authority_id : String? = nil)
        query = Question.select("id, title, description, type, options, required, choices, max_rating, tags, deleted_at, previous_question_id, authority_id")
        query = query.where(authority_id: authority_id) if authority_id

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
