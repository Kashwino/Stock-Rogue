extends RefCounted
class_name Positions
## Long and short positions opened at the Fence. Stake gold on any venue;
## every open position settles automatically at the end of your next job:
##     payout = stake × (1 + leverage × Δ)      Δ = price move since opening,
##                                              inverted for a short
## floored at zero. Base leverage 2, two positions at a time. They live in
## RunState.positions and are saved with the run.
##
## The trade-off is deliberate: a HIT crashes its venue (a short pays), but
## every crash drags the Board index — gold for the quota versus the index.

const BASE_LEVERAGE := 2.0
const BASE_SLOTS := 2
const STAKES := [50, 100, 250]

static func slots() -> int:
	var n := BASE_SLOTS
	if RunState.character_profile and RunState.character_profile.id == &"broker":
		n = 3
	if RunState.has_perk(&"market_maker"):
		n += 1
	return n

static func leverage() -> float:
	var lev := BASE_LEVERAGE
	if RunState.character_profile and RunState.character_profile.id == &"broker":
		lev = 3.0
	if RunState.has_perk(&"market_maker"):
		lev += 0.5
	return lev

## Stake sizes scale with the quota block so late positions still matter.
static func stake_options() -> Array:
	var qb: int = RunState.run_map.quota_block if RunState.run_map else 0
	var out: Array = []
	for s: int in STAKES:
		out.append(int(s * pow(1.6, qb)))
	return out

static func open_count() -> int:
	return RunState.positions.size()

static func can_open() -> bool:
	return open_count() < slots()

static func open(venue: StringName, side: String, stake: int) -> Dictionary:
	if RunState.market == null:
		return {"ok": false, "message": "The market is closed."}
	var asset := RunState.market.get_asset(venue)
	if asset == null:
		return {"ok": false, "message": "Pick a venue."}
	if side != "long" and side != "short":
		return {"ok": false, "message": "Long or short?"}
	if not can_open():
		return {"ok": false, "message": "All %d position slots are taken." % slots()}
	if stake <= 0 or not RunEconomy.spend(stake):
		return {"ok": false, "message": "Not enough gold for that stake."}
	RunState.positions.append({
		"venue": String(venue), "side": side, "stake": stake,
		"entry": asset.current_price, "leverage": leverage(),
	})
	return {"ok": true, "message": "%s %s opened: $%d at %.2f." % [side.to_upper(), Venues.ticker(venue), stake, asset.current_price]}

## Price move since the position opened, from the position's point of view
## (a short gains when the price falls).
static func move_of(p: Dictionary) -> float:
	if RunState.market == null:
		return 0.0
	var entry: float = maxf(float(p.get("entry", 1.0)), 0.01)
	var now := RunState.market.price_of(StringName(p.get("venue", "")))
	var d := (now - entry) / entry
	return -d if p.get("side", "long") == "short" else d

static func value_of(p: Dictionary) -> int:
	var stake: int = int(p.get("stake", 0))
	var lev: float = float(p.get("leverage", BASE_LEVERAGE))
	return maxi(0, roundi(stake * (1.0 + lev * move_of(p))))

## Every open position with its live value, for the HUD, map and Fence.
static func quotes() -> Array:
	var out: Array = []
	for p: Dictionary in RunState.positions:
		var q := p.duplicate()
		q["move"] = move_of(p)
		q["value"] = value_of(p)
		q["profit"] = int(q["value"]) - int(p.get("stake", 0))
		out.append(q)
	return out

## Close everything at today's prices and pay out. Called at the end of a job.
static func settle_all() -> Array:
	var settled := quotes()
	RunState.positions.clear()
	var total := 0
	for q: Dictionary in settled:
		total += int(q["value"])
	if total > 0:
		RunEconomy.add_bonus(total)
	return settled

## One line per position: "SHORT BANK $100 → $128 (+28)".
static func describe(q: Dictionary) -> String:
	return "%s %s  $%d → $%d (%+d)" % [String(q.get("side", "")).to_upper(), Venues.ticker(StringName(q.get("venue", ""))),
		int(q.get("stake", 0)), int(q.get("value", 0)), int(q.get("profit", 0))]

## Venue id -> side, for tickers.
static func sides() -> Dictionary:
	var out := {}
	for p: Dictionary in RunState.positions:
		out[StringName(p.get("venue", ""))] = p.get("side", "long")
	return out
