extends Control
class_name HoneyWidget

const HoneyDripScript = preload("res://ui/hud/honey/honey_drip.gd")

@export var viewport_path: NodePath = NodePath("HoneyViewport")
@export var display_path: NodePath = NodePath("HoneyDisplay")
@export var label_path: NodePath = NodePath("HoneyViewport/HoneyRenderRoot/HoneyRenderLabel")
@export var drip_spawn_path: NodePath = NodePath("DripSpawnPoint")
@export var fx_root_path: NodePath = NodePath("HudFxRoot")
@export var profile_manager_path: NodePath = NodePath("/root/ProfileManager")
@export var honey_prefix: String = "Honey: "
@export var drip_threshold: int = 100
@export var drip_cooldown_sec: float = 0.35
@export var drip_burst_cap: int = 3
@export var drip_prewarm_count: int = 8
@export var emit_boot_brand_drip: bool = true
@export var spawn_when_hidden: bool = false

static var _boot_drip_emitted: bool = false

var _profile_manager: Node = null
var _honey_viewport: SubViewport = null
var _honey_display: TextureRect = null
var _honey_label: Label = null
var _drip_spawn_point: Node2D = null
var _fx_root: Node2D = null

var _current_honey: int = -1
var _gain_budget: int = 0
var _queued_drips: int = 0
var _cooldown_remaining: float = 0.0

var _drip_pool: Array[HoneyDrip] = []
var _drip_active: Array[HoneyDrip] = []

func _ready() -> void:
	_resolve_nodes()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	call_deferred("_sync_viewport_size")
	_bind_profile_manager()
	_prewarm_drip_pool()
	_sync_initial_honey()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_emit_boot_brand_drip_if_needed()
	set_process(true)

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not visible and not spawn_when_hidden:
		return
	_enqueue_drips_from_budget()
	_try_spawn_queued_drip()

func apply_label_font(font: Font, size: int) -> void:
	if _honey_label == null or font == null:
		return
	_honey_label.add_theme_font_override("font", font)
	_honey_label.add_theme_font_size_override("font_size", maxi(1, size))

func set_honey_value(new_value: int, reason: String = "", emit_gain: bool = true) -> void:
	var safe_value: int = maxi(0, new_value)
	if _current_honey < 0:
		_current_honey = safe_value
		_update_honey_label()
		return
	if safe_value == _current_honey:
		return
	var delta: int = safe_value - _current_honey
	_current_honey = safe_value
	_update_honey_label()
	if emit_gain and delta > 0:
		_accumulate_gain(delta)

func _resolve_nodes() -> void:
	_honey_viewport = get_node_or_null(viewport_path) as SubViewport
	_honey_display = get_node_or_null(display_path) as TextureRect
	_honey_label = get_node_or_null(label_path) as Label
	_drip_spawn_point = get_node_or_null(drip_spawn_path) as Node2D
	_fx_root = get_node_or_null(fx_root_path) as Node2D
	if _honey_viewport != null:
		_honey_viewport.transparent_bg = true
		_honey_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _honey_display != null and _honey_viewport != null:
		_honey_display.texture = _honey_viewport.get_texture()
		_honey_display.stretch_mode = TextureRect.STRETCH_SCALE
		_honey_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _fx_root == null:
		_fx_root = Node2D.new()
		_fx_root.name = "HudFxRoot"
		add_child(_fx_root)

func _bind_profile_manager() -> void:
	_profile_manager = get_node_or_null(profile_manager_path)
	if _profile_manager == null:
		return
	if _profile_manager.has_signal("honey_balance_changed"):
		var callable_ref: Callable = Callable(self, "_on_honey_balance_changed")
		if not _profile_manager.is_connected("honey_balance_changed", callable_ref):
			_profile_manager.connect("honey_balance_changed", callable_ref)

func _sync_initial_honey() -> void:
	if _profile_manager != null and _profile_manager.has_method("get_honey_balance"):
		var balance: int = int(_profile_manager.call("get_honey_balance"))
		set_honey_value(balance, "init_sync", false)
	elif _honey_label != null:
		var fallback_value: int = _extract_honey_value(_honey_label.text)
		set_honey_value(fallback_value, "init_label", false)

func _on_honey_balance_changed(new_value: int, delta: int, _reason: String) -> void:
	if _current_honey < 0:
		set_honey_value(new_value, "signal_init", false)
		return
	var safe_value: int = maxi(0, new_value)
	var previous_value: int = _current_honey
	if safe_value == _current_honey:
		return
	_current_honey = safe_value
	_update_honey_label()
	if delta > 0:
		_accumulate_gain(delta)
	elif delta == 0 and safe_value > previous_value:
		_accumulate_gain(safe_value - previous_value)

