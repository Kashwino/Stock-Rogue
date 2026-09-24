extends RefCounted
class_name RunMap

## The whole-run route. Four stages (Town -> City -> World -> Doomsday), each a
## sequence of steps. The hideout (SHOP) comes before EVERY heist choice, a
## stage ends with a mandatory BOSS heist in the stage's signature building, and
## the Board's collector checks the books at each QUOTA_GATE.
##
##   Town / City / World:  SHOP, HEIST, SHOP, HEIST, SHOP, BOSS, QUOTA, ADVANCE
##   Doomsday:             SHOP, HEIST, QUOTA, SHOP, BOSS (the Chairman)
##
## A HEIST_CHOICE step offers 2-4 heist options; a boss step is a HEIST_CHOICE
## with exactly one BOSS option.

enum Stage { TOWN, CITY, WORLD, DOOMSDAY }
enum StepKind { HEIST_CHOICE, SHOP, QUOTA_GATE, ADVANCE }

const STAGE_NAMES := {
	Stage.TOWN: "Town", Stage.CITY: "City",
	Stage.WORLD: "World", Stage.DOOMSDAY: "Doomsday",
}
## Ordinary heists before the stage boss.
const REGULAR_HEISTS := {
	Stage.TOWN: 2, Stage.CITY: 2, Stage.WORLD: 2, Stage.DOOMSDAY: 1,
}
## Heist difficulty ("room rarity") floor per stage; options roll +0..1.
const STAGE_RARITY_FLOOR := {
	Stage.TOWN: 0, Stage.CITY: 1, Stage.WORLD: 2, Stage.DOOMSDAY: 3,
}
const STAGE_VENUES := {
	Stage.TOWN:     [&"pickpocket", &"corner_racket", &"chop_shop"],
	Stage.CITY:     [&"cat_burglar", &"safecracker", &"bank_job", &"fence"],
	Stage.WORLD:    [&"museum", &"diamond_exchange", &"casino_skim", &"transit_ambush", &"crypto_launder"],
	Stage.DOOMSDAY: [&"central_bank_hack", &"reactor_sabotage", &"crypto_launder"],
}
## The mandatory boss heist that closes each stage: boss id + the venue it moves.
const STAGE_BOSSES := {
	Stage.TOWN: [&"landlord", &"corner_racket"],
	Stage.CITY: [&"auditor", &"bank_job"],
	Stage.WORLD: [&"ambassador", &"diamond_exchange"],
	Stage.DOOMSDAY: [&"chairman", &"cartel_cartel"],
}

## Gold the collector wants to SEE at each gate (a threshold, not a payment).
##   gate 0: 380   gate 1: 760   gate 2: 1520   gate 3: 3040
const BASE_QUOTA := 380.0
const QUOTA_GROWTH := 2.0
const MIN_OPTIONS := 2
const MAX_OPTIONS := 4
const ROUTE_VERSION := 3

## A single step in a stage. HEIST_CHOICE steps hold `options` (Array[MapNode]);
## other kinds are single fixed steps.
class Step:
	var kind: int
	var options: Array = []          # MapNode list for HEIST_CHOICE
	var skippable: bool = false      # the hideout can be skipped
	var chosen_index: int = -1       # which option the player picked
	var is_boss: bool = false
	func _init(k: int) -> void:
		kind = k

# stages[i] = Array[Step]
var stages: Array = []
var stage_order: Array = [Stage.TOWN, Stage.CITY, Stage.WORLD, Stage.DOOMSDAY]

var current_stage: int = 0
var current_step: int = 0
var heists_done: int = 0
var quota_block: int = 0
var run_seed: int = 0

var _rng := RandomNumberGenerator.new()

func generate(seed_value: int = 0) -> void:
	run_seed = seed_value
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	stages.clear()
	for s in stage_order:
		stages.append(_build_stage(s))
	current_stage = 0
	current_step = 0
	heists_done = 0
	quota_block = 0

func _build_stage(stage: int) -> Array:
	var steps: Array = []
	var floor_rarity: int = STAGE_RARITY_FLOOR[stage]
	var venues: Array = STAGE_VENUES[stage]
	for h in REGULAR_HEISTS[stage]:
		var shop := Step.new(StepKind.SHOP)
		shop.skippable = true
		steps.append(shop)
		var choice := Step.new(StepKind.HEIST_CHOICE)
		var count := _rng.randi_range(MIN_OPTIONS, MAX_OPTIONS)
		for i in count:
			choice.options.append(_make_heist_option(stage, floor_rarity, venues, h, i))
		steps.append(choice)
	if stage == Stage.DOOMSDAY:
		steps.append(Step.new(StepKind.QUOTA_GATE))
		var last_shop := Step.new(StepKind.SHOP)
		last_shop.skippable = true
		steps.append(last_shop)
		steps.append(_boss_step(stage, floor_rarity))
	else:
		var boss_shop := Step.new(StepKind.SHOP)
		boss_shop.skippable = true
		steps.append(boss_shop)
		steps.append(_boss_step(stage, floor_rarity))
		steps.append(Step.new(StepKind.QUOTA_GATE))
		steps.append(Step.new(StepKind.ADVANCE))
	return steps

func _boss_step(stage: int, floor_rarity: int) -> Step:
	var step := Step.new(StepKind.HEIST_CHOICE)
	step.is_boss = true
	var node := MapNode.new(MapNode.Type.BOSS)
	node.stage = stage
	node.room_rarity = mini(floor_rarity + 1, 4)
	node.boss_id = STAGE_BOSSES[stage][0]
	node.venue_id = STAGE_BOSSES[stage][1]
	node.is_valuable = true
	step.options.append(node)
	return step

