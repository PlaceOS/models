require "./helper"

module PlaceOS::Model
  describe GroupInvitation do
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

    it "hashes the secret and returns plaintext once" do
      group = Generator.group.save!
      invitation = GroupInvitation.build_with_secret(
        group: group,
        email: "alice@example.com",
        permissions: Permissions::Read | Permissions::Update,
      )
      invitation.save!

      plaintext = invitation.plaintext_secret
      plaintext.should_not be_nil
      invitation.secret_digest.should_not eq plaintext
      invitation.secret_digest.should eq GroupInvitation.digest_secret(plaintext.not_nil!)

      # Plaintext is not reloadable from the database
      reloaded = GroupInvitation.find!(invitation.id.not_nil!)
      reloaded.plaintext_secret.should be_nil
    end

    it "lowercases and strips email" do
      group = Generator.group.save!
      invitation = GroupInvitation.build_with_secret(group: group, email: "  Bob@Example.Com  ")
      invitation.save!
      invitation.email.should eq "bob@example.com"
    end

    it "find_by_secret? locates an invitation" do
      group = Generator.group.save!
      invitation = GroupInvitation.build_with_secret(group: group, email: "c@e.com")
      invitation.save!

      found = GroupInvitation.find_by_secret?(invitation.plaintext_secret.not_nil!)
      found.try(&.id).should eq invitation.id

      GroupInvitation.find_by_secret?("nope").should be_nil
    end

    it "expired? reflects expires_at" do
      group = Generator.group.save!
      past = GroupInvitation.build_with_secret(
        group: group, email: "d@e.com", expires_at: 1.hour.ago,
      ).tap(&.save!)
      future = GroupInvitation.build_with_secret(
        group: group, email: "e@e.com", expires_at: 1.hour.from_now,
      ).tap(&.save!)

      past.expired?.should be_true
      future.expired?.should be_false
    end

    it "find_by_secret? skips expired invitations" do
      group = Generator.group.save!
      invitation = GroupInvitation.build_with_secret(
        group: group, email: "f@e.com", expires_at: 1.hour.ago,
      )
      invitation.save!

      GroupInvitation.find_by_secret?(invitation.plaintext_secret.not_nil!).should be_nil
    end

    it "accept! creates a GroupUser and destroys the invitation" do
      group = Generator.group.save!
      user = Generator.user.save!
      invitation = GroupInvitation.build_with_secret(
        group: group,
        email: user.email.to_s,
        permissions: Permissions::Read | Permissions::Share,
      )
      invitation.save!

      gu = invitation.accept!(user)
      gu.permission_flags.should eq(Permissions::Read | Permissions::Share)
      GroupInvitation.find?(invitation.id.not_nil!).should be_nil
      GroupUser.find!({user.id.not_nil!, group.id.not_nil!}).should_not be_nil
    end

    it "accept! raises on expired invitations" do
      group = Generator.group.save!
      user = Generator.user.save!
      invitation = GroupInvitation.build_with_secret(
        group: group, email: user.email.to_s, expires_at: 1.hour.ago,
      )
      invitation.save!

      expect_raises(::PgORM::Error) do
        invitation.accept!(user)
      end
    end
  end
end
