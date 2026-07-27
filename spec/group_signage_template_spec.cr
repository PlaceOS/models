require "./helper"

module PlaceOS::Model
  describe GroupSignageTemplate do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      GroupSignageTemplate.clear
      Group.clear
      SignageTemplate.clear
      User.clear
      Authority.clear
    end

    it "saves with composite key" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      template = Generator.signage_template(authority: authority).save!

      link = Generator.group_signage_template(group: group, signage_template: template).save!
      link.persisted?.should be_true

      found = GroupSignageTemplate.find!({group.id.not_nil!, template.id.not_nil!})
      found.group_id.should eq group.id
      found.signage_template_id.should eq template.id
    end

    it "prevents duplicate (group_id, signage_template_id)" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      template = Generator.signage_template(authority: authority).save!

      Generator.group_signage_template(group: group, signage_template: template).save!
      expect_raises(::PgORM::Error) do
        Generator.group_signage_template(group: group, signage_template: template).save!
      end
    end

    it "rejects a link whose group and template are in different authorities" do
      auth1 = Generator.authority(domain: "http://one.example").save!
      auth2 = Generator.authority(domain: "http://two.example").save!
      group = Generator.group(authority: auth1).save!
      template = Generator.signage_template(authority: auth2).save!

      link = GroupSignageTemplate.new(
        group_id: group.id.not_nil!,
        signage_template_id: template.id.not_nil!,
      )
      link.valid?.should be_false
      link.errors.map(&.field).should contain(:signage_template_id)
    end

    it "cascades when the group is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      template = Generator.signage_template(authority: authority).save!

      Generator.group_signage_template(group: group, signage_template: template).save!
      group.destroy
      GroupSignageTemplate.where(signage_template_id: template.id).to_a.should be_empty
    end

    it "cascades when the template is destroyed" do
      authority = Generator.authority.save!
      group = Generator.group(authority: authority).save!
      template = Generator.signage_template(authority: authority).save!

      Generator.group_signage_template(group: group, signage_template: template).save!
      template.destroy
      GroupSignageTemplate.where(group_id: group.id).to_a.should be_empty
    end
  end
end
