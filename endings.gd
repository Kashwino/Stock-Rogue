extends RefCounted
class_name Endings
## Every way a run can end, in the order the CASE CLOSED gallery lists them.
##   Early (TAKE HIS DEAL on a stage boss — a partial win: reduced Clout, and
##   it doesn't count toward the Legend):
##     1 THE LANDLORD'S CHAIR · 2 COOKED BOOKS · 3 DIPLOMATIC EXIT
##   Final (the Chairman's verdict), resolved in this order:
##     4 BLACK MONDAY    BURN THE BOARD with your open shorts up $400+ (secret)
##     5 SCORCHED EARTH  BURN THE BOARD otherwise
##     6 THE SYNDICATE   TAKE THE SEAT, all three stage bosses flipped
##     7 THE PURGE       TAKE THE SEAT, all three executed
##     8 THE PUPPETEER   TAKE THE SEAT, all three shaken down
##     9 THE NEW CHAIRMAN  TAKE THE SEAT, mixed verdicts, index >= 840
##    10 A SEAT AT THE TABLE  TAKE THE SEAT, mixed verdicts, a lower index
##    11 RETIRED         WALK AWAY
## Each has a title, 3-5 epilogue cards, a family (its music), a stamp and a
## one-line gallery hint.

const BLACK_MONDAY_PROFIT := 400
## BURN THE BOARD: every listed venue falls to this share of its price.
const BURN_CRASH := 0.55

const ORDER := [&"landlords_chair", &"cooked_books", &"diplomatic_exit", &"black_monday", &"scorched_earth",
	&"syndicate", &"purge", &"puppeteer", &"new_chairman", &"seat_at_table", &"retired"]
const EARLY := [&"landlords_chair", &"cooked_books", &"diplomatic_exit"]
## Ending family -> music theme (tools/gen_music.py).
const THEMES := {"rule": "end_rule", "escape": "end_escape", "collapse": "end_collapse", "retire": "end_retire", "busted": "end_busted"}

