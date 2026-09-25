extends Node
## End-to-end run through the real scene changes: Home -> case file -> crew
## (prologue) -> case wall (stage card) -> hideout -> a heist -> job report ->
## case wall -> the Doomsday quota sit-down -> the Chairman's job -> his death
## -> extraction -> THE NEW CHAIRMAN ending -> credits -> NEW SPECIALIST ->
## Home. The runner lives on the root so scene changes don't free it.
##   godot --headless --path . res://tests/full_loop.tscn

func _ready() -> void:
	var runner := Runner.new()
	runner.name = "FullLoopRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var passes := 0
	var failures := 0

	func check(ok: bool, what: String) -> void:
		if ok:
			passes += 1
			print("LOOP PASS: ", what)
		else:
			failures += 1
			push_error("LOOP FAILED: " + what)

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func _scene_is(path: String) -> bool:
		var s := get_tree().current_scene
		return s != null and s.scene_file_path == path and not Transition.busy

	func _wait_scene(path: String, seconds := 12.0) -> bool:
		var until := Time.get_ticks_msec() + int(seconds * 1000.0)
		while Time.get_ticks_msec() < until:
			if _scene_is(path):
				await get_tree().process_frame
				await get_tree().process_frame
				return true
			await get_tree().process_frame
		return false

	func _find(type_name: String) -> Node:
		var found := get_tree().root.find_children("*", type_name, true, false)
		return found[0] if not found.is_empty() else null

	func _run() -> void:
		Meta.reset()
		RunSave.slot = 0
		RunSave.delete_run()
		RunFlow.queue_scene("res://home_screen.tscn")
		check(await _wait_scene("res://home_screen.tscn"), "the game opens on the home screen")
		# Case files -> crew card: the prologue plays over the case wall.
		RunFlow.queue_scene("res://character_select.tscn")
		check(await _wait_scene("res://character_select.tscn"), "PLAY opens the case files")
		var select := get_tree().current_scene
		select._on_file_chosen(0)
		select._on_crew_chosen(CharacterSelect.CREW[0])
		check(await _wait_scene("res://map_ui_screen.tscn"), "hiring the Operator opens the case wall")
		var prologue := _find("Prologue") as Prologue
		check(prologue != null and prologue.full, "a case file's first run plays the whole prologue")
		if prologue:
			prologue._close()
		await get_tree().create_timer(0.7).timeout
		var intro := _find("StageIntro") as StageIntro
		check(intro != null and intro.stage == 0, "the Town intro card is on the case wall")
		if intro:
			intro._close()
		# The hideout, then back to the board for the first heist choice.
		get_tree().current_scene.map_ui._emit_hideout()
		check(await _wait_scene("res://hideout_room.tscn"), "the hideout opens")
		RunFlow.leave_hideout()
		check(await _wait_scene("res://map_ui_screen.tscn"), "walking out returns to the case wall")
		check(RunState.run_map.current_kind() == RunMap.StepKind.HEIST_CHOICE, "the first heist choice is up")
		get_tree().current_scene.map_ui._choose(0)
		check(await _wait_scene("res://heist_floor.tscn"), "choosing a case file starts the heist")
		var floor_scene := get_tree().current_scene as HeistFloor
		floor_scene.player._invulnerable = true
		floor_scene.player.global_position = floor_scene.generator.start_room.center_position()
		floor_scene.car.arm()
		await get_tree().create_timer(0.5).timeout
		floor_scene._extract()
		check(floor_scene.results._shown and get_tree().paused, "extraction shows the job report")
		floor_scene.results._on_continue()
		check(await _wait_scene("res://map_ui_screen.tscn"), "the job report returns to the case wall")
		check(RunFlow.heists_completed == 1 and RunState.run_map.current_step == 2, "the route moved past the heist")
		# Jump to Doomsday's sit-down with the collector, with the books in order.
		var map := RunState.run_map
		map.current_stage = 3
		map.quota_block = 3
		for i in map.stages[3].size():
			if map.stages[3][i].kind == RunMap.StepKind.QUOTA_GATE:
				map.current_step = i
				break
		RunState.stage_intros.append(3)
		RunEconomy.gold = int(map.current_quota()) + 500
		Debug.set_index(map.current_stock_quota() + 400.0)
		RunFlow.go_to_map()
		check(await _wait_scene("res://map_ui_screen.tscn"), "the Doomsday case wall opens")
		get_tree().current_scene._on_quota_faced()
		check(map.quota_block == 4 and map.current_kind() == RunMap.StepKind.SHOP, "the collector signs off on the books")
		# The Chairman's job: straight to the arena, then he falls.
		Debug._chairman_job()
		check(await _wait_scene("res://heist_floor.tscn", 15.0), "the Chairman's job starts")
		floor_scene = get_tree().current_scene as HeistFloor
		check(floor_scene.boss_id == &"chairman", "the Chairman is waiting")
		floor_scene.player._invulnerable = true
		await get_tree().create_timer(0.5).timeout
		floor_scene.debug_kill_boss()
		var chairman: Boss = floor_scene.boss
		check(chairman != null and chairman.kneeling, "the Chairman goes to his knees")
		floor_scene.open_verdict(chairman)
		var card: VerdictCard = floor_scene._verdict_card
		check(card != null and card._options == Verdicts.CHAIRMAN_OPTIONS and get_tree().paused, "the last VERDICT: seat, burn or walk")
		card.choose(Verdicts.SEAT)
		check(RunState.chairman_verdict == "seat" and not get_tree().paused, "TAKE THE SEAT")
		await get_tree().create_timer(5.0).timeout
		if not floor_scene.results._shown:
			floor_scene._extract()
		check(floor_scene.results._shown, "the last job report comes up")
		floor_scene.results._on_continue()
		await get_tree().create_timer(0.5).timeout
		var ending := _find("EndingSequence") as EndingSequence
		check(ending != null and ending.ending == &"new_chairman", "a high index takes the Chairman's seat")
		if ending == null:
			_finish()
			return
		ending._on_button()
		check(ending._stage == 1, "the epilogue gives way to the title")
		ending._on_button()
		check(ending._stage == 2 and Story.CREDITS_NAME in ending._credits.get_children().map(func(l): return l.text), "the credits roll")
		ending._on_button()
		var popup: SpecialistPopup = null
		for n: Node in get_tree().root.get_children():
			if n is SpecialistPopup:
				popup = n
		check(popup != null and &"legend" in popup.ids, "the first win unlocks the Legend")
		while popup and is_instance_valid(popup) and popup.is_inside_tree():
			popup._next()
			await get_tree().process_frame
		check(await _wait_scene("res://home_screen.tscn"), "the ending hands back to the home screen")
		check(not RunState.active and not RunSave.slot_has_run(0), "the run is over and its save is gone")
		check(int(Meta.stats.get("runs_won", 0)) == 1 and Meta.is_specialist_unlocked(&"legend"), "the career records the win")
		_finish()

	func _finish() -> void:
		print("LOOP passes: %d  failures: %d" % [passes, failures])
		print("FULL LOOP COMPLETE" if failures == 0 else "FULL LOOP FAILED")
		# Let late UI stamps land first, then stop every voice before quitting
		# so no playback outlives the audio server.
		await get_tree().create_timer(1.5).timeout
		Audio.silence()
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0 if failures == 0 else 1)
