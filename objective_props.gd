extends RefCounted
class_name ObjectiveProps
## World pieces for heist objectives. All are drawn unshaded so they read in
## the dark, and all use the same "hold USE" interaction as alarm panels.


## Sabotage: hold USE for 2 s beside it to plant a charge.
class ChargePoint extends Node2D:
	signal planted(point: ChargePoint)
	const HOLD := 2.0
	const REACH := 100.0
	var floor_host: HeistFloor
	var done := false
	var hold := 0.0
	var _t := 0.0
	var _label: WorldPrompt

	func _ready() -> void:
		z_index = 20
		material = StreetArt._unshaded()
		_label = WorldPrompt.new()
		_label.text = "PLANT CHARGE\nHOLD USE / E"
		_label.color = Palette.GOLD_PALE
		_label.position = Vector2(0, -56)
		_label.hide()
		add_child(_label)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if done or floor_host == null or not is_instance_valid(floor_host.player):
			return
		var near := global_position.distance_to(floor_host.player.global_position) < REACH
		_label.visible = near
		if near and Input.is_action_pressed("interact"):
			if hold == 0.0:
				Audio.play("beep", global_position)
			hold += delta
			if hold >= HOLD:
				done = true
				_label.hide()
				Audio.play("mag_in", global_position, 2.0, 0.7)
				planted.emit(self)
		else:
			hold = maxf(hold - delta * 2.0, 0.0)

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * (8.0 if done else 3.0))
		if not done:
			draw_circle(Vector2.ZERO, 34.0, Palette.with_alpha(Palette.GOLD, 0.1 + 0.08 * pulse))
			draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Palette.with_alpha(Palette.GOLD, 0.7), 2.0, true)
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				draw_line(Vector2.from_angle(a) * 22.0, Vector2.from_angle(a) * 30.0, Palette.GOLD, 3.0)
			if hold > 0.0:
				draw_arc(Vector2.ZERO, 42.0, -PI * 0.5, -PI * 0.5 + TAU * hold / HOLD, 32, Palette.GOLD, 5.0, true)
		# The charge itself: a brick of plastique with a blinking diode.
		draw_rect(Rect2(-12, -8, 24, 16), Color("5a5a3a") if done else Color(0.25, 0.25, 0.2, 0.6))
		draw_rect(Rect2(-12, -8, 24, 16), Color.BLACK, false, 1.5)
		if done:
			draw_circle(Vector2(8, -4), 3.0, Palette.DANGER if pulse > 0.5 else Color("5a1010"))


## The Package: pick it up with USE; you carry it (slower) to the car.
class PackageCase extends Node2D:
	signal picked_up(case: PackageCase)
	const REACH := 70.0
	var floor_host: HeistFloor
	var carried := false
	var _t := 0.0
	var _label: WorldPrompt

	func _ready() -> void:
		z_index = 20
		material = StreetArt._unshaded()
		_label = WorldPrompt.new()
		_label.text = "THE PACKAGE\nUSE / E TO TAKE"
		_label.color = Palette.GOLD_PALE
		_label.position = Vector2(0, -54)
		_label.hide()
		add_child(_label)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if carried or floor_host == null or not is_instance_valid(floor_host.player):
			return
		var near := global_position.distance_to(floor_host.player.global_position) < REACH
		_label.visible = near
		if near and Input.is_action_just_pressed("interact"):
			carried = true
			_label.hide()
			hide()
			Audio.play("chest_open", global_position)
			picked_up.emit(self)

	func _draw() -> void:
		var bob := sin(_t * 2.5) * 2.0
		draw_circle(Vector2(0, 4), 30.0, Palette.with_alpha(Palette.GOLD, 0.12 + 0.06 * sin(_t * 3.0)))
		draw_rect(Rect2(-18, -12 + bob, 36, 24), Color("2a1d14"))
		draw_rect(Rect2(-18, -12 + bob, 36, 24), Palette.GOLD, false, 2.0)
		draw_rect(Rect2(-6, -17 + bob, 12, 6), Color("1a120c"))
		draw_line(Vector2(-18, bob), Vector2(18, bob), Palette.GOLD_DIM, 1.5)


## Smash & Grab: a stencilled floor marker in a jackpot room.
class JackpotMarker extends Node2D:
	var size := Vector2(200, 150)
	var looted := false
	var _t := 0.0

	func _ready() -> void:
		z_index = -3
		material = StreetArt._unshaded()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if looted:
			return
		var a := 0.25 + 0.15 * sin(_t * 3.0)
		var r := Rect2(-size * 0.5, size)
		draw_rect(r, Palette.with_alpha(Palette.GOLD, a * 0.35))
		draw_rect(r, Palette.with_alpha(Palette.GOLD, a + 0.3), false, 3.0)
		draw_string(VisualTheme.font("heading_bold"), Vector2(-60, 8), "JACKPOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.with_alpha(Palette.GOLD, a + 0.4))
