extends Node2D
class_name FloorGenerator

## Builds a heist building at runtime from the room scenes in res://rooms/.
## NO DOORS: rooms connect through open gaps in their walls. After placement,
## every gap that doesn't lead into another room is sealed with a wall piece —
## except the MAIN ENTRANCE (start room) and a number of EMERGENCY EXITS that
## scales with the quota level. Those are sealed too (no out-of-bounds) but get
## a distinct visual and are exposed for the extraction system.
##
## Seeded: same seed -> same building.

signal floor_built(rooms: Array, start_room)

const MODULE := Vector2(600, 450)
const ROOMS_DIR := "res://rooms"
const WALL_THICK := 24.0
const DOOR_GAP := 96.0
const WALL_COLOR := Color("506069")

const NORTH := 0
const SOUTH := 1
const EAST := 2
const WEST := 3

const SIDE_DELTA := {
	NORTH: Vector2i(0, -1),
	SOUTH: Vector2i(0, 1),
	EAST:  Vector2i(1, 0),
	WEST:  Vector2i(-1, 0),
}

var rooms: Array = []
var start_room = null
var boss_room = null
var weapon_chest_room = null
var upgrade_chest_room = null

## Filled by generate(): the main entrance and the emergency exits.
## Each is {room, side: int, inside_pos: Vector2 (world), visual: Polygon2D}.
var entrance: Dictionary = {}
var exits: Array = []

var _rng := RandomNumberGenerator.new()
var _occupied: Dictionary = {}
var _templates_small: Array = []
var _templates_medium: Array = []
var _templates_large: Array = []

func generate(run_seed: int, room_count: int = 12, exit_count: int = 1) -> void:
	_rng.seed = run_seed
	_clear()
	_load_templates()


	if _templates_small.is_empty():
		push_error("FloorGenerator: no room templates in " + ROOMS_DIR
			+ ". Run generate_rooms.gd (File > Run) to create them.")
		return

	# 1. Start room (small, at origin).
	var first = _place_room(_pick_from(_templates_small), Vector2i.ZERO)
	if first == null:
		push_error("FloorGenerator: could not place the start room.")
		return
	start_room = first
	first.set("is_start_room", true)

	# 2. Large rooms early, while 2x2 space is still free.
	var large_target := 2 if room_count >= 10 else 1
	var large_placed := 0
	var large_tries := 0
	while large_placed < large_target and large_tries < 60 and not _templates_large.is_empty():
		large_tries += 1
		if _grow_with(_pick_from(_templates_large)):
			large_placed += 1

	# 3. Fill with small/medium.
	var attempts := 0
	while rooms.size() < room_count and attempts < room_count * 50:
		attempts += 1
		var roll := _rng.randf()
		var tpl: PackedScene
		if roll < 0.7 or _templates_medium.is_empty():
			tpl = _pick_from(_templates_small)
		else:
			tpl = _pick_from(_templates_medium)
		_grow_with(tpl)

	if rooms.size() < 2:
		push_error("FloorGenerator: only " + str(rooms.size())
			+ " room placed. Room scenes are probably missing room_size — "
			+ "re-run generate_rooms.gd.")

	# 4. Boss room (large) at the farthest point from start.
	_place_boss_room()

	# 5. Chest rooms.
	_designate_chest_rooms()

	_assign_unique_ids()

	# 6. Seal unused gaps; pick entrance + emergency exits from the perimeter.
	_process_gaps(exit_count)

	floor_built.emit(rooms, start_room)

func _pick_from(pool: Array) -> PackedScene:
	return pool[_rng.randi() % pool.size()]

func _grow_with(template: PackedScene) -> bool:
	if rooms.is_empty():
		return _place_room(template, Vector2i.ZERO) != null
	for attempt in 12:
		var anchor = rooms[_rng.randi() % rooms.size()]
		var anchor_cells := _cells_for(anchor, anchor.get_meta("cell"))
		var from_cell: Vector2i = anchor_cells[_rng.randi() % anchor_cells.size()]
		var sides := [NORTH, SOUTH, EAST, WEST]
		var side: int = sides[_rng.randi() % sides.size()]
		var target: Vector2i = from_cell + SIDE_DELTA[side]
		if _occupied.has(target):
			continue
		if _place_room(template, target) != null:
			return true
	return false

