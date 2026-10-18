"""Render capability build-out independently of runtime acceptance or source file counts."""
from pathlib import Path
import argparse
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs/buildout-progress.json"
REPORT = ROOT / "docs/BUILDOUT-PROGRESS.md"


def render():
    data = json.loads(LEDGER.read_text(encoding="utf-8"))
    coverage = json.loads((ROOT / "releaseVerificationAndDeployment/cortexQA/coverage.json").read_text(encoding="utf-8"))
    cases = {row["id"]: row for row in coverage["cases"]}
    rows = data["families"]
    if len(rows) != len(cases) or {row["id"] for row in rows} != set(cases):
        raise ValueError("Build-out scope must retain every registered feature family exactly once")
    assessed = [row for row in rows if row["assessment"] != "unassessed"]
    lines = ["# CBE build-out progress", "", "Build-out measures implemented capability and integration. Acceptance, physical reliability and performance are separate criteria.", "", "These are provisional source-based estimates using explicit, equally weighted capabilities. They are not time/effort estimates or claims of working in-game quality. Scores: absent = 0; implemented subset with a named build gap = 0.5; scoped execution path wired = 1. Physical verification is not required for build credit.", "", f"**Assessment coverage: {len(assessed)}/{len(rows)} feature families.** Unassessed families remain unknown, not 0%. No overall percentage is reported until the full denominator has been assessed.", "", "| Feature family | Build-out | Acceptance status |", "| --- | ---: | --- |"]
    details = []
    for row in rows:
        if row["assessment"] == "unassessed":
            if row["criteria"]:
                raise ValueError("Unassessed family cannot carry scored capabilities")
            percentage = "Unassessed"
        else:
            if not row["criteria"] or row["assessment"] != "provisional_source_assessment":
                raise ValueError("Assessed family needs its explicit capability denominator")
            earned = total = 0
            detail = [f"## {row['id']} — {row['title']}", "", f"Source checkpoint: `{row['source_commit']}`; reviewed {row['reviewed_at']}; confidence: {row['confidence']}.", "", "| Capability | Built | Implementation / remaining build gap |", "| --- | ---: | --- |"]
            for criterion in row["criteria"]:
                score, weight = criterion["built"], criterion["weight"]
                if type(score) not in (int, float) or score not in (0, 0.5, 1) or type(weight) not in (int, float) or not math.isfinite(weight) or weight <= 0:
                    raise ValueError("Invalid capability score/weight")
                if score < 1 and not criterion["remaining_build_gap"]:
                    raise ValueError("Partial credit needs a concrete remaining build gap")
                if not criterion["evidence"]:
                    raise ValueError("Scored capability needs source evidence")
                links = []
                for evidence in criterion["evidence"]:
                    file = (ROOT / evidence["path"]).resolve()
                    if not file.is_relative_to(ROOT.resolve()) or not file.is_file():
                        raise ValueError("Missing or out-of-repository source evidence")
                    if hashlib.sha256(file.read_bytes()).hexdigest() != evidence["sha256"]:
                        raise ValueError(f"Source changed; reassess build-out evidence: {evidence['path']}")
                    links.append(f"[{file.stem}](../{evidence['path']})")
                earned += score * weight
                total += weight
                note = criterion["implemented"] + (" Remaining: " + criterion["remaining_build_gap"] if criterion["remaining_build_gap"] else "")
                detail.append(f"| {criterion['capability']} | {score:g} / 1 | {note} {'; '.join(links)} |")
            percentage = f"~{earned / total * 100:.0f}%"
            details += detail + ["", f"Calculation: {earned:g} implemented capability units / {total:g} scoped units. Acceptance is not part of this calculation.", ""]
        lines.append(f"| {row['id']} — {row['title']} | {percentage} | {cases[row['id']]['status']} |")
    return "\n".join(lines + ["", "Workshop source-integration/parity percentages are not inferred from these figures. Source contributions need their own explicit scope and disposition. Compatibility-only sources remain separate.", ""] + details) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    report = render()
    if args.check:
        if not REPORT.is_file() or REPORT.read_text(encoding="utf-8") != report:
            raise SystemExit("Build-out report is stale; render it after reviewing the ledger")
        print("Build-out scope, evidence hashes and report passed; no behaviour acceptance inferred")
    else:
        REPORT.write_text(report, encoding="utf-8")
        print("Rendered separate build-out report")


if __name__ == "__main__":
    main()
