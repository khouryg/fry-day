# Fry Day privacy policy

Updated September 20, 2026.

Fry Day is an independent continuation of Sun Day. This policy describes the Fry Day implementation in this repository.

## Location and weather

With your permission, the app obtains your location while in use and sends latitude and longitude to Open-Meteo to request UV forecasts. Coordinates are not sent to an app-operated server. The request also exposes your IP address to Open-Meteo. Its [terms and privacy policy](https://open-meteo.com/en/terms) explain that troubleshooting logs may contain coordinates and are deleted after 90 days.

Apple's Core Location geocoder is used to show a place name. The last place name is shared locally with the widget. A cached weather response containing the last approved coordinates, forecast data, and its update time is stored in the device cache and shared with the app’s widget. The widget uses that last location to request fresh forecasts about every three hours when iOS allows, without requesting GPS updates. Successful fetches replace the shared forecast. iOS may remove this cache. Background GPS tracking is not enabled. You can revoke location permission in Settings.

## Sessions and profile

Session times, selected clothing/sunscreen/skin type, optional age, and forecast samples used for exposure estimates are saved in a local file protected by iOS file protection. This folder is excluded from device backups. Your session history can be deleted one record at a time in the app. Deleting the app removes its remaining local files.

Apple Health integration is optional and requested only when you choose to import an available age and skin type. Imported profile values remain in the same protected, backup-excluded local file. Fry Day does not write vitamin D estimates to Health and does not read dietary vitamin D history. You can manage Health permissions in Health or Settings. Revoking access does not itself delete profile values already imported; clear the age in How It Works and change skin type using the main screen or delete the app.

## Widgets, Live Activities, and notifications

The app shares a minimal snapshot with its own widget using an App Group: the last location name, coordinates and forecast, estimated daily total, and active session identity/start time. These values stay on-device and may be visible on the Home Screen. Live Activities display session time and forecast information on the Lock Screen and Dynamic Island; anyone who can see your screen may see that information. You can disable widgets and Live Activities through iOS controls.

Fry Day does not schedule notifications or request notification permission. Upgrading from the first beta cancels its previously scheduled session reminders. Fry Day does not operate a push notification server.

## Other collection and services

Fry Day includes no analytics SDK, advertising, accounts, advertising identifier access, or developer-operated data collection service. It does not sell data. Network services may receive technical connection information as described in their policies. GitHub hosts the source code, support issues, methodology, and this policy; opening those links uses GitHub's service under its own privacy terms.

## Contact and changes

For support, privacy questions, or deletion questions, [open an issue](https://github.com/khouryg/fry-day/issues). Do not put private health information in public issues. Policy changes will update this document and its date.
