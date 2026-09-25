# Testing Stock Rogue

## Automated checks

Run these from the project folder (Godot 4.6.1 on the `PATH` as `godot`).

| Command | What it proves |
| --- | --- |
| `tools/run_tests.sh` | Static sweep, clean import, settings and career saves surviving separate processes, the gameplay smoke suite (~1300 checks), then the **full loop**: Home → case file → crew (prologue) → case wall (stage card) → hideout → heist → job report → Doomsday quota → the Chairman on his knees → VERDICT: TAKE THE SEAT → THE NEW CHAIRMAN → credits → NEW SPECIALIST → Home. Fails on any `ERROR:` in the logs. |
| `tools/check.sh` | Every script compiles. |
| `python3 tools/sweep.py` | Every `res://` path exists, every input action the code reads is defined, every signal target exists, scene changes are guarded, tabs only, no `Label2D`, no method named `bind`, no constructor passed as a Callable, no bare `print()` in game code. |
| `python3 tools/balance_sim.py` | The economy invariants: two flawless heists don't clear the first stock gate but two Market Manipulations on top do, the first gold gate is reachable in about two heists, a short plus a HIT is profitable but costs index, combo gold stays under ~35% of floor loot, THE NEW CHAIRMAN is about a quarter of wins, no verdict policy dominates, and a boss's deal pays less Clout than a won run while staying tempting. Reads the constants from the scripts and the loot census. |
| `godot --headless --path . res://tools/loot_census.tscn` | Rebuilds `tools/loot_census.json` (money in real buildings per stage). Rerun after changing rooms, props or loot. |
| `godot --headless --path . res://tools/perf_bench.tscn` | 50 guards hunting the player in a World heist while he fires: CPU cost of a 60 fps frame (about 10 ms of the 16.7 ms budget on the CI machine) and physics keeping real time. Add `-- variant=massacre` for Full gore: five violent kills every 20 frames (sprays, gibs, pools, bodies) with the crowd kept at 50; it reports the frame p99 and the corpse / gib caps. |
| Web: `rm -rf build/web && mkdir -p build/web && godot --headless --path . --export-release Web build/web/index.html && python3 web/prepare_web.py && node tests/browser.mjs` | The exported Web build on a phone-sized touch screen: settings, Connections purchases, a practice heist with two-finger touch, the lobby terminal, pause, a new case file with the prologue and stage card, the hideout, a heist choice, resume after reload. |
| `godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- shot=<preset> out=<png>` | Renders any screen (see `tools/screenshot.gd` for presets and options such as `pause=1`, `debug=1`, `hint=<id>`, `terminal=1`, `shot=ending id=<ending> part=title`, `shot=heist boss=landlord teleport=boss then=debug_kill_boss card=1`, `heat=34`, `kills=3`, `gore=0/1/2`, `blood=0/1`, `shot=death cause=police`, `shot=home then=_on_gallery`, `tab=EFFECTS`). |

## Manual route (10–15 minutes)

