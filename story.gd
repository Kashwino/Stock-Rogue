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
	return lines
