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

## Phase 2 — Game feel

- `CombatFX` rebuilt as the feel hub: trauma-based camera shake (squared,
  noise-driven offset and roll, scaled by the Settings shake slider), camera
  recoil kick opposite each shot, a slight aim-lead offset toward the cursor /
  stick, and a real-time-managed time scale (hit-stop 60–65 ms on kills and
  hits, slow-motion on a room's last kill and on boss kills) that can never
  stay stuck slow.
- Per-weapon heft: shake, recoil and flash size scale with damage and pellets.
- Hit flash on every character (kit), knockback on enemies (weapon value or a
  small default) and on the player (pushed along the incoming bullet).
- Pooled/capped effects: muzzle flash sprite + light, ejected brass casings
  (40), impact sparks, bullet holes on walls and furniture (80), blood flecks,
  floating damage numbers (Settings toggle).
- Drawn crosshair at the cursor (or ahead of the player on a gamepad): the gap
  widens with spread and firing bloom; a ring fills while reloading. The OS
  cursor hides only while playing.
- Loot has a short magnet, pops, and its value flies to the HUD gold counter,
  which counts up.
- Market feedback: player-caused venue moves are gathered for a beat and pop a
  "BANK +2.3%" chip by the player while the ticker flashes green or red.
- Dodge rolls leave gold afterimages and kick up dust.
- Bullets restyled: gold/white tracers for the player, glowing orange-red
  slugs for enemies, both unshaded so darkness never hides them.

## Phase 3 — Audio

- New `Audio` autoload (`audio.gd`) replaces the old `Sfx` node: pooled 2D and
  flat players, per-sound voice limits, ±6% pitch variance, a mix table of dB
  offsets, looping one-shots (alarm, heartbeat, van engine, drone), and music
  that crossfades between tracks. Heist music is two synced layers (stealth /
  combat) crossfaded by an intensity value from heat, alert guards and nearby
  fights; bosses switch to their own track.
- `tools/gen_sfx.py` synthesises every sound (59 effects) and the six music
  loops (menu, hideout, heist stealth, heist combat, boss, ending) as WAV files
  under `assets/audio/`; see `assets/audio/README.md`. No third-party audio.
- Hooked: weapon shots per class, dry fire, reload (mag out / in), footsteps
  (silent when sneaking), dodge, hits, deaths, guard alerts, camera spotting,
  alarm loop, radio calls, van engine, loot tiers, case reveals and ticks,
  cash register / deny at vendors, stock up/down chips, typewriter, paper
  sounds, low-health heartbeat, every button (hover tick + click).
- Buses: Master, Music, SFX, UI. Settings gained Music, Interface volume and
  Screen shake sliders plus Dynamic shadows, Post-processing, Reduce flashing
  and Damage numbers toggles. The settings panel is two columns so it fits a
  phone in landscape.
- `build/` and `artifacts/` carry `.gdignore` so Godot never imports test
  output.

## Phase 4 — Enemies & security

- Nine new archetypes (17 in total), each with its own silhouette and a
  readable telegraph, all behind the provoke gate and the existing collision
  and separation rules. Their behaviour lives in `EnemyBrain` plug-ins
  (`enemy_brain.gd`, `enemy_brains.gd`):
  - **Riot Shield** — frontal ~100° shield deflects rounds with sparks; turns
    slowly (flank him); telegraphed shield bash drops the guard.
  - **Grenadier** — lobs grenades with a filling landing ring (0.9 s); blasts
    hurt everyone in the radius, guards included, and ignore furniture.
  - **K9 Handler + Dog** — the dog waits at heel, is released when the handler
    is provoked (or loses him), and lunges after a shown crouch.
  - **Security Tech** — when provoked runs for the nearest alarm panel (a
    red "!" over his head); reaching it raises the alarm: +14 heat and a van
    right now. From the City on he also launches a **Drone**.
  - **Laser Sniper** — a laser tracks you for 1.2 s (the last beat locks and
    turns white), then a heavy shot; breaking line of sight cancels it.
  - **Bouncer** — fists; a telegraphed charge lane; hits slow you briefly.
  - **Drone** — flies on its own physics layer over furniture (walls still
    stop it), orbits and fires 3-round bursts.
  - **Cleaner** — World+ at high heat: shimmer-cloaked until he fires.
- **Elite affixes** (City onward, rare Town jobs, and hot late vans): Armored,
  Volatile (blast 0.6 s after death), Hasted (afterimages), Shielded
  (regenerating bubble), Veteran (+1 damage). Elites glow, wear a name tag and
  drop a valuable.
- **Per-stage pools** (`HeistFloor.stage_pools`) for ordinary, treasure and boss
  rooms, and per-stage van pairs escalating with heat (still exactly two).
- **Civilians** in about a third of ordinary rooms (never boss or treasure
  rooms): gunfire makes them cower, flee for the street or (the brave ones)
  run for an alarm panel. Holding your aim on a runner for a second makes
  them drop. Killing one: +14 heat, the venue drops 12%, and a grade penalty.
- **Security**: cameras sweep every room but the lobby (spotting you = +6 heat
  and arms the nearest panel). Alarm panels are now 1–3 per building, placed
  first where a tech works; hold USE 1.5 s beside one to cut it (a gold ring
  fills) along with its room's cameras. Guard radio calls show a radio icon
  and a 2 s bar; hits knock the bar back, only a kill stops it. Every source
  lands in the heat log ("CAMERA SPOTTED YOU +6").
- **Performance**: bullets are pooled (`BulletPool`); guards and techs keep
  the distance-sleeping director and its spatial buckets.
- New shared pieces: `Telegraph` (lasers, lanes, landing rings), `Blast`,
  `Grenade`, `EnemyOverhead` (tags, radio bar, alarm icon, shield bubble),
  `Civilian`; new generated sounds (throw, punch, cloak, scream, beep).

## Phase 5 — Bosses

- **Boss framework** (`boss.gd`, extends Enemy): name and title, health
  thresholds that start new phases (1.3 s of invulnerability, one line of
  dialogue, an arena change), an attack state machine with telegraphs, and
  health/damage scaled by the quota block (+30% health per block).
- **The fight**: walking into the arena (clear of the doorways) seals every
  doorway with steel shutters, pans the camera to the boss and slams a title
  card (name, title, PRIORITY TARGET). A top-centre **boss bar** shows the
  name, a tick at every phase threshold, a damage trail, status tags
  (DIPLOMATIC IMMUNITY, AUDIT, LIQUIDATION) and the boss's lines.
- **Death**: slow motion, a burst of cash on the floor, the venue's big stock
  shock (the existing `report_shock`), shutters roll up, the heist is marked
  as before, the boss's **unique weapon** drops in a case, and the career
  earns Intel (+3; lieutenants +1) and a boss kill.
- **Signature buildings** as data (`boss_layouts.gd`) built by
  `FloorGenerator.generate_authored`: Tenement Row, the Marlowe Exchange
  (converted from its old scene), the Embassy of Valdoria and the Exchange
  tower. All dressing, crews, loot, chests, security and exits run through the
  normal pipeline.
- **The Landlord** (Town): shotgun volleys behind a cone telegraph, calls two
  goons; P2 flips tables into new cover and charges down a shown lane,
  smashing furniture and ending dazed against a wall; P3 enraged.
- **The Auditor** (City, rebuilt): fights from behind wheeled-in desks; a
  safe-wedge levy ring, a laser swept across the room (start line and arc
  shown first), drones; the AUDIT window doubles the stock crash from every
  hit; P2 teleports between desks (landing ring first) with two more desks.
- **The Ambassador** (World): diplomatic immunity while her bodyguards stand
  (a second detail returns once); rocket barrages with landing markers; P2
  gold-revolver fans and falling chandeliers.
- **The Chairman** (Doomsday): a giant ticker wall over the trading floor;
  P1 "Bull Market" volleys shaped like rising chart lines with a gap; P2
  "Margin Call" floor strips that follow a live price line (orange warning,
  then red); P3 "Liquidation" drains gold every second. His death wraps the
  heist up by itself and leads into the ending.
- **Lieutenants**: ordinary jobs keep a named elite ("KNUCKLES" BYRNE) and two
  of his crew in the boss room; he gets the boss bar once he joins the fight.
- Four boss-only weapons (Eviction Notice, The Red Pen, Diplomatic Pouch,
  Golden Gavel) that never enter the reward pools.
- `Meta` gained career stats (fire-exit escapes, bosses killed, best index,
  runs won, heists, gold, deaths) for Phase 9's unlocks.
- Deferred spawns (cash, reward cases, elite drops) are tracked by the floor
  so none can leak if the floor is torn down first.

## Phase 6 — Market mechanics

- **CONTRACT vs HIT** on every lead (about a third are HITs, from their own
  hash so seeds stay stable). A CONTRACT pumps the venue on success as before;
  a HIT inverts the tape — your hits and kills drive it down, damage you take
  props it up — and the grade crashes it (S+ −40% … a botched D actually
  lifts it). Green/red chips on the case files, the intro card and the job
  report.
- **Positions at the Fence**: a POSITIONS counter beside the three offers
  (which keep their reroll). Long or short any venue with a stake scaled to
  the quota block; every open position settles at the end of the next job:
  stake × (1 + 2 × move), inverted for shorts, floored at zero. Two slots
  (the Broker and a Market Maker perk get more). Positions are saved with the
  run, marked L/S on every ticker, listed on the case wall and settled on the
  job report with a P/L line (`positions.gd`, `positions_panel.gd`).
- **Live loot multiplier**: floor valuables pay value × clamp(price / base,
  0.5, 2.0) at the moment of pickup, as the HUD already showed.
- **Repeat-venue decay**: every extra CONTRACT on the same venue pumps ×0.65
  of the one before; the case file says so.
- **Market news** (`market_news.gd`): after every job a story breaks — a
  headline that moves a venue or a whole stage's sector now, or a RUMOR of a
  move that lands (usually) at the end of the next job, just before positions
  settle. Shown on THE WIRE clipping on the case wall, on the Fence's
  positions counter, in the heist chat and on the job report.
- Hideout prices and gold show `$` (the old gold glyph was missing from the
  fonts); map labels with a wrap width now actually wrap.
- The `Audio` autoload stops its players on shutdown (no leaked playbacks
  when the game quits mid-sound).

## Phase 7 — Objectives & map modifiers

- **Six objectives** (`objectives.gd`), weighted per stage, shown on the case
  file (with an icon), the intro card and the HUD tracker; failing an
  optional objective only costs its bonus:
  - **Loot** — the default.
  - **Assassination** — a named VIP (TARGET: "SAL" MORETTI) sits in a far
    room, marked on the minimap; a bounty and a jolt to the venue.
  - **Smash & Grab** — the alarm is ringing the moment you walk in; 2–3
    marked jackpot rooms hold three big valuables each; a lockdown seals every
    fire exit (never the main door) when its clock runs out.
  - **Ghost Run** — no kills and no witnessed alarms: a big venue move and a fee.
  - **Sabotage** — hold USE for 2 s at 2–3 marked points; each charge knocks
    the venue, and all of them crash it on the way out (doubly likely on HITs).
  - **The Package** — carry a case to the car at 85% speed.
- **Eight map modifiers**, 0–2 per lead (more in later stages), drawn as
  icons with tooltips on the case files and as chips on the intro card:
  Heavy Response (vans twice as often, loot ×1.5 — was ×2), Lockdown (fire
  exits sealed, grade swings ×1.5), Insider, Blackout (dark building, guards
  see 40% less), Camera Network (two cameras per room), Payday (loot ×1.5,
  guards ×1.3), Skeleton Crew (guards ×0.6, loot ×0.7) and **Rival Crew**:
  3–4 masked rivals who fight the guards and you (guards and rivals now pick
  targets by faction; no friendly fire within a side).
- **Strangers' tips**: from the City on, some leads hide their objective,
  contract and modifiers behind "???" unless you run a Recon Network.
- **The Black Market reacts** to the next leads' modifiers with gear for that
  job (always one slot when any applies): Night-Vision Goggles (Blackout),
  Signal Jammer (Camera Network), Police Scanner (Heavy Response), Bolt Cutters
  (Lockdown), Body Armor (Rival Crew), Duffel Bag (Payday).
- The screenshot tool takes `objective=`, `mods=`, `contract=` and
  `then=method:arg`.

## Phase 8 — Build identity

- **Relics** (`relic_item.gd`, `relics.gd`, `relic_hooks.gd`): twenty
  run-long relics kept in `RunState.relics` (saved), sold at the Black Market,
  found in every upgrade chest (one card of three) and offered by every stage
  boss next to his unique weapon. A `RelicHooks` node in the heist carries the
  kill / hit_taken / reload / room_cleared / heist_start / extract signals:
  Blood Ledger, Hair Trigger, Silent Partner, Golden Parachute, Adrenaline
  Futures, Hedge Fund, Pump & Dump, Insider Wire (vision cones), Laundered
  Cash (stacks), Fence's Discount, Lucky Casing, Stopping Power, Cold Feet,
  Getaway Driver, Back Door Man, Riot Insurance, Market Maker, Second Wind,
  Tracer Rounds and Paper Trail. Owned relics show as medallions under the
  HUD's objective panel.
- **Weapon mods** (`weapon_mods.gd`): Suppressor, Extended Mag, Laser Sight
  (with a visible laser), Hollow Points (armoured archetypes now flagged),
  Quick Hands and Incendiary (burning). One slot on small weapons, two on big
  ones; bought at the Black Market and fitted to the active weapon (or another
  with room); saved with the loadout and listed on the HUD weapon panel.
- **A signature trait for every weapon** (`weapon_traits.gd`), shown on the
  dealer's reveal cards and the chest detail: the Tommy Gun tightens under
  sustained fire, the Burst Carbine fires three-round bursts, the Snub .38's
  last round hits ×3, the Silenced 9mm is suppressed, the Hand Cannon
  pierces, the Squad LMG steadies but slows you, the Sawed-Off knocks back
  hard, Combat Shotgun pellets ricochet, the Marksman Rifle crits unnoticed
  guards ×3, the Street SMG reloads fast from empty — and the other fourteen
  (boss uniques included) have one each.
- The weapon dealer's reveal cards and sealed cases are drawn (no font glyphs);
  the HUD's LOOT figure now includes modifier and relic multipliers.
- The Fence's old "Golden Parachute" perk is shown as **Stop-Loss Order** so it
  does not clash with the relic (its id is unchanged for saves).

## Phase 9 — Characters & meta progression

- **All five specialists play as their cards say** (`CharacterProfile` gained
  trait fields; the crew `.tres` files carry them): the **Ghost** (2 hearts,
  silent movement and dodges, gunshots −40%, cameras half as fast, starts with
  a Silenced 9mm), the **Wolf** (4 hearts, +25% damage with fractions rounded
  by chance, getting hit makes a noise pulse), the **Broker** (2 hearts, every
  stock swing ×1.5, three positions at leverage 3, Fence −25%), the **Legend**
  (1 heart, never healed — no Patch Kits, Second Wind or Blood Dividend — gold
  and favourable stock moves ×2, starts with a random Classified-or-better
  gun). The Operator is unchanged.
- **Career tracking** across all three case files: fire-exit escapes, bosses
  killed (stage bosses and lieutenants), best index, runs won, heists, gold,
  deaths. Specialists unlock exactly as printed — 5 fire-exit escapes, 3
  bosses, index 350 in one run, a win — with progress on each locked card and
  a **NEW SPECIALIST** mugshot card on the job report or the front page.
- **Clout** replaces Intel and is earned at the end of every run (stages ×3,
  stage bosses ×2, index / 60, +8 for retiring; once per run). Older saves'
  Intel carries over as Clout.
- **Connections** (the renamed NETWORK board, also on the case-file screen):
  weapons for the reward pool, one starting perk — Fast Hands, Quiet Shoes,
  Cool Head, Seed Money (+$50), Friend at the Fence (a free reroll every
  hideout visit), Patch Kit (the first drop to 1 HP heals 1) — and four coat
  colours, with a crew column tracking every feat.
- The front page lists the Clout the run earned.

## Phase 10 — Story & endings

- **Prologue** (`prologue.gd`, `narration.gd`): four typewriter cards over the
  rainy skyline the first time a case file starts a run, a single line on every
  later run of that file. Tap finishes a line, the next tap moves on, SKIP or
  Esc jumps to the case wall.
- **Stage intro cards** (`stage_intro.gd`): each stage opens on the case wall
  with a manila card — stage, one line of narration, the boss waiting at the
  end of it and a NEXT TARGET stamp. Shown once per stage per run (saved with
  the run).
- **Vendors read the run**: new lines for open Fence positions, rumors on the
  wire, a coat full of relics, and the World and Doomsday stages, on top of the
  index/quota/grade/boss/health reactions. The collector's sit-down keeps its
  opening line, verdict and next-stage teaser.
- **Winning endings** (`ending_sequence.gd`): the city pans past while the
  epilogue types out, then the title slams down with the run's numbers, then
  the credits roll (`Story.CREDITS_NAME`, fonts and licence, Godot), then the
  NEW SPECIALIST card if the win unlocked the Legend, then home.
  **RETIRED** is the normal win; **THE NEW CHAIRMAN** plays when the Board
  index is at 800 or more when the Chairman falls (tuned by the balance sim). **BUSTED** keeps the front
  page.

## Phase 11 — Menus, pause, onboarding, settings

- **Pause screen** rebuilt to match the rest of the game: the job's case file
  (venue, objective as the HUD words it, conditions, heat, bag, time on the
  job) beside RESUME / SETTINGS / QUIT TO MENU, and a controls card for the
  hands on the controls right now. Quitting keeps the run; it resumes from
  the case wall. The touch PAUSE button hides while anything else has the game
  paused (job report, lobby terminal).
- **Onboarding hints** (`onboarding_hints.gd`): on a fresh save the first
  heists show one-time tips as their moment comes — move/aim, the provoke
  rule, shooting, reloading, loot, heat, the getaway car, fire exits. Each is
  remembered in the career save and never repeats; a new **Tutorial tips**
  setting turns them off. Tips name the right buttons for keyboard,
  controller or touch.
- **Settings** now cover Master / Effects / Music / Interface volume, screen
  shake, low effects, post-processing, dynamic shadows, reduce flashing,
  damage numbers, tutorial tips, fullscreen, frame cap and touch controls.
- **Controller**: the right stick now actually aims the gun (it only moved
  the crosshair before); with the stick at rest you aim where you walk. The
  last device used drives prompts, and every menu, vendor panel, terminal,
  the ending and the story cards can be driven with a pad (focus lands on the
  first control; any button advances a story card, START skips).
- The lobby **market terminal** got the stamped title treatment and shows
  venue names instead of internal ids.

## Phase 12 — Balance, performance, final QA

- **`tools/balance_sim.py`** (stdlib Python) re-verifies the economy with every
  income source: floor loot and room-clear gold measured in real buildings by
  **`tools/loot_census.gd`**, grade shocks with contract decay, a port of the
  live venue price during a heist, objectives, Fence positions, Market
  Manipulation, market news and boss shocks. Constants are read from the
  scripts. All invariants hold: two flawless heists reach index ~77 (p95 113)
  against the first gate of 120; two Market Manipulations on top reach ~189;
  a typical player already has the first $380 after one heist (median $774,
  $1264 after two, before spending), comfortably inside "about two heists";
  a $100 short plus a HIT on that venue pays ~$72 and costs ~14 index.
- **Live venue price fix**: a shock (a boss kill, a pump) fed the price's
  momentum so hard that it kept drifting tens of percent afterwards (+76% on
  one boss kill). Momentum is now capped at 1.2% per tick and shocks feed it
  a tenth as much, so a big event runs on by a few percent at most.
- **THE NEW CHAIRMAN** now needs index 800 (the sim puts ~90% of winners above
  600, ~25–30% above 800).
- **Performance**: sparks, bullet holes, casings and blood are pooled like
  bullets and damage numbers (fixed sets reused oldest-first). New
  **`tools/perf_bench.gd`**: 50 guards hunting the player on screen while he
  fires costs about 10 ms of CPU per 60 fps frame (base heist ~8.4 ms), with
  physics keeping real time; distance sleeping stays on.
- **F1 debug menu** (`debug_menu.gd`, autoload `Debug`; debug builds or
  `Log.DEBUG` only): add gold, set the Board index, jump to any stage or the
  Chairman's job, start any boss job, spawn any guard (or an elite) beside
  you, heal, kill the boss, max heat, and play BUSTED / RETIRED / THE NEW
  CHAIRMAN. Boss jobs and endings run as practice in the practice slot.
- **End-to-end test** (`tests/full_loop.gd`, in `tools/run_tests.sh` and CI):
  Home → case file → crew → prologue → stage card → hideout → heist → job
  report → Doomsday quota → the Chairman → ending → credits → NEW SPECIALIST
  → Home, through the real scene changes, with no errors.
- **Static sweep** (`tools/sweep.py`, in the test script and CI): resource
  paths, input actions, signal targets, guarded scene changes, tabs, no
  `Label2D`, no method named `bind`, no constructor passed as a Callable, no
  bare `print()` in game code. The sweep found nothing; the browser suite
  found one real bug (below).
- Fixed: pooled FX were built through `Spark.new`-style Callables, which the
  editor accepts but the exported Web build can't compile — caught by the
  browser suite before release.
- Removed three scripts nothing used any more (`contract_art.gd`,
  `hud_frame.gd`, `route_map_art.gd`).
- **TESTING.md**: every automated check, and a 10–15 minute manual route from a
  fresh career through each ending.

## Brief 2 · Phase 1 — Kill classes & feedback

- **`TimeController`** (autoload) now owns `Engine.time_scale`. Hit-stop,
  slow-mo and later kill/verdict moments are requests with a priority and a
  real-time duration: the strongest live request wins, they never multiply,
  the scale always returns to 1.0, and while the tree is paused the game runs
  at normal speed and no request is taken. `CombatFX.hit_stop/slow_mo` are thin
  wrappers; extraction and every scene change clear it.
- **Every death is classified** (`KillInfo`): STANDARD, CRIT (Marksman Rifle
  crits on unprovoked guards, any unprovoked victim, Hair Trigger shots),
  OVERKILL (2+ damage past the remaining health, point-blank shotgun blasts,
  the Hand Cannon), EXPLOSIVE (grenades, Volatile elites, props), BURN
  (Incendiary), TAKEDOWN (Phase 4), plus a MULTI count (2+ kills within
  0.4 s or from one trigger pull / one blast). Bullets, blasts and burns say
  how they hit through `note_hit()` before `take_damage()`.
- **Kill feedback** (`KillFeedback`): hit-stop per class (50 / 70 / 90 /
  120 ms), a camera punch toward the body, the crosshair's hit marker turns
  into a red X, a white kill-confirm flash on the body, and a DOUBLE /
  TRIPLE / MASSACRE banner above the weapon panel (a plain fade with Reduce
  flashing).
- **Death motion** (`corpse.gd`): bodies slide along the killing blow with
  friction and a little spin — further for overkills and heavy knockback,
  thrown by explosions — and stop dead at walls. The victim's gun leaves his
  hands and skitters away on its own path. Civilians fall the same way.

## Brief 2 · Phase 2 — Kill sounds

- `tools/gen_sfx.py` grew a kill bank (stdlib only, no voices): four flesh
  impacts, a bone crunch, a wet splatter, a gib burst, body falls on
  concrete / carpet / marble / metal, a weapon clatter, the kill-confirm
  tick, a crit ding, a burn sizzle, a muffled knife slash and a muffled
  crack for takedowns, and minor-key brass stings for DOUBLE, TRIPLE and
  QUAD+.
- Every death plays three layers — impact, body, fall — chosen by its class
  (gib burst for explosions, sizzle for burns, bone crunch plus splatter for
  overkills), with the fall landing a beat later on the stage's floor (Town
  concrete, City carpet, World marble, Doomsday metal) and the dropped gun
  clattering after it. The player's kills add the tick, the crit ding and
  the multi sting.
