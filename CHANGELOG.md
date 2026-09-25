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

## Brief 2 · Phase 4 — Takedowns

- New **`melee`** action: F, right mouse, pad B, and a MELEE touch button
  (checked at start-up like every other action). A prompt ("F · TAKEDOWN" /
  "F · EXECUTE", with the right button for your device) appears over the
  guard in reach, and a one-time tip explains both moves.
- **Stealth takedown** (`takedown.gd`): from behind — within 45 px and 110°
  of his back — on an unprovoked guard: a 0.45 s knife, invulnerable while
  it lands, and no noise at all (the body makes no sound for guards to
  hear). Not on Brutes, turrets, drones, lieutenants or bosses; a riot
  shield only covers the front.
- **Stagger**: a guard hit into his last quarter of health (a Brute: his
  last tenth; always at least his last hit point) staggers for 1.2 s — no
  moving, no shooting, a wobble and a flashing outline with a pulsing ring.
  Bosses never stagger.
- **Stagger execution**: melee on a staggered guard is a 0.5 s point-blank
  shot with the equipped gun — loud unless it's suppressed — refunds two
  rounds and is always an OVERKILL (full gore).
- **Ghost Run** now allows silent stealth takedowns; any other kill still
  blows it.
- Career stats count takedowns (both kinds).

## Brief 2 · Phase 5 — THE RALLY (combo)

- **Combo** (`combo.gd`): the first kill starts it, each kill adds points and
  refreshes a 2.5 s window. Points: kill 1 · each extra multi-kill victim +1
  · overkill +1 · crit +1 · stealth takedown +2 · stagger execution +3 ·
  explosive-prop kill +2 · last round in the mag +1 · during or 0.5 s after a
  dodge +1 · at 1 HP +2 (Margin Call) · unaware victim +1 · variety (a weapon
  or method unlike the last two kills) +1.
- **Tiers**: TICK x1 → RALLY x1.2 (5) → BULL RUN x1.5 (12) → SURGE x2 (22) →
  FRENZY x2.5 (35) → BLACK SWAN x3 (50), each with its sting, a slam and a
  colour on the combo panel.
- **The market rallies with you**: while a combo is live each kill's stock
  gain is multiplied by the tier.
- **Cash out** when the window runs out: points × multiplier × a base that
  grows with the quota block, plus a small venue move ("COMBO CASHED — 27 pts
  · BULL RUN · +$84 · +0.8%"). **PANIC SELL** on taking damage: 75% of that
  gold is gone, with a red slam and a crash. A live combo cashes out as you
  extract.
- **HUD**: a right-edge combo panel — count, tier, multiplier and take, the
  draining window, the last few bonuses — hidden when no combo is live.
- **Grade & meta**: the best combo and the points cashed nudge the heist
  grade a little and appear on the job report; the run's best combo is
  saved, tracked in the career, and adds up to +3 Clout.
- **Relics**: Momentum Trader (+1 s window), Dead Cat Bounce (the first hit
  during a combo doesn't break it, once per heist), Compound Interest (tiers
  20% sooner), Blood Money (every tier-up drops a little cash), Short Fuse
  (explosive props +50% damage, explosive kills +1 point). 25 relics now.
- **Specialists**: the Wolf's window is 0.5 s longer, the Ghost's stealth
  takedowns are worth a point more, the Broker's cash-outs pay 1.25x (gold
  and stock), the Legend's tier multipliers are 1.5x.
