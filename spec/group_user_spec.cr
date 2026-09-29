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

    it "rejects a user_id that does not exist" do
      group = Generator.group.save!
      gu = GroupUser.new(user_id: "user-does-not-exist", group_id: group.id.not_nil!, permissions: 0)
      gu.valid?.should be_false
      gu.errors.map(&.field).should contain(:user_id)
    end

    it "rejects a group_id that does not exist" do
      user = Generator.user.save!
      gu = GroupUser.new(user_id: user.id.not_nil!, group_id: UUID.random, permissions: 0)
      gu.valid?.should be_false
      gu.errors.map(&.field).should contain(:group_id)
    end

    describe "default permissions" do
      it "defaults to 0 on a new group" do
        group = Generator.group.save!
        Group.find!(group.id.not_nil!).default_permissions.should eq 0
      end

      it "persists the group's default_permissions" do
        group = Generator.group
        group.default_permissions = (Permissions::Read | Permissions::Operate).to_i
        group.save!

        Group.find!(group.id.not_nil!).default_permissions.should eq (Permissions::Read | Permissions::Operate).to_i
      end

      it "applies the group's default_permissions when none are provided" do
        group = Generator.group
        group.default_permissions = (Permissions::Read | Permissions::Share).to_i
        group.save!
        user = Generator.user.save!

        gu = Generator.group_user(user: user, group: group, permissions: nil)
        gu.permissions.should be_nil
        gu.save!

        gu.permission_flags.should eq(Permissions::Read | Permissions::Share)
        found = GroupUser.find!({user.id.not_nil!, group.id.not_nil!})
        found.permissions.should eq (Permissions::Read | Permissions::Share).to_i
      end

      it "keeps explicitly provided permissions over the group default" do
        group = Generator.group
        group.default_permissions = Permissions::Read.to_i
        group.save!
        user = Generator.user.save!

        Generator.group_user(user: user, group: group, permissions: Permissions::Manage).save!
        GroupUser.find!({user.id.not_nil!, group.id.not_nil!}).permission_flags.should eq Permissions::Manage
      end

      it "keeps an explicit None over a non-zero group default" do
        group = Generator.group
        group.default_permissions = Permissions::Read.to_i
        group.save!
        user = Generator.user.save!

        Generator.group_user(user: user, group: group, permissions: Permissions::None).save!
        GroupUser.find!({user.id.not_nil!, group.id.not_nil!}).permission_flags.should eq Permissions::None
      end

      it "grants the defaulted permissions through effective permission resolution" do
        authority = Generator.authority(domain: "http://defaults.example").save!
        group = Generator.group(authority: authority, subsystems: ["signage"])
        group.default_permissions = (Permissions::Read | Permissions::Update).to_i
        group.save!
        zone = Generator.zone.save!
        Generator.group_zone(group: group, zone: zone, permissions: Permissions::All).save!
        user = Generator.user(authority: authority).save!
        Generator.group_user(user: user, group: group, permissions: nil).save!

        Group.effective_permissions(group.authority_id.not_nil!, "signage", user.id.not_nil!, zone.id.not_nil!)
          .should eq(Permissions::Read | Permissions::Update)
      end
    end
  end
end
