extends Control
## HUD preview (Brief 3): every Noir Props HUD element in every state,
## cycling on a timer, over a dark floor, for quick visual checks.
##   godot --path . res://tools/hud_preview.tscn
##   (xvfb-run ... -- out=/tmp/preview.png frames=N  saves a frame and quits;
##    headless with only frames=N it cycles N frames and quits, for errors)
## Chips gain and lose, cash riffles and spends, the tag swings, a pistol /
## revolver / shotgun fire, reload and swap, the objective strikes through,
## stars climb 0-5, combo tiers climb and panic, every banner, the boss bar
## fills, drains and shatters, verdict stamps slam, prompts, damage numbers
## and ticker slips float.

var _t := 0.0
var _step := 0
var _chips: HudProps.ChipStack
var _money: HudProps.MoneyClip
var _racks: Array = []
var _note: HudPaper.ObjectiveNote
var _machine: HudPaper.TickerMachine
var _feed: TraderFeed
var _heat: HudPulp.HeatBar
var _combo: Combo
var _slab: HudPulp.ComboSlab
var _banner: HudPulp.Banner
var _caption: HudPulp.Caption
var _boss: BossBar
var _file: VerdictCard.CaseFile
var _world: Node2D
var _marks: Array = []
var _args := {}

func _ready() -> void:
	for raw: String in OS.get_cmdline_user_args():
		var parts := raw.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RunState.start_run(load("res://main_character.tres"), 1955)
	RunState.add_max_health(1)
	for r in [&"blood_money", &"hair_trigger", &"laundered_cash", &"laundered_cash", &"deed_box"]:
		RunState.add_relic(r)
	var bg := ColorRect.new()
	bg.color = Color("24201c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tape := TickerTape.new()
	tape.paper = true
	tape.size = Vector2(1280, 30)
	add_child(tape)
	_note = HudPaper.ObjectiveNote.new()
	_note.position = Vector2(20, 44)
	_note.size = Vector2(300, 160)
	add_child(_note)
	_heat = HudPulp.HeatBar.new()
	_heat.position = Vector2(380, 32)
	_heat.size = Vector2(520, 120)
	add_child(_heat)
	var map := HudPaper.BlueprintMap.new()
	map.position = Vector2(1016, 104)
	map.size = Vector2(248, 132)
	add_child(map)
	_machine = HudPaper.TickerMachine.new()
	_machine.position = Vector2(1016, 238)
	_machine.size = Vector2(248, 128)
	add_child(_machine)
	_machine.set_venue(&"bank_job")
	_feed = TraderFeed.new()
	_feed.telegram = true
	_feed.position = Vector2(1020, 370)
	_feed.size = Vector2(244, 62)
	add_child(_feed)
	for pair in [["map", "MAP", 1110], ["pause", "PAUSE", 1184]]:
		var key := TypewriterKey.new()
		key.icon_name = pair[0]
		key.caption = pair[1]
		key.position = Vector2(pair[2], 30)
		key.size = Vector2(66, 72)
		add_child(key)
	_chips = HudProps.ChipStack.new()
	_chips.position = Vector2(16, 574)
	_chips.size = Vector2(70, 138)
	add_child(_chips)
	_money = HudProps.MoneyClip.new()
	_money.position = Vector2(88, 624)
	_money.size = Vector2(236, 90)
	add_child(_money)
	var books := HudProps.Matchbooks.new()
	books.position = Vector2(470, 654)
	books.size = Vector2(340, 60)
	add_child(books)
	for i in 3:
		var rack := HudProps.WeaponRack.new()
		rack.position = Vector2(924, 480 + i * 118) if i < 2 else Vector2(560, 540)
		rack.size = Vector2(340, 104)
		add_child(rack)
		_racks.append(rack)
	var weapons := [&"pistol", &"snub38", &"shotgun"]
	for i in 3:
		for w: WeaponItem in ItemPool.weapons():
			if w.id == weapons[i]:
				_racks[i].set_weapon(w, w.eff_mag(), -1 if i == 0 else 24)
	_combo = Combo.new()
	add_child(_combo)
	_slab = HudPulp.ComboSlab.new()
	_slab.position = Vector2(340, 190)
	_slab.size = Vector2(272, 140)
	add_child(_slab)
	_slab.bind_combo(_combo)
	_banner = HudPulp.Banner.new()
	_banner.position = Vector2(620, 180)
	_banner.size = Vector2(380, 92)
	add_child(_banner)
	_caption = HudPulp.Caption.new()
	_caption.position = Vector2(330, 470)
	_caption.size = Vector2(640, 46)
	add_child(_caption)
	_boss = BossBar.new()
	add_child(_boss)
	_boss.position = Vector2(340, 330)
	_boss.show_for(null, "THE LANDLORD", "Owns every door in Town.", [0.5, 0.2])
	_boss.preview_frac = 1.0
	_file = VerdictCard.CaseFile.new()
	_file.boss_id = &"landlord"
	_file.position = Vector2(20, 214)
	_file.size = Vector2(640, 400)
	_file.scale = Vector2(0.48, 0.48)
	add_child(_file)
	_world = Node2D.new()
	add_child(_world)
	var prompt := WorldPrompt.new()
	prompt.text = "ALARM PANEL\nHOLD USE / E  —  CUT THE LINE"
	prompt.position = Vector2(170, 450)
	_world.add_child(prompt)
	var terminal := WorldPrompt.new()
	terminal.text = "MARKET TERMINAL\nUSE / E"
	terminal.color = Palette.NEON_CYAN
	terminal.position = Vector2(170, 510)
	_world.add_child(terminal)
	for i in 6:
		var m := CombatFX.FloatMark.new()
		_world.add_child(m)
		_marks.append(m)
	_tick()

func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.0:
		_t = 0.0
		_tick()
	if (_args.has("out") or _args.has("frames")) and Engine.get_process_frames() >= int(_args.get("frames", "240")):
		var image := get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
		if _args.has("out"):
			if image:
				image.save_png(String(_args["out"]))
			else:
				print("hud_preview: no image headless — run with a display (xvfb-run) to save a frame")
		_args.erase("out")
		_args.erase("frames")
		set_process(false)
		Audio.silence()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(0)

## One step of the cycle: every element moves to its next state.
func _tick() -> void:
	_step += 1
	var s := _step
	_chips.set_health([4, 3, 2, 1, 2, 3, 4][s % 7], 4)
	_money.set_gold([250, 480, 1300, 900, 180][s % 5])
	_money.set_loot_multiplier([1.0, 1.08, 0.94, 1.22][s % 4])
	_note.set_objective("SMASH & GRAB" if s % 6 < 3 else "LOOT", ("Jackpot rooms %d/3\nLockdown in 0:%02d" % [s % 3, 59 - s % 60]) if s % 6 < 3 else "Grab the valuables.\nGet back to the car.")
	_heat.set_values(float(s * 3 % 40), 16.0, 12.0, float(20 - s % 20))
	_heat.set_stars(s % 6)
	if s % 6 == 0:
		_heat.stars = 0
	_heat.push_source(["CAMERA SPOTTED YOU  +8", "GUARD RADIO CALL  +10", "ALARM PANEL TRANSMITTING  +3"][s % 3])
	_machine.set_price(40.0 + sin(s) * 4.0, sin(s) * 0.08, sin(s) > sin(s - 1))
	if s % 2 == 0:
		_feed.post(["vaultrat", "no_alibi", "FenceKing"][s % 3], ["buying every dip on this one", "selling. SELLING.", "clean exit. textbook."][s % 3], [Palette.UP, Palette.DOWN, Palette.GOLD][s % 3])
	for i in _racks.size():
		var rack: HudProps.WeaponRack = _racks[i]
		if rack.weapon == null:
			continue
		if s % 8 == 7:
			rack.start_reload(0.8)
			rack.set_ammo(rack.weapon.eff_mag(), rack.reserve)
		elif rack.mag > 0:
			rack.set_ammo(rack.mag - 1, rack.reserve)
	# The combo climbs through its tiers, cashes, then panics.
	if s % 10 == 9:
		_combo.on_player_hurt()
	elif s % 10 == 0:
		_combo.cash_out()
	else:
		_combo.add_points(6)
		_combo._log(["+2 TAKEDOWN", "+1 OVERKILL", "+1 CRIT", "+3 EXECUTION"][s % 4])
		_combo.window = 999.0
		_combo.window_left = 500.0 + s % 4 * 100.0
	if s % 3 == 0:
		_banner.show_count([2, 3, 4][s / 3 % 3])
	if s % 4 == 1:
		_caption.show_line(["COMBO CASHED — 27 pts · BULL RUN · +$84 · +0.8%", "PANIC SELL — 18 pts dumped · +$22", "FLIPPED — SAFEHOUSE RENT"][s % 3], [Palette.GOLD, Palette.DANGER, Palette.STAMP_GREEN][s % 3], s % 3 == 1)
	_boss.preview_frac = [1.0, 0.7, 0.45, 0.18, 0.0, 0.0][s % 6]
	_boss.preview_kneel = s % 6 >= 4
	if s % 5 == 0:
		var v: StringName = [Verdicts.EXECUTE, Verdicts.FLIP, Verdicts.SHAKE, Verdicts.DEAL][s / 5 % 4]
		_file.slam(Verdicts.card_title(v, &"landlord"), Verdicts.stamp_color(v))
	var m: CombatFX.FloatMark = _marks[s % _marks.size()]
	if s % 2 == 0:
		m.start(Vector2(700, 440), str(1 + s % 4), Palette.PAPER, CombatFX.FloatMark.NUMBER, s % 4 == 0)
	else:
		m.start(Vector2(820, 440), "BANK %+.1f%%" % (sin(s) * 3.0), Palette.UP if sin(s) > 0.0 else Palette.DOWN, CombatFX.FloatMark.SLIP, false)
