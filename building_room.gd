extends Node2D
class_name BuildingRoom

## A spatial room in a building floor: has a defined rect, walls, doors, and
## enemy spawn markers. Spawns its enemies when activated, tracks clear state.
## Works with RoomManager. This replaces the abstract Room for the door-based
## building layout.
##
## Scene layout (children):
##   Walls        (StaticBody2D with the room's wall collision)
##   SpawnPoints  (Node2D holding Marker2D children)
##   Door(s)      (Door.gd) placed in the wall openings
##   DoorEntries  (Node2D with Marker2D children named by side: North/South/East/West)

signal cleared()

@export var id: StringName = &"room"
@export var is_start_room: bool = false
@export var room_size: Vector2 = Vector2(800, 600)   # for camera framing
@export var enemy_scene: PackedScene
@export var spawn_count: int = 4
@export var rarity: int = 0                          # RoomRarity index

@onready var spawn_points: Node2D = get_node_or_null("SpawnPoints")
@onready var door_entries: Node2D = get_node_or_null("DoorEntries")

## Local rects occupied by furniture (PropPlacer fills this). Spawns and loot
## keep out of them.
var blocked_rects: Array = []

var _alive: int = 0
var _cleared: bool = false
var _activated: bool = false

func room_id() -> StringName:
	return id

func is_start() -> bool:
	return is_start_room

func is_cleared() -> bool:
	return _cleared

func enemies_alive() -> int:
	return _alive

func center_position() -> Vector2:
	return global_position + room_size * 0.5

## Spawn enemies + begin combat. Called by RoomManager when the player enters.
func activate() -> void:
	if _activated:
		return
	_activated = true
	if _cleared:
		return
	var markers := _markers()
	var used: Array = []
	for i in spawn_count:
		if enemy_scene == null:
			break
		var e := enemy_scene.instantiate()
		e.position = room_size * 0.5 if has_meta("is_boss") else _spawn_slot(i, markers, used)
		add_child(e)
		used.append(e.position)
		if e.has_signal("died"):
			e.died.connect(_on_enemy_died)
		_alive += 1
	if _alive == 0:
		_mark_cleared()

## A spawn position that never coincides with another enemy. Tries the marker,
## then jitters progressively harder, and as a last resort scatters in the room.
## Guarantees a minimum separation so two enemies can't share an x/y.
func _spawn_slot(index: int, markers: Array, used: Array) -> Vector2:
	const MIN_SEP := 60.0
	var base: Vector2
	if index < markers.size():
		base = markers[index].position
	elif markers.size() > 0:
		base = markers[index % markers.size()].position
	else:
		base = Vector2(room_size.x * 0.5, room_size.y * 0.5)

	for attempt in 24:
		var candidate: Vector2
		if attempt == 0 and index < markers.size():
			candidate = base            # first try the exact marker
		else:
			# Grow the jitter each attempt so we always eventually find space.
			var spread := 40.0 + attempt * 22.0
			candidate = base + Vector2(
				randf_range(-spread, spread), randf_range(-spread, spread))
		candidate.x = clampf(candidate.x, 70.0, room_size.x - 70.0)
		candidate.y = clampf(candidate.y, 70.0, room_size.y - 70.0)

		var clear := true
		for p: Vector2 in used:
			if candidate.distance_to(p) < MIN_SEP:
				clear = false
				break
		for r: Rect2 in blocked_rects:
			if r.grow(18).has_point(candidate):
				clear = false
				break
		if clear:
			return candidate

	# Extremely unlikely fallback: shove far from everything we can.
	return Vector2(
		randf_range(70.0, room_size.x - 70.0),
		randf_range(70.0, room_size.y - 70.0))

func _markers() -> Array:
	var out := []
	if spawn_points:
		for c in spawn_points.get_children():
			if c is Marker2D:
				out.append(c)
	return out

## Take in a guard that arrives later (a handler's dog, a tech's drone): the
## room is not clear until it falls too.
func adopt(e: Node) -> void:
	add_child(e)
	if e.has_signal("died"):
		e.died.connect(_on_enemy_died)
	_alive += 1

func _on_enemy_died(_e) -> void:
	_alive -= 1
	if _alive <= 0 and not _cleared:
		_mark_cleared()

func _mark_cleared() -> void:
	_cleared = true
	cleared.emit()

## Where to place the player when they enter through a door on `side`.
func door_entry_position(side: int) -> Vector2:
	if door_entries:
		var names := ["North", "South", "East", "West"]
		var marker := door_entries.get_node_or_null(names[side])
		if marker:
			return marker.global_position
	return center_position()
