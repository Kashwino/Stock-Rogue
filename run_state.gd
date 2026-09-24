extends Node
## Autoload this as "RunState" (Project Settings > Autoload).
## Holds everything that must persist across scene swaps within a single run:
## the loadout, the player's current/max health, and the run map. Gold lives in
## RunEconomy (also an autoload). A "run" begins with start_run() and ends on
## death or completion.

signal health_changed(current: int, maxv: int)
signal run_started()
signal run_ended(victory: bool)

var loadout: Loadout = null          # persistent weapon loadout
var run_map: RunMap = null           # the branching map
var character_profile: CharacterProfile = null

## The criminal stock market for the WHOLE run. Prices persist across heists —
## every grade and live move compounds. Quota gates read the empire index.
var market: CriminalMarket = null

## Run perks (bought in the shop): &"recon", &"inside_trader", ...
var perks: Array = []
var hedge_charges: int = 0
var short_position: Dictionary = {}
var run_id: String = ""
var last_grade := ""
var bosses_down: Array = []          # stage boss ids defeated this run
## Fence positions: [{venue, side, stake, entry, leverage}] (see Positions).
var positions: Array = []
## Completed CONTRACT jobs per venue: repeat contracts pump less (×0.65 each).
var contract_counts: Dictionary = {}
## The news wire (latest first) and rumors waiting to land (see MarketNews).
var news: Array = []
var rumors: Array = []

var max_health: int = 3
var health: int = 3

# Persistent stat modifiers from upgrades (applied to the player each heist).
# stat name -> {add: float, mult: float}
var stat_mods: Dictionary = {}

var active: bool = false

func start_run(profile: CharacterProfile, run_seed: int = 0) -> void:
	character_profile = profile
	max_health = profile.base_health if profile else 3
	health = max_health
	stat_mods.clear()
	hedge_charges = 0
	short_position.clear()
	last_grade = ""
	bosses_down.clear()
	positions.clear()
	contract_counts.clear()
	news.clear()
	rumors.clear()
	run_id = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]

	# Fresh loadout with the starter Sidearm.
	if is_instance_valid(loadout):
		loadout.queue_free()
	loadout = Loadout.new()
	add_child(loadout)
	loadout.equip(ItemPool.weapons()[0])

	# Fresh map.
	run_map = RunMap.new()
	run_map.generate(run_seed)

	# Fresh run-long market (prices persist and compound across heists).
	if market and is_instance_valid(market):
		market.queue_free()
	market = CriminalMarket.new()
	market.assets = Roster.build()
	add_child(market)
	market.setup(run_seed)
	perks.clear()
	if Meta.starting_perk != &"":
		add_perk(Meta.starting_perk)

	if profile and profile.id == &"ghost":
		add_perk(&"quiet_shoes")
	if profile and profile.id == &"wolf":
		add_stat_mod(&"damage_bonus", 1.0, 1.0)

	# Reset gold for the run.
	if has_node("/root/RunEconomy"):
		get_node("/root/RunEconomy").reset()

	active = true
	run_started.emit()
	health_changed.emit(health, max_health)

func end_run(victory: bool) -> void:
	active = false
	if loadout and is_instance_valid(loadout):
		loadout.queue_free()
		loadout = null
	if market and is_instance_valid(market):
		market.queue_free()
		market = null
	perks.clear()
	run_ended.emit(victory)

# --- Perks ---
func add_perk(id: StringName) -> void:
	if id not in perks:
		perks.append(id)

func has_perk(id: StringName) -> bool:
	return id in perks

# --- Empire index (drives the quota stock requirement) ---
## Starts at 1 (market at baseline) and climbs as you pump venues. Calibrated
## so the first quota gate sits at 120 — same real difficulty as the original
## percent scale, just starting from 1 instead of 100.
## and it rises; tank heists and it falls. Quota gates demand a minimum index.
const INDEX_SCALE := 595.0   # growth-to-points calibration (ratio 1.20 -> 120)

func empire_index() -> float:
	if market == null or market.assets.is_empty():
		return 1.0
	var total := 0.0
	var counted := 0
	for a in market.assets:
		if a.base_price > 0.0:
			total += a.current_price / a.base_price
			counted += 1
	if counted == 0:
		return 1.0
	var mean_ratio := total / float(counted)
	return 1.0 + (mean_ratio - 1.0) * INDEX_SCALE

# --- Health (persists across heists; carries damage between them) ---
func set_health(v: int) -> void:
	health = clampi(v, 0, max_health)
	health_changed.emit(health, max_health)

func heal(amount: int) -> void:
	set_health(health + amount)

func add_max_health(amount: int) -> void:
	max_health += amount
	health += amount
	health_changed.emit(health, max_health)

# --- Persistent upgrades ---
## Record an upgrade so it re-applies to the player at the start of each heist.
func add_stat_mod(stat: StringName, add: float = 0.0, mult: float = 1.0) -> void:
	if not stat_mods.has(stat):
		stat_mods[stat] = {"add": 0.0, "mult": 1.0}
	stat_mods[stat]["add"] += add
	stat_mods[stat]["mult"] *= mult

## Apply all recorded stat mods + persistent health to a freshly-spawned player.
func apply_to_player(player) -> void:
	player.max_health = max_health
	player.health = health
	player.health_changed.emit(player.health, player.max_health)
	if player.has_method("attach_loadout"):
		player.attach_loadout(loadout)
	else:
		player.loadout = loadout
	for stat in stat_mods.keys():
		if stat in player:
			var m: Dictionary = stat_mods[stat]
			var base = player.get(stat)
			player.set(stat, base * m["mult"] + m["add"])

