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
	check(ItemPool.weapons().size() == 17, "17 weapons")
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
	check(is_equal_approx(asset.current_price, before * 0.8) and RunEconomy.gold == 475, "short payout and price")
	check(MarketOps.execute("hedge", &"bank_job")["ok"] and RunState.hedge_charges == 3, "three-hit circuit breaker")
	check(not MarketOps.execute("hedge", &"bank_job")["ok"] and RunEconomy.gold == 375, "cannot double-buy active hedge")
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
	boss.take_damage(9999)
	check(floor_scene.marked, "boss death marks heist and triggers reward")
	await get_tree().create_timer(0.2).timeout
	floor_scene.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	await _test_projectiles()
	RunState.deserialize(saved)
	check(RunState.has_perk(&"fast_hands") and RunState.hedge_charges == 2, "perk and hedge deserialize")
	# Construct the remaining production screens to catch missing node references.
	for path: String in ["res://home_screen.tscn", "res://character_select.tscn", "res://map_ui_screen.tscn", "res://hideout_room.tscn"]:
		var scene: Node = load(path).instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().process_frame
		await get_tree().process_frame
		check(is_instance_valid(scene), "screen ready " + path)
		scene.queue_free()
		await get_tree().process_frame
	RunState.end_run(false)
	await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	print("TEST SUITE COMPLETE")
	get_tree().quit(0)

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
