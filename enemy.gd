extends CharacterBody2D
class_name Enemy

## A guard. Chases and shoots the player, takes damage, dies.
## Must be in the "enemies" group (added in _ready).
##
## ROLES:
##   PATROL  — investigates noises, then returns to its post.
##   SENTRY  — guards valuables and NEVER leaves its post. It will shoot at
##             anything it can see, but it won't walk off to chase a sound.
##
## ALERT STATES:
##   IDLE          holding post, unaware
##   INVESTIGATING heard something, walking to where the noise came from
##   HUNTING       has seen the player; chases and shoots
## A guard that loses the player relaxes back to INVESTIGATING, then IDLE.

signal died(enemy: Enemy)

enum Role { PATROL, SENTRY }
enum Alert { IDLE, INVESTIGATING, HUNTING }

## Guard archetypes. Applied via apply_archetype(); each one retunes health,
## weapon behaviour and movement so a building has a readable mix of threats
## rather than fifteen identical shooters. SPRINTER, TURRET and MEDIC also get
## distinct MOVEMENT behaviour, not just different numbers — see _do_hunt.
## RIOT onwards run an EnemyBrain (enemy_brains.gd) with their own telegraphs.
enum Kind { GRUNT, ENFORCER, SHOTGUNNER, MARKSMAN, BRUTE, SPRINTER, TURRET, MEDIC,
	RIOT, GRENADIER, HANDLER, DOG, TECH, SNIPER, BOUNCER, DRONE, CLEANER }

const KIND_NAMES := {
	Kind.GRUNT: "GUARD", Kind.ENFORCER: "ENFORCER", Kind.SHOTGUNNER: "SHOTGUNNER",
	Kind.MARKSMAN: "MARKSMAN", Kind.BRUTE: "BRUTE", Kind.SPRINTER: "SPRINTER",
	Kind.TURRET: "TURRET", Kind.MEDIC: "MEDIC", Kind.RIOT: "RIOT SHIELD",
	Kind.GRENADIER: "GRENADIER", Kind.HANDLER: "K9 HANDLER", Kind.DOG: "DOG",
	Kind.TECH: "SECURITY TECH", Kind.SNIPER: "LASER SNIPER", Kind.BOUNCER: "BOUNCER",
	Kind.DRONE: "DRONE", Kind.CLEANER: "CLEANER",
}

## Elite affixes (City onward, or late reinforcements). Elites glow, carry a
## name tag and drop a valuable.
const AFFIXES := [&"armored", &"volatile", &"hasted", &"shielded", &"veteran"]
const AFFIX_COLORS := {
	&"armored": Color("a9bccf"), &"volatile": Color("ff7a2a"), &"hasted": Color("ffe14a"),
	&"shielded": Color("37e3ff"), &"veteran": Color("e0544c"),
}
const SHIELD_MAX := 3
const SHIELD_REGEN := 3.5

