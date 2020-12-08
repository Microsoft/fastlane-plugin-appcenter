require 'json'
require 'net/http'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Actions
    class AppcenterFetchAppAction < Action
      def self.description
        "Fetches an app from App Center by owner name and app name"
      end

      def self.authors
        ["yinzara"]
      end

      def self.run(params)
        api_token = params[:api_token]
        app_name = params[:app_name]
        owner_name = params[:owner_name]

        app = Helper::AppcenterHelper.get_app(
          api_token,
          owner_name,
          app_name
        )

        UI.user_error!("No app named '#{app_name}' owned by #{owner_name} was found") unless app

        return app
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "APPCENTER_API_TOKEN",
                                       description: "API Token for App Center Access",
                                       verify_block: proc do |value|
                                         UI.user_error!("No API token for App Center given, pass using `api_token: 'token'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :owner_name,
                                       env_name: "APPCENTER_OWNER_NAME",
                                       description: "Name of the owner of the application on App Center",
                                       verify_block: proc do |value|
                                         UI.user_error!("No owner name for App Center given, pass using `owner_name: 'owner name'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :app_name,
                                       env_name: "APPCENTER_APP_NAME",
                                       description: "Name of the application on App Center",
                                       verify_block: proc do |value|
                                         UI.user_error!("No app name for App Center given, pass using `app_name: 'app name'`") unless value && !value.empty?
                                       end)
        ]
      end

      def self.return_value
        "A hash of the app attributes"
      end
      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
