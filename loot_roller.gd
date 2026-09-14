extends RefCounted
class_name LootRoller

## Turns a chest tier into rarity odds, then rolls N items from a pool.
## Better tier = better odds of high-rarity items. Used for both the in-heist
## Weapon/Upgrade chests and the end-of-heist graded container.

## Chest tiers, worst -> best. The end-of-heist container names map here:
##   JUNKPILE(D) TRUNK(C) TRUCK(B) STORAGE(A) AIRDROP(S)
enum ChestTier { JUNKPILE, TRUNK, TRUCK, STORAGE, AIRDROP }

const TIER_NAMES := {
	ChestTier.JUNKPILE: "Junkpile",
	ChestTier.TRUNK:    "Trunk",
	ChestTier.TRUCK:    "Truck",
	ChestTier.STORAGE:  "Storage Unit",
	ChestTier.AIRDROP:  "Airdrop",
}

# Rarity weights per chest tier: [Standard, Restricted, Classified, Covert, TopSecret].
# Higher tiers shift weight toward rarer items.
const WEIGHTS := {
	ChestTier.JUNKPILE: [70, 22, 6, 2, 0],
	ChestTier.TRUNK:    [50, 30, 14, 5, 1],
	ChestTier.TRUCK:    [32, 33, 22, 10, 3],
	ChestTier.STORAGE:  [18, 30, 28, 16, 8],
	ChestTier.AIRDROP:  [8, 22, 30, 25, 15],
}

## Map a heist grade name -> the container tier it awards.
static func tier_from_grade(grade_name: String) -> ChestTier:
	match grade_name:
		"S+", "S": return ChestTier.AIRDROP
		"A":       return ChestTier.STORAGE
		"B":       return ChestTier.TRUCK
		"C":       return ChestTier.TRUNK
		_:         return ChestTier.JUNKPILE

## Roll a single rarity for the given tier.
static func roll_rarity(tier: ChestTier, rng: RandomNumberGenerator) -> int:
	var weights: Array = WEIGHTS[tier]
	var total := 0
	for w in weights:
		total += w
	var pick := rng.randi_range(1, total)
	var acc := 0
	for i in weights.size():
		acc += weights[i]
		if pick <= acc:
			return i
	return 0

## Roll `count` items from `pool`, biased to the tier's rarity odds.
## `pool` is an Array of WeaponItem or UpgradeItem resources (mixed OK).
## Picks items whose rarity matches the rolled rarity when possible; falls back
## to nearest available. Avoids duplicate ids within the same reveal.
static func roll_items(pool: Array, tier: ChestTier, count: int,
		rng: RandomNumberGenerator) -> Array:
	var chosen := []
	var used_ids := {}
	var attempts := 0
	while chosen.size() < count and attempts < 100:
		attempts += 1
		var target := roll_rarity(tier, rng)
		var item = _pick_by_rarity(pool, target, used_ids, rng)
		if item != null:
			chosen.append(item)
			used_ids[item.id] = true
	# If pool too small to fill count, return what we have.
	return chosen

static func _pick_by_rarity(pool: Array, target_rarity: int,
		used_ids: Dictionary, rng: RandomNumberGenerator):
	# Gather candidates at the exact rarity first, then widen if none.
	for search_widen in range(0, 5):
		var candidates := []
		for item in pool:
			if used_ids.has(item.id):
				continue
			if abs(int(item.rarity) - target_rarity) <= search_widen:
				candidates.append(item)
		if candidates.size() > 0:
			return candidates[rng.randi() % candidates.size()]
	return null

static func tier_name(t: ChestTier) -> String:
	return TIER_NAMES.get(t, "?")
