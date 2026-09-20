extends Control
var _root: Control
var _main_menu: Control
var _settings_panel: Control

func _ready() -> void:
	get_tree().paused = false
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := MenuBackdrop.new()
	backdrop.hero = true
	_root.add_child(backdrop)
	_main_menu = _build_main_menu()
	_root.add_child(_main_menu)
	_settings_panel = CenterContainer.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VisualTheme.panel(VisualTheme.EDGE, 24))
	var settings := SettingsPanel.new()
	settings.closed.connect(_on_close_settings)
	panel.add_child(settings)
	_settings_panel.add_child(panel)
	_root.add_child(_settings_panel)
	_settings_panel.hide()

func _label(parent: Control, text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_main_menu() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	_label(wrap, "AFTER HOURS  /  THE CRIMINAL EXCHANGE", Vector2(64, 65), 18, VisualTheme.TEAL)
	var title := _label(wrap, "STOCK\nROGUE", Vector2(60, 115), 94, VisualTheme.WHITE)
	title.add_theme_constant_override("line_spacing", -22)
	_label(wrap, "BET THE CRASH.\nSTEAL THE UPSIDE.", Vector2(64, 504), 31, VisualTheme.GOLD)
	_label(wrap, "A heist on the floor. A killing on the market.", Vector2(64, 600), 19, Color("a4b8b8"))
	_label(wrap, "01   /   INFILTRATE     02   /   MANIPULATE     03   /   ESCAPE", Vector2(64, 652), 16, Color("a4b8b8"))
	var panel := PanelContainer.new()
	panel.position = Vector2(822, 83)
	panel.size = Vector2(390, 554)
	panel.add_theme_stylebox_override("panel", VisualTheme.panel(Color("50605a"), 24))
	wrap.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var kicker := Label.new()
	kicker.text = "YOUR NEXT MOVE"
	kicker.add_theme_font_size_override("font_size", 18)
	kicker.add_theme_color_override("font_color", VisualTheme.TEAL)
	col.add_child(kicker)
	var sub := Label.new()
	sub.text = "Choose a score. Make it count."
	sub.add_theme_font_size_override("font_size", 20)
	col.add_child(sub)
	col.add_child(HSeparator.new())
	col.add_child(_button("PLAY", _on_play))
	col.add_child(_button("QUICK HEIST", RunFlow.start_quick_test))
	col.add_child(_button("NETWORK", _on_network))
	if RunFlow.can_continue():
		col.add_child(_button("CONTINUE", _on_continue))
	col.add_child(_button("SETTINGS", _on_open_settings))
	if not OS.has_feature("web"):
		col.add_child(_button("QUIT", _on_quit))
	return wrap

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(336, 66)
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
	panel.add_theme_stylebox_override("panel", VisualTheme.panel(VisualTheme.EDGE, 20))
	center.add_child(panel)
	_root.add_child(center)
	panel.closed.connect(func():
		center.queue_free()
		_main_menu.show())

func _on_quit() -> void:
	get_tree().quit()
