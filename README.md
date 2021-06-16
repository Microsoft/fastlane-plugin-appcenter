# App Center `fastlane` plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-appcenter)
[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-appcenter.svg)](https://badge.fury.io/rb/fastlane-plugin-appcenter)
[![Build Status](https://travis-ci.org/microsoft/fastlane-plugin-appcenter.svg?branch=master)](https://travis-ci.org/microsoft/fastlane-plugin-appcenter)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-appcenter`, add it to your project by running:

```bash
fastlane add_plugin appcenter
```

fastlane v2.96.0 or higher is required for all plugin-actions to function properly.

## About App Center
With [App Center](https://appcenter.ms) you can continuously build, test, release, and monitor your apps. This plugin provides a set of actions to interact with App Center.

`appcenter_fetch_devices` allows you to obtain the list of iOS devices to distribute an app to (useful for automatic provisioning of testers' devices).

`appcenter_upload` allows you to upload and [distribute](https://docs.microsoft.com/en-us/appcenter/distribution/uploading) apps to your testers on App Center as well as to upload .dSYM files to [collect detailed crash reports](https://docs.microsoft.com/en-us/appcenter/crashes/ios) in App Center.

`appcenter_fetch_version_number` allows you to obtain the latest version number (short or full) for an app. This is useful for tasks such as getting the latest version of an app so that an increment action can take place on CI, or checking that an upload has been successful.

`appcenter_codepush_release_react` allows you to deploy app updates via CodePush.

## Usage

To get started, first, [obtain an API token](https://appcenter.ms/settings/apitokens) in App Center. The API Token is used to authenticate with the App Center API in each call.

```ruby
appcenter_fetch_devices(
  api_token: "<appcenter token>",
  owner_name: "<appcenter account name of the owner of the app (username or organization URL name)>",
  app_name: "<appcenter app name>",
  destinations: "*", # Default is 'Collaborators', use '*' for all distribution groups
  devices_file: "devices.txt" # Default. If you customize, the extension must be .txt
)
```

```ruby
appcenter_upload(
  api_token: "<appcenter token>",
  owner_name: "<appcenter account name of the owner of the app (username or organization URL name)>",
  owner_type: "user", # Default is user - set to organization for appcenter organizations
  app_name: "<appcenter app name (as seen in app URL)>",
  file: "<path to android build binary>",
  notify_testers: true # Set to false if you don't want to notify testers of your new release (default: `false`)
)
```

```ruby
appcenter_fetch_version_number(
  api_token: "<appcenter token>",
  owner_name: "<appcenter account name of the owner of the app (username or organization URL name)>",
  app_name: "<appcenter app name (as seen in app URL)>",
  version: "a specific version to get the last release for" # optional, don't set this value to get the last upload of all versions
)
```

The `appcenter_fetch_version_number` returns a hash that contains the id, the version number, and the build number. The version corresponds to the `short_version` and the build number to the `version` known by App Center for a given release:
```ruby
{"id"=>1, "version"=>"1.0.0", "build_number"=>"1.0.0.1234"} # iOS apps contain the full version plus build number due to the way that Apple use CFBundleVersion for this value
{"id"=>588, "version"=>"1.2.0", "build_number"=>"1615"}
```

```ruby
appcenter_codepush_release_react(
  api_token: "<appcenter token>",
  owner_name: "<appcenter account name of the owner of the app (username or organization URL name)>",
  app_name: "<appcenter app name (as seen in app URL)>",
  deployment: "Staging"
)
```

### Help

Once installed, information and help for an action can be printed out with this command:

```bash
fastlane action appcenter_upload # or any action included with this plugin
```

### A note on App Name

The `app_name` and `owner_name` as set in the Fastfile come from the app's URL in App Center, in the below form:
```
https://appcenter.ms/users/{owner_name}/apps/{app_name}
```
They should not be confused with the displayed name on App Center pages, which is called `app_display_name ` instead.

### Parameters

The action parameters `api_token`, `owner_name`, `app_name`, and others can also be omitted when their values are [set as environment variables](https://docs.fastlane.tools/advanced/#environment-variables). By default, `appcenter_upload` will use the same `api_token`, `owner_name`, and `app_name` you used in `appcenter_fetch_devices`.

Here is the list of all existing parameters:

#### `appcenter_fetch_devices`

| Key & Env Var | Description |
|-----------------|--------------------|
| `api_token` <br/> `APPCENTER_API_TOKEN` | API Token for App Center |
| `owner_name` <br/> `APPCENTER_OWNER_NAME` | Owner name, as found in the App's URL in App Center |
| `destinations` <br/> `APPCENTER_DISTRIBUTE_DESTINATIONS` | Comma separated list of distribution group names. Default is 'Collaborators', use '*' for all distribution groups |
| `devices_file` <br/> `FL_REGISTER_DEVICES_FILE` | File to save the devices list to. Same environment variable as _fastlane_'s `register_devices` action |

#### `appcenter_upload`

| Key & Env Var | Description |
|-----------------|--------------------|
| `api_token` <br/> `APPCENTER_API_TOKEN` | API Token for App Center |
| `owner_type` <br/> `APPCENTER_OWNER_TYPE` | Owner type, either 'user' or 'organization' (default: `user`) |
| `owner_name` <br/> `APPCENTER_OWNER_NAME` | Owner name as found in the App's URL in App Center |
| `app_name` <br/> `APPCENTER_APP_NAME` | App name as found in the App's URL in App Center. If there is no app with such name, you will be prompted to create one |
| `app_display_name` <br/> `APPCENTER_APP_DISPLAY_NAME` | App display name to use when creating a new app |
| `app_os` <br/> `APPCENTER_APP_OS` | App OS can be Android, iOS, macOS, Windows, Custom. Used for new app creation, if app 'app_name' was not found |
| `app_platform` <br/> `APPCENTER_APP_PLATFORM` | App Platform. Used for new app creation, if app 'app_name' was not found |
| `file` <br/> `APPCENTER_DISTRIBUTE_FILE` | File path to the release build to publish |
| `upload_build_only` <br/> `APPCENTER_DISTRIBUTE_UPLOAD_BUILD_ONLY` | Flag to upload only the build to App Center. Skips uploading symbols or mapping (default: `false`) |
| `dsym` <br/> `APPCENTER_DISTRIBUTE_DSYM` | Path to your symbols file. For iOS provide path to app.dSYM.zip |
| `upload_dsym_only` <br/> `APPCENTER_DISTRIBUTE_UPLOAD_DSYM_ONLY` | Flag to upload only the dSYM file to App Center (default: `false`) |
| `mapping` <br/> `APPCENTER_DISTRIBUTE_ANDROID_MAPPING` | Path to your Android mapping.txt |
| `upload_mapping_only` <br/> `APPCENTER_DISTRIBUTE_UPLOAD_ANDROID_MAPPING_ONLY` | Flag to upload only the mapping.txt file to App Center (default: `false`) |
| `destinations` <br/> `APPCENTER_DISTRIBUTE_DESTINATIONS` | Comma separated list of destination names, use '*' for all distribution groups if destination type is 'group'. Both distribution groups and stores are supported. All names are required to be of the same destination type (default: `Collaborators`) |
| `destination_type` <br/> `APPCENTER_DISTRIBUTE_DESTINATION_TYPE` | Destination type of distribution destination. 'group' and 'store' are supported (default: `group`) |
| `mandatory_update` <br/> `APPCENTER_DISTRIBUTE_MANDATORY_UPDATE` | Require users to update to this release. Ignored if destination type is 'store' (default: `false`) |
| `notify_testers` <br/> `APPCENTER_DISTRIBUTE_NOTIFY_TESTERS` | Send email notification about release. Ignored if destination type is 'store' (default: `false`) |
| `release_notes` <br/> `APPCENTER_DISTRIBUTE_RELEASE_NOTES` | Release notes (default: `No changelog given`) |
| `should_clip` <br/> `APPCENTER_DISTRIBUTE_RELEASE_NOTES_CLIPPING` | Clip release notes if its length is more then 5000, true by default (default: `true`) |
| `release_notes_link` <br/> `APPCENTER_DISTRIBUTE_RELEASE_NOTES_LINK` | Additional release notes link |
| `build_number` <br/> `APPCENTER_DISTRIBUTE_BUILD_NUMBER` | The build number, required for macOS .pkg and .dmg builds, as well as Android ProGuard `mapping.txt` when using `upload_mapping_only` |
| `version` <br/> `APPCENTER_DISTRIBUTE_VERSION` | The build version, required for .pkg, .dmg, .zip and .msi builds, as well as Android ProGuard `mapping.txt` when using `upload_mapping_only` |
| `timeout` <br/> `APPCENTER_DISTRIBUTE_TIMEOUT` | Request timeout in seconds applied to individual HTTP requests. Some commands use multiple HTTP requests, large file uploads are also split in multiple HTTP requests |
| `dsa_signature` <br/> `APPCENTER_DISTRIBUTE_DSA_SIGNATURE` | DSA signature of the macOS or Windows release for Sparkle update feed |
| `ed_signature` <br/> `APPCENTER_DISTRIBUTE_ED_SIGNATURE` | EdDSA signature of the macOS or Windows release for Sparkle update feed |
| `strict` <br/> `APPCENTER_STRICT_MODE` | Strict mode, set to 'true' to fail early in case a potential error was detected |

#### `appcenter_fetch_version_number`

| Key & Env Var | Description |
|-----------------|--------------------|
| `api_token` <br/> `APPCENTER_API_TOKEN` | API Token for App Center |
| `owner_name` <br/> `APPCENTER_OWNER_NAME` | Owner name, as found in the App's URL in App Center |
| `app_name` <br/> `APPCENTER_APP_NAME` | App name as found in the App's URL in App Center. If there is no app with such name, you will be prompted to create one |
| `version` <br/> `APPCENTER_APP_VERSION` | App version to get the last release for instead of the last release of all versions |

#### `appcenter_codepush_release_react`
| Key & Env Var | Description |
|-----------------|--------------------|
| `api_token` <br/> `APPCENTER_API_TOKEN` | API Token for App Center |
| `owner_name` <br/> `APPCENTER_OWNER_NAME` | Owner name, as found in the App's URL in App Center |
| `app_name` <br/> `APPCENTER_APP_NAME` | App name as found in the App's URL in App Center. If there is no app with such name, you will be prompted to create one |
| `deployment` <br/> `APPCENTER_CODEPUSH_DEPLOYMENT` | Name of deployment track (default: `Staging`) |
| `target_version` <br/> `APPCENTER_CODEPUSH_TARGET_VERSION` | Target binary app version |
| `mandatory` <br/> `APPCENTER_CODEPUSH_MANDATORY` | Specifies whether the update should be mandatory (default: `true`) |
| `description` <br/> `APPCENTER_CODEPUSH_DESCRIPTION` | Description of CodePush release |
| `dry_run` <br/> `APPCENTER_CODEPUSH_DRY_RUN` | Print command that would be run, don't run it (default: `false`) |
| `disabled` <br/> `APPCENTER_CODEPUSH_DISABLED` | Specifies whether this release should not be immediately available for download (default: `false`) |
| `no_duplicate_release_error` <br/> `APPCENTER_CODEPUSH_NO_DUPLICATE_ERROR` | Specifies whether to ignore errors if bundle is identical to the latest codepush release (default: `false`) |
| `bundle_name` <br/> `APPCENTER_CODEPUSH_BUNDLE_NAME` | Specifies the name of the bundle file |
| `output_dir` <br/> `APPCENTER_CODEPUSH_OUTPUT` | Specifies path to where the bundle and sourcemap should be written |
| `sourcemap_output` <br/> `APPCENTER_CODEPUSH_SOURCEMAP_OUTPUT` | Specifies path to write sourcemaps to |
| `development` <br/> `APPCENTER_CODEPUH_DEVELOPMENT` | Specifies whether to generate dev or release build (default: `false`) |

## Example

Check out this [example `Fastfile`](fastlane/Fastfile) to see how to use the `appcenter_upload` action. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

Sample uses `.env` for setting private variables like API token, owner name, .etc. You need to replace it in `Fastfile` by your own values.

There are three examples in `test` lane:
- upload release for android with minimum required parameters
- upload release for ios with all set parameters
- upload only dSYM file for ios

Check out this [example `Fastfile`](fastlane/fetch_devices/Fastfile) for a full example of fetching devices, registering them with Apple, provisioning the devices, and signing an app.

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please open a [GitHub issue](https://github.com/microsoft/fastlane-plugin-appcenter/issues).

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

## Contributing

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Security

Check out [SECURITY.md](SECURITY.md) for any security concern with this project.

## Contact

We're on Twitter as [@vsappcenter](https://www.twitter.com/vsappcenter). Additionally you can reach out to us on the [App Center](https://appcenter.ms/apps) portal. Open the "?" menu on the top right corner of screen, then use "Contact support" to file a support ticket. Our support team is there to answer your questions and help you solve your problems.