- **Explosive props** (`explosive_prop.gd`): gas cans, fuel drums and fuse
  boxes, 0–3 per room by stage (never in boss arenas, never in a doorway
  corridor, next to a spawn point or a loot slot, never cutting a room off).
  They stop bullets on layer 1, go up when shot (guards' rounds too), hurt
  everyone in range, set each other off, gib, scorch and are heard across
  the floor.
- **Balance**: combo gold per heist is capped per stage ($140 / $205 / $355 /
  $560 — about 35% of a thorough heist's floor loot); `tools/balance_sim.py`
  now simulates the combo (gold, the market multiplier and cash-out moves)
  and checks the cap.

## Brief 2 · Phase 6 — Wanted & adaptive music

- **WANTED stars** (`wanted.gd`): heat now reads as 0–5 stars beside the heat
  bar — 1★ at 4, 2★ 8, 3★ 12 (the moment the fire exits seal), 4★ 20, 5★ 30.
  A marked boss forces at least 3★. Every star gets a sting, a siren blip and
  a "WANTED LEVEL n" chip; at 5★ the stars flash police red and blue (steady
  with Reduce flashing).
- **Laying low** replaces the old steady heat decay: after 20 s with nobody
  hunting you, heat drifts down 0.2/s — but never below the floor of the
  stars you've earned. Disabling security obeys the same floor.
- **The street reacts**: 3★ distant sirens; 4★ two police cruisers park up
  and down the street from the getaway car, light bars going, sirens close;
  5★ a helicopter searchlight laps the outside of the building. Standing in
  it stops the getaway car's clock ("SPOTLIGHT — wait for the dark") and
  shows you to every guard outside within 900 px.
- **Adaptive music** (`tools/gen_music.py`, `audio.gd`): every stage has its
  own explore / tension / combat stems in its own key and tempo (Town 96 BPM,
  City 104, World 112, Doomsday 124) over shared drum, Wanted (3★/4★/5★) and
  combo (BULL RUN+, FRENZY+) layers. Layers fade in and out on bar
  boundaries so nothing ever restarts; tier and star stingers land on the
  next beat; the music ducks under boss intros and big moments.
- **Boss themes**: each boss has a theme and a phase-two layer that comes in
  with his second phase; the stage music returns once he's down. New themes
  for the verdict, the map and all five ending families (rule, escape,
  collapse, retire, busted); the old heist, boss and ending tracks are gone.
- **Dynamic music** setting (on by default): off keeps a single calm mix
  (explore + brushed drums) in every heist.
- Settings panel: Gore and Blood choices sit under the frame-rate and touch
  choices; Tutorial tips and Dynamic music joined the toggles.

## Brief 2 · Phase 7 — Boss verdicts

- **Bosses kneel** (`boss.gd`): at 0 HP the three stage bosses and the
  Chairman drop to their knees instead of dying — hands up, gun skittering
  away. The arena stays sealed, every guard still standing drops his gun,
  puts his hands up and STANDS DOWN, time swells (a TimeController moment),
  the music ducks into the verdict theme and the objective says to walk up.
  Bullets can't finish him; only a verdict can.
- **The VERDICT card** (`verdict_card.gd`, press USE next to him): his name,
  his plea, your FEAR / LOYALTY / GREED, and the options as cards (keys 1-4,
  a pad or a tap). It pauses the heist while it's up.
  - **EXECUTE** — a 1.1 s point-blank finisher with his own name (EVICTED,
    AUDITED, IMMUNITY REVOKED), maximum gore, the full stock shock, his cash
    and his unique gun, +1 Fear.
  - **FLIP** — he walks out working for you: the Landlord's Safehouse Rent
    (gold at every hideout visit), the Auditor's Cooked Books (damage crashes
    25% smaller) or the Ambassador's Diplomatic Cover (WANTED capped at 4
    stars). Half the shock, +1 Loyalty, and the Board gets suspicious: every
    heist of the next stage starts at 1 star.
  - **SHAKE DOWN** — 60% of the stage's gold quota and his relic: the Deed
    Box (+1 max HP), the Black Ledger (the wire's next story one heist
    early, breaking at the end of the next job; +1 position leverage) or the
    Diplomatic Pouch (the first alarm each heist goes nowhere). No shock,
    +1 Greed. Boss relics never enter the pools.
  - **TAKE HIS DEAL** — ends the run on the spot with his early ending; the
    card shows the buyout (150% of the stage quota) and the Clout. Not on a
    practice job.
- **The finale remembers** (`ally.gd`, `chairman_boss.gd`): every flipped
  boss arrives to fight beside you against the Chairman (a simplified gun,
  draws the guards' fire, DOWN for 20 s instead of dying); every executed
  boss's crew comes for revenge (one wave each, +10% damage per execution
  while they're up); every shaken-down boss sabotages a phase (Deed Box: he
  starts 15% down; Black Ledger: no Liquidation drain; Diplomatic Pouch:
  Margin Call strips half as wide).
