# Fastlane Publishing Assets

This folder contains App Store metadata, iPhone/iPad screenshot assets, and
fastlane lanes for TabletBasic.

## Before Uploading

Copy or rename the `.example` files to the matching `.txt` names and replace
the placeholder values with real public values:

- `fastlane/metadata/en-US/support_url.txt`
- `fastlane/metadata/en-US/marketing_url.txt`, optional
- `fastlane/metadata/en-US/privacy_url.txt`, if required for the final listing
- `fastlane/metadata/review_information/*.txt`, if submitting for review

Do not commit App Store Connect API keys, Apple ID passwords, or signing
certificates.

## Regenerate Assets

```sh
python3 fastlane/scripts/generate_store_assets.py
```

Or, after installing fastlane:

```sh
bundle install
bundle exec fastlane ios screenshots
```

## Upload Metadata And Screenshots

Set the required account/team environment variables first:

```sh
export FASTLANE_APPLE_ID="you@example.com"
export FASTLANE_TEAM_ID="TEAMID1234"
export FASTLANE_ITC_TEAM_ID="123456789"
```

Then upload the store listing assets without uploading a binary:

```sh
bundle exec fastlane ios upload_store_assets
```

The `release` lane builds and uploads the binary, metadata, and screenshots, but
it does not submit the app for review automatically.
