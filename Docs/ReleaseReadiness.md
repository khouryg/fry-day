# Release readiness

Release candidate 1.0.0 (4) is available to the owner in TestFlight. These checks do not guarantee App Review approval.

- [x] Registered app and widget identifiers plus App Group under team `5G2JU987CA`; signed archive succeeded September 20, 2026. App and widget both verified as 1.0.0 (3).
- [x] Installed the approved frying-pan/sun-egg icon as an opaque 1024 × 1024 asset.
- [x] Re-ran all 32 macOS tests and 34 iOS simulator tests successfully.
- [x] Verified bundled icons, privacy manifests, shared App Group entitlement, and matching archive versions.
- [x] Owner decision: keep the inherited vitamin D estimates for the first release and defer further scientific review. Their unvalidated status remains explicit in the app, methodology, and listing. The owner subsequently authorized optional export of sun-derived estimates to Health’s dietary Vitamin D category, with the mismatch disclosed. This decision does not establish scientific validation or Apple approval.
- [x] Checked Open-Meteo's current non-commercial terms and limits; see `AppStoreSubmission.md`. The app is free with no advertising or subscriptions. Capacity must be reassessed before a large rollout.
- [x] Apple accepted the owner-approved listing name “Fry Day: Sun & UV Timer” (app ID `6814111734`). Installed app name remains Fry Day. Name acceptance is not trademark clearance.
- [x] Published privacy/methodology/support documents on the default branch and verified their links (PR #1 merged).
- [x] Uploaded the corrected signed build 1.0.0 (3); processing completed and the Fry Day Internal group shows Testing. Owner is its sole tester. Build 3 processing and Testing status were verified September 20, 2026.
- [ ] Real-device functional checks: Lock Screen/Dynamic Island, End link, disabled permissions, travel, offline recovery, force-quit recovery, and battery. Direct installation currently reports that the paired iPhone is locked; use TestFlight or retry while it stays awake.
- [ ] VoiceOver, Dynamic Type, and small-screen checks.
- [ ] Store screenshots, privacy answers, age rating, support/review contact, free pricing, territories, and any required trader-status declaration.
- [ ] Final listing and device-test review before public App Store submission.

See [submission copy](AppStoreSubmission.md), [TestFlight workflow](TestFlightRelease.md), and [device beta checklist](DeviceTestChecklist.md).

## Build 4 status — September 20, 2026

- 39 iOS simulator tests passed; signed archive and upload succeeded.
- App Store Connect completed processing and the existing Fry Day Internal group shows 1.0.0 (4) as Testing, with the owner as its sole tester. Build ID: `9a88bb88-215b-4b5d-a0cb-832a44dc093e`.
- TestFlight testing notes and the draft App Store description/review notes include the best-effort warning and limitations.
- Owner previously approved build 3 appearance; build 4 physical notification checks remain.
- Three approved screenshot assets are prepared locally, but the App Store version still has zero screenshots and no selected release build. Privacy publication, age rating, pricing/availability, and any applicable trader declaration remain to finish. Review contact was previously saved; no public review submission made.

## Build 5 status — September 20, 2026

- 43 iOS simulator tests passed, including Health sample conversion and stable export identifiers.
- Signed archive and upload succeeded; app and widget both verified as 1.0.0 (5), with correct identifiers, privacy manifests, icon, App Group, and Health entitlement.
- Build `b0d89f0e-dfd9-4878-b133-b588cfdc8e78` is Testing in Fry Day Internal (one owner tester); testing notes saved.
- Three approved screenshots uploaded in home, Live Activity, history order. Draft description and review notes disclose optional Health export and its dietary-category mismatch.
- Age questionnaire saved: calculated 16+ (regional and older OS ratings vary).
- Physical Health export/duplicate/denied-permission and notification checks remain, along with final store declarations and public review submission.
