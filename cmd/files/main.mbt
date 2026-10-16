///|
extern "js" fn scan(root : String) -> String =
  #| function(root) { return globalThis.moonFolderHost.scan(root); }

///|
extern "js" fn execute(root : String, plan : String) -> String =
  #| function(root, plan) { return globalThis.moonFolderHost.execute(root, plan); }

///|
extern "js" fn undo(receipt : String) -> String =
  #| function(receipt) { return globalThis.moonFolderHost.undo(receipt); }

///|
extern "js" fn error(message : String) -> Unit =
  #| function(message) { console.error(message); process.exitCode = 1; }

///|
fn main {
  let args = @env.args()
  if args.length() != 4 {
    error(
      "usage: node scripts/moonfolder.cjs preview|copy DIRECTORY | undo RECEIPT.json",
    )
  } else {
    try {
      match args[2] {
        "preview" =>
          println(@folder.plan_snapshot(scan(args[3])).to_json().stringify())
        "copy" => {
          let plan = @folder.plan_snapshot(scan(args[3]))
          println(execute(args[3], plan.to_json().stringify()))
        }
        "undo" => println(undo(args[3]))
        _ => error("unknown command; expected preview, copy or undo")
      }
    } catch {
      failure => error("operation failed: \{failure}")
    }
  }
}