## Pull the player's post-heist health back into the run state so damage carries.
func sync_from_player(player) -> void:
	health = clampi(player.health, 0, max_health)
	health_changed.emit(health, max_health)

# --- Serialization (for save/resume at room boundaries) ---

## Serialize everything needed to resume the run into a plain Dictionary.
## seed lets us regenerate the identical map; position tracks where in it we are.
func serialize(map_seed: int, stage: int, step: int, room_index: int) -> Dictionary:
	var econ = get_node_or_null("/root/RunEconomy")
	return {
		"seed": map_seed,
		"stage": stage,
		"step": step,
		"room_index": room_index,           # which room within the current heist
		"health": health,
		"max_health": max_health,
		"gold": econ.gold if econ else 0,
		"stat_mods": _serialize_stat_mods(),
		"loadout": _serialize_loadout(),
		"profile_path": character_profile.resource_path if character_profile else "",
		"perks": perks.duplicate(),
		"hedge_charges": hedge_charges,
		"short_position": short_position.duplicate(true),
		"run_id": run_id,
		"last_grade": last_grade,
		"bosses_down": bosses_down.duplicate(),
		"quota_block": run_map.quota_block if run_map else 0,
		"heists_done": run_map.heists_done if run_map else 0,
		"market": _serialize_market(),
		"positions": positions.duplicate(true),
		"contract_counts": contract_counts.duplicate(),
		"news": news.duplicate(true),
		"rumors": rumors.duplicate(true),
	}

func _serialize_market() -> Dictionary:
	var out := {}
	if market:
		for a in market.assets:
			out[String(a.id)] = a.current_price
	return out

func _serialize_stat_mods() -> Array:
	var out := []
	for stat in stat_mods.keys():
		var m: Dictionary = stat_mods[stat]
		out.append({"stat": String(stat), "add": m["add"], "mult": m["mult"]})
	return out

func _serialize_loadout() -> Dictionary:
	if loadout == null:
		return {}
	# Save weapon ids per slot; ItemPool rebuilds the actual resources on load.
	var big_ids := []
	for w in loadout.big:
		big_ids.append(String(w.id) if w != null else "")
	var small_ids := []
	for w in loadout.small:
		small_ids.append(String(w.id) if w != null else "")
	return {"big": big_ids, "small": small_ids, "active": loadout.active_slot}

## Rebuild run state from a saved Dictionary. Returns the map seed so the caller
## can regenerate the map and jump to the saved position.
func deserialize(data: Dictionary) -> void:
	run_id = str(data.get("run_id", "legacy-" + str(data.get("seed", 0))))
	short_position = data.get("short_position", {}).duplicate(true)
	last_grade = str(data.get("last_grade", ""))
	bosses_down = Array(data.get("bosses_down", [])).duplicate()
	positions = Array(data.get("positions", [])).duplicate(true)
	contract_counts = Dictionary(data.get("contract_counts", {})).duplicate()
	news = Array(data.get("news", [])).duplicate(true)
	rumors = Array(data.get("rumors", [])).duplicate(true)
	max_health = int(data.get("max_health", 3))
	health = int(data.get("health", max_health))

	# Profile.
	var pp: String = data.get("profile_path", "")
	if pp != "" and ResourceLoader.exists(pp):
		character_profile = load(pp)

	# Gold.
	var econ = get_node_or_null("/root/RunEconomy")
	if econ:
		econ.gold = int(data.get("gold", 0))
		econ.gold_changed.emit(econ.gold)

	# Stat mods.
	stat_mods.clear()
	for m in data.get("stat_mods", []):
		add_stat_mod(StringName(m["stat"]), float(m["add"]), float(m["mult"]))

	# Loadout: rebuild from saved weapon ids.
	if loadout and is_instance_valid(loadout):
		loadout.queue_free()
	loadout = Loadout.new()
	add_child(loadout)
	_deserialize_loadout(data.get("loadout", {}))

	# Perks.
	perks.clear()
	for pk in data.get("perks", []):
		perks.append(StringName(pk))

	hedge_charges = clampi(int(data.get("hedge_charges", 0)), 0, 3)

	# Market: rebuild the roster, then overwrite prices with the saved ones.
	if market and is_instance_valid(market):
		market.queue_free()
	market = CriminalMarket.new()
	market.assets = Roster.build()
	add_child(market)
	market.setup()
	var saved_prices: Dictionary = data.get("market", {})
	for a in market.assets:
		if saved_prices.has(String(a.id)):
			a.current_price = float(saved_prices[String(a.id)])

	active = true
	health_changed.emit(health, max_health)

func _deserialize_loadout(data: Dictionary) -> void:
	if data.is_empty():
		loadout.equip(ItemPool.weapons()[0])   # fallback: starter
		return
	var by_id := {}
	for w in ItemPool.weapons():
		by_id[String(w.id)] = w
	for id in data.get("big", []):
		if id != "" and by_id.has(id):
			loadout.equip(by_id[id])
	for id in data.get("small", []):
		if id != "" and by_id.has(id):
			loadout.equip(by_id[id])
	if data.has("active"):
		loadout.active_slot = data["active"]