Start from a **fresh career**: delete the game's user folder
(`~/.local/share/godot/app_userdata/Stock Rogue` on Linux,
`%APPDATA%\Godot\app_userdata\Stock Rogue` on Windows,
`~/Library/Application Support/Godot/app_userdata/Stock Rogue` on macOS; in a
browser, clear the site's storage). Run from the editor or a debug export so
**F1** opens the debug menu.

1. **Launch.** Rain on the office window, blinking skyline, ticker along the
   bottom. Hover and click buttons: every one ticks and clicks.
2. **Settings.** Move each volume slider (music and effects change as you
   drag), toggle post-processing, reduce flashing, damage numbers, tutorial
   tips. Back out and reopen: everything stuck.
3. **PLAY → case file 1 → crew wall.** Only the Operator is hired; the Ghost,
   Wolf, Broker and Legend show their feat and progress. Pick the Operator.
4. **Prologue.** Four typewriter cards over the rain. Tap to hurry a line, tap
   again to move on (or SKIP). The case wall opens with the **TOWN** card:
   narration, the Landlord teaser, NEXT TARGET stamp. OPEN THE CASE.
5. **Case wall.** Stage header, collector's note (gold and index needed), the
   wire, red string along the route. ENTER HIDEOUT.
6. **Hideout.** Walk to each vendor. Weapon Dealer: open a sealed case (strip
   spin, rarity reveal). The Fence: market operations and Fence positions.
   Black Market: relics, a mod and job gear. Vendors comment on your run.
   Walk out to the job board.
7. **Heist choice.** Two to four pinned case files: venue, CONTRACT or HIT,
   objective, modifier icons (hover for details). Pick one.
8. **Heist.** Intro card, then the street: the car, rain, the neon sign.
   Tips appear under the heat bar as their moment comes (move, guards wait,
   shoot, reload, loot, heat, the car, fire exits) — each only once per save.
   Walk in, wake a room, fight: shake, hit-stop, casings, damage numbers,
   the venue's price moving with every hit. Press **Esc**: the job's case
   file, RESUME / SETTINGS / QUIT TO MENU and the controls. Use the lobby
   terminal once. Bag some loot and extract at the car (hold still) or a
   green fire exit while heat is low.
9. **Job report.** Grade stamp, loot, contract, objective, positions, the
   stock move. Continue to the case wall.
10. **Second hideout and heist**, then the **Landlord**: shutters seal the
    arena, intro card, boss bar, telegraphed attacks and phases. He drops his
    unique weapon and a relic; the car leaves only once he's down.
11. **Quota sit-down.** Check the collector's note first: if you're short,
    F1 → +$5000 or INDEX 120 *before* sitting down — failing him ends the
    run (BUSTED, front page). He opens the books, reads the numbers, signs
    off. MOVE UP TO THE CITY → the City card.
12. **Skip ahead.** F1 → THE CHAIRMAN'S JOB. Fight him (ticker walls, margin
    floor, chart volleys) or F1 → FORCE KNEEL. Walk up, press USE, choose a
    verdict (TAKE THE SEAT / BURN THE BOARD / WALK AWAY), take the job report.
13. **Ending.** The city pans past while the epilogue types out; the title,
    its final image, your numbers and verdicts; the credits roll; on a first
    final ending the **NEW SPECIALIST: THE LEGEND** card; then home.
