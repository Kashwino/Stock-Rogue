extends RefCounted
class_name PropPlacer
## Furnishes a building room with Prop cover according to its room type, on a
## 20 px occupancy grid. Hard rules: never block a doorway corridor, a spawn
## marker, a loot/chest slot or a security device, and every doorway, spawn
## point and the room centre must stay mutually reachable (flood fill, with a
## one-cell clearance so a body fits). A prop that breaks that is taken back.

const CELL := 20.0
const WALL_BAND := 30.0

## kind -> [size, round, placement]. placement: "wall" hugs a wall (rotated on
## east/west walls), "free" stands in the room as cover, "corner" tucks away.
const KINDS := {
	"crate": [Vector2(56, 56), false, "free"],
	"crate_big": [Vector2(70, 70), false, "free"],
	"pallet": [Vector2(76, 60), false, "free"],
	"barrel": [Vector2(38, 38), true, "corner"],
	"shelf": [Vector2(160, 36), false, "wall"],
	"workbench": [Vector2(130, 44), false, "wall"],
	"display_case": [Vector2(96, 46), false, "free"],
	"safe": [Vector2(52, 52), false, "wall"],
	"car": [Vector2(150, 74), false, "free"],
	"desk": [Vector2(112, 56), false, "free"],
	"desk_big": [Vector2(170, 70), false, "free"],
	"filing": [Vector2(96, 36), false, "wall"],
	"cubicle": [Vector2(110, 90), false, "free"],
	"plant": [Vector2(34, 34), true, "corner"],
	"water_cooler": [Vector2(30, 30), false, "wall"],
	"copier": [Vector2(64, 46), false, "wall"],
	"counter": [Vector2(220, 44), false, "free"],
	"sofa": [Vector2(116, 48), false, "wall"],
	"meeting_table": [Vector2(230, 90), false, "free"],
	"slot_machine": [Vector2(46, 46), false, "wall"],
	"card_table": [Vector2(92, 92), true, "free"],
	"roulette": [Vector2(84, 84), true, "free"],
	"pillar": [Vector2(44, 44), false, "free"],
	"statue": [Vector2(50, 50), true, "free"],
	"bar": [Vector2(220, 42), false, "wall"],
	"server_rack": [Vector2(44, 96), false, "free"],
	"server_wall": [Vector2(150, 40), false, "wall"],
	"trading_desk": [Vector2(150, 60), false, "free"],
	"big_screen": [Vector2(190, 18), false, "wall"],
	"glass": [Vector2(130, 12), false, "free"],
	"gold_stack": [Vector2(66, 32), false, "free"],
}

## room type -> [[kind, min, max], ...]
const RECIPES := {
	"lobby": [["counter", 1, 1], ["plant", 2, 3], ["sofa", 1, 1]],
	"warehouse": [["crate", 2, 4], ["crate_big", 1, 2], ["shelf", 2, 3], ["barrel", 2, 3], ["pallet", 1, 2]],
	"pawnshop": [["display_case", 2, 3], ["shelf", 2, 2], ["safe", 1, 1], ["plant", 0, 1]],
	"garage": [["car", 1, 1], ["workbench", 1, 2], ["barrel", 2, 3], ["crate", 1, 2]],
	"backoffice": [["desk", 1, 2], ["filing", 2, 2], ["safe", 1, 1], ["sofa", 0, 1]],
	"storage": [["crate", 3, 5], ["crate_big", 1, 2], ["shelf", 2, 3]],
	"office": [["desk", 2, 4], ["filing", 1, 2], ["plant", 2, 2], ["water_cooler", 1, 1]],
	"cubicles": [["cubicle", 3, 4], ["plant", 1, 2], ["copier", 1, 1]],
	"bank_hall": [["counter", 1, 1], ["pillar", 2, 4], ["plant", 2, 2], ["sofa", 0, 1]],
	"meeting": [["meeting_table", 1, 1], ["plant", 2, 2], ["big_screen", 1, 1]],
	"records": [["filing", 3, 5], ["shelf", 2, 2], ["desk", 0, 1]],
	"casino": [["slot_machine", 4, 7], ["card_table", 1, 2], ["roulette", 0, 1]],
	"lounge": [["sofa", 2, 3], ["card_table", 1, 1], ["plant", 2, 2], ["bar", 0, 1]],
	"gallery": [["statue", 2, 3], ["display_case", 2, 2], ["pillar", 1, 2]],
	"embassy_hall": [["pillar", 3, 4], ["statue", 1, 1], ["plant", 2, 3], ["sofa", 0, 1]],
	"bar": [["bar", 1, 1], ["card_table", 1, 2], ["sofa", 1, 1], ["plant", 1, 1]],
	"trading_floor": [["trading_desk", 3, 5], ["big_screen", 1, 2]],
	"server_room": [["server_rack", 3, 5], ["server_wall", 1, 2]],
	"exec_office": [["desk_big", 1, 1], ["sofa", 1, 1], ["plant", 2, 2], ["big_screen", 1, 1]],
	"glass_hall": [["glass", 2, 3], ["plant", 2, 3], ["pillar", 1, 2]],
	"boss_office": [["pillar", 2, 2], ["plant", 2, 2], ["sofa", 1, 2], ["crate", 0, 1]],
	"vault": [["safe", 2, 3], ["gold_stack", 2, 3], ["shelf", 0, 1]],
}

