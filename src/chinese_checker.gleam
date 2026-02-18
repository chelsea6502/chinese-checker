import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/fetch
import gleam/float
import gleam/http/request
import gleam/int
import gleam/javascript/promise
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/set.{type Set}
import gleam/string
import hsk
import lustre
import lustre/attribute.{class, disabled, id, selected, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- Types ---

pub type DictEntry {
  DictEntry(pinyin: String, definition: String)
}

pub type Assessment {
  TooHard
  VeryChallenging
  Challenging
  Optimal
  Comfortable
  TooEasy
}

pub type UnknownWord {
  UnknownWord(
    word: String,
    count: Int,
    pinyin: String,
    definition: String,
  )
}

pub type AnalysisResult {
  AnalysisResult(
    total_words: Int,
    unique_words: Int,
    known_count: Int,
    comprehension_pct: Float,
    assessment: Assessment,
    unknown_words: List(UnknownWord),
  )
}

pub type Model {
  Model(
    input_text: String,
    hsk_old_level: Option(Int),
    hsk_new_level: Option(Int),
    result: Option(AnalysisResult),
    dictionary: Dict(String, DictEntry),
    loading: Bool,
    error: Option(String),
  )
}

pub type Msg {
  UserUpdatedText(String)
  UserSelectedHskOld(Option(Int))
  UserSelectedHskNew(Option(Int))
  UserClickedAnalyze
  UserClickedClear
  DictionaryLoaded(Result(Dict(String, DictEntry), String))
}

fn default_model() -> Model {
  Model(
    input_text: "",
    hsk_old_level: Some(4),
    hsk_new_level: None,
    result: None,
    dictionary: dict.new(),
    loading: True,
    error: None,
  )
}

// --- Dictionary ---

fn decode_entry() -> decode.Decoder(DictEntry) {
  use pinyin <- decode.field("p", decode.string)
  use definition <- decode.field("d", decode.string)
  decode.success(DictEntry(pinyin:, definition:))
}

@external(javascript, "./ffi.mjs", "getOrigin")
fn get_origin() -> String

fn fetch_dictionary() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let url = get_origin() <> "/dictionary.json"
    case request.to(url) {
      Error(_) -> dispatch(DictionaryLoaded(Error("Invalid dictionary URL")))
      Ok(req) -> {
        fetch.send(req)
        |> promise.try_await(fetch.read_text_body)
        |> promise.map(fn(resp_result) {
          dispatch(DictionaryLoaded(
            resp_result
            |> result.map_error(fn(_) { "Failed to fetch dictionary" })
            |> result.try(fn(response) {
              json.parse(response.body, decode.dict(decode.string, decode_entry()))
              |> result.map_error(fn(_) { "Failed to parse dictionary JSON" })
            }),
          ))
        })
        Nil
      }
    }
  })
}

fn get_entry_field(
  dictionary: Dict(String, DictEntry),
  word: String,
  f: fn(DictEntry) -> String,
) -> String {
  dictionary |> dict.get(word) |> result.map(f) |> result.unwrap("")
}

// --- HSK ---

fn known_words_for_levels(
  old_level: Option(Int),
  new_level: Option(Int),
) -> Set(String) {
  let all_old = [hsk.hsk1(), hsk.hsk2(), hsk.hsk3(), hsk.hsk4(), hsk.hsk5()]
  let all_new = [hsk.band1(), hsk.band2(), hsk.band3()]
  let old =
    old_level
    |> option.map(fn(n) { list.take(all_old, n) })
    |> option.unwrap([])
  let new =
    new_level
    |> option.map(fn(n) { list.take(all_new, n) })
    |> option.unwrap([])
  list.fold(list.append(old, new), set.new(), set.union)
}

// --- Analysis ---

const max_word_length = 4

const max_unknown_display = 20

fn has_cjk(s: String) -> Bool {
  s
  |> string.to_utf_codepoints
  |> list.any(fn(cp) {
    let v = string.utf_codepoint_to_int(cp)
    v >= 0x4E00 && v <= 0x9FFF
  })
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
  !string.is_empty(trimmed)
  && has_cjk(trimmed)
  && !is_all_digits(trimmed)
  && !has_ascii_alnum(trimmed)
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
  |> string.from_utf_codepoints
}

fn substr(graphemes: List(String), start: Int, end: Int) -> String {
  graphemes
  |> list.drop(start)
  |> list.take(end - start)
  |> string.concat
}

