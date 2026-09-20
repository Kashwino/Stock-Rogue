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
	RunFlow.pending_heist = MapNode.new()
	RunFlow.pending_heist.venue_id = &"bank_job"
	check(ItemPool.weapons().size() == 20, "20 weapons in catalog")
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
	pause.close_pause()
	await get_tree().create_timer(1.7).timeout
	check(not RunState.loadout.reloading, "reload resumes after pause")
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
	# Boss telegraphs, a second phase, projectile identity and death hookup.
	player.global_position = boss.global_position + Vector2(180, 80)
	boss.set_sleeping(false)
	boss.clock = 0.0
	boss.attack = AuditorBoss.Attack.RECOVER
	boss._physics_process(0.02)
	check(boss.attack == AuditorBoss.Attack.DECLARE_LEVY, "boss declares levy")
	boss.clock = 0.0
	boss._physics_process(0.02)
	check(boss.attack == AuditorBoss.Attack.RECOVER, "boss fires levy and recovers")
	boss.health = boss.max_health / 2
	boss.clock = 0.0
	boss._physics_process(0.02)
	check(boss.phase == 2 and boss.attack == AuditorBoss.Attack.DECLARE_CHARGE, "margin-call phase declares charge")
	var prior_stage := RunState.run_map.current_stage
	RunState.run_map.current_stage = 3
	floor_scene._extract()
	check(not floor_scene._extracting, "final boss cannot be skipped by extraction")
	RunState.run_map.current_stage = prior_stage
	boss.take_damage(9999)
	check(floor_scene.marked, "boss death marks heist and triggers reward")
	await get_tree().create_timer(0.2).timeout
	check(MarketOps.execute("short", &"bank_job")["ok"], "open final extraction contract")
	asset.current_price = float(RunState.short_position["entry"]) * 0.9
	var extraction_gold := RunEconomy.gold
	floor_scene._extract()
	check(get_tree().paused and floor_scene.results._shown, "extraction presents results while paused")
	check(RunEconomy.gold == extraction_gold + 105 and RunState.short_position.is_empty(), "real extraction pays short before grade movement")
	check(Meta.intel == 8, "real extraction banks sabotage and boss Intel")
	floor_scene._extract()
	check(RunEconomy.gold == extraction_gold + 105 and Meta.intel == 8, "duplicate extraction cannot duplicate gold or Intel")
	floor_scene.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	check(Engine.time_scale == 1.0, "scene exit restores time scale")
	await _test_lockdown()
	await _test_projectiles()
	RunState.deserialize(saved)
	check(RunState.has_perk(&"fast_hands") and RunState.hedge_charges == 2, "perk and hedge deserialize")
	# Construct the remaining production screens to catch missing node references.
	for path: String in ["res://home_screen.tscn", "res://character_select.tscn", "res://map_ui_screen.tscn", "res://hideout_room.tscn", "res://prep_lobby.tscn"]:
		var scene: Node = load(path).instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().process_frame
		await get_tree().process_frame
		check(is_instance_valid(scene), "screen ready " + path)
		if path == "res://hideout_room.tscn":
			RunEconomy.gold = 2000
			scene._open_station(&"market")
			await get_tree().process_frame
			var panel: CanvasLayer = scene._active_panel
			var purchase: Button = panel.find_children("*", "Button", true, false).filter(func(b): return b.text == "Buy")[0]
			purchase.pressed.emit()
			check(RunEconomy.gold < 2000 and purchase.disabled, "unified market buys weapon and debits gold")
			scene._close_panel()
			scene._open_station(&"market")
			check(scene._active_panel == panel and purchase.disabled, "reopening market does not restock purchases")
			scene._close_panel()
		scene.queue_free()
		await get_tree().process_frame
	RunState.end_run(false)
	await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	print("TEST SUITE COMPLETE")
	get_tree().quit(0)