- A shared "death" voice group caps kill layers at six at once, on top of
  the per-sound limits and the usual pitch variance. Overkills, takedowns
  and explosions duck the music 3 dB for half a second (an Amplify effect on
  the Music bus, so the volume setting is untouched).

## Brief 2 · Phase 3 — Gore

- **Settings**: Gore off / low / full (default full) and Blood red / noir
  (ink-black with a red rim).
  - *Off*: sparks and dust puffs instead of blood; bodies fade after 3 s.
  - *Low*: spray particles and marks that fade after 8 s; no gibs, pools
    or footprints.
  - *Full*: everything below.
- **Sprays** (`gore.gd`): every hit throws droplets along the shot, more for
  bigger hits, and a pierced body throws an exit spray out the far side.
  Spray that reaches a wall paints it.
- **The building remembers**: settled marks are blitted into one texture per
  room (a floor layer under the bodies and a wall layer over the wall art),
  uploaded at most five times a second, so hundreds of marks cost about one
  draw call per room for the whole heist. Marks outside the rooms are live
  nodes capped at 60, oldest first.
- **Pools** spread under a body over two seconds, then bake. **Smears** trail
  a sliding body; a body that hits a wall splats it. **Drips** follow guards
  and civilians below 30% health, and the player at 1 HP.
