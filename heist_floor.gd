extends Node2D
class_name HeistFloor

## The playable heist. Free-roam Hotline-Miami style:
##  - The building matches the CHOSEN heist (rarity -> size/danger, venue -> stock).
##  - You START outside at the GETAWAY CAR and walk in through the MAIN DOOR.
##    All guards are already inside: patrols investigate noise, sentries stay
##    posted on the valuables and never leave them.
##  - No door locks, no forced room clearing. Rooms award gold when their crew
##    falls, but nothing gates your movement.
##  - HEAT comes from witnessed security reports; reinforcements breach from entrances
##    and HUNT you. Killing the boss MARKS you: bigger waves, and emergency
##    exits weld shut one by one. The main door always stays open.
##  - To extract, get back OUT of the building and stand at the car for a few
##    seconds. Taking a hit cancels it. Die inside = the run is over.
##
## Scene: Node2D root with this script + a Camera2D child (created if missing).

const ENEMY_SCENE_PATH := "res://enemy.tscn"
const ROOMS_BY_STAGE := {0: 10, 1: 12, 2: 14, 3: 16}
const GOLD_TABLE := {
	0: [0.10, 10, 25], 1: [0.25, 20, 40], 2: [0.45, 40, 80],
	3: [0.60, 60, 120], 4: [0.80, 120, 200], 5: [0.0, 0, 0], 6: [1.0, 300, 500],
}

@export var reinforcement_interval: float = 34.0   # seconds between miniboss pairs
@export var min_interval: float = 16.0
@export var exit_close_interval: float = 20.0      # marked: seconds per exit weld
@export var extract_radius: float = 80.0

## Fire exits let you slip out fast — but only while the heist is still quiet.
@export var fire_exit_heat_limit: float = 12.0     # above this, fire exits are no good
@export var fire_exit_hold: float = 2.5            # seconds to stand in the exit

var _fire_hold: float = 0.0
var _fire_last_health: int = -1

var generator: FloorGenerator
var player: Player
var camera: Camera2D
var live: LiveStock
var hud = null
var results = null

var marked: bool = false
var heat: float = 0.0
var _heat_timer: float = 0.0
var _close_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _extracting: bool = false
var _prompt: Label = null
var car: GetawayCar = null

# Grade bookkeeping.
var _kills: int = 0
var _enemies_total: int = 0
var _heist_start: float = 0.0
var active_elapsed: float = 0.0
var director: EnemyDirector
var _kill_streak := 0
var _rarity: int = 0
var _venue: StringName = &""
var modifier: StringName = &""
var fx: CombatFX
var security_disabled := 0
var last_heat_source := "No reports. Stay out of sight."
var quiet_seconds := 0.0
var _security_status: Label
var tactical_map: HeistMap
var _status_clock := 0.0

func _ready() -> void:
	director = EnemyDirector.new()
	add_child(director)
	add_child(PauseMenu.new())
	camera = get_node_or_null("Camera2D")
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	camera.make_current()
	camera.zoom = Vector2(1.15, 1.15)
	fx = CombatFX.new()
	fx.camera = camera
	add_child(fx)

	_ensure_chest_ui()
	_ensure_results()
	_build_floor()

