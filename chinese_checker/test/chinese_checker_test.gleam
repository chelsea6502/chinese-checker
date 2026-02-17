import gleam/dict
import gleam/option.{None, Some}
import gleam/set
import gleeunit
import gleeunit/should

import chinese_checker/analysis
import chinese_checker/hsk
import chinese_checker/model.{
  Comfortable, DictEntry, Optimal, TooEasy, TooHard,
}

pub fn main() {
  gleeunit.main()
}

pub fn assessment_thresholds_test() {
  analysis.get_assessment(50.0) |> should.equal(TooHard)
  analysis.get_assessment(85.0) |> should.equal(model.VeryChallenging)
  analysis.get_assessment(88.0) |> should.equal(model.Challenging)
  analysis.get_assessment(90.0) |> should.equal(Optimal)
  analysis.get_assessment(93.0) |> should.equal(Comfortable)
  analysis.get_assessment(96.0) |> should.equal(TooEasy)
}

pub fn hsk1_set_size_test() {
  let words = hsk.hsk1()
  // HSK1 has ~150 words
  let size = set.size(words)
  { size >= 140 && size <= 155 } |> should.be_true
}

pub fn known_words_cumulative_test() {
  let level1 = hsk.known_words_for_levels(Some(1), None)
  let level2 = hsk.known_words_for_levels(Some(2), None)
  // Level 2 should include all level 1 words plus more
  let s1 = set.size(level1)
  let s2 = set.size(level2)
  { s2 > s1 } |> should.be_true
}

pub fn analyze_simple_known_text_test() {
  // All words known -> should get high comprehension
  let known = set.from_list(["我", "是", "中国", "人"])
  let dict = dict.new()
  let result = analysis.analyze("我是中国人", known, dict)
  case result {
    Some(r) -> {
      { r.comprehension_pct >. 90.0 } |> should.be_true
      { r.total_words > 0 } |> should.be_true
    }
    None -> should.fail()
  }
}

pub fn analyze_empty_text_test() {
  let known = set.from_list(["我"])
  let dict = dict.new()
  let result = analysis.analyze("", known, dict)
  result |> should.equal(None)
}

pub fn analyze_no_chinese_test() {
  let known = set.from_list(["我"])
  let dict = dict.new()
  let result = analysis.analyze("hello world 123", known, dict)
  result |> should.equal(None)
}

pub fn analyze_with_unknown_words_test() {
  let known = set.from_list(["我", "喜欢"])
  let dict =
    dict.from_list([
      #("吃", DictEntry(pinyin: "chi1", definition: "to eat")),
      #("苹果", DictEntry(pinyin: "ping2 guo3", definition: "apple")),
    ])
  let result = analysis.analyze("我喜欢吃苹果", known, dict)
  case result {
    Some(r) -> {
      { r.comprehension_pct <. 100.0 } |> should.be_true
      { r.total_words > 0 } |> should.be_true
    }
    None -> should.fail()
  }
}

pub fn analyze_with_dict_for_segmentation_test() {
  // "苹果" is in dict but not known — should be segmented as one word
  let known = set.from_list(["我", "喜欢", "吃"])
  let dict =
    dict.from_list([
      #("苹果", DictEntry(pinyin: "ping2 guo3", definition: "apple")),
    ])
  let result = analysis.analyze("我喜欢吃苹果", known, dict)
  case result {
    Some(r) -> {
      // 4 words: 我 喜欢 吃 苹果 — 3 known, 1 unknown
      r.total_words |> should.equal(4)
      r.known_count |> should.equal(3)
    }
    None -> should.fail()
  }
}
