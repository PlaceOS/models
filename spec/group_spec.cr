require "./helper"

module PlaceOS::Model
  describe Group do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
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

    it "allows several roots for the same authority" do
      authority = Generator.authority.save!
      support = Generator.group(authority: authority, parent: nil, subsystems: ["support"]).save!
      signage = Generator.group(authority: authority, parent: nil, subsystems: ["signage"]).save!

      roots = Group.where(authority_id: authority.id, parent_id: nil).to_a.map(&.id)
      roots.should contain(support.id)
      roots.should contain(signage.id)
      roots.size.should eq 2
    end

    it "keeps the trees under separate roots independent" do
      authority = Generator.authority.save!
      support = Generator.group(
        authority: authority,
        subsystems: ["support"],
        features: {"support" => {"tickets" => JSON::Any.new(true)}},
      ).save!
      signage = Generator.group(authority: authority, subsystems: ["support"]).save!
      support_team = Generator.group(authority: authority, parent: support, subsystems: ["support"]).save!
      signage_team = Generator.group(authority: authority, parent: signage, subsystems: ["support"]).save!

      support.descendant_ids.sort.should eq [support.id.not_nil!, support_team.id.not_nil!].sort
      signage.descendant_ids.sort.should eq [signage.id.not_nil!, signage_team.id.not_nil!].sort

      support_team.feature?("support", "tickets").should be_true
      signage_team.feature?("support", "tickets").should be_false
    end

    it "allows a child group to be promoted to a root" do
      authority = Generator.authority.save!
      root = Generator.group(authority: authority).save!
      child = Generator.group(authority: authority, parent: root).save!

      child.parent_id = nil
      child.save!
      Group.find!(child.id.not_nil!).parent_id.should be_nil
      root.descendant_ids.should_not contain(child.id.not_nil!)
    end

    it "allows roots in different authorities" do
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

    it "persists the subsystems list it participates in" do
      authority = Generator.authority.save!
      group = Generator.group(
        authority: authority,
        subsystems: ["signage", "events"],
      ).save!

      group.reload!
      group.subsystems.sort!.should eq ["events", "signage"]
    end
  end
end
