extends Node
## The map screen scene root. Hosts the MapUI and wires its signals to RunFlow.
## This is the MAP_SCENE that RunFlow.go_to_map() loads.
##
## Scene layout (children):
##   MapUI   (map_ui.gd, CanvasLayer)

@onready var map_ui = $MapUI

func _ready() -> void:
	get_tree().paused = false      # never inherit a paused tree from a heist
	Audio.music("map")
	# Safety: if there's no active run (e.g. opened this scene directly), start one.
	if RunState.run_map == null:
		var profile = load("res://main_character.tres") if ResourceLoader.exists("res://main_character.tres") else null
		RunFlow.start_new_run(profile)
		return
	if map_ui == null:
		push_error("[MapScreen] MapUI child missing — the scene needs a MapUI node with map_ui.gd.")
		return
	map_ui.heist_chosen.connect(_on_heist_chosen)
	map_ui.hideout_requested.connect(_on_hideout_requested)
	map_ui.hideout_skipped.connect(_on_hideout_skipped)
	map_ui.quota_faced.connect(_on_quota_faced)
	map_ui.stage_advanced.connect(_on_stage_advanced)
	map_ui.run_complete.connect(_on_run_complete)
	map_ui.bind_map(RunState.run_map)

func _on_heist_chosen(node) -> void:
	RunFlow.launch_heist(node)

func _on_hideout_requested() -> void:
	RunFlow.enter_hideout()

func _on_hideout_skipped() -> void:
	RunFlow.leave_hideout()

func _on_quota_faced() -> void:
	if RunFlow.resolve_quota():
		map_ui.refresh()
	else:
		RunFlow.end_run(false, "quota")

func _on_stage_advanced() -> void:
	RunFlow.advance_stage()

func _on_run_complete() -> void:
	RunFlow.end_run(true)
