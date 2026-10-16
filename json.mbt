///|
pub fn Plan::to_json(self : Plan) -> Json {
  let items : Array[Json] = self.items.map(fn(item) {
    let value : Json = {
      "source": item.source,
      "destination": item.destination,
      "category": item.category,
      "size": item.size.to_string(),
      "renamed": item.renamed,
    }
    value
  })
  let skipped : Array[Json] = self.skipped.map(fn(item) {
    let value : Json = { "name": item.name, "reason": item.reason }
    value
  })
  {
    "schema": "moon-folder-plan-v1",
    "items": Json::array(items),
    "skipped": Json::array(skipped),
    "total_bytes": self.total_bytes.to_string(),
  }
}

///|
// Bound nesting before calling the standard JSON parser, ignoring braces in strings.
fn check_depth(text : String) -> Unit raise PlanError {
  let mut depth = 0
  let mut quoted = false
  let mut escaped = false
  for c in text {
    if quoted {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        quoted = false
      }
    } else if c == '"' {
      quoted = true
    } else if c == '[' || c == '{' {
      depth += 1
      if depth > 8 {
        raise LimitExceeded("snapshot nesting exceeds 8")
      }
    } else if c == ']' || c == '}' {
      depth -= 1
    }
  }
}

///|
pub fn plan_snapshot(text : String) -> Plan raise PlanError {
  if text.length() > 2_097_152 {
    raise LimitExceeded("snapshot text exceeds 2 Mi code units")
  }
  check_depth(text)
  let value = @json.parse(text[:]) catch {
    _ => raise InvalidInput("invalid snapshot JSON")
  }
  let rows = match value {
    Array(rows) => rows
    _ => raise InvalidInput("snapshot must be an array")
  }
  if rows.length() > 4096 {
    raise LimitExceeded("too many entries")
  }
  let entries : Array[Entry] = []
  for row in rows {
    match row {
      { "name": String(name), "size": String(size), "kind": String(kind), .. } => {
        if size.length() == 0 || size.length() > 13 {
          raise InvalidInput("invalid size")
        }
        for c in size {
          if c < '0' || c > '9' {
            raise InvalidInput("size must be decimal digits")
          }
        }
        let size = @string.parse_int64(size[:]) catch {
          _ => raise InvalidInput("invalid size")
        }
        let kind = match kind {
          "file" => File
          "directory" => Directory
          "symlink" => Symlink
          "other" => Other
          _ => raise InvalidInput("invalid entry kind")
        }
        entries.push({ name, size, kind, })
      }
      _ => raise InvalidInput("invalid entry fields")
    }
  }
  plan(entries)
}
