require "json"
require "net/http"
require "fastlane_core/ui/ui"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Actions
    class AppcenterFetchVersionNumberAction < Action
      def self.description
        "Fetches the latest version number of an app or the last build number of a version from App Center"
      end

      def self.authors
        ["jspargo", "ShopKeep", "Qutaibah"]
      end

      def self.run(params)
        api_token = params[:api_token]
        app_name = params[:app_name]
        owner_name = params[:owner_name]
        version = params[:version]

        releases = Helper::AppcenterHelper.fetch_releases(
          api_token: api_token,
          owner_name: owner_name,
          app_name: app_name,
          )

        UI.abort_with_message!("No versions found for '#{app_name}' owned by #{owner_name}") unless releases

        sorted_releases = releases

        if version.nil?
          sorted_releases = releases.sort_by { |release| release["id"] }
        else
          sorted_releases = releases.select { |release| release["short_version"] == version }.sort_by { |release| release["id"] }
        end

        latest_release = sorted_releases.last

        if latest_release.nil?
          if version.nil?
            UI.user_error!("This app has no releases yet")
            return nil
          end
          UI.user_error!("The provided version (#{version}) has no releases yet")
          return nil
        end

        return {
          "id" => latest_release["id"],
          "version" => latest_release["short_version"],
          "build_number" => latest_release["version"],
          "release_notes" => latest_release["release_notes"],
        }
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
                                       end),
          FastlaneCore::ConfigItem.new(key: :version,
                                       env_name: "APPCENTER_APP_VERSION",
                                       description: "The version to get the latest release for",
                                       optional: true,
                                       type: String),

        ]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end

      def self.get_apps(api_token)
        host_uri = URI.parse("https://api.appcenter.ms")
        http = Net::HTTP.new(host_uri.host, host_uri.port)
        http.use_ssl = true
        apps_request = Net::HTTP::Get.new("/v0.1/apps")
        apps_request["X-API-Token"] = api_token
        apps_response = http.request(apps_request)
        return [] unless apps_response.kind_of?(Net::HTTPOK)
        return JSON.parse(apps_response.body)
      end
    end
  end
end
