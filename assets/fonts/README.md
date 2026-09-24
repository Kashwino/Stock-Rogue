# Fonts

All fonts are licensed under the SIL Open Font License 1.1 (license texts in
this folder), fetched from the google/fonts repository.

| File | Role |
|---|---|
| Oswald.ttf (variable weight) | headings, logo, stamps |
| BarlowSemiCondensed-Medium/Bold.ttf | body text, buttons |
| IBMPlexMono-Medium.ttf | ticker tape, prices, numbers |
| CourierPrime-Regular/Bold.ttf | case files, typewriter narration, reports |

`visual_theme.gd` builds the UI theme from these at startup. If a file is
missing the game falls back to a `SystemFont` with sensible family names.
