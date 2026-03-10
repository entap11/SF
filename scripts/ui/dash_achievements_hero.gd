extends Control
class_name DashAchievementsHero

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"

const FUTURE_TRACKS := [
	"Async records and map mastery boards",
	"Placement awards and seasonal badges",
	"Contest ribbons, streaks, and category crowns",
	"Profile achievements linked to cosmetic and honey rewards"
]

@onready var title_label: Label = $VBox/Header/Title
@onready var sub_label: Label = $VBox/Header/Sub
@onready var unlocked_panel_header: Label = $VBox/Body/TopRow/UnlockedPanel/UnlockedVBox/UnlockedHeader
@onready var unlocked_panel_sub: Label = $VBox/Body/TopRow/UnlockedPanel/UnlockedVBox/UnlockedSub
@onready var unlocked_list: VBoxContainer = $VBox/Body/TopRow/UnlockedPanel/UnlockedVBox/UnlockedList
@onready var roadmap_panel_header: Label = $VBox/Body/TopRow/RoadmapPanel/RoadmapVBox/RoadmapHeader
@onready var roadmap_panel_sub: Label = $VBox/Body/TopRow/RoadmapPanel/RoadmapVBox/RoadmapSub
@onready var roadmap_list: VBoxContainer = $VBox/Body/TopRow/RoadmapPanel/RoadmapVBox/RoadmapList
@onready var footer_label: Label = $VBox/Body/FooterPanel/FooterVBox/FooterText

var _font_regular: Font = null
var _font_semibold: Font = null

func _ready() -> void:
	_load_fonts()
	_style_ui()
	refresh_view()

func refresh_view() -> void:
	_refresh_unlocked()
	_refresh_roadmap()
	_refresh_footer()

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH) as Font
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		_font_semibold = load(FONT_SEMIBOLD_PATH) as Font

func _style_ui() -> void:
	title_label.text = "ACHIEVEMENTS"
	sub_label.text = "Current awards, unlocked achievements, and the future async records layer."
	unlocked_panel_header.text = "UNLOCKED NOW"
	roadmap_panel_header.text = "NEXT DEFINITIONS"
	_apply_font(title_label, _font_semibold, 24)
	_apply_font(sub_label, _font_regular, 13)
	_apply_font(unlocked_panel_header, _font_semibold, 14)
	_apply_font(unlocked_panel_sub, _font_regular, 12)
	_apply_font(roadmap_panel_header, _font_semibold, 14)
	_apply_font(roadmap_panel_sub, _font_regular, 12)
	_apply_font(footer_label, _font_regular, 12)
	_style_panel($VBox/Body/TopRow/UnlockedPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/TopRow/RoadmapPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))
	_style_panel($VBox/Body/FooterPanel, Color(0.08, 0.09, 0.12, 0.92), Color(0.34, 0.36, 0.44, 0.72))

func _refresh_unlocked() -> void:
	for child in unlocked_list.get_children():
		child.queue_free()
	var unlocked: Dictionary = {}
	if ProfileManager != null and ProfileManager.has_method("get_unlocked_achievements"):
		var unlocked_any: Variant = ProfileManager.call("get_unlocked_achievements")
		if typeof(unlocked_any) == TYPE_DICTIONARY:
			unlocked = (unlocked_any as Dictionary).duplicate(true)
	var unlocked_ids: Array = unlocked.keys()
	unlocked_ids.sort()
	unlocked_panel_sub.text = "%d achievements currently unlocked on this profile." % unlocked_ids.size()
	if unlocked_ids.is_empty():
		var empty := Label.new()
		empty.text = "No live achievements granted yet."
		_apply_font(empty, _font_regular, 12)
		unlocked_list.add_child(empty)
		return
	for achievement_id_any in unlocked_ids:
		var label := Label.new()
		label.text = str(achievement_id_any).replace("_", " ").to_upper()
		_apply_font(label, _font_semibold, 12)
		unlocked_list.add_child(label)

func _refresh_roadmap() -> void:
	for child in roadmap_list.get_children():
		child.queue_free()
	roadmap_panel_sub.text = "This tab can absorb async records, ribbons, awards, and achievement scarcity later."
	for item in FUTURE_TRACKS:
		var label := Label.new()
		label.text = item
		apply_regular(label)
		roadmap_list.add_child(label)

func _refresh_footer() -> void:
	footer_label.text = "Dash tab three is intentionally broader than badges. It gives us one home for async records, achievements, awards, and recognition surfaces without redesigning the drawer again."

func apply_regular(control: Control) -> void:
	_apply_font(control, _font_regular, 12)

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null:
		return
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", maxi(1, size))

func _style_panel(panel: Control, fill: Color, border: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)
