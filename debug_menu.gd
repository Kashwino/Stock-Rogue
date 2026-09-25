extends CanvasLayer
## Autoload "Debug": the F1 developer menu. Only in debug builds (running from
## the editor, a debug export, or with Log.DEBUG on); release exports never
## open it. Add gold, set the Board index, jump to any stage or the Chairman's
## job, start any boss job, spawn any guard next to you, and play each ending.
## Debug endings and boss jobs run as practice, so they never touch the career.
## Pauses the tree while open (and restores it on close).

const BOSS_STAGE := {&"landlord": 0, &"auditor": 1, &"ambassador": 2, &"chairman": 3}

var opened := false
var _root: Control
var _body: VBoxContainer
var _status: Label
var _kind: OptionButton
var _was_paused := false

static func available() -> bool:
	return Log.DEBUG or OS.is_debug_build()

func _ready() -> void:
	layer = 190
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu") and not event.is_echo() and available():
		if opened:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	if opened:
		return
	opened = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	_root.show()

func close() -> void:
	if not opened:
		return
	opened = false
	_root.hide()
	get_tree().paused = _was_paused

func _exit_tree() -> void:
	if opened:
		get_tree().paused = _was_paused

# ------------------------------------------------------------------ layout --
func _build() -> void:
	for child in _root.get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 30)
	scroll.size = Vector2(1160, 660)
	_root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(1140, 0)
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_body.add_child(VisualTheme.label("DEBUG  ·  F1 to close", "KickerLabel", 20, Palette.DANGER))
	_status = VisualTheme.label("", "MonoLabel", 16)
	_body.add_child(_status)
	_refresh_status()
	var in_heist := get_tree().current_scene is HeistFloor
	_row("ECONOMY", [["+$500", _add_gold.bind(500)], ["+$5000", _add_gold.bind(5000)],
		["INDEX 120", _set_index.bind(120.0)], ["INDEX 227", _set_index.bind(227.0)],
		["INDEX 350", _set_index.bind(350.0)], ["INDEX 492", _set_index.bind(492.0)],
		["INDEX %d" % int(Story.NEW_CHAIRMAN_INDEX + 50), _set_index.bind(Story.NEW_CHAIRMAN_INDEX + 50.0)]])
	_row("ROUTE", [["TOWN", _skip_to_stage.bind(0)], ["THE CITY", _skip_to_stage.bind(1)],
		["THE WORLD", _skip_to_stage.bind(2)], ["DOOMSDAY", _skip_to_stage.bind(3)],
		["THE CHAIRMAN'S JOB", _chairman_job]])
	_row("BOSS JOBS", [["LANDLORD", _boss_job.bind(&"landlord")], ["AUDITOR", _boss_job.bind(&"auditor")],
		["AMBASSADOR", _boss_job.bind(&"ambassador")], ["CHAIRMAN", _boss_job.bind(&"chairman")]])
	_row("ENDINGS", [["BUSTED", _ending.bind(&"busted")], ["RETIRED", _ending.bind(&"retired")],
		["THE NEW CHAIRMAN", _ending.bind(&"new_chairman")]])
	if in_heist:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		_body.add_child(line)
		var tag := VisualTheme.label("SPAWN", "KickerLabel", 16)
		tag.custom_minimum_size = Vector2(120, 0)
		line.add_child(tag)
		_kind = OptionButton.new()
		_kind.custom_minimum_size = Vector2(300, 48)
		for k: int in Enemy.KIND_NAMES:
			_kind.add_item(String(Enemy.KIND_NAMES[k]), k)
		line.add_child(_kind)
		line.add_child(_button("SPAWN", _spawn_enemy.bind(false)))
		line.add_child(_button("SPAWN ELITE", _spawn_enemy.bind(true)))
		_row("HEIST", [["HEAL", _heal], ["KILL BOSS", _kill_boss], ["MAX HEAT", _max_heat]])
	_body.add_child(_button("CLOSE", close))

func _row(title: String, entries: Array) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	_body.add_child(line)
	var tag := VisualTheme.label(title, "KickerLabel", 16)
	tag.custom_minimum_size = Vector2(120, 0)
	line.add_child(tag)
	for entry: Array in entries:
		line.add_child(_button(entry[0], entry[1]))

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	return b

func _refresh_status() -> void:
	if _status == null:
		return
	var where := get_tree().current_scene.scene_file_path.get_file() if get_tree().current_scene else "?"
	if not RunState.active or RunState.run_map == null:
		_status.text = "%s   ·   no run" % where
		return
	_status.text = "%s   ·   stage %d step %d   ·   $%d   ·   index %.0f   ·   gate block %d%s" % [
		where, RunState.run_map.current_stage, RunState.run_map.current_step, RunEconomy.gold,
		RunState.empire_index(), RunState.run_map.quota_block, "   ·   practice" if RunFlow.practice else ""]