# ---------------------------------------------------------------- build -----
func _build_floor() -> void:
	# The building corresponds to the heist chosen on the map.
	var stage: int = RunState.run_map.current_stage if RunState.run_map else 0
	var heist_index: int = RunState.run_map.current_step if RunState.run_map else 0
	if RunFlow.pending_heist != null:
		_rarity = RunFlow.pending_heist.room_rarity
		_venue = RunFlow.pending_heist.venue_id
		modifier = RunFlow.pending_heist.modifier
	else:
		_rarity = 0
		_venue = &"pickpocket"

	var room_count: int = ROOMS_BY_STAGE.get(stage, 10) + int(_rarity / 2.0)
	var quota_level: int = RunState.run_map.quota_block if RunState.run_map else 0
	var exit_count: int = clampi(quota_level + 1, 1, 4)

	_rng.seed = hash(str(RunFlow.run_seed) + "_floor_" + str(stage) + "_" + str(heist_index))

	generator = FloorGenerator.new()
	add_child(generator)
	if (stage == 0 and heist_index <= 1) or _venue == &"bank_job":
		generator.generate_authored()
	else:
		generator.generate(
			hash(str(RunFlow.run_seed) + "_floor_" + str(stage) + "_" + str(heist_index)),
			room_count, exit_count)
	if generator.rooms.is_empty():
		push_error("HeistFloor: no rooms generated")
		return
	_dress_building()

	# Difficulty from heist rarity: denser crews in rarer heists.
	for room in generator.rooms:
		if room == generator.start_room:
			room.spawn_count = 0
		elif room.has_meta("is_boss"):
			room.spawn_count = 1
			room.enemy_scene = load("res://auditor_boss.tscn") if stage == 3 or RunSave.slot == RunSave.SLOT_COUNT else load("res://enemy.tscn")
		elif room.get_meta("chest_kind", "") == "":
			var base: int = room.get("spawn_count")
			room.set("spawn_count", base + int(_rarity * 0.75))
			if not room.has_meta("is_boss"):
				room.set("rarity", _rarity)

	_spawn_player()
	_setup_market_and_hud()

	# Spawn EVERY room's crew now — the building is alive from the start.
	_enemies_total = 0
	for room in generator.rooms:
		if room.has_signal("cleared"):
			room.cleared.connect(_on_room_cleared.bind(room))
		room.activate()
		_hook_room_enemies(room)
		_scatter_loot(room)

	# Chests exist from the start too.
	if generator.weapon_chest_room:
		_spawn_chest(generator.weapon_chest_room, "weapon")
	if generator.upgrade_chest_room:
		_spawn_chest(generator.upgrade_chest_room, "upgrade")

	if modifier == &"lockdown":
		for gap: Dictionary in generator.exits:
			generator.close_exit(gap)
	_decorate_exits()
	_ensure_prompt()
	_spawn_car()
	_assign_guard_roles()
	director.refresh()
	var terminal := MarketTerminal.new()
	terminal.position = generator.start_room.position + Vector2(430, 270)
	add_child(terminal)
	_setup_security()
	_setup_tactics()

	RunEconomy.on_room_start()
	_heist_start = Time.get_ticks_msec() / 1000.0
	_heat_timer = reinforcement_interval
	RunFlow.on_room_entered(0)

func _spawn_player() -> void:
	var scene = load("res://player.tscn")
	if scene == null:
		push_error("HeistFloor: player.tscn not found")
		return
	player = scene.instantiate()
	add_child(player)
	# Start OUTSIDE, next to the getaway car.
	player.global_position = _outside_position()
	if RunState.active:
		RunState.apply_to_player(player)
	player.died.connect(_on_player_died)
	var pcam = player.get_node_or_null("Camera2D")
	if pcam:
		pcam.enabled = false
	camera.global_position = player.global_position

func _setup_market_and_hud() -> void:
	# Persistent run-long market lives in RunState; the heist drives ONE venue.
	live = LiveStock.new()
	live.venue_asset_id = _venue
	add_child(live)
	live.setup(RunState.market, player, RunState.character_profile)
	player.live_stock = live

	var hud_scene = load("res://hud.tscn")
	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
		if hud.has_method("bind_hud"):
			hud.bind_hud(player, live, RunState.loadout)

func _ensure_chest_ui() -> void:
	if get_tree().get_nodes_in_group("chest_ui").size() > 0:
		return
	var scene = load("res://chest_ui.tscn")
	if scene == null:
		push_warning("HeistFloor: chest_ui.tscn not found — chests won't open")
		return
	var ui = scene.instantiate()
	add_child(ui)
	if not ui.is_in_group("chest_ui"):
		ui.add_to_group("chest_ui")
	if ui.has_signal("item_chosen"):
		ui.item_chosen.connect(_on_item_claimed)

func _ensure_results() -> void:
	var scene = load("res://results_screen.tscn")
	if scene == null:
		push_warning("HeistFloor: results_screen.tscn not found")
		return
	results = scene.instantiate()
	add_child(results)
	results.continued.connect(_on_results_continued)

