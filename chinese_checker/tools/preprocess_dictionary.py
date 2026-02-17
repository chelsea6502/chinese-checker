#!/usr/bin/env python3
"""Convert CC-CEDICT definitions.txt to a compact JSON dictionary.

Output format: { "simplified": { "p": "pinyin", "d": "definition" }, ... }
Short keys reduce file size.  Only simplified Chinese entries are stored.
"""

import json
import re
import sys
from pathlib import Path

CEDICT_PATH = Path(__file__).resolve().parents[2] / "definitions.txt"
OUTPUT_PATH = Path(__file__).resolve().parent.parent / "static" / "dictionary.json"


def parse_cedict(path: Path) -> dict[str, dict[str, str]]:
    entries: dict[str, dict[str, str]] = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Format: Traditional Simplified [pinyin] /def1/def2/.../
            m = re.match(r"(\S+)\s+(\S+)\s+\[([^\]]+)\]\s+/(.+)/", line)
            if not m:
                continue

            _traditional, simplified, pinyin, defs = m.groups()
            # Take all definitions joined by "; "
            definition = "; ".join(d for d in defs.split("/") if d)

            # Only keep first entry for each simplified form
            if simplified not in entries:
                entries[simplified] = {"p": pinyin, "d": definition}

    return entries


def main() -> None:
    if not CEDICT_PATH.exists():
        print(f"Error: {CEDICT_PATH} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Parsing {CEDICT_PATH} ...")
    entries = parse_cedict(CEDICT_PATH)
    print(f"Parsed {len(entries)} entries")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, separators=(",", ":"))

    size_mb = OUTPUT_PATH.stat().st_size / (1024 * 1024)
    print(f"Wrote {OUTPUT_PATH}  ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