# ----------------------------------------------------------------- actions --
## A run to act on: the current one, or a fresh run in the practice slot
## (never one of the three case files).
func _ensure_run() -> void:
	if RunState.active and RunState.run_map:
		return
	RunSave.slot = RunSave.SLOT_COUNT
	RunFlow.run_seed = randi()
	RunFlow.heists_completed = 0
	RunFlow.total_kills = 0
	RunFlow.pending_heist = null
	RunFlow.practice = false
	RunState.start_run(load("res://main_character.tres"), RunFlow.run_seed)

func _add_gold(amount: int) -> void:
	_ensure_run()
	RunEconomy.gold += amount
	_refresh_status()

## Scale every venue so the Board index reads `target`.
func _set_index(target: float) -> void:
	_ensure_run()
	set_index(target)
	_refresh_status()

static func set_index(target: float) -> void:
	if RunState.market == null or RunState.market.assets.is_empty():
		return
	var total := 0.0
	for a in RunState.market.assets:
		total += a.current_price / a.base_price
	var mean := total / RunState.market.assets.size()
	var want := 1.0 + (target - 1.0) / RunState.INDEX_SCALE
	var f := want / maxf(mean, 0.0001)
	for a in RunState.market.assets:
		a.current_price = maxf(a.current_price * f, 0.01)

func _skip_to_stage(stage: int) -> void:
	_ensure_run()
	var map := RunState.run_map
	map.current_stage = stage
	map.current_step = 0
	map.quota_block = stage
	RunState.stage_intros.erase(stage)
	close()
	RunFlow.go_to_map()

## Doomsday's last step: the gate is passed, the Chairman's job is next.
func _chairman_job() -> void:
	_ensure_run()
	var map := RunState.run_map
	map.current_stage = 3
	map.quota_block = 4
	var steps: Array = map.stages[3]
	for i in steps.size():
		if steps[i].kind == RunMap.StepKind.HEIST_CHOICE and steps[i].is_boss:
			map.current_step = i
	close()
	RunFlow.launch_heist(map.first_heist_option())

func _boss_job(id: StringName) -> void:
	_ensure_run()
	var stage: int = BOSS_STAGE[id]
	var node := MapNode.new(MapNode.Type.BOSS)
	node.boss_id = id
	node.venue_id = RunMap.STAGE_BOSSES[stage][1]
	node.room_rarity = stage + 1
	RunState.run_map.current_stage = stage
	_practice()
	close()
	RunFlow.launch_heist(node)

## Boss jobs and endings play as practice in the practice slot, so a real
## case file and the career are left exactly as they were.
func _practice() -> void:
	RunSave.slot = RunSave.SLOT_COUNT
	RunFlow.practice = true

func _ending(which: StringName) -> void:
	_ensure_run()
	_practice()
	close()
	match which:
		&"busted":
			RunFlow.end_run(false, "")
		&"retired":
			set_index(Story.NEW_CHAIRMAN_INDEX - 200.0)
			RunFlow.end_run(true)
		&"new_chairman":
			set_index(Story.NEW_CHAIRMAN_INDEX + 50.0)
			RunFlow.end_run(true)

func _spawn_enemy(elite: bool) -> void:
	var floor_scene := get_tree().current_scene as HeistFloor
	if floor_scene == null or _kind == null:
		return
	var player := floor_scene.player
	var owner: Enemy = null
	var best := INF
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var d := e.global_position.distance_squared_to(player.global_position)
		if d < best and e.is_inside_tree() and e.get_parent() is BuildingRoom:
			best = d
			owner = e
	if owner == null:
		return
	var e := floor_scene.spawn_companion(owner, _kind.get_selected_id(), Vector2.ZERO)
	if e == null:
		return
	e.global_position = player.global_position + player.aim_direction() * 160.0
	if elite:
		e.make_elite(Enemy.AFFIXES.pick_random())
	close()

func _heal() -> void:
	var floor_scene := get_tree().current_scene as HeistFloor
	if floor_scene:
		floor_scene.player.health = floor_scene.player.max_health
		floor_scene.player.health_changed.emit(floor_scene.player.health, floor_scene.player.max_health)
	RunState.health = RunState.max_health

func _kill_boss() -> void:
	var floor_scene := get_tree().current_scene as HeistFloor
	if floor_scene:
		close()
		floor_scene.debug_kill_boss()

func _max_heat() -> void:
	var floor_scene := get_tree().current_scene as HeistFloor
	if floor_scene:
		floor_scene.add_heat(40.0, "Debug")
	_refresh_status()
