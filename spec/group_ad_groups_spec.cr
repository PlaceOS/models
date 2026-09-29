require "./helper"

module PlaceOS::Model
  describe "Group AD group mappings" do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
      User.clear
      Authority.clear
    end

    ad_staff = "6a1c9a4e-0000-4000-8000-000000000001"
    ad_admins = "6a1c9a4e-0000-4000-8000-000000000002"
    ad_other = "6a1c9a4e-0000-4000-8000-000000000003"

    create_group = ->(authority : Authority, parent : Group?, mappings : Hash(String, Tuple(String, Int32))) {
      group = Generator.group(authority: authority, parent: parent)
      group.ad_group_mappings = mappings
      group.save!
    }

    membership = ->(user : User, group : Group) {
      GroupUser.find?({user.id.not_nil!, group.id.not_nil!})
    }

    describe "#ad_group_mappings" do
      it "defaults to empty" do
        group = Generator.group.save!
        Group.find!(group.id.not_nil!).ad_group_mappings.should be_empty
      end

      it "round-trips through the database" do
        authority = Generator.authority.save!
        group = create_group.call(authority, nil, {
          ad_staff  => {"Staff", Permissions::Read.to_i},
          ad_admins => {"Admins", (Permissions::Read | Permissions::Manage).to_i},
        })

        found = Group.find!(group.id.not_nil!)
        found.ad_group_mappings.should eq({
          ad_staff  => {"Staff", Permissions::Read.to_i},
          ad_admins => {"Admins", (Permissions::Read | Permissions::Manage).to_i},
        })
      end

      it "serialises mappings as {id: [name, permissions]}" do
        group = Generator.group
        group.ad_group_mappings = {ad_staff => {"Staff", 1}}
        JSON.parse(group.to_json)["ad_group_mappings"].should eq JSON.parse(%({"#{ad_staff}": ["Staff", 1]}))
      end

      it "normalises ids and sanitises names on save" do
        authority = Generator.authority.save!
        group = create_group.call(authority, nil, {
          "  #{ad_staff.upcase} " => {"<b>Staff</b>", 1},
        })

        Group.find!(group.id.not_nil!).ad_group_mappings.should eq({ad_staff => {"Staff", 1}})
      end

      it "rejects blank AD group ids" do
        group = Generator.group
        group.ad_group_mappings = {"  " => {"Blank", 1}}
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:ad_group_mappings)
      end

      it "rejects out of range permissions" do
        group = Generator.group
        group.ad_group_mappings = {ad_staff => {"Staff", -1}}
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:ad_group_mappings)

        group.ad_group_mappings = {ad_staff => {"Staff", Permissions::All.to_i + 1}}
        group.valid?.should be_false

        group.ad_group_mappings = {ad_staff => {"Staff", Permissions::All.to_i}}
        group.valid?.should be_true
      end
    end

    describe ".add_remove_ad_groups" do
      it "adds the user to groups mapped to their AD groups" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        root = create_group.call(authority, nil, {ad_staff => {"Staff", Permissions::Read.to_i}})
        admins = create_group.call(authority, root, {ad_admins => {"Admins", Permissions::Manage.to_i}})
        unrelated = create_group.call(authority, root, {ad_other => {"Other", Permissions::Read.to_i}})

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff, ad_admins])

        staff_member = membership.call(user, root).not_nil!
        staff_member.auto_assigned.should eq ad_staff
        staff_member.permission_flags.should eq Permissions::Read

        admin_member = membership.call(user, admins).not_nil!
        admin_member.auto_assigned.should eq ad_admins
        admin_member.permission_flags.should eq Permissions::Manage

        membership.call(user, unrelated).should be_nil
      end

      it "matches AD group ids case-insensitively" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        group = create_group.call(authority, nil, {ad_staff => {"Staff", 1}})

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [" #{ad_staff.upcase} "])

        membership.call(user, group).not_nil!.auto_assigned.should eq ad_staff
      end

      it "only considers groups in the given authority" do
        authority = Generator.authority(domain: "http://one.example").save!
        other_authority = Generator.authority(domain: "http://two.example").save!
        user = Generator.user(authority: authority).save!
        other_group = create_group.call(other_authority, nil, {ad_staff => {"Staff", 1}})

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        membership.call(user, other_group).should be_nil
        GroupUser.where(user_id: user.id).to_a.should be_empty
      end

      it "removes auto-assigned memberships when the user leaves the AD group" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        root = create_group.call(authority, nil, {ad_staff => {"Staff", 1}})
        admins = create_group.call(authority, root, {ad_admins => {"Admins", 1}})

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff, ad_admins])
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        membership.call(user, root).should_not be_nil
        membership.call(user, admins).should be_nil
      end

      it "removes all auto-assigned memberships when the user has no AD groups" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        root = create_group.call(authority, nil, {ad_staff => {"Staff", 1}})

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [] of String)

        membership.call(user, root).should be_nil
      end

      it "never removes or modifies manual memberships" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        mapped = create_group.call(authority, nil, {ad_staff => {"Staff", Permissions::Read.to_i}})
        unmapped = create_group.call(authority, mapped, {} of String => Tuple(String, Int32))
        Generator.group_user(user: user, group: mapped, permissions: Permissions::Manage).save!
        Generator.group_user(user: user, group: unmapped, permissions: Permissions::Update).save!

        # user is in the mapped AD group: manual membership is not converted
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])
        manual = membership.call(user, mapped).not_nil!
        manual.auto_assigned.should be_nil
        manual.permission_flags.should eq Permissions::Manage

        # user has left every AD group: manual memberships survive
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [] of String)
        membership.call(user, mapped).not_nil!.permission_flags.should eq Permissions::Manage
        membership.call(user, unmapped).not_nil!.permission_flags.should eq Permissions::Update
      end

      it "updates permissions when the mapping changes" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        group = create_group.call(authority, nil, {ad_staff => {"Staff", Permissions::Read.to_i}})
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        group.ad_group_mappings = {ad_staff => {"Staff", (Permissions::Read | Permissions::Update).to_i}}
        group.save!
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        membership.call(user, group).not_nil!.permission_flags.should eq(Permissions::Read | Permissions::Update)
      end

      it "removes auto-assigned memberships when the mapping is removed from the group" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        group = create_group.call(authority, nil, {ad_staff => {"Staff", 1}})
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        group.ad_group_mappings = {} of String => Tuple(String, Int32)
        group.save!
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        membership.call(user, group).should be_nil
      end

      it "combines permissions when several AD groups map to the same group" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        group = create_group.call(authority, nil, {
          ad_staff  => {"Staff", Permissions::Read.to_i},
          ad_admins => {"Admins", Permissions::Manage.to_i},
        })

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_admins, ad_staff])
        member = membership.call(user, group).not_nil!
        member.auto_assigned.should eq ad_staff
        member.permission_flags.should eq(Permissions::Read | Permissions::Manage)

        # leaving the recorded AD group keeps the membership via the other one
        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_admins])
        member = membership.call(user, group).not_nil!
        member.auto_assigned.should eq ad_admins
        member.permission_flags.should eq Permissions::Manage
      end

      it "is idempotent" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        group = create_group.call(authority, nil, {ad_staff => {"Staff", 1}})

        2.times { Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff]) }

        GroupUser.where(user_id: user.id).to_a.map(&.group_id).should eq [group.id]
      end

      it "grants the mapped permissions through effective permission resolution" do
        authority = Generator.authority.save!
        user = Generator.user(authority: authority).save!
        group = Generator.group(authority: authority, subsystems: ["signage"])
        group.ad_group_mappings = {ad_staff => {"Staff", (Permissions::Read | Permissions::Operate).to_i}}
        group.save!
        zone = Generator.zone.save!
        Generator.group_zone(group: group, zone: zone, permissions: Permissions::All).save!

        Group.add_remove_ad_groups(authority.id.not_nil!, user.id.not_nil!, [ad_staff])

        Group.effective_permissions(authority.id.not_nil!, "signage", user.id.not_nil!, zone.id.not_nil!)
          .should eq(Permissions::Read | Permissions::Operate)
      end
    end
  end
end
