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

Apple upload and processing completed for 1.0.0 (1). App Store Connect confirms the Fry Day Internal group build status is Testing and its sole tester, the owner, is Invited. No external tester group or public release was enabled. The direct-install CoreDevice lock error remains separate from successful TestFlight availability.

## Build 2 — single-page home and Live Activity only

Removed the main ScrollView and redundant reminder controls. The original cards and gradients remain, with normal/compact spacing selected for available height. Forecast timestamps and the Live Activity explanation are available in How It Works. Removed all notification scheduling and permission requests; launch cancels legacy notification identifiers from build 1. Persisted reminderDate fields remain for decoding existing session/activity records only.

Validation: all 34 iOS tests passed. Simulator visual checks confirmed the complete home screen on iPhone 17 Pro / iOS 26.2 and iPhone SE (3rd generation) / iOS 18.5, including the denied-location and seasonal-warning state on SE. Signed Release archive succeeded with app and widget both 1.0.0 (2). Physical-device confirmation of this layout remains for the owner to perform in TestFlight.

Build 2 upload and processing completed. App Store Connect shows 1.0.0 (2) as Testing in Fry Day Internal. Build ID: `9776da65-1f2e-44cd-ad47-09122c4835a9`.

## Original Sun Day layout restoration

Restored upstream's 40-point title, 72-point UV number, 20-point card gaps and outer/card padding, and 15-point picker padding. Removed the added footer rows and moved their secondary information into How It Works. Kept Fry Day branding, corrected session behavior, estimate wording, and automatic Live Activities without notifications. Like upstream, the original-size layout can overflow on smaller screens instead of shrinking its cards; scrolling does not bounce when the content fits.

Validation: simulator build succeeded; iPhone 17 Pro visual check confirms all original-size cards fit on one page, and the existing How It Works sheet opens with forecast information and source links. No session or weather-service code changed. The restoration is packaged as 1.0.0 (3). All 34 iOS tests passed again, the signed archive succeeded, and app/widget versions, App Group entitlements, icon, and privacy manifests were checked. Apple accepted the upload and completed processing. Build 1.0.0 (3) is verified as Testing in Fry Day Internal, with the existing owner tester. Build ID: `7c96f4ae-3e59-4a4a-8fbf-4d12af2bdc38`.
