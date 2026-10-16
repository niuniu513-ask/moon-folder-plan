"""Independent filesystem acceptance checks. Uses temporary synthetic files only."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "scripts/moonfolder.cjs"

def run(*args, ok=True):
    result = subprocess.run(["node", str(CLI), *map(str, args)],
                            cwd=ROOT, text=True, capture_output=True, encoding="utf-8")
    if (result.returncode == 0) != ok:
        raise AssertionError(f"exit {result.returncode}: {result.stdout}\n{result.stderr}")
    return json.loads(result.stdout) if ok else result.stderr

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def seed(folder):
    files = {"lecture.PDF": b"synthetic lecture", "照片.jpg": bytes(range(256)),
             "notes.txt": b"notes", "bundle.zip": b"not actually a zip",
             "data.json": b"{}", "mystery": b"unknown", ".private": b"hidden"}
    for name, data in files.items():
        (folder / name).write_bytes(data)
    (folder / "subdir").mkdir()
    (folder / "subdir" / "nested.txt").write_bytes(b"never copied recursively")
    return files

def main():
    checks = []
    with tempfile.TemporaryDirectory(prefix="moon-folder-plan-") as temporary:
        parent = Path(temporary)
        root = parent / "中文 space"
        root.mkdir()
        files = seed(root)
        names_before = set(root.iterdir())
        preview = run("preview", root)
        assert set(root.iterdir()) == names_before
        by_source = {item["source"]: item for item in preview["items"]}
        expected = {"lecture.PDF": "Documents", "照片.jpg": "Images", "notes.txt": "Documents",
                    "bundle.zip": "Archives", "data.json": "Code", "mystery": "Other"}
        assert {name: item["category"] for name, item in by_source.items()} == expected
        assert int(preview["total_bytes"]) == sum(len(files[name]) for name in expected)
        checks.append("preview_classification_and_no_side_effects")

        html = parent / "preview.html"
        preview_command = ["node", str(ROOT / "scripts/preview.cjs"), str(root), str(html)]
        rendered = subprocess.run(preview_command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        assert rendered.returncode == 0, rendered.stderr
        markup = html.read_text(encoding="utf-8")
        assert "旅行" not in markup  # report contains only these synthetic file names
        assert "照片.jpg" in markup and "id=\"search\"" in markup
        assert "id=\"category\"" in markup
        before_html = html.read_bytes()
        refused = subprocess.run(preview_command, cwd=ROOT, capture_output=True)
        assert refused.returncode != 0 and html.read_bytes() == before_html
        assert set(root.iterdir()) == names_before
        checks.append("html_report_and_existing_output_preserved")

        copied = run("copy", root)
        receipt = Path(copied["receipt"])
        batch = receipt.parent
        ledger = json.loads(receipt.read_text(encoding="utf-8"))
        assert ledger["state"] == "complete" and copied["copied"] == len(expected)
        for item in ledger["items"]:
            assert (root / item["source"]).read_bytes() == files[item["source"]]
            assert (batch / item["destination"]).read_bytes() == files[item["source"]]
            assert item["sha256"] == digest(root / item["source"])
        assert not (batch / ".private").exists()
        checks.append("copy_hashes_originals_preserved")

        # Changing one copy blocks deletion of every other copy.
        changed = batch / ledger["items"][0]["destination"]
        unchanged = changed.read_bytes()
        changed.write_bytes(b"user modified copy")
        run("undo", receipt, ok=False)
        assert all((batch / item["destination"]).exists() for item in ledger["items"])
        changed.write_bytes(unchanged)
        checks.append("changed_copy_blocks_entire_undo")

        source = root / ledger["items"][0]["source"]
        source.write_bytes(b"user modified original")
        run("undo", receipt, ok=False)
        assert all((batch / item["destination"]).exists() for item in ledger["items"])
        source.write_bytes(unchanged)
        checks.append("changed_original_blocks_entire_undo")

        removed = run("undo", receipt)
        assert removed["removed_copies"] == len(expected)
        assert all(not (batch / item["destination"]).exists() for item in ledger["items"])
        assert receipt.exists()
        assert run("undo", receipt)["removed_copies"] == 0
        assert all((root / name).read_bytes() == data for name, data in files.items())
        checks.append("undo_repeatable_and_originals_preserved")

        copied_again = run("copy", root)
        assert copied_again["batch"] != str(batch)
        receipt2 = Path(copied_again["receipt"])
        ledger2 = json.loads(receipt2.read_text(encoding="utf-8"))
        ledger2["items"][0]["destination"] = "../escape"
        receipt2.write_text(json.dumps(ledger2), encoding="utf-8")
        run("undo", receipt2, ok=False)
        checks.append("receipt_traversal_rejected")

        # Link behavior is verified when the host allows creation of symlinks.
        symlink_check = "unavailable (host privilege)"
        try:
            (root / "linked.txt").symlink_to(root / "notes.txt")
        except (OSError, NotImplementedError):
            pass
        else:
            preview2 = run("preview", root)
            assert "linked.txt" not in {x["source"] for x in preview2["items"]}
            symlink_check = "passed"

        empty = parent / "empty"
        empty.mkdir()
        assert run("copy", empty) == {"copied": 0, "receipt": None}
        assert list(empty.iterdir()) == []
        run("preview", parent / "missing", ok=False)
        run("unknown", empty, ok=False)
        run("copy", root / "notes.txt", ok=False)
        checks.append("empty_missing_input_and_command_errors")

    print(json.dumps({"checks": checks, "passed": len(checks),
                      "symlink_check": symlink_check,
                      "data": "synthetic temporary files only"}, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