const DATA := {
	&"landlords_chair": {
		"title": "THE LANDLORD'S CHAIR", "family": "rule", "stamp": "SMALL-TIME KING", "kicker": "EARLY ENDING  ·  YOU TOOK HIS DEAL",
		"hint": "Some landlords would rather sublet than die.",
		"epilogue": [
			"The Landlord signed it all over on the back of a rent book: every door, every racket, every late fee in Town.",
			"By spring you knew every pawn shop by the smell of its back room. They paid on the first of the month. They paid you.",
			"The Board sent a card. Congratulations on the promotion. Please remain where you are.",
			"You never saw the tower up close. From the Town, on a clear night, you could just make out its lights.",
		],
	},
	&"cooked_books": {
		"title": "COOKED BOOKS", "family": "retire", "stamp": "OFF THE RECORD", "kicker": "EARLY ENDING  ·  YOU TOOK HIS DEAL",
		"hint": "An accountant always has a second set of books — and a vacancy.",
		"epilogue": [
			"The Auditor slid a ledger across the desk. Two columns, one for the Board and one for you. Neither with your name on it.",
			"You audit the crews now. Quietly. The numbers go up the tower and the money goes somewhere nobody checks.",
			"You are rich. You are invisible. On paper you do not exist, which is the only place anyone looks.",
			"Every quarter a car waits outside to take the books upstairs. It has never once been late. Neither have you.",
		],
	},
	&"diplomatic_exit": {
		"title": "DIPLOMATIC EXIT", "family": "escape", "stamp": "DEPARTED", "kicker": "EARLY ENDING  ·  YOU TOOK HER DEAL",
		"hint": "Some doors only open with the right passport.",
		"epilogue": [
			"The Ambassador pressed a passport into your hand. New name, new face in the photo, a stamp from a country with warm water.",
			"The plane left at dawn. By noon the city was a rumor; by evening, a bad dream you told nobody about.",
			"The beach is real. The drinks are cold. The money came through three banks and a consulate and arrived clean.",
			"Last week a postcard came with no return address. One line, in a very neat hand: THE BOARD NEVER FORGETS.",
		],
	},
	&"black_monday": {
		"title": "BLACK MONDAY", "family": "collapse", "stamp": "SHORT THE WORLD", "kicker": "SECRET ENDING  ·  THE BOARD BURNED",
		"hint": "Burn it all down — and make sure you're betting against it.",
		"epilogue": [
			"The Exchange burned for two days. Every name on its walls went down with it: the rackets, the fronts, the crews.",
			"Every name except one. You had shorted the whole underworld, and the whole underworld paid out.",
			"The papers called it Black Monday. The survivors called it worse. Nobody ever connected it to a nobody with a borrowed pistol.",
			"There is no Board anymore. There is a very large number in an account that answers only to you.",
		],
	},
	&"scorched_earth": {
		"title": "SCORCHED EARTH", "family": "collapse", "stamp": "NOTHING LEFT", "kicker": "ENDING  ·  THE BOARD BURNED",
		"hint": "Some trades end with nobody holding anything.",
		"epilogue": [
			"You lit the tower and walked out through the smoke. The ticker kept scrolling as it melted.",
			"By morning every venue was ash: the Board's, the crews', yours. Every dollar you'd earned was listed on those walls.",
			"The city will rebuild. Somebody always does. For now there is just rain on a black lot downtown.",
			"You're free. You're broke. You'd do it again.",
		],
	},
	&"syndicate": {
		"title": "THE SYNDICATE", "family": "rule", "stamp": "THE BOARD IS OURS", "kicker": "ENDING  ·  YOU TOOK THE SEAT",
		"hint": "Turn every one of them — then take the chair together.",
		"epilogue": [
			"The Landlord took the Town, the Auditor took the books, the Ambassador took the world. You took the head of the table.",
			"The Board still meets on the top floor. The chairs are the same. The people in them owe you their lives.",
			"Crews that used to pay quotas now pay dues. It's the same money. It just goes somewhere friendlier.",
			"For the first time in its history, nobody on the Board is trying to kill the Chairman. Mostly.",
		],
	},
	&"purge": {
		"title": "THE PURGE", "family": "rule", "stamp": "RULE BY FEAR", "kicker": "ENDING  ·  YOU TOOK THE SEAT",
		"hint": "Execute every one of them — then sit where they sat.",
		"epilogue": [
			"You put down the Landlord, the Auditor, the Ambassador and the Chairman. Nobody was left to object.",
			"The streets went quiet. Not peaceful. Quiet. The kind of quiet where people stop saying names out loud.",
			"The quotas are paid early now, in cash, in envelopes left on the step without a knock.",
			"You rule an empty city from an empty tower. Every chair at the table is yours, and every one of them is cold.",
		],
	},
	&"puppeteer": {
		"title": "THE PUPPETEER", "family": "rule", "stamp": "STRINGS ATTACHED", "kicker": "ENDING  ·  YOU TOOK THE SEAT",
		"hint": "Take their money and their secrets — every one of them.",
		"epilogue": [
			"You have the Landlord's deeds, the Auditor's ledger and the Ambassador's pouch. You have everything they were.",
			"You never sat in the Chairman's seat. You put a man in it, a nervous one, and you taught him to look at you before he speaks.",
			"The Board votes the way you tell it to. The crews curse the new Chairman. Nobody curses you; nobody knows your name.",
			"Some nights you watch the tower lights from across the river and pull a string, just to see one blink.",
		],
	},
	&"new_chairman": {
		"title": "THE NEW CHAIRMAN", "family": "rule", "stamp": "THE BOARD IS YOURS", "kicker": "ENDING  ·  THE BOARD HAS A NEW SIGNATURE",
		"hint": "Take the seat with the market behind you.",
		"epilogue": [
			"The Chairman went down on his own trading floor. The ticker didn't stop. It just changed names.",
			"By morning every crew in the city had a new quota, and a new signature at the bottom of the page.",
			"The collectors came up to the tower with their hats in their hands.",
			"You set the quotas now. You own the tower. You are the Board.",
		],
	},
	&"seat_at_table": {
		"title": "A SEAT AT THE TABLE", "family": "rule", "stamp": "PROBATIONARY", "kicker": "ENDING  ·  YOU TOOK THE SEAT",
		"hint": "Take the seat without the numbers to hold it.",
		"epilogue": [
			"You sat down in the Chairman's seat. It was still warm.",
			"The Board looked at the index, then at you, and smiled the way sharks smile at a swimmer.",
			"They let you set one quota. Then another. They're patient. They've outlived every chairman they ever had.",
			"You keep a pistol in the desk drawer now. Some mornings you check it's still loaded before you check the market.",
		],
	},
	&"retired": {
		"title": "RETIRED", "family": "retire", "stamp": "CASE CLOSED", "kicker": "ENDING  ·  CASE CLOSED",
		"hint": "Walk away while you still can.",
		"epilogue": [
			"The Chairman went down on his own trading floor, under a ticker that finally stopped.",
			"By morning the Board had a new rumor: somebody walked out with the whole book and never listed it.",
			"You sold your seat before anyone could offer you one. The case file was closed, stamped and filed.",
			"Somewhere warmer, a nobody reads the market pages and doesn't recognise a single name.",
		],
	},
}

