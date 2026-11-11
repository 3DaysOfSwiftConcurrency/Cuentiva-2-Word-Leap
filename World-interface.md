# Cuentiva's illustrated interface

## Visual scope

- Adventure remains the tab name. Its navigation bar and title are hidden; a transparent, pinned safe-area header displays only the coin artwork and saved balance at the top right. It has no button, tap action or control background. The adventure presentation requests dark system chrome for readable status-bar text over the artwork; the selected world palette remains in effect.
- The menu uses the twilight village painting, a winding dotted trail, illustrated homes and full character sprites. Each home retains its castle number, lock, prerequisite and completion status.
- Settings is a quiet campsite with Tilo and the same warm lettering and dark reading surfaces. All seven existing colour-theme choices remain available.
- The completed-book reader uses the village scenery behind readable Spanish/English passage panels. Book covers now include the level's landscape artwork.
- Game preparation, failure, HUD, reading prompt, completion controls and Game Over statistics use the shared world palette. Game Over still shows the skeleton over the actual game scene.
- The static launch screen uses the same village artwork. No additional splash screen or launch delay was introduced.
- Adventure now keeps this backdrop visible until its catalogue, locks and balance are ready, then fades in the populated menu. There is no launch spinner or zero-balance flash. See `Library-startup.md` for the shipped CUENLIB binary and verification details.

## Reuse and ownership

`WorldVillage` is a byte-for-byte copy of the existing original painting at `Artwork/OriginalBackgrounds/BookBackgroundThreeEnvelopes.imageset/three-envelopes.jpg`. It adds 647,605 source bytes to the asset catalogue; this is not a measured installed-app size.

Existing `LettersLandmark` and character sprites are reused. No new generated artwork is required. The original painting and all gameplay/parallax assets remain intact.

`WorldBackdrop` and `worldPanel` are stateless presentation components. `SettingsFeature`
owns the selected theme and its existing `selectedWordLeapTheme` persistence key;
`ThemeManager` adapts that selection into the shared SwiftUI palette. Feature/ViewModel
ownership of navigation, locking, completion and rewards remains unchanged. The
progressive gameplay-background schedule is also unchanged.

## Accessibility and layout

- Decorative artwork is hidden from VoiceOver. Castle accessibility labels retain number, title and access status; the game exit control now has an explicit label.
- The menu, settings, book reader and end-of-game content scroll; the reader has a bounded reading width on larger screens.
- Artwork and the trail do not introduce motion or timers. Existing gameplay Reduce Motion handling is preserved.
- Panel ink contrast was checked across all seven themes against panels composited over white (the brightest possible artwork). Both primary and secondary ink exceed 4.5:1. Navigation uses a dark system material; controls use warm accents rather than white system cards.

## Validation — 23 October 2026

- All production Swift sources pass Swift 6 iOS typechecking and module emission.
- Hosted test sources pass iOS typechecking.
- 54 core tests in 15 suites pass in the temporary macOS harness, including castle access/progression, environment assignment and all-book physics simulations. These are not simulator UI tests.
- Referenced shared artwork files exist; the launch storyboard parses as XML; `git diff --check` passes.
- Full Xcode build and visual device verification remain blocked in this environment: Interface Builder reports `iOS 26.2 Platform Not Installed`, with CoreSimulator service failures. No successful archive, installed-app size or simulator rendering is claimed.

Before release, check Stage Menu scrolling/locks, all theme selections, large Dynamic Type, the reader sheet, game completion and Game Over on an iPhone and iPad. Also verify the static-launch-to-menu transition on device, where iOS can cache an older launch snapshot.

## Persistent treasure balance

Previously, doubloons existed only in the in-memory adventure statistics. The menu now reads a persistent balance through LibraryViewModel → LibraryFeature → LevelProgressStore. The existing local progress store owns the balance under `wordLeapDoubloonBalance`; completed-castle storage is unchanged.

WordLeapFeature credits the increase in each level's cumulative coin count, bounded by the available coins. The HUD and summaries display that same Feature-validated count rather than a raw scene report. Duplicate, lower, negative, death and rescue reports cannot credit the same pickup twice. Checkpoint retries retain the credit watermark; a deliberately fresh playthrough can earn again. App-owned credit tasks finish after leaving the game. Actor-isolated increments avoid replacing the balance with a stale screen snapshot. There is no spending or purchase behaviour in this change.

No historical lifetime total existed, so pre-update pickups cannot be reconstructed from completed-book IDs. The new balance begins at zero and accumulates actual pickups from this update onward. Reopening restores the saved balance.

Follow-up checks: production and hosted-test iOS typechecking pass; the core macOS harness passes 60 tests in 17 suites, including six balance cases. Runtime visual verification remains outstanding.
