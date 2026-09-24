extends Node
## Dev tool: renders a scene (optionally after a scripted setup) and saves PNGs.
## Run under a real/virtual display (not --headless):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- shot=home out=/tmp/home.png
## Presets live in _setup(); frames= controls how long to wait before capturing.

var args := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for raw: String in OS.get_cmdline_user_args():
		var parts := raw.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	_run.call_deferred()

func _run() -> void:
	var shot: String = args.get("shot", "home")
	var out: String = args.get("out", "/tmp/shot.png")
	var frames := int(args.get("frames", "90"))
	var scene := await _setup(shot)
	for i in frames:
		await get_tree().process_frame
	if args.has("wait"):
		await get_tree().create_timer(float(args["wait"]), true, false, true).timeout
	if args.has("teleport") and scene is HeistFloor:
		var where: String = args["teleport"]
		var target: Vector2 = scene.generator.start_room.center_position()
		if where == "boss" and scene.generator.boss_room:
			target = scene.generator.boss_room.center_position() + Vector2(0, 160)
		elif where.begins_with("room"):
			var idx := int(where.substr(4))
			target = scene.generator.rooms[idx % scene.generator.rooms.size()].center_position()
		scene.player.global_position = target
		scene.player._invulnerable = true
		scene.camera.global_position = target
		if args.has("fire"):
			Input.action_press("fire")
		if args.has("provoke"):
			for e in get_tree().get_nodes_in_group("enemies"):
				e.hunting = true
		for i in 40:
			await get_tree().process_frame
	var extra: String = args.get("then", "")
	var extra_arg := ""
	if extra.contains(":"):
		extra_arg = extra.get_slice(":", 1)
		extra = extra.get_slice(":", 0)
	if extra != "" and is_instance_valid(scene) and scene.has_method(extra):
		if extra_arg != "":
			scene.call(extra, StringName(extra_arg))
		else:
			scene.call(extra)
		for i in 30:
			await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(out)
	print("SHOT SAVED ", out, " ", image.get_size())
	get_tree().quit(0)

func _setup(shot: String) -> Node:
	var path := ""
	match shot:
		"home": path = "res://home_screen.tscn"
		"select": path = "res://character_select.tscn"
		"map", "hideout", "heist":
			RunSave.slot = RunSave.SLOT_COUNT
			RunFlow.run_seed = int(args.get("seed", "4817"))
			RunState.start_run(load("res://main_character.tres"), RunFlow.run_seed)
			if args.has("stage"):
				RunState.run_map.current_stage = int(args["stage"])
				RunState.run_map.current_step = int(args.get("step", "1"))
			if args.has("relics"):
				for r in String(args["relics"]).split(","):
					RunState.add_relic(StringName(r))
			if args.has("gold"):
				RunEconomy.gold = int(args["gold"])
			path = {"map": "res://map_ui_screen.tscn", "hideout": "res://hideout_room.tscn", "heist": "res://heist_floor.tscn"}[shot]
			if shot == "heist":
				var step = RunState.run_map.current()
				RunFlow.pending_heist = RunState.run_map.first_heist_option() if RunState.run_map.has_method("first_heist_option") else MapNode.new()
				if args.has("objective"):
					RunFlow.pending_heist.objective = StringName(args["objective"])
				if args.has("mods"):
					var mods: Array = []
					for m in String(args["mods"]).split(","):
						mods.append(StringName(m))
					RunFlow.pending_heist.modifiers = mods
					RunFlow.pending_heist.modifier = mods[0]
				if args.has("contract"):
					RunFlow.pending_heist.contract = StringName(args["contract"])
		"gallery":
			return _gallery()
		"death", "victory":
			RunState.start_run(load("res://main_character.tres"), 11)
			var d = load("res://death_screen.tscn").instantiate()
			get_tree().root.add_child(d)
			var summary := {"heists": 4, "stage": "City", "gold": 612, "index": 87.0, "kills": 23, "venue": "bank_job", "who": "The Operator", "cause": args.get("cause", "")}
			if shot == "death":
				d.show_death(summary)
			else:
				d.show_victory(summary)
			return d
		"results":
			RunState.start_run(load("res://main_character.tres"), 11)
			var r = load("res://results_screen.tscn").instantiate()
			get_tree().root.add_child(r)
			r.show_result({"grade_name": args.get("grade", "A"), "stock_delta": 1.12, "intel": 3, "loot": 184,
				"stats": {"hits_taken": 1, "kills": 9, "enemies_total": 14, "time_seconds": 187.0},
				"breakdown": {"accuracy": 0.62}, "short": {"payout": 140, "profit": 65}}, "bank_job")
			return r
		_:
			path = shot
	var packed: PackedScene = load(path)
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	return scene

## Every character silhouette side by side, for art review.
func _gallery() -> Node:
	var root := Node2D.new()
	get_tree().root.add_child(root)
	get_tree().current_scene = root
	var bg := ColorRect.new()
	bg.color = Color("2a2a30")
	bg.size = Vector2(1400, 800)
	bg.position = Vector2(-60, -60)
	root.add_child(bg)
	var cam := Camera2D.new()
	root.add_child(cam)
	cam.position = Vector2(float(args.get("cx", "470")), float(args.get("cy", "320")))
	var z := float(args.get("zoom", "1.35"))
	cam.zoom = Vector2(z, z)
	cam.make_current()
	var i := 0
	for k in Enemy.Kind.values():
		var e: Enemy = load("res://enemy.tscn").instantiate()
		e.position = Vector2(80 + (i % 8) * 110, 120 + int(i / 8) * 130)
		root.add_child(e)
		e.apply_archetype(k)
		e.set_physics_process(false)
		e.sprite.rotation = -0.5 + 0.12 * i
		var l := Label.new()
		l.text = Enemy.Kind.keys()[k]
		l.position = e.position + Vector2(-40, 34)
		l.add_theme_font_size_override("font_size", 12)
		root.add_child(l)
		i += 1
	var j := 0
	for id in [&"operator", &"ghost", &"wolf", &"broker", &"legend"]:
		var holder := Node2D.new()
		holder.position = Vector2(80 + j * 110, 520)
		root.add_child(holder)
		var spr := Node2D.new()
		holder.add_child(spr)
		spr.rotation = -0.3
		SpriteKit.dress(spr, SpriteKit.hero_spec(id, [SpriteKit.Gun.PISTOL, SpriteKit.Gun.SMG, SpriteKit.Gun.SHOTGUN, SpriteKit.Gun.REVOLVER, SpriteKit.Gun.LONG_RIFLE][j]))
		j += 1
	return root
