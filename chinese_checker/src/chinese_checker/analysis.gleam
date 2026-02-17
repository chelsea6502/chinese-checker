import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/set.{type Set}
import gleam/string

import chinese_checker/dictionary
import chinese_checker/model.{
  type AnalysisResult, type Assessment, type DictEntry, AnalysisResult,
  Challenging, Comfortable, Optimal, TooEasy, TooHard, UnknownWord,
  VeryChallenging,
}

const max_word_length = 4

const max_unknown_display = 20

// --- FFI for jieba-wasm segmentation ---

@external(javascript, "../analysis_ffi.mjs", "segmentChinese")
fn segment_chinese_ffi(text: String) -> String

fn segment_with_jieba(text: String) -> List(String) {
  case text {
    "" -> []
    _ ->
      segment_chinese_ffi(text)
      |> string.split("\n")
      |> list.filter(fn(s) { s != "" })
  }
}

// --- Character classification helpers ---

fn is_cjk_char(cp: Int) -> Bool {
  cp >= 0x4E00 && cp <= 0x9FFF
}

fn has_cjk(s: String) -> Bool {
  s
  |> string.to_utf_codepoints
  |> list.any(fn(cp) { is_cjk_char(string.utf_codepoint_to_int(cp)) })
}

fn is_ascii_alnum(cp: Int) -> Bool {
  { cp >= 0x30 && cp <= 0x39 }
  || { cp >= 0x41 && cp <= 0x5A }
  || { cp >= 0x61 && cp <= 0x7A }
}

fn has_ascii_alnum(s: String) -> Bool {
  s
  |> string.to_utf_codepoints
  |> list.any(fn(cp) { is_ascii_alnum(string.utf_codepoint_to_int(cp)) })
}

fn is_all_digits(s: String) -> Bool {
  s
  |> string.to_utf_codepoints
  |> list.all(fn(cp) {
    let v = string.utf_codepoint_to_int(cp)
    v >= 0x30 && v <= 0x39
  })
}

fn is_valid_word(word: String) -> Bool {
  let trimmed = string.trim(word)
  case trimmed {
    "" -> False
    _ ->
      has_cjk(trimmed)
      && !is_all_digits(trimmed)
      && !has_ascii_alnum(trimmed)
  }
}

fn remove_whitespace(text: String) -> String {
  text
  |> string.to_utf_codepoints
  |> list.filter(fn(cp) {
    let v = string.utf_codepoint_to_int(cp)
    v != 0x20
    && v != 0x09
    && v != 0x0A
    && v != 0x0D
    && v != 0x3000
    && v != 0xA0
    && v != 0x200B
  })
  |> list.map(fn(cp) { string.from_utf_codepoints([cp]) })
  |> string.concat
}

// --- Substring extraction ---

fn substr(graphemes: List(String), start: Int, end: Int) -> String {
  graphemes
  |> list.drop(start)
  |> list.take(end - start)
  |> string.concat
}

// --- segment_unknown: dictionary max-match + jieba fallback ---

fn segment_unknown_text(
  text: String,
  dict_keys: Set(String),
) -> List(String) {
  let graphemes = string.to_graphemes(text)
  let len = list.length(graphemes)
  do_segment_unknown(graphemes, 0, len, dict_keys, [])
}

