class_name BuffTargetingRuntimeGate
extends RefCounted

const DEVICE_HARNESS_ARG: String = "--buff-targeting-device-harness"
const HEAVY_FIXTURE_ARG: String = "--buff-targeting-device-heavy-fixture"
const ROLE_ARG_PREFIX: String = "--buff-targeting-device-role="
const BUILD_ID_ARG_PREFIX: String = "--buff-targeting-device-build="
const VALID_ROLES: Array[String] = ["local", "pvp_host", "pvp_guest", "async_first", "async_second"]


static func enabled_for_runtime(production_enabled: bool, is_debug_build: bool, user_args: PackedStringArray) -> bool:
	if production_enabled:
		return true
	if not is_debug_build:
		return false
	return user_args.has(DEVICE_HARNESS_ARG)


static func heavy_fixture_enabled_for_runtime(is_debug_build: bool, user_args: PackedStringArray) -> bool:
	return is_debug_build and user_args.has(HEAVY_FIXTURE_ARG)


static func device_role(user_args: PackedStringArray) -> String:
	for arg: String in user_args:
		if not arg.begins_with(ROLE_ARG_PREFIX):
			continue
		var role: String = arg.trim_prefix(ROLE_ARG_PREFIX).strip_edges().to_lower()
		return role if VALID_ROLES.has(role) else "unspecified"
	return "unspecified"


static func device_build_id(user_args: PackedStringArray) -> String:
	for arg: String in user_args:
		if not arg.begins_with(BUILD_ID_ARG_PREFIX):
			continue
		var build_id: String = arg.trim_prefix(BUILD_ID_ARG_PREFIX).strip_edges().to_lower()
		if build_id.length() != 40:
			return "unattributed"
		for character: String in build_id:
			if not "0123456789abcdef".contains(character):
				return "unattributed"
		return build_id
	return "unattributed"
