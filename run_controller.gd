extends Node
class_name RunController

## Drives one run: blocks of rounds, three phases per round, quota checks,
## and the cash pool. Owns a CriminalMarket. Emits signals for the UI to react.
##
## Phase flow per round:
##   PREP (real-time trading + spending) -> [pause] -> HEIST -> CHASE -> next round
## Every ROUNDS_PER_BLOCK rounds, quota is checked. Miss it = run ends.

signal phase_changed(phase: Phase)
signal cash_changed(cash: float)
signal heat_changed(heat: float)
signal block_completed(block: int, quota: float, met: bool)
signal round_advanced(round_index: int, block: int)
signal heist_resolved(result: Dictionary)
signal chase_resolved(result: Dictionary)
signal run_ended(reason: String, final_cash: float)

enum Phase { PREP, PAUSE, HEIST, CHASE }

const ROUNDS_PER_BLOCK := 3
const MAX_HEAT := 10.0
const BASE_QUOTA := 300.0
const QUOTA_GROWTH := 1.6          # quota multiplies by this each block

@export var starting_cash: float = 100.0

var market: CriminalMarket
var cash: float = 0.0
var heat: float = 0.0
var round_index: int = 0           # 0-based, global across the run
var block: int = 0                 # 0-based block counter
var current_phase: Phase = Phase.PREP
var prep_quality: float = 0.0      # accumulated from spending this round
var holdings: Dictionary = {}      # asset_id -> units held
var active_job: StringName = &""   # the venture being heisted this round
var _rng := RandomNumberGenerator.new()
var _alive: bool = true

func setup(market_node: CriminalMarket, seed: int = 0) -> void:
	market = market_node
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	cash = starting_cash
	heat = 0.0
	round_index = 0
	block = 0
	_alive = true
	holdings.clear()
	_set_phase(Phase.PREP)
	cash_changed.emit(cash)
	heat_changed.emit(heat)

func current_quota() -> float:
	return BASE_QUOTA * pow(QUOTA_GROWTH, block)

# --- Cash pool (trading + heist share one pool) ---
func add_cash(amount: float) -> void:
	cash += amount
	cash_changed.emit(cash)
	if cash <= 0.0:
		_end_run("Bankrupt")

func spend(amount: float) -> bool:
	if amount > cash:
		return false
	cash -= amount
	cash_changed.emit(cash)
	return true

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, MAX_HEAT)
	heat_changed.emit(heat)
	if heat >= MAX_HEAT:
		_end_run("Busted")

# --- Prep phase ---
## Spend cash on prep to raise this round's prep_quality. Returns success.
func buy_prep(cost: float, quality_gain: float) -> bool:
	if not spend(cost):
		return false
	prep_quality += quality_gain
	return true

## Trading: buy N units of an asset at current price.
func buy_asset(asset_id: StringName, units: int) -> bool:
	var price := market.price_of(asset_id)
	var total := price * units
	if not spend(total):
		return false
	holdings[asset_id] = holdings.get(asset_id, 0) + units
	return true

## Trading: sell N units at current price.
func sell_asset(asset_id: StringName, units: int) -> bool:
	var have: int = holdings.get(asset_id, 0)
	if units > have:
		return false
	var price := market.price_of(asset_id)
	holdings[asset_id] = have - units
	add_cash(price * units)
	return true

## Choose which venture to heist this round.
func set_active_job(asset_id: StringName) -> void:
	active_job = asset_id

## Called each real-time tick during PREP so the market moves while trading.
func prep_tick() -> void:
	if current_phase == Phase.PREP:
		market.advance()

## Player signals they're done prepping.
func finish_prep() -> void:
	if current_phase == Phase.PREP:
		_set_phase(Phase.PAUSE)

## After the pause, launch the heist.
func begin_heist() -> void:
	if current_phase != Phase.PAUSE:
		return
	_set_phase(Phase.HEIST)
	_resolve_heist_and_chase()

# --- Resolution (heist flows into chase with no pause) ---
func _resolve_heist_and_chase() -> void:
	var asset := market.get_asset(active_job)
	if asset == null:
		push_error("RunController: no active job set")
		return
	# Difficulty scales with the venture's tier.
	var difficulty := float(asset.tier) + 1.0

	var heist := HeistResolver.resolve_heist(prep_quality, difficulty, _rng)
	add_heat(heist["heat_gained"])
	heist_resolved.emit(heist)

	# Straight into the chase, no pause.
	_set_phase(Phase.CHASE)
	var chase := HeistResolver.resolve_chase(
		heist["outcome"], prep_quality, heat, _rng)
	add_heat(chase["heat_gained"])
	chase_resolved.emit(chase)

	# Payout = venture price * loot_multiplier * loot_kept.
	var payout := asset.current_price * heist["loot_multiplier"] * chase["loot_kept"]
	add_cash(payout)

	if _alive:
		_advance_round()

# --- Round / block progression ---
func _advance_round() -> void:
	round_index += 1
	prep_quality = 0.0
	active_job = &""

	# Block boundary?
	if round_index % ROUNDS_PER_BLOCK == 0:
		var quota := current_quota()
		var met := cash >= quota
		block_completed.emit(block, quota, met)
		if not met:
			_end_run("Quota not met")
			return
		block += 1

	if _alive:
		round_advanced.emit(round_index, block)
		_set_phase(Phase.PREP)

func _set_phase(p: Phase) -> void:
	current_phase = p
	phase_changed.emit(p)

func _end_run(reason: String) -> void:
	if not _alive:
		return
	_alive = false
	var survived := reason == "Victory"
	Meta.record_run_end(cash, survived)
	RunSave.delete_run()               # roguelike: no resume after death
	run_ended.emit(reason, cash)

# --- Save / resume ---
func snapshot() -> Dictionary:
	return {
		"cash": cash, "heat": heat, "round_index": round_index,
		"block": block, "holdings": holdings, "prep_quality": prep_quality,
		"active_job": String(active_job),
	}

func restore(state: Dictionary) -> void:
	cash = float(state.get("cash", starting_cash))
	heat = float(state.get("heat", 0.0))
	round_index = int(state.get("round_index", 0))
	block = int(state.get("block", 0))
	holdings = state.get("holdings", {})
	prep_quality = float(state.get("prep_quality", 0.0))
	active_job = StringName(state.get("active_job", ""))
	cash_changed.emit(cash)
	heat_changed.emit(heat)
	_set_phase(Phase.PREP)
