extends Node2D
class_name StreetArt
## Everything outside the building: rain-slick asphalt (shader), a sidewalk
## ring with a kerb, lane markings and a crosswalk at the front door, lamp
## posts with sodium pools, parked cars, rooftops beyond, and the venue's neon
## sign over the main entrance.

var bounds := Rect2()
var door_pos := Vector2.ZERO        # world position of the main door (wall)
var door_out := Vector2.DOWN        # outward direction from the door
var sign_text := ""
var theme: EnvTheme
var lighting: HeistLighting
var neon := Palette.NEON_MAGENTA
var _lamp_posts: Array[Vector2] = []
var _cars: Array = []

func _ready() -> void:
	z_index = -20
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sign_text)
	neon = [Palette.NEON_MAGENTA, Palette.NEON_CYAN, Color("ff5a3a"), Palette.NEON_GREEN][rng.randi() % 4]
	_build_asphalt()
	var walk := bounds.grow(110)
	# Lamp posts every ~420 px along the kerb.
	var kerb := bounds.grow(128)
	var step := 420.0
	var x := kerb.position.x + 60.0
	while x < kerb.end.x:
		_lamp_posts.append(Vector2(x, kerb.position.y))
		_lamp_posts.append(Vector2(x, kerb.end.y))
		x += step
	var y := kerb.position.y + 200.0
	while y < kerb.end.y - 100.0:
		_lamp_posts.append(Vector2(kerb.position.x, y))
		_lamp_posts.append(Vector2(kerb.end.x, y))
		y += step
	for p in _lamp_posts:
		if lighting:
			lighting.add_street_lamp(p + (p - bounds.get_center()).normalized() * 30.0, Palette.SODIUM, 2.3, 0.9)
	# Parked cars along the far side of the road.
	for i in 6:
		var side := rng.randi() % 4
		var along := rng.randf_range(0.1, 0.9)
		var road := bounds.grow(330)
		var at := Vector2.ZERO
		var horizontal := side < 2
		match side:
			0: at = Vector2(road.position.x + road.size.x * along, road.position.y)
			1: at = Vector2(road.position.x + road.size.x * along, road.end.y)
			2: at = Vector2(road.position.x, road.position.y + road.size.y * along)
			3: at = Vector2(road.end.x, road.position.y + road.size.y * along)
		if at.distance_to(door_pos + door_out * 190.0) < 300.0:
			continue
		_cars.append([at, horizontal, [Color("5a1f22"), Color("22364a"), Color("2f3a2a"), Color("6a6a70"), Color("1a1a1e")][rng.randi() % 5]])
	_build_sign()
	queue_redraw()
	walk.size = walk.size

func _build_asphalt() -> void:
	var outer := bounds.grow(1400)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)])
	poly.z_index = -1
	poly.z_as_relative = true
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/wet_street.gdshader")
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	mat.set_shader_parameter("puddle_noise", tex)
	poly.material = mat
	add_child(poly)

