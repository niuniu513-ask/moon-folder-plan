///|
pub suberror PlanError {
  InvalidInput(String)
  LimitExceeded(String)
} derive(Debug)

///|
pub extend PlanError with @debug.Debug::{to_repr}

///|
pub impl Show for PlanError with fn output(self, logger) {
  match self {
    InvalidInput(message) => logger.write_string("invalid input: " + message)
    LimitExceeded(message) => logger.write_string("limit exceeded: " + message)
  }
}

///|
pub extend PlanError with Show::{output, to_string}

///|
pub(all) enum EntryKind {
  File
  Directory
  Symlink
  Other
} derive(Eq, Debug)

///|
pub extend EntryKind with Eq::{equal, not_equal}

///|
pub extend EntryKind with @debug.Debug::{to_repr}

///|
pub(all) struct Entry {
  name : String
  size : Int64
  kind : EntryKind
} derive(Eq, Debug)

///|
pub extend Entry with Eq::{equal, not_equal}

///|
pub extend Entry with @debug.Debug::{to_repr}

///|
pub(all) struct Rule {
  extension : String
  category : String
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub(all) struct CopyItem {
  source : String
  destination : String
  category : String
  size : Int64
  renamed : Bool
} derive(Eq, Debug)

///|
pub extend CopyItem with Eq::{equal, not_equal}

///|
pub extend CopyItem with @debug.Debug::{to_repr}

///|
pub(all) struct Skipped {
  name : String
  reason : String
} derive(Eq, Debug)

///|
pub extend Skipped with Eq::{equal, not_equal}

///|
pub extend Skipped with @debug.Debug::{to_repr}

///|
pub struct Plan {
  items : Array[CopyItem]
  skipped : Array[Skipped]
  total_bytes : Int64
}

///|
pub fn Plan::items(self : Plan) -> Array[CopyItem] {
  self.items.copy()
}

///|
pub fn Plan::skipped(self : Plan) -> Array[Skipped] {
  self.skipped.copy()
}

///|
pub fn Plan::total_bytes(self : Plan) -> Int64 {
  self.total_bytes
}

///|
/// Override or extend these rules by passing a complete custom rule array.
pub fn default_rules() -> Array[Rule] {
  let groups : Array[(String, Array[String])] = [
    (
      "Documents",
      [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "csv", "odt",
        "ods", "rtf",
      ],
    ),
    (
      "Images",
      ["jpg", "jpeg", "png", "gif", "webp", "bmp", "svg", "heic", "tiff"],
    ),
    ("Videos", ["mp4", "mov", "mkv", "avi", "webm", "mpeg"]),
    ("Audio", ["mp3", "wav", "flac", "aac", "ogg", "m4a"]),
    ("Archives", ["zip", "7z", "rar", "gz", "bz2", "xz", "tar"]),
    (
      "Code",
      [
        "mbt", "py", "js", "ts", "html", "css", "json", "yaml", "yml", "toml", "c",
        "cpp", "rs", "go",
      ],
    ),
  ]
  let result : Array[Rule] = []
  for group in groups {
    for extension in group.1 {
      result.push({ extension, category: group.0, })
    }
  }
  result
}
