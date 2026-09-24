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
## HIT jobs crash the venue instead of pumping it.
var hit_job := false
var fx: CombatFX
var security_disabled := 0
var last_heat_source := "No reports. Stay out of sight."
var quiet_seconds := 0.0
var _security_status: Label
var tactical_map: HeistMap
var _status_clock := 0.0
var boss_heist := false
var boss_id: StringName = &""
var exit_signs: Array = []
var loot_banked := 0
var _siren_on := false
var _heartbeat_on := false
var _boss_music := false
var env: EnvTheme
var lighting: HeistLighting
var post_fx: PostFX
var building_bounds := Rect2()
var wall_art: Array = []
var bullet_pool: BulletPool
var _stage := 0
## Heat-log bookkeeping read by objectives and the grade.
var civilians_killed := 0
var alarms_raised := 0
## Boss fight state.
var boss: Boss = null
var lieutenant: Enemy = null
var audit_active := false
var _shutters: Array = []
var _focus_point := Vector2.ZERO
var _focus_until_msec := 0
var _lieutenant_shown := false
var _alarm_quiet_until := -1.0

func _ready() -> void:
	director = EnemyDirector.new()
	add_child(director)
	bullet_pool = BulletPool.new()
	add_child(bullet_pool)
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
	post_fx = PostFX.new()
	add_child(post_fx)

	_ensure_chest_ui()
	_ensure_results()
	_build_floor()

# ---------------------------------------------------------------- build -----
func _build_floor() -> void:
	# The building corresponds to the heist chosen on the map.
	var stage: int = RunState.run_map.current_stage if RunState.run_map else 0
	var heist_index: int = RunState.run_map.current_step if RunState.run_map else 0
	_stage = stage
	if RunFlow.pending_heist != null:
		_rarity = RunFlow.pending_heist.room_rarity
		_venue = RunFlow.pending_heist.venue_id
		modifier = RunFlow.pending_heist.modifier
		hit_job = RunFlow.pending_heist.is_hit()
	else:
		_rarity = 0
		_venue = &"pickpocket"

	boss_heist = RunFlow.pending_heist != null and RunFlow.pending_heist.is_boss()
	boss_id = RunFlow.pending_heist.boss_id if boss_heist else &""
	var room_count: int = ROOMS_BY_STAGE.get(stage, 10) + int(_rarity / 2.0)
	var quota_level: int = RunState.run_map.quota_block if RunState.run_map else 0
	var exit_count: int = clampi(quota_level + 1, 1, 4)

	_rng.seed = hash(str(RunFlow.run_seed) + "_floor_" + str(stage) + "_" + str(heist_index))

	generator = FloorGenerator.new()
	add_child(generator)
	if boss_heist and BossLayouts.has_layout(boss_id):
		generator.generate_authored(boss_id)
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
			# Stage bosses fight alone (they call their own help); ordinary jobs
			# keep a titled lieutenant and two of his crew in the boss room.
			room.spawn_count = 1 if boss_heist else 3
			room.enemy_scene = load(boss_scene_path(boss_id)) if boss_heist else load("res://enemy.tscn")
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
	_dress_outside()
	var cross := Crosshair.new()
	cross.player = player
	add_child(cross)
	_assign_guard_roles()
	_spawn_civilians()
	director.refresh()
	var terminal := MarketTerminal.new()
	terminal.position = generator.start_room.position + Vector2(430, 270)
	add_child(terminal)
	_setup_security()
	_setup_tactics()

	_show_intro_card()
	Audio.music_layers("heist_stealth", "heist_combat")
	RunEconomy.on_room_start()
	_heist_start = Time.get_ticks_msec() / 1000.0
	_heat_timer = reinforcement_interval

func _show_intro_card() -> void:
	var card := HeistIntroCard.new()
	card.venue_name = Venues.display_name(_venue)
	card.sign_name = Venues.sign_name(_venue, boss_id)
	card.security = _rarity
	card.objective = "LOOT"
	card.objective_detail = "grab the valuables and get back to the car"
	if boss_heist:
		card.boss_title = Story.boss_name(boss_id)
		card.objective = "TAKE HIM DOWN"
		card.objective_detail = "the car won't leave while he stands"
	if not boss_heist:
		var tick := Venues.ticker(_venue)
		card.modifiers.append(["HIT: CRASH " + tick, "", Palette.DANGER] if hit_job else ["CONTRACT: PUMP " + tick, "", Palette.STAMP_GREEN])
	if RunFlow.pending_heist and RunFlow.pending_heist.modifier != &"":
		card.modifiers.append([RunFlow.pending_heist.modifier_name(), RunFlow.pending_heist.modifier_detail()])
	if RunFlow.practice:
		card.modifiers.append(["REHEARSAL — NOBODY DIES IN A DRY RUN", ""])
	add_child(card)

func _spawn_player() -> void:
	var scene = load("res://player.tscn")
	if scene == null:
		push_error("HeistFloor: player.tscn not found")
		return
	player = scene.instantiate()
	add_child(player)
	# Start OUTSIDE on the door's axis; the getaway car is parked alongside.
	player.global_position = _outside_position()
	if RunState.active:
		RunState.apply_to_player(player)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health)
	var pcam = player.get_node_or_null("Camera2D")
	if pcam:
		pcam.enabled = false
	camera.global_position = player.global_position

func _setup_market_and_hud() -> void:
	# Persistent run-long market lives in RunState; the heist drives ONE venue.
	live = LiveStock.new()
	live.venue_asset_id = _venue
	live.hit_job = hit_job
	add_child(live)
	live.setup(RunState.market, player, RunState.character_profile)
	player.live_stock = live
	live.player_moved.connect(_on_player_moved_market)

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
	# The main door has the neon sign and a gold threshold; fire exits get a
	# lit green EXIT box (or a red SEALED one under lockdown).
	for g: Dictionary in generator.exits:
		var sealed: bool = not g.get("open", false)
		_exit_label(g["inside_pos"], "SEALED" if sealed else "EXIT", Palette.DANGER if sealed else Palette.NEON_GREEN)

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

func _door_outward() -> Vector2:
	if generator.entrance.is_empty():
		return Vector2.DOWN
	var e: Dictionary = generator.entrance
	return (e["room"].to_global(e["wall_pos"]) - e["inside_pos"]).normalized()