var room: BuildingRoom
var theme: EnvTheme
var room_type := ""
var rng := RandomNumberGenerator.new()
var _w := 0
var _h := 0
var _blocked: PackedByteArray      # 1 = wall band / prop, 2 = keep-out
var _targets: Array[Vector2i] = []
var _placed: Array = []

## open_gaps: [{local: Vector2, side: int}], keepouts: [[local Vector2, radius]]
func furnish(open_gaps: Array, keepouts: Array, obstacles: Array) -> Array:
	rng.seed = hash(str(room.get_meta("cell", Vector2i.ZERO)) + room_type + str(theme.stage))
	_w = int(ceil(room.room_size.x / CELL))
	_h = int(ceil(room.room_size.y / CELL))
	_blocked = PackedByteArray()
	_blocked.resize(_w * _h)
	# Wall band.
	for y in _h:
		for x in _w:
			var p := _center(x, y)
			if p.x < WALL_BAND or p.y < WALL_BAND or p.x > room.room_size.x - WALL_BAND or p.y > room.room_size.y - WALL_BAND:
				_blocked[y * _w + x] = 1
	# Existing solid obstacles (authored counters): hard blocked.
	for r: Rect2 in obstacles:
		_mark(r.grow(6), 1)
	# Doorway corridors stay clear, and each doorway is a reachability target.
	for gap: Dictionary in open_gaps:
		var at: Vector2 = gap["local"]
		var side: int = gap["side"]
		var inward := Vector2.ZERO
		match side:
			FloorGenerator.NORTH: inward = Vector2(0, 1)
			FloorGenerator.SOUTH: inward = Vector2(0, -1)
			FloorGenerator.EAST: inward = Vector2(-1, 0)
			FloorGenerator.WEST: inward = Vector2(1, 0)
		var depth := 190.0
		var width := 150.0
		var corridor := Rect2()
		if inward.x == 0.0:
			corridor = Rect2(Vector2(at.x - width * 0.5, minf(at.y, at.y + inward.y * depth)), Vector2(width, depth))
		else:
			corridor = Rect2(Vector2(minf(at.x, at.x + inward.x * depth), at.y - width * 0.5), Vector2(depth, width))
		_mark(corridor, 2)
		_targets.append(_cell_of(at + inward * 60.0))
	for k: Array in keepouts:
		var at: Vector2 = k[0]
		var radius: float = k[1]
		_mark(Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), 2)
		_targets.append(_cell_of(at))
	_targets.append(_cell_of(room.room_size * 0.5))
	# Recipe.
	var recipe: Array = RECIPES.get(room_type, [["crate", 1, 2], ["plant", 1, 2]])
	var area_scale := clampf(room.room_size.x * room.room_size.y / (600.0 * 450.0), 1.0, 3.0)
	for entry: Array in recipe:
		var count := rng.randi_range(entry[1], entry[2])
		if count > 1:
			count = mini(int(round(count * sqrt(area_scale))), count * 2)
		for i in count:
			_try_place(entry[0])
	return _placed

