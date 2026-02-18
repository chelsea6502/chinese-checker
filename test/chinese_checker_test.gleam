import gleam/dict
import gleam/option.{None, Some}
import gleam/set
import gleeunit
import gleeunit/should

import chinese_checker.{
  Comfortable, DictEntry, Optimal, TooEasy, TooHard, VeryChallenging, Challenging,
  analyze, get_assessment,
}

pub fn main() {
  gleeunit.main()
}

pub fn assessment_thresholds_test() {
  get_assessment(50.0) |> should.equal(TooHard)
  get_assessment(85.0) |> should.equal(VeryChallenging)
  get_assessment(88.0) |> should.equal(Challenging)
  get_assessment(90.0) |> should.equal(Optimal)
  get_assessment(93.0) |> should.equal(Comfortable)
  get_assessment(96.0) |> should.equal(TooEasy)
}

pub fn analyze_simple_known_text_test() {
  let known = set.from_list(["我", "是", "中国", "人"])
  let d = dict.new()
  let result = analyze("我是中国人", known, d)
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
  let d = dict.new()
  analyze("", known, d) |> should.equal(None)
}

pub fn analyze_no_chinese_test() {
  let known = set.from_list(["我"])
  let d = dict.new()
  analyze("hello world 123", known, d) |> should.equal(None)
}

pub fn analyze_with_unknown_words_test() {
  let known = set.from_list(["我", "喜欢"])
  let d =
    dict.from_list([
      #("吃", DictEntry(pinyin: "chi1", definition: "to eat")),
      #("苹果", DictEntry(pinyin: "ping2 guo3", definition: "apple")),
    ])
  let result = analyze("我喜欢吃苹果", known, d)
  case result {
    Some(r) -> {
      { r.comprehension_pct <. 100.0 } |> should.be_true
      { r.total_words > 0 } |> should.be_true
    }
    None -> should.fail()
  }
}

pub fn analyze_with_dict_for_segmentation_test() {
  let known = set.from_list(["我", "喜欢", "吃"])
  let d =
    dict.from_list([
      #("苹果", DictEntry(pinyin: "ping2 guo3", definition: "apple")),
    ])
  let result = analyze("我喜欢吃苹果", known, d)
  case result {
    Some(r) -> {
      // 4 words: 我 喜欢 吃 苹果 — 3 known, 1 unknown
      r.total_words |> should.equal(4)
      r.known_count |> should.equal(3)
    }
    None -> should.fail()
  }
}
