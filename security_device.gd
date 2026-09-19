extends StaticBody2D
class_name SecurityDevice
## Cameras scan at 5 Hz; panels only transmit after a witnessed intrusion.
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
const RANGE := 450.0

func _ready() -> void:
	add_to_group("security")
	collision_layer = 8
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
	queue_redraw()

func _physics_process(delta: float) -> void:
	if disabled or not is_instance_valid(floor_host.player) or floor_host.player.is_dead():
		return
	var p: Player = floor_host.player
	if kind == Kind.ALARM and global_position.distance_squared_to(p.global_position) < 10000.0 and Input.is_action_just_pressed("interact"):
		disable()
		return
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
				floor_host.add_heat(4.0, "Alarm panel transmitting")
	else:
		# Distant cameras do no ray queries or redraws.
		if global_position.distance_squared_to(p.global_position) > 1000000.0:
			detected = 0.0
			return
		scan_angle = (room.center_position() - global_position).angle() + sin(floor_host.active_elapsed * 0.65) * 0.55
		var offset: Vector2 = p.global_position - global_position
		var sees := offset.length() < RANGE and absf(angle_difference(scan_angle, offset.angle())) < 0.48
		if sees:
			var query := PhysicsRayQueryParameters2D.create(global_position, p.global_position, 1)
			sees = get_world_2d().direct_space_state.intersect_ray(query).is_empty()
		detected = minf(1.6, detected + elapsed) if sees else maxf(0.0, detected - elapsed * 2.0)
		transmit_clock = maxf(0.0, transmit_clock - elapsed)
		if detected >= 1.6 and transmit_clock <= 0.0:
			transmit_clock = 8.0
			floor_host.security_alert(room, "Camera spotted you", 8.0)
	_update_caption()
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
		caption.text = ("ALARM TRANSMITTING" if armed else "ALARM PANEL") + "\nUSE / E to disable room"
	else:
		caption.text = "CAMERA  ·  SHOOT TO DISABLE" if detected <= 0 else "DETECTING  %d%%" % int(detected / 1.6 * 100)

func _draw() -> void:
	var color := Color(0.3, 0.4, 0.43) if disabled else Color(1, 0.65, 0.2)
	if kind == Kind.CAMERA and not disabled:
		var cone := PackedVector2Array([Vector2.ZERO])
		for i in 17:
			cone.append(Vector2.from_angle(scan_angle - 0.48 + i * 0.06) * RANGE)
		draw_colored_polygon(cone, Color(1.0, 0.3 if detected > 0 else 0.7, 0.15, 0.10))
	draw_rect(Rect2(-21, -16, 42, 32), color)
	draw_circle(Vector2.ZERO, 8, Color(0.03, 0.07, 0.09))
	if armed and not disabled:
		draw_arc(Vector2.ZERO, 30, 0, TAU, 20, Color(1, 0.2, 0.15), 3)
