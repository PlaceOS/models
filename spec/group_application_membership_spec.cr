require "./helper"

module PlaceOS::Model
  describe GroupApplicationMembership do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      GroupApplicationMembership.clear
      Group.clear
      GroupApplication.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      app = Generator.group_application(authority: authority).save!

      membership = Generator.group_application_membership(group: group, application: app).save!
      membership.persisted?.should be_true

      found = GroupApplicationMembership.find!({group.id.not_nil!, app.id.not_nil!})
      found.group_id.should eq group.id
      found.application_id.should eq app.id
    end

    it "prevents duplicate (group_id, application_id)" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      app = Generator.group_application(authority: authority).save!

      Generator.group_application_membership(group: group, application: app).save!
      expect_raises(::PgORM::Error) do
        Generator.group_application_membership(group: group, application: app).save!
      end
    end

    it "rejects a membership whose group and application are in different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      group = Generator.group(authority: auth1).save!
      app = Generator.group_application(authority: auth2).save!

      membership = GroupApplicationMembership.new(
        group_id: group.id.not_nil!,
        application_id: app.id.not_nil!,
      )
      membership.valid?.should be_false
      membership.errors.map(&.field).should contain(:application_id)
    end

    it "cascades when the group is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      app = Generator.group_application(authority: authority).save!

      Generator.group_application_membership(group: group, application: app).save!
      group.destroy
      GroupApplicationMembership.where(application_id: app.id).to_a.should be_empty
    end

    it "cascades when the application is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      app = Generator.group_application(authority: authority).save!

      Generator.group_application_membership(group: group, application: app).save!
      app.destroy
      GroupApplicationMembership.where(group_id: group.id).to_a.should be_empty
    end

    it "records history on create and destroy when acting_user is set" do
      authority = Generator.authority.save!
      actor = Generator.user(authority: authority).save!
      group = Generator.group(authority: authority).save!
      app = Generator.group_application(authority: authority).save!

      membership = Generator.group_application_membership(group: group, application: app)
      membership.acting_user = actor
      membership.save!

      membership.acting_user = actor
      membership.destroy

      entries = GroupHistory.where(resource_type: "group_application_membership").to_a
      entries.map(&.action).sort!.should eq ["create", "delete"]
      entries.first.application_id.should eq app.id
      entries.first.group_id.should eq group.id
    end
  end
end