func _decorate_exits() -> void:
	# Labels over the main door + each emergency exit.
	if not generator.entrance.is_empty():
		_exit_label(generator.entrance["inside_pos"], "MAIN DOOR — the car is out here",
			Color(0.95, 0.8, 0.3))
	for g: Dictionary in generator.exits:
		_exit_label(g["inside_pos"], "LOCKDOWN — EXIT SEALED" if modifier == &"lockdown" else "FIRE EXIT — quiet escape", Color(1.0, 0.35, 0.3) if modifier == &"lockdown" else Color(0.35, 0.85, 0.5))

## A point OUTSIDE the main door, on the street side of the entrance wall.
func _outside_position() -> Vector2:
	if generator.entrance.is_empty():
		if generator.start_room:
			var sr = generator.start_room
			return sr.global_position + sr.get("room_size") * 0.5
		return Vector2.ZERO
	var e: Dictionary = generator.entrance
	var inside: Vector2 = e["inside_pos"]
	var room = e["room"]
	var wall_world: Vector2 = room.to_global(e["wall_pos"])
	# Step from inside, through the wall, and out into the street.
	var outward := (wall_world - inside).normalized()
	return wall_world + outward * 190.0

## Park the getaway car outside the main door and route extraction through it.
func _spawn_car() -> void:
	car = GetawayCar.new()
	car.global_position = _outside_position()
	add_child(car)
	car.bind_player(player)
	car.extracted.connect(_extract)
	car.extraction_started.connect(func():
		if _prompt: _prompt.hide())
	car.extraction_cancelled.connect(func(_r): pass)

## Assign roles and archetypes to the building's standing crew.
## Sentries hold valuables and doorways; patrols roam and investigate noise.
func _assign_guard_roles() -> void:
	for room in generator.rooms:
		var guards_loot: bool = room.has_meta("chest_kind") or room.has_meta("is_boss")
		var doorways := _doorway_posts(room)
		var door_i := 0
		var guards: Array = []
		for c in room.get_children():
			if c.is_in_group("enemies"):
				guards.append(c)

		var room_rect := Rect2(room.global_position, room.get("room_size"))
		for c in guards:
			if c is AuditorBoss:
				c.set_guard_room(room_rect)
				continue
			# Archetype first: rarity raises the odds of the nastier kinds.
			c.apply_archetype(_pick_archetype(room, guards_loot))
			c.set_guard_room(room_rect)
			c.radio_carrier = c == guards[0]

			if guards_loot:
				# Treasure guards: rooted, watchful, never leave the prize.
				c.role = Enemy.Role.SENTRY
				c.sight_range = 520.0
			elif door_i < doorways.size() and _rng.randf() < 0.55:
				# Post a guard ON a doorway so entrances are actually held.
				c.role = Enemy.Role.SENTRY
				c.global_position = doorways[door_i]
				c.set_post(doorways[door_i])
				door_i += 1
			else:
				c.role = Enemy.Role.PATROL

## World-space positions just inside each of a room's open doorways.
func _doorway_posts(room) -> Array:
	var out: Array = []
	var size: Vector2 = room.get("room_size")
	var inset := 96.0
	# One post per module edge midpoint, pulled inside the room.
	var w := int(round(size.x / 600.0))
	var h := int(round(size.y / 450.0))
	for m in w:
		out.append(room.to_global(Vector2(600.0 * m + 300.0, inset)))
		out.append(room.to_global(Vector2(600.0 * m + 300.0, size.y - inset)))
	for m in h:
		out.append(room.to_global(Vector2(inset, 450.0 * m + 225.0)))
		out.append(room.to_global(Vector2(size.x - inset, 450.0 * m + 225.0)))
	out.shuffle()
	return out

