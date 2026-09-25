extends Node
## Autoload as "RunFlow". The brain of a run: owns the seed, tracks position on
## the route, swaps between the map (the case wall), the hideout and the heist
## building, and saves at every boundary so the player can quit and resume.
##
## Flow: map (current step) -> hideout | heist choice | quota sit-down | stage
## advance -> ... -> the Chairman -> ending.

const MAP_SCENE := "res://map_ui_screen.tscn"
const HIDEOUT_SCENE := "res://hideout_room.tscn"
const ARENA_SCENE := "res://heist_floor.tscn"
const HOME_SCENE := "res://home_screen.tscn"
const SELECT_SCENE := "res://character_select.tscn"

var run_seed: int = 0

# Run-long tallies for the end screen.
## Where a death happened ("RENT OFFICE, TENEMENT ROW"), for the front page.
var death_where := ""
var heists_completed: int = 0
var total_kills: int = 0
var stage: int = 0
var step: int = 0
var room_index: int = 0                # kept for save compatibility

# The heist the player just chose (set before swapping to the arena).
var pending_heist: MapNode = null
## Set by the quick-heist shortcut: a standalone practice job in its own slot.
var practice := false

# --- Starting / resuming ---
func start_new_run(profile: CharacterProfile) -> void:
	practice = false
	run_seed = randi()
	RunState.start_run(profile, run_seed)
	stage = 0
	step = 0
	room_index = 0
	pending_heist = null
	heists_completed = 0
	total_kills = 0
	save()
	go_to_map()

func can_continue() -> bool:
	return RunSave.has_run()

func continue_run() -> void:
	var data := RunSave.load_run()
	if data.is_empty():
		return
	practice = false
	run_seed = int(data.get("seed", randi()))
	stage = int(data.get("stage", 0))
	step = int(data.get("step", 0))
	room_index = int(data.get("room_index", 0))
	heists_completed = int(data.get("heists_completed", 0))
	total_kills = int(data.get("total_kills", 0))
	RunState.deserialize(data)
	RunState.run_map = RunMap.new()
	RunState.run_map.generate(run_seed)
	if int(data.get("route_version", 1)) >= RunMap.ROUTE_VERSION:
		RunState.run_map.restore_position(stage, step, int(data.get("quota_block", 0)), int(data.get("heists_done", heists_completed)))
	else:
		# Older route shapes: migrate by completed heists, keeping all gear.
		RunState.run_map.restore_progress(heists_completed)
	pending_heist = null
	go_to_map()

# --- Saving (called at every boundary) ---
func save() -> void:
	if practice:
		return
	if RunState.run_map:
		stage = RunState.run_map.current_stage
		step = RunState.run_map.current_step
	var data := RunState.serialize(run_seed, stage, step, room_index)
	data["heists_completed"] = heists_completed
	data["total_kills"] = total_kills
	data["route_version"] = RunMap.ROUTE_VERSION
	RunSave.save_run(data)

# --- Scene transitions ---
func go_to_map() -> void:
	room_index = 0
	save()
	# Unpause defensively: the results screen pauses the tree, and if anything
	# interrupted its cleanup the map would load frozen.
	get_tree().paused = false
	_change(MAP_SCENE)

## The map's SHOP step sends the player into the hideout.
func enter_hideout() -> void:
	save()
	get_tree().paused = false
	_change(HIDEOUT_SCENE)

## Walking out of the hideout (or skipping it) moves past the SHOP step.
func leave_hideout() -> void:
	if RunState.run_map and RunState.run_map.current_kind() == RunMap.StepKind.SHOP:
		RunState.run_map.advance_step()
	go_to_map()

## Called by the map when a heist option is chosen.
func launch_heist(node: MapNode) -> void:
	pending_heist = node
	room_index = 0
	save()
	_change(ARENA_SCENE)

## Called by the arena when the whole heist is done (after the results card).
func on_heist_finished() -> void:
	heists_completed += 1
	pending_heist = null
	if practice:
		practice = false
		RunState.end_run(true)
		RunSave.delete_run()
		_change(HOME_SCENE)
		return
	if RunState.run_map:
		var next = RunState.run_map.advance_step()
		if next == null:
			end_run(true)
			return
		# A story breaks on the wire between jobs (the Black Ledger reads the
		# next one early).
		MarketNews.between_jobs(run_seed, RunState.run_map.heists_done)
	go_to_map()

## Quota gate outcome from the map's sit-down with the collector.
func resolve_quota() -> bool:
	if not practice:
		Meta.record_best("best_index", RunState.empire_index())
	var passed := RunState.run_map.check_quota_full(RunEconomy.gold, RunState.empire_index())
	if passed:
		RunState.run_map.advance_step()
		save()
	return passed

## A stage's ADVANCE step: move on to the next stage.
func advance_stage() -> void:
	if RunState.run_map and RunState.run_map.current_kind() == RunMap.StepKind.ADVANCE:
		if RunState.run_map.advance_step() == null:
			end_run(true)
			return
	go_to_map()

## TAKE HIS DEAL on a kneeling stage boss: the run ends right here with his
## early ending — his buyout paid, the Clout reduced (see Verdicts).
func take_deal(boss_id: StringName) -> void:
	if practice or not RunState.active:
		return
	RunEconomy.add_bonus(Verdicts.deal_payout())
	if boss_id not in RunState.bosses_down:
		RunState.bosses_down.append(boss_id)
	get_tree().paused = false
	end_run(true, "", Verdicts.deal_ending(boss_id))

