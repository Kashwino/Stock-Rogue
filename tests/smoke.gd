extends Node
var floor_scene: HeistFloor
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("TEST FAILED: " + description)
		get_tree().quit(1)
		assert(condition, description)
	print("TEST PASS: " + description)
func _run() -> void:
	RunSave.slot = RunSave.SLOT_COUNT
	RunFlow.run_seed = 4817
	RunState.start_run(load("res://main_character.tres"), 4817)
	RunState.add_max_health(20)
	RunFlow.pending_heist = MapNode.new(MapNode.Type.BOSS)
	RunFlow.pending_heist.venue_id = &"bank_job"
	RunFlow.pending_heist.boss_id = &"auditor"
	check(ItemPool.weapons().size() == 24, "24 weapons in catalog (four boss uniques)")
	check(ItemPool.rewardable_weapons().size() == 16, "three career weapons gated from rewards")
	_test_progression()
	_test_modifiers()
	_test_route()
	check(ItemPool.upgrades().size() >= 9, "expanded upgrade pool")
	var weapon_ids: Dictionary = {}
	for weapon: WeaponItem in ItemPool.weapons():
		check(not weapon_ids.has(weapon.id), "unique weapon " + String(weapon.id))
		weapon_ids[weapon.id] = true
	floor_scene = load("res://heist_floor.tscn").instantiate()
	get_tree().root.add_child(floor_scene)
	get_tree().current_scene = floor_scene
	await get_tree().process_frame
	check(floor_scene.generator.rooms.size() == 8, "fixed eight-room Marlowe Exchange")
	await get_tree().physics_frame
	_test_doors()
	check(floor_scene.generator.start_room.name == &"Lobby", "authored lobby entrance")
	check(not floor_scene.generator.entrance.is_empty(), "accessible main door")
	var bosses := get_tree().get_nodes_in_group("boss")
	check(bosses.size() == 1 and bosses[0] is AuditorBoss, "one unique Auditor boss")
	var boss: AuditorBoss = bosses[0]
	check(boss.get_parent() == floor_scene.generator.boss_room, "Auditor occupies the authored boss room")
	var player := floor_scene.player
	player._invulnerable = true
	# Place inside the entrance to start the gameplay clock.
	player.global_position = floor_scene.generator.start_room.center_position()
	floor_scene.car.arm()
	floor_scene.director.refresh()
	await get_tree().create_timer(0.25).timeout
	check(floor_scene.active_elapsed > 0.0, "heist clock advances")
	var pause := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	RunState.loadout.consume_round()
	RunState.loadout.reload()
	pause.open_pause()
	var clock_before := floor_scene.active_elapsed
	var heat_before := floor_scene.heat
	var price_before := RunState.market.price_of(&"bank_job")
	var position_before := player.global_position
	await get_tree().create_timer(1.6, true).timeout
	check(get_tree().paused and floor_scene.active_elapsed == clock_before, "pause freezes grading time")
	check(floor_scene.heat == heat_before and RunState.market.price_of(&"bank_job") == price_before, "pause freezes heat and market")
	check(player.global_position == position_before and RunState.loadout.reloading, "pause freezes player and reload timer")
	check(pause._job != null and pause._job.find_children("*", "Label", true, false).size() >= 3, "the pause screen shows the job's case file")
	var pause_buttons := pause.menu.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(pause_buttons == ["RESUME", "SETTINGS", "QUIT TO MENU"], "pause offers Resume / Settings / Quit to Menu")
	pause._open_settings()
	check(pause._settings_box.visible and not pause.menu.visible, "settings open from the pause screen")
	pause.settings_panel.closed.emit()
	check(not pause._settings_box.visible and pause.menu.visible, "settings close back to the pause screen")
	check(PauseMenu.controls_text("pad").contains("RT fire") and PauseMenu.controls_text("keys").contains("R reload"), "the controls card follows the device")
	pause.close_pause()
	await get_tree().create_timer(1.7).timeout
	check(not RunState.loadout.reloading, "reload resumes after pause")
	await _test_onboarding()
	_test_fx_pools()
	_test_debug_menu()
	_test_time_controller()
	await _test_kill_feedback()
	await _test_kill_sounds()
	# Reload cancellation must never refill a replacement gun.
	RunState.loadout.consume_round()
	RunState.loadout.reload()
	RunState.loadout.equip(ItemPool.weapons()[1])
	check(not RunState.loadout.reloading, "equipping a chest weapon cancels stale reload")
	# Actual distance sleeping, hysteresis, and damage wake-up.
	var guard: Enemy = load("res://enemy.tscn").instantiate()
	guard.position = player.global_position + Vector2(5000, 0)
	floor_scene.add_child(guard)
	floor_scene.director.refresh()
	check(guard.sleeping and not guard.is_physics_processing(), "far guard physics sleeps")
	guard.global_position = player.global_position + Vector2(1200, 0)
	floor_scene.director.refresh()
	check(guard.sleeping, "sleep hysteresis avoids threshold churn")
	guard.take_damage(1)
	floor_scene.director.refresh()
	check(not guard.sleeping, "damage wakes a sleeping guard")
	guard.wake_until_msec = 0
	guard.global_position = player.global_position + Vector2(5000, 0)
	floor_scene.director.refresh()
	check(guard.sleeping, "guard sleeps again outside range")
	guard.global_position = player.global_position + Vector2(900, 0)
	floor_scene.director.refresh()
	check(not guard.sleeping, "near guard wakes")
	guard.queue_free()
	# Market operations: validate before spending, preserve changes in a save.
	RunEconomy.gold = 0
	var asset := RunState.market.get_asset(&"bank_job")
	var before := asset.current_price
	check(not MarketOps.execute("pump", &"bank_job")["ok"] and asset.current_price == before, "unaffordable trade is atomic")
	RunEconomy.gold = 500
	check(MarketOps.execute("pump", &"bank_job")["ok"], "pump executes")
	check(is_equal_approx(asset.current_price, before * 1.15) and RunEconomy.gold == 440, "pump cost and price")
	before = asset.current_price
	check(MarketOps.execute("short", &"bank_job")["ok"], "short executes")
	check(is_equal_approx(asset.current_price, before) and RunEconomy.gold == 365, "short escrows 75 without moving price or instant profit")
	check(not MarketOps.execute("short", &"bank_job")["ok"] and RunEconomy.gold == 365, "cannot double open a short")
	floor_scene.live.report_kill()
	check(asset.current_price < before and ShortBook.quote()["profit"] > 0, "kills make the active short profitable")
	before = asset.current_price
	floor_scene.live.report_damage_taken(1)
	check(asset.current_price > before, "taking damage hurts the short")
	var open_save := RunState.serialize(4817, 0, 0, 0)
	check(open_save["short_position"]["venue"] == "bank_job", "short position serializes")
	asset.current_price = float(RunState.short_position["entry"]) * 0.5
	var covered := ShortBook.settle(true)
	check(covered["payout"] == 225 and RunEconomy.gold == 590, "escape settles capped short proceeds")
	check(ShortBook.settle(true).is_empty() and RunEconomy.gold == 590, "short settles exactly once")
	check(MarketOps.execute("hedge", &"bank_job")["ok"] and RunState.hedge_charges == 3, "three-hit circuit breaker")
	check(not MarketOps.execute("hedge", &"bank_job")["ok"] and RunEconomy.gold == 490, "cannot double-buy active hedge")
	RunState.short_position = open_save["short_position"].duplicate(true)
	check(ShortBook.settle(false)["payout"] == 0 and RunEconomy.gold == 490, "death forfeits short collateral")
	floor_scene.live.report_damage_taken(1)
	check(RunState.hedge_charges == 2, "damage consumes hedge")
	RunState.add_perk(&"fast_hands")
	var saved := RunState.serialize(4817, 0, 0, 0)
	check(saved["hedge_charges"] == 2 and "fast_hands" in saved["perks"], "perk and hedge serialization")
	var terminal := get_tree().get_first_node_in_group("market_terminal") as MarketTerminal
	terminal.open_terminal()
	check(get_tree().paused and terminal.opened, "market terminal pauses gameplay")
	terminal._trade("pump")
	var gold_after_trade := RunEconomy.gold
	terminal._trade("pump")
	check(terminal.used and RunEconomy.gold == gold_after_trade, "terminal accepts only one trade per heist")
	terminal.close_terminal()
	check(not get_tree().paused, "terminal returns to active heist")
	await _test_security()
	floor_scene.fx.last_kill()
	check(Engine.time_scale < 1.0, "room finish slows action")
	await get_tree().create_timer(0.35, true, false, true).timeout
	check(Engine.time_scale == 1.0, "room finish restores normal speed")
	# Boss fight: walking in engages him, shutters seal the arena, the intro
	# gates damage, telegraphed attacks, phases, the AUDIT window, death.
	player.global_position = boss.arena.get_center() + Vector2(0, 160)
	boss.set_sleeping(false)
	boss._physics_process(0.02)
	check(boss.engaged and floor_scene.boss == boss, "walking into the arena engages the boss")
	check(floor_scene._shutters.size() > 0, "shutters seal the arena")
	check(floor_scene.hud.boss_bar.visible, "boss bar shows")
	var boss_hp := boss.health
	boss.take_damage(5)
	check(boss.health == boss_hp, "boss cannot be hurt during the intro")
	floor_scene._on_boss_intro_done()
	check(boss.intro_done and boss.desks.size() > 0, "the Auditor fights from behind desks")
	boss.attack = &"levy_wind"
	boss.clock = 0.0
	boss._physics_process(0.02)
	check(boss.attack == &"recover", "boss fires the levy and recovers")
	boss.attack = &"recover"
	boss.clock = 0.0
	boss._physics_process(0.02)
	check(boss.attack in [&"sweep_wind", &"levy_wind", &"drones"], "boss picks a telegraphed attack")
	boss._set_audit(true)
	check(floor_scene.live.damage_multiplier == 2.0 and floor_scene.audit_active, "AUDIT doubles the stock crash from hits")
	boss._set_audit(false)
	boss.health = boss.max_health / 2
	boss._physics_process(0.02)
	check(boss.phase == 2 and boss.invulnerable, "second phase opens with a beat of invulnerability")
	floor_scene._extract()
	check(not floor_scene._extracting, "boss heist cannot be skipped by extraction")
	boss.invulnerable = false
	boss._transition = 0.0
	boss.take_damage(9999)
	check(floor_scene.marked, "boss death marks heist and triggers reward")
	await get_tree().process_frame
	check(floor_scene._shutters.is_empty(), "the arena opens when the boss falls")
	var reward := floor_scene.find_children("*", "WorldChest", true, false).filter(func(c): return not c.fixed_items.is_empty())
	check(reward.size() == 1 and reward[0].fixed_items[0].id == &"red_pen", "the Auditor drops his unique weapon")
	check(ItemPool.boss_weapon(&"auditor") not in ItemPool.rewardable_weapons(), "boss uniques never enter reward pools")
	await get_tree().create_timer(0.2).timeout
	check(MarketOps.execute("short", &"bank_job")["ok"], "open final extraction contract")
	asset.current_price = float(RunState.short_position["entry"]) * 0.9
	var extraction_gold := RunEconomy.gold
	floor_scene._extract()
	check(get_tree().paused and floor_scene.results._shown, "extraction presents results while paused")
	check(RunEconomy.gold == extraction_gold + 105 and RunState.short_position.is_empty(), "real extraction pays short before grade movement")
	check(int(RunState.contract_counts.get("bank_job", 0)) == 1 and floor_scene.results._shown, "a finished CONTRACT counts toward repeat-venue decay")
	check(int(Meta.stats["heists_completed"]) == 1 and int(Meta.stats["bosses_killed"]) >= 1, "extraction records the career")
	floor_scene._extract()
	check(RunEconomy.gold == extraction_gold + 105 and int(Meta.stats["heists_completed"]) == 1, "duplicate extraction cannot duplicate gold or career stats")
	floor_scene.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	check(Engine.time_scale == 1.0, "scene exit restores time scale")
	await _test_lockdown()
	await _test_projectiles()
	await _test_bosses()
	await _test_objectives()
	await _test_build()
	_test_specialists()
	await _test_story()
	RunState.deserialize(saved)
	check(RunState.has_perk(&"fast_hands") and RunState.hedge_charges == 2, "perk and hedge deserialize")
	# Construct the remaining production screens to catch missing node references.
	RunState.start_run(load("res://main_character.tres"), 4817)
	RunFlow.practice = true
	for path: String in ["res://home_screen.tscn", "res://character_select.tscn", "res://map_ui_screen.tscn", "res://hideout_room.tscn"]:
		var scene: Node = load(path).instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().process_frame
		await get_tree().process_frame
		check(is_instance_valid(scene), "screen ready " + path)
		if path == "res://map_ui_screen.tscn":
			check(scene.find_children("*", "StageIntro", true, false).size() == 1 and 0 in RunState.stage_intros, "a stage opens with its intro card, once")
			scene.map_ui._maybe_stage_intro()
			check(scene.find_children("*", "StageIntro", true, false).size() == 1, "the stage intro never repeats")
		if path == "res://hideout_room.tscn":
			RunEconomy.gold = 2000
			for kind: StringName in [&"stocks", &"blackmarket"]:
				scene._open_station(kind)
				await get_tree().process_frame
				var panel: CanvasLayer = scene._active_panel
				var gold_before := RunEconomy.gold
				var purchase: Button = panel.find_children("*", "Button", true, false).filter(func(b): return b.text == "Buy")[0]
				purchase.pressed.emit()
				check(RunEconomy.gold < gold_before and purchase.disabled, "vendor sells an offer and debits gold: " + String(kind))
				scene._close_panel()
				scene._open_station(kind)
				check(scene._active_panel == panel and purchase.disabled, "reopening a vendor does not restock: " + String(kind))
				scene._close_panel()
			scene._open_station(&"weapons")
			await get_tree().process_frame
			check(scene._active_panel != null and scene._case_opened.size() == 3, "weapon dealer shows three sealed cases")
			scene._close_panel()
		scene.queue_free()
		await get_tree().process_frame
	RunState.end_run(false)
	await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	print("TEST SUITE COMPLETE")
	Audio.silence()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)

