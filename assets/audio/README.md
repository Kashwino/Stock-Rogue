# Audio

**Everything here is generated placeholder audio.** No samples, no external
libraries: `tools/gen_sfx.py` synthesises every sound effect and music loop
with Python's standard library (`wave`, `struct`, `math`, `random`, `array`).

## Regenerate

```sh
python3 tools/gen_sfx.py          # everything (~30 s)
python3 tools/gen_sfx.py sfx      # effects only
python3 tools/gen_sfx.py music    # music only
```

Output is 22.05 kHz, 16-bit mono WAV. Godot imports it with QOA compression,
so the shipped build is far smaller than the source files (~11 MB here).
The generator is seeded, so the files only change when the script does.

## Layout

- `sfx/` — gunshots per weapon class (`shot_pistol`, `shot_revolver`,
  `shot_smg`, `shot_rifle`, `shot_sniper`, `shot_shotgun`, `shot_lmg`,
  `shot_silenced`, `shot_enemy`), `dry_fire`, `mag_out`, `mag_in`,
  `impact_wall`, `impact_body`, `footstep_1..3`, `hurt`, `death_enemy`,
  `death_player`, `alert`, `loot_0..3` (value tiers), `cash_register`,
  `ui_hover`, `ui_click`, `ui_deny`, `case_tick`, `reveal_0..4` (per rarity),
  `van_engine`, `van_brakes`, `van_doors`, `alarm` (loop), `camera_spot`,
  `stock_up`, `stock_down`, `heartbeat` (loop), `boss_intro`, `boss_phase`,
  `boss_death`, `stamp`, `paper`, `typewriter`, `explosion`, `laser_charge`,
  `deflect`, `dog_bark`, `drone`, `radio`, `shutter`, `dodge`, `chest_open`,
  `door_bang`.
- Kill layers (Brief 2): `flesh_1..4`, `bone_crunch`, `splatter`, `gib_burst`,
  `fall_concrete` / `fall_carpet` / `fall_marble` / `fall_metal`, `clatter`,
  `kill_tick`, `crit_ding`, `burn_sizzle`, `takedown_knife`,
  `takedown_crack`, `multi_2..4`; combo `combo_up` / `combo_cash` /
  `combo_crash`; WANTED `star_up`, `siren_blip`, `sirens_far` (loop),
  `sirens_near` (loop), `heli` (loop).
- `music/` — `menu`, `hideout` (tools/gen_sfx.py) and the adaptive music from
  tools/gen_music.py: shared 96 BPM stems (`drums_brush`, `drums_combat`,
  `wanted3..5`, `combo_a`, `combo_b`) that every stage pitch-scales to its
  tempo; per-stage `<stage>_explore` / `_tension` / `_combat` (town 96, city
  104, world 112, doomsday 124); `boss_<id>` + `boss_<id>_hi`; `verdict`;
  `map`; and the ending families `end_rule`, `end_escape`, `end_collapse`,
  `end_retire`, `end_busted`. Loops are rendered into circular buffers, so
  they are seamless; stems of one stage share length and tempo.

## Swapping in real audio

Drop a file with the same name into the same folder (WAV or OGG — for OGG,
change the extension in `audio.gd`'s `SFX_DIR`/`MUSIC_DIR` lookups). Mix
offsets per sound live in `audio.gd` (`GAIN`), voice limits in `LIMITS`, and
numbered variants in `VARIANTS`. Music loops are forced to loop at runtime,
so no import settings need to change.
