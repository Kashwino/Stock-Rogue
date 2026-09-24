extends Node2D
class_name HeistLighting
## Night lighting for a heist: CanvasModulate darkness, ceiling lamps per room
## (a few flicker), the player's flashlight cone plus a small glow so the
## player always reads, muzzle-flash lights, street lamps, police light sweeps
## at high heat, and optional LightOccluder2D wall shadows.
## Lamps far from the player are switched off at 4 Hz to keep mobile GPUs fed.

const LAMP_RANGE := 1250.0

static var _radial: Texture2D
static var _cone: Texture2D

var theme: EnvTheme
var player: Node2D
var darkness := 1.0                  # 1 normal, >1 darker (Blackout)
var canvas_modulate: CanvasModulate
var flashlight: PointLight2D
var glow: PointLight2D
var lamps: Array[PointLight2D] = []
var police: Array[PointLight2D] = []
var police_active := false
var enabled := true
var shadows := false
var _cull_clock := 0.0
var _t := 0.0
var _muzzle_pool: Array[PointLight2D] = []

static func radial() -> Texture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.42))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_radial = t
	return _radial

## A forward cone pointing +X, origin at the image's left-centre.
static func cone() -> Texture2D:
	if _cone == null:
		var size := 256
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var origin := Vector2(size * 0.5, size * 0.5)
		for y in size:
			for x in size:
				var d := Vector2(x, y) - origin
				var dist := d.length() / (size * 0.5)
				var ang := absf(d.angle())
				var a := 0.0
				if dist < 1.0 and d.x > 0.0:
					var edge := clampf((0.52 - ang) / 0.2, 0.0, 1.0)
					a = edge * pow(1.0 - dist, 0.8)
				if dist < 0.12:
					a = maxf(a, (0.12 - dist) / 0.12 * 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_cone = ImageTexture.create_from_image(img)
	return _cone

func setup(env: EnvTheme, rooms: Array, hero: Node2D, blackout: bool) -> void:
	theme = env
	player = hero
	enabled = not Settings.values.get("low_effects", false)
	shadows = enabled and Settings.values.get("dynamic_shadows", false)
	darkness = 1.9 if blackout else 1.0
	if not enabled:
		return
	canvas_modulate = CanvasModulate.new()
	var amb := theme.ambient
	canvas_modulate.color = Color(amb.r / darkness, amb.g / darkness, amb.b / darkness)
	add_child(canvas_modulate)
	for room in rooms:
		_room_lamps(room, blackout)
	_player_lights()

func _room_lamps(room: Node2D, blackout: bool) -> void:
	var size: Vector2 = room.room_size
	var modules := Vector2i(maxi(1, int(round(size.x / 600.0))), maxi(1, int(round(size.y / 450.0))))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room.get_meta("cell", Vector2i.ZERO))
	for mx in modules.x:
		for my in modules.y:
			if blackout and rng.randf() < 0.75:
				continue
			var lamp := PointLight2D.new()
			lamp.texture = radial()
			lamp.texture_scale = 2.9
			lamp.color = theme.lamp
			lamp.energy = theme.lamp_energy * (0.55 if blackout else 1.0)
			lamp.position = room.position + Vector2(300.0 + mx * 600.0, 225.0 + my * 450.0) + Vector2(rng.randf_range(-60, 60), rng.randf_range(-40, 40))
			lamp.shadow_enabled = shadows
			lamp.shadow_filter = Light2D.SHADOW_FILTER_PCF5
			lamp.set_meta("base_energy", lamp.energy)
			if rng.randf() < theme.flicker_chance:
				lamp.set_meta("flicker", rng.randf_range(0.0, 10.0))
			add_child(lamp)
			lamps.append(lamp)

func _player_lights() -> void:
	flashlight = PointLight2D.new()
	flashlight.texture = cone()
	flashlight.texture_scale = 3.4
	flashlight.energy = 0.95 if darkness > 1.0 else 0.55
	flashlight.color = Color("fff1d6")
	flashlight.shadow_enabled = shadows
	add_child(flashlight)
	glow = PointLight2D.new()
	glow.texture = radial()
	glow.texture_scale = 1.25
	glow.energy = 0.7
	glow.color = Color("ffe9c4")
	add_child(glow)

## Street lamps (sodium pools) around the building, plus the neon sign's spill.
func add_street_lamp(at: Vector2, color: Color = Palette.SODIUM, scale_factor: float = 2.2, energy: float = 1.0) -> PointLight2D:
	if not enabled:
		return null
	var lamp := PointLight2D.new()
	lamp.texture = radial()
	lamp.texture_scale = scale_factor
	lamp.color = color
	lamp.energy = energy
	lamp.position = at
	lamp.set_meta("base_energy", energy)
	add_child(lamp)
	lamps.append(lamp)
	return lamp

## Red/blue police sweeps outside the entrance once the response is rolling.
func set_police(active: bool, near: Vector2) -> void:
	if not enabled or active == police_active:
		return
	police_active = active
	if active and police.is_empty():
		for i in 2:
			var l := PointLight2D.new()
			l.texture = radial()
			l.texture_scale = 3.2
			l.color = Palette.POLICE_RED if i == 0 else Palette.POLICE_BLUE
			l.energy = 0.0
			l.position = near + Vector2(-120 + i * 240, 0)
			add_child(l)
			police.append(l)
	for l in police:
		l.visible = active

## Brief bright flash at a gunshot. Pooled.
func muzzle_flash(at: Vector2, color: Color = Color("ffd89a")) -> void:
	if not enabled:
		return
	var light: PointLight2D = null
	for l in _muzzle_pool:
		if not l.visible:
			light = l
			break
	if light == null:
		if _muzzle_pool.size() >= 6:
			return
		light = PointLight2D.new()
		light.texture = radial()
		light.texture_scale = 1.6
		add_child(light)
		_muzzle_pool.append(light)
	light.position = at
	light.color = color
	light.energy = 1.4
	light.visible = true
	var tw := light.create_tween()
	tw.tween_property(light, "energy", 0.0, 0.07)
	tw.tween_callback(light.hide)

## Wall shadows: one occluder per wall slab (only with Dynamic shadows on).
func add_occluders(rects: Array) -> void:
	if not shadows:
		return
	for r: Rect2 in rects:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		occ.occluder = poly
		add_child(occ)

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(player):
		return
	_t += delta
	var aim := Vector2.RIGHT
	if player.has_method("aim_direction"):
		aim = player.aim_direction()
	flashlight.global_position = player.global_position
	flashlight.rotation = aim.angle()
	glow.global_position = player.global_position
	for l in lamps:
		if l.visible and l.has_meta("flicker"):
			var phase: float = l.get_meta("flicker")
			var f := sin(_t * 23.0 + phase) * sin(_t * 3.1 + phase * 2.0)
			l.energy = float(l.get_meta("base_energy")) * (0.35 if f > 0.82 else 1.0)
	if police_active:
		for i in police.size():
			police[i].energy = maxf(0.0, sin(_t * 9.0 + i * PI)) * 1.3
	_cull_clock -= delta
	if _cull_clock <= 0.0:
		_cull_clock = 0.25
		var p := player.global_position
		for l in lamps:
			l.visible = l.global_position.distance_squared_to(p) < LAMP_RANGE * LAMP_RANGE