func _make_heist_option(stage: int, floor_rarity: int, venues: Array, heist_index: int, option_index: int) -> MapNode:
	var node := MapNode.new(MapNode.Type.HEIST)
	node.stage = stage
	node.room_rarity = floor_rarity + _rng.randi_range(0, 1)
	node.venue_id = venues[_rng.randi() % venues.size()]
	node.is_valuable = _rng.randf() < 0.3
	# Modifiers come from an independent hash so later content passes can add
	# roll types without reshuffling every other choice on a seed.
	var tags: Array = [&"heavy_police", &"lockdown", &"insider"]
	node.modifier = tags[(absi(hash(str(run_seed) + ":" + str(stage) + ":" + str(heist_index))) + option_index) % tags.size()]
	return node

# --- Progression ---
func current() -> Step:
	if current_stage >= stages.size():
		return null
	var steps: Array = stages[current_stage]
	if current_step >= steps.size():
		return null
	return steps[current_step]

func current_kind() -> int:
	var step := current()
	return step.kind if step else -1

## Look ahead to the NEXT HEIST_CHOICE step's options without advancing.
## The hideout's Black Market stocks for "the case" coming up.
func peek_next_heist_options() -> Array:
	if current_stage >= stages.size():
		return []
	var steps: Array = stages[current_stage]
	for i in range(current_step, steps.size()):
		var s: Step = steps[i]
		if s.kind == StepKind.HEIST_CHOICE:
			return s.options
	return []

## True when the next heist on the route is the stage's boss.
func next_heist_is_boss() -> bool:
	var options := peek_next_heist_options()
	return options.size() == 1 and options[0].type == MapNode.Type.BOSS

## First option of the next heist choice (dev tools and screenshots use this).
func first_heist_option() -> MapNode:
	var options := peek_next_heist_options()
	return options[0] if not options.is_empty() else MapNode.new()

## Pick an option on the current HEIST_CHOICE step. Returns the chosen MapNode.
func choose_option(index: int) -> MapNode:
	var step := current()
	if step == null or step.kind != StepKind.HEIST_CHOICE:
		return null
	if index < 0 or index >= step.options.size():
		return null
	step.chosen_index = index
	var node: MapNode = step.options[index]
	if node.type == MapNode.Type.MYSTERY:
		node.reveal()
	return node

## Advance to the next step. Returns the new current Step (or null at run end).
func advance_step() -> Step:
	var finished := current()
	if finished and finished.kind == StepKind.HEIST_CHOICE:
		heists_done += 1
	current_step += 1
	var steps: Array = stages[current_stage]
	if current_step >= steps.size():
		current_stage += 1
		current_step = 0
		quota_block = maxi(quota_block, current_stage)
		if current_stage >= stages.size():
			return null
	return current()

func current_quota() -> float:
	return BASE_QUOTA * pow(QUOTA_GROWTH, quota_block)

## The empire index the Board demands at this gate: 120, 227, 350, 492.
## The index is a run-wide AVERAGE across every venue, so heists alone fall
## short: two flawless jobs reach ~110. Market operations close the gap.
func current_stock_quota() -> float:
	return stock_quota_for(quota_block)

static func stock_quota_for(block: int) -> float:
	var ratio_bar := 1.20 * pow(1.15, block)
	return 1.0 + (ratio_bar - 1.0) * 595.0

## Combined gate: needs the GOLD on hand AND the empire index.
func check_quota_full(gold: int, stock_index: float) -> bool:
	var met := gold >= current_quota() and stock_index >= current_stock_quota()
	if met:
		quota_block += 1
	return met

func stage_name() -> String:
	if current_stage >= stage_order.size():
		return "Complete"
	return STAGE_NAMES[stage_order[current_stage]]

static func name_of_stage(stage: int) -> String:
	return STAGE_NAMES.get(stage, "Complete")

func is_complete() -> bool:
	return current_stage >= stages.size()

func is_final_stage() -> bool:
	return current_stage == Stage.DOOMSDAY

## Total heists on the route (regular + bosses), for progress displays.
func total_heists() -> int:
	var n := 0
	for steps: Array in stages:
		for s: Step in steps:
			if s.kind == StepKind.HEIST_CHOICE:
				n += 1
	return n

## Restore an exact saved position (route_version 3 saves).
func restore_position(stage: int, step: int, block: int, done: int) -> void:
	current_stage = clampi(stage, 0, stages.size())
	current_step = 0 if current_stage >= stages.size() else clampi(step, 0, stages[current_stage].size() - 1)
	quota_block = clampi(block, 0, 4)
	heists_done = maxi(done, 0)

## Migrate an older save (different route shape) by completed-heist count:
## park the run on the first step after that many heists, gear intact.
func restore_progress(completed: int) -> void:
	var remaining := maxi(completed, 0)
	current_stage = 0
	current_step = 0
	heists_done = 0
	quota_block = 0
	while remaining > 0 and not is_complete():
		var step := current()
		if step.kind == StepKind.HEIST_CHOICE:
			remaining -= 1
		elif step.kind == StepKind.QUOTA_GATE:
			quota_block += 1
		advance_step()
	# Never resume inside a gate we did not actually face: step back onto a
	# preceding hideout if the migration landed past the last heist.
	if is_complete():
		current_stage = stages.size() - 1
		current_step = stages[current_stage].size() - 1
