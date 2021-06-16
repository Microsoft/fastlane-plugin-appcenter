require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Actions
    class AppcenterCodepushReleaseReactAction < Action
      def self.description
        "CodePush release react action"
      end

      def self.authors
        ["Ivan Sokolovskii"]
      end

      def self.run(params)
        app = params[:app_name]
        owner = params[:owner_name]
        token = params[:api_token]
        deployment = params[:deployment]
        dev = params[:development]
        description = params[:description]
        mandatory = params[:mandatory]
        version = params[:target_version]
        disabled = params[:disabled]
        no_errors = params[:no_duplicate_release_error]
        bundle = params[:bundle_name]
        output = params[:output_dir]
        sourcemap_output = params[:sourcemap_output]
        dry_run = params[:dry_run]

        command = "appcenter codepush release-react --token #{token} --app #{owner}/#{app} --deployment-name #{deployment} --development #{dev} "
        if description
          command += "--description \"#{description}\" "
        end
        if mandatory
          command += "--mandatory "
        end
        if version
          command += "--target-binary-version #{version} "
        end
        if disabled
          command += "--disabled "
        end
        if no_errors
          command += "--disable-duplicate-release-error "
        end
        if bundle
          command += "--bundle-name #{bundle} "
        end
        if output
          command += "--output-dir #{output} "
        end
        if sourcemap_output
          command += "--sourcemap-output #{sourcemap_output} "
        end
        if dry_run
          UI.message("Dry run!".red + " Would have run: " + command + "\n")
        else
          sh(command.to_s)
        end
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                      type: String,
                                  env_name: "APPCENTER_API_TOKEN",
                               description: "API Token for App Center Access",
                              verify_block: proc do |value|
                                UI.user_error!("No API token for App Center given, pass using `api_token: 'token'`") unless value && !value.empty?
                              end),
          FastlaneCore::ConfigItem.new(key: :owner_name,
                                      type: String,
                                  env_name: "APPCENTER_OWNER_NAME",
                               description: "Name of the owner of the application on App Center",
                              verify_block: proc do |value|
                                UI.user_error!("No owner name for App Center given, pass using `owner_name: 'owner name'`") unless value && !value.empty?
                              end),
          FastlaneCore::ConfigItem.new(key: :app_name,
                                      type: String,
                                  env_name: "APPCENTER_APP_NAME",
                               description: "Name of the application on App Center",
                              verify_block: proc do |value|
                                UI.user_error!("No app name for App Center given, pass using `app_name: 'app name'`") unless value && !value.empty?
                              end),
          FastlaneCore::ConfigItem.new(key: :deployment,
                                      type: String,
                                  env_name: "APPCENTER_CODEPUSH_DEPLOYMENT",
                                  optional: true,
                             default_value: "Staging",
                               description: "Deployment name for releasing to"),
          FastlaneCore::ConfigItem.new(key: :target_version,
                                      type: String,
                                  env_name: "APPCENTER_CODEPUSH_TARGET_VERSION",
                                  optional: true,
                               description: "Target binary version for example 1.0.1"),
          FastlaneCore::ConfigItem.new(key: :mandatory,
                                      type: Boolean,
                                  env_name: "APPCENTER_CODEPUSH_MANDATORY",
                             default_value: true,
                                  optional: true,
                               description: "mandatory update or not"),
          FastlaneCore::ConfigItem.new(key: :description,
                                      type: String,
                                  env_name: "APPCENTER_CODEPUSH_DESCRIPTION",
                                  optional: true,
                               description: "Release description for CodePush"),
          FastlaneCore::ConfigItem.new(key: :dry_run,
                                      type: Boolean,
                                  env_name: "APPCENTER_CODEPUSH_DRY_RUN",
                             default_value: false,
                                  optional: true,
                               description: "Print the command that would be run, and don't run it"),
          FastlaneCore::ConfigItem.new(key: :disabled,
                                      type: Boolean,
                                  env_name: "APPCENTER_CODEPUSH_DISABLED",
                             default_value: false,
                                  optional: true,
                               description: "Specifies whether this release should be immediately downloadable"),
          FastlaneCore::ConfigItem.new(key: :no_duplicate_release_error,
                                      type: Boolean,
                                  env_name: "APPCENTER_CODEPUSH_NO_DUPLICATE_ERROR",
                             default_value: false,
                                  optional: true,
                               description: "Specifies whether to return an error if the main bundle is identical to the latest codepush release"),
          FastlaneCore::ConfigItem.new(key: :bundle_name,
                                      type: String,
                                  env_name: "APPCENTER_CODEPUSH_BUNDLE_NAME",
                                  optional: true,
                               description: "Specifies the name of the bundle file"),
          FastlaneCore::ConfigItem.new(key: :output_dir,
                                      type: String,
                                  env_name: "APPCENTER_CODEPUSH_OUTPUT",
                                  optional: true,
                               description: "Specifies path to where the bundle and sourcemap should be written"),
          FastlaneCore::ConfigItem.new(key: :sourcemap_output,
                                      type: String,
                                  env_name: "APPCENTER_CODEPUSH_SOURCEMAP_OUTPUT",
                                  optional: true,
                               description: "Specifies path to write sourcemap to"),
          FastlaneCore::ConfigItem.new(key: :development,
                                      type: Boolean,
                                  env_name: "APPCENTER_CODEPUSH_DEVELOPMENT",
                                  optional: true,
                             default_value: false,
                               description: "Specifies whether to generate a dev build")
        ]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
