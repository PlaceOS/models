require "./base/model"
require "./asset_type"
require "./asset_purchase_order"
require "./utilities/sanitization"

module PlaceOS::Model
  class Asset < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset

    attribute identifier : String?, es_type: "keyword"
    attribute serial_number : String?
    attribute other_data : JSON::Any?
    attribute barcode : String?

    attribute name : String?, sanitize: :text
    attribute client_ids : JSON::Any? # {floorsense_id: "", other_id: ""} etc
    attribute map_id : String?
    attribute bookable : Bool = true
    attribute accessible : Bool = false
    attribute zones : Array(String) = [] of String, es_type: "keyword"
    attribute place_groups : Array(String) = [] of String, es_type: "keyword"
    attribute assigned_to : String?                    # email
    attribute assigned_name : String?, sanitize: :text # name of user
    # queryable with AND and OR operators
    attribute features : Array(String) = [] of String, es_type: "keyword"
    attribute images : Array(String) = [] of String, es_type: "keyword"
    attribute notes : String?, sanitize: :common # email
    attribute security_system_groups : Array(String) = [] of String, es_type: "keyword"

    # attribute parent_id : String? # nested resource like lockers and locker banks
    belongs_to Asset, foreign_key: "parent_id", association_name: "parent"

    belongs_to AssetType, foreign_key: "asset_type_id", association_name: "asset_type"
    belongs_to AssetPurchaseOrder, foreign_key: "purchase_order_id", association_name: "purchase_order"
    belongs_to Zone, foreign_key: "zone_id", association_name: "zone"

    # Validation
    ###############################################################################################

    validates :asset_type_id, presence: true
    validates :zone_id, presence: true

    before_save do
      if (data = @other_data) && @other_data_changed
        @other_data = Sanitization.sanitize_strings(data)
      end
      if (feat = @features) && @features_changed
        @features = Sanitization.sanitize_strings(feat)
      end
    end

    before_destroy :cleanup_bookings

    # Reject any bookings that are current
    protected def cleanup_bookings
      current_time = Time.utc.to_unix

      Booking.where(
        %("booking_end" > ? AND '#{self.id}'=ANY(asset_ids)),
        current_time
      ).update_all({:rejected => true, :rejected_at => current_time, :approved => false})
    end
  end
end
