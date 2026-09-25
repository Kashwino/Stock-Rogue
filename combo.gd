extends Node
class_name Combo
## THE RALLY — the heist's combo. The first kill starts it, every kill adds
## points and refreshes a 2.5 s window. Let the window run out and it CASHES
## OUT: gold (points x tier multiplier x a base that grows with the quota
## block) plus a small move in the venue. Take damage and it's a PANIC SELL:
## 75% of that gold is gone (stock moves already made stay made).
##
## Points per kill: kill 1 · each extra victim of a multi-kill +1 · overkill
## +1 · crit +1 · stealth takedown +2 · stagger execution +3 · explosive-prop
## kill +2 · last round in the mag +1 · during or 0.5 s after a dodge +1 ·
## at 1 HP +2 (Margin Call) · unprovoked victim +1 · variety (a weapon or
## method different from the last two kills) +1.
##
## While a combo is live the market rallies with you: each kill's stock gain
## is multiplied by the tier's multiplier.

signal changed()
signal tier_up(tier: int)
signal cashed(points: int, tier: int, gold: int, pct: float)
signal panicked(points: int, tier: int, gold: int)

const TIERS := ["TICK", "RALLY", "BULL RUN", "SURGE", "FRENZY", "BLACK SWAN"]
const THRESHOLDS := [0, 5, 12, 22, 35, 50]
const MULTS := [1.0, 1.2, 1.5, 2.0, 2.5, 3.0]
const TIER_COLORS := [Color("d9d2c3"), Color("f3d98c"), Color("e8b842"), Color("5fd18a"), Color("ff8a3d"), Color("ff4d5e")]
const BASE_WINDOW := 2.5
## The small venue pump on a cash-out: base + per point, capped.
const PUMP_BASE := 0.003
const PUMP_PER_POINT := 0.0002
const PUMP_MAX := 0.01
const PANIC_KEEP := 0.25
## Combo gold per heist is capped at ~35% of a thorough heist's floor loot
## (tools/loot_census.json), per stage.
const GOLD_CAP := [140, 205, 355, 560]

var host: Node
var live := false
var points := 0
var tier := 0
var window := BASE_WINDOW
var window_left := 0.0
var log_lines: Array = []          # recent "+2 TAKEDOWN" lines, newest last
## Per-heist totals (results, grade, Meta).
var best_points := 0
var best_tier := 0
var cashed_points := 0
var cashed_gold := 0
var combos_cashed := 0
var panics := 0
var dead_cat_used := false
var _methods: Array = []           # last two kill methods, for variety
var _kills := 0

# ----------------------------------------------------------------- tuning --
func window_length() -> float:
	var w := BASE_WINDOW + float(RunState.profile_value("combo_window_bonus", 0.0))
	if RunState.has_relic(&"momentum_trader"):
		w += 1.0
	return w

func threshold(t: int) -> int:
	var th: int = THRESHOLDS[t]
	if RunState.has_relic(&"compound_interest"):
		th = int(floor(th * 0.8))
	return th

## The tier multiplier (the Legend's are 1.5x).
func multiplier(t: int = -1) -> float:
	var m: float = MULTS[tier if t < 0 else t]
	return m * float(RunState.profile_value("combo_tier_mult", 1.0))

## What each kill's stock gain is multiplied by right now.
func market_multiplier() -> float:
	return multiplier() if live else 1.0

func stage() -> int:
	if host and host.has_method("stage_index"):
		return clampi(host.stage_index(), 0, GOLD_CAP.size() - 1)
	return 0

func base_gold() -> float:
	var block := RunState.run_map.quota_block if RunState.run_map else 0
	return 2.0 * pow(1.55, clampi(block, 0, 4))

func cap() -> int:
	return int(GOLD_CAP[stage()])

## Gold the live combo would pay if it cashed out now (before the cap).
func pending_gold() -> int:
	var g := points * multiplier() * base_gold()
	g *= float(RunState.profile_value("combo_cash_mult", 1.0))
	return int(round(g))

func tier_name(t: int = -1) -> String:
	return TIERS[tier if t < 0 else t]

func tier_color(t: int = -1) -> Color:
	return TIER_COLORS[tier if t < 0 else t]

