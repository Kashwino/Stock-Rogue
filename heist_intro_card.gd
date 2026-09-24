extends CanvasLayer
class_name HeistIntroCard
## A two-and-a-half second title card as the job starts: the venue's name in
## neon, local time, security level, the objective and any modifiers. Skip it
## with any key, click or tap. It never pauses: you are still on the street.

signal finished

var venue_name := ""
var sign_name := ""
var security := 0
var objective := "LOOT"
var objective_detail := ""
var modifiers: Array = []       # [[title, detail, optional chip colour], ...]
var boss_title := ""
var duration := 2.6
var _root: Control
var _done := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var band := ColorRect.new()
	band.color = Color(0.02, 0.02, 0.03, 0.86)
	band.position = Vector2(0, 170)
	band.size = Vector2(1280, 330)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)
	for y in [170.0, 498.0]:
		var rule := ColorRect.new()
		rule.color = Palette.GOLD_DIM
		rule.position = Vector2(0, y)
		rule.size = Vector2(1280, 2)
		_root.add_child(rule)
	var hour := 1 + absi(hash(sign_name)) % 4
	var minute := absi(hash(venue_name)) % 60
	var kicker := VisualTheme.label("LOCAL TIME  0%d:%02d AM   ·   %s" % [hour, minute, venue_name.to_upper()], "KickerLabel", 20)
	kicker.position = Vector2(90, 196)
	_root.add_child(kicker)
	var title := VisualTheme.label(sign_name, "TitleLabel", 70, Palette.GOLD_PALE)
	title.position = Vector2(86, 222)
	_root.add_child(title)
	if boss_title != "":
		var boss := VisualTheme.label(boss_title, "HeadingLabel", 30, Palette.DANGER)
		boss.position = Vector2(90, 316)
		_root.add_child(boss)
	var levels := ["LIGHT", "MODERATE", "HEAVY", "SEVERE", "MAXIMUM"]
	var sec := VisualTheme.label("SECURITY", "KickerLabel", 18)
	sec.position = Vector2(90, 362)
	_root.add_child(sec)
	var bars := SecurityBars.new()
	bars.level = clampi(security, 0, 4)
	bars.position = Vector2(190, 364)
	bars.size = Vector2(130, 22)
	_root.add_child(bars)
	var sec_word := VisualTheme.label(levels[clampi(security, 0, 4)], "", 20, Palette.PAPER)
	sec_word.position = Vector2(334, 360)
	_root.add_child(sec_word)
	var obj := VisualTheme.label("OBJECTIVE", "KickerLabel", 18)
	obj.position = Vector2(90, 402)
	_root.add_child(obj)
	var obj_text := VisualTheme.label(objective + ("  —  " + objective_detail if objective_detail != "" else ""), "", 22, Palette.PAPER)
	obj_text.position = Vector2(200, 398)
	obj_text.size = Vector2(1000, 30)
	_root.add_child(obj_text)
	var y := 440.0
	var x := 90.0
	for mod: Array in modifiers:
		var chip := Label.new()
		chip.text = "  %s  " % mod[0]
		chip.add_theme_font_override("font", VisualTheme.font("heading"))
		chip.add_theme_font_size_override("font_size", 18)
		var tint: Color = mod[2] if mod.size() > 2 else Palette.GOLD
		chip.add_theme_color_override("font_color", Palette.INK if tint.get_luminance() > 0.45 else Palette.PAPER)
		chip.add_theme_stylebox_override("normal", VisualTheme.box(tint, Color.TRANSPARENT, 0, 2, 4))
		chip.position = Vector2(x, y)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(chip)
		x += chip.get_minimum_size().x + 14.0
	var skip := VisualTheme.label("any key to skip", "DimLabel", 15)
	skip.position = Vector2(1080, 470)
	_root.add_child(skip)
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.2)
	tw.tween_interval(duration)
	tw.tween_callback(close)

func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if skip:
		close()

func close() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_finish)

func _finish() -> void:
	finished.emit()
	queue_free()


class SecurityBars extends Control:
	var level := 0
	func _draw() -> void:
		for i in 5:
			var r := Rect2(i * 26, 0, 20, size.y)
			draw_rect(r, Palette.DANGER if i <= level else Color(1, 1, 1, 0.12))
