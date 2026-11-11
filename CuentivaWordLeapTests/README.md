# Tests

Startup coverage: `BinaryStoryLibraryTests` compares every bundled binary book
against the manuscript and cover metadata, including order and punctuation. It
rejects malformed headers, invalid offsets/counts, invalid UTF-8 and duplicate IDs.
`CuentivaBookRepositoryTests` verifies that remote editorial refreshes reject
incomplete books, duplicate IDs, unplayable passages and content without a book
header, so invalid downloaded content cannot replace the playable bundled catalogue.
`LibraryViewModelTests` checks that readiness includes saved locks and balance,
revisits stay ready, a corrupt library can recover through retry, and a failed
remote refresh preserves the playable bundled catalogue. `AppModelTests`
checks that concurrent launch signals join one ready library result. Launch visuals still need an iOS check.
See `../Library-startup.md` for regeneration and stale-asset checks.

`LibraryFeatureTests` also pauses a remote refresh behind a controlled gate and
proves that the already loaded bundled catalogue remains immediately playable.
The watchdog is cleanup protection; the passing path does not depend on a delay.

Settings coverage: `SettingsFeatureTests` verifies restoration, persistence and
safe fallback from an obsolete stored theme. `ThemeManagerTests` verifies that
the presentation palette reads and writes the Feature-owned selection rather
than owning a second persistence path. `SettingsViewModelTests` verifies that the
screen routes theme selection through that Feature while keeping About copy and
formatting Feature-supplied app identity at the ViewModel boundary.

Persistent treasure coverage: `DoubloonBalanceTests` checks duplicate/lower reports,
checkpoint-safe crediting, leaving during a save, fresh replay earnings, invalid counts,
and overlapping credits/refreshes. `LevelProgressStoreTests` checks reopening a balance
without changing completed castles. `LibraryViewModelTests` checks saved-balance loading
and live gameplay updates. The HUD and transparent pinned header still need iOS visual checks.

`FeatureTests/Library/LibraryFeatureTests.swift` checks numbered access for all
52 castles, one-at-a-time unlocks, FIFO completion commands, rejection of direct locked-castle completion, saved progress restoration, completed-book
replays (including legacy out-of-order completions), unavailable catalogues and
unknown IDs. `CastleAccessTests` checks gameplay denial, partial progress,
completion-save ordering before Next level, cancellation, and canonical book
content. `WordLeapFeatureTests` verifies that duplicate, skipped and final-only
landing reports cannot complete a level and that rescue receives only the Feature's
semantic completion outcome. `LibraryFeatureTests` also checks fresh-feature refresh
readiness. `LibraryViewModelTests` checks disabled selection and live map updates.
These run in the macOS package with production LibraryFeature, AppModel and
LibraryViewModel sources; tests inject their own graph and never use AppModel.shared.

`Support/AdventureTestFixture.swift` copies a three-book binary into a separate temporary directory and creates a
UserDefaults suite for every test. The existing completion key and data format
are preserved; no player progress is reset. GameViewModel's locked-entry test
requires the hosted iOS runner, alongside its existing SpriteKit presentation test.

`BookBackgroundTests` checks all 52 fixed book assignments: Sky Falls for 1–10,
new packs at books 11/16/21/26/31/36/41/46/51 and the Letters finale at 52.
It checks no early reveals or consecutive repeats after the introduction, stable
replays after title/order changes, and Sky Falls for unknown future IDs.
Its UIKit-only tests load all eleven backdrops and check
all 23 cutouts' alpha channels and decoded transparent pixels in the compiled
asset catalogue (20 new story cutouts plus the three Sky Falls sprites).

`PresentationTests/ParallaxLayoutTests.swift` checks camera-driven movement,
depth ratios, offscreen wrapping, long climbs, frame-rate independence, retry
positioning, viewport changes and Reduce Motion. It runs in the macOS package.
`ParallaxSceneryRecipeTests` checks every pack's unique artwork, bounded density,
increasing depth speeds, an open central corridor and setting-specific particles.
`ParallaxBackgroundNodeTests` checks all eleven packs: bounded node counts,
no physics bodies, relayout, depth-specific movement, still scenery with Reduce
Motion, correct cutout selection and stationary distant backdrops.
That suite requires the hosted iOS test target; it is not a UI test target.

`GameCharacterTests` verifies all nine cast identities, complete profiles, book lookup,
unknown-storyteller fallback and the feature's read-only catalogue. The UIKit-only
artwork test checks that every portrait and transparent sprite loads from the compiled
asset catalogue; it needs the hosted iOS test runner, not the temporary macOS package.

Run Command-U with the **Cuentiva Word Leap** scheme in Xcode, or:

```sh
xcodebuild -project 'Cuentiva Word Leap.xcodeproj' -scheme 'Cuentiva Word Leap' \
  -destination 'platform=iOS Simulator,name=iPhone Air' test
```

The synchronized test group includes Swift sources automatically. No UI test target is required.

`FeatureTests/WordLeap/WordLeapSimulationTests.swift` exercises the same simulation used
by `WordLeapScene`: supported spawn, inclusive top-edge landing, checkpoints/resizing,
and completing every bundled book across five viewport sizes at 30, 60 and 120 fps,
with a 180 ms steering reaction delay. It also verifies coin contact, roughly 30
collectibles per book, no duplicate collections after retry/resize, and safe completion.
Floating-point positions use a small tolerance. Decoder tests cover the bilingual reader
and original Cuentiva cover metadata; `StoryBookTests` covers immutable bilingual
passage pairing and missing translations; tokenizer tests cover full-stop platforms.

These tests can also execute on macOS with the simulation, book decoder and their
dependencies in a temporary Swift package. In that context the manuscript is a test
resource (`Bundle.module`); Xcode's hosted tests use the app's manuscript (`Bundle.main`).
Such a run verifies the production simulation, not SpriteKit rendering, touch delivery,
safe-area layout, or physical-device performance. Those still need an iOS playtest.

Game Over coverage: `AdventureRunStatisticsTests` verifies unique word/platform/verb
counts, full-platform completion, cumulative book totals and duplicate-safe coin/time reports. `ActivePlayTimeTests`
checks that waiting and death add no time and checkpoint retries/resizing preserve it.
`AdventureRunFeatureTests` checks next-level continuity versus a fresh adventure.
`LevelPlanBuilderTests` checks offline verb-form matching against the vocabulary reused
from Verbos, plus the explicit unavailable state for a missing vocabulary. This is an
estimate: homographs and verbs outside that teaching collection are not fully classified.
`View model tests/GameViewModelTests.swift` covers the summary, Feature-validated
landing words and rewards, retry and fresh-start
presentation, changed-request replacement and observable next-level completion
through isolated features. It also checks singular gameplay copy and safe elapsed-time
presentation for an extreme finite value; it requires the hosted iOS test target. SpriteKit reports
gameplay events synchronously on the main actor, preserving their frame order rather
than creating an independently scheduled task for each callback.

Device checks: fall, see the friendly skeleton transition, inspect the six summary tiles,
continue from checkpoint, finish a book and choose Next level, then die again. Also test
background/foreground, rotation, Reduce Motion and large Dynamic Type. Counts cover the
current adventure (including checkpoint retries and Next level), not lifetime totals.
