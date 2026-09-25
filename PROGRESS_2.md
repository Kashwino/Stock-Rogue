# Stock Rogue — Brief 2 progress

Read this first after a context reset and continue from the first unchecked
item. Branch `brief-2` (mirrored to `codex/mobile-web-beta`, the session's
designated branch). Commit after every phase as `brief2 phase N: <summary>`.
Verify with `tools/run_tests.sh` (sweep + import + settings + smoke + full
loop), `python3 tools/balance_sim.py`, and the Web build + `node tests/browser.mjs`.

## Rules added by this brief
- `TimeController` autoload owns `Engine.time_scale`: requests with a priority
  and duration, never stacked, always restored, nothing while paused.

## Phase 1 — Kill classes & feedback
- [x] TimeController autoload; every direct `Engine.time_scale` write migrated
- [x] Kill classification (STANDARD / CRIT / OVERKILL / EXPLOSIVE / BURN / TAKEDOWN + MULTI flag)
- [x] Hit-stop per class via TimeController
- [x] Camera punch toward the kill; red X hit-marker on kills; kill-confirm flash
- [x] Death motion: corpse slide + spin + friction, weapon skitters, explosions launch, wall stop
- [x] Multi-kill banner (DOUBLE / TRIPLE / MASSACRE), reduce-flashing aware

## Phase 2 — Kill sounds
- [x] gen_sfx.py: flesh impacts ×4, bone crunch, splatter, gib burst, falls ×4 floors, clatter, confirm tick, crit ding, sizzle, takedown, multi stings
- [x] Three-layer kill playback (impact + body + fall), floor-matched falls
- [x] Voice limit (~6 death layers), variance, music duck on overkill/takedown

## Phase 3 — Gore
- [x] Settings: Gore Off/Low/Full, Blood style Red/Noir
- [x] Directional spray per hit, exit spray on pierce
- [x] Decals: floor splatters, wall splats, pools, smears, drip trails
- [x] Baked per-room decal layer with caps
- [x] Gibs (Full) with wall bounce and trails
- [x] Bloody footprints (player + guards)
- [x] Player blood vignette + 1-HP drips
- [x] Bodies are evidence (guards investigate, radio on a second body; civilians flee; Ghost +50%)

## Phase 4 — Takedowns
- [ ] `melee` input action (F + right mouse)
- [ ] Stealth takedown (behind, unprovoked, silent, invulnerable) with exclusions
- [ ] Stagger below 25% (Brutes 10%), stagger execution (+2 rounds, OVERKILL)
- [ ] Ghost Run allows stealth takedowns; Meta takedowns stat

## Phase 5 — Combo "THE RALLY"
- [ ] Combo core: points, window, tiers, cash-out, PANIC SELL
- [ ] Market multiplier on kills while live
- [ ] HUD combo panel + cash-out / panic popups
- [ ] Grade weight, results rows, Meta best combo + Clout nudge
- [ ] 5 combo relics; character hooks
- [ ] Explosive props (gas cans, fuel drums, fuse boxes) with chains
- [ ] Combo gold cap, verified in balance_sim

## Phase 6 — Wanted & adaptive music
- [ ] Wanted stars 0–5 on the HUD; thresholds; marked ≥ 3★; laying low
- [ ] 3★ sirens, 4★ cruisers, 5★ helicopter spotlight (pauses extraction, reveals)
- [ ] tools/gen_music.py: per-stage stems, boss themes, verdict, hideout, map, menu, 5 ending themes
- [ ] Adaptive music layers on bar boundaries; stingers on beats; ducking
- [ ] Dynamic music setting

## Phase 7 — Boss verdicts
- [ ] Bosses kneel; arena stays sealed; guards stand down; VERDICT card
- [ ] EXECUTE / FLIP / SHAKE DOWN / TAKE HIS DEAL with passives and relics
- [ ] Finale: flipped allies, revenge wave, sabotaged phases
- [ ] Chairman verdict: TAKE THE SEAT / BURN THE BOARD / WALK AWAY
- [ ] Verdicts in the run save (defaults for old saves)

## Phase 8 — Endings & gallery
- [ ] 11 endings resolved in order + BUSTED variants
- [ ] Each ending: title, epilogue cards, final image, family theme, stats with verdicts, credits
- [ ] CASE CLOSED gallery with silhouettes and hints; first-time bonus Clout
- [ ] Meta: verdict counts, endings seen, early endings; Legend = any final ending

## Phase 9 — Settings, performance, balance, QA
- [ ] Settings: Gore, Blood style, Dynamic music, combo HUD scale
- [ ] Budgets: 60 fps with 50 enemies + Full gore; caps
- [ ] balance_sim: combo, verdict payouts, early vs full-run Clout
- [ ] Debug menu additions
- [ ] TESTING.md, CHANGELOG.md, this file complete; zero errors on a full run
