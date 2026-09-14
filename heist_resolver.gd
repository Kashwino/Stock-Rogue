extends RefCounted
class_name HeistResolver

## Pure resolution logic for the Heist and Chase phases.
## No nodes, no UI — feed it numbers, get an outcome back. Easy to unit test.

enum Outcome { CLEAN, MESSY, BOTCHED }   # heist quality tiers
enum ChaseResult { ESCAPED, ESCAPED_HOT, CAUGHT }

## Prep quality is what the player bought (weapons/crew/gear), 0..~ higher is better.
## Difficulty is the venture's stat. Luck is a random band each attempt.
##
## Returns a Dictionary:
##   {
##     "outcome": Outcome,
##     "loot_multiplier": float,   # applied to the venture's base payout
##     "heat_gained": float,
##     "roll": float,              # the raw score, for display/debug
##   }
static func resolve_heist(prep_quality: float, difficulty: float,
		rng: RandomNumberGenerator) -> Dictionary:
	# Luck band: +/- 0.25 gaussian noise on the prep-vs-difficulty ratio.
	var luck := rng.randfn(0.0, 0.25)
	# Score > 1 means prep outclassed the job; < 1 means underprepared.
	var ratio := (prep_quality + 0.01) / (difficulty + 0.01)
	var score := ratio + luck

	var outcome: Outcome
	var loot_mult: float
	var heat: float

	if score >= 1.3:
		outcome = Outcome.CLEAN
		loot_mult = 1.5          # bonus loot for a flawless job
		heat = 0.5
	elif score >= 0.8:
		outcome = Outcome.MESSY
		loot_mult = 1.0          # got the loot but left a trail
		heat = 1.5
	else:
		outcome = Outcome.BOTCHED
		loot_mult = 0.3          # scraped a fraction, mostly a loss
		heat = 3.0

	return {
		"outcome": outcome,
		"loot_multiplier": loot_mult,
		"heat_gained": heat,
		"roll": score,
	}

## Chase depends on how the heist went (heat carried in) plus prep + luck.
## A CLEAN heist rarely triggers a hot chase; a BOTCHED one usually does.
static func resolve_chase(heist_outcome: Outcome, prep_quality: float,
		current_heat: float, rng: RandomNumberGenerator) -> Dictionary:
	# Base escape chance improves with prep, worsens with accumulated heat.
	var base := 0.6 + prep_quality * 0.05 - current_heat * 0.04
	match heist_outcome:
		Outcome.CLEAN:   base += 0.25
		Outcome.MESSY:   base += 0.0
		Outcome.BOTCHED: base -= 0.25
	base = clampf(base, 0.05, 0.95)

	var roll := rng.randf()
	var result: ChaseResult
	var loot_kept: float
	var heat: float

	if roll < base - 0.2:
		result = ChaseResult.ESCAPED
		loot_kept = 1.0
		heat = 0.0
	elif roll < base:
		result = ChaseResult.ESCAPED_HOT      # got away but they know your face
		loot_kept = 1.0
		heat = 1.0
	else:
		result = ChaseResult.CAUGHT           # lose most of the loot, big heat
		loot_kept = 0.2
		heat = 2.5

	return {
		"result": result,
		"loot_kept": loot_kept,
		"heat_gained": heat,
		"escape_chance": base,
	}

static func outcome_name(o: Outcome) -> String:
	match o:
		Outcome.CLEAN:   return "Clean"
		Outcome.MESSY:   return "Messy"
		Outcome.BOTCHED: return "Botched"
	return "?"

static func chase_name(c: ChaseResult) -> String:
	match c:
		ChaseResult.ESCAPED:     return "Escaped"
		ChaseResult.ESCAPED_HOT: return "Escaped (Hot)"
		ChaseResult.CAUGHT:      return "Caught"
	return "?"
