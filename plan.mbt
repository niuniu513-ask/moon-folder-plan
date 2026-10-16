///|
/// ASCII folding only. We do not claim Unicode normalization equivalence.
pub fn ascii_fold(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn extension(name : String) -> (String, String) {
  let mut dot = -1
  for i = 0; i < name.length(); i = i + 1 {
    if name.code_unit_at(i) == 46 {
      dot = i
    }
  }
  if dot <= 0 || dot == name.length() - 1 {
    (name, "")
  } else {
    (name[:dot].to_owned(), ascii_fold(name[dot + 1:].to_owned()))
  }
}

///|
fn unsafe_name(name : String) -> String? {
  if name.length() == 0 || name.length() > 180 {
    return Some("name-length")
  }
  if name == "." || name == ".." {
    return Some("relative-navigation")
  }
  for c in name {
    if c.to_int() < 32 ||
      c == '\u007f' ||
      c == '/' ||
      c == '\\' ||
      c == ':' ||
      c == '*' ||
      c == '?' ||
      c == '"' ||
      c == '<' ||
      c == '>' ||
      c == '|' {
      return Some("nonportable-name")
    }
  }
  let last = name.code_unit_at(name.length() - 1)
  if last == 46 || last == 32 {
    return Some("trailing-dot-or-space")
  }
  let stem = ascii_fold(extension(name).0)
  let first = stem.split(".").head().unwrap()
  if first == "con" || first == "prn" || first == "aux" || first == "nul" {
    return Some("reserved-device-name")
  }
  if first.length() == 4 && (first[:3] == "com" || first[:3] == "lpt") {
    let digit = first.code_unit_at(3)
    if (digit >= 49 && digit <= 57) ||
      digit == 185 ||
      digit == 178 ||
      digit == 179 {
      return Some("reserved-device-name")
    }
  }
  None
}

///|
fn valid_category(category : String) -> Bool {
  if category.length() == 0 || category.length() > 32 {
    return false
  }
  for c in category {
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '-' ||
      c == '_') {
      return false
    }
  }
  unsafe_name(category) == None
}

///|
fn name_compare(left : String, right : String) -> Int {
  let count = Int::min(left.length(), right.length())
  for i = 0; i < count; i = i + 1 {
    let a = left.code_unit_at(i)
    let b = right.code_unit_at(i)
    if a < b {
      return -1
    }
    if a > b {
      return 1
    }
  }
  left.length().compare(right.length())
}

///|
/// Pure metadata planner: no file reads, writes or content inference.
/// Names are immediate directory entries, never relative or absolute paths.
pub fn plan(
  entries : Array[Entry],
  rules? : Array[Rule] = default_rules(),
  include_hidden? : Bool = false,
) -> Plan raise PlanError {
  if entries.length() > 4096 || rules.length() > 256 {
    raise LimitExceeded("at most 4096 entries and 256 rules")
  }
  let categories : Map[String, String] = Map([])
  let category_spelling : Map[String, String] = Map([])
  for rule in rules {
    let ext = ascii_fold(rule.extension)
    if ext.length() == 0 || ext.length() > 16 || !valid_category(rule.category) {
      raise InvalidInput("invalid extension or category")
    }
    for c in ext {
      if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
        raise InvalidInput("extensions must be ASCII alphanumeric without dot")
      }
    }
    if categories.contains(ext) {
      raise InvalidInput("duplicate extension rule")
    }
    let key = ascii_fold(rule.category)
    match category_spelling.get(key) {
      Some(previous) if previous != rule.category =>
        raise InvalidInput("category case collision")
      _ => category_spelling.set(key, rule.category)
    }
    if key == "other" && rule.category != "Other" {
      raise InvalidInput("fallback category is spelled Other")
    }
    categories.set(ext, rule.category)
  }
  let sorted = entries.copy()
  sorted.sort_by(fn(a, b) { name_compare(a.name, b.name) })
  let sources : Map[String, Bool] = Map([])
  let used : Map[String, Bool] = Map([])
  let items : Array[CopyItem] = []
  let skipped : Array[Skipped] = []
  let mut total = 0L
  for entry in sorted {
    if sources.contains(entry.name) {
      raise InvalidInput("duplicate source name")
    }
    sources.set(entry.name, true)
    if entry.size < 0 {
      raise InvalidInput("negative file size")
    }
    if entry.size > 1_099_511_627_776L {
      raise LimitExceeded("individual entry exceeds 1 TiB")
    }
    let reason = if entry.kind != File {
      Some("not-regular-file")
    } else if !include_hidden && entry.name.has_prefix(".") {
      Some("hidden-file")
    } else {
      unsafe_name(entry.name)
    }
    match reason {
      Some(reason) => {
        skipped.push({ name: entry.name, reason, })
        continue
      }
      None => ()
    }
    let (stem, ext) = extension(entry.name)
    let category = categories.get(ext).unwrap_or("Other")
    let mut candidate = entry.name
    let mut suffix = 0
    while used.contains(ascii_fold(category + "/" + candidate)) {
      suffix += 1
      let tail = if ext == "" {
        ""
      } else {
        entry.name[stem.length():].to_owned()
      }
      candidate = "\{stem} (\{suffix})\{tail}"
    }
    let destination = category + "/" + candidate
    used.set(ascii_fold(destination), true)
    total += entry.size
    items.push({
      source: entry.name,
      destination,
      category,
      size: entry.size,
      renamed: suffix != 0,
    })
  }
  { items, skipped, total_bytes: total, }
}
