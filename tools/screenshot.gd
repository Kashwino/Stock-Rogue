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
	# Session-only settings for the shot (never saved).
	if args.has("gore"):
		Settings.values["gore"] = int(args["gore"])
	if args.has("blood"):
		Settings.values["blood_style"] = int(args["blood"])
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
	if args.has("card") and scene is HeistFloor and scene.boss:
		# The VERDICT card over a kneeling boss (then=debug_kill_boss first).
		scene.player.global_position = scene.boss.global_position + Vector2(0, 80)
		scene.open_verdict(scene.boss)
		for i in 30:
			await get_tree().process_frame
	if args.has("kills") and scene is HeistFloor:
		# A multi-kill in front of the player: bodies slide, guns skitter.
		var owner: Enemy = null
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not (e is Boss) and e.get_parent() is BuildingRoom:
				owner = e
				break
		var kill_shot := KillInfo.next_shot_id()
		var kind_arg := String(args.get("source", "bullet"))
		for i in int(args["kills"]):
			var v: Enemy = scene.spawn_companion(owner, Enemy.Kind.GRUNT, Vector2.ZERO)
			v.global_position = scene.player.global_position + Vector2(120 + i * 26, -60 + i * 40)
			await get_tree().physics_frame
			v.note_hit({"source": StringName(kind_arg), "dir": Vector2(1, 0.2 * (i - 1)).normalized(), "force": 220.0, "by_player": true, "shot": kill_shot})
			v.take_damage(v.health + int(args.get("excess", "3")))
		for i in int(args.get("after", "12")):
			await get_tree().process_frame
		if args.has("hp"):
			scene.player.health = int(args["hp"])
			scene.player.health_changed.emit(scene.player.health, scene.player.max_health)
			for i in 20:
				await get_tree().process_frame
	if args.has("melee") and scene is HeistFloor:
		# A guard to knife from behind, and a staggered one.
		var src: Enemy = null
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not (e is Boss) and e.get_parent() is BuildingRoom:
				src = e
				break
		var p: Vector2 = scene.player.global_position
		var calm: Enemy = scene.spawn_companion(src, Enemy.Kind.GRUNT, Vector2.ZERO)
		calm.global_position = p + Vector2(32, 0)
		calm.set_post(calm.global_position)
		calm._provoked = false
		calm.sprite.global_rotation = 0.0
		var shaky: Enemy = scene.spawn_companion(src, Enemy.Kind.ENFORCER, Vector2.ZERO)
		shaky.global_position = p + Vector2(-60, 90)
		shaky.set_post(shaky.global_position)
		await get_tree().physics_frame
		shaky.take_damage(shaky.health - shaky.stagger_threshold())
		shaky.stagger_left = 30.0
		scene.player._update_melee(0.2)
		for i in 10:
			await get_tree().process_frame
	if args.has("heat") and scene is HeistFloor:
		scene.add_heat(float(args["heat"]), "Test")
		for i in 30:
			await get_tree().process_frame
	if args.has("hint"):
		Meta.hints_seen.clear()
		var hints := get_tree().root.find_children("*", "OnboardingHints", true, false)
		if not hints.is_empty():
			hints[0]._show(String(args["hint"]))
		for i in 30:
			await get_tree().process_frame
	if args.has("terminal"):
		var terminal := get_tree().get_first_node_in_group("market_terminal")
		if terminal:
			terminal.open_terminal()
		for i in 20:
			await get_tree().process_frame
	if args.has("debug"):
		get_node("/root/Debug").open()
		for i in 20:
			await get_tree().process_frame
	if args.has("pause"):
		var pause := get_tree().get_first_node_in_group("pause_menu")
		if pause:
			pause.open_pause()
		for i in 20:
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
			if not args.has("intro"):
				RunState.stage_intros = [0, 1, 2, 3]
			path = {"map": "res://map_ui_screen.tscn", "hideout": "res://hideout_room.tscn", "heist": "res://heist_floor.tscn"}[shot]
			if shot == "heist":
				var step = RunState.run_map.current()
				RunFlow.pending_heist = RunState.run_map.first_heist_option() if RunState.run_map.has_method("first_heist_option") else MapNode.new()
				if args.has("boss"):
					RunFlow.pending_heist = MapNode.new(MapNode.Type.BOSS)
					RunFlow.pending_heist.venue_id = &"bank_job"
					RunFlow.pending_heist.boss_id = StringName(args["boss"])
				if args.has("verdicts"):
					# verdicts=landlord:flip,auditor:execute
					for pair in String(args["verdicts"]).split(","):
						RunState.verdicts[pair.get_slice(":", 0)] = pair.get_slice(":", 1)
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
		"prologue":
			return Prologue.play(self, args.get("full", "1") == "1", int(args.get("slot", "0")))
		"ending":
			var seq := EndingSequence.new()
			seq.freeze_beneath = false
			seq.summary = {"heists": 12, "index": float(args.get("index", "420")), "gold": 1840, "kills": 96, "who": "The Operator", "clout": 42}
			seq.ending = StringName(args.get("id", "new_chairman" if float(seq.summary["index"]) >= Story.NEW_CHAIRMAN_INDEX else "seat_at_table"))
			get_tree().root.add_child(seq)
			var part := String(args.get("part", ""))
			if part in ["title", "credits"]:
				seq._show_title()
			if part == "credits":
				seq._roll_credits()
			return seq
		"specialist":
			var popup := SpecialistPopup.new()
			popup.ids = [StringName(args.get("who", "ghost"))]
			get_tree().root.add_child(popup)
			return popup
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
			r.show_result({"grade_name": args.get("grade", "A"), "stock_delta": 1.12, "loot": 184,
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
