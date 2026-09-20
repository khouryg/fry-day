# Fry Day TestFlight workflow

User authorized working through release preparation on September 20, 2026, and explicitly chose to retain the inherited vitamin D estimates for the first release while deferring further scientific review. Keep the limitations disclosed; do not claim clinical validation.

1. Inspect source changes and the latest App Store Connect build number. Keep app and widget versions identical in `project.yml`.
2. Generate the Xcode project, run appropriate tests, and archive Release for generic iOS with automatic signing and provisioning updates. Team: `5G2JU987CA`.
3. Inspect archive versions, icon, privacy manifests, entitlements, and App Group. Use `com.khouryg.fryday` and `.widget`, not the separate Mumblers identifiers.
4. Export/upload using `method=app-store-connect`, `destination=upload`, automatic signing, and `manageAppVersionAndBuildNumber=false`. Keep logs and confirm the uploaded identity.
5. Verify processing and compliance in App Store Connect. This app uses only Apple-provided encryption; see `Docs/AppStoreSubmission.md`.
6. Assign the build to a Fry Day internal tester group with the app owner. Do not copy or invite Mumblers testers without an explicit Fry Day request. Add external testers and submit for Beta App Review only when their audience is authorized.
7. Verify final build status and group assignment. Upload completion is not tester availability. Report processing/review blockers accurately.
8. Public App Store release follows the completed listing, disclosures, screenshots, and review preparation; a beta upload is not a public release.