## Weighted archetype pick. Treasure rooms and rarer heists skew dangerous.
func _pick_archetype(room, guards_loot: bool) -> int:
	var rarity: int = room.get("rarity")
	var roll := _rng.randf()
	if room.has_meta("is_boss"):
		# The boss room can field a Medic to keep its guards topped up — killing
		# it first is the smart play. Turrets watch the approach.
		if roll < 0.22: return Enemy.Kind.BRUTE
		if roll < 0.42: return Enemy.Kind.ENFORCER
		if roll < 0.58: return Enemy.Kind.SHOTGUNNER
		if roll < 0.74: return Enemy.Kind.TURRET
		if roll < 0.88: return Enemy.Kind.MEDIC
		return Enemy.Kind.SPRINTER
	if guards_loot:
		# TURRET fits treasure rooms perfectly: an emplacement watching the
		# prize, forcing you to approach from an angle instead of walking in.
		if roll < 0.25: return Enemy.Kind.SHOTGUNNER
		if roll < 0.5: return Enemy.Kind.ENFORCER
		if roll < 0.72: return Enemy.Kind.TURRET
		return Enemy.Kind.MARKSMAN
	# Ordinary rooms: mostly grunts early, more specialists as rarity climbs.
	var specialist_chance := 0.15 + rarity * 0.09
	if roll > specialist_chance:
		return Enemy.Kind.GRUNT
	var r2 := _rng.randf()
	if r2 < 0.3: return Enemy.Kind.ENFORCER
	if r2 < 0.54: return Enemy.Kind.SHOTGUNNER
	if r2 < 0.72: return Enemy.Kind.MARKSMAN
	if r2 < 0.87: return Enemy.Kind.SPRINTER
	if r2 < 0.96: return Enemy.Kind.TURRET
	return Enemy.Kind.BRUTE

func _exit_label(pos: Vector2, text: String, color: Color) -> void:
	# There is no Label2D in Godot. A Label is a Control, but parenting it to a
	# Node2D makes it inherit the 2D transform, so it sits in the world.
	var anchor := Node2D.new()
	anchor.global_position = pos + Vector2(0, -52)
	anchor.z_index = 50
	add_child(anchor)

	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Offset so the text centres on the anchor rather than starting at it.
	l.position = Vector2(-90, 0)
	l.custom_minimum_size = Vector2(180, 0)
	anchor.add_child(l)

## Big centred prompt shown while standing in an open doorway.
func _ensure_prompt() -> void:
	if _prompt != null:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_prompt = Label.new()
	_prompt.text = "WAY OUT — the car is parked outside"
	_prompt.add_theme_font_size_override("font_size", 28)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.78
	_prompt.anchor_bottom = 0.78
	_prompt.hide()
	layer.add_child(_prompt)

## Nearest open threshold within extract_radius, or {} if none.
func _threshold_in_reach() -> Dictionary:
	var p: Vector2 = player.global_position
	if not generator.entrance.is_empty() \
			and p.distance_to(generator.entrance["inside_pos"]) <= extract_radius:
		return generator.entrance
	for g: Dictionary in generator.exits:
		if g.get("open", false) and p.distance_to(g["inside_pos"]) <= extract_radius:
			return g
	return {}

# ------------------------------------------------------------- enemies ------
func _hook_room_enemies(room) -> void:
	for c in room.get_children():
		if c.is_in_group("enemies") and not c.has_meta("hooked"):
			c.set_meta("hooked", true)
			_enemies_total += 1
			c.died.connect(_on_enemy_died)

func _on_enemy_died(e) -> void:
	_kills += 1
	_kill_streak += 1
	if RunState.has_perk(&"blood_dividend") and _kill_streak % 8 == 0 and player.health > 0:
		player.health = mini(player.health + 1, player.max_health)
		player.health_changed.emit(player.health, player.max_health)
	RunFlow.total_kills += 1
	fx.shake(3.0)
	if live:
		live.report_kill()

func _on_room_cleared(room) -> void:
	if room.get("spawn_count") <= 0:
		return
	# Gold on wiping a room's crew (chance + amount by rarity). Movement is
	# never gated — this is purely the payday.
	var rarity: int = room.get("rarity")
	var row: Array = GOLD_TABLE.get(rarity, GOLD_TABLE[0])
	if _rng.randf() < row[0]:
		RunEconomy.award_clear(_rng.randi_range(row[1], row[2]) * loot_multiplier())
	RunEconomy.on_room_start()   # hit-penalty ramp resets per cleared room
	# Empty treasure rooms also emit cleared on activation; only actual kills get the beat.
	if room.get("spawn_count") > 0:
		fx.last_kill()

	if room.has_meta("is_boss") and not marked:
		_become_marked()

