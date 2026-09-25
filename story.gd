extends RefCounted
class_name Story
## All narrative text in one place: the Board, its collectors, the stage
## bosses, stage teasers. Phase 10 builds the prologue and endings on top.

const BOSSES := {
	&"landlord": ["THE LANDLORD", "Owns every door in Town. Collects rent with a shotgun."],
	&"auditor": ["THE AUDITOR", "The Board's accountant. Every hit you take goes in his ledger."],
	&"ambassador": ["THE AMBASSADOR", "Diplomatic immunity, a gold revolver and loyal bodyguards."],
	&"chairman": ["THE CHAIRMAN", "Sets the quotas. Owns the tower. Owns the Board."],
}

const STAGE_TEASERS := {
	0: "Town. Pawn shops, chop shops and back-room rackets. The Landlord collects rent on every door.",
	1: "The City. Banks, offices and two sets of books. The Auditor is already counting your mistakes.",
	2: "The World. Casinos, embassies and diamonds with paperwork. The Ambassador cannot be touched — officially.",
	3: "Doomsday. The Exchange tower, where the Board lists every crew in the city. The Chairman is waiting upstairs.",
}

## Credits: the name on the case file.
const CREDITS_NAME := "KASHWINO"

## The prologue: typewriter narration over the rainy skyline, full on a
## case file's first run.
const PROLOGUE := [
	"This city's underworld runs its own exchange. They call it the Board.",
	"Every crew, every racket, every front is listed. Pull a clean job and your price goes up. Bleed, and it goes down.",
	"The Chairman sets the quotas. His collectors enforce them. Miss one and you are delisted. Permanently.",
	"You are a nobody with a borrowed pistol and a blank case file. Climb from the Town rackets to the Exchange tower. Take the Chairman's seat — or become a headline.",
]
const PROLOGUE_SHORT := "Case file %d. Same city. Same Board. Same Chairman. A different nobody with a borrowed pistol."

## Stage intro cards: [title, narration, boss teaser].
const STAGE_INTROS := {
	0: ["TOWN", "Pawn shops, chop shops and back-room rackets. Everybody on this block pays rent.", "THE LANDLORD owns every door in Town and collects with a shotgun. Make your quota, then knock on his."],
	1: ["THE CITY", "Banks, offices and two sets of books. Up here the Board keeps receipts.", "THE AUDITOR is already counting your mistakes. Every hit you take goes in his ledger."],
	2: ["THE WORLD", "Casinos, embassies, diamonds with paperwork. The money here has passports.", "THE AMBASSADOR cannot be touched — officially. Her bodyguards make sure of the rest."],
	3: ["DOOMSDAY", "The Exchange tower. Every crew in the city is listed on its walls. Yours included.", "THE CHAIRMAN is waiting on the trading floor. He set every quota you ever paid."],
}

## Winning endings. Index at or above NEW_CHAIRMAN_INDEX at the final
## extraction takes the seat; otherwise you retire.
const NEW_CHAIRMAN_INDEX := 840.0
const EPILOGUE_RETIRED := [
	"The Chairman went down on his own trading floor, under a ticker that finally stopped.",
	"By morning the Board had a new rumor: somebody walked out with the whole book and never listed it.",
	"You sold your seat before anyone could offer you one. The case file was closed, stamped and filed.",
	"Somewhere warmer, a nobody reads the market pages and doesn't recognise a single name.",
]
const EPILOGUE_CHAIRMAN := [
	"The Chairman went down on his own trading floor. The ticker didn't stop. It just changed names.",
	"By morning every crew in the city had a new quota, and a new signature at the bottom of the page.",
	"The collectors came up to the tower with their hats in their hands.",
	"You set the quotas now. You own the tower. You are the Board.",
]

static func ending_id(index: float) -> StringName:
	return &"new_chairman" if index >= NEW_CHAIRMAN_INDEX else &"retired"

const COLLECTOR_OPEN_OK := [
	"Sit. Let's see if you're worth the paper.",
	"The Board likes a crew that pays on time. Show me.",
	"You look like money. Let's make sure.",
]
const COLLECTOR_OPEN_SHORT := [
	"You're light. I can smell it from here.",
	"Open the books. Slowly. I hate surprises.",
	"The Chairman asked about you. Don't make me lie to him.",
]
const COLLECTOR_PASS := [
	"Paid in full. The Board remembers who pays.",
	"Good. Keep this up and you'll get a bigger chair.",
	"Clean books. Get out of my sight — and get richer.",
]
const COLLECTOR_FAIL := [
	"Short. The Board doesn't do payment plans.",
	"You're delisted. Somebody will come for the furniture.",
	"That's the last number you'll ever miss.",
]

