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
    assessed = [row for row in rows if row["assessment"] == "provisional_source_assessment"]
    acceptance_only = [row for row in rows if row["assessment"] == "acceptance_only"]
    scores = {}
    lines = ["# CBE build-out progress", "", "Build-out measures implemented capability and integration. Acceptance, physical reliability and performance are separate criteria.", "", "These are provisional source-based estimates using explicit, equally weighted capabilities. They are not time/effort estimates or claims of working in-game quality. Scores: absent = 0; implemented subset with a named build gap = 0.5; scoped execution path wired = 1. Physical verification is not required for build credit.", "", f"**Scope: {len(assessed)} assessed product families, {len(acceptance_only)} acceptance-only scenario, {len(rows)-len(assessed)-len(acceptance_only)} unassessed.** Unassessed is unknown, never 0%.", "", "| Feature family | Build-out | Separate acceptance register |", "| --- | ---: | --- |"]
    details = []
    for row in rows:
        if row["assessment"] == "acceptance_only":
            if row["criteria"] or not row.get("reason"):
                raise ValueError("Acceptance-only scope must have no build score and an explicit reason")
            percentage = "Acceptance-only"
        elif row["assessment"] == "unassessed":
            if row["criteria"]:
                raise ValueError("Unassessed family cannot carry scored capabilities")
            percentage = "Unassessed"
        else:
            if not row["criteria"] or row["assessment"] != "provisional_source_assessment":
                raise ValueError("Assessed family needs its explicit capability denominator")
            earned = total = 0
            detail = [f"## {row['id']} â€” {row['title']}", "", f"Source checkpoint: `{row['source_commit']}`; reviewed {row['reviewed_at']}; confidence: {row['confidence']}.", "", "| Capability | Built | Implementation / remaining build gap |", "| --- | ---: | --- |"]
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
            scores[row["id"]] = earned / total
            percentage = f"~{earned / total * 100:.0f}%"
            details += detail + ["", f"Calculation: {earned:g} implemented capability units / {total:g} scoped units. Acceptance is not part of this calculation.", ""]
        lines.append(f"| {row['id']} â€” {row['title']} | {percentage} | {cases[row['id']]['status']} |")
    areas = data.get("areas", [])
    area_lines = []
    if areas:
        members = [key for area in areas for key in area["families"]]
        expected = {row["id"] for row in rows if row["assessment"] != "acceptance_only"}
        if len(members) != len(set(members)) or set(members) != expected:
            raise ValueError("Subsystem weights must cover product scope exactly once")
        weights = [area["weight"] for area in areas]
        if any(type(w) not in (int,float) or not math.isfinite(w) or w <= 0 for w in weights) or sum(weights) != 100:
            raise ValueError("Subsystem weights must be positive and sum to100")
        area_lines = ["## Registered product-plan build-out", "", "The total uses explicit subsystem and family scope weights in the ledger. They reflect planning priorities, not measured effort; cross-cutting features overlap. Small ancillary features do not receive the same total weight as driving or coordinated operations.", "", "| Subsystem | Scope weight | Build-out estimate |", "| --- | ---: | ---: |"]
        weighted = 0
        for area in areas:
            fw = area["families"]
            if any(type(w) not in (int,float) or not math.isfinite(w) or w <= 0 for w in fw.values()):
                raise ValueError("Invalid family scope weight")
            if all(key in scores for key in fw):
                value = sum(scores[key]*weight for key,weight in fw.items())/sum(fw.values())
                weighted += value*area["weight"]
                area_lines.append(f"| {area['name']} | {area['weight']}% | ~{value*100:.0f}% |")
            else:
                area_lines.append(f"| {area['name']} | {area['weight']}% | Unassessed |")
        if set(scores) == expected:
            area_lines += ["", f"**Current registered-plan build-out index: approximately {round(weighted/5)*5:.0f}%.** The underlying weighted estimate is {weighted:.1f}%; rounding avoids false precision. This is provisional and mostly low-confidence. It is not an estimate of remaining time or proof that the behaviour works.", ""]
        area_lines += [data.get("assessment_limit", ""), "", "Workshop integration is a separate unfinished scope review; no source-parity percentage is inferred. Compatibility-only sources remain separate. Physical acceptance and the 5% median / 10% p95 budget are also separate.", ""]
    return "\n".join(lines + [""] + area_lines + ["", "Workshop source-integration/parity percentages are not inferred from these figures. Source contributions need their own explicit scope and disposition. Compatibility-only sources remain separate.", ""] + details) + "\n"


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