func _become_marked() -> void:
	marked = true
	add_heat(16.0, "Auditor distress beacon")
	_close_timer = exit_close_interval
	# Big payoff for the boss: gold + a hard stock pump on the venue.
	RunEconomy.add_bonus(_rng.randi_range(250, 400) * loot_multiplier())
	if live:
		live.report_shock(0.70 if ShortBook.targets(_venue) else 1.30, &"boss")
	pass # Debug logging removed.

# ------------------------------------------------- heat & reinforcements ----
func _process(delta: float) -> void:
	if _extracting or player == null or not is_instance_valid(player):
		return

	# Camera follows the player.
	camera.global_position = camera.global_position.lerp(
		player.global_position, clampf(delta * 8.0, 0.0, 1.0))
	_status_clock -= delta
	if _status_clock <= 0.0:
		_status_clock = 0.15
		_update_security_status()

	# The car stays locked until you've actually been inside the building.
	if car and not car.armed and _player_is_inside():
		car.arm()
		# The clock starts when you go in, not while you're casing the street.
		_heist_start = Time.get_ticks_msec() / 1000.0
		pass # Debug logging removed.

	# Nothing escalates while you're still on the street casing the place.
	if car and not car.armed:
		return

	active_elapsed += delta
	# No passive escalation: lose sight, interrupt calls, disable alarms to cool off.
	quiet_seconds += delta
	if quiet_seconds >= 4.0:
		heat = maxf(0.0, heat - delta)
	_heat_timer = maxf(0.0, _heat_timer - delta)
	if heat >= dispatch_threshold() and _heat_timer <= 0.0:
		_spawn_reinforcements()
		_heat_timer = 12.0 if modifier == &"heavy_police" else 24.0

	# Marked: emergency exits weld shut one by one. Main door never closes.
	if marked:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_close_next_exit()
			_close_timer = exit_close_interval

	_check_extraction()

## True once the player's position falls inside any room's footprint. Cheap
## rect test — no extra Area2D nodes needed.
func _player_is_inside() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var p: Vector2 = player.global_position
	for room in generator.rooms:
		var origin: Vector2 = room.global_position
		var size: Vector2 = room.get("room_size")
		if p.x >= origin.x and p.x <= origin.x + size.x \
				and p.y >= origin.y and p.y <= origin.y + size.y:
			return true
	return false

## Reinforcements arrive by van — but now as a pair of MINIBOSSES, not a
## growing mob. A fixed squad of 2 kept the encounter readable: you always
## know exactly what just walked in and can fight it as its own moment,
## instead of getting buried under an ever-larger wave as heat climbs.
func _spawn_reinforcements() -> void:
	# Cap pursuing reinforcements; sleeping guards are managed separately.
	var pursuers := 0
	for guard in get_tree().get_nodes_in_group("enemies"):
		if guard.hunting:
			pursuers += 1
	if pursuers >= 12:
		return
	var scene = load(ENEMY_SCENE_PATH)
	if scene == null:
		return
	var points: Array = []
	if not generator.entrance.is_empty():
		points.append(generator.entrance)
	for g: Dictionary in generator.exits:
		if g.get("open", false):
			points.append(g)
	if points.is_empty():
		return

	var gap: Dictionary = points[_rng.randi() % points.size()]

	var van := CargoVan.new()
	van.enemy_scene = scene
	van.squad_size = 2                       # always a pair, never a mob
	van.archetypes = _miniboss_archetypes()
	van.miniboss = true                      # tells the van to buff their stats
	# Park outside the door, approaching from further out.
	var inside: Vector2 = gap["inside_pos"]
	var wall_world: Vector2 = gap["room"].to_global(gap["wall_pos"])
	var outward := (wall_world - inside).normalized()
	van.drop_position = wall_world + outward * 150.0
	van.approach_from = wall_world + outward * 900.0
	van.squad_deployed.connect(_on_squad_deployed)
	add_child(van)
	pass # Debug logging removed.

