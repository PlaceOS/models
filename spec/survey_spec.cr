require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Survey.clear
  end

  describe Survey do
    test_round_trip(Survey)

    it "saves a Survey" do
      survey = Generator.survey.save!

      survey.should_not be_nil
      survey.persisted?.should be_true
      Survey.find!(survey.id).id.should eq survey.id
    end

    describe "validation" do
      it "requires an authority" do
        survey = Generator.survey
        survey.authority_id = nil
        survey.valid?.should be_false
        survey.errors.map(&.field).should contain(:authority_id)
      end

      it "requires a zone_id or a building_id, treating empty strings as unset" do
        survey = Generator.survey
        survey.zone_id = ""
        survey.building_id = ""
        survey.valid?.should be_false
        survey.errors.map(&.field).should contain(:zone_id)
        survey.zone_id.should be_nil

        survey.building_id = Generator.zone.save!.id
        survey.valid?.should be_true
      end
    end

    describe "foreign keys" do
      it "clears zone_id and building_id when the zone is deleted, keeping the survey" do
        zone = Generator.zone.save!
        building = Generator.zone.save!
        survey = Generator.survey(zone_id: zone.id, building_id: building.id).save!

        zone.delete
        reloaded = Survey.find!(survey.id)
        reloaded.zone_id.should be_nil
        reloaded.building_id.should eq building.id

        building.delete
        Survey.find!(survey.id).building_id.should be_nil
      end

      it "is deleted when its authority is deleted" do
        authority = Generator.authority(domain: "survey-cascade-#{RANDOM.hex(4)}.dev").save!
        survey = Generator.survey(authority: authority).save!

        authority.delete
        Survey.find?(survey.id).should be_nil
      end
    end

    it "adopts surveys that have no authority" do
      survey = Generator.survey.save!
      Survey.where(id: survey.id).update_all(authority_id: nil)
      other = Generator.authority(domain: "survey-adopt-#{RANDOM.hex(4)}.dev").save!
      owned = Generator.survey(authority: other).save!

      authority_id = Generator.localhost_authority.id.as(String)
      Survey.adopt_unowned(authority_id)

      Survey.find!(survey.id).authority_id.should eq authority_id
      Survey.find!(owned.id).authority_id.should eq other.id
    end

    it "lists the surveys of an authority" do
      mine = Generator.survey.save!
      other = Generator.authority(domain: "survey-list-#{RANDOM.hex(4)}.dev").save!
      Generator.survey(authority: other).save!

      Survey.list(authority_id: mine.authority_id).map(&.id).should eq [mine.id]
    end

    describe ".triggered_by" do
      checked_in = Survey::TriggerType::CHECKEDIN
      # zones are created per example, a sibling spec's global before_each may clear the table
      new_zone = -> { Generator.zone.save!.id.as(String) }

      it "matches a survey with only a zone_id on that zone" do
        level, building = new_zone.call, new_zone.call
        survey = Generator.survey(trigger: checked_in, zone_id: level).save!

        Survey.triggered_by(checked_in, [building, level]).map(&.id).should eq [survey.id]
        Survey.triggered_by(checked_in, [building]).should be_empty
      end

      it "matches a survey with only a building_id on that building" do
        level, building, other_level = new_zone.call, new_zone.call, new_zone.call
        survey = Generator.survey(trigger: checked_in, building_id: building).save!

        Survey.triggered_by(checked_in, [building, other_level]).map(&.id).should eq [survey.id]
        Survey.triggered_by(checked_in, [level]).should be_empty
      end

      it "matches a survey with both only when both match" do
        level, building, other_level = new_zone.call, new_zone.call, new_zone.call
        survey = Generator.survey(trigger: checked_in, zone_id: level, building_id: building).save!

        Survey.triggered_by(checked_in, [building, level]).map(&.id).should eq [survey.id]
        Survey.triggered_by(checked_in, [building, other_level]).should be_empty
        Survey.triggered_by(checked_in, [level]).should be_empty
      end

      it "triggers nothing without zones" do
        Generator.survey(trigger: checked_in, zone_id: new_zone.call).save!

        Survey.triggered_by(checked_in, [] of String).should be_empty
        Survey.triggered_by(checked_in, nil).should be_empty
      end

      it "only matches the survey's trigger" do
        level = new_zone.call
        Generator.survey(trigger: Survey::TriggerType::CHECKEDOUT, zone_id: level).save!

        Survey.triggered_by(checked_in, [level]).should be_empty
      end

      it "never matches a survey whose zones were deleted" do
        zone = Generator.zone.save!
        Generator.survey(trigger: checked_in, zone_id: zone.id).save!
        zone_id = zone.id.as(String)
        zone.delete

        Survey.triggered_by(checked_in, [zone_id]).should be_empty
      end
    end

    it "lists the invitations of an authority's surveys" do
      mine = Generator.invitation(survey_id: Generator.survey.save!.id).save!
      other = Generator.authority(domain: "survey-invite-#{RANDOM.hex(4)}.dev").save!
      Generator.invitation(survey_id: Generator.survey(authority: other).save!.id).save!

      Survey::Invitation.list(authority_id: Generator.localhost_authority.id).map(&.id).should eq [mine.id]
    end
  end
end
