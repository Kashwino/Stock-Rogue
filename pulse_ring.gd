extends Node2D
class_name PulseRing
## A slow expanding ring that marks something you can interact with.
## Unshaded so it reads in the dark; stops when `active` goes false.

var color := Palette.GOLD
var radius := 40.0
var active := true
var _t := 0.0

func _ready() -> void:
	z_index = -1
	material = StreetArt._unshaded()

func _process(delta: float) -> void:
	if not active:
		if visible:
			hide()
		return
	_t = fmod(_t + delta, 1.6)
	queue_redraw()

func _draw() -> void:
	var p := _t / 1.6
	draw_arc(Vector2.ZERO, radius * (0.6 + p * 0.7), 0, TAU, 32, Palette.with_alpha(color, 0.55 * (1.0 - p)), 2.5, true)
	draw_arc(Vector2.ZERO, radius * 0.6, 0, TAU, 32, Palette.with_alpha(color, 0.25), 1.5, true)
