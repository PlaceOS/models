require "./helper"

module PlaceOS::Model
  Spec.before_each do
    EventMetadata.clear
  end

  describe EventMetadata do
    describe "event metadata querying" do
      it "looks up event metadata" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!

        EventMetadata.by_tenant(tenant.id).by_event_ids([event.event_id]).to_a.size.should eq 1
        EventMetadata.by_tenant(tenant.id).by_event_ids([event.ical_uid]).to_a.size.should eq 1
        EventMetadata.by_tenant(tenant.id).by_event_ids([event.event_id, event.ical_uid]).to_a.size.should eq 1

        # these two ids would only be queried seperately
        EventMetadata.by_tenant(tenant.id).by_master_ids([event.recurring_master_id]).to_a.size.should eq 1
        EventMetadata.by_tenant(tenant.id).by_master_ids([event.resource_master_id]).to_a.size.should eq 1

        EventMetadata.by_tenant(tenant.id).by_events_or_master_ids([event.resource_master_id, "1234", event.ical_uid], [event.resource_master_id, "1234", event.ical_uid]).to_a.size.should eq 1
      end
    end

    describe "event metadata permissions" do
      it "sets the permission field to PRIVATE by default" do
        tenant = get_tenant

        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!

        EventMetadata.by_tenant(tenant.id).to_a.first.permission.should eq EventMetadata::Permission::PRIVATE
      end
    end

    describe "history recording" do
      Spec.before_each do
        History.clear
      end

      it "records history when metadata fields are updated" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!

        # Should not record history for initial save
        History.all.to_a.size.should eq 0

        # Update a field
        event.setup_time = 300
        event.save!

        histories = History.all.to_a
        histories.size.should eq 1
        histories.first.type.should eq "event"
        histories.first.resource_id.should eq event.event_id
        histories.first.action.should eq "updated"
        histories.first.changed_fields.should contain "setup_time"
      end

      it "records multiple changed fields" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!

        # Update multiple fields
        event.setup_time = 300
        event.breakdown_time = 600
        event.cancelled = true
        event.save!

        histories = History.all.to_a
        histories.size.should eq 1
        histories.first.changed_fields.should contain "setup_time"
        histories.first.changed_fields.should contain "breakdown_time"
        histories.first.changed_fields.should contain "cancelled"
      end

      it "tracks ext_data changes at the field level" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!

        # Set ext_data
        event.set_ext_data(JSON.parse(%({"catering": true, "notes": "test"})))
        event.save!

        histories = History.all.to_a
        histories.size.should eq 1
        histories.first.changed_fields.should contain "ext_data.catering"
        histories.first.changed_fields.should contain "ext_data.notes"
      end

      it "does not record history when no fields changed" do
        tenant = get_tenant
        event_start = 5.minutes.from_now
        event_end = 10.minutes.from_now

        event = Generator.event_metadata(tenant.id, event_start, event_end)
        event.save!

        # Save without changes
        event.save!

        History.all.to_a.size.should eq 0
      end
    end
  end
end
