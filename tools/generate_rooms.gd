@tool
extends EditorScript
## ROOM GENERATOR — run this once from the Godot editor to create 20 room scenes.
##
## HOW TO RUN:
##   1. Put this file in your project (e.g. res://generate_rooms.gd).
##   2. Open it in the Godot script editor.
##   3. Menu: File > Run  (or press Ctrl+Shift+X).
##   4. It creates res://rooms/small_01.tscn ... large_05.tscn (20 files).
##
## Each room matches the structure that works in floor_test.tscn:
##   Room (Node2D, building_room.gd)
##     Floor (Polygon2D)
##     Walls (StaticBody2D, collision layer 1) with wall segments + door gaps
##     SpawnPoints (Node2D) with Marker2D children

const OUT_DIR := "res://rooms"
const WALL_THICK := 24.0
const DOOR_GAP := 96.0          # walkable opening height/width
const BLOCK_OFFSET := 119.0     # matches the working Block offset (out of Area2D)

## GRID MODULE — every room is a multiple of this so rooms tile together
## like rooms in a real building floorplan.
##   Small  = 1 module  (600 x 450)
##   Medium = 2 modules (1200x450 horizontal, or 600x900 vertical)
##   Large  = 4 modules (1200x900, a 2x2 square)
const MODULE := Vector2(600, 450)
const WALL_COLOR := Color(0.30, 0.31, 0.37)

# side constants matching Door.DoorSide
const NORTH := 0
const SOUTH := 1
const EAST := 2
const WEST := 3

func _run() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("rooms"):
		dir.make_dir("rooms")

	var made := 0
	# ALL rooms get doors on ALL FOUR sides. The floor generator seals the ones
	# that don't lead anywhere, so any two adjacent rooms can always connect.
	var all_sides := [NORTH, SOUTH, EAST, WEST]

	# 10 small rooms — 1 module (600x450).
	for i in 10:
		made += _build_room("small_%02d" % (i + 1), MODULE, all_sides, 3)

	# 5 medium rooms — 2 modules. Mix of horizontal (1200x450) and vertical (600x900).
	var med_sizes := [
		Vector2(MODULE.x * 2, MODULE.y),      # horizontal
		Vector2(MODULE.x, MODULE.y * 2),      # vertical
		Vector2(MODULE.x * 2, MODULE.y),      # horizontal
		Vector2(MODULE.x, MODULE.y * 2),      # vertical
		Vector2(MODULE.x * 2, MODULE.y),      # horizontal
	]
	for i in 5:
		made += _build_room("medium_%02d" % (i + 1), med_sizes[i], all_sides, 5)

	# 5 large rooms — 4 modules (1200x900, a 2x2 square).
	for i in 5:
		made += _build_room("large_%02d" % (i + 1),
			Vector2(MODULE.x * 2, MODULE.y * 2), all_sides, 8)

	print("Room generator: wrote %d room scenes to " % made + OUT_DIR)


func _build_room(room_name: String, size: Vector2, door_sides: Array,
		spawn_count: int) -> int:
	var root := Node2D.new()
	root.name = room_name
	root.set_script(load("res://building_room.gd"))
	root.set("id", StringName(room_name))
	root.set("room_size", size)
	root.set("spawn_count", spawn_count)
	# Assign the enemy scene if it exists.
	if ResourceLoader.exists("res://enemy.tscn"):
		root.set("enemy_scene", load("res://enemy.tscn"))

	# --- Floor visual (Polygon2D: a Node2D, so it sits in world space) ---
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	floor_poly.color = Color(0.15, 0.16, 0.2)
	floor_poly.z_index = -10
	root.add_child(floor_poly)
	floor_poly.owner = root

	# --- Walls ---
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1        # IMPORTANT: on layer 1 so the player collides
	walls.collision_mask = 0
	root.add_child(walls)
	walls.owner = root

	_build_walls(walls, root, size, door_sides)

	# --- Spawn points ---
	var spawns := Node2D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	spawns.owner = root
	_build_spawns(spawns, root, size, spawn_count)

	# --- Save ---
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Failed packing " + room_name)
		return 0
	var path := OUT_DIR + "/" + room_name + ".tscn"
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Failed saving " + path)
		return 0
	return 1

