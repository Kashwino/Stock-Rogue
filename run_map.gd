extends RefCounted
class_name RunMap

## The whole-run map. Stages (Town -> City -> World -> Doomsday), each a sequence
## of CHOICE STEPS. A heist step offers 2-4 heist options; the player picks one.
## After each heist comes a skippable shop step (skipping may reveal a secret).
## Quota gate after every 2 heists.

enum Stage { TOWN, CITY, WORLD, DOOMSDAY }
enum StepKind { HEIST_CHOICE, SHOP, QUOTA_GATE, ADVANCE }

const STAGE_NAMES := {
	Stage.TOWN: "Town", Stage.CITY: "City",
	Stage.WORLD: "World", Stage.DOOMSDAY: "Doomsday",
}
const HEISTS_PER_STAGE := {
	Stage.TOWN: 2, Stage.CITY: 2, Stage.WORLD: 2, Stage.DOOMSDAY: 1,
}
const STAGE_RARITY_FLOOR := {
	Stage.TOWN: 0, Stage.CITY: 1, Stage.WORLD: 2, Stage.DOOMSDAY: 4,
}
const STAGE_VENUES := {
	Stage.TOWN:     [&"pickpocket", &"corner_racket", &"chop_shop"],
	Stage.CITY:     [&"cat_burglar", &"safecracker", &"bank_job"],
	Stage.WORLD:    [&"museum", &"diamond_exchange", &"casino_skim"],
	Stage.DOOMSDAY: [&"central_bank_hack", &"reactor_sabotage"],
}

const HEISTS_PER_QUOTA := 2
## Gold demanded at each gate. Growth is steep (2.1x) because player income
## scales explosively with heist rarity — a rarity-4 building pays ~70x what a
## rarity-0 one does, so a flat curve becomes trivial by the third gate.
##   gate 0: 450   gate 1: 945   gate 2: 1984   gate 3: 4167
const BASE_QUOTA := 380.0
const QUOTA_GROWTH := 2.0
const MIN_OPTIONS := 2
const MAX_OPTIONS := 4

## A single step in a stage. HEIST_CHOICE steps hold `options` (Array[MapNode]);
## other kinds are single fixed steps.
class Step:
	var kind: int
	var options: Array = []          # MapNode list for HEIST_CHOICE
	var skippable: bool = false      # shops are skippable
	var chosen_index: int = -1       # which option the player picked
	func _init(k: int) -> void:
		kind = k

# stages[i] = Array[Step]
var stages: Array = []
var stage_order: Array = [Stage.TOWN, Stage.CITY, Stage.WORLD, Stage.DOOMSDAY]

var current_stage: int = 0
var current_step: int = 0
var heists_done: int = 0
var quota_block: int = 0

var _rng := RandomNumberGenerator.new()

func generate(run_seed: int = 0) -> void:
	if run_seed != 0:
		_rng.seed = run_seed
	else:
		_rng.randomize()
	stages.clear()
	for s in stage_order:
		stages.append(_build_stage(s))
	# Independent of the map RNG: existing save seeds keep their original choices.
	for s in stages.size():
		for h in stages[s].size():
			var choice: Step = stages[s][h]
			for i in choice.options.size():
				var tags: Array = [&"heavy_police", &"lockdown", &"insider"]
				choice.options[i].modifier = tags[(absi(hash(str(run_seed) + ":" + str(s) + ":" + str(h))) + i) % 3]
	current_stage = 0
	current_step = 0
	heists_done = 0
	quota_block = 0

func _build_stage(stage: int) -> Array:
	var steps: Array = []
	var heists: int = HEISTS_PER_STAGE[stage]
	var floor_rarity: int = STAGE_RARITY_FLOOR[stage]
	var venues: Array = STAGE_VENUES[stage]

	for h in heists:
		# The hideout (SHOP) now comes BEFORE every heist choice, including the
		# very first of the stage — you always get a chance to gear up and
		# work the market before picking a target, not just between jobs.
		var shop := Step.new(StepKind.SHOP)
		shop.skippable = true
		steps.append(shop)

		# Heist choice step with 2-4 options.
		var step := Step.new(StepKind.HEIST_CHOICE)
		var count := _rng.randi_range(MIN_OPTIONS, MAX_OPTIONS)
		for i in count:
			step.options.append(_make_heist_option(floor_rarity, venues))
		steps.append(step)

		# Quota gate after every N heists (global index).
		if (_global_heist_index(stage, h) + 1) % HEISTS_PER_QUOTA == 0:
			steps.append(Step.new(StepKind.QUOTA_GATE))

	steps.append(Step.new(StepKind.ADVANCE))
	return steps

