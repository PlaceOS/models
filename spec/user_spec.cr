require "digest/md5"

require "./helper"

module PlaceOS::Model
  describe User do
    describe "#save" do
      it "saves a User" do
        user = Generator.user.save!
        User.find!(user.id.as(String)).id.should eq user.id
      end

      it "sets email digest on save" do
        user = Generator.user
        expected_digest = Digest::MD5.hexdigest(user.email.to_s.strip.downcase)
        user.email_digest.should be_nil
        user.save!

        user.persisted?.should be_true
        user.email_digest.should eq expected_digest
      end
    end

    describe "before_destroy" do
      context "ensure_admin_remains" do
        it "protects against concurrent deletes of admins" do
          num_tests = 30
          errors = [] of Model::Error
          num_tests.times do
            User.clear
            Array.new(4) { Generator.user(admin: true).save! }
              .map { |u|
                future do
                  begin
                    u.destroy
                  rescue e : Model::Error
                    e.message.should eq "At least one admin must remain"
                    errors << e
                  end
                end
              }.each &.get
          end

          errors.size.should eq num_tests
        end

        it "raises if only one sys_admin User remains" do
          User.clear
          user = Generator.user(admin: true).save!
          expect_raises(Model::Error, "At least one admin must remain") do
            user.destroy
          end
        end

        it "does not raise if more than one sys_admin User remains" do
          User.clear
          user0 = Generator.user(admin: true).save!
          user1 = Generator.user(admin: false).save!
          Generator.user(admin: true).save!
          user0.destroy
          user1.destroy
        end

        it "does not perform the validation on non-admin Users" do
          User.clear
          user0 = Generator.user(support: false, admin: false).save!
          user0.destroy
          user1 = Generator.user(support: true, admin: false).save!
          user1.destroy
        end
      end
    end

    describe "validations" do
      it "ensure associated authority" do
        user = Generator.user
        user.authority_id = ""
        user.valid?.should be_false
        user.errors.first.field.should eq :authority_id
      end

      it "ensure presence of user's email" do
        user = Generator.user
        user.email = Email.new("")
        user.valid?.should be_false
        user.errors.first.field.should eq :email
      end
    end

    describe "mass assignment" do
      it "prevents escalation of privilege" do
        user = Generator.user(admin: false, support: false).save!
        user.assign_attributes_from_json({support: true}.to_json)
        user.is_support?.should be_false
        user.assign_attributes_from_json({sys_admin: true}.to_json)
        user.is_admin?.should be_false
        user.assign_attributes_from_json({sys_admin: true, support: true}.to_json)
        user.is_admin?.should be_false
        user.is_support?.should be_false
      end

      it "prevents User's authority from changing" do
        user = Generator.user.save!
        authority_id = user.authority_id
        user.assign_attributes_from_json({authority_id: "auth-sn34ky"}.to_json)
        user.authority_id.should eq authority_id
      end
    end

    describe "#assign_admin_attributes_from_json" do
      {% for field in PlaceOS::Model::User::AdminAttributes.instance_vars %}
        it "assigns {{ field.name }} attribute if present" do
          support, updated_support = false, true
          sys_admin, updated_sys_admin = false, true
          login_name, updated_login_name = "fake", "even faker"
          staff_id, updated_staff_id = "1234", "1237"
          card_number, updated_card_number = "4719383889906362", "4719383889906362"
          groups, updated_groups = ["public"], ["private"]
          user = Model::User.new(
            support: support,
            admin: admin,
            login_name: login_name,
            staff_id: staff_id,
            card_number: card_number,
            groups: groups,
          )

          user.assign_admin_attributes_from_json({ email: "shouldn't change", {{field.name}}: {{field.name.id}}_updated }.to_json)
          user.email_changed?.should be_false
          user.{{field.id}}.should eq {{field.id}}_updated
        end
      {% end %}
    end

    describe "JSON subset" do
      user = Generator.user.save!

      it "#to_public_json" do
        public_user = JSON.parse(user.to_public_json).as_h
        public_attributes = User::PUBLIC_DATA.map(&.to_s)
        public_attributes << "id"
        public_user.keys.sort!.should eq public_attributes.sort
      end

      it "#to_admin_json" do
        user = Generator.user.save!
        admin_user = JSON.parse(user.to_admin_json).as_h
        admin_attributes = User::ADMIN_DATA.map(&.to_s)
        admin_attributes << "id"
        admin_user.keys.sort!.should eq admin_attributes.sort
      end
    end

    it "should create a new user with a password" do
      existing = Authority.find_by_domain("localhost")
      authority = existing || Generator.authority.save!
      json = {
        name:         Faker::Name.name,
        email:        Random.rand(9999).to_s + Faker::Internet.email,
        authority_id: authority.id,
        sys_admin:    true,
        support:      true,
        password:     "p@ssw0rd",
      }.to_json

      user = Model::User.from_json(json)
      user.password_digest.should be_nil
      user.password.should eq("p@ssw0rd")
      user.save!
      user.password_digest.should_not be_nil
      user.password.should be_nil
    end

    describe "queries" do
      it "#find_by_emails" do
        existing = Authority.find_by_domain("localhost")
        authority = existing || Generator.authority.save!
        expected_users = Array.new(5) {
          Generator.user(authority).save!
        }

        # User with pun email and different authority
        not_expected = Generator.user(Generator.authority("https://unexpected.com").save!)
        not_expected.email = expected_users.first.email
        not_expected.save!

        emails = expected_users.map &.email

        found = User.find_by_emails(authority.id.as(String), emails)
        found_ids = found.compact_map(&.id).to_a.sort!
        found_ids.should eq expected_users.compact_map(&.id).sort!
        found_ids.should_not contain(not_expected.id)
      end

      it "#find_by_email" do
        existing = Authority.find_by_domain("localhost")
        authority = existing || Generator.authority.save!
        expected_user = Generator.user(authority).save!

        found = User.find_by_email(authority.id.as(String), expected_user.email)
        found.try(&.id).should eq expected_user.id
      end
    end
  end
end
