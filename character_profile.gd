extends Resource
class_name CharacterProfile

## Per-character tuning. Base health plus how sharply the stock reacts as the
## character's health drops. Low health = higher volatility multiplier, which
## amplifies BOTH stock gains (kills/hits) and crashes (taking damage).

@export var id: StringName = &"main"
@export var display_name: String = "The Operator"
@export var base_health: int = 3

## Volatility at FULL health (baseline reaction). 1.0 = normal.
@export var volatility_at_full: float = 1.0

## Volatility at 1 HP (maximum reaction). Higher = more swing when nearly dead.
@export var volatility_at_low: float = 2.5

## Curve shape: 1.0 = linear ramp; >1 keeps it calm until health is really low;
## <1 ramps up quickly after the first hit.
@export var volatility_curve: float = 1.5

## Base stock move sizes (percent, before volatility multiplier).
##
## TUNING: gains are deliberately TINY. A heist has dozens of enemies, and these
## compound — at +1%/hit a single building pumped a venue past 10,000%, which
## drowned out the grade multiplier entirely. Combat should be a background hum;
## the GRADE (+40% S+ down to -25% D) is what actually moves the market.
##
## Damage is the opposite: one hit costs roughly 14 kills' worth of gains, and
## ~7 hits erases an entire flawless building. Getting hit must genuinely hurt.
@export var gain_per_hit: float = 0.0008      # +0.08% per bullet landed
@export var gain_per_kill: float = 0.004      # +0.4% per kill
@export var crash_per_damage: float = 0.055   # -5.5% per point of damage taken

## Returns the volatility multiplier for a given current health.
## health == base_health -> volatility_at_full
## health == 1           -> volatility_at_low
func volatility_for(current_health: int) -> float:
	if base_health <= 1:
		return volatility_at_low
	# t = 0 at full health, 1 at 1 HP.
	var t := 1.0 - (float(current_health - 1) / float(base_health - 1))
	t = clampf(t, 0.0, 1.0)
	t = pow(t, volatility_curve)
	return lerpf(volatility_at_full, volatility_at_low, t)
