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
	var illustration := PropArt.new()
	illustration.kind = "car"
	illustration.position = Vector2(60, 38)
	add_child(illustration)

	# Anchor a Control label into world space via this Node2D.
	var anchor := Node2D.new()
	anchor.position = Vector2(0, -zone_radius - 34)
	add_child(anchor)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(220, 0)
	_label.position = Vector2(-110, 0)
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
	if scene is HeistFloor and RunState.run_map and RunState.run_map.current_stage == 3 and not scene.marked:
		_label.text = "DEFEAT THE AUDITOR BEFORE ESCAPING"
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
