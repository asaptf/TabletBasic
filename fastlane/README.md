fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Regenerate local App Store screenshots and marketing assets

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload App Store metadata only (no binary, no screenshots)

### ios upload_store_assets

```sh
[bundle exec] fastlane ios upload_store_assets
```

Upload App Store metadata and screenshots only

### ios build_release

```sh
[bundle exec] fastlane ios build_release
```

Build an App Store archive

### ios upload_binary

```sh
[bundle exec] fastlane ios upload_binary
```

Build and upload App Store binary without metadata or screenshots

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload binary, metadata, and screenshots without submitting for review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