fn do_segment_unknown(
  graphemes: List(String),
  pos: Int,
  len: Int,
  dict_keys: Set(String),
  acc: List(String),
) -> List(String) {
  case pos >= len {
    True -> list.reverse(acc)
    False -> {
      let remaining = list.drop(graphemes, pos)
      let max_len = int.min(max_word_length, len - pos)
      case try_dict_match(remaining, max_len, dict_keys) {
        Some(#(word, word_len)) ->
          do_segment_unknown(
            graphemes,
            pos + word_len,
            len,
            dict_keys,
            [word, ..acc],
          )
        None -> {
          let next_pos = find_next_dict_pos(graphemes, pos + 1, len, dict_keys)
          let unmatched = substr(graphemes, pos, next_pos)
          let jieba_segs = segment_with_jieba(unmatched)
          let new_acc =
            list.fold(list.reverse(jieba_segs), acc, fn(a, s) { [s, ..a] })
          do_segment_unknown(graphemes, next_pos, len, dict_keys, new_acc)
        }
      }
    }
  }
}

fn try_dict_match(
  remaining: List(String),
  try_len: Int,
  dict_keys: Set(String),
) -> Option(#(String, Int)) {
  case try_len < 1 {
    True -> None
    False -> {
      let candidate = remaining |> list.take(try_len) |> string.concat
      case set.contains(dict_keys, candidate) {
        True -> Some(#(candidate, try_len))
        False -> try_dict_match(remaining, try_len - 1, dict_keys)
      }
    }
  }
}

fn find_next_dict_pos(
  graphemes: List(String),
  pos: Int,
  len: Int,
  dict_keys: Set(String),
) -> Int {
  case pos >= len {
    True -> len
    False -> {
      let remaining = list.drop(graphemes, pos)
      let max_len = int.min(max_word_length, len - pos)
      case try_dict_match(remaining, max_len, dict_keys) {
        Some(_) -> pos
        None -> find_next_dict_pos(graphemes, pos + 1, len, dict_keys)
      }
    }
  }
}

// --- DP types ---

type DpCell {
  DpCell(
    score: Int,
    // Segments stored in reverse order (newest first).
    // Each is #(word, is_known).
    segments: List(#(String, Bool)),
    // Start index of pending unknown region, or -1 if none.
    unknown_start: Int,
  )
}

// --- DP segmentation ---

fn dp_segment(
  text: String,
  known_words: Set(String),
  dict_keys: Set(String),
) -> List(#(String, Bool)) {
  let graphemes = string.to_graphemes(text)
  let n = list.length(graphemes)

  case n {
    0 -> []
    _ -> {
      // dp[0] = base case: score 0, no segments, no unknown region
      let dp =
        dict.from_list([
          #(0, DpCell(score: 0, segments: [], unknown_start: -1)),
        ])

      // Fill DP for positions 1..n
      let dp =
        int.range(from: 1, to: n + 1, with: dp, run: fn(dp_acc, i) {
          dp_fill_position(dp_acc, i, graphemes, known_words, dict_keys)
        })

      // Extract final result from dp[n]
      let assert Ok(final) = dict.get(dp, n)

      // Handle trailing unknown chunk
      case final.unknown_start >= 0 {
        True -> {
          let unknown_text = substr(graphemes, final.unknown_start, n)
          let unknown_segs = segment_unknown_text(unknown_text, dict_keys)
          let with_unknown =
            list.fold(unknown_segs, final.segments, fn(acc, w) {
              [#(w, False), ..acc]
            })
          list.reverse(with_unknown)
        }
        False -> list.reverse(final.segments)
      }
    }
  }
}

fn dp_fill_position(
  dp: Dict(Int, DpCell),
  i: Int,
  graphemes: List(String),
  known_words: Set(String),
  dict_keys: Set(String),
) -> Dict(Int, DpCell) {
  let start_j = int.max(0, i - max_word_length)

  // Try to find a known word ending at position i
  let best_known =
    try_known_word_at(dp, start_j, i, graphemes, known_words, dict_keys, None)

  case best_known {
    Some(cell) -> dict.insert(dp, i, cell)
    None -> {
      // No known word found. Extend unknown region from best previous position.
      let best_prev_pos = find_best_prev_pos(dp, 0, i)
      case dict.get(dp, best_prev_pos) {
        Ok(prev) -> {
          let unknown_start = case prev.unknown_start >= 0 {
            True -> prev.unknown_start
            False -> best_prev_pos
          }
          dict.insert(
            dp,
            i,
            DpCell(
              score: prev.score,
              segments: prev.segments,
              unknown_start: unknown_start,
            ),
          )
        }
        Error(_) -> dp
      }
    }
  }
}

fn try_known_word_at(
  dp: Dict(Int, DpCell),
  j: Int,
  end_i: Int,
  graphemes: List(String),
  known_words: Set(String),
  dict_keys: Set(String),
  best: Option(DpCell),
) -> Option(DpCell) {
  case j >= end_i {
    True -> best
    False -> {
      let word = substr(graphemes, j, end_i)
      let new_best = case set.contains(known_words, word) {
        True -> {
          case dict.get(dp, j) {
            Ok(prev) -> {
              let new_score = prev.score + string.length(word)
              let should_update = case best {
                None -> True
                Some(b) -> new_score > b.score
              }
              case should_update {
                True -> {
                  // Process pending unknown chunk if any
                  let new_segments = case prev.unknown_start >= 0 {
                    True -> {
                      let unknown_text =
                        substr(graphemes, prev.unknown_start, j)
                      let unknown_segs =
                        segment_unknown_text(unknown_text, dict_keys)
                      list.fold(unknown_segs, prev.segments, fn(acc, w) {
                        [#(w, False), ..acc]
                      })
                    }
                    False -> prev.segments
                  }
                  let new_segments = [#(word, True), ..new_segments]
                  Some(DpCell(
                    score: new_score,
                    segments: new_segments,
                    unknown_start: -1,
                  ))
                }
                False -> best
              }
            }
            Error(_) -> best
          }
        }
        False -> best
      }
      try_known_word_at(
        dp,
        j + 1,
        end_i,
        graphemes,
        known_words,
        dict_keys,
        new_best,
      )
    }
  }
}

fn find_best_prev_pos(dp: Dict(Int, DpCell), pos: Int, end: Int) -> Int {
  let init_score = case dict.get(dp, pos) {
    Ok(cell) -> cell.score
    Error(_) -> -1
  }
  find_best_prev_loop(dp, pos + 1, end, pos, init_score)
}

fn find_best_prev_loop(
  dp: Dict(Int, DpCell),
  pos: Int,
  end: Int,
  best_pos: Int,
  best_score: Int,
) -> Int {
  case pos >= end {
    True -> best_pos
    False -> {
      let score = case dict.get(dp, pos) {
        Ok(cell) -> cell.score
        Error(_) -> -1
      }
      case score > best_score {
        True -> find_best_prev_loop(dp, pos + 1, end, pos, score)
        False -> find_best_prev_loop(dp, pos + 1, end, best_pos, best_score)
      }
    }
  }
}

// --- Assessment ---

pub fn get_assessment(pct: Float) -> Assessment {
  case pct <. 82.0 {
    True -> TooHard
    False ->
      case pct <. 87.0 {
        True -> VeryChallenging
        False ->
          case pct <. 89.0 {
            True -> Challenging
            False ->
              case pct <. 92.0 {
                True -> Optimal
                False ->
                  case pct <. 95.0 {
                    True -> Comfortable
                    False -> TooEasy
                  }
              }
          }
      }
  }
}

pub fn assessment_emoji(assessment: Assessment) -> String {
  case assessment {
    TooHard -> "⛔"
    VeryChallenging -> "🔴"
    Challenging -> "🟡"
    Optimal -> "🟢"
    Comfortable -> "🔵"
    TooEasy -> "⚪"
  }
}

pub fn assessment_label(assessment: Assessment) -> String {
  case assessment {
    TooHard -> "Too Difficult"
    VeryChallenging -> "Very Challenging"
    Challenging -> "Challenging"
    Optimal -> "Optimal (i+1)"
    Comfortable -> "Comfortable"
    TooEasy -> "Too Easy"
  }
}

// --- Main analysis entry point ---

pub fn analyze(
  text: String,
  known_words: Set(String),
  dict: Dict(String, DictEntry),
) -> Option(AnalysisResult) {
  let cleaned = remove_whitespace(text)

  case has_cjk(cleaned) {
    False -> None
    True -> {
      let dict_keys = dict |> dict.keys |> set.from_list

      // Use DP segmentation with jieba fallback for unknown chunks
      let segments = dp_segment(cleaned, known_words, dict_keys)

      // Filter to valid words only
      let valid_segments =
        segments
        |> list.filter(fn(seg) { is_valid_word(seg.0) })

      case valid_segments {
        [] -> None
        _ -> {
          let total_words = list.length(valid_segments)

          // Build frequency map
          let word_counts =
            list.fold(valid_segments, dict.new(), fn(acc, seg) {
              let word = seg.0
              let current = case dict.get(acc, word) {
                Ok(#(count, is_known)) -> #(count + 1, is_known)
                Error(_) -> #(1, seg.1)
              }
              dict.insert(acc, word, current)
            })

          let unique_words = dict.size(word_counts)

          let known_count =
            valid_segments
            |> list.filter(fn(seg) { seg.1 })
            |> list.length

          let comprehension_pct = case total_words {
            0 -> 0.0
            _ ->
              int.to_float(known_count)
              *. 100.0
              /. int.to_float(total_words)
          }

          let assessment = get_assessment(comprehension_pct)

          let unknown_words =
            word_counts
            |> dict.to_list
            |> list.filter_map(fn(entry) {
              case entry {
                #(word, #(count, False)) -> {
                  let pinyin = dictionary.get_pinyin(dict, word)
                  let def = dictionary.get_definition(dict, word)
                  let truncated_def = case string.length(def) > 80 {
                    True -> string.slice(def, 0, 77) <> "..."
                    False -> def
                  }
                  Ok(UnknownWord(
                    word:,
                    count:,
                    pinyin:,
                    definition: truncated_def,
                  ))
                }
                _ -> Error(Nil)
              }
            })
            |> list.sort(fn(a, b) {
              int.compare(b.count, a.count)
              |> fn(ord) {
                case ord {
                  order.Eq -> string.compare(a.word, b.word)
                  _ -> ord
                }
              }
            })
            |> list.take(max_unknown_display)

          Some(AnalysisResult(
            total_words:,
            unique_words:,
            known_count:,
            comprehension_pct:,
            assessment:,
            unknown_words:,
          ))
        }
      }
    }
  }
}
