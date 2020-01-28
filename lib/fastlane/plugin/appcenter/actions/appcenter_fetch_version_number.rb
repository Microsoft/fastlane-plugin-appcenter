require 'json'
require 'net/http'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Actions
    class AppcenterFetchVersionNumberAction < Action
      def self.description
        "Fetches the latest version number of an app from App Center"
      end

      def self.authors
        ["jspargo", "ShopKeep"]
      end

      def self.run(params)
        api_token = params[:api_token]
        app_name = params[:app_name]
        owner_name = params[:owner_name]

        if owner_name.nil?
          owner_name = get_owner_name(api_token, app_name)
        end

        if app_name.nil? || owner_name.nil?
          UI.user_error!("No app '#{app_name}' found for owner #{owner_name}")
          return nil
        end

        releases = Helper::AppcenterHelper.fetch_releases(
          api_token: api_token,
          owner_name: owner_name,
          app_name: app_name
        )

        if releases.nil?
          UI.user_error!("No versions found for '#{app_name}' owned by #{owner_name}")
          return nil
        end

        sorted_release = releases.sort_by { |release| release['id'] }.reverse!
        latest_build = sorted_release.first

        if latest_build.nil?
          UI.user_error!("The app has no versions yet")
          return nil
        end

        return latest_build['version']
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
                                       optional: true,
                                       description: "Name of the owner of the application on App Center",
                                       verify_block: proc do |value|
                                         UI.user_error!("No owner name for App Center given, pass using `owner_name: 'owner name'`") unless value && !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :app_name,
                                       env_name: "APPCENTER_APP_NAME",
                                       optional: true,
                                       description: "Name of the application on App Center",
                                       verify_block: proc do |value|
                                         UI.user_error!("No app name for App Center given, pass using `app_name: 'app name'`") unless value && !value.empty?
                                       end)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end

      def self.get_owner_and_app_name(api_token)
        apps = get_apps(api_token)
        app_matches = prompt_for_apps(apps)
        return unless app_matches.count > 0
        selected_app = app_matches.first
        name = selected_app['name'].to_s
        owner = selected_app['owner']['name'].to_s
        return name, owner
      end

      def self.get_owner_name(api_token, app_name)
        apps = get_apps(api_token)
        return unless apps.count > 0
        app_matches = apps.select { |app| app['name'] == app_name }
        return unless app_matches.count > 0
        selected_app = app_matches.first

        owner = selected_app['owner']['name'].to_s
        return owner
      end

      def self.get_apps(api_token)
        host_uri = URI.parse('https://api.appcenter.ms')
        http = Net::HTTP.new(host_uri.host, host_uri.port)
        http.use_ssl = true
        apps_request = Net::HTTP::Get.new("/v0.1/apps")
        apps_request['X-API-Token'] = api_token
        apps_response = http.request(apps_request)
        return [] unless apps_response.kind_of?(Net::HTTPOK)
        return JSON.parse(apps_response.body)
      end
    end
  end
end
