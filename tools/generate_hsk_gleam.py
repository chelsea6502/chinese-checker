#!/usr/bin/env python3
"""Generate hsk.gleam source file from HSK word list text files."""

import os

KNOWN_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "known")
OUTPUT_FILE = os.path.join(
    os.path.dirname(__file__), "..", "src", "chinese_checker", "hsk.gleam"
)

# Mapping from function/constant name to filename
WORD_LISTS = [
    ("hsk1", "HSK1.txt"),
    ("hsk2", "HSK2.txt"),
    ("hsk3", "HSK3.txt"),
    ("hsk4", "HSK4.txt"),
    ("hsk5", "HSK5.txt"),
    ("hsk_band1", "HSKBand1.txt"),
    ("hsk_band2", "HSKBand2.txt"),
    ("hsk_band3", "HSKBand3.txt"),
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
            # Strip tab and everything after it
            if "\t" in line:
                line = line.split("\t")[0]
            # Strip # suffix
            if "#" in line:
                line = line.split("#")[0]
            line = line.strip()
            if line:
                words.append(line)
    return words


def generate_gleam() -> str:
    """Generate the full Gleam source file content."""
    parts: list[str] = []

    # Imports
    parts.append("import gleam/list")
    parts.append("import gleam/option.{type Option, None, Some}")
    parts.append("import gleam/set.{type Set}")
    parts.append("import gleam/string")
    parts.append("")

    # For each word list, emit a const and a pub fn
    for name, filename in WORD_LISTS:
        filepath = os.path.join(KNOWN_DIR, filename)
        words = read_words(filepath)
        # Build the escaped constant string with words joined by \n
        escaped = "\\n".join(words)
        parts.append(f'const {name}_words = "{escaped}"')
        parts.append("")
        parts.append(f"pub fn {name}() -> Set(String) {{")
        parts.append(f"  {name}_words")
        parts.append('  |> string.split("\\n")')
        parts.append("  |> set.from_list")
        parts.append("}")
        parts.append("")

    # known_words_for_levels function
    parts.append("pub fn known_words_for_levels(")
    parts.append("  old_level: Option(Int),")
    parts.append("  new_level: Option(Int),")
    parts.append(") -> Set(String) {")
    parts.append("  let old = case old_level {")
    parts.append("    None -> set.new()")
    parts.append("    Some(1) -> hsk1()")
    parts.append("    Some(2) -> set.union(hsk1(), hsk2())")
    parts.append("    Some(3) -> set.union(set.union(hsk1(), hsk2()), hsk3())")
    parts.append("    Some(4) -> set.union(set.union(set.union(hsk1(), hsk2()), hsk3()), hsk4())")
    parts.append("    Some(5) -> set.union(set.union(set.union(set.union(hsk1(), hsk2()), hsk3()), hsk4()), hsk5())")
    parts.append("    Some(_) -> set.new()")
    parts.append("  }")
    parts.append("  let new = case new_level {")
    parts.append("    None -> set.new()")
    parts.append("    Some(1) -> hsk_band1()")
    parts.append("    Some(2) -> set.union(hsk_band1(), hsk_band2())")
    parts.append("    Some(3) -> set.union(set.union(hsk_band1(), hsk_band2()), hsk_band3())")
    parts.append("    Some(_) -> set.new()")
    parts.append("  }")
    parts.append("  set.union(old, new)")
    parts.append("}")
    parts.append("")

    return "\n".join(parts)


def main() -> None:
    output = generate_gleam()
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(output)
    print(f"Generated {os.path.abspath(OUTPUT_FILE)}")
    # Count words per list for verification
    for name, filename in WORD_LISTS:
        filepath = os.path.join(KNOWN_DIR, filename)
        words = read_words(filepath)
        print(f"  {name}: {len(words)} words")


if __name__ == "__main__":
    main()
