# Chinese Checker

Analyze Chinese text from input files to gauge comprehension based on your known words.

## Acknowledgments

This project is based on [Destaq/chinese-comprehension](https://github.com/Destaq/chinese-comprehension) as the starting point.

## Features
- Batch text file analysis with comprehension percentage
- pkuseg word segmentation (~97% accuracy)
- Automatic proper noun detection (excludes names/places)
- Unknown words listed with pinyin, frequency, and definitions
- Organize known/unknown words across multiple `.txt` files

## Requirements
Python 3.9+ and dependencies in `requirements.txt` (pkuseg, spaCy, pypinyin)

## Installation

### Option 1: Docker (Recommended)

```bash
git clone https://github.com/chelsea6502/chinese-checker.git
cd chinese-checker
chmod +x run.sh
./run.sh
```

### Option 2: Local Installation

```bash
git clone https://github.com/chelsea6502/chinese-checker.git
cd chinese-checker
pip install -r requirements.txt
```

Models (pkuseg + spaCy zh_core_web_sm) download automatically on first run.

## Usage

### Docker

1. Place Chinese text files (`.txt`) in the `input/` directory
2. Run: `./run.sh`

The volumes are mounted, so you can add/modify files in `input/`, `known/`, and `unknown/` directories without rebuilding.

### Local

1. Place Chinese text files (`.txt`) in the `input/` directory
2. Run: `python script.py`

The script will process all `.txt` files in the `input/` directory and generate a comprehension report for each file.

### Known Words Directory
Create `.txt` files in the `known/` directory with one word per line. You can organize words across multiple files:

**known/hsk1.txt:**
```
是
你好
再见
```

**known/hsk2.txt:**
```
有
五
```

### Unknown Words Directory (Optional)
Create `.txt` files in the `unknown/` directory to list compound words that shouldn't count as known even if individual characters are known:

**unknown/compounds.txt:**
```
好吃	# hǎo chī
道理	# dào lǐ
行者	# xíng zhě
```

Entries in `known/` files take priority over `unknown/` files.

## Example Output

```
============================================================
File: story.txt
============================================================

Word Count: 1523
Total Unique Words: 487
Comprehension: 92.3% - 🟢 Optimal (i+1)
Unique Unknown Words: 23

=== Unknown Words (by frequency) ===
道 (dào) : 15 - way, path, principle
行者 (xíng zhě) : 8 - traveler, pilgrim
裏 (lǐ) : 6 - inside, interior
與 (yǔ) : 5 - and, with, to give
...
```

## Technical Details

**Segmentation Strategy:**
1. Match against all `.txt` files in `known/` directory (dynamic programming)
2. Match against all `.txt` files in `unknown/` directory
3. Fallback to pkuseg for remaining text

**Proper Noun Detection:** spaCy NER excludes PERSON, GPE, ORG, FAC, LOC entities from calculations.

## License

MIT
