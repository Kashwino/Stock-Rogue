extends Node
## Loot census for tools/balance_sim.py. Builds real heist buildings for every
## stage (ordinary jobs, several seeds each) and records what money they hold:
## floor valuables, the expected room-clear gold from GOLD_TABLE, guard count
## and room count. Writes res://tools/loot_census.json.
##   godot --headless --path . res://tools/loot_census.tscn

const SEEDS_PER_STAGE := 12

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := {}
	for stage in 4:
		var jobs: Array = []
		for i in SEEDS_PER_STAGE:
			var run_seed := 1000 + stage * 97 + i * 13
			RunState.start_run(load("res://main_character.tres"), run_seed)
			RunFlow.practice = true
			RunState.run_map.current_stage = stage
			RunState.run_map.current_step = 1
			var options: Array = RunState.run_map.peek_next_heist_options()
			var node: MapNode = options[i % options.size()] if not options.is_empty() else MapNode.new()
			if node.type == MapNode.Type.BOSS:
				continue
			node.modifiers = []
			node.modifier = &""
			RunFlow.pending_heist = node
			var floor_scene: HeistFloor = load("res://heist_floor.tscn").instantiate()
			get_tree().root.add_child(floor_scene)
			await get_tree().physics_frame
			await get_tree().process_frame
			var floor_loot := 0
			for l: Node in get_tree().get_nodes_in_group("loot_pickups"):
				floor_loot += int(l.get("value"))
			var clear_gold := 0.0
			var rooms := 0
			for room: Node in floor_scene.generator.rooms:
				rooms += 1
				if int(room.get("spawn_count")) > 0:
					var row: Array = HeistFloor.GOLD_TABLE.get(int(room.get("rarity")), HeistFloor.GOLD_TABLE[0])
					clear_gold += row[0] * (row[1] + row[2]) * 0.5
			jobs.append({
				"venue": String(node.venue_id), "floor_loot": floor_loot,
				"clear_gold": snappedf(clear_gold, 0.1), "rooms": rooms,
				"guards": get_tree().get_nodes_in_group("enemies").size(),
			})
			floor_scene.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
		out[str(stage)] = jobs
		print("CENSUS stage %d: %d jobs" % [stage, jobs.size()])
	RunState.end_run(false)
	var f := FileAccess.open("res://tools/loot_census.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("CENSUS WRITTEN")
	Audio.silence()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)
