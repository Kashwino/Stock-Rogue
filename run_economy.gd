extends Node
## Autoload this file as "RunEconomy" (Project Settings > Autoload).
## No class_name — the autoload registration provides the global name.
##
## GOLD (separate from grade):
##   UP:   on room clear only, a lump scaled by room rarity (+ lucky bonus).
##   DOWN: per hit taken, gentle escalating ramp that RESETS each room.
## Spent in the shop. (Per-kill gold was removed by design.)

signal gold_changed(amount: int)

@export var starting_gold: int = 250
@export var lucky_room_bonus: int = 40

# --- Per-hit penalty ramp (steep; resets when a room's crew is wiped) ---
## Taking damage is the single worst thing you can do: it crashes the venue
## stock AND drains gold on an accelerating curve. One hit is survivable;
## four hits in the same room costs ~192g, more than most rooms ever pay out.
@export var base_hit_penalty: int = 30
@export var hit_penalty_step: int = 12       # each successive hit costs this much more
var _hits_this_room: int = 0

var gold: int = 0

func _ready() -> void:
	gold = starting_gold
	gold_changed.emit(gold)

func reset() -> void:
	gold = starting_gold
	_hits_this_room = 0
	gold_changed.emit(gold)

# --- Called at the start of each room to reset the ramp ---
func on_room_start() -> void:
	_hits_this_room = 0

# --- Gains (room clear only) ---
## Award a clear reward (already rolled within the room's rarity range).
func award_clear(amount: int) -> void:
	_add(_legend(amount))

func on_lucky_room() -> void:
	_add(lucky_room_bonus)

func add_bonus(amount: int) -> void:
	_add(_legend(amount))

## The Legend doubles every gold gain.
func _legend(amount: int) -> int:
	if amount > 0 and RunState.character_profile and RunState.character_profile.gain_mult != 1.0:
		return roundi(amount * RunState.character_profile.gain_mult)
	return amount

# --- Losses ---
## Gentle escalating penalty: base, base+step, base+2*step, ... within a room.
## e.g. 25, 31, 37, 43 with step 6. Resets when on_room_start() is called.
func on_player_hit(hits: int = 1) -> void:
	for i in hits:
		var penalty := base_hit_penalty + _hits_this_room * hit_penalty_step
		_add(-penalty)
		_hits_this_room += 1

# --- Shop ---
func can_afford(cost: int) -> bool:
	return gold >= cost

func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	_add(-cost)
	return true

func _add(delta: int) -> void:
	gold = maxi(gold + delta, 0)
	gold_changed.emit(gold)
