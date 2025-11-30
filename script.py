"""
Chinese Comprehension Checker

Analyzes Chinese text from clipboard to calculate comprehension based on known words.
Uses dynamic programming for optimal word segmentation.
"""

import jieba
import pyperclip
import unicodedata
from collections import Counter, namedtuple
from pypinyin import pinyin, Style
from typing import List, Set

# Constants
MAX_WORD_LENGTH = 4
DEFAULT_KNOWN_WORDS_PATH = "known.txt"
UNKNOWN_WORDS_PATH = "unknown.txt"
MAX_UNKNOWN_WORDS_DISPLAY = 50

# Comprehensive punctuation set
PUNCTUATION_CHARS = set(
    ',.:()!@[]+/\\！?？｡。＂＃＄％＆＇（）＊＋，－／：；＜＝＞＠［＼］＾＿｀｛｜｝～'
    '｟｠｢｣､、〃《》「」『』【】〔〕〖〗〘〙〚〛〜〝〞〟〰〾〿–—''‛""„‟…‧﹏.?;﹔|.-·-*─\'\'\"\""'
)

# Named tuple for DP state
DPState = namedtuple('DPState', ['score', 'segmentation', 'unknown_start'])


def comprehension_checker(known_words_path: str = DEFAULT_KNOWN_WORDS_PATH) -> str:
    """Check comprehension of Chinese text from clipboard against known words."""
    try:
        # Load known words and expand with individual characters
        with open(known_words_path, encoding="utf8") as f:
            base_words = set(f.read().split())
        known_words = base_words.copy()
        for word in base_words:
            known_words.update(word)
        
        # Load unknown words to exclude from known word counting
        unknown_words_list = set()
        try:
            with open(UNKNOWN_WORDS_PATH, encoding="utf8") as f:
                for line in f:
                    # Skip comments and empty lines
                    line = line.strip()
                    if line and not line.startswith('#'):
                        # Extract word (before any tab or comment)
                        word = line.split('\t')[0].split('#')[0].strip()
                        if word:
                            unknown_words_list.add(word)
        except FileNotFoundError:
            pass  # unknown.txt is optional
        
        text = pyperclip.paste()
        if not text:
            raise ValueError("Clipboard is empty")
        
        # Clean up: remove whitespace and diacritics
        normalized = unicodedata.normalize("NFKD", "".join(text.split()))
        cleaned = "".join(c for c in normalized if unicodedata.category(c) != "Mn")
        
        if not cleaned:
            return "Error: No Chinese text found in clipboard after filtering"
        
        # DP tokenization to maximize known word coverage
        n = len(cleaned)
        dp: List[DPState] = [DPState(0, [], -1)] + [DPState(float('-inf'), [], -1)] * n
        
        for i in range(1, n + 1):
            for j in range(max(0, i - MAX_WORD_LENGTH), i):
                word = cleaned[j:i]
                
                if word in known_words:
                    prev = dp[j]
                    new_seg = prev.segmentation.copy()
                    
                    if prev.unknown_start != -1:
                        new_seg.extend([(w, False) for w in jieba.cut(cleaned[prev.unknown_start:j])])
                    
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
            result.extend([(w, False) for w in jieba.cut(cleaned[final.unknown_start:n])])
        
        # Filter to valid Chinese words only
        def is_valid(word: str) -> bool:
            return (
                word.strip()
                and not word.isdigit()
                and not all(c in PUNCTUATION_CHARS for c in word)
                and not any(c.isascii() and (c.isalpha() or c.isdigit()) for c in word)
            )
        
        words = [word for word, _ in result if is_valid(word)]
        
        if not words:
            return "Error: No Chinese text found in clipboard after filtering"
        
        # Calculate stats
        word_counts = Counter(words)
        # A word is known if it's in known_words AND not in unknown_words_list
        # This prevents compound words from being counted as known just because their characters are known
        is_known = lambda w: (w in known_words or all(c in known_words for c in w)) and w not in unknown_words_list
        
        total_words = len(words)
        unique_words = len(word_counts)
        known_count = sum(count for word, count in word_counts.items() if is_known(word))
        unknown_words = sorted(
            [(w, c) for w, c in word_counts.items() if not is_known(w)],
            key=lambda x: x[1], reverse=True
        )
        
        # Format output
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
                word_pinyin = ' '.join(p[0] for p in pinyin(word, style=Style.TONE))
                lines.append(f"{word} ({word_pinyin}) : {count}")
            
            if len(unknown_words) > display_count:
                lines.append(f"... and {len(unknown_words) - display_count} more")
        
        return '\n'.join(lines)
        
    except FileNotFoundError:
        return f"Error: Known words file not found at '{known_words_path}'"
    except ValueError as e:
        return f"Error: {str(e)}"
    except Exception as e:
        return f"Error: An unexpected error occurred: {str(e)}"


if __name__ == "__main__":
    print(comprehension_checker())
