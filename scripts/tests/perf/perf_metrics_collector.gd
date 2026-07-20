class_name PerfMetricsCollector
extends RefCounted

const LEVEL_OFF: String = "OFF"
const LEVEL_MINIMAL: String = "MINIMAL"
const LEVEL_FULL: String = "FULL"

const DEFAULT_MINIMAL_PERCENTILE_LIMIT: int = 4096
const DEFAULT_FULL_PERCENTILE_LIMIT: int = 16384
const DEFAULT_FULL_RAW_SAMPLE_LIMIT: int = 12000
const DEFAULT_FORENSIC_LIMIT: int = 10
const MAX_FORENSIC_LIMIT: int = 64

var _level: String = LEVEL_MINIMAL
var _percentile_limit: int = DEFAULT_MINIMAL_PERCENTILE_LIMIT
var _raw_sample_limit: int = 0
var _forensic_limit: int = DEFAULT_FORENSIC_LIMIT
var _hitch_threshold_ms: float = INF
var _additional_clock_reads_per_sample: int = 2

var _sample_count: int = 0
var _sum_ms: float = 0.0
var _min_ms: float = INF
var _max_ms: float = 0.0
var _percentile_samples: Array = []
var _raw_samples: Array = []
var _worst_records: Array = []
var _hitch_count: int = 0
var _hitch_records: Array = []


func _init(
	level: String = LEVEL_MINIMAL,
	forensic_limit: int = DEFAULT_FORENSIC_LIMIT,
	hitch_threshold_ms: float = INF,
	percentile_limit_override: int = -1,
	raw_sample_limit_override: int = -1,
	additional_clock_reads_per_sample_override: int = -1
) -> void:
	_level = level.strip_edges().to_upper()
	_forensic_limit = clampi(forensic_limit, 0, MAX_FORENSIC_LIMIT)
	_hitch_threshold_ms = hitch_threshold_ms
	match _level:
		LEVEL_OFF:
			_percentile_limit = 0
			_raw_sample_limit = 0
		LEVEL_FULL:
			_percentile_limit = DEFAULT_FULL_PERCENTILE_LIMIT
			_raw_sample_limit = DEFAULT_FULL_RAW_SAMPLE_LIMIT
		_:
			_level = LEVEL_MINIMAL
			_percentile_limit = DEFAULT_MINIMAL_PERCENTILE_LIMIT
			_raw_sample_limit = 0
	if percentile_limit_override >= 0:
		_percentile_limit = percentile_limit_override
	if raw_sample_limit_override >= 0:
		_raw_sample_limit = raw_sample_limit_override
	_additional_clock_reads_per_sample = 0 if _level == LEVEL_OFF else 2
	if _level != LEVEL_OFF and additional_clock_reads_per_sample_override >= 0:
		_additional_clock_reads_per_sample = additional_clock_reads_per_sample_override


func level() -> String:
	return _level


func timing_enabled() -> bool:
	return _level != LEVEL_OFF


func full_capture_enabled() -> bool:
	return _level == LEVEL_FULL


func needs_forensic_context(duration_ms: float) -> bool:
	if not timing_enabled() or _forensic_limit <= 0:
		return false
	return _qualifies_for_top(_worst_records, duration_ms) \
		or (duration_ms > _hitch_threshold_ms and _qualifies_for_top(_hitch_records, duration_ms))


func observe(sample_index: int, duration_ms: float, context: Dictionary = {}) -> void:
	if not timing_enabled():
		return
	_sample_count += 1
	_sum_ms += duration_ms
	_min_ms = minf(_min_ms, duration_ms)
	_max_ms = maxf(_max_ms, duration_ms)
	_retain_percentile_sample(duration_ms)
	if full_capture_enabled() and _raw_sample_limit > 0 and _raw_samples.size() < _raw_sample_limit:
		_raw_samples.append({"sample_index": sample_index, "duration_ms": duration_ms})
	var retain_worst: bool = _qualifies_for_top(_worst_records, duration_ms)
	var retain_hitch: bool = duration_ms > _hitch_threshold_ms and _qualifies_for_top(_hitch_records, duration_ms)
	if duration_ms > _hitch_threshold_ms:
		_hitch_count += 1
	if retain_worst or retain_hitch:
		var record := {
			"sample_index": sample_index,
			"duration_ms": duration_ms,
			"context": context.duplicate(true) if not context.is_empty() else {}
		}
		if retain_worst:
			_retain_top_record(_worst_records, record, _forensic_limit)
		if retain_hitch:
			_retain_top_record(_hitch_records, record, _forensic_limit)


