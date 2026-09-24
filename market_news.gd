extends RefCounted
class_name MarketNews
## The street's news wire between jobs. After every heist one story breaks:
##   a HEADLINE moves a venue (or a whole sector) right away, or
##   a RUMOR says a move is coming — it lands (usually) at the end of the
##   next job, just before open positions settle. That is the opening: read
##   the wire at the case wall, then take a position at the Fence.
## Stories live in RunState.news (latest first) and RunState.rumors.

const MAX_KEPT := 6
const RUMOR_CHANCE := 0.4
const RUMOR_RELIABILITY := 0.75

## [headline template, move]. {N} = the venue's street noun, {T} = ticker.
const UP_STORIES := [
	["COUNCILMAN ON THE PAYROLL — {T} rallies", 0.14],
	["RIVAL CREW ARRESTED — {T} has the street to itself", 0.16],
	["INSURANCE PAYOUT CLEARS — {N} flush with cash", 0.12],
	["NEW SHIPMENT LANDS AT THE {N}", 0.11],
	["COPS LOOK THE OTHER WAY AT THE {N}", 0.13],
]
const DOWN_STORIES := [
	["RAID AT THE {N} — {T} dives", -0.15],
	["INFORMANT TALKS — {T} under the microscope", -0.13],
	["FIRE AT THE {N} — books lost", -0.12],
	["FEDS SUBPOENA THE {N}", -0.14],
	["TURF WAR SPILLS INTO THE {N}", -0.11],
]
const RUMOR_UP := ["WORD IS THE {N} IS ABOUT TO GET A BIG DELIVERY", "WHISPERS OF A BUYOUT AT THE {N}"]
const RUMOR_DOWN := ["WORD IS THE FEDS ARE CIRCLING THE {N}", "SOMEONE AT THE {N} IS TALKING TO THE D.A."]
## Sector stories hit every venue in a stage.
const SECTOR_STORIES := [
	["CITYWIDE CRACKDOWN — every {S} racket slides", -0.08],
	["BOOM TIMES — the {S} is buying", 0.07],
]

## Roll the next story, apply headlines now, queue rumors. Returns the story.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	if RunState.market == null or RunState.market.assets.is_empty():
		return {}
	var story := {}
	var assets: Array = RunState.market.assets
	var asset: CriminalAsset = assets[rng.randi() % assets.size()]
	var noun := Venues.noun(asset.id)
	var tick := Venues.ticker(asset.id)
	if rng.randf() < RUMOR_CHANCE:
		var up := rng.randf() < 0.5
		var pool: Array = RUMOR_UP if up else RUMOR_DOWN
		var text: String = pool[rng.randi() % pool.size()]
		var move := rng.randf_range(0.14, 0.22) * (1.0 if up else -1.0)
		story = {"kind": "rumor", "venue": String(asset.id), "move": move,
			"text": "RUMOR: " + text.replace("{N}", noun).replace("{T}", tick)}
		RunState.rumors.append({"venue": String(asset.id), "move": move,
			"real": rng.randf() < RUMOR_RELIABILITY, "text": story["text"]})
	elif rng.randf() < 0.18:
		var stage: int = RunState.run_map.current_stage if RunState.run_map else 0
		stage = clampi(stage, 0, 3)
		var pick: Array = SECTOR_STORIES[rng.randi() % SECTOR_STORIES.size()]
		var sector: String = ["TOWN", "CITY", "WORLD", "EXCHANGE"][stage]
		var ids: Array = RunMap.STAGE_VENUES.get(stage, [])
		for id in ids:
			_move(StringName(id), float(pick[1]))
		story = {"kind": "sector", "venue": "", "move": float(pick[1]),
			"text": String(pick[0]).replace("{S}", sector)}
	else:
		var up := rng.randf() < 0.5
		var pool: Array = UP_STORIES if up else DOWN_STORIES
		var pick: Array = pool[rng.randi() % pool.size()]
		var move: float = float(pick[1]) * rng.randf_range(0.85, 1.2)
		_move(asset.id, move)
		story = {"kind": "headline", "venue": String(asset.id), "move": move,
			"text": String(pick[0]).replace("{N}", noun).replace("{T}", tick)}
	_keep(story)
	return story

## End of a job: queued rumors come true (or don't) before positions settle.
## Returns the stories that resolved.
static func resolve_rumors() -> Array:
	var out: Array = []
	for r: Dictionary in RunState.rumors:
		var real: bool = r.get("real", true)
		var venue := StringName(r.get("venue", ""))
		if real:
			_move(venue, float(r.get("move", 0.0)))
		var text := "%s %s" % [Venues.ticker(venue), ("%+.0f%% — the rumor was true" % (float(r["move"]) * 100.0)) if real else "— the rumor was nothing"]
		out.append({"kind": "resolved", "venue": String(venue), "move": float(r["move"]) if real else 0.0, "text": text})
	RunState.rumors.clear()
	for story: Dictionary in out:
		_keep(story)
	return out

static func _move(id: StringName, pct: float) -> void:
	var a: CriminalAsset = RunState.market.get_asset(id) if RunState.market else null
	if a:
		a.current_price = maxf(a.current_price * (1.0 + pct), 0.01)

static func _keep(story: Dictionary) -> void:
	if story.is_empty():
		return
	RunState.news.push_front(story)
	while RunState.news.size() > MAX_KEPT:
		RunState.news.pop_back()

## The most recent story's line with its move, for the wire and the wall.
static func line(story: Dictionary) -> String:
	var move := float(story.get("move", 0.0))
	if story.get("kind", "") == "rumor" or is_zero_approx(move):
		return String(story.get("text", ""))
	var venue := StringName(story.get("venue", ""))
	var tag := Venues.ticker(venue) if venue != &"" else "SECTOR"
	return "%s  (%s %+.0f%%)" % [story.get("text", ""), tag, move * 100.0]
