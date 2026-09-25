extends Control
## Main menu: an office window on the rainy skyline, the logo, the Board's
## ticker along the bottom and the menu on the right.

var _root: Control
var _main_menu: Control
var _settings_panel: Control

func _ready() -> void:
	get_tree().paused = false
	Audio.music("menu")
	for child in get_children():
		child.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := MenuBackdrop.new()
	backdrop.hero = true
	_root.add_child(backdrop)
	var tape := TickerTape.new()
	tape.position = Vector2(0, 690)
	tape.size = Vector2(1280, 30)
	_root.add_child(tape)
	_main_menu = _build_main_menu()
	_root.add_child(_main_menu)
	_settings_panel = CenterContainer.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VisualTheme.panel(Palette.GOLD_DIM, 24))
	var settings := SettingsPanel.new()
	settings.closed.connect(_on_close_settings)
	panel.add_child(settings)
	_settings_panel.add_child(panel)
	_root.add_child(_settings_panel)
	_settings_panel.hide()

func _build_main_menu() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	var logo := Logo.new()
	logo.position = Vector2(60, 70)
	logo.size = Vector2(640, 330)
	wrap.add_child(logo)
	var tag := VisualTheme.label("A noir heist roguelike on a crooked stock exchange.", "", 22, Palette.PAPER)
	tag.position = Vector2(70, 420)
	wrap.add_child(tag)
	var tag2 := VisualTheme.label("ROB THE FLOOR  ·  RIG THE MARKET  ·  MAKE THE QUOTA", "KickerLabel", 18)
	tag2.position = Vector2(70, 456)
	wrap.add_child(tag2)
	var panel := PanelContainer.new()
	panel.position = Vector2(846, 120)
	panel.size = Vector2(370, 520)
	panel.add_theme_stylebox_override("panel", VisualTheme.panel(Palette.GOLD_DIM, 24))
	wrap.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(VisualTheme.label("YOUR NEXT MOVE", "KickerLabel", 18))
	var first := _button("PLAY", _on_play, true)
	col.add_child(first)
	if RunFlow.can_continue():
		col.add_child(_button("CONTINUE", _on_continue))
	col.add_child(_button("QUICK HEIST", RunFlow.start_quick_test))
	col.add_child(_button("CONNECTIONS", _on_network))
	col.add_child(_button("CASE CLOSED", _on_gallery))
	col.add_child(_button("SETTINGS", _on_open_settings))
	if not OS.has_feature("web"):
		col.add_child(_button("QUIT", _on_quit))
	first.grab_focus.call_deferred()
	var foot := VisualTheme.label("v%s  ·  all art, sound and music generated in-engine" % ProjectSettings.get_setting("application/config/version", "1.0"), "DimLabel", 15)
	foot.position = Vector2(70, 650)
	wrap.add_child(foot)
	return wrap

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 56)
	if primary:
		button.theme_type_variation = "PrimaryButton"
	button.pressed.connect(action)
	return button

func _on_play() -> void:
	Settings.apply_display_from_gesture()
	RunFlow.queue_scene("res://character_select.tscn")

func _on_continue() -> void:
	RunFlow.queue_scene("res://character_select.tscn")

func _on_open_settings() -> void:
	_main_menu.hide()
	_settings_panel.show()

func _on_close_settings() -> void:
	_settings_panel.hide()
	_main_menu.show()

func _on_network() -> void:
	_main_menu.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := CareerPanel.new()
	panel.add_theme_stylebox_override("panel", VisualTheme.panel(Palette.GOLD_DIM, 20))
	center.add_child(panel)
	_root.add_child(center)
	panel.closed.connect(_on_network_closed.bind(center))

func _on_network_closed(center: Control) -> void:
	center.queue_free()
	_main_menu.show()

## CASE CLOSED: the endings gallery.
func _on_gallery() -> void:
	_main_menu.hide()
	var gallery := CaseClosed.new()
	_root.add_child(gallery)
	gallery.closed.connect(_on_gallery_closed)

func _on_gallery_closed() -> void:
	_main_menu.show()
	VisualTheme.focus_first(_main_menu)

func _on_quit() -> void:
	get_tree().quit()


## The logo: STOCK ROGUE in heavy gold caps with a live chart line cutting
## through, and a red stamp slammed on the corner.
class Logo extends Control:
	var _t := 0.0
	var _points: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		var y := 0.0
		for i in 34:
			y += rng.randf_range(-16, 14)
			_points.append(y)
		var stamp := StampArt.new()
		stamp.text = "LISTED ON THE BOARD"
		stamp.font_size = 24
		stamp.tilt = -0.14
		add_child(stamp)
		stamp.position = Vector2(372, 266)
		stamp.slam(0.4)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var f := VisualTheme.font("heading_bold")
		var kicker := VisualTheme.font("mono")
		draw_string(kicker, Vector2(6, 18), "THE BOARD  ·  AFTER HOURS TRADING", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.GOLD_DIM)
		for i in 2:
			var word := "STOCK" if i == 0 else "ROGUE"
			var base := Vector2(0, 142 + i * 118)
			draw_string(f, base + Vector2(5, 6), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 136, Color(0, 0, 0, 0.6))
			draw_string(f, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 136, Palette.GOLD if i == 0 else Palette.PAPER)
		# The chart line crawling through the lettering.
		var pts := PackedVector2Array()
		var shift := fmod(_t * 18.0, 18.0)
		for i in _points.size():
			var x := i * 18.0 - shift
			var y := 170.0 + float(_points[(i + int(_t)) % _points.size()]) * 0.7
			pts.append(Vector2(x, y))
		draw_polyline(pts, Palette.with_alpha(Palette.DANGER, 0.85), 4.0, true)
		draw_circle(pts[pts.size() - 1], 6.0, Palette.DANGER)
