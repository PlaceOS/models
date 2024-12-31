require "./helper"

module PlaceOS::Model
  describe Guest do
    Spec.after_each do
      Guest.clear
    end

    it "can search via tsquery" do
      tenant = get_tenant
      Guest.create!(
        id: 1_i64,
        tenant_id: tenant.id,
        email: "john.doe@example.com",
        name: "John Doe",
        preferred_name: "Johnny",
        organisation: "Example Org",
        phone: "1234567890"
      )

      Guest.create!(
        id: 2_i64,
        tenant_id: tenant.id,
        email: "jane.doe@example.com",
        name: "Jane Doe",
        organisation: "Another Org",
        phone: "0987654321"
      )

      results = Guest.where("tsv_search @@ to_tsquery('simple', 'john & example')").all
      results.size.should eq 1
      results.first.id.should eq 1

      results = Guest.where("tsv_search @@ to_tsquery('simple', 'jane')").all
      results.size.should eq 1
      results.first.id.should eq 2

      results = Guest.where("tsv_search @@ to_tsquery('simple', 'example')").all
      results.size.should eq 2
    end
  end
end
