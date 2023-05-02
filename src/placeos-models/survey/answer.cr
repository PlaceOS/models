module PlaceOS::Model
  class Survey < ModelWithAutoKey
    class Answer < ModelWithAutoKey
      table :answers
      attribute type : String
      attribute answer_json : JSON::Any = JSON::Any.new({} of String => JSON::Any)

      belongs_to Survey::Question, foreign_key: "question_id", pk_type: Int64, serialize: true
      belongs_to Survey, pk_type: Int64, serialize: true

      validates :question_id, :survey_id, :type, presence: true

      def self.list(survey_id : Int64? = nil, created_after : Int64? = nil, created_before : Int64? = nil)
        query = Answer.select("id, question_id, survey_id, type, answer_json")
        # filter
        query = query.where(survey_id: survey_id) if survey_id
        after_time = created_after ? Time.unix(created_after) : Time.unix(0)
        before_time = created_before ? Time.unix(created_before) : Time.local
        query = query.where("created_at between ? and ?", after_time.to_local, before_time.to_local)

        query.to_a
      end
    end
  end
end
