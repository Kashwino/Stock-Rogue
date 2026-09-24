extends RefCounted
class_name Venues
## Presentation data for every listed venue: ticker symbol, the name on the
## neon sign over the front door, and a short description for case files.

const DATA := {
	&"pickpocket": ["PKPT", "LUCKY PAWN & LOAN", "Pawnbroker fencing lifted wallets."],
	&"corner_racket": ["CRNR", "ROSA'S CORNER DELI", "Numbers racket behind the deli counter."],
	&"chop_shop": ["CHOP", "EDDIE'S AUTO BODY", "Stolen cars in, parts out the back."],
	&"cat_burglar": ["CATB", "HALCYON RESIDENCES", "Penthouse fence for second-storey work."],
	&"safecracker": ["SAFE", "UNION SAFE DEPOSIT", "Boxes nobody is supposed to open."],
	&"fence": ["FNCE", "MARLOWE IMPORTS", "Everything stolen passes through here."],
	&"bank_job": ["BANK", "FIRST FEDERAL", "A bank with two sets of books."],
	&"casino_skim": ["CSNO", "THE GOLDEN ROULETTE", "The house always wins. So does the skim."],
	&"transit_ambush": ["TRNS", "ARMORED TRANSIT DEPOT", "Where the money trucks sleep."],
	&"museum": ["MUSE", "MUSEUM OF FINE ART", "Forgeries on the walls, originals below."],
	&"diamond_exchange": ["DMND", "DIAMOND EXCHANGE", "Conflict stones, clean paperwork."],
	&"crypto_launder": ["CRYP", "NODE TOWER", "Servers washing dirty money all night."],
	&"reactor_sabotage": ["RCTR", "HELIOS POWER", "The grid the whole city runs on."],
	&"central_bank_hack": ["CBNK", "CENTRAL RESERVE", "Where the money is printed."],
	&"cartel_cartel": ["BORD", "THE EXCHANGE", "The Board's own tower. The Chairman's seat."],
}

## What the papers call the place.
const NOUNS := {
	&"pickpocket": "PAWN SHOP", &"corner_racket": "DELI", &"chop_shop": "CHOP SHOP",
	&"cat_burglar": "PENTHOUSE", &"safecracker": "VAULT", &"fence": "WAREHOUSE",
	&"bank_job": "BANK", &"casino_skim": "CASINO", &"transit_ambush": "DEPOT",
	&"museum": "MUSEUM", &"diamond_exchange": "EMBASSY", &"crypto_launder": "SERVER FARM",
	&"reactor_sabotage": "POWER PLANT", &"central_bank_hack": "RESERVE", &"cartel_cartel": "EXCHANGE TOWER",
}

static func noun(id: StringName) -> String:
	return NOUNS.get(id, "WAREHOUSE")

## Signature buildings for the stage bosses override the venue's sign.
const BOSS_SIGNS := {
	&"landlord": "TENEMENT ROW",
	&"auditor": "MARLOWE EXCHANGE",
	&"ambassador": "EMBASSY OF VALDORIA",
	&"chairman": "THE EXCHANGE",
}

static func ticker(id: StringName) -> String:
	return DATA[id][0] if DATA.has(id) else String(id).substr(0, 4).to_upper()

static func sign_name(id: StringName, boss: StringName = &"") -> String:
	if boss != &"" and BOSS_SIGNS.has(boss):
		return BOSS_SIGNS[boss]
	return DATA[id][1] if DATA.has(id) else String(id).replace("_", " ").to_upper()

static func blurb(id: StringName) -> String:
	return DATA[id][2] if DATA.has(id) else ""

static func display_name(id: StringName) -> String:
	if RunState.market:
		var a := RunState.market.get_asset(id)
		if a:
			return a.display_name
	return String(id).replace("_", " ").capitalize()
