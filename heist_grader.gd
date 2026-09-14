extends RefCounted
class_name HeistGrader

## Converts a completed heist's combat stats into a letter grade, a loot-chest
## tier, and a stock-price delta. Pure logic — feed it a stats Dictionary.
##
## Grade weighs: hits taken (heaviest), accuracy, time, kills.

enum Grade { S_PLUS, S, A, B, C, D }

## Loot tiers unlocked by grade. Higher grade = better chest.
enum LootTier { JUNK, STORAGE_UNIT, WEAPON_CASE, VAULT }

## stats Dictionary shape:
##   {
##     "hits_taken": int,
##     "shots_fired": int,
##     "shots_hit": int,
##     "kills": int,
##     "enemies_total": int,      # for kill completeness
##     "time_seconds": float,
##     "par_time": float,         # target time for full marks on speed
##   }
static func grade_heist(stats: Dictionary) -> Dictionary:
	var hits: int = stats.get("hits_taken", 0)
	var fired: int = stats.get("shots_fired", 0)
	var hit: int = stats.get("shots_hit", 0)
	var kills: int = stats.get("kills", 0)
	var total: int = maxi(stats.get("enemies_total", kills), 1)
	var time: float = stats.get("time_seconds", 0.0)
	var par: float = maxf(stats.get("par_time", 60.0), 1.0)

	# --- Component scores, each 0..1 (higher = better) ---

	# Hits: flawless = 1.0, falls off fast. This is the heaviest component.
	var hit_score := 1.0 / (1.0 + float(hits) * 0.6)

	# Accuracy: fraction of shots that connected.
	var acc := 0.0 if fired == 0 else float(hit) / float(fired)

	# Time: at or under par = full marks; linearly worse after.
	var time_score := clampf(par / maxf(time, 0.01), 0.0, 1.0)

	# Kills: completeness of the clear.
	var kill_score := clampf(float(kills) / float(total), 0.0, 1.0)

	# --- Weighted total. Hits dominates. ---
	var score := (hit_score * 0.45
		+ acc * 0.20
		+ time_score * 0.15
		+ kill_score * 0.20)

	var grade := _score_to_grade(score)
	return {
		"grade": grade,
		"grade_name": grade_name(grade),
		"score": score,
		"loot_tier": _grade_to_loot(grade),
		"stock_delta": _grade_to_stock_delta(grade),
		"breakdown": {
			"hit_score": hit_score, "accuracy": acc,
			"time_score": time_score, "kill_score": kill_score,
		},
	}

static func _score_to_grade(s: float) -> Grade:
	if s >= 0.92: return Grade.S_PLUS
	if s >= 0.82: return Grade.S
	if s >= 0.70: return Grade.A
	if s >= 0.55: return Grade.B
	if s >= 0.40: return Grade.C
	return Grade.D

## Grade -> loot chest tier the player can open.
static func _grade_to_loot(g: Grade) -> LootTier:
	match g:
		Grade.S_PLUS, Grade.S: return LootTier.VAULT
		Grade.A:               return LootTier.WEAPON_CASE
		Grade.B, Grade.C:      return LootTier.STORAGE_UNIT
		_:                     return LootTier.JUNK

## Grade -> percentage move applied to the venture's stock (as a multiplier).
static func _grade_to_stock_delta(g: Grade) -> float:
	match g:
		Grade.S_PLUS: return 1.40    # +40%
		Grade.S:      return 1.25
		Grade.A:      return 1.12
		Grade.B:      return 1.02
		Grade.C:      return 0.92
		Grade.D:      return 0.75    # -25%, botched job tanks the stock
	return 1.0

static func grade_name(g: Grade) -> String:
	match g:
		Grade.S_PLUS: return "S+"
		Grade.S:      return "S"
		Grade.A:      return "A"
		Grade.B:      return "B"
		Grade.C:      return "C"
		Grade.D:      return "D"
	return "?"

static func loot_name(t: LootTier) -> String:
	match t:
		LootTier.VAULT:        return "Vault"
		LootTier.WEAPON_CASE:  return "Weapon Case"
		LootTier.STORAGE_UNIT: return "Storage Unit"
		LootTier.JUNK:         return "Junk"
	return "?"
