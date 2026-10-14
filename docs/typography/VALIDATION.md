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
