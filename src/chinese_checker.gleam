import gleam/dict
import gleam/option.{None, Some}
import lustre
import lustre/effect

import chinese_checker/analysis
import chinese_checker/dictionary
import chinese_checker/hsk
import chinese_checker/model.{
  type Model, type Msg, DictionaryLoaded, HskLoaded, Model, UserClickedAnalyze,
  UserClickedClear, UserSelectedHskNew, UserSelectedHskOld, UserUpdatedText,
}
import chinese_checker/view

fn init(_flags: Nil) -> #(Model, effect.Effect(Msg)) {
  #(model.init(), effect.batch([dictionary.fetch_dictionary(), hsk.fetch_hsk()]))
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
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
      case model.hsk_words {
        None -> #(model, effect.none())
        Some(lists) -> {
          let known_words =
            hsk.known_words_for_levels(
              lists,
              model.hsk_old_level,
              model.hsk_new_level,
            )
          let result =
            analysis.analyze(model.input_text, known_words, model.dictionary)
          #(Model(..model, result: result), effect.none())
        }
      }
    }

    UserClickedClear -> #(
      Model(..model, input_text: "", result: None),
      effect.none(),
    )

    DictionaryLoaded(Ok(d)) -> {
      let loading = case model.hsk_words {
        Some(_) -> False
        None -> True
      }
      #(Model(..model, dictionary: d, loading: loading, error: None), effect.none())
    }

    DictionaryLoaded(Error(err)) -> #(
      Model(..model, loading: False, error: Some(err)),
      effect.none(),
    )

    HskLoaded(Ok(lists)) -> {
      let loading = dict.size(model.dictionary) == 0
      #(Model(..model, hsk_words: Some(lists), loading: loading), effect.none())
    }

    HskLoaded(Error(err)) -> #(
      Model(..model, loading: False, error: Some(err)),
      effect.none(),
    )
  }
}

pub fn main() {
  let app = lustre.application(init, update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
