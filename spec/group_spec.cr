require "./helper"

module PlaceOS::Model
  describe Group do
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

    it "saves a root group for an authority" do
      authority = Generator.authority.save!
      root = Generator.group(authority: authority, parent: nil).save!
      root.persisted?.should be_true
      root.parent_id.should be_nil
      root.authority_id.should eq authority.id
    end

    it "saves child groups under a root" do
      authority = Generator.authority.save!
      root = Generator.group(authority: authority).save!
      child = Generator.group(authority: authority, parent: root).save!
      child.parent_id.should eq root.id
      root.children.to_a.map(&.id).should contain(child.id)
    end

    it "rejects a second root for the same authority" do
      authority = Generator.authority.save!
      Generator.group(authority: authority, parent: nil).save!

      second_root = Generator.group(authority: authority, parent: nil)
      second_root.valid?.should be_false
      second_root.errors.map(&.field).should contain(:parent_id)
    end

    it "allows one root per different authority" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      Generator.group(authority: auth1, parent: nil).save!
      Generator.group(authority: auth2, parent: nil).save! # should not raise
    end

    it "rejects a parent in a different authority" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      other_root = Generator.group(authority: auth1).save!

      foreign = Generator.group(authority: auth2, parent: other_root)
      foreign.valid?.should be_false
      foreign.errors.map(&.field).should contain(:parent_id)
    end

    it "descendant_ids returns the full subtree" do
      authority = Generator.authority.save!
      root = Generator.group(authority: authority).save!
      a = Generator.group(authority: authority, parent: root).save!
      b = Generator.group(authority: authority, parent: root).save!
      aa = Generator.group(authority: authority, parent: a).save!

      ids = root.descendant_ids
      ids.should contain(root.id.not_nil!)
      ids.should contain(a.id.not_nil!)
      ids.should contain(b.id.not_nil!)
      ids.should contain(aa.id.not_nil!)
      ids.size.should eq 4
    end

    it "cascade-destroys children when parent is destroyed" do
      authority = Generator.authority.save!
      root = Generator.group(authority: authority).save!
      child = Generator.group(authority: authority, parent: root).save!

      root.destroy
      Group.find?(child.id.not_nil!).should be_nil
    end

    it "cascade-destroys groups when authority is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      authority.destroy
      Group.find?(group.id.not_nil!).should be_nil
    end

    it "records history on create/update/delete when acting_user is set" do
      authority = Generator.authority.save!
      actor = Generator.user(authority: authority).save!

      group = Generator.group(authority: authority)
      group.acting_user = actor
      group.save!

      group.acting_user = actor
      group.name = "renamed"
      group.save!

      group.acting_user = actor
      group.destroy

      entries = GroupHistory.where(resource_type: "group", resource_id: group.id.to_s).to_a
      actions = entries.map(&.action).sort!
      actions.should eq ["create", "delete", "update"]
    end

    it "lists applications it participates in" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      app1 = Generator.group_application(authority: authority, code: "signage").save!
      app2 = Generator.group_application(authority: authority, code: "events").save!
      Generator.group_application_membership(group: group, application: app1).save!
      Generator.group_application_membership(group: group, application: app2).save!

      group.applications.map(&.id).sort!.should eq [app1.id, app2.id].compact.sort!
    end
  end
end
