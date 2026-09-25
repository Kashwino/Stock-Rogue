extends Control
class_name BossBar
## Top-centre boss health bar: name and title, a bar with a tick at every
## phase threshold, a white "damage trail", status tags (IMMUNITY, AUDIT) and
## the boss's lines of dialogue underneath. Lieutenants get the same bar
## without phase ticks.

var boss: Enemy = null
var title := ""
var subtitle := ""
var ticks: Array = []
var _trail := 1.0
var _line := ""
var _line_clock := 0.0
## Brief 3: when the boss kneels the bar cracks and shatters (1 -> 0).
var _shatter := 0.0
var _shattered := false
## The HUD preview drives the bar without a boss: health 0..1 (-1 = off)
## and a kneel.
var preview_frac := -1.0
var preview_kneel := false
var _last_frac := -1.0
var _tag_clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(300, 166)
	size = Vector2(680, 106)
	hide()

func show_for(target: Enemy, name_text: String, sub: String = "", phase_ticks: Array = []) -> void:
	boss = target
	_shatter = 0.0
	_shattered = false
	title = name_text
	subtitle = sub
	ticks = phase_ticks
	_trail = 1.0
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)

func say(text: String) -> void:
	if text == "":
		return
	_line = text
	_line_clock = 3.2

func clear() -> void:
	boss = null
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(hide)

func _process(delta: float) -> void:
	if not visible:
		return
	var busy := _line_clock > 0.0 or _shatter > 0.0
	_line_clock = maxf(_line_clock - delta, 0.0)
	_shatter = maxf(_shatter - delta * (0.9 if not HudKit.reduce_motion() else 5.0), 0.0)
	var frac := preview_frac
	if is_instance_valid(boss):
		frac = clampf(float(boss.health) / float(maxi(boss.max_health, 1)), 0.0, 1.0)
	if frac >= 0.0:
		var before := _trail
		_trail = move_toward(_trail, frac, delta * 0.35) if _trail > frac else frac
		busy = busy or before != _trail or frac != _last_frac
		_last_frac = frac
	# Redraw on change (health, trail, a line, the shatter), and a few times a
	# second for the status tags; never every frame for nothing.
	_tag_clock -= delta
	if busy or _tag_clock <= 0.0:
		_tag_clock = 0.25
		queue_redraw()

