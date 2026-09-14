extends Node2D
class_name Room

## One combat room with a RARITY that sets its gold-on-clear range.
## Chest rooms have no enemies and give no clear gold (their reward is loot).
## Gold is awarded ONLY on clear, random within the tier's [min,max]. A lucky
## room adds a bonus on top.

signal room_cleared(room: Room)
signal enemy_killed(total_kills: int)

enum RoomRarity { COMMON, UNCOMMON, RARE, PUMPED, ELITE, CHEST, BOSS }

@export var rarity: RoomRarity = RoomRarity.COMMON
@export var enemy_scene: PackedScene          # assign Enemy.tscn
@export var spawn_count: int = 4
@export var is_lucky: bool = false            # lucky rooms pay a bonus on clear
@export var auto_start: bool = true           # spawn on ready (for testing)

## For PUMPED rooms: multiply enemy health/damage to make "strong normal" enemies.
@export var pumped_multiplier: float = 1.6

@onready var spawn_points: Node2D = $SpawnPoints

## Optional live stock driver, set by the heist setup. If null, stock calls skip.
var live_stock: LiveStock = null

var _alive_enemies: int = 0
var _kills: int = 0
var _cleared: bool = false

# Gold drop per rarity: [chance 0..1, min, max].
# Gold is SCARCE — most common rooms drop nothing. Chance AND amount scale
# with rarity, so real gold comes from pushing into danger.
const GOLD_DROPS := {
	RoomRarity.COMMON:   [0.10, 10, 25],
	RoomRarity.UNCOMMON: [0.25, 20, 40],
	RoomRarity.RARE:     [0.50, 40, 80],
	RoomRarity.PUMPED:   [0.65, 70, 120],
	RoomRarity.ELITE:    [0.90, 120, 200],
	RoomRarity.CHEST:    [0.0, 0, 0],
	RoomRarity.BOSS:     [1.0, 300, 500],
}

func _ready() -> void:
	if auto_start:
		start()

func start() -> void:
	_cleared = false
	_kills = 0
	_alive_enemies = 0
	RunEconomy.on_room_start()               # reset the escalating hit penalty

	# Chest rooms: no enemies. Clear immediately (loot handled elsewhere).
	if rarity == RoomRarity.CHEST:
		_clear()
		return

	var markers := _get_markers()
	for i in spawn_count:
		var e := enemy_scene.instantiate()
		add_child(e)
		if markers.size() > 0:
			e.global_position = markers[i % markers.size()].global_position
		_apply_rarity_to_enemy(e)
		e.died.connect(_on_enemy_died)
		_alive_enemies += 1

func _apply_rarity_to_enemy(e) -> void:
	# Strengthen enemies in Pumped/Elite/Boss rooms.
	match rarity:
		RoomRarity.PUMPED:
			if "max_health" in e:
				e.max_health = int(round(e.max_health * pumped_multiplier))
		RoomRarity.ELITE, RoomRarity.BOSS:
			if "max_health" in e:
				e.max_health = int(round(e.max_health * 2.5))
			if "move_speed" in e:
				e.move_speed *= 0.9
		_:
			pass

func _get_markers() -> Array:
	if spawn_points == null:
		return []
	var out := []
	for c in spawn_points.get_children():
		if c is Marker2D:
			out.append(c)
	return out

func _on_enemy_died(enemy) -> void:
	_alive_enemies -= 1
	_kills += 1
	# Stock still pumps on kills (that's the grade/stock channel, not gold).
	if live_stock:
		live_stock.report_kill()
	enemy_killed.emit(_kills)
	if _alive_enemies <= 0 and not _cleared:
		_clear()

func _clear() -> void:
	_cleared = true
	# Gold is awarded ONLY here, and only if the rarity's drop roll succeeds.
	var drop: Array = GOLD_DROPS.get(rarity, [0.0, 0, 0])
	var chance: float = drop[0]
	if chance > 0.0 and randf() < chance:
		var reward := randi_range(int(drop[1]), int(drop[2]))
		RunEconomy.award_clear(reward)
	if is_lucky:
		RunEconomy.on_lucky_room()
	room_cleared.emit(self)

func kills() -> int:
	return _kills

func enemy_total() -> int:
	return 0 if rarity == RoomRarity.CHEST else spawn_count

func rarity_name() -> String:
	return RoomRarity.keys()[rarity].capitalize()
