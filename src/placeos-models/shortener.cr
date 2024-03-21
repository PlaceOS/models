require "./base/model"

module PlaceOS::Model
  class Shortener < ModelBase
    include PlaceOS::Model::Timestamps

    table :shortener

    attribute name : String, es_subfield: "keyword"
    attribute uri : String
    attribute description : String = ""

    attribute user_id : String
    attribute user_email : PlaceOS::Model::Email, format: "email", converter: PlaceOS::Model::EmailConverter
    attribute user_name : String

    attribute redirect_count : Int64 = 0
    attribute enabled : Bool = true

    attribute valid_from : Time? = nil, converter: Time::EpochConverter
    attribute valid_until : Time? = nil, converter: Time::EpochConverter

    belongs_to Authority

    def user=(user)
      self.user_id = user.id.as(String)
      self.user_email = user.email
      self.user_name = user.name
    end

    def perform_redirect? : Bool
      now = Time.utc
      v_from = self.valid_from
      v_until = self.valid_until
      return false if v_from && v_from > now
      return false if v_until && v_until <= now
      enabled
    end

    def increment_redirect_count : Nil
      count = @redirect_count || 0_i64
      @redirect_count = count + 1_i64
      short_id = self.id.as(String)
      PgORM::Database.exec_sql(%(UPDATE shortener SET redirect_count = redirect_count + 1 WHERE id = '#{short_id}'))
    rescue error
      Log.warn(exception: error) { "failed to increment short url redirect_count for #{self.id}" }
    end

    # Callbacks
    ###############################################################################################

    TIME_OFFSET = Time.utc(2024, 3, 1).to_unix

    before_create :short_id

    protected def short_id
      self.new_record = true
      time = Time.utc.to_unix - TIME_OFFSET
      @id = "uri-#{time.to_s(62)}"
    end

    # Validation
    ###############################################################################################

    validates :uri, presence: true
    validates :name, presence: true
    validates :user_id, presence: true
    validates :user_name, presence: true
  end
end
