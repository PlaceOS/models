require "./helper"

module PlaceOS::Model
  describe Tenant::OutlookConfig do
    it "#clean sets blank strings to nil" do
      config = Tenant::OutlookConfig.from_json({
        app_id:          "    ",
        base_path:       "    ",
        app_domain:      "    ",
        app_resource:    "    ",
        source_location: "    ",
      }.to_json)

      clean_config = config.not_nil!.clean

      clean_config.app_id.should eq("")
      clean_config.base_path.should be_nil
      clean_config.app_domain.should be_nil
      clean_config.app_resource.should be_nil
      clean_config.source_location.should be_nil
    end

    it "#clean removes leading and trailing whitespace" do
      config = Tenant::OutlookConfig.from_json({
        app_id:          "  qwer-asdf-zxcv  ",
        base_path:       "  inlook  ",
        app_domain:      "  https://tenant.example.com/inlook/  ",
        app_resource:    "  api://tenant.example.com/qwer-asdf-zxcv  ",
        source_location: "  https://tenant.example.com/inlook/  ",
      }.to_json)

      clean_config = config.not_nil!.clean

      clean_config.app_id.should eq("qwer-asdf-zxcv")
      clean_config.base_path.should eq("inlook")
      clean_config.app_domain.should eq("https://tenant.example.com/inlook/")
      clean_config.app_resource.should eq("api://tenant.example.com/qwer-asdf-zxcv")
      clean_config.source_location.should eq("https://tenant.example.com/inlook/")
    end

    it "#clean changes uppercase to downcase" do
      config = Tenant::OutlookConfig.from_json({
        app_id:          "  QWER-ASDF-ZXCV  ",
        base_path:       "  InLook  ",
        app_domain:      "  HTTPS://tenant.example.com/inlook/  ",
        app_resource:    "  API://tenant.example.com/QWER-ASDF-ZXCV  ",
        source_location: "  HTTPS://tenant.example.com/inlook/  ",
      }.to_json)

      clean_config = config.not_nil!.clean

      clean_config.app_id.should eq("qwer-asdf-zxcv")
      clean_config.base_path.should eq("inlook")
      clean_config.app_domain.should eq("https://tenant.example.com/inlook/")
      clean_config.app_resource.should eq("api://tenant.example.com/qwer-asdf-zxcv")
      clean_config.source_location.should eq("https://tenant.example.com/inlook/")
    end
  end
end
