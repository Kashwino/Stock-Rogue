extends Node2D
class_name EnemyOverhead
## Status drawn above a guard, unshaded so it reads in the dark:
##   name tag (elites, reinforcements), radio icon + call bar, the security
##   tech's alarm "!" and an elite's shield bubble. Redraws only on change,
##   except while something is pulsing.

var tag := "":
	set(v):
		if v != tag:
			tag = v
			queue_redraw()
var tag_color := Palette.GOLD
## Radio carrier marker; `radio` > 0 shows the call progress bar (0..1).
var radio_icon := false:
	set(v):
		if v != radio_icon:
			radio_icon = v
			queue_redraw()
var radio := 0.0:
	set(v):
		if absf(v - radio) > 0.001:
			radio = v
			queue_redraw()
var alarm := false:
	set(v):
		if v != alarm:
			alarm = v
			set_process(v or staggered)
			queue_redraw()
## Shield bubble strength 0..1 (0 = none).
var bubble := 0.0:
	set(v):
		if absf(v - bubble) > 0.001:
			bubble = v
			queue_redraw()
var lift := 46.0
## A melee prompt under the guard ("F · TAKEDOWN"), set by the player.
var prompt := "":
	set(v):
		if v != prompt:
			prompt = v
			queue_redraw()
## Staggered: a pulsing ring at his feet.
var staggered := false:
	set(v):
		if v != staggered:
			staggered = v
			set_process(v or alarm)
			queue_redraw()

func _ready() -> void:
	z_index = 40
	material = StreetArt._unshaded()
	set_process(alarm)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if staggered:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		if Settings.values.get("reduce_flashing", false):
			pulse = 0.7
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, Palette.with_alpha(Palette.SODIUM, 0.45 + 0.45 * pulse), 2.5, true)
	if prompt != "":
		var pf := VisualTheme.font("heading_bold")
		var pw := pf.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var pbox := Rect2(-pw * 0.5 - 6.0, 26.0, pw + 12.0, 20.0)
		draw_rect(pbox, Color(0.04, 0.04, 0.05, 0.85))
		draw_rect(pbox, Palette.GOLD, false, 1.5)
		draw_string(pf, Vector2(-pw * 0.5, 41.0), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.GOLD)
	var y := -lift
	if bubble > 0.0:
		draw_circle(Vector2.ZERO, 30.0, Palette.with_alpha(Palette.NEON_CYAN, 0.07 + 0.08 * bubble))
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Palette.with_alpha(Palette.NEON_CYAN, 0.35 + 0.5 * bubble), 2.0, true)
	if tag != "":
		var font := VisualTheme.font("mono")
		var size := 13
		var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var box := Rect2(-w * 0.5 - 6.0, y - 15.0, w + 12.0, 18.0)
		draw_rect(box, Color(0.04, 0.04, 0.05, 0.82))
		draw_rect(box, tag_color, false, 1.5)
		draw_string(font, Vector2(-w * 0.5, y - 2.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tag_color)
		y -= 22.0
	if radio_icon or radio > 0.0:
		var col := Palette.SODIUM if radio > 0.0 else Palette.with_alpha(Palette.PAPER, 0.7)
		# Walkie-talkie: body, antenna, speaker grille.
		draw_rect(Rect2(-24, y - 14, 9, 14), col)
		draw_line(Vector2(-17, y - 14), Vector2(-17, y - 21), col, 2.0)
		draw_line(Vector2(-22, y - 9), Vector2(-17, y - 9), Color.BLACK, 1.0)
		draw_line(Vector2(-22, y - 6), Vector2(-17, y - 6), Color.BLACK, 1.0)
		if radio > 0.0:
			var bar := Rect2(-10, y - 11, 38, 8)
			draw_rect(bar, Color(0, 0, 0, 0.75))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(radio, 0.0, 1.0), bar.size.y)), Palette.DANGER if radio > 0.66 else Palette.SODIUM)
			draw_rect(bar, Palette.PAPER, false, 1.0)
		y -= 24.0
	if alarm:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		if Settings.values.get("reduce_flashing", false):
			pulse = 1.0
		draw_circle(Vector2(0, y - 8), 11.0, Palette.with_alpha(Palette.DANGER, pulse))
		draw_string(VisualTheme.font("heading_bold"), Vector2(-4, y - 1), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