func _test_progression() -> void:
	Meta.reset()
	check(Meta.award_run("run-fixture", 2, 2, 130.0, false) == 12, "clout: stages x3 + bosses x2 + index / 60")
	check(Meta.award_run("run-fixture", 2, 2, 130.0, false) == 0 and Meta.clout == 12, "a run pays its clout once")
	check(Meta.award_run("won-fixture", 4, 4, 600.0, true) == 38, "retiring adds the win bonus")
	Meta.clout = 14
	check(Meta.purchase(&"circuit_smg") == "Unlocked permanently." and Meta.clout == 2, "weapon unlock spends Clout")
	check(ItemPool.rewardable_weapons().size() == 17, "purchased weapon enters reward pool")
	Meta.purchase(&"circuit_smg")
	check(Meta.clout == 2, "duplicate unlock does not spend")
	Meta.purchase(&"cool_head")
	check(Meta.clout == 2 and &"cool_head" not in Meta.unlocked_assets, "unaffordable unlock is atomic")
	# Specialists unlock through career feats, exactly as the cards say.
	check(Meta.check_unlocks().is_empty(), "no feats, no specialists")
	Meta.stats["fire_exit_escapes"] = 5
	Meta.stats["bosses_killed"] = 2
	check(Meta.check_unlocks() == [&"ghost"] and Meta.is_specialist_unlocked(&"ghost"), "five fire-exit escapes hire the Ghost")
	check(not Meta.is_specialist_unlocked(&"wolf") and Meta.unlock_progress(&"wolf") == "2 / 3", "the Wolf needs three bosses")
	Meta.stats["best_index"] = 351.0
	Meta.stats["runs_won"] = 1
	var hired := Meta.check_unlocks()
	check(&"broker" in hired and &"legend" in hired, "index 350 hires the Broker; a win hires the Legend")
	Meta.clout = 6
	Meta.purchase(&"coat_crimson")
	check(Meta.equip_coat(&"coat_crimson") and Meta.coat_color().a > 0.0, "coats can be bought and worn")
	Meta.load_meta()
	check(Meta.coat == &"coat_crimson" and &"ghost" in Meta.specialists, "career survives a reload")
	Meta.reset()

