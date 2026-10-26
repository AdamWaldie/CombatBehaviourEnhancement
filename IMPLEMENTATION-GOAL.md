# CBE implementation goal

Deliver a standalone Arma 3 AI improvement addon by selecting useful functionality from the source register, merging complementary methods, fixing defects and evolving them into coherent CBE behaviour. Source fidelity serves gameplay quality, tactical plausibility, balance and engine performance; copying every source mechanism is not the objective.

## Source and work order

Use `reference/sourceReviews/source-review-map.json` and its readable `SOURCE-REVIEW-MAP.md` as the recoverable source queue. Record each selected capability's source evidence, intended benefit, CBE execution owner, implementation gaps and next concrete work. Missing historical evidence remains missing; inventory or source review alone is not implementation credit.

1. Stabilise foundations: finite owner-local danger/operation FSM lifecycle, admission, interruption, cleanup, locality changes and preservation of mission/Zeus orders. Implement and improve LAMBS functionality without requiring LAMBS. Complete the relevant HBQ source review and redesign unsafe methods.
2. Build individual movement, cover, building traversal/CQB, driving and recovery on those foundations. Then compose pairs, squads, multi-squad coordination, combined arms and support. Review all Protocol sources for their useful functionality in that order.
3. Cherry-pick complementary improvements from the remaining registered references. Merge shared intent into existing owners. Keep compatibility-only, optional/default-off stealth and follow-on extensions within their recorded scope.

## Change safeguards

For each bounded batch, state the specific capability or defect being resolved; trace its actual execution and writers before editing. Keep one movement/task owner, bounded work and finite recovery. Preserve authored skill baselines, newer orders, group membership policies and specialist ownership. Do not add permanent controllers, broad scans, speculative infrastructure or physical shortcuts to hide failures. Preserve local reference archives, Workshop files, signing keys and unrelated checkout changes.

Extend relevant existing checks, then run the coherent build/package gates. Keep retained failures visible. Build-out, offline verification, physical behaviour and measured performance are separate evidence categories. Audits remain paused until the user resumes them; do not manufacture physical acceptance. The performance target remains at most 5% median / 10% p95 overhead, subject to measurement.

## Finite completion

A batch is complete when its stated outcome is implemented, relevant checks pass and no known material issue remains within that batch. Do not add optional refinements or move its criteria. The overall production goal is complete only when required registered functionality is resolved, authority/lifecycle checks and authorised physical validation pass, and performance is measured within budget. If blocked, record the exact blocker, completed work and minimum remaining action; continue independent required build-out where possible.
