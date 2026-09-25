# Brief 3 — Noir Props HUD: progress

Work happens on `brief-3` (pushed to `codex/mobile-web-beta` as well). After a
context reset, continue from the first unchecked item.

## Inventory: every HUD / in-heist overlay element and its new form

| # | Element (before) | Where in code | New form | Done |
|---|---|---|---|---|
| 1 | Ticker tape (dark strip) | `ticker_tape.gd` (`paper = true` in the HUD) | Cream paper strip, perforations both edges, typewriter type, red / green arrows, shadow; the robbed venue circled in red pencil; a jumping symbol flashes | [x] |
| 2 | Hearts | `hud_props.gd` ChipStack | Poker-chip stack bottom-left; gold chips for bonus max HP; flip-off / drop-on animations, clack; 1 HP wobble + red glow; `xN` typed | [x] |
| 3 | Gold counter | `hud_props.gd` MoneyClip | Banknote stack in a brass money clip, amount on a paper band; 3 thickness tiers; riffle + roll-up on gain, bill slides out on spend | [x] |
| 4 | Loot multiplier | MoneyClip tag | Manila luggage tag on a string, swings when it changes | [x] |
| 5 | Objective panel | `hud_paper.gd` ObjectiveNote | Torn notepad page, paperclip, -3 degrees, typewriter; red-pencil strike + fresh note slides in; clocks in red, ticking in place | [x] |
| 6 | Relic tokens | `hud_props.gd` Matchbooks | Matchbooks fanned in an arc along the bottom, mark emblem, stack count, hover tooltip | [x] |
| 7 | Heat meter + log + stars | `hud_pulp.gd` HeatBar | Slanted hatched bar, police notches, green EXIT sign, five police badges (flash on gain), log as skewed captions | [x] |
| 8 | MAP / PAUSE buttons | `typewriter_key.gd` (heist_floor, pause_menu) | Round typewriter keys in brass rings, lift on hover, sink + click on press | [x] |
| 9 | Minimap | `hud_paper.gd` BlueprintMap | Folded blueprint, creases, torn corner, pushpin; chalk rooms, pencil marks | [x] |
| 10 | Stock panel + chart | `hud_paper.gd` TickerMachine / TapeChart | Glass-dome ticker machine, chart on curling tape over graph paper, stamped venue, red-pencil quota + scribbled gap, gold-ink index | [x] |
| 11 | Trader feed | `trader_feed.gd` (`telegram = true`) + HudPaper.Telegram | Telegram strips pasted at slight angles, stacking and fading | [x] |
| 12 | Combo panel | `hud_pulp.gd` ComboSlab | Italic count on a skewed slab with a halftone burst, tier banner, draining skewed bar; speed-line slam on tier-up; PANIC SELL tears it apart | [x] |
| 13 | Multi-kill banner | `hud_pulp.gd` Banner | Skewed banner, halftone, ink-outlined italic; MASSACRE impact star; "N DOWN" typed | [x] |
| 14 | Combo cash-out / panic popup | `hud_pulp.gd` Caption | Pulp caption on a slant (also verdict lines) | [x] |
| 15 | Weapon panel | `hud_props.gd` WeaponRack | Gun silhouette on the table, rounds as cartridges (cylinder for revolvers, shells for shotguns), cartridge box / stamped infinity; eject, reload refill, card-flip swap | [x] |
| 16 | Damage numbers | `combat_fx.gd` FloatMark | Italic pulp numbers with an ink outline; crits get an impact star | [x] |
| 17 | Floating market chips | `combat_fx.gd` FloatMark (SLIP) | Ticker slips that flutter up and away | [x] |
| 18 | Boss bar | `boss_bar.gd` | Long skewed bar, slanted title card, notched phase ticks, slanted status tags; cracks and shatters when the boss kneels | [x] |
| 19 | Verdict card | `verdict_card.gd` | The boss's case file with four rubber stamps; the chosen stamp slams onto the file before the verdict plays | [x] |
| 20 | Guard melee prompt / verdict prompt | `enemy_overhead.gd` | Typewriter key cap + skewed label | [x] |
| 21 | Guard name tags, radio bar | `enemy_overhead.gd` | Small skewed slabs | [x] |
| 22 | Terminal / alarm / camera / charge / package / chest prompts | `world_prompt.gd` | Skewed name slab + key cap and action | [x] |
| 23 | Getaway car status, exit prompt | `getaway_car.gd`, `heist_floor.gd` | Pulp type with ink outline (car: skewed StyleBoxFlat slab) | [x] |
| 24 | Tip card | `onboarding_hints.gd` | Torn manila note with a red-pencil margin, below the heat bar (below the boss bar while one is up) | [x] |
| 25 | Low-HP vignette | `blood_vignette.gd` + shader | Ink bleed with a tide line; red with Red blood, pure ink with Noir / Gore off | [x] |
| 26 | Crosshair reload ring | `crosshair.gd` | Spinning revolver-cylinder outline filling its chambers | [x] |
| 27 | Ally tags (finale) | `ally.gd` | Unchanged mono label over a health line (open, no frame) | [x] |
| 28 | Pause menu, chest reveal, lobby terminal, tactical map | modal menus | Kept as menus (see Decisions) | [x] |

## Phases

### Phase 1 — Foundation
- [x] Palette additions, pulp font role, `HudKit` (paper, chips, bullets, banknotes, slants, halftone, stamps, typewriter keys, blueprint, badges, prompts)
- [x] Settings: HUD style (Noir Props / Minimal), HUD scale, HUD opacity, Reduce motion (+ combo size) in the HUD tab
- [x] Corner-anchored clusters; touch layout (vitals under the objective, gun bottom-centre)

### Phase 2 — Diegetic props
- [x] Chip stack, money clip, luggage tag, weapon rack (cartridges / cylinder / shells / box), matchbooks

### Phase 3 — Paper and machines
- [x] Notepad objective, blueprint minimap, ticker machine chart, telegram feed, typewriter keys, tip note, paper ticker tape

### Phase 4 — Pulp
- [x] Heat bar + badges + log, combo slab, banners, captions, damage numbers, ticker slips, boss bar + shatter, verdict stamps, world prompts and tags

### Phase 5 — Screen effects, Minimal, motion
- [x] Ink bleed, cylinder reload ring, Minimal style for every widget, Reduce motion / Reduce flashing audit

### Phase 6 — Tooling, performance, docs
- [x] `tools/hud_preview.tscn` cycling every element and state
- [x] F1 → HUD SHOTS (`hud_shots.gd`) to `user://hud_shots/`; self-reviewed lit / dark / rain / 1 HP / FRENZY / boss
- [x] Props redraw only on change; perf bench unchanged (~9.8 ms CPU per 60 fps frame)
- [x] Smoke checks for the HUD; `TESTING.md` HUD checklist; `CHANGELOG.md` + Decisions
