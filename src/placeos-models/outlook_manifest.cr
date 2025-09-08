require "xml"

module PlaceOS::Model
  record OutlookManifest, app_id : String, app_domain : String, app_resource : String, source_location : String,
    function_file_url : String, taskpane_url : String, rooms_button_url : String, desks_button_url : String, version : String do
    def to_xml
      XML.build(version: "1.0", encoding: "UTF-8", indent: "  ") do |xml|
        xml.element(
          "OfficeApp",
          "xmlns": "http://schemas.microsoft.com/office/appforoffice/1.1",
          "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
          "xmlns:bt": "http://schemas.microsoft.com/office/officeappbasictypes/1.0",
          "xmlns:mailappor": "http://schemas.microsoft.com/office/mailappversionoverrides/1.0",
          "xsi:type": "MailApp"
        ) do
          xml.element("Id") { xml.text UUID.random.to_s }
          xml.element("Version") { xml.text @version }
          xml.element("ProviderName") { xml.text "PLACEOS" }
          xml.element("DefaultLocale") { xml.text "en-US" }
          xml.element("DisplayName", "DefaultValue": "PlaceOS | Book Meeting Plugin")
          xml.element("Description", "DefaultValue": "This add-in allows you to book rooms in your building via the PlaceOS API")
          xml.element("IconUrl", "DefaultValue": "https://s3.ap-southeast-2.amazonaws.com/os.place.tech/outlook-plugin-resources/16x16-01.png")
          xml.element("HighResolutionIconUrl", "DefaultValue": "https://s3.ap-southeast-2.amazonaws.com/os.place.tech/outlook-plugin-resources/80x80-01.png")
          xml.element("SupportUrl", "DefaultValue": "https://place.technology/contact")
          xml.element("AppDomains") do
            xml.element("AppDomain") { xml.text @app_domain }
          end
          xml.element("Hosts") do
            xml.element("Host", "Name": "Mailbox")
          end
          xml.element("Requirements") do
            xml.element("Sets") do
              xml.element("Set", "Name": "Mailbox", "MinVersion": "1.1")
            end
          end
          xml.element("FormSettings") do
            xml.element("Form", "xsi:type": "ItemRead") do
              xml.element("DesktopSettings") do
                xml.element("SourceLocation", "DefaultValue": @source_location)
                xml.element("RequestedHeight") { xml.text "250" }
              end
            end
          end
          xml.element("Permissions") { xml.text "ReadWriteItem" }
          xml.element("Rule", "xsi:type": "RuleCollection", "Mode": "Or") do
            xml.element("Rule", "xsi:type": "ItemIs", "ItemType": "Message", "FormType": "Read")
          end
          xml.element("DisableEntityHighlighting") { xml.text "false" }
          xml.element("VersionOverrides", "xmlns": "http://schemas.microsoft.com/office/mailappversionoverrides", "xsi:type": "VersionOverridesV1_0") do
            xml.element("VersionOverrides", "xmlns": "http://schemas.microsoft.com/office/mailappversionoverrides/1.1", "xsi:type": "VersionOverridesV1_1") do
              xml.element("Requirements") do
                xml.element("bt:Sets", "DefaultMinVersion": "1.6") do
                  xml.element("bt:Set", "Name": "Mailbox")
                end
              end
              xml.element("Hosts") do
                xml.element("Host", "xsi:type": "MailHost") do
                  xml.element("DesktopFormFactor") do
                    xml.element("FunctionFile", "resid": "functionFile")
                    xml.element("ExtensionPoint", "xsi:type": "AppointmentOrganizerCommandSurface") do
                      xml.element("OfficeTab", "id": "TabDefault") do
                        xml.element("Group", "id": "msgReadGroup") do
                          xml.element("Label", "resid": "GroupLabel")
                          xml.element("Control", "xsi:type": "Button", "id": "msgReadOpenPaneButton") do
                            xml.element("Label", "resid": "TaskpaneButton.Label")
                            xml.element("Supertip") do
                              xml.element("Title", "resid": "TaskpaneButton.Label")
                              xml.element("Description", "resid": "TaskpaneButton.Tooltip")
                            end
                            xml.element("Icon") do
                              xml.element("bt:Image", "size": "16", "resid": "Icon.16x16")
                              xml.element("bt:Image", "size": "32", "resid": "Icon.32x32")
                              xml.element("bt:Image", "size": "80", "resid": "Icon.80x80")
                            end
                            xml.element("Action", "xsi:type": "ShowTaskpane") do
                              xml.element("SourceLocation", "resid": "Taskpane.Url")
                            end
                          end
                          xml.element("Control", "xsi:type": "Button", "id": "RoomsButton") do
                            xml.element("Label", "resid": "RoomsButton.Label")
                            xml.element("Supertip") do
                              xml.element("Title", "resid": "RoomsButton.Label")
                              xml.element("Description", "resid": "RoomsButton.Tooltip")
                            end
                            xml.element("Icon") do
                              xml.element("bt:Image", "size": "16", "resid": "Icon.16x16")
                              xml.element("bt:Image", "size": "32", "resid": "Icon.32x32")
                              xml.element("bt:Image", "size": "80", "resid": "Icon.80x80")
                            end
                            xml.element("Action", "xsi:type": "ShowTaskpane") do
                              xml.element("SourceLocation", "resid": "RoomsButton.Url")
                            end
                          end
                          xml.element("Control", "xsi:type": "Button", "id": "DesksButton") do
                            xml.element("Label", "resid": "DesksButton.Label")
                            xml.element("Supertip") do
                              xml.element("Title", "resid": "DesksButton.Label")
                              xml.element("Description", "resid": "DesksButton.Tooltip")
                            end
                            xml.element("Icon") do
                              xml.element("bt:Image", "size": "16", "resid": "Icon.16x16")
                              xml.element("bt:Image", "size": "32", "resid": "Icon.32x32")
                              xml.element("bt:Image", "size": "80", "resid": "Icon.80x80")
                            end
                            xml.element("Action", "xsi:type": "ShowTaskpane") do
                              xml.element("SourceLocation", "resid": "DesksButton.Url")
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
              xml.element("Resources") do
                xml.element("bt:Images") do
                  xml.element("bt:Image", "id": "Icon.16x16", "DefaultValue": "https://s3.ap-southeast-2.amazonaws.com/os.place.tech/outlook-plugin-resources/16x16-01.png")
                  xml.element("bt:Image", "id": "Icon.32x32", "DefaultValue": "https://s3.ap-southeast-2.amazonaws.com/os.place.tech/outlook-plugin-resources/32x32-01.png")
                  xml.element("bt:Image", "id": "Icon.80x80", "DefaultValue": "https://s3.ap-southeast-2.amazonaws.com/os.place.tech/outlook-plugin-resources/80x80-01.png")
                end
                xml.element("bt:Urls") do
                  xml.element("bt:Url", "id": "functionFile", "DefaultValue": @function_file_url)
                  xml.element("bt:Url", "id": "Taskpane.Url", "DefaultValue": @taskpane_url)
                  xml.element("bt:Url", "id": "RoomsButton.Url", "DefaultValue": @rooms_button_url)
                  xml.element("bt:Url", "id": "DesksButton.Url", "DefaultValue": @desks_button_url)
                end
                xml.element("bt:ShortStrings") do
                  xml.element("bt:String", "id": "GroupLabel", "DefaultValue": "PlaceOS | Book Meeting")
                  xml.element("bt:String", "id": "TaskpaneButton.Label", "DefaultValue": "Book a meeting")
                  xml.element("bt:String", "id": "DesksButton.Label", "DefaultValue": "Book a Desk")
                  xml.element("bt:String", "id": "RoomsButton.Label", "DefaultValue": "Upcoming meetings")
                end
                xml.element("bt:LongStrings") do
                  xml.element("bt:String", "id": "TaskpaneButton.Tooltip", "DefaultValue": "Opens a pane displaying all available properties.")
                  xml.element("bt:String", "id": "DesksButton.Tooltip", "DefaultValue": "Opens a pane displaying all available properties.")
                  xml.element("bt:String", "id": "RoomsButton.Tooltip", "DefaultValue": "Opens a pane displaying all available properties.")
                end
              end
              xml.element("WebApplicationInfo") do
                xml.element("Id") { xml.text @app_id }
                xml.element("Resource") { xml.text @app_resource }
                xml.element("Scopes") do
                  xml.element("Scope") { xml.text "profile" }
                  xml.element("Scope") { xml.text "openid" }
                  xml.element("Scope") { xml.text "User.Read" }
                end
              end
            end
          end
        end
      end
    end
  end
end
