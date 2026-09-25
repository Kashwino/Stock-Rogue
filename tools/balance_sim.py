#!/usr/bin/env python3
"""Stock Rogue economy simulator (stdlib only).

Re-verifies the run economy against the brief's invariants with every income
source the game has now: floor valuables and room-clear gold (measured by
tools/loot_census.gd), grade shocks with contract decay, the live venue price
during a heist (a port of LiveStock), objective shocks and fees, Fence
positions, Market Manipulation, market news and boss shocks.

Constants are read from the GDScript sources so the sim follows the code.

    python3 tools/balance_sim.py            # run every check, exit 1 on failure
    python3 tools/balance_sim.py --runs 4000

Regenerate the loot census after changing rooms, props or loot tables:
    godot --headless --path . res://tools/loot_census.tscn
"""
import argparse
import json
import math
import os
import random
import re
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def src(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return f.read()


def const(text, name):
    m = re.search(r"const %s\s*:?=\s*([-\d.]+)" % name, text)
    if not m:
        raise SystemExit("balance_sim: cannot find const %s" % name)
    return float(m.group(1))


def export_var(text, name):
    m = re.search(r"var %s\s*:\s*float\s*=\s*([-\d.]+)" % name, text)
    if not m:
        raise SystemExit("balance_sim: cannot find var %s" % name)
    return float(m.group(1))


# ---------------------------------------------------------------- the code --
RUN_STATE = src("run_state.gd")
RUN_MAP = src("run_map.gd")
GRADER = src("heist_grader.gd")
LIVE = src("live_stock.gd")
PROFILE = src("character_profile.gd")
HIDEOUT = src("hideout_room.gd")
FLOOR = src("heist_floor.gd")
STORY = src("story.gd")
POSITIONS = src("positions.gd")
VENUES_SRC = src("venues.gd")

INDEX_SCALE = const(RUN_STATE, "INDEX_SCALE")
BASE_QUOTA = const(RUN_MAP, "BASE_QUOTA")
QUOTA_GROWTH = const(RUN_MAP, "QUOTA_GROWTH")
NEW_CHAIRMAN_INDEX = const(STORY, "NEW_CHAIRMAN_INDEX")
BASE_LEVERAGE = const(POSITIONS, "BASE_LEVERAGE")
START_GOLD = int(re.search(r"starting_gold: int = (\d+)", src("run_economy.gd")).group(1))

_grade_block = GRADER[GRADER.index("func _grade_to_stock_delta"):]
GRADE_DELTA = {g: float(v) for g, v in re.findall(r"Grade\.(\w+):\s*return ([\d.]+)", _grade_block)}
CONTRACT_DECAY = float(re.search(r"pow\(([\d.]+), repeats\)", FLOOR).group(1))
MM_PCT = int(re.search(r"\+(\d+)% to EVERY venue", HIDEOUT).group(1)) / 100.0
MM_PRICE = int(re.search(r'"Market Manipulation".*?"price": int\((\d+) \* scale\)', HIDEOUT, re.S).group(1))
FENCE_SCALE = float(re.search(r"var scale := pow\(([\d.]+), qb\) \* \(1.0 - float", HIDEOUT).group(1))

TICK = export_var(LIVE, "tick_interval")
NOISE = export_var(LIVE, "noise_amplitude")
RETENTION = export_var(LIVE, "momentum_retention")
REVERSION = export_var(LIVE, "mean_reversion")
MAX_MOMENTUM = const(LIVE, "MAX_MOMENTUM")
GAIN_HIT = export_var(PROFILE, "gain_per_hit")
GAIN_KILL = export_var(PROFILE, "gain_per_kill")
CRASH_DAMAGE = export_var(PROFILE, "crash_per_damage")

VENUES = re.findall(r'^\t&"(\w+)": \[', VENUES_SRC[VENUES_SRC.index("const DATA"):VENUES_SRC.index("const NOUNS")], re.M)
STAGE_VENUES = []
for stage in ("TOWN", "CITY", "WORLD", "DOOMSDAY"):
    line = re.search(r"Stage\.%s:\s*\[([^\]]*)\]" % stage, RUN_MAP[RUN_MAP.index("const STAGE_VENUES"):]).group(1)
    STAGE_VENUES.append(re.findall(r'&"(\w+)"', line))
STAGE_BOSS_VENUE = []
for stage in ("TOWN", "CITY", "WORLD", "DOOMSDAY"):
    m = re.search(r"Stage\.%s: \[&\"\w+\", &\"(\w+)\"\]" % stage, RUN_MAP[RUN_MAP.index("const STAGE_BOSSES"):])
    STAGE_BOSS_VENUE.append(m.group(1))

# Objective fee per stage (x (stage + 1)) and the venue shock on a CONTRACT.
OBJECTIVES = {"loot": (0, 1.0), "assassination": (120, 1.08), "smash_grab": (80, 1.0),
              "ghost": (100, 1.2), "sabotage": (90, 0.85), "package": (150, 1.0)}
OBJ_WEIGHTS = {"loot": 5.0, "assassination": 1.5, "ghost": 1.5, "package": 1.5, "sabotage": 1.0, "smash_grab": 0.8}

try:
    with open(os.path.join(ROOT, "tools", "loot_census.json"), encoding="utf-8") as f:
        CENSUS = {int(k): v for k, v in json.load(f).items()}
except FileNotFoundError:
    raise SystemExit("balance_sim: run tools/loot_census.tscn first (writes tools/loot_census.json)")


def index_of(market):
    mean = sum(market.values()) / len(market)
    return 1.0 + (mean - 1.0) * INDEX_SCALE


def new_market():
    return {v: 1.0 for v in VENUES}


# --------------------------------------------------------------- players ----
# grade, share of floor loot bagged, share of rooms cleared, damage taken,
# time vs par, chance the objective lands.
SKILL = {
    "flawless": dict(grade="S_PLUS", loot=0.95, clear=1.0, damage=0, pace=1.0, objective=1.0),
    "sharp":    dict(grade="S", loot=0.75, clear=0.8, damage=1, pace=1.2, objective=0.85),
    "typical":  dict(grade="A", loot=0.6, clear=0.6, damage=2, pace=1.4, objective=0.7),
    "shaky":    dict(grade="B", loot=0.45, clear=0.45, damage=3, pace=1.7, objective=0.5),
}


def live_move(rng, kills, seconds, damage, inverted=False, boss_shock=None):
    """Port of LiveStock over one heist: returns the venue's price multiplier."""
    p = 1.0
    momentum = 0.0
    sign = -1.0 if inverted else 1.0
    ticks = max(1, int(seconds / TICK))
    kill_ticks = sorted(rng.randrange(ticks) for _ in range(kills))
    hurt_ticks = sorted(rng.randrange(ticks) for _ in range(damage))
    boss_tick = int(ticks * 0.8) if boss_shock else -1

    def apply(pct):
        nonlocal p, momentum
        momentum = max(-MAX_MOMENTUM, min(MAX_MOMENTUM, momentum + pct * 0.35))
        p *= 1.0 + pct

    for t in range(ticks):
        for _ in range(kill_ticks.count(t)):
            for _ in range(3):
                apply(sign * GAIN_HIT)
            apply(sign * GAIN_KILL)
        for _ in range(hurt_ticks.count(t)):
            apply(-sign * CRASH_DAMAGE)
        if t == boss_tick:
            shock = boss_shock if not inverted else 2.0 - boss_shock
            momentum = max(-MAX_MOMENTUM, min(MAX_MOMENTUM, momentum + (shock - 1.0) * 0.05))
            p *= shock
        momentum = momentum * RETENTION + rng.gauss(0.0, NOISE) * (1.0 - RETENTION)
        momentum = max(-MAX_MOMENTUM, min(MAX_MOMENTUM, momentum))
        move = momentum + rng.gauss(0.0, NOISE * 0.5)
        if rng.random() < 0.03:
            move += rng.gauss(0.0, NOISE * 4.0)
        p *= 1.0 + move
        p += (1.0 - p) * REVERSION
    return max(p, 0.01)


def heist(rng, market, gold, stage, venue, skill, contracts, hit=False, boss=False):
    """One job: moves `market` in place and returns the gold it paid."""
    s = SKILL[skill]
    job = rng.choice(CENSUS[stage])
    par = 15.0 * job["rooms"]
    kills = int(job["guards"] * s["clear"])
    ratio = market[venue]
    live = live_move(rng, kills, par * s["pace"], s["damage"], inverted=hit, boss_shock=1.30 if boss else None)
    delta = GRADE_DELTA[s["grade"]]
    if hit:
        delta = 2.0 - delta
    else:
        repeats = contracts.get(venue, 0)
        if delta > 1.0:
            delta = 1.0 + (delta - 1.0) * CONTRACT_DECAY ** repeats
        contracts[venue] = repeats + 1
    paid = job["floor_loot"] * s["loot"] + job["clear_gold"] * s["clear"]
    if not boss:
        names = list(OBJ_WEIGHTS)
        obj = rng.choices(names, weights=[OBJ_WEIGHTS[n] for n in names])[0]
        if rng.random() < s["objective"]:
            fee, shock = OBJECTIVES[obj]
            paid += fee * (stage + 1)
            live *= (2.0 - shock) if hit else shock
    else:
        paid += rng.randint(8, 12) * (18 + 8 * stage) * s["loot"]
    market[venue] = max(ratio * live * delta, 0.01)
    # The wire between jobs: one story, usually a headline on one venue.
    roll = rng.random()
    if roll < 0.6:
        v = rng.choice(VENUES)
        market[v] *= 1.0 + rng.choice([0.14, 0.16, 0.12, 0.11, 0.13, -0.15, -0.13, -0.12, -0.14, -0.11]) * rng.uniform(0.85, 1.2)
    elif roll < 0.8:
        pct = rng.choice([-0.08, 0.07])
        for v in STAGE_VENUES[stage]:
            market[v] *= 1.0 + pct
    return int(paid)


def manipulate(market):
    for v in market:
        market[v] *= 1.0 + MM_PCT


# ---------------------------------------------------------------- checks ----
def pct(values, q):
    values = sorted(values)
    return values[min(len(values) - 1, int(q * len(values)))]


def check_stock_gate(rng, runs):
    alone, with_mm, afford = [], [], []
    for _ in range(runs):
        market, contracts = new_market(), {}
        gold = START_GOLD
        for _ in range(2):
            gold += heist(rng, market, gold, 0, rng.choice(STAGE_VENUES[0]), "flawless", contracts)
        alone.append(index_of(market))
        afford.append(gold >= 2 * MM_PRICE)
        manipulate(market)
        manipulate(market)
        with_mm.append(index_of(market))
    gate = 1.0 + (1.20 - 1.0) * INDEX_SCALE
    print("Stock gate 0 (%.0f):" % gate)
    print("  two flawless heists alone   median %.0f  p95 %.0f  max %.0f" % (statistics.median(alone), pct(alone, 0.95), max(alone)))
    print("  + two Market Manipulations  median %.0f  p10 %.0f   (MM +%d%% all venues, $%d)" % (statistics.median(with_mm), pct(with_mm, 0.10), MM_PCT * 100, MM_PRICE))
    print("  gold for both MMs after two flawless heists: %.0f%% of runs" % (100.0 * sum(afford) / runs))
    return [
        ("two flawless heists alone do not clear the stock gate", pct(alone, 0.95) < gate),
        ("two Market Manipulations on top clear it", statistics.median(with_mm) >= gate),
        ("two flawless heists pay for both manipulations", sum(afford) / runs >= 0.9),
    ]


def check_gold_gate(rng, runs):
    quota = BASE_QUOTA
    after = {1: [], 2: []}
    for _ in range(runs):
        market, contracts = new_market(), {}
        gold = START_GOLD
        for n in (1, 2):
            gold += heist(rng, market, gold, 0, rng.choice(STAGE_VENUES[0]), "typical", contracts)
            after[n].append(gold)
    reach2 = sum(g >= quota for g in after[2]) / runs
    reach1 = sum(g >= quota for g in after[1]) / runs
    print("Gold gate 0 ($%.0f): start $%d" % (quota, START_GOLD))
    print("  typical player, no spending: after 1 heist median $%.0f (%.0f%% there), after 2 median $%.0f (%.0f%% there)"
          % (statistics.median(after[1]), 100 * reach1, statistics.median(after[2]), 100 * reach2))
    return [
        ("the starting cash is short of the first gate", START_GOLD < quota),
        ("a typical player can reach the first gold gate in about two heists", reach2 >= 0.8),
    ]


def check_shorts(rng, runs):
    profits, index_moves = [], []
    for _ in range(runs):
        market, contracts = new_market(), {}
        venue = rng.choice(STAGE_VENUES[0])
        entry = market[venue]
        before = index_of(market)
        heist(rng, market, START_GOLD, 0, venue, "sharp", contracts, hit=True)
        move = (entry - market[venue]) / entry
        profits.append(100 * (1.0 + BASE_LEVERAGE * move) - 100)
        index_moves.append(index_of(market) - before)
    print("Shorts: $100 Fence short, then a HIT on that venue (sharp play):")
    print("  profit median $%.0f  p10 $%.0f   index move median %+.1f" % (statistics.median(profits), pct(profits, 0.10), statistics.median(index_moves)))
    return [
        ("shorting a venue and hitting it is profitable", pct(profits, 0.10) > 0),
        ("that crash costs index", statistics.median(index_moves) < 0),
    ]


def full_run(rng, skill):
    """A whole run by one kind of player. Returns (won, final index)."""
    market, contracts = new_market(), {}
    gold = START_GOLD
    block = 0
    for stage in range(4):
        jobs = 2 if stage < 3 else 1
        visits = 0
        for job in range(jobs + 1):
            boss = job == jobs
            if boss and stage == 3:
                # Doomsday: the quota sits before the Chairman.
                if not gate(market, gold, block):
                    return False, index_of(market)
                block += 1
            # Hideout before every job: manipulate when the gate needs it.
            visits += 1
            gold = hideout(rng, market, gold, block, stage)
            venue = STAGE_BOSS_VENUE[stage] if boss else rng.choice(STAGE_VENUES[stage])
            long_stake = 0
            if not boss and gold > 400 and rng.random() < 0.4:
                long_stake = 100
                gold -= long_stake
                entry = market[venue]
            gold += heist(rng, market, gold, stage, venue, skill, contracts, boss=boss)
            if long_stake:
                gold += max(0, int(long_stake * (1.0 + BASE_LEVERAGE * (market[venue] - entry) / entry)))
            if boss and stage == 3:
                gold += rng.randint(400, 600)
        if stage < 3:
            if not gate(market, gold, block):
                return False, index_of(market)
            block += 1
    return True, index_of(market)


def gate(market, gold, block):
    need_index = 1.0 + (1.20 * 1.15 ** block - 1.0) * INDEX_SCALE
    return gold >= BASE_QUOTA * QUOTA_GROWTH ** block and index_of(market) >= need_index


def hideout(rng, market, gold, block, stage):
    need_index = 1.0 + (1.20 * 1.15 ** block - 1.0) * INDEX_SCALE
    quota = BASE_QUOTA * QUOTA_GROWTH ** block
    price = int(MM_PRICE * FENCE_SCALE ** block)
    for _ in range(2):
        # The Fence shows three of its offers; a reroll is cheap.
        if index_of(market) < need_index + 40 and gold - price >= quota * 0.5 and rng.random() < 0.75:
            manipulate(market)
            gold -= price
    # Guns, mods and relics: spend some of what's left over the quota.
    spare = gold - quota
    if spare > 0:
        gold -= int(spare * rng.uniform(0.2, 0.5))
    return gold


def check_endings(rng, runs):
    mix = [("sharp", 0.25), ("typical", 0.45), ("shaky", 0.30)]
    wins = []
    by_skill = {}
    for _ in range(runs):
        skill = rng.choices([m[0] for m in mix], weights=[m[1] for m in mix])[0]
        won, idx = full_run(rng, skill)
        by_skill.setdefault(skill, []).append(won)
        if won:
            wins.append(idx)
    print("Endings (%d simulated runs):" % runs)
    for skill, results in by_skill.items():
        print("  %-8s win rate %.0f%%" % (skill, 100.0 * sum(results) / len(results)))
    if not wins:
        return [("some simulated runs win", False)]
    share = sum(i >= NEW_CHAIRMAN_INDEX for i in wins) / len(wins)
    print("  final index of winners: median %.0f  p75 %.0f  p90 %.0f" % (statistics.median(wins), pct(wins, 0.75), pct(wins, 0.90)))
    print("  THE NEW CHAIRMAN (index >= %.0f): %.0f%% of wins   (target ~25%%; p75 is %.0f)" % (NEW_CHAIRMAN_INDEX, 100 * share, pct(wins, 0.75)))
    return [("THE NEW CHAIRMAN is roughly a quarter of wins", 0.15 <= share <= 0.35)]


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--runs", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    print("Stock Rogue balance sim — %d venues, index scale %.0f, live momentum cap %.3f\n" % (len(VENUES), INDEX_SCALE, MAX_MOMENTUM))
    results = []
    for check in (check_stock_gate, check_gold_gate, check_shorts, check_endings):
        results += check(rng, args.runs)
        print()
    failed = 0
    for text, ok in results:
        print("%s  %s" % ("PASS" if ok else "FAIL", text))
        failed += 0 if ok else 1
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
