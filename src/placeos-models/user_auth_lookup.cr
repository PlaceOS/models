require "./base/model"
require "./authority"
require "./user"

module PlaceOS::Model
  class UserAuthLookup < ModelBase
    include PgORM::Timestamps

    table :authentication

    attribute uid : String
    attribute provider : String

    # Association
    ###############################################################################################
    attribute user_id : String?
    attribute authority_id : String?

    belongs_to User
    belongs_to Authority

    # Callbacks
    ###############################################################################################

    before_create :generate_id

    protected def generate_id
      self.new_record = true
      self.id = "auth-#{self.authority_id}-#{self.provider}-#{self.uid}"
    end
  end
end
