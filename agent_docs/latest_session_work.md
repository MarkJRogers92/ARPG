# Latest session work

## Expedition campaign — 2026-10-08

- Feature branch: `feature/expedition-campaign-v1`; base `3fe4ea0`.
- Task commits: `125043d`, `d0196d9`, `4be1500`, `a35ee41`, `3b67fec`, `aede952`, `473d471`.
- Campaign baseline HEAD: `473d471`; overnight checkpoint 1 HEAD: `3254886`.
- Overnight commits: `4a553ae`, `76d80aa`, `3254886`.
- Core, UI/combat integration, persistence, and Classic compatibility evidence is documented in `docs/expedition_campaign/VALIDATION.md`.
- Six full finale simulations succeeded after the 900-second boss arrival; varied fresh/tank attempts also failed. This does not establish universal balance.
- Normal-speed Hunt reached a real 300-second success at time scale 1 using automated input; no human enjoyment claim.
- Continuous journey passed: 12 real Main settlements succeeded across 12 unique attempts and three biome clears; Graveyard, Frozen Wastes, and Ember Rift guardians died at 995.74s, 916.64s, and 989.77s. It used an automated full-Necromancer account fixture, not a human balance test.
- Earlier fresh Ember bot attempts orbited at radius 6.8 while the meteor lure requires within 4. A corrected-lure fresh run still failed at 924.92s with three of four seals and 33,527.8 boss HP remaining; this single automated result is not a general balance conclusion.
- All six save/profile primary and backup fingerprints plus `project.godot` match the starting checkpoint. Test setup temporarily wrote two empty campaign fields and restored them; progression values were unchanged. Godot shutdown warnings remain possible.
- Preserve the local uncommitted `project.godot` 4.7 marker. No push, release, merge, deployment, or installed-app replacement.
- Later harness-only artifact/failure-preservation edits passed parser checks; the full journey was not rerun after them. Baseline campaign acceptance is complete; the overnight improvement task remains active, and remote push needs separate authorization.
- Overnight checkpoint 3 is integrated at `9211a01`: route previews show biome-scaled base gold before event/shard changes, optional Cursed Cache bonus, talent awards by mission and realm, and reserved Rare versus banked finale Legendary prizes. Veiled routes and existing reveal/availability/commit behavior remain unchanged. Parent diff review prompted repair of a vacuous state-preservation test; integrated UI passed (exit 0, no ERROR/WARNING). Parent inspected 720p/1080p fixture views, not live-play evidence. Protected player-file fingerprints and original `project.godot` bytes matched; no import churn. No full journey rerun for this view-only change. Overnight work remains active until 7:00 a.m. Chicago time; next bounded entry is to inspect one concrete combat/objective feedback moment or town friction against current state. Details: `docs/expedition_campaign/OVERNIGHT.md`.
