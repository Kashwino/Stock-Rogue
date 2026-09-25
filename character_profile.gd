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

## --- Specialist traits (defaults are the Operator: no changes) ---
## Footsteps, sprinting and dodges make no noise.
@export var silent := false
## Gunshot carry (1.0 = normal; the Ghost is 0.6).
@export var gunshot_noise := 1.0
## Camera detection speed (1.0 = normal; the Ghost is 0.5).
@export var camera_spot_rate := 1.0
## Weapon damage (the Wolf hits 25% harder; fractions round by chance).
@export var damage_mult := 1.0
## Taking damage emits a noise pulse that draws guards (the Wolf).
@export var noisy_when_hit := false
## Every player-driven stock move scaled, both ways (the Broker x1.5).
@export var swing_mult := 1.0
## Fence positions.
@export var position_slots := 2
@export var position_leverage := 2.0
## Fence prices off (the Broker 25%).
@export var fence_discount := 0.0
## No healing is sold or found (the Legend).
@export var no_healing := false
## Gold and stock gains doubled (the Legend).
@export var gain_mult := 1.0
## Starting weapon: a fixed id, or a random one of at least this rarity.
## THE RALLY: extra combo window (s), extra points per stealth takedown,
## cash-out gold and stock multiplier, tier multiplier scale.
@export var combo_window_bonus := 0.0
@export var takedown_combo_bonus := 0
@export var combo_cash_mult := 1.0
@export var combo_tier_mult := 1.0
@export var start_weapon: StringName = &""
@export var start_weapon_min_rarity := -1

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
