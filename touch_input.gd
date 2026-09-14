extends Node
var move := Vector2.ZERO
var aim := Vector2.RIGHT
var firing := false
var touch_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"dodge": [KEY_SPACE, KEY_SHIFT], "reload": [KEY_R],
		"swap_weapon": [KEY_Q], "interact": [KEY_E], "pause": [KEY_ESCAPE]
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in keys[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mouse)

func movement() -> Vector2:
	return (move + Input.get_vector("move_left", "move_right", "move_up", "move_down")).limit_length(1.0)

func reset() -> void:
	move = Vector2.ZERO
	firing = false
	for action in ["fire", "dodge", "reload", "swap_weapon", "interact"]:
		Input.action_release(action)
