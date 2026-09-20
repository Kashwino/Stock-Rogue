extends HideoutRoom
class_name PrepLobby
## A safe, walkable base. Rooms are permanent; active-run equipment is never reset.
var selected := "operator"
var status_label: Label
var crew_label: Label
var lobby_ui: CanvasLayer
var room_visuals: Node2D
const ROOMS := [
	[&"room_armory", "ARMORY", "weapon", Vector2(300, 175)],
	[&"room_training", "TRAINING", "perk", Vector2(620, 175)],
	[&"room_crew", "CREW QUARTERS", "crew", Vector2(940, 175)],
]
const CREW_DATA := {
	"operator": ["The Operator", 3, 1.0, 2.5],
	"ghost": ["The Ghost", 2, 1.5, 3.0],
	"wolf": ["The Wolf", 4, 0.8, 2.0],
	"broker": ["The Broker", 2, 2.0, 4.0],
}
func _ready() -> void:
	get_tree().paused = false
	_build_room()
	_build_walker()
	_build_stations()
	_build_hud_hint()

func _build_room() -> void:
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1240, 0), Vector2(1240, 650), Vector2(0, 650)])
	backdrop.color = Color("1d2e36")
	add_child(backdrop)
	for x in range(0, 1240, 48):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 0), Vector2(x, 650)])
		line.default_color = Color("293e44")
		line.width = 1
		add_child(line)
	for r: Rect2 in [Rect2(0, 0, 1240, 18), Rect2(0, 632, 1240, 18), Rect2(0, 0, 18, 650), Rect2(1222, 0, 18, 650)]:
		_add_wall(r)
	# Three wings have real walls with centered walk-through doorways.
	for x in [150, 470, 790]:
		_add_wall(Rect2(x, 80, 12, 250))
		_add_wall(Rect2(x + 288, 80, 12, 250))
		_add_wall(Rect2(x, 80, 300, 12))
		_add_wall(Rect2(x, 318, 105, 12))
		_add_wall(Rect2(x + 195, 318, 105, 12))
	room_visuals = Node2D.new()
	add_child(room_visuals)
	_refresh_rooms()

func _refresh_rooms() -> void:
	for child in room_visuals.get_children():
		child.queue_free()
	for room: Array in ROOMS:
		var built: bool = room[0] in Meta.unlocked_assets
		var label := Label.new()
		label.position = room[3] - Vector2(125, 60)
		label.text = room[1] + ("\nOPEN" if built else "\nBUILD / %d INTEL" % Meta.CATALOG[room[0]]["cost"])
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", VisualTheme.TEAL if built else VisualTheme.GOLD)
		room_visuals.add_child(label)
		var prop := PropArt.new()
		prop.kind = "chest" if room[2] == "weapon" else "terminal"
		prop.position = room[3] + Vector2(0, 60)
		prop.modulate.a = 1.0 if built else 0.25
		room_visuals.add_child(prop)

func _build_walker() -> void:
	_walker = HideoutWalker.new()
	_walker.position = Vector2(620, 420)
	add_child(_walker)
	var camera := Camera2D.new()
	camera.position = Vector2(620, 325)
	add_child(camera)
	camera.make_current()

func _build_stations() -> void:
	for room: Array in ROOMS:
		_make_station(room[0], "", "", room[3] + Vector2(0, 90), VisualTheme.GOLD)
	_make_station(&"crew", "THE CREW", "Choose your specialist", Vector2(370, 430), VisualTheme.TEAL)
	_make_station(&"board", "HEIST MAP", "Plan your next score", Vector2(850, 430), VisualTheme.GOLD)

func _build_hud_hint() -> void:
	lobby_ui = CanvasLayer.new()
	lobby_ui.layer = 10
	add_child(lobby_ui)
	var title := Label.new()
	title.position = Vector2(40, 20)
	title.text = "THE SAFEHOUSE / CASE FILE %02d" % (RunSave.slot + 1)
	title.add_theme_font_size_override("font_size", 28)
	lobby_ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(40, 60)
	status_label.text = "Walk to a room and press USE to build or enter. Permanent rooms cost Intel."
	status_label.add_theme_font_size_override("font_size", 19)
	lobby_ui.add_child(status_label)
	crew_label = Label.new()
	crew_label.position = Vector2(390, 545)
	crew_label.add_theme_font_size_override("font_size", 23)
	lobby_ui.add_child(crew_label)
	_update_crew_label()
	_button("CHOOSE CHARACTER", Vector2(380, 600), _show_crew_panel)
	_button("CONTINUE RUN" if RunFlow.lobby_resume else "PLAN HEIST", Vector2(770, 600), _depart)
	_button("MENU", Vector2(1020, 22), func(): RunFlow.queue_scene("res://home_screen.tscn"), Vector2(150, 58))

func _button(text: String, at: Vector2, action: Callable, dimensions: Vector2 = Vector2(350, 74)) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.pressed.connect(action)
	lobby_ui.add_child(button)

func _update_crew_label() -> void:
	var name_text: String = RunState.character_profile.display_name if RunFlow.lobby_resume and RunState.character_profile else CREW_DATA[selected][0]
	crew_label.text = "%s  /  %d INTEL%s" % [name_text, Meta.intel, "  /  RUN IN PROGRESS" if RunFlow.lobby_resume else ""]

func _open_station(kind: StringName) -> void:
	if _active_panel:
		return
	if kind == &"board":
		_depart()
	elif kind == &"crew":
		_show_crew_panel()
	else:
		for room: Array in ROOMS:
			if kind != room[0]:
				continue
			if kind not in Meta.unlocked_assets:
				status_label.text = Meta.purchase(kind)
				_refresh_rooms()
				_update_crew_label()
			elif room[2] == "crew":
				_show_crew_panel()
			else:
				_open_career(room[2])

func _open_career(category: String) -> void:
	_walker.movement_enabled = false
	_active_panel = CanvasLayer.new()
	_active_panel.layer = 80
	add_child(_active_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_active_panel.add_child(center)
	var panel := CareerPanel.new()
	panel.category = category
	panel.closed.connect(_close_panel)
	center.add_child(panel)

func _show_crew_panel() -> void:
	if _active_panel:
		return
	_walker.movement_enabled = false
	var frame := _panel_frame("CHOOSE YOUR SPECIALIST", "CREW QUARTERS", VisualTheme.TEAL)
	_active_panel = frame["layer"]
	add_child(_active_panel)
	for id: String in CREW_DATA:
		var data: Array = CREW_DATA[id]
		var unlocked: bool = id in ["operator", "ghost"] or &"room_crew" in Meta.unlocked_assets
		var button := Button.new()
		button.text = "%s / %d HP%s" % [data[0], data[1], "" if unlocked else " / BUILD CREW QUARTERS"]
		button.custom_minimum_size = Vector2(720, 65)
		button.disabled = not unlocked or RunFlow.lobby_resume
		button.pressed.connect(_select.bind(id))
		frame["body"].add_child(button)
	var label := Label.new()
	label.text = "Character is locked for this run; gear and health are preserved." if RunFlow.lobby_resume else "Ghost: quiet footsteps. Wolf: +1 bullet damage. Broker: amplified market swings."
	label.add_theme_font_size_override("font_size", 18)
	frame["body"].add_child(label)

func _select(id: String) -> void:
	selected = id
	_close_panel()
	_update_crew_label()

func _depart() -> void:
	if _active_panel:
		return
	if RunFlow.lobby_resume:
		RunFlow.go_to_map()
	else:
		RunFlow.start_new_run(load("res://crew_" + selected + ".tres"))
