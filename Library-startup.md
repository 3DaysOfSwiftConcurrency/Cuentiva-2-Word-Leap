# Adventure startup and the bundled library

Adventure keeps one WorldBackdrop in place while preparing its first presentation.
There is no launch spinner, separate loading screen, empty castle map or visible
zero-balance placeholder. The app delegate signals AppModel synchronously at launch;
AppModel asks LibraryFeature to begin loading without blocking the interface. The
Adventure screen joins that same Feature-owned task when needed. LibraryFeature concurrently reads the local catalogue,
completed-castle IDs and doubloon balance. It publishes those values together on
the main actor before setting isReady. LibraryViewModel exposes that readiness;
LibraryView reveals the menu and noninteractive balance with a short opacity
transition. Reduce Motion disables that transition. The hidden balance reserves
the same space so content preparation does not change the backdrop's geometry.

The static AdventureLaunch storyboard, root tab-container backdrop and Adventure use the same village artwork,
aspect-fill treatment and uniform shadow colour at 32% opacity. Adventure omits
the other screens' additional vignette to avoid a brightness change. iOS owns
that launch surface; launch-to-SwiftUI rendering was visually checked on the
iPhone Air simulator (iOS 26.2). A physical-device check is still required.
Both build configurations select AdventureLaunch. Its new resource name helps
avoid reuse of the earlier launch resource; the fallback colour is now dark in
both appearances. The storyboard also declares its fallback colour directly, so
it does not depend on an asset-catalog colour lookup before the image is drawn.
No saved progress or coins are cleared to refresh launch snapshots.
No timed splash screen or minimum waiting duration is added. Revisiting Adventure
keeps its populated menu visible. A missing/corrupt library shows a retry message
over the same backdrop instead of silently presenting an empty map.

## Launch-screen regression check

On 23 October 2026, the installed storyboard and compiled WorldVillage image
were both present, but the simulator's `splashboardd` logged that it could not
load WorldVillage and generated a grey snapshot. Changing JPEG to PNG alone
did not resolve it. Restarting the simulator's launch-image service, then
building and running again in Xcode regenerated the snapshot successfully.
The original JPEG was restored and verified again; no duplicate PNG is shipped.

For the same simulator-only failure, stop the app, run
`xcrun simctl spawn booted launchctl stop com.apple.splashboard`, then build and
run again in Xcode. Do not uninstall the app or erase its data to refresh this
snapshot. This diagnostic action is not part of app startup.

Check the actual system launch surface with
`xcrun simctl launch --terminate-running-process --wait-for-debugger booted com.3DaysOfSwiftConcurrency.CuentivaWordLeap`.
Wait for the system's opening animation to finish, then capture a simulator
screenshot. Because the app has not started executing, this tests the launch
storyboard rather than an in-app imitation. Afterwards, run the same launch
command without `--wait-for-debugger` to restore normal operation.

Verification showed the same full-bleed village crop and shading before launch
and behind the populated Adventure menu. The existing 39 doubloons and one
conquered castle remained intact. Fresh launch-image generation logs contained
no WorldVillage loading failure. A successful build alone is not sufficient
evidence for this check.

## Initial tab appearance — 23 October 2026

The illustrated screens already use dark chrome regardless of their selected
colour palette. Apply that policy once at the app root, with
`UIUserInterfaceStyle = Dark` in both build configurations so the window starts
with the same appearance. Do not reintroduce a child-screen
`preferredColorScheme` override: a System root followed by a dark preference
from Adventure can visibly change the tab bar after presentation.
The saved theme selection and its palette are unchanged.

The Debug simulator build succeeds. Cold-launch screenshots on iPhone Air
(iOS 26.2) show consistent dark tab styling from its first captured appearance
through the populated menu. Stored System selection, 39 doubloons and one
conquered castle remain intact. This check does not establish launch-storyboard
continuity: the newly installed simulator build showed a black system launch
snapshot even after restarting its launch-image service. Recheck the system
launch image separately in the Xcode/device build; do not erase user data.

## Bundled data

The shipped asset is `CuentivaWordLeap/3 - App Resources/Editorial/Library.dat`:
52 books, 157,725 bytes (about 154 KiB). This is the library resource size, not
the installed app size. The synchronized Xcode app group includes the resource.

It uses the **same CUENLIB version-two binary format as Cuentiva**: a 16-byte
header, 152-byte book records, 32-byte sentence records, little-endian offsets
and interned UTF-8 strings. This is not JSON with a renamed extension. For the
same normalized book records, output was checked byte-for-byte against
Cuentiva's original compiler.

Word Leap reads its required fields: stable IDs, catalogue order, storyteller,
Spanish/English titles and passages, and cover level/symbol/palette. Unused
learning fields are absent or empty; this is not a copy of Cuentiva's entire
reader database. Existing manuscript and metadata remain the editable source.
All 52 decoded StoryBooks equal the original source, including punctuation,
translations and cover metadata. Existing progress keys and book IDs are unchanged.

The repository reads this bundled binary on its actor and caches the resulting
books. Startup does not parse the manuscript/metadata JSON or contact GitHub.
Level geometry is still built when a book is played; the separate verb vocabulary
is unchanged. Manual pull-to-refresh still retrieves the editorial manuscript
and updates the in-memory catalogue only after the complete manuscript validates.
Incomplete books, duplicate IDs and orphan passage content are rejected, leaving
the playable bundled catalogue intact. This does not add downloaded-file persistence
or background catalogue updates.

## Regeneration and validation

From the project folder, after editing the manuscript or cover metadata:

```sh
python3 scripts/build_library_dat.py
python3 scripts/build_library_dat.py --check
```

Commit Library.dat alongside its source changes. The check command fails if the
binary is stale. The hosted parity test also detects content differences; there
is no Python dependency during app launch and no automatic build-time compiler.

The isolated three-book test fixture has its own compiled resource:

```sh
python3 scripts/build_library_dat.py \
  --stories CuentivaWordLeapTests/Fixtures/AdventureLibrary.txt \
  --output CuentivaWordLeapTests/Fixtures/AdventureLibrary.dat
```

The binary reader rejects unknown versions, truncated/out-of-bounds tables,
invalid UTF-8, duplicate book IDs and missing required story content. Input size,
book count and passage count are bounded before allocation/materialization.

## Verification — 10 November 2026

- The bundled-data regeneration check passes for all 52 books, and source syntax,
  asset metadata, editorial metadata, the storyboard and privacy manifest validate.
- Full Xcode build remains blocked here by Interface Builder reporting
  `iOS 26.2 Platform Not Installed`, alongside CoreSimulator service errors.
- A source-only compiler attempt reaches Swift compilation, where the host sandbox
  blocks the Observation macro service before it can typecheck the complete module.
- This does not establish visual launch continuity or measured launch performance.
  On device, cold-launch offline with saved coins and a completed castle: the first
  visible map must show the correct balance, completed castle and next unlock.
  Repeat with a fresh install, Reduce Motion, and returning from Settings/gameplay.
