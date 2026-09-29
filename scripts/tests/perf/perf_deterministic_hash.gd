class_name PerfDeterministicHash
extends RefCounted

const DETERMINISTIC_VARIANT := preload("res://scripts/util/deterministic_variant.gd")

static func hash_variant(value: Variant) -> String:
	return DETERMINISTIC_VARIANT.hash_variant(value)


static func canonical_json(value: Variant) -> String:
	return DETERMINISTIC_VARIANT.canonical_json(value)


static func _canonical_dictionary(value: Dictionary) -> String:
	return DETERMINISTIC_VARIANT.canonical_json(value)