func _test_modifiers() -> void:
	var a := RunMap.new()
	var b := RunMap.new()
	a.generate(9182)
	b.generate(9182)
	var tags: Dictionary = {}
	var goals: Dictionary = {}
	for seed_value in [9182, 1234, 55, 8080]:
		var m := RunMap.new()
		m.generate(seed_value)
		for s in m.stages.size():
			for h in m.stages[s].size():
				for node: MapNode in m.stages[s][h].options:
					if node.is_boss():
						continue
					check(node.modifiers.size() <= 2, "at most two modifiers per lead")
					for mod in node.modifiers:
						tags[mod] = true
					goals[node.objective] = true
	for s in a.stages.size():
		for h in a.stages[s].size():
			for i in a.stages[s][h].options.size():
				var node: MapNode = a.stages[s][h].options[i]
				if node.is_boss():
					continue
				var twin: MapNode = b.stages[s][h].options[i]
				check(node.modifiers == twin.modifiers and node.objective == twin.objective and node.mystery == twin.mystery, "leads are deterministic per seed")
	check(tags.size() == 8, "all eight map modifiers appear")
	check(goals.size() == 6, "all six objectives appear")

func _test_security() -> void:
	var devices := get_tree().get_nodes_in_group("security")
	var cameras := 0
	var panels: Array = []
	for device: SecurityDevice in devices:
		if device.kind == SecurityDevice.Kind.ALARM:
			panels.append(device)
		else:
			cameras += 1
	check(cameras == floor_scene.generator.rooms.size() - 1, "every room but the lobby has a camera")
	check(panels.size() >= 1 and panels.size() <= 3, "one to three alarm panels per building")
	var panel: SecurityDevice = panels[0]
	var start_heat := floor_scene.heat
	floor_scene.security_alert(panel.room, "Test radio", 10.0)
	check(panel.armed and floor_scene.heat > start_heat, "witness report arms the nearest panel and adds heat")
	var room_cameras := 0
	for device: SecurityDevice in devices:
		if device.kind == SecurityDevice.Kind.CAMERA and device.room == panel.room:
			room_cameras += 1
	var before_cut := floor_scene.security_disabled
	# Holding USE next to the panel for 1.5 s cuts it.
	floor_scene.player.global_position = panel.global_position + Vector2(-60, 0)
	Input.action_press("interact")
	panel._physics_process(0.8)
	check(not panel.disabled and panel.hold > 0.0, "a short hold does not cut the panel")
	panel._physics_process(0.8)
	Input.action_release("interact")
	var count := floor_scene.security_disabled
	check(panel.disabled and count == before_cut + 1 + room_cameras and not panel.armed, "holding USE cuts the panel and its room cameras")
	panel.take_damage(999)
	check(floor_scene.security_disabled == count, "disabled security cannot be farmed")
	for device: SecurityDevice in devices:
		device.disable()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.radio_carrier = false
	floor_scene.heat = 0.0
	await get_tree().create_timer(0.7).timeout
	check(floor_scene.heat == 0.0, "no passive heat after security is disabled")
	var guard: Enemy = load("res://enemy.tscn").instantiate()
	floor_scene.add_child(guard)
	guard.set_physics_process(false)
	guard.radio_carrier = true
	guard._provoked = true
	guard.health = 20
	guard._radio_step(1.0, true)
	check(guard.radio_progress > 0.0 and guard.overhead.radio > 0.0, "radio call shows a progress bar")
	guard.take_damage(1)
	check(is_equal_approx(guard.radio_progress, 0.5), "a hit knocks the radio call back")
	guard._radio_step(1.6, true)
	check(floor_scene.heat > 0.0 and guard.radio_cooldown > 0.0, "completed guard radio call creates heat")
	guard.queue_free()
	await _test_enemies()
	floor_scene.modifiers = [&"heavy_police"]
	check(floor_scene.loot_multiplier() == 1.5 and floor_scene.dispatch_threshold() == 8.0, "heavy response: loot x1.5 and police respond sooner")
	var gold := RunEconomy.gold
	floor_scene._on_loot_collected(20)
	check(RunEconomy.gold == gold + roundi(30 * floor_scene.live_loot_multiplier()), "heavy response raises the actual pickup payout")
	floor_scene.modifiers = [&"payday", &"heavy_police"]
	check(is_equal_approx(floor_scene.loot_multiplier(), 2.25), "loot modifiers stack")
	floor_scene.modifiers = []
	await _test_market()

## Contracts vs hits, Fence positions, the live loot multiplier, the wire.
func _test_market() -> void:
	var asset := RunState.market.get_asset(&"bank_job")
	# Live loot multiplier follows the venue's price at the moment of pickup.
	asset.current_price = asset.base_price * 1.5
	check(is_equal_approx(floor_scene.live_loot_multiplier(), 1.5), "loot is worth more while the venue trades high")
	var gold := RunEconomy.gold
	floor_scene._on_loot_collected(20)
	check(RunEconomy.gold == gold + 30, "pickups pay value x live multiplier")
	asset.current_price = asset.base_price * 5.0
	check(floor_scene.live_loot_multiplier() == 2.0, "live multiplier clamps at 2.0")
	asset.current_price = asset.base_price
	# HIT jobs invert the tape.
	var before := asset.current_price
	floor_scene.live.hit_job = true
	floor_scene.live.report_kill()
	check(asset.current_price < before, "a kill on a HIT drives the venue down")
	before = asset.current_price
	floor_scene.live.report_damage_taken(1)
	check(asset.current_price > before, "damage taken on a HIT softens the crash")
	floor_scene.live.hit_job = false
	asset.current_price = asset.base_price
	# Map leads: roughly a third are HITs, deterministically per seed.
	var map_a := RunMap.new()
	map_a.generate(777)
	var map_b := RunMap.new()
	map_b.generate(777)
	var hits := 0
	var total := 0
	for st in map_a.stages.size():
		for h in map_a.stages[st].size():
			for i in map_a.stages[st][h].options.size():
				var node: MapNode = map_a.stages[st][h].options[i]
				if node.is_boss():
					continue
				total += 1
				hits += int(node.is_hit())
				check(node.contract == map_b.stages[st][h].options[i].contract, "contract type deterministic")
	check(hits > 0 and hits < total, "leads mix CONTRACTs and HITs")
	# Positions: stake, leverage, settlement, slots, save.
	RunEconomy.gold = 1000
	RunState.positions.clear()
	var short := Positions.open(&"bank_job", "short", 100)
	check(short["ok"] and RunEconomy.gold == 900, "a short stakes gold at the Fence")
	var casino := RunState.market.get_asset(&"casino_skim")
	check(Positions.open(&"casino_skim", "long", 100)["ok"], "a long opens alongside")
	check(not Positions.open(&"museum", "long", 100)["ok"] and RunEconomy.gold == 800, "two position slots, atomic refusal")
	asset.current_price *= 0.8
	casino.current_price *= 1.1
	var saved := RunState.serialize(4817, 0, 0, 0)
	check(saved["positions"].size() == 2, "positions are saved with the run")
	var settled := Positions.settle_all()
	var short_q: Dictionary = settled.filter(func(q): return q["side"] == "short")[0]
	var long_q: Dictionary = settled.filter(func(q): return q["side"] == "long")[0]
	check(short_q["value"] == 140 and long_q["value"] == 120, "payout = stake x (1 + 2 x move), inverted for shorts")
	check(RunEconomy.gold == 1060 and RunState.positions.is_empty(), "settlement pays out and closes the book")
	RunState.positions.clear()
	Positions.open(&"bank_job", "long", 100)
	asset.current_price *= 0.3
	check(Positions.settle_all()[0]["value"] == 0, "a blown position is floored at zero")
	asset.current_price = asset.base_price
	casino.current_price = casino.base_price
	# The wire: headlines move a venue now; rumors land at the end of the next job.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	RunState.news.clear()
	RunState.rumors.clear()
	for i in 12:
		MarketNews.roll(rng)
	check(not RunState.news.is_empty() and RunState.news.size() <= MarketNews.MAX_KEPT, "the wire keeps recent stories")
	RunState.rumors.append({"venue": "museum", "move": 0.2, "real": true, "text": "RUMOR"})
	var museum := RunState.market.get_asset(&"museum")
	var m_before := museum.current_price
	var resolved := MarketNews.resolve_rumors()
	check(resolved.size() >= 1 and is_equal_approx(museum.current_price, m_before * 1.2) and RunState.rumors.is_empty(), "a true rumor lands at the end of the job")
	for a: CriminalAsset in RunState.market.assets:
		a.current_price = a.base_price
	RunState.news.clear()

