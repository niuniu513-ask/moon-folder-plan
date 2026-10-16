///|
fn file(name : String, size? : Int64 = 1) -> Entry {
  { name, size, kind: File, }
}

///|
fn destinations(plan : Plan) -> Array[String] {
  plan.items().map(fn(i) { i.destination })
}

///|
fn invalid(
  entries : Array[Entry],
  rules? : Array[Rule] = default_rules(),
) -> Bool {
  try plan(entries, rules~) catch {
    InvalidInput(_) => true
    _ => false
  } noraise {
    _ => false
  }
}

///|
test "empty plan and zero-size files are valid" {
  assert_eq(plan([]).total_bytes(), 0)
  assert_eq(plan([]).items(), [])
  assert_eq(plan([file("empty.txt", size=0)]).total_bytes(), 0)
}

///|
test "default categories cover common personal files" {
  let p = plan([
    file("a.PDF"),
    file("b.jpg"),
    file("c.MP4"),
    file("d.wav"),
    file("e.zip"),
    file("f.py"),
    file("g.unknown"),
  ])
  assert_eq(destinations(p), [
    "Documents/a.PDF", "Images/b.jpg", "Videos/c.MP4", "Audio/d.wav", "Archives/e.zip",
    "Code/f.py", "Other/g.unknown",
  ])
}

///|
test "compound extensions use last suffix and preserve original name" {
  assert_eq(destinations(plan([file("backup.tar.gz"), file("plain")])), [
    "Archives/backup.tar.gz", "Other/plain",
  ])
}

///|
test "hidden file opt-in keeps dotfile names and directories are never traversed" {
  let entries = [
    file(".env"),
    Entry::{ name: "subdir", size: 0, kind: Directory, },
  ]
  assert_eq(plan(entries).items().length(), 0)
  let p = plan(entries, include_hidden=true)
  assert_eq(destinations(p), ["Other/.env"])
  assert_eq(p.skipped()[0].reason, "not-regular-file")
}

///|
test "links and special entries are skipped" {
  let p = plan([
    { name: "link", size: 0, kind: Symlink, },
    { name: "pipe", size: 0, kind: Other, },
  ])
  assert_eq(p.items().length(), 0)
  assert_eq(p.skipped().length(), 2)
}

///|
test "paths traversal controls and reserved names never enter a plan" {
  let names = [
    "../x", "a/b", "a\\b", "C:x", "..", "CON.txt", "aux", "Lpt9.csv", "COM¹.txt",
    "x\n.txt", "tail.", "tail ", "a?b",
  ]
  for name in names {
    assert_eq(plan([file(name)]).items().length(), 0)
  }
}

///|
test "Unicode personal filenames are preserved exactly" {
  assert_eq(
    destinations(plan([file("学习笔记.pdf"), file("旅行照片.jpg")])),
    ["Documents/学习笔记.pdf", "Images/旅行照片.jpg"],
  )
}

///|
test "ASCII case collisions receive stable numbered suffixes" {
  assert_eq(destinations(plan([file("a.TXT"), file("A.txt")])), [
    "Documents/A.txt", "Documents/a (1).TXT",
  ])
}

///|
test "preexisting numbered source names cannot collide with generated names" {
  let p = plan([file("A.txt"), file("a.txt"), file("a (1).txt")])
  let used : Map[String, Bool] = Map([])
  for item in p.items() {
    let key = ascii_fold(item.destination)
    assert_true(!used.contains(key))
    used.set(key, true)
  }
  assert_eq(p.items().length(), 3)
}

///|
test "input order does not decide output or collision winner" {
  let forward = [file("a.TXT"), file("A.txt"), file("x.jpg")]
  let reverse = [file("x.jpg"), file("A.txt"), file("a.TXT")]
  assert_eq(plan(forward).items(), plan(reverse).items())
}

///|
test "duplicate source names and negative sizes are rejected" {
  assert_true(invalid([file("a"), file("a")]))
  assert_true(invalid([file("a", size=-1)]))
}

///|
test "rule validation prevents category paths and ambiguous spellings" {
  for
    rules in [
      [Rule::{ extension: "txt", category: "../escape", }],
      [Rule::{ extension: ".txt", category: "Docs", }],
      [Rule::{ extension: "txt", category: "CON", }],
      [Rule::{ extension: "txt", category: "other", }],
      [
        Rule::{ extension: "txt", category: "Docs", },
        Rule::{ extension: "TXT", category: "Docs", },
      ],
      [
        Rule::{ extension: "txt", category: "Docs", },
        Rule::{ extension: "pdf", category: "docs", },
      ],
    ] {
    assert_true(invalid([], rules~))
  }
}

///|
test "custom rules replace default rules" {
  let rules = [Rule::{ extension: "pdf", category: "Study", }]
  assert_eq(destinations(plan([file("a.pdf"), file("b.jpg")], rules~)), [
    "Study/a.pdf", "Other/b.jpg",
  ])
}

///|
test "resource limits are explicit" {
  let rejected = try plan(Array::make(4097, file("x"))) catch {
    LimitExceeded(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
  let rejected = try plan([file("x", size=1_099_511_627_777L)]) catch {
    LimitExceeded(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}

///|
test "total sizes use Int64 and returned arrays do not mutate the plan" {
  let p = plan([
    file("a", size=1_099_511_627_776L),
    file("b", size=1_099_511_627_776L),
  ])
  assert_eq(p.total_bytes(), 2_199_023_255_552L)
  p.items().clear()
  assert_eq(p.items().length(), 2)
}

///|
test "metadata snapshot and JSON report retain exact sizes" {
  let p = plan_snapshot(
    "[{\"name\":\"a.pdf\",\"size\":\"1099511627776\",\"kind\":\"file\"}]",
  )
  assert_eq(p.total_bytes(), 1_099_511_627_776L)
  let report = p.to_json()
  match report {
    { "total_bytes": String(value), .. } => assert_eq(value, "1099511627776")
    _ => fail("missing total_bytes")
  }
}

///|
test "malformed snapshots wrong shapes kinds and sizes are rejected" {
  for
    text in [
      "", "{}", "[{}]", "[{\"name\":\"x\",\"size\":1,\"kind\":\"file\"}]", "[{\"name\":\"x\",\"size\":\"-1\",\"kind\":\"file\"}]",
      "[{\"name\":\"x\",\"size\":\"1\",\"kind\":\"bad\"}]",
    ] {
    let rejected = try plan_snapshot(text) catch {
      InvalidInput(_) => true
      _ => false
    } noraise {
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "depth precheck ignores braces inside quoted and escaped strings" {
  check_depth("{\"x\":\"[[[[[[[[[[[\\\"\"}")
  let rejected = try plan_snapshot("[[[[[[[[[0]]]]]]]]]") catch {
    LimitExceeded(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}

///|
test "many colliding names remain unique and size conserving" {
  let entries = Array::makei(200, fn(i) {
    let number = i / 2
    let name = if i % 2 == 0 {
      "SAMPLE\{number}.TXT"
    } else {
      "sample\{number}.txt"
    }
    file(name, size=i.to_int64())
  })
  let p = plan(entries)
  assert_eq(p.items().length(), 200)
  assert_eq(p.total_bytes(), 19900)
  let used : Map[String, Bool] = Map([])
  for item in p.items() {
    assert_true(!used.contains(ascii_fold(item.destination)))
    used.set(ascii_fold(item.destination), true)
  }
}