- **Gibs** (full only) on overkills and explosions: 5–10 shards in the
  victim's coat colour and blood, sliding with friction, bouncing off walls
  (ray checks against layer 1 — no new physics layers), leaving trails, and
  settling into the floor. At most 80 at once; the oldest settles first.
- **Bloody footprints**: walking through a pool leaves twelve fading prints,
  for the player and for guards.
- **Blood vignette** (`blood_vignette.gd`): ragged blood creeps in from the
  screen edges as health drops and throbs with the heartbeat at 1 HP (the
  post-process red pulse still runs beneath it); follows the blood style.
- **Bodies are evidence**: bodies now stay for the whole heist (40 per
  building; the oldest leaves a dark shape baked into the floor). An
  unprovoked guard who sees one goes to look — investigating, not hunting —
  and radios it in if he finds a second. Civilians who see a body panic.
  With the Ghost's slow cameras guards also take half again as long to take
  a body in.

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
- **Dodge tuning kept** (0.25 s i-frames, 0.6 s cooldown, sprint noise): the
  roll already existed; only its feel changed.
- **Audio format.** Generated WAVs are imported with QOA compression; loops are
  set at runtime (loop_mode on a duplicate) so the files need no import
  overrides.
- **Heist music is layered, not switched,** so heat changes never restart the
  track.
