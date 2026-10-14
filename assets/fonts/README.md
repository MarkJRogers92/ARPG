# Soulbound typography

- **Source Sans 3 Medium**: reading text, item lists, stats and comparisons.
- **Source Sans 3 Semibold**: buttons, selected item names and HUD counters.
- Real medium italic and semibold italic faces keep rich text in the same family.
- **Marcellus Regular**: title, realm names and major screen headings only.
- **Soulbound UI Symbols / Signs**: renamed subsets of Noto Sans Symbols 2 / Noto Sans Symbols for existing game symbols. Their outlines are unchanged; their line metrics match Source Sans so symbols cannot inflate all menu rows. OS font fallback is disabled for every imported font.

Source Sans uses tabular lining figures by default. The body resources explicitly disable proportional and old-style figure substitutions. `tools/typography_test.gd` checks digit widths at every representative UI size, symbol coverage, and line metrics. Use `UiStyle.heading` / `RunUi.heading` only for display text; dense text and numbers use the body or emphasis face. Panel text is crisp without outlines; labels over the world use a restrained 2 px outline.

## Provenance and redistribution

Initial fonts downloaded 2026-10-13; Medium weights added 2026-10-14, from the official [Adobe Source Sans repository](https://github.com/adobe-fonts/source-sans/tree/release), [Google Fonts Marcellus directory](https://github.com/google/fonts/tree/main/ofl/marcellus), and Google Fonts [Noto Sans Symbols](https://github.com/google/fonts/tree/main/ofl/notosanssymbols) / [Symbols 2](https://github.com/google/fonts/tree/main/ofl/notosanssymbols2) directories. Source Sans version 3.052; Marcellus version 1.000. `sources.json` records exact download URLs and SHA-256 hashes for the originals and derived fonts.

All fonts use the SIL Open Font License 1.1. Original license/copyright notices are retained in `SourceSans3-OFL.md`, `Marcellus-OFL.txt`, `NotoSansSymbols-OFL.txt` and `NotoSansSymbols2-OFL.txt`; font metadata also retains upstream notices. The Noto derivatives are renamed to Soulbound UI Symbols / Signs. All three export presets explicitly include the license files and provenance manifest. Do not sell these fonts on their own or remove the notices.

To reproduce the two symbol subsets, obtain the original files matching the manifest, install fontTools in a development environment, and run:

```sh
python3 tools/build_ui_symbol_fonts.py --source-dir /path/to/noto-originals
```

The game has no fontTools or network dependency.