## Every archetype builds, runs its brain and respects its rules.
func _test_enemies() -> void:
	var player := floor_scene.player
	var origin: Vector2 = floor_scene.generator.start_room.center_position()
	player.global_position = origin
	var scene: PackedScene = load("res://enemy.tscn")
	check(Enemy.Kind.size() >= 17, "seventeen guard archetypes")
	var spawned: Array = []
	for k in Enemy.Kind.values():
		var e: Enemy = scene.instantiate()
		e.position = origin + Vector2(260, 0).rotated(TAU * spawned.size() / 17.0)
		floor_scene.add_child(e)
		e.apply_archetype(k)
		e.health = 999
		e.max_health = 999
		e.hunting = true
		spawned.append(e)
		check(e.kit != null and e.kind == k, "archetype dressed: " + e.kind_name())
	var drone: Enemy = spawned[Enemy.Kind.DRONE]
	check(drone.collision_layer == Layers.FLYERS and drone.collision_mask == Layers.WALLS, "drones fly over furniture")
	for i in 40:
		await get_tree().physics_frame
	for e: Enemy in spawned:
		check(is_instance_valid(e), "archetype survives its brain: " + e.kind_name())
	# Riot shield: stops rounds from the front, not from behind.
	var riot: Enemy = spawned[Enemy.Kind.RIOT]
	riot.brain.state = 0
	riot.brain.facing = 0.0
	check(riot.deflects(Vector2.LEFT), "riot shield deflects frontal fire")
	check(not riot.deflects(Vector2.RIGHT), "riot shield is open from behind")
	# The handler brought his dog.
	var handler: Enemy = spawned[Enemy.Kind.HANDLER]
	check(is_instance_valid(handler.brain.dog) and handler.brain.dog.kind == Enemy.Kind.DOG, "K9 handler deploys a dog")
	for e: Enemy in spawned:
		e.set_physics_process(false)
		e.queue_free()
	if is_instance_valid(handler.brain.dog):
		handler.brain.dog.queue_free()
	await get_tree().process_frame
	# Elites: shielded bubble eats hits, then the body takes them.
	var elite: Enemy = scene.instantiate()
	elite.position = origin + Vector2(2000, 2000)
	floor_scene.add_child(elite)
	elite.apply_archetype(Enemy.Kind.ENFORCER)
	elite.make_elite(&"shielded")
	check(elite.elite and elite.max_health == 8 and elite.elite_tag.begins_with("SHIELDED"), "elite gets health and a name tag")
	for i in Enemy.SHIELD_MAX:
		elite.take_damage(1)
	check(elite.health == elite.max_health, "shield bubble absorbs hits")
	elite.take_damage(1)
	check(elite.health == elite.max_health - 1, "hits land once the bubble is down")
	elite.take_damage(999)
	await get_tree().process_frame
	check(floor_scene.find_children("*", "LootPickup", true, false).size() > 0, "elites drop a valuable")
	# Blasts hurt guards too.
	var victim: Enemy = scene.instantiate()
	victim.position = origin + Vector2(3000, 0)
	floor_scene.add_child(victim)
	victim.apply_archetype(Enemy.Kind.BRUTE)
	var hp := victim.health
	Blast.detonate(floor_scene, victim.global_position + Vector2(30, 0), 90.0, 2, 3)
	check(victim.health == hp - 3, "grenade blasts hurt guards")
	victim.queue_free()
	# A security tech reaching a panel raises the alarm and calls a van.
	var panel := floor_scene._add_device(floor_scene.generator.rooms[1], SecurityDevice.Kind.ALARM, Vector2(300, 200))
	var tech: Enemy = scene.instantiate()
	tech.position = panel.position + Vector2(-40, 0)
	floor_scene.add_child(tech)
	tech.apply_archetype(Enemy.Kind.TECH)
	var alarms := floor_scene.alarms_raised
	var heat := floor_scene.heat
	tech._provoked = true
	check(tech.brain.running and tech.overhead.alarm, "provoked tech runs for the alarm")
	tech.brain._run(0.016)
	check(floor_scene.alarms_raised == alarms + 1 and floor_scene.heat > heat, "tech at the panel raises the alarm")
	tech.queue_free()
	panel.queue_free()
	# Civilians: killing one is heat, a venue crash and a grade penalty.
	var civ := Civilian.new()
	civ.position = origin + Vector2(-3000, 0)
	floor_scene.add_child(civ)
	heat = floor_scene.heat
	civ.take_damage(5)
	check(floor_scene.civilians_killed == 1 and floor_scene.heat > heat, "civilian death is heat and a grade penalty")
	var clean := HeistGrader.grade_heist({"hits_taken": 0, "shots_fired": 10, "shots_hit": 10, "kills": 5, "enemies_total": 5, "time_seconds": 10.0, "par_time": 60.0})
	var dirty := HeistGrader.grade_heist({"hits_taken": 0, "shots_fired": 10, "shots_hit": 10, "kills": 5, "enemies_total": 5, "time_seconds": 10.0, "par_time": 60.0, "civilians": 2})
	check(dirty["score"] < clean["score"], "civilian kills lower the grade")
	floor_scene.civilians_killed = 0
	# Bullets are pooled: a spent round is reused.
	var pool := floor_scene.bullet_pool
	var created := pool.created
	var b: Node = BulletPool.take(player, player.bullet_scene)
	b.global_position = origin
	b.setup(Vector2.RIGHT, player)
	b._finish()
	var again: Node = BulletPool.take(player, player.bullet_scene)
	check(again == b and pool.created <= created + 1, "spent bullets return to the pool")
	again._finish()
	floor_scene.heat = 0.0

## A regular job built for each objective and a few modifiers.
func _job(objective: StringName, mods: Array = [], contract: StringName = &"contract") -> HeistFloor:
	RunFlow.pending_heist = MapNode.new(MapNode.Type.HEIST)
	RunFlow.pending_heist.venue_id = &"corner_racket"
	RunFlow.pending_heist.room_rarity = 1
	RunFlow.pending_heist.objective = objective
	RunFlow.pending_heist.modifiers = mods
	RunFlow.pending_heist.modifier = mods[0] if not mods.is_empty() else &""
	RunFlow.pending_heist.contract = contract
	var job: HeistFloor = load("res://heist_floor.tscn").instantiate()
	get_tree().root.add_child(job)
	get_tree().current_scene = job
	await get_tree().physics_frame
	job.player._invulnerable = true
	return job

