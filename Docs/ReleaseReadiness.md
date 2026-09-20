# Release readiness

Release candidate 1.0.0 (1) is prepared. These checks do not guarantee App Review approval.

- [x] Registered app and widget identifiers plus App Group under team `5G2JU987CA`; signed archive succeeded September 20, 2026. App and widget both verified as 1.0.0 (1).
- [x] Installed the approved frying-pan/sun-egg icon as an opaque 1024 × 1024 asset.
- [x] Re-ran all 32 macOS tests and 34 iOS simulator tests successfully.
- [x] Verified bundled icons, privacy manifests, shared App Group entitlement, and matching archive versions.
- [x] Owner decision: keep the inherited vitamin D estimates for the first release and defer further scientific review. Their unvalidated status remains explicit in the app, methodology, and listing. No synthesized estimates are written to Health. This decision does not establish scientific validation or Apple approval.
- [x] Checked Open-Meteo's current non-commercial terms and limits; see `AppStoreSubmission.md`. The app is free with no advertising or subscriptions. Capacity must be reassessed before a large rollout.
- [x] Apple accepted the owner-approved listing name “Fry Day: Sun & UV Timer” (app ID `6814111734`). Installed app name remains Fry Day. Name acceptance is not trademark clearance.
- [x] Published privacy/methodology/support documents on the default branch and verified their links (PR #1 merged).
- [ ] Upload the signed build, verify processing/compliance, and assign a Fry Day internal tester group. Do not copy Mumblers testers.
- [ ] Real-device functional checks: Lock Screen/Dynamic Island, End link, disabled permissions, Focus, travel, offline recovery, force-quit recovery, and battery. Direct installation currently reports that the paired iPhone is locked; use TestFlight or retry while it stays awake.
- [ ] VoiceOver, Dynamic Type, and small-screen checks.
- [ ] Store screenshots, privacy answers, age rating, support/review contact, free pricing, territories, and any required trader-status declaration.
- [ ] Final listing and device-test review before public App Store submission.

See [submission copy](AppStoreSubmission.md), [TestFlight workflow](TestFlightRelease.md), and [device beta checklist](DeviceTestChecklist.md).
