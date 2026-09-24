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
