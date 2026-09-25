# Testing Stock Rogue

## Automated checks

Run these from the project folder (Godot 4.6.1 on the `PATH` as `godot`).

| Command | What it proves |
| --- | --- |
| `tools/run_tests.sh` | Static sweep, clean import, settings and career saves surviving separate processes, the gameplay smoke suite (~1050 checks), then the **full loop**: Home → case file → crew (prologue) → case wall (stage card) → hideout → heist → job report → Doomsday quota → the Chairman → THE NEW CHAIRMAN → credits → NEW SPECIALIST → Home. Fails on any `ERROR:` in the logs. |
| `tools/check.sh` | Every script compiles. |
| `python3 tools/sweep.py` | Every `res://` path exists, every input action the code reads is defined, every signal target exists, scene changes are guarded, tabs only, no `Label2D`, no method named `bind`, no constructor passed as a Callable, no bare `print()` in game code. |
| `python3 tools/balance_sim.py` | The economy invariants: two flawless heists don't clear the first stock gate but two Market Manipulations on top do, the first gold gate is reachable in about two heists, a short plus a HIT is profitable but costs index, and THE NEW CHAIRMAN is about a quarter of wins. Reads the constants from the scripts and the loot census. |
| `godot --headless --path . res://tools/loot_census.tscn` | Rebuilds `tools/loot_census.json` (money in real buildings per stage). Rerun after changing rooms, props or loot. |
| `godot --headless --path . res://tools/perf_bench.tscn` | 50 guards hunting the player in a World heist while he fires: CPU cost of a 60 fps frame (about 10 ms of the 16.7 ms budget on the CI machine) and physics keeping real time. |
| Web: `rm -rf build/web && mkdir -p build/web && godot --headless --path . --export-release Web build/web/index.html && python3 web/prepare_web.py && node tests/browser.mjs` | The exported Web build on a phone-sized touch screen: settings, Connections purchases, a practice heist with two-finger touch, the lobby terminal, pause, a new case file with the prologue and stage card, the hideout, a heist choice, resume after reload. |
| `godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- shot=<preset> out=<png>` | Renders any screen (see `tools/screenshot.gd` for presets and options such as `pause=1`, `debug=1`, `hint=<id>`, `terminal=1`, `shot=ending part=credits`). |

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
    floor, chart volleys) or F1 → KILL BOSS, then take the job report.
13. **Ending.** The city pans past while the epilogue types out; the title
    (RETIRED, or THE NEW CHAIRMAN at index 800+) with your numbers; the
    credits roll; on a first win the **NEW SPECIALIST: THE LEGEND** card;
    then home. The Legend is now hireable.
14. **Every ending.** F1 → BUSTED (the newspaper front page), F1 → RETIRED,
    F1 → THE NEW CHAIRMAN. Debug endings run as practice and leave the
    career alone.
15. **Controller (optional).** With a pad: navigate the menus, left stick
    moves, right stick aims (at rest you aim where you walk), RT fires,
    LB rolls, X reloads, START pauses; the pause card and tips show pad
    buttons.
16. **Phone / Web (optional).** Landscape: left thumb moves, right thumb aims
    and fires, DODGE / RELOAD / SWAP / USE / MAP / PAUSE on screen.
