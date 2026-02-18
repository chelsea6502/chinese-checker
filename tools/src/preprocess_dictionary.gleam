import gleam/dict
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

const cedict_path = "../definitions.txt"

const output_path = "../assets/dictionary.json"

pub fn main() {
  io.println("Reading " <> cedict_path <> " ...")
  let assert Ok(content) = simplifile.read(from: cedict_path)

  let entries =
    content
    |> string.split("\n")
    |> list.fold(dict.new(), fn(acc, line) {
      case parse_line(line) {
        None -> acc
        Some(#(simplified, pinyin, definition)) ->
          case dict.has_key(acc, simplified) {
            True -> acc
            False -> dict.insert(acc, simplified, #(pinyin, definition))
          }
      }
    })

  let count = dict.size(entries)
  io.println("Parsed " <> int.to_string(count) <> " entries")

  let json_str =
    entries
    |> dict.to_list
    |> list.map(fn(kv) {
      let #(simplified, #(pinyin, definition)) = kv
      #(simplified, json.object([
        #("p", json.string(pinyin)),
        #("d", json.string(definition)),
      ]))
    })
    |> json.object
    |> json.to_string

  let assert Ok(_) = simplifile.write(to: output_path, contents: json_str)
  io.println("Wrote " <> output_path)
}

fn parse_line(line: String) -> Option(#(String, String, String)) {
  let line = string.trim(line)
  case string.is_empty(line) || string.starts_with(line, "#") {
    True -> None
    False -> {
      // Format: Traditional Simplified [pinyin] /def1/def2/.../
      use #(_traditional, rest) <- option.then(
        to_option(string.split_once(line, " ")),
      )
      use #(simplified, rest) <- option.then(
        to_option(string.split_once(rest, " ")),
      )
      use #(_, rest) <- option.then(to_option(string.split_once(rest, "[")))
      use #(pinyin, rest) <- option.then(
        to_option(string.split_once(rest, "]")),
      )
      let rest = string.trim(rest)
      case string.starts_with(rest, "/") {
        False -> None
        True -> {
          let inner = string.drop_start(rest, 1)
          let inner = case string.ends_with(inner, "/") {
            True -> string.drop_end(inner, 1)
            False -> inner
          }
          let definition =
            inner
            |> string.split("/")
            |> list.filter(fn(d) { !string.is_empty(string.trim(d)) })
            |> string.join("; ")
          Some(#(simplified, pinyin, definition))
        }
      }
    }
  }
}

fn to_option(result: Result(a, b)) -> Option(a) {
  case result {
    Ok(v) -> Some(v)
    Error(_) -> None
  }
}
