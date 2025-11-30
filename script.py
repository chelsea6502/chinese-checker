"""
Chinese Comprehension Checker

Analyzes Chinese text from clipboard to calculate comprehension based on known words.
Uses dynamic programming for optimal word segmentation.
"""

import jieba
import pyperclip
import re
import unicodedata
from collections import Counter, namedtuple
from pypinyin import pinyin, Style
from typing import List, Tuple, Set

# Constants
MAX_WORD_LENGTH = 4
DEFAULT_KNOWN_WORDS_PATH = "known.txt"
MAX_UNKNOWN_WORDS_DISPLAY = 50

# Comprehensive punctuation set
PUNCTUATION_CHARS = set(
    ',.:()!@[]+/\\！?？｡。＂＃＄％＆＇（）＊＋，－／：；＜＝＞＠［＼］＾＿｀｛｜｝～'
    '｟｠｢｣､、〃《》「」『』【】〔〕〖〗〘〙〚〛〜〝〞〟〰〾〿–—''‛""„‟…‧﹏.?;﹔|.-·-*─\'\'\"\""'
)

# Named tuple for DP state
DPState = namedtuple('DPState', ['score', 'segmentation', 'unknown_start'])

def load_word_list_from_file(filepath: str) -> Set[str]:
    """Load word list from file and expand with individual characters."""
    with open(filepath, encoding="utf8") as f:
        words = set(f.read().split())
    result = words.copy()
    for word in words:
        result.update(word)
    return result


def text_clean_up(text: str) -> str:
    """Remove whitespace and diacritics from text."""
    normalized = unicodedata.normalize("NFKD", "".join(text.split()))
    return "".join(c for c in normalized if unicodedata.category(c) != "Mn")


# ============================================================================
# COMPREHENSION CHECKER FUNCTIONS
# ============================================================================

def dp_tokenize(text: str, known_words: Set[str]) -> List[str]:
    """Tokenize text using DP to maximize known word coverage."""
    if not text:
        return []
    
    n = len(text)
    dp: List[DPState] = [DPState(0, [], -1)] + [DPState(float('-inf'), [], -1)] * n
    
    for i in range(1, n + 1):
        for j in range(max(0, i - MAX_WORD_LENGTH), i):
            word = text[j:i]
            
            if word in known_words:
                prev = dp[j]
                new_seg = prev.segmentation.copy()
                
                if prev.unknown_start != -1:
                    new_seg.extend([(w, False) for w in jieba.cut(text[prev.unknown_start:j])])
                
                new_seg.append((word, True))
                new_score = prev.score + len(word)
                
                if new_score > dp[i].score:
                    dp[i] = DPState(new_score, new_seg, -1)
        
        if dp[i].score == float('-inf'):
            best_prev = max(range(i), key=lambda x: dp[x].score)
            prev = dp[best_prev]
            unknown_start = best_prev if prev.unknown_start == -1 else prev.unknown_start
            dp[i] = DPState(prev.score, prev.segmentation.copy(), unknown_start)
    
    final = dp[n]
    result = final.segmentation.copy()
    
    if final.unknown_start != -1:
        result.extend([(w, False) for w in jieba.cut(text[final.unknown_start:n])])
    
    return [word for word, _ in result]


def filter_content(words: List[str]) -> List[str]:
    """Filter out punctuation, numbers, whitespace, and English content."""
    return [
        word for word in words
        if word.strip() and not word.isdigit()
        and not all(c in PUNCTUATION_CHARS for c in word)
        and not any(c.isascii() and (c.isalpha() or c.isdigit()) for c in word)
    ]


def calculate_comprehension_stats(filtered_content: List[str], known_words: Set[str]
                                 ) -> Tuple[int, int, int, List[Tuple[str, int]]]:
    """Calculate comprehension statistics and return unknown words by frequency."""
    word_counts = Counter(filtered_content)
    is_known = lambda w: w in known_words or all(c in known_words for c in w)
    
    known_count = sum(count for word, count in word_counts.items() if is_known(word))
    unknown_words = sorted(
        [(w, c) for w, c in word_counts.items() if not is_known(w)],
        key=lambda x: x[1], reverse=True
    )
    return len(filtered_content), len(word_counts), known_count, unknown_words


def format_results(total_words: int, unique_words: int, known_count: int,
                   unknown_words: List[Tuple[str, int]]) -> str:
    """Format comprehension results with unknown words list."""
    if not total_words:
        return "Error: No Chinese text found in clipboard after filtering"
    
    lines = [
        f"\nWord Count: {total_words}",
        f"Total Unique Words: {unique_words}",
        f"Comprehension: {known_count / total_words * 100:.1f}%",
        f"Unique Unknown Words: {len(unknown_words)}"
    ]
    
    if unknown_words:
        lines.append("\n=== Unknown Words (by frequency) ===")
        display_count = min(len(unknown_words), MAX_UNKNOWN_WORDS_DISPLAY)
        
        for word, count in unknown_words[:display_count]:
            word_pinyin = ' '.join(''.join(p) for p in pinyin(word, style=Style.TONE))
            lines.append(f"{word} ({word_pinyin}) : {count}")
        
        if len(unknown_words) > display_count:
            lines.append(f"... and {len(unknown_words) - display_count} more")
    
    return '\n'.join(lines)


def comprehension_checker(known_words_path: str = DEFAULT_KNOWN_WORDS_PATH) -> str:
    """Check comprehension of Chinese text from clipboard against known words."""
    try:
        known_words = load_word_list_from_file(known_words_path)
        text = pyperclip.paste()
        if not text:
            raise ValueError("Clipboard is empty")
        
        filtered = filter_content(dp_tokenize(text_clean_up(text), known_words))
        stats = calculate_comprehension_stats(filtered, known_words)
        return format_results(*stats)
        
    except FileNotFoundError:
        return f"Error: Known words file not found at '{known_words_path}'"
    except ValueError as e:
        return f"Error: {str(e)}"
    except Exception as e:
        return f"Error: An unexpected error occurred: {str(e)}"


if __name__ == "__main__":
    print(comprehension_checker())
