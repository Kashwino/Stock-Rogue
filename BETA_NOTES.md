# Stock Rogue 0.2 — mobile Web beta

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
- 17 weapons total: six new guns with bouncing rounds, penetrating shots,
  shotgun knockback or a reduced noise radius.
- Nine stat upgrades total, plus six new purchasable fence perks: Fast Hands,
  Blood Dividend, Quiet Shoes, Cool Head, Scavenger and Golden Parachute.
- Pump the Tape: 60 gold, selected venue +15%, +8 heat.
- Short & Leak: 75 gold, selected venue -20%, 110 gold payout, +12 heat.
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
