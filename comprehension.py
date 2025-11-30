"""
Chinese Comprehension Checker

Analyzes Chinese text from clipboard to calculate comprehension based on known words.
Uses dynamic programming for optimal word segmentation.
"""

import jieba
import pyperclip
import re
import os
import unicodedata
from collections import Counter
from pypinyin import pinyin, Style
from typing import List, Tuple, Set, Dict
from re import compile as _Re

try:
    import pdfminer.high_level
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False


# Constants
MAX_WORD_LENGTH = 4
DEFAULT_KNOWN_WORDS_PATH = "known.txt"
MAX_UNKNOWN_WORDS_DISPLAY = 50

# Comprehensive punctuation set
PUNCTUATION_CHARS = set(
    ',.:()!@[]+/\\！?？｡。＂＃＄％＆＇（）＊＋，－／：；＜＝＞＠［＼］＾＿｀｛｜｝～'
    '｟｠｢｣､、〃《》「」『』【】〔〕〖〗〘〙〚〛〜〝〞〟〰〾〿–—''‛""„‟…‧﹏.?;﹔|.-·-*─\'\'\"\""'
)

# Unicode character splitter for proper Chinese character handling
_unicode_chr_splitter = _Re(r"(?s)((?:[\ud800-\udbff][\udc00-\udfff])|.)").split


# ============================================================================
# SHARED UTILITY FUNCTIONS
# ============================================================================

def load_word_list_from_file(filepath: str) -> Set[str]:
    """
    Load a word list from a file and expand it with individual characters.
    
    This function:
    1. Reads words from the file (one per line)
    2. Removes whitespace and empty entries
    3. Adds individual characters from each word to the set
    
    The character expansion assumes learners know individual characters
    used in words they know. This helps recognize compound words like
    慢慢的 even if not explicitly in the word list.
    
    Args:
        filepath: Path to the word list file
        
    Returns:
        Set of words and their constituent characters
        
    Raises:
        FileNotFoundError: If the file doesn't exist
        IOError: If there's an error reading the file
    """
    try:
        with open(filepath, "r", encoding="utf8") as word_file:
            content = word_file.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Word list file not found: {filepath}")
    except IOError as e:
        raise IOError(f"Error reading word list file: {e}")
    
    # Split on whitespace and filter empty strings
    words = set(re.sub(r"\s+", "\n", content).split("\n"))
    words.discard("")  # Remove empty string if present
    
    finalized_words = words.copy()
    
    # Add individual characters from each word
    # Assumes learner knows characters used in every word they know
    for word in words:
        for char in word:
            finalized_words.add(char)
    
    return finalized_words


def text_clean_up(text: str) -> str:
    """
    Clean up text by removing whitespace and diacritics.
    
    This function:
    1. Removes all whitespace (spaces, tabs, newlines)
    2. Removes diacritical marks while preserving base characters
    
    Args:
        text: Input text to clean
        
    Returns:
        Cleaned text string
    """
    # Remove all whitespace
    text_no_whitespace = "".join(re.sub(r"\s+", "\n", text).split("\n"))
    
    # Remove diacritics using Unicode normalization
    normalized = unicodedata.normalize("NFKD", text_no_whitespace)
    result = "".join(c for c in normalized if unicodedata.category(c) != "Mn")
    
    return result


def remove_exclusions(
    word_list: List[str],
    additional_exclusions: List[str],
    do_punctuations: bool = False
) -> List[str]:
    """
    Remove excluded words and optionally punctuation from a word list.
    
    Args:
        word_list: List of words to filter
        additional_exclusions: List of words to exclude (e.g., proper nouns)
        do_punctuations: Whether to also filter out punctuation (default: False)
        
    Returns:
        Filtered word list
        
    Note:
        Punctuation filtering is disabled by default as per industry standard.
        English letters and numbers are always filtered out.
    """
    filtered_list = word_list.copy()
    
    # Optionally remove punctuation
    if do_punctuations:
        punctuation_set = set(PUNCTUATION_CHARS)
        filtered_list = [word for word in filtered_list if word not in punctuation_set]
    
    # Remove additional exclusions and ASCII alphanumeric content
    filtered_list = [
        word for word in filtered_list
        if word not in additional_exclusions and not re.match(r'[a-zA-Z0-9]+', word)
    ]
    
    return filtered_list


def round_to_nearest_base(x: float, base: int = 50) -> int:
    """
    Round a number to the nearest multiple of a base value.
    
    Args:
        x: Number to round
        base: Base value to round to (default: 50)
        
    Returns:
        Rounded integer value
        
    Example:
        >>> round_to_nearest_base(123, 50)
        100
        >>> round_to_nearest_base(149, 50)
        150
    """
    return base * round(x / base)


