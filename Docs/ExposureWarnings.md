# Best-effort exposure warnings

Authorized September 20, 2026. Uses the inherited skin-type MED estimate at a threshold of 1; this model has not been clinically validated. This feature does not establish a safe exposure duration or guarantee against sunburn. It does not account for unrecorded exposure, medications, or individual sensitivity. Sunscreen does not increase the warning time.

A running session projects its accumulated dose across the changing forecast. New forecasts and settings preserve earlier segments. The next threshold crossing replaces one pending local notification. Ending or discarding cancels it. The last deadline and session ID persist so an already-due warning is not repeatedly scheduled. Continuing an already-warned session does not issue another warning.

Permission is requested when starting a session. Denial does not block tracking. No extra GPS or weather polling is added. Local notifications are scheduled ahead of time; suspended apps cannot guarantee recalculation for unexpected weather changes. Focus, notification permissions, and OS behavior can silence or delay delivery.

If there is insufficient future forecast coverage to project the threshold, a check-exposure notice is scheduled for the end of coverage. Missing elapsed coverage prompts that notice immediately. Details and scheduling status appear in How It Works; the dashboard remains unchanged.

Before release, verify permission denial, locked-device delivery, pending notification replacement, cancellation on End, and relaunch/Continue behavior on a physical device. Simulator tests cover constant, rising, falling, exhausted, and ended forecast projections. Build 1.0.0 (4) was uploaded to TestFlight on September 20, 2026; see ReleaseReadiness.md for distribution status.