func _place_boss_room() -> void:
	if _templates_large.is_empty() or start_room == null:
		return
	var start_cell: Vector2i = start_room.get_meta("cell")
	var candidates: Array = []
	for room in rooms:
		for cell: Vector2i in _cells_for(room, room.get_meta("cell")):
			for side: int in [NORTH, SOUTH, EAST, WEST]:
				var t: Vector2i = cell + SIDE_DELTA[side]
				if not _occupied.has(t) and t not in candidates:
					candidates.append(t)
	candidates.sort_custom(func(a, b):
		return (a - start_cell).length_squared() > (b - start_cell).length_squared())
	for cell: Vector2i in candidates:
		var placed = _place_room(_pick_from(_templates_large), cell)
		if placed != null:
			boss_room = placed
			placed.set("rarity", 6)
			placed.set("spawn_count", 1)
			placed.set_meta("is_boss", true)
			return

func _designate_chest_rooms() -> void:
	var smalls: Array = []
	for room in rooms:
		if room == start_room or room == boss_room:
			continue
		var size: Vector2 = room.get("room_size")
		if size == MODULE:
			smalls.append(room)
	if smalls.is_empty():
		return
	smalls.shuffle()
	weapon_chest_room = smalls[0]
	weapon_chest_room.set("rarity", 5)
	weapon_chest_room.set("spawn_count", 0)
	weapon_chest_room.set_meta("chest_kind", "weapon")
	if smalls.size() > 1:
		upgrade_chest_room = smalls[1]
		upgrade_chest_room.set("rarity", 5)
		upgrade_chest_room.set("spawn_count", 0)
		upgrade_chest_room.set_meta("chest_kind", "upgrade")

func _clear() -> void:
	for r in rooms:
		if is_instance_valid(r):
			r.queue_free()
	rooms.clear()
	_occupied.clear()
	start_room = null
	boss_room = null
	weapon_chest_room = null
	upgrade_chest_room = null
	entrance = {}
	exits.clear()

func _load_templates() -> void:
	_templates_small.clear()
	_templates_medium.clear()
	_templates_large.clear()
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		# Exported PCKs expose .tscn.remap entries; load their logical paths.
		var resource_name := f.trim_suffix(".remap")
		if resource_name.ends_with(".tscn"):
			var scene = load(ROOMS_DIR + "/" + resource_name)
			if scene:
				if resource_name.begins_with("small"):
					_templates_small.append(scene)
				elif resource_name.begins_with("medium"):
					_templates_medium.append(scene)
				elif resource_name.begins_with("large"):
					_templates_large.append(scene)
		f = dir.get_next()
	dir.list_dir_end()

func _cells_for(room, cell: Vector2i) -> Array:
	var size: Vector2 = room.get("room_size")
	# A room scene with no/zero room_size would occupy NO cells, which silently
	# lets everything else overlap it. Treat it as one module instead.
	if size.x < MODULE.x or size.y < MODULE.y:
		size = MODULE
	var w := maxi(int(round(size.x / MODULE.x)), 1)
	var h := maxi(int(round(size.y / MODULE.y)), 1)
	var out := []
	for x in w:
		for y in h:
			out.append(cell + Vector2i(x, y))
	return out

func _place_room(template: PackedScene, cell: Vector2i):
	var room = template.instantiate()
	var cells := _cells_for(room, cell)
	for c: Vector2i in cells:
		if _occupied.has(c):
			room.queue_free()
			return null
	add_child(room)
	room.position = Vector2(cell.x * MODULE.x, cell.y * MODULE.y)
	room.set_meta("cell", cell)
	for c: Vector2i in cells:
		_occupied[c] = room
	rooms.append(room)
	return room

func _assign_unique_ids() -> void:
	var i := 0
	for room in rooms:
		i += 1
		var tag := "room"
		if room == start_room:
			tag = "start"
		elif room == boss_room:
			tag = "boss"
		elif room == weapon_chest_room:
			tag = "chestw"
		elif room == upgrade_chest_room:
			tag = "chestu"
		room.set("id", StringName("%s_%d" % [tag, i]))
		room.name = "%s_%d" % [tag.capitalize(), i]

