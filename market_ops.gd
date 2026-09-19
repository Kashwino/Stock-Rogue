extends RefCounted
class_name MarketOps
## Fictional in-game trades; all costs/effects are checked atomically.
const OPERATIONS := {
	"pump": {"name": "PUMP THE TAPE", "cost": 60, "heat": 8.0, "detail": "Selected venue +15%. More value, more attention."},
	"short": {"name": "SHORT THIS HEIST", "cost": 75, "heat": 0.0, "detail": "75 collateral. Fight to crash this venue; escape to collect 0-225. Death loses the stake."},
	"hedge": {"name": "CIRCUIT BREAKER", "cost": 100, "heat": 4.0, "detail": "Halve stock losses from your next 3 damage events."}
}

static func execute(operation: String, target: StringName) -> Dictionary:
	if not OPERATIONS.has(operation) or RunState.market == null:
		return {"ok": false, "message": "The market is unavailable."}
	var asset := RunState.market.get_asset(target)
	if asset == null:
		return {"ok": false, "message": "Select a valid venue."}
	if operation == "hedge" and RunState.hedge_charges > 0:
		return {"ok": false, "message": "Your current circuit breaker is still active."}
	if operation == "short":
		return ShortBook.open_position(target)
	var op: Dictionary = OPERATIONS[operation]
	if not RunEconomy.spend(int(op["cost"])):
		return {"ok": false, "message": "Not enough gold."}
	match operation:
		"pump":
			asset.current_price = maxf(asset.current_price * 1.15, 0.01)
		"hedge":
			RunState.hedge_charges = 3
	var snapshot := {}
	for item: CriminalAsset in RunState.market.assets:
		snapshot[item.id] = item.current_price
	RunState.market.market_ticked.emit(snapshot)
	RunState.market.event_fired.emit(StringName(operation), op["name"])
	return {"ok": true, "heat": op["heat"], "message": op["name"] + " executed. Terminal locked."}