## Two toughened specialists, escalating with heat. Always exactly 2 kinds —
## the point is a readable duo, not a growing roster.
func _miniboss_archetypes() -> Array:
	var tiers: Array = [Enemy.Kind.ENFORCER, Enemy.Kind.SHOTGUNNER]
	if heat > 12.0:
		tiers = [Enemy.Kind.ENFORCER, Enemy.Kind.MARKSMAN]
	if heat > 20.0:
		tiers = [Enemy.Kind.SHOTGUNNER, Enemy.Kind.SPRINTER]
	if heat > 28.0 or marked:
		tiers = [Enemy.Kind.BRUTE, Enemy.Kind.MEDIC]
	tiers.shuffle()
	return tiers

func _on_squad_deployed(enemies: Array) -> void:
	for e in enemies:
		_enemies_total += 1
		e.died.connect(_on_enemy_died)

func _close_next_exit() -> void:
	for g: Dictionary in generator.exits:
		if g.get("open", false):
			generator.close_exit(g)
			pass # Debug logging removed.
			return

# ---------------------------------------------------------- extraction ------
func _check_extraction() -> void:
	# The MAIN DOOR extracts via the getaway car outside. FIRE EXITS are a
	# separate, faster escape — but only while the job is still quiet. Once heat
	# passes fire_exit_heat_limit the alarm's out, the fire exits are watched,
	# and you must fight back to the car. Using a fire exit means standing in it
	# for fire_exit_hold seconds; taking a hit resets the timer.
	if _prompt == null:
		return
	if player == null or not is_instance_valid(player):
		return

	var at_exit := _fire_exit_in_reach()
	var hot := heat >= fire_exit_heat_limit

	if at_exit.is_empty() or hot:
		if _fire_hold > 0.0:
			_fire_hold = 0.0
		var near := _threshold_in_reach()
		if not at_exit.is_empty() and hot:
			_prompt.text = "FIRE EXIT SEALED — too much heat. Reach the car."
			_prompt.visible = true
		else:
			_prompt.text = "WAY OUT — the car is parked outside"
			_prompt.visible = not near.is_empty()
		return

	# Standing in a usable fire exit: run the hold timer.
	_prompt.visible = true
	if _fire_last_health < 0:
		_fire_last_health = player.health
	if player.health < _fire_last_health:
		_fire_hold = 0.0                 # a hit resets the escape
	_fire_last_health = player.health

	_fire_hold += get_process_delta_time()
	var remaining: float = maxf(fire_exit_hold - _fire_hold, 0.0)
	_prompt.text = "SLIPPING OUT THE FIRE EXIT…  %.1f" % remaining
	if _fire_hold >= fire_exit_hold:
		pass # Debug logging removed.
		_extract()

## Nearest OPEN fire exit within reach, or {}.
func _fire_exit_in_reach() -> Dictionary:
	var p: Vector2 = player.global_position
	for g: Dictionary in generator.exits:
		if g.get("open", false) and p.distance_to(g["inside_pos"]) <= extract_radius:
			return g
	return {}

func _extract() -> void:
	if RunState.run_map and RunState.run_map.current_stage == 3 and not marked:
		return
	if _extracting:
		return
	_extracting = true
	Engine.time_scale = 1.0
	# Settle at the combat price, before the extraction grade changes it.
	var short_result := ShortBook.settle(true)
	var receipt := "%s:%s:%s" % [RunState.run_id, RunState.run_map.current_stage, RunState.run_map.current_step]
	var earned_intel := Meta.award_extraction(receipt, _kills, security_disabled, marked)
	var elapsed: float = active_elapsed
	var stats := {
		"hits_taken": player.hits_taken,
		"shots_fired": player.shots_fired,
		"shots_hit": player.shots_hit,
		"kills": _kills,
		"enemies_total": maxi(_enemies_total, 1),
		"time_seconds": elapsed,
		"par_time": 15.0 * generator.rooms.size(),
	}
	var result: Dictionary = HeistGrader.grade_heist(stats)
	result["intel"] = earned_intel
	result["short"] = short_result
	result["meta_saved"] = Meta.last_save_ok

	# Grade moves the venue stock. "Inside Trader" perk boosts the upside.
	var delta: float = result["stock_delta"]
	if delta > 1.0 and RunState.has_perk(&"inside_trader"):
		delta = 1.0 + (delta - 1.0) * 1.25
	if live:
		live.report_shock(delta, &"grade")
	else:
		var asset = RunState.market.get_asset(_venue) if RunState.market else null
		if asset:
			asset.current_price = maxf(asset.current_price * delta, 0.01)

	result["stats"] = stats
	RunState.sync_from_player(player)
	if results:
		results.show_result(result, String(_venue))
	else:
		_on_results_continued()

