extends Node
class_name CombatFX
var camera: Camera2D
var shake_strength := 0.0
var slow_active := false

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if Settings.values["low_effects"]:
		shake_strength = 0.0
	shake_strength = move_toward(shake_strength, 0, delta * 32.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength

func shake(amount: float) -> void:
	if not Settings.values["low_effects"]:
		shake_strength = minf(10.0, maxf(shake_strength, amount))

func muzzle(at: Vector2, direction: Vector2) -> void:
	if Settings.values["low_effects"]:
		return
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(-4, -7), Vector2(30, 0), Vector2(-4, 7), Vector2(5, 0)])
	flash.color = Color(1, 0.87, 0.35)
	get_parent().add_child(flash)
	flash.global_position = at
	flash.rotation = direction.angle()
	flash.z_index = 20
	var t := flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.065)
	t.tween_callback(flash.queue_free)

func last_kill() -> void:
	shake(5.0)
	if slow_active or Settings.values["low_effects"]:
		return
	slow_active = true
	Engine.time_scale = 0.35
	# Pause freezes this beat. Real-time duration prevents slow-mo stretching itself.
	await get_tree().create_timer(0.22, false, false, true).timeout
	Engine.time_scale = 1.0
	slow_active = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
