extends Node
class_name Loadout

## Manages the player's weapons: 2 big slots + 1 small slot. Handles equipping
## claimed weapons, swapping the active weapon, and per-weapon ammo tracking.
##
## Ammo is tracked per equipped weapon instance (mag + reserve), so scavenging
## can top up reserves by ammo_type later.

signal active_changed(weapon: WeaponItem, mag: int, reserve: int)
signal loadout_changed()
signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished()

## True while a reload is in progress; firing is blocked.
var reloading: bool = false
var _reload_remaining := 0.0
var _reload_key := ""
var _reload_weapon: WeaponItem

const BIG_SLOTS := 2
const SMALL_SLOTS := 1

# Slot arrays hold WeaponItem or null.
var big: Array = [null, null]
var small: Array = [null]

# Ammo state per slot, keyed by a slot tag -> {mag, reserve}.
var _ammo: Dictionary = {}

# Which weapon is active: ["big", 0] / ["big", 1] / ["small", 0].
var active_slot: Array = ["small", 0]

func _ready() -> void:
	# Give the player a default sidearm in the small slot if empty.
	set_process(false)

## Equip a weapon into the correct slot type. Returns the slot it went to,
## or empty array if no free slot (caller can prompt a swap/drop).
func equip(weapon: WeaponItem) -> Array:
	cancel_reload()
	if weapon.slot == WeaponItem.Slot.BIG:
		return _equip_into("big", big, BIG_SLOTS, weapon)
	else:
		return _equip_into("small", small, SMALL_SLOTS, weapon)

func _equip_into(tag: String, arr: Array, count: int, weapon: WeaponItem) -> Array:
	# First free slot.
	for i in count:
		if arr[i] == null:
			arr[i] = weapon
			_init_ammo(tag, i, weapon)
			loadout_changed.emit()
			set_active(tag, i)
			return [tag, i]
	# No free slot: replace the currently active one if it matches this type.
	if active_slot[0] == tag:
		var idx: int = active_slot[1]
		arr[idx] = weapon
		_init_ammo(tag, idx, weapon)
		loadout_changed.emit()
		set_active(tag, idx)
		return [tag, idx]
	# Otherwise replace slot 0.
	arr[0] = weapon
	_init_ammo(tag, 0, weapon)
	loadout_changed.emit()
	set_active(tag, 0)
	return [tag, 0]

func _init_ammo(tag: String, idx: int, weapon: WeaponItem) -> void:
	var key := tag + str(idx)
	if weapon.uses_ammo:
		# Start fully stocked up to the weapon's max reserve, not a fixed
		# mag_size*2 -- otherwise bumping max_reserve (e.g. for a "5x more
		# ammo" balance pass) wouldn't change what you actually start with.
		_ammo[key] = {"mag": weapon.mag_size, "reserve": weapon.max_reserve}
	else:
		# "Infinite ammo" now means an infinite RESERVE, not an infinite mag.
		# The weapon still fires from a magazine that empties and must be
		# reloaded — that's what makes the starter's reload meaningful.
		_ammo[key] = {"mag": weapon.mag_size, "reserve": -1}

## Set the active weapon by slot.
func set_active(tag: String, idx: int) -> void:
	cancel_reload()
	active_slot = [tag, idx]
	var w := get_active()
	var a := _active_ammo()
	if w:
		active_changed.emit(w, a["mag"], a["reserve"])

## Cycle to the next equipped weapon (for a swap key).
func cycle() -> void:
	var order := [["big", 0], ["big", 1], ["small", 0]]
	var start := order.find(active_slot)
	for step in range(1, order.size() + 1):
		var cand: Array = order[(start + step) % order.size()]
		var arr: Array = big if cand[0] == "big" else small
		if arr[cand[1]] != null:
			set_active(cand[0], cand[1])
			return

func get_active() -> WeaponItem:
	var arr: Array = big if active_slot[0] == "big" else small
	return arr[active_slot[1]]