def text_setup(filepath: str) -> str:
    """
    Load text from a file, supporting both .txt and .pdf formats.
    
    Args:
        filepath: Path to the text file
        
    Returns:
        Text content from the file
        
    Raises:
        FileNotFoundError: If the file doesn't exist
        ValueError: If PDF support is not available but PDF file is provided
        IOError: If there's an error reading the file
    """
    _, file_extension = os.path.splitext(filepath)
    
    if file_extension.lower() == ".pdf":
        if not PDF_SUPPORT:
            raise ValueError(
                "PDF support not available. Install pdfminer.six: "
                "pip install pdfminer.six"
            )
        try:
            return pdfminer.high_level.extract_text(filepath)
        except Exception as e:
            raise IOError(f"Error extracting text from PDF: {e}")
    else:
        # Assume text format
        try:
            with open(filepath, "r", encoding="utf8") as text_file:
                return text_file.read()
        except FileNotFoundError:
            raise FileNotFoundError(f"Text file not found: {filepath}")
        except IOError as e:
            raise IOError(f"Error reading text file: {e}")


def split_unicode_chrs(text: str) -> List[str]:
    """
    Split a Chinese text character by character, handling surrogate pairs.
    
    This function properly handles Unicode surrogate pairs (characters
    outside the Basic Multilingual Plane) which are represented as two
    16-bit code units in UTF-16.
    
    Args:
        text: Text to split into characters
        
    Returns:
        List of individual characters
        
    Note:
        Courtesy of 'flow' on StackOverflow: https://stackoverflow.com/a/3798790/12876940
    """
    return [char for char in _unicode_chr_splitter(text) if char]


# ============================================================================
# COMPREHENSION CHECKER FUNCTIONS
# ============================================================================

def dp_tokenize(text: str, known_words: Set[str]) -> List[str]:
    """
    Tokenize text using dynamic programming to find optimal segmentation.
    
    Maximizes coverage of known words, uses jieba for unknown sequences.
    
    Args:
        text: Input Chinese text to tokenize
        known_words: Set of known words for matching
        
    Returns:
        List of tokenized words
        
    Algorithm:
        - Uses DP to find optimal segmentation that maximizes known word coverage
        - Prefers longer known words over shorter ones
        - Falls back to jieba segmentation for unknown sequences
    """
    if not text:
        return []
    
    n = len(text)
    # dp[i] = (score, segmentation, last_unknown_start)
    # score: total length of known words matched
    # segmentation: list of (word, is_known) tuples
    # last_unknown_start: start index of current unknown sequence (-1 if none)
    dp: List[Tuple[float, List[Tuple[str, bool]], int]] = [
        (0, [], -1)
    ] + [(float('-inf'), [], -1)] * n
    
    for i in range(1, n + 1):
        # Try all possible last words ending at position i
        for j in range(max(0, i - MAX_WORD_LENGTH), i):
            word = text[j:i]
            
            if word in known_words:
                prev_score, prev_seg, prev_unknown_start = dp[j]
                
                # If there was an unknown sequence before this known word, segment it
                new_seg = prev_seg.copy()
                if prev_unknown_start != -1:
                    unknown_text = text[prev_unknown_start:j]
                    new_seg.extend([(w, False) for w in jieba.cut(unknown_text)])
                
                # Add this known word
                new_seg.append((word, True))
                
                # Score: prefer longer known words
                new_score = prev_score + len(word)
                
                if new_score > dp[i][0]:
                    dp[i] = (new_score, new_seg, -1)  # reset unknown start
        
        # If no known word ending at i, mark as unknown
        if dp[i][0] == float('-inf'):
            # Continue from best previous position
            best_prev = max(range(i), key=lambda x: dp[x][0])
            prev_score, prev_seg, prev_unknown_start = dp[best_prev]
            
            # Start or continue unknown sequence
            unknown_start = best_prev if prev_unknown_start == -1 else prev_unknown_start
            
            dp[i] = (prev_score, prev_seg.copy(), unknown_start)
    
    # Process final result
    final_score, final_seg, final_unknown_start = dp[n]
    
    # If there's a trailing unknown sequence, segment it
    if final_unknown_start != -1:
        unknown_text = text[final_unknown_start:n]
        final_seg.extend([(w, False) for w in jieba.cut(unknown_text)])
    
    # Return just the words (strip the is_known flag)
    return [word for word, _ in final_seg]


def should_filter_word(word: str) -> bool:
    """
    Determine if a word should be filtered out from analysis.
    
    Filters out:
    - Whitespace
    - Pure numbers
    - Pure punctuation
    - Words containing ASCII letters or numbers (e.g., S01E03Part4)
    
    Args:
        word: Word to check
        
    Returns:
        True if word should be filtered out, False otherwise
    """
    # Skip if it's whitespace
    if not word.strip():
        return True
    
    # Skip if it's purely numbers
    if word.isdigit():
        return True
    
    # Skip if it's purely punctuation
    if all(c in PUNCTUATION_CHARS for c in word):
        return True
    
    # Skip if it contains any ASCII letters or numbers
    if any(c.isascii() and (c.isalpha() or c.isdigit()) for c in word):
        return True
    
    return False


def filter_content(words: List[str]) -> List[str]:
    """
    Filter out punctuation, numbers, whitespace, and English/alphanumeric content.
    
    Args:
        words: List of words to filter
        
    Returns:
        Filtered list of words
    """
    return [word for word in words if not should_filter_word(word)]