# ------------------------------------------------------------------ kills --
func on_kill(info: KillInfo) -> void:
	if info == null or not info.by_player:
		return
	var player: Node = host.player if host else null
	var gained: Array = []                      # [points, reason]
	gained.append([1, "KILL"])
	if info.multi >= 2:
		gained.append([1, "MULTI"])
	if info.overkill:
		gained.append([1, "OVERKILL"])
	if info.crit:
		gained.append([1, "CRIT"])
	if info.source == &"takedown" and info.stealth:
		gained.append([2 + int(RunState.profile_value("takedown_combo_bonus", 0)), "TAKEDOWN"])
	if info.source == &"execution":
		gained.append([3, "EXECUTION"])
	if info.prop:
		gained.append([2, "DETONATION"])
	if info.kill_class == KillInfo.EXPLOSIVE and RunState.has_relic(&"short_fuse"):
		gained.append([1, "SHORT FUSE"])
	if info.last_round:
		gained.append([1, "LAST ROUND"])
	if player and player.has_method("dodged_recently") and player.dodged_recently(0.5):
		gained.append([1, "DODGE"])
	if player and int(player.get("health")) == 1:
		gained.append([2, "MARGIN CALL"])
	if info.unprovoked:
		gained.append([1, "UNAWARE"])
	var method := String(info.weapon_id) if info.source == &"bullet" and info.weapon_id != &"" else String(info.source)
	if _methods.size() >= 2 and not (method in _methods):
		gained.append([1, "VARIETY"])
	_methods.append(method)
	while _methods.size() > 2:
		_methods.pop_front()
	var total := 0
	for g: Array in gained:
		total += int(g[0])
		if int(g[0]) > 0:
			_log("+%d %s" % [g[0], g[1]])
	add_points(total)

## Add points (kills, the debug menu), starting a combo if none is live.
func add_points(amount: int) -> void:
	if not live:
		live = true
		points = 0
		tier = 0
	points += amount
	_kills += 1
	window = window_length()
	window_left = window
	var old := tier
	while tier < TIERS.size() - 1 and points >= threshold(tier + 1):
		tier += 1
	best_points = maxi(best_points, points)
	best_tier = maxi(best_tier, tier)
	if tier > old:
		_on_tier_up()
	changed.emit()

func _on_tier_up() -> void:
	tier_up.emit(tier)
	Audio.play("combo_up", null, 0.0, 1.0 + tier * 0.06)
	if RunState.has_relic(&"blood_money") and host and is_instance_valid(host.player):
		host.drop_loot(host.player.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 10 + 6 * tier)

func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 5:
		log_lines.pop_front()

# ------------------------------------------------------------ end of combo --
func _process(delta: float) -> void:
	if not live:
		return
	window_left -= delta
	if window_left <= 0.0:
		cash_out()
	else:
		changed.emit()

## The window ran out: bank it.
func cash_out() -> void:
	if not live:
		return
	var gold := mini(pending_gold(), maxi(0, cap() - cashed_gold))
	var pct := minf(PUMP_BASE + points * PUMP_PER_POINT, PUMP_MAX) * float(RunState.profile_value("combo_cash_mult", 1.0))
	if host and host.get("live") and host.live:
		host.live.report_shock(1.0 - pct if host.live.inverted() else 1.0 + pct, &"combo")
	if gold > 0:
		RunEconomy.add_bonus(gold)
	cashed_gold += gold
	cashed_points += points
	combos_cashed += 1
	var p := points
	var t := tier
	_end()
	cashed.emit(p, t, gold, pct)
	Audio.play("combo_cash")

## Taking damage breaks it: most of the money is gone.
func on_player_hurt() -> void:
	if not live:
		return
	if RunState.has_relic(&"dead_cat_bounce") and not dead_cat_used:
		dead_cat_used = true
		_log("DEAD CAT BOUNCE")
		changed.emit()
		return
	var gold := mini(int(round(pending_gold() * PANIC_KEEP)), maxi(0, cap() - cashed_gold))
	if gold > 0:
		RunEconomy.add_bonus(gold)
	cashed_gold += gold
	panics += 1
	var p := points
	var t := tier
	_end()
	panicked.emit(p, t, gold)
	Audio.play("combo_crash")

func _end() -> void:
	live = false
	points = 0
	tier = 0
	window_left = 0.0
	log_lines.clear()
	_methods.clear()
	changed.emit()

## Pay out a live combo when the heist ends (extraction).
func settle() -> void:
	if live:
		cash_out()
