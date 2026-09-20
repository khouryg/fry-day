# App Store screenshots

Three portrait PNGs at 1284 × 2778, RGB without alpha, for the 6.5-inch screenshot slot:

1. `01-home.png` — local UV overview.
2. `02-live-activity.png` — the running session on the Lock Screen.
3. `03-history.png` — locally saved session history.


`preview.png` is a contact sheet for review, not an upload asset. `raw/` contains unchanged simulator captures from the build 3 source on iPhone 17 Pro, iOS 26.2. The simulated public location is San Francisco; session records are simulator test data. The Live Activity timer was captured during a real short simulator session. Promotional copy sits outside the app screen. No UI source changes were made.

Regenerate on macOS using `swift render.swift /absolute/path/to/Docs/AppStoreScreenshots`. The renderer uses AppKit and CoreText; no external packages. Outputs are opaque RGB PNGs.

Prepared September 20, 2026. Not yet uploaded to App Store Connect.

The fourth image shows the pending Health export update, which is not in TestFlight build 4. Only use it in the App Store listing once the matching release build is selected. The native permission screen was captured without granting write access or exporting any Health records.

The current set uses the original three captures with a Health-style heart mark and “Save vitamin D estimates to Apple Health” beneath each phone. The separate fourth design is an unused earlier alternative. These updated captions require the upcoming release containing optional Health export; build 4 does not include it.

Latest layout: Health promotion appears only as a large overlay in the empty black area of the third (history) screenshot. The first two screenshots have no Health footer. The promotional overlay is artwork, not a new in-app history panel.
