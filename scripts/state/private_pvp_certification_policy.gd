extends RefCounted

const FEATURE_NAME: String = "private_pvp_certification"


static func is_enabled() -> bool:
	return OS.has_feature(FEATURE_NAME)


static func is_free_private_1v1(mode_id: String, paid: bool) -> bool:
	if paid:
		return false
	var clean_mode: String = mode_id.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	return clean_mode == "1V1" or clean_mode == "PVP"


static func allows_rollout_bypass(mode_id: String, paid: bool) -> bool:
	return is_enabled() and is_free_private_1v1(mode_id, paid)