const ARCHETYPES := {
	Kind.GRUNT: {
		"health": 3, "speed": 90.0, "fire_rate": 1.2, "range": 400.0,
		"keep": 180.0, "damage": 1, "pellets": 1, "spread": 0.05,
		"bullet_speed": 320.0, "colour": Color(0.85, 0.35, 0.35),
	},
	Kind.ENFORCER: {   # steady rifle fire, pushes in
		"health": 5, "speed": 105.0, "fire_rate": 0.75, "range": 480.0,
		"keep": 200.0, "damage": 1, "pellets": 1, "spread": 0.03,
		"bullet_speed": 400.0, "colour": Color(0.95, 0.55, 0.2),
	},
	Kind.SHOTGUNNER: { # deadly close, harmless far — forces you to keep distance
		"health": 4, "speed": 120.0, "fire_rate": 1.6, "range": 240.0,
		"keep": 90.0, "damage": 1, "pellets": 5, "spread": 0.30,
		"bullet_speed": 340.0, "colour": Color(0.9, 0.75, 0.25),
	},
	Kind.MARKSMAN: {   # slow, accurate, long range; hangs back
		"health": 2, "speed": 70.0, "fire_rate": 2.2, "range": 700.0,
		"keep": 420.0, "damage": 2, "pellets": 1, "spread": 0.0,
		"bullet_speed": 620.0, "colour": Color(0.55, 0.75, 1.0),
	},
	Kind.BRUTE: {      # slow tank, hits hard, soaks a magazine
		"health": 10, "speed": 62.0, "fire_rate": 1.9, "range": 300.0,
		"keep": 60.0, "damage": 2, "pellets": 3, "spread": 0.18,
		"bullet_speed": 280.0, "colour": Color(0.65, 0.3, 0.75),
	},
	Kind.SPRINTER: {   # hit-and-run: dashes in close, fires, then bolts back out
		"health": 3, "speed": 175.0, "fire_rate": 1.1, "range": 260.0,
		"keep": 140.0, "damage": 1, "pellets": 1, "spread": 0.08,
		"bullet_speed": 360.0, "colour": Color(0.95, 0.35, 0.65),
	},
	Kind.TURRET: {     # never moves an inch, but hits hard and far — a threat
		"health": 6, "speed": 0.0, "fire_rate": 1.0, "range": 620.0,
		"keep": 0.0, "damage": 2, "pellets": 1, "spread": 0.02,
		"bullet_speed": 480.0, "colour": Color(0.6, 0.62, 0.68),
	},
	Kind.MEDIC: {      # weak and unarmed-ish; heals allies, runs from a fight
		"health": 3, "speed": 100.0, "fire_rate": 1.8, "range": 260.0,
		"keep": 260.0, "damage": 1, "pellets": 1, "spread": 0.1,
		"bullet_speed": 300.0, "colour": Color(0.5, 0.95, 0.65),
	},
	Kind.RIOT: {       # frontal shield, slow advance, shield bash up close
		"health": 8, "speed": 58.0, "fire_rate": 1.5, "range": 320.0,
		"keep": 60.0, "damage": 1, "pellets": 1, "spread": 0.08,
		"bullet_speed": 330.0, "colour": Color(0.55, 0.65, 0.8),
	},
	Kind.GRENADIER: {  # fire_rate = seconds between grenades
		"health": 4, "speed": 80.0, "fire_rate": 3.4, "range": 520.0,
		"keep": 320.0, "damage": 2, "pellets": 1, "spread": 0.0,
		"bullet_speed": 0.0, "colour": Color(0.6, 0.7, 0.35),
	},
	Kind.HANDLER: {    # an ordinary shooter who brings a dog
		"health": 4, "speed": 95.0, "fire_rate": 1.3, "range": 380.0,
		"keep": 210.0, "damage": 1, "pellets": 1, "spread": 0.06,
		"bullet_speed": 330.0, "colour": Color(0.75, 0.55, 0.3),
	},
	Kind.DOG: {        # fast and fragile; fire_rate = seconds between lunges
		"health": 2, "speed": 235.0, "fire_rate": 1.1, "range": 170.0,
		"keep": 0.0, "damage": 1, "pellets": 1, "spread": 0.0,
		"bullet_speed": 0.0, "colour": Color(0.55, 0.42, 0.3),
	},
	Kind.TECH: {       # unarmed: runs for the alarm panel
		"health": 3, "speed": 130.0, "fire_rate": 99.0, "range": 0.0,
		"keep": 380.0, "damage": 0, "pellets": 1, "spread": 0.0,
		"bullet_speed": 0.0, "colour": Color(0.35, 0.75, 0.72),
	},
	Kind.SNIPER: {     # fire_rate = cooldown after each heavy shot
		"health": 3, "speed": 62.0, "fire_rate": 1.6, "range": 900.0,
		"keep": 520.0, "damage": 2, "pellets": 1, "spread": 0.0,
		"bullet_speed": 1050.0, "colour": Color(0.9, 0.25, 0.25),
	},
	Kind.BOUNCER: {    # fists; fire_rate = punch cooldown, range = charge reach
		"health": 12, "speed": 100.0, "fire_rate": 1.1, "range": 260.0,
		"keep": 0.0, "damage": 1, "pellets": 1, "spread": 0.0,
		"bullet_speed": 0.0, "colour": Color(0.2, 0.2, 0.24),
	},
	Kind.DRONE: {      # fire_rate = seconds between 3-round bursts
		"health": 2, "speed": 150.0, "fire_rate": 1.9, "range": 440.0,
		"keep": 230.0, "damage": 1, "pellets": 1, "spread": 0.1,
		"bullet_speed": 380.0, "colour": Color(0.4, 0.45, 0.5),
	},
	Kind.CLEANER: {    # cloaked black-ops; fire_rate = seconds between bursts
		"health": 6, "speed": 140.0, "fire_rate": 1.5, "range": 460.0,
		"keep": 210.0, "damage": 1, "pellets": 1, "spread": 0.06,
		"bullet_speed": 470.0, "colour": Color(0.1, 0.12, 0.14),
	},
}

@export var move_speed: float = 90.0
@export var max_health: int = 3
@export var fire_rate: float = 1.2           # seconds between shots
@export var fire_range: float = 400.0        # only shoots if player within range
@export var keep_distance: float = 180.0     # tries to hold this gap
@export var contact_damage: int = 1
@export var currency_value: int = 15         # currency awarded to the player on death
@export var sight_range: float = 420.0       # sees the player this far, line-of-sight
@export var hearing_multiplier: float = 1.0  # scales how far this guard hears
@export var role: Role = Role.PATROL
@export var enemy_bullet_scene: PackedScene  # assign EnemyBullet.tscn

## Weapon shape, set by the archetype.
var bullet_damage: int = 1
var pellets: int = 1
var spread: float = 0.05
var bullet_speed: float = 320.0
var kind: Kind = Kind.GRUNT

## Apply an archetype's stats. Call BEFORE the node enters the tree if possible;
## it also refreshes health so it works after _ready().
func apply_archetype(k: Kind) -> void:
	kind = k
	var a: Dictionary = ARCHETYPES[k]
	max_health = a["health"]
	health = max_health
	move_speed = a["speed"]
	fire_rate = a["fire_rate"]
	fire_range = a["range"]
	keep_distance = a["keep"]
	bullet_damage = a["damage"]
	pellets = a["pellets"]
	spread = a["spread"]
	bullet_speed = a["bullet_speed"]
	# Marksmen are watchful; brutes are half-deaf.
	match k:
		Kind.MARKSMAN:
			sight_range = 720.0
			hearing_multiplier = 1.2
		Kind.BRUTE:
			hearing_multiplier = 0.7
		Kind.TURRET:
			sight_range = 620.0
			hearing_multiplier = 0.0      # can't hear a thing, must be seen
		Kind.MEDIC:
			hearing_multiplier = 1.4      # skittish, notices everything
		Kind.SPRINTER:
			hearing_multiplier = 1.1
		Kind.SNIPER:
			sight_range = 950.0
		Kind.DOG:
			hearing_multiplier = 1.5
		Kind.TECH:
			hearing_multiplier = 1.2
		Kind.DRONE:
			sight_range = 520.0
			hearing_multiplier = 0.8
		Kind.CLEANER:
			sight_range = 560.0
		Kind.BOUNCER:
			hearing_multiplier = 0.8
		_:
			pass
	brain = _make_brain(k)
	if brain:
		brain.e = self
		brain.setup()
	_apply_body_layers()
	_apply_archetype_visual()

