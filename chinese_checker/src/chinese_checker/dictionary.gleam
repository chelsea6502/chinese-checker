import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/fetch
import gleam/http/request
import gleam/javascript/promise
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import lustre/effect.{type Effect}

import chinese_checker/model.{type DictEntry, type Msg, DictEntry, DictionaryLoaded}

fn decode_entry() -> decode.Decoder(DictEntry) {
  use pinyin <- decode.field("p", decode.string)
  use definition <- decode.field("d", decode.string)
  decode.success(DictEntry(pinyin:, definition:))
}

fn decode_dictionary() -> decode.Decoder(Dict(String, DictEntry)) {
  decode.dict(decode.string, decode_entry())
}

@external(javascript, "../dictionary_ffi.mjs", "getOrigin")
fn get_origin() -> String

pub fn fetch_dictionary() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let url = get_origin() <> "/dictionary.json"
    case request.to(url) {
      Error(_) -> dispatch(DictionaryLoaded(Error("Invalid dictionary URL")))
      Ok(req) -> {
        fetch.send(req)
        |> promise.try_await(fetch.read_text_body)
        |> promise.map(fn(resp_result) {
          let result = case resp_result {
            Error(_) -> Error("Failed to fetch dictionary")
            Ok(response) ->
              case json.parse(response.body, decode_dictionary()) {
                Ok(d) -> Ok(d)
                Error(_) -> Error("Failed to parse dictionary JSON")
              }
          }
          dispatch(DictionaryLoaded(result))
        })

        Nil
      }
    }
  })
}

pub fn lookup(
  dictionary: Dict(String, DictEntry),
  word: String,
) -> option.Option(DictEntry) {
  case dict.get(dictionary, word) {
    Ok(entry) -> Some(entry)
    Error(_) -> None
  }
}

/// Get pinyin for a word from the dictionary, or empty string if not found.
pub fn get_pinyin(dictionary: Dict(String, DictEntry), word: String) -> String {
  dictionary
  |> dict.get(word)
  |> result.map(fn(e) { e.pinyin })
  |> result.unwrap("")
}

/// Get definition for a word from the dictionary, or empty string if not found.
pub fn get_definition(
  dictionary: Dict(String, DictEntry),
  word: String,
) -> String {
  dictionary
  |> dict.get(word)
  |> result.map(fn(e) { e.definition })
  |> result.unwrap("")
}
