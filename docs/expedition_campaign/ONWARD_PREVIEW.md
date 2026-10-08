# Onward journey preview

Branch: `preview/onward-biome-settlements`, based on merged PR #33 (`4035c99`). This is a local review candidate, not a release.

## Journey

The Last Lantern is the starting town. Successful missions move the party forward through different stops instead of repeatedly restoring the same sanctuary. Familiar service companions travel along the route.

| Progress in region | Hollow Graveyard | Frozen Wastes | Ember Rift |
| --- | --- | --- | --- |
| Arrival | The Last Lantern | Whitepass Refuge | Cinderwake Outpost |
| One expedition cleared | Gravediggers' Camp | Sledwright's Rest | Redwake Caravan |
| Two cleared | Bellwether Crossing | Rimewatch | Coalhaven |
| Guardian approach | Vigil of Ash | Chapel of the Thaw | Gate of Embers |

Defeating the final guardian opens Dawn's Rest.

## State and compatibility

`CampaignWaystops.resolve()` reads committed biome, cleared-node count, and completion state. The existing controller remains the only progression authority. No new save field, migration, reward rule, or balance change is needed.

A failed expedition or withdrawal leaves the party at its previous stop. Pending road events, result acknowledgment, retries, and reloads do not independently move it. Guardian success already advances the biome and resets its clear list atomically; the presentation follows that saved result. Existing saves therefore resolve into their appropriate stop immediately.

## Preview

Use the task output `Play Onward Journey Preview.command`. It launches this isolated checkout with the separate `Soulbound_OnwardPreview_20261008` profile, copied once from the original player files. Choose New Campaign for the full Last Lantern to Gravediggers' Camp transition, or Continue Campaign to view the copied checkpoint's place in the journey.

The local `override.cfg` is excluded from Git. Checking the branch out elsewhere does not isolate saves by itself.

## Verification

Godot 4.7.2 integrated checks passed: waystop progression 66; windowed first-arrival variant 70 including two native 1280×720 captures; all-stop movement/service and presentation checks 571; world progression 50; existing walk-town 43, UI behavior, backdrop, sound lifecycle, and campaign lifecycle 150. Evidence: this task's `work/onward-evidence/integrated/` logs.

The first-arrival harness mounts the real Shell/Main flow and injects a successful result; it does not play another five-minute combat round. It checks the saved result, new physical camp, acknowledgement without scene replacement, and reload. Later guardian-approach setup uses saved-state fixtures. All 13 stops were exercised using directional movement and the interaction action to reach/open all seven services. Six native 1280×720 rendered fixtures were inspected, including all three climates and completion; this is not a full human campaign playthrough or balance assessment.

Original player profile primary/backups (six file states) and the original checkout's project settings match the pre-work fingerprints. The preview uses a separate copied profile. Some headless harnesses still emit ObjectDB/resource shutdown warnings after their success markers; no failed assertions or script errors remain in final runs. Save schema, controller progression, economy, and balance were not changed.

Native Luna implemented the bounded packages; independent native Sol reviewed the production diffs and corrections. Jev routing was unavailable, so the native assignment was retained. The branch is local and has not been pushed or merged.
