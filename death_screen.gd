extends CanvasLayer
class_name DeathScreen

## The run's obituary: tomorrow's front page. A headline generated from how the
## run ended, a procedural press photo, and the numbers buried in the columns.
##   BUSTED — died inside a building, or the Board cut you off at a quota gate
##   RETIRED / THE NEW CHAIRMAN — handled by the ending sequence (Phase 10),
##   which falls back to a celebratory front page here.
## Built entirely in code: CanvasLayer + this script, parented to the root.

signal dismissed()

var _root: Control
var _paper: Control
var _button: Button
var _dim: ColorRect

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.03, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	_root.hide()

## summary keys (all optional): heists, stage, gold, index, kills, cause, venue
func show_death(summary: Dictionary = {}) -> void:
	Audio.music("end_busted", 0.8)
	Audio.loop("alarm", false)
	Audio.loop("heartbeat", false)
	var headline := Headlines.busted(summary)
	_present(headline, summary, false)

func show_victory(summary: Dictionary = {}) -> void:
	Audio.music("end_retire")
	var headline := Headlines.victory(summary)
	_present(headline, summary, true)

func _present(headline: Array, summary: Dictionary, victory: bool) -> void:
	_paper = Newspaper.new()
	_paper.headline = headline[0]
	_paper.subhead = headline[1]
	_paper.summary = summary
	_paper.victory = victory
	_paper.position = Vector2(170, 740)
	_paper.size = Vector2(940, 680)
	_paper.rotation = 0.35
	_paper.pivot_offset = _paper.size * 0.5
	_root.add_child(_paper)
	_button = Button.new()
	_button.text = "Back to the street"
	_button.theme_type_variation = "PrimaryButton"
	_button.position = Vector2(930, 648)
	_button.size = Vector2(320, 60)
	_button.pressed.connect(_on_pressed)
	_button.modulate.a = 0.0
	_root.add_child(_button)
	_root.show()
	get_tree().paused = true
	# The paper spins in and lands on the desk.
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "color:a", 0.88, 0.4)
	tw.parallel().tween_property(_paper, "position", Vector2(170, 20), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_paper, "rotation", -0.025, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_button, "modulate:a", 1.0, 0.25)
	var fresh: Array = summary.get("new_specialists", [])
	if not fresh.is_empty():
		tw.tween_callback(SpecialistPopup.present.bind(self, fresh))
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui("paper")
	_button.grab_focus.call_deferred()

func _on_pressed() -> void:
	# Parented to the tree ROOT so it survives scene changes — free it here.
	get_tree().paused = false
	dismissed.emit()
	RunFlow.queue_scene("res://home_screen.tscn")
	queue_free()

func _exit_tree() -> void:
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false


