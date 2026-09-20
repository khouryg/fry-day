# Fry Day device beta checklist

Use a real iPhone with a current UV forecast. These checks are not established by the simulator unit tests.

- Launch, allow location, and verify that the forecast updates for the current area.
- Start a session while forecast UV is positive; allow notifications and Live Activities if desired.
- Lock the phone. Verify the session timer and check-in time are visible in the Live Activity, and inspect the Dynamic Island where supported.
- Use the Live Activity's End link. Save a corrected end time and confirm that the displayed estimate and local history agree.
- Start another session, background the app, then return. Confirm elapsed time and estimates reconcile.
- Check a reminder with the screen locked. Repeat with notifications disabled or Focus enabled; the session must still save correctly.
- Add small and medium Home Screen widgets. Observe forecast progression without opening the app; check that an expired forecast does not freeze at an old UV value.
- Travel to another area while the app is visible, then reopen after travel. Check location and forecast freshness.
- Test a short offline interval, reconnect, and confirm recovery. Check manual retry after an error.
- Inspect VoiceOver labels, larger text sizes, and a smaller screen. Verify the completion sheet, pickers, and manual entry remain usable.
- Delete one saved session and verify the daily total updates.
- For energy comparison, use matched foreground and locked-screen sessions under similar brightness, signal, temperature, and battery conditions. Simulator timings do not measure battery drain.

Record device/OS, build, each result, and any issue. Do not mark the complete checklist passed just because installation or launch succeeds.
