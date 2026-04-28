require "./helper"

module PlaceOS::Model
  describe GroupZone do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key, bitmask, and deny flag" do
      group = Generator.group.save!
      zone = Generator.zone.save!

      gz = Generator.group_zone(
        group: group,
        zone: zone,
        permissions: Permissions::Read | Permissions::Operate,
      ).save!

      gz.permission_flags.should eq(Permissions::Read | Permissions::Operate)
      gz.deny.should be_false

      found = GroupZone.find!({group.id.not_nil!, zone.id.not_nil!})
      found.permissions.should eq gz.permissions
    end

    it "allows a deny row" do
      group = Generator.group.save!
      zone = Generator.zone.save!
      gz = Generator.group_zone(group: group, zone: zone, deny: true).save!
      gz.deny.should be_true
    end

    it "cascades when the zone is deleted" do
      group = Generator.group.save!
      zone = Generator.zone.save!
      Generator.group_zone(group: group, zone: zone).save!

      zone.destroy
      GroupZone.where(group_id: group.id).to_a.should be_empty
    end

    it "prevents duplicate (group_id, zone_id)" do
      group = Generator.group.save!
      zone = Generator.zone.save!
      Generator.group_zone(group: group, zone: zone).save!

      expect_raises(::PgORM::Error) do
        Generator.group_zone(group: group, zone: zone).save!
      end
    end
  end
end
