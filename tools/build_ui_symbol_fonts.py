#!/usr/bin/env python3
"""Build small, renamed OFL symbol faces with Source Sans 3 line metrics.

Input: the exact official Noto files recorded in assets/fonts/sources.json.
Usage: python3 tools/build_ui_symbol_fonts.py --source-dir /path/to/originals
Only glyphs absent from Source Sans are retained. Outlines are unchanged;
matching the line metrics prevents a symbol fallback enlarging all UI rows.
"""
import argparse
import hashlib
import json
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-dir', required=True, type=Path)
args = parser.parse_args()
target = Path(__file__).resolve().parents[1] / 'assets/fonts'
manifest = json.loads((target / "sources.json").read_text())
original_hashes = {record["file"]: record["sha256"] for record in manifest["files"]}
for original, name, characters in [
    ('NotoSansSymbols2-Regular.ttf', 'Soulbound UI Symbols', '♜☠❄★▣✦✧⌖◇☆↯'),
    ('NotoSansSymbols.ttf', 'Soulbound UI Signs', '⚑⚒⚔'),
]:
    source = args.source_dir / original
    if hashlib.sha256(source.read_bytes()).hexdigest() != original_hashes[original]:
        raise SystemExit("Source hash differs from recorded upstream file: " + original)
    font = TTFont(source)
    options = subset.Options()
    options.name_IDs = ['*']  # Retain the upstream copyright and license records.
    options.name_legacy = True
    options.name_languages = ['*']
    build = subset.Subsetter(options=options)
    build.populate(unicodes=[ord(c) for c in characters])
    build.subset(font)
    # These selected symbols fit the body face's em box. The upstream metrics
    # also accommodate large, unused historic glyphs and musical notation.
    font['hhea'].ascent = 1000
    font['hhea'].descent = -326
    font['hhea'].lineGap = 0
    font['OS/2'].sTypoAscender = 1000
    font['OS/2'].sTypoDescender = -326
    font['OS/2'].sTypoLineGap = 0
    font['OS/2'].fsSelection |= 1 << 7
    for record in font['name'].names:
        if record.nameID in [1, 2, 3, 4, 6, 16, 17]:
            value = 'Regular' if record.nameID in [2, 17] else name
            if record.nameID == 6: value = name.replace(' ', '') + '-Regular'
            if record.nameID == 3: value = name + ' 2026-10-13'
            record.string = value.encode(record.getEncoding())
    output = target / (name.replace(' ', '') + '.ttf')
    font.save(output)
    print(output.name, output.stat().st_size)