## Build the four sides. On a side with doors, cut ONE GAP PER MODULE.
func _build_walls(walls: StaticBody2D, root: Node, size: Vector2, door_sides: Array) -> void:
	var t := WALL_THICK
	var ht := t * 0.5

	for side: int in [NORTH, SOUTH, EAST, WEST]:
		var horizontal: bool = (side == NORTH or side == SOUTH)
		# Length of this wall, and its fixed coordinate on the other axis.
		var wall_len: float = size.x if horizontal else size.y
		var fixed: float = 0.0
		match side:
			NORTH: fixed = ht
			SOUTH: fixed = size.y - ht
			EAST:  fixed = size.x - ht
			WEST:  fixed = ht

		# Gap centres along this wall (one per module).
		var gap_centres: Array[float] = []
		if side in door_sides:
			var module_len: float = MODULE.x if horizontal else MODULE.y
			var n: int = int(round(wall_len / module_len))
			for m in n:
				gap_centres.append(module_len * m + module_len * 0.5)

		# Build the solid spans between the gaps.
		var spans := _spans_excluding_gaps(wall_len, gap_centres, DOOR_GAP * 0.5)
		var idx := 0
		for span in spans:
			idx += 1
			var start: float = span[0]
			var length: float = span[1]
			if length <= 1.0:
				continue
			var centre := start + length * 0.5
			var nm := _side_name(side) + str(idx)
			if horizontal:
				_add_wall(walls, root, nm, Vector2(centre, fixed), Vector2(length, t))
			else:
				_add_wall(walls, root, nm, Vector2(fixed, centre), Vector2(t, length))

## Given a wall length and gap centres, return [[start, length], ...] for the
## solid parts between/around the gaps.
func _spans_excluding_gaps(wall_len: float, gap_centres: Array, half_gap: float) -> Array:
	var spans: Array = []
	var cursor := 0.0
	for gc: float in gap_centres:
		var gap_start: float = maxf(gc - half_gap, 0.0)
		if gap_start > cursor:
			spans.append([cursor, gap_start - cursor])
		cursor = minf(gc + half_gap, wall_len)
	if cursor < wall_len:
		spans.append([cursor, wall_len - cursor])
	return spans

func _side_name(side: int) -> String:
	match side:
		NORTH: return "WallNorth"
		SOUTH: return "WallSouth"
		EAST:  return "WallEast"
		WEST:  return "WallWest"
	return "Wall"


func _add_wall(parent: Node, root: Node, wall_name: String, pos: Vector2, wsize: Vector2) -> void:
	var cs := CollisionShape2D.new()
	cs.name = wall_name
	cs.position = pos
	var shape := RectangleShape2D.new()
	shape.size = wsize
	cs.shape = shape
	parent.add_child(cs)
	cs.owner = root

	# Visible wall. Polygon2D is a Node2D so it draws in world space (a
	# ColorRect is a Control and would NOT position correctly here).
	var vis := Polygon2D.new()
	vis.name = wall_name + "Vis"
	vis.position = pos
	var hx := wsize.x * 0.5
	var hy := wsize.y * 0.5
	vis.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	vis.color = WALL_COLOR
	parent.add_child(vis)
	vis.owner = root

func _build_spawns(parent: Node, root: Node, size: Vector2, count: int) -> void:
	# Spread markers in a loose ring, inset from the walls.
	var inset := 120.0
	var positions := [
		Vector2(inset, inset),
		Vector2(size.x - inset, inset),
		Vector2(inset, size.y - inset),
		Vector2(size.x - inset, size.y - inset),
		Vector2(size.x * 0.5, inset),
		Vector2(size.x * 0.5, size.y - inset),
		Vector2(inset, size.y * 0.5),
		Vector2(size.x - inset, size.y * 0.5),
	]
	for i in count:
		_add_marker(parent, root, "M%d" % (i + 1), positions[i % positions.size()])

func _add_marker(parent: Node, root: Node, marker_name: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = pos
	parent.add_child(m)
	m.owner = root


