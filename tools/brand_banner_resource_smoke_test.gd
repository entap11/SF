extends SceneTree

const BANNERS: Array[String] = [
	"res://assets/sprites/sf_skin_v1/signage_banner_yellow_top.tres",
	"res://assets/sprites/sf_skin_v1/signage_banner_yellow_red.tres",
	"res://assets/sprites/sf_skin_v1/signage_banner_reflect_yellow.tres",
	"res://assets/sprites/sf_skin_v1/signage_banner_reflect_red.tres",
	"res://assets/sprites/sf_skin_v1/signage_banner_obsideon.tres"
]

var _failed: bool = false

func _init() -> void:
	await process_frame
	for path in BANNERS:
		var texture: Texture2D = load(path) as Texture2D
		_assert_true(texture != null, "%s should load as Texture2D" % path)
		if texture != null:
			var size: Vector2 = texture.get_size()
			_assert_true(size.x >= 1200.0, "%s should keep banner-width region" % path)
			_assert_true(size.y >= 280.0, "%s should keep banner-height region" % path)
	if _failed:
		quit(1)
		return
	print("BRAND_BANNER_RESOURCE_SMOKE: PASS")
	quit(0)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_failed = true
	push_error("BRAND_BANNER_RESOURCE_SMOKE: %s" % label)
