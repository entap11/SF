class_name PerfDeterministicWindowedAdapter
extends RefCounted

const DEFAULT_TARGET_FPS: int = 30
const DEFAULT_SIMULATION_HZ: int = 10
const DEFAULT_FRAMES_PER_SIMULATION_TICK: int = 3
const DEFAULT_WARMUP_FRAMES: int = 60
const DEFAULT_MEASUREMENT_FRAMES: int = 300

var target_fps: int = DEFAULT_TARGET_FPS
var simulation_hz: int = DEFAULT_SIMULATION_HZ
var frames_per_simulation_tick: int = DEFAULT_FRAMES_PER_SIMULATION_TICK
var warmup_frames: int = DEFAULT_WARMUP_FRAMES
var measurement_frames: int = DEFAULT_MEASUREMENT_FRAMES
var simulation_active: bool = true


func _init(config: Dictionary = {}) -> void:
	target_fps = int(config.get("target_fps", DEFAULT_TARGET_FPS))
	simulation_hz = int(config.get("simulation_hz", DEFAULT_SIMULATION_HZ))
	frames_per_simulation_tick = int(config.get("frames_per_simulation_tick", DEFAULT_FRAMES_PER_SIMULATION_TICK))
	warmup_frames = int(config.get("warmup_frames", DEFAULT_WARMUP_FRAMES))
	measurement_frames = int(config.get("measurement_frames", DEFAULT_MEASUREMENT_FRAMES))
	simulation_active = bool(config.get("simulation_active", true))


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if target_fps <= 0:
		errors.append("target_fps_must_be_positive")
	if simulation_hz <= 0:
		errors.append("simulation_hz_must_be_positive")
	if frames_per_simulation_tick <= 0:
		errors.append("frames_per_simulation_tick_must_be_positive")
	if warmup_frames < 0:
		errors.append("warmup_frames_cannot_be_negative")
	if measurement_frames <= 0:
		errors.append("measurement_frames_must_be_positive")
	if target_fps != simulation_hz * frames_per_simulation_tick:
		errors.append("target_fps_must_equal_simulation_hz_times_frames_per_tick")
	if simulation_active and warmup_frames % frames_per_simulation_tick != 0:
		errors.append("warmup_frames_must_align_to_simulation_tick_boundary")
	if simulation_active and measurement_frames % frames_per_simulation_tick != 0:
		errors.append("measurement_frames_must_align_to_simulation_tick_boundary")
	return errors


func total_frames() -> int:
	return warmup_frames + measurement_frames


func warmup_ticks() -> int:
	return warmup_frames / frames_per_simulation_tick if simulation_active else 0


func measurement_ticks() -> int:
	return measurement_frames / frames_per_simulation_tick if simulation_active else 0


func total_ticks() -> int:
	return warmup_ticks() + measurement_ticks()


func should_tick(frame_number: int) -> bool:
	return simulation_active \
		and frame_number > 0 \
		and frame_number <= total_frames() \
		and frame_number % frames_per_simulation_tick == 0


func tick_number_for_frame(frame_number: int) -> int:
	if not should_tick(frame_number):
		return 0
	return frame_number / frames_per_simulation_tick


func is_measurement_frame(frame_number: int) -> bool:
	return frame_number > warmup_frames and frame_number <= total_frames()


func cadence_identity() -> Dictionary:
	return {
		"adapter_version": 1,
		"control_clock": "rendered_frame_index",
		"elapsed_wall_time_controls_simulation": false,
		"target_fps": target_fps,
		"simulation_hz": simulation_hz,
		"frames_per_simulation_tick": frames_per_simulation_tick,
		"warmup_frames": warmup_frames,
		"measurement_frames": measurement_frames,
		"total_frames": total_frames(),
		"warmup_ticks": warmup_ticks(),
		"measurement_ticks": measurement_ticks(),
		"total_ticks": total_ticks(),
		"simulation_active": simulation_active
	}
