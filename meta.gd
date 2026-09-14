extends Node
## Autoload singleton: persistent progression that survives across runs and deaths.
## Register in Project Settings > Autoload with node name "Meta".
## Access anywhere as Meta.prestige, Meta.tutorial_seen, etc.

const SAVE_PATH := "user://meta.save"

# --- Persistent progression fields ---
var prestige: int = 0
var unlocked_assets: Array[StringName] = []      # ids the player has unlocked
var high_score: float = 0.0
var runs_played: int = 0
var runs_survived: int = 0
var tutorial_seen: bool = false
var total_profit: float = 0.0                    # lifetime cash earned

func _ready() -> void:
	load_meta()

func save_meta() -> void:
	var data := {
		"prestige": prestige,
		"unlocked_assets": unlocked_assets,
		"high_score": high_score,
		"runs_played": runs_played,
		"runs_survived": runs_survived,
		"tutorial_seen": tutorial_seen,
		"total_profit": total_profit,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Meta: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data))
	f.close()

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return                                    # first launch: keep defaults
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Meta: save file corrupt, ignoring")
		return
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
	prestige = 0
	unlocked_assets.clear()
	high_score = 0.0
	runs_played = 0
	runs_survived = 0
	tutorial_seen = false
	total_profit = 0.0
	save_meta()