fn segment_unknown_text(text: String, dict_keys: Set(String)) -> List(String) {
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
          let unmatched_chars =
            graphemes |> list.drop(pos) |> list.take(next_pos - pos)
          let new_acc =
            list.fold(list.reverse(unmatched_chars), acc, fn(a, s) { [s, ..a] })
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

type DpCell {
  DpCell(
    score: Int,
    segments: List(#(String, Bool)),
    unknown_start: Int,
  )
}

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
      let dp =
        dict.from_list([
          #(0, DpCell(score: 0, segments: [], unknown_start: -1)),
        ])

      let dp =
        int.range(from: 1, to: n + 1, with: dp, run: fn(dp_acc, i) {
          dp_fill_position(dp_acc, i, graphemes, known_words, dict_keys)
        })

      let assert Ok(final) = dict.get(dp, n)

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
  let best_known =
    try_known_word_at(dp, start_j, i, graphemes, known_words, dict_keys, None)

  case best_known {
    Some(cell) -> dict.insert(dp, i, cell)
    None -> {
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

fn find_best_prev_pos(dp: Dict(Int, DpCell), start: Int, end: Int) -> Int {
  let dp_score = fn(pos) {
    dict.get(dp, pos) |> result.map(fn(c) { c.score }) |> result.unwrap(-1)
  }
  int.range(from: start + 1, to: end, with: #(start, dp_score(start)), run: fn(
    acc,
    pos,
  ) {
    let score = dp_score(pos)
    case score > acc.1 {
      True -> #(pos, score)
      False -> acc
    }
  }).0
}

pub fn get_assessment(pct: Float) -> Assessment {
  case pct {
    p if p <. 82.0 -> TooHard
    p if p <. 87.0 -> VeryChallenging
    p if p <. 89.0 -> Challenging
    p if p <. 92.0 -> Optimal
    p if p <. 95.0 -> Comfortable
    _ -> TooEasy
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

pub fn analyze(
  text: String,
  known_words: Set(String),
  the_dict: Dict(String, DictEntry),
) -> Option(AnalysisResult) {
  let cleaned = remove_whitespace(text)

  case has_cjk(cleaned) {
    False -> None
    True -> {
      let dict_keys = the_dict |> dict.keys |> set.from_list
      let segments = dp_segment(cleaned, known_words, dict_keys)
      let valid_segments =
        segments
        |> list.filter(fn(seg) { is_valid_word(seg.0) })

      case valid_segments {
        [] -> None
        _ -> {
          let total_words = list.length(valid_segments)

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
                  let pinyin = get_entry_field(the_dict, word, fn(e) { e.pinyin })
                  let def = get_entry_field(the_dict, word, fn(e) { e.definition })
                  let truncated_def = case string.length(def) > 80 {
                    True -> string.slice(def, 0, 77) <> "..."
                    False -> def
                  }
                  Ok(UnknownWord(word:, count:, pinyin:, definition: truncated_def))
                }
                _ -> Error(Nil)
              }
            })
            |> list.sort(fn(a, b) {
              case int.compare(b.count, a.count) {
                order.Eq -> string.compare(a.word, b.word)
                ord -> ord
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

// --- View ---

fn parse_level(val: String) -> Option(Int) {
  case val {
    "none" -> None
    _ -> int.parse(val) |> option.from_result
  }
}

fn level_select(
  current: Option(Int),
  max_level: Int,
  on_msg: fn(Option(Int)) -> Msg,
) -> Element(Msg) {
  let level_options =
    int.range(from: max_level, to: 0, with: [], run: fn(acc, n) {
      let s = int.to_string(n)
      [html.option([value(s), selected(current == Some(n))], "Level " <> s), ..acc]
    })
  html.select(
    [class("level-select"), event.on_change(fn(v) { on_msg(parse_level(v)) })],
    [html.option([value("none"), selected(current == None)], "None"), ..level_options],
  )
}

fn sidebar(model: Model) -> Element(Msg) {
  html.aside([class("sidebar")], [
    html.h2([], [html.text("HSK Level")]),
    html.div([class("sidebar-section")], [
      html.h3([], [html.text("HSK 2.0")]),
      level_select(model.hsk_old_level, 5, UserSelectedHskOld),
    ]),
    html.div([class("sidebar-section")], [
      html.h3([], [html.text("HSK 3.0 (New HSK)")]),
      level_select(model.hsk_new_level, 3, UserSelectedHskNew),
    ]),
  ])
}

fn char_count_display(text: String) -> Element(Msg) {
  let count = string.length(text)
  let cls = case count >= 5000 {
    True -> "char-count warning"
    False -> "char-count"
  }
  html.div([class(cls)], [html.text(int.to_string(count) <> "/5000 characters")])
}

fn results_panel(result: AnalysisResult) -> Element(Msg) {
  let emoji = assessment_emoji(result.assessment)
  let label = assessment_label(result.assessment)
  let pct_str = float_to_string_1dp(result.comprehension_pct)

  html.div([class("results")], [
    html.h3([], [html.text("Analysis Results")]),
    html.div([class("result-box")], [
      html.div([class("stats")], [
        stat_item("Word Count", int.to_string(result.total_words)),
        stat_item("Unique Words", int.to_string(result.unique_words)),
        stat_item("Comprehension", pct_str <> "%"),
        stat_item("Assessment", emoji <> " " <> label),
        stat_item(
          "Unknown Words",
          int.to_string(list.length(result.unknown_words)),
        ),
      ]),
      case result.unknown_words {
        [] -> element.none()
        words -> unknown_words_table(words)
      },
    ]),
  ])
}

fn stat_item(label: String, val: String) -> Element(Msg) {
  html.div([class("stat-item")], [
    html.span([class("stat-label")], [html.text(label <> ": ")]),
    html.span([class("stat-value")], [html.text(val)]),
  ])
}

fn unknown_words_table(words: List(UnknownWord)) -> Element(Msg) {
  html.div([class("unknown-words")], [
    html.h4([], [html.text("Unknown Words (by frequency)")]),
    html.table([class("words-table")], [
      html.thead([], [
        html.tr([], [
          html.th([], [html.text("Word")]),
          html.th([], [html.text("Pinyin")]),
          html.th([], [html.text("Count")]),
          html.th([], [html.text("Definition")]),
        ]),
      ]),
      html.tbody(
        [],
        list.map(words, fn(w) {
          html.tr([], [
            html.td([class("word-cell")], [html.text(w.word)]),
            html.td([class("pinyin-cell")], [html.text(w.pinyin)]),
            html.td([class("count-cell")], [html.text(int.to_string(w.count))]),
            html.td([class("def-cell")], [html.text(w.definition)]),
          ])
        }),
      ),
    ]),
  ])
}

fn float_to_string_1dp(f: Float) -> String {
  let whole = float.truncate(f)
  let frac =
    float.truncate({ f -. int.to_float(whole) } *. 10.0) |> int.absolute_value
  int.to_string(whole) <> "." <> int.to_string(frac)
}

fn main_content(model: Model) -> Element(Msg) {
  html.main([class("main-content")], [
    html.div([class("header")], [
      html.h1([], [html.text("Chinese Checker")]),
      html.p([class("subtitle")], [
        html.text(
          "Analyze Mandarin text comprehension based on your known words",
        ),
      ]),
    ]),
    html.div([class("input-section")], [
      html.textarea(
        [
          id("text-input"),
          class("text-input"),
          attribute.placeholder("粘贴中文文本在这里..."),
          attribute.rows(12),
          attribute.attribute("maxlength", "5000"),
          event.on_input(UserUpdatedText),
        ],
        model.input_text,
      ),
      char_count_display(model.input_text),
      html.div([class("buttons")], [
        html.button(
          [
            class("btn btn-primary"),
            event.on_click(UserClickedAnalyze),
            disabled(model.loading || string.is_empty(model.input_text)),
          ],
          [html.text("Analyze Text")],
        ),
        html.button(
          [class("btn btn-secondary"), event.on_click(UserClickedClear)],
          [html.text("Clear")],
        ),
      ]),
    ]),
    case model.result {
      Some(result) -> results_panel(result)
      None -> element.none()
    },
  ])
}

fn view(model: Model) -> Element(Msg) {
  case model.loading {
    True ->
      html.div([class("app loading")], [
        html.div([class("loading-message")], [
          html.text("Loading dictionary..."),
        ]),
      ])
    False ->
      html.div([class("app")], [
        sidebar(model),
        main_content(model),
        case model.error {
          Some(err) ->
            html.div([class("error-banner")], [html.text("Error: " <> err)])
          None -> element.none()
        },
      ])
  }
}

// --- App ---

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(default_model(), fetch_dictionary())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserUpdatedText(text) -> #(Model(..model, input_text: text), effect.none())

    UserSelectedHskOld(level) -> #(
      Model(..model, hsk_old_level: level, result: None),
      effect.none(),
    )

    UserSelectedHskNew(level) -> #(
      Model(..model, hsk_new_level: level, result: None),
      effect.none(),
    )

    UserClickedAnalyze -> {
      let known_words =
        known_words_for_levels(model.hsk_old_level, model.hsk_new_level)
      let result = analyze(model.input_text, known_words, model.dictionary)
      #(Model(..model, result: result), effect.none())
    }

    UserClickedClear -> #(
      Model(..model, input_text: "", result: None),
      effect.none(),
    )

    DictionaryLoaded(Ok(d)) -> #(
      Model(..model, dictionary: d, loading: False, error: None),
      effect.none(),
    )

    DictionaryLoaded(Error(err)) -> #(
      Model(..model, loading: False, error: Some(err)),
      effect.none(),
    )
  }
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