func _test_progression() -> void:
	check(Meta.award_extraction("empty-fixture", 0, 0, false) == 0, "empty extraction earns no Intel")
	check(Meta.award_extraction("earned-fixture", 12, 4, true) == 14, "extraction awards capped combat and sabotage Intel")
	check(Meta.award_extraction("earned-fixture", 12, 4, true) == 0 and Meta.intel == 14, "checkpoint replay cannot duplicate Intel")
	check(Meta.purchase(&"circuit_smg") == "Unlocked permanently." and Meta.intel == 2, "weapon unlock spends Intel")
	check(ItemPool.rewardable_weapons().size() == 17, "purchased weapon enters reward pool")
	Meta.purchase(&"circuit_smg")
	check(Meta.intel == 2, "duplicate unlock does not spend")
	Meta.purchase(&"cool_head")
	check(Meta.intel == 2 and &"cool_head" not in Meta.unlocked_assets, "unaffordable unlock is atomic")
	Meta.reset()

func _test_modifiers() -> void:
	var a := RunMap.new()
	var b := RunMap.new()
	a.generate(9182)
	b.generate(9182)
	var tags: Dictionary = {}
	for s in a.stages.size():
		for h in a.stages[s].size():
			for i in a.stages[s][h].options.size():
				var node: MapNode = a.stages[s][h].options[i]
				tags[node.modifier] = true
				check(node.modifier == b.stages[s][h].options[i].modifier, "map modifier deterministic")
	check(tags.size() == 3, "all three map modifiers appear")

func _test_security() -> void:
	var devices := get_tree().get_nodes_in_group("security")
	check(devices.size() == 14, "seven rooms have cameras and alarm panels")
	var panel: SecurityDevice
	for device: SecurityDevice in devices:
		if device.kind == SecurityDevice.Kind.ALARM:
			panel = device
			break
	var start_heat := floor_scene.heat
	floor_scene.security_alert(panel.room, "Test radio", 10.0)
	check(panel.armed and floor_scene.heat > start_heat, "witness report arms local alarm and adds heat")
	panel.disable()
	var count := floor_scene.security_disabled
	check(count == 2 and not panel.armed, "disabling panel also disables room camera")
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
	check(guard.radio_progress > 0.0, "radio has interruptible windup")
	guard.take_damage(1)
	check(guard.radio_progress == 0.0 and guard.radio_cooldown > 0.0, "damage interrupts a radio call")
	guard.radio_cooldown = 0.0
	guard._radio_step(2.0, true)
	check(floor_scene.heat > 0.0, "completed guard radio call creates heat")
	guard.queue_free()
	floor_scene.modifier = &"heavy_police"
	check(floor_scene.loot_multiplier() == 2 and floor_scene.dispatch_threshold() == 8.0, "heavy police doubles loot and responds sooner")
	var gold := RunEconomy.gold
	floor_scene._on_loot_collected(10)
	check(RunEconomy.gold == gold + 20, "heavy modifier doubles actual pickup payout")
	floor_scene.modifier = &""

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
	var markets := 0
	var empty := 0
	for seed_value in range(1, 31):
		var route := RunMap.new()
		route.generate(seed_value)
		check(route.stages.map(func(s): return s.size()) == [3, 3, 3, 1], "exact 3 Town / 3 City / 3 Capital / 1 final")
		for i in 10:
			var choice: RunMap.Step = route.current()
			check(choice.kind == RunMap.StepKind.HEIST_CHOICE, "no forced markets or quota gates")
			check(choice.options.size() == 1 if i == 9 else choice.options.size() >= 2 and choice.options.size() <= 4, "correct location count")
			if choice.market_available: markets += 1
			else: empty += 1
			if i == 9:
				check(choice.options[0].type == MapNode.Type.BOSS, "final node is explicit boss")
			route.choose_option(0)
			route.advance_step()
		check(route.is_complete(), "run ends after tenth score")
		route.restore_progress(7)
		check(route.current_stage == 2 and route.current_step == 1, "old checkpoint migrates by completed scores")
		route.current().market_visited = true
		var restored := RunMap.new()
		restored.generate(seed_value)
		restored.restore_progress(7)
		restored.restore_markets(route.visited_markets())
		check(restored.current().market_visited, "visited market preserved on resume")
	check(markets > 0 and empty > 0, "RNG includes and omits optional markets")
