extends Enemy
class_name AuditorBoss
## The Auditor: alternating declared levies and a locked-direction foreclosure.
## This state machine never uses the guard archetype's hunt/fire loop.
enum Attack { RECOVER, DECLARE_LEVY, DECLARE_CHARGE, CHARGE }
var attack := Attack.RECOVER
var phase := 1
var cycle := 0
var clock := 1.5
var locked_direction := Vector2.RIGHT
var safe_angle := 0.0
var _phase_announced := false
var _name_label: Label

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	max_health = 64 + (RunFlow.pending_heist.room_rarity * 10 if RunFlow.pending_heist else 0)
	health = max_health
	currency_value = 0
	sight_range = 1000.0
	_name_label = Label.new()
	_name_label.text = "THE AUDITOR"
	_name_label.position = Vector2(-120, -90)
	_name_label.size = Vector2(240, 32)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	var body := sprite.get_node("Body") as Polygon2D
	body.polygon = PackedVector2Array([Vector2(-24, -23), Vector2(16, -23), Vector2(28, 0), Vector2(16, 23), Vector2(-24, 23)])
	body.color = Color(0.95, 0.79, 0.28)
	sprite.modulate = Color.WHITE

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(_player):
		return
	phase = 2 if health <= max_health / 2 else 1
	if phase == 2 and not _phase_announced:
		_phase_announced = true
		_name_label.text = "THE AUDITOR - MARGIN CALL"
		Sfx.play_sound("warning")
	var inside := _guard_rect.has_point(_player.global_position) if _has_guard_rect else _can_see_player()
	if not inside:
		velocity = _steer_toward(_post, 70.0) if global_position.distance_to(_post) > 20.0 else Vector2.ZERO
		attack = Attack.RECOVER
		clock = 1.25
		move_and_slide()
		queue_redraw()
		return
	wake_for(2.0)
	clock -= delta
	var direction := (_player.global_position - global_position).normalized()
	sprite.rotation = direction.angle()
	match attack:
		Attack.RECOVER:
			velocity = _steer_toward(_player.global_position, 50.0) if global_position.distance_to(_player.global_position) > 260.0 else Vector2.ZERO
			if clock <= 0.0:
				cycle += 1
				locked_direction = direction
				safe_angle = direction.angle() + PI * 0.5
				attack = Attack.DECLARE_CHARGE if cycle % 2 == 0 else Attack.DECLARE_LEVY
				clock = 0.9 if phase == 1 else 0.65
				Sfx.play_sound("warning")
		Attack.DECLARE_LEVY:
			velocity = Vector2.ZERO
			if clock <= 0.0:
				_levy()
				attack = Attack.RECOVER
				clock = 1.45 if phase == 1 else 1.0
		Attack.DECLARE_CHARGE:
			velocity = Vector2.ZERO
			if clock <= 0.0:
				attack = Attack.CHARGE
				clock = 0.6
		Attack.CHARGE:
			velocity = locked_direction * (480.0 if phase == 2 else 400.0)
			if global_position.distance_to(_player.global_position) < 44.0:
				_player.take_damage(1)
			if clock <= 0.0 or is_on_wall():
				attack = Attack.RECOVER
				clock = 1.4
	move_and_slide()
	queue_redraw()

func _levy() -> void:
	var count := 16 if phase == 2 else 12
	for i in count:
		var angle := TAU * float(i) / float(count)
		# A visible green escape wedge remains open in both phases.
		if absf(angle_difference(angle, safe_angle)) < 0.5:
			continue
		var bullet := enemy_bullet_scene.instantiate()
		bullet.speed = 300.0 if phase == 2 else 240.0
		bullet.damage = 1
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + Vector2.from_angle(angle) * 34.0
		bullet.setup(Vector2.from_angle(angle), self)

func _draw() -> void:
	draw_rect(Rect2(-65, -53, 130, 9), Color(0.15, 0.16, 0.2))
	if max_health > 0:
		draw_rect(Rect2(-65, -53, 130.0 * maxf(float(health) / max_health, 0.0), 9), Color(0.95, 0.7, 0.2))
	if attack == Attack.DECLARE_CHARGE:
		draw_line(Vector2.ZERO, locked_direction * 360.0, Color(1.0, 0.22, 0.3, 0.8), 16.0)
	elif attack == Attack.DECLARE_LEVY:
		draw_arc(Vector2.ZERO, 125.0, safe_angle + 0.5, safe_angle + TAU - 0.5, 48, Color(1.0, 0.28, 0.35, 0.8), 6.0)
		draw_arc(Vector2.ZERO, 125.0, safe_angle - 0.5, safe_angle + 0.5, 12, Color(0.35, 1.0, 0.6), 6.0)

func _flash() -> void:
	queue_redraw()
