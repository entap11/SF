class_name BuffTargetingPresentationConfig
extends RefCounted

# Presentation-only values. Distances are root-screen pixels unless explicitly
# named otherwise; durations use seconds and frequencies use hertz.
const TOUCH_SLOP_ROOT_SCREEN_PX: float = 18.0
const TOUCH_OVERLAY_OFFSET_ROOT_SCREEN_PX: Vector2 = Vector2(0.0, -56.0)
const MOUSE_OVERLAY_OFFSET_ROOT_SCREEN_PX: Vector2 = Vector2(0.0, -28.0)
const DRAG_OVERLAY_SIZE_UI_PX: Vector2 = Vector2(112.0, 112.0)

const ELIGIBLE_PULSE_FREQUENCY_HZ: float = 1.6
const ELIGIBLE_PULSE_ALPHA_MIN: float = 0.26
const ELIGIBLE_PULSE_ALPHA_MAX: float = 0.64
const PREVIEW_PULSE_STRENGTH: float = 0.98

const HIVE_ACQUISITION_RADIUS_ROOT_SCREEN_PX: float = 52.0
const HIVE_RETENTION_RADIUS_ROOT_SCREEN_PX: float = 72.0
const HIVE_SWITCH_MARGIN_ROOT_SCREEN_PX: float = 14.0
const HIVE_VISIBLE_FOOTPRINT_PADDING_ROOT_SCREEN_PX: float = 18.0
const HIVE_RETENTION_EXTRA_ROOT_SCREEN_PX: float = 20.0
const HIVE_ELIGIBLE_RING_PAD_ROOT_SCREEN_PX: float = 16.0
const HIVE_PREVIEW_RING_PAD_ROOT_SCREEN_PX: float = 26.0
const HIVE_ELIGIBLE_RING_WIDTH_ROOT_SCREEN_PX: float = 5.0
const HIVE_PREVIEW_RING_WIDTH_ROOT_SCREEN_PX: float = 8.0

const LANE_ACQUISITION_RADIUS_ROOT_SCREEN_PX: float = 44.0
const LANE_RETENTION_RADIUS_ROOT_SCREEN_PX: float = 64.0
const LANE_SWITCH_MARGIN_ROOT_SCREEN_PX: float = 12.0
const LANE_ELIGIBLE_WIDTH_LOCAL_PX: float = 10.0
const LANE_PREVIEW_WIDTH_LOCAL_PX: float = 22.0
const LANE_PREVIEW_BACKDROP_WIDTH_LOCAL_PX: float = 28.0
const LANE_TRAVEL_PERIOD_LOCAL_PX: float = 54.0
const LANE_TRAVEL_LENGTH_LOCAL_PX: float = 19.0
const GLOBAL_BOUNDARY_WIDTH_LOCAL_PX: float = 9.0

const INVALID_RELEASE_SNAP_BACK_SECONDS: float = 0.16
const SUCCESS_FLASH_DURATION_SECONDS: float = 0.42
const SUCCESS_FLASH_STRENGTH: float = 1.0
const SUCCESS_HIVE_RING_PAD_LOCAL_PX: float = 14.0
const SUCCESS_HIVE_RING_WIDTH_LOCAL_PX: float = 9.0
const SUCCESS_LANE_WIDTH_LOCAL_PX: float = 20.0
const SUCCESS_GLOBAL_WIDTH_LOCAL_PX: float = 10.0

# Presentation receipts never own, release, commit, or cancel gameplay state.
const ACTIVATION_RECEIPT_TIMEOUT_MSEC: int = 8000
const MAX_LIVE_ACTIVATION_RECEIPTS: int = 32
const MAX_HANDLED_OUTCOMES: int = 128
const MAX_LATENCY_SAMPLES: int = 256


static func tuning_snapshot() -> Dictionary:
	return {
		"touch_slop_root_screen_px": TOUCH_SLOP_ROOT_SCREEN_PX,
		"touch_overlay_offset_root_screen_px": TOUCH_OVERLAY_OFFSET_ROOT_SCREEN_PX,
		"mouse_overlay_offset_root_screen_px": MOUSE_OVERLAY_OFFSET_ROOT_SCREEN_PX,
		"eligible_pulse_frequency_hz": ELIGIBLE_PULSE_FREQUENCY_HZ,
		"eligible_pulse_alpha_min": ELIGIBLE_PULSE_ALPHA_MIN,
		"eligible_pulse_alpha_max": ELIGIBLE_PULSE_ALPHA_MAX,
		"preview_pulse_strength": PREVIEW_PULSE_STRENGTH,
		"hive_preview_ring_width_root_screen_px": HIVE_PREVIEW_RING_WIDTH_ROOT_SCREEN_PX,
		"lane_preview_width_local_px": LANE_PREVIEW_WIDTH_LOCAL_PX,
		"hive_acquisition_radius_root_screen_px": HIVE_ACQUISITION_RADIUS_ROOT_SCREEN_PX,
		"hive_retention_radius_root_screen_px": HIVE_RETENTION_RADIUS_ROOT_SCREEN_PX,
		"hive_switch_margin_root_screen_px": HIVE_SWITCH_MARGIN_ROOT_SCREEN_PX,
		"lane_acquisition_radius_root_screen_px": LANE_ACQUISITION_RADIUS_ROOT_SCREEN_PX,
		"lane_retention_radius_root_screen_px": LANE_RETENTION_RADIUS_ROOT_SCREEN_PX,
		"lane_switch_margin_root_screen_px": LANE_SWITCH_MARGIN_ROOT_SCREEN_PX,
		"invalid_release_snap_back_seconds": INVALID_RELEASE_SNAP_BACK_SECONDS,
		"success_flash_duration_seconds": SUCCESS_FLASH_DURATION_SECONDS,
		"success_flash_strength": SUCCESS_FLASH_STRENGTH,
		"receipt_timeout_msec": ACTIVATION_RECEIPT_TIMEOUT_MSEC,
		"max_live_receipts": MAX_LIVE_ACTIVATION_RECEIPTS,
		"max_handled_outcomes": MAX_HANDLED_OUTCOMES,
		"max_latency_samples": MAX_LATENCY_SAMPLES
	}