func _make_brain(k: Kind) -> EnemyBrain:
	match k:
		Kind.RIOT: return EnemyBrains.Riot.new()
		Kind.GRENADIER: return EnemyBrains.Grenadier.new()
		Kind.HANDLER: return EnemyBrains.Handler.new()
		Kind.DOG: return EnemyBrains.Dog.new()
		Kind.TECH: return EnemyBrains.Tech.new()
		Kind.SNIPER: return EnemyBrains.Sniper.new()
		Kind.BOUNCER: return EnemyBrains.Bouncer.new()
		Kind.DRONE: return EnemyBrains.Drone.new()
		Kind.CLEANER: return EnemyBrains.Cleaner.new()
	return null

## Drones fly: they live on the FLYERS layer and only walls stop them.
func _apply_body_layers() -> void:
	if kind == Kind.DRONE:
		collision_layer = Layers.FLYERS
		collision_mask = Layers.WALLS
	else:
		collision_layer = Layers.ENEMIES
		collision_mask = Layers.SOLID | Layers.ENEMIES

func kind_name() -> String:
	return KIND_NAMES.get(kind, "GUARD")

## What stops this guard's eyes and feet (drones see over furniture).
func solid_mask() -> int:
	return brain.solid_mask() if brain else Layers.SOLID

## Sprite is @onready, so archetypes applied before the node is in the tree
## must defer their visual change until _ready().
func _apply_archetype_visual() -> void:
	if sprite == null:
		return
	sprite.modulate = Color.WHITE
	var spec := visual_spec()
	if faction == &"rival":
		# The other crew: street clothes, masks, a green armband.
		spec.merge({"body": SpriteKit.Body.HOODIE if spec.get("body") != SpriteKit.Body.DRONE else spec["body"],
			"head": SpriteKit.Head.BALACLAVA, "color": Color("23302a"), "trim": Palette.NEON_GREEN,
			"hat": Color("121814")}, true)
	kit = SpriteKit.dress(sprite, spec)

## Silhouette first, colour second: every archetype gets its own body, head
## and weapon shape so a room reads at a glance.
func visual_spec() -> Dictionary:
	var S := SpriteKit
	match kind:
		Kind.GRUNT:
			return {"body": S.Body.VEST, "head": S.Head.CAP, "gun": S.Gun.PISTOL, "color": Color("34425e"), "trim": Color("8fa3c7"), "hat": Color("1e2638"), "skin": S.SKIN[1], "acc": ["radio"] if radio_carrier else []}
		Kind.ENFORCER:
			return {"body": S.Body.ARMOR, "head": S.Head.HELMET, "gun": S.Gun.RIFLE, "color": Color("4b4f38"), "trim": Color("c08a3a"), "hat": Color("363a28"), "skin": S.SKIN[2], "acc": ["plates"]}
		Kind.SHOTGUNNER:
			return {"body": S.Body.BULKY, "head": S.Head.BALD, "gun": S.Gun.SHOTGUN, "color": Color("5a3a26"), "trim": Color("d0a040"), "skin": S.SKIN[0]}
		Kind.MARKSMAN:
			return {"body": S.Body.LEAN, "head": S.Head.BERET, "gun": S.Gun.LONG_RIFLE, "color": Color("30465a"), "trim": Color("8cc0ff"), "hat": Color("5a1e22"), "skin": S.SKIN[4]}
		Kind.BRUTE:
			return {"body": S.Body.TANK, "head": S.Head.BALD, "gun": S.Gun.LMG, "color": Color("3e2a44"), "trim": Color("b06ad0"), "skin": S.SKIN[3], "scale": 1.3}
		Kind.SPRINTER:
			return {"body": S.Body.HOODIE, "head": S.Head.HOOD, "gun": S.Gun.SMG, "color": Color("7a2744"), "trim": Color("ff6aa0"), "hat": Color("5a1a30"), "skin": S.SKIN[1]}
		Kind.TURRET:
			return {"body": S.Body.TRIPOD, "gun": S.Gun.LMG, "color": Color("4d5660"), "trim": Palette.DANGER, "scale": 1.1}
		Kind.MEDIC:
			return {"body": S.Body.SUIT, "head": S.Head.HAIR, "gun": S.Gun.PISTOL, "color": Color("d9d6cc"), "trim": Color("ffffff"), "hair": Color("3a2818"), "skin": S.SKIN[0], "acc": ["cross"], "scale": 0.92}
		Kind.RIOT:
			return {"body": S.Body.ARMOR, "head": S.Head.HELMET, "gun": S.Gun.PISTOL, "shield": true, "color": Color("26324a"), "trim": Color("8aa4c0"), "hat": Color("1b2230"), "skin": S.SKIN[2], "scale": 1.08}
		Kind.GRENADIER:
			return {"body": S.Body.BULKY, "head": S.Head.HELMET, "gun": S.Gun.LAUNCHER, "color": Color("4a5230"), "trim": Color("c69a3b"), "hat": Color("3a4024"), "skin": S.SKIN[1], "acc": ["bandolier"]}
		Kind.HANDLER:
			return {"body": S.Body.VEST, "head": S.Head.CAP, "gun": S.Gun.PISTOL, "color": Color("4a3a2a"), "trim": Color("d0a040"), "hat": Color("2a2016"), "skin": S.SKIN[3], "acc": ["leash", "hivis"]}
		Kind.DOG:
			return {"body": S.Body.DOG, "color": Color("4d3b2a"), "trim": Palette.DANGER, "scale": 1.05}
		Kind.TECH:
			return {"body": S.Body.VEST, "head": S.Head.VISOR, "gun": S.Gun.TABLET, "color": Color("2d5a5e"), "trim": Palette.TEAL, "hat": Color("1c2a2c"), "skin": S.SKIN[4], "acc": ["radio"]}
		Kind.SNIPER:
			return {"body": S.Body.LEAN, "head": S.Head.VISOR, "gun": S.Gun.LONG_RIFLE, "color": Color("22252b"), "trim": Palette.DANGER, "hat": Color("15171b"), "visor": Palette.DANGER, "skin": S.SKIN[2], "gun_accent": Palette.DANGER}
		Kind.BOUNCER:
			return {"body": S.Body.BULKY, "head": S.Head.SLICKED, "gun": S.Gun.NONE, "color": Color("18181c"), "trim": Color("e8e8e8"), "hair": Color("0e0e0e"), "skin": S.SKIN[3], "acc": ["glasses", "tie"], "scale": 1.28}
		Kind.DRONE:
			return {"body": S.Body.DRONE, "color": Color("3a3f48"), "eye": Palette.DANGER, "scale": 1.1}
		Kind.CLEANER:
			return {"body": S.Body.ARMOR, "head": S.Head.VISOR, "gun": S.Gun.SMG, "color": Color("121418"), "trim": Color("2e3a40"), "hat": Color("0b0c0e"), "visor": Palette.NEON_CYAN, "skin": S.SKIN[1]}
	return {"body": S.Body.SUIT, "head": S.Head.CAP, "gun": S.Gun.PISTOL, "color": Color("3d4658")}

