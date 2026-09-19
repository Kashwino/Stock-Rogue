extends CanvasLayer
class_name ResultsScreen

## Post-heist grade card. Builds its whole UI in code, so the scene is just:
##   CanvasLayer (root) + this script.
##
## Built this way for the same reason as ChestUI: a CanvasLayer routes mouse
## input down the CONTROL tree, so the contents need a full-rect Control root
## or buttons silently stop responding.
##
## Pauses the game while shown, and emits `continued` when dismissed.

signal continued

const GRADE_COLORS := {
	"S+": Color(1.0, 0.85, 0.3), "S": Color(1.0, 0.8, 0.35),
	"A": Color(0.45, 0.95, 0.55), "B": Color(0.5, 0.8, 1.0),
	"C": Color(0.8, 0.8, 0.85), "D": Color(1.0, 0.5, 0.45),
}
const VERDICTS := {
	"S+": "They'll tell stories about this one.",
	"S": "Professional work.",
	"A": "Clean enough. You got paid.",
	"B": "Messy, but you walked out.",
	"C": "That could have gone better.",
	"D": "You're lucky to be breathing.",
}

var _root: Control
var _grade_stamp: Label
var _verdict_label: Label
var _venue_label: Label
var _rows: VBoxContainer
var _stock_label: Label
var _continue_button: Button
var _shown: bool = false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.04, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.1, 0.98)
	sb.border_color = Color(0.35, 0.36, 0.44)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(420, 0)
	panel.add_child(col)

	_venue_label = Label.new()
	_venue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_venue_label.add_theme_font_size_override("font_size", 13)
	_venue_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	col.add_child(_venue_label)

	_grade_stamp = Label.new()
	_grade_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_stamp.add_theme_font_size_override("font_size", 68)
	col.add_child(_grade_stamp)

	_verdict_label = Label.new()
	_verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_label.add_theme_font_size_override("font_size", 15)
	_verdict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_verdict_label)

	col.add_child(HSeparator.new())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	col.add_child(_rows)

	_stock_label = Label.new()
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_label.add_theme_font_size_override("font_size", 20)
	col.add_child(_stock_label)

	_continue_button = Button.new()
	_continue_button.text = "Back to the map"
	_continue_button.custom_minimum_size = Vector2(0, 74)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_button.pressed.connect(_on_continue)
	col.add_child(_continue_button)

func show_result(result: Dictionary, venue_name: String = "") -> void:
	var g: String = result.get("grade_name", "?")
	_grade_stamp.text = g
	_grade_stamp.add_theme_color_override("font_color",
		GRADE_COLORS.get(g, Color.WHITE))
	_verdict_label.text = VERDICTS.get(g, "")
	_venue_label.text = venue_name.to_upper().replace("_", " ")

	var stats: Dictionary = result.get("stats", {})
	var b: Dictionary = result.get("breakdown", {})

	for c in _rows.get_children():
		c.queue_free()
	_add_row("Hits taken", str(stats.get("hits_taken", 0)))
	_add_row("Accuracy", "%d%%" % int(b.get("accuracy", 0.0) * 100))
	_add_row("Time", _fmt_time(stats.get("time_seconds", 0.0)))
	_add_row("Kills", "%d / %d" % [stats.get("kills", 0),
		stats.get("enemies_total", 0)])
	_add_row("Intel banked", "+%d  /  NETWORK" % int(result.get("intel", 0)) if result.get("meta_saved", true) else "Could not save on this device")
	var short_result: Dictionary = result.get("short", {})
	if not short_result.is_empty():
		_add_row("Short settled", "%d gold returned (%+d profit)" % [short_result["payout"], short_result["profit"]])

	var delta: float = result.get("stock_delta", 1.0)
	var pct: float = (delta - 1.0) * 100.0
	_stock_label.text = "STOCK  %s%.0f%%" % ["+" if pct >= 0.0 else "", pct]
	_stock_label.add_theme_color_override("font_color",
		Color(0.45, 0.95, 0.55) if pct >= 0.0 else Color(1.0, 0.5, 0.45))

	_root.show()
	_shown = true
	get_tree().paused = true
	_continue_button.grab_focus()

func _add_row(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", Color(0.62, 0.63, 0.7))
	row.add_child(l)
	var v := Label.new()
	v.text = value
	row.add_child(v)
	_rows.add_child(row)

func _fmt_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	return "%d:%02d" % [m, s]

func _on_continue() -> void:
	if not _shown:
		return
	_shown = false
	get_tree().paused = false
	_root.hide()
	continued.emit()

## Never leave the game frozen if this is torn down while visible.
func _exit_tree() -> void:
	if _shown and is_inside_tree():
		get_tree().paused = false
