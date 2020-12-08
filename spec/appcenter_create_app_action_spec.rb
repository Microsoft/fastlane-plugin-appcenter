require_relative 'appcenter_stub'

describe Fastlane::Actions::AppcenterCreateAppAction do
  describe '#run' do
    before :each do
      allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
    end

    context "check the correct errors are raised" do
      it 'raises an error when no api token is given' do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_create_app(
              owner_name: 'owner-name',
              owner_type: 'organization',
              app_name: 'App-Name'
            )
          end").runner.execute(:test)
        end.to raise_error("No API token for App Center given, pass using `api_token: 'token'`")
      end
      it 'raises an error when there is an existing app' do
        expect do
          stub_check_app(200, 'App-Name', 'owner-name')
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_create_app(
              api_token: '1234',
              owner_type: 'organization',
              owner_name: 'owner-name',
              app_name: 'App-Name',
              app_display_name: 'display name',
              app_os: 'iPhone',
              app_platform: 'Objective-C-Swift',
            )
          end").runner.execute(:test)
        end.to raise_error("An app named 'App-Name' owned by owner-name already existed")
      end
      it 'raises an error when app creation fails' do
        expect do
          stub_create_app(400, 'App-Name', 'display name', 'iPhone', 'Objective-C-Swift', 'organization', 'owner-name', 'a secret value')
          stub_check_app(404, 'App-Name', 'owner-name')
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_create_app(
              api_token: '1234',
              owner_type: 'organization',
              owner_name: 'owner-name',
              app_name: 'App-Name',
              app_display_name: 'display name',
              app_os: 'iPhone',
              app_platform: 'Objective-C-Swift',
              error_on_create_existing: false
            )
          end").runner.execute(:test)
        end.to raise_error("Unable to create 'App-Name' owned by owner-name")
      end
    end

    context "when no errors are expected" do
      before :each do
        stub_create_app(200, 'App-Name', 'display name', 'iPhone', 'Objective-C-Swift', 'organization', 'owner-name', 'a secret value')
      end
      context "with no existing app" do
        let(:version) do
          stub_check_app(404, 'App-Name', 'owner-name')
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_create_app(
              api_token: '1234',
              owner_type: 'organization',
              owner_name: 'owner-name',
              app_name: 'App-Name',
              app_display_name: 'display name',
              app_os: 'iPhone',
              app_platform: 'Objective-C-Swift'
            )
          end").runner.execute(:test)
        end

        it 'returns the correct app' do
          puts version
          expect(version["name"]).to eq('App-Name')
        end
      end

      context "with existing app and :error_on_create_existing false" do
        let(:version) do
          stub_check_app(200, 'App-Name', 'owner-name')
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_create_app(
              api_token: '1234',
              owner_type: 'organization',
              owner_name: 'owner-name',
              app_name: 'App-Name',
              app_display_name: 'display name',
              app_os: 'iPhone',
              app_platform: 'Objective-C-Swift',
              error_on_create_existing: false
            )
          end").runner.execute(:test)
        end

        it 'returns the correct app' do
          puts version
          expect(version["name"]).to eq('App-Name')
        end
      end

      context "with valid parameters and no existing app" do
        let(:version) do
          stub_check_app(404, 'App-Name', 'owner-name')
          Fastlane::FastFile.new.parse("lane :test do
            appcenter_create_app(
              api_token: '1234',
              owner_type: 'organization',
              owner_name: 'owner-name',
              app_name: 'App-Name',
              app_display_name: 'display name',
              app_os: 'iPhone',
              app_platform: 'Objective-C-Swift',
            )
          end").runner.execute(:test)
        end

        it 'returns the correct app' do
          puts version
          expect(version["app_secret"]).to eq('a secret value')
          expect(version["display_name"]).to eq('display name')
          expect(version["os"]).to eq('iPhone')
          expect(version["platform"]).to eq('Objective-C-Swift')
        end
      end
    end
  end
end
