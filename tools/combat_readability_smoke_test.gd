extends SceneTree

const Readability = preload("res://scripts/renderers/combat_readability.gd")
const Hierarchy = preload("res://scripts/renderers/lane_visual_hierarchy.gd")
var failed: bool = false

func _initialize() -> void:
	ProjectSettings.set_setting(Hierarchy.SETTINGS_ENABLED, true)
	var sample: Dictionary = {
		"viewer_owner_id": 1,
		"hives": [{"id": 1, "owner_id": 1}, {"id": 2, "owner_id": 2}, {"id": 3, "owner_id": 3}, {"id": 4, "owner_id": 2}],
		"lanes": [
			{"lane_id": 1, "a_id": 1, "b_id": 2, "send_a": true, "send_b": true},
			{"lane_id": 2, "a_id": 1, "b_id": 3, "send_a": true},
			{"lane_id": 3, "a_id": 3, "b_id": 4, "send_b": true}],
		"units": [{"from": 4, "to": 1, "owner_id": 2, "lane_id": 4}]
	}
	var original: Dictionary = sample.duplicate(true)
	var teams: Dictionary = {1: 1, 2: 2, 3: 1}
	var context: Dictionary = Readability.build_context(sample, 2, -1, teams)
	_expect(context.connections.has(1) and context.connections.has(2) and not context.connections.has(3), "enemy focus must isolate the same connection graph as friendly focus")
	_expect(context.threats[1].size() == 2, "incoming threats include units on a retracted route")
	_expect(not context.threats.has(3) or context.threats[3].size() == 1, "team feeds are not enemy attacks")
	var focus: Dictionary = Hierarchy.profile_for_context(sample.lanes[0], context)
	var feed: Dictionary = Hierarchy.profile_for_context(sample.lanes[1], context)
	var threat: Dictionary = Hierarchy.profile_for_context(sample.lanes[2], context)
	_expect(focus.alpha > threat.alpha and threat.alpha > feed.alpha, "focus is strongest and unrelated incoming threats remain visible")
	_expect(focus.z_index > threat.z_index and threat.z_index > feed.z_index, "crossing priorities must follow attention priorities")
	_expect(Readability.unit_alpha(sample.units[0], context) > 0.5, "unrelated inbound enemy units remain visible while inspecting")
	# Source 4 changes hands; its red units already in flight stay red threats.
	sample.hives[3].owner_id = 1
	context = Readability.build_context(sample, 4, -1, teams)
	_expect(context.threats[1].has("4:2"), "source capture must not erase an in-flight enemy threat")
	_expect(context.connections.has(1), "retracted in-flight routes still connect the inspected hive")
	sample.hives[3].owner_id = 2
	_expect(sample == original, "render helpers must not mutate the canonical sample")
	context = Readability.build_context(sample, 999, -1, teams)
	_expect(context.focus_hive == -1, "removed hive focus must be cleared")
	context = Readability.build_context(sample, -1, 1, teams)
	_expect(context.connections.has(1) and context.connections.has(2), "lane grab must focus both endpoints")
	print("COMBAT_READABILITY_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
