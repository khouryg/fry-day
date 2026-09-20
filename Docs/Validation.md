# Development validation

Validated September 19, 2026 with Xcode 26.6 and an iPhone 17 Pro simulator running iOS 26.2.

- The original 21 regression tests passed on macOS (`swift test`) and iOS (`xcodebuild test`). They cover exposure intervals, forecast/settings changes, corrected end times, gaps, midnight, archive recovery, duplicate completion, save failures, and widget refresh/expiry policy.
- Simulator walkthrough confirmed the restored original home-screen layout and gradients, starting a session, a Live Activity appearing on the Lock Screen, ending the session through the app, and saving through the original-style completion sheet. The saved archive contained one completed session and no active session.
- The final app and widget compiled successfully in an unsigned Release build for generic iOS from the Fry Day project folder, with no compiler warnings or errors.
- Built app inspection confirmed the app icon, launch storyboard, Live Activities declaration, and app/extension privacy manifests are bundled.

The Lock Screen capture was partially clipped, so the complete Live Activity layout and its End link still need device testing. Actual widget refresh scheduling, notification delivery under Focus, accessibility, and small-screen layouts also require further testing. No signing, TestFlight upload, or App Store submission has been performed. See [release readiness](ReleaseReadiness.md).

## Efficiency pass

Final verification: 32 tests passed on macOS and 34 on the iOS 26.2 simulator, including two app-coordinator tests for saved-total cache invalidation. The final unsigned iOS Release build passed without compiler warnings or errors. An initial simulator test-host launch stalled; the retry with parallel testing disabled completed successfully.

- Foreground calculation ticks run once a second only during an active session, once a minute while idle, and stop when inactive. Elapsed exposure is cached at complete integration steps; an unfinished step is recalculated with the original formula. The cache is rebuilt after changes to session inputs, corrected end times, day boundaries, or clock reversal.
- A deterministic six-hour session test shows that the following one-second tick evaluates one integration step instead of reprocessing the whole session. Every-second estimates are compared with the original calculation across an hour boundary. These are operation-count and correctness checks, not battery measurements.
- Completed daily totals are cached and invalidated on record changes and day changes. Widget snapshot writes/reloads are coalesced for synchronous state changes.
- Weather fetches reuse fresh cached forecasts on launch, keep the five-minute active-session interval, and use ten minutes while idle. UV values still advance locally through forecast samples. Automatic requests are separated by at least one minute during movement; failed requests back off by 1, 2, 4, 8, then at most 15 minutes. Manual retry bypasses backoff, and a connectivity-restored event clears it while retaining the request-burst limit.
- Coarse 1-km foreground location updates are retained to preserve travel responsiveness. Repeated starts and geocoding requests are coalesced; location stops when inactive, and delayed callbacks cannot restart it. No background location monitoring was added.
- Widget forecast timelines, Live Activities, reminders, and the visual layout retain their existing behavior.

Physical-device energy profiling and travel/network-transition checks remain necessary to quantify battery savings and validate system scheduling.

## Signed release candidate — September 20, 2026

- Re-ran all 32 macOS tests and all 34 iOS simulator tests successfully.
- Signed Release archive 1.0.0 (1) succeeded under team `5G2JU987CA`. App and widget identifiers, matching version/build, shared App Group entitlement, and both privacy manifests were verified in the archive.
- Final frying-pan/sun-egg icon verified as 1024 × 1024 with no alpha. The existing screen layout was preserved and a compact estimate label was added.
- Archive: `/private/tmp/FryDay-1.0.0-1.xcarchive`; build log: `/private/tmp/fryday-archive-1.log`.
- Direct installation on the paired iPhone reported device-locked errors, including after an unlock attempt. No physical-device functional test is claimed.

## App Store upload correction — September 20, 2026

Apple rejected the first upload with ITMS-90683 because the HealthKit entitlement/API reference requires `NSHealthUpdateUsageDescription`, even though authorization uses an empty write set. Added a truthful description stating that Fry Day does not write Health data. The authorization and UI are unchanged. Regenerated the project and successfully rebuilt the signed Release archive at `/private/tmp/FryDay-1.0.0-1-fixed.xcarchive`; verified the required key in the archived app. No new functional code was introduced.