func _try_place(kind: String) -> void:
	if not KINDS.has(kind):
		return
	var def: Array = KINDS[kind]
	var base_size: Vector2 = def[0]
	var is_round: bool = def[1]
	var placement: String = def[2]
	for attempt in 26:
		var size := base_size
		var pos := Vector2.ZERO
		match placement:
			"wall":
				var side := rng.randi() % 4
				var margin := WALL_BAND + 4.0
				if side >= 2:
					size = Vector2(base_size.y, base_size.x)
				match side:
					0: pos = Vector2(rng.randf_range(margin + size.x * 0.5, room.room_size.x - margin - size.x * 0.5), margin + size.y * 0.5)
					1: pos = Vector2(rng.randf_range(margin + size.x * 0.5, room.room_size.x - margin - size.x * 0.5), room.room_size.y - margin - size.y * 0.5)
					2: pos = Vector2(margin + size.x * 0.5, rng.randf_range(margin + size.y * 0.5, room.room_size.y - margin - size.y * 0.5))
					3: pos = Vector2(room.room_size.x - margin - size.x * 0.5, rng.randf_range(margin + size.y * 0.5, room.room_size.y - margin - size.y * 0.5))
			"corner":
				var cx := WALL_BAND + 10.0 + size.x * 0.5 if rng.randf() < 0.5 else room.room_size.x - WALL_BAND - 10.0 - size.x * 0.5
				var cy := WALL_BAND + 10.0 + size.y * 0.5 if rng.randf() < 0.5 else room.room_size.y - WALL_BAND - 10.0 - size.y * 0.5
				pos = Vector2(cx, cy) + Vector2(rng.randf_range(0, 50) * (1 if cx < room.room_size.x * 0.5 else -1), rng.randf_range(0, 40) * (1 if cy < room.room_size.y * 0.5 else -1))
			_:
				if rng.randf() < 0.3 and not is_round:
					size = Vector2(base_size.y, base_size.x)
				var inset := WALL_BAND + 50.0
				pos = Vector2(rng.randf_range(inset + size.x * 0.5, room.room_size.x - inset - size.x * 0.5), rng.randf_range(inset + size.y * 0.5, room.room_size.y - inset - size.y * 0.5))
		var rect := Rect2(pos - size * 0.5, size)
		if not _free(rect.grow(10)):
			continue
		var cells := _mark(rect, 1)
		if kind in Prop.FLAT or _connected():
			var prop := Prop.new()
			prop.kind = "crate" if kind == "crate_big" else ("desk" if kind == "desk_big" else ("server_rack" if kind == "server_wall" else kind))
			prop.size = size
			prop.is_round = is_round
			prop.theme = theme
			prop.seed_value = rng.randi()
			prop.position = pos
			room.add_child(prop)
			room.blocked_rects.append(rect.grow(12))
			_placed.append(prop)
			if kind in Prop.FLAT:
				_unmark(cells)
			return
		_unmark(cells)

func _center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, _w - 1), clampi(int(p.y / CELL), 0, _h - 1))

func _mark(r: Rect2, value: int) -> Array:
	var cells: Array = []
	var x0 := clampi(int(floor(r.position.x / CELL)), 0, _w - 1)
	var y0 := clampi(int(floor(r.position.y / CELL)), 0, _h - 1)
	var x1 := clampi(int(ceil(r.end.x / CELL)), 0, _w)
	var y1 := clampi(int(ceil(r.end.y / CELL)), 0, _h)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * _w + x
			if _blocked[i] == 0:
				_blocked[i] = value
				cells.append(i)
	return cells

func _unmark(cells: Array) -> void:
	for i: int in cells:
		_blocked[i] = 0

func _free(r: Rect2) -> bool:
	var x0 := int(floor(r.position.x / CELL))
	var y0 := int(floor(r.position.y / CELL))
	var x1 := int(ceil(r.end.x / CELL))
	var y1 := int(ceil(r.end.y / CELL))
	if x0 < 0 or y0 < 0 or x1 > _w or y1 > _h:
		return false
	for y in range(y0, y1):
		for x in range(x0, x1):
			if _blocked[y * _w + x] != 0:
				return false
	return true

## A cell is walkable when it and its four neighbours are free of solid
## things (keep-out cells count as floor) — a one-cell clearance for bodies.
func _walkable(x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= _w - 1 or y >= _h - 1:
		return false
	for o: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _blocked[(y + o.y) * _w + x + o.x] == 1:
			return false
	return true

func _connected() -> bool:
	if _targets.is_empty():
		return true
	var start := _targets[0]
	if not _walkable(start.x, start.y):
		return false
	var seen := PackedByteArray()
	seen.resize(_w * _h)
	var queue: Array[Vector2i] = [start]
	seen[start.y * _w + start.x] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for o: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + o
			if n.x < 0 or n.y < 0 or n.x >= _w or n.y >= _h:
				continue
			var i := n.y * _w + n.x
			if seen[i] == 1 or not _walkable(n.x, n.y):
				continue
			seen[i] = 1
			queue.append(n)
	for t: Vector2i in _targets:
		if seen[t.y * _w + t.x] == 0:
			return false
	return true