func _test_objectives() -> void:
	var job := await _job(&"assassination")
	check(is_instance_valid(job.vip) and job.vip.elite_tag.begins_with("TARGET"), "assassination plants a named VIP")
	check(job.objective_points().size() == 1 and not job.objective_success(), "the VIP is marked on the map")
	job.vip.shield_hp = 0
	job.vip.take_damage(99999)
	check(job.objective_success(), "killing the VIP completes the job")
	var paid := job._resolve_objective()
	check(paid["success"] and int(paid["gold"]) > 0, "the bounty pays out")
	job.queue_free()
	await get_tree().process_frame
	job = await _job(&"smash_grab")
	check(job.jackpots.size() >= 2, "smash and grab marks jackpot rooms")
	job._tick_objective(0.1)
	check(job._smash_started and job.heat >= job.dispatch_threshold() and job._lockdown_clock > 0.0, "the alarm is already ringing on entry")
	job._lockdown_clock = 0.01
	job._tick_objective(0.1)
	var open_exits := job.generator.exits.filter(func(g): return g.get("open", false))
	check(open_exits.is_empty() and job.generator.entrance.get("open", true), "lockdown seals every fire exit, never the main door")
	for m in job.jackpots:
		for i in 3:
			job._on_jackpot_piece(10, m)
	check(job.objective_success(), "looting every jackpot room completes it")
	job.queue_free()
	await get_tree().process_frame
	job = await _job(&"ghost", [&"blackout"])
	check(job.objective_success(), "a ghost run starts clean")
	var guard: Enemy = get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_parent() is BuildingRoom and e.kind == Enemy.Kind.GRUNT).front()
	if guard:
		check(guard.sight_range < 420.0, "blackout cuts guard sight")
	job.security_alert(job.generator.rooms[1], "Test", 1.0)
	check(not job.objective_success(), "one alarm blows a ghost run")
	job.queue_free()
	await get_tree().process_frame
	job = await _job(&"sabotage", [], &"hit")
	check(job.charges.size() >= 2 and job.hit_job, "sabotage places charges (a HIT)")
	for c in job.charges:
		c.done = true
		c.planted.emit(c)
	check(job.objective_success() and job.charges_planted == job.charges.size(), "planting every charge completes it")
	job.queue_free()
	await get_tree().process_frame
	job = await _job(&"package", [&"payday"])
	check(is_instance_valid(job.package), "the package waits in a far room")
	var speed := job.player.move_speed
	job.package.carried = true
	job.package.picked_up.emit(job.package)
	check(job.carrying_package and job.player.move_speed < speed, "carrying the package slows you")
	check(job.objective_success(), "delivering the package is the job")
	job.queue_free()
	await get_tree().process_frame
	job = await _job(&"loot", [&"rival_crew", &"camera_network"])
	check(job.rivals.size() >= 3, "rival crew brings 3-4 rivals")
	check(job.rivals.all(func(r): return r.faction == &"rival"), "rivals are their own faction")
	var cams := get_tree().get_nodes_in_group("security").filter(func(d): return d.kind == SecurityDevice.Kind.CAMERA)
	check(cams.size() == (job.generator.rooms.size() - 1) * 2, "camera network doubles the cameras")
	var r: Enemy = job.rivals[0]
	var g: Enemy = get_tree().get_nodes_in_group("enemies").filter(func(e): return e.faction == &"guard" and e.is_inside_tree()).front()
	job.player.global_position = r.global_position + Vector2(0, 600)
	g.global_position = r.global_position + Vector2(90, 0)
	job.director.refresh()
	r._retarget_clock = 0.0
	r._retarget(0.1)
	check(r._player == g, "rivals go after guards")
	job.queue_free()
	await get_tree().process_frame
	# Gear for the next job: body armor eats the first hit.
	RunState.job_gear = [&"body_armor"]
	job = await _job(&"loot")
	job.player._invulnerable = false
	var hp := job.player.health
	job.player.take_damage(1)
	check(job.player.health == hp and job.player.armor_charges == 0, "body armor absorbs the first hit")
	RunState.job_gear.clear()
	job.queue_free()
	await get_tree().process_frame

## Relics, weapon mods and weapon traits.
func _test_build() -> void:
	check(Relics.DATA.size() >= 20 and Relics.all().size() == Relics.DATA.size(), "twenty relics in the catalog")
	for w: WeaponItem in ItemPool.weapons():
		check(w.trait_text() != "", "signature trait: " + w.display_name)
	RunState.relics.clear()
	RunState.add_relic(&"laundered_cash")
	RunState.add_relic(&"laundered_cash")
	RunState.add_relic(&"hedge_fund")
	RunState.add_relic(&"hedge_fund")
	check(RunState.relic_count(&"laundered_cash") == 2 and RunState.relic_count(&"hedge_fund") == 1, "stacking relics stack, others don't")
	var job := await _job(&"loot")
	check(is_equal_approx(job.loot_multiplier(), 1.15 * 1.15), "laundered cash compounds loot")
	RunState.relics.clear()
	var p := job.player
	var lo := RunState.loadout
	# Weapon mods: fit to the active weapon, change its numbers, and are saved.
	lo.set_active("small", 0)
	var sidearm := lo.get_active()
	sidearm.mods.clear()
	check(WeaponMods.install(&"extended_mag") == sidearm and sidearm.eff_mag() == int(ceil(sidearm.mag_size * 1.5)), "extended mag fits the active weapon (+50%)")
	check(not sidearm.can_take_mod(&"laser_sight"), "small weapons take a single mod")
	var saved := RunState.serialize(1, 0, 0, 0)
	sidearm.mods.clear()
	lo.restore_mods(saved["loadout"]["mods"])
	check(sidearm.has_mod(&"extended_mag"), "mods are saved with the weapon")
	sidearm.mods = [&"suppressor"]
	check(is_equal_approx(sidearm.eff_noise(), sidearm.noise_radius * 0.4), "suppressor cuts noise")
	sidearm.mods.clear()
	# Blood Ledger refunds a round on a kill; Hair Trigger doubles the next shot.
	RunState.add_relic(&"blood_ledger")
	lo.consume_round()
	var mag_before := int(lo._active_ammo()["mag"])
	job.hooks.kill.emit(null)
	check(int(lo._active_ammo()["mag"]) == mag_before + 1, "blood ledger puts a round back")
	RunState.add_relic(&"hair_trigger")
	job.hooks.reload.emit()
	check(p.hair_trigger, "hair trigger arms on reload")
	# Golden Parachute catches one lethal hit per run.
	RunState.add_relic(&"golden_parachute")
	p._invulnerable = false
	p._mercy_timer = 0.0
	p.health = 1
	p.take_damage(3)
	check(p.health == 1 and RunState.parachute_used and not p.is_dead(), "golden parachute leaves you at 1 HP")
	p._mercy_timer = 0.0
	RunState.add_relic(&"adrenaline_futures")
	var w := lo.get_active()
	check(p.effective_fire_interval(w) < w.fire_rate, "adrenaline futures fires faster at 1 HP")
	p._invulnerable = true
	p.health = p.max_health
	# Positional and passive relics.
	RunState.add_relic(&"back_door_man")
	RunState.add_relic(&"market_maker")
	check(job.fire_exit_limit() == 20.0, "back door man keeps fire exits open to heat 20")
	check(Positions.slots() == 3 and is_equal_approx(Positions.leverage(), 2.5), "market maker adds a slot and leverage")
	RunState.add_relic(&"fences_discount")
	check(HideoutRoom._price(100) == 85, "fence's discount takes 15% off")
	RunState.add_relic(&"second_wind")
	p.health = p.max_health - 1
	job.hooks.room_cleared.emit(job.generator.rooms[1])
	job.hooks.room_cleared.emit(job.generator.rooms[1])
	check(p.health == p.max_health, "second wind heals once per job")
	RunState.add_relic(&"paper_trail")
	var bank := RunState.market.get_asset(&"bank_job")
	var price := bank.current_price
	job.hooks.extract.emit({"grade_name": "A"})
	check(is_equal_approx(bank.current_price, price * 1.02), "paper trail lifts every venue on an A")
	RunState.add_relic(&"insider_wire")
	job._show_vision_cones()
	var coned := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.sprite and e.sprite.has_node("VisionCone"))
	check(not coned.is_empty(), "insider wire shows vision cones")
	# Traits and mods on the bullet.
	var guard: Enemy = load("res://enemy.tscn").instantiate()
	guard.position = p.global_position + Vector2(4000, 4000)
	job.add_child(guard)
	guard.apply_archetype(Enemy.Kind.GRUNT)
	guard.health = 50
	var b: Bullet = load("res://bullet.tscn").instantiate()
	job.add_child(b)
	b.damage = 2
	b.weapon = ItemPool.weapons().filter(func(x): return x.id == &"rifle")[0]
	check(b._damage_against(guard) == 6, "the marksman rifle crits an unprovoked guard x3")
	guard._provoked = true
	check(b._damage_against(guard) == 2, "no crit once he's onto you")
	b.weapon.mods = [&"hollow_points"]
	check(b._damage_against(guard) == 3, "hollow points +1 against the unarmoured")
	guard.armored = true
	check(b._damage_against(guard) == 1, "hollow points -1 against armour")
	guard.ignite(3.0)
	var hp := guard.health
	guard._tick_burn(1.05)
	check(guard.health == hp - 1, "incendiary rounds burn")
	guard.red_marked = true
	hp = guard.health
	guard.take_damage(1)
	check(guard.health == hp - 2, "the red pen's mark adds +1 to every hit")
	b.queue_free()
	guard.queue_free()
	# Burst carbine: one pull, three rounds.
	var carbine: WeaponItem = ItemPool.weapons().filter(func(x): return x.id == &"burstcarbine")[0]
	lo.equip(carbine)
	var fired := p.shots_fired
	p._fire_timer = 0.0
	Input.action_press("fire")
	p._try_fire()
	Input.action_release("fire")
	for i in 20:
		p._tick_burst(0.05)
	check(p.shots_fired - fired == 3, "the burst carbine fires three-round bursts")
	RunState.relics.clear()
	RunState.parachute_used = false
	job.queue_free()
	await get_tree().process_frame

