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
      end
    end
  end
end
