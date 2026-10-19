"""Index readable HBQ evidence without inferring review coverage or implementation parity.

Local engineering tool. Requires the preserved private source snapshot and historic
index. Reads those inputs only; writes the tracked metadata index with --write.
Do not add to public CI: Workshop snapshots are intentionally not in the repository.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEWS = ROOT / "releaseVerificationAndDeployment/referenceReviews"
OUTPUT = REVIEWS / "hbq-reference-index.json"
SOURCE = ROOT / ".qa/source-refresh-20261011/inventory/3812620045/hbq_advanced_driving_ai"
HISTORIC = ROOT / ".qa/workshop-comparison-20261014/HBQ-SEMANTIC-REVIEWS.json"
CONTROLLER_SHA = "2e6f0515474117496216a8900b5341588603c0b43bf41ec74e259f5c863e9931"

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()

def inventory() -> dict:
    controller = SOURCE / "functions/fn_driveAssist.sqf"
    if not controller.is_file() or digest(controller) != CONTROLLER_SHA:
        raise ValueError("Preserved HBQ controller is missing or mismatched; locate the protected snapshot.")
    if not HISTORIC.is_file():
        raise ValueError("Historic private review index is unavailable; do not infer its coverage.")
    source_files = sorted(p for p in SOURCE.rglob("*") if p.is_file() and p.suffix.lower() in {".sqf", ".cpp", ".hpp", ".fsm"})
    current = []
    for path in sorted(REVIEWS.glob("*.json")):
        if path == OUTPUT:
            continue
        raw = path.read_text(encoding="utf-8-sig")
        if not (path.name.startswith("hbq-") or "3812620045" in raw or "hbq_advanced_driving_ai" in raw):
            continue
        data = json.loads(raw)
        scope = data.get("scope", data.get("purpose", "Read the record for its exact scope."))
        mentions = [p.relative_to(SOURCE).as_posix() for p in source_files if p.name.lower() in raw.lower()]
        current.append({"path": relative(path), "sha256": digest(path), "scope": scope,
                        "sourceFileMentions": mentions,
                        "meaning": "Readable evidence pointer; a source mention is not complete semantic review or acceptance."})
    by_hash = {row["sha256"]: row["path"] for row in current}
    history = []
    for old in json.loads(HISTORIC.read_text(encoding="utf-8-sig")).get("reviews", []):
        expected = old.get("sha256", "")
        candidates = [ROOT / old["path"], HISTORIC.parent / old["path"]]
        found = next((p for p in candidates if p.is_file()), None)
        if found is None and expected in by_hash:
            found = ROOT / by_hash[expected]
        row = {"recordedPath": old["path"], "recordedSha256": expected}
        if found is None:
            row["status"] = "unresolved-historic-text"
        else:
            actual = digest(found)
            row.update({"status": "exact-historic-hash" if actual == expected else "readable-revised-text",
                        "currentPath": relative(found), "currentSha256": actual})
        history.append(row)
    return {"schema": 1, "workshopId": "3812620045", "sourceRoot": relative(SOURCE),
            "sourceControllerSha256": CONTROLLER_SHA,
            "sourceFiles": [{"path": p.relative_to(SOURCE).as_posix(), "sha256": digest(p)} for p in source_files],
            "readableReviewPointers": current,
            "historicIndex": {"path": relative(HISTORIC), "sha256": digest(HISTORIC)},
            "historicReviewPointers": history,
            "limits": ["Snapshot availability only; live Workshop freshness is not established.",
                       "Historic hashes are preserved. Revised or missing text does not establish old findings.",
                       "No source-file, helper, review or link count is an implementation or parity percentage.",
                       "Read each scope and current production call path before using an integration claim.",
                       "Physical behaviour and performance remain separate unverified requirements."]}

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Refresh tracked metadata from protected local inputs.")
    args = parser.parse_args()
    result = inventory()
    rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.write:
        OUTPUT.write_text(rendered, encoding="utf-8", newline="\n")
    elif not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != rendered:
        raise SystemExit("HBQ evidence index is stale. Reconcile current inputs, then run --write.")
    missing = sum(r["status"] == "unresolved-historic-text" for r in result["historicReviewPointers"])
    print(f"HBQ evidence index: {len(result['sourceFiles'])} source files, {len(result['readableReviewPointers'])} readable review pointers, {missing} unresolved historic texts. No parity inferred.")

if __name__ == "__main__":
    main()