## Reinforcements are spawned with hunting = true: they always know where you
## are and never idle.
var hunting: bool = false:
	set(value):
		hunting = value
		if value:
			_alert = Alert.HUNTING
			_provoked = true

@onready var sprite: Node2D = $Sprite
@onready var muzzle: Node2D = $Muzzle
var kit: SpriteKit = null

var health: int
var _player: Node2D = null
var _fire_timer: float = 0.0
var _dead: bool = false
var _flash_tween: Tween
var sleeping := false
var wake_until_msec: int = 0
var _director: EnemyDirector = null
var radio_carrier := false
var radio_progress := 0.0
var radio_cooldown := 0.0
const RADIO_TIME := 2.0
## Archetype behaviour plug-in (null for the original eight).
var brain: EnemyBrain = null
var overhead: EnemyOverhead
var _telegraph: Telegraph = null
## Elite state.
var elite := false
var affix: StringName = &""
var armored := false
var shield_hp := 0
var _shield_clock := 0.0
var _haste_clock := 0.0
## Name tag above the head (elites, lieutenants, reinforcements).
var elite_tag := "":
	set(v):
		elite_tag = v
		if overhead:
			overhead.tag = v

func set_sleeping(value: bool) -> void:
	if _dead:
		return
	sleeping = value
	set_physics_process(not value)
	if value:
		velocity = Vector2.ZERO

func wake_for(seconds: float = 2.0) -> void:
	wake_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	set_sleeping(false)

func _exit_tree() -> void:
	if is_instance_valid(_director):
		_director.unregister(self)


var _alert: int = Alert.IDLE
var _post: Vector2 = Vector2.ZERO         # where this guard belongs
var _investigate_target: Vector2 = Vector2.ZERO
var _lose_timer: float = 0.0              # counts down once the player is unseen
var _guard_rect: Rect2 = Rect2()
var _has_guard_rect: bool = false

## SPRINTER dash-cycle state.
var _dashing_in: bool = true
var _dash_timer: float = 0.0

## MEDIC support state.
var _medic_target: Node = null
var _medic_scan_timer: float = 0.0
var _medic_heal_timer: float = 0.0
## Set true once the guard is roused (entered room, heard/took a shot). Only
## then will it chase and open fire. Brains hear about it once.
var _provoked: bool = false:
	set(v):
		if v and not _provoked:
			_provoked = true
			if brain and not _dead:
				brain.on_provoked()
		elif not v:
			_provoked = false

const LOSE_INTEREST_TIME := 4.0

