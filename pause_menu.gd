extends CanvasLayer
class_name PauseMenu
var opened := false
var overlay: ColorRect
var menu: VBoxContainer
var settings_panel: SettingsPanel
var resume_button: Button

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var pause := Button.new()
	pause.text = "PAUSE"
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-146, 18)
	pause.size = Vector2(120, 74)
	pause.pressed.connect(open_pause)
	root.add_child(pause)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.02, 0.035, 0.94)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14)
	style.border_color = Color(0.85, 0.68, 0.3)
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var holder := VBoxContainer.new()
	panel.add_child(holder)
	menu = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(480, 0)
	menu.add_theme_constant_override("separation", 18)
	holder.add_child(menu)
	var title := Label.new()
	title.text = "HEIST PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	menu.add_child(title)
	var hint := Label.new()
	hint.text = "Take a breath. The clock is stopped."
	menu.add_child(hint)
	resume_button = _button("RESUME", close_pause)
	_button("SETTINGS", func():
		menu.hide()
		settings_panel.show())
	_button("MENU - LAST CHECKPOINT", func():
		close_pause()
		get_tree().change_scene_to_file("res://home_screen.tscn"))
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(func():
		settings_panel.hide()
		menu.show()
		resume_button.grab_focus())
	holder.add_child(settings_panel)
	settings_panel.hide()
	overlay.hide()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 74
	button.pressed.connect(callback)
	menu.add_child(button)
	return button

func open_pause() -> void:
	if opened or get_tree().paused:
		return
	var scene := get_tree().current_scene
	if scene is HeistFloor and scene.get("_extracting"):
		return
	opened = true
	Controls.release_all()
	get_tree().paused = true
	menu.show()
	settings_panel.hide()
	overlay.show()
	resume_button.grab_focus()

func close_pause() -> void:
	if not opened:
		return
	opened = false
	overlay.hide()
	Controls.release_all()
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if opened:
			if settings_panel.visible:
				settings_panel.closed.emit()
			else:
				close_pause()
		else:
			open_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		open_pause()

func _exit_tree() -> void:
	if opened:
		get_tree().paused = false
