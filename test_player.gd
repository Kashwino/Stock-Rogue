extends CharacterBody2D
## Minimal movement-only player for testing the door/room system.
## No shooting, no stats — just WASD movement so you can walk to doors.
## Must be in the "player" group (set in the scene or here).

@export var speed: float = 220.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
