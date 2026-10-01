extends RefCounted

const VERSION := 1
const MAX_BYTES := 64 * 1024 * 1024
var root_path := "user://saved_matches"

func path_for(owner: String, id: String) -> String:
	return root_path.path_join(owner.sha256_text()).path_join(id.sha256_text() + ".save")

func write(owner: String, id: String, payload: Dictionary) -> bool:
	if owner.is_empty() or id.is_empty():
		return false
	var path := path_for(owner, id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return false
	var bytes := var_to_bytes(payload)
	if bytes.size() > MAX_BYTES:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"version": VERSION, "owner": owner, "id": id, "sha256": _digest(bytes), "bytes": bytes})
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func read(owner: String, id: String) -> Dictionary:
	return _read_path(path_for(owner, id), owner)

func list_for(owner: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := root_path.path_join(owner.sha256_text())
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return result
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".save"):
			continue
		var saved := _read_path(directory.path_join(name), owner)
		if not saved.is_empty():
			result.append(saved)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("saved_at", 0)) > int(b.get("saved_at", 0)))
	return result

func remove(owner: String, id: String) -> void:
	var path := path_for(owner, id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _read_path(path: String, owner: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES + 4096:
		return {}
	# Never deserialize Objects from disk.
	var envelope: Variant = file.get_var(false)
	if not envelope is Dictionary or int(envelope.get("version", 0)) != VERSION or str(envelope.get("owner", "")) != owner:
		return {}
	var bytes: Variant = envelope.get("bytes")
	if not bytes is PackedByteArray or _digest(bytes) != str(envelope.get("sha256", "")):
		return {}
	var payload: Variant = bytes_to_var(bytes)
	if not payload is Dictionary or str(payload.get("owner", "")) != owner or str(payload.get("id", "")) != str(envelope.get("id", "")):
		return {}
	return payload

func _digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