14. **Every ending.** F1 → EARLY / FINAL rows play any of the eleven endings;
    the BUSTED row plays each front-page variant. Debug endings run as
    practice and leave the career alone. Home → CASE CLOSED shows what you've
    reached (from a real run; debug endings don't count).
15. **Controller (optional).** With a pad: navigate the menus, left stick
    moves, right stick aims (at rest you aim where you walk), RT fires,
    LB rolls, X reloads, START pauses; the pause card and tips show pad
    buttons.
16. **Phone / Web (optional).** Landscape: left thumb moves, right thumb aims
    and fires, DODGE / RELOAD / SWAP / USE / MAP / PAUSE on screen.

## Brief 2 checklist (kill feedback, gore, combos, wanted, verdicts, endings)

Run from the editor or a debug export (F1 = debug menu).

1. **Kill feel.** Shoot guards: a hit marker, a red X and a tiny hit-stop on
   each kill; overkills (shotgun point-blank, 2+ excess damage) throw the
   body and shake harder; crits ding; explosions launch; burning guards
   sizzle. Two or three kills from one shot: DOUBLE / TRIPLE / MASSACRE.
   Each floor (Town concrete, City carpet, World marble, Doomsday metal)
   has its own body-fall sound. Settings → EFFECTS → Reduce flashing: the
   banners fade instead of slamming and the body flash dims.
2. **Gore.** F1 → GORE → GORE DUMMY, then shoot it. Full: sprays, wall
   splatter, gibs on overkills, a pool under the body, footprints when you
   walk through it; the marks stay for the whole heist. Settings → EFFECTS →
   Gore: low (short-lived marks, no gibs) and off (sparks and dust, bodies
   fade after 3 s). Blood: noir turns it ink-black with a red rim. At 1 HP
   the screen edges bleed (hidden with Gore off).
3. **Evidence.** Leave a body where a patrol will see it: he stops, walks
   over, shows BODY?, and a second body gets a radio call (+heat).
4. **Takedowns.** Sneak behind an unaware guard: the prompt reads F /
   MELEE · TAKEDOWN; a silent knife. Shoot a guard into his last quarter:
   he staggers (wobble, flash); melee → EXECUTE, a point-blank shot that
   refunds rounds. Ghost Run survives silent takedowns, not gunfire.
5. **Combo break vs cash-out.** Chain kills: the right-hand panel counts
   points, tiers (RALLY → BLACK SWAN, a sting each) and the log. Stop and let
   the window run out: COMBO CASHED with gold and a small venue move. Chain
   again and take a hit: PANIC SELL keeps a quarter. F1 → COMBO → FRENZY /
   BLACK SWAN / PANIC SELL to check the panel quickly; Settings → HUD →
   Combo panel size.
6. **Explosive props.** F1 → GORE → EXPLOSIVE PROP, shoot it: blast, scorch,
   neighbours chain, guards in range die as DETONATIONS.
7. **Stars 0 → 5 and the music.** F1 → WANTED → 1 … 5 in a heist: a star
   sting and siren blip each time; 3★ distant sirens and the WANTED 3 layer,
   4★ cruisers outside and the bass/siren layer, 5★ a helicopter spotlight
   (stand in it outside: the car stops and outside guards come) and the
   chase layer. Layers change on the bar, stingers on the beat; combos add
   a hi-hat riff (BULL RUN) and a lead (FRENZY). Each stage has its own key
   and tempo. Settings → SOUND → Dynamic music off: one steady mix.
8. **Verdicts.** F1 → BOSS JOBS → LANDLORD (practice), then F1 → FORCE
   KNEEL: he drops to his knees, his gun skitters away, guards put their
   hands up, time swells, the verdict theme plays. USE next to him: the
   VERDICT card (1-4 / tap). Try each on a fresh boss job: EXECUTE (the
   finisher, gore, his gun), FLIP (he walks out; Safehouse Rent / Cooked
   Books / Diplomatic Cover), SHAKE DOWN (gold and his relic), TAKE HIS DEAL
   (disabled on practice jobs — test it from a real run).
9. **The finale.** F1 → VERDICTS → MIXED (or ALL FLIPPED / EXECUTED /
   SHAKEN), then F1 → THE CHAIRMAN'S JOB: flipped bosses fight beside you
   (downed for 20 s, never killed), executed bosses' crews come in revenge
   waves (+10% damage each while they're up), shaken relics sabotage him
   (15% down, no Liquidation, half-width Margin Call strips).
10. **Route to each ending.** Deals: TAKE HIS DEAL on the Landlord /
    Auditor / Ambassador → THE LANDLORD'S CHAIR / COOKED BOOKS / DIPLOMATIC
    EXIT. The Chairman: BURN THE BOARD with $400+ of open shorts (Fence
    shorts or the terminal short) → BLACK MONDAY, else SCORCHED EARTH;
    TAKE THE SEAT with all three flipped / executed / shaken → THE SYNDICATE
    / THE PURGE / THE PUPPETEER; mixed → THE NEW CHAIRMAN at index 840+ (F1
    → INDEX), else A SEAT AT THE TABLE; WALK AWAY → RETIRED. Die to each
    boss, a sniper, a blast or at five stars for the BUSTED variants.
11. **CASE CLOSED.** Home → CASE CLOSED: reached endings show their image and
    count, the rest are silhouettes with hints; the first time you reach an
    ending the job report's Clout line shows the bonus.
