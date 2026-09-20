# Fry Day 1.0.0 — submission preparation

## Identity

- Name: Fry Day
- Subtitle: UV, sun sessions & reminders
- Primary language: English (U.S.)
- Primary category: Weather
- Secondary category: Health & Fitness
- Price: Free; no ads, purchases, subscriptions, or accounts.
- Bundle: `com.khouryg.fryday`; widget: `com.khouryg.fryday.widget`.
- App Group: `group.com.khouryg.fryday`; development team: `5G2JU987CA`.
- Copyright: 2026 George Khoury

## Description

Keep track of your time in the sun with Fry Day.

See your local UV forecast, start an outdoor session, and keep its timer visible on your Lock Screen or Dynamic Island. Choose a check-in reminder so you remember to review your session, even when the app is in the background.

• Local UV forecasts with Home Screen widgets
• Live Activities and optional check-in notifications
• Saved sessions with editable end times
• Vitamin D estimates using your selected clothing, sunscreen, skin type, and optional age
• Optional Apple Health import of available age and skin type
• Local session history, without accounts, ads, or subscriptions

Vitamin D values are modeled estimates from an inherited formula, not measurements or clinically validated predictions. Fry Day does not measure vitamin D status or tell you how long sun exposure is safe. Reminders are personal check-ins, not burn warnings. Consult a healthcare professional for medical advice.

Weather forecasts are provided by Open-Meteo. Actual widget and notification delivery depends on iOS settings and scheduling.

Fry Day is a free, independent continuation of the open-source Sun Day app. Source code, methodology, and original-project attribution are available on GitHub.

## URLs

- Support: https://github.com/khouryg/fry-day/issues
- Privacy: https://github.com/khouryg/fry-day/blob/main/PRIVACY.md
- Marketing/source: https://github.com/khouryg/fry-day
- Methodology: https://github.com/khouryg/fry-day/blob/main/METHODOLOGY.md

Keywords: uv,index,sun,outdoors,vitamin d,exposure,timer,reminder,weather

## Review notes

Fry Day is an independent continuation of jackjackbits/sunday, released under the Unlicense. The original license and attribution are retained in the public repository. This app adds persistent corrected sessions, Live Activities, local check-in reminders, and forecast-driven widget updates, and fixes data-integrity and resource-packaging issues.

No login or purchase is required. Allow location to load UV forecasts. Begin is available when the local forecast UV is above zero; End remains available for a running session. To review the session feature, use a location and time with nonzero forecast UV. The clock and UV forecast are real rather than a fabricated review mode. How It Works is opened from the title/info control; session history and optional Health import are there.

Health integration is optional and read-only (available age and skin type). Estimated skin synthesis is never written to Health's dietary vitamin D category. Session reminders are selected by the user; they do not assert a safe exposure duration. The owner chose to retain the inherited estimates for the first release and defer additional scientific validation. The model's limitations are disclosed in the app, methodology, and listing.

## Export compliance

Fry Day uses Apple's URLSession/TLS for HTTPS and Apple's operating-system data protection. No custom cryptography or bundled cryptographic library is present. `ITSAppUsesNonExemptEncryption` is false on that basis. Do not copy the separate Mumblers app's encryption or territory answers into Fry Day.

## Privacy disclosure preparation

The app sends coordinates to Open-Meteo for weather and uses Apple's geocoder for a place name. Open-Meteo's policy permits troubleshooting request logs retained for 90 days; do not claim that no location leaves the device. Session history and optional imported Health profile values remain on-device in a backup-excluded file. No tracking, ads, analytics SDK, advertising identifier, or app-operated account/backend is included. Verify App Store Connect answers against the bundled manifest and PRIVACY.md before publication.

## Remaining external checks

App Store name acceptance is not a trademark clearance. A preliminary search found an unrelated Android task app named FryDay; no legal exclusivity is claimed. Physical-device battery, travel, accessibility, notification/Focus, Lock Screen/Dynamic Island, and real widget-scheduling checks remain distinct from automated tests and build success. Territory selection and any required trader-status declaration must reflect the owner's actual circumstances.

## Weather service check — September 20, 2026

The current free app has no advertising, subscriptions, paid features, or promotional commercial use. This matches Open-Meteo's stated non-commercial examples. Its free tier is limited to fewer than 10,000 calls per day, 5,000 per hour, 600 per minute, and the displayed monthly limit is 300,000. These are service limits, not a guaranteed allowance for each installed copy. Reassess service capacity before a large rollout or any monetization; never embed a paid service secret in the public client. Source: https://open-meteo.com/en/terms

The weather source and CC BY 4.0 attribution appear in the app; widget and Live Activity UV labels name Open-Meteo. The methodology describes interpolation.