func _draw() -> void:
	# Brief 3: a long skewed bar with the name on a slanted title card, phase
	# ticks as notches, and a crack that shatters the bar when he kneels.
	var bar := Rect2(24, 34, size.x - 48, 18)
	var pulp := VisualTheme.font("pulp")
	var mono := VisualTheme.font("mono")
	var type := VisualTheme.font("type_bold")
	var frac := 0.0
	var immune := ""
	var kneeling := false
	if preview_frac >= 0.0 and not is_instance_valid(boss):
		frac = preview_frac
		kneeling = preview_kneel
	if is_instance_valid(boss):
		frac = clampf(float(boss.health) / float(maxi(boss.max_health, 1)), 0.0, 1.0)
		if boss is Boss:
			immune = boss.immune_reason
			kneeling = boss.kneeling
			if immune == "" and boss.invulnerable and not kneeling:
				immune = "..."
	if not kneeling and preview_frac >= 0.0:
		_shattered = false
	if kneeling and _shatter <= 0.0 and not _shattered:
		_shatter = 1.0
		_shattered = true
	# The title card: the name on a slanted slab, the subtitle typed beside it.
	var title_w := HudKit.text_width(pulp, title, 24) + 28.0
	var card := Rect2(Vector2(10, 0), Vector2(title_w, 30))
	if not HudKit.minimal():
		HudKit.draw_slant_panel(self, card, Palette.DANGER.darkened(0.2), HudKit.SKEW, true, Color(0, 0, 0, 0.3))
	HudKit.text(self, pulp, card.position + Vector2(14, 24), title, 24, Palette.PAPER_CREAM)
	if subtitle != "":
		var room := size.x - card.end.x - 18.0
		var text := subtitle.to_upper()
		# Trim whole words until the line fits, rather than cutting mid-word.
		while text.length() > 4 and mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > room:
			var cut := text.rfind(" ", text.length() - 3)
			text = (text.substr(0, cut) if cut > 0 else text.substr(0, text.length() - 4)).trim_suffix(".").trim_suffix(",") + "…"
		HudKit.text(self, type, Vector2(card.end.x + 14, 22), text, 13, Palette.PAPER_CREAM)
	if _shatter > 0.0 or (_shattered and kneeling):
		_draw_shards(bar)
	else:
		var track := HudKit.slant(bar)
		if not HudKit.minimal():
			HudKit.shadowed(self, track, Color(0.12, 0.03, 0.03, 0.95))
		var trail := HudKit.slant(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)).grow(-2.0))
		if _trail > 0.01:
			draw_colored_polygon(trail, Color(1, 1, 1, 0.5))
		if frac > 0.0:
			draw_colored_polygon(HudKit.slant(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)).grow(-2.0)), Palette.GOLD if immune == "" else Palette.NEON_CYAN)
		# Phase thresholds: notches cut into the top and bottom edges.
		for t in ticks:
			var x: float = bar.position.x + bar.size.x * float(t)
			var top := Vector2(x - bar.size.y * HudKit.SKEW, bar.position.y)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-5, -1), top + Vector2(5, -1), top + Vector2(0, 7)]), Palette.HUD_INK)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, bar.end.y + 1), Vector2(x + 5, bar.end.y + 1), Vector2(x, bar.end.y - 7)]), Palette.HUD_INK)
		draw_polyline(HudKit.closed(track), Palette.HUD_INK, 2.0, true)
	var tags: Array = []
	if kneeling:
		tags.append(["ON HIS KNEES" if not (boss is AmbassadorBoss) else "ON HER KNEES", Palette.GOLD])
	if immune != "" and immune != "...":
		tags.append([immune, Palette.NEON_CYAN])
	if is_instance_valid(boss) and boss is AuditorBoss and boss.auditing:
		tags.append(["AUDIT: HITS CRASH THE STOCK x2", Palette.DANGER])
	if is_instance_valid(boss) and boss is ChairmanBoss and boss.phase >= 3 and not boss.drain_disabled:
		tags.append(["LIQUIDATION: -$%d" % boss.drained, Palette.DANGER])
	var x := 24.0
	for tag: Array in tags:
		var tw := mono.get_string_size(tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var r := Rect2(x, 58, tw + 16, 20)
		draw_colored_polygon(HudKit.slant(r), Palette.with_alpha(tag[1], 0.92))
		draw_string(mono, Vector2(x + 8, 73), tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.HUD_INK)
		x += tw + 26
	if _line_clock > 0.0:
		var alpha := clampf(_line_clock / 0.4, 0.0, 1.0)
		HudKit.text(self, VisualTheme.font("heading_bold"), Vector2(24, 100), "“%s”" % _line, 20, Palette.with_alpha(Palette.PAPER, alpha), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0)

## The bar cracks, then breaks into shards that fall away.
func _draw_shards(bar: Rect2) -> void:
	var k := 1.0 - _shatter
	var n := 7
	for i in n:
		var x0 := bar.position.x + bar.size.x * i / n
		var x1 := bar.position.x + bar.size.x * (i + 1) / n
		var jag := (HudKit.noise(31, i) - 0.5) * 16.0
		var piece := HudKit.slant(Rect2(Vector2(x0, bar.position.y), Vector2(x1 - x0, bar.size.y)))
		piece[1] = piece[1] + Vector2(jag, 0)
		piece[2] = piece[2] + Vector2(jag, 0)
		var drop := Vector2((HudKit.noise(41, i) - 0.5) * 60.0 * k, 90.0 * k * k)
		var spin := (HudKit.noise(51, i) - 0.5) * 1.6 * k
		var c := (piece[0] + piece[2]) * 0.5
		var pts := PackedVector2Array()
		for p in piece:
			pts.append(c + (p - c).rotated(spin) + drop)
		var a := clampf(_shatter * 1.4, 0.0, 1.0)
		draw_colored_polygon(pts, Palette.with_alpha(Palette.GOLD.darkened(0.3), a))
		draw_polyline(HudKit.closed(pts), Palette.with_alpha(Palette.HUD_INK, a), 1.5, true)
