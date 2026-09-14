extends Node
class_name EnemyDirector
## A 5 Hz manager handles distance activation and local separation buckets.
const WAKE_DISTANCE := 1100.0
const SLEEP_DISTANCE := 1500.0
const CELL_SIZE := 96.0
var enemies: Array[Enemy] = []
var buckets: Dictionary = {}
var _timer := 0.0
var active_count := 0

func _ready() -> void:
	add_to_group("enemy_director")

func register(enemy: Enemy) -> void:
	if enemy not in enemies:
		enemies.append(enemy)

func unregister(enemy: Enemy) -> void:
	enemies.erase(enemy)

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.2
	refresh()

func refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	buckets.clear()
	active_count = 0
	var now := Time.get_ticks_msec()
	for enemy: Enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead:
			continue
		var distance := enemy.global_position.distance_squared_to(player.global_position)
		var limit := WAKE_DISTANCE if enemy.sleeping else SLEEP_DISTANCE
		var awake := enemy.hunting or now < enemy.wake_until_msec or distance <= limit * limit
		enemy.set_sleeping(not awake)
		if not awake:
			continue
		active_count += 1
		var cell := Vector2i((enemy.global_position / CELL_SIZE).floor())
		if not buckets.has(cell):
			buckets[cell] = []
		buckets[cell].append(enemy)

func neighbours(position: Vector2, radius: float = CELL_SIZE) -> Array:
	var cell := Vector2i((position / CELL_SIZE).floor())
	var out: Array = []
	var extent := ceili(radius / CELL_SIZE)
	for x in range(-extent, extent + 1):
		for y in range(-extent, extent + 1):
			out.append_array(buckets.get(cell + Vector2i(x, y), []))
	return out
