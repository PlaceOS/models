require "./helper"

module PlaceOS::Model
  describe History do
    Spec.before_each do
      History.clear
      History.cleanup_interval = nil
    end

    Spec.after_each do
      History.retention = 30.days
      History.max_entries = 250
      History.min_entries = 5
      History.cleanup_interval = 1.hour
    end

    it "saves a History entry" do
      history = Generator.history.save!

      history.persisted?.should be_true
      history.id.should be_a(UUID)

      found = History.find!(history.id.as(UUID))
      found.resource_type.should eq history.resource_type
      found.resource_id.should eq history.resource_id
      found.action.should eq history.action
      found.changed_fields.should eq ["name"]
      found.diff["name"].should eq JSON.parse(%(["old", "new"]))
    end

    it "requires resource_type, resource_id and action" do
      history = History.new(resource_type: "", resource_id: "", action: "")
      history.valid?.should be_false
      history.errors.map(&.field).sort!.should eq [:action, :resource_id, :resource_type]
    end

    it "queries entries of a resource and correlated entries, newest first" do
      older = Generator.history(resource_id: "zone-1", correlation_id: "group-1", created_at: 2.minutes.ago).save!
      newer = Generator.history(resource_id: "zone-1", created_at: 1.minute.ago).save!
      other = Generator.history(resource_id: "zone-2", correlation_id: "group-1").save!

      History.for_resource("zone", "zone-1").to_a.map(&.id).should eq [newer.id, older.id]
      History.correlated("group-1").to_a.map(&.id).should eq [other.id, older.id]
    end

    describe History::Tracked do
      it "records creates with every field set" do
        zone = Generator.zone
        zone.description = "a zone"
        zone.save!

        entries = zone.change_history.to_a
        entries.size.should eq 1
        entry = entries.first
        entry.action.should eq "create"
        entry.resource_type.should eq "zone"
        entry.resource_id.should eq zone.id
        entry.diff["name"].should eq JSON::Any.new([JSON::Any.new(nil), JSON::Any.new(zone.name)])
        entry.diff["description"][1].should eq "a zone"
        entry.changed_fields.should_not contain "created_at"
        entry.snapshot.try(&.raw).should be_nil
      end

      it "records previous and current values of updates" do
        zone = Generator.zone.save!
        previous_name = zone.name

        zone.name = "renamed"
        zone.save!

        entries = zone.change_history.to_a
        entries.map(&.action).should eq ["update", "create"]
        entries.first.changed_fields.should eq ["name"]
        entries.first.diff.should eq JSON.parse({"name" => [previous_name, "renamed"]}.to_json)
        Zone.change_history(zone.id.as(String)).count.should eq 2
      end

      it "does not record saves without changes or with only ignored changes" do
        system = Generator.control_system.save!
        system.save!
        system.signage_last_seen = Time.utc
        system.save!

        system.change_history.to_a.map(&.action).should eq ["create"]
      end

      it "records the values written, after other callbacks have run" do
        invitation = Generator.group_invitation(email: "  Someone@Example.COM ").save!

        entry = invitation.change_history.to_a.first
        entry.diff["email"][1].should eq "someone@example.com"
      end

      it "redacts sensitive fields" do
        user = Generator.user
        user.password = "secret password"
        user.save!

        entry = user.change_history.to_a.first
        entry.diff["password_digest"].should eq JSON.parse(%(["[REDACTED]", "[REDACTED]"]))
        entry.diff.to_json.should_not contain(user.password_digest.not_nil!)

        user.destroy
        snapshot = user.change_history.to_a.first.snapshot.not_nil!
        snapshot.as_h.has_key?("password_digest").should be_false
        snapshot["email"].should eq user.email.to_s
      end

      it "records deletes with a snapshot" do
        zone = Generator.zone.save!
        zone.destroy

        entry = zone.change_history.to_a.first
        entry.action.should eq "delete"
        entry.diff.as_h.should be_empty
        entry.snapshot.not_nil!["name"].should eq zone.name
      end

      it "records composite keys and correlation ids" do
        group_zone = Generator.group_zone.save!
        group_zone.permissions = Permissions::All.to_i
        group_zone.save!

        entries = History.correlated(group_zone.group_id.to_s).where(resource_type: "group_zones").to_a
        entries.size.should eq 2
        entries.first.resource_id.should eq "#{group_zone.group_id}:#{group_zone.zone_id}"
        entries.first.changed_fields.should eq ["permissions"]
      end

      it "is rolled back with the change" do
        zone = Generator.zone
        expect_raises(Exception, "rollback") do
          ::PgORM::Database.transaction do
            zone.save!
            raise "rollback"
          end
        end

        History.count.should eq 0
      end

      it "records approvals only for playlist revisions" do
        revision = Generator.revision
        revision.save!
        revision.items = ["playlist-item-1"]
        revision.save!
        revision.change_history.count.should eq 0

        approver = Generator.user.save!
        revision.approver = approver
        revision.save!

        entries = revision.change_history.to_a
        entries.size.should eq 1
        entries.first.action.should eq "approve"
        entries.first.correlation_id.should eq revision.playlist_id
        entries.first.snapshot.not_nil!["approved_by_id"].should eq approver.id

        History.correlated(revision.playlist_id.not_nil!).count.should eq 1
      end

      it "records booking changes" do
        tenant = get_tenant
        booking = Generator.booking(tenant.id, "desk-1", 1.hour.from_now, 2.hours.from_now)
        booking.save!
        booking.checked_in = true
        booking.save!

        entries = History.for_resource("bookings", booking.id.to_s).to_a
        entries.map(&.action).should eq ["update", "create"]
        entries.first.diff["checked_in"].should eq JSON.parse("[false, true]")
        entries.first.changed_fields.should_not contain "history"
      end

      describe "metadata" do
        it "records the fiber's metadata, including cascading changes" do
          user = Generator.user.save!
          metadata = History::Metadata.new(app_name: "backoffice", ip: "10.0.0.1").with_user(user)

          zone = Generator.zone
          other = Generator.zone
          History.with_metadata(metadata) do
            zone.save!
            other.save!
          end
          History.current_metadata.should be_nil

          [zone, other].each do |record|
            entry = record.change_history.to_a.first
            entry.user_id.should eq user.id
            entry.user_email.should eq user.email.to_s
            entry.metadata.app_name.should eq "backoffice"
            entry.metadata.ip.should eq "10.0.0.1"
            entry.metadata.user_name.should eq user.name
          end
        end

        it "prefers the record's metadata and restores nested metadata" do
          outer = History::Metadata.new(app_name: "outer")
          inner = History::Metadata.new(app_name: "inner")
          own = History::Metadata.new(app_name: "own")

          zone = Generator.zone
          own_zone = Generator.zone
          own_zone.history_metadata = own

          History.with_metadata(outer) do
            History.with_metadata(inner) { zone.save! }
            History.current_metadata.should eq outer
            own_zone.save!
          end

          zone.change_history.to_a.first.metadata.app_name.should eq "inner"
          own_zone.change_history.to_a.first.metadata.app_name.should eq "own"
        end

        it "builds metadata from a provider only when a change is recorded" do
          calls = 0
          app_name = "before"
          provider = History::MetadataProvider.new do
            calls += 1
            History::Metadata.new(app_name: app_name)
          end

          zone = Generator.zone
          History.with_metadata(provider) do
            History.with_metadata(History::Metadata.new(app_name: "inner")) { }
            calls.should eq 0

            app_name = "after"
            zone.save!
            Zone.find!(zone.id.as(String))
          end
          History.current_metadata.should be_nil

          calls.should eq 1
          zone.change_history.to_a.first.metadata.app_name.should eq "after"
        end

        it "records changes without metadata" do
          zone = Generator.zone.save!
          entry = zone.change_history.to_a.first
          entry.user_id.should be_nil
          entry.context.as_h.should be_empty
        end
      end

      describe ".undelete" do
        it "restores a deleted record with its id" do
          zone = Generator.zone
          zone.description = "restore me"
          zone.save!
          zone.destroy
          Zone.find?(zone.id.as(String)).should be_nil

          restored = Zone.undelete(zone.id.as(String))
          restored.id.should eq zone.id

          found = Zone.find!(zone.id.as(String))
          found.name.should eq zone.name
          found.description.should eq "restore me"

          zone.change_history.to_a.map(&.action).should eq ["restore", "delete", "create"]
        end

        it "raises when there is nothing to restore" do
          expect_raises(::PgORM::Error::RecordNotFound) do
            Zone.undelete("zone-missing")
          end
        end

        it "raises when the record already exists" do
          zone = Generator.zone.save!
          zone.destroy
          Zone.undelete(zone.id.as(String))

          expect_raises(::PgORM::Error) do
            Zone.undelete(zone.id.as(String))
          end
        end
      end
    end

    describe "retention" do
      it "keeps at most max_entries per resource" do
        History.max_entries = 3
        zone = Generator.zone.save!
        4.times do |index|
          zone.name = "name #{index}"
          zone.save!
        end

        entries = zone.change_history.to_a
        entries.size.should eq 3
        entries.first.diff["name"][1].should eq "name 3"
      end

      it "removes entries older than retention beyond min_entries" do
        History.min_entries = 2
        zone = Generator.zone.save!
        3.times do |index|
          Generator.history(resource_id: zone.id.as(String), created_at: (40 + index).days.ago).save!
        end

        zone.name = "renamed"
        zone.save!

        entries = zone.change_history.to_a
        entries.size.should eq 2
        entries.first.action.should eq "update"
        entries.last.action.should eq "create"
      end

      it "keeps min_entries of old resources" do
        History.min_entries = 2
        4.times do |index|
          Generator.history(resource_id: "zone-old", created_at: (40 + index).days.ago).save!
        end
        Generator.history(resource_id: "zone-new").save!

        History.cleanup_expired.should eq 2
        History.for_resource("zone", "zone-old").count.should eq 2
        History.for_resource("zone", "zone-new").count.should eq 1
      end

      it "removes every entry once a deletion has expired" do
        Generator.history(resource_id: "zone-gone", created_at: 50.days.ago).save!
        Generator.history(resource_id: "zone-gone", action: "delete", created_at: 40.days.ago).save!
        Generator.history(resource_id: "zone-recent", created_at: 50.days.ago).save!
        Generator.history(resource_id: "zone-recent", action: "delete", created_at: 1.day.ago).save!

        History.cleanup_expired.should eq 2
        History.for_resource("zone", "zone-gone").count.should eq 0
        History.for_resource("zone", "zone-recent").count.should eq 2
      end

      it "cleans up in batches" do
        History.min_entries = 0
        3.times { Generator.history(created_at: 40.days.ago).save! }

        History.cleanup_expired(2).should eq 2
        History.cleanup_expired(2).should eq 1
        History.count.should eq 0
      end

      it "cleans up periodically as changes are recorded" do
        Generator.history(resource_id: "zone-gone", action: "delete", created_at: 40.days.ago).save!
        History.cleanup_interval = Time::Span.zero

        Generator.zone.save!
        History.for_resource("zone", "zone-gone").count.should eq 0
      end
    end
  end
end