# --- Gap processing: seal dead gaps, mark entrance + exits -------------------

## A "gap" is a doorway opening in a room's wall. One per module per side.
## Returns every gap of a room: {side, local_wall_pos, inside_local, cell}.
func _gaps_of(room) -> Array:
	var size: Vector2 = room.get("room_size")
	var room_cell: Vector2i = room.get_meta("cell")
	var ht := WALL_THICK * 0.5
	var inset := 70.0
	var out: Array = []
	var w := int(round(size.x / MODULE.x))
	var h := int(round(size.y / MODULE.y))
	for side: int in [NORTH, SOUTH, EAST, WEST]:
		var horizontal: bool = (side == NORTH or side == SOUTH)
		var n: int = w if horizontal else h
		for m in n:
			var c: float = (MODULE.x if horizontal else MODULE.y) * m \
				+ (MODULE.x if horizontal else MODULE.y) * 0.5
			var wall_pos: Vector2
			var inside: Vector2
			var gap_cell: Vector2i
			match side:
				NORTH:
					wall_pos = Vector2(c, ht)
					inside = Vector2(c, inset)
					gap_cell = room_cell + Vector2i(m, 0)
				SOUTH:
					wall_pos = Vector2(c, size.y - ht)
					inside = Vector2(c, size.y - inset)
					gap_cell = room_cell + Vector2i(m, h - 1)
				EAST:
					wall_pos = Vector2(size.x - ht, c)
					inside = Vector2(size.x - inset, c)
					gap_cell = room_cell + Vector2i(w - 1, m)
				WEST:
					wall_pos = Vector2(ht, c)
					inside = Vector2(inset, c)
					gap_cell = room_cell + Vector2i(0, m)
			out.append({
				"side": side, "wall_pos": wall_pos,
				"inside_local": inside, "cell": gap_cell,
			})
	return out

func _process_gaps(exit_count: int) -> void:
	# Collect every perimeter gap (gap whose neighbouring cell is empty).
	var perimeter: Array = []
	for room in rooms:
		for gap in _gaps_of(room):
			var neighbour_cell: Vector2i = gap["cell"] + SIDE_DELTA[gap["side"]]
			var neighbour = _occupied.get(neighbour_cell)
			if neighbour == null:
				var entry := {
					"room": room, "side": gap["side"],
					"wall_pos": gap["wall_pos"],
					"inside_local": gap["inside_local"],
					"inside_pos": room.to_global(gap["inside_local"]),
				}
				perimeter.append(entry)
			# Gaps into another room stay open: that's a doorway.

	# Entrance: a perimeter gap on the start room (fallback: nearest to start).
	var entrance_gap: Dictionary = {}
	for g: Dictionary in perimeter:
		if g["room"] == start_room:
			entrance_gap = g
			break
	if entrance_gap.is_empty() and perimeter.size() > 0:
		var sc: Vector2 = start_room.global_position
		perimeter.sort_custom(func(a, b):
			return a["inside_pos"].distance_to(sc) < b["inside_pos"].distance_to(sc))
		entrance_gap = perimeter[0]

	# Emergency exits: farthest-from-entrance perimeter gaps, spread out,
	# never in the start room, at most one per room.
	var exit_gaps: Array = []
	if not entrance_gap.is_empty():
		var pool: Array = []
		var used_rooms: Array = [start_room]
		for g: Dictionary in perimeter:
			if g != entrance_gap:
				pool.append(g)
		var epos: Vector2 = entrance_gap["inside_pos"]
		pool.sort_custom(func(a, b):
			return a["inside_pos"].distance_to(epos) > b["inside_pos"].distance_to(epos))
		for g: Dictionary in pool:
			if exit_gaps.size() >= exit_count:
				break
			if g["room"] in used_rooms:
				continue
			exit_gaps.append(g)
			used_rooms.append(g["room"])

	# Seal every perimeter gap. The entrance and emergency exits are NOT sealed —
	# they are the ways in and out — but they get a bright threshold marker.
	for g: Dictionary in perimeter:
		if g == entrance_gap:
			entrance = g
			entrance["visual"] = _mark_threshold(g, Color(0.95, 0.78, 0.25))
			entrance["open"] = true
		elif g in exit_gaps:
			g["visual"] = _mark_threshold(g, Color(0.35, 0.85, 0.5))
			g["open"] = true
			exits.append(g)
		else:
			_seal_gap(g)

