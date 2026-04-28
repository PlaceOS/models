require "./helper"

module PlaceOS::Model
  # Fixture for the permission-resolution end-to-end tests.
  #
  # Group tree (every group participates in `subsystem` unless a test
  # tears the membership down):
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
    getter authority : Authority
    getter subsystem : String
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
      @authority, @subsystem, @user,
      @root, @team_a, @squad_a1, @team_b,
      @building, @floor_1, @room_101, @room_102, @floor_2,
    )
    end

    def self.build(subsystem : String = "signage") : GroupPermissionsFixture
      authority = Generator.authority(domain: "http://perm-#{Random::Secure.hex(4)}.example").save!
      user = Generator.user(authority: authority).save!

      root = Generator.group(authority: authority, parent: nil, subsystems: [subsystem]).save!
      team_a = Generator.group(authority: authority, parent: root, subsystems: [subsystem]).save!
      squad_a1 = Generator.group(authority: authority, parent: team_a, subsystems: [subsystem]).save!
      team_b = Generator.group(authority: authority, parent: root, subsystems: [subsystem]).save!

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
        authority, subsystem, user,
        root, team_a, squad_a1, team_b,
        building, floor_1,
        room_101, room_102, floor_2,
      )
    end

    # Convenience forwarders so tests can stay short.
    def zone_accessible?(zone : Zone) : Bool
      Group.zone_accessible?(authority.id.not_nil!, subsystem, user.id.not_nil!, zone.id.not_nil!)
    end

    def effective_permissions(zone : Zone) : Permissions
      Group.effective_permissions(authority.id.not_nil!, subsystem, user.id.not_nil!, zone.id.not_nil!)
    end

    def effective_permissions(zone_ids : Array(String)) : Permissions
      Group.effective_permissions(authority.id.not_nil!, subsystem, user.id.not_nil!, zone_ids)
    end

    def accessible_zone_ids : Array(String)
      Group.accessible_zone_ids(authority.id.not_nil!, subsystem, user.id.not_nil!)
    end
  end

  # End-to-end tests for the subsystem-scoped permission resolution on
  # `Group`:
  # - transitive group membership with replace override
  # - transitive zone grants with replace override
  # - deny rows masking inherited access
  # - effective_permissions / zone_accessible? / accessible_zone_ids
  describe Group do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
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

      f.zone_accessible?(f.floor_1).should be_true
      f.effective_permissions(f.floor_1).should eq Permissions::Read
    end

    it "propagates membership down the group tree (transitive)" do
      f = GroupPermissionsFixture.build
      # User explicitly in root group only
      Generator.group_user(user: f.user, group: f.root, permissions: Permissions::Read).save!
      # team_a holds a zone grant
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      # User's membership in root transitively applies to team_a's zones
      f.zone_accessible?(f.floor_1).should be_true
      f.effective_permissions(f.floor_1).should eq Permissions::Read
    end

    it "propagates zone grants down the zone tree" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      # Grant at floor_1 reaches room_101 and room_102 transitively
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      f.zone_accessible?(f.room_101).should be_true
      f.zone_accessible?(f.room_102).should be_true
      # floor_2 is a sibling of floor_1, not reachable
      f.zone_accessible?(f.floor_2).should be_false
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
      f.effective_permissions(f.building).should eq Permissions::Read
      # At floor_1 (covered transitively by building's grant, through team_a
      # via root's zone grant): user's effective group is team_a with
      # Update only.
      f.effective_permissions(f.floor_1).should eq Permissions::Update
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

      f.effective_permissions(f.floor_1)
        .should eq(Permissions::Read | Permissions::Update)
      f.effective_permissions(f.room_101).should eq Permissions::Read
      # room_102 still inherits from floor_1
      f.effective_permissions(f.room_102)
        .should eq(Permissions::Read | Permissions::Update)
    end

    it "deny row zeroes out a zone subtree" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!
      Generator.group_zone(group: f.team_a, zone: f.building, permissions: Permissions::All).save!
      # Deny at floor_1 — floor_1 and its descendants must lose access.
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::All, deny: true).save!

      f.zone_accessible?(f.building).should be_true
      f.zone_accessible?(f.floor_2).should be_true
      f.zone_accessible?(f.floor_1).should be_false
      f.zone_accessible?(f.room_101).should be_false
    end

    it "accessible_zone_ids returns all reachable zones" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      ids = f.accessible_zone_ids
      expected = [f.floor_1.id, f.room_101.id, f.room_102.id].compact.map(&.to_s).sort!
      ids.sort!.should eq expected
    end

    it "unions grants from multiple groups the user belongs to" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_user(user: f.user, group: f.team_b, permissions: Permissions::Update).save!

      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_b, zone: f.floor_1, permissions: Permissions::Update).save!

      f.effective_permissions(f.floor_1)
        .should eq(Permissions::Read | Permissions::Update)
    end

    it "returns None for users with no membership" do
      f = GroupPermissionsFixture.build
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::All).save!

      f.accessible_zone_ids.should be_empty
      f.zone_accessible?(f.floor_1).should be_false
      f.effective_permissions(f.floor_1).should eq Permissions::None
    end

    it "ignores grants from groups that are not members of this subsystem" do
      f = GroupPermissionsFixture.build
      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      # Drop team_a out of this subsystem. Grants from team_a must no
      # longer count — even though the group, the GroupZone row, and the
      # GroupUser row all still exist.
      f.team_a.subsystems = [] of String
      f.team_a.save!

      f.zone_accessible?(f.floor_1).should be_false
    end

    it "lets a group participate in two subsystems independently" do
      f = GroupPermissionsFixture.build
      other_subsystem = "events-#{Random::Secure.hex(3)}"
      f.team_a.subsystems = [f.subsystem, other_subsystem]
      f.team_a.save!

      Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
      Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

      # Both subsystems see the grant (team_a participates in both).
      Group.effective_permissions(
        f.authority.id.not_nil!, f.subsystem, f.user.id.not_nil!, f.floor_1.id.not_nil!,
      ).should eq Permissions::Read
      Group.effective_permissions(
        f.authority.id.not_nil!, other_subsystem, f.user.id.not_nil!, f.floor_1.id.not_nil!,
      ).should eq Permissions::Read
    end

    describe "effective_permissions with a batch of zone ids" do
      it "returns None for an empty list" do
        f = GroupPermissionsFixture.build
        Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::All).save!
        Generator.group_zone(group: f.team_a, zone: f.building, permissions: Permissions::All).save!

        f.effective_permissions([] of String).should eq Permissions::None
      end

      it "returns None when none of the zones have an applicable grant" do
        f = GroupPermissionsFixture.build
        unreachable_zone = Generator.zone.save!

        f.effective_permissions(
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
        f.effective_permissions(
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
        f.effective_permissions(
          [f.floor_1.id.not_nil!, other_child.id.not_nil!],
        ).should eq(Permissions::Read | Permissions::Update)
      end

      it "ignores zones the user can't reach and honours the reachable ones" do
        f = GroupPermissionsFixture.build
        unreachable_zone = Generator.zone.save!

        Generator.group_user(user: f.user, group: f.team_a, permissions: Permissions::Read).save!
        Generator.group_zone(group: f.team_a, zone: f.floor_1, permissions: Permissions::Read).save!

        f.effective_permissions(
          [unreachable_zone.id.not_nil!, f.room_101.id.not_nil!],
        ).should eq Permissions::Read
      end
    end
  end
end
