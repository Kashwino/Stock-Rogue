extends RefCounted
class_name ItemPool

## A few example weapons and upgrades to test the loot system. Later you can
## replace these with saved .tres resources and load them from a folder.

static func weapons() -> Array:
	var out := []

	out.append(_wpn(&"pistol", "Sidearm", Rarity.Tier.STANDARD, WeaponItem.Slot.SMALL,
		1, 0.34, 600.0, 0.02, 1, false, 9))          # infinite-reserve starter, 9-round mag (~3/s)

	out.append(_wpn(&"snub38", "Snub .38", Rarity.Tier.STANDARD, WeaponItem.Slot.SMALL,
		2, 0.50, 550.0, 0.03, 1, true, 6, 150, &"light"))     # slower than the starter, hits harder

	out.append(_wpn(&"tommygun", "Tommy Gun", Rarity.Tier.STANDARD, WeaponItem.Slot.BIG,
		1, 0.20, 600.0, 0.10, 1, true, 25, 625, &"light"))    # loose spray, cheapest BIG option

	out.append(_wpn(&"smg", "Street SMG", Rarity.Tier.RESTRICTED, WeaponItem.Slot.BIG,
		1, 0.16, 650.0, 0.07, 1, true, 30, 900, &"light"))

	out.append(_wpn(&"burstcarbine", "Burst Carbine", Rarity.Tier.RESTRICTED, WeaponItem.Slot.BIG,
		2, 0.26, 700.0, 0.04, 1, true, 18, 450, &"light"))    # hits harder than the SMG, a touch slower

	out.append(_wpn(&"shotgun", "Sawed-Off", Rarity.Tier.CLASSIFIED, WeaponItem.Slot.BIG,
		2, 0.95, 500.0, 0.25, 6, true, 6, 240, &"shell"))

	out.append(_wpn(&"silenced9mm", "Silenced 9mm", Rarity.Tier.CLASSIFIED, WeaponItem.Slot.SMALL,
		2, 0.28, 650.0, 0.015, 1, true, 12, 280, &"light"))   # tight spread, small-slot pick at this tier

	out.append(_wpn(&"rifle", "Marksman Rifle", Rarity.Tier.COVERT, WeaponItem.Slot.BIG,
		3, 0.70, 1000.0, 0.0, 1, true, 8, 320, &"heavy"))

	out.append(_wpn(&"combatshotgun", "Combat Shotgun", Rarity.Tier.COVERT, WeaponItem.Slot.BIG,
		2, 0.75, 550.0, 0.18, 7, true, 8, 280, &"shell"))     # sustained spread alternative to the rifle

	out.append(_wpn(&"handcannon", "Hand Cannon", Rarity.Tier.TOP_SECRET, WeaponItem.Slot.SMALL,
		4, 0.85, 800.0, 0.0, 1, true, 6, 180, &"heavy"))

	out.append(_wpn(&"squadlmg", "Squad LMG", Rarity.Tier.TOP_SECRET, WeaponItem.Slot.BIG,
		2, 0.14, 750.0, 0.06, 1, true, 40, 800, &"heavy"))    # sustained fire vs the Hand Cannon's heavy single hits

	return out

## Same pool, minus the starter pistol -- every player already has it equipped,
## so it's a wasted pull as a case/chest reward. Used anywhere a weapon is
## handed out as loot (case dealer, weapon chests); `weapons()` itself stays
## unchanged since starting-loadout and save/load lookups need the pistol in it.
static func rewardable_weapons() -> Array:
	var out := []
	for w in weapons():
		if w.id != &"pistol":
			out.append(w)
	return out

static func upgrades() -> Array:
	var out := []

	out.append(_upg(&"kevlar", "Kevlar Lining", "+1 max health",
		Rarity.Tier.STANDARD, &"max_health", UpgradeItem.ApplyMode.ADD, 1.0))

	out.append(_upg(&"stims", "Combat Stims", "+15% move speed",
		Rarity.Tier.RESTRICTED, &"move_speed", UpgradeItem.ApplyMode.MULTIPLY, 1.15))

	out.append(_upg(&"trigger", "Filed Trigger", "-20% fire interval (faster)",
		Rarity.Tier.CLASSIFIED, &"fire_rate", UpgradeItem.ApplyMode.MULTIPLY, 0.8))

	out.append(_upg(&"reflexes", "Wired Reflexes", "-30% dodge cooldown",
		Rarity.Tier.COVERT, &"dodge_cooldown", UpgradeItem.ApplyMode.MULTIPLY, 0.7))

	out.append(_upg(&"juggernaut", "Juggernaut Plating", "+3 max health",
		Rarity.Tier.TOP_SECRET, &"max_health", UpgradeItem.ApplyMode.ADD, 3.0))

	return out

static func _wpn(id: StringName, name: String, rarity: int, slot: int,
		dmg: int, rate: float, bspeed: float, spread: float, pellets: int,
		uses_ammo: bool, mag: int = 12, reserve: int = 96,
		ammo_type: StringName = &"light") -> WeaponItem:
	var w := WeaponItem.new()
	w.id = id; w.display_name = name; w.rarity = rarity; w.slot = slot
	w.damage = dmg; w.fire_rate = rate; w.bullet_speed = bspeed
	w.spread = spread; w.pellets = pellets
	w.uses_ammo = uses_ammo; w.mag_size = mag; w.max_reserve = reserve
	w.ammo_type = ammo_type
	return w

static func _upg(id: StringName, name: String, desc: String, rarity: int,
		stat: StringName, mode: int, amount: float) -> UpgradeItem:
	var u := UpgradeItem.new()
	u.id = id; u.display_name = name; u.description = desc; u.rarity = rarity
	u.stat = stat; u.mode = mode; u.amount = amount
	return u
