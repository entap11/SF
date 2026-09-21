# Match menu and arena proportions — September 21, 2026

Implemented for review on `codex/single-player-campaign`. Physical iPhone and
Android validation remains pending. This pass sets the space around the arena;
floor artwork and replacement maps are subsequent sprint work.

Second scale trial: units are 22.5% larger, hive artwork 15% larger, and readable
lanes 15% wider than the initial readability pass. This adds half of the first
trial's increase, as requested. These values live together in
`scripts/renderers/combat_readability.gd`. Hive label sizing, focus/ownership cues,
camera framing, authoritative radii, and simulation rules are unchanged. Review
this increment during crowded play on phones before increasing it again.

Selection follow-up: valid new destinations from a selected player-owned hive
stay fully visible alongside its existing connections. The renderer reads the
canonical connection and lane-budget queries used by input validation. Enemy
inspection does not advertise commands from enemy hives. Unrelated hive opacity
is now 75% (previously 48%); unrelated units are 60% (previously 28%). Unrelated
lanes retain 65% of their normal opacity, with incoming threats more prominent.
Labels remain opaque. These are presentation changes, not new targeting rules.

## Layout

`MatchHudLayout` owns the shared geometry in logical viewport units. The menu and
ads respect the device safe area. Screen scaling determines their physical size.

| Surface | Proportion |
| --- | --- |
| Menu | 216 × 124, top-left inside safe area |
| Top banner | Safe width minus 32; width-to-height ratio 6.4:1 |
| Power row | 92 high, immediately below banner |
| Arena | Remaining space between power row and footer |
| Buff footer | 256 high; three player slots centered in 1v1 |
| Ad footer | Same banner ratio, with 8 units above and below |

The old bottom Back to Jukebox control is replaced by the match menu/results
journey. The footer follows the existing runtime buff policy: it shows the second
ad surface when buffs are unavailable. Existing ad entitlements, inventory policy,
and the production buff feature gate remain in force. A reserved surface does
not guarantee an advertiser fill.

## Menu and ad behavior

- Menu and Android Back open an overlay. The match keeps running; the menu says so.
- Leave requires explicit confirmation for unfinished matches, with No focused
  initially. Campaign copy explains that quitting earns no unlock/time/stingers;
  multiplayer and stake copy disclose the applicable consequence.
- Exit intents go to existing match services. No UI code changes gameplay state,
  awards results, or settles money. Failed service requests keep the match open.
- In-match ad taps save the original creative/link and acknowledge it inside the
  banner. Repeated taps on that creative do not duplicate the saved entry.
- Results offer Saved Ads. Only an explicit Open there invokes the provider's
  browser action. Saved entries are scoped to the current match/player in memory.
- Opening an external browser behind the game is not a portable mobile contract.
  Apple documents external URL handling through the receiving app, with no
  background-tab option in this API: [UIApplication.open](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:)).

## Validation and remaining limits

Passed: layout checks at four portrait sizes with simulated safe areas; exit
confirmation and failure handling; ad manager/surface/measurement/placement;
real-Shell match captures and saved-link flow; results and Campaign flow;
buff touch, pointer coordinates, and visibility; all five lane/input regression
checks; MVP smoke (26 passed, zero failed); campaign fingerprint check.

The graphical fixture verifies both footer configurations using the existing
buff debug harness. It uses a fake ad provider and does not open a real browser or
call financial services. MVP smoke still emits engine shader/resource/UID warnings;
its assertions pass. This is not evidence of a warning-free device build.

Paid-match limitation: the legacy VS service rejects generic paid leave requests
with its existing economy-authority gate. The UI honors that rejection and stays
in the match. Durable public leave uses its existing authoritative route. Actual
paid forfeiture/settlement has not been validated; do not treat the warning dialog
or its fixture as proof of financial integration.

Next: review these proportions, verify safe-area/touch behavior on actual iPhone
and Android hardware, then adjust floor presentation around representative
replacement maps. The paid exit authority path needs integration validation before
shipping that flow.

Review captures: `../artifacts/match-chrome-2026-09-21` relative to the worktree's
parent, including `arena-no-buffs.png`, `arena-buffs.png`,
`stake-confirmation.png`, and `saved-ads.png`.
