# Development validation

Validated September 19, 2026 with Xcode 26.6 and an iPhone 17 Pro simulator running iOS 26.2.

- All 21 deterministic tests passed on macOS (`swift test`) and iOS (`xcodebuild test`). They cover exposure intervals, forecast/settings changes, corrected end times, gaps, midnight, archive recovery, duplicate completion, save failures, and widget refresh/expiry policy.
- Simulator walkthrough confirmed the restored original home-screen layout and gradients, starting a session, a Live Activity appearing on the Lock Screen, ending the session through the app, and saving through the original-style completion sheet. The saved archive contained one completed session and no active session.
- The final app and widget compiled successfully in an unsigned Release build for generic iOS from the Fry Day project folder, with no compiler warnings or errors.
- Built app inspection confirmed the app icon, launch storyboard, Live Activities declaration, and app/extension privacy manifests are bundled.

The Lock Screen capture was partially clipped, so the complete Live Activity layout and its End link still need device testing. Actual widget refresh scheduling, notification delivery under Focus, accessibility, and small-screen layouts also require further testing. No signing, TestFlight upload, or App Store submission has been performed. See [release readiness](ReleaseReadiness.md).
