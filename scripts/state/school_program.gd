class_name SchoolProgram
extends RefCounted

const ScholasticTypesScript = preload("res://scripts/state/scholastic_types.gd")

static func new_school_program(school_id: String, identity: Dictionary = {}) -> Dictionary:
	var clean_id: String = ScholasticTypesScript.normalize_id(school_id)
	if clean_id.is_empty():
		clean_id = ScholasticTypesScript.normalize_id(str(identity.get("school_name", "school")))
	return {
		"school_id": clean_id,
		"school_name": ScholasticTypesScript.clean_text(str(identity.get("school_name", "")), 96),
		"city": ScholasticTypesScript.clean_text(str(identity.get("city", "")), 64),
		"state": ScholasticTypesScript.clean_text(str(identity.get("state", "")), 32).to_upper(),
		"mascot_name": ScholasticTypesScript.clean_text(str(identity.get("mascot_name", "")), 48),
		"colors": ScholasticTypesScript.sanitize_colors(identity.get("colors", []) as Array),
		"logo_asset_id": ScholasticTypesScript.clean_text(str(identity.get("logo_asset_id", "")), 96),
		"fight_song_asset_id": ScholasticTypesScript.clean_text(str(identity.get("fight_song_asset_id", "")), 96),
		"verification_status": str(identity.get("verification_status", ScholasticTypesScript.VERIFICATION_UNVERIFIED)).strip_edges().to_upper(),
		"teams": [],
		"membership_by_player_id": {},
		"created_at_unix": int(identity.get("created_at_unix", 0)),
		"updated_at_unix": int(identity.get("updated_at_unix", 0))
	}

static func merge_identity(program: Dictionary, identity: Dictionary) -> Dictionary:
	var out: Dictionary = program.duplicate(true)
	for key: String in ["school_name", "city", "state", "mascot_name", "logo_asset_id", "fight_song_asset_id", "verification_status"]:
		if identity.has(key):
			out[key] = ScholasticTypesScript.clean_text(str(identity.get(key, "")), 96)
	if identity.has("state"):
		out["state"] = str(out.get("state", "")).to_upper()
	if identity.has("colors"):
		out["colors"] = ScholasticTypesScript.sanitize_colors(identity.get("colors", []) as Array)
	return out