- **"Stage 2+" for elites** is read as the second stage (the City) onward;
  Town only sees an elite on its rarest jobs.
- **Radio calls**: a hit knocks the call back half a second instead of
  cancelling it, so only a kill reliably stops the heat (per the brief).
- **Alarm panels are sparse** (1–3 per building instead of one per room), so
  a witnessed intrusion arms the *nearest* panel. A second full alarm within
  25 s only adds heat, so several techs cannot chain vans.
- **Civilian deaths** caused by guards' grenades still add heat (+6) but do
  not count against the crew's grade or the venue.
- **Boss payouts** come from the cash burst on the floor rather than a
  direct bonus, so the money is visibly there to pick up; the Chairman pays
  directly because the run ends with him.
- **Boss rewards are weapons for now**: relics arrive in Phase 8 and join the
  boss drop then.
- **The Marlowe Exchange scene** was replaced by layout data; the room names
  (Lobby, Auditor, Records, Vault…) are unchanged so saves and tests agree.
- **Positions settle at every extraction**, i.e. at the end of the job that
  follows the hideout visit where they were opened; dying forfeits them.
- **The in-heist terminal short stays** alongside Fence positions: it is a
  one-job bet on the venue you are robbing, settled at the combat price.
- **Rumors are the tradeable news** (75% reliable); headlines move prices
  immediately and mostly set the scene.