func _ready() -> void:
	overhead = EnemyOverhead.new()
	overhead.tag = elite_tag
	add_child(overhead)
	add_to_group("enemies")                  # ensures bullets can find us
	# Set collision in code so a mis-set enemy.tscn can't let guards walk
	# through walls. Layer 2 = enemies; mask 1 (walls) + 2 (other enemies) so
	# guards physically can't overlap and pile onto one spot. Drones fly.
	_apply_body_layers()
	if health <= 0:
		health = max_health
	_apply_archetype_visual()
	_fire_timer = randf() * fire_rate        # stagger so they don't all fire in sync
	_post = global_position
	# Reinforcements set `hunting` before _ready() runs, so honour it here.
	if hunting:
		_alert = Alert.HUNTING
		_lose_timer = LOSE_INTEREST_TIME
		_provoked = true
	_acquire_player()
	_director = get_tree().get_first_node_in_group("enemy_director") as EnemyDirector
	if _director:
		_director.register(self)
	# Listen for gunshots, deaths, footsteps.
	if has_node("/root/Noise"):
		get_node("/root/Noise").heard.connect(_on_noise)

func _acquire_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

## Guards and rival crews fight each other as well as the player. `_player`
## is whoever this fighter is after right now (normally the player).
var faction: StringName = &"guard"
var _retarget_clock := 0.0
static var _rival_round: PackedScene = null

func _retarget(delta: float) -> void:
	_retarget_clock -= delta
	if _retarget_clock > 0.0:
		return
	_retarget_clock = 0.4
	var host := heist()
	if host == null or (faction == &"guard" and host.rivals_alive() == 0):
		if not (_player is Player):
			_acquire_player()
		return
	var real: Node2D = host.player
	var best: Node2D = real
	var best_d := INF
	if is_instance_valid(real) and not real.is_dead():
		best_d = global_position.distance_to(real.global_position)
	for other in (host.director.neighbours(global_position, sight_range) if host.director else []):
		if other == self or not is_instance_valid(other) or other._dead or other.faction == faction:
			continue
		var d := global_position.distance_to(other.global_position)
		if d < best_d * 0.9:
			best_d = d
			best = other
	if best:
		_player = best

## Rounds that can hit fighters: used when the target is not the player.
func _round_for_target() -> PackedScene:
	if _player is Player or _player == null:
		return enemy_bullet_scene
	if _rival_round == null:
		_rival_round = load("res://bullet.tscn")
	return _rival_round

# --------------------------------------------------------------- hearing ----
func _on_noise(pos: Vector2, radius: float, kind: StringName) -> void:
	if _dead:
		return
	if global_position.distance_to(pos) > radius * hearing_multiplier:
		return
	wake_for()
	if _alert == Alert.HUNTING:
		return
	# A sound in earshot rouses the guard — now sight will make it hunt.
	if kind == &"gunshot" or kind == &"death":
		_provoked = true
	# Sentries never abandon their post — they just face the noise and get
	# twitchy. Patrols go and look.
	if role == Role.SENTRY:
		_alert = Alert.INVESTIGATING
		_investigate_target = _post
		if sprite:
			sprite.rotation = (pos - global_position).angle()
		return
	_alert = Alert.INVESTIGATING
	_investigate_target = pos

# ----------------------------------------------------------------- sight ----
## True if the player is within range AND nothing solid is in the way.
func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_dead") and _player.is_dead():
		return false
	if _player is Enemy and _player._dead:
		return false
	var to_player := _player.global_position - global_position
	if to_player.length() > sight_range:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, _player.global_position)
	query.collision_mask = solid_mask()      # walls and furniture block sight
	query.collide_with_areas = false
	query.exclude = [get_rid(), _player.get_rid()]
	var hit := space.intersect_ray(query)
	# Anything static between us blocks the view.
	return hit.is_empty() or (hit["collider"] is CharacterBody2D)

# ----------------------------------------------------------------- brain ----
func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null or not is_instance_valid(_player):
		_acquire_player()
		return

	if brain:
		brain.tick(delta)
	_tick_elite(delta)
	_retarget(delta)
	if not is_instance_valid(_player):
		return

	# Sight only triggers hunting once the guard is PROVOKED — the player has
	# entered its room, fired a shot it heard, or shot it. Until then a guard
	# that can see the player just watches: no chasing, no shooting. This stops
	# the whole building opening fire the instant you're visible down a hallway.
	var sees := _can_see_player()
	if sees and _provoked:
		if _alert != Alert.HUNTING:
			Audio.play("alert", global_position)
		_alert = Alert.HUNTING
		_lose_timer = LOSE_INTEREST_TIME
	elif _alert == Alert.HUNTING:
		# Lost line of sight: keep pushing to the last known spot for a while.
		_lose_timer -= delta
		if _lose_timer <= 0.0:
			_alert = Alert.INVESTIGATING
			_investigate_target = _player.global_position

	# Being seen while in the player's room counts as provocation on its own.
	if sees and not _provoked and _player_in_my_room():
		_provoked = true
	if _radio_step(delta, sees):
		velocity = Vector2.ZERO
		return

	match _alert:
		Alert.HUNTING:      _do_hunt(delta, sees)
		_:
			if brain and brain.calm(delta):
				pass
			elif _alert == Alert.INVESTIGATING:
				_do_investigate(delta)
			else:
				_do_idle(delta)

	# Gentle separation: push apart from any very close neighbour so groups
	# spread into a loose formation instead of collapsing onto one point.
	velocity += _separation() * move_speed
	move_and_slide()

## Sum of small pushes away from nearby enemies (boids-style separation).
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in (_director.neighbours(global_position) if _director else []):
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector2 = global_position - other.global_position
		var d := away.length()
		if d < 46.0 and d > 0.01:
			push += away.normalized() * (1.0 - d / 46.0)
	return push.limit_length(1.0)

