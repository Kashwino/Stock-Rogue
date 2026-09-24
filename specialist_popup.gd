extends CanvasLayer
class_name SpecialistPopup
## "NEW SPECIALIST": a mugshot card slammed over the job report, the front
## page or the ending when a feat unlocks someone. One card per specialist;
## tap, click or press a key to move on. Runs while the tree is paused.

signal finished

var ids: Array = []
var _index := 0
var _root: Control
var _card: Control

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_root.gui_input.connect(_on_input)
	_show_current()

static func present(host: Node, new_ids: Array) -> SpecialistPopup:
	if new_ids.is_empty() or host == null:
		return null
	var popup := SpecialistPopup.new()
	popup.ids = new_ids
	host.get_tree().root.add_child(popup)
	return popup

func _crew(id: StringName) -> Dictionary:
	for c: Dictionary in CharacterSelect.CREW:
		if c["id"] == id:
			return c
	return {"name": String(id).to_upper(), "role": "", "trait": ""}

func _show_current() -> void:
	if _card:
		_card.queue_free()
	var id: StringName = ids[_index]
	var c := _crew(id)
	_card = PaperSheet.new()
	_card.stock = Palette.PAPER
	_card.position = Vector2(340, 110)
	_card.size = Vector2(600, 460)
	_card.rotation = -0.02
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var kicker := VisualTheme.label("NEW SPECIALIST", "KickerLabel", 22, Palette.STAMP_RED)
	kicker.position = Vector2(40, 30)
	_card.add_child(kicker)
	var portrait := PortraitArt.new()
	portrait.who = id
	portrait.unlocked = true
	portrait.position = Vector2(40, 76)
	portrait.size = Vector2(190, 220)
	_card.add_child(portrait)
	var name_l := VisualTheme.label(String(c["name"]), "", 44, Palette.INK)
	name_l.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	name_l.position = Vector2(254, 70)
	_card.add_child(name_l)
	var role := VisualTheme.label(String(c.get("role", "")).to_upper(), "", 20, Palette.STAMP_RED)
	role.add_theme_font_override("font", VisualTheme.font("type_bold"))
	role.position = Vector2(258, 124)
	_card.add_child(role)
	var trait_l := VisualTheme.label(String(c.get("trait", "")), "", 17, Palette.INK)
	trait_l.add_theme_font_override("font", VisualTheme.font("type"))
	trait_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_l.custom_minimum_size = Vector2(310, 0)
	trait_l.position = Vector2(258, 160)
	_card.add_child(trait_l)
	trait_l.set_deferred("size", Vector2(310, 0))
	var hint := VisualTheme.label("Pick them on the crew wall.   Tap to continue.", "", 16, Color("5a5040"))
	hint.add_theme_font_override("font", VisualTheme.font("type"))
	hint.position = Vector2(40, 400)
	_card.add_child(hint)
	var stamp := StampArt.new()
	stamp.text = "HIRED"
	stamp.font_size = 54
	stamp.ink = Palette.STAMP_GREEN
	stamp.tilt = -0.2
	_card.add_child(stamp)
	stamp.position = Vector2(330, 300)
	stamp.slam(0.3)
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui("reveal_4")
	_card.scale = Vector2(0.6, 0.6)
	_card.pivot_offset = _card.size * 0.5
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_next()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.is_echo():
		_next()
		get_viewport().set_input_as_handled()

func _next() -> void:
	_index += 1
	if _index >= ids.size():
		finished.emit()
		queue_free()
	else:
		_show_current()
