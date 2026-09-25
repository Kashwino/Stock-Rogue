extends Node2D
class_name GetawayCar

## The getaway car, parked OUTSIDE the building's main door. You start the heist
## standing next to it and you finish by coming back and holding still.
##
## Extraction takes `escape_duration` seconds of standing in the zone. Taking
## any damage cancels it — you can't tank hits while the engine turns over.
## Walking out of the zone cancels it too.

signal extraction_started()
signal extraction_cancelled(reason: String)
signal extracted()

@export var escape_duration: float = 4.0
@export var zone_radius: float = 110.0

## The car won't start until the player has actually been inside. Without this
## you could stand in the ring at spawn and extract with a perfect grade for
## doing nothing. HeistFloor calls arm() the first time the player is detected
## inside the building.
var armed: bool = false

var _player: Node2D = null
var _progress: float = 0.0
var _running: bool = false
var _done: bool = false
var _last_health: int = -1

var _body: Polygon2D
var _ring: Line2D
var _art: Node2D
## Direction the car's nose points (set before adding to the tree).
var facing := Vector2.RIGHT
var _label: Label

func _ready() -> void:
	z_index = 5
	_build_visual()

func _build_visual() -> void:
	# Zone marker on the tarmac.
	_ring = Line2D.new()
	_ring.width = 3.0
	_ring.default_color = Color(0.95, 0.8, 0.3, 0.55)
	_ring.closed = true
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * zone_radius)
	_ring.points = pts
	add_child(_ring)

	# The car itself: a simple body with a roof, pointing away from the door.
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-54, -26), Vector2(54, -26), Vector2(54, 26), Vector2(-54, 26)])
	_body.color = Color(0.17, 0.19, 0.26)
	add_child(_body)

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-22, -18), Vector2(20, -18), Vector2(20, 18), Vector2(-22, 18)])
	roof.color = Color(0.28, 0.31, 0.40)
	add_child(roof)
	_body.hide()
	roof.hide()
	_art = CarArt.new()
	_art.rotation = facing.angle()
	add_child(_art)

	# Anchor a Control label into world space via this Node2D.
	var anchor := Node2D.new()
	anchor.position = Vector2(0, -zone_radius - 34)
	add_child(anchor)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(260, 0)
	_label.position = Vector2(-130, 0)
	_label.material = StreetArt._unshaded()
	HudKit.style_label(_label, 14, Palette.GOLD)
	anchor.add_child(_label)
	_reset_label()

func bind_player(p: Node2D) -> void:
	_player = p

## Called once the player has been inside the building. Until then the car
## refuses to start.
func arm() -> void:
	if armed:
		return
	armed = true
	_reset_label()

func _reset_label() -> void:
	if armed:
		_label.text = "GETAWAY CAR — stand here to escape"
		_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	else:
		_label.text = "GETAWAY CAR — locked"
		_label.add_theme_color_override("font_color", Color(0.55, 0.56, 0.62))
	_ring.default_color = Color(0.95, 0.8, 0.3, 0.55) if armed \
		else Color(0.5, 0.5, 0.55, 0.3)
	_ring.width = 3.0

func _process(delta: float) -> void:
	if _done or _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("is_dead") and _player.is_dead():
		_cancel("down")
		return

	var scene := get_tree().current_scene
	if scene is HeistFloor and scene.requires_boss_kill():
		_label.text = "THE BOSS STILL STANDS — NO RUNNING"
		return

	var inside := global_position.distance_to(_player.global_position) <= zone_radius

	# Not armed yet: you haven't set foot in the building. Standing here does
	# nothing except tell you so.
	if not armed:
		if inside:
			_label.text = "NOTHING TO RUN WITH — get inside"
			_label.add_theme_color_override("font_color", Color(0.62, 0.63, 0.7))
		else:
			_reset_label()
		return

	# Any damage taken while escaping resets the attempt.
	var hp: int = _player.health
	if _last_health >= 0 and hp < _last_health and _running:
		_last_health = hp
		_cancel("hit")
		return
	_last_health = hp

	if inside:
		if not _running:
			_running = true
			_progress = 0.0
			extraction_started.emit()
		# The police helicopter's light on you: the driver won't pull out.
		if scene is HeistFloor and scene.spotlit():
			_label.text = "SPOTLIGHT — wait for the dark"
			_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
			return
		_progress += delta
		_update_label()
		if _progress >= escape_duration:
			_finish()
	elif _running:
		_cancel("left")

