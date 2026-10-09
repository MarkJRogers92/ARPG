# Gravediggers’ Camp life preview

Local branch `preview/gravediggers-camp-life`, based on merged PR #35 (`2df2ec1`).

## Scope

Make Gravediggers’ Camp the first inhabited stop: local workers, subtle camp movement and sound, and an optional conversation with Mara about the road ahead and the crew who stay behind. Keep the existing seven services and journey rules.

The encounter is narrative only, repeatable, and scoped to this stop. It does not award resources, add quest state, or change the save format. Later biomes are outside this preview’s implementation scope.

## Isolation

The normal preview launcher uses the separate `Soulbound_CampLifePreview_20261008` profile, initially copied from the player profile. The original profile and checkout settings are protected by starting fingerprints. The untracked override is local preview configuration only.

## Verification

Native Luna implemented the bounded package. Native Sol reviewed the actual production and preview/test changes; its scene-ownership and motion-test corrections were applied and checked by the parent. Jev routing was unavailable; the ordinary native assignment was retained.

Godot 4.7.2: the focused camp-life test passed 46 assertions, including interaction/action binding, dialogue choices/focus, Escape and Leave, phase/service guards, state immutability, actor collision, camp audio lifetime, role-specific animation, and repeat travel cleanup. The existing all-stop visual/movement/service suite passed 582 assertions, walk-town 43, UI behavior and backdrop fixtures passed. The direct-demo verification creates a valid first success through the real controller, mounts the real Shell, then activates Save & Leave and verifies that the old Shell, town, controller, and audio manager are freed as the title appears.

Evidence is in `work/camp-life-evidence/`: final corrected focused logs `camp-life-correction.log` and `showcase-correction.log`; compatibility logs `waystop-visual.log`, `walk-town.log`, `ui-behavior.log`, `backdrop.log`; native 1280×720 renders `native-final/camp.png` and `native-final/dialogue.png` inspected by the parent.

This is automated fixture/input-path and rendered-view evidence, not a full human campaign playthrough. The binding check changes the mapping and exercises the Use action, not a physical F-key event. Audio stream validity, playback, explicit loop bounds, SFX bus routing, zero-ended seam fades, and teardown were verified instrumentally; the new crackle was not listened to. The reproducible local generator is `tools/audio/make_campfire_loop.py`. The focused test still reports 4 ObjectDB instances and 2 resources at shutdown; the showcase/title test reports 12 and 6. Those shutdown diagnostics are not a demonstrated player-facing leak and remain unresolved.

Original six save-file states and original checkout settings match starting fingerprints. Generated import sidecars were restored. No save schema, controller, economy, or reward changes. Local preview only: not pushed, merged, or installed over the released app.

## Direct camp demo

`Visit Gravediggers Camp Demo.command` starts directly at this stop through `tools/campaign_camp_life_preview.gd`. Each launch creates a fresh disposable demo campaign at a timestamped `campaign-camp-life-showcase-*.save` path, disables account progression, and leaves the copied `campaign.save` and `meta.save` alone. Services and departure use the real campaign Shell. Save & Leave returns to the title within that demo process; relaunching the demo starts fresh. Use `Play Camp Life Preview.command` for normal play with the separate copied preview profile.
