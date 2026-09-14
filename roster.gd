extends Node
class_name Roster

## Builds the starting roster in code (easy to tune). You can also convert
## each of these into a saved .tres resource via the Godot editor later.

static func build() -> Array[CriminalAsset]:
	var list: Array[CriminalAsset] = []

	# --- STREET (penny stocks) ---
	list.append(_make("pickpocket", "Pickpocket Syndicate",
		CriminalAsset.Tier.STREET, 4.0, 0.05, 0.01, 2.0, 0,
		{ &"turf_war": 0.7 }, {}))
	list.append(_make("corner_racket", "Corner Racket",
		CriminalAsset.Tier.STREET, 6.0, 0.08, 0.015, 3.0, 0,
		{ &"turf_war": 0.5, &"corrupt_official": 1.25 }, {}))
	list.append(_make("chop_shop", "Chop Shop",
		CriminalAsset.Tier.STREET, 8.0, 0.12, 0.0, 4.0, 0,
		{ &"turf_war": 0.8 }, {}))

	# --- BURGLARY (mid-cap) ---
	list.append(_make("cat_burglar", "Cat Burglar Inc.",
		CriminalAsset.Tier.BURGLARY, 15.0, 0.14, 0.02, 8.0, 3,
		{ &"silent_alarm": 0.55 }, {}))
	list.append(_make("safecracker", "Safecracker Union",
		CriminalAsset.Tier.BURGLARY, 18.0, 0.07, 0.025, 9.0, 3,
		{ &"silent_alarm": 0.7 }, { &"bank_job": 0.3 }))
	# Fence rises with everyone's loot volume -> broad positive correlation.
	list.append(_make("fence", "Fence Network",
		CriminalAsset.Tier.BURGLARY, 20.0, 0.06, 0.015, 10.0, 3,
		{}, { &"cat_burglar": 0.25, &"bank_job": 0.25, &"museum": 0.25 }))

	# --- INSTITUTIONAL (large-cap) ---
	list.append(_make("bank_job", "Bank Job Ltd.",
		CriminalAsset.Tier.INSTITUTIONAL, 40.0, 0.18, 0.02, 20.0, 8,
		{ &"silent_alarm": 0.45, &"interpol_crackdown": 0.6 }, {}))
	list.append(_make("casino_skim", "Casino Skim Co.",
		CriminalAsset.Tier.INSTITUTIONAL, 45.0, 0.05, 0.03, 22.0, 8,
		{ &"audit": 0.5 }, {}))
	list.append(_make("transit_ambush", "Armored Transit Ambush",
		CriminalAsset.Tier.INSTITUTIONAL, 35.0, 0.22, 0.0, 18.0, 8,
		{ &"bullion_convoy": 2.2, &"interpol_crackdown": 0.7 }, {}))

	# --- PRESTIGE (blue-chip) ---
	list.append(_make("museum", "Museum Consortium",
		CriminalAsset.Tier.PRESTIGE, 80.0, 0.12, 0.03, 40.0, 15,
		{ &"forgery_scandal": 0.5, &"interpol_crackdown": 0.65 }, {}))
	list.append(_make("diamond_exchange", "Diamond Exchange Heist",
		CriminalAsset.Tier.PRESTIGE, 90.0, 0.15, 0.02, 45.0, 15,
		{ &"interpol_crackdown": 0.6 }, {}))
	list.append(_make("crypto_launder", "Crypto Launder DAO",
		CriminalAsset.Tier.PRESTIGE, 60.0, 0.35, 0.0, 30.0, 15,
		{ &"audit": 0.7 }, {}))

	# --- CATASTROPHE (endgame derivatives) ---
	list.append(_make("reactor_sabotage", "Reactor Sabotage",
		CriminalAsset.Tier.CATASTROPHE, 150.0, 0.4, 0.0, 100.0, 25,
		{ &"meltdown": 0.1, &"corrupt_official": 1.5 }, {}))
	list.append(_make("central_bank_hack", "Central Bank Hack",
		CriminalAsset.Tier.CATASTROPHE, 200.0, 0.3, 0.02, 120.0, 25,
		{ &"interpol_crackdown": 0.4 }, {}))
	# Cartel Cartel: a monopoly whose moves drag the lower tiers.
	list.append(_make("cartel_cartel", "Cartel Cartel",
		CriminalAsset.Tier.CATASTROPHE, 180.0, 0.2, 0.025, 110.0, 25,
		{ &"turf_war": 1.4 }, {}))

	return list


static func _make(id: StringName, name: String, tier: int,
		base: float, vol: float, drift: float, ante: float, prestige: int,
		events: Dictionary, corr: Dictionary) -> CriminalAsset:
	var a := CriminalAsset.new()
	a.id = id
	a.display_name = name
	a.tier = tier
	a.base_price = base
	a.volatility = vol
	a.drift = drift
	a.ante = ante
	a.prestige_required = prestige
	a.event_sensitivity = events
	a.correlations = corr
	return a
