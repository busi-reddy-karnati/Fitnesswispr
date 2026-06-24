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

### ios verify

```sh
[bundle exec] fastlane ios verify
```

Verify API credentials by listing apps

### ios poll

```sh
[bundle exec] fastlane ios poll
```

Poll until the agreement block clears

### ios setup_group

```sh
[bundle exec] fastlane ios setup_group
```

Create internal beta group and attach the latest build

### ios add_testers

```sh
[bundle exec] fastlane ios add_testers
```

Add App Store Connect users as internal testers

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload the already-built IPA to TestFlight (internal)

### ios wait_app

```sh
[bundle exec] fastlane ios wait_app
```

Wait until the app record exists

### ios status

```sh
[bundle exec] fastlane ios status
```

Show TestFlight status

### ios diag

```sh
[bundle exec] fastlane ios diag
```

Raw API diagnostic

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Create the app record on App Store Connect

### ios archive

```sh
[bundle exec] fastlane ios archive
```

Archive + export the IPA only (no upload)

### ios public_beta

```sh
[bundle exec] fastlane ios public_beta
```

Set up the external (public) TestFlight group and submit for Beta App Review

### ios invite_tester

```sh
[bundle exec] fastlane ios invite_tester
```

Invite an external tester by email to an external group (default 'Public Beta')

### ios public_beta_status

```sh
[bundle exec] fastlane ios public_beta_status
```

Print the public TestFlight link and review status

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios ci_release

```sh
[bundle exec] fastlane ios ci_release
```

CI: build + upload to TestFlight with an auto-incremented build number

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