class Headlines:
	## BUSTED variants: the headline names what got you (a boss, the kind of
	## guard, a five-star manhunt, an explosion, a rival crew), the story
	## says where.
	static func busted(s: Dictionary) -> Array:
		var stage := String(s.get("stage", "Town")).to_upper()
		var venue := StringName(s.get("venue", ""))
		var noun := Venues.noun(venue) if venue != &"" else "WAREHOUSE"
		var who := String(s.get("who", "an unnamed crew"))
		var cause := String(s.get("cause", ""))
		var where := String(s.get("where", "")).capitalize()
		if where == "":
			where = Venues.sign_name(venue) if venue != &"" else "a downtown building"
		if cause == "quota":
			return ["BOARD CUTS OFF DELINQUENT CREW",
				"Collector's ledger comes up short in %s. Sources say %s has been delisted — and nobody gets relisted." % [stage.capitalize(), who]]
		var pick := func(pool: Array) -> String:
			return pool[absi(hash(str(s.get("heists", 0)) + noun + cause)) % pool.size()]
		match cause:
			"boss:landlord":
				return ["LANDLORD SERVES FINAL EVICTION", "%s fell in the %s. The Landlord was seen collecting rent an hour later, shotgun still warm." % [who, where]]
			"boss:auditor":
				return ["AUDITOR CLOSES THE BOOKS ON LOCAL CREW", "%s was written off in the %s. The Auditor's ledger shows the account settled in full." % [who, where]]
			"boss:ambassador":
				return ["DIPLOMATIC INCIDENT AT THE EMBASSY", "%s fell in the %s. The Ambassador has claimed immunity and declined to comment." % [who, where]]
			"boss:chairman":
				return ["THE CHAIRMAN DELISTS A CHALLENGER", "%s fell on the %s, a floor above the city. The ticker never paused." % [who, where]]
			"police":
				return [pick.call(["FIVE-STAR MANHUNT ENDS AT THE %s" % noun, "CITYWIDE DRAGNET CORNERS CREW"]),
					"Cruisers, a helicopter and half the precinct closed in on %s at %s. Witnesses counted sirens until they lost count." % [who, where]]
			"explosion":
				return [pick.call(["BLAST ROCKS THE %s" % noun, "FIREBALL ENDS %s HEIST" % stage]),
					"Investigators sifting the %s found scorched ledgers, twisted metal and what was left of %s." % [where, who]]
			"rival":
				return ["RIVAL CREW SETTLES A SCORE", "%s was cut down by another crew inside %s. The Board recognises the survivors." % [who, where]]
			"lieutenant":
				return ["BOARD LIEUTENANT CLAIMS A SCALP", "One of the Board's named men put %s down in the %s and was back at his post by morning." % [who, where]]
		if cause.begins_with("kind:"):
			var kind := cause.substr(5)
			var line := KIND_HEADLINES.get(kind, "%s STOPS ROBBERY AT THE %s") as String
			var head := line
			if line.count("%s") == 1:
				head = line % noun
			elif line.count("%s") == 2:
				head = line % [kind, noun]
			return [head,
				"Police say %s fell in the %s. The %s who did it went back to work." % [who, where, kind.to_lower()]]
		var pool := [
			"CREW BUSTED IN %s %s SHOOTOUT" % [stage, noun],
			"%s JOB ENDS IN BLOOD" % noun,
			"GUNFIRE AT THE %s: SUSPECT DOWN" % noun,
		]
		return [pick.call(pool), "Police say %s fell inside %s. Witnesses describe a well-dressed figure, a getaway car that never left, and a stock ticker that would not stop falling." % [who, where]]

	## Headlines by the kind of guard that did it (%s = the venue's noun).
	const KIND_HEADLINES := {
		"GUARD": "NIGHT GUARD FOILS HEIST AT THE %s",
		"LASER SNIPER": "ONE SHOT FROM THE DARK AT THE %s",
		"MARKSMAN": "MARKSMAN ENDS %s STANDOFF",
		"DOG": "GUARD DOG RUNS DOWN THIEF AT THE %s",
		"BRUTE": "BRUTE FORCE AT THE %s: THIEF CRUSHED",
		"RIOT SHIELD": "RIOT SQUAD HOLDS THE LINE AT THE %s",
		"TURRET": "AUTOMATED DEFENSES CUT DOWN THIEF AT THE %s",
		"DRONE": "SECURITY DRONE CORNERS THIEF AT THE %s",
		"SHOTGUNNER": "SHOTGUN BLAST ENDS %s ROBBERY",
		"BOUNCER": "BOUNCER THROWS OUT A THIEF — PERMANENTLY",
	}

	static func victory(s: Dictionary) -> Array:
		if s.get("ending", "") == "new_chairman":
			return ["NEW FACE IN THE CHAIRMAN'S SEAT", "The Board has a new chair and nobody will say the name out loud. The index has never been higher."]
		return ["THE CHAIRMAN FALLS; CREW VANISHES", "The Exchange tower dark tonight. The Board's books are missing. So is the crew that opened them."]


