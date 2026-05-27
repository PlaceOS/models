require "./helper"

module PlaceOS::Model
  describe PendingMail do
    Spec.before_each do
      PendingMail.clear
      Asset.clear
      Upload.clear
      Zone.clear
      User.clear
    end

    it "saves and round-trips a pending mail" do
      mail = Generator.pending_mail
      mail.cc = ["cc@place.technology"]
      mail.send_from = "Sender@Place.Technology"
      mail.reply_to = "reply@place.technology"
      mail.expiry = Time.utc(2030, 1, 1)
      mail.sent_at = Time.utc(2026, 1, 2)
      mail.sent_by = "signage-worker-1"
      mail.source_service = "signage"
      mail.source_reference = "ref-1234"
      mail.save!

      found = PendingMail.find!(mail.id.not_nil!)
      found.send_to.should eq ["recipient@place.technology"]
      found.cc.should eq ["cc@place.technology"]
      found.template.should eq ["welcome", "email"]
      found.args["name"].should eq "Jen"
      found.args["count"].should eq 3_i64
      found.send_from.should eq "Sender@Place.Technology"
      found.authority_id.should eq mail.authority_id
      found.user_id.should eq mail.user_id
      found.expiry.should eq Time.utc(2030, 1, 1)

      # monitoring fields default empty, persist when set
      found.sent_at.should eq Time.utc(2026, 1, 2)
      found.sent_by.should eq "signage-worker-1"
      found.rejected_at.should be_nil
      found.rejected_reason.should be_nil

      # provenance fields
      found.source_service.should eq "signage"
      found.source_reference.should eq "ref-1234"
    end

    it "resolves authority and user associations" do
      mail = Generator.pending_mail.save!
      mail.authority.id.should eq mail.authority_id
      mail.user.id.should eq mail.user_id
    end

    it "requires at least one recipient" do
      mail = Generator.pending_mail(send_to: [] of String)
      mail.save.should eq false
      mail.errors.any? { |e| e.field == :send_to }.should eq true
    end

    it "validates recipient email formats" do
      mail = Generator.pending_mail(send_to: ["not-an-email"])
      mail.save.should eq false
      mail.errors.any? { |e| e.field == :send_to }.should eq true
    end

    it "validates cc, send_from and reply_to email formats" do
      mail = Generator.pending_mail
      mail.cc = ["nope"]
      mail.send_from = "also-bad"
      mail.reply_to = "still-bad"
      mail.save.should eq false

      fields = mail.errors.map(&.field)
      fields.should contain(:cc)
      fields.should contain(:send_from)
      fields.should contain(:reply_to)
    end

    it "rejects non-scalar (nested) args on deserialization" do
      authority = Authority.find_by_domain("localhost").as(Authority)
      user = Generator.user(authority: authority).save!

      json = %({
        "authority_id": "#{authority.id}",
        "user_id": "#{user.id}",
        "send_to": ["a@place.technology"],
        "args": {"nested": {"not": "allowed"}}
      })

      expect_raises(JSON::ParseException) do
        PendingMail.from_json(json)
      end
    end

    it "prunes the zone id from zones arrays when a zone is deleted" do
      zone = Generator.zone.save!
      zone_id = zone.id.as(String)

      mail = Generator.pending_mail
      mail.zones = [zone_id]
      mail.save!

      asset = Generator.asset
      asset.zones = [zone_id]
      asset.save!

      zone.destroy

      PendingMail.find!(mail.id.not_nil!).zones.should_not contain(zone_id)
      Asset.find!(asset.id.as(String)).zones.should_not contain(zone_id)
    end

    it "prunes the upload id from attachment arrays when an upload is deleted" do
      authority = Authority.find_by_domain("localhost").as(Authority)
      user = Generator.user(authority: authority).save!

      # build an upload with no storage so destroy skips the cloud delete
      upload = Upload.new(
        uploaded_by: user.id,
        uploaded_email: user.email,
        file_name: "doc.pdf",
        file_size: 1024_i64,
        file_md5: "abc123",
        object_key: "object-key",
      )
      upload.save!
      upload_id = upload.id.as(String)

      mail = Generator.pending_mail(authority: authority, user: user)
      mail.attachments = [upload_id]
      mail.resource_attachments = [upload_id]
      mail.save!

      upload.destroy

      found = PendingMail.find!(mail.id.not_nil!)
      found.attachments.should_not contain(upload_id)
      found.resource_attachments.should_not contain(upload_id)
    end
  end
end
