@target(erlang)

import gleam/dict
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

// --- Dictionary preprocessing ---

const cedict_path = "definitions.txt"

const dict_output_path = "assets/dictionary.json"

fn preprocess_dictionary() {
  io.println("Reading " <> cedict_path <> " ...")
  let assert Ok(content) = simplifile.read(from: cedict_path)

  let entries =
    content
    |> string.split("\n")
    |> list.fold(dict.new(), fn(acc, line) {
      case parse_cedict_line(line) {
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

  let assert Ok(_) = simplifile.write(to: dict_output_path, contents: json_str)
  io.println("Wrote " <> dict_output_path)
}

fn parse_cedict_line(line: String) -> Option(#(String, String, String)) {
  let line = string.trim(line)
  case string.is_empty(line) || string.starts_with(line, "#") {
    True -> None
    False -> {
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

// --- HSK word list generation ---

const known_dir = "known"

const hsk_output_path = "assets/hsk.json"

const word_lists = [
  #("hsk1", "HSK1.txt"),
  #("hsk2", "HSK2.txt"),
  #("hsk3", "HSK3.txt"),
  #("hsk4", "HSK4.txt"),
  #("hsk5", "HSK5.txt"),
  #("band1", "HSKBand1.txt"),
  #("band2", "HSKBand2.txt"),
  #("band3", "HSKBand3.txt"),
]

fn generate_hsk() {
  let entries =
    word_lists
    |> list.map(fn(pair) {
      let #(name, filename) = pair
      let filepath = known_dir <> "/" <> filename
      let assert Ok(content) = simplifile.read(from: filepath)
      let words = read_words(content)
      io.println(
        "  " <> name <> ": " <> int.to_string(list.length(words)) <> " words",
      )
      #(name, json.array(words, json.string))
    })

  let json_str =
    entries
    |> json.object
    |> json.to_string

  let assert Ok(_) = simplifile.write(to: hsk_output_path, contents: json_str)
  io.println("Generated " <> hsk_output_path)
}

fn read_words(content: String) -> List(String) {
  content
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    let line = string.trim(line)
    case string.is_empty(line) || string.starts_with(line, "#") {
      True -> None
      False -> {
        let line = case string.split_once(line, "\t") {
          Ok(#(before, _)) -> before
          Error(_) -> line
        }
        let line = case string.split_once(line, "#") {
          Ok(#(before, _)) -> before
          Error(_) -> line
        }
        let line = string.trim(line)
        case string.is_empty(line) {
          True -> None
          False -> Some(line)
        }
      }
    }
  })
}

// --- Main ---

pub fn main() {
  preprocess_dictionary()
  generate_hsk()
}