func _update_label() -> void:
	var remaining: float = maxf(escape_duration - _progress, 0.0)
	_label.text = "ESCAPING…  %.1f" % remaining
	_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	# Ring fills up as the clock runs down.
	var t: float = _progress / escape_duration
	_ring.default_color = Color(0.45, 0.95, 0.55, 0.35 + 0.5 * t)
	_ring.width = 3.0 + 5.0 * t

func _cancel(reason: String) -> void:
	if not _running:
		return
	_running = false
	_progress = 0.0
	_reset_label()
	if reason == "hit":
		_label.text = "HIT! — get clear and try again"
		_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	extraction_cancelled.emit(reason)

func _finish() -> void:
	_done = true
	_running = false
	_label.text = "GONE."
	extracted.emit()

## Two headlight cones plus tail-light glow, owned by the heist's lighting.
func add_headlights(lighting: HeistLighting) -> void:
	if lighting == null or not lighting.enabled:
		return
	var across := Vector2(-facing.y, facing.x)
	for side in [-1.0, 1.0]:
		var beam := PointLight2D.new()
		beam.texture = HeistLighting.cone()
		beam.texture_scale = 2.4
		beam.color = Color("fff0c8")
		beam.energy = 0.9
		beam.position = facing * 62.0 + across * side * 20.0
		beam.rotation = facing.angle()
		add_child(beam)
	var tail := PointLight2D.new()
	tail.texture = HeistLighting.radial()
	tail.texture_scale = 0.9
	tail.color = Color("ff2a2a")
	tail.energy = 0.7
	tail.position = -facing * 64.0
	add_child(tail)


class CarArt extends Node2D:
	## The getaway car: a long black sedan with gold pinstripe, nose along +X.
	func _ready() -> void:
		z_index = 1
		queue_redraw()
	func _draw() -> void:
		var body := Rect2(-66, -30, 132, 60)
		draw_rect(Rect2(body.position + Vector2(6, 8), body.size), Color(0, 0, 0, 0.45))
		for p in [Vector2(-50, -34), Vector2(30, -34), Vector2(-50, 26), Vector2(30, 26)]:
			draw_rect(Rect2(p, Vector2(24, 8)), Color("050506"))
		draw_rect(body, Color("15161b"))
		draw_rect(Rect2(-60, -26, 120, 52), Color("1f2128"))
		draw_line(Vector2(-60, -22), Vector2(60, -22), Palette.GOLD_DIM, 1.5)
		draw_line(Vector2(-60, 22), Vector2(60, 22), Palette.GOLD_DIM, 1.5)
		# Glass and roof.
		draw_rect(Rect2(8, -22, 22, 44), Color("0f2230"))
		draw_rect(Rect2(-34, -22, 14, 44), Color("0f2230"))
		draw_rect(Rect2(-20, -24, 28, 48), Color("26282f"))
		draw_line(Vector2(10, -18), Vector2(26, 6), Color(1, 1, 1, 0.12), 3.0)
		# Lights.
		draw_rect(Rect2(60, -24, 7, 12), Color("fff4cc"))
		draw_rect(Rect2(60, 12, 7, 12), Color("fff4cc"))
		draw_rect(Rect2(-68, -24, 5, 10), Color("d02a2a"))
		draw_rect(Rect2(-68, 14, 5, 10), Color("d02a2a"))
		draw_rect(body, Color("050506"), false, 2.0)