- **The Chairman's verdict**: TAKE THE SEAT (the finisher: DELISTED), BURN
  THE BOARD (the Exchange goes up and every venue crashes to 55%; your open
  shorts are what's left) or WALK AWAY (he stays on his knees). The last job
  then wraps itself up.
- **Endings are data** (`endings.gd`): all eleven, in gallery order, with
  titles, epilogues, stamps and music families; the Chairman's verdict and
  your stage verdicts pick the final one. A deal plays its boss's early
  ending, pays reduced Clout and counts as an early ending, never as a won
  run (so it never unlocks the Legend).
- Verdicts, the Chairman's verdict, reputation, suspicion, rent and the
  Black Ledger's story are saved with the run (old saves load clean).
- Career: verdict counts and early endings.

## Brief 2 · Phase 8 — Endings & gallery

- **Eleven endings** (`endings.gd`), resolved in the brief's order: three
  early ones from a boss's deal (THE LANDLORD'S CHAIR, COOKED BOOKS,
  DIPLOMATIC EXIT) and eight after the Chairman (BLACK MONDAY, SCORCHED
  EARTH, THE SYNDICATE, THE PURGE, THE PUPPETEER, THE NEW CHAIRMAN, A SEAT
  AT THE TABLE, RETIRED).
- **Every ending** types out 4 epilogue cards over the rain, then its title,
  kicker and stamp over a **procedural final image** of its own
  (`ending_art.gd`: a chair in the Landlord's doorway, the Auditor's two
  columns, a beach at dusk, a gold line rising out of a burning skyline, a
  round table, an empty one, marionette strings, the lit top floor, a chair
  ringed by the Board's eyes, a balcony at sunrise), plays its family's
  theme (rule / escape / collapse / retire), and lists the run's numbers,
  its verdicts and the Chairman's, then the credits.
- **BUSTED variants**: the front page's headline now names what got you —
  each boss, the kind of guard (sniper, dog, riot shield, turret...), a
  five-star manhunt, an explosion, a rival crew or a lieutenant — and the
  story says where (the room and the building).
- **CASE CLOSED** (home screen): a card per ending plus BUSTED. Reached
  endings show their image, title and count; the rest are dark silhouettes
  with a one-line hint once you've reached any ending. The first time you
  reach an ending pays +5 Clout (+3 for an early one).
- **Career**: endings seen (and busts), early endings, verdict counts. The
  Legend now unlocks on any final ending; an early ending never counts.

## Brief 2 · Phase 9 — Settings, performance, balance, QA

- **Settings in tabs** (SOUND / DISPLAY / EFFECTS / HUD) so everything fits
  a phone in landscape; new: Combo panel size (75-150%), alongside Gore,
  Blood style and Dynamic music. Every Brief 2 effect honours Screen shake
  (trauma and punch are scaled by it) and Reduce flashing (banners, tier
  slams, star flashes, sirens' lights and now the kill-confirm flash).
- **Performance**: `tools/perf_bench.tscn -- variant=massacre` runs 50
  hunting guards with Full gore while five of them die violently every 20
  frames: ~9.7 ms of CPU per 60 fps frame, p99 ~13 ms, with the caps holding
  (40 bodies — the oldest baked into the floor — and 80 gibs).
- **Balance**: `tools/balance_sim.py` now simulates verdicts (EXECUTE's full
  shock and cash, FLIP's half shock with Safehouse Rent / Cooked Books,
  SHAKE DOWN's quota share with the Black Ledger's leverage) and deals.
  Win rates for all-execute / all-flip / all-shake runs sit within 6 points;
  deals pay 11 / 18 / 26 Clout against ~41 for a won run.
- **Debug menu**: set every stage boss's verdict, play any of the eleven
  endings or eight BUSTED front pages; in a heist, combo points and tiers,
  a panic sell, WANTED 0-5, a gore dummy, an explosive prop, FORCE KNEEL and
  the VERDICT card.
- `TESTING.md`: the Brief 2 checklist (kill feel, gore, evidence, takedowns,
  combo break vs cash-out, stars 0 → 5 and the music, verdicts, the finale,
  routes to every ending, CASE CLOSED).

## Brief 3 — Noir Props HUD

The in-heist HUD and its overlays in a new visual language: props on the heist
table for vitals and information, pulp slants for action, and the ticker tape
as the one straight strip across the top. No information was removed
(`PROGRESS_3.md` maps every element to its new form).

- **Props** (`hud_props.gd`): health as a poker-chip stack (gold chips for
  bonus max HP; a hit flips the top chip off with a clack, a heal drops one
  on, the last chip wobbles and glows at 1 HP); cash on a banknote in a brass
  money clip (three stack tiers, bills riffle and the number rolls up on a
  gain, a bill slides out on a spend) with the loot multiplier on a swinging
  luggage tag; the gun as a silhouette with its rounds as real cartridges (a
  revolver's cylinder, a shotgun's shells), a cartridge box for the reserve
  or a stamped infinity, rounds ejecting on each shot, refilling one by one on
  a reload, a card-flip on a swap; relics as matchbooks fanned along the
  bottom with hover tooltips.
- **Paper and machines** (`hud_paper.gd`, `typewriter_key.gd`): the objective
  on a torn, paperclipped notepad page (red-pencil strike-through and a fresh
  note sliding in; Smash & Grab clocks in red, ticking in place); the minimap
  on a folded blueprint with a pushpin and a torn corner; the venue's chart on
  ticker tape curling out of a glass-dome ticker machine (stamped name,
  red-pencil quota with the gap scribbled on, gold-ink index); the trader feed
  as pasted telegram strips; MAP and PAUSE as round typewriter keys; tips as
  torn manila notes; the ticker as a perforated paper strip.
- **Pulp** (`hud_pulp.gd`): a slanted, hatched heat bar with police notches,
  a green EXIT sign and five police badges that flash on a new star; THE
  RALLY as an italic count on a skewed slab with a halftone burst, a slanted
  tier banner and a draining skewed bar (speed-line slam on a tier-up, torn
  apart by a PANIC SELL); DOUBLE / TRIPLE / MASSACRE on skewed banners (an
  impact star for MASSACRE); captions on a slant; damage numbers in pulp
  italics (crits get an impact star); market chips as fluttering ticker slips;
  the boss bar as a long skewed bar with a slanted title card that cracks and
  shatters when the boss kneels; the VERDICT card as his case file with four
  rubber stamps, the chosen one slamming onto the file.
- **World prompts** (`world_prompt.gd`): terminal, alarm panel, camera,
  charge, package and reward-case prompts, guard takedown / execute prompts
  and the boss's verdict prompt as a typewriter key cap with a skewed label;
  guard tags on small skewed slabs.
- **Screen effects**: low health is an ink bleed creeping in from the edges
  (red with the Red blood style, pure ink with Noir); the crosshair's reload
  ring is a spinning revolver cylinder.
- **Settings** (HUD tab): HUD style (Noir Props / Minimal — frameless,
  outlined text and icons), HUD scale (75-150%, each corner cluster scales
  about its corner), HUD opacity (50-100%), Reduce motion (no idle wobble,
  riffles, flutters or slides; values update at once). Reduce flashing also
  holds the badges, the police-light bar and every slam steady.
- **Tooling**: `tools/hud_preview.tscn` cycles every element through every
  state; F1 → HUD SHOTS saves the HUD in a lit room, a dark room, outside in
  the rain, at 1 HP, in a FRENZY and in a boss fight to `user://hud_shots/`
  (also `tools/screenshot.tscn -- shot=heist hudshots=1`).
- **Performance**: props redraw only when their value changes or while an
  animation runs; halftone and paper grain are baked textures; the perf bench
  still costs ~9.8 ms of CPU per 60 fps frame with 50 guards and Full gore.

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
- **(Brief 2) Stagger threshold with whole-number health**: "below 25%" is
  read as the last quarter of max health rounded, and never less than the
  last hit point — otherwise three-hit guards could never stagger.
- **(Brief 2) Ghost Run rule change**: silent stealth takedowns no longer
  fail it; gunfire (and explosion) kills still do.
- **(Brief 2) Executions refund rounds** up to a full magazine; they don't
  spend one.
- **(Brief 2) The combo's cash-out venue move is small** (0.3% + 0.02% a
  point, at most 1%): with the market multiplier on kills, bigger moves let
  two combo-perfect heists clear the first stock gate on their own.
- **(Brief 2) Stock-gate invariant with combos**: the sim's median and p75
  for two flawless heists stay below 120; the tail (p90 ~136) can reach it
  with near-perfect combo play, since THE RALLY's market multiplier rewards
  exactly that.
- **(Brief 2) THE NEW CHAIRMAN threshold** is now index 840: combos raise
  winners' final index, and 840 keeps it at about a quarter of wins.
- **(Brief 2) Explosive props sit on layer 1 (WALLS)** as the brief asks; they
  are Props, so the wall art never paints them as walls.
- **(Brief 2) Stage stems share one tempo on disk.** The shared layers
  (drums, Wanted, combo) are written once at 96 BPM and pitch-scaled to each
  stage's tempo; each stage's own stems are written at the same frequency
  ratio, so every layer stays in tune and the audio budget stays ~29 MB.
- **(Brief 2) Stem sync without AudioStreamSynchronized**: the stems are
  separate players started on the same frame and nudged back into step when
  they drift (at most once a second). The synchronized stream was avoided for
  the Web build's sake.
- **(Brief 2) Boss and ending themes are four-bar loops** with a denser
  phase-two layer, again to keep the download small.
- **(Brief 2) Stars never drop during a heist**; laying low only cools heat
  down to the current star's floor. Fire exits therefore stay sealed once
  3★ is reached.
- **(Brief 2) No star glyph in text**: the stars are drawn shapes; chips say
  "WANTED LEVEL 3" because the shipped fonts have no ★.
- **(Brief 2) Cruisers park along the street** (up and down from the getaway
  car), never across it, so they can't land inside the building.
- **(Brief 2) Verdict payouts.** SHAKE DOWN pays 60% of the stage's gold
  quota plus the relic; Safehouse Rent is $40 × (1 + quota block) per
  hideout visit; a deal buys you out for 150% of the quota and +3 Clout on
  top of the run's usual award (a won run still earns more: +8 and all four
  stages). EXECUTE keeps the old boss payday (cash burst, unique gun, full
  shock); FLIP pays nothing up front.
