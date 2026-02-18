#!/usr/bin/env python3
"""Generate hsk.json asset from HSK word list text files."""

import json
import os

KNOWN_DIR = os.path.join(os.path.dirname(__file__), "..", "known")
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "..", "assets", "hsk.json")

WORD_LISTS = [
    ("hsk1", "HSK1.txt"),
    ("hsk2", "HSK2.txt"),
    ("hsk3", "HSK3.txt"),
    ("hsk4", "HSK4.txt"),
    ("hsk5", "HSK5.txt"),
    ("band1", "HSKBand1.txt"),
    ("band2", "HSKBand2.txt"),
    ("band3", "HSKBand3.txt"),
]


def read_words(filepath: str) -> list[str]:
    """Read words from a file, one per line.

    - Skip blank lines and lines starting with #.
    - Strip tabs and # suffixes from each line.
    """
    words = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "\t" in line:
                line = line.split("\t")[0]
            if "#" in line:
                line = line.split("#")[0]
            line = line.strip()
            if line:
                words.append(line)
    return words


def main() -> None:
    data = {}
    for name, filename in WORD_LISTS:
        filepath = os.path.join(KNOWN_DIR, filename)
        words = read_words(filepath)
        data[name] = words
        print(f"  {name}: {len(words)} words")

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Generated {os.path.abspath(OUTPUT_FILE)}")


if __name__ == "__main__":
    main()
