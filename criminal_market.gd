extends Node
class_name CriminalMarket

## Owns the roster, ticks the market, fires events, and propagates correlations.
## Add as an autoload or child node; call setup() then advance() each round.

signal market_ticked(prices: Dictionary)          # id -> current_price
signal event_fired(event_id: StringName, label: String)

@export var assets: Array[CriminalAsset] = []

var _by_id: Dictionary = {}                        # id -> CriminalAsset
var _rng := RandomNumberGenerator.new()
var market_signal: float = 0.5                     # global index (e.g. "carat price")

# Event pool: id -> human-readable label. Weight by tier as you like.
const EVENTS := {
	&"interpol_crackdown":   "Interpol Crackdown — institutional sector crashes",
	&"corrupt_official":     "Corrupt Official Elected — sector rally",
	&"silent_alarm":         "Silent Alarm — burglary/bank drawdown",
	&"bullion_convoy":       "Bullion Convoy Spotted — transit ambush spikes",
	&"forgery_scandal":      "Forgery Scandal — museum swings",
	&"audit":                "Surprise Audit — casino skim hit",
	&"turf_war":             "Turf War — street tier crashes",
	&"meltdown":             "Reactor Incident — catastrophe resolves",
}

func setup(run_seed: int = 0) -> void:
	if run_seed != 0:
		_rng.seed = run_seed
	else:
		_rng.randomize()
	_by_id.clear()
	for a in assets:
		a.initialize()
		_by_id[a.id] = a

## Advance one full market round: drift/noise -> maybe an event -> correlations.
func advance(event_chance: float = 0.35) -> void:
	# 1. Wander the global signal a little.
	market_signal = clampf(market_signal + _rng.randfn(0.0, 0.05), 0.0, 1.0)

	# 2. Base tick for every asset.
	for a in assets:
		a.tick(_rng, market_signal)

	# 3. Possibly fire one event this round.
	if _rng.randf() < event_chance:
		var keys := EVENTS.keys()
		var eid: StringName = keys[_rng.randi() % keys.size()]
		for a in assets:
			a.apply_event(eid)
		event_fired.emit(eid, EVENTS[eid])

	# 4. Propagate correlations (one pass off pre-correlation deltas).
	var deltas := {}
	for a in assets:
		deltas[a.id] = a.last_delta
	for a in assets:
		for other_id in a.correlations.keys():
			if deltas.has(other_id):
				var w: float = float(a.correlations[other_id])
				a.current_price = max(a.current_price + deltas[other_id] * w, 0.01)

	var snapshot := {}
	for a in assets:
		snapshot[a.id] = a.current_price
	market_ticked.emit(snapshot)

func price_of(id: StringName) -> float:
	return _by_id[id].current_price if _by_id.has(id) else 0.0

func get_asset(id: StringName) -> CriminalAsset:
	return _by_id.get(id)
