import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import simplifile

const known_dir = "../known"

const output_path = "../assets/hsk.json"

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

pub fn main() {
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

  let assert Ok(_) = simplifile.write(to: output_path, contents: json_str)
  io.println("Generated " <> output_path)
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