## Park the getaway car outside the main door and route extraction through it.
func _spawn_car() -> void:
	car = GetawayCar.new()
	car.global_position = _outside_position() + Vector2(-_door_outward().y, _door_outward().x) * 150.0
	if not generator.entrance.is_empty():
		var e: Dictionary = generator.entrance
		var outward: Vector2 = (e["room"].to_global(e["wall_pos"]) - e["inside_pos"]).normalized()
		car.facing = Vector2(-outward.y, outward.x)
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
		var has_radio := false
		for c in guards:
			if c is Boss:
				c.set_guard_room(room_rect)
				c.set_post(c.global_position)
				continue
			# Archetype first: rarity raises the odds of the nastier kinds.
			c.apply_archetype(_pick_archetype(room, guards_loot))
			c.set_guard_room(room_rect)
			# One radio per room, carried by someone who can actually talk.
			if not has_radio and c.kind not in NO_RADIO:
				c.radio_carrier = true
				has_radio = true
			_maybe_elite(c, room)
			if room.has_meta("is_boss") and not boss_heist and lieutenant == null:
				lieutenant = c
				c.make_lieutenant(Story.lieutenant_name(_rng))
				c.died.connect(_on_lieutenant_down)

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

## Archetypes that never carry the radio.
const NO_RADIO := [Enemy.Kind.TECH, Enemy.Kind.DOG, Enemy.Kind.DRONE, Enemy.Kind.TURRET]
## Archetypes that never roll an elite affix.
const NO_ELITE := [Enemy.Kind.DOG, Enemy.Kind.DRONE, Enemy.Kind.TURRET, Enemy.Kind.TECH]
var _elite_budget := -1

## Elites from the City onward (and on rare Town jobs): a small per-building
## budget, likelier in treasure and boss rooms and on rarer jobs.
func _maybe_elite(c: Enemy, room) -> void:
	if c.kind in NO_ELITE:
		return
	if _elite_budget < 0:
		_elite_budget = (0 if _rarity < 4 else 1) if _stage == 0 else 1 + _stage + int(_rarity >= 3)
	if _elite_budget <= 0:
		return
	var chance := 0.05 + 0.045 * _stage + 0.02 * _rarity
	if room.has_meta("chest_kind") or room.has_meta("is_boss"):
		chance *= 2.0
	if _rng.randf() < chance:
		c.make_elite(Enemy.AFFIXES[_rng.randi() % Enemy.AFFIXES.size()])
		_elite_budget -= 1

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

## Per-stage archetype pools: {kind: weight} for ordinary rooms, treasure
## rooms and boss rooms. Town is guards, dogs and bouncers; the City brings
## techs, riot shields and laser sights; the World adds grenadiers and
## drones; the Exchange fields everything.
static func stage_pools(stage: int) -> Dictionary:
	match stage:
		0:
			return {
				"room": {Enemy.Kind.GRUNT: 10.0, Enemy.Kind.SHOTGUNNER: 2.0, Enemy.Kind.BOUNCER: 1.8, Enemy.Kind.HANDLER: 1.4, Enemy.Kind.TECH: 1.2,
					Enemy.Kind.SPRINTER: 1.0, Enemy.Kind.ENFORCER: 0.8, Enemy.Kind.RIOT: 0.7, Enemy.Kind.MARKSMAN: 0.6, Enemy.Kind.GRENADIER: 0.3},
				"treasure": {Enemy.Kind.SHOTGUNNER: 3.0, Enemy.Kind.ENFORCER: 2.5, Enemy.Kind.BOUNCER: 2.0, Enemy.Kind.TURRET: 1.5, Enemy.Kind.MARKSMAN: 1.5},
				"boss": {Enemy.Kind.BRUTE: 2.0, Enemy.Kind.ENFORCER: 2.0, Enemy.Kind.SHOTGUNNER: 2.0, Enemy.Kind.BOUNCER: 1.5, Enemy.Kind.MEDIC: 1.2, Enemy.Kind.HANDLER: 1.0},
			}
		1:
			return {
				"room": {Enemy.Kind.GRUNT: 7.0, Enemy.Kind.ENFORCER: 2.5, Enemy.Kind.TECH: 1.6, Enemy.Kind.SNIPER: 1.3, Enemy.Kind.RIOT: 1.5, Enemy.Kind.MARKSMAN: 1.0,
					Enemy.Kind.GRENADIER: 0.9, Enemy.Kind.SHOTGUNNER: 1.0, Enemy.Kind.MEDIC: 0.8, Enemy.Kind.DRONE: 0.8, Enemy.Kind.SPRINTER: 0.8, Enemy.Kind.HANDLER: 0.6},
				"treasure": {Enemy.Kind.RIOT: 2.5, Enemy.Kind.ENFORCER: 2.5, Enemy.Kind.TURRET: 2.0, Enemy.Kind.SNIPER: 1.5, Enemy.Kind.SHOTGUNNER: 1.5},
				"boss": {Enemy.Kind.RIOT: 2.0, Enemy.Kind.ENFORCER: 2.0, Enemy.Kind.TURRET: 1.5, Enemy.Kind.MEDIC: 1.2, Enemy.Kind.SNIPER: 1.2, Enemy.Kind.DRONE: 1.0},
			}
		2:
			return {
				"room": {Enemy.Kind.GRUNT: 4.0, Enemy.Kind.ENFORCER: 2.5, Enemy.Kind.RIOT: 2.0, Enemy.Kind.GRENADIER: 1.5, Enemy.Kind.SNIPER: 1.5, Enemy.Kind.BOUNCER: 1.5,
					Enemy.Kind.HANDLER: 1.2, Enemy.Kind.TECH: 1.4, Enemy.Kind.DRONE: 1.2, Enemy.Kind.MEDIC: 1.0, Enemy.Kind.SPRINTER: 1.0, Enemy.Kind.SHOTGUNNER: 1.0, Enemy.Kind.TURRET: 0.5},
				"treasure": {Enemy.Kind.RIOT: 2.5, Enemy.Kind.GRENADIER: 2.0, Enemy.Kind.BOUNCER: 2.0, Enemy.Kind.TURRET: 1.5, Enemy.Kind.SNIPER: 1.5},
				"boss": {Enemy.Kind.BRUTE: 2.0, Enemy.Kind.RIOT: 2.0, Enemy.Kind.GRENADIER: 1.5, Enemy.Kind.MEDIC: 1.2, Enemy.Kind.BOUNCER: 1.5, Enemy.Kind.DRONE: 1.0},
			}
	return {
		"room": {Enemy.Kind.GRUNT: 2.5, Enemy.Kind.ENFORCER: 2.5, Enemy.Kind.RIOT: 2.0, Enemy.Kind.GRENADIER: 2.0, Enemy.Kind.SNIPER: 2.0, Enemy.Kind.BOUNCER: 1.5,
			Enemy.Kind.TECH: 1.5, Enemy.Kind.DRONE: 1.5, Enemy.Kind.MEDIC: 1.0, Enemy.Kind.BRUTE: 1.0, Enemy.Kind.SPRINTER: 1.0, Enemy.Kind.TURRET: 0.8, Enemy.Kind.SHOTGUNNER: 1.0, Enemy.Kind.HANDLER: 1.0},
		"treasure": {Enemy.Kind.RIOT: 2.5, Enemy.Kind.SNIPER: 2.0, Enemy.Kind.GRENADIER: 2.0, Enemy.Kind.BRUTE: 1.5, Enemy.Kind.TURRET: 1.5},
		"boss": {Enemy.Kind.BRUTE: 2.0, Enemy.Kind.RIOT: 2.0, Enemy.Kind.GRENADIER: 2.0, Enemy.Kind.SNIPER: 1.5, Enemy.Kind.MEDIC: 1.5, Enemy.Kind.DRONE: 1.2},
	}

