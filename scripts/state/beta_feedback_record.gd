extends RefCounted

const PROMPT_PATH := "user://beta_feedback_prompt.json"
const EXPERIENCE_PATH := "user://beta_feedback_experience.json"
const VALUES := {
	"experience": ["unknown", "new", "intermediate", "experienced"],
	"challenge": ["too_easy", "about_right", "too_hard"],
	"interesting": ["yes", "partly", "no"],
	"controls": ["yes", "no", "unsure"]
}

static func valid_answers(answers: Dictionary) -> bool:
	if answers.size() != VALUES.size():
		return false
	for key in VALUES:
		if answers.get(key) not in VALUES[key]:
			return false
	return true

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func write_json(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var err := file.get_error()
	file.close()
	return err == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

static func acknowledge(path: String, receipt: Dictionary, sent_hash: String) -> bool:
	if receipt.get("ok") != true or receipt.get("sha256") != sent_hash:
		return false
	if receipt.get("capture_id") != path.get_file().trim_suffix(".feedback.json"):
		return false
	if FileAccess.get_sha256(path) != sent_hash:
		return false
	return DirAccess.remove_absolute(path) == OK
