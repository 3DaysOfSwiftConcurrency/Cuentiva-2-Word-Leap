# Numbered castle progression

## User journey

- Every castle shows its one-based adventure number.
- A fresh player can enter Castle 1 only.
- Finishing a castle saves its existing completion ID and opens the next castle.
- Locked castles show a padlock and name the prerequisite castle; tapping them
  cannot navigate into gameplay.
- Completed castles remain replayable, including those completed out of order
  before locks were introduced. Unknown saved IDs are retained but not counted
  as conquered castles on the current map.
- Retries and partial progress do not unlock anything. Next level waits for the
  preceding completion save, even when selected immediately.
- Background reveal assignments, physics, coins and run statistics are unchanged.

No new persistence format or migration is used.

## Verification — 23 October 2026

- 54 tests in 15 suites passed in the macOS verification package, including
  all 52 sequential unlocks, direct-entry denials, save ordering, replay,
  restoration, cancellation, map selection and existing gameplay simulations.
- All production Swift sources and hosted iOS test sources passed type-checking.
  Hosted GameViewModel/SpriteKit tests were not executed.
- The Release build was attempted but failed at launch-screen compilation:
  `iOS 26.2 Platform Not Installed`, with CoreSimulator connection errors.
  There is no successful build/install or visual playtest for this change.
- Logs are saved at `/private/tmp/word-leap-castles-*.log`.

## CFA ownership

Adventure: LibraryView → LibraryViewModel → AppModel.libraryFeature →
CuentivaBookRepository / LevelProgressStore.

Gameplay: GameView → GameViewModel → AppModel.wordLeapFeature →
the same LibraryFeature → LevelProgressStore.

LibraryFeature owns numbering, access and completion publication. AdventureCastle
is its immutable book/number/access snapshot. WordLeapFeature validates access
through LibraryFeature before building a level; the canonical catalogue book is
used rather than trusting a supplied book's contents. New completion commands are
accepted only for the currently unlocked progression; previously saved out-of-order
completion remains readable for compatibility. Completion is saved before
publication. Its retained completion task outlives leaving the game and is awaited
by the next start request. Existing progress refreshes merge monotonically so
an older read cannot remove a newly published completion.

LibraryViewModel owns selection and prepares each castle's display and accessibility
values. StoryOutpost only renders that presentation. No access rules live in SwiftUI. Denied or unavailable gameplay entries
show a recoverable message instead of an endless loading indicator.

## Manual checks

On a fresh install, check numbers 1–52 and confirm only Castle 1 is playable.
Complete Castle 1 and immediately select Next level. Leave Castle 2 unfinished:
Castle 3 must remain locked. Return to the map, replay Castle 1, relaunch, and
confirm the completion/lock state survives. Inspect locked artwork and VoiceOver
labels in both themes and with large text. With existing progress, confirm no
completed castle becomes inaccessible.