def is_word_known(word: str, known_words: Set[str]) -> bool:
    """
    Check if a word is known based on the known words set.
    
    A word is considered "known" if:
    1. It's in the known_words list, OR
    2. All its characters are in the known_words list
    
    Args:
        word: Word to check
        known_words: Set of known words
        
    Returns:
        True if word is known, False otherwise
    """
    if word in known_words:
        return True
    
    # Check if all characters in the word are known
    return all(char in known_words for char in word)


def calculate_comprehension_stats(
    filtered_content: List[str],
    known_words: Set[str]
) -> Tuple[int, int, int, List[Tuple[str, int]]]:
    """
    Calculate comprehension statistics for the filtered content.
    
    Args:
        filtered_content: List of filtered words from text
        known_words: Set of known words
        
    Returns:
        Tuple of (total_words, unique_words, known_count, unknown_words_list)
        where unknown_words_list is sorted by frequency
    """
    counted_target = Counter(filtered_content)
    
    total_words = len(filtered_content)
    unique_words = len(counted_target)
    known_count = 0
    unknown_words = []
    
    for hanzi, count in counted_target.items():
        if is_word_known(hanzi, known_words):
            known_count += count
        else:
            unknown_words.append((hanzi, count))
    
    # Sort unknown words by frequency (descending)
    unknown_words.sort(key=lambda x: x[1], reverse=True)
    
    return total_words, unique_words, known_count, unknown_words


def format_unknown_words(unknown_words: List[Tuple[str, int]], max_display: int = MAX_UNKNOWN_WORDS_DISPLAY) -> str:
    """
    Format unknown words list with pinyin for display.
    
    Args:
        unknown_words: List of (word, count) tuples
        max_display: Maximum number of words to display
        
    Returns:
        Formatted string of unknown words with pinyin
    """
    if not unknown_words:
        return ""
    
    result = "\n\n=== Unknown Words (by frequency) ==="
    
    for word, count in unknown_words[:max_display]:
        # Get pinyin for the word
        word_pinyin = ' '.join([''.join(p) for p in pinyin(word, style=Style.TONE)])
        result += f"\n{word} ({word_pinyin}) : {count}"
    
    if len(unknown_words) > max_display:
        result += f"\n... and {len(unknown_words) - max_display} more"
    
    return result


def format_results(
    total_words: int,
    unique_words: int,
    known_count: int,
    unknown_words: List[Tuple[str, int]]
) -> str:
    """
    Format comprehension results for display.
    
    Args:
        total_words: Total word count
        unique_words: Number of unique words
        known_count: Number of known words
        unknown_words: List of unknown words with counts
        
    Returns:
        Formatted result string
    """
    if total_words == 0:
        return "Error: No Chinese text found in clipboard after filtering"
    
    comprehension_percentage = (known_count / total_words) * 100
    
    result = (
        f"\nWord Count: {total_words}"
        f"\nTotal Unique Words: {unique_words}"
        f"\nComprehension: {comprehension_percentage:.1f}%"
        f"\nUnique Unknown Words: {len(unknown_words)}"
    )
    
    result += format_unknown_words(unknown_words)
    
    return result


def get_clipboard_text() -> str:
    """
    Get text from clipboard with error handling.
    
    Returns:
        Clipboard text content
        
    Raises:
        ValueError: If clipboard is empty
    """
    text = pyperclip.paste()
    if not text:
        raise ValueError("Clipboard is empty")
    return text


def comprehension_checker(known_words_path: str = DEFAULT_KNOWN_WORDS_PATH) -> str:
    """
    Main function to check comprehension of Chinese text from clipboard.
    
    Process:
    1. Load known words from file
    2. Get text from clipboard
    3. Clean and tokenize text using DP algorithm
    4. Filter out non-Chinese content
    5. Calculate comprehension statistics
    6. Format and return results
    
    Args:
        known_words_path: Path to file containing known words
        
    Returns:
        Formatted comprehension report string
        
    Raises:
        ValueError: If clipboard is empty or no Chinese text found
        FileNotFoundError: If known words file doesn't exist
    """
    try:
        # Load known words from file
        known_words = load_word_list_from_file(known_words_path)
        
        # Get text from clipboard
        target_text = get_clipboard_text()
        
        # Clean up text (remove whitespace, diacritics)
        cleaned_text = text_clean_up(target_text)
        
        # Use DP tokenization for optimal segmentation
        tokenized_text = dp_tokenize(cleaned_text, known_words)
        
        # Filter out punctuation, numbers, whitespace, and English content
        filtered_content = filter_content(tokenized_text)
        
        # Calculate comprehension statistics
        total_words, unique_words, known_count, unknown_words = calculate_comprehension_stats(
            filtered_content, known_words
        )
        
        # Format and return results
        return format_results(total_words, unique_words, known_count, unknown_words)
        
    except FileNotFoundError as e:
        return f"Error: Known words file not found at '{known_words_path}'"
    except ValueError as e:
        return f"Error: {str(e)}"
    except Exception as e:
        return f"Error: An unexpected error occurred: {str(e)}"


if __name__ == "__main__":
    print(comprehension_checker())
