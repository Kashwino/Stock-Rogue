extends Node
## Autoload singleton: persistent progression that survives across runs and deaths.
## Register in Project Settings > Autoload with node name "Meta".
## Access anywhere as Meta.prestige, Meta.tutorial_seen, etc.

const SAVE_PATH := "user://meta.save"
const WEB_KEY := "stock-rogue-career-v1"
## The Connections board: spend Clout on weapons for the reward pool, one
## starting perk, and a coat colour. Modest by design; nothing here wins a
## quota on its own.
const CATALOG := {
	&"circuit_smg": {"name": "Circuit Thief", "cost": 12, "kind": "weapon", "detail": "Quiet SMG with piercing rounds. Enters cases and chests."},
	&"margin_call": {"name": "Margin Call", "cost": 18, "kind": "weapon", "detail": "Heavy rail pistol. Pierces guards. Enters the loot pool."},
	&"hostile_takeover": {"name": "Hostile Takeover", "cost": 24, "kind": "weapon", "detail": "Rapid shotgun with ricochets. Enters the loot pool."},
	&"fast_hands": {"name": "Fast Hands", "cost": 8, "kind": "perk", "detail": "Start runs with 25% faster reloads."},
	&"quiet_shoes": {"name": "Quiet Shoes", "cost": 8, "kind": "perk", "detail": "Start runs with silent dodge rolls."},
	&"cool_head": {"name": "Cool Head", "cost": 10, "kind": "perk", "detail": "Incoming heat reduced by 25%."},
	&"seed_money": {"name": "Seed Money", "cost": 10, "kind": "perk", "detail": "Start runs with $50 more."},
	&"fence_friend": {"name": "Friend at the Fence", "cost": 12, "kind": "perk", "detail": "One free reroll every hideout visit."},
	&"patch_kit": {"name": "Patch Kit", "cost": 14, "kind": "perk", "detail": "The first time you drop to 1 HP in a run, heal 1."},
	&"coat_crimson": {"name": "Crimson Coat", "cost": 6, "kind": "coat", "detail": "A coat the colour of a bad quarter.", "color": "7a1f24"},
	&"coat_ivory": {"name": "Ivory Coat", "cost": 6, "kind": "coat", "detail": "Clean enough to lie in.", "color": "d8d0bd"},
	&"coat_midnight": {"name": "Midnight Coat", "cost": 6, "kind": "coat", "detail": "Blue-black, for rooftops.", "color": "18203a"},
	&"coat_emerald": {"name": "Emerald Coat", "cost": 6, "kind": "coat", "detail": "Old money green.", "color": "1f4a32"},
}
## Feats that unlock the specialists (career-wide, across all case files).
const UNLOCKS := {
	&"ghost": ["fire_exit_escapes", 5, "Slip out a fire exit 5 times"],
	&"wolf": ["bosses_killed", 3, "Put down 3 bosses"],
	&"broker": ["best_index", 350, "Reach Index 350 in one run"],
	&"legend": ["runs_won", 1, "Retire — win a full run"],
}
## The meta currency, earned at the end of every run.
var clout := 0
## Legacy name, kept so older saves and tools still read the balance.
var intel: int:
	get:
		return clout
	set(v):
		clout = v
var coat: StringName = &""
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
## Career stats across all three case files. Specialist unlocks read these.
const STAT_DEFAULTS := {
	"fire_exit_escapes": 0, "bosses_killed": 0, "best_index": 0.0, "runs_won": 0,
	"heists_completed": 0, "total_gold": 0, "deaths": 0,
}
var stats: Dictionary = STAT_DEFAULTS.duplicate()
## Stage bosses put down, by id (lieutenants count only in bosses_killed).
var bosses_seen: Array = []

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
		"clout": clout,
		"coat": String(coat),
		"starting_perk": String(starting_perk),
		"extraction_receipts": extraction_receipts,
		"specialists": specialists,
		"stats": stats,
		"bosses_seen": bosses_seen,
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
	clout = maxi(0, int(parsed.get("clout", parsed.get("intel", 0))))
	coat = StringName(parsed.get("coat", ""))
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
	stats = STAT_DEFAULTS.duplicate()
	var saved_stats = parsed.get("stats", {})
	if saved_stats is Dictionary:
		for key in STAT_DEFAULTS:
			stats[key] = saved_stats.get(key, STAT_DEFAULTS[key])
	bosses_seen = []
	for b in parsed.get("bosses_seen", []):
		bosses_seen.append(String(b))
	if starting_perk not in unlocked_assets or not CATALOG.has(starting_perk) or CATALOG[starting_perk]["kind"] != "perk":
		starting_perk = &""