func _update_honey_label() -> void:
	if _honey_label == null:
		return
	_honey_label.text = "%s%s" % [honey_prefix, _format_number(_current_honey)]

func _accumulate_gain(delta: int) -> void:
	if delta <= 0:
		return
	_gain_budget += delta
	_enqueue_drips_from_budget()

func _enqueue_drips_from_budget() -> void:
	if drip_threshold <= 0:
		return
	if _queued_drips >= drip_burst_cap:
		return
	var ready_count: int = _gain_budget / drip_threshold
	if ready_count <= 0:
		return
	var headroom: int = maxi(0, drip_burst_cap - _queued_drips)
	if headroom <= 0:
		return
	var enqueue_count: int = mini(ready_count, headroom)
	_queued_drips += enqueue_count
	_gain_budget -= enqueue_count * drip_threshold

func _try_spawn_queued_drip() -> void:
	if _queued_drips <= 0:
		return
	if _cooldown_remaining > 0.0:
		return
	var drip: HoneyDrip = _acquire_drip()
	if drip == null:
		return
	drip.reset(_resolve_drip_spawn_position())
	_queued_drips -= 1
	_cooldown_remaining = drip_cooldown_sec

func _resolve_drip_spawn_position() -> Vector2:
	if _drip_spawn_point != null:
		return _drip_spawn_point.global_position
	if _honey_display != null:
		var display_rect: Rect2 = _honey_display.get_global_rect()
		return display_rect.position + Vector2(display_rect.size.x - 16.0, display_rect.size.y - 4.0)
	if _honey_label != null:
		var label_rect: Rect2 = _honey_label.get_global_rect()
		return label_rect.position + Vector2(label_rect.size.x - 16.0, label_rect.size.y - 4.0)
	return global_position

func _prewarm_drip_pool() -> void:
	for idx in range(maxi(0, drip_prewarm_count)):
		var drip: HoneyDrip = _create_drip_instance(idx)
		_release_drip(drip)

func _create_drip_instance(index: int) -> HoneyDrip:
	var drip_any: Variant = HoneyDripScript.new()
	var drip: HoneyDrip = drip_any as HoneyDrip
	drip.name = "HoneyDrip_%d" % index
	if not drip.finished.is_connected(_on_drip_finished):
		drip.finished.connect(_on_drip_finished)
	_fx_root.add_child(drip)
	drip.visible = false
	return drip

func _acquire_drip() -> HoneyDrip:
	var drip: HoneyDrip = null
	if _drip_pool.is_empty():
		drip = _create_drip_instance(_drip_active.size() + _drip_pool.size())
	else:
		drip = _drip_pool.pop_back()
	if drip == null:
		return null
	if not _drip_active.has(drip):
		_drip_active.append(drip)
	return drip

func _on_drip_finished(drip: HoneyDrip) -> void:
	_release_drip(drip)

func _release_drip(drip: HoneyDrip) -> void:
	if drip == null:
		return
	_drip_active.erase(drip)
	if not _drip_pool.has(drip):
		_drip_pool.append(drip)

func _emit_boot_brand_drip_if_needed() -> void:
	if not emit_boot_brand_drip:
		return
	if _boot_drip_emitted:
		return
	if not visible and not spawn_when_hidden:
		return
	var drip: HoneyDrip = _acquire_drip()
	if drip == null:
		return
	_boot_drip_emitted = true
	drip.reset(_resolve_drip_spawn_position())
	_cooldown_remaining = maxf(_cooldown_remaining, drip_cooldown_sec)

func _on_visibility_changed() -> void:
	if visible:
		_emit_boot_brand_drip_if_needed()

func _on_resized() -> void:
	_sync_viewport_size()

func _sync_viewport_size() -> void:
	if _honey_viewport == null:
		return
	var target_size: Vector2 = size
	if target_size.x < 1.0 or target_size.y < 1.0:
		target_size = custom_minimum_size
	if target_size.x < 1.0:
		target_size.x = 236.0
	if target_size.y < 1.0:
		target_size.y = 36.0
	var viewport_size: Vector2i = Vector2i(maxi(1, int(ceil(target_size.x))), maxi(1, int(ceil(target_size.y))))
	if _honey_viewport.size != viewport_size:
		_honey_viewport.size = viewport_size

func _extract_honey_value(text: String) -> int:
	var digits: String = ""
	for idx in range(text.length()):
		var ch: String = text.substr(idx, 1)
		var code: int = ch.unicode_at(0)
		if code >= 48 and code <= 57:
			digits += ch
	if digits == "":
		return 0
	return int(digits)

func _format_number(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(abs(value))
	var chunks: Array[String] = []
	while digits.length() > 3:
		chunks.push_front(digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	chunks.push_front(digits)
	var out: String = ",".join(chunks)
	if negative:
		return "-" + out
	return out
