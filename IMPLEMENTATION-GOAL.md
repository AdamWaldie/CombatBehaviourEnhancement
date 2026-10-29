# CBE implementation goal

Deliver a standalone Arma 3 AI improvement addon by selecting, combining, fixing and improving useful AI functionality from the source register. Gameplay quality, tactical plausibility, balance and engine performance govern the implementation. Implement useful LAMBS functionality inside CBE and evolve it without requiring LAMBS. Reconcile the entire relevant HBQ controller and all nine registered Protocol capabilities at their appropriate layers.

## Regular implementation commits

Make regular local commits as work progresses. Commit each coherent implementation or defect-fix checkpoint after its relevant checks, and before switching to a substantial new work area or handing over. Do not wait for the whole feature set, the full production goal, or a low-usage threshold. A necessary work-in-progress checkpoint must state unfinished work and failed or pending checks honestly.

Keep pushes batched at coherent review checkpoints to control GitHub Actions usage. Local commits do not require repeated full builds when runtime inputs are unchanged; completed review/push checkpoints still require the applicable full gates. Before each Git mutation verify the CBE root, remote, branch and intended PR, stage only an exact reviewed whitelist, and preserve unrelated changes. Never treat a commit or green package as physical acceptance.

## Governing directive — 27 October 2026

Use `reference/sourceReviews/source-review-map.json` and `reference/sourceReviews/SOURCE-REVIEW-MAP.md` as the recoverable source queue. Follow the linked LAMBS queue, HBQ index, Protocol programme and source-specific reviews below. Compare preserved source with current CBE executors before relying on an old assessment. The historical `LOCAL_IMPLEMENTATION_LEDGER.md` is absent; do not invent its contents or claim historical completeness.

Build in dependency order: owner-local FSM/execution lifecycles, then individual sensing/firing/movement/cover/building traversal/driving, then pairs and squads, then coordination and combined arms. A known material defect blocks dependent expansion until repaired or isolated. Continue independent required implementation where safe. This order must produce finite improvements, not an indefinitely expanding foundation programme.

Before each batch, identify its register entry, source version/hash and actual execution path; the intended gameplay improvement; the current CBE owner and dependencies; behaviour to preserve; and the finite outcome and relevant checks. Record which methods are retained, adapted, combined or rejected. Rejecting an unsafe method does not close a required capability gap.

Trace admission, task identity, actual command writers, delayed callbacks, interruption, cleanup and repeat use, including supported locality, casualty and deletion handling. Implement within the existing owner. Preserve newer mission/Zeus orders, authored skills, group policies, specialist control and useful native engine behaviour. Keep searches, update rates, concurrency and recovery bounded. Metadata retirement alone does not prove that native commands or external controllers have stopped.

Preserve the prior verified candidate and its limitations. If a regression appears, isolate and repair or revert the responsible change before adding dependent behaviour. Do not compensate with competing controllers, forced actions, renewed retry budgets, audit assistance, false completion or weaker checks. Extend relevant existing checks and run coherent build/package gates at the checkpoint. Stop the batch once its outcome is delivered, its checks pass and no known material issue remains within its scope.

Record implementation and unresolved gaps in the existing source review/register and handover. Report build-out, offline verification, physical behaviour and measured cost separately. Pending physical acceptance does not erase implemented work; source review, file counts and green packages do not demonstrate improved AI. The full production objective and maximum 5% median / 10% p95 overhead target remain active.

Audits remain paused: no Arma launch or installed-game staging. Work only in the verified CBE checkout and intended branch/PR. Preserve unrelated changes, Workshop originals, extracted baselines, archives and signing keys. Keep raw reference material and secrets out of commits and packages. This directive authorises no merge or publication. Compatibility-only, optional and follow-on scope remains as recorded below.

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
