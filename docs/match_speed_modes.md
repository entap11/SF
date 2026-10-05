# Match movement speed

Base unit speed is 223.146 px/s, 15% above the previous 194.04 px/s. Fast mode is 1.5× the new base (334.719 px/s). All matches default to base; there is no menu or persistent player preference yet.

After map initialization and before starting the simulation, the match setup system can call `OpsState.configure_match_speed("fast")` or `OpsState.configure_match_speed("base")`. Check the returned `ok` and `reason`. Unknown modes and changes after a match has started are rejected. A new map resets to base.

The only authoritative selection is `OpsState.state.match_speed_mode`. UnitSystem, SwarmSystem, lane movement/arrival timing, relay travel estimates, and overflow train spacing read the derived speed from that state. Existing unit-speed buffs multiply the selected base; swarms retain their existing 2× unit-speed ratio. Production, match clocks, cooldowns, buff durations, and fixed simulation ticks keep their existing timing.

Authority snapshots (including save/resume) carry the mode, and synchronization hashes include it. Older snapshots without the field restore as base; invalid mode values reject the restore before changing state. Future multiplayer setup must distribute the same selection to every participant before simulation begins; a local UI preference must never change a running match's speed.

The fenced legacy `Arena._tick` path remains disabled. Active simulation movement continues through the authoritative systems, not `Engine.time_scale` or rendering frame deltas.