func _make_heist_option(floor_rarity: int, venues: Array) -> MapNode:
	var node := MapNode.new(MapNode.Type.HEIST)
	node.room_rarity = floor_rarity + _rng.randi_range(0, 2)
	node.venue_id = venues[_rng.randi() % venues.size()]
	# Some options are flagged valuable, and some of those are disguised bosses.
	if _rng.randf() < 0.3:
		node.is_valuable = true
		if _rng.randf() < 0.5:
			node.type = MapNode.Type.MYSTERY
			node.revealed = false
			node.hidden_type = MapNode.Type.BOSS
	return node

func _global_heist_index(stage: int, heist_in_stage: int) -> int:
	var idx := 0
	for i in stage_order.size():
		if stage_order[i] == stage:
			return idx + heist_in_stage
		idx += HEISTS_PER_STAGE[stage_order[i]]
	return idx + heist_in_stage

# --- Progression ---
func current() -> Step:
	if current_stage >= stages.size():
		return null
	var steps: Array = stages[current_stage]
	if current_step >= steps.size():
		return null
	return steps[current_step]

## Look ahead to the NEXT HEIST_CHOICE step's options without advancing.
## Used by the hideout's Black Market so its stock reflects "the case" coming
## up — the player hasn't picked a target yet, so this reflects the whole set
## of options rather than one specific pick.
func peek_next_heist_options() -> Array:
	if current_stage >= stages.size():
		return []
	var steps: Array = stages[current_stage]
	for i in range(current_step, steps.size()):
		var s: Step = steps[i]
		if s.kind == StepKind.HEIST_CHOICE:
			return s.options
	return []

## Pick an option on the current HEIST_CHOICE step. Returns the chosen MapNode.
func choose_option(index: int) -> MapNode:
	var step := current()
	if step == null or step.kind != StepKind.HEIST_CHOICE:
		return null
	if index < 0 or index >= step.options.size():
		return null
	step.chosen_index = index
	var node: MapNode = step.options[index]
	# Reveal a mystery when selected (you commit before knowing? -> reveal on enter).
	if node.type == MapNode.Type.MYSTERY:
		node.reveal()
	if node.is_combat():
		heists_done += 1
	return node

## Advance to the next step. Returns the new current Step (or null at run end).
func advance_step() -> Step:
	current_step += 1
	var steps: Array = stages[current_stage]
	if current_step >= steps.size():
		current_stage += 1
		current_step = 0
		if current_stage >= stages.size():
			return null
	return current()

func current_quota() -> float:
	return BASE_QUOTA * pow(QUOTA_GROWTH, quota_block)

## The empire index (see RunState.empire_index) the mob demands at this gate.
## The index is a run-wide AVERAGE across ~15 venues, so a single heist barely
## moves it: even a flawless one lifts the index ~5 points.
##
## These bars are deliberately ABOVE what heists alone can reach. Two perfect
## heists get you to ~110; the first gate wants 120. The gap is closed by buying
## market operations in the shop — the stock economy is a required system, not
## an optional bonus.
## Same underlying difficulty as ever (market must grow 20% for gate 0, then
## 15% more per gate) expressed on the 1-start scale: 120, 227, 350, 492.
func current_stock_quota() -> float:
	var ratio_bar := 1.20 * pow(1.15, quota_block)
	return 1.0 + (ratio_bar - 1.0) * 595.0

## Combined gate: needs the GOLD payment AND the empire index. Passing either
## alone is not enough — a rich crew with a crashed market still gets cut off.
func check_quota_full(gold: int, stock_index: float) -> bool:
	var met := gold >= current_quota() and stock_index >= current_stock_quota()
	if met:
		quota_block += 1
	return met

func check_quota(gold: int) -> bool:
	var met := gold >= current_quota()
	if met:
		quota_block += 1
	return met

func stage_name() -> String:
	if current_stage >= stage_order.size():
		return "Complete"
	return STAGE_NAMES[stage_order[current_stage]]

func is_complete() -> bool:
	return current_stage >= stages.size()
