extends CanvasLayer
## Multitouch sticks own individual finger IDs. Menu buttons remain normal UI.
var left_id := -1
var right_id := -1
var left_origin := Vector2.ZERO
var right_origin := Vector2.ZERO
var _root: Node2D
var _left_base: Line2D
var _right_base: Line2D
var _left_knob: Polygon2D
var _right_knob: Polygon2D
var _buttons: Array[TouchScreenButton] = []
var _was_visible := false
var _was_combat := false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Node2D.new()
	add_child(_root)
	_left_base = _ring("MOVE")
	_right_base = _ring("AIM / FIRE")
	_left_knob = _knob(_left_base)
	_right_knob = _knob(_right_base)
	for pair in [["dodge", "DODGE"], ["reload", "RELOAD"], ["swap_weapon", "SWAP"], ["interact", "USE"]]:
		var button := TouchScreenButton.new()
		button.action = pair[0]
		var shape := CircleShape2D.new()
		shape.radius = 46.0
		button.shape = shape
		var visual := Polygon2D.new()
		var points := PackedVector2Array()
		for i in 24:
			points.append(Vector2.from_angle(TAU * i / 24.0) * 45.0)
		visual.polygon = points
		visual.color = Color(0.13, 0.18, 0.25, 0.9)
		button.add_child(visual)
		var label := Label.new()
		label.text = pair[1]
		label.position = Vector2(-43, -12)
		label.size = Vector2(86, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		_root.add_child(button)
		_buttons.append(button)
	_root.hide()

func _ring(text: String) -> Line2D:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.92, 0.78, 0.4, 0.6)
	ring.closed = true
	for i in 48:
		ring.add_point(Vector2.from_angle(TAU * i / 48.0) * 83.0)
	var label := Label.new()
	label.text = text
	label.position = Vector2(-80, 90)
	label.size = Vector2(160, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(label)
	_root.add_child(ring)
	return ring

func _knob(parent: Node) -> Polygon2D:
	var knob := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		points.append(Vector2.from_angle(TAU * i / 24.0) * 27.0)
	knob.polygon = points
	knob.color = Color(0.95, 0.82, 0.5, 0.7)
	parent.add_child(knob)
	return knob

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var combat := scene is HeistFloor
	var hub := scene is HideoutRoom
	var mode: int = Settings.values["touch_mode"]
	var enabled := mode == 1 or (mode == 0 and (DisplayServer.is_touchscreen_available() or TouchInput.touch_active))
	var panel_open := hub and scene.get("_active_panel") != null
	var show_controls := enabled and (combat or hub) and not get_tree().paused and not panel_open
	if show_controls != _was_visible or combat != _was_combat:
		release_all()
		_root.visible = show_controls
		_was_visible = show_controls
		_was_combat = combat
	if not show_controls:
		return
	var size := get_viewport().get_visible_rect().size
	left_origin = Vector2(135, size.y - 150)
	right_origin = Vector2(size.x - 145, size.y - 150)
	_left_base.position = left_origin
	_right_base.position = right_origin
	_right_base.visible = combat
	_left_knob.position = TouchInput.move * 57.0
	_right_knob.position = TouchInput.aim * (57.0 if TouchInput.firing else 0.0)
	for i in _buttons.size():
		_buttons[i].visible = combat or i == 3
	_buttons[0].position = Vector2(size.x - 330, size.y - 95)
	_buttons[1].position = Vector2(size.x - 330, size.y - 210)
	_buttons[2].position = Vector2(size.x - 445, size.y - 95)
	_buttons[3].position = Vector2(size.x - 445, size.y - 210)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		TouchInput.touch_active = true
	if not _root.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if left_id < 0 and event.position.distance_to(left_origin) < 110.0:
				left_id = event.index
				_set_left(event.position)
			elif _was_combat and right_id < 0 and event.position.distance_to(right_origin) < 110.0:
				right_id = event.index
				_set_right(event.position)
			else:
				return
		else:
			if event.index == left_id:
				left_id = -1
				TouchInput.move = Vector2.ZERO
			elif event.index == right_id:
				right_id = -1
				TouchInput.firing = false
			else:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == left_id:
			_set_left(event.position)
		elif event.index == right_id:
			_set_right(event.position)
		else:
			return
		get_viewport().set_input_as_handled()

func _set_left(pos: Vector2) -> void:
	var raw := (pos - left_origin) / 57.0
	TouchInput.move = raw.limit_length(1.0) if raw.length() > 0.13 else Vector2.ZERO

func _set_right(pos: Vector2) -> void:
	var raw := pos - right_origin
	TouchInput.firing = raw.length() > 12.0
	if TouchInput.firing:
		TouchInput.aim = raw.normalized()

func release_all() -> void:
	left_id = -1
	right_id = -1
	TouchInput.reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()
