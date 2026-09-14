extends Resource
class_name CriminalAsset

## A tradeable criminal venture. Its "share price" drifts each tick and
## reacts to market events based on its tier, volatility, and sensitivities.

enum Tier { STREET, BURGLARY, INSTITUTIONAL, PRESTIGE, CATASTROPHE }

@export var id: StringName                 # "bank_job", "reactor_sabotage"
@export var display_name: String           # "Bank Job Ltd."
@export var tier: Tier = Tier.STREET

# --- Price ---
@export var base_price: float = 10.0       # starting / reference price
@export_range(0.0, 1.0) var volatility: float = 0.1  # per-tick random swing magnitude
@export_range(-0.2, 0.2) var drift: float = 0.0      # baseline trend per tick (+ = grows)

# --- Capital / position sizing ("ante" to run a job) ---
@export var ante: float = 5.0              # capital locked per unit held
@export var prestige_required: int = 0     # gate: unlock threshold

# --- Event & market coupling ---
# Maps an event id -> multiplier applied to price when that event resolves.
# e.g. { "interpol_crackdown": 0.6, "corrupt_official": 1.3 }
@export var event_sensitivity: Dictionary = {}

# Maps another asset id -> correlation weight (-1..1). Its moves bleed into this.
# e.g. Fence Network correlates positively with everyone.
@export var correlations: Dictionary = {}

# --- Runtime state (not exported; set at runtime) ---
var current_price: float = 0.0
var heat: float = 0.0                       # rises with activity; high heat = forced lie-low
var last_delta: float = 0.0                 # last tick's price change (for candlesticks)

func initialize() -> void:
	current_price = base_price
	heat = 0.0
	last_delta = 0.0

## Advance one market tick. `rng` lets you seed runs for reproducibility.
## `market_signal` is a global index (0..1) you can read to time entries.
func tick(rng: RandomNumberGenerator, market_signal: float = 0.5) -> void:
	var noise := rng.randfn(0.0, volatility)          # gaussian swing
	var trend := drift
	# Higher heat suppresses upside (crime under scrutiny cools off).
	var heat_penalty := -heat * 0.02
	var pct := trend + noise + heat_penalty
	var new_price: float = max(current_price * (1.0 + pct), 0.01)
	last_delta = new_price - current_price
	current_price = new_price
	heat = max(heat - 0.05, 0.0)                        # heat decays slowly

## Apply a resolving event. Returns the price delta caused by it.
func apply_event(event_id: StringName) -> float:
	if not event_sensitivity.has(event_id):
		return 0.0
	var mult: float = float(event_sensitivity[event_id])
	var before := current_price
	current_price = max(current_price * mult, 0.01)
	last_delta = current_price - before
	heat += 1.0                                         # events draw attention
	return last_delta

func is_unlocked(player_prestige: int) -> bool:
	return player_prestige >= prestige_required