# --- Run end ---
## `ending`: an early ending (TAKE HIS DEAL); a win without one resolves the
## final ending from the Chairman's verdict (Endings.resolve).
func end_run(victory: bool, cause: String = "", ending: StringName = &"") -> void:
	if not RunState.active:
		return
	ShortBook.settle(false)
	Meta.record_run_end(RunEconomy.gold, victory)
	# Snapshot the run's stats BEFORE clearing state — RunState.end_run() wipes
	# the market and loadout, so reading them afterwards gives nothing.
	var summary := {
		"where": death_where,
		"heists": heists_completed,
		"stage": "Town",
		"gold": RunEconomy.gold,
		"index": 1.0,
		"kills": total_kills,
		"cause": cause,
		"venue": String(pending_heist.venue_id) if pending_heist else "",
		"who": RunState.character_profile.display_name if RunState.character_profile else "The Operator",
	}
	if RunState.run_map:
		summary["stage"] = RunState.run_map.stage_name()
	if RunState.market:
		summary["index"] = RunState.empire_index()
	if victory and ending == &"":
		ending = Endings.resolve(RunState.chairman_verdict, float(summary["index"]), RunState.burn_short_profit)
	var early := Endings.is_early(ending)
	if victory:
		summary["ending"] = String(ending)
		summary["early"] = early
	summary["verdicts"] = RunState.verdicts.duplicate()
	summary["chairman_verdict"] = RunState.chairman_verdict
	summary["reputation"] = [RunState.fear, RunState.loyalty, RunState.greed]
	# The career: stats, Clout for the run, and any specialist it unlocked.
	# An early ending (a deal) is a partial win: it isn't counted as a won
	# run, so it never unlocks the Legend.
	if not practice:
		var stat := "deaths"
		if victory:
			stat = "early_endings" if early else "runs_won"
		Meta.stats[stat] = int(Meta.stats.get(stat, 0)) + 1
		Meta.record_best("best_index", float(summary["index"]))
		var cleared: int = RunState.run_map.current_stage if RunState.run_map else 0
		if victory:
			cleared = cleared + 1 if early else 4
		Meta.record_best("best_combo", RunState.best_combo)
		summary["clout"] = Meta.award_run(RunState.run_id, cleared, RunState.bosses_down.size(), float(summary["index"]),
			victory and not early, RunState.best_combo, Verdicts.DEAL_CLOUT_BONUS if early else 0)
		if victory:
			summary["first_time"] = Meta.record_ending(ending)
			summary["clout"] = int(summary["clout"]) + int(summary["first_time"])
		else:
			Meta.record_ending(&"busted")
		summary["new_specialists"] = Meta.check_unlocks()
	practice = false
	death_where = ""
	RunState.end_run(victory)
	RunSave.delete_run()               # roguelike: run save gone at death/win
	_show_end_screen(victory, summary)

## Spawn the death/victory screen over whatever scene is currently loaded.
## A win (or a deal) plays its ending (endings.gd); a death gets the BUSTED
## front page.
func _show_end_screen(victory: bool, summary: Dictionary) -> void:
	if victory:
		for existing in get_tree().root.get_children():
			if existing is DeathScreen or existing is EndingSequence:
				existing.queue_free()
		var seq := EndingSequence.play(self, summary)
		seq.add_to_group("end_screen")
		return
	if not ResourceLoader.exists("res://death_screen.tscn"):
		push_error("RunFlow: res://death_screen.tscn missing — returning to menu.")
		get_tree().paused = false
		_change(HOME_SCENE)
		return
	var screen = load("res://death_screen.tscn").instantiate()
	# Parent to the root so it survives the current scene being freed.
	# Clear any leftover screen first so they can't stack across runs.
	for existing in get_tree().root.get_children():
		if existing is DeathScreen:
			existing.queue_free()
	screen.add_to_group("end_screen")
	get_tree().root.add_child(screen)
	if victory:
		screen.show_victory(summary)
	else:
		screen.show_death(summary)

## A separate fourth save slot keeps the practice shortcut away from real
## case files: a standalone job at the Marlowe Exchange with the Auditor.
func start_quick_test() -> void:
	Settings.apply_display_from_gesture()
	RunSave.slot = RunSave.SLOT_COUNT
	run_seed = 4817
	heists_completed = 0
	total_kills = 0
	stage = 0
	step = 0
	room_index = 0
	RunState.start_run(load("res://main_character.tres"), run_seed)
	# Practice jobs are rehearsals: extra padding, and health never drops below
	# one (see Player.take_damage).
	RunState.add_max_health(3)
	RunEconomy.add_bonus(350)
	for weapon: WeaponItem in ItemPool.weapons():
		if weapon.id in [&"ricochet", &"breacher"]:
			RunState.loadout.equip(weapon)
	pending_heist = MapNode.new(MapNode.Type.BOSS)
	pending_heist.venue_id = &"bank_job"
	pending_heist.boss_id = &"auditor"
	pending_heist.room_rarity = 1
	pending_heist.modifier = &"insider"
	pending_heist.modifiers = [&"insider"]
	practice = true
	_change(ARENA_SCENE)

func _change(path: String) -> void:
	var err := queue_scene(path)
	if err != OK:
		push_error("RunFlow: cannot open " + path + " (error " + str(err) + ")")

## Defer scene removal until touch/mouse button dispatch has finished.
func queue_scene(path: String) -> Error:
	if not ResourceLoader.exists(path):
		push_error("RunFlow: scene does not exist: " + path)
		return ERR_FILE_NOT_FOUND
	_commit_scene.call_deferred(path)
	return OK

func _commit_scene(path: String) -> void:
	Controls.release_all()
	var style := "stamp" if path in [ARENA_SCENE, HIDEOUT_SCENE] else "fade"
	var stamp := "HIDEOUT" if path == HIDEOUT_SCENE else "GO TIME"
	Transition.change_scene(path, style, stamp)
