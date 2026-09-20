# Release readiness

This branch is a development foundation, not an App Store submission or a guarantee of review approval.

- Register app/extension/App Group identifiers under the owner's Apple developer team and validate a signed archive.
- Check the chosen name/icon against App Store availability and relevant branding rights. “Fry Day” is the user's chosen identity; availability has not been established.
- Publish the revised privacy/methodology/support files on the default branch before releasing, so in-app links resolve to the correct documents.
- Confirm non-commercial Open-Meteo usage and expected scale. Maintain attribution in the app and wherever UV data is displayed. No ads/subscriptions are implemented.
- Review the inherited estimate model and health wording with appropriate scientific expertise. Do not reintroduce dietary vitamin D writes for synthesized estimates.
- Verify Lock Screen/Dynamic Island behavior, End deep link, disabled Live Activities, notification denial/Focus, and force-quit recovery on physical devices. Live Activities are not continuous background execution and have system lifetime limits.
- Exercise overnight sessions, corrected dates, offline/gapped forecasts, settings changes, save failures, and duplicate actions.
- Check VoiceOver, Dynamic Type, small screens, and local record deletion.
- Validate privacy manifests, App Store privacy answers, age rating, support contact, screenshots, version/build numbers, and archive resource contents.
- Run `swift test`, iOS tests, and an archive build before any TestFlight/App Store submission. The repository does not configure automatic deployment.