## Weighted archetype pick from this stage's pool. Rarer rooms trade grunts
## for specialists.
func _pick_archetype(room, guards_loot: bool) -> int:
	var rarity: int = room.get("rarity")
	var pools := stage_pools(_stage)
	var pool: Dictionary = pools["room"]
	if room.has_meta("is_boss"):
		pool = pools["boss"]
	elif guards_loot:
		pool = pools["treasure"]
	return _weighted(pool, rarity)

func _weighted(pool: Dictionary, rarity: int = 0) -> int:
	var total := 0.0
	var weights: Dictionary = {}
	for k in pool:
		var w: float = pool[k]
		if k == Enemy.Kind.GRUNT:
			w *= maxf(0.25, 1.0 - rarity * 0.15)
		weights[k] = w
		total += w
	var roll := _rng.randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return pool.keys()[0]

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
	l.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_stylebox_override("normal", VisualTheme.box(Color(0.02, 0.05, 0.03, 0.92), color, 2, 2, 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(-50, 0)
	l.custom_minimum_size = Vector2(100, 0)
	l.material = StreetArt._unshaded()
	anchor.add_child(l)
	exit_signs.append(l)

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
	fx.add_trauma(0.2)
	fx.hit_stop(0.065)
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

	if room.has_meta("is_boss") and not marked and not boss_heist:
		_become_marked()
		fx.slow_mo(0.9, 0.25)

func _become_marked() -> void:
	marked = true
	add_heat(16.0, "The Board wants answers" if boss_heist else "Lieutenant down")
	_close_timer = exit_close_interval
	# Big payoff: gold (a stage boss pays through his cash burst instead) and
	# a hard stock shock on the venue.
	if not boss_heist:
		RunEconomy.add_bonus(_rng.randi_range(250, 400) * loot_multiplier())
	if live:
		live.report_shock(0.70 if live.inverted() else 1.30, &"boss")

# ------------------------------------------------- heat & reinforcements ----
func _process(delta: float) -> void:
	if _extracting or player == null or not is_instance_valid(player):
		return

	# Camera follows the player, leaning a little toward where they aim.
	var look_at: Vector2 = player.global_position
	if Time.get_ticks_msec() < _focus_until_msec:
		look_at = _focus_point
	camera.global_position = camera.global_position.lerp(
		look_at, clampf(delta * (4.0 if look_at != player.global_position else 8.0), 0.0, 1.0))
	var want := Vector2.ZERO
	if TouchInput.touch_active and Settings.values["touch_mode"] != 2:
		want = TouchInput.aim * (60.0 if TouchInput.firing else 20.0)
	elif TouchInput.pad_aim() != Vector2.ZERO:
		want = TouchInput.pad_aim() * 70.0
	else:
		want = (get_global_mouse_position() - player.global_position).limit_length(460.0) * 0.16
	fx.lead = fx.lead.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	_tick_market_chip(delta)
	_status_clock -= delta
	if _status_clock <= 0.0:
		_status_clock = 0.15
		_update_security_status()
		_watch_lieutenant()

	# The car stays locked until you've actually been inside the building.
	if car and not car.armed and _player_is_inside():
		car.arm()
		# The clock starts when you go in, not while you're casing the street.
		_heist_start = Time.get_ticks_msec() / 1000.0

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

## Two toughened specialists, escalating with heat and stage. Always exactly
## two — the point is a readable duo, not a growing roster. Cleaners only
## come for you in the World and beyond, once the heat is high.
func _miniboss_archetypes() -> Array:
	var tiers: Array
	var level := 0
	if heat > 12.0:
		level = 1
	if heat > 20.0:
		level = 2
	if heat > 28.0 or marked:
		level = 3
	match _stage:
		0:
			tiers = [[Enemy.Kind.ENFORCER, Enemy.Kind.SHOTGUNNER], [Enemy.Kind.ENFORCER, Enemy.Kind.BOUNCER], [Enemy.Kind.SHOTGUNNER, Enemy.Kind.HANDLER], [Enemy.Kind.BRUTE, Enemy.Kind.MEDIC]][level]
		1:
			tiers = [[Enemy.Kind.ENFORCER, Enemy.Kind.RIOT], [Enemy.Kind.SNIPER, Enemy.Kind.ENFORCER], [Enemy.Kind.GRENADIER, Enemy.Kind.RIOT], [Enemy.Kind.BRUTE, Enemy.Kind.MEDIC]][level]
		2:
			tiers = [[Enemy.Kind.RIOT, Enemy.Kind.GRENADIER], [Enemy.Kind.SNIPER, Enemy.Kind.BOUNCER], [Enemy.Kind.CLEANER, Enemy.Kind.RIOT], [Enemy.Kind.CLEANER, Enemy.Kind.MEDIC]][level]
		_:
			tiers = [[Enemy.Kind.RIOT, Enemy.Kind.SNIPER], [Enemy.Kind.CLEANER, Enemy.Kind.GRENADIER], [Enemy.Kind.CLEANER, Enemy.Kind.BOUNCER], [Enemy.Kind.CLEANER, Enemy.Kind.BRUTE]][level]
	tiers = tiers.duplicate()
	tiers.shuffle()
	return tiers

func _on_squad_deployed(enemies: Array) -> void:
	for e in enemies:
		_enemies_total += 1
		e.died.connect(_on_enemy_died)
		e.set_meta("hooked", true)
	# Late, hot responses bring an elite along.
	if not enemies.is_empty() and (_stage >= 1 or marked) and (heat > 20.0 or marked):
		var lead: Enemy = enemies[0]
		if lead.kind not in NO_ELITE:
			lead.make_elite(Enemy.AFFIXES[_rng.randi() % Enemy.AFFIXES.size()])

func _close_next_exit() -> void:
	for g: Dictionary in generator.exits:
		if g.get("open", false):
			generator.close_exit(g)
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
		_extract()

## Nearest OPEN fire exit within reach, or {}.
func _fire_exit_in_reach() -> Dictionary:
	var p: Vector2 = player.global_position
	for g: Dictionary in generator.exits:
		if g.get("open", false) and p.distance_to(g["inside_pos"]) <= extract_radius:
			return g
	return {}

## Boss heists are mandatory kills: the car will not leave while he stands.
func requires_boss_kill() -> bool:
	return boss_heist and not marked

func _extract() -> void:
	if requires_boss_kill():
		return
	if _extracting:
		return
	_extracting = true
	Engine.time_scale = 1.0
	Audio.loop("alarm", false)
	Audio.loop("heartbeat", false)
	Audio.play("cash_register")
	# Settle at the combat price, before the extraction grade changes it.
	var short_result := ShortBook.settle(true)
	var receipt := "%s:%s:%s" % [RunState.run_id, RunState.run_map.current_stage if RunState.run_map else 0, RunState.run_map.current_step if RunState.run_map else 0]
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
		"civilians": civilians_killed,
	}
	var result: Dictionary = HeistGrader.grade_heist(stats)
	RunState.last_grade = result["grade_name"]
	if boss_heist and marked and boss_id not in RunState.bosses_down:
		RunState.bosses_down.append(boss_id)
	result["intel"] = earned_intel
	result["short"] = short_result
	result["boss_id"] = String(boss_id)
	result["loot"] = loot_banked
	result["meta_saved"] = Meta.last_save_ok

	# Grade moves the venue stock. A CONTRACT pumps it (less for every repeat
	# contract on the same venue); a HIT crashes it, harder the cleaner the job.
	var delta: float = result["stock_delta"]
	if hit_job:
		delta = 2.0 - delta
	else:
		var repeats: int = int(RunState.contract_counts.get(String(_venue), 0))
		if delta > 1.0:
			delta = 1.0 + (delta - 1.0) * pow(0.65, repeats)
			if RunState.has_perk(&"inside_trader"):
				delta = 1.0 + (delta - 1.0) * 1.25
		RunState.contract_counts[String(_venue)] = repeats + 1
	result["stock_delta"] = delta
	result["contract"] = "HIT" if hit_job else "CONTRACT"
	if live:
		live.report_shock(delta, &"grade")
	else:
		var asset = RunState.market.get_asset(_venue) if RunState.market else null
		if asset:
			asset.current_price = maxf(asset.current_price * delta, 0.01)

	# The wire's rumors land, then every Fence position settles at today's prices.
	result["rumors"] = MarketNews.resolve_rumors()
	result["positions"] = Positions.settle_all()
	result["stats"] = stats
	RunState.sync_from_player(player)
	if results:
		results.show_result(result, String(_venue))
	else:
		_on_results_continued()

func _on_results_continued() -> void:
	RunFlow.on_heist_finished()

var _chip_accum := 0.0
var _chip_clock := 0.0

## Your actions move the venue: gather small moves for a beat, then pop a
## "+2.3%" chip by the player and flash the ticker.
func _on_player_moved_market(pct: float) -> void:
	_chip_accum += pct
	if _chip_clock <= 0.0:
		_chip_clock = 0.35

func _tick_market_chip(delta: float) -> void:
	if _chip_clock <= 0.0:
		return
	_chip_clock -= delta
	if _chip_clock > 0.0:
		return
	if absf(_chip_accum) >= 0.001 and is_instance_valid(player):
		var col := Palette.UP if _chip_accum > 0.0 else Palette.DOWN
		Audio.play("stock_up" if _chip_accum > 0.0 else "stock_down")
		fx.chip(player.global_position, "%s %+.1f%%" % [Venues.ticker(_venue), _chip_accum * 100.0], col)
		if hud and hud.get("ticker"):
			hud.ticker.flash(col)
	_chip_accum = 0.0

func _on_player_health(current: int, maximum: int) -> void:
	if post_fx:
		post_fx.set_health(current, maximum)

## Damage feedback shared by every hit on the player.
func on_player_hurt() -> void:
	if post_fx:
		post_fx.hit(1.0)

func _on_player_died() -> void:
	# Die before extracting: the loot is gone and so is the run.
	if _extracting:
		return
	_extracting = true
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
		var pos := _loot_slot(size, placed, room)
		placed.append(pos)
		var pickup := LootPickup.new()
		pickup.value = _rng.randi_range(per_min, per_max)
		room.add_child(pickup)
		pickup.position = pos
		pickup.collected.connect(_on_loot_collected.bind(pickup))

## A floor position inset from the walls, spaced from other loot.
func _loot_slot(size: Vector2, placed: Array, room: BuildingRoom = null) -> Vector2:
	var candidate := Vector2.ZERO
	for attempt in 16:
		candidate = Vector2(
			_rng.randf_range(90, size.x - 90),
			_rng.randf_range(90, size.y - 90))
		var ok := true
		for p: Vector2 in placed:
			if candidate.distance_to(p) < 80.0:
				ok = false
				break
		if ok and room:
			for r: Rect2 in room.blocked_rects:
				if r.grow(20).has_point(candidate):
					ok = false
					break
		if ok:
			return candidate
	return candidate

func _on_loot_collected(value: int, pickup: Node2D = null) -> void:
	# Valuables are worth what the venue trades at, the moment you pick them up.
	var paid := roundi(value * loot_multiplier() * live_loot_multiplier() * (1.25 if RunState.has_perk(&"scavenger") else 1.0))
	loot_banked += paid
	if pickup and is_instance_valid(pickup) and hud and hud.has_method("fly_gold"):
		hud.fly_gold(pickup.get_global_transform_with_canvas().origin, paid)
	RunEconomy.add_bonus(paid)
	var tier := 0 if value <= 25 else (1 if value <= 60 else (2 if value <= 140 else 3))
	Audio.play("loot_%d" % tier, pickup.global_position if pickup and is_instance_valid(pickup) else null)
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

func fire_exit_limit() -> float:
	return fire_exit_heat_limit

## Live loot multiplier: floor valuables are worth more while the venue trades
## above its listing price (Phase 6 wires the pickups to it).
func live_loot_multiplier() -> float:
	if RunState.market == null:
		return 1.0
	var a: CriminalAsset = RunState.market.get_asset(_venue)
	if a == null or a.base_price <= 0.0:
		return 1.0
	return clampf(a.current_price / a.base_price, 0.5, 2.0)

func dispatch_threshold() -> float:
	return 8.0 if modifier == &"heavy_police" else 16.0

func add_heat(amount: float, source: String) -> void:
	if amount <= 0.0 or _extracting:
		return
	var was_quiet := heat < dispatch_threshold()
	var gained := amount * (0.75 if RunState.has_perk(&"cool_head") else 1.0)
	heat = minf(100.0, heat + gained)
	quiet_seconds = 0.0
	last_heat_source = source
	if hud and hud.has_method("log_heat"):
		hud.log_heat("%s  +%d" % [source.to_upper(), roundi(gained)])
	if was_quiet and heat >= dispatch_threshold():
		_heat_timer = minf(_heat_timer, 4.0)

## A witnessed intrusion (camera, radio call): heat now, and the nearest alarm
## panel starts transmitting until someone cuts it.
func security_alert(room: Node, source: String, amount: float) -> void:
	add_heat(amount, source)
	var at: Vector2 = room.center_position() if room and room.has_method("center_position") else player.global_position
	var panel := nearest_alarm_panel(at)
	if panel:
		panel.armed = true
		panel.transmit_clock = maxf(panel.transmit_clock, 2.0)

func on_security_disabled(_device: SecurityDevice) -> void:
	security_disabled += 1
	heat = maxf(0.0, heat - 4.0)
	last_heat_source = "Security disabled · heat -4"
	if live:
		live.report_sabotage()
	Audio.play("shutter")
	fx.add_trauma(0.15)

## Cameras sweep most rooms. Alarm panels are rarer — 1 to 3 per building,
## placed first where a security tech works, then spread far apart — so
## cutting them is a real errand and a tech's sprint is a real threat.
func _setup_security() -> void:
	var rooms: Array = []
	for room in generator.rooms:
		if room != generator.start_room:
			rooms.append(room)
	for room in rooms:
		_add_device(room, SecurityDevice.Kind.CAMERA, CAMERA_SPOT)
		if modifier == &"camera_network":
			_add_device(room, SecurityDevice.Kind.CAMERA, Vector2(room.room_size.x - CAMERA_SPOT.x, CAMERA_SPOT.y))
	var count := clampi(1 + int(_stage >= 1) + int(_stage >= 3 or _rarity >= 3), 1, 3)
	var chosen: Array = []
	for room in rooms:
		if chosen.size() >= count:
			break
		for c in room.get_children():
			if c is Enemy and c.kind == Enemy.Kind.TECH:
				chosen.append(room)
				break
	var anchors: Array = [generator.start_room.center_position()]
	for room in chosen:
		anchors.append(room.center_position())
	while chosen.size() < count and chosen.size() < rooms.size():
		var best = null
		var best_score := -1.0
		for room in rooms:
			if room in chosen:
				continue
			var nearest := INF
			for a: Vector2 in anchors:
				nearest = minf(nearest, a.distance_to(room.center_position()))
			nearest += _rng.randf() * 120.0
			if nearest > best_score:
				best_score = nearest
				best = room
		chosen.append(best)
		anchors.append(best.center_position())
	for room in chosen:
		_add_device(room, SecurityDevice.Kind.ALARM, Vector2(room.room_size.x - 65, room.room_size.y - 100))

const CAMERA_SPOT := Vector2(55, 70)

func _add_device(room, kind: int, local: Vector2) -> SecurityDevice:
	var device := SecurityDevice.new()
	device.kind = kind
	device.floor_host = self
	device.room = room
	device.position = room.position + local
	add_child(device)
	return device

func stage_index() -> int:
	return _stage

## The closest alarm panel still online, or null.
func nearest_alarm_panel(pos: Vector2) -> SecurityDevice:
	var best: SecurityDevice = null
	var best_d := INF
	for device in get_tree().get_nodes_in_group("security"):
		if device.kind != SecurityDevice.Kind.ALARM or device.disabled:
			continue
		var d: float = device.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = device
	return best

## Someone reached a panel: heat spike, every panel transmits, and a van is
## sent right now.
func raise_alarm(source: String, panel: SecurityDevice = null) -> void:
	if _extracting:
		return
	alarms_raised += 1
	# While a response is already rolling, another pull only adds heat.
	var now := active_elapsed
	if now < _alarm_quiet_until:
		add_heat(5.0, source)
		return
	_alarm_quiet_until = now + 25.0
	add_heat(14.0, source)
	for device in get_tree().get_nodes_in_group("security"):
		if device.kind == SecurityDevice.Kind.ALARM and not device.disabled:
			device.armed = true
			device.transmit_clock = maxf(device.transmit_clock, 3.0)
	Audio.play("alert")
	fx.add_trauma(0.25)
	if is_instance_valid(panel):
		fx.chip(panel.global_position, "ALARM RAISED", Palette.DANGER)
	_spawn_reinforcements()
	_heat_timer = maxf(_heat_timer, 14.0)

## A companion that arrives with its owner: a handler's dog, a tech's drone.
func spawn_companion(owner: Enemy, kind: int, offset: Vector2) -> Enemy:
	var scene: PackedScene = load(ENEMY_SCENE_PATH)
	var parent := owner.get_parent()
	if scene == null or parent == null or not owner.is_inside_tree():
		return null
	var e: Enemy = scene.instantiate()
	e.position = _free_spot(parent, owner.position, offset)
	if parent is BuildingRoom:
		parent.adopt(e)
	else:
		parent.add_child(e)
	e.apply_archetype(kind)
	if owner._has_guard_rect:
		e.set_guard_room(owner._guard_rect)
	e.set_post(e.global_position)
	e.set_meta("hooked", true)
	_enemies_total += 1
	e.died.connect(_on_enemy_died)
	return e

## `base + offset` in `parent` space, nudged until it is clear of walls/props.
func _free_spot(parent: Node, base: Vector2, offset: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var xf: Transform2D = parent.global_transform if parent is Node2D else Transform2D.IDENTITY
	for i in 8:
		var local := base + offset.rotated(TAU * i / 8.0)
		var query := PhysicsPointQueryParameters2D.new()
		query.position = xf * local
		query.collision_mask = Layers.SOLID
		if space.intersect_point(query, 1).is_empty():
			return local
	return base

## A valuable dropped in the world (elite kills).
func drop_loot(at: Vector2, value: int) -> void:
	var pickup := LootPickup.new()
	pickup.value = value
	pickup.position = to_local(at)
	pickup.collected.connect(_on_loot_collected.bind(pickup))
	spawn_deferred(pickup)

## Where a fleeing civilian heads: the nearest way out of the building.
func nearest_way_out(pos: Vector2) -> Vector2:
	var best := _outside_position()
	var best_d := pos.distance_to(best)
	for g: Dictionary in generator.exits:
		if not g.get("open", false):
			continue
		var wall: Vector2 = g["room"].to_global(g["wall_pos"])
		var out: Vector2 = wall + (wall - g["inside_pos"]).normalized() * 80.0
		if pos.distance_to(out) < best_d:
			best_d = pos.distance_to(out)
			best = out
	return best

func on_civilian_killed(civ: Node2D, player_caused: bool) -> void:
	if player_caused:
		civilians_killed += 1
		add_heat(14.0, "Civilian down")
		if live:
			live.report_shock(0.88, &"civilian")
	else:
		add_heat(6.0, "Civilian casualty")
	fx.chip(civ.global_position, "CIVILIAN DOWN", Palette.DANGER)

## Bystanders in some ordinary rooms (never the boss room or treasure rooms).
func _spawn_civilians() -> void:
	var rooms_with := 0
	for room in generator.rooms:
		if room == generator.start_room or room.has_meta("is_boss") or room.has_meta("chest_kind"):
			continue
		if boss_heist or _rng.randf() > 0.34:
			continue
		rooms_with += 1
		var placed: Array = []
		for i in _rng.randi_range(1, 2):
			var civ := Civilian.new()
			civ.stage = _stage
			civ.look_seed = _rng.randi()
			civ.runner = _rng.randf() < 0.3
			var pos := _loot_slot(room.room_size, placed, room)
			placed.append(pos)
			civ.position = pos
			room.add_child(civ)

# ------------------------------------------------------------- bosses -----
static func boss_scene_path(id: StringName) -> String:
	var path := "res://%s_boss.tscn" % String(id)
	return path if ResourceLoader.exists(path) else "res://auditor_boss.tscn"

## The player walked into the arena: seal it, pan to the boss, title card.
func start_boss_fight(b: Boss) -> void:
	boss = b
	_seal_arena(b.get_parent())
	start_boss_music()
	if hud and hud.boss_bar:
		hud.boss_bar.show_for(b, b.display_name, b.subtitle, b.thresholds)
	if is_instance_valid(player):
		player._mercy_timer = 2.8
	_focus_point = b.global_position
	_focus_until_msec = Time.get_ticks_msec() + 2300
	var card := BossIntroCard.new()
	card.boss_name = b.display_name
	card.subtitle = b.subtitle
	add_child(card)
	card.finished.connect(_on_boss_intro_done)

func _on_boss_intro_done() -> void:
	if is_instance_valid(boss) and not boss._dead:
		boss.finish_intro()

## Steel shutters drop over every doorway of the arena.
func _seal_arena(room: Node2D) -> void:
	for gap: Dictionary in _open_gaps_local(room):
		var shutter := Shutter.new()
		shutter.horizontal = gap["horizontal"]
		shutter.width = FloorGenerator.DOOR_GAP + 18.0
		shutter.thickness = FloorGenerator.WALL_THICK + 8.0
		shutter.position = gap["local"]
		room.add_child(shutter)
		shutter.close()
		_shutters.append(shutter)

func _open_arena() -> void:
	for shutter in _shutters:
		if is_instance_valid(shutter):
			shutter.open()
	_shutters.clear()

## A line of dialogue under the boss bar (and over the boss).
func boss_says(b: Enemy, line: String) -> void:
	if line == "":
		return
	if hud and hud.boss_bar:
		hud.boss_bar.say(line)
	if is_instance_valid(b):
		fx.chip(b.global_position + Vector2(0, -40), line, Palette.PAPER)

## The Auditor's ledger: while it is open, hits crash the stock twice as hard.
func set_audit(on: bool) -> void:
	audit_active = on
	if live:
		live.damage_multiplier = 2.0 if on else 1.0

## The Auditor's cover: `count` desks spread through the arena. World positions.
func place_desks(b: Boss, count: int, first: int = 0) -> Array:
	var room: Node2D = b.get_parent()
	var spots := [Vector2(0.28, 0.3), Vector2(0.72, 0.3), Vector2(0.5, 0.72), Vector2(0.2, 0.62), Vector2(0.8, 0.62)]
	var out: Array = []
	for i in range(first, mini(first + count, spots.size())):
		var local: Vector2 = room.room_size * spots[i]
		var world := room.to_global(local)
		if is_instance_valid(player) and world.distance_to(player.global_position) < 90.0:
			continue
		_clear_props_at(room, local, 70.0)
		var desk := Prop.new()
		desk.kind = "desk"
		desk.size = Vector2(112, 56)
		desk.theme = env
		desk.seed_value = i
		desk.position = local
		room.add_child(desk)
		out.append(world)
	return out

## The Landlord's second act: tables flip up into new cover around the room.
func flip_tables(b: Boss, count: int) -> void:
	var room: Node2D = b.get_parent()
	for i in count:
		var local := Vector2.ZERO
		for attempt in 12:
			local = Vector2(randf_range(120.0, room.room_size.x - 120.0), randf_range(120.0, room.room_size.y - 120.0))
			var world := room.to_global(local)
			if world.distance_to(b.global_position) > 130.0 and (not is_instance_valid(player) or world.distance_to(player.global_position) > 130.0):
				break
		_clear_props_at(room, local, 60.0)
		var table := Prop.new()
		table.kind = "card_table"
		table.size = Vector2(92, 92)
		table.is_round = true
		table.theme = env
		table.seed_value = 40 + i
		table.position = local
		table.scale = Vector2(0.2, 0.2)
		room.add_child(table)
		var tw := table.create_tween()
		tw.tween_property(table, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fx.spark(table.global_position, Vector2.UP, Palette.SODIUM)
	Audio.play("door_bang", b.global_position)

func _clear_props_at(room: Node2D, local: Vector2, radius: float) -> void:
	for c in room.get_children():
		if c is Prop and c.position.distance_to(local) < radius:
			c.queue_free()

## Boss down: slow motion, a burst of cash, the stock shock, the doors open,
## and a unique reward drops where he fell.
func on_boss_down(b: Boss) -> void:
	fx.slow_mo(1.2, 0.2)
	fx.add_trauma(0.9)
	Audio.play("boss_death")
	set_audit(false)
	if hud and hud.boss_bar:
		hud.boss_bar.clear()
	if not marked:
		_become_marked()
	_open_arena()
	_boss_music = false
	Audio.music_layers("heist_stealth", "heist_combat")
	Audio.set_intensity(1.0)
	if not RunFlow.practice:
		Meta.record_boss(b.boss_id, false)
	if b.boss_id == &"chairman":
		# The last trade: the heist wraps itself up and the ending plays.
		RunEconomy.add_bonus(_rng.randi_range(400, 600))
		get_tree().create_timer(3.2, false).timeout.connect(_extract)
		return
	_cash_burst(b.global_position, _rng.randi_range(8, 12), 18 + 8 * _stage)
	_drop_boss_reward(b)

## Coins and notes spraying out of a fallen boss.
func _cash_burst(at: Vector2, count: int, each: int) -> void:
	for i in count:
		var pickup := LootPickup.new()
		pickup.value = each + _rng.randi_range(0, each)
		var landing := at + Vector2.from_angle(TAU * i / count + _rng.randf() * 0.4) * _rng.randf_range(50.0, 150.0)
		pickup.position = to_local(at)
		pickup.set_meta("landing", to_local(landing))
		pickup.collected.connect(_on_loot_collected.bind(pickup))
		spawn_deferred(pickup)

## Nodes born inside a physics callback (a kill, a blast) join the floor on the
## next idle frame. Anything still waiting when the floor goes away is freed
## with it instead of leaking.
var _pending_spawns: Array = []

func spawn_deferred(node: Node) -> void:
	_pending_spawns.append(node)
	_add_pending.call_deferred(node)

func _add_pending(node: Node) -> void:
	_pending_spawns.erase(node)
	if not is_instance_valid(node):
		return
	add_child(node)
	if node.has_meta("landing"):
		var tw := node.create_tween()
		tw.tween_property(node, "position", node.get_meta("landing"), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for node in _pending_spawns:
			if is_instance_valid(node):
				node.free()
		_pending_spawns.clear()

## The boss's unique weapon, in a case where he fell.
func _drop_boss_reward(b: Boss) -> void:
	var weapon := ItemPool.boss_weapon(b.boss_id)
	var scene = load("res://world_chest.tscn")
	if weapon == null or scene == null:
		return
	var chest = scene.instantiate()
	chest.set("kind", 0)
	chest.set("tier", LootRoller.ChestTier.AIRDROP)
	chest.fixed_items = [weapon]
	chest.position = to_local(b.global_position)
	spawn_deferred(chest)

## Debug/screenshot helper: skip the intro and put the stage boss down.
func debug_kill_boss() -> void:
	var b: Boss = boss
	if b == null and generator and generator.boss_room:
		for c in generator.boss_room.get_children():
			if c is Boss:
				b = c
	if b == null or b._dead:
		return
	if not b.engaged:
		b.engage()
	b.finish_intro()
	b.invulnerable = false
	b.immune_reason = ""
	b._transition = 0.0
	b.take_damage(999999)

## Ordinary jobs: the lieutenant gets a bar once he joins the fight.
func _watch_lieutenant() -> void:
	if _lieutenant_shown or not is_instance_valid(lieutenant) or lieutenant._dead:
		return
	if lieutenant._alert == Enemy.Alert.HUNTING and hud and hud.boss_bar:
		_lieutenant_shown = true
		hud.boss_bar.show_for(lieutenant, lieutenant.elite_tag, "LIEUTENANT")

func _on_lieutenant_down(e) -> void:
	if hud and hud.boss_bar and hud.boss_bar.boss == e:
		hud.boss_bar.clear()
	fx.chip(e.global_position, "LIEUTENANT DOWN", Palette.GOLD)
	if not RunFlow.practice:
		Meta.record_boss(&"lieutenant", true)

func _setup_tactics() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	tactical_map = HeistMap.new()
	tactical_map.floor_host = self
	tactical_map.full_reveal = modifier == &"insider"
	ui.add_child(tactical_map)
	tactical_map.hide()
	var toggle := Button.new()
	toggle.text = "MAP"
	toggle.position = Vector2(1040, 38)
	toggle.size = Vector2(98, 58)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(_toggle_map)
	ui.add_child(toggle)
	if hud and hud.has_method("bind_floor"):
		hud.bind_floor(self)
	_update_security_status()

## Music intensity follows the alarm state: sneaking plays the stealth layer,
## anyone hunting you (or heat past the dispatch line) brings in the combat
## layer. The siren loops while a response is rolling; a heartbeat at 1 HP.
func _update_audio() -> void:
	if _extracting or not is_instance_valid(player):
		return
	var hunting := 0
	for e in director.enemies:
		if is_instance_valid(e) and not e.sleeping and e._alert == Enemy.Alert.HUNTING:
			hunting += 1
	var intensity := clampf(heat / maxf(dispatch_threshold(), 1.0), 0.0, 1.0)
	if hunting > 0:
		intensity = maxf(intensity, clampf(0.65 + hunting * 0.07, 0.0, 1.0))
	if not _boss_music:
		Audio.set_intensity(intensity)
	var responding := heat >= dispatch_threshold()
	if responding != _siren_on:
		_siren_on = responding
		Audio.loop("alarm", responding)
		if lighting and not generator.entrance.is_empty():
			lighting.set_police(responding, _outside_position())
	var low := player.health == 1 and player.max_health > 1 and not player.is_dead()
	if low != _heartbeat_on:
		_heartbeat_on = low
		Audio.loop("heartbeat", low)

## The boss notices you: stinger, then the boss theme takes over.
func start_boss_music() -> void:
	if _boss_music:
		return
	_boss_music = true
	Audio.play("boss_intro")
	Audio.music("boss", 0.6)

func _exit_tree() -> void:
	Audio.loop("alarm", false)
	Audio.loop("heartbeat", false)

func _toggle_map() -> void:
	if get_tree().paused and not tactical_map.visible:
		return
	Controls.release_all()
	tactical_map.visible = not tactical_map.visible
	get_tree().paused = tactical_map.visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tactical_map") and not event.is_echo():
		_toggle_map()
		get_viewport().set_input_as_handled()

func _update_security_status() -> void:
	_update_audio()
	if hud and hud.has_method("set_heat"):
		hud.set_heat(heat, dispatch_threshold(), fire_exit_limit(), _heat_timer)
		hud.set_loot_multiplier(live_loot_multiplier())

## Stage art for the whole building: themed floors, walls with height,
## furniture that doubles as cover. Runs right after generation, before crews.
func _dress_building() -> void:
	var stage_idx: int = RunFlow.pending_heist.stage if RunFlow.pending_heist else (RunState.run_map.current_stage if RunState.run_map else 0)
	if boss_heist and BossLayouts.has_layout(boss_id):
		stage_idx = BossLayouts.stage_of(boss_id)
	env = EnvTheme.for_stage(stage_idx)
	building_bounds = Rect2()
	for room: BuildingRoom in generator.rooms:
		var rect := Rect2(room.global_position, room.room_size)
		building_bounds = rect if building_bounds.size == Vector2.ZERO else building_bounds.merge(rect)
		var gaps := _open_gaps_local(room)
		var obstacles: Array = []
		var counter := room.get_node_or_null("Counter") as StaticBody2D
		if counter:
			# Authored counters become proper furniture on the props layer.
			var prop := Prop.new()
			prop.kind = "counter"
			prop.size = Vector2(170, 34)
			prop.theme = env
			prop.position = counter.position
			counter.queue_free()
			room.add_child(prop)
			obstacles.append(prop.footprint())
			room.blocked_rects.append(prop.footprint().grow(12))
		var art := RoomArt.new()
		art.room = room
		art.theme = env
		art.room_type = env.room_type_for(room, room == generator.start_room)
		art.open_gaps = gaps
		room.set_meta("room_type", art.room_type)
		room.add_child(art)
		var walls := RoomArt.WallArt.new()
		walls.room = room
		walls.theme = env
		room.add_child(walls)
		wall_art.append(walls)
		var keepouts: Array = []
		for marker in room.get_node("SpawnPoints").get_children() if room.has_node("SpawnPoints") else []:
			keepouts.append([marker.position, 46.0])
		keepouts.append([Vector2(55, 70), 50.0])                                        # camera
		keepouts.append([Vector2(room.room_size.x - 55, 70), 50.0])                     # second camera
		keepouts.append([Vector2(room.room_size.x - 65, room.room_size.y - 100), 56.0])  # alarm panel
		if room == generator.start_room:
			keepouts.append([Vector2(430, 270), 70.0])                                   # market terminal
		if room.has_meta("is_boss"):
			keepouts.append([room.room_size * 0.5, 170.0])
		elif room.has_meta("chest_kind"):
			keepouts.append([room.room_size * 0.5, 90.0])
		var placer := PropPlacer.new()
		placer.room = room
		placer.theme = env
		placer.room_type = art.room_type
		placer.furnish(gaps, keepouts, obstacles)

## Doorways of a room that actually lead somewhere: into a neighbour, or out
## through the main door / a fire exit. Local coordinates.
func _open_gaps_local(room: Node2D) -> Array:
	var out: Array = []
	for gap: Dictionary in generator._gaps_of(room):
		var side: int = gap["side"]
		var neighbour: Vector2i = gap["cell"] + FloorGenerator.SIDE_DELTA[side]
		var open: bool = generator._occupied.has(neighbour) and generator._occupied[neighbour] != room
		if not open:
			for door: Dictionary in [generator.entrance] + generator.exits:
				if not door.is_empty() and door["room"] == room and door["side"] == side and door["wall_pos"] == gap["wall_pos"]:
					open = true
		if open:
			out.append({"local": gap["wall_pos"], "side": side, "horizontal": side == FloorGenerator.NORTH or side == FloorGenerator.SOUTH})
	return out

## Outside and lighting: once the player and car exist.
func _dress_outside() -> void:
	lighting = HeistLighting.new()
	add_child(lighting)
	lighting.setup(env, generator.rooms, player, modifier == &"blackout")
	fx.lighting = lighting
	var occluders: Array = []
	for walls: RoomArt.WallArt in wall_art:
		for r: Rect2 in walls.rects:
			occluders.append(Rect2(r.position + walls.room.global_position, r.size))
	lighting.add_occluders(occluders)
	var street := StreetArt.new()
	street.bounds = building_bounds
	street.theme = env
	street.lighting = lighting
	if not generator.entrance.is_empty():
		var e: Dictionary = generator.entrance
		var wall_world: Vector2 = e["room"].to_global(e["wall_pos"])
		street.door_pos = wall_world
		street.door_out = (wall_world - e["inside_pos"]).normalized()
	street.sign_text = Venues.sign_name(_venue, boss_id)
	add_child(street)
	var rain := StreetArt.Rain.new()
	rain.follow = camera
	add_child(rain)
	if car:
		car.add_headlights(lighting)
	for g: Dictionary in generator.exits:
		lighting.add_street_lamp(g["inside_pos"], Palette.NEON_GREEN, 1.1, 0.7)
