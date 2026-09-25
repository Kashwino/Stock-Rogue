extends Node
class_name HudShots
## Debug: capture the HUD in the situations that stress its legibility, to
## user://hud_shots/ (F1 → HUD SHOTS in a heist, or the screenshot tool's
## `hudshots=1`):
##   lit_room      the brightest room (a lamp right over it)
##   dark_room     the room furthest from any lamp
##   rain_outside  out on the street by the getaway car
##   one_hp        at 1 HP (the ink bleed, the last chip glowing)
##   frenzy        a live FRENZY combo
##   boss_fight    a boss on the bar (the building's boss room)
## The player is made untouchable while it runs; it frees itself when done.

signal finished(paths: Array)

const DIR := "user://hud_shots/"
var floor_host: HeistFloor
var paths: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := floor_host
	if f == null or not is_instance_valid(f.player):
		finished.emit(paths)
		queue_free()
		return
	var tree := get_tree()
	tree.paused = false
	f.player._invulnerable = true
	var rooms: Array = f.generator.rooms
	var lamps: Array = f.lighting.lamps if f.lighting else []
	var lit: Node2D = rooms[0]
	var dark: Node2D = rooms[0]
	var best_lit := INF
	var best_dark := -INF
	for room in rooms:
		var c: Vector2 = room.center_position()
		var nearest := INF
		for lamp: PointLight2D in lamps:
			if is_instance_valid(lamp):
				nearest = minf(nearest, lamp.global_position.distance_to(c))
		if nearest < best_lit:
			best_lit = nearest
			lit = room
		if nearest > best_dark and nearest < INF:
			best_dark = nearest
			dark = room
	await _shot("lit_room", lit.center_position())
	await _shot("dark_room", dark.center_position())
	if f.car:
		await _shot("rain_outside", f.car.global_position + Vector2(0, -90))
	f.player.health = 1
	f.player.health_changed.emit(1, f.player.max_health)
	await _shot("one_hp", lit.center_position())
	f.player.health = f.player.max_health
	f.player.health_changed.emit(f.player.health, f.player.max_health)
	if f.combo:
		f.combo.add_points(maxi(1, f.combo.threshold(4) - f.combo.points))
		f.combo.window = 999.0
		f.combo.window_left = 600.0
		await _shot("frenzy", lit.center_position())
		f.combo.window = f.combo.window_length()
		f.combo.window_left = 0.1
	if f.generator.boss_room:
		var target: Vector2 = f.generator.boss_room.center_position()
		var boss: Enemy = null
		for c in f.generator.boss_room.get_children():
			if c is Enemy and not c._dead:
				boss = c
		if boss and f.hud and f.hud.boss_bar:
			f.hud.boss_bar.show_for(boss, boss.display_name if boss is Boss else boss.elite_tag, boss.subtitle if boss is Boss else "LIEUTENANT", boss.thresholds if boss is Boss else [])
		await _shot("boss_fight", target + Vector2(0, 160))
	finished.emit(paths)
	queue_free()

func _shot(id: String, at: Vector2) -> void:
	var f := floor_host
	f.player.global_position = at
	f.camera.global_position = at
	for i in 24:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := DIR + id + ".png"
	if image and image.save_png(path) == OK:
		paths.append(ProjectSettings.globalize_path(path))
