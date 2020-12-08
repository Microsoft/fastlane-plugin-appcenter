require_relative 'appcenter_stub'

def stub_get_app_not_found(status)
  not_found_json = JSON.parse(File.read("spec/fixtures/releases/not_found.json"))
  stub_request(:get, "https://api.appcenter.ms/v0.1/apps/owner-name/App-Name")
    .to_return(status: status, body: not_found_json.to_json, headers: { 'Content-Type' => 'application/json' })
end

def stub_get_app_forbidden(status)
  forbidden_json = JSON.parse(File.read("spec/fixtures/releases/forbidden.json"))
  stub_request(:get, "https://api.appcenter.ms/v0.1/apps/owner-name/App-Name")
    .to_return(status: status, body: forbidden_json.to_json, headers: { 'Content-Type' => 'application/json' })
end

describe Fastlane::Actions::AppcenterFetchAppAction do
  describe '#run' do
    before :each do
      allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
    end

    context "check the correct errors are raised" do
      it 'raises an error when no api token is given' do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_fetch_app(
              owner_name: 'owner-name',
              app_name: 'App-Name'
            )
          end").runner.execute(:test)
        end.to raise_error("No API token for App Center given, pass using `api_token: 'token'`")
      end

      it 'raises an error when the owner/account name or API key are incorrect' do
        stub_get_app_forbidden(403)
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_fetch_app(
              api_token: '1234',
              owner_name: 'owner-name',
              app_name: 'App-Name'
            )
          end").runner.execute(:test)
        end.to raise_error("No app named 'App-Name' owned by owner-name was found")
      end

      it 'raises an error when the app name does not exist for an owner/account' do
        stub_get_app_not_found(404)
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_fetch_app(
              api_token: '1234',
              owner_name: 'owner-name',
              app_name: 'App-Name'
            )
          end").runner.execute(:test)
        end.to raise_error("No app named 'App-Name' owned by owner-name was found")
      end
    end

    context "when no errors are expected" do
      before :each do
        stub_check_app(200, 'App-Name', 'owner-name')
      end

      context "with a valid token, owner name, and app name" do
        let(:version) do
          version = Fastlane::FastFile.new.parse("lane :test do
            appcenter_fetch_app(
              api_token: '1234',
              owner_name: 'owner-name',
              app_name: 'App-Name'
            )
          end").runner.execute(:test)
        end

        it 'returns the correct version number' do
          puts version
          expect(version["id"]).to eq('aaaaaaaa-1111-1aa1-1aa1-1111aaaa1111')
          expect(version["app_secret"]).to eq('aaaaaaaa-1111-1aa1-1aa1-1111aaaa1111')
          expect(version["display_name"]).to eq('My App β')
          expect(version["description"]).to eq('Beta')
          expect(version["icon_url"]).to eq('https://rink.hockeyapp.net/api/2/apps/12345?format=png')
          expect(version["platform"]).to eq('Objective-C-Swift')
        end
      end
    end
  end
end