func _on_results_continued() -> void:
	RunFlow.on_heist_finished()

func _on_player_died() -> void:
	# Die before extracting: the loot is gone and so is the run.
	if _extracting:
		return
	_extracting = true
	pass # Debug logging removed.
	if _prompt:
		_prompt.hide()
	RunState.sync_from_player(player)
	await get_tree().create_timer(1.2, false).timeout
	RunFlow.end_run(false)

# --------------------------------------------------------------- loot -------
## Scatter valuables across a room's floor. Count and value both scale with the
## room's rarity, so pushing into dangerous rooms is what pays — not kills.
func _scatter_loot(room) -> void:
	var rarity: int = room.get("rarity")
	var size: Vector2 = room.get("room_size")

	# Rarer rooms have more pickups worth more each. Tuned so a fully-looted
	# building yields on the order of one gold gate across a couple of heists —
	# generous enough to reward pushing in, not a windfall.
	var count := (rarity + 1) / 2 + _rng.randi_range(0, 1)
	var per_min := 5 + rarity * 4
	var per_max := per_min + 6 + rarity * 5
	# Treasure rooms already hold a chest; keep their floor loot light.
	if room.has_meta("chest_kind"):
		count = 1
	# Boss rooms are a jackpot.
	if room.has_meta("is_boss"):
		count = 3 + rarity / 2
		per_min = 25
		per_max = 55

	if count <= 0:
		return

	var placed: Array = []
	for i in count:
		var pos := _loot_slot(size, placed)
		placed.append(pos)
		var pickup := LootPickup.new()
		pickup.value = _rng.randi_range(per_min, per_max)
		room.add_child(pickup)
		pickup.position = pos
		pickup.collected.connect(_on_loot_collected)

## A floor position inset from the walls, spaced from other loot.
func _loot_slot(size: Vector2, placed: Array) -> Vector2:
	var candidate := Vector2.ZERO
	for attempt in 6:
		candidate = Vector2(
			_rng.randf_range(90, size.x - 90),
			_rng.randf_range(90, size.y - 90))
		var ok := true
		for p: Vector2 in placed:
			if candidate.distance_to(p) < 80.0:
				ok = false
				break
		if ok:
			return candidate
	return candidate

func _on_loot_collected(value: int) -> void:
	RunEconomy.add_bonus(roundi(value * loot_multiplier() * (1.25 if RunState.has_perk(&"scavenger") else 1.0)))
	Sfx.play_sound("pickup")
	if hud and hud.has_method("flash_gold"):
		hud.flash_gold()

func _spawn_chest(room, kind: String) -> void:
	if room.has_meta("chest_spawned"):
		return
	room.set_meta("chest_spawned", true)
	var scene = load("res://world_chest.tscn")
	if scene == null:
		push_warning("HeistFloor: world_chest.tscn not found")
		return
	var chest = scene.instantiate()
	room.add_child(chest)
	chest.global_position = room.center_position()
	chest.set("kind", 0 if kind == "weapon" else 1)
	chest.set("tier", WorldChest.tier_from_room_rarity(5))

func _on_item_claimed(item) -> void:
	if item is WeaponItem:
		if RunState.loadout:
			RunState.loadout.equip(item)
	elif item is UpgradeItem:
		var add: float = item.amount if item.mode == UpgradeItem.ApplyMode.ADD else 0.0
		var mult: float = item.amount if item.mode == UpgradeItem.ApplyMode.MULTIPLY else 1.0
		if item.stat == &"max_health":
			RunState.add_max_health(int(add))
		else:
			RunState.add_stat_mod(item.stat, add, mult)
		if player:
			item.apply_to(player)

func loot_multiplier() -> int:
	return 2 if modifier == &"heavy_police" else 1

func dispatch_threshold() -> float:
	return 8.0 if modifier == &"heavy_police" else 16.0

