require "./helper"

module PlaceOS::Model
  # Fixture for the permission-resolution end-to-end tests.
  #
  # Group tree (for one application):
  #   root
  #    ├── team_a
  #    │    └── squad_a1
  #    └── team_b
  #
  # Zone tree:
  #   building
  #    ├── floor_1
  #    │    ├── room_101
  #    │    └── room_102
  #    └── floor_2
  class GroupPermissionsFixture
    getter app : GroupApplication
    getter user : User
    getter root : Group
    getter team_a : Group
    getter squad_a1 : Group
    getter team_b : Group
    getter building : Zone
    getter floor_1 : Zone
    getter room_101 : Zone
    getter room_102 : Zone
    getter floor_2 : Zone

    def initialize(
      @app, @user, @root, @team_a, @squad_a1, @team_b,
      @building, @floor_1, @room_101, @room_102, @floor_2,
    )
    end

    def self.build : GroupPermissionsFixture
      authority = Generator.authority(domain: "http://perm-#{Random::Secure.hex(4)}.example").save!
      app = Generator.group_application(authority: authority).save!
      user = Generator.user(authority: authority).save!

      root = Generator.group(authority: authority, parent: nil).save!
      team_a = Generator.group(authority: authority, parent: root).save!
      squad_a1 = Generator.group(authority: authority, parent: team_a).save!
      team_b = Generator.group(authority: authority, parent: root).save!

      # Every group participates in this application, unless a test
      # explicitly tears the membership back down.
      [root, team_a, squad_a1, team_b].each do |g|
        Generator.group_application_membership(group: g, application: app).save!
      end

      building = Generator.zone.save!
      floor_1 = Generator.zone.save!
      floor_1.parent_id = building.id
      floor_1.save!
      room_101 = Generator.zone.save!
      room_101.parent_id = floor_1.id
      room_101.save!
      room_102 = Generator.zone.save!
      room_102.parent_id = floor_1.id
      room_102.save!
      floor_2 = Generator.zone.save!
      floor_2.parent_id = building.id
      floor_2.save!

      new(
        app, user,
        root, team_a, squad_a1, team_b,
        building, floor_1,
        room_101, room_102, floor_2,
      )
    end
  end

  # End-to-end tests for GroupApplication's permission resolution:
  # - transitive group membership with replace override
  # - transitive zone grants with replace override
  # - deny rows masking inherited access
  # - effective_permissions / zone_accessible? / accessible_zone_ids
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
      # Not clearing Zone: the generator caches `asset_zone` as a
      # class-level memo and other specs rely on it. Our zones use random
      # names so they don't collide across tests.
    end

    it "grants direct access" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_1.id.not_nil!).should be_true
      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!).should eq Permissions::Read
    end

    it "propagates membership down the group tree (transitive)" do
      f = GroupPermissionsFixture.build
      # User explicitly in root group only
      Generator.group_user(user: f.user, group: f.root, permissions: Permissions::Read).save!
      # team_a holds a zone grant
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      # User's membership in root transitively applies to team_a's zones
      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_1.id.not_nil!).should be_true
      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!).should eq Permissions::Read
    end

    it "propagates zone grants down the zone tree" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      # Grant at floor_1 reaches room_101 and room_102 transitively
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      f.app.zone_accessible?(f.user.id.not_nil!, f.room_101.id.not_nil!).should be_true
      f.app.zone_accessible?(f.user.id.not_nil!, f.room_102.id.not_nil!).should be_true
      # floor_2 is a sibling of floor_1, not reachable
      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_2.id.not_nil!).should be_false
    end

    it "replaces inherited group perms when user is explicitly in a descendant" do
      f = GroupPermissionsFixture.build
      # Parent grants Read; child explicitly grants Update only — at the
      # child and below, Update is in force (Read is *not* inherited).
      Generator.group_user(user: f.user, group: f.root, permissions: Permissions::Read).save!
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Update).save!

      Generator.group_zone(group: f.root, zone: f.building, permissions: Permissions::All).save!
      # Note: Permissions::All mask is ANDed with the user's effective perms
      # in each group, so user sees only what both sides grant.

      # At building (via root, user has Read): user sees Read only
      f.app.effective_permissions(f.user.id.not_nil!, f.building.id.not_nil!).should eq Permissions::Read
      # At floor_1 (covered transitively by building's grant, through team_a
      # via root's zone grant): user's effective group is team_a with
      # Update only.
      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!).should eq Permissions::Update
    end

    it "replaces inherited zone grants via a more-specific GroupZone row" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!
      # Grant at floor_1 gives Read + Update
      Generator.group_zone(
        group: f.team_a, zone: f.floor_1,
        permissions: Permissions::Read | Permissions::Update,
      ).save!
      # A more-specific entry on room_101 with just Read replaces the inherited grant
      Generator.group_zone(
        group: f.team_a, zone: f.room_101,
        permissions: Permissions::Read,
      ).save!

      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!)
        .should eq(Permissions::Read | Permissions::Update)
      f.app.effective_permissions(f.user.id.not_nil!, f.room_101.id.not_nil!)
        .should eq Permissions::Read
      # room_102 still inherits from floor_1
      f.app.effective_permissions(f.user.id.not_nil!, f.room_102.id.not_nil!)
        .should eq(Permissions::Read | Permissions::Update)
    end

    it "deny row zeroes out a zone subtree" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!
      Generator.group_zone(group: f.team_a, zone: f.building, permissions: Permissions::All).save!
      # Deny at floor_1 — floor_1 and its descendants must lose access.
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::All, deny: true).save!

      f.app.zone_accessible?(f.user.id.not_nil!, f.building.id.not_nil!).should be_true
      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_2.id.not_nil!).should be_true
      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_1.id.not_nil!).should be_false
      f.app.zone_accessible?(f.user.id.not_nil!, f.room_101.id.not_nil!).should be_false
    end

    it "accessible_zone_ids returns all reachable zones" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      ids = f.app.accessible_zone_ids(f.user.id.not_nil!)
      expected = [f.floor_1.id, f.room_101.id, f.room_102.id].compact.map(&.to_s).sort!
      ids.sort!.should eq expected
    end

    it "unions grants from multiple groups the user belongs to" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_user(user: f.user, group: f.team_b, permissions: Permissions::Update).save!

      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_b, zone: f.floor_1, permissions: Permissions::Update).save!

      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!)
        .should eq(Permissions::Read | Permissions::Update)
    end

    it "returns None for users with no membership" do
      f = GroupPermissionsFixture.build
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::All).save!

      f.app.accessible_zone_ids(f.user.id.not_nil!).should be_empty
      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_1.id.not_nil!).should be_false
      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!)
        .should eq Permissions::None
    end

    it "ignores grants from groups that are not members of this application" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      # Revoke team_a's membership in this application. Grants from
      # team_a must no longer count — even though the group, the
      # GroupZone row, and the GroupUser row all still exist.
      GroupApplicationMembership.find!({f.team_a.id.not_nil!, f.app.id.not_nil!}).destroy

      f.app.zone_accessible?(f.user.id.not_nil!, f.floor_1.id.not_nil!).should be_false
    end

    it "lets a group participate in two applications independently" do
      f = GroupPermissionsFixture.build
      other_app = Generator.group_application(
        authority: Authority.find!(f.user.authority_id), code: "other-#{Random::Secure.hex(3)}",
      ).save!
      Generator.group_application_membership(group: f.team_a, application: other_app).save!

      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      # Both applications see the grant (team_a is a member of both).
      f.app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!).should eq Permissions::Read
      other_app.effective_permissions(f.user.id.not_nil!, f.floor_1.id.not_nil!).should eq Permissions::Read
    end

    describe "effective_permissions with a batch of zone ids" do
      it "returns None for an empty list" do
        f = GroupPermissionsFixture.build
        Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!
        Generator.group_zone(group: f.team_a, zone: f.building, permissions: Permissions::All).save!

        f.app.effective_permissions(f.user.id.not_nil!, [] of String).should eq Permissions::None
      end

      it "returns None when none of the zones have an applicable grant" do
        f = GroupPermissionsFixture.build
        unreachable_zone = Generator.zone.save!

        f.app.effective_permissions(
          f.user.id.not_nil!,
          [unreachable_zone.id.not_nil!, f.floor_1.id.not_nil!],
        ).should eq Permissions::None
      end

      it "picks the closest ancestor grant per zone in one hierarchy" do
        f = GroupPermissionsFixture.build
        Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!
        # Building-level grant gives Read + Update; a more specific grant on
        # room_101 replaces it with just Read. Under replace semantics,
        # room_101 → Read, floor_1 (via building) → Read | Update.
        Generator.group_zone(
          group: f.team_a, zone: f.building,
          permissions: Permissions::Read | Permissions::Update,
        ).save!
        Generator.group_zone(
          group: f.team_a, zone: f.room_101,
          permissions: Permissions::Read,
        ).save!

        # room_101 picks up its own (narrower) grant; the union across the
        # batch should be Read | Update (from floor_1's inherited grant)
        # OR Read (from room_101) = Read | Update.
        f.app.effective_permissions(
          f.user.id.not_nil!,
          [f.room_101.id.not_nil!, f.floor_1.id.not_nil!],
        ).should eq(Permissions::Read | Permissions::Update)
      end

      it "merges permissions from zones in different hierarchies" do
        f = GroupPermissionsFixture.build
        Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!

        other_root_zone = Generator.zone.save!
        other_child = Generator.zone.save!
        other_child.parent_id = other_root_zone.id
        other_child.save!

        Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!
        Generator.group_zone(group: f.team_a, zone: other_root_zone, permissions: Permissions::Update).save!

        # Two separate zone hierarchies contribute: floor_1 gives Read,
        # the other hierarchy gives Update via inheritance. Union = both.
        f.app.effective_permissions(
          f.user.id.not_nil!,
          [f.floor_1.id.not_nil!, other_child.id.not_nil!],
        ).should eq(Permissions::Read | Permissions::Update)
      end

      it "ignores zones the user can't reach and honours the reachable ones" do
        f = GroupPermissionsFixture.build
        unreachable_zone = Generator.zone.save!

        Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
        Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

        f.app.effective_permissions(
          f.user.id.not_nil!,
          [unreachable_zone.id.not_nil!, f.room_101.id.not_nil!],
        ).should eq Permissions::Read
      end
    end
  end
end
