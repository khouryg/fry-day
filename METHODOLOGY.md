# Fry Day exposure estimates

This implementation retains a simplified vitamin D model from Sun Day. **The formula and its coefficients have not been clinically validated.** Results are modeled estimates, not measurements of vitamin D status, absorbed UV dose, or safe exposure duration. They must not be used to diagnose deficiency, determine supplements, or decide how long someone can safely remain in the sun. Consult a clinician before making medical decisions.

## Shared calculation

Both live and manual sessions use one calculation:

`IU/hour = 21000 × (3 × UV / (4 + UV)) × clothing × sunscreen × skin × age`

- Clothing: uncovered 1.0; swimwear 0.80; shorts/tee 0.50; pants/tee 0.30; pants/sleeves 0.10.
- Sunscreen transmission assumptions: none 1.0; SPF 15 0.07; SPF 30 0.03; SPF 50 0.02; SPF 100+ 0.01. These idealized factors do not measure application, wear, or protection in practice.
- Skin factors I–VI: 1.25, 1.10, 1.0, 0.70, 0.40, 0.20.
- Optional age factor: 1.0 through age 20, then a continuous 0.015 decrease per year, reaching 0.25 at age 70 and remaining there. This is an inherited modeling assumption with its previous discontinuity removed, not a validated individual prediction.

The previous clock-only quality multiplier and dietary-intake-based adaptation multiplier were removed. Foods and supplements must not be interpreted as recent sun exposure.

## Weather and time

Open-Meteo supplies hourly forecast UV values. Epoch timestamps avoid phone/API time-zone and DST indexing errors. Each running session records the forecast and settings in effect at each change. Past segments retain their original inputs; new forecasts affect subsequent time.

Calculation integrates rates in steps of at most one minute, splitting at forecast and setting boundaries. Interpolation is limited to adjacent hourly samples. Missing or out-of-coverage time is excluded and disclosed. Correcting an end time truncates this same timeline. Manual entries require forecast coverage for the whole selected interval; they do not fabricate historical weather.

Forecasts describe ambient conditions, not personal exposure. Shade, glass, orientation, clothing coverage, and sunscreen use introduce uncertainty. The app does not infer whether the user has gone indoors.

## Live Activities and Health

Live Activities start automatically with a session and do not keep app code running continuously. Persisted timestamps let elapsed timers render while the app is suspended. With notification permission, the app schedules a best-effort exposure warning using the inherited skin-type MED estimate at a threshold of 1. It integrates changing forecast UV and preserves earlier exposure when a new forecast arrives. This is not a validated burn threshold or a safe-exposure countdown. Sunscreen does not extend the warning time; unreported prior exposure and individual sensitivity are not accounted for. Missing forecast coverage produces a check-exposure notice. iOS suspension can prevent timely forecast recalculation, and notification settings can delay or silence delivery. Use sun protection independently of the alert.

Modeled estimates remain saved locally. With separate opt-in and write permission, Fry Day also exports completed session estimates to Health’s dietary Vitamin D category, converting IU to micrograms (1 IU = 0.025 micrograms). This category measures consumption, so Health may combine sun-derived estimates with food and supplements. Metadata identifies the source as an unvalidated sun-exposure estimate; this does not create a separate Health category. Each session uses a stable HealthKit sync identifier to prevent duplicate retries. Optional profile import reads age and skin type. Deleting local sessions does not delete exported Health records.

## Provenance

The original implementation and research references remain available in the [upstream methodology at the reviewed commit](https://github.com/jackjackbits/sunday/blob/d8331e9acafd3f3b33cdd2d41fd89a347b385c22/METHODOLOGY.md). Citing that document does not establish validation of Fry Day's formula. A scientific review of coefficients and product claims remains a release-readiness item.