## Every stage boss: signature building, engagement, phases, death. And an
## ordinary job's titled lieutenant.
func _test_bosses() -> void:
	RunFlow.pending_heist = MapNode.new(MapNode.Type.HEIST)
	RunFlow.pending_heist.venue_id = &"corner_racket"
	RunFlow.pending_heist.room_rarity = 2
	var job: HeistFloor = load("res://heist_floor.tscn").instantiate()
	get_tree().root.add_child(job)
	get_tree().current_scene = job
	await get_tree().physics_frame
	check(is_instance_valid(job.lieutenant) and job.lieutenant.lieutenant and job.lieutenant.elite, "ordinary jobs keep a titled lieutenant")
	check(job.lieutenant.get_parent() == job.generator.boss_room and job.lieutenant.elite_tag.contains("\""), "the lieutenant runs the boss room under his name")
	var lt := job.lieutenant
	var kills_before := int(Meta.stats["bosses_killed"])
	lt.shield_hp = 0
	lt.take_damage(99999)
	check(int(Meta.stats["bosses_killed"]) == kills_before + 1, "a lieutenant kill counts toward the career")
	job.queue_free()
	await get_tree().process_frame
	for id: StringName in [&"landlord", &"ambassador", &"chairman"]:
		RunFlow.pending_heist = MapNode.new(MapNode.Type.BOSS)
		RunFlow.pending_heist.venue_id = &"bank_job"
		RunFlow.pending_heist.boss_id = id
		var heist: HeistFloor = load("res://heist_floor.tscn").instantiate()
		get_tree().root.add_child(heist)
		get_tree().current_scene = heist
		await get_tree().physics_frame
		var b: Boss = heist.generator.boss_room.get_children().filter(func(c): return c is Boss)[0]
		check(b.boss_id == id, "signature building hosts " + String(id))
		check(heist.generator.boss_room.get_meta("authored_title", "") != "", "authored arena for " + String(id))
		heist.player._invulnerable = true
		heist.player.global_position = b.arena.get_center() + Vector2(0, 170)
		b._physics_process(0.02)
		check(b.engaged and heist._shutters.size() > 0, String(id) + " engages and seals the arena")
		heist._on_boss_intro_done()
		for i in 120:
			await get_tree().physics_frame
		check(is_instance_valid(b) and not b._dead and b.intro_done, String(id) + " fights without errors")
		b.health = int(b.max_health * 0.15)
		for i in 5:
			await get_tree().physics_frame
		check(b.phase == b.thresholds.size() + 1, String(id) + " reaches its final phase")
		b._transition = 0.0
		b.invulnerable = false
		b.immune_reason = ""
		for g in b.get_parent().get_children():
			if g is Enemy and g != b:
				g.queue_free()
		b.take_damage(99999)
		check(heist.marked and b._dead, String(id) + " death marks the heist")
		heist.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

## The four specialists play as their cards say.
func _test_specialists() -> void:
	var ghost: CharacterProfile = load("res://crew_ghost.tres")
	RunState.start_run(ghost, 77)
	var weapons := (RunState.loadout.big + RunState.loadout.small).filter(func(w): return w != null).map(func(w): return w.id)
	check(RunState.max_health == 2 and &"silenced9mm" in weapons, "the Ghost: two hearts and a Silenced 9mm")
	check(RunState.profile_value("gunshot_noise", 1.0) == 0.6 and RunState.profile_value("camera_spot_rate", 1.0) == 0.5, "the Ghost: quieter shots, slower cameras")
	var broker: CharacterProfile = load("res://crew_broker.tres")
	RunState.start_run(broker, 77)
	check(Positions.slots() == 3 and Positions.leverage() == 3.0, "the Broker: three positions at leverage 3")
	var legend: CharacterProfile = load("res://crew_legend.tres")
	RunState.start_run(legend, 77)
	var best := (RunState.loadout.big + RunState.loadout.small).filter(func(w): return w != null and w.id != &"pistol")
	check(RunState.max_health == 1 and not best.is_empty() and int(best[0].rarity) >= Rarity.Tier.CLASSIFIED, "the Legend: one heart and a Classified-or-better gun")
	var gold := RunEconomy.gold
	RunEconomy.add_bonus(50)
	check(RunEconomy.gold == gold + 100, "the Legend doubles gold gains")
	RunState.health = 1
	RunState.heal(1)
	check(RunState.health == 1, "the Legend is never healed")
	var wolf: CharacterProfile = load("res://crew_wolf.tres")
	RunState.start_run(wolf, 77)
	check(RunState.max_health == 4 and RunState.profile_value("damage_mult", 1.0) == 1.25, "the Wolf: four hearts, +25% damage")
	RunState.start_run(load("res://main_character.tres"), 4817)

func _test_time_controller() -> void:
	TimeController.clear()
	TimeController.slow_mo(1.0, 0.35)
	check(is_equal_approx(Engine.time_scale, 0.35), "slow-mo request applies at once")
	TimeController.hit_stop(0.05)
	check(is_equal_approx(Engine.time_scale, TimeController.HITSTOP_SCALE), "hit-stop outranks slow-mo instead of multiplying")
	TimeController._requests[1]["until"] = Time.get_ticks_usec() - 1
	TimeController._apply()
	check(is_equal_approx(Engine.time_scale, 0.35), "when hit-stop ends the slow-mo resumes")
	get_tree().paused = true
	TimeController._apply()
	check(Engine.time_scale == 1.0 and TimeController._requests.is_empty(), "nothing runs slow while paused")
	TimeController.hit_stop(0.1)
	check(TimeController._requests.is_empty(), "no requests are taken while paused")
	get_tree().paused = false
	TimeController.slow_mo(0.5, 0.2, &"swell")
	TimeController.release(&"swell")
	check(Engine.time_scale == 1.0, "a released request restores normal speed")
	TimeController.clear()

func _test_kill_feedback() -> void:
	# Classification from the killing hit.
	var cases := [
		[{"source": &"bullet", "by_player": true}, 0, KillInfo.STANDARD],
		[{"source": &"bullet", "by_player": true}, 2, KillInfo.OVERKILL],
		[{"source": &"bullet", "by_player": true, "pellets": 6, "point_blank": true}, 0, KillInfo.OVERKILL],
		[{"source": &"bullet", "by_player": true, "weapon": &"handcannon"}, 0, KillInfo.OVERKILL],
		[{"source": &"bullet", "by_player": true, "unprovoked": true}, 0, KillInfo.CRIT],
		[{"source": &"bullet", "by_player": true, "crit": true}, 1, KillInfo.CRIT],
		[{"source": &"blast", "by_player": true}, 0, KillInfo.EXPLOSIVE],
		[{"source": &"burn", "by_player": true}, 0, KillInfo.BURN],
		[{"source": &"takedown", "by_player": true, "stealth": true}, 0, KillInfo.TAKEDOWN],
	]
	for c: Array in cases:
		check(KillInfo.classify(null, c[0], c[1]).kill_class == c[2], "kill class %s from %s" % [c[2], c[0]])
	check(KillInfo.classify(null, {"source": &"bullet", "by_player": false, "unprovoked": true}, 0).kill_class == KillInfo.STANDARD, "a guard's kill on a guard is no crit")
	# A real kill in the heist: classified, the body slides, feedback fires.
	var player := floor_scene.player
	var owner: Enemy = null
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not (e is Boss) and e.get_parent() is BuildingRoom:
			owner = e
			break
	var victims: Array = []
	for i in 2:
		var v := floor_scene.spawn_companion(owner, Enemy.Kind.GRUNT, Vector2(0, 0))
		v.global_position = player.global_position + Vector2(140 + i * 30, 0)
		victims.append(v)
	await get_tree().physics_frame
	var chain_before := floor_scene.kills.chain
	var shot := KillInfo.next_shot_id()
	for v: Enemy in victims:
		v.note_hit({"source": &"bullet", "dir": Vector2.RIGHT, "force": 180.0, "by_player": true, "shot": shot})
		v.take_damage(v.health + 3)
	var first: KillInfo = victims[0].kill_info
	check(first != null and first.kill_class == KillInfo.OVERKILL and first.by_player, "a player kill is classified on death")
	check(first.corpse != null and first.corpse.velocity.x > 60.0, "the body slides along the shot")
	check(floor_scene.kills.chain >= 2 and victims[1].kill_info.multi >= 2, "two kills from one shot chain into a MULTI")
	check(floor_scene.hud.multi_banner.modulate.a > 0.5 and floor_scene.hud.multi_banner._label.text == "DOUBLE", "the DOUBLE banner shows")
	check(TimeController.has(&"hit_stop"), "a kill asks TimeController for hit-stop")
	check(floor_scene.crosshair._mark.marker_kill, "the crosshair marker turns into the kill X")
	await get_tree().create_timer(1.2).timeout
	check(first.corpse.is_still() and first.corpse.velocity == Vector2.ZERO, "the body settles")
	var skitter: Node = first.corpse.weapon
	check(skitter != null and is_instance_valid(skitter) and skitter.global_position.distance_to(first.corpse.global_position) > 4.0, "the dropped gun skitters off on its own")
	TimeController.clear()
	check(chain_before >= 0 and HudWidgets.MultiBanner.title_for(3) == "TRIPLE" and HudWidgets.MultiBanner.title_for(5) == "MASSACRE", "multi titles")

