# Stock Rogue — completion progress

Read this first after a context reset: continue from the first unchecked item.
Branch: `codex/mobile-web-beta` (see CHANGELOG → Decisions). Commit after every
phase as `phase N: <summary>`. Verify with `tools/run_tests.sh` (headless import +
settings round-trip + smoke suite) and, for UI flows, the Web export +
`node tests/browser.mjs`. Visual checks: `xvfb-run -a godot --path .
--rendering-driver opengl3 res://tools/screenshot.tscn -- shot=<preset> out=<png>`.

## Architecture

**Engine:** Godot 4.6.1, GL Compatibility renderer, 1280×720 canvas_items stretch.
Ships as a single-threaded Web build (phones in landscape) and desktop.

**Autoloads** (project.godot, in load order):
`Look` (visual_theme.gd — palette/theme bootstrap), `Settings` (settings.cfg +
browser localStorage), `RunEconomy` (gold), `RunSave` (3 case-file slots + a
practice slot), `Meta` (career save: unlocks, stats, currency), `RunState` (the
live run: loadout, health, market, perks, positions), `RunFlow` (route position +
scene changes), `Noise` (AI hearing bus), `TouchInput` (virtual sticks + input
map guard), `Audio` (audio.gd: SFX pools, loops, layered music), `Controls` (mobile_controls.gd touch overlay),
`QAProbe` (read-only browser telemetry behind `?qa=1`), `Transition` (scene
changes behind a shutter/stamp).

**Loop:** `home_screen.tscn` → `character_select.tscn` (case files → crew
cards) → `RunFlow.start_new_run` → `map_ui_screen.tscn` (the case wall) shows the
current route step:
- `SHOP` → `hideout_room.tscn` (Weapon Dealer cases, The Fence, Black Market) →
  leaving advances the step;
- `HEIST_CHOICE` → pick one of 2–4 cards (or the single stage boss) →
  `heist_floor.tscn` → extraction → results card → `RunFlow.on_heist_finished`;
- `QUOTA_GATE` → the collector checks gold on hand + empire index (fail = run over);
- `ADVANCE` → next stage. Stages: Town, City, World, Doomsday. After the Chairman
  → ending. Death anywhere → `death_screen.tscn` (spawned on the root).

**Route** (`run_map.gd`): Town/City/World = SHOP, HEIST, SHOP, HEIST, SHOP, BOSS,
QUOTA, ADVANCE; Doomsday = SHOP, HEIST, QUOTA, SHOP, BOSS (Chairman). Gold quota
380×2^block (threshold, not payment); index gates 120/227/350/492
(`INDEX_SCALE` 595). Saves are route_version 3 (exact step); older saves migrate
by completed-heist count.

**Heist** (`heist_floor.gd`): `FloorGenerator` places room scenes from `rooms/`
on a 600×450 module grid (open gaps, sealed perimeter, gold main entrance, green
fire exits) or loads an authored layout. Player starts outside at the
`GetawayCar`; all guards (`enemy.gd`, archetypes, PATROL/SENTRY, provoke gate)
spawn at build time; `EnemyDirector` distance-sleeps them and buckets them for
separation. Newer archetypes run an `EnemyBrain` (`enemy_brains.gd`); elites
carry an affix; per-stage pools live in `HeistFloor.stage_pools`. `Civilian`s
wander ordinary rooms. Bullets come from the heist's `BulletPool`. Heat comes
from `SecurityDevice` cameras/alarm panels, guard radio calls, techs and
civilians reaching panels, and market moves; above the dispatch threshold `CargoVan`s drop miniboss
pairs. `LiveStock` moves the venue price in real time; `HeistGrader` grades the
job at extraction and shocks the venue. `MarketTerminal` in the lobby offers one
market operation per heist (`MarketOps`, `ShortBook`). Boss jobs build a
signature building from `BossLayouts`; the boss (`boss.gd` subclasses) engages
when the player walks in, the floor seals the arena (`Shutter`), shows
`BossIntroCard` and the HUD `BossBar`, and pays out in `on_boss_down`.

**Collision layers** (`layers.gd`): 1 walls, 2 enemies, 4 player, 8 security
devices, 16 props/cover, 32 flyers (drones). All set in code.

**Economy/market:** `CriminalMarket` + `Roster` (15 venues, run-long prices),
empire index = mean price ratio mapped through `INDEX_SCALE`. Leads are
CONTRACTs or HITs (`MapNode.contract`); Fence positions live in
`RunState.positions` (`Positions`), news and rumors in `RunState.news` /
`rumors` (`MarketNews`, rolled in `RunFlow.on_heist_finished`).

**UI rule set:** every CanvasLayer UI has one full-rect Control root; UI built in
code; anything that pauses sets PROCESS_MODE_ALWAYS and unpauses on exit.

## Phase checklist

- [x] Phase 0 — audit & cleanup (dead scripts removed, Log helper, Layers,
      input map in project.godot, brief route restored: case files → crew →
      hideout before every heist → quota gates → stage bosses)
- [x] Phase 1 — visual foundation (theme, fonts, sprite kit, stage art, props,
      lighting, street, post-fx, transitions, HUD, case wall, hideout, menus)
- [x] Phase 2 — game feel (shake, hit-stop, slow-mo, knockback, damage numbers,
      muzzle/casings/sparks/holes, crosshair, recoil + lead, loot magnet, market chips)
- [x] Phase 3 — audio (Audio autoload, generated SFX + 6 music loops, layered
      heist music, hooks everywhere, volume/shake/display settings)
- [x] Phase 4 — enemies & security (9 new archetypes via EnemyBrain, elites,
      stage pools, civilians, sparse alarm panels with hold-to-cut, radio bar,
      bullet pooling)
- [x] Phase 5 — bosses (Boss framework, four multi-phase bosses in data-authored
      signature buildings, shutters, intro card, boss bar, lieutenants, uniques)
- [x] Phase 6 — market mechanics (CONTRACT/HIT, Fence positions, live loot
      multiplier, repeat-venue decay, news wire and rumors)
- [ ] Phase 7 — objectives & map modifiers
- [ ] Phase 8 — build identity (relics, mods, traits)
- [ ] Phase 9 — characters & meta progression
- [ ] Phase 10 — story & endings
- [ ] Phase 11 — menus, pause, onboarding, settings
- [ ] Phase 12 — balance, performance, final QA
