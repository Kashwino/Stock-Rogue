extends RefCounted
class_name EnvTheme
## Per-stage environment art direction: materials, lamp colours, darkness and
## which room types (and therefore furniture) a building of that stage has.
##   Town     pawn shops, garages, warehouses — concrete, brick, crates
##   City     offices and banks — carpet, drywall, desks, filing cabinets
##   World    casinos and embassies — marble, velvet, wood panelling, gold
##   Doomsday the Exchange tower — dark glass, server racks, trading desks

var stage := 0
var name := "town"
var floor_style := "concrete"
var floor_a := Color("3a3632")
var floor_b := Color("332f2b")
var accent := Color("b8893a")
var wall_top := Color("6e4a3c")
var wall_face := Color("3e2922")
var baseboard := Color("1b1412")
var lamp := Color("ffb45e")
var lamp_energy := 0.95
var flicker_chance := 0.25
var ambient := Color(0.34, 0.33, 0.42)
var room_types: Array = []
var rug := Color("4a2a2a")

static func for_stage(stage_index: int) -> EnvTheme:
	var t := EnvTheme.new()
	t.stage = clampi(stage_index, 0, 3)
	match t.stage:
		0:
			t.name = "town"
			t.floor_style = "concrete"
			t.floor_a = Color("3b3834")
			t.floor_b = Color("34312d")
			t.accent = Color("c9962f")
			t.wall_top = Color("7a4d3d")
			t.wall_face = Color("40271f")
			t.baseboard = Color("1a1210")
			t.lamp = Color("ffb35a")
			t.flicker_chance = 0.3
			t.ambient = Color(0.36, 0.34, 0.42)
			t.room_types = ["warehouse", "pawnshop", "garage", "backoffice", "storage"]
			t.rug = Color("5a3a2a")
		1:
			t.name = "city"
			t.floor_style = "carpet"
			t.floor_a = Color("2d3645")
			t.floor_b = Color("283040")
			t.accent = Color("8ea9c9")
			t.wall_top = Color("8c8f96")
			t.wall_face = Color("4a4d55")
			t.baseboard = Color("15171c")
			t.lamp = Color("d6ecff")
			t.lamp_energy = 0.85
			t.flicker_chance = 0.12
			t.ambient = Color(0.32, 0.35, 0.46)
			t.room_types = ["office", "cubicles", "bank_hall", "meeting", "records"]
			t.rug = Color("1f3a52")
		2:
			t.name = "world"
			t.floor_style = "marble"
			t.floor_a = Color("5a5248")
			t.floor_b = Color("4e473f")
			t.accent = Palette.GOLD
			t.wall_top = Color("5a3624")
			t.wall_face = Color("2e1a12")
			t.baseboard = Color("171008")
			t.lamp = Color("ffd38a")
			t.lamp_energy = 1.0
			t.flicker_chance = 0.05
			t.ambient = Color(0.36, 0.3, 0.36)
			t.room_types = ["casino", "lounge", "gallery", "embassy_hall", "bar"]
			t.rug = Color("6a1622")
		3:
			t.name = "doomsday"
			t.floor_style = "glass"
			t.floor_a = Color("15191f")
			t.floor_b = Color("11151a")
			t.accent = Palette.NEON_CYAN
			t.wall_top = Color("3a4450")
			t.wall_face = Color("181d24")
			t.baseboard = Color("0a0d11")
			t.lamp = Color("9fe8ff")
			t.lamp_energy = 0.9
			t.flicker_chance = 0.1
			t.ambient = Color(0.26, 0.3, 0.4)
			t.room_types = ["trading_floor", "server_room", "exec_office", "glass_hall"]
			t.rug = Color("10262e")
	return t

## Room type for a generated room: lobby, boss office and vault are fixed;
## everything else comes from the stage list, seeded by the room's position.
func room_type_for(room: Node, is_start: bool) -> String:
	if room.has_meta("authored_type"):
		return room.get_meta("authored_type")
	if is_start:
		return "lobby"
	if room.has_meta("is_boss"):
		return "boss_office"
	if room.has_meta("chest_kind"):
		return "vault"
	var cell: Vector2i = room.get_meta("cell", Vector2i.ZERO)
	var h := absi(hash(str(cell) + name))
	return room_types[h % room_types.size()]