func _active_ammo() -> Dictionary:
	var key: String = active_slot[0] + str(active_slot[1])
	return _ammo.get(key, {"mag": -1, "reserve": -1})

## Returns true if the active weapon can fire (has ammo, not mid-reload).
func can_fire() -> bool:
	if reloading:
		return false
	var a := _active_ammo()
	return a["mag"] > 0

## Consume one round from the active weapon's mag. Returns true if fired.
## Every weapon now fires from a magazine, including infinite ones — the only
## difference is the reserve (-1 = bottomless).
func consume_round() -> bool:
	if reloading:
		return false
	var w := get_active()
	if w == null:
		return false
	var key: String = active_slot[0] + str(active_slot[1])
	var a: Dictionary = _ammo[key]
	if a["mag"] <= 0:
		return false
	a["mag"] -= 1
	ammo_changed.emit(a["mag"], a["reserve"])
	# The sidearm's reload is MANDATORY: it starts the instant the mag runs
	# dry, not just when the player next tries to fire and finds it empty.
	# Every other weapon still reloads on the player's own timing.
	if a["mag"] == 0 and w.id == &"pistol":
		reload()
	return true

## Reload the active weapon. Applies to EVERY weapon — infinite-ammo guns get
## the same reload cycle (timing + animation) for feel, they just don't move
## ammo counts. Firing is blocked for the weapon's reload_time.
func reload() -> void:
	if reloading:
		return
	var w := get_active()
	if w == null:
		return
	var key: String = active_slot[0] + str(active_slot[1])
	var a: Dictionary = _ammo[key]
	var infinite: bool = a["reserve"] < 0
	# Nothing to gain: mag already full, or a finite gun with an empty reserve.
	if a["mag"] >= w.mag_size:
		return
	if not infinite and a["reserve"] <= 0:
		return

	reloading = true
	_reload_key = key
	_reload_weapon = w
	var modifier := 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player is Player:
		modifier = player.reload_multiplier
	if RunState.has_perk(&"fast_hands"):
		modifier *= 0.75
	_reload_remaining = maxf(w.reload_time * modifier, 0.1)
	set_process(true)
	reload_started.emit(_reload_remaining)

func _process(delta: float) -> void:
	if not reloading:
		return
	_reload_remaining -= delta
	if _reload_remaining > 0.0:
		return
	var a: Dictionary = _ammo[_reload_key]
	var needed := _reload_weapon.mag_size - int(a["mag"])
	if int(a["reserve"]) < 0:
		a["mag"] = _reload_weapon.mag_size
	else:
		var take := mini(needed, int(a["reserve"]))
		a["mag"] += take
		a["reserve"] -= take
	reloading = false
	_reload_weapon = null
	set_process(false)
	reload_finished.emit()
	ammo_changed.emit(a["mag"], a["reserve"])

## Scavenging: add reserve ammo to any equipped weapon of a matching type.
func scavenge(ammo_type: StringName, amount: int) -> int:
	var added := 0
	for tag: String in ["big", "small"]:
		var arr: Array = big if tag == "big" else small
		for i in arr.size():
			var w = arr[i]
			if w != null and w.uses_ammo and w.ammo_type == ammo_type:
				var key: String = tag + str(i)
				var a: Dictionary = _ammo[key]
				var space: int = w.max_reserve - a["reserve"]
				var give: int = min(space, amount)
				a["reserve"] += give
				added += give
	if added > 0:
		var act := _active_ammo()
		ammo_changed.emit(act["mag"], act["reserve"])
	return added

func active_ammo_readout() -> String:
	var a := _active_ammo()
	if a["reserve"] < 0:
		return str(a["mag"]) + " / ∞"      # finite mag, infinite reserve
	return str(a["mag"]) + " / " + str(a["reserve"])

func cancel_reload() -> void:
	if not reloading:
		return
	_reload_weapon = null
	_reload_remaining = 0.0
	set_process(false)
	reloading = false
	reload_finished.emit()
