extends CharacterBody2D
class_name HideoutWalker

## Lightweight movement-only body for the hideout hub. Deliberately NOT the
## full player.gd — no weapons, no health, nothing that could let the player
## get hurt in what's supposed to be a safe backroom between jobs.
##
## Builds its own visual and collision shape in code — it's spawned directly
## via HideoutWalker.new(), never from a .tscn, so it can't depend on scene
## children existing.

@export var move_speed: float = 220.0
var movement_enabled: bool = true

var sprite: Node2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1        # walls only
	_build_visual_and_collision()

func _build_visual_and_collision() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)

	sprite = Node2D.new()
	add_child(sprite)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)])
	body.color = Color(0.85, 0.72, 0.4)
	sprite.add_child(body)

	# A little nose so facing direction reads clearly.
	var nose := Polygon2D.new()
	nose.polygon = PackedVector2Array([
		Vector2(10, -5), Vector2(20, 0), Vector2(10, 5)])
	nose.color = Color(0.95, 0.85, 0.5)
	sprite.add_child(nose)

func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed
	if dir.length() > 0.1 and sprite:
		sprite.rotation = dir.angle()
	move_and_slide()
