import gleam/dynamic/decode
import gleam/fetch
import gleam/http/request
import gleam/javascript/promise
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import lustre/effect.{type Effect}

import chinese_checker/model.{type HskWordLists, type Msg, HskLoaded, HskWordLists}

fn decode_word_set() -> decode.Decoder(Set(String)) {
  decode.list(decode.string)
  |> decode.map(set.from_list)
}

fn decode_hsk_word_lists() -> decode.Decoder(HskWordLists) {
  use hsk1 <- decode.field("hsk1", decode_word_set())
  use hsk2 <- decode.field("hsk2", decode_word_set())
  use hsk3 <- decode.field("hsk3", decode_word_set())
  use hsk4 <- decode.field("hsk4", decode_word_set())
  use hsk5 <- decode.field("hsk5", decode_word_set())
  use band1 <- decode.field("band1", decode_word_set())
  use band2 <- decode.field("band2", decode_word_set())
  use band3 <- decode.field("band3", decode_word_set())
  decode.success(HskWordLists(hsk1:, hsk2:, hsk3:, hsk4:, hsk5:, band1:, band2:, band3:))
}

@external(javascript, "../dictionary_ffi.mjs", "getOrigin")
fn get_origin() -> String

pub fn fetch_hsk() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let url = get_origin() <> "/hsk.json"
    case request.to(url) {
      Error(_) -> dispatch(HskLoaded(Error("Invalid HSK URL")))
      Ok(req) -> {
        fetch.send(req)
        |> promise.try_await(fetch.read_text_body)
        |> promise.map(fn(resp_result) {
          let result = case resp_result {
            Error(_) -> Error("Failed to fetch HSK word lists")
            Ok(response) ->
              case json.parse(response.body, decode_hsk_word_lists()) {
                Ok(lists) -> Ok(lists)
                Error(_) -> Error("Failed to parse HSK JSON")
              }
          }
          dispatch(HskLoaded(result))
        })
        Nil
      }
    }
  })
}

pub fn known_words_for_levels(
  lists: HskWordLists,
  old_level: Option(Int),
  new_level: Option(Int),
) -> Set(String) {
  let old = case old_level {
    None -> set.new()
    Some(1) -> lists.hsk1
    Some(2) -> set.union(lists.hsk1, lists.hsk2)
    Some(3) -> set.union(set.union(lists.hsk1, lists.hsk2), lists.hsk3)
    Some(4) ->
      set.union(set.union(set.union(lists.hsk1, lists.hsk2), lists.hsk3), lists.hsk4)
    Some(5) ->
      set.union(
        set.union(set.union(set.union(lists.hsk1, lists.hsk2), lists.hsk3), lists.hsk4),
        lists.hsk5,
      )
    Some(_) -> set.new()
  }
  let new = case new_level {
    None -> set.new()
    Some(1) -> lists.band1
    Some(2) -> set.union(lists.band1, lists.band2)
    Some(3) -> set.union(set.union(lists.band1, lists.band2), lists.band3)
    Some(_) -> set.new()
  }
  set.union(old, new)
}
