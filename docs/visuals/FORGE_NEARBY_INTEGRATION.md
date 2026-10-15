# Field forge and Nearby loot integration — 2026-10-13

This combines the two previously isolated candidates on the actual default
branch's `f33c220b6e663bb0b9b28c90b9359ec202918695` baseline (PR #54).
All earlier guardian, exploration, combat-readability and UI upgrades remain
inherited from that commit. The only patch conflict was adjacent test-runner
entries; both suites are retained. No release workflow or export settings changed.

## Combined acceptance

- Final aggregate: **52/52 suites passed**, including Classic and Campaign
  UI, combat, lifecycle, facilities, rewards and save/resume coverage.

- The forge suite now follows a paid accepted roll into the real Equipment
  Nearby tab, frees one backpack slot, collects and separately equips ground
  loot, then writes a disk snapshot and creates a fresh Main scene from it.
- The forged weapon is retained once in the backpack, the collected weapon is
  worn once, the fee remains eight shards and spent forge identities survive.
- Focused headless suites passed: forge **55 assertions**, Nearby **71**, plus
  gear-impact and resume suites.
- Both interaction suites passed at verified physical 1024×576, 1280×720 and
  1920×1080: forge **58 assertions** and Nearby **75** at each size. Screenshots
  were inspected. Keyboard focus, repeat/stale input, modal ownership, death,
  full packs, long names and Campaign restrictions are covered.
- The final runtime source passed the required **420-second frame-budget bot**:
  **13,872 kills, 34 upgrade choices, hero alive**. Gameplay time was 418.4 seconds;
  menus and slow motion consume frames. No script/parse errors or exit diagnostics
  appeared in this smoke log.

## Compatibility and limits

The existing version-1 snapshot format gains only an optional list of spent
Classic field-forge keys. Older saves load without the field. Nearby does not
persist ground loot; its UI explains that uncollected drops are transient.
Campaign town reforge, reward settlement and banked-item protection are unchanged.
No progression migration, new assets, dependencies or paid services were added.

Tests use disposable profiles and Godot 4.6 Compatibility on cloud Linux.
Rendered captures use Mesa llvmpipe, so they are not native-device performance
measurements. Existing ObjectDB/resource shutdown warnings remain in some
focused suites; no suppression rules were changed. The cloud display falls back
to dummy audio. Physical gamepad input, a full human playthrough and installed
native builds require separate verification. Successful export alone does not
establish that the installed Mac application has launched or loaded a real save.

The publication pull request and its exact merge-commit Build workflow are the
source of truth for remote merge/export status. The pre-integration individual
reports remain historical evidence and are not claims about the installed app.
