extends RefCounted
class_name Verdicts
## Boss verdicts. The three stage bosses and the Chairman don't die at 0 HP —
## they KNEEL, and you decide what happens to them (verdict_card.gd):
##   EXECUTE      a unique finisher, the full stock shock, +1 Fear. His crew
##                comes for revenge in the finale (one wave each), and you hit
##                10% harder per execution while they're up.
##   FLIP         he works for you now: a passive for the rest of the run,
##                half the shock, +1 Loyalty. He fights beside you against the
##                Chairman. The Board gets suspicious: every heist of the next
##                stage starts at 1 star.
##   SHAKE DOWN   his money and his books: gold (scaled by the quota block)
##                and his relic, no shock, +1 Greed. His relic sabotages one of
##                the Chairman's phases.
##   TAKE HIS DEAL  end the run right there with his early ending.
## The Chairman's verdict is the run's last choice: TAKE THE SEAT, BURN THE
## BOARD or WALK AWAY (see Story.resolve_ending).
## Verdicts live in RunState.verdicts ({boss id: verdict}) and the run save.

const EXECUTE := &"execute"
const FLIP := &"flip"
const SHAKE := &"shake"
const DEAL := &"deal"
const SEAT := &"seat"
const BURN := &"burn"
const WALK := &"walk"

const STAGE_BOSSES := [&"landlord", &"auditor", &"ambassador"]
const STAGE_OPTIONS := [EXECUTE, FLIP, SHAKE, DEAL]
const CHAIRMAN_OPTIONS := [SEAT, BURN, WALK]

## Shake-down gold: this share of the stage's gold quota (it scales with the
## quota block), plus his relic.
const SHAKE_SHARE := 0.6
## Safehouse Rent: gold at every hideout visit, per quota block.
const RENT_BASE := 40
## TAKE HIS DEAL: the buyout, as a share of the stage's gold quota, and the
## Clout bonus on top of the run's usual award (still less than finishing).
const DEAL_SHARE := 1.5
const DEAL_CLOUT_BONUS := 3
## Every execution adds this much damage while his crew's revenge wave is up.
const REVENGE_DAMAGE := 0.10
const ALLY_REVIVE := 20.0
## Chairman sabotage from the shaken bosses.
const DEED_BOX_HP := 0.85
const MARGIN_HALVED := 0.5

const DATA := {
	&"landlord": {
		"plea": "Okay. Okay! Every door in Town — name your price.",
		"finisher": "EVICTED",
		"flip": ["SAFEHOUSE RENT", "He collects for you now: gold at every hideout visit."],
		"shake": &"deed_box",
		"shake_text": "+1 max HP",
		"sabotage": "the Chairman starts 15% down",
		"deal": &"landlords_chair",
		"deal_text": "Take the Town rackets off his hands. Small-time king.",
		"crew": [Enemy.Kind.SHOTGUNNER, Enemy.Kind.BOUNCER, Enemy.Kind.BRUTE, Enemy.Kind.GRUNT],
		"leave": "I'll tell the tenants you're the new management.",
	},
	&"auditor": {
		"plea": "Wait. I keep the Board's books. Both sets.",
		"finisher": "AUDITED",
		"flip": ["COOKED BOOKS", "He adjusts the ledger: stock crashes from damage are 25% smaller."],
		"shake": &"black_ledger",
		"shake_text": "news one heist early, leverage +1",
		"sabotage": "no Liquidation drain",
		"deal": &"cooked_books",
		"deal_text": "Become the Board's silent auditor. Rich, invisible, owned.",
		"crew": [Enemy.Kind.ENFORCER, Enemy.Kind.SNIPER, Enemy.Kind.RIOT, Enemy.Kind.GRUNT],
		"leave": "I'll amend the records. Quietly.",
	},
	&"ambassador": {
		"plea": "I have a passport with your name on it. Several.",
		"finisher": "IMMUNITY REVOKED",
		"flip": ["DIPLOMATIC COVER", "Her embassy vouches for you: WANTED never goes past 4 stars."],
		"shake": &"diplomatic_pouch",
		"shake_text": "first alarm each heist ignored",
		"sabotage": "Margin Call zones halved",
		"deal": &"diplomatic_exit",
		"deal_text": "A new passport and a beach far away. The Board never forgets.",
		"crew": [Enemy.Kind.ENFORCER, Enemy.Kind.RIOT, Enemy.Kind.GRENADIER, Enemy.Kind.SNIPER],
		"leave": "My government will be in touch. On your side, for now.",
	},
	&"chairman": {
		"plea": "Name it. The seat, the Board, the money. Everything is for sale.",
		"finisher": "DELISTED",
	},
}

## What the card says about each option.
const OPTION_NAMES := {
	EXECUTE: "EXECUTE", FLIP: "FLIP", SHAKE: "SHAKE DOWN", DEAL: "TAKE HIS DEAL",
	SEAT: "TAKE THE SEAT", BURN: "BURN THE BOARD", WALK: "WALK AWAY",
}

