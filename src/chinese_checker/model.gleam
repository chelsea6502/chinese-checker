import gleam/dict.{type Dict}
import gleam/option.{type Option, None}
import gleam/set.{type Set}

pub type DictEntry {
  DictEntry(pinyin: String, definition: String)
}

pub type HskWordLists {
  HskWordLists(
    hsk1: Set(String),
    hsk2: Set(String),
    hsk3: Set(String),
    hsk4: Set(String),
    hsk5: Set(String),
    band1: Set(String),
    band2: Set(String),
    band3: Set(String),
  )
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
    hsk_words: Option(HskWordLists),
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
  HskLoaded(Result(HskWordLists, String))
}

pub fn init() -> Model {
  Model(
    input_text: "",
    hsk_old_level: option.Some(4),
    hsk_new_level: None,
    result: None,
    dictionary: dict.new(),
    hsk_words: None,
    loading: True,
    error: None,
  )
}
