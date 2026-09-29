# Stateless, versioned randomness: replay depends on seed/seat/decision, never uptime.
extends RefCounted

static func sample(seed_value: int, seat: int, decision: int, purpose: String) -> float:
	var text := "%d:%d:%d:%s" % [seed_value, seat, decision, purpose]
	var value: int = 2166136261
	for index in range(text.length()):
		value = ((value ^ text.unicode_at(index)) * 16777619) & 0xffffffff
	value = (value ^ (value >> 16)) & 0xffffffff
	return float(value) / 4294967296.0
