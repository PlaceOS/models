require "./helper"

module PlaceOS::Model
  describe Repository do
    it "saves a Repository" do
      repo = Generator.repository.save!
      Repository.find(repo.id.as(String)).should_not be_nil
    end

    describe "validation" do
      context "folder_name" do
        it "enforces valid path characters" do
          repo = Generator.repository

          repo.folder_name = "no spaces please"
          repo.valid?.should be_false
          repo.errors.first.to_s.should eq("folder_name is invalid")

          repo.errors.clear

          repo.folder_name = "no_spaces_here"
          repo.valid?.should be_true
        end
      end
      context "url" do
        it "ensures scheme is present" do
          repo = Generator.repository

          repo.uri = "iqoherlk9dgaJUNK"
          repo.valid?.should be_false
          repo.errors.first.to_s.should eq("uri is an invalid URI")
          repo.errors.clear

          repo.uri = "https://good.stuff"
          repo.valid?.should be_true
        end
      end
    end

    describe "encryption" do
      mock_id = "some-kinda-id"
      mock_encrypted = %(\e0c217481-c787-482f-9522-3a24909b1432|QduWKfyGqlR7rVo5|AHHqybTR9+eIFY18)
      expected_unencrypted = "super secret"

      it "does not encrypt empty fields" do
        repository = Generator.repository
        repository.password = ""
        repository.username = ""
        repository.id = mock_id
        repository.run_save_callbacks { true }
        repository.password.nil?.should be_true
        repository.username.nil?.should be_true
      end

      {% for field in {:password} %}
        it "#encrypt_{{ field.id }}" do
          repository = Generator.repository
          repository.{{ field.id }} = expected_unencrypted
          repository.id = mock_id
          repository.encrypt_{{ field.id }}.not_nil!.should start_with '\e'
        end

        it "#decrypt_{{ field.id }}" do
          repository = Generator.repository

          repository.{{ field.id }} = mock_encrypted
          repository.id = mock_id
          repository.decrypt_{{ field.id }}.should eq expected_unencrypted
        end

        it "encrypts `{{ field.id }}` before save" do
          repository = Generator.repository
          repository.{{ field.id }} = expected_unencrypted
          repository.id = mock_id
          repository.run_save_callbacks { true }
          encrypted = repository.{{ field.id }}.not_nil!
          encrypted.should_not eq expected_unencrypted
          encrypted.should start_with '\e'
        end
      {% end %}
    end

    it "removes dependent Drivers on destroy" do
      repo = Generator.repository(type: Repository::Type::Driver).save!

      drivers = Array(Driver).new(3) { Generator.driver(repo: repo).save! }
      Repository.find(repo.id.as(String)).should_not be_nil
      repo.destroy
      Driver.find_all(drivers.compact_map &.id).to_a.should be_empty
    end
  end
end
