# Changelog

## Phase 0 — Audit & cleanup

- Removed dead prototype code with no production caller: `heist_controller.gd`,
  `heist_resolver.gd`, `heist_sequencer.gd`, `room.gd`, `room_manager.gd`,
  `run_controller.gd`, `door.gd`, `test_player.gd`, `arena_setup.gd`,
  `shop_ui.gd` (old menu shop), `tutorial_overlay.gd` (depended on a scene that
  never existed; onboarding is rebuilt in Phase 11), `floor_test.tscn` plus its
  duplicate copies and editor-state files.
- Moved the editor-only room generator to `tools/generate_rooms.gd`.
- Added `Log` (gated by `Log.DEBUG`, default false) and removed every leftover
  debug placeholder line.
- Added `Layers` with every physics layer documented in one place.
- The input map now lives in `project.godot` (keyboard, mouse and gamepad, plus
  `tactical_map` and `debug_menu`). `TouchInput` only patches in keyboard
  defaults and reports a readable error if an action is missing.
- Restored the loop this brief describes: case files → crew cards → the case
  wall. The hideout comes before every heist choice (skippable), each stage ends
  with a mandatory boss heist, and the Board's collector checks gold on hand and
  the empire index at a quota gate (4 gates: 380/120, 760/227, 1520/350,
  3040/492). Stages are Town, City, World and Doomsday.
- The hideout has its three vendors again (Weapon Dealer, The Fence, Black
  Market). Each vendor's panel is built once per visit, so its offers, opened
  cases and escalating reroll price persist until you walk out.
- The empty map-scene template nodes are gone (`map_ui.gd` builds everything).
- `tools/run_tests.sh` mirrors CI locally with a clean user folder;
  `tools/screenshot.tscn` renders any screen to PNG under Xvfb.

## Phase 1 — Visual foundation

- **Palette + theme.** `Palette` holds every colour (ink, panel, gold, dim
  gold, danger red, rarity colours untouched, neon, police, paper). `Look`
  (visual_theme.gd) builds the project theme in code at startup: stamped gold
  buttons (primary/danger/ghost variations), panels, paper panels, sliders,
  switches, checkboxes, scrollbars, tooltips and popups, plus label roles
  (Heading, Title, Mono, Type, Dim, Kicker). Fonts are OFL (Oswald, Barlow
  Semi Condensed, IBM Plex Mono, Courier Prime) in `assets/fonts` with
  licences; SystemFont fallbacks if missing.
- **Character kit** (`sprite_kit.gd`): layered procedural top-down people —
  world-aligned drop shadow, walking feet, superellipse torso per body type
  (coat, suit, vest, armour, bulky, tank, lean, hoodie, gown), arms that hold
  a silhouette matching the equipped weapon, heads with hats/helmets/hoods,
  accessories (medic cross, radio, bandolier, hi-vis, pinstripe…), tripod
  turrets, drones and dogs. Idle breathing, walk bob, recoil kick, reload pose,
  hit flash, and a fallen-body decal that fades (capped at 40). Every guard
  archetype has its own silhouette; each specialist has a look; the player
  gets a gold rim.
- **Environments per stage** (`env_theme.gd`, `room_art.gd`): Town concrete
  slabs and hazard lanes, City carpet tiles and polished banking halls, World
  marble and casino velvet, Doomsday dark glass with glowing ticker strips.
  Rooms get a type (warehouse, pawn counter, offices, gaming floor, trading
  floor…) and a stencilled name; walls are repainted with a top face, a front
  face and a baseboard.
- **Props & cover** (`prop.gd`, `prop_placer.gd`): ~30 furniture kinds
  (crates, shelves, desks, cubicles, filing cabinets, safes, slot machines,
  card tables, server racks, trading desks, pillars, statues…) placed by room
  type as StaticBody2D on the new props layer (16): they stop walkers, bullets
  and sight. A 20 px occupancy grid keeps doorway corridors, spawn markers,
  security devices, the terminal and room centres clear, and a flood fill
  (with a one-cell body clearance) rejects any prop that would cut a doorway,
  spawn point or the centre off. Spawns and floor loot avoid furniture.
- **Lighting** (`heist_lighting.gd`): CanvasModulate night per stage, ceiling
  lamps per module (some flicker), player flashlight cone + a small glow so the
  player always reads, pooled muzzle-flash lights, sodium street lamps, neon
  spill, getaway-car headlights, police sweeps, optional LightOccluder2D wall
  shadows (Dynamic shadows setting). Far lamps are culled at 4 Hz.
