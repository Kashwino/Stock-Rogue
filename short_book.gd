extends RefCounted
class_name ShortBook
## A collateralized fictional contract. No borrowing, debt or instant payout.
const MARGIN := 75
const NOTIONAL := 300.0

static func targets(venue: StringName) -> bool:
	return not RunState.short_position.is_empty() and StringName(RunState.short_position.get("venue", "")) == venue

static func open_position(venue: StringName) -> Dictionary:
	if not RunState.short_position.is_empty():
		return {"ok": false, "message": "A short is already open."}
	if RunFlow.pending_heist == null or RunFlow.pending_heist.venue_id != venue:
		return {"ok": false, "message": "Short the venue you are currently robbing."}
	var asset := RunState.market.get_asset(venue)
	if asset == null or not RunEconomy.spend(MARGIN):
		return {"ok": false, "message": "You need 75 gold as collateral."}
	RunState.short_position = {"venue": String(venue), "entry": asset.current_price, "margin": MARGIN}
	return {"ok": true, "heat": 0.0, "message": "SHORT OPEN. Kills and sabotage drive the price down; hits taken drive it up. Escape to collect."}

static func quote() -> Dictionary:
	if RunState.short_position.is_empty() or RunState.market == null:
		return {}
	var p: Dictionary = RunState.short_position
	var entry: float = maxf(float(p["entry"]), 0.01)
	var current: float = RunState.market.price_of(StringName(p["venue"]))
	var profit: int = roundi(NOTIONAL * (entry - current) / entry)
	var payout: int = clampi(MARGIN + profit, 0, MARGIN * 3)
	return {"payout": payout, "profit": payout - MARGIN, "entry": entry, "price": current}

static func settle(escaped: bool) -> Dictionary:
	var result := quote()
	if result.is_empty():
		return {}
	if not escaped:
		result["payout"] = 0
		result["profit"] = -MARGIN
	# Clear before payment so duplicate extraction callbacks cannot pay twice.
	RunState.short_position.clear()
	RunEconomy.add_bonus(int(result["payout"]))
	return result
