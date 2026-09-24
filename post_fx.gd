extends CanvasLayer
class_name PostFX
## Full-screen post-process for heists (Settings "post_fx"): vignette and film
## grain, a chromatic-aberration kick on damage, and a red pulse with
## desaturation while the player is on their last heart. Sits under the HUD.

var rect: ColorRect
var mat: ShaderMaterial
var _aberration := 0.0
var _danger := 0.0
var _target_danger := 0.0
var _t := 0.0

func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/post_fx.gdshader")
	rect.material = mat
	root.add_child(rect)
	_apply_setting()
	Settings.changed.connect(_apply_setting)

func _apply_setting() -> void:
	visible = Settings.values.get("post_fx", true) and not Settings.values.get("low_effects", false)

func hit(strength: float = 1.0) -> void:
	_aberration = clampf(_aberration + strength, 0.0, 1.5)

func set_health(current: int, maximum: int) -> void:
	_target_danger = 1.0 if current <= 1 and maximum > 1 else (0.6 if current <= 1 else 0.0)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_aberration = move_toward(_aberration, 0.0, delta * 3.0)
	_danger = move_toward(_danger, _target_danger, delta * 1.5)
	var beat := pow(maxf(sin(_t * 5.2), 0.0), 6.0)
	var calm: bool = Settings.values.get("reduce_flashing", false)
	mat.set_shader_parameter("aberration", _aberration * (0.4 if calm else 1.0))
	mat.set_shader_parameter("danger", _danger)
	mat.set_shader_parameter("pulse", 0.3 if calm else beat)