func _test_kill_sounds() -> void:
	for id: String in ["flesh_1", "flesh_2", "flesh_3", "flesh_4", "bone_crunch", "splatter", "gib_burst",
			"fall_concrete", "fall_carpet", "fall_marble", "fall_metal", "clatter", "kill_tick", "crit_ding",
			"burn_sizzle", "takedown_knife", "takedown_crack", "multi_2", "multi_3", "multi_4"]:
		check(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % id), "kill sound generated: " + id)
	check(floor_scene.floor_surface() in Audio.FLOORS, "bodies land on the stage's floor")
	Audio.silence()
	var info := KillInfo.classify(null, {"source": &"bullet", "by_player": true}, 3)
	info.position = floor_scene.player.global_position
	info.multi = 2
	Audio.play_kill(info, "marble")
	check(Audio._live_voices("flesh").size() == 1 and Audio._live_voices("bone_crunch").size() == 1, "an overkill plays impact and bone crunch")
	check(Audio._live_voices("kill_tick").size() == 1 and Audio._live_voices("multi_2").size() == 1, "the player's kill ticks and a double stings")
	await get_tree().create_timer(0.7).timeout
	check(Audio._live_voices("fall_marble").size() == 1, "the body lands a beat later, on the floor it fell on")
	for i in 12:
		Audio.play_kill(info, "concrete")
	check(Audio.group_voices("death") <= Audio.GROUP_LIMITS["death"], "a massacre never stacks more than six death layers")
	await get_tree().create_timer(0.15).timeout
	check(Audio._duck_fx != null and Audio._duck_fx.volume_db < -1.0, "overkills duck the music")
	Audio.silence()

func _test_debug_menu() -> void:
	var debug := get_node("/root/Debug")
	check(debug.available(), "the debug menu is available in debug builds")
	debug.open()
	var labels: Array = debug._root.find_children("*", "Button", true, false).map(func(b): return b.text)
	for want: String in ["+$500", "INDEX 120", "DOOMSDAY", "THE CHAIRMAN'S JOB", "AUDITOR", "BUSTED", "RETIRED", "THE NEW CHAIRMAN", "SPAWN", "SPAWN ELITE", "KILL BOSS"]:
		check(want in labels, "debug menu offers " + want)
	check(get_tree().paused, "the debug menu pauses while open")
	var gold := RunEconomy.gold
	debug._add_gold(500)
	check(RunEconomy.gold == gold + 500, "debug adds gold")
	var index := RunState.empire_index()
	debug._set_index(350.0)
	check(absf(RunState.empire_index() - 350.0) < 0.5, "debug sets the Board index")
	debug.set_index(index)
	var before := get_tree().get_nodes_in_group("enemies").size()
	debug._kind.select(debug._kind.get_item_index(Enemy.Kind.SNIPER))
	debug._spawn_enemy(true)
	var spawned := get_tree().get_nodes_in_group("enemies")
	check(spawned.size() == before + 1, "debug spawns a guard next to the player")
	check(not debug.opened and not get_tree().paused, "spawning closes the menu and unpauses")
	var newest: Enemy = null
	for e: Enemy in spawned:
		if e.kind == Enemy.Kind.SNIPER and e.elite_tag != "":
			newest = e
	check(newest != null, "the spawned guard is the chosen kind, as an elite")
	if newest:
		newest.queue_free()

func _test_fx_pools() -> void:
	var fx := floor_scene.fx
	var at := floor_scene.player.global_position
	for i in 120:
		fx.casing(at, Vector2.RIGHT)
		fx.bullet_hole(at)
		fx.spark(at, Vector2.UP)
		fx.blood(at, Vector2.LEFT)
	check(fx._casings.size() == CombatFX.CASING_CAP and fx._holes.size() == CombatFX.HOLE_CAP, "casings and bullet holes are pooled at their caps")
	check(fx._sparks.size() == CombatFX.SPARK_CAP and fx._blood.size() == CombatFX.BLOOD_CAP, "sparks and blood are pooled at their caps")
	var first: Node = fx._casings[0]
	fx.casing(at, Vector2.RIGHT)
	check(is_instance_valid(first) and fx._casings.size() == CombatFX.CASING_CAP, "a full pool reuses its oldest node instead of freeing it")

func _test_onboarding() -> void:
	var player := floor_scene.player
	var hints_nodes := floor_scene.find_children("*", "OnboardingHints", true, false)
	check(hints_nodes.size() == 1, "a fresh save's heist carries onboarding hints")
	var hints: OnboardingHints = hints_nodes[0]
	for device: String in ["keys", "pad", "touch"]:
		for id: String in OnboardingHints.ORDER:
			var words := OnboardingHints.text(id, device)
			check(words[0] != "" and words[1] != "", "hint %s reads on %s" % [id, device])
	check(OnboardingHints.text("reload", "pad")[1].begins_with("X") and OnboardingHints.text("reload", "keys")[1].begins_with("R"), "hints name the right button")
	check(hints._due("move") and hints._due("provoke"), "move and provoke hints come due inside the building")
	await get_tree().create_timer(1.2).timeout
	var first := hints._showing
	check(first != "" and first in Meta.hints_seen, "the first hint that comes due shows and is remembered")
	check(not Meta.take_hint(first), "a seen hint never shows again")
	hints._clock = 0.0
	await get_tree().create_timer(0.8).timeout
	check("move" in Meta.hints_seen and "provoke" in Meta.hints_seen, "hints queue one after another")
	# Controller: the right stick aims, and the last device drives prompts.
	var pad_event := InputEventJoypadButton.new()
	pad_event.pressed = true
	TouchInput._input(pad_event)
	check(TouchInput.device() == "pad", "a controller button switches prompts to the controller")
	Input.action_press("aim_up", 1.0)
	check(player.aim_direction().distance_to(Vector2.UP) < 0.05, "the right stick aims")
	Input.action_release("aim_up")
	check(player.aim_direction().distance_to(Vector2.UP) < 0.05, "aim holds when the stick is released")
	var key_event := InputEventKey.new()
	key_event.pressed = true
	TouchInput._input(key_event)
	check(TouchInput.device() == "keys", "the keyboard takes prompts back")

