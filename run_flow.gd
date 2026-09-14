extends Node
## Autoload as "RunFlow". The brain of a run: owns the seed, tracks position
## (stage/step/room), swaps between the map scene and the arena scene, and saves
## at every boundary so the player can quit and resume (at room start).
##
## Scenes involved (adjust paths to your project):
##   MAP_SCENE   — the run map screen
##   ARENA_SCENE — the combat arena
##
## Flow: map -> pick heist -> arena (room by room) -> grade -> back to map -> ...

const MAP_SCENE := "res://map_ui_screen.tscn"     # a scene whose root hosts MapUI + logic
## The playable heist. This MUST be the building floor — the old wave-based
## res://arena.tscn ignores the generator, extraction, and the death screen.
const ARENA_SCENE := "res://heist_floor.tscn"

var run_seed: int = 0

# Run-long tallies for the end screen.
var heists_completed: int = 0
var total_kills: int = 0
var stage: int = 0
var step: int = 0
var room_index: int = 0                # which room within the current heist

# The heist the player just chose (set before swapping to the arena).
var pending_heist: MapNode = null

func _ready() -> void:
	pass

# --- Starting / resuming ---
func start_new_run(profile: CharacterProfile) -> void:
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
	run_seed = int(data.get("seed", randi()))
	stage = int(data.get("stage", 0))
	step = int(data.get("step", 0))
	room_index = int(data.get("room_index", 0))
	heists_completed = int(data.get("heists_completed", 0))
	total_kills = int(data.get("total_kills", 0))
	# Rebuild state + map.
	RunState.deserialize(data)
	RunState.run_map = RunMap.new()
	RunState.run_map.generate(run_seed)
	# Fast-forward the map to the saved position.
	RunState.run_map.current_stage = stage
	RunState.run_map.current_step = step
	go_to_map()

# --- Saving (called at every boundary) ---
func save() -> void:
	if RunState.run_map:
		stage = RunState.run_map.current_stage
		step = RunState.run_map.current_step
	var data := RunState.serialize(run_seed, stage, step, room_index)
	data["heists_completed"] = heists_completed
	data["total_kills"] = total_kills
	RunSave.save_run(data)

# --- Scene transitions ---
func go_to_map() -> void:
	room_index = 0
	save()
	# Unpause defensively: the results screen pauses the tree, and if anything
	# interrupted its cleanup the map would load frozen.
	get_tree().paused = false
	if not ResourceLoader.exists(MAP_SCENE):
		push_error("RunFlow: " + MAP_SCENE + " does not exist — cannot return "
			+ "to heist selection.")
		return
	print("[RunFlow] returning to map: ", MAP_SCENE)
	var err := get_tree().change_scene_to_file(MAP_SCENE)
	if err != OK:
		push_error("RunFlow: failed to load " + MAP_SCENE + " (error " + str(err) + ")")

## Called by the map when a heist option is chosen.
func launch_heist(node: MapNode) -> void:
	pending_heist = node
	room_index = 0
	save()
	if not ResourceLoader.exists(ARENA_SCENE):
		push_error("RunFlow: " + ARENA_SCENE + " does not exist. Create it: "
			+ "New Scene > Node2D root > attach heist_floor.gd > add a Camera2D "
			+ "child > save as res://heist_floor.tscn")
		return
	print("[RunFlow] launching heist scene: ", ARENA_SCENE)
	get_tree().change_scene_to_file(ARENA_SCENE)

## Called by the arena when the player enters a new room (boundary save).
func on_room_entered(index: int) -> void:
	room_index = index
	save()

## Called by the arena when the whole heist is done (after grade screen).
func on_heist_finished() -> void:
	heists_completed += 1
	# Advance the map past the chosen heist step. advance_step() returns null
	# once the final stage is cleared — that's the win condition, not a map to
	# load, and going to the map anyway left the game on a dead screen.
	pending_heist = null
	if RunState.run_map:
		var next = RunState.run_map.advance_step()
		if next == null:
			print("[RunFlow] final stage cleared — run won")
			end_run(true)
			return
	go_to_map()

# --- Run end ---
func end_run(victory: bool) -> void:
	# Snapshot the run's stats BEFORE clearing state — RunState.end_run() wipes
	# the market and loadout, so reading them afterwards gives nothing.
	# Everything here is guarded: a bad read must not stop the end screen.
	var summary := {
		"heists": heists_completed,
		"stage": "Town",
		"gold": 0,
		"index": 1.0,
		"kills": total_kills,
	}
	var econ = get_node_or_null("/root/RunEconomy")
	if econ:
		summary["gold"] = econ.gold
	if RunState.run_map:
		summary["stage"] = RunState.run_map.stage_name()
	if RunState.market:
		summary["index"] = RunState.empire_index()

	RunState.end_run(victory)
	RunSave.delete_run()               # roguelike: run save gone at death/win
	# Unlockables persist separately via Meta (recorded elsewhere).

	_show_end_screen(victory, summary)

## Spawn the death/victory screen over whatever scene is currently loaded.
func _show_end_screen(victory: bool, summary: Dictionary) -> void:
	if not ResourceLoader.exists("res://death_screen.tscn"):
		push_error("RunFlow: res://death_screen.tscn missing — create it "
			+ "(CanvasLayer root + death_screen.gd). Returning to menu.")
		get_tree().paused = false
		get_tree().change_scene_to_file("res://home_screen.tscn")
		return
	var scene = load("res://death_screen.tscn")
	var screen = scene.instantiate()
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
