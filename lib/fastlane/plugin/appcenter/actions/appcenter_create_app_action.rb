require 'json'
require 'net/http'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Actions
    class AppcenterCreateAppAction < Action
      def self.description
        "Creates an App Center with the given attributes and "\
        "returns a hash of the newly created app with generated values."\
        "If the app already exists, action aborts with error."\
        "If the 'error_on_create_existing' is set to false, "\
        "an existing app will not error and instead return the "\
        "app unchanged."
      end

      def self.authors
        ["yinzara"]
      end

      def self.run(params)
        api_token = params[:api_token]
        owner_type = params[:owner_type]
        owner_name = params[:owner_name]
        app_name = params[:app_name]
        app_display_name = params[:app_display_name]
        app_os = params[:app_os]
        app_platform = params[:app_platform]

        app = Helper::AppcenterHelper.get_app(api_token, owner_name, app_name)
        UI.abort_with_message!("An app named '#{app_name}' owned by #{owner_name} already existed") if app && params[:error_on_create_existing]

        app ||= Helper::AppcenterHelper.create_app(
          api_token, owner_type, owner_name, app_name, app_display_name, app_os, app_platform
        )

        UI.abort_with_message!("Unable to create '#{app_name}' owned by #{owner_name}") unless app

        return app
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "APPCENTER_API_TOKEN",
                                       description: "API Token for App Center",
                                       default_value: Actions.lane_context[SharedValues::APPCENTER_API_TOKEN],
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("No API token for App Center given, pass using `api_token: 'token'`") unless value && !value.empty?
                                       end),

          FastlaneCore::ConfigItem.new(key: :owner_type,
                                       env_name: "APPCENTER_OWNER_TYPE",
                                       description: "Owner type, either 'user' or 'organization'",
                                       optional: true,
                                       default_value: "user",
                                       type: String,
                                       verify_block: proc do |value|
                                         accepted_formats = ["user", "organization"]
                                         UI.user_error!("Only \"user\" and \"organization\" types are allowed, you provided \"#{value}\"") unless accepted_formats.include? value
                                       end),

          FastlaneCore::ConfigItem.new(key: :owner_name,
                                       env_name: "APPCENTER_OWNER_NAME",
                                       description: "Owner name as found in the App's URL in App Center",
                                       default_value: Actions.lane_context[SharedValues::APPCENTER_OWNER_NAME],
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("No Owner name for App Center given, pass using `owner_name: 'name'`") unless value && !value.empty?
                                       end),

          FastlaneCore::ConfigItem.new(key: :app_name,
                                       env_name: "APPCENTER_APP_NAME",
                                       description: "App name as found in the App's URL in App Center. If there is no app with such name, you will be prompted to create one",
                                       default_value: Actions.lane_context[SharedValues::APPCENTER_APP_NAME],
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("No App name given, pass using `app_name: 'app name'`") unless value && !value.empty?
                                       end),

          FastlaneCore::ConfigItem.new(key: :app_display_name,
                                       env_name: "APPCENTER_APP_DISPLAY_NAME",
                                       description: "App display name to use when creating a new app",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("No App display name given, pass using `app_display_name: 'app display name'`") unless value && !value.empty?
                                       end,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :app_os,
                                       env_name: "APPCENTER_APP_OS",
                                       description: "App OS. Used for new app creation, if app 'app_name' was not found",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("No App os given, pass using `app_os: 'app-os'`") unless value && !value.empty?
                                       end,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :app_platform,
                                       env_name: "APPCENTER_APP_PLATFORM",
                                       description: "App Platform. Used for new app creation, if app 'app_name' was not found",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("No App platform given, pass using `app_platform: 'app-platform'`") unless value && !value.empty?
                                       end,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :error_on_create_existing,
                                       env_name: "APPCENTER_APP_ERROR_ON_CREATE_EXISTING",
                                       description: "If the app already exists, should an error be thrown? If false, if the app exists it will be returned unchanged",
                                       is_string: false,
                                       default_value: true,
                                       optional: true)
        ]
      end

      def self.return_value
        "A hash of the newly created app (or a hash of the existing app if :error_on_create_existing is false and the app already exists)"
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
