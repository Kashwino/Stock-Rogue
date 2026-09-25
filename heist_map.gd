extends Control
class_name HeistMap
var floor_host: Node
var discovered: Dictionary = {}
var bounds := Rect2()
var full_reveal := false
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(330, 170)
	size = Vector2(620, 360)
	for room in floor_host.generator.rooms:
		var rect := Rect2(room.global_position, room.room_size)
		bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	bounds = bounds.merge(Rect2(floor_host.car.global_position - Vector2(60, 60), Vector2(120, 120)))

func _process(delta: float) -> void:
	clock += delta
	if clock < 0.15:
		return
	clock = 0.0
	for room in floor_host.generator.rooms:
		if Rect2(room.global_position, room.room_size).has_point(floor_host.player.global_position):
			discovered[room.get_instance_id()] = true
	if visible:
		queue_redraw()

func _draw() -> void:
	if bounds.size == Vector2.ZERO:
		return
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var scale_factor: float = minf((size.x - 40) / bounds.size.x, (size.y - 95) / bounds.size.y)
	var origin := Vector2((size.x - bounds.size.x * scale_factor) * 0.5, 40)
	draw_string(ThemeDB.fallback_font, Vector2(20, 25), "INSIDER: FULL LAYOUT" if full_reveal else "EXPLORED ROOMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	for room in floor_host.generator.rooms:
		if not full_reveal and not discovered.has(room.get_instance_id()):
			continue
		var rect := Rect2(origin + (room.global_position - bounds.position) * scale_factor, room.room_size * scale_factor)
		var color := Color(0.22, 0.23, 0.28)
		if room.has_meta("is_boss"):
			color = Color(0.55, 0.16, 0.2)
		elif room.has_meta("chest_kind"):
			color = Palette.GOLD_DIM
		draw_rect(rect.grow(-2), color)
		draw_rect(rect.grow(-2), Palette.with_alpha(Palette.PAPER, 0.35), false, 1)
	for gap: Dictionary in [floor_host.generator.entrance] + floor_host.generator.exits:
		if gap.is_empty() or (not full_reveal and not discovered.has(gap["room"].get_instance_id())):
			continue
		var at: Vector2 = origin + (gap["inside_pos"] - bounds.position) * scale_factor
		draw_circle(at, 5, Color(0.3, 1, 0.5) if gap.get("open", true) else Color(1, 0.2, 0.2))
	draw_circle(origin + (floor_host.player.global_position - bounds.position) * scale_factor, 5, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 33), "White: YOU   Red room: BOSS   Gold room: CHEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 12), "Exits: green / sealed red    ·    MAP to resume", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _exit_tree() -> void:
	if visible:
		get_tree().paused = false

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.BG, 0.97)
	style.border_color = Palette.GOLD_DIM
	style.set_border_width_all(2)
	return style