## Specialists unlock through feats (tracked in Phase 9 stats). Crews hired
## through the beta's Crew Quarters stay hired.
func is_specialist_unlocked(id: StringName) -> bool:
	if id == &"operator":
		return true
	if id in specialists:
		return true
	if feat_met(id):
		return true
	return id in [&"wolf", &"broker"] and &"room_crew" in unlocked_assets

func feat_met(id: StringName) -> bool:
	if not UNLOCKS.has(id):
		return false
	var feat: Array = UNLOCKS[id]
	return float(stats.get(feat[0], 0)) >= float(feat[1])

func purchase(id: StringName) -> String:
	if not CATALOG.has(id):
		return "Unknown unlock."
	if id in unlocked_assets:
		return "Already unlocked."
	var cost: int = CATALOG[id]["cost"]
	if clout < cost:
		return "Earn Clout by finishing runs: the index you reach, stages cleared, bosses."
	clout -= cost
	unlocked_assets.append(id)
	if not save_meta():
		clout += cost
		unlocked_assets.erase(id)
		return "Could not save. Purchase cancelled."
	return "Unlocked permanently."

## Wear an owned coat ("" for the specialist's own).
func equip_coat(id: StringName) -> bool:
	if id != &"" and (id not in unlocked_assets or not CATALOG.has(id) or CATALOG[id]["kind"] != "coat"):
		return false
	coat = id
	return save_meta()

func coat_color() -> Color:
	if coat != &"" and CATALOG.has(coat) and CATALOG[coat].has("color"):
		return Color(CATALOG[coat]["color"])
	return Color(0, 0, 0, 0)

func equip_starting_perk(id: StringName) -> bool:
	if id != &"" and (id not in unlocked_assets or not CATALOG.has(id) or CATALOG[id]["kind"] != "perk"):
		return false
	var previous := starting_perk
	starting_perk = id
	if not save_meta():
		starting_perk = previous
		return false
	return true

## Clout for a finished run: stages cleared, stage bosses, the best index,
## and a bonus for retiring. A receipt stops a run paying twice.
func award_run(run_id: String, stages_cleared: int, bosses: int, index: float, won: bool) -> int:
	if run_id == "" or extraction_receipts.has(run_id):
		return 0
	var earned := stages_cleared * 3 + bosses * 2 + int(maxf(index, 0.0) / 60.0) + (8 if won else 0)
	earned = maxi(earned, 1)
	extraction_receipts[run_id] = earned
	clout += earned
	if not save_meta():
		clout -= earned
		extraction_receipts.erase(run_id)
		return 0
	return earned

## Specialists whose feat is now met but who were not yet hired. Hires them
## and returns their ids (for the NEW SPECIALIST card).
func check_unlocks() -> Array:
	var fresh: Array = []
	for id: StringName in UNLOCKS:
		if id in specialists or (id in [&"wolf", &"broker"] and &"room_crew" in unlocked_assets):
			continue
		if feat_met(id):
			specialists.append(id)
			fresh.append(id)
	if not fresh.is_empty():
		save_meta()
	return fresh

## Progress toward a specialist, e.g. "3 / 5".
func unlock_progress(id: StringName) -> String:
	if not UNLOCKS.has(id):
		return ""
	var feat: Array = UNLOCKS[id]
	return "%d / %d" % [mini(int(stats.get(feat[0], 0)), int(feat[1])), int(feat[1])]

## Add to a career stat and save.
func record(stat: String, amount = 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount
	save_meta()

## Keep the best value of a career stat.
func record_best(stat: String, value: float) -> void:
	if value > float(stats.get(stat, 0.0)):
		stats[stat] = value
		save_meta()

## A boss or lieutenant put down: counts toward the Wolf.
func record_boss(boss_id: StringName, is_lieutenant: bool) -> void:
	stats["bosses_killed"] = int(stats.get("bosses_killed", 0)) + 1
	if not is_lieutenant and String(boss_id) not in bosses_seen:
		bosses_seen.append(String(boss_id))
	save_meta()

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
	clout = 0
	coat = &""
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
	stats = STAT_DEFAULTS.duplicate()
	bosses_seen.clear()
	save_meta()
