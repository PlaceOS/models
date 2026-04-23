require "./helper"

module PlaceOS::Model
  describe GroupApplicationDoorkeeper do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      GroupApplicationDoorkeeper.clear
      GroupApplicationMembership.clear
      Group.clear
      GroupApplication.clear
      DoorkeeperApplication.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key" do
      authority = Generator.authority.save!
      group_app = Generator.group_application(authority: authority).save!
      doorkeeper = Generator.doorkeeper_application(owner: authority).save!

      link = Generator.group_application_doorkeeper(
        group_application: group_app,
        doorkeeper_application: doorkeeper,
      ).save!
      link.persisted?.should be_true

      found = GroupApplicationDoorkeeper.find!({group_app.id.not_nil!, doorkeeper.id.not_nil!})
      found.group_application_id.should eq group_app.id
      found.doorkeeper_application_id.should eq doorkeeper.id
    end

    it "prevents duplicate (group_application_id, doorkeeper_application_id)" do
      authority = Generator.authority.save!
      group_app = Generator.group_application(authority: authority).save!
      doorkeeper = Generator.doorkeeper_application(owner: authority).save!

      Generator.group_application_doorkeeper(
        group_application: group_app, doorkeeper_application: doorkeeper,
      ).save!

      expect_raises(::PgORM::Error) do
        Generator.group_application_doorkeeper(
          group_application: group_app, doorkeeper_application: doorkeeper,
        ).save!
      end
    end

    it "rejects a link whose sides are in different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      group_app = Generator.group_application(authority: auth1).save!
      doorkeeper = Generator.doorkeeper_application(owner: auth2).save!

      link = GroupApplicationDoorkeeper.new(
        group_application_id: group_app.id.not_nil!,
        doorkeeper_application_id: doorkeeper.id.not_nil!,
      )
      link.valid?.should be_false
      link.errors.map(&.field).should contain(:doorkeeper_application_id)
    end

    it "cascades when the group application is destroyed" do
      authority = Generator.authority.save!
      group_app = Generator.group_application(authority: authority).save!
      doorkeeper = Generator.doorkeeper_application(owner: authority).save!

      Generator.group_application_doorkeeper(
        group_application: group_app, doorkeeper_application: doorkeeper,
      ).save!

      group_app.destroy
      GroupApplicationDoorkeeper
        .where(doorkeeper_application_id: doorkeeper.id)
        .to_a
        .should be_empty
    end

    it "cascades when the doorkeeper application is destroyed" do
      authority = Generator.authority.save!
      group_app = Generator.group_application(authority: authority).save!
      doorkeeper = Generator.doorkeeper_application(owner: authority).save!

      Generator.group_application_doorkeeper(
        group_application: group_app, doorkeeper_application: doorkeeper,
      ).save!

      doorkeeper.destroy
      GroupApplicationDoorkeeper
        .where(group_application_id: group_app.id)
        .to_a
        .should be_empty
    end

    it "records history on create and destroy when acting_user is set" do
      authority = Generator.authority.save!
      actor = Generator.user(authority: authority).save!
      group_app = Generator.group_application(authority: authority).save!
      doorkeeper = Generator.doorkeeper_application(owner: authority).save!

      link = Generator.group_application_doorkeeper(
        group_application: group_app, doorkeeper_application: doorkeeper,
      )
      link.acting_user = actor
      link.save!

      link.acting_user = actor
      link.destroy

      entries = GroupHistory.where(resource_type: "group_application_doorkeeper").to_a
      entries.map(&.action).sort!.should eq ["create", "delete"]
      entries.first.application_id.should eq group_app.id
      entries.first.group_id.should be_nil
    end
  end
end