func _test_story() -> void:
	check(Story.ending_id(Story.NEW_CHAIRMAN_INDEX - 1.0) == &"retired" and Story.ending_id(Story.NEW_CHAIRMAN_INDEX) == &"new_chairman", "the index decides RETIRED or THE NEW CHAIRMAN")
	for st in 4:
		check(Story.STAGE_INTROS.has(st) and Story.STAGE_INTROS[st].size() == 3, "stage %d has an intro card" % st)
	# Narration: tap finishes a line, the next tap moves on, skip ends it.
	var text := Narration.new()
	text.lines = ["one line", "two lines"]
	var done := [false]
	text.finished.connect(func(): done[0] = true)
	get_tree().root.add_child(text)
	text.advance()
	check(text._label.visible_characters == text._label.text.length(), "a tap finishes the typing line")
	text.advance()
	check(text._label.text == "two lines", "the next tap moves to the next line")
	text.skip_all()
	check(done[0], "skipping finishes the narration")
	text.queue_free()
	# The prologue: full once per case file, a single line after.
	Meta.prologue_slots.clear()
	check(Meta.take_prologue(1) and not Meta.take_prologue(1) and Meta.take_prologue(2), "the full prologue plays on each case file's first run only")
	var prologue := Prologue.play(self, false, 1)
	await get_tree().process_frame
	var lines: Array = prologue.find_children("*", "Narration", true, false)[0].lines
	check(lines.size() == 1 and String(lines[0]).begins_with("Case file 2"), "later runs get the one-line prologue")
	prologue.queue_free()
	var full := Prologue.play(self, true, 0)
	await get_tree().process_frame
	check(full.find_children("*", "Narration", true, false)[0].lines.size() == Story.PROLOGUE.size(), "a first run gets the whole prologue")
	full.queue_free()
	# The winning ending: epilogue, title, credits, then the unlock card.
	var seq := EndingSequence.new()
	seq.freeze_beneath = false
	seq.summary = {"heists": 11, "index": 900.0, "gold": 900, "kills": 80, "who": "The Operator", "clout": 38, "new_specialists": [&"legend"]}
	seq.ending = Story.ending_id(900.0)
	get_tree().root.add_child(seq)
	await get_tree().process_frame
	check(seq.ending == &"new_chairman" and seq._narration.lines == Story.EPILOGUE_CHAIRMAN, "a high index plays THE NEW CHAIRMAN epilogue")
	seq._on_button()
	check(seq._stage == 1 and seq._title_block != null, "skipping the epilogue slams the title")
	var titles := seq._title_block.find_children("*", "Label", true, false).map(func(l): return l.text)
	check("THE NEW CHAIRMAN" in titles, "the ending's title shows")
	seq._on_button()
	check(seq._stage == 2 and seq._credits.get_child_count() == EndingSequence.credits_lines().size(), "the credits roll")
	var credit_text := seq._credits.get_children().map(func(l): return l.text)
	check(Story.CREDITS_NAME in credit_text, "the credits carry the author's name")
	seq._finish()
	var popups := get_tree().root.get_children().filter(func(n): return n is SpecialistPopup)
	check(seq._stage == 3 and popups.size() == 1, "a first win shows the NEW SPECIALIST card before home")
	for p: Node in popups:
		p.queue_free()
	seq.queue_free()
	var retired := EndingSequence.new()
	retired.freeze_beneath = false
	retired.summary = {"index": 300.0}
	retired.ending = Story.ending_id(300.0)
	get_tree().root.add_child(retired)
	await get_tree().process_frame
	check(retired._narration.lines == Story.EPILOGUE_RETIRED, "an ordinary win plays RETIRED")
	retired.queue_free()
	await get_tree().process_frame
	# Vendors read the run.
	RunState.start_run(load("res://main_character.tres"), 4817)
	RunState.run_map.current_stage = 3
	check(Story.vendor_lines(&"weapons").any(func(l): return String(l).contains("tower")), "vendors react to the stage")
	RunState.run_map.current_stage = 0

func _test_lockdown() -> void:
	RunFlow.pending_heist.modifier = &"lockdown"
	var lockdown: HeistFloor = load("res://heist_floor.tscn").instantiate()
	get_tree().root.add_child(lockdown)
	get_tree().current_scene = lockdown
	await get_tree().physics_frame
	check(not lockdown.generator.exits.is_empty(), "lockdown has emergency exits to seal")
	for gap: Dictionary in lockdown.generator.exits:
		check(not gap.get("open", true), "lockdown seals fire exits at build time")
	check(lockdown.generator.entrance.get("open", true), "lockdown preserves main escape")
	lockdown.tactical_map.full_reveal = true
	check(lockdown.tactical_map.full_reveal, "Insider can reveal the tactical layout")
	lockdown.queue_free()
	await get_tree().process_frame

func _test_doors() -> void:
	var gen := floor_scene.generator
	var visited: Dictionary = {}
	var queue: Array = [gen.start_room.get_meta("cell")]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if visited.has(cell):
			continue
		visited[cell] = true
		for delta: Vector2i in gen.SIDE_DELTA.values():
			var other := cell + delta
			if gen._occupied.has(other) and not visited.has(other):
				queue.append(other)
				if gen._occupied[cell] != gen._occupied[other]:
					var center := (Vector2(cell) + Vector2(0.5, 0.5)) * gen.MODULE
					var midpoint := center + Vector2(delta) * gen.MODULE * 0.5
					var direction := Vector2(delta)
					var query := PhysicsRayQueryParameters2D.create(midpoint - direction * 36.0, midpoint + direction * 36.0, 1)
					check(floor_scene.get_world_2d().direct_space_state.intersect_ray(query).is_empty(), "authored doorway is physically open")
	check(visited.size() == gen._occupied.size(), "all authored room cells reachable")

func _test_projectiles() -> void:
	var arena := Node2D.new()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var shooter: Player = load("res://player.tscn").instantiate()
	shooter.position = Vector2(9000, 9000)
	arena.add_child(shooter)
	shooter.set_physics_process(false)
	var targets: Array[Enemy] = []
	for x in [10050, 10120, 10190]:
		var enemy: Enemy = load("res://enemy.tscn").instantiate()
		enemy.position = Vector2(x, 10000)
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.health = 10
		targets.append(enemy)
	await get_tree().physics_frame
	var round: Bullet = load("res://bullet.tscn").instantiate()
	round.position = Vector2(10000, 10000)
	round.speed = 2400
	round.damage = 2
	round.pierce = 1
	arena.add_child(round)
	round.setup(Vector2.RIGHT, shooter)
	await get_tree().create_timer(0.25).timeout
	check(targets[0].health == 8 and targets[1].health == 8 and targets[2].health == 10, "fast piercing round hits exactly two guards once each")
	var wall := StaticBody2D.new()
	wall.position = Vector2(10150, 10200)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12, 100)
	shape.shape = rectangle
	wall.add_child(shape)
	arena.add_child(wall)
	var behind: Enemy = load("res://enemy.tscn").instantiate()
	behind.position = Vector2(10020, 10200)
	arena.add_child(behind)
	behind.set_physics_process(false)
	behind.health = 10
	await get_tree().physics_frame
	var bounce: Bullet = load("res://bullet.tscn").instantiate()
	bounce.position = Vector2(10080, 10200)
	bounce.speed = 1200
	bounce.damage = 3
	bounce.ricochets = 1
	arena.add_child(bounce)
	bounce.setup(Vector2.RIGHT, shooter)
	await get_tree().create_timer(0.3).timeout
	check(behind.health == 7, "ricochet round reflects off solid cover")
	await get_tree().create_timer(0.1).timeout
	arena.queue_free()
	await get_tree().process_frame

func _test_route() -> void:
	check(is_equal_approx(RunMap.stock_quota_for(0), 120.0) and roundi(RunMap.stock_quota_for(1)) == 227 and roundi(RunMap.stock_quota_for(2)) == 350 and roundi(RunMap.stock_quota_for(3)) == 492, "stock gates 120 / 227 / 350 / 492")
	for seed_value in range(1, 21):
		var route := RunMap.new()
		route.generate(seed_value)
		check(route.stages.map(func(s): return s.size()) == [8, 8, 8, 5], "route shape per stage")
		check(is_equal_approx(route.current_quota(), 380.0), "first gold gate is 380")
		var heists := 0
		var bosses := 0
		var gates := 0
		var previous := -1
		var guard := 0
		while not route.is_complete() and guard < 100:
			guard += 1
			var step: RunMap.Step = route.current()
			if step.kind == RunMap.StepKind.HEIST_CHOICE:
				heists += 1
				check(previous == RunMap.StepKind.SHOP, "the hideout comes before every heist choice")
				if step.is_boss:
					bosses += 1
					check(step.options.size() == 1 and step.options[0].is_boss() and step.options[0].boss_id != &"", "boss step offers exactly one named boss")
				else:
					check(step.options.size() >= 2 and step.options.size() <= 4, "2-4 heist options")
			elif step.kind == RunMap.StepKind.QUOTA_GATE:
				gates += 1
				route.quota_block += 1
			previous = step.kind
			route.advance_step()
		check(heists == 11 and bosses == 4 and gates == 4, "11 heists, 4 stage bosses, 4 quota gates")
		var migrated := RunMap.new()
		migrated.generate(seed_value)
		migrated.restore_progress(4)
		check(migrated.heists_done == 4 and migrated.current_stage == 1, "old saves migrate by completed heists")
		var exact := RunMap.new()
		exact.generate(seed_value)
		exact.restore_position(2, 3, 2, 5)
		check(exact.current_stage == 2 and exact.current_step == 3 and exact.quota_block == 2, "v3 saves restore their exact step")
