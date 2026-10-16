///|
fn main {
  let entries : Array[@folder.Entry] = [
    { name: "lecture.PDF", size: 2048, kind: File, },
    { name: "photo.jpg", size: 8192, kind: File, },
    { name: "PHOTO.JPG", size: 4096, kind: File, },
    { name: "notes", size: 128, kind: File, },
    { name: "link", size: 0, kind: Symlink, },
  ]
  println(@folder.plan(entries).to_json().stringify()) catch {
    error => abort("demo failed: \{error}")
  }
}