## Steer toward `target` while sliding around walls. Casts three whiskers
## (ahead, and 40 degrees either side); if the direct path is blocked it picks
## the clearest open angle instead of grinding into the wall.
func _steer_toward(target: Vector2, speed: float) -> Vector2:
	var desired := (target - global_position)
	if desired.length() < 1.0:
		return Vector2.ZERO
	desired = desired.normalized()
	if _is_clear(desired, 90.0):
		return desired * speed

	# Blocked ahead: fan out and take the best open direction.
	var best := Vector2.ZERO
	var best_score := -1.0
	for step in [-1, 1]:
		for angle in [0.4, 0.8, 1.3, 2.0]:
			var candidate := desired.rotated(angle * step)
			if not _is_clear(candidate, 80.0):
				continue
			# Prefer directions closest to where we actually want to go.
			var score := candidate.dot(desired)
			if score > best_score:
				best_score = score
				best = candidate
	if best == Vector2.ZERO:
		return Vector2.ZERO
	return best * speed

## True if nothing solid is within `dist` along `dir`.
func _is_clear(dir: Vector2, dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + dir * dist)
	query.collision_mask = solid_mask()
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()

func _do_idle(_delta: float) -> void:
	# Drift back to post if shoved off it, otherwise hold still.
	if global_position.distance_to(_post) > 24.0:
		velocity = _steer_toward(_post, move_speed * 0.5)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

func _do_investigate(delta: float) -> void:
	var to_target := _investigate_target - global_position
	if sprite and to_target.length() > 1.0:
		sprite.rotation = to_target.angle()
	if to_target.length() > 40.0:
		velocity = _steer_toward(_investigate_target, move_speed * 0.8)
	else:
		# Arrived and found nothing — stand down.
		velocity = velocity.lerp(Vector2.ZERO, 0.2)
		_lose_timer -= delta
		if _lose_timer <= 0.0:
			_alert = Alert.IDLE
			_investigate_target = _post

## Move this guard's post (where it stands and returns to).
func set_post(pos: Vector2) -> void:
	_post = pos

## The room this guard belongs to, as a world-space rect. Sentries won't budge
## until the player is actually inside it.
func set_guard_room(rect: Rect2) -> void:
	_guard_rect = rect
	_has_guard_rect = true

## True if the player has entered this sentry's room.
func _player_in_my_room() -> bool:
	if not _has_guard_rect or _player == null:
		return false
	return _guard_rect.has_point(_player.global_position)