- **(Brief 2) "The next stage starts at 1 star"** is every heist of that
  stage: a star is only a heat floor of 4, so one heist would barely register.
- **(Brief 2) Shaken-down sabotage follows the verdict**, not the relic, so
  the Chairman's weaknesses always match what you did to his bosses.
- **(Brief 2) Guards who stand down stay standing down** for the rest of the
  heist; vans that arrive afterwards are fresh and fight. They can still be
  shot, but they count as provoked (no UNAWARE or CRIT bonus for it).
- **(Brief 2) Allies are drawn to guards' fire only.** Guards pick the
  nearest of you and your allies; bosses keep their attacks on you. Allies
  don't melee and never count as your kills.
- **(Brief 2) BURN THE BOARD crashes every venue to 55%**, and BLACK MONDAY
  needs $400 of profit across your open Fence shorts and terminal short at
  that moment.
- **(Brief 2) "Kills" of kneeling bosses**: the career's bosses-put-down
  count (the Wolf's feat) counts every verdict except a deal.
- **(Brief 2) Brief 3 arrived mid-Brief 2**: Brief 2's remaining phases are
  finished first because Brief 3 restyles the verdict card and the kneel
  that Brief 2 introduces; Brief 3 then starts on `brief-3` from there.
- **(Brief 2) The Legend's feat is "reach a final ending"**: `runs_won`
  only counts endings 4-11, so the old feat reads the same data.
- **(Brief 2) Epilogues are four cards each** (the brief allows 3-5) so
  every ending takes about the same time to reach its title.
- **(Brief 2) Busts are in the gallery too** as a twelfth card, counted from
  the career's deaths, so the grid reads as a full case wall.
- **(Brief 2) "What got you"** is the last thing that hurt you: the round's
  shooter, a blast, a boss's hazard. At five stars any non-boss, non-blast
  death is reported as the manhunt.
- **(Brief 2) Settings became tabs**: with Gore, Blood, Dynamic music and
  the combo size the single page no longer fit 720 px (and Brief 3 adds HUD
  settings); the browser suite now taps DISPLAY before Low effects.
- **(Brief 2) The frame budget is measured on the CPU** (headless, no GPU),
  as in Brief 1: the massacre bench's p99 is the number that matters.
- **(Brief 3) Modal menus keep their menu styling**: the pause menu, the
  reward-case reveal, the lobby terminal and the tactical map are full-screen
  menus rather than HUD; only their triggers (the MAP / PAUSE keys and the
  world prompts) took the new form.
- **(Brief 3) Layout on other aspect ratios**: the project letterboxes
  (`stretch/aspect = keep`), so the 1280x720 canvas always holds; the HUD
  still anchors every cluster to its screen corner from the root's size, so
  it would also hold with an expanding canvas.
- **(Brief 3) Touch layout**: with touch controls on screen the thumbs own
  the bottom corners, so the vitals sit under the objective, the gun at the
  bottom centre, the combo on the left, and the trader telegrams step aside
  for the MELEE button (the chatter is flavour, not information).
- **(Brief 3) Chip count**: the stack also carries a typed "xN" — counting
  poker chips at a glance mid-fight is harder than it looks.
- **(Brief 3) The ink bleed shows with Gore off too** (as pure ink): it is a
  health warning, not blood.
- **(Brief 3) Inner classes never name their own script's class**: an inner
  class calling `OwnScript.helper()` made the script hold itself and leak at
  exit, so shared helpers live in `HudKit` / `Verdicts`, and MAP/PAUSE's key
  is its own script (an inner-class node in an autoload leaked the same way).
