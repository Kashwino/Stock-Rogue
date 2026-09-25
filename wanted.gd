extends Node2D
class_name Wanted
## WANTED: heat read as 0-5 stars. Stars only ever go up during a heist.
##   1★ heat 4 · 2★ 8 · 3★ 12 (exactly when the fire exits seal) · 4★ 20 · 5★ 30
## A boss marked forces at least 3★.
## Laying low: after 20 s with nobody hunting you, heat drifts down 0.2/s —
## but never below the floor of the stars you've earned.
## On top of the van escalation, the street reacts:
##   3★ distant sirens · 4★ police cruisers park outside, lights and sirens ·
##   5★ a helicopter spotlight sweeps the street and the building's outside;
##   standing in it stops the getaway-car clock and shows you to any guard
##   outside.
## Nothing here collides (visual only; layer none).

signal star_gained(stars: int)

const THRESHOLDS := [4.0, 8.0, 12.0, 20.0, 30.0]
const LAY_LOW_AFTER := 20.0
const LAY_LOW_RATE := 0.2
const SPOT_RADIUS := 95.0

var host: Node
var stars := 0
## Diplomatic Cover (a flipped Ambassador) caps this at 4.
var cap := 5
var lay_low := 0.0              # seconds with nobody hunting you
var hunters := 0
var _scan := 0.0
var _cruisers: Array = []
var _heli: Heli = null

func setup(floor_host: Node) -> void:
	host = floor_host
	cap = RunState.wanted_cap()

static func stars_for(heat: float) -> int:
	var n := 0
	for t: float in THRESHOLDS:
		if heat >= t:
			n += 1
	return n

## The heat the current stars won't let you drop below.
func floor_heat() -> float:
	return 0.0 if stars <= 0 else THRESHOLDS[stars - 1]

## Heat went up: maybe a star.
func on_heat(heat: float) -> void:
	var now := mini(stars_for(heat), cap)
	while stars < now:
		stars += 1
		_on_star(stars)

## Force at least `n` stars (a boss marked, a suspicious Board).
func force(n: int) -> void:
	n = mini(n, cap)
	while stars < n:
		stars += 1
		_on_star(stars)

func _on_star(n: int) -> void:
	star_gained.emit(n)
	Audio.sting("star_up")
	Audio.play("siren_blip")
	if n >= 3:
		Audio.loop("sirens_far", true, -6.0 if n == 3 else -14.0)
	if n >= 4 and _cruisers.is_empty():
		_park_cruisers()
		Audio.loop("sirens_near", true)
	if n >= 5 and _heli == null:
		_heli = Heli.new()
		_heli.bounds = host.building_bounds if host and "building_bounds" in host else Rect2(0, 0, 2000, 1500)
		add_child(_heli)
		Audio.loop("heli", true)

func _park_cruisers() -> void:
	if host == null or host.car == null:
		return
	var car: Node2D = host.car
	# Up and down the street from the getaway car, noses toward it.
	var along: Vector2 = car.facing if "facing" in car else Vector2.RIGHT
	for side in [-1, 1]:
		var c := Cruiser.new()
		c.facing = -along * side
		add_child(c)
		c.global_position = car.global_position + along * side * 330.0
		_cruisers.append(c)

## Per frame from the heist: count hunters, advance laying-low.
func tick(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		hunters = 0
		if host and host.director:
			for e in host.director.enemies:
				if is_instance_valid(e) and not e._dead and e.hunting and e.get("_player") == host.player:
					hunters += 1
	if hunters > 0:
		lay_low = 0.0
	else:
		lay_low += delta
	if _heli and host and is_instance_valid(host.player) and spotlit(host.player.global_position):
		_reveal()

func laying_low() -> bool:
	return lay_low >= LAY_LOW_AFTER

## In the helicopter's light (outside the building only).
func spotlit(at: Vector2) -> bool:
	if _heli == null:
		return false
	if host and "building_bounds" in host and host.building_bounds.has_point(at):
		return false
	return at.distance_to(_heli.spot) <= SPOT_RADIUS

func _reveal() -> void:
	for e in (host.director.enemies if host.director else []):
		if not is_instance_valid(e) or e._dead or e.hunting:
			continue
		if host.building_bounds.has_point(e.global_position):
			continue
		if e.global_position.distance_to(host.player.global_position) < 900.0:
			e._provoked = true
			e.hunting = true
			e.wake_for(6.0)

func _exit_tree() -> void:
	Audio.loop("sirens_far", false)
	Audio.loop("sirens_near", false)
	Audio.loop("heli", false)


## A patrol car on the kerb with its light bar going.
class Cruiser extends Node2D:
	var facing := Vector2.RIGHT
	var _t := 0.0

	func _ready() -> void:
		z_index = 3
		rotation = facing.angle()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-54, -26, 108, 52), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(-52, -24, 104, 48), Color("1b1e24"))
		draw_rect(Rect2(-52, -24, 104, 48), Color("4a505c"), false, 2.0)
		draw_rect(Rect2(-28, -24, 56, 48), Color("e9e6df"))
		draw_rect(Rect2(-18, -19, 32, 38), Color("2a3342"))
		draw_rect(Rect2(44, -20, 6, 10), Color("fff3c4"))
		draw_rect(Rect2(44, 10, 6, 10), Color("fff3c4"))
		var calm: bool = Settings.values.get("reduce_flashing", false)
		var phase := fmod(_t, 0.5) < 0.25
		var red := Palette.POLICE_RED if (phase or calm) else Palette.POLICE_RED.darkened(0.6)
		var blue := Palette.POLICE_BLUE if (not phase or calm) else Palette.POLICE_BLUE.darkened(0.6)
		draw_rect(Rect2(-4, -20, 8, 18), red)
		draw_rect(Rect2(-4, 2, 8, 18), blue)
		if not calm:
			draw_circle(Vector2(0, -12), 60.0, Palette.with_alpha(red, 0.08))
			draw_circle(Vector2(0, 12), 60.0, Palette.with_alpha(blue, 0.08))


## The police helicopter's searchlight, sweeping the outside of the building.
class Heli extends Node2D:
	var bounds := Rect2()
	var spot := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		z_index = 40
		material = StreetArt._unshaded()

	func _process(delta: float) -> void:
		_t += delta
		# A slow lap just outside the walls, with a wobble.
		var grown := bounds.grow(150.0)
		var k := fmod(_t * 0.045, 1.0)
		var perim := 2.0 * (grown.size.x + grown.size.y)
		var d := k * perim
		var p := grown.position
		if d < grown.size.x:
			p += Vector2(d, 0)
		elif d < grown.size.x + grown.size.y:
			p += Vector2(grown.size.x, d - grown.size.x)
		elif d < 2.0 * grown.size.x + grown.size.y:
			p += Vector2(grown.size.x - (d - grown.size.x - grown.size.y), grown.size.y)
		else:
			p += Vector2(0, grown.size.y - (d - 2.0 * grown.size.x - grown.size.y))
		spot = p + Vector2(sin(_t * 0.9) * 60.0, cos(_t * 0.7) * 50.0)
		queue_redraw()

	func _draw() -> void:
		var local := to_local(spot)
		draw_circle(local, Wanted.SPOT_RADIUS * 1.25, Color(0.9, 0.95, 1.0, 0.06))
		draw_circle(local, Wanted.SPOT_RADIUS, Color(0.9, 0.95, 1.0, 0.13))
		draw_arc(local, Wanted.SPOT_RADIUS, 0.0, TAU, 40, Color(0.9, 0.95, 1.0, 0.25), 2.0, true)