- **Outside** (`street_art.gd`): wet-asphalt shader with puddle reflections,
  sidewalk and kerb, lane markings, crosswalk, lamp posts, parked cars,
  rooftops, a flickering neon sign with the venue's name over the main door,
  and rain (CPU particles: streaks + splashes) drawn beneath the building so
  it only falls outside.
- **Post-process** (`post_fx.gd`): vignette, film grain, chromatic aberration
  on damage, red heartbeat and desaturation at 1 HP (Settings `post_fx`).
- **Transitions** (`transition.gd` autoload): fade, and a case-file stamp
  wipe into hideouts and heists. Input is blocked while covered. **Heist intro
  card**: venue sign, local time, security level, objective, modifiers;
  skippable, never pauses.
- **HUD rebuilt in code**: ticker tape crawl (every venue; the robbed one boxed
  in gold), drawn hearts, gold counter, live loot multiplier, objective panel,
  heat meter with fire-exit and police ticks + heat-source log, minimap,
  restyled stock chart, trader feed, weapon panel with a drawn weapon icon,
  magazine pips, reserve and reload bar.
- **Case wall map**: corkboard, stage header, route strip of pinned index
  cards joined by red string, heist leads as pinned case files with a night
  photo of the building, ticker/price, security bars and modifier; the quota
  gate is a sit-down across the table from the Board's collector with a ledger
  and a PAID UP / CUT OFF stamp; stage hand-off card with a teaser.
- **Hideout**: plank floor, rug, card table with chips, stacked cash, a TV
  running the live ticker, a neon sign and a drawn NPC per vendor with speech
  bubbles that react to the run (low index, close to quota, last grade, boss
  down, low health, boss next).
- **Main menu**: rain on an office window over a blinking skyline with the
  Exchange tower's neon crown, searchlights, the logo with a live chart line and
  a LISTED ON THE BOARD stamp, ticker along the bottom.
- **Case files & crew**: dossier cards with hover tilt and slammed stamps;
  mugshot portraits per specialist; locked crew are silhouettes.
- **Results** are a typed job report with the grade slammed on as a stamp;
  **death** is tomorrow's front page with a headline generated from the run.
- Loot glows by value tier (cash, jewels, briefcase, art); chests and the
  market terminal pulse.
- Tools: `tools/check.sh` (compile every script), `tools/screenshot.tscn`
  presets (home, select, map, hideout, heist, gallery, results, death).

## Decisions

- **Branch.** The session's git configuration requires all work to be committed
  and pushed on `codex/mobile-web-beta`; the brief's `full-game` branch name was
  substituted by that branch. The untouched baseline is commit `aa53153`.
- **Existing mobile beta vs the brief.** This repository had moved past the
  version the brief describes (a "ten scores" route, optional Night Market, no
  quota gates, a walkable preparation lobby that sold crew with Intel). Where
  they disagree on intent the brief wins, so the brief's route, crew-card
  unlocks and three-vendor hideout are back. Everything else from the beta stays:
  mobile touch controls, the Web export, the market terminal, security devices,
  the tactical map, the practice "Quick Heist" and the regression suites.
- **Preparation lobby removed.** Its jobs are covered by the crew cards
  (specialists now unlock through feats) and, from Phase 9, the Connections
  board. Players who already built the beta's Crew Quarters keep the Wolf and
  Broker.
- **Quota is a threshold, not a payment** — matching the original code; the
  collector wants to *see* the money.
- **Boss heists are mandatory kills**: the getaway car will not leave while the
  stage boss stands.
- **Heist difficulty** is capped at 0–4 (stage floor + 0..1) so the room-clear
  gold table's boss row (6) is never used for ordinary rooms.
- **Practice job** ("Quick Heist") is a standalone Auditor job in its own slot
  that never touches the three case files and returns to the menu afterwards.
  It pads health by +6.
- **Generated files** (`*.uid`, `*.import`) are git-ignored, as before; CI and
  a local import regenerate them.
- **Old saves** (route_version < 3) migrate by completed-heist count, keeping
  health, gold, loadout and market prices.
- **Practice job is a rehearsal**: health cannot drop below 1 in the Quick
  Heist (hits still cost gold, grade and stock). This also makes the browser
  regression suite deterministic.
- **Currency shown as `$`**: the currency is still called gold in text, but
  `$` renders on every platform (the old `⦿` glyph was not in the shipped
  fonts on the Web build).
- **Getaway car** is parked alongside the door axis so the walk from the car
  to the main door is straight.
