require "./base/model"

module PlaceOS::Model
  class Client < ModelBase
    include PlaceOS::Model::Timestamps
    table :clients

    attribute name : String
    attribute description : String? = nil
    attribute billing_address : String? = nil
    attribute billing_contact : String? = nil
    attribute is_management : Bool = false
    attribute config : JSON::Any? = nil

    has_many(
      child_class: Authority,
      foreign_key: "client_id",
      collection_name: :authorities
    )

    has_many(
      child_class: ControlSystem,
      foreign_key: "client_id",
      collection_name: :systems
    )

    has_many(
      child_class: Module,
      foreign_key: "client_id",
      collection_name: :modules
    )

    has_many(
      child_class: Zone,
      foreign_key: "client_id",
      collection_name: :zones
    )

    validates :name, presence: true
  end
end