## The front page itself.
class Newspaper extends Control:
	var headline := ""
	var subhead := ""
	var summary: Dictionary = {}
	var victory := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var date := Time.get_date_dict_from_system()
		var masthead := VisualTheme.label("THE DAILY LEDGER", "", 58, Palette.INK)
		masthead.add_theme_font_override("font", VisualTheme.font("heading_bold"))
		masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		masthead.position = Vector2(0, 8)
		masthead.size = Vector2(size.x, 80)
		add_child(masthead)
		var line := VisualTheme.label("VOL. CXII   ·   %d/%d/%d   ·   LATE CITY EDITION   ·   TEN CENTS" % [date.get("month", 1), date.get("day", 1), date.get("year", 1955)], "", 16, Color("3a3428"))
		line.add_theme_font_override("font", VisualTheme.font("type_bold"))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.position = Vector2(0, 100)
		line.size = Vector2(size.x, 22)
		add_child(line)
		var head := VisualTheme.label(headline, "", 50, Palette.INK)
		head.add_theme_font_override("font", VisualTheme.font("heading_bold"))
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(size.x - 60, 0)
		head.position = Vector2(30, 132)
		head.size = Vector2(size.x - 60, 120)
		add_child(head)
		var sub := VisualTheme.label(subhead, "", 19, Color("2a2418"))
		sub.add_theme_font_override("font", VisualTheme.font("type"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(410, 0)
		sub.position = Vector2(480, 290)
		sub.size = Vector2(410, 160)
		add_child(sub)
		var facts := [
			"HEISTS PULLED ........ %d" % int(summary.get("heists", 0)),
			"LAST SEEN ............ %s" % String(summary.get("stage", "Town")),
			"CASH RECOVERED ....... $%d" % int(summary.get("gold", 0)),
			"BOARD INDEX CLOSED ... %d" % roundi(float(summary.get("index", 1.0))),
			"BODIES COUNTED ....... %d" % int(summary.get("kills", 0)),
		]
		if summary.has("clout"):
			facts.append("CLOUT ON THE STREET .. +%d" % int(summary["clout"]))
		var col := VisualTheme.label("\n".join(facts), "", 17, Palette.INK)
		col.add_theme_font_override("font", VisualTheme.font("mono"))
		col.position = Vector2(480, 470)
		add_child(col)
		var stamp := StampArt.new()
		stamp.text = "RETIRED" if victory else "BUSTED"
		stamp.ink = Palette.STAMP_GREEN if victory else Palette.STAMP_RED
		stamp.font_size = 60
		stamp.tilt = -0.22
		add_child(stamp)
		stamp.position = Vector2(110, 520)
		stamp.slam(0.8)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(10, 12), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color("e8e2d2"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 900:
			draw_rect(Rect2(Vector2(rng.randf() * size.x, rng.randf() * size.y), Vector2(2, 1)), Color(0, 0, 0, 0.04))
		draw_line(Vector2(24, 96), Vector2(size.x - 24, 96), Palette.INK, 3.0)
		draw_line(Vector2(24, 126), Vector2(size.x - 24, 126), Palette.INK, 1.5)
		draw_line(Vector2(24, 272), Vector2(size.x - 24, 272), Palette.INK, 1.5)
		# Press photo.
		var photo := Rect2(Vector2(30, 290), Vector2(420, 300))
		draw_rect(photo, Color("1a1a1c"))
		var night := Color("222226") if not victory else Color("2a2a30")
		draw_rect(Rect2(photo.position + Vector2(0, photo.size.y * 0.6), Vector2(photo.size.x, photo.size.y * 0.4)), night)
		if victory:
			# The dark tower, crown gone out.
			var c := photo.get_center()
			draw_rect(Rect2(c.x - 50, photo.position.y + 40, 100, photo.size.y - 40), Color("0e0e10"))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - 50, photo.position.y + 40), Vector2(c.x, photo.position.y + 10), Vector2(c.x + 50, photo.position.y + 40)]), Color("0e0e10"))
			for i in 30:
				draw_circle(photo.position + Vector2(rng.randf() * photo.size.x, rng.randf() * photo.size.y * 0.5), 1.0, Color(1, 1, 1, 0.5))
		else:
			# Police lights washing a chalk outline.
			draw_circle(photo.position + Vector2(110, 90), 90, Color(0.9, 0.2, 0.2, 0.18))
			draw_circle(photo.position + Vector2(310, 80), 90, Color(0.2, 0.3, 0.9, 0.18))
			var body := PackedVector2Array([Vector2(200, 230), Vector2(212, 200), Vector2(240, 196), Vector2(262, 214), Vector2(300, 206), Vector2(304, 220), Vector2(266, 232), Vector2(250, 262), Vector2(224, 262), Vector2(214, 238)])
			for i in body.size():
				body[i] += photo.position - Vector2(40, 30)
			draw_polyline(body + PackedVector2Array([body[0]]), Color(0.9, 0.9, 0.9, 0.8), 2.0, true)
			draw_rect(Rect2(photo.position + Vector2(20, 250), Vector2(380, 6)), Color("d8c02a"))
		# Halftone grain on the photo.
		for x in range(int(photo.position.x), int(photo.end.x), 6):
			for y in range(int(photo.position.y), int(photo.end.y), 6):
				if (x + y) % 12 == 0:
					draw_rect(Rect2(x, y, 1, 1), Color(1, 1, 1, 0.06))
		draw_rect(photo, Palette.INK, false, 2.0)
		# Filler columns of type.
		for col in 2:
			for i in 7:
				var y := 600.0 + i * 10
				var w := rng.randf_range(160, 200)
				if y < size.y - 20:
					draw_line(Vector2(30 + col * 220, y), Vector2(30 + col * 220 + w, y), Color(0, 0, 0, 0.25), 2.0)
