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

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

Upload verified iOS IPA to TestFlight (never rebuilds)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload and sync App Store metadata and screenshots

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```

Submit App Store Version 1.0.0 for Review

### ios check_status

```sh
[bundle exec] fastlane ios check_status
```

Check App Store Connect Status

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Legacy local build and upload lane

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
