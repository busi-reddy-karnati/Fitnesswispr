# SpotRep — Public Beta (TestFlight)

This document holds the metadata used for TestFlight external (public) testing
and the steps to publish a public link. The automation lives in
`ios/fastlane/Fastfile` (`public_beta` and `public_beta_status` lanes).

## Beta App Description (shown to testers)

> SpotRep is the fastest way to log your lifts. Record a set by voice ("bench
> 3x10 at 135"), by typing, or by importing a spreadsheet or photo of an old
> log. See your training consistency at a glance, tap a muscle to see what to
> train next, and share progress with a spotter who can view — or log on your
> behalf. No account required; optional Sign in with Apple backs up and syncs
> your data.

## What to Test (build notes)

> Thanks for testing SpotRep! Please try:
> - Logging a workout by voice, by typing, and by importing a spreadsheet/photo
> - Editing and deleting a workout, and changing a workout's date
> - The consistency heatmap and tapping a day / a muscle group
> - Adding a spotter (share invite), and revoking / stopping spotting
> - Exporting your workouts to CSV/Excel
>
> Send feedback with the screenshot/annotate tool in TestFlight, or email us.
> Known: AI parsing of unusual formats may need a clarifying tap.

## Required for Beta App Review (provide these)

- **Feedback email** — where tester feedback is sent.
- **Contact info** — first name, last name, email, phone (Apple review contact).
- **Privacy Policy URL** — publish `docs/PRIVACY.md` via GitHub Pages, e.g.
  `https://ishiki-labs.github.io/Fitnesswispr/PRIVACY` (enable Pages from the
  `docs/` folder on the default branch), then fill the contact email in
  `PRIVACY.md`.
- **Demo account** — not required (the app works anonymously).
- **Export compliance** — already declared (`ITSAppUsesNonExemptEncryption =
  false`); builds clear automatically.

## Publish steps

1. Fill in the env vars (see Fastfile `public_beta`) and the privacy URL.
2. `cd ios && fastlane public_beta` — creates the external "Public Beta" group
   with a public link, sets Test Information + review contact, attaches the
   latest valid build, and submits it for Beta App Review.
3. After Apple approves (usually < 24h), `fastlane public_beta_status` prints the
   shareable public link.
