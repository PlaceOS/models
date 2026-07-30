require "./helper"

module PlaceOS::Model
  # `booking_instances.extension_data` is a complete snapshot when present.
  # An occurrence only inherits from the parent while it has no non-empty object
  # stored; once extension data is explicitly changed, later series edits must
  # not alter that occurrence's snapshot.
  describe BookingInstance do
    timezone = Time::Location.load("Australia/Perth")
    start_time = Time.local(2020, 1, 10, 7, 0, 0, location: timezone)
    end_time = start_time + 10.hours + 30.minutes
    start_query = Time.local(2020, 1, 5, 5, 0, 0, location: timezone)
    end_query = Time.local(2020, 1, 13, 5, 0, 0, location: timezone)

    series_data = JSON.parse(%({
      "location": "Test Street",
      "plate_number": "testplate1",
      "vehicle_type": "motorcycle"
    }))

    booking = uninitialized Booking

    before_each do
      Booking.clear
      BookingInstance.clear
      Tenant.clear

      booking = Generator.booking(
        1_i64,
        asset_id: "unallocated-1234",
        start: start_time,
        ending: end_time
      )
      booking.timezone = "Australia/Perth"
      booking.recurrence_type = :daily
      booking.recurrence_days = 0b1111111
      booking.tenant_id = Generator.tenant(domain: "instance-ext-data.dev").id
      booking.change_extension_data(series_data)
      booking.save!
    end

    it "inherits the series' extension data when the instance sets none" do
      times = booking.calculate_daily(start_query, end_query).instances

      instance = booking.to_instance(times[1].to_unix)
      instance.asset_id = "parking-bay-7"
      instance.skip_clash_check = true
      instance.save!

      reloaded = BookingInstance.find_one_by_sql?(<<-SQL, booking.id, times[1].to_unix).not_nil!
        SELECT i.* FROM "booking_instances" i WHERE i.id = $1 AND i.instance_start = $2 LIMIT 1
      SQL

      hydrated = reloaded.hydrate_booking(booking)
      hydrated.asset_id.should eq "parking-bay-7"
      hydrated.extension_data.as_h["plate_number"].should eq JSON::Any.new("testplate1")
      hydrated.extension_data.as_h["location"].should eq JSON::Any.new("Test Street")
    end

    it "treats an empty override as no override at all" do
      times = booking.calculate_daily(start_query, end_query).instances

      instance = booking.to_instance(times[1].to_unix)
      instance.extension_data = JSON::Any.new(Hash(String, JSON::Any).new)
      instance.skip_clash_check = true
      instance.save!

      reloaded = BookingInstance.find_one_by_sql?(<<-SQL, booking.id, times[1].to_unix).not_nil!
        SELECT i.* FROM "booking_instances" i WHERE i.id = $1 AND i.instance_start = $2 LIMIT 1
      SQL

      hydrated = reloaded.hydrate_booking(booking)
      hydrated.extension_data.as_h["plate_number"].should eq JSON::Any.new("testplate1")
    end

    it "rejects non-object extension data" do
      times = booking.calculate_daily(start_query, end_query).instances

      instance = booking.to_instance(times[1].to_unix)
      instance.extension_data = JSON.parse(%(["not", "an", "object"]))
      instance.skip_clash_check = true

      instance.save.should be_false
      instance.errors.map(&.field).should contain(:extension_data)
    end

    it "uses a non-empty instance value as the complete extension-data snapshot" do
      times = booking.calculate_daily(start_query, end_query).instances

      instance = booking.to_instance(times[1].to_unix)
      instance.extension_data = JSON.parse(%({
        "location": "Snapshot Street",
        "plate_number": "testplate2"
      }))
      instance.skip_clash_check = true
      instance.save!

      reloaded = BookingInstance.find_one_by_sql?(<<-SQL, booking.id, times[1].to_unix).not_nil!
        SELECT i.* FROM "booking_instances" i WHERE i.id = $1 AND i.instance_start = $2 LIMIT 1
      SQL

      hydrated = reloaded.hydrate_booking(booking)
      hydrated.extension_data.as_h["plate_number"].should eq JSON::Any.new("testplate2")
      hydrated.extension_data.as_h["location"].should eq JSON::Any.new("Snapshot Street")
      hydrated.extension_data.as_h.has_key?("vehicle_type").should be_false
    end

    it "keeps its snapshot when the series extension data changes later" do
      times = booking.calculate_daily(start_query, end_query).instances

      instance = booking.to_instance(times[1].to_unix)
      instance.extension_data = JSON.parse(%({
        "location": "Snapshot Street",
        "plate_number": "testplate2"
      }))
      instance.skip_clash_check = true
      instance.save!

      # the series' extension data changes after the override was stored
      booking.change_extension_data(JSON.parse(%({
        "location": "Second Street",
        "plate_number": "testplate1",
        "vehicle_type": "motorcycle"
      })))
      booking.save!

      hydrated = BookingInstance.find_one_by_sql?(<<-SQL, booking.id, times[1].to_unix).not_nil!.hydrate_booking(booking.reload!)
        SELECT i.* FROM "booking_instances" i WHERE i.id = $1 AND i.instance_start = $2 LIMIT 1
      SQL

      hydrated.extension_data.as_h["location"].should eq JSON::Any.new("Snapshot Street")
      hydrated.extension_data.as_h["plate_number"].should eq JSON::Any.new("testplate2")
      hydrated.extension_data.as_h.has_key?("vehicle_type").should be_false
    end

    it "does not mutate the parent booking's extension data while hydrating" do
      times = booking.calculate_daily(start_query, end_query).instances

      instance = booking.to_instance(times[1].to_unix)
      instance.extension_data = JSON.parse(%({"plate_number": "testplate2"}))
      instance.skip_clash_check = true
      instance.save!

      instance.hydrate_booking(booking)
      booking.extension_data.as_h["plate_number"].should eq JSON::Any.new("testplate1")
    end
  end
end
