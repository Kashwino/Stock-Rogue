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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(340, 150)
	size = Vector2(600, 96)
	hide()

func show_for(target: Enemy, name_text: String, sub: String = "", phase_ticks: Array = []) -> void:
	boss = target
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
	_line_clock = maxf(_line_clock - delta, 0.0)
	if is_instance_valid(boss):
		var frac := clampf(float(boss.health) / float(maxi(boss.max_health, 1)), 0.0, 1.0)
		_trail = move_toward(_trail, frac, delta * 0.35) if _trail > frac else frac
	queue_redraw()

func _draw() -> void:
	var bar := Rect2(0, 30, size.x, 16)
	var heading := VisualTheme.font("heading_bold")
	var mono := VisualTheme.font("mono")
	draw_string(heading, Vector2(0, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.DANGER)
	if subtitle != "":
		var w := heading.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var room := size.x - w - 14.0
		var text := subtitle.to_upper()
		# Trim whole words until the line fits, rather than cutting mid-word.
		while text.length() > 4 and mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > room:
			var cut := text.rfind(" ", text.length() - 3)
			text = (text.substr(0, cut) if cut > 0 else text.substr(0, text.length() - 4)).trim_suffix(".").trim_suffix(",") + "…"
		draw_string(mono, Vector2(w + 14, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.PAPER_DIM)
	draw_rect(bar.grow(3), Color(0.02, 0.02, 0.03, 0.9))
	draw_rect(bar, Color(0.18, 0.05, 0.05))
	var frac := 0.0
	var immune := ""
	if is_instance_valid(boss):
		frac = clampf(float(boss.health) / float(maxi(boss.max_health, 1)), 0.0, 1.0)
		if boss is Boss:
			immune = boss.immune_reason
			if immune == "" and boss.invulnerable:
				immune = "..."
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Palette.GOLD if immune == "" else Palette.NEON_CYAN)
	for t in ticks:
		var x: float = bar.position.x + bar.size.x * float(t)
		draw_line(Vector2(x, bar.position.y - 4), Vector2(x, bar.end.y + 4), Palette.PAPER, 2.0)
	draw_rect(bar, Palette.GOLD_DIM, false, 1.5)
	var tags: Array = []
	if immune != "" and immune != "...":
		tags.append([immune, Palette.NEON_CYAN])
	if is_instance_valid(boss) and boss is AuditorBoss and boss.auditing:
		tags.append(["AUDIT: HITS CRASH THE STOCK x2", Palette.DANGER])
	if is_instance_valid(boss) and boss is ChairmanBoss and boss.phase >= 3:
		tags.append(["LIQUIDATION: -$%d" % boss.drained, Palette.DANGER])
	var x := 0.0
	for tag: Array in tags:
		var tw := mono.get_string_size(tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_rect(Rect2(x, 52, tw + 12, 20), Palette.with_alpha(tag[1], 0.9))
		draw_string(mono, Vector2(x + 6, 67), tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)
		x += tw + 20
	if _line_clock > 0.0:
		var alpha := clampf(_line_clock / 0.4, 0.0, 1.0)
		draw_string(heading, Vector2(0, 92), "“%s”" % _line, HORIZONTAL_ALIGNMENT_LEFT, size.x, 20, Palette.with_alpha(Palette.PAPER, alpha))
