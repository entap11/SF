class_name PerfDeterministicHash
extends RefCounted


static func hash_variant(value: Variant) -> String:
	return canonical_json(value).sha256_text()


static func canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return JSON.stringify(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var rows: Array[String] = []
			for item in value as Array:
				rows.append(canonical_json(item))
			return "[%s]" % ",".join(rows)
		TYPE_DICTIONARY:
			return _canonical_dictionary(value as Dictionary)
		_:
			return JSON.stringify(str(value))


static func _canonical_dictionary(value: Dictionary) -> String:
	var keyed: Array[Dictionary] = []
	for key_any in value.keys():
		keyed.append({"key": str(key_any), "value": value.get(key_any)})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", ""))
	)
	var rows: Array[String] = []
	for entry in keyed:
		rows.append("%s:%s" % [
			JSON.stringify(str(entry.get("key", ""))),
			canonical_json(entry.get("value"))
		])
	return "{%s}" % ",".join(rows)