## Lieutenants: the names on the Board's payroll who run an ordinary job.
const LIEUTENANT_FIRST := ["Knuckles", "Two-Tone", "Sal", "Mickey", "Vinnie", "Lefty", "Dutch", "Rocco",
	"Bruno", "Frankie", "Nails", "Tommy", "Eddie", "Big Lou", "Silk", "Duchess", "Mags", "Ruby"]
const LIEUTENANT_LAST := ["Moretti", "Kowalski", "Doyle", "Vance", "Castellano", "Byrne", "Novak",
	"Marchetti", "Kane", "Rourke", "Lazlo", "Petrov", "Santoro", "Quill"]

static func lieutenant_name(rng: RandomNumberGenerator) -> String:
	var first: String = LIEUTENANT_FIRST[rng.randi() % LIEUTENANT_FIRST.size()]
	var last: String = LIEUTENANT_LAST[rng.randi() % LIEUTENANT_LAST.size()]
	return ("\"%s\" %s" % [first, last]).to_upper()

static func _pick(pool: Array) -> String:
	return pool[randi() % pool.size()]

static func boss_name(id: StringName) -> String:
	return BOSSES[id][0] if BOSSES.has(id) else String(id).to_upper()

static func boss_title(id: StringName) -> String:
	return "%s — %s" % [boss_name(id), BOSSES[id][1]] if BOSSES.has(id) else boss_name(id)

static func stage_teaser(stage: int) -> String:
	return STAGE_TEASERS.get(stage, "")

static func collector_opening(passing: bool) -> String:
	return _pick(COLLECTOR_OPEN_OK if passing else COLLECTOR_OPEN_SHORT)

static func collector_verdict(passing: bool) -> String:
	return _pick(COLLECTOR_PASS if passing else COLLECTOR_FAIL)

const VENDOR_BASE := {
	&"weapons": [
		"Cases come sealed. No refunds, no questions.",
		"The grade goes up every time you survive the collector.",
		"That pistol? Pea shooter. Crack a case.",
		"I don't sell guns. I sell second chances.",
	],
	&"stocks": [
		"Three moves today. Pick one, or pay me to look again.",
		"The index is a mood. Moods can be bought.",
		"Pump it, short it — just don't bleed on my carpet.",
		"Everybody on the Board is lying. I just lie cheaper.",
	],
	&"blackmarket": [
		"Gear for the next job. I hear things about it.",
		"Kevlar's cheaper than a funeral.",
		"I know what's waiting in that building. You don't. Yet.",
		"Cash only. Obviously.",
	],
}

## Vendor chatter that reacts to how the run is going.
static func vendor_lines(kind: StringName) -> Array:
	var lines: Array = VENDOR_BASE.get(kind, ["..."]).duplicate()
	if RunState.run_map == null:
		return lines
	var index := RunState.empire_index()
	var need := RunState.run_map.current_stock_quota()
	var gold := RunEconomy.gold
	var gold_need := RunState.run_map.current_quota()
	if index < need * 0.5:
		lines.append("Your index is in the gutter. The collector reads the tape too.")
		if kind == &"stocks":
			lines.append("You need the index up. I can make a market move. For a fee.")
	elif index >= need:
		lines.append("Index looks healthy. The Board likes a winner.")
	if gold >= gold_need * 0.8 and gold < gold_need:
		lines.append("You're close to the collector's number. One more good job.")
	if RunState.last_grade in ["S+", "S"]:
		lines.append("Word travels. That last job was clean.")
	elif RunState.last_grade == "D":
		lines.append("Heard the last one went sideways. Heard it on the news.")
	if not RunState.bosses_down.is_empty():
		var last: StringName = StringName(RunState.bosses_down.back())
		lines.append("You put down %s? The whole Board is talking." % boss_name(last).capitalize())
	if RunState.health <= 1:
		lines.append("You're bleeding on my floor. Patch yourself up.")
	if RunState.run_map.next_heist_is_boss():
		lines.append("The big one's next. Don't walk in light.")
	if not RunState.positions.is_empty() and kind == &"stocks":
		lines.append("You're holding paper on %d venue%s. I'd watch the wire." % [RunState.positions.size(), "" if RunState.positions.size() == 1 else "s"])
	if not RunState.rumors.is_empty() and kind == &"blackmarket":
		lines.append("That rumor on the wire? Half of them are true. Guess which half.")
	if RunState.relics.size() >= 3:
		lines.append("You're carrying a museum in that coat. The Board notices trinkets.")
	match RunState.run_map.current_stage:
		2:
			lines.append("Casinos and consulates now. Pay the doorman in chips, not bullets.")
		3:
			lines.append("The tower's lit up tonight. The Chairman's expecting company.")
	return lines
