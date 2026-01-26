# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name SimTuning
extends RefCounted

const UNIT_TRAVEL_MS := 4800.0
const UNIT_SPEED_PX_PER_SEC := 204.0
const LANE_ESTABLISH_MS := 2400.0
const BASE_SPAWN_MS := 1000.0
const PER_POWER_MS := 2.0
const MIN_SPAWN_MS := 200.0
const PRESSURE_PER_SPAWN := 1.0
const CAPTURE_START_POWER := 1
const MAX_POWER := 50
const LANE_FLOW_LOGS := true
const LANE_TICK_LOGS := false
const LANE_DUMP_INTERVAL_MS := 1000.0