static func has(id: StringName) -> bool:
	return DATA.has(id)

static func is_early(id: StringName) -> bool:
	return id in EARLY

## A final ending (4-11): these unlock the Legend.
static func is_final(id: StringName) -> bool:
	return DATA.has(id) and not is_early(id)

static func title(id: StringName) -> String:
	return String(DATA.get(id, {}).get("title", String(id).to_upper()))

static func epilogue(id: StringName) -> Array:
	return DATA.get(id, {}).get("epilogue", [])

static func family(id: StringName) -> String:
	return String(DATA.get(id, {}).get("family", "retire"))

static func theme(id: StringName) -> String:
	return String(THEMES.get(family(id), "end_retire"))

static func number(id: StringName) -> int:
	return ORDER.find(id) + 1

## The run's verdicts for the ending card, from its summary.
static func verdict_lines(summary: Dictionary) -> String:
	var verdicts: Dictionary = summary.get("verdicts", {})
	var names := {"execute": "EXECUTED", "flip": "FLIPPED", "shake": "SHAKEN DOWN", "deal": "TOOK THE DEAL"}
	var parts: Array = []
	for id: StringName in Verdicts.STAGE_BOSSES:
		var v := String(verdicts.get(String(id), ""))
		if v != "":
			parts.append("%s %s" % [Story.boss_name(id).replace("THE ", ""), names.get(v, v.to_upper())])
	var lines: Array = ["VERDICTS", " · ".join(parts) if not parts.is_empty() else "none handed down"]
	var chairman := String(summary.get("chairman_verdict", ""))
	if chairman != "":
		lines.append("THE CHAIRMAN: " + Verdicts.option_name(StringName(chairman)))
	return "\n".join(lines)

## The Chairman's verdict and the run's state -> the final ending.
static func resolve(chairman_verdict: String, index: float, short_profit: int) -> StringName:
	match chairman_verdict:
		"burn":
			return &"black_monday" if short_profit >= BLACK_MONDAY_PROFIT else &"scorched_earth"
		"walk":
			return &"retired"
	if Verdicts.count(Verdicts.FLIP) == 3:
		return &"syndicate"
	if Verdicts.count(Verdicts.EXECUTE) == 3:
		return &"purge"
	if Verdicts.count(Verdicts.SHAKE) == 3:
		return &"puppeteer"
	return &"new_chairman" if index >= Story.NEW_CHAIRMAN_INDEX else &"seat_at_table"
