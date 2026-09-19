# Stock Rogue 0.3 — criminal network update

## New in 0.3

- Map contracts carry visible modifiers: **Heavy Police Response** doubles pickup,
  room-clear and boss gold, halves the police heat threshold (8 vs 16), and halves
  the dispatch interval (12 vs 24 seconds). **Lockdown** seals fire exits from entry;
  the main door and getaway car remain available. **Insider** reveals all rooms,
  chests, the boss and exits in the touch-accessible MAP overlay. Other contracts
  reveal rooms as you explore. Quick Heist uses Insider.
- Heat comes from camera sightings, completed guard radio calls, active alarm panels,
  market manipulation and the Auditor's distress beacon. It never rises merely
  because time passes. After four seconds without reports, heat falls by 1/second.
  Cameras show detection cones and a windup; guards show an interruptible radio call.
  Shoot cameras or USE/shoot a panel to disable its room's security. Each disabled
  device reduces heat by 4 and the venue price by 3.5% before character volatility.
- **Short This Heist** replaces the instant Short & Leak payout. It escrows 75 gold
  against 300 gold notional exposure to the current venue. In this hostile position,
  hits and kills push its stock down, while taking damage pushes it up. Sabotage
  always lowers the venue's value. Escape settles collateral plus profit, capped
  between 0 and 225 gold. Death forfeits the stake; settlement cannot happen twice.
  Settlement uses the combat price before the extraction grade. Shorting sacrifices
  venue growth, so it competes with the empire Index needed at quota gates.
- NETWORK on the home screen spends persistent Intel on three new loot-pool weapons
  (Circuit Thief, Margin Call, Hostile Takeover) and three starting perks (Fast Hands,
  Quiet Shoes, Cool Head). Equip one perk for future runs. Existing weapons remain
  available. Earn Intel on escape: 1 per two kills (max 6), 1 per disabled device
  (max 4), plus 4 for the Auditor. Empty escapes earn nothing and replaying an awarded
  checkpoint cannot duplicate Intel. Currency, unlocks, equipment and receipts save
  immediately, including synchronous browser storage.
- Screen shake, muzzle flashes, guard/player/boss hit flashes, a brief room-final-kill
  slowdown, and animated gold totals. Low Effects suppresses these effects.
- Resume restores quota progress as well as the map position.

## Play and controls

Open the published Web build in a modern browser. On a phone, rotate to landscape.
Tap **QUICK HEIST** to start at the authored Marlowe Exchange with extra health,
gold, the Ricochet Bond sidearm and Breach Hammer shotgun. It uses a separate
test save slot; your three case files are not overwritten.

- Left stick: move. Right stick: aim and fire.
- DODGE, RELOAD, SWAP and USE: touch action buttons.
- PAUSE: stop mid-heist, resume, change settings, or return to the last checkpoint.
- Desktop: WASD/arrows, mouse aim/fire, Space/Shift dodge, R reload, Q swap, E use, Esc pause.
- Walk through the main door from the getaway car, grab valuables and chests, then
  return to the car to extract. Defeating the boss is optional but profitable.
- The terminal in the lobby permits one market operation per heist.

## Added systems

- Fixed, hand-authored eight-room Marlowe Exchange scene with a central loop,
  optional records/vault branches, counters and a dedicated Auditor chamber.
  Used for the first heist and Bank Job venues; other heists retain procedural layouts.
- **The Auditor**: declared radial levies with a green escape wedge, locked-direction
  foreclosure charges, and a faster **Margin Call** phase below half health.
  Defeating him triggers the existing marked/reinforcement/extraction consequences.
- 20 weapons in the full catalog, including three permanent unlocks and guns with bouncing rounds, penetrating shots,
  shotgun knockback or a reduced noise radius.
- Nine stat upgrades total, plus six new purchasable fence perks: Fast Hands,
  Blood Dividend, Quiet Shoes, Cool Head, Scavenger and Golden Parachute.
- Pump the Tape: 60 gold, selected venue +15%, +8 heat.
- Short This Heist: 75 gold collateral; combat-driven settlement on escape, +0 heat.
- Circuit Breaker: 100 gold, halve the next three damage-driven stock losses, +4 heat.
- Enemy manager checks distance at 5 Hz with separate wake/sleep thresholds;
  sleeping guards stop physics, noise/damage wakes them, and hunting reinforcements
  remain active. Spatial buckets replace all-enemy scans for separation/medic searches.
- Low effects reduces hit flashes, reload animations and pickup movement.
  Optional 30 FPS cap, audio buses and immediate saved settings.

## Settings and saves

Master/effects volume, fullscreen preference, low effects, frame cap and touch-control
mode are stored in user settings. Web builds also synchronously save settings in
same-origin local storage. Private browsing or clearing browser storage can remove
saves. Browsers require a user gesture to enter fullscreen: the preference persists,
and starting a game or tapping the fullscreen setting applies it.

Run progress saves at existing scene/heist boundaries, not at arbitrary moments
during a fight. Returning to the menu from pause resumes at the last checkpoint.

## Legacy-script audit

No listed file was deleted: prototype examples are retained deliberately.

| Script | Confirmed reference / status |
|---|---|
| heist_controller.gd | No caller or scene reference; unused old multi-room controller. |
| heist_resolver.gd | Referenced only by unused run_controller.gd. |
| heist_sequencer.gd | Referenced only by legacy arena_setup.gd; not the production heist flow. |
| room.gd | Used by legacy arena/controller/sequencer classes, not BuildingRoom gameplay. |
| room_manager.gd | Used by floor_test.tscn prototype; retain for that example. |
| run_controller.gd | No production caller or scene reference; old turn-based economy prototype. |
| door.gd | Used by room_manager.gd and floor_test.tscn; retain for that example. |
| test_player.gd | No caller or scene reference. |
| tutorial_overlay.gd | No caller or scene reference. |

The active entry point is home_screen.tscn; RunFlow enters map_ui_screen.tscn,
hideout_room.tscn and heist_floor.tscn. map_screen.gd has no ShopUI node reference.
Runtime debug print calls were removed; test logs remain in tests/ only.

## Reproduce validation

Use Godot **4.6.1-stable**, matching export templates and Node 22.

```sh
godot --headless --editor --path . --import
godot --headless --path . res://tests/settings_test.tscn -- write
godot --headless --path . res://tests/settings_test.tscn -- read
godot --headless --path . res://tests/smoke.tscn
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python web/prepare_web.py
npm install --no-save --package-lock=false playwright@1.51.1
npx playwright install --with-deps chromium
node tests/browser.mjs
```

Run tests in a disposable checkout/profile: they deliberately write test settings
and the separate test save slot. GitHub Actions does this on an isolated runner.
The workflow uploads the Web ZIP and browser screenshots/report as artifacts.

Browser automation uses the real exported engine, touchscreen events and normal UI.
The optional ?qa=1 URL enables a read-only state snapshot; it does not accept commands
or modify gameplay. Automated mobile Chromium is not a substitute for testing on
physical Android and iPhone hardware. The Web export is single-threaded to avoid
cross-origin-isolation requirements and improve mobile compatibility.

The Web packaging step compresses the engine to reduce mobile download size. It requires a browser with DecompressionStream support (current Safari, Chrome, Firefox and Edge). The same packaged files are exercised by browser CI before publication.
