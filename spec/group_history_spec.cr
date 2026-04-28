require "./helper"

module PlaceOS::Model
  describe GroupHistory do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
      User.clear
      Authority.clear
    end

    it "saves a history entry" do
      group = Generator.group.save!
      user = Generator.user.save!

      entry = Generator.group_history(
        group_id: group.id,
        user: user,
        action: "update",
        resource_type: "group",
        resource_id: group.id.to_s,
        changed_fields: ["name", "description"],
      ).save!

      entry.persisted?.should be_true
      entry.id.should be_a(UUID)
      entry.changed_fields.should eq ["name", "description"]
      entry.created_at.should_not be_nil
    end

    it "requires email, action, resource_type, resource_id" do
      entry = GroupHistory.new(
        email: "",
        action: "",
        resource_type: "",
        resource_id: "",
      )
      entry.valid?.should be_false
      fields = entry.errors.map(&.field)
      fields.should contain(:email)
      fields.should contain(:action)
      fields.should contain(:resource_type)
      fields.should contain(:resource_id)
    end

    it "nullifies user_id but preserves email when acting user is deleted" do
      user = Generator.user.save!
      group = Generator.group.save!

      entry = Generator.group_history(
        group_id: group.id,
        user: user,
      ).save!

      entry.user_id.should eq user.id
      entry.email.should eq user.email.to_s
      entry.user_deleted?.should be_false

      user.destroy

      reloaded = GroupHistory.find!(entry.id.not_nil!)
      reloaded.user_id.should be_nil
      reloaded.email.should eq user.email.to_s
      reloaded.user_deleted?.should be_true
    end
  end
end
