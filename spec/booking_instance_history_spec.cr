require "./helper"

module PlaceOS::Model
  describe BookingInstance do
    describe "history" do
      # NOTE:: these must be in the *future*. The state machine is time relative, so
      # the fixed 2020 dates used by the sibling instance specs would resolve every
      # occurrence to `ended` / `no_show` and never exercise a check-in transition.
      timezone = Time::Location.load("Europe/Berlin")
      now = Time.local(timezone)
      start_time = (now + 2.days).at_beginning_of_hour
      end_time = start_time + 1.hour
      start_query = now + 1.day
      end_query = now + 6.days

      booking = Generator.booking(1_i64, asset_id: "desk-1234", start: start_time, ending: end_time)

      Spec.before_each do
        Survey::Invitation.clear
        Survey.clear
        Booking.clear
        Tenant.clear
        booking = Generator.booking(
          1_i64,
          asset_id: "desk-1234",
          start: start_time,
          ending: end_time
        )
        booking.timezone = "Europe/Berlin"
        booking.recurrence_type = :daily
        booking.recurrence_days = 0b1111111
      end

      # an occurrence far enough in the future that it is still "reserved" unless
      # we explicitly check it in
      it "records the utm_source against the checked_in entry" do
        booking.tenant_id = Generator.tenant(domain: "recurrence-history.dev").id
        booking.save!
        times = booking.calculate_daily(start_query, end_query).instances
        instance_start = times[1].to_unix

        instance = booking.to_instance(instance_start)
        instance.checked_in = true
        instance.checked_in_at = instance_start - 60_i64
        instance.utm_source = "mobile"
        instance.save!

        reloaded = BookingInstance
          .where(id: booking.id.as(Int64), instance_start: instance_start)
          .first

        reloaded.history.size.should eq 1
        reloaded.history.last.state.should eq Booking::State::CheckedIn
        reloaded.history.last.source.should eq "mobile"
      end

      it "records a distinct utm_source per transition" do
        booking.tenant_id = Generator.tenant(domain: "recurrence-history2.dev").id
        booking.save!
        times = booking.calculate_daily(start_query, end_query).instances
        instance_start = times[1].to_unix

        # materialises while still reserved
        instance = booking.to_instance(instance_start)
        instance.utm_source = "desktop"
        instance.save!
        instance.history.map(&.state).should eq [Booking::State::Reserved]

        instance.checked_in = true
        instance.checked_in_at = instance_start - 60_i64
        instance.utm_source = "mobile"
        instance.save!

        instance.checked_out_at = instance_start + 60_i64
        instance.utm_source = "kiosk"
        instance.save!

        reloaded = BookingInstance
          .where(id: booking.id.as(Int64), instance_start: instance_start)
          .first

        reloaded.history.map(&.state).should eq [
          Booking::State::Reserved,
          Booking::State::CheckedIn,
          Booking::State::CheckedOut,
        ]
        reloaded.history.map(&.source).should eq ["desktop", "mobile", "kiosk"]
      end

      it "leaves the source nil when no utm_source is supplied" do
        booking.tenant_id = Generator.tenant(domain: "recurrence-history3.dev").id
        booking.save!
        times = booking.calculate_daily(start_query, end_query).instances
        instance_start = times[1].to_unix

        instance = booking.to_instance(instance_start)
        instance.checked_in = true
        instance.checked_in_at = instance_start - 60_i64
        instance.save!

        instance.history.last.state.should eq Booking::State::CheckedIn
        instance.history.last.source.should be_nil
      end

      it "does not append a duplicate entry when the state is unchanged" do
        booking.tenant_id = Generator.tenant(domain: "recurrence-history4.dev").id
        booking.save!
        times = booking.calculate_daily(start_query, end_query).instances
        instance_start = times[1].to_unix

        instance = booking.to_instance(instance_start)
        instance.utm_source = "desktop"
        instance.save!
        instance.history.size.should eq 1

        # a save that changes nothing about the state must not grow the history
        instance.process_state = "pending"
        instance.utm_source = "mobile"
        instance.save!
        instance.history.size.should eq 1
        instance.history.last.source.should eq "desktop"
      end

      it "keeps the instance history separate from the parent booking" do
        booking.tenant_id = Generator.tenant(domain: "recurrence-history5.dev").id
        booking.save!
        parent_history = booking.history.dup
        parent_history.map(&.state).should eq [Booking::State::Reserved]

        times = booking.calculate_daily(start_query, end_query).instances
        instance_start = times[1].to_unix

        instance = booking.to_instance(instance_start)
        instance.checked_in = true
        instance.checked_in_at = instance_start - 60_i64
        instance.utm_source = "mobile"
        instance.save!

        booking.reload!
        booking.history.map(&.state).should eq parent_history.map(&.state)
        booking.history.map(&.source).should eq parent_history.map(&.source)
        booking.checked_in.should be_false
      end

      # `Booking#save!` delegates to the instance, so the caller's booking object
      # must come back carrying what was actually written
      it "reflects the instance history back onto a hydrated booking on save" do
        booking.tenant_id = Generator.tenant(domain: "recurrence-history6.dev").id
        booking.save!
        times = booking.calculate_daily(start_query, end_query).instances
        instance_start = times[1].to_unix

        hydrated = booking.hydrate_instance(instance_start)
        hydrated.checked_in = true
        hydrated.checked_in_at = instance_start - 60_i64
        hydrated.utm_source = "mobile"
        hydrated.save!

        hydrated.history.last.state.should eq Booking::State::CheckedIn
        hydrated.history.last.source.should eq "mobile"

        reloaded = BookingInstance
          .where(id: booking.id.as(Int64), instance_start: instance_start)
          .first
        reloaded.history.last.source.should eq "mobile"
      end

      describe "survey triggers" do
        it "invites the host when an occurrence transitions" do
          booking.tenant_id = Generator.tenant(domain: "recurrence-survey.dev").id
          booking.zones = ["zone-survey-1"]
          booking.save!

          survey = Generator.survey(
            trigger: Survey::TriggerType::CHECKEDIN,
            zone_id: "zone-survey-1",
            building_id: "zone-survey-1",
          )
          survey.save!

          times = booking.calculate_daily(start_query, end_query).instances
          instance_start = times[1].to_unix

          instance = booking.to_instance(instance_start)
          instance.checked_in = true
          instance.checked_in_at = instance_start - 60_i64
          instance.save!

          invitations = Survey::Invitation.list(survey.id)
          invitations.size.should eq 1
          invitations.first.email.should eq booking.user_email.to_s
        end

        it "only invites on the matching state" do
          booking.tenant_id = Generator.tenant(domain: "recurrence-survey2.dev").id
          booking.zones = ["zone-survey-2"]
          booking.save!

          survey = Generator.survey(
            trigger: Survey::TriggerType::CHECKEDOUT,
            zone_id: "zone-survey-2",
            building_id: "zone-survey-2",
          )
          survey.save!

          times = booking.calculate_daily(start_query, end_query).instances
          instance_start = times[1].to_unix

          instance = booking.to_instance(instance_start)
          instance.checked_in = true
          instance.checked_in_at = instance_start - 60_i64
          instance.save!
          Survey::Invitation.list(survey.id).size.should eq 0

          instance.checked_out_at = instance_start + 60_i64
          instance.save!
          Survey::Invitation.list(survey.id).size.should eq 1
        end

        it "does not re-invite when a save leaves the state unchanged" do
          booking.tenant_id = Generator.tenant(domain: "recurrence-survey3.dev").id
          booking.zones = ["zone-survey-3"]
          booking.save!

          survey = Generator.survey(
            trigger: Survey::TriggerType::CHECKEDIN,
            zone_id: "zone-survey-3",
            building_id: "zone-survey-3",
          )
          survey.save!

          times = booking.calculate_daily(start_query, end_query).instances
          instance_start = times[1].to_unix

          instance = booking.to_instance(instance_start)
          instance.checked_in = true
          instance.checked_in_at = instance_start - 60_i64
          instance.save!
          Survey::Invitation.list(survey.id).size.should eq 1

          instance.process_state = "pending"
          instance.save!
          Survey::Invitation.list(survey.id).size.should eq 1
        end

        # guards the `survey_trigger` -> `trigger_survey_invitations` extraction
        it "still invites on a plain (non recurring) booking" do
          tenant_id = Generator.tenant(domain: "plain-survey.dev").id
          plain = Generator.booking(
            tenant_id,
            asset_id: "desk-plain",
            start: start_time,
            ending: end_time
          )
          plain.zones = ["zone-survey-4"]

          survey = Generator.survey(
            trigger: Survey::TriggerType::RESERVED,
            zone_id: "zone-survey-4",
            building_id: "zone-survey-4",
          )
          survey.save!

          plain.save!

          invitations = Survey::Invitation.list(survey.id)
          invitations.size.should eq 1
          invitations.first.email.should eq plain.user_email.to_s
        end
      end
    end
  end
end
