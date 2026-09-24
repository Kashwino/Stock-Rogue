extends CanvasLayer
class_name PauseMenu
## The heist's pause screen (Esc / START / the touch PAUSE button): the job's
## case file on the left, RESUME / SETTINGS / QUIT TO MENU on the right, and
## the controls for whatever the player is holding. Quitting keeps the run —
## it picks up from the last case-wall checkpoint. Pauses the tree, so it runs
## PROCESS_MODE_ALWAYS and unpauses on the way out.

var opened := false
var overlay: ColorRect
var menu: Control
var settings_panel: SettingsPanel
var resume_button: Button
var _settings_box: PanelContainer
var _job: Control
var _controls: Label
var _pause_button: Button

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
	pause.add_theme_font_size_override("font_size", 20)
	pause.position = Vector2(1148, 38)
	pause.size = Vector2(118, 58)
	pause.focus_mode = Control.FOCUS_NONE
	pause.pressed.connect(open_pause)
	root.add_child(pause)
	_pause_button = pause
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.02, 0.035, 0.9)
	root.add_child(overlay)
	# The menu: job file left, buttons right.
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(menu)
	var kicker := VisualTheme.label("THE CLOCK IS STOPPED", "KickerLabel", 20)
	kicker.position = Vector2(690, 120)
	menu.add_child(kicker)
	var title := VisualTheme.label("HEIST PAUSED", "TitleLabel", 60)
	title.position = Vector2(686, 142)
	menu.add_child(title)
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(690, 250)
	buttons.custom_minimum_size = Vector2(420, 0)
	buttons.add_theme_constant_override("separation", 14)
	menu.add_child(buttons)
	resume_button = _button(buttons, "RESUME", "PrimaryButton", close_pause)
	_button(buttons, "SETTINGS", "", _open_settings)
	_button(buttons, "QUIT TO MENU", "DangerButton", _quit)
	var note := VisualTheme.label("Quitting keeps the run: it picks up from the case wall.", "DimLabel", 16)
	note.position = Vector2(690, 520)
	menu.add_child(note)
	_controls = VisualTheme.label("", "MonoLabel", 15, Palette.PAPER_DIM)
	_controls.position = Vector2(690, 556)
	menu.add_child(_controls)
	# Settings take the whole screen when open.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	_settings_box = PanelContainer.new()
	center.add_child(_settings_box)
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(_close_settings)
	_settings_box.add_child(settings_panel)
	_settings_box.hide()
	overlay.hide()

## The touch PAUSE button hides under anything else that pauses (terminal,
## job report) so it never sits on top of their panels.
func _process(_delta: float) -> void:
	_pause_button.visible = not get_tree().paused

func _button(parent: Control, text: String, variation: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if variation != "":
		button.theme_type_variation = variation
	button.add_theme_font_size_override("font_size", 26)
	button.custom_minimum_size = Vector2(420, 70)
	button.pressed.connect(callback)
	parent.add_child(button)
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
	_build_job_card()
	_controls.text = controls_text(TouchInput.device())
	menu.show()
	_settings_box.hide()
	overlay.show()
	resume_button.grab_focus()
	Audio.play_ui("paper")

func close_pause() -> void:
	if not opened:
		return
	opened = false
	overlay.hide()
	Controls.release_all()
	get_tree().paused = false

func _open_settings() -> void:
	menu.hide()
	_settings_box.show()

func _close_settings() -> void:
	_settings_box.hide()
	menu.show()
	resume_button.grab_focus()

func _quit() -> void:
	close_pause()
	RunFlow.queue_scene("res://home_screen.tscn")

## The controls, for the hands on them right now.
static func controls_text(device: String) -> String:
	match device:
		"pad":
			return "L-STICK move   R-STICK aim   RT fire   LB roll\nX reload   Y swap   A use   VIEW map   START pause"
		"touch":
			return "Left thumb moves, right thumb aims and fires.\nDODGE · RELOAD · SWAP · USE · MAP on screen."
	return "WASD move   MOUSE aim   CLICK fire   SPACE roll\nR reload   Q swap   E use   TAB map   ESC pause"

## The job's case file: venue, objective, modifiers, heat and time on the job.
func _build_job_card() -> void:
	if _job:
		_job.queue_free()
	_job = PaperSheet.new()
	_job.stock = Palette.MANILA
	_job.position = Vector2(150, 110)
	_job.size = Vector2(460, 480)
	_job.rotation = -0.015
	_job.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(_job)
	var scene := get_tree().current_scene
	var node: MapNode = RunFlow.pending_heist
	var venue: StringName = node.venue_id if node else &""
	var boss: StringName = node.boss_id if node else &""
	var tab := VisualTheme.label("THE JOB", "", 18, Palette.STAMP_RED)
	tab.add_theme_font_override("font", VisualTheme.font("type_bold"))
	tab.position = Vector2(40, 30)
	_job.add_child(tab)
	var name_label := VisualTheme.label(Venues.sign_name(venue, boss).to_upper() if venue != &"" else "THE JOB", "", 36, Palette.INK)
	name_label.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.position = Vector2(38, 52)
	_job.add_child(name_label)
	name_label.set_deferred("size", Vector2(390, 0))
	var lines: Array = []
	if scene is HeistFloor:
		var floor_scene := scene as HeistFloor
		# Same words as the HUD's objective panel (boss jobs read TAKE HIM DOWN).
		var hud = floor_scene.hud
		if hud and hud.get("objective_title") and hud.get("objective_body"):
			lines.append("OBJECTIVE  %s" % String(hud.objective_title.text).to_upper())
			lines.append(String(hud.objective_body.text).replace("\n", " "))
		else:
			lines.append("OBJECTIVE  %s" % Objectives.title(floor_scene.objective).to_upper())
			lines.append(Objectives.brief(floor_scene.objective))
		if not floor_scene.modifiers.is_empty():
			var names: Array = []
			for m: StringName in floor_scene.modifiers:
				names.append(String(MapNode.MODIFIERS.get(m, [String(m).to_upper()])[0]))
			lines.append("CONDITIONS  " + ", ".join(names))
		lines.append("HEAT  %d   ·   BAGGED  $%d" % [roundi(floor_scene.heat), floor_scene.loot_banked])
		lines.append("TIME ON THE JOB  %d:%02d" % [int(floor_scene.active_elapsed) / 60, int(floor_scene.active_elapsed) % 60])
	var body := VisualTheme.label("\n".join(lines), "", 17, Palette.INK)
	body.add_theme_font_override("font", VisualTheme.font("type_bold"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(40, 170)
	_job.add_child(body)
	body.set_deferred("size", Vector2(390, 0))
	var stamp := StampArt.new()
	stamp.text = "ON HOLD"
	stamp.font_size = 30
	stamp.tilt = 0.1
	_job.add_child(stamp)
	stamp.position = Vector2(250, 400)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if opened:
			if _settings_box.visible:
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
