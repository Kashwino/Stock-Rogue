extends Node
## The map screen scene root. Hosts the MapUI (and a ShopUI) and wires their
## signals to RunFlow. This is the MAP_SCENE that RunFlow.go_to_map() loads.
##
## Scene layout (children):
##   MapUI   (map_ui.gd, CanvasLayer)
##   ShopUI  (shop_ui.gd, CanvasLayer)
##
## On load it binds the current RunMap from RunState and shows the current step.

@onready var map_ui = $MapUI
@onready var shop_ui = $ShopUI

func _ready() -> void:
	print("[MapScreen] _ready — MapUI=", map_ui, " ShopUI=", shop_ui)
	get_tree().paused = false      # never inherit a paused tree from a heist

	# Safety: if there's no active run (e.g. opened this scene directly), start one.
	if RunState.run_map == null:
		print("[MapScreen] no run_map — starting a new run")
		var profile = load("res://main_character.tres") if ResourceLoader.exists("res://main_character.tres") else null
		RunFlow.start_new_run(profile)
		return   # start_new_run reloads this scene

	if map_ui == null:
		push_error("[MapScreen] MapUI child missing — the scene needs a MapUI "
			+ "node with map_ui.gd. Cannot show the map.")
		return

	# Wire MapUI signals.
	map_ui.heist_chosen.connect(_on_heist_chosen)
	map_ui.shop_opened.connect(_on_shop_opened)
	map_ui.shop_skipped.connect(_on_shop_skipped)
	map_ui.quota_reached.connect(_on_quota_reached)
	map_ui.run_advanced.connect(_on_run_advanced)
	map_ui.run_complete.connect(_on_run_complete)

	if shop_ui:
		shop_ui.closed.connect(_on_shop_closed)
	else:
		push_warning("[MapScreen] ShopUI child missing — shops will be skipped.")

	# Show the map at the current step.
	map_ui.bind_map(RunState.run_map)
	print("[MapScreen] map bound OK")

func _on_heist_chosen(node) -> void:
	# Hand off to RunFlow, which swaps to the arena scene.
	RunFlow.launch_heist(node)

func _on_shop_opened() -> void:
	# The old menu-based shop is replaced by the walkable hideout: three
	# stations (Weapon Dealer, The Fence, Black Market) in a real room.
	# hideout_room.gd advances the step and returns to this scene itself when
	# the player walks out the door, so nothing else to wire here.
	print("[MapScreen] shop_opened received — entering the hideout")
	RunFlow.save()
	const HIDEOUT_SCENE := "res://hideout_room.tscn"
	if not ResourceLoader.exists(HIDEOUT_SCENE):
		push_error("[MapScreen] " + HIDEOUT_SCENE + " does not exist. Create it: "
			+ "New Scene, root type Node2D, attach hideout_room.gd, save at "
			+ "exactly that path.")
		map_ui.show()          # don't strand the player on a blank screen
		return
	var err := get_tree().change_scene_to_file(HIDEOUT_SCENE)
	if err != OK:
		push_error("[MapScreen] failed to load " + HIDEOUT_SCENE
			+ " (error code " + str(err) + ")")
		map_ui.show()

func _on_shop_skipped() -> void:
	# Skipping a shop advances past it (secret-event hook could go here later).
	RunState.run_map.advance_step()
	RunFlow.save()
	map_ui.refresh()

func _on_shop_closed() -> void:
	# Kept for compatibility, but the hideout no longer emits this — it
	# advances the step and swaps scenes on its own.
	RunState.run_map.advance_step()
	RunFlow.save()
	map_ui.refresh()

func _on_quota_reached(quota: float) -> void:
	var econ = get_node("/root/RunEconomy")
	if RunState.run_map.check_quota_full(econ.gold, RunState.empire_index()):
		# Passed: advance past the gate.
		RunState.run_map.advance_step()
		RunFlow.save()
		map_ui.refresh()
	else:
		# Failed the quota: run ends.
		RunFlow.end_run(false)

func _on_run_advanced() -> void:
	RunState.run_map.advance_step()
	RunFlow.save()
	map_ui.refresh()

func _on_run_complete() -> void:
	RunFlow.end_run(true)
