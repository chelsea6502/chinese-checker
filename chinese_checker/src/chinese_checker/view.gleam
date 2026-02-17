import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{class, disabled, id, selected, value}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import chinese_checker/analysis
import chinese_checker/model.{
  type AnalysisResult, type Model, type Msg, UserClickedAnalyze, UserClickedClear,
  UserSelectedHskNew, UserSelectedHskOld, UserUpdatedText,
}

fn parse_level(val: String) -> Option(Int) {
  case val {
    "none" -> None
    _ ->
      case int.parse(val) {
        Ok(n) -> Some(n)
        Error(_) -> None
      }
  }
}

fn sidebar(model: Model) -> Element(Msg) {
  html.aside([class("sidebar")], [
    html.h2([], [html.text("HSK Level")]),
    // HSK 2.0
    html.div([class("sidebar-section")], [
      html.h3([], [html.text("HSK 2.0")]),
      html.select(
        [
          class("level-select"),
          event.on_change(fn(val) { UserSelectedHskOld(parse_level(val)) }),
        ],
        [
          html.option([value("none"), selected(model.hsk_old_level == None)], "None"),
          html.option([value("1"), selected(model.hsk_old_level == Some(1))], "Level 1"),
          html.option([value("2"), selected(model.hsk_old_level == Some(2))], "Level 2"),
          html.option([value("3"), selected(model.hsk_old_level == Some(3))], "Level 3"),
          html.option([value("4"), selected(model.hsk_old_level == Some(4))], "Level 4"),
          html.option([value("5"), selected(model.hsk_old_level == Some(5))], "Level 5"),
        ],
      ),
    ]),
    // HSK 3.0
    html.div([class("sidebar-section")], [
      html.h3([], [html.text("HSK 3.0 (New HSK)")]),
      html.select(
        [
          class("level-select"),
          event.on_change(fn(val) { UserSelectedHskNew(parse_level(val)) }),
        ],
        [
          html.option([value("none"), selected(model.hsk_new_level == None)], "None"),
          html.option([value("1"), selected(model.hsk_new_level == Some(1))], "Level 1"),
          html.option([value("2"), selected(model.hsk_new_level == Some(2))], "Level 2"),
          html.option([value("3"), selected(model.hsk_new_level == Some(3))], "Level 3"),
        ],
      ),
    ]),
  ])
}

fn char_count_display(text: String) -> Element(Msg) {
  let count = string.length(text)
  let warning = count >= 5000
  html.div(
    [
      class(case warning {
        True -> "char-count warning"
        False -> "char-count"
      }),
    ],
    [html.text(int.to_string(count) <> "/5000 characters")],
  )
}

fn results_panel(result: AnalysisResult) -> Element(Msg) {
  let emoji = analysis.assessment_emoji(result.assessment)
  let label = analysis.assessment_label(result.assessment)
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

fn unknown_words_table(
  words: List(model.UnknownWord),
) -> Element(Msg) {
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
            html.td([class("count-cell")], [
              html.text(int.to_string(w.count)),
            ]),
            html.td([class("def-cell")], [html.text(w.definition)]),
          ])
        }),
      ),
    ]),
  ])
}

fn float_to_string_1dp(f: Float) -> String {
  let whole = float.truncate(f)
  let frac = float.truncate({ f -. int.to_float(whole) } *. 10.0)
  let frac_abs = case frac < 0 {
    True -> -frac
    False -> frac
  }
  int.to_string(whole) <> "." <> int.to_string(frac_abs)
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
        html.button([class("btn btn-secondary"), event.on_click(UserClickedClear)], [
          html.text("Clear"),
        ]),
      ]),
    ]),
    case model.result {
      Some(result) -> results_panel(result)
      None -> element.none()
    },
  ])
}

pub fn view(model: Model) -> Element(Msg) {
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