func _do_hunt(delta: float, sees: bool) -> void:
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if brain and brain.hunt(delta, sees, to_player, dist):
		return
	if sprite and dist > 1.0:
		sprite.rotation = to_player.angle()

	if kind == Kind.TURRET:
		# Never moves, at all — it's an emplacement, not a guard. Pure line-
		# of-sight threat that punishes a straight-line approach and rewards
		# using cover or flanking around its firing arc.
		velocity = Vector2.ZERO
	elif kind == Kind.SPRINTER:
		_do_sprinter(delta, to_player, dist)
	elif kind == Kind.MEDIC:
		_do_medic(delta, to_player, dist)
	elif role == Role.SENTRY:
		# Sentries are rooted to what they're guarding. They only give chase
		# once the player is in the room with them, and even then they stay
		# close to the post rather than following you across the building.
		if _player_in_my_room() and dist > keep_distance:
			var leash := global_position.distance_to(_post)
			if leash < 260.0:
				velocity = _steer_toward(_player.global_position, move_speed * 0.75)
			else:
				velocity = _steer_toward(_post, move_speed * 0.6)
		elif global_position.distance_to(_post) > 24.0:
			velocity = _steer_toward(_post, move_speed * 0.6)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 0.25)
	elif dist > keep_distance:
		velocity = _steer_toward(_player.global_position, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

	# Only shoot at what you can actually see. Medics hold fire while healing.
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	var may_fire := sees and dist <= fire_range and _fire_timer <= 0.0
	if kind == Kind.MEDIC and _medic_target != null:
		may_fire = false
	if may_fire:
		_fire_timer = fire_rate
		_shoot(to_player.normalized())

## Hit-and-run: closes to point-blank, unloads, then bolts back out to range
## before closing in again. Cycles on _dash_timer so it reads as a rhythm you
## can learn, not random jitter.
func _do_sprinter(delta: float, to_player: Vector2, dist: float) -> void:
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dashing_in = not _dashing_in
		_dash_timer = 1.1 if _dashing_in else 0.9
	if _dashing_in and dist > 50.0:
		velocity = _steer_toward(_player.global_position, move_speed)
	elif not _dashing_in:
		velocity = _steer_toward(
			global_position - to_player.normalized() * 300.0, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.3)

## Stays at range, tags the nearest hurt ally, and RUNS to it to heal — a
## priority kill target: leaving one alive keeps its friends topped up.
func _do_medic(delta: float, to_player: Vector2, dist: float) -> void:
	_medic_scan_timer -= delta
	if _medic_scan_timer <= 0.0:
		_medic_scan_timer = 0.5
		_medic_target = _find_hurt_ally()

	if _medic_target != null and is_instance_valid(_medic_target):
		var to_ally: Vector2 = _medic_target.global_position - global_position
		if to_ally.length() > 60.0:
			velocity = _steer_toward(_medic_target.global_position, move_speed * 1.1)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			_medic_heal_timer -= delta
			if _medic_heal_timer <= 0.0:
				_medic_heal_timer = 1.2
				if _medic_target.has_method("heal"):
					_medic_target.heal(2)
		return

	# No one to heal: keep distance from the player like a marksman would.
	if dist > keep_distance:
		velocity = _steer_toward(_player.global_position, move_speed)
	elif dist < keep_distance * 0.6:
		velocity = _steer_toward(
			global_position - to_player.normalized() * 200.0, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

func _find_hurt_ally() -> Node:
	var best: Node = null
	var best_d := 360.0
	for other in (_director.neighbours(global_position, 360.0) if _director else []):
		if other == self or not is_instance_valid(other):
			continue
		if "health" not in other or "max_health" not in other:
			continue
		if other.health >= other.max_health or other.health <= 0:
			continue
		var d := global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best

func _shoot(dir: Vector2) -> void:
	if enemy_bullet_scene == null:
		return
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.muzzle(global_position + dir * 28.0, dir)
	if kit:
		kit.kick(0.6 + 0.2 * pellets)
	Audio.play("shot_enemy", global_position, 0.0, 1.15 if pellets == 1 else 0.8)
	for i in maxi(pellets, 1):
		var offset := 0.0
		if pellets > 1:
			# Spread the pellets evenly across the cone, plus a little jitter.
			offset = lerpf(-spread, spread, float(i) / float(pellets - 1))
			offset += randf_range(-spread, spread) * 0.25
		elif spread > 0.0:
			offset = randf_range(-spread, spread)
		_fire_bullet(dir.rotated(offset), bullet_damage, bullet_speed, false)
	# Gunfire draws every guard in earshot.
	if has_node("/root/Noise"):
		get_node("/root/Noise").gunshot(global_position)

## One enemy round from the muzzle, pooled when a heist hosts a BulletPool.
func _fire_bullet(dir: Vector2, dmg: int, spd: float, loud := true) -> Node:
	if enemy_bullet_scene == null or not is_inside_tree():
		return null
	var b := BulletPool.take(self, _round_for_target())
	b.damage = dmg
	b.speed = spd
	b.global_position = global_position + dir * 28.0
	b.setup(dir, self)
	if loud and has_node("/root/Noise"):
		get_node("/root/Noise").gunshot(global_position)
	return b

# ---------------------------------------------------------------- damage ----
## Called by a MEDIC on a nearby wounded ally. Small floating "+N" so a heal
## reads clearly — and tells the player their damage just got undone.
func heal(amount: int) -> void:
	if _dead or health <= 0:
		return
	var before := health
	health = mini(health + amount, max_health)
	if health == before:
		return
	if kit:
		var flash := create_tween()
		flash.tween_property(kit, "modulate", Color(0.5, 1.4, 0.6), 0.1)
		flash.tween_property(kit, "modulate", Color.WHITE, 0.25)

func take_damage(amount: int = 1) -> void:
	# queue_free() only frees at end of frame, so without this guard several
	# bullets landing on the same frame would each count as a separate kill.
	if _dead:
		return
	wake_for(3.0)
	# Being shot: you know where it came from and you're now hostile.
	_provoked = true
	_alert = Alert.HUNTING
	_lose_timer = LOSE_INTEREST_TIME
	if shield_hp > 0:
		# The bubble eats the hit and starts its regeneration clock over.
		shield_hp -= 1
		_shield_clock = SHIELD_REGEN
		overhead.bubble = float(shield_hp) / SHIELD_MAX
		Audio.play("deflect", global_position, -2.0)
		return
	# A hit knocks the radio call back; only a kill stops it for good.
	radio_progress = maxf(radio_progress - 0.5, 0.0)
	health -= amount
	if brain:
		brain.on_hurt()
	_flash()
	if health <= 0:
		_die()

## Riot shields stop bullets from the front.
func deflects(dir: Vector2) -> bool:
	return brain != null and not _dead and brain.deflects(dir)

func _flash() -> void:
	if kit:
		kit.flash()

func _die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", true)
	# A body hitting the floor is heard by anyone nearby.
	if has_node("/root/Noise"):
		get_node("/root/Noise").death(global_position)
	if kit and get_parent():
		SpriteKit.drop_corpse(get_parent(), global_position, sprite.global_rotation if sprite else 0.0, kit.spec)
	Audio.play("death_enemy" if kind != Kind.DRONE else "impact_wall", global_position)
	if brain:
		brain.on_death()
	var host := heist()
	if host:
		if affix == &"volatile":
			Blast.fuse(host, global_position, 0.6, 95.0, 2, 3, true)
		if elite:
			host.drop_loot(global_position, randi_range(35, 70) * (1 + host.stage_index()))
	died.emit(self)
	queue_free()

## A radio carrier who starts hunting calls it in: a radio icon and a 2 s bar
## over his head. Kill him before it fills and the heat never happens; hits
## only knock the bar back.
func _radio_step(delta: float, sees: bool) -> bool:
	if not radio_carrier or hunting:
		overhead.radio_icon = false
		overhead.radio = 0.0
		return false
	radio_cooldown = maxf(0.0, radio_cooldown - delta)
	overhead.radio_icon = radio_cooldown <= 0.0
	if not sees or not _provoked or radio_cooldown > 0.0:
		radio_progress = 0.0
		overhead.radio = 0.0
		return false
	if radio_progress == 0.0:
		Audio.play("radio", global_position)
	radio_progress += delta
	overhead.radio = minf(1.0, radio_progress / RADIO_TIME)
	if radio_progress >= RADIO_TIME:
		radio_progress = 0.0
		radio_cooldown = 12.0
		overhead.radio = 0.0
		Audio.play("radio", global_position, 0.0, 0.8)
		var host := heist()
		if host:
			host.security_alert(get_parent(), "Guard radio call", 10.0)
	return true

# ------------------------------------------------------------ brain help ----
func heist() -> HeistFloor:
	if not is_inside_tree():
		return null
	return get_tree().current_scene as HeistFloor

## This guard's warning-shape canvas (lasers, lanes), created on first use.
func telegraph() -> Telegraph:
	if _telegraph == null:
		_telegraph = Telegraph.new()
		add_child(_telegraph)
	return _telegraph

func telegraph_clear() -> void:
	if _telegraph:
		_telegraph.clear()

## Where a ray from `from` along `dir` first meets a wall (or `length` away).
func ray_end(from: Vector2, dir: Vector2, length: float) -> Vector2:
	var to := from + dir * length
	var query := PhysicsRayQueryParameters2D.create(from, to, solid_mask())
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else to

## Close-quarters hit on the player: damage, optional slow, shove.
func melee(dmg: int, dir: Vector2, slow: float, slow_time: float, knock: float) -> void:
	var p := _player as Player
	if p == null or p.is_dead():
		return
	var before := p.hits_taken
	p.last_hit_dir = dir
	p.take_damage(dmg + (1 if affix == &"veteran" else 0))
	if p.hits_taken == before:
		return                    # dodged, or mercy frames
	if slow > 0.0:
		p.apply_slow(slow, slow_time)
	if knock > 0.0:
		p.shove(dir * knock)

## Hold a band of distance from the player: back off inside `near`, close in
## beyond `far`, otherwise settle.
func keep_range(to_player: Vector2, dist: float, near: float, far: float) -> void:
	if dist < near:
		velocity = _steer_toward(global_position - to_player.normalized() * 200.0, move_speed)
	elif dist > far:
		velocity = _steer_toward(_player.global_position, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

func throw_grenade(target: Vector2) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var g := Grenade.new()
	g.from = global_position
	g.to = target
	g.player_damage = bullet_damage
	host.add_child(g)
	if kit:
		kit.kick(1.0)

# ----------------------------------------------------------------- elites ---
## Promote to an elite: +50% health, the affix's twist, a glow, a name tag and
## a valuable on death.
func make_elite(a: StringName) -> void:
	if a == &"" or elite:
		return
	elite = true
	affix = a
	max_health = int(ceil(max_health * 1.5))
	match a:
		&"armored":
			armored = true
			max_health *= 2
		&"hasted":
			move_speed *= 1.4
			fire_rate *= 0.7
		&"shielded":
			shield_hp = SHIELD_MAX
		&"veteran":
			bullet_damage += 1
	health = max_health
	elite_tag = "%s %s" % [String(a).to_upper(), kind_name()]
	if overhead:
		overhead.tag_color = AFFIX_COLORS.get(a, Palette.GOLD)
		overhead.bubble = 1.0 if shield_hp > 0 else 0.0
	material = StreetArt._unshaded()
	queue_redraw()

## A named elite who runs an ordinary job's boss room: double an elite's
## health, bigger, with his name over his head.
var lieutenant := false

func make_lieutenant(title: String) -> void:
	if not elite:
		make_elite(AFFIXES[randi() % AFFIXES.size()])
	lieutenant = true
	max_health *= 2
	health = max_health
	elite_tag = title
	if overhead:
		overhead.tag_color = Palette.GOLD
	if sprite:
		sprite.scale *= 1.2

func _tick_elite(delta: float) -> void:
	if not elite:
		return
	if affix == &"shielded" and shield_hp < SHIELD_MAX:
		_shield_clock -= delta
		if _shield_clock <= 0.0:
			shield_hp = SHIELD_MAX
			overhead.bubble = 1.0
			Audio.play("cloak", global_position, -8.0, 1.6)
	elif affix == &"hasted" and velocity.length() > 60.0 and kit and not Settings.values["low_effects"]:
		_haste_clock -= delta
		if _haste_clock <= 0.0:
			_haste_clock = 0.09
			_afterimage()

func _afterimage() -> void:
	var host := get_parent()
	if host == null:
		return
	var ghost := Node2D.new()
	ghost.global_position = global_position
	ghost.rotation = sprite.global_rotation
	ghost.z_index = 3
	host.add_child(ghost)
	var copy := SpriteKit.new()
	copy.apply(kit.spec)
	copy.modulate = Palette.with_alpha(AFFIX_COLORS[&"hasted"], 0.4)
	ghost.add_child(copy)
	copy.set_process(false)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)

## Elite glow on the floor under the guard.
func _draw() -> void:
	if not elite:
		return
	var col: Color = AFFIX_COLORS.get(affix, Palette.GOLD)
	draw_circle(Vector2(0, 4), 30.0, Palette.with_alpha(col, 0.12))
	draw_arc(Vector2(0, 4), 26.0, 0.0, TAU, 32, Palette.with_alpha(col, 0.55), 2.0, true)
