# CBE implementation goal

Deliver a standalone Arma 3 AI improvement addon by selecting useful functionality from the source register, merging complementary methods, fixing defects and evolving them into coherent CBE behaviour. Source fidelity serves gameplay quality, tactical plausibility, balance and engine performance; copying every source mechanism is not the objective. LAMBS is a functionality baseline to implement and improve, never a required dependency.

## Governing implementation priority

Build upward from shared foundations, with reliable gameplay improvements as the outcome. First close concrete FSM ownership, interruption, cleanup and repeat-use defects against the LAMBS baseline and the relevant HBQ execution paths. Then compose individual behaviours, pairs, squads and combined operations. Complete the registered Protocol AI capability programme on those foundations. Do not jump layers simply because a higher-level feature is easier to add or improves a tracker figure.

The source register governs the work queue and intended contributions. Review every reference still lacking a source disposition, including its relevant callers, delayed writers and cleanup; select useful AI functionality across the collection and merge complementary strengths into existing CBE owners. A review finding must lead to a specific capability decision or defect resolution, rather than an expanding parallel planning programme. Respect recorded compatibility-only, optional and follow-on scope. LAMBS functionality must work within standalone CBE, without requiring LAMBS itself.

Before extending an affected layer, identify known material regressions in its shared foundations. Fix or isolate those regressions first; independent required work may continue while physical validation is paused. Preserve the last verified candidate and its limitations. Never treat an unrun audit, matching source names, more tests or a green package as evidence of improved AI. Do not conceal a failure through test-side assistance, weakened checks or physical shortcuts.

## Source register and evidence

Use these existing records before choosing or claiming work:

- `reference/sourceReviews/source-review-map.json` and `reference/sourceReviews/SOURCE-REVIEW-MAP.md`: recoverable master source queue and selected intent.
- `reference/sourceReviews/lambs-danger-source-queue.json`: readable danger/FSM review scope and unresolved source paths.
- `releaseVerificationAndDeployment/referenceReviews/hbq-reference-index.json`: HBQ review evidence and unresolved historical pointers. Review the entire relevant HBQ source, including every major branch; selected helpers do not establish whole-mod coverage.
- `releaseVerificationAndDeployment/referenceReviews/protocol-implementation-programme-20261020.json`: all nine Protocol references and their capability/integration gaps.

For each selected capability, record the source version/hash and actual execution path, intended benefit, existing CBE owner, useful differences, implementation gaps and next concrete change. Mark source methods as retained, adapted, replaced or rejected with a reason. Rejecting an unsafe method does not resolve a required capability: retain the capability gap until a suitable implementation exists. Missing historical evidence remains missing. Inventory, source review and test counts alone earn no implementation credit.

## Foundations-up implementation order

1. **FSM and execution foundations.** Establish finite owner-local danger/operation lifecycles: admission, task identity, decision/execution separation, interruption, native-command ownership, cancellation, cleanup, locality migration and repeat use. Preserve newer mission/Zeus orders and specialist ownership. Complete relevant LAMBS and HBQ source-to-executor tracing as these foundations are repaired.
2. **Individual building blocks.** Build movement, cover, sensing/contact response, firing, building traversal/CQB, driving, traffic and finite recovery on those lifecycles. Keep useful native engine behaviour. Resolve shared defects here before relying on them in larger behaviours.
3. **Pairs and squads.** Compose buddy roles, arrival-driven movement, casualty replacement, coherent building entry/clearance/isolation/egress, squad manoeuvre and convoy flow from the shared building blocks.
4. **Coordination and combined arms.** Build multi-squad allocation, armour/infantry cooperation, artillery, AA, aircraft, insertion and support through the same task ownership and handover rules. Implement useful Protocol functionality and complementary registered methods at the layer they belong to, rather than importing independent competing controllers.
5. **Deferred scope.** Compatibility expansion comes last: IKMS, WBK Droids and WBK Zombies remain compatibility-only. Keep optional stealth default-off and follow-on extensions deferred according to their register entries. Existing specialist safeguards remain mandatory throughout.

This sequence governs dependencies, not an endless prerequisite programme. Define a finite foundation batch, resolve its specific defects, and build the next required capability on it. A physical-validation pause does not prevent independent implementation; it does prevent claims of demonstrated behaviour.

## Change safeguards

Before each bounded batch, name the capability or defect, its register reference, affected CBE owner, observable intended outcome and checks. Trace the real callers, writers, callbacks and cleanup before editing. Reuse existing owners and focused checks; add machinery only for a demonstrated unmet requirement. Do not replace a working path merely to resemble a reference mod.

Keep one task/movement owner per affected actor or platform, bounded searches and finite recovery. Delayed work must retain its original task identity and refuse stale authority. Release only state the operation still owns. Preserve authored skill baselines, newer orders, group membership policies and specialist ownership. CBA owns settings; Zeus/ZEN modules issue behaviour tasks.

Do not add permanent controllers, broad scans, speculative infrastructure, arm stretching or physical shortcuts to conceal failures. Explicit operator-selected garrison teleport remains the recorded exception. Inaccessible building points must produce bounded failure/replanning, not false clearance or endless retries.

Work only in the verified CBE checkout and intended branch/PR. Preserve unrelated changes, local reference archives, installed Workshop/game files and signing keys. Never stage upstream reference assets into the product. Keep changes reviewable so a regression can be isolated and reverted without discarding unrelated work.

## Verification and progress

Extend relevant existing checks, then run coherent build/package gates at an implementation checkpoint. Do not weaken a failed check to conceal a behavioural defect. Retain failures and record the exact source/candidate and limitations.

Track **build-out**, **offline verification**, **physical behaviour** and **measured performance** separately. A capability can be implemented while physical validation remains pending; neither source inventory nor passing static checks proves it works in Arma. Audits remain paused until the user resumes them. Do not launch Arma or stage audits while paused. The performance target remains at most 5% median / 10% p95 overhead, subject to measurement.

For a material regression, isolate the changed execution path and repair or revert the responsible change before layering dependent functionality onto it. Do not count retained failures as accepted behaviour. Record remaining physical uncertainty for a later authorised pass without repeatedly rebuilding an unchanged candidate.

## Finite completion

A batch is complete when its stated outcome is implemented, relevant checks pass and no known material issue remains within that batch. Do not add optional refinements or move its criteria. Update the existing register/review record and handover with what changed, what is evidenced and what remains.

The overall production goal is complete when required selected functionality has an explicit resolved disposition, authority/lifecycle checks and authorised physical validation pass, and performance is measured within budget. It does not require wholesale copying of every reference or implementation of deferred optional scope. If blocked, record the exact blocker, completed work and minimum remaining action; continue independent required build-out where possible.