- **Boss jobs are always CONTRACTs**; the boss's own shock follows the tape
  direction (inverted while a short targets the venue).
- **"Alarms" for a Ghost Run** means any witnessed report: a camera spotting
  you, a guard's radio call, or someone pulling an alarm panel.
- **Rival crew kills are not paid or counted** toward the grade; nobody hired
  you for them.
- **Next-job gear** is a stand-in for the relics that arrive in Phase 8; it is
  consumed by the job it was bought for.
- **Relic stacking**: only Laundered Cash stacks, as the brief says; the rest
  are unique per run and leave the pools once owned.
- **Boss rewards**: the reward case offers the unique weapon and a relic of
  Covert grade or better; you take one.
- **Mods are fitted automatically** to the active weapon (or the first other
  weapon with room) so buying one is a single tap on a phone.
- **Clout replaces Intel entirely** (the brief's run-end currency); jobs no
  longer pay a per-extraction meta currency. The beta's built "rooms" left the
  catalog, but a player who built Crew Quarters keeps the Wolf and Broker.
- **A met feat counts as hired** even before the NEW SPECIALIST card has been
  shown (e.g. progress made by an older build).
- **Prologue trigger** is the crew card that starts a new run (not
  `RunFlow.start_new_run`), so tests, the practice job and screenshots never
  see it. "First run" is tracked per case-file slot in the career save.
- **The ending owns the screen**: the heist under it is disabled and its HUD
  hidden until the ending hands off to the home screen.
- **THE NEW CHAIRMAN threshold** is index 800, not the brief's "~600": the
  balance sim puts ~90% of winning runs above 600 but ~25% above 800, and
  "about a quarter of wins" is the intent.
- **Tips use the HUD's fonts.** A tip card in a new font size stalled a frame
  long enough on software-GL phones to cost a player a quarter-second of
  movement; reusing the HUD's already-rendered font/size pairs removed it.
- **Browser suite waits for state**, not fixed timeouts, at the two touch steps
  that depend on frame rate (software-GL Chromium runs the game at ~12 fps).
- **Debug menu gate**: "only when DEBUG" is read as debug builds (editor runs
  and debug exports) or `Log.DEBUG`; release exports never open it.
- **Debug jobs are practice**: boss jobs and endings started from F1 run in
  the practice slot, so they can't overwrite a case file or the career.
- **Performance target** is measured as CPU time per frame in a headless
  bench (no GPU in CI); ~10 ms with 50 hunting guards leaves the renderer
  ~6.7 ms for 60 fps.
- **Browser suite waits on frames**, not milliseconds: the QA probe reports
  the frame counter and every tap waits for the game to advance.
- **(Brief 2) Branch.** The brief asks for `brief-2`; this session's git setup
  designates `codex/mobile-web-beta`. Work is committed on `brief-2` and the
  same commits are pushed to both branches.
- **(Brief 2) MULTI window** runs on game time, so kills that land during a
  hit-stop still chain.
- **(Brief 2) Kill feedback is for the player's kills**: guards and rival
  crews killing each other still get classified bodies and death motion, but
  no hit-stop, punch or banner.
- **(Brief 2) Floor sounds follow the stage**, not the individual room:
  every stage has one dominant floor material in its art.
- **(Brief 2) Gore needs no post-processing**: the blood vignette is its own
  overlay, so it works with Post-processing off (and hides with Gore off).
- **(Brief 2) Decal resolution** is half the world resolution (one texel per
  two pixels): sharp enough for blood, a quarter of the memory.
- **(Brief 2) Corpses no longer fade** after 22 s — they're evidence now —
  except with Gore off.
