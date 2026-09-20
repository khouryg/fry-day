# Fry Day device beta checklist

Use a real iPhone with a current UV forecast. These checks are not established by the simulator unit tests.

- Launch, allow location, and verify that the forecast updates for the current area.
- Start a session while forecast UV is positive; allow Live Activities if desired. Allow notifications when prompted, and separately verify that declining them does not block tracking.
- Lock the phone. Verify the session timer are visible in the Live Activity, and inspect the Dynamic Island where supported.
- Use the Live Activity's End link. Save a corrected end time and confirm that the displayed estimate and local history agree.
- Start another session, background the app, then return. Confirm elapsed time and estimates reconcile.
- Upgrade from build 1 with a reminder pending; verify the legacy reminder is canceled. Build 4 schedules the new exposure warning only for an active session.
- Add small and medium Home Screen widgets. Observe forecast progression without opening the app; check that an expired forecast does not freeze at an old UV value.
- Travel to another area while the app is visible, then reopen after travel. Check location and forecast freshness.
- Test a short offline interval, reconnect, and confirm recovery. Check manual retry after an error.
- Inspect VoiceOver labels, larger text sizes, and a smaller screen. Verify the completion sheet, pickers, and manual entry remain usable.
- Delete one saved session and verify the daily total updates.
- For energy comparison, use matched foreground and locked-screen sessions under similar brightness, signal, temperature, and battery conditions. Simulator timings do not measure battery drain.

Record device/OS, build, each result, and any issue. Do not mark the complete checklist passed just because installation or launch succeeds.

## Build 4 exposure warning checks

- Verify the forecast-based warning appears on a locked phone when permitted; do not stay in the sun to wait for a test alert.
- End a session before its scheduled warning and verify no alert arrives for that session.
- Reopen a running session after a forecast change; check the warning status in How It Works.
- Relaunch after an alert has become due and verify it does not repeatedly notify.
- Check Continue Tracking before and after a warning, offline forecast expiry, and notification-disabled settings.

## Optional Health export

- Enable export in How It Works and grant dietary Vitamin D write permission. Profile import remains a separate request.
- Save a session with a corrected end time; verify one Health Vitamin D entry, correct microgram conversion (IU × 0.025), session interval, and source metadata.
- Export the same session again from history; verify no duplicate entry.
- Decline or revoke permission and verify local save succeeds with export status explaining the failure.
- Disable export and verify new sessions stay local. Existing Health records remain.
- Manually export an earlier saved session, then verify its original date is preserved.