func add_heat(amount: float, source: String) -> void:
	if amount <= 0.0 or _extracting:
		return
	var was_quiet := heat < dispatch_threshold()
	heat = minf(100.0, heat + amount * (0.75 if RunState.has_perk(&"cool_head") else 1.0))
	quiet_seconds = 0.0
	last_heat_source = source
	if was_quiet and heat >= dispatch_threshold():
		_heat_timer = minf(_heat_timer, 4.0)

func security_alert(room: Node, source: String, amount: float) -> void:
	add_heat(amount, source)
	for device in get_tree().get_nodes_in_group("security"):
		if device.room == room and device.kind == SecurityDevice.Kind.ALARM and not device.disabled:
			device.armed = true
			device.transmit_clock = maxf(device.transmit_clock, 2.0)

func on_security_disabled(_device: SecurityDevice) -> void:
	security_disabled += 1
	heat = maxf(0.0, heat - 4.0)
	last_heat_source = "Security disabled · heat -4"
	if live:
		live.report_sabotage()
	Sfx.play_sound("pickup")
	fx.shake(3.0)

func _setup_security() -> void:
	for room in generator.rooms:
		if room == generator.start_room:
			continue
		for kind in [SecurityDevice.Kind.CAMERA, SecurityDevice.Kind.ALARM]:
			var device := SecurityDevice.new()
			device.kind = kind
			device.floor_host = self
			device.room = room
			device.position = room.position + (Vector2(55, 70) if kind == SecurityDevice.Kind.CAMERA else Vector2(room.room_size.x - 65, room.room_size.y - 100))
			add_child(device)

func _setup_tactics() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_security_status = Label.new()
	_security_status.position = Vector2(332, 29)
	_security_status.size = Vector2(530, 102)
	_security_status.add_theme_font_size_override("font_size", 18)
	_security_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_security_status)
	tactical_map = HeistMap.new()
	tactical_map.floor_host = self
	tactical_map.full_reveal = modifier == &"insider"
	layer.add_child(tactical_map)
	tactical_map.hide()
	var toggle := Button.new()
	toggle.text = "MAP"
	toggle.position = Vector2(984, 18)
	toggle.size = Vector2(130, 70)
	toggle.pressed.connect(_toggle_map)
	layer.add_child(toggle)
	_update_security_status()

func _toggle_map() -> void:
	if get_tree().paused and not tactical_map.visible:
		return
	Controls.release_all()
	tactical_map.visible = not tactical_map.visible
	get_tree().paused = tactical_map.visible

func _update_security_status() -> void:
	if _security_status == null:
		return
	var tag := RunFlow.pending_heist.modifier_name() if RunFlow.pending_heist else "STANDARD SECURITY"
	var response := " · POLICE IN %.0fs" % _heat_timer if heat >= dispatch_threshold() else " · CLEAR"
	_security_status.text = "%s\nHEAT  %.0f / %.0f%s\n%s" % [tag, heat, dispatch_threshold(), response, last_heat_source]
	var short_quote := ShortBook.quote()
	if not short_quote.is_empty():
		_security_status.text += "\nSHORT: %s%d P/L · escape pays %d" % ["+" if short_quote["profit"] >= 0 else "", short_quote["profit"], short_quote["payout"]]

func _dress_building() -> void:
	var bounds := Rect2()
	for room: BuildingRoom in generator.rooms:
		var rect := Rect2(room.global_position, room.room_size)
		bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
		var label := room.get_node_or_null("RoomName")
		if label:
			label.hide()
		var art := RoomArt.new()
		art.room = room
		room.add_child(art)
		var walls := room.get_node_or_null("Walls")
		if walls:
			for wall in walls.get_children():
				if wall is Polygon2D:
					wall.color = Color("506069")
					var edge := Line2D.new()
					edge.points = wall.polygon
					edge.closed = true
					edge.width = 2
					edge.default_color = Color("82958d")
					wall.add_child(edge)
		var counter := room.get_node_or_null("Counter/Countertop") as Polygon2D
		if counter:
			counter.color = Color("6b6856")
			var trim := Line2D.new()
			trim.points = counter.polygon
			trim.closed = true
			trim.width = 3
			trim.default_color = Color("c3ad77")
			counter.add_child(trim)
	var street := StreetArt.new()
	street.bounds = bounds
	add_child(street)
