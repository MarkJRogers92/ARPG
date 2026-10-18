# Rune Greatsword and Amber Amulet integration

## Play the opt-in preview

Open `scenes/pilot/equipment_preview.tscn` in Godot 4.6 and press F6, or run:

```sh
godot --path . scenes/pilot/equipment_preview.tscn
```

The scene is the real Main game with its normal movement, camera, combat, HUD,
and inventory. It starts with both generated items equipped. Press Tab/I to
inspect them, unequip, and swap them back. The sword uses the level-one Staff
implicit and casts existing bolts; the amulet uses the level-one Pendant
implicit. These are visual integration fixtures, not new melee/accessory balance.
The default title/start scene, drop odds, class defaults, and saves are unchanged.

Account progress is disabled during this preview, suspend/save is disabled,
and RunSave uses an isolated path. Exit to title restores the original guards
and opens the ordinary title. A real suspended run and account profile are
protected by byte-identity tests. Quit and normal input remain available.

## Verification

```sh
bash tools/run_tests.sh -t 'tools/imported_equipment_test.gd tools/equipment_preview_test.gd'
bash tools/run_tests.sh
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
```

The focused tests inspect actual imported meshes, triangle counts, all PBR maps,
normal gameplay scale, grip alignment through motion/casts on every hero,
repeated equipment swaps, inventory serialization, icon centering, loot meshes,
unchanged random weapon pools, and frame-driven Main/exit/save isolation.

Verified locally with Godot 4.6.3: 660 imported-equipment checks; 241 preview
lifecycle checks; the three existing hero visual suites; a 420-second-frame-budget
Classic smoke bot; Linux resource-pack export and all 660 equipment checks against
that exported pack. The smoke's game clock can advance less than its frame budget
while menus are paused. This is automated headless evidence, not a human playtest.

The first aggregate run passed 64/65 suites. The campaign suite's four damaged-file
lookup failures were reproduced on untouched base code using XDG paths containing
`..`, then passed on integrated code using canonical absolute XDG paths. The save
implementation is unchanged. Use normalized absolute XDG paths for isolated cloud
runs. A final aggregate rerun uses those corrected paths.

Current limits: this cloud environment could run Godot 4.6.3 headless but could
not open a graphical display. No native in-game screenshots, pixel-level hand
fit, physical input check, GPU timing, installable executable export, or two-handed combat
animation approval is claimed. The prepared assets have separate four-view
Blender visual QA. Keep this branch in review until the in-engine visual pass
and provider/source-image release-rights review are complete.
