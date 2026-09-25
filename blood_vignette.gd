extends CanvasLayer
class_name BloodVignette
## Low health as an ink bleed creeping in from the screen edges, deepening
## with missing health and throbbing with the heartbeat at 1 HP (the
## post-process's red pulse still runs underneath). Red with the Red blood
## style, pure ink with Noir or Gore off. Sits under the HUD, over the world.

var _rect: ColorRect
var _mat: ShaderMaterial
var _amount := 0.0
var _target := 0.0
var _last_heart := false
var _t := 0.0

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/blood_vignette.gdshader")
	_rect.material = _mat
	root.add_child(_rect)
	_apply_style()
	Settings.changed.connect(_apply_style)

## Brief 3: an ink bleed. Red blood style tints the ink red; Noir (and Gore
## off: it's ink, not blood) is pure ink.
func _apply_style() -> void:
	var ink := int(Settings.values.get("blood_style", 0)) == 1 or int(Settings.values.get("gore", 2)) == Settings.GORE_OFF
	_mat.set_shader_parameter("core", Color(0.035, 0.035, 0.045) if ink else Color(0.3, 0.02, 0.04))
	_mat.set_shader_parameter("rim", Color(0.09, 0.09, 0.11) if ink else Color(0.12, 0.0, 0.02))
	visible = true

func set_health(current: int, maximum: int) -> void:
	_target = 0.0 if maximum <= 0 else clampf(1.0 - float(current) / float(maximum), 0.0, 1.0)
	_last_heart = current == 1

func _process(delta: float) -> void:
	_t += delta
	_amount = move_toward(_amount, _target, delta * 1.2)
	var beat := 0.0
	if _last_heart and not Settings.values.get("reduce_flashing", false):
		beat = pow(maxf(sin(_t * 5.2), 0.0), 6.0)
	_mat.set_shader_parameter("amount", _amount)
	_mat.set_shader_parameter("pulse", beat)
	_rect.visible = _amount > 0.01
