extends SceneTree

const BuffStripVisibilityPolicy := preload("res://scripts/ui/buff_strip_visibility_policy.gd")

var _failed: bool = false

func _init() -> void:
	_set_match_meta("STAGE_RACE", false, true)
	_expect(not BuffStripVisibilityPolicy.should_show_opponent_buff_strips(self), "async Stage Race should hide opponent buff strips")

	_set_match_meta("ASYNC_SINGLE_MAP_TIMED", false, true)
	_expect(not BuffStripVisibilityPolicy.should_show_opponent_buff_strips(self), "async single-map timed should hide opponent buff strips")

	_set_match_meta("CAPTURE_FLAG", false, true)
	_expect(not BuffStripVisibilityPolicy.should_show_opponent_buff_strips(self), "CPU capture flag should hide opponent buff strips")

	_set_match_meta("1V1", true, false)
	_expect(BuffStripVisibilityPolicy.should_show_opponent_buff_strips(self), "human PvP should show opponent buff strips")

	_set_match_meta("1V1", true, true)
	_expect(not BuffStripVisibilityPolicy.should_show_opponent_buff_strips(self), "bot-filled PvP should hide opponent buff strips")

	if not _failed:
		print("BUFF_STRIP_VISIBILITY_POLICY_SMOKE: PASS")
	quit(1 if _failed else 0)

func _set_match_meta(mode: String, human_pvp: bool, remote_is_cpu: bool) -> void:
	set_meta("vs_mode", mode)
	set_meta("human_pvp", human_pvp)
	set_meta("vs_remote_profile", {
		"uid": "remote",
		"display_name": "Remote",
		"is_cpu": remote_is_cpu
	})

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_STRIP_VISIBILITY_POLICY_SMOKE: %s" % message)
