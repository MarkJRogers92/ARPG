# Walkable Last Lantern town — plan and handoff

Goal: replace the menu-style town between expeditions with a 3D sanctuary the
hero walks around. Each service (route board, armory, market, trainer, crypt,
Ferryman, Ledger) is a place or person you walk up to and use with **E**.

## Rules

- Presentation only. `CampaignController`, `CampaignState`, save format, and
  rewards are untouched. Every state change still goes through the existing
  `CampaignTown._command(...)` calls.
- The existing service panels in `campaign_town.gd` are reused as overlays.
  Do not duplicate their logic.
- Headless runs (all `tools/*_test.gd` suites) keep the classic menu town, so
  existing UI tests stay valid. `CampaignTown.walk_mode` can force either mode.

## Design

- `scripts/campaign/campaign_walk_town.gd` (`CampaignWalkTown`, Node3D): builds
  the plaza (ground, central lantern, lights), places one station per service,
  spawns the class-colored `HeroModel`, follows it with a camera, reads
  `move_*` input, pushes the hero out of station footprints, shows a floating
  prompt at the nearest station, and emits `station_used(service_id)` on
  `interact`. `walking = false` freezes input while a panel is open.
- `campaign_town.gd` in walk mode: hides the opaque backdrop and the classic
  sanctuary inset; the body row (service rail + panel + status) is shown only
  while a panel is open or a phase forces it (`EVENT_PENDING`,
  `RESULT_PENDING`, `CAMPAIGN_COMPLETE`). Esc closes an open panel; with no
  panel open Esc keeps its old meaning (save & leave).

## Status

1. [x] Plan (this file)
2. [x] Walkable scene: plaza, stations, hero, camera, movement, prompts
3. [x] Town integration: overlay panels, Esc handling, forced phases, hint bar
4. [ ] Verify in Godot 4.7 on desktop: import, walk, every station opens its
       panel, depart from route board, result/event overlays, Esc behavior.
       Not yet run (authored without a Godot binary).
5. [ ] Polish after first look: station spacing/scale, camera angle, collisions,
       NPC idle animation, footstep sound, gamepad prompt glyphs, biome-tinted
       lighting (reuse `CampaignBackdrop` journey/trophy dressing).

## Known risks to check first

- `AssetProps.mesh(kind)` may return null for a kind; the station still gets a
  glow ring and label so it is usable.
- Station prop scale (1.0) versus hero scale (HeroModel rig 1.12) is a guess.
- Ui focus: closing a panel releases GUI focus so Space/Enter can't hit
  "Save & Leave" while walking.
