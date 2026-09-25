extends Node
## Performance bench: a real World-stage heist with 50 guards hunting the
## player on screen while the player holds the trigger. Reports the CPU cost
## of a frame (scripts + physics) and the live node / bullet counts.
##   godot --headless --path . res://tools/perf_bench.tscn [-- variant=no_crowd|no_fire|no_enemy_process|no_enemy_physics|no_overhead|massacre]
## `massacre`: Full gore, and every 20 frames five guards die violently
## (overkills: sprays, gibs, pools, bodies) and five fresh ones take their
## place, so the crowd stays at 50 while the floor fills with evidence.
## Headless has no GPU, so this measures the game's own work per frame; the
## budget for 60 fps leaves most of 16.7 ms to the renderer.

const ENEMIES := 50
const FRAMES := 600
var _steps := 0

func _on_step() -> void:
	_steps += 1

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 0
	RunState.start_run(load("res://main_character.tres"), 4242)
	RunFlow.practice = true
	RunState.run_map.current_stage = 2
	RunState.run_map.current_step = 1
	var node: MapNode = RunState.run_map.first_heist_option()
	node.modifiers = []
	RunFlow.pending_heist = node
	var floor_scene: HeistFloor = load("res://heist_floor.tscn").instantiate()
	get_tree().root.add_child(floor_scene)
	get_tree().current_scene = floor_scene
	for i in 3:
		await get_tree().physics_frame
	var player := floor_scene.player
	player._invulnerable = true
	# The biggest room, and every existing guard's crew moved into view.
	var room: BuildingRoom = floor_scene.generator.rooms[0]
	for r: BuildingRoom in floor_scene.generator.rooms:
		if r.spawn_count > room.spawn_count:
			room = r
	player.global_position = room.center_position()
	floor_scene.car.arm()
	var owner: Enemy = null
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.get_parent() == room:
			owner = e
			break
	if owner == null:
		owner = get_tree().get_nodes_in_group("enemies")[0]
	var kinds := [Enemy.Kind.GRUNT, Enemy.Kind.ENFORCER, Enemy.Kind.SHOTGUNNER, Enemy.Kind.MARKSMAN, Enemy.Kind.SPRINTER, Enemy.Kind.RIOT, Enemy.Kind.DOG, Enemy.Kind.BOUNCER]
	var crowd: Array = []
	var crowd_size := 0 if "variant=no_crowd" in OS.get_cmdline_user_args() else ENEMIES
	for i in crowd_size:
		var offset := Vector2.from_angle(TAU * i / crowd_size) * randf_range(180, 420)
		var e := floor_scene.spawn_companion(owner, kinds[i % kinds.size()], offset)
		if e:
			e.global_position = player.global_position + offset
			crowd.append(e)
	for e: Enemy in crowd:
		e.hunting = true
		e.max_health = 99999
		e.health = 99999
	var variant := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("variant="):
			variant = a.substr(8)
	match variant:
		"no_enemy_process":
			for e: Enemy in get_tree().get_nodes_in_group("enemies"):
				e.set_process(false)
		"no_enemy_physics":
			for e: Enemy in get_tree().get_nodes_in_group("enemies"):
				e.set_physics_process(false)
		"no_overhead":
			for e: Enemy in get_tree().get_nodes_in_group("enemies"):
				if e.overhead:
					e.overhead.set_process(false)
					e.overhead.hide()
		"no_fire":
			pass
	if variant != "no_fire":
		Input.action_press("fire")
	var process_ms: Array = []
	var start := Time.get_ticks_usec()
	_steps = 0
	get_tree().physics_frame.connect(_on_step)
	var with_step: Array = []
	var without_step: Array = []
	var massacre := variant == "massacre"
	if massacre:
		Settings.values["gore"] = Settings.GORE_FULL
		floor_scene.gore._read_settings()
	var killed := 0
	var kill_ms: Array = []
	var all_ms: Array = []
	for i in FRAMES:
		if massacre and i % 20 == 10:
			var k0 := Time.get_ticks_usec()
			for k in 5:
				crowd = crowd.filter(func(e): return is_instance_valid(e) and not e._dead)
				if crowd.is_empty():
					break
				var victim: Enemy = crowd.pop_front()
				victim.note_hit({"source": &"bullet", "dir": (victim.global_position - player.global_position).normalized(), "force": 320.0, "by_player": true, "point_blank": true, "pellets": 6})
				victim.take_damage(victim.health + 4)
				killed += 1
				var offset := Vector2.from_angle(randf() * TAU) * randf_range(180, 420)
				var fresh := floor_scene.spawn_companion(owner, kinds[killed % kinds.size()], offset)
				if fresh:
					fresh.global_position = player.global_position + offset
					fresh.hunting = true
					fresh.max_health = 99999
					fresh.health = 99999
					crowd.append(fresh)
			kill_ms.append((Time.get_ticks_usec() - k0) / 1000.0)
		var t0 := Time.get_ticks_usec()
		var steps_before := _steps
		await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		all_ms.append(ms)
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var stepped := _steps - steps_before
		if stepped == 1:
			with_step.append(ms)
		elif stepped == 0:
			without_step.append(ms)
	var wall := (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	print("PERF physics steps %d in %.2f s wall = %.1f steps/s (60 = real time)" % [_steps, seconds, _steps / seconds])
	Input.action_release("fire")
	process_ms.sort()
	var avg := func(a: Array) -> float: return a.reduce(func(x, y): return x + y, 0.0) / a.size()
	print("PERF enemies on screen: %d (active %d)  bullets live: %d  nodes: %d" % [crowd.size(), floor_scene.director.active_count, floor_scene.bullet_pool.active_count() if floor_scene.bullet_pool.has_method("active_count") else -1, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("PERF process (scripts) ms  avg %.2f  p95 %.2f" % [avg.call(process_ms), process_ms[int(FRAMES * 0.95)]])
	with_step.sort()
	without_step.sort()
	if not with_step.is_empty() and not without_step.is_empty():
		var frame: float = avg.call(without_step)
		var step: float = avg.call(with_step) - frame
		print("PERF frame without physics %.2f ms, physics step %.2f ms -> a 60 fps frame costs %.2f ms of CPU (budget 16.7)" % [frame, step, frame + step])
		print("PERF worst frames with a step: p95 %.2f ms  max %.2f ms" % [with_step[int(with_step.size() * 0.95)], with_step[-1]])
	print("PERF wall ms per frame %.2f  (~%.0f fps CPU-bound, no GPU)" % [wall, 1000.0 / wall])
	if massacre:
		kill_ms.sort()
		all_ms.sort()
		print("PERF five violent kills in one frame: avg %.2f ms  max %.2f ms   (frame p99 %.2f ms, max %.2f ms)" % [avg.call(kill_ms), kill_ms[-1], all_ms[int(all_ms.size() * 0.99)], all_ms[-1]])
		print("PERF massacre: %d killed  corpses %d (cap %d)  gibs %d (cap %d)  live marks %d  stamps %d" % [killed,
			get_tree().get_nodes_in_group("corpse").size(), Corpse.CAP, floor_scene.gore.active_gibs(), Gore.GIB_CAP,
			floor_scene.gore.live_marks(), floor_scene.gore.stamps])
	floor_scene.queue_free()
	RunState.end_run(false)
	Audio.silence()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)
