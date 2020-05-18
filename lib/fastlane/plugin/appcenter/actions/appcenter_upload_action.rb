module Fastlane
  module Actions
    module Constants
      MAX_RELEASE_NOTES_LENGTH = 5000
      SUPPORTED_EXTENSIONS = {
          android: %w(.aab .apk),
          ios: %w(.ipa),
          mac: %w(.app .app.zip .dmg .pkg),
          windows: %w(.appx .appxbundle .appxupload .msix .msixbundle .msixupload .zip .msi),
          custom: %w(.zip)
      }
      ALL_SUPPORTED_EXTENSIONS = SUPPORTED_EXTENSIONS.values.flatten.sort!.uniq!
      STORE_ONLY_EXTENSIONS = %w(.aab)
      STORE_SUPPORTED_EXTENSIONS = %w(.aab .apk .ipa)
      VERSION_REQUIRED_EXTENSIONS = %w(.msi .zip)
      FULL_VERSION_REQUIRED_EXTENSIONS = %w(.dmg .pkg)
    end

    module SharedValues
      APPCENTER_DOWNLOAD_LINK = :APPCENTER_DOWNLOAD_LINK
      APPCENTER_BUILD_INFORMATION = :APPCENTER_BUILD_INFORMATION
    end

    class RetryableException < StandardError
    end

    class AppcenterUploadAction < Action
      def self.is_apple_build(file)
        return false unless file

        file_ext = Helper::AppcenterHelper.file_extname_full(file)
        ((Constants::SUPPORTED_EXTENSIONS[:ios] + Constants::SUPPORTED_EXTENSIONS[:mac])).include? file_ext
      end

      # run whole upload process for dSYM files
      def self.run_dsym_upload(params)
        values = params.values
        api_token = params[:api_token]
        owner_name = params[:owner_name]
        app_name = params[:app_name]
        file = params[:file] || params[:ipa]
        dsym = params[:dsym]
        build_number = params[:build_number]
        version = params[:version]

        dsym_path = nil
        if dsym
          # we can use dsym parameter for all apple builds
          self.optional_error("dsym parameter can only be used with Apple builds (ios, mac)") unless !file || self.is_apple_build(file)
          dsym_path = dsym
        else
          # if dsym is not set, but build is ipa - check default path
          if file && File.exist?(file) && File.extname(file) == '.ipa'
            dsym_path = file.to_s.gsub('.ipa', '.dSYM.zip')
            UI.message("dSYM is found")
          end
        end

        # if we provided valid dsym path, or <ipa_path>.dSYM.zip was found, start dSYM upload
        if dsym_path && File.exist?(dsym_path)
          if File.directory?(dsym_path)
            UI.message("dSYM path is folder, zipping...")
            dsym_path = Actions::ZipAction.run(path: dsym, output_path: dsym + ".zip")
            UI.message("dSYM files zipped")
          end

          values[:dsym_path] = dsym_path

          UI.message("Starting dSYM upload...")

          # TODO: this should eventually be removed once we have warned of deprecation for long enough
          if File.extname(dsym_path) == ".txt"
            file_name = File.basename(dsym_path)
            dsym_upload_details = Helper::AppcenterHelper.create_mapping_upload(api_token, owner_name, app_name, file_name ,build_number, version)
          else
            dsym_upload_details = Helper::AppcenterHelper.create_dsym_upload(api_token, owner_name, app_name)
          end

          if dsym_upload_details
            symbol_upload_id = dsym_upload_details['symbol_upload_id']
            upload_url = dsym_upload_details['upload_url']

            UI.message("Uploading dSYM...")
            Helper::AppcenterHelper.upload_symbol(api_token, owner_name, app_name, dsym_path, "Apple", symbol_upload_id, upload_url)
          end
        end
      end

      def self.run_mapping_upload(params)
        api_token = params[:api_token]
        owner_name = params[:owner_name]
        app_name = params[:app_name]
        mapping = params[:mapping]
        build_number = params[:build_number]
        version = params[:version]

        if mapping == nil
          return
        end

        UI.message("Starting mapping upload...")
        mapping_name = File.basename(mapping)
        symbol_upload_details = Helper::AppcenterHelper.create_mapping_upload(api_token, owner_name, app_name, mapping_name, build_number, version)

        if symbol_upload_details
          symbol_upload_id = symbol_upload_details['symbol_upload_id']
          upload_url = symbol_upload_details['upload_url']

          UI.message("Uploading mapping...")
          Helper::AppcenterHelper.upload_symbol(api_token, owner_name, app_name, mapping, "Android", symbol_upload_id, upload_url)
        end
      end

      # run whole upload process for release
      def self.run_release_upload(params)
        values = params.values
        api_token = params[:api_token]
        owner_name = params[:owner_name]
        owner_type = params[:owner_type]
        app_name = params[:app_name]
        destinations = params[:destinations]
        destination_type = params[:destination_type]
        mandatory_update = params[:mandatory_update]
        notify_testers = params[:notify_testers]
        release_notes = params[:release_notes]
        should_clip = params[:should_clip]
        release_notes_link = params[:release_notes_link]
        timeout = params[:timeout]
        build_number = params[:build_number]
        version = params[:version]
        dsa_signature = params[:dsa_signature]

        if release_notes.length >= Constants::MAX_RELEASE_NOTES_LENGTH
          unless should_clip
            clip = UI.confirm("The release notes are limited to #{Constants::MAX_RELEASE_NOTES_LENGTH} characters, proceeding will clip them. Proceed anyway?")
            UI.abort_with_message!("Upload aborted, please edit your release notes") unless clip
            release_notes_link ||= UI.input("Provide a link for additional release notes, leave blank to skip")
          end
          read_more = "..." + (release_notes_link.to_s.empty? ? "" : "\n\n[read more](#{release_notes_link})")
          release_notes = release_notes[0, Constants::MAX_RELEASE_NOTES_LENGTH - read_more.length] + read_more
          values[:release_notes] = release_notes
          UI.message("Release notes clipped")
        end

        file = [
          params[:file],
          params[:ipa],
          params[:apk],
          params[:aab],
        ].detect { |e| !e.to_s.empty? }

        UI.user_error!("Couldn't find build file at path '#{file}'") unless file && File.exist?(file)

        file_ext = Helper::AppcenterHelper.file_extname_full(file)
        if destination_type == "group"
          self.optional_error("Can't distribute #{file_ext} to groups, please use `destination_type: 'store'`") if Constants::STORE_ONLY_EXTENSIONS.include? file_ext
        else
          self.optional_error("Can't distribute #{file_ext} to stores, please use `destination_type: 'group'`") unless Constants::STORE_SUPPORTED_EXTENSIONS.include? file_ext
          UI.user_error!("The combination of `destinations: '*'` and `destination_type: 'store'` is invalid, please use `destination_type: 'group'` or explicitly specify the destinations") if destinations == "*"
        end

        release_upload_body = nil
        unless params[:file].to_s.empty?
          if Constants::FULL_VERSION_REQUIRED_EXTENSIONS.include? file_ext
            self.optional_error("Fields `version` and `build_number` must be specified to upload a #{file_ext} file") if build_number.to_s.empty? || version.to_s.empty?
          elsif Constants::VERSION_REQUIRED_EXTENSIONS.include? file_ext
            self.optional_error("Field `version` must be specified to upload a #{file_ext} file") if version.to_s.empty?
          else
            self.optional_error("Fields `version` and `build_number` are not supported for files of type #{file_ext}") unless build_number.to_s.empty? && version.to_s.empty?
          end

          release_upload_body = { build_version: version } unless version.nil?
          release_upload_body = { build_version: version, build_number: build_number } if !version.nil? && !build_number.nil?
        end

        if file_ext == ".app" && File.directory?(file)
          UI.message("App path is a directory, zipping it before upload")
          zip_file = file + ".zip"
          if File.exist? zip_file
            override = UI.interactive? ? UI.confirm("File '#{zip_file}' already exists, do you want to override it?") : true
            UI.abort_with_message!("Not overriding, aborting publishing operation") unless override
            UI.message("Deleting zip archive: #{zip_file}")
            File.delete zip_file
          end
          UI.message("Creating zip archive: #{zip_file}")
          file = Actions::ZipAction.run(path: file, output_path: zip_file)
        end

        UI.message("Starting release upload...")
        upload_details = Helper::AppcenterHelper.create_release_upload(api_token, owner_name, app_name, release_upload_body)
        if upload_details
          upload_id = upload_details['upload_id']
          upload_url = upload_details['upload_url']

          UI.message("Uploading release binary...")
          uploaded = Helper::AppcenterHelper.upload_build(api_token, owner_name, app_name, file, upload_id, upload_url, timeout)

          if uploaded
            release_id = uploaded['release_id']
            release_url = Helper::AppcenterHelper.get_release_url(owner_type, owner_name, app_name, release_id)
            UI.message("Release '#{release_id}' committed: #{release_url}")

            release = Helper::AppcenterHelper.update_release(api_token, owner_name, app_name, release_id, release_notes)
            Helper::AppcenterHelper.update_release_metadata(api_token, owner_name, app_name, release_id, dsa_signature)

            destinations_array = []
            if destinations == '*'
              UI.message("Looking up all distribution groups for #{owner_name}/#{app_name}")
              distribution_groups = Helper::AppcenterHelper.fetch_distribution_groups(
                api_token: api_token,
                owner_name: owner_name,
                app_name: app_name
              )

              UI.abort_with_message!("Failed to list distribution groups for #{owner_name}/#{app_name}") unless distribution_groups
              
              destinations_array = distribution_groups.map {|h| h['name'] }
            else
              destinations_array = destinations.split(',').map(&:strip)
            end
            
            destinations_array.each do |destination_name|
              destination = Helper::AppcenterHelper.get_destination(api_token, owner_name, app_name, destination_type, destination_name)
              if destination
                destination_id = destination['id']
                distributed_release = Helper::AppcenterHelper.add_to_destination(api_token, owner_name, app_name, release_id, destination_type, destination_id, mandatory_update, notify_testers)
                if distributed_release
                  UI.success("Release '#{release_id}' (#{distributed_release['short_version']}) was successfully distributed to #{destination_type} \"#{destination_name}\"")
                else
                  UI.error("Release '#{release_id}' was not found for destination '#{destination_name}'")
                end
              else
                UI.error("#{destination_type} '#{destination_name}' was not found")
              end
            end

            safe_download_url = Helper::AppcenterHelper.get_install_url(owner_type, owner_name, app_name)
            UI.message("Release '#{release_id}' is available for download at: #{safe_download_url}")
          else
            UI.user_error!("Failed to upload release")
          end
        end

        release
      end

      # checks app existance, if ther is no such - creates it
      def self.get_or_create_app(params)
        api_token = params[:api_token]
        owner_type = params[:owner_type]
        owner_name = params[:owner_name]
        app_name = params[:app_name]
        app_display_name = params[:app_display_name]
        app_os = params[:app_os]
        app_platform = params[:app_platform]

        platforms = {
          Android: %w[Java React-Native Xamarin Unity],
          iOS: %w[Objective-C-Swift React-Native Xamarin Unity],
          macOS: %w[Objective-C-Swift],
          Windows: %w[UWP WPF WinForms Unity],
          Custom: %w[Custom]
        }

        begin
          if Helper::AppcenterHelper.get_app(api_token, owner_name, app_name)
            return :got_app
          end
        rescue URI::InvalidURIError
          UI.user_error!("Provided app_name: '#{app_name}' is not in a valid format. Please ensure no special characters or spaces in the app_name.")
          return false
        end

        should_create_app = !app_display_name.to_s.empty? || !app_os.to_s.empty? || !app_platform.to_s.empty?

        if Helper.test? || should_create_app || UI.confirm("App with name #{app_name} not found, create one?")
          app_display_name = app_name if app_display_name.to_s.empty?
          os = app_os.to_s.empty? && (Helper.test? ? "Android" : UI.select("Select OS", platforms.keys)) || app_os.to_s
          platform = app_platform.to_s.empty? && (Helper.test? ? platforms[os.to_sym][0] : app_platform.to_s) || app_platform.to_s
          if platform.to_s.empty?
            platform = platforms[os.to_sym].length == 1 ? platforms[os.to_sym][0] : UI.select("Select Platform", platforms[os.to_sym])
          end

          if Helper::AppcenterHelper.create_app(api_token, owner_type, owner_name, app_name, app_display_name, os, platform)
            return :created_app
          end
        else
          UI.error("Lane aborted")
          false
        end
      end

      def self.run(params)
        values = params.values
        upload_build_only = params[:upload_build_only]
        upload_dsym_only = params[:upload_dsym_only]
        upload_mapping_only = params[:upload_mapping_only]

        Options.strict_mode(params[:strict])

        release = nil
        case self.get_or_create_app(params)
        when :created_app
          each_retry = Proc.new do |exception, try, elapsed_time, next_interval|
            UI.message("Release upload failed (#{exception.message}), retrying. Attempt# #{try}. #{next_interval} seconds until the next try.")
          end
          Retriable.retriable(tries: 60, on_retry: each_retry) do
            release = self.run_release_upload(params) unless upload_dsym_only || upload_mapping_only
            raise RetryableException unless release
          end
        when :got_app
          release = self.run_release_upload(params) unless upload_dsym_only || upload_mapping_only
        else
          return
        end

        params[:version] = release['short_version'] if release
        params[:build_number] = release['version'] if release

        self.run_dsym_upload(params) unless upload_mapping_only || upload_build_only
        self.run_mapping_upload(params) unless upload_dsym_only || upload_build_only

        return values if Helper.test?
      end

      def self.description
        "Distribute new release to App Center"
      end

      def self.authors
        ["Microsoft"]
      end

      def self.details
        "Symbols will also be uploaded automatically if a `app.dSYM.zip` file is found next to `app.ipa`. In case it is located in a different place you can specify the path explicitly in `:dsym` parameter."
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
                                  optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :app_os,
                                  env_name: "APPCENTER_APP_OS",
                               description: "App OS can be Android, iOS, macOS, Windows, Custom. Used for new app creation, if app 'app_name' was not found",
                                  optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :app_platform,
                                  env_name: "APPCENTER_APP_PLATFORM",
                               description: "App Platform. Used for new app creation, if app 'app_name' was not found",
                                  optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :apk,
                                  env_name: "APPCENTER_DISTRIBUTE_APK",
                               description: "Build release path for android build",
                             default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH],
                                  optional: true,
                                deprecated: true,
                                      type: String,
                       conflicting_options: [:ipa, :aab, :file],
                            conflict_block: proc do |value|
                              UI.user_error!("You can't use 'apk' and '#{value.key}' options in one run")
                            end,
                              verify_block: proc do |value|
                                accepted_formats = [".apk"]
                                file_extname_full = Helper::AppcenterHelper.file_extname_full(value)
                                self.optional_error("Only \".apk\" formats are allowed, you provided \"#{file_extname_full}\"") unless accepted_formats.include? file_extname_full
                              end),

          FastlaneCore::ConfigItem.new(key: :aab,
                                  env_name: "APPCENTER_DISTRIBUTE_AAB",
                               description: "Build release path for android app bundle build",
                             default_value: Actions.lane_context[SharedValues::GRADLE_AAB_OUTPUT_PATH],
                                  optional: true,
                                deprecated: true,
                                      type: String,
                       conflicting_options: [:ipa, :apk, :file],
                            conflict_block: proc do |value|
                              UI.user_error!("You can't use 'aab' and '#{value.key}' options in one run")
                            end,
                              verify_block: proc do |value|
                                accepted_formats = [".aab"]
                                self.optional_error("Only \".aab\" formats are allowed, you provided \"#{File.extname(value)}\"") unless accepted_formats.include? File.extname(value)
                              end),

          FastlaneCore::ConfigItem.new(key: :ipa,
                                  env_name: "APPCENTER_DISTRIBUTE_IPA",
                               description: "Build release path for iOS builds",
                             default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
                                  optional: true,
                                deprecated: true,
                                      type: String,
                       conflicting_options: [:apk, :aab, :file],
                            conflict_block: proc do |value|
                              UI.user_error!("You can't use 'ipa' and '#{value.key}' options in one run")
                            end,
                              verify_block: proc do |value|
                                accepted_formats = [".ipa"]
                                self.optional_error("Only \".ipa\" formats are allowed, you provided \"#{File.extname(value)}\"") unless accepted_formats.include? File.extname(value)
                              end),

          FastlaneCore::ConfigItem.new(key: :file,
                                  env_name: "APPCENTER_DISTRIBUTE_FILE",
                               description: "File path to the release build to publish",
                                  optional: true,
                                      type: String,
                       conflicting_options: [:apk, :aab, :ipa],
                            conflict_block: proc do |value|
                              UI.user_error!("You can't use 'file' and '#{value.key}' options in one run")
                            end,
                              verify_block: proc do |value|
                                platform = Actions.lane_context[SharedValues::PLATFORM_NAME]
                                if platform
                                  accepted_formats = Constants::SUPPORTED_EXTENSIONS[platform.to_sym]
                                  unless accepted_formats
                                    UI.important("Unknown platform '#{platform}', Supported are #{Constants::SUPPORTED_EXTENSIONS.keys}")
                                    accepted_formats = Constants::ALL_SUPPORTED_EXTENSIONS
                                  end
                                  file_ext = Helper::AppcenterHelper.file_extname_full(value)
                                  self.optional_error("Extension not supported: '#{file_ext}'. Supported formats for platform '#{platform}': #{accepted_formats.join ' '}") unless accepted_formats.include? file_ext
                                end
                              end),

          FastlaneCore::ConfigItem.new(key: :upload_build_only,
                                  env_name: "APPCENTER_DISTRIBUTE_UPLOAD_BUILD_ONLY",
                               description: "Flag to upload only the build to App Center. Skips uploading symbols or mapping",
                                  optional: true,
                                 is_string: false,
                             default_value: false,
                       conflicting_options: [:upload_dsym_only, :upload_mapping_only],
                            conflict_block: proc do |value|
                              UI.user_error!("You can't use 'upload_build_only' and '#{value.key}' options in one run")
                            end),

          FastlaneCore::ConfigItem.new(key: :dsym,
                                  env_name: "APPCENTER_DISTRIBUTE_DSYM",
                               description: "Path to your symbols file. For iOS provide path to app.dSYM.zip",
                             default_value: Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH],
                                  optional: true,
                                      type: String,
                              verify_block: proc do |value|
                                deprecated_files = [".txt"]
                                if value
                                  UI.user_error!("Couldn't find dSYM file at path '#{value}'") unless File.exist?(value)
                                  UI.message("Support for *.txt has been deprecated. Please use --mapping parameter or APPCENTER_DISTRIBUTE_ANDROID_MAPPING environment variable instead.") if deprecated_files.include? File.extname(value)
                                end
                              end),

          FastlaneCore::ConfigItem.new(key: :upload_dsym_only,
                                  env_name: "APPCENTER_DISTRIBUTE_UPLOAD_DSYM_ONLY",
                               description: "Flag to upload only the dSYM file to App Center",
                                  optional: true,
                                 is_string: false,
                             default_value: false),

          FastlaneCore::ConfigItem.new(key: :mapping,
                                  env_name: "APPCENTER_DISTRIBUTE_ANDROID_MAPPING",
                               description: "Path to your Android mapping.txt",
                               default_value: (defined? SharedValues::GRADLE_MAPPING_TXT_OUTPUT_PATH) && Actions.lane_context[SharedValues::GRADLE_MAPPING_TXT_OUTPUT_PATH] || nil,
                                  optional: true,
                                      type: String,
                              verify_block: proc do |value|
                                accepted_formats = [".txt"]
                                if value
                                  UI.user_error!("Couldn't find mapping file at path '#{value}'") unless File.exist?(value)
                                  UI.user_error!("Only \"*.txt\" formats are allowed, you provided \"#{File.name(value)}\"") unless accepted_formats.include? File.extname(value)
                                end
                              end),

          FastlaneCore::ConfigItem.new(key: :upload_mapping_only,
                                  env_name: "APPCENTER_DISTRIBUTE_UPLOAD_ANDROID_MAPPING_ONLY",
                               description: "Flag to upload only the mapping.txt file to App Center",
                                  optional: true,
                                 is_string: false,
                             default_value: false),

          FastlaneCore::ConfigItem.new(key: :group,
                                  env_name: "APPCENTER_DISTRIBUTE_GROUP",
                               description: "Comma separated list of Distribution Group names",
                                  optional: true,
                                      type: String,
                                deprecated: true,
                              verify_block: proc do |value|
                                UI.user_error!("Option `group` is deprecated. Use `destinations` and `destination_type`")
                              end),

          FastlaneCore::ConfigItem.new(key: :destinations,
                                  env_name: "APPCENTER_DISTRIBUTE_DESTINATIONS",
                               description: "Comma separated list of destination names, use '*' for all distribution groups if destination type is 'group'. Both distribution groups and stores are supported. All names are required to be of the same destination type",
                             default_value: Actions.lane_context[SharedValues::APPCENTER_DISTRIBUTE_DESTINATIONS] || "Collaborators",
                                  optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :destination_type,
                                  env_name: "APPCENTER_DISTRIBUTE_DESTINATION_TYPE",
                               description: "Destination type of distribution destination. 'group' and 'store' are supported",
                             default_value: "group",
                                  optional: true,
                                      type: String,
                              verify_block: proc do |value|
                                UI.user_error!("No or incorrect destination type given. Use 'group' or 'store'") unless value && !value.empty? && ["group", "store"].include?(value)
                              end),

          FastlaneCore::ConfigItem.new(key: :mandatory_update,
                                  env_name: "APPCENTER_DISTRIBUTE_MANDATORY_UPDATE",
                               description: "Require users to update to this release. Ignored if destination type is 'store'",
                                  optional: true,
                                 is_string: false,
                             default_value: false),

          FastlaneCore::ConfigItem.new(key: :notify_testers,
                                  env_name: "APPCENTER_DISTRIBUTE_NOTIFY_TESTERS",
                               description: "Send email notification about release. Ignored if destination type is 'store'",
                                  optional: true,
                                 is_string: false,
                             default_value: false),

          FastlaneCore::ConfigItem.new(key: :release_notes,
                                  env_name: "APPCENTER_DISTRIBUTE_RELEASE_NOTES",
                               description: "Release notes",
                             default_value: Actions.lane_context[SharedValues::FL_CHANGELOG] || "No changelog given",
                                  optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :should_clip,
                                  env_name: "APPCENTER_DISTRIBUTE_RELEASE_NOTES_CLIPPING",
                               description: "Clip release notes if its length is more then #{Constants::MAX_RELEASE_NOTES_LENGTH}, true by default",
                                  optional: true,
                                 is_string: false,
                             default_value: true),

          FastlaneCore::ConfigItem.new(key: :release_notes_link,
                                  env_name: "APPCENTER_DISTRIBUTE_RELEASE_NOTES_LINK",
                               description: "Additional release notes link",
                                  optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :build_number,
                                       env_name: "APPCENTER_DISTRIBUTE_BUILD_NUMBER",
                                       description: "The build number, required for macOS .pkg and .dmg builds, as well as Android ProGuard `mapping.txt` when using `upload_mapping_only`",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :version,
                                       env_name: "APPCENTER_DISTRIBUTE_VERSION",
                                       description: "The build version, required for .pkg, .dmg, .zip and .msi builds, as well as Android ProGuard `mapping.txt` when using `upload_mapping_only`",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :timeout,
                                       env_name: "APPCENTER_DISTRIBUTE_TIMEOUT",
                                       description: "Request timeout in seconds",
                                       optional: true,
                                       type: Integer),

          FastlaneCore::ConfigItem.new(key: :dsa_signature,
                                       env_name: "APPCENTER_DISTRIBUTE_DSA_SIGNATURE",
                                       description: "DSA signature of the macOS or Windows release for Sparkle update feed",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :strict,
                                       env_name: "APPCENTER_STRICT_MODE",
                                       description: "Strict mode, set to 'true' to fail early in case a potential error was detected",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.output
        [
          ['APPCENTER_DOWNLOAD_LINK', 'The newly generated download link for this build'],
          ['APPCENTER_BUILD_INFORMATION', 'contains all keys/values from the App Center API']
        ]
      end

      def self.is_supported?(platform)
        return Constants::SUPPORTED_EXTENSIONS.keys.include?(platform) if Options.strict

        true
      end

      def self.example_code
        [
          'appcenter_upload(
            api_token: "...",
            owner_name: "appcenter_owner",
            app_name: "testing_android_app",
            file: "./app-release.apk",
            destinations: "Testers",
            destination_type: "group",
            mapping: "./mapping.txt",
            release_notes: "release notes",
            notify_testers: false
          )',
          'appcenter_upload(
            api_token: "...",
            owner_name: "appcenter_owner",
            app_name: "testing_ios_app",
            file: "./app-release.ipa",
            destinations: "Testers,Public",
            destination_type: "group",
            dsym: "./app.dSYM.zip",
            release_notes: "release notes",
            notify_testers: false
          )',
          'appcenter_upload(
            api_token: "...",
            owner_name: "appcenter_owner",
            app_name: "testing_ios_app",
            file: "./app-release.ipa",
            destinations: "*",
            destination_type: "group",
            release_notes: "release notes",
            notify_testers: false
          )',
          'appcenter_upload(
            api_token: "...",
            owner_name: "appcenter_owner",
            app_name: "testing_google_play_app",
            file: "./app.aab",
            destinations: "Alpha",
            destination_type: "store",
            release_notes: "this is a store release"
          )'
        ]
      end

      class Options
        include Singleton

        def self.strict_mode(mode)
          @strict = mode.to_s == "true"
          UI.message("Enabled strict mode") if @strict
        end

        def self.strict
          @strict
        end
      end

      def self.optional_error(message)
        if Options.strict
          UI.user_error!(message)
        else
          UI.important(message)
          UI.important("The current operation might fail, trying anyway...")
        end
      end
    end
  end
end
