extends Node2D
class_name BulletPool
## Recycles bullets instead of instancing and freeing one per shot. The heist
## owns one pool; spent rounds park themselves here (hidden, not processing,
## not monitoring) and the next shot revives one. Outside a heist, take()
## falls back to a plain instance on the current scene.

const CAP_PER_SCENE := 200
var _idle: Dictionary = {}        # scene path -> Array of parked bullets
var created := 0

func _ready() -> void:
	add_to_group("bullet_pool")
	z_index = 6

## A ready-to-fire bullet of `scene`. Set damage/speed, position, then setup().
static func take(from: Node, scene: PackedScene) -> Node:
	var pool := from.get_tree().get_first_node_in_group("bullet_pool") as BulletPool
	if pool == null:
		var b := scene.instantiate()
		from.get_tree().current_scene.add_child(b)
		return b
	return pool._take(scene)

func _take(scene: PackedScene) -> Node:
	var key := scene.resource_path
	var stack: Array = _idle.get(key, [])
	while not stack.is_empty():
		var b: Node = stack.pop_back()
		if is_instance_valid(b):
			b.revive()
			return b
	var fresh := scene.instantiate()
	fresh.set_meta("pool_key", key)
	fresh.pool = self
	add_child(fresh)
	created += 1
	return fresh

## Called by a spent bullet.
func park(b: Node) -> void:
	var key: String = b.get_meta("pool_key", "")
	if not _idle.has(key):
		_idle[key] = []
	var stack: Array = _idle[key]
	if stack.size() >= CAP_PER_SCENE:
		b.queue_free()
		return
	stack.append(b)

func idle_count() -> int:
	var n := 0
	for stack: Array in _idle.values():
		n += stack.size()
	return n