## Fill a dead-end gap with a solid wall piece that matches the room walls.
func _seal_gap(gap: Dictionary) -> void:
	var room = gap["room"]
	var side: int = gap["side"]
	var horizontal: bool = (side == NORTH or side == SOUTH)
	var wsize := Vector2(DOOR_GAP + 4.0, WALL_THICK) if horizontal \
		else Vector2(WALL_THICK, DOOR_GAP + 4.0)

	var body := StaticBody2D.new()
	body.collision_layer = Layers.WALLS
	body.collision_mask = 0
	body.position = gap["wall_pos"]
	room.add_child(body)

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wsize
	cs.shape = shape
	body.add_child(cs)

	# Polygon2D (a Node2D) draws in world space; a ColorRect would not.
	var vis := Polygon2D.new()
	vis.polygon = _rect_points(wsize)
	vis.color = WALL_COLOR
	body.add_child(vis)

## Mark an open threshold (main door / emergency exit). No collision: you walk
## through it. Returns the Polygon2D so exits can recolour when they weld shut.
func _mark_threshold(gap: Dictionary, color: Color) -> Polygon2D:
	var room = gap["room"]
	var side: int = gap["side"]
	var horizontal: bool = (side == NORTH or side == SOUTH)
	var wsize := Vector2(DOOR_GAP, 14.0) if horizontal else Vector2(14.0, DOOR_GAP)

	var marker := Node2D.new()
	marker.position = gap["wall_pos"]
	room.add_child(marker)

	var vis := Polygon2D.new()
	vis.polygon = _rect_points(wsize)
	vis.color = color
	marker.add_child(vis)

	# A soft glow pad on the inside so the doorway reads from a distance.
	var pad := Polygon2D.new()
	pad.polygon = _rect_points(Vector2(DOOR_GAP + 40.0, DOOR_GAP + 40.0))
	pad.color = Color(color.r, color.g, color.b, 0.16)
	pad.position = gap["inside_local"] - marker.position
	marker.add_child(pad)

	gap["marker_node"] = marker
	return vis

## Close an emergency exit: recolour it and drop a solid wall in the opening.
func close_exit(gap: Dictionary) -> void:
	if not gap.get("open", false):
		return
	gap["open"] = false
	if gap.has("visual") and is_instance_valid(gap["visual"]):
		gap["visual"].color = Color(0.6, 0.2, 0.2)
	_seal_gap(gap)

func _rect_points(size: Vector2) -> PackedVector2Array:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	return PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])

## This authored scene fixes rooms, cover, approach, loops and loot branches.
## Seed affects combat/loot only; it never changes this building's geometry.
func generate_authored() -> void:
	_clear()
	var layout := preload("res://layouts/marlowe_exchange.tscn").instantiate()
	add_child(layout)
	for child in layout.get_children():
		if child is BuildingRoom:
			rooms.append(child)
			var cell := Vector2i(child.position / MODULE)
			child.set_meta("cell", cell)
			for occupied: Vector2i in _cells_for(child, cell):
				_occupied[occupied] = child
	start_room = layout.get_node("Lobby")
	start_room.is_start_room = true
	boss_room = layout.get_node("Auditor")
	boss_room.set_meta("is_boss", true)
	boss_room.rarity = 6
	boss_room.spawn_count = 1
	weapon_chest_room = layout.get_node("Records")
	upgrade_chest_room = layout.get_node("Vault")
	for room in [weapon_chest_room, upgrade_chest_room]:
		room.spawn_count = 0
		room.rarity = 5
		room.set_meta("chest_kind", "weapon" if room == weapon_chest_room else "upgrade")
	_process_gaps(2)
	floor_built.emit(rooms, start_room)
