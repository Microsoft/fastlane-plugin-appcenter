class File
  def each_chunk(chunk_size)
    yield read(chunk_size) until eof?
  end
end

module Fastlane
  module Helper
    class AppcenterHelper

      # Time to wait between 2 status polls in seconds
      RELEASE_UPLOAD_STATUS_POLL_INTERVAL = 1

      # Maximum number of retries for a request
      MAX_REQUEST_RETRIES = 2

      # Delay between retries in seconds
      REQUEST_RETRY_INTERVAL = 5

      # basic utility method to check file types that App Center will accept,
      # accounting for file types that can and should be zip-compressed
      # before they are uploaded
      def self.file_extname_full(path)
        %w(.app.zip .dSYM.zip).each do |suffix|
          return suffix if path.to_s.downcase.end_with? suffix.downcase
        end

        File.extname path
      end

      # create request
      def self.connection(upload_url = nil, dsym = false, csv = false)
        require 'faraday'
        require 'faraday_middleware'

        default_api_url = "https://api.appcenter.ms"
        if ENV['APPCENTER_ENV']&.upcase == 'INT'
          default_api_url = "https://api-gateway-core-integration.dev.avalanch.es"
        end
        options = {
          url: upload_url || default_api_url
        }

        UI.message("DEBUG: BASE URL #{options[:url]}") if ENV['DEBUG']

        Faraday.new(options) do |builder|
          if upload_url
            builder.request :multipart unless dsym
            builder.request :url_encoded unless dsym
          else
            builder.request :json
          end
          builder.response :json, content_type: /\bjson$/ unless csv
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      # creates new release upload
      # returns:
      # upload_id
      # upload_url
      def self.create_release_upload(api_token, owner_name, app_name, body)
        connection = self.connection
        url = "v0.1/apps/#{owner_name}/#{app_name}/uploads/releases"
        body ||= {}

        UI.message("DEBUG: POST #{url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body: #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']
        response = connection.post(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']
        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        when 500...600
          UI.abort_with_message!("Internal Service Error, please try again later")
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # creates new mapping upload in appcenter
      # returns:
      # symbol_upload_id
      # upload_url
      # expiration_date
      def self.create_mapping_upload(api_token, owner_name, app_name, file_name, build_number, version)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/symbol_uploads"
        body = {
          symbol_type: "AndroidProguard",
          file_name: file_name,
          build: build_number,
          version: version,
        }

        UI.message("DEBUG: POST #{url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.post(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # creates new dSYM upload in appcenter
      # returns:
      # symbol_upload_id
      # upload_url
      # expiration_date
      def self.create_dsym_upload(api_token, owner_name, app_name)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/symbol_uploads"
        body = {
          symbol_type: 'Apple'
        }

        UI.message("DEBUG: POST #{url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.post(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # commits or aborts symbol upload
      def self.update_symbol_upload(api_token, owner_name, app_name, symbol_upload_id, status)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/symbol_uploads/#{symbol_upload_id}"
        body = {
          status: status
        }

        UI.message("DEBUG: PATCH #{url}") if ENV['DEBUG']
        UI.message("DEBUG: PATCH body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.patch(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # upload symbol (dSYM or mapping) files to specified upload url
      # if succeed, then commits the upload
      # otherwise aborts
      def self.upload_symbol(api_token, owner_name, app_name, symbol, symbol_type, symbol_upload_id, upload_url)
        connection = self.connection(upload_url, true)

        UI.message("DEBUG: PUT #{upload_url}") if ENV['DEBUG']
        UI.message("DEBUG: PUT body <data>\n") if ENV['DEBUG']

        response = connection.put do |req|
          req.headers['x-ms-blob-type'] = "BlockBlob"
          req.headers['Content-Length'] = File.size(symbol).to_s
          req.headers['internal-request-source'] = "fastlane"
          req.body = Faraday::UploadIO.new(symbol, 'application/octet-stream') if symbol && File.exist?(symbol)
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        log_type = "dSYM" if symbol_type == "Apple"
        log_type = "mapping" if symbol_type == "Android"

        case response.status
        when 200...300
          self.update_symbol_upload(api_token, owner_name, app_name, symbol_upload_id, 'committed')
          UI.success("#{log_type} uploaded")
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error uploading #{log_type} #{response.status}: #{response.body}")
          self.update_symbol_upload(api_token, owner_name, app_name, symbol_upload_id, 'aborted')
          UI.error("#{log_type} upload aborted")
          false
        end
      end

      # sets metadata for new upload in App Center
      # returns:
      # chunk size
      def self.set_release_upload_metadata(set_metadata_url, api_token, owner_name, app_name, upload_id, timeout)
        connection = self.connection(set_metadata_url)

        UI.message("DEBUG: POST #{set_metadata_url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body <data>\n") if ENV['DEBUG']
        response = connection.post do |req|
          req.options.timeout = timeout
          req.headers['internal-request-source'] = "fastlane"
        end
        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          chunk_size = response.body['chunk_size']
          unless chunk_size.is_a? Integer
            UI.error("Set metadata didn't return chunk size: #{response.status}: #{response.body}")
            false
          else
            UI.message("Metadata set")
            chunk_size
          end
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error setting metadata: #{response.status}: #{response.body}")
          false
        end
      end

      # Verifies a successful upload to App Center
      # returns:
      # successful upload response body.
      def self.finish_release_upload(finish_url, api_token, owner_name, app_name, upload_id, timeout)
        connection = self.connection(finish_url)

        UI.message("DEBUG: POST #{finish_url}") if ENV['DEBUG']
        response = connection.post do |req|
          req.options.timeout = timeout
          req.headers['internal-request-source'] = "fastlane"
        end
        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          if response.body['error'] == false
            UI.message("Upload finished")
            self.update_release_upload(api_token, owner_name, app_name, upload_id, 'uploadFinished')
          else
            UI.error("Error finishing upload: #{response.body['message']}")
            false
          end
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error finishing upload: #{response.status}: #{response.body}")
          false
        end
      end

      # upload binary for specified upload_url
      # if succeed, then commits the release
      # otherwise aborts
      def self.upload_build(api_token, owner_name, app_name, file, upload_id, upload_url, content_type, chunk_size, timeout)
        block_number = 1

        File.open(file).each_chunk(chunk_size) do |chunk|
          upload_chunk_url = "#{upload_url}&block_number=#{block_number}"
          retries = 0

          while retries <= MAX_REQUEST_RETRIES
            begin
              connection = self.connection(upload_chunk_url, true)

              UI.message("DEBUG: POST #{upload_chunk_url}") if ENV['DEBUG']
              UI.message("DEBUG: POST body <data>\n") if ENV['DEBUG']
              response = connection.post do |req|
                req.options.timeout = timeout
                req.headers['internal-request-source'] = "fastlane"
                req.headers['Content-Length'] = chunk.length.to_s
                req.headers['Content-Type'] = 'application/octet-stream'
                req.body = chunk
              end
              UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']
              status = response.status
              message = response.body
            rescue Faraday::Error => e

              # Low level HTTP errors, we will retry them
              status = 0
              message = e.message
            end

            case status
            when 200...300
              if response.body['error'] == false
                UI.message("Chunk uploaded")
                block_number += 1
                break
              else
                UI.error("Error uploading binary #{response.body['message']}")
                return false
              end
            when 401
              UI.user_error!("Auth Error, provided invalid token")
              return false
            when 400...407, 409...428, 430...499
              UI.user_error!("Client error: #{response.status}: #{response.body}")
              return false
            else
              if retries < MAX_REQUEST_RETRIES
                UI.message("DEBUG: Retryable error uploading binary #{status}: #{message}")
                retries += 1
                sleep(REQUEST_RETRY_INTERVAL)
              else
                UI.error("Error uploading binary #{status}: #{message}")
                return false
              end
            end
          end
        end
        UI.message("Binary uploaded")
      end

      # Commits or aborts the upload process for a release
      def self.update_release_upload(api_token, owner_name, app_name, upload_id, status)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/uploads/releases/#{upload_id}"
        body = {
          upload_status: status,
          id: upload_id
        }

        UI.message("DEBUG: PATCH #{url}") if ENV['DEBUG']
        UI.message("DEBUG: PATCH body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.patch(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 500...600
          UI.abort_with_message!("Internal Service Error, please try again later")
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      # get existing release
      def self.get_release(api_token, owner_name, app_name, release_id)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/releases/#{release_id}"

        UI.message("DEBUG: GET #{url}") if ENV['DEBUG']

        response = connection.get(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          release = response.body
          release
        when 404
          UI.error("Not found, invalid release url")
          false
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error fetching information about release #{response.status}: #{response.body}")
          false
        end
      end

      # Polls the upload for a release id. When a release is uploaded, we have to check
      # for a successful extraction before we can continue.
      # returns:
      # release_distinct_id
      def self.poll_for_release_id(api_token, url)
        connection = self.connection

        while true
          UI.message("DEBUG: GET #{url}") if ENV['DEBUG']
          response = connection.get(url) do |req|
            req.headers['X-API-Token'] = api_token
            req.headers['internal-request-source'] = "fastlane"
          end

          UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

          case response.status
          when 200...300
            case response.body['upload_status']
            when "readyToBePublished"
              return response.body['release_distinct_id']
            when "error"
              UI.error("Error fetching release: #{response.body['error_details']}")
              return false
            else
              sleep(RELEASE_UPLOAD_STATUS_POLL_INTERVAL)
            end
          else
            UI.error("Error fetching information about release #{response.status}: #{response.body}")
            return false
          end
        end
      end

      # get distribution group or store
      def self.get_destination(api_token, owner_name, app_name, destination_type, destination_name)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/distribution_#{destination_type}s/#{ERB::Util.url_encode(destination_name)}"

        UI.message("DEBUG: GET #{url}") if ENV['DEBUG']

        response = connection.get(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          destination = response.body
          destination
        when 404
          UI.error("Not found, invalid distribution #{destination_type} name")
          false
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error getting #{destination_type} #{response.status}: #{response.body}")
          false
        end
      end

      # add release to destination
      def self.update_release(api_token, owner_name, app_name, release_id, release_notes = '')
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/releases/#{release_id}"
        body = {
          release_notes: release_notes
        }

        UI.message("DEBUG: PUT #{url}") if ENV['DEBUG']
        UI.message("DEBUG: PUT body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.put(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          # get full release info
          release = self.get_release(api_token, owner_name, app_name, release_id)
          return false unless release

          download_url = release['download_url']

          Actions.lane_context[Fastlane::Actions::SharedValues::APPCENTER_DOWNLOAD_LINK] = download_url
          Actions.lane_context[Fastlane::Actions::SharedValues::APPCENTER_BUILD_INFORMATION] = release

          UI.message("Release '#{release_id}' (#{release['short_version']}) was successfully updated")

          release
        when 404
          UI.error("Not found, invalid release id")
          false
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error adding updating release #{response.status}: #{response.body}")
          false
        end
      end

      # updates release metadata
      def self.update_release_metadata(api_token, owner_name, app_name, release_id, dsa_signature = '', ed_signature = '')
        return if dsa_signature.to_s == '' && ed_signature.to_s == ''

        url = "v0.1/apps/#{owner_name}/#{app_name}/releases/#{release_id}"
        body = {
          metadata: {}
        }

        if dsa_signature.to_s != ''
          body[:metadata]["dsa_signature"] = dsa_signature
        end
        if ed_signature.to_s != ''
          body[:metadata]["ed_signature"] = ed_signature
        end

        UI.message("DEBUG: PATCH #{url}") if ENV['DEBUG']
        UI.message("DEBUG: PATCH body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        connection = self.connection
        response = connection.patch(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          UI.message("Release Metadata was successfully updated for release '#{release_id}'")
        when 404
          UI.error("Not found, invalid release id")
          false
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error adding updating release metadata #{response.status}: #{response.body}")
          false
        end
      end

      # add release to distribution group or store
      def self.add_to_destination(api_token, owner_name, app_name, release_id, destination_type, destination_id, mandatory_update = false, notify_testers = false)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}/releases/#{release_id}/#{destination_type}s"
        body = {
          id: destination_id
        }

        if destination_type == "group"
          body["mandatory_update"] = mandatory_update
          body["notify_testers"] = notify_testers
        end

        UI.message("DEBUG: POST #{url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.post(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          # get full release info
          release = self.get_release(api_token, owner_name, app_name, release_id)
          return false unless release

          download_url = release['download_url']

          Actions.lane_context[Fastlane::Actions::SharedValues::APPCENTER_DOWNLOAD_LINK] = download_url
          Actions.lane_context[Fastlane::Actions::SharedValues::APPCENTER_BUILD_INFORMATION] = release

          UI.message("Release '#{release_id}' (#{release['short_version']}) was successfully distributed'")

          release
        when 404
          UI.error("Not found, invalid distribution #{destination_type} name")
          false
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error adding to #{destination_type} #{response.status}: #{response.body}")
          false
        end
      end

      # returns the app if it exists, false in case of 404 and error otherwise
      def self.get_app(api_token, owner_name, app_name)
        connection = self.connection

        url = "v0.1/apps/#{owner_name}/#{app_name}"

        UI.message("DEBUG: GET #{url}") if ENV['DEBUG']

        response = connection.get(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          UI.message("DEBUG: #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']
          response.body
        when 404
          UI.message("DEBUG: #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']
          false
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error getting app #{owner_name}/#{app_name}, #{response.status}: #{response.body}")
          false
        end
      end

      # returns true if app exists, false in case of 404 and error otherwise
      def self.create_app(api_token, owner_type, owner_name, app_name, app_display_name, os, platform)
        connection = self.connection

        url = owner_type == "user" ? "v0.1/apps" : "v0.1/orgs/#{owner_name}/apps"
        body = {
          display_name: app_display_name,
          name: app_name,
          os: os,
          platform: platform
        }

        UI.message("DEBUG: POST #{url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.post(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          created = response.body
          UI.success("Created #{os}/#{platform} app with name \"#{created['name']}\" and display name \"#{created['display_name']}\" for #{owner_type} \"#{owner_name}\"")
          created
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        else
          UI.error("Error creating app #{response.status}: #{response.body}")
          false
        end
      end

      def self.fetch_distribution_groups(api_token:, owner_name:, app_name:)
        connection = self.connection

        url = "/v0.1/apps/#{owner_name}/#{app_name}/distribution_groups"

        UI.message("DEBUG: GET #{url}") if ENV['DEBUG']

        response = connection.get(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      def self.fetch_devices(api_token:, owner_name:, app_name:, distribution_group:)
        connection = self.connection(nil, false, true)

        url = "/v0.1/apps/#{owner_name}/#{app_name}/distribution_groups/#{ERB::Util.url_encode(distribution_group)}/devices/download_devices_list"

        UI.message("DEBUG: GET #{url}") if ENV['DEBUG']

        response = connection.get(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          response.body
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner, application or distribution group name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      def self.fetch_releases(api_token:, owner_name:, app_name:)
        connection = self.connection(nil, false, true)

        url = "/v0.1/apps/#{owner_name}/#{app_name}/releases"

        UI.message("DEBUG: GET #{url}") if ENV['DEBUG']

        response = connection.get(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          JSON.parse(response.body)
        when 401
          UI.user_error!("Auth Error, provided invalid token")
          false
        when 404
          UI.error("Not found, invalid owner or application name")
          false
        else
          UI.error("Error #{response.status}: #{response.body}")
          false
        end
      end

      def self.get_release_url(owner_type, owner_name, app_name, release_id)
        owner_path = owner_type == "user" ? "users/#{owner_name}" : "orgs/#{owner_name}"
        if ENV['APPCENTER_ENV']&.upcase == 'INT'
          return "https://portal-server-core-integration.dev.avalanch.es/#{owner_path}/apps/#{app_name}/distribute/releases/#{release_id}"
        end

        return "https://appcenter.ms/#{owner_path}/apps/#{app_name}/distribute/releases/#{release_id}"
      end

      def self.get_install_url(owner_type, owner_name, app_name)
        owner_path = owner_type == "user" ? "users/#{owner_name}" : "orgs/#{owner_name}"
        if ENV['APPCENTER_ENV']&.upcase == 'INT'
          return "https://install.portal-server-core-integration.dev.avalanch.es/#{owner_path}/apps/#{app_name}"
        end

        return "https://install.appcenter.ms/#{owner_path}/apps/#{app_name}"
      end

      # add new created app to existing distribution group
      def self.add_new_app_to_distribution_group(api_token:, owner_name:, app_name:, destination_name:)
        url = URI.escape("/v0.1/orgs/#{owner_name}/distribution_groups/#{destination_name}/apps")
        body = {
          apps: [
            { name: app_name }
          ]
        }

        UI.message("DEBUG: POST #{url}") if ENV['DEBUG']
        UI.message("DEBUG: POST body #{JSON.pretty_generate(body)}\n") if ENV['DEBUG']

        response = connection.post(url) do |req|
          req.headers['X-API-Token'] = api_token
          req.headers['internal-request-source'] = "fastlane"
          req.body = body
        end

        UI.message("DEBUG: #{response.status} #{JSON.pretty_generate(response.body)}\n") if ENV['DEBUG']

        case response.status
        when 200...300
          created = response.body
          UI.success("Added new app #{app_name} to distribution group #{destination_name}")
        when 401
          UI.user_error!("Auth Error, provided invalid token")
        when 404
          UI.error("Not found, invalid distribution group name #{destination_name}")
        when 409
          UI.success("App already added to distribution group #{destination_name}")
        else
          UI.error("Error adding app to distribution group #{response.status}: #{response.body}")
        end
      end
    end
  end
end
