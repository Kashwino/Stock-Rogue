extends Node2D
class_name RoomManager

## Manages a building floor of rooms connected by doors. For the first test it
## handles 2+ rooms: activates the room the player is in, locks its doors until
## cleared, then unlocks. Walking through an open door pans the camera to the
## linked room and activates it.
##
## Each room is a Node2D (a "BuildingRoom") with:
##   - an id (StringName, set via metadata or node name)
##   - Door children (Door.gd)
##   - enemy spawn markers + a way to spawn/track enemies
##   - a defined rect (for the camera framing)

signal floor_cleared()

@export var player_path: NodePath
@export var camera_path: NodePath
@export var pan_time: float = 0.4

var _player: Node2D
var _camera: Camera2D
var _rooms: Dictionary = {}          # id -> room node
var _active_room = null
var _transitioning: bool = false

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_camera = get_node_or_null(camera_path)
	_collect_rooms()
	# Activate the room the player starts in (first room found, or one tagged start).
	var start = _find_start_room()
	if start:
		_enter_room(start, null)

func _collect_rooms() -> void:
	for child in get_children():
		if child.has_method("room_id"):
			_rooms[child.room_id()] = child
			# Connect each room's doors.
			for door in _doors_of(child):
				door.player_entered_door.connect(_on_door_entered)
			# Listen for the room being cleared.
			if child.has_signal("cleared"):
				child.cleared.connect(_on_room_cleared.bind(child))

func _find_start_room():
	for id in _rooms.keys():
		var r = _rooms[id]
		if r.has_method("is_start") and r.is_start():
			return r
	# Fallback: first room.
	return _rooms.values()[0] if _rooms.size() > 0 else null

func _doors_of(room) -> Array:
	var out := []
	for c in room.get_children():
		if c is Door:
			out.append(c)
	return out

# --- Entering / activating a room ---
func _enter_room(room, from_door) -> void:
	_active_room = room

	# Frame the camera on this room.
	if _camera and room.has_method("center_position"):
		_pan_camera_to(room.center_position())

	# Activate the room (spawn/enable its enemies).
	if room.has_method("activate"):
		room.activate()

	# Lock doors if there are enemies; otherwise leave open.
	_update_doors(room)

func _update_doors(room) -> void:
	var has_enemies := false
	if room.has_method("enemies_alive"):
		has_enemies = room.enemies_alive() > 0
	for door in _doors_of(room):
		if has_enemies:
			door.lock()
		else:
			door.unlock()

func _on_room_cleared(room) -> void:
	if room == _active_room:
		# Open the doors so the player can proceed.
		for door in _doors_of(room):
			door.unlock()
		if _all_rooms_cleared():
			floor_cleared.emit()

func _all_rooms_cleared() -> bool:
	for id in _rooms.keys():
		var r = _rooms[id]
		if r.has_method("is_cleared") and not r.is_cleared():
			return false
	return true

# --- Door transition ---
func _on_door_entered(door: Door) -> void:
	if _transitioning:
		return
	var target = _rooms.get(door.to_room_id)
	if target == null:
		return
	_transitioning = true

	# Move the player to the matching door in the target room.
	if target.has_method("door_entry_position"):
		_player.global_position = target.door_entry_position(door.opposite_side())

	_enter_room(target, door)
	await get_tree().create_timer(pan_time).timeout
	_transitioning = false

func _pan_camera_to(pos: Vector2) -> void:
	if _camera == null:
		return
	var t := create_tween()
	t.tween_property(_camera, "global_position", pos, pan_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
