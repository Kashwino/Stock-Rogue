extends Node
class_name HeistSequencer

## Runs a multi-room heist by REUSING one Room node: configure -> start -> on
## clear, reconfigure for the next room -> repeat until the last, then finish.
## Seeded: room count, miniboss location, and each room's spawn derive from the
## run seed + heist index, so a resumed run plays identically.

signal room_changed(index: int, total: int, is_miniboss: bool)
signal heist_complete()

# Rooms per stage (Town starts at 10, escalating).
const ROOMS_PER_STAGE := {
	0: 10,   # Town
	1: 12,   # City
	2: 14,   # World
	3: 16,   # Doomsday
}

var _room: Room = null
var _rarity: int = 0
var _total_rooms: int = 10
var _miniboss_room: int = -1           # index that hides the miniboss
var _current: int = 0
var _rng := RandomNumberGenerator.new()

## Configure the heist. `start_at_room` lets a resumed run jump back in.
func setup(room: Room, stage: int, rarity: int, run_seed: int, heist_index: int,
		start_at_room: int = 0) -> void:
	_room = room
	_rarity = rarity
	_total_rooms = ROOMS_PER_STAGE.get(stage, 10)

	# Seed deterministically from run seed + which heist this is.
	_rng.seed = hash(str(run_seed) + "_" + str(heist_index))

	# Pick a hidden miniboss room (not the first, so it's a mid/late surprise).
	# ~70% of heists have one.
	if _rng.randf() < 0.7:
		_miniboss_room = _rng.randi_range(2, _total_rooms - 1)
	else:
		_miniboss_room = -1

	_room.auto_start = false
	_room.room_cleared.connect(_on_room_cleared)

	_current = start_at_room
	_start_current_room()

func _start_current_room() -> void:
	var is_miniboss := (_current == _miniboss_room)
	# Configure the room for this step.
	if is_miniboss:
		_room.rarity = Room.RoomRarity.ELITE      # miniboss = elite-tier fight
	else:
		_room.rarity = _rarity
	# Vary spawn count a little per room, seeded.
	_room.spawn_count = 3 + _rng.randi_range(0, 3)

	room_changed.emit(_current, _total_rooms, is_miniboss)
	# Boundary save happens in the arena via this signal.
	_room.start()

func _on_room_cleared(_r) -> void:
	_current += 1
	if _current >= _total_rooms:
		heist_complete.emit()
	else:
		_start_current_room()

func current_room() -> int:
	return _current

func total_rooms() -> int:
	return _total_rooms

func is_miniboss_room() -> bool:
	return _current == _miniboss_room
