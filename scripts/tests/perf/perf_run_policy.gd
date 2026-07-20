class_name PerfRunPolicy
extends RefCounted

const HARNESS_ARG: String = "--sf-perf-harness"


static func enabled_for_runtime(is_debug_build: bool, user_args: PackedStringArray) -> bool:
	return is_debug_build and user_args.has(HARNESS_ARG)


static func refusal_reason(is_debug_build: bool, user_args: PackedStringArray) -> String:
	if not is_debug_build:
		return "release_build_refused"
	if not user_args.has(HARNESS_ARG):
		return "missing_required_argument:%s" % HARNESS_ARG
	return ""
