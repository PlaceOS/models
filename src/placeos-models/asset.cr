require "./base/model"
require "./asset_type"
require "./asset_purchase_order"

module PlaceOS::Model
  class Asset < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset

    attribute identifier : String?, es_type: "keyword"
    attribute serial_number : String?
    attribute other_data : JSON::Any?
    attribute barcode : String?

    belongs_to AssetType, foreign_key: "asset_type_id", association_name: "asset_type"
    belongs_to AssetPurchaseOrder, foreign_key: "purchase_order_id", association_name: "purchase_order"
    belongs_to Zone, foreign_key: "zone_id", association_name: "zone"

    # Validation
    ###############################################################################################

    validates :asset_type_id, presence: true
    validates :zone_id, presence: true

    before_destroy :cleanup_bookings

    # Reject any bookings that are current
    protected def cleanup_bookings
      current_time = Time.utc.to_unix

      Booking.where(
        %("booking_end" > ? AND asset_id = ?),
        current_time, self.id
      ).update_all({:rejected => true, :rejected_at => current_time, :approved => false})
    end
  end
end