func _draw() -> void:
	var road := bounds.grow(330)
	var walk := bounds.grow(128)
	# Rooftops beyond the road: dark blocks with vents and AC units.
	var far := bounds.grow(1400)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for band in [Rect2(far.position, Vector2(far.size.x, road.position.y - 70 - far.position.y)),
			Rect2(Vector2(far.position.x, road.end.y + 70), Vector2(far.size.x, far.end.y - road.end.y - 70)),
			Rect2(Vector2(far.position.x, road.position.y - 70), Vector2(road.position.x - 70 - far.position.x, road.size.y + 140)),
			Rect2(Vector2(road.end.x + 70, road.position.y - 70), Vector2(far.end.x - road.end.x - 70, road.size.y + 140))]:
		draw_rect(band, Color("0c0d10"))
		var bx: float = band.position.x
		while bx < band.end.x:
			var w := rng.randf_range(160, 320)
			var roof := Rect2(Vector2(bx + 8, band.position.y + 8), Vector2(minf(w, band.end.x - bx) - 16, band.size.y - 16))
			draw_rect(roof, Color("16171c").lerp(Color("1d1a1a"), rng.randf()))
			draw_rect(roof, Color("0a0a0c"), false, 3.0)
			for k in 3:
				var vent := Rect2(roof.position + Vector2(rng.randf() * maxf(roof.size.x - 40, 1), rng.randf() * maxf(roof.size.y - 30, 1)), Vector2(34, 22))
				draw_rect(vent, Color("24262c"))
				draw_rect(vent, Color("0c0c0f"), false, 1.5)
			bx += w
	# Sidewalk ring and kerb.
	draw_rect(walk, Color("2c2d33"))
	for xx in range(int(walk.position.x), int(walk.end.x), 60):
		draw_line(Vector2(xx, walk.position.y), Vector2(xx, walk.position.y + 128 - 110), Color(0, 0, 0, 0.35), 1.0)
		draw_line(Vector2(xx, walk.end.y - 18), Vector2(xx, walk.end.y), Color(0, 0, 0, 0.35), 1.0)
	draw_rect(walk, Color("5a5a62"), false, 4.0)
	draw_rect(bounds.grow(14), Color("1a1a1f"))
	# Lane markings on the road ring.
	var mid := bounds.grow(230)
	var dash := 60.0
	var px := mid.position.x
	while px < mid.end.x:
		draw_rect(Rect2(px, mid.position.y - 2, 34, 4), Color("b8a45a"))
		draw_rect(Rect2(px, mid.end.y - 2, 34, 4), Color("b8a45a"))
		px += dash
	var py := mid.position.y
	while py < mid.end.y:
		draw_rect(Rect2(mid.position.x - 2, py, 4, 34), Color("b8a45a"))
		draw_rect(Rect2(mid.end.x - 2, py, 4, 34), Color("b8a45a"))
		py += dash
	# Crosswalk from the door to the car.
	var cw := door_pos + door_out * 250.0
	var across := Vector2(-door_out.y, door_out.x)
	for i in range(-4, 5):
		var c := cw + across * i * 24.0
		var pts := PackedVector2Array([c - across * 7 - door_out * 60, c + across * 7 - door_out * 60, c + across * 7 + door_out * 60, c - across * 7 + door_out * 60])
		draw_colored_polygon(pts, Color(0.85, 0.85, 0.8, 0.35))
	# Lamp posts.
	for p in _lamp_posts:
		draw_circle(p + Vector2(3, 4), 9, Color(0, 0, 0, 0.4))
		draw_circle(p, 8, Color("2a2c30"))
		draw_circle(p, 4, Color("ffcf8a"))
	# Parked cars.
	for car: Array in _cars:
		var at: Vector2 = car[0]
		var size := Vector2(120, 56) if car[1] else Vector2(56, 120)
		var r := Rect2(at - size * 0.5, size)
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.4))
		draw_rect(r, car[2])
		var glass := r.grow(-10)
		if car[1]:
			glass = Rect2(r.position + Vector2(r.size.x * 0.3, 7), Vector2(r.size.x * 0.4, r.size.y - 14))
		else:
			glass = Rect2(r.position + Vector2(7, r.size.y * 0.3), Vector2(r.size.x - 14, r.size.y * 0.4))
		draw_rect(glass, Color("1a2630"))
		draw_line(glass.position + Vector2(4, 4), glass.get_center(), Color(1, 1, 1, 0.12), 3.0)
		draw_rect(r, Color("08080a"), false, 2.0)

