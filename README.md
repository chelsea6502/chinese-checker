# Chinese Comprehension Checker

Analyze Chinese text from your clipboard to gauge comprehension based on your known words.

## Features
- Analyzes Chinese text directly from clipboard
- Uses dynamic programming for optimal word segmentation
- Calculates comprehension percentage based on known words
- Lists unknown words with pinyin and frequency
- Supports optional `unknown.txt` file to exclude compound words from being counted as known
- Filters out punctuation, numbers, and English content automatically

## Requirements
* Python 3.9 or above
* [jieba](https://github.com/fxsjy/jieba) - Chinese character segmentation library
* pyperclip - Clipboard access
* pypinyin - Pinyin conversion

## Installation

### Step 1: Install Python
Download Python 3.9 or above from [python.org](https://www.python.org/downloads/)

### Step 2: Clone or Download
```bash
git clone https://github.com/chelsea6502/chinese-comprehension.git
cd chinese-comprehension
```

### Step 3: Install Dependencies
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage
1. Copy Chinese text to your clipboard
2. Run the script:
```bash
python script.py
```

### Known Words File
By default, the script looks for `known.txt` in the same directory. To use a different file, modify the `DEFAULT_KNOWN_WORDS_PATH` constant in the script.

Create a `known.txt` file with one word per line:
```
是
你好
再见
有
五
```

### Unknown Words File (Optional)
Create an optional `unknown.txt` file to list compound words that should NOT be counted as known, even if all their individual characters are known. This prevents false positives where compound words are incorrectly counted as known.

Format (one word per line, comments with # are optional):
```
好吃	# hǎo chī
道理	# dào lǐ
行者	# xíng zhě
```

**Why use this?** If you know the characters 好 and 吃 individually, the script would normally count 好吃 as "known". But if you haven't learned 好吃 as a compound word, add it to `unknown.txt` to exclude it from your comprehension calculation.

**Note:** If a word appears in both `known.txt` and `unknown.txt`, it will be treated as known (explicit entries in `known.txt` take priority).

## Example Output

```
Word Count: 1523
Total Unique Words: 487
Comprehension: 92.3%
Unique Unknown Words: 23

=== Unknown Words (by frequency) ===
道 (dào) : 15 - way, path, principle
行者 (xíng zhě) : 8 - traveler, pilgrim
裏 (lǐ) : 6 - inside, interior
與 (yǔ) : 5 - and, with, to give
...
```

## License

MIT License - feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
