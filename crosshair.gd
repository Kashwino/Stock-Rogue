extends CanvasLayer
class_name Crosshair
## A drawn crosshair at the cursor (mouse) or ahead of the player (gamepad).
## Its gap widens with the weapon's spread and each shot's bloom; a ring
## around it fills while reloading. The OS cursor hides during play and comes
## back whenever the game is paused or this layer leaves the tree.

var player: Player
var _mark: Mark

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_mark = Mark.new()
	root.add_child(_mark)

func _process(_delta: float) -> void:
	var touch: bool = TouchInput.touch_active and Settings.values["touch_mode"] != 2
	var show := is_instance_valid(player) and not get_tree().paused and not touch and not Transition.busy
	_mark.visible = show
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if show and TouchInput.pad_aim() == Vector2.ZERO else Input.MOUSE_MODE_VISIBLE
	if not show:
		return
	var pad := TouchInput.pad_aim()
	if pad != Vector2.ZERO:
		var screen_player := player.get_global_transform_with_canvas().origin
		_mark.position = screen_player + pad * 170.0
	else:
		_mark.position = _mark.get_viewport().get_mouse_position()
	var weapon: WeaponItem = player.loadout.get_active() if player.loadout else null
	var spread := (weapon.spread if weapon else 0.02) * player.spread_multiplier
	_mark.gap = lerpf(_mark.gap, 6.0 + spread * 120.0 + player.bloom * 14.0, 0.35)
	_mark.reload = 0.0
	if player.loadout and player.loadout.reloading and player.loadout._reload_weapon:
		var total: float = maxf(player.loadout._reload_weapon.reload_time * player.reload_multiplier, 0.1)
		_mark.reload = 1.0 - clampf(player.loadout._reload_remaining / total, 0.0, 1.0)
	_mark.queue_redraw()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


class Mark extends Control:
	var gap := 8.0
	var reload := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var col := Palette.GOLD_PALE
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var a: Vector2 = d * gap
			var b: Vector2 = d * (gap + 9.0)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.7), 3.0)
			draw_line(a, b, col, 2.0)
		draw_circle(Vector2.ZERO, 1.8, col)
		if reload > 0.0:
			draw_arc(Vector2.ZERO, gap + 14.0, -PI * 0.5, -PI * 0.5 + TAU * reload, 32, Palette.GOLD, 3.0, true)
			draw_arc(Vector2.ZERO, gap + 14.0, 0, TAU, 32, Color(1, 1, 1, 0.15), 1.0, true)
