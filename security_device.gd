extends StaticBody2D
class_name SecurityDevice
## Cameras sweep and scan at 5 Hz: holding you in the cone for 1.6 s reports
## you (heat) and arms the nearest alarm panel. Shoot one to kill it.
## Alarm panels transmit heat while armed; hold interact for 1.5 s next to one
## to cut it (and every camera in its room). Security techs and brave
## civilians run for panels to raise the full alarm.
enum Kind { CAMERA, ALARM }
var kind: Kind = Kind.CAMERA
var floor_host: Node
var room: Node2D
var disabled := false
var armed := false
var health := 3
var scan_angle := 0.0
var detected := 0.0
var clock := 0.0
var transmit_clock := 0.0
var caption: Label
var hold := 0.0
const RANGE := 450.0
const HOLD_TIME := 1.5
const HOLD_REACH := 110.0
const SPOT_HEAT := 6.0
const TRANSMIT_HEAT := 3.0

func _ready() -> void:
	add_to_group("security")
	collision_layer = Layers.SECURITY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(42, 32)
	shape.shape = box
	add_child(shape)
	caption = Label.new()
	caption.position = Vector2(-130, -65)
	caption.size = Vector2(260, 60)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 17)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	_update_caption()
	caption.hide()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if disabled or not is_instance_valid(floor_host.player) or floor_host.player.is_dead():
		return
	var p: Player = floor_host.player
	if kind == Kind.ALARM:
		var near := global_position.distance_squared_to(p.global_position) < HOLD_REACH * HOLD_REACH
		var was := hold
		if near and Input.is_action_pressed("interact"):
			if hold == 0.0:
				Audio.play("beep", global_position)
			hold += delta
			if hold >= HOLD_TIME:
				hold = 0.0
				disable()
				return
		else:
			hold = maxf(hold - delta * 2.0, 0.0)
		if hold != was:
			queue_redraw()
		caption.visible = near or armed
	clock += delta
	if clock < 0.2:
		return
	var elapsed := clock
	clock = 0.0
	if kind == Kind.ALARM:
		if armed:
			transmit_clock -= elapsed
			if transmit_clock <= 0.0:
				transmit_clock = 6.0
				floor_host.add_heat(TRANSMIT_HEAT, "Alarm panel transmitting")
	else:
		# Distant cameras do no ray queries or redraws.
		if global_position.distance_squared_to(p.global_position) > 1000000.0:
			detected = 0.0
			return
		scan_angle = (room.center_position() - global_position).angle() + sin(floor_host.active_elapsed * 0.65) * 0.55
		var offset: Vector2 = p.global_position - global_position
		var sees := offset.length() < RANGE and absf(angle_difference(scan_angle, offset.angle())) < 0.48
		if sees:
			var query := PhysicsRayQueryParameters2D.create(global_position, p.global_position, Layers.SOLID)
			sees = get_world_2d().direct_space_state.intersect_ray(query).is_empty()
		if sees and detected <= 0.0:
			Audio.play("camera_spot", global_position)
		detected = minf(1.6, detected + elapsed) if sees else maxf(0.0, detected - elapsed * 2.0)
		transmit_clock = maxf(0.0, transmit_clock - elapsed)
		if detected >= 1.6 and transmit_clock <= 0.0:
			transmit_clock = 8.0
			floor_host.security_alert(room, "Camera spotted you", SPOT_HEAT)
	_update_caption()
	if kind == Kind.CAMERA:
		caption.visible = global_position.distance_squared_to(p.global_position) < 260.0 * 260.0 or detected > 0.0
	queue_redraw()

func take_damage(amount: int = 1) -> void:
	if disabled:
		return
	health -= amount
	if health <= 0:
		disable()
	else:
		modulate = Color(2, 2, 2)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.1)

func disable(cascade: bool = true) -> void:
	if disabled:
		return
	disabled = true
	armed = false
	detected = 0.0
	set_deferred("collision_layer", 0)
	set_physics_process(false)
	floor_host.on_security_disabled(self)
	if kind == Kind.ALARM and cascade:
		for device in get_tree().get_nodes_in_group("security"):
			if device != self and device.room == room:
				device.disable(false)
	_update_caption()
	queue_redraw()

func _update_caption() -> void:
	if disabled:
		caption.text = "SECURITY OFFLINE"
	elif kind == Kind.ALARM:
		caption.text = ("ALARM TRANSMITTING" if armed else "ALARM PANEL") + "\nHOLD USE / E  —  CUT THE LINE"
	else:
		caption.text = "CAMERA  ·  SHOOT TO DISABLE" if detected <= 0 else "DETECTING  %d%%" % int(detected / 1.6 * 100)

func _draw() -> void:
	var color := Color(0.3, 0.4, 0.43) if disabled else Color(1, 0.65, 0.2)
	if kind == Kind.CAMERA and not disabled:
		var cone := PackedVector2Array([Vector2.ZERO])
		for i in 17:
			cone.append(Vector2.from_angle(scan_angle - 0.48 + i * 0.06) * RANGE)
		draw_colored_polygon(cone, Color(1.0, 0.3 if detected > 0 else 0.7, 0.15, 0.10))
	draw_rect(Rect2(-22, -14, 48, 34), Color(0, 0, 0, 0.3))
	draw_style_box(VisualTheme.panel(Color("526b70"), 0), Rect2(-22, -17, 44, 34))
	if kind == Kind.CAMERA:
		draw_rect(Rect2(-15, -10, 28, 20), Color("8daba7") if not disabled else Color("33464d"))
		draw_circle(Vector2(7, 0), 8, Color("13232d"))
		draw_circle(Vector2(8, 0), 4, color)
	else:
		draw_rect(Rect2(-16, -11, 21, 14), color.darkened(0.6))
		draw_line(Vector2(-12, -4), Vector2(0, -4), color, 2)
		for y in [-7, 1, 9]:
			draw_circle(Vector2(13, y), 2, color)
	if armed and not disabled:
		draw_arc(Vector2.ZERO, 30, 0, TAU, 20, Color(1, 0.2, 0.15), 3)
	if kind == Kind.ALARM and not disabled:
		# Big enough to read on a phone; fills while the player holds USE.
		draw_arc(Vector2.ZERO, 40, 0, TAU, 32, Color(1, 1, 1, 0.18), 3)
		if hold > 0.0:
			draw_arc(Vector2.ZERO, 40, -PI * 0.5, -PI * 0.5 + TAU * hold / HOLD_TIME, 32, Palette.GOLD, 5, true)
