# Quiet Fantasy — local review, 2026-10-14

Branch: `codex/quiet-fantasy-menu`, on typography revision `51ac16a`, itself based on release `6ea00372e6c020a066ba923d4c736b591a1394aa` (PR #55). Prior candidates remain at `codex/typography-candidate-1` and `codex/typography-candidate-2`. No push, merge, export or installed-build replacement.

## Reference and implementation

Mark selected **B · Quiet Fantasy** in the supplied concept. The exact Library image was materialized using the supported transfer and verified as readable 1983×793 pixels before implementation:

- Library: `libfile_569771254c8c8191a0dcba6ae324aaa7`
- File version: `file_00000000745481f7b456ec4666a84004`
- SHA-256: `4e840f08263a948db1682a7b1c549b1758ee8d928960ea7c74783d2ae58bfb79`

The opening page now uses an ivory Marcellus title, muted gold diamond selection, thin rules, slate surfaces, vertical primary navigation and a real saved-campaign card. Small copy retains the readable Source Sans 3 Medium/Semibold family, tabular figures and bundled symbols from the typography pass; all font licenses/provenance remain in `assets/fonts/`.

Hero/class, Reliquary/loadout and realm choices move to adventure preparation. The Sanctum retains Altar, Pact, Bestiary, Crypt and Daily Night; direct Crypt and Daily links remain on the opening page. Settings reuses the actual settings/Controls panel with a title-specific Back action. Saved Gold, Soul Shards, hero, realm and campaign phase are read from the real save APIs.

The background and card thumbnail are live views of shipped 3D scenery. A menu-owned hero duplicate removes combat markers from the title composition. Its camera, hero and scenery hide on close; the original player and gameplay camera return. This follows B's composition and palette; it does **not** reproduce the concept's painted mountains, castle or moon. No new models, paid artwork, Meshy or API credits were used.

Page and modal ownership prevent hidden-page navigation. Back/Escape restores the opening action, class selection retains the preparation page and focus, and transition guards prevent duplicate starts. Existing campaign replacement and pause abandonment confirmations remain in use. No gameplay balance or save schema changes.

## Verification

Evidence root: `/Users/markrogers/Documents/Codex/2026-10-13/task-4/evidence/quiet-fantasy/`.

- **54/54** full headless suites passed (`all-tests.log`, `tests-full/`).
- Final menu flow: **161 checks, zero failures** (`final-flow-tests.log`). Real keyboard/controller event dispatch, modal focus/Back, repeated facility opening, save-byte preservation, cancellation, double Continue, confirmed New Campaign and double Classic scene transitions are covered. Controller menu mappings were missing and are now explicit for accept, back, D-pad and left stick.
- **36 native menu captures**, twelve views at each of **960×540, 1280×720 and 1920×1080**; **231 checks, zero failures** (`native-menu.log`, `after/`). Includes preparation, replacement confirmation, loadout, Settings and all secondary facilities.
- **45 native typography layouts**, zero failures across the same physical sizes (`native-typography.log`, `typography/layouts.json`): opening/Classic, HUD, pause, Controls, guide, Equipment, Nearby, long item, upgrades, chest, Forge inspection/comparison, shrine and game-over.
- **436 font contract checks** passed in the full suite. The 420-second smoke bot passed (`smoke.log`). `git diff --check` passed.

The normal logical canvas is 1280×720, scaled to the three asserted physical PNG sizes. `review.html` opens the menu capture matrix; `Soulbound-Quiet-Fantasy-before-after.png` compares the actual shipped title and final development title at 1280×720. Screenshots use deterministic disposable scene fixtures, not fabricated image labels.

Preview projects use separate `SoulboundTypographyBefore` / `SoulboundTypographyAfter` userdata linked inside this task. Native windows are offscreen and unfocused, with Dummy audio. `/Applications/Soulbound.app`, the real ARPG saves, Horse, Post Mortem and the original checkout's unrelated imports were untouched.

## New Library deliverables

The earlier typography contact sheet was not overwritten. New items and complete version identities are recorded in `evidence/quiet-fantasy/library-identities.json`; Library identity/version xattrs were applied and verified on each local original.

| Actual capture | Library ID | File version ID |
| --- | --- | --- |
| Home, 1280×720 | `libfile_09372039d6a0819189614c9e18e9be59` | `file_0000000020ac81f7923af1336f29a403` |
| Classic, 960×540 | `libfile_603f6f50b0008191b1c6b6cad01079a3` | `file_00000000dfb881f7a22ab826b27591f3` |
| Settings, 1280×720 | `libfile_583d3d57f2cc8191b7555861015eb704` | `file_00000000c7c881f7ad15877375a40d38` |
| Before/after comparison | `libfile_5718827de22c819189e5a40fd5af4c32` | `file_00000000514881f7b992284ecd768b9f` |

## Limits

Validation used native Godot **4.7.2**, Compatibility renderer on Apple M2; the repository still targets 4.6 and no 4.6 packaged build was tested. Known engine ObjectDB/resource/audio shutdown diagnostics remain. This is controlled visual/input and regression evidence, not a human full-campaign playthrough or performance benchmark. No physical controller hardware was attached; controller checks dispatch genuine joypad input events through Godot's input pipeline. No remaining implementation blocker.
