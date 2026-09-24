extends RefCounted
class_name Objectives
## What a job asks of you. Loot is the default; the others are optional —
## failing one only costs its bonus (a boss job's kill is the exception).
##   loot           grab the valuables, back to the car
##   assassination  a named VIP elite is somewhere inside
##   smash_grab     the alarm is already ringing; marked rooms hold jackpots;
##                  a lockdown seals every fire exit when the timer runs out
##   ghost          no kills and no alarms: a big move on the venue
##   sabotage       plant charges at 2-3 marked points (hold USE 2 s)
##   package        carry a case to the car (15% slower while you carry it)

const DATA := {
	&"loot": ["LOOT", "Grab the valuables and get back to the car.", ""],
	&"assassination": ["ASSASSINATION", "A named VIP is inside. Put them down.", "a bounty and a jolt to the venue"],
	&"smash_grab": ["SMASH & GRAB", "The alarm is already ringing. Hit the marked rooms before the lockdown.", "jackpot rooms and a finder's fee"],
	&"ghost": ["GHOST RUN", "In and out: no kills, no alarms.", "a big move on the venue and a fee"],
	&"sabotage": ["SABOTAGE", "Plant charges at the marked points (hold USE 2 s).", "the venue crashes when you leave"],
	&"package": ["THE PACKAGE", "Carry the case to the car. It slows you down.", "a courier's fee"],
}

## Weights by stage (Town eases in; the tower likes everything).
const WEIGHTS := {
	0: {&"loot": 5.0, &"assassination": 1.5, &"ghost": 1.5, &"package": 1.5, &"sabotage": 1.0, &"smash_grab": 0.8},
	1: {&"loot": 3.0, &"assassination": 2.0, &"ghost": 1.6, &"package": 1.5, &"sabotage": 1.6, &"smash_grab": 1.4},
	2: {&"loot": 2.5, &"assassination": 2.0, &"ghost": 1.5, &"package": 1.5, &"sabotage": 1.8, &"smash_grab": 1.8},
	3: {&"loot": 2.0, &"assassination": 2.0, &"ghost": 1.4, &"package": 1.4, &"sabotage": 2.0, &"smash_grab": 2.0},
}

static func title(id: StringName) -> String:
	return DATA[id][0] if DATA.has(id) else "LOOT"

static func brief(id: StringName) -> String:
	return DATA[id][1] if DATA.has(id) else DATA[&"loot"][1]

static func reward(id: StringName) -> String:
	return DATA[id][2] if DATA.has(id) else ""

## Weighted pick. HITs lean toward sabotage (the natural pair).
static func pick(rng: RandomNumberGenerator, stage: int, hit: bool) -> StringName:
	var weights: Dictionary = WEIGHTS.get(clampi(stage, 0, 3), WEIGHTS[0]).duplicate()
	if hit:
		weights[&"sabotage"] = float(weights[&"sabotage"]) * 2.0
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return &"loot"

## 0-2 modifiers, more in later stages, never two that contradict.
static func pick_modifiers(rng: RandomNumberGenerator, stage: int) -> Array:
	var count := 0
	match clampi(stage, 0, 3):
		0: count = 1 if rng.randf() < 0.6 else 0
		1: count = 2 if rng.randf() < 0.3 else 1
		2: count = 2 if rng.randf() < 0.5 else 1
		3: count = 2 if rng.randf() < 0.8 else 1
	var pool: Array = MapNode.MODIFIERS.keys()
	var out: Array = []
	var guard := 0
	while out.size() < count and guard < 20:
		guard += 1
		var m: StringName = pool[rng.randi() % pool.size()]
		if m in out:
			continue
		if (m == &"payday" and &"skeleton_crew" in out) or (m == &"skeleton_crew" and &"payday" in out):
			continue
		out.append(m)
	return out
