extends Node
class_name LiveStock

## Drives ONE venue's stock price in real time during a heist. Bullets landing,
## kills, and damage taken all nudge the price, scaled by the character's
## health-based volatility multiplier (low health = bigger swings both ways).
##
## Wire it: give it the CriminalMarket, the venue asset id, the player, and the
## character profile. Then the player/enemies call the report_* methods.

signal price_updated(price: float, delta: float, direction: int)  # dir: +1/-1
## Fired when something noteworthy happens, so the comment feed can react.
## kind: &"kill", &"hit", &"damage", &"boss", &"grade", &"drift_up", &"drift_down"
signal market_event(kind: StringName, magnitude: float)

@export var venue_asset_id: StringName = &""

## Background trading. Other people are in this market too — the price wobbles
## on its own, so it reads as a live order book rather than a score counter.
@export var tick_interval: float = 0.55       # seconds between background ticks
@export var noise_amplitude: float = 0.0035   # base random swing per tick
@export var momentum_retention: float = 0.75  # how strongly trends persist
## Pull back toward the venue's base price each tick. Without this, a long
## heist could drift the stock ±30% on luck alone and swamp the player's grade.
@export var mean_reversion: float = 0.004

var _market: CriminalMarket = null
var _player: Player = null
var _profile: CharacterProfile = null

var _tick_timer: float = 0.0
var _momentum: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	set_process(true)

func _process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = tick_interval
	_background_tick()

## A tick of ordinary trading: momentum plus noise, amplified by volatility so
## the market gets jumpier as the player gets closer to death.
func _background_tick() -> void:
	var vol := _current_vol()
	# Momentum carries the previous move forward, so trends form and break
	# instead of the price jittering around a fixed point.
	_momentum = _momentum * momentum_retention \
		+ _rng.randfn(0.0, noise_amplitude) * (1.0 - momentum_retention)
	var move := _momentum + _rng.randfn(0.0, noise_amplitude * 0.5)
	# Occasional larger orders hitting the book.
	if _rng.randf() < 0.03:
		move += _rng.randfn(0.0, noise_amplitude * 4.0)
	_apply_raw(move * vol)
	_revert_toward_base()
	if absf(move) > noise_amplitude * 3.0:
		market_event.emit(
			&"drift_up" if move > 0.0 else &"drift_down", absf(move))

## Nudge the price back toward its baseline so random walks can't run away.
func _revert_toward_base() -> void:
	var asset := _asset()
	if asset == null or asset.base_price <= 0.0:
		return
	asset.current_price += (asset.base_price - asset.current_price) * mean_reversion

func setup(market: CriminalMarket, player: Player, profile: CharacterProfile) -> void:
	_market = market
	_player = player
	_profile = profile

func _current_vol() -> float:
	if _profile == null or _player == null:
		return 1.0
	return _profile.volatility_for(_player.health)

func _asset() -> CriminalAsset:
	if _market == null or venue_asset_id == &"":
		return null
	return _market.get_asset(venue_asset_id)

## Apply a percentage move to the venue price, scaled by current volatility.
## pct is the base move (e.g. +0.01). Positive = up, negative = down.
func _apply(pct: float) -> void:
	# A player action doesn't just move the price once — it pushes the market's
	# momentum, so a good run builds a visible rally and a bad one bleeds out.
	_momentum += pct * 0.35
	_apply_raw(pct * _current_vol())

## Move the price by an already-scaled fraction, with no extra volatility pass.
func _apply_raw(effective: float) -> void:
	var asset := _asset()
	if asset == null:
		return
	var before := asset.current_price
	asset.current_price = max(before * (1.0 + effective), 0.01)
	var delta := asset.current_price - before
	var dir := 1 if delta >= 0.0 else -1
	price_updated.emit(asset.current_price, delta, dir)

# --- Called from gameplay ---

## Player landed a bullet on an enemy.
func report_hit_landed() -> void:
	var base := _profile.gain_per_hit if _profile else 0.01
	_apply(base)
	market_event.emit(&"hit", base)

## Player killed an enemy.
func report_kill() -> void:
	var base := _profile.gain_per_kill if _profile else 0.05
	_apply(base)
	market_event.emit(&"kill", base)

## Player took damage (crash, amplified at low health).
func report_damage_taken(amount: int) -> void:
	var base := (_profile.crash_per_damage if _profile else 0.04) * amount
	_apply(-base)
	market_event.emit(&"damage", base)

## A big scripted move (boss pump, grade payout at extraction).
func report_shock(multiplier: float, kind: StringName = &"grade") -> void:
	_momentum += (multiplier - 1.0) * 0.5
	_apply_raw(multiplier - 1.0)
	market_event.emit(kind, absf(multiplier - 1.0))