func summary() -> Dictionary:
	var available: bool = timing_enabled() and _sample_count > 0
	var percentile_dropped: int = maxi(0, _sample_count - _percentile_samples.size())
	var raw_dropped: int = maxi(0, _sample_count - _raw_samples.size()) if full_capture_enabled() else 0
	return {
		"level": _level,
		"timing_enabled": timing_enabled(),
		"available": available,
		"unavailable_reason": "collection level OFF disables per-sample timing" if not timing_enabled() else "no measured samples" if not available else "",
		"sample_count": _sample_count,
		"average_ms": (_sum_ms / float(_sample_count)) if available else null,
		"median_ms": _percentile(_percentile_samples, 0.5) if available else null,
		"p95_ms": _percentile(_percentile_samples, 0.95) if available else null,
		"p99_ms": _percentile(_percentile_samples, 0.99) if available else null,
		"p999_ms": _percentile(_percentile_samples, 0.999) if available else null,
		"min_ms": _min_ms if available else null,
		"max_ms": _max_ms if available else null,
		"hitch_count": _hitch_count if available else null,
		"worst_records": _worst_records.duplicate(true),
		"hitch_records": _hitch_records.duplicate(true),
		"raw_samples": _raw_samples.duplicate(true) if full_capture_enabled() else [],
		"retention": {
			"percentile_sample_limit": _percentile_limit,
			"retained_percentile_sample_count": _percentile_samples.size(),
			"dropped_percentile_sample_count": percentile_dropped,
			"percentiles_exact": available and percentile_dropped == 0,
			"forensic_record_limit": _forensic_limit,
			"retained_worst_record_count": _worst_records.size(),
			"retained_hitch_record_count": _hitch_records.size(),
			"raw_sample_capture": full_capture_enabled(),
			"raw_sample_limit": _raw_sample_limit,
			"retained_raw_sample_count": _raw_samples.size(),
			"dropped_raw_sample_count": raw_dropped,
			"truncated": percentile_dropped > 0 or raw_dropped > 0 or _hitch_count > _hitch_records.size()
		},
		"overhead_contract": _overhead_contract()
	}


func _retain_percentile_sample(duration_ms: float) -> void:
	if _percentile_limit <= 0:
		return
	if _percentile_samples.size() < _percentile_limit:
		_percentile_samples.append(duration_ms)
		return
	# Deterministic reservoir retention keeps memory bounded and makes identical
	# input sequences produce identical percentile samples.
	var candidate: int = posmod((_sample_count * 1103515245) + 12345, _sample_count)
	if candidate < _percentile_limit:
		_percentile_samples[candidate] = duration_ms


func _retain_top_record(records: Array, record: Dictionary, limit: int) -> void:
	if limit <= 0:
		return
	if records.size() < limit:
		records.append(record.duplicate(true))
	else:
		var smallest_duration: float = float((records[records.size() - 1] as Dictionary).get("duration_ms", 0.0))
		if float(record.get("duration_ms", 0.0)) <= smallest_duration:
			return
		records[records.size() - 1] = record.duplicate(true)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var duration_a: float = float(a.get("duration_ms", 0.0))
		var duration_b: float = float(b.get("duration_ms", 0.0))
		if not is_equal_approx(duration_a, duration_b):
			return duration_a > duration_b
		return int(a.get("sample_index", 0)) < int(b.get("sample_index", 0))
	)


func _qualifies_for_top(records: Array, duration_ms: float) -> bool:
	if _forensic_limit <= 0:
		return false
	if records.size() < _forensic_limit:
		return true
	return duration_ms > float((records[records.size() - 1] as Dictionary).get("duration_ms", 0.0))


func _overhead_contract() -> Dictionary:
	match _level:
		LEVEL_OFF:
			return {
				"additional_per_sample_clock_reads": 0,
				"aggregate_updates": false,
				"percentile_retention": false,
				"raw_sample_allocation": false,
				"forensic_context_copied_only_when_retained": false
			}
		LEVEL_FULL:
			return {
				"additional_per_sample_clock_reads": _additional_clock_reads_per_sample,
				"aggregate_updates": true,
				"percentile_retention": true,
				"raw_sample_allocation": true,
				"forensic_context_copied_only_when_retained": true
			}
		_:
			return {
				"additional_per_sample_clock_reads": _additional_clock_reads_per_sample,
				"aggregate_updates": true,
				"percentile_retention": true,
				"raw_sample_allocation": false,
				"forensic_context_copied_only_when_retained": true
			}


func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(round(percentile * float(sorted.size() - 1))), 0, sorted.size() - 1)
	return float(sorted[index])
