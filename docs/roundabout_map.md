# Roundabout

`res://maps/roundabout/MAP_roundabout__SBASE__3p.json` is a three-player FFA map on the 18×28 board. Twelve ordinary hives form a ring around an empty center; there are no walls, towers, barracks, or structure slots. Clear lanes across the center remain legal.

Each player starts with one 10-power hive and two nearby 5-power neutral expansions. Three additional 5-power neutrals separate the territories. Hive IDs run around the ring in order:

| Player | Starting hive | Nearby expansions | Shared border hives |
| --- | --- | --- | --- |
| P1 | 1 | 12, 2 | 11 with P3; 3 with P2 |
| P2 | 5 | 4, 6 | 3 with P1; 7 with P3 |
| P3 | 9 | 8, 10 | 7 with P2; 11 with P1 |

The ring uses half-cell coordinates around `(8.5, 13.5)`. Its orientation is intentional: the original upright arrangement blocked the direct lane between two starts under the existing hive connection geometry. The final layout gives each start seven legal targets, including both opponents and both nearby expansions. Nearby expansion distances differ by less than 1%; distances between starting hives differ by less than 0.3%.

Validation uses the production map loader, `GameState.can_connect`, the three-player lobby and handshake selectors, and both opening lane intents under all six player-to-start assignments. These checks establish opening access and map compatibility; competitive balance still needs playtesting.