func _build_sign() -> void:
	if sign_text == "":
		return
	var holder := Node2D.new()
	holder.z_index = 30
	holder.z_as_relative = false
	var along := Vector2(-door_out.y, door_out.x)
	holder.position = door_pos + door_out * 44.0 + along * 150.0
	add_child(holder)
	var plate := ColorRect.new()
	var label := Label.new()
	label.text = sign_text
	var settings := LabelSettings.new()
	settings.font = VisualTheme.font("heading_bold")
	settings.font_size = 30
	settings.font_color = neon.lightened(0.55)
	settings.outline_size = 10
	settings.outline_color = Palette.with_alpha(neon, 0.85)
	settings.shadow_size = 18
	settings.shadow_color = Palette.with_alpha(neon, 0.45)
	settings.shadow_offset = Vector2.ZERO
	label.label_settings = settings
	var width := settings.font.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 40
	label.size = Vector2(width, 50)
	label.position = Vector2(-width * 0.5, -25)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.color = Color(0.03, 0.03, 0.04, 0.9)
	plate.size = Vector2(width + 16, 58)
	plate.position = Vector2(-width * 0.5 - 8, -29)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(plate)
	holder.add_child(label)
	label.material = _unshaded()
	plate.material = _unshaded()
	if lighting:
		lighting.add_street_lamp(holder.position + door_out * 40.0, neon, 2.6, 0.8)
	if not Settings.values.get("reduce_flashing", false):
		var tw := label.create_tween().set_loops()
		tw.tween_interval(2.4)
		tw.tween_property(label, "modulate:a", 0.35, 0.05)
		tw.tween_property(label, "modulate:a", 1.0, 0.05)
		tw.tween_interval(0.12)
		tw.tween_property(label, "modulate:a", 0.5, 0.04)
		tw.tween_property(label, "modulate:a", 1.0, 0.06)

static func _unshaded() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


## Rain that falls only on the street: drawn under the building's floors, it
## follows the camera so a single emitter covers the view.
class Rain extends Node2D:
	var follow: Node2D
	var streaks: CPUParticles2D
	var splashes: CPUParticles2D

	func _ready() -> void:
		z_index = -15
		var heavy: bool = not Settings.values.get("low_effects", false)
		streaks = CPUParticles2D.new()
		streaks.amount = 260 if heavy else 90
		streaks.lifetime = 0.45
		streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		streaks.emission_rect_extents = Vector2(900, 600)
		streaks.direction = Vector2(0.35, 1.0)
		streaks.spread = 3.0
		streaks.gravity = Vector2.ZERO
		streaks.initial_velocity_min = 700.0
		streaks.initial_velocity_max = 900.0
		streaks.particle_flag_align_y = true
		streaks.local_coords = false
		streaks.texture = _streak()
		streaks.color = Color(0.72, 0.8, 0.95, 0.42)
		add_child(streaks)
		splashes = CPUParticles2D.new()
		splashes.amount = 120 if heavy else 40
		splashes.lifetime = 0.35
		splashes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		splashes.emission_rect_extents = Vector2(900, 600)
		splashes.gravity = Vector2.ZERO
		splashes.initial_velocity_min = 0.0
		splashes.initial_velocity_max = 0.0
		splashes.local_coords = false
		splashes.texture = _ring()
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.2))
		curve.add_point(Vector2(1, 1.0))
		splashes.scale_amount_curve = curve
		var fade := Gradient.new()
		fade.set_color(0, Color(0.8, 0.88, 1.0, 0.45))
		fade.set_color(1, Color(0.8, 0.88, 1.0, 0.0))
		splashes.color_ramp = fade
		add_child(splashes)

	func _process(_delta: float) -> void:
		if is_instance_valid(follow):
			global_position = follow.global_position

	static func _streak() -> Texture2D:
		var img := Image.create_empty(2, 22, false, Image.FORMAT_RGBA8)
		for y in 22:
			img.set_pixel(0, y, Color(1, 1, 1, float(y) / 22.0))
			img.set_pixel(1, y, Color(1, 1, 1, float(y) / 30.0))
		return ImageTexture.create_from_image(img)

	static func _ring() -> Texture2D:
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x - 7.5, y - 7.5).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - absf(d - 6.0) / 1.5, 0.0, 1.0)))
		return ImageTexture.create_from_image(img)
