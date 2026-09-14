extends Node
class_name HeistController

## Runs one full heist: sequences its rooms, tracks run-wide stats (kills, time,
## and reads the player's hit/accuracy counters), then grades the whole heist and
## applies the stock delta + hands back the loot tier when the last room clears.

signal heist_finished(result: Dictionary)
signal room_started(index: int, total: int)

@export var player_path: NodePath            # points at the Player node
@export var par_time: float = 90.0           # target time for full speed marks
@export var venue_asset_id: StringName = &"" # which stock this heist moves

var _rooms: Array[Room] = []
var _index: int = -1
var _total_kills: int = 0
var _enemies_total: int = 0
var _start_time: float = 0.0
var _player: Player = null
var _market: CriminalMarket = null           # optional; set to move the stock

## Call once with the ordered list of Room nodes for this heist.
func setup(rooms: Array[Room], player: Player, market: CriminalMarket = null) -> void:
	_rooms = rooms
	_player = player
	_market = market
	_total_kills = 0
	_enemies_total = 0
	for r in _rooms:
		_enemies_total += r.enemy_total()
		r.auto_start = false                 # controller drives spawning
		r.room_cleared.connect(_on_room_cleared)
		r.enemy_killed.connect(_on_enemy_killed)
	_start_time = Time.get_ticks_msec() / 1000.0
	_index = -1
	_next_room()

func _next_room() -> void:
	_index += 1
	if _index >= _rooms.size():
		_finish()
		return
	room_started.emit(_index, _rooms.size())
	_rooms[_index].start()

func _on_room_cleared(_room) -> void:
	_next_room()

func _on_enemy_killed(_room_kills: int) -> void:
	_total_kills += 1

func _finish() -> void:
	var elapsed := (Time.get_ticks_msec() / 1000.0) - _start_time
	var stats := {
		"hits_taken": _player.hits_taken if _player else 0,
		"shots_fired": _player.shots_fired if _player else 0,
		"shots_hit": _player.shots_hit if _player else 0,
		"kills": _total_kills,
		"enemies_total": _enemies_total,
		"time_seconds": elapsed,
		"par_time": par_time,
	}
	var result := HeistGrader.grade_heist(stats)

	# Apply the grade's stock delta to the venue's asset, if wired.
	if _market and venue_asset_id != &"":
		var asset := _market.get_asset(venue_asset_id)
		if asset:
			asset.current_price = max(asset.current_price * result["stock_delta"], 0.01)

	result["stats"] = stats
	heist_finished.emit(result)
