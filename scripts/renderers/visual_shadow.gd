class_name VisualShadow
extends Sprite2D

@export var shadow_color: Color = Color(0.02, 0.02, 0.03, 1.0)

func sync_from_sprite(
	source: Sprite2D,
	projected_offset: Vector2,
	projected_scale: Vector2,
	alpha: float,
	z_index_value: int
) -> void:
	if source == null or not is_instance_valid(source) or source.texture == null:
		visible = false
		return

	texture = source.texture
	centered = source.centered
	offset = source.offset
	flip_h = source.flip_h
	flip_v = source.flip_v
	hframes = source.hframes
	vframes = source.vframes
	frame = source.frame
	region_enabled = source.region_enabled
	region_rect = source.region_rect
	position = source.position + projected_offset
	rotation = source.rotation
	scale = Vector2(
		source.scale.x * maxf(0.01, projected_scale.x),
		source.scale.y * maxf(0.01, projected_scale.y)
	)
	z_index = z_index_value
	material = null
	self_modulate = Color(shadow_color.r, shadow_color.g, shadow_color.b, clampf(alpha, 0.0, 1.0))
	visible = alpha > 0.0
