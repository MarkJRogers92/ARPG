# Typography review — 2026-10-13

Local branch `codex/typography-polish`, based on current default release `6ea00372e6c020a066ba923d4c736b591a1394aa` (PR #55). No push, merge or installed-build replacement.

## Changes

- Bundled Source Sans 3 regular/semibold/italic weights for readable body text and counters; restrained Marcellus for title and major headings.
- Shared font roles across title, HUD, pause/settings/Controls, inventory/Nearby, item/build comparisons, upgrades, build guide, chest/Forge choices and end screen; the same body face now covers 3D loot, shrine and town labels.
- Tabular lining figures prevent number-width jitter. True rich-text weights and fully bundled symbol coverage remove platform-specific font substitutions.
- Reduced outlines on panels, kept a light outline over the world, raised secondary-text contrast and comparison/list sizing, and eased all-caps headings.
- Wrapping for choice copy, realm footers and item metadata; long item names remain two lines with ellipsis and full tooltip; item lists use ellipsis. Existing scrolling and keyboard focus paths remain.
- Font OFL licenses, source hashes and derivative-generation script retained. Export presets include license/provenance files.

No gameplay, balance, saves, API use, art generation or changes to Horse/Post Mortem.

## Evidence

Local evidence root: `/Users/markrogers/Documents/Codex/2026-10-13/task-4/evidence/`.

`before/` and `after/` each contain 42 native PNGs: title, HUD, pause, Controls, build guide, Equipment, Nearby, long item, upgrades, chest, Forge inspection/comparison, shrine and game-over at **960×540**, **1280×720** and **1920×1080**. `layouts.json` records actual physical window dimensions, logical bounds and action/control rectangles. The 16:9 game uses its normal 1280×720 logical canvas and scales it to each physical size; the PNG dimensions are independently asserted.

The screenshots use real Main and UI classes with deterministic disposable fixtures. They are rendered on Apple M2 / native Metal OpenGL Compatibility, with offscreen unfocused development windows and Dummy audio. The installed app is never launched, focused, closed or replaced. Fixture profiles are separate `SoulboundTypographyBefore` / `SoulboundTypographyAfter` paths linked to this task's `userdata/` directories; they cannot overwrite the ARPG profile. Source release project settings are unchanged.

Verification engine: local Godot **4.7.2** standard editor binary, copied and ad-hoc signed in the task's `toolchain/` directory. The project targets 4.6; this pass does not upgrade that version or claim a 4.6 runtime run.

## Checks

- Native before/after review: 42 layouts per version, zero viewport/action-bound failures.
- Font contracts: 436 checks, zero failures (digits, glyphs, line metrics, theme roles).
- Existing title/pause/inventory contract caught and verified correction of symbol-font line-height inflation and realm-footer clipping.
- **53/53 full headless suites passed**, including the new font contracts and existing UI, Forge/Nearby, guide, campaign and core regression tests; see `evidence/all-tests.log` and `evidence/tests-final/`.
- `git diff --check` passed.

## Limits

This is a controlled visual/layout and regression review, not a full human campaign or a performance benchmark. Known Godot ObjectDB/resource/audio shutdown diagnostics may still occur; no runtime cleanup change or warning-free production claim is made. No packaged export, CI, push, merge, deployment, real-profile testing or installed build update was performed. The original checkout and its unrelated import edits are preserved.

## Revision 2 — stronger reading text and menu grouping

Previous candidate remains recoverable at `4f3da92` and local branch `codex/typography-candidate-1`; its screenshots and first Library version are retained.

- Replaced the light regular body face with true Source Sans 3 Medium / Medium Italic, retaining semibold emphasis and Marcellus headings.
- Increased inventory/list/comparison text from 15 to 17 logical pixels. Small label text now has a 14 px floor; ordinary 15–17 px labels gain one pixel. Secondary copy is brighter.
- Enlarged Soulbound from 48 to 64 px. A compact branding row sits above hero selection; hero/loadout details and campaign actions have separate aligned blocks; wider realm cards hold the larger reading text. Every existing action remains available.
- The hero detail area has bounded scrolling and keyboard access for long descriptions, resets when a new hero is previewed, and cannot push the footer offscreen. Reliquary retains full loadout text in its tooltip when the button needs ellipsis. Resume the night shares the branding row.

Revision evidence is in `evidence/revision-2/after/`. Native checks repeat all three physical sizes and all five class detail states. Affected suites were run first. Final revision: **53/53 full suites passed**, **436 font checks passed**, and **42/42 native layouts passed** across 960×540, 1280×720 and 1920×1080, including all class-detail states. Results are recorded in `evidence/revision-2/all-tests.log` and `evidence/revision-2/validation.json`.
