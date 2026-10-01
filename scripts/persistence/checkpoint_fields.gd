extends RefCounted

# Only explicit, data-only fields cross the persistence boundary. Never encode Objects.
static func capture(source: Object, fields: Array) -> Dictionary:
	var result: Dictionary = {}
	for field in fields:
		var value: Variant = source.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

static func restore(target: Object, fields: Array, saved: Dictionary) -> void:
	for field in fields:
		if not saved.has(field):
			continue
		var value: Variant = saved[field]
		var current: Variant = target.get(field)
		# assign preserves typed collections, including integer dictionary keys.
		if current is Array and value is Array:
			current.assign(value.duplicate(true))
		elif current is Dictionary and value is Dictionary:
			current.clear()
			current.merge(value.duplicate(true))
		else:
			target.set(field, value)
