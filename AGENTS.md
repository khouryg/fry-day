# Fry Day project instructions

- Preserve Sun Day's original simple interface, layout, time-of-day gradients, and sheet styling. The owner explicitly rejected a complete UI overhaul. Make only small UI changes needed for requested features or correctness.
- Keep widget updates gentle: advance cached forecasts using timeline entries, and throttle network requests to about three hours with retry throttling. Do not add background GPS tracking or aggressive polling.
- Keep the app free. Preserve upstream licensing and attribution, and identify Fry Day as an independent continuation.
- Session history must remain local and usable without Health access. The owner explicitly authorized optional export of sun-derived estimates to Health's dietary vitamin D category on September 20, 2026. Explain the dietary-category mismatch, preserve local saves when Health access fails, and use stable session identifiers to prevent duplicate exports.
- Treat `project.yml` as the source of truth for generated Xcode projects. Follow `Docs/ReleaseReadiness.md` before a release; a simulator build is not signed-device or App Store validation.

- Release decision (September 20, 2026): retain the inherited vitamin D estimates for the first release, keep their limitations explicit, and defer further scientific validation. Do not remove the estimates or hold the entire beta workflow for that review. Do not describe the model as clinically validated.

- Approved App Store listing name: `Fry Day: Sun & UV Timer`. Keep the installed display name `Fry Day`. Apple rejected the unqualified listing name as already in use.

- Preserve Sun Day’s original card dimensions, typography, order, and 20-point spacing. Remove added footer rows; details belong in How It Works. Match the original overflow behavior on screens too small for the full layout instead of compressing its proportions. Keep the automatic Live Activity. The owner subsequently authorized a best-effort exposure warning notification using the inherited model; retain the simple header and do not restore a manual reminder control. Clearly describe warnings as forecast-based estimates, not guaranteed burn prevention. Existing information and history sheets may scroll.
