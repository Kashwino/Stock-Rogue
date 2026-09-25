extends RefCounted
class_name Relics
## The relic catalog (25: 20 + the five combo relics). Sold at the Black Market, found in upgrade chests,
## dropped by bosses. See RelicItem and RelicHooks.

## id: [name, description, rarity, stacks, mark]
const DATA := {
	&"blood_ledger": ["Blood Ledger", "Every kill puts a round back in the magazine.", Rarity.Tier.RESTRICTED, false, "BL"],
	&"hair_trigger": ["Hair Trigger", "The first shot after a reload deals double damage.", Rarity.Tier.CLASSIFIED, false, "HT"],
	&"silent_partner": ["Silent Partner", "Your gunshots carry 40% less far.", Rarity.Tier.RESTRICTED, false, "SP"],
	&"golden_parachute": ["Golden Parachute", "Once per run a lethal hit leaves you at 1 HP. The venue crashes 20%.", Rarity.Tier.TOP_SECRET, false, "GP"],
	&"adrenaline_futures": ["Adrenaline Futures", "At 1 HP: fire 40% faster and move 15% faster.", Rarity.Tier.CLASSIFIED, false, "AF"],
	&"hedge_fund": ["Hedge Fund", "Stock crashes from damage you take are 30% smaller.", Rarity.Tier.RESTRICTED, false, "HF"],
	&"pump_and_dump": ["Pump & Dump", "Boss and lieutenant kills move the venue 15% more.", Rarity.Tier.COVERT, false, "PD"],
	&"insider_wire": ["Insider Wire", "You can see every guard's vision cone.", Rarity.Tier.COVERT, false, "IW"],
	&"laundered_cash": ["Laundered Cash", "Loot +15%. Stacks.", Rarity.Tier.STANDARD, true, "LC"],
	&"fences_discount": ["Fence's Discount", "Hideout prices -15%.", Rarity.Tier.CLASSIFIED, false, "FD"],
	&"lucky_casing": ["Lucky Casing", "20% of your shots cost no ammo.", Rarity.Tier.RESTRICTED, false, "LU"],
	&"stopping_power": ["Stopping Power", "Bigger knockback, and hit guards lose their next shot.", Rarity.Tier.CLASSIFIED, false, "ST"],
	&"cold_feet": ["Cold Feet", "+25% speed after a second without firing.", Rarity.Tier.STANDARD, false, "CF"],
	&"getaway_driver": ["Getaway Driver", "The car pulls out after 2 s instead of 4.", Rarity.Tier.RESTRICTED, false, "GD"],
	&"back_door_man": ["Back Door Man", "Fire exits stay usable up to heat 20.", Rarity.Tier.CLASSIFIED, false, "BD"],
	&"riot_insurance": ["Riot Insurance", "Police vans come 25% less often.", Rarity.Tier.COVERT, false, "RI"],
	&"market_maker": ["Market Maker", "+1 Fence position slot and +0.5 leverage.", Rarity.Tier.COVERT, false, "MM"],
	&"second_wind": ["Second Wind", "The first room you clear each job heals 1.", Rarity.Tier.RESTRICTED, false, "SW"],
	&"tracer_rounds": ["Tracer Rounds", "Your rounds pierce one extra guard.", Rarity.Tier.CLASSIFIED, false, "TR"],
	&"paper_trail": ["Paper Trail", "An A grade or better lifts every venue 2%.", Rarity.Tier.TOP_SECRET, false, "PT"],
	# THE RALLY (combo) relics.
	&"momentum_trader": ["Momentum Trader", "Your combo window lasts 1 s longer.", Rarity.Tier.RESTRICTED, false, "MT"],
	&"dead_cat_bounce": ["Dead Cat Bounce", "The first hit you take during a combo doesn't break it (once per heist).", Rarity.Tier.CLASSIFIED, false, "DC"],
	&"compound_interest": ["Compound Interest", "Combo tiers come 20% sooner.", Rarity.Tier.COVERT, false, "CI"],
	&"blood_money": ["Blood Money", "Every combo tier-up drops a little cash.", Rarity.Tier.RESTRICTED, false, "BM"],
	&"short_fuse": ["Short Fuse", "Explosive props hit 50% harder; explosive kills are worth +1 combo point.", Rarity.Tier.CLASSIFIED, false, "SF"],
}
## Boss relics: only a SHAKE DOWN verdict hands these out; they never enter
## the pools, the shop or chests.
const BOSS_DATA := {
	&"deed_box": ["Deed Box", "+1 max HP. (The Landlord's deeds: the Chairman starts 15% weaker.)", Rarity.Tier.TOP_SECRET, false, "DB"],
	&"black_ledger": ["Black Ledger", "Read the wire one heist early; position leverage +1. (The Chairman's Liquidation can't touch your gold.)", Rarity.Tier.TOP_SECRET, false, "LG"],
	&"diplomatic_pouch": ["Diplomatic Pouch", "The first alarm each heist is ignored. (The Chairman's Margin Call zones are halved.)", Rarity.Tier.TOP_SECRET, false, "DP"],
}
const PRICES := [180, 260, 360, 480, 650]

static func exists(id: StringName) -> bool:
	return DATA.has(id) or BOSS_DATA.has(id)

static func make(id: StringName) -> RelicItem:
	if not exists(id):
		return null
	var d: Array = DATA[id] if DATA.has(id) else BOSS_DATA[id]
	var r := RelicItem.new()
	r.id = id
	r.display_name = d[0]
	r.description = d[1]
	r.rarity = d[2]
	r.stacks = d[3]
	r.mark = d[4]
	return r

static func all() -> Array:
	var out: Array = []
	for id in DATA:
		out.append(make(id))
	return out

## Relics the run can still gain (stacking ones never run out).
static func available() -> Array:
	var out: Array = []
	for id in DATA:
		if DATA[id][3] or not RunState.has_relic(id):
			out.append(make(id))
	return out

static func price_of(r: RelicItem, scale: float = 1.0) -> int:
	return int(PRICES[clampi(int(r.rarity), 0, PRICES.size() - 1)] * scale)

## A random relic weighted toward `min_tier` and above (bosses give good ones).
static func roll(rng: RandomNumberGenerator, min_tier: int = 0) -> RelicItem:
	var pool := available().filter(func(r): return int(r.rarity) >= min_tier)
	if pool.is_empty():
		pool = available()
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]
