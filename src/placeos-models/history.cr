require "./base/model"

module PlaceOS::Model
  class History < ModelBase
    include PlaceOS::Model::Timestamps

    table :history

    attribute type : String, es_subfield: "keyword"
    attribute resource_id : String, es_subfield: "keyword"
    attribute action : String, es_subfield: "keyword"
    attribute changed_fields : Array(String) = [] of String, es_type: "keyword"

    # Validation
    ###############################################################################################

    validates :type, presence: true
    validates :resource_id, presence: true
    validates :action, presence: true
  end
end
