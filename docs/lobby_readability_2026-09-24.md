# Setup and lobby readability — September 24, 2026

The owner approved continuing menu polish through Free Roll and Money Games
setup/lobbies, with larger controls, clear game/entry details, persistent primary
actions and Back, and understandable waiting or blocked states.

## Implemented

- The shared journey frame uses a scrolling content area and a fixed action area,
  with large button targets, live labels, focus-following scroll, safe-area
  padding, Escape and Android Back handling. Existing artwork is not removed.
- VS setup uses grids for modes, map counts, flag settings and entry amounts.
  Continue and Back remain visible. The existing paid-disabled fallback now
  explains that the setup uses Free Roll.
- The shared free/paid VS lobby shows mode, maps, entry and player count on separate
  lines. Its existing Find Match, Cancel Search, waiting and start states still
  drive the same primary button. Status and player lists can scroll.
- Public contest selection and stage-race cards/details use larger controls.
  Public-contest errors, Refresh Board, Play and Back stay reachable. Selected
  Gauntlet is highlighted independently of the time-puzzle map-count field.
- Setup and contest-detail handoffs now hide only their own presentation frame;
  the previous code hid the parent and therefore its newly opened child lobby.
  Closing the child restores the originating frame. Main-menu setup is tracked
  as an open surface so home controls hide and return consistently.
- Insufficient balance keeps the existing background and enlarged Cancel art.
  It shows the balance/required entry, identifies the existing Add Funds and Card
  placeholders as unavailable, and keeps Free Roll and Cancel reachable. No
  funding implementation or cash availability was added.

Existing callbacks retain matchmaking, player requirements, eligibility, maps,
entry amounts, escrow and launch behavior. No asset file, simulation system or
authoritative state implementation was changed in this pass.

## Review and checks

Native review: `../artifacts/lobby-polish-2026-09-24/index.html`, relative to the
worktree. The verification record lists exact source hashes and check results.
The isolated runner uses disposable player data and offline service settings.
Paid availability, wallet values and the search-in-progress capture are explicit
local fixtures, not live-service or settlement evidence.

`lobby_readability_smoke_test` covers free/paid presentation, paid-disabled copy,
mode-specific setup, nested lobby and details return paths, fixed actions,
insufficient funds without a debit, and the Free Roll exit. It also requests an
explicit 1080×1500 logical viewport to stress short layouts; production viewport
scaling is unchanged. Focused regression checks cover contest/lobby routes, paid
entry requirements, escrow, bot practice, and the preceding menu layout.

Final verification: the native readability check and seven focused regression
checks passed. Fifteen native captures are in the review. Hash comparisons confirm
119 authoritative/pressure sources and 22 entry, matchmaking and launch method
bodies are unchanged. Python/JavaScript syntax and `git diff --check` passed.

Reproduce native captures:

```sh
python3 tools/run_menu_polish_checks.py --godot /path/to/Godot --output /tmp/lobby-review/native --capture --test lobby_readability_smoke_test
python3 tools/build_lobby_readability_review.py /tmp/lobby-review
```

Existing Godot asset UID/Unicode warnings remain. The runner accepts only the
previously documented custom-sampler diagnostic in headless checks; native runs
must have no script or engine ERROR diagnostics.

## Remaining sprint work

Owner density follow-up: use available space for the buttons. Shared choices now
start at 168 authored units, primary actions at 216 (240 in the match lobby),
and Back at 144. Body/section gaps are 16, footer gaps 12, and side margins 28.
Setup mode choices expand into spare vertical space; the single Free Roll entry
uses the full row. The follow-up native before/after review is
`../artifacts/menu-density-2026-09-24/index.html`. Its separate verification record
covers the revised layout; the eight-check record above describes the preceding
setup/lobby pass. Both native menu/lobby checks passed again for this refinement;
29 before/after screen pairs are available, including the shorter layout stress.

Results/retry and the remaining Dashboard, utility and nested leaderboard/dialog
surfaces are next. Restoring and enlarging the existing home/mode-button art is
required before menu finalization; the plain cluster panels remain layout
placeholders. Physical-device readability, safe areas, touch/drag behavior and
performance stay in the owner's combined validation pass. Live matchmaking and
authoritative-service settlement require their separate integration validation.
