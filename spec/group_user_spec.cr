require "./helper"

module PlaceOS::Model
  describe GroupUser do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key and bitmask" do
      group = Generator.group.save!
      user = Generator.user.save!

      gu = Generator.group_user(
        user: user,
        group: group,
        permissions: Permissions::Read | Permissions::Update,
      ).save!

      gu.persisted?.should be_true
      gu.permission_flags.should eq(Permissions::Read | Permissions::Update)

      found = GroupUser.find!({user.id.not_nil!, group.id.not_nil!})
      found.permissions.should eq gu.permissions
    end

    it "prevents duplicate (user_id, group_id)" do
      group = Generator.group.save!
      user = Generator.user.save!
      Generator.group_user(user: user, group: group).save!

      expect_raises(::PgORM::Error) do
        Generator.group_user(user: user, group: group).save!
      end
    end

    it "cascades when the user is deleted" do
      group = Generator.group.save!
      user = Generator.user.save!
      Generator.group_user(user: user, group: group).save!

      user.destroy
      GroupUser.where(group_id: group.id).to_a.should be_empty
    end

    it "cascades when the group is deleted" do
      group = Generator.group.save!
      user = Generator.user.save!
      Generator.group_user(user: user, group: group).save!

      group.destroy
      GroupUser.where(user_id: user.id).to_a.should be_empty
    end

    it "records history on create when acting_user is set" do
      group = Generator.group.save!
      user = Generator.user.save!

      gu = Generator.group_user(user: user, group: group)
      gu.acting_user = user
      gu.save!

      histories = GroupHistory.where(resource_type: "group_user").to_a
      histories.size.should eq 1
      histories.first.group_id.should eq group.id
    end

    it "rejects a user and group from different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      group = Generator.group(authority: auth1).save!
      user = Generator.user(authority: auth2).save!

      gu = Generator.group_user(user: user, group: group)
      gu.valid?.should be_false
      gu.errors.map(&.field).should contain(:user_id)
    end
  end
end
