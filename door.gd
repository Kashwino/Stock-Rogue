extends Area2D
class_name Door

## A door in a wall between two rooms. Locked (closed) while the current room
## has live enemies; opens when the room is cleared. Walking into an open door
## triggers a transition to the linked room via the RoomManager.
##
## Set `to_room` to the target room's node path (or the RoomManager resolves it).
## `side` is which wall this door sits on (for camera pan direction).

signal player_entered_door(door: Door)

enum DoorSide { NORTH, SOUTH, EAST, WEST }

@export var side: DoorSide = DoorSide.NORTH
@export var to_room_id: StringName = &""     # id of the room this leads to
@export var locked: bool = true

@onready var sprite = get_node_or_null("Sprite")   # visual (ColorRect or Sprite2D)
@onready var block: StaticBody2D = get_node_or_null("Block")  # blocks passage when locked

var _player_here: bool = false
var _fired: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()
	_apply_block()

func _process(_delta: float) -> void:
	# Continuously check overlap. The Block sitting in the doorway interferes with
	# clean enter/exit events, so poll instead: fire once when open + player inside.
	if locked:
		_fired = false
		return
	if _player_here or _player_overlapping():
		if not _fired:
			_fired = true
			player_entered_door.emit(self)

func _player_overlapping() -> bool:
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false

func lock() -> void:
	locked = true
	_fired = false
	_apply_block()
	_refresh_visual()

func unlock() -> void:
	locked = false
	_apply_block()
	_refresh_visual()

## Enable/disable the Block's collision shape(s). Deferred so it's safe to call
## during a physics callback (e.g. from a bullet-hit -> room-clear chain).
func _apply_block() -> void:
	if block == null:
		return
	for c in block.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", not locked)   # locked = solid, unlocked = passable

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_here = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_here = false

func _refresh_visual() -> void:
	if sprite and sprite is CanvasItem:
		sprite.modulate = Color(0.6, 0.3, 0.3) if locked else Color(0.4, 0.9, 0.5)

## Opposite side, for placing the player at the matching door in the next room.
func opposite_side() -> DoorSide:
	match side:
		DoorSide.NORTH: return DoorSide.SOUTH
		DoorSide.SOUTH: return DoorSide.NORTH
		DoorSide.EAST:  return DoorSide.WEST
		DoorSide.WEST:  return DoorSide.EAST
	return DoorSide.NORTH
