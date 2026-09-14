extends CanvasLayer
class_name DeathScreen

## Shown when a run ends. Two flavours:
##   BUSTED  — died inside a building (loot lost, run over)
##   RETIRED — cleared Doomsday and got out (victory)
##
## Built entirely in code, so the scene is just: CanvasLayer + this script.
## Call show_death(summary) or show_victory(summary).

signal dismissed()

var _root: Control
var _title: Label
var _subtitle: Label
var _stats_box: VBoxContainer
var _button: Button
var _dim: ColorRect
var _panel: PanelContainer

func _ready() -> void:
	layer = 100
	_build()
	_root.hide()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.04, 0.0)   # fades in
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.55, 0.12, 0.12)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 46; sb.content_margin_right = 46
	sb.content_margin_top = 34; sb.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	_panel = panel

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	panel.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 54)
	col.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color(0.68, 0.68, 0.74))
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_subtitle)

	var sep := HSeparator.new()
	col.add_child(sep)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	col.add_child(_stats_box)

	_button = Button.new()
	_button.text = "Back to the street"
	_button.custom_minimum_size = Vector2(0, 40)
	_button.pressed.connect(_on_pressed)
	col.add_child(_button)

## summary keys (all optional): heists, stage, gold, index, kills, best_grade, venue
func show_death(summary: Dictionary = {}) -> void:
	_present("BUSTED", Color(0.92, 0.25, 0.25),
		"You bled out on the floor. The crew scattered, the take is gone, and "
		+ "the market never heard your name.", summary, Color(0.55, 0.12, 0.12))

func show_victory(summary: Dictionary = {}) -> void:
	_present("RETIRED", Color(0.45, 0.95, 0.55),
		"You walked away clean with the whole empire behind you. "
		+ "Nobody does that twice.", summary, Color(0.18, 0.5, 0.25))

func _present(title: String, colour: Color, blurb: String,
		summary: Dictionary, border: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", colour)
	_subtitle.text = blurb

	# Recolour the panel border to match the outcome.
	if _panel:
		var sb := _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_color = border

	for c in _stats_box.get_children():
		c.queue_free()
	_add_stat("Heists pulled", str(summary.get("heists", 0)))
	_add_stat("Reached", String(summary.get("stage", "Town")))
	_add_stat("Gold on hand", "⦿ " + str(summary.get("gold", 0)))
	_add_stat("Empire index", "%d" % int(summary.get("index", 1.0)))
	if summary.has("kills"):
		_add_stat("Bodies", str(summary["kills"]))

	# Process while paused BEFORE creating tweens, or they'd freeze instantly.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.show()
	get_tree().paused = true

	# Fade the dim in, then pop the title.
	_dim.color = Color(0.02, 0.02, 0.04, 0.0)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "color", Color(0.02, 0.02, 0.04, 0.86), 0.5)
	# Size the pivot from the label's minimum size — reading .size here would
	# give 0 because the container hasn't laid out yet, and awaiting a frame is
	# unreliable while the tree is paused.
	_title.pivot_offset = _title.get_minimum_size() * 0.5
	_title.scale = Vector2(1.6, 1.6)
	var tw2 := create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(_title, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _add_stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", Color(0.62, 0.62, 0.7))
	row.add_child(l)
	var v := Label.new()
	v.text = value
	row.add_child(v)
	_stats_box.add_child(row)

func _on_pressed() -> void:
	# This screen is parented to the tree ROOT (so it survives the heist scene
	# being freed), which means changing scenes does NOT remove it — it would
	# sit on top of the menu forever. Free it explicitly.
	get_tree().paused = false
	dismissed.emit()
	get_tree().change_scene_to_file("res://home_screen.tscn")
	queue_free()
