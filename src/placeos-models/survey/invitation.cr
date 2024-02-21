require "ulid"

module PlaceOS::Model
  class Survey < ModelWithAutoKey
    class Invitation < ModelWithAutoKey
      table :survey_invitations
      attribute token : String?
      attribute email : String?
      attribute sent : Bool?

      belongs_to Survey, pk_type: Int64, serialize: true

      before_create :generate_token

      def generate_token
        self.token = ULID.generate
      end

      validates :survey_id, :email, presence: true

      def self.list(survey_id : Int64? = nil, sent : Bool? = nil)
        query = Survey::Invitation.select("id, survey_id, token, email, sent")

        # filter
        query = query.where(survey_id: survey_id) if survey_id
        # can't use `query.where_not(sent: true)` here due to
        # `sent <> true` not being equivalent to `sent IS NOT true` in PostgreSQL
        query = sent ? query.where(sent: true) : query.where("sent IS NOT $1", true) unless sent.nil?
        query.to_a
      end

      def patch(changes : self)
        {% for key in [:survey_id, :email, :sent] %}
        begin
          self.{{key.id}} = changes.{{key.id}} if changes.{{key.id}}_present? || self.{{key.id}}.nil?
        rescue NilAssertionError
        end
      {% end %}
        save!
      end
    end
  end
end
