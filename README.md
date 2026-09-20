# Fry Day

An independent, free continuation of [Sun Day](https://github.com/jackjackbits/sunday), originally released by jackjackbits and contributors under the [Unlicense](LICENSE).

Fry Day helps you remember an outdoor sun session with a Lock Screen / Dynamic Island Live Activity and a local check-in reminder. Sessions and editable end times are saved on-device. The app also shows timestamped UV forecasts and optional modeled vitamin D estimates.

## Build

Requires Xcode 15 or newer, iOS 17+, and XcodeGen. Development is currently verified with Xcode 26.6.

```sh
xcodegen generate
open FryDay.xcodeproj
```

Choose your development team in Xcode. Register `com.khouryg.fryday`, `com.khouryg.fryday.widget`, and `group.com.khouryg.fryday` with that team before device signing. Set a different identifier prefix throughout the project if you are publishing your own derivative. No upstream signing team is embedded.

```sh
swift test
xcodebuild -project FryDay.xcodeproj -scheme FryDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The Swift package runs deterministic exposure/persistence regression tests on macOS. The same tests also run in the iOS test target. Generated Xcode projects are ignored; `project.yml` owns settings, resources, plists, and versioning. The original icon remains in the upstream history; Fry Day uses its own vector-designed icon (`Docs/AppIcon.svg`, rendered with `Scripts/render-icon.swift`).

## What changed

- Persistent sessions survive suspension, termination, and midnight; completed history is independent of Health permissions.
- Live Activity elapsed timer and End link; a scheduled check-in reminder works while the app is suspended.
- Corrected end times recalculate the interval. UV forecast gaps are excluded instead of filled with invented values.
- Timestamped weather requests, bounded cache, explicit offline state, and no moon-service dependency.
- The original widget advances UV from forecast timelines every 15 minutes; network refreshes are throttled to roughly three hours, with retry throttling and explicit forecast age.
- No synthesized vitamin D is written into Health's dietary intake category. Optional Health access reads age and skin type only.
- Original simple UI and time-of-day gradients retained, with Fry Day branding, a compact reminder control, and accurate save/estimate wording.
- Bundled icon/launch resources, privacy manifests, and privacy/support links.

## Estimates and privacy

The inherited exposure formula is **not clinically validated** and does not measure vitamin D production or a safe exposure duration. See [methodology](METHODOLOGY.md). Session reminders are user-selected check-ins, not burn predictions.

See the [privacy policy](PRIVACY.md), [attributions](ATTRIBUTIONS.md), and [release checklist](Docs/ReleaseReadiness.md). No analytics, advertising, accounts, or app-operated backend is included.