static func option_name(v: StringName) -> String:
	return OPTION_NAMES.get(v, String(v).to_upper())

static func his(id: StringName) -> String:
	return "her" if id == &"ambassador" else "his"

static func is_stage_boss(id: StringName) -> bool:
	return id in STAGE_BOSSES

static func options_for(id: StringName) -> Array:
	return CHAIRMAN_OPTIONS if id == &"chairman" else STAGE_OPTIONS

static func plea(id: StringName) -> String:
	return String(DATA.get(id, {}).get("plea", "..."))

static func finisher_name(id: StringName) -> String:
	return String(DATA.get(id, {}).get("finisher", "EXECUTED"))

static func flip_name(id: StringName) -> String:
	return String(DATA.get(id, {}).get("flip", ["", ""])[0])

static func flip_text(id: StringName) -> String:
	return String(DATA.get(id, {}).get("flip", ["", ""])[1])

static func shake_relic(id: StringName) -> StringName:
	return StringName(DATA.get(id, {}).get("shake", &""))

static func deal_ending(id: StringName) -> StringName:
	return StringName(DATA.get(id, {}).get("deal", &""))

static func crew_kinds(id: StringName) -> Array:
	return DATA.get(id, {}).get("crew", [Enemy.Kind.GRUNT])

static func leave_line(id: StringName) -> String:
	return String(DATA.get(id, {}).get("leave", ""))

static func _quota() -> float:
	return RunState.run_map.current_quota() if RunState.run_map else RunMap.BASE_QUOTA

static func shake_gold() -> int:
	return int(round(_quota() * SHAKE_SHARE))

static func rent() -> int:
	var block: int = RunState.run_map.quota_block if RunState.run_map else 0
	return RENT_BASE * (1 + block)

static func deal_payout() -> int:
	return int(round(_quota() * DEAL_SHARE))

## Clout the run would earn if it ended on this boss's deal right now.
static func deal_clout(id: StringName) -> int:
	var stage: int = RunState.run_map.current_stage if RunState.run_map else 0
	var bosses := RunState.bosses_down.size() + (0 if id in RunState.bosses_down else 1)
	return Meta.clout_for(stage + 1, bosses, RunState.empire_index(), false, RunState.best_combo) + DEAL_CLOUT_BONUS

## The card's one-line detail for an option.
static func describe(v: StringName, id: StringName) -> String:
	match v:
		EXECUTE:
			return "A finisher. Full stock shock, %s gun, +1 FEAR. %s crew will want revenge." % [his(id), his(id).capitalize()]
		FLIP:
			return "%s — %s Half shock, +1 LOYALTY. %s fights beside you at the end. The Board gets suspicious: next stage starts at 1 star." % [flip_name(id), flip_text(id), "She" if id == &"ambassador" else "He"]
		SHAKE:
			var r := Relics.make(shake_relic(id))
			var d: Dictionary = DATA.get(id, {})
			return "$%d and %s %s (%s). No shock, +1 GREED. In the finale: %s." % [shake_gold(), his(id), r.display_name.to_upper() if r else "relic", d.get("shake_text", ""), d.get("sabotage", "")]
		DEAL:
			var first := "" if Meta.has_seen_ending(deal_ending(id)) else " (+%d the first time)" % Meta.FIRST_EARLY_CLOUT
			return "%s Ends the run now: $%d, +%d CLOUT%s." % [DATA.get(id, {}).get("deal_text", ""), deal_payout(), deal_clout(id), first]
		SEAT:
			return "Put him down and sit in his chair. The Board is yours — if it lets you keep it."
		BURN:
			return "Torch the Exchange and everything listed on it. Your shorts are the only thing left standing."
		WALK:
			return "Leave him on his knees and walk out with what you have."
	return ""

# ------------------------------------------------------------ run queries --
static func verdict_of(id: StringName) -> StringName:
	return StringName(RunState.verdicts.get(String(id), ""))

static func count(v: StringName) -> int:
	var n := 0
	for id in STAGE_BOSSES:
		if verdict_of(id) == v:
			n += 1
	return n

static func flipped(id: StringName) -> bool:
	return verdict_of(id) == FLIP

static func shaken(id: StringName) -> bool:
	return verdict_of(id) == SHAKE

static func executed(id: StringName) -> bool:
	return verdict_of(id) == EXECUTE

## "EXECUTED · FLIPPED · —" for the endings and the pause screen.
static func summary_line() -> String:
	var parts: Array = []
	for id in STAGE_BOSSES:
		var v := verdict_of(id)
		parts.append("%s %s" % [Story.boss_name(id).replace("THE ", ""), {EXECUTE: "EXECUTED", FLIP: "FLIPPED", SHAKE: "SHAKEN DOWN", DEAL: "DEALT"}.get(v, "—")])
	return "  ·  ".join(parts)
