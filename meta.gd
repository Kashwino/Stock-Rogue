extends Node
## Autoload singleton: persistent progression that survives across runs and deaths.
## Register in Project Settings > Autoload with node name "Meta".
## Access anywhere as Meta.prestige, Meta.tutorial_seen, etc.

const SAVE_PATH := "user://meta.save"
const WEB_KEY := "stock-rogue-career-v1"
const CATALOG := {
	&"circuit_smg": {"name": "Circuit Thief", "cost": 12, "kind": "weapon", "detail": "Quiet SMG with piercing rounds. Enters cases and chests."},
	&"margin_call": {"name": "Margin Call", "cost": 18, "kind": "weapon", "detail": "Heavy rail pistol. Pierces three guards. Enters the loot pool."},
	&"hostile_takeover": {"name": "Hostile Takeover", "cost": 24, "kind": "weapon", "detail": "Rapid shotgun with ricochets. Enters the loot pool."},
	&"fast_hands": {"name": "Fast Hands", "cost": 8, "kind": "perk", "detail": "Start with faster reloads. Equip one starting perk."},
	&"quiet_shoes": {"name": "Quiet Shoes", "cost": 8, "kind": "perk", "detail": "Start with quieter footsteps. Equip one starting perk."},
	&"cool_head": {"name": "Cool Head", "cost": 10, "kind": "perk", "detail": "Incoming heat reduced by 25%. Equip one starting perk."},
	&"room_armory": {"name": "Armory", "cost": 8, "kind": "room", "detail": "Build an armory to research permanent weapon unlocks."},
	&"room_training": {"name": "Training Room", "cost": 8, "kind": "room", "detail": "Build a training room to buy and equip starting perks."},
	&"room_crew": {"name": "Crew Quarters", "cost": 12, "kind": "room", "detail": "Build crew quarters to recruit the Wolf and Broker."},
}
var intel := 0
var starting_perk: StringName = &""
var extraction_receipts: Dictionary = {}
var last_save_ok := true

# --- Persistent progression fields ---
var prestige: int = 0
var unlocked_assets: Array[StringName] = []      # ids the player has unlocked
var high_score: float = 0.0
var runs_played: int = 0
var runs_survived: int = 0
var tutorial_seen: bool = false
var specialists: Array[StringName] = []          # unlocked crew beyond the Operator
var total_profit: float = 0.0                    # lifetime cash earned

func _ready() -> void:
	load_meta()

func save_meta() -> bool:
	var data := {
		"prestige": prestige,
		"unlocked_assets": unlocked_assets,
		"high_score": high_score,
		"runs_played": runs_played,
		"runs_survived": runs_survived,
		"tutorial_seen": tutorial_seen,
		"total_profit": total_profit,
		"intel": intel,
		"starting_perk": String(starting_perk),
		"extraction_receipts": extraction_receipts,
		"specialists": specialists,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	last_save_ok = f != null
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
	if OS.has_feature("web"):
		var ok = JavaScriptBridge.eval("(()=>{try{localStorage.setItem('" + WEB_KEY + "'," + JSON.stringify(JSON.stringify(data)) + ");return true}catch(e){return false}})()", true)
		last_save_ok = last_save_ok or ok == true
	return last_save_ok

func load_meta() -> void:
	var content := FileAccess.get_file_as_string(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else "{}"
	if OS.has_feature("web"):
		var saved = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('" + WEB_KEY + "')}catch(e){return null}})()", true)
		if saved is String and JSON.parse_string(saved) is Dictionary:
			content = saved
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	intel = maxi(0, int(parsed.get("intel", 0)))
	starting_perk = StringName(parsed.get("starting_perk", ""))
	extraction_receipts = parsed.get("extraction_receipts", {})
	prestige = int(parsed.get("prestige", 0))
	high_score = float(parsed.get("high_score", 0.0))
	runs_played = int(parsed.get("runs_played", 0))
	runs_survived = int(parsed.get("runs_survived", 0))
	tutorial_seen = bool(parsed.get("tutorial_seen", false))
	total_profit = float(parsed.get("total_profit", 0.0))
	# Arrays come back as generic; rebuild typed.
	unlocked_assets.clear()
	for a in parsed.get("unlocked_assets", []):
		unlocked_assets.append(StringName(a))
	specialists.clear()
	for sp in parsed.get("specialists", []):
		specialists.append(StringName(sp))
	if starting_perk not in unlocked_assets or not CATALOG.has(starting_perk) or CATALOG[starting_perk]["kind"] != "perk":
		starting_perk = &""

## Specialists unlock through feats (tracked in Phase 9 stats). Crews hired
## through the beta's Crew Quarters stay hired.
func is_specialist_unlocked(id: StringName) -> bool:
	if id == &"operator":
		return true
	if id in specialists:
		return true
	return id in [&"wolf", &"broker"] and &"room_crew" in unlocked_assets

func purchase(id: StringName) -> String:
	if not CATALOG.has(id):
		return "Unknown unlock."
	if id in unlocked_assets:
		return "Already unlocked."
	var cost: int = CATALOG[id]["cost"]
	if intel < cost:
		return "Earn Intel by escaping after kills or sabotage."
	intel -= cost
	unlocked_assets.append(id)
	if not save_meta():
		intel += cost
		unlocked_assets.erase(id)
		return "Could not save. Purchase cancelled."
	return "Unlocked permanently."

func equip_starting_perk(id: StringName) -> bool:
	if id != &"" and (id not in unlocked_assets or not CATALOG.has(id) or CATALOG[id]["kind"] != "perk"):
		return false
	var previous := starting_perk
	starting_perk = id
	if not save_meta():
		starting_perk = previous
		return false
	return true

func award_extraction(receipt: String, kills: int, sabotaged: int, boss: bool) -> int:
	# A checkpoint replay cannot award the same contract a second time.
	if extraction_receipts.has(receipt):
		return 0
	var earned := mini(6, maxi(0, kills) / 2) + mini(4, maxi(0, sabotaged)) + (4 if boss else 0)
	if earned <= 0:
		return 0
	extraction_receipts[receipt] = earned
	intel += earned
	if not save_meta():
		intel -= earned
		extraction_receipts.erase(receipt)
		return 0
	return earned

# --- Convenience helpers ---
func unlock(asset_id: StringName) -> void:
	if asset_id not in unlocked_assets:
		unlocked_assets.append(asset_id)
		save_meta()

func record_run_end(final_cash: float, survived: bool) -> void:
	runs_played += 1
	if survived:
		runs_survived += 1
	high_score = maxf(high_score, final_cash)
	total_profit += final_cash
	save_meta()

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save_meta()

## Wipe all progression (for a "reset progress" settings button).
func reset() -> void:
	intel = 0
	starting_perk = &""
	extraction_receipts.clear()
	prestige = 0
	unlocked_assets.clear()
	high_score = 0.0
	runs_played = 0
	runs_survived = 0
	tutorial_seen = false
	total_profit = 0.0
	specialists.clear()
	save_meta()
