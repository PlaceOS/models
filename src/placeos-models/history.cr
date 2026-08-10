require "./base/model"

module PlaceOS::Model
  class History < ModelBase
    include PlaceOS::Model::Timestamps

    table :history

    attribute type : String
    attribute resource_id : String
    attribute action : String
    attribute changed_fields : Array(String) = [] of String

    # Validation
    ###############################################################################################

    validates :type, presence: true
    validates :resource_id, presence: true
    validates :action, presence: true
  end
end
