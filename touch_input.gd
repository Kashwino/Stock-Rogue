extends Node
## Autoload "TouchInput": virtual-stick state plus an input-map guard.
var move := Vector2.ZERO
var aim := Vector2.RIGHT
var firing := false
var touch_active := false
## Every action the game reads. They are defined in project.godot; this list
## only exists to fail loudly (and patch in keyboard defaults) if one is gone.
const REQUIRED := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	"dodge": [KEY_SPACE, KEY_SHIFT], "reload": [KEY_R],
	"swap_weapon": [KEY_Q], "interact": [KEY_E], "pause": [KEY_ESCAPE],
	"tactical_map": [KEY_TAB, KEY_M], "debug_menu": [KEY_F1],
	"aim_left": [], "aim_right": [], "aim_up": [], "aim_down": [], "fire": [],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var missing: Array = []
	for action: String in REQUIRED:
		if InputMap.has_action(action):
			continue
		missing.append(action)
		InputMap.add_action(action)
		for code: int in REQUIRED[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
		if action == "fire":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event("fire", mouse)
	if not missing.is_empty():
		push_error("Input map is missing actions %s — add them under Project Settings > Input Map. Keyboard defaults were patched in for this session." % str(missing))

func movement() -> Vector2:
	return (move + Input.get_vector("move_left", "move_right", "move_up", "move_down")).limit_length(1.0)

## Right-stick aim from a controller, or ZERO when the stick is centred.
func pad_aim() -> Vector2:
	var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	return v.normalized() if v.length() > 0.35 else Vector2.ZERO

func reset() -> void:
	move = Vector2.ZERO
	firing = false
	for action in ["fire", "dodge", "reload", "swap_weapon", "interact"]:
		Input.action_release(action)
