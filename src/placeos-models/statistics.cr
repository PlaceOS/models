require "time"
require "./base/model"

module PlaceOS::Model
  class Statistics < ModelBase
    include PlaceOS::Model::Timestamps

    table :stats

    attribute modules_disconnected : Int32 = 0
    attribute triggers_active : Int32 = 0
    attribute websocket_connections : Int32 = 0
    attribute fixed_connections : Int32 = 0
    attribute core_nodes_online : Int32 = 0

    # The time at which this object should be destroyed
    attribute ttl : Int64 = 30.days.from_now.to_unix
  end
end
