require "./helper"

module PlaceOS::Model
  describe GroupApplication do
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

    it "saves with required fields" do
      authority = Generator.authority.save!
      app = Generator.group_application(authority: authority).save!

      app.persisted?.should be_true
      app.id.should be_a(UUID)
      GroupApplication.find!(app.id.not_nil!).name.should eq app.name
    end

    it "requires name, code, authority_id" do
      authority = Generator.authority.save!
      app = GroupApplication.new(
        name: "",
        code: "",
        authority_id: authority.id.not_nil!,
      )
      app.valid?.should be_false
      app.errors.map(&.field).should contain(:name)
      app.errors.map(&.field).should contain(:code)
    end

    it "enforces unique (authority_id, code) at the model level" do
      authority = Generator.authority.save!
      Generator.group_application(authority: authority, code: "signage").save!

      dupe = Generator.group_application(authority: authority, code: "signage")
      dupe.valid?.should be_false
      dupe.errors.map(&.field).should contain(:code)

      expect_raises(::PgORM::Error) do
        dupe.save!
      end
    end

    it "allows same code across different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!

      Generator.group_application(authority: auth1, code: "signage").save!
      # Should not raise
      Generator.group_application(authority: auth2, code: "signage").save!
    end

    it "exposes root_group for its authority" do
      authority = Generator.authority.save!
      app = Generator.group_application(authority: authority).save!
      root = Generator.group(authority: authority, parent: nil).save!

      app.root_group.try(&.id).should eq root.id
      GroupApplication.root_group(authority.id.not_nil!).try(&.id).should eq root.id
    end

    it "exposes member_groups filtered by GroupApplicationMembership" do
      authority = Generator.authority.save!
      app = Generator.group_application(authority: authority).save!
      root = Generator.group(authority: authority).save!
      member = Generator.group(authority: authority, parent: root).save!
      _outsider = Generator.group(authority: authority, parent: root).save!

      Generator.group_application_membership(group: root, application: app).save!
      Generator.group_application_membership(group: member, application: app).save!

      app.member_groups.map(&.id).sort!.should eq [root.id, member.id].compact.sort!
    end

    it "records history on create when acting_user is set" do
      authority = Generator.authority.save!
      actor = Generator.user(authority: authority).save!
      app = Generator.group_application(authority: authority)
      app.acting_user = actor
      app.save!

      histories = GroupHistory.where(resource_type: "group_application", resource_id: app.id.to_s).to_a
      histories.size.should eq 1
      histories.first.action.should eq "create"
      histories.first.user_id.should eq actor.id
      histories.first.email.should eq actor.email.to_s
    end

    it "does not record history when acting_user is nil" do
      app = Generator.group_application.save!
      GroupHistory.where(resource_type: "group_application", resource_id: app.id.to_s).to_a.should be_empty
    end

    it "records history on destroy" do
      authority = Generator.authority.save!
      actor = Generator.user(authority: authority).save!
      app = Generator.group_application(authority: authority).save!
      app.acting_user = actor
      app.destroy

      GroupHistory
        .where(resource_type: "group_application", resource_id: app.id.to_s, action: "delete")
        .to_a
        .size.should eq 1
    end

    it "cascades groups on authority delete" do
      authority = Generator.authority.save!
      app = Generator.group_application(authority: authority).save!
      authority.destroy
      GroupApplication.find?(app.id.not_nil!).should be_nil
    end
  end
end
