def stub_fetch_distribution_groups(owner_name:, app_name:, groups: ["Collaborators", "test-group-1", "test group 2"])
  body = groups.map { |g| { name: g } }
  stub_request(:get, "https://api.appcenter.ms/v0.1/apps/#{owner_name}/#{app_name}/distribution_groups")
    .to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: body.to_json
    )
end

def stub_fetch_devices(owner_name:, app_name:, distribution_group:)
  stub_request(:get, "https://api.appcenter.ms/v0.1/apps/#{owner_name}/#{app_name}/distribution_groups/#{ERB::Util.url_encode(distribution_group)}/devices/download_devices_list")
    .to_return(
      status: 200,
      headers: { 'Content-Type' => 'text/csv; charset=utf-8' },
      body: "Device ID\tDevice Name\n
      1234567890abcdefghij1234567890abcdefghij\tDevice 1 - iPhone X\n
      abcdefghij1234567890abcdefghij1234567890\tDevice 2 - iPhone XS\n"
    )
end

def stub_check_app(status, app_name = "app", owner_name = "owner")
  success_json = JSON.parse(format(
                              File.read("spec/fixtures/apps/valid_app_response.json"),
                              app_name: app_name, owner_name: owner_name
                            ))
  stub_request(:get, "https://api.appcenter.ms/v0.1/apps/#{owner_name}/#{app_name}")
    .to_return(
      status: status,
      body: success_json.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

# rubocop:disable Metrics/ParameterLists
def stub_create_app(status, app_name = "app", app_display_name = "app", app_os = "Android", app_platform = "Java", owner_type = "user", owner_name = "owner", app_secret = "app_secret")
  stub_request(:post, owner_type == "user" ? "https://api.appcenter.ms/v0.1/apps" : "https://api.appcenter.ms/v0.1/orgs/#{owner_name}/apps")
    .with(
      body: "{\"display_name\":\"#{app_display_name}\",\"name\":\"#{app_name}\",\"os\":\"#{app_os}\",\"platform\":\"#{app_platform}\"}"
    )
    .to_return(
      status: status,
      body: "{\"display_name\":\"#{app_display_name}\",\"name\":\"#{app_name}\",\"os\":\"#{app_os}\",\"platform\":\"#{app_platform}\",\"app_secret\":\"#{app_secret}\"}",
      headers: { 'Content-Type' => 'application/json' }
    )
end
# rubocop:enable Metrics/ParameterLists
