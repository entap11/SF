extends Control
class_name DashAchievementsHero

const UITypography := preload("res://scripts/ui/ui_typography.gd")

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
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()

func _style_ui() -> void:
	title_label.text = "ACHIEVEMENTS"
	sub_label.text = "Your unlocked awards and upcoming challenges."
	unlocked_panel_header.text = "UNLOCKED NOW"
	roadmap_panel_header.text = "COMING NEXT"
	_apply_token(title_label, _font_semibold, "screen_title")
	_apply_token(sub_label, _font_regular, "panel_subtitle")
	_apply_token(unlocked_panel_header, _font_semibold, "section_title")
	_apply_token(unlocked_panel_sub, _font_regular, "body")
	_apply_token(roadmap_panel_header, _font_semibold, "section_title")
	_apply_token(roadmap_panel_sub, _font_regular, "body")
	_apply_token(footer_label, _font_regular, "meta")
	var footer_panel: Control = footer_label.get_parent().get_parent() as Control
	if footer_panel != null:
		footer_panel.visible = false
		footer_panel.custom_minimum_size = Vector2.ZERO
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
		_apply_token(empty, _font_regular, "body")
		unlocked_list.add_child(empty)
		return
	for achievement_id_any in unlocked_ids:
		var label := Label.new()
		label.text = str(achievement_id_any).replace("_", " ").to_upper()
		_apply_token(label, _font_semibold, "body")
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
	_apply_token(control, _font_regular, "body")

func _apply_font(control: Control, font: Font, size: int) -> void:
	UITypography.apply_font(control, font, size, UITypography.PORTRAIT_CANVAS_SCALE)

func _apply_token(control: Control, font: Font, token: String) -> void:
	UITypography.apply_token(control, font, token, UITypography.PORTRAIT_CANVAS_SCALE)

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
