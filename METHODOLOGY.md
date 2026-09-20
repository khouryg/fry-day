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

## Reminders and Health

The reminder interval is selected by the user and is not a burn limit. Live Activities do not keep app code running continuously. Persisted timestamps let elapsed timers render while the app is suspended, and local notifications provide a separate check-in.

Modeled estimates are stored only in Fry Day. They are not exported to Health's dietary vitamin D field, which measures consumption. Optional Health access reads age and skin type only.

## Provenance

The original implementation and research references remain available in the [upstream methodology at the reviewed commit](https://github.com/jackjackbits/sunday/blob/d8331e9acafd3f3b33cdd2d41fd89a347b385c22/METHODOLOGY.md). Citing that document does not establish validation of Fry Day's formula. A scientific review of coefficients and product claims remains a release-readiness item.
