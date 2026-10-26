Governing implementation direction: read IMPLEMENTATION-GOAL.md, especially the Current goal directive and source-register batch requirements, before choosing work. Foundations first; preserve working behaviour and protected sources. Audits remain paused.

Current implementation direction: see `IMPLEMENTATION-GOAL.md`; use the source register and build upward from FSM foundations. Audits remain paused.

# Contribution guidance

## Definition of done

Work toward a clear, finite definition of done. Treat the task as complete when the requested outcome is delivered, the relevant checks pass, and no known material issue remains within scope.

Do not continually subdivide the work, move the completion criteria, or add optional refinements. Every additional step must resolve a specific unmet requirement, failed check, or material uncertainty. Once those are resolved, stop and deliver the result.

If completion is blocked, state the exact blocker, what is already complete, and the minimum action needed to finish. Do not substitute repeated planning, monitoring, or status updates for completion.

- Every SQF file must begin with a useful documentation block naming `WaldoTheWarfighter` as author and documenting purpose, locality, repeat/JIP behaviour, arguments, return value, callers and an example.
- AI operations must be finite, locality-aware and immediately interruptible by Zeus or a newer mission order.
- SQF `call` uses dynamic scope. Do not shadow an outer control flag with an actor array or another type in a block that calls helper CODE; pass context explicitly where practical. Queued CBA callbacks need explicit argument payloads, not presumed lexical captures.
- Trace actual execution context before claiming an intra-call scheduler race: CortexSchedulerTick calls jobs directly from a CBA PFH, normally unscheduled. Its budget applies between jobs, not within one callback. Separate deferred messages/timers, scheduled direct callers and synchronous re-entry from ordinary scheduler suspension. Do not add repeated guards or copy work on a suspension assumption alone; record the real stale-input case and measure added cost.
- Preserve feature gates and public intent. Do not add global per-frame scans or permanent movement controllers.
- Static tests are regression gates. Arma behavior requires the checked-in dedicated-server/client audit and fresh runtime evidence.
- Optional AI addons receive explicit ownership; never run two movement controllers over the same group.

- Follow CONTRIBUTING.md for source, feature-guide and PR documentation requirements.
- Run the complete build_mod.ps1 gates at a coherent implementation checkpoint, including config, documentation/link checks, CBA/Zeus/script parity and static performance regression checks. HEMTT compilation/lint and FSM validation remain mandatory before that checkpoint is delivered. During development use focused existing checks; a local commit or goal continuation alone is not a reason to rerun the full build.
- Never blanket-accept performance findings or claim static/package success as live tactical acceptance. Preserve the exact packaged candidate for audit and release.

## Standing user scope and priorities

These are established user requirements, not new discoveries. Carry them into every follow-up and handoff. The latest direct user instruction overrides a stale status note.

- IKMS (the melee reference), WBK Droids and WBK Zombies are **compatibility-only**. Review their ownership, animation and handover requirements, but do not count them as general tactical implementations, behaviour parity or feature-completion progress. Compatibility expansion is last. Existing specialist takeover safeguards remain required throughout.
- Prioritise FSM decision/execution ownership and the **entire HBQ driving source**. Every source function and every major branch needs a recorded disposition, including startup/locality, settings, terrain/navigation areas, predictive obstacles, gates, traffic, jams, recovery, crew policy, damage policy, diagnostics and performance. A selected-function review is not a whole-mod review. Methods that violate physical recovery or mission authority must be redesigned or explicitly rejected, not silently omitted or copied.
- Artillery crew policy (user decision2026-10-24): preserve existing group membership. Position only the selected gun and its operating crew; never automatically split a gun-crew group or redirect unrelated infantry through a group-wide waypoint. Selected-platform movement/hold/return must preserve unrelated actors' native orders and current mission authority.
- Build reliable individual behaviours before composing pairs, squads, multi-squad coordination and combined arms. Preserve the dynamic intent and the real execution path of source methods. Filename association earns no implementation credit.
- CBA settings own addon configuration, feature enablement and tuning. Native Zeus/ZEN modules issue **behaviour tasks**, not settings or diagnostics panels. Follow the source task pattern: explicit group, destination/area or behaviour-specific world target, scoped task parameters, authenticated server dispatch and current-owner executor. Do not recreate ordinary-driving enable/release/inspect modules. HBQ navigation corridors and LAMBS CQB/garrison/defend task modules are reference examples; copy intent, not unsafe implementation shortcuts. A task's radius or destination parameter is not a global addon setting. Trace registration, labelled controls, payload, authoritative validation, owner execution, acknowledgement, interruption, cleanup and repeat/JIP behaviour. Never present an unavailable behaviour as working.
- No implementation-completion percentage is justified by source inventory, setting coverage, registered tests or file-review counts. Distinguish implemented source, offline validation, narrow physical evidence, retained failures and complete acceptance.
- Current audits are held by user request. Do not launch until the user resumes them. Audit stop/restart permission is already granted when runs are authorised. Stop only the identified audit processes and verify that they actually exit. Normal and headless-client cases use separate batches.
- The chat may be attached to a different repository. WAIT is currently at `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`, remote `https://github.com/AdamWaldie/CombatBehaviourEnhancement.git`. Before every Git mutation, verify the actual repository root, remote, branch and intended PR. Do not commit WAIT work to another checkout. PRs 12 and 13 were merged. Continued work starts from merged main on a new branch and belongs in a new PR. Verify the live PR state before updating it.

Current HBQ evidence pointers: `releaseVerificationAndDeployment/referenceReviews/hbq-reference-index.json`. Verify locally with `python releaseVerificationAndDeployment/hbq_reference_index.py`; refresh deliberately with `--write` after reviewing changed evidence. This local-only checker requires preserved private inputs and must not be added to public CI. Historical unresolved review links are not recovered findings or proof of source parity.

Current local source comparison: `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`. Its deep-review items remain open. The source index is structural evidence only. Preserved Pinned Down sources are under `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`; verify its manifest before relying on it. Keep raw sources and assets out of published product content.
- Explicit Garrison task teleport placement is permitted as an operator-selected, clearly labelled option (user clarification 2026-10-14). Keep walking garrison as a distinct mode. This exception does not authorise teleport recovery, natural building routing, CQB clearance, physical-audit completion. Other module shortcuts may be exposed as explicit task options when their production executor supports them; do not silently choose a fallback target or safety policy. Do not treat source shortcuts as universally forbidden or permitted: record each task's purpose and the user's scoped decision.

- Consolidate source modules with the same behaviour intent into one WAIT task surface. Garrison combines useful source methods through labelled per-task options, not duplicate source-branded modules. Keep walking/instant placement distinct; assess height preference, patrol, exit conditions, static-weapon use and casualty refill against real executor support. Use selectors for mutually exclusive modes and toggles for independent choices. Defence lines, object defence and physical clearance remain separate intents. Never add a cosmetic option without authoritative parsing, owner execution and cleanup.

## GitHub Actions usage

- Batch related implementation work locally; do not push every small commit or every goal continuation. Push a coherent review checkpoint after local validation, or when the user requests it. Avoid repeated remote reruns without diagnosing the failure first.
- Validation runs automatically for main and ready pull requests. Draft PRs use local gates; a remote draft check requires deliberate workflow_dispatch. Do not mark a PR ready merely to cause a build. Ready-for-review must trigger the complete validation pipeline.
- Keep validation concurrency scoped to the workflow and PR/ref, cancel superseded validation runs, and preserve full release/signed-candidate checks. Do not use skip-ci messages or remove tests to conceal failures.
- Pass the read-only GitHub token to the HEMTT installer to avoid unauthenticated release API rate limits; never print it.

## Continuation handover

Read `AGENT-HANDOVER.md` for the current review checkpoint, local evidence paths and outstanding work. Revalidate live Git/PR and process state before relying on its snapshot. The handover and engineering reference reviews are not player-facing package content.

## Low-credit checkpoint and handover

User standing instruction updated2026-10-24: when remaining usage is below10%, immediately save a safe commit, update the correct pull request and provide a continuation handover. This supersedes the earlier20-credit threshold. Use the live account usage percentages: remaining is100 minus usedPercent for each applicable reported window. A supplemental credit balance is not a usage percentage; missing windows are unknown, not full or empty.

Check the live account usage tool before a long work batch and when resuming after a substantial break. Do not claim continuous monitoring between turns. When any applicable reported window is below10% remaining, do not start another implementation batch. Bring the current bounded operation to a safe checkpoint, inspect any actual live process handle, preserve unrelated changes, verify repository/branch/PR identity and commit only intended work. The user's threshold instruction authorises pushing that safe checkpoint to the correct existing PR branch and updating its description, or creating a new PR if no correct open PR exists. Do not force-push, merge, publish a release, mark a draft ready merely to trigger CI or conceal failed checks. If saving/pushing is blocked, retain the local commit and report the exact blocker and unpushed state.

Refresh AGENT-HANDOVER.md and AGENT-CONTINUATION-PROMPT.md with the unchanged full objective, plan, current branch/commit/PR, local versus remote state, implemented and unfinished areas, failed checks, exact artifacts, validation limits, active processes, pending decisions, audit authorisation and next action. Include the implementation register/mod list, source inventories, review registers, Workshop originals and protected archive locations. Display the absolute working directory and relevant stores in the user-facing handover, and link the commit/PR and continuation prompt. Never expose private source contents, keys or secrets. Never mark the goal complete, change audit permission or redeem a usage reset because the threshold was reached. Preserve the full scope for the next agent.

## Required plan and Workshop source protection

Every agent must read this section plus `AGENT-CONTINUATION-PROMPT.md` and the latest dated notes in `AGENT-HANDOVER.md` before changing WAIT. Follow the full production-readiness goal; do not substitute inventory coverage for working behaviour.

1. Establish current repository/PR boundaries and retained failures. Review current source against the user's intent and relevant Workshop implementation before proposing a fix.
2. Build reliable individual execution and owner-local FSM building blocks first, with the entire HBQ driving controller a priority. Then compose buddy pairs, squads, coordination and combined arms. Preserve dynamic CQB entry, routing, garrison, casualty replacement, exterior isolation and post-clear continuation.
3. Record source intent, actual call path, useful methods, unsafe shortcuts, licence constraints, implementation disposition and remaining gaps. Compare whole AI scope, not just the current CQB topic. CBA owns settings; Zeus/ZEN modules issue behaviours. Compatibility-only sources remain compatibility-only.
4. Validate bounded changes locally, commit coherent checkpoints and update handover/evidence. Physical audits remain paused until the user resumes them. Later run normal and actual-provider HC batches separately, retain all failures and measure physical behaviour and the 5% median/10% p95 performance budget. Do not merge or publish without authorisation.

Workshop references and their private local sources are protected research inputs:

- `LOCAL_IMPLEMENTATION_LEDGER.md` is the private master mod list/intent register. Keep it local and excluded from Git. Never force-add it. `docs/COMPLETION-STATUS.md` and `releaseVerificationAndDeployment/cortexQA/{FEATURE_STATUS.md,coverage.json}` record acceptance limits.
- `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`, `source-code-index.json`, `wait-code-index.json`, `HBQ-CONTROLLER-BRANCH-INDEX.json` and `HBQ-SEMANTIC-REVIEWS.json` locate source and review evidence. `.qa/source-refresh-20261011/code-inventory.json` and `inventory/<WorkshopID>/` contain the extracted baseline. HBQ:3812620045; LAMBS:1858075458. Read tracked `releaseVerificationAndDeployment/referenceReviews/` for later findings and freshness checks before repeating an old review.
- Evaluate3623550024 and3798063749 across their general AI scope;3820871877 is AI-only, excluding player features.3819636004 requires Advanced Rappelling and CBA. The private ledger remains authoritative for the complete reference list; these examples are not exhaustive. IKMS, WBK Droids and WBK Zombies are compatibility-only.
- Preserve `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708` independently of Steam and the temporary checkout. Read its README/manifest and use `verify_archive.py` to check integrity before relying on archived contents. Eight missing Workshop installations were preserved as extracted snapshots, not original PBO/signature backups; never imply otherwise.
- Never edit, delete, move, overwrite or repack installed Workshop originals, preserved archives, extracted baselines or their provenance as part of implementation/build/cleanup. Do not run reference scripts/addons merely to inspect them. Use a separate disposable working copy for experiments or extraction; keep new versions in distinct dated directories with origin, Workshop ID and hashes. Never silently replace an old snapshot or prune the archive because Steam removed a mod.
- Keep raw upstream code/assets, private inventories and signing secrets out of product packages and repositories. Preserve attribution/licences alongside reference copies; a method's usefulness does not authorise copying restricted code. Implement permitted intent in WAIT and document provenance/disposition.
- A fresh clone does not contain the private mod list or snapshots. If absent, report exactly what is unavailable and locate the preserved material before claiming a comparison. Do not fabricate parity or recreate lost sources from memory. Carry these paths, protection rules and open source gaps into every successor handover.

## Current product name and first-release namespace

The user explicitly chose Combat Behaviour Enhancement (CBE) and required a complete first-release changeover with no legacy product-name compatibility. Use only CBE_fnc_* functions, CBE_* settings/state/events/module and patch identifiers, virtual root z/cbe/addons, PBO prefix cbe, receipt cbe-build.json and candidate cbe-candidate.zip. Do not add WAIT function aliases, old setting adapters or the former Waldo_AI_Tweaks_Main detection patch. Native command/phase strings WAIT are engine semantics and must remain WAIT. External providers' actual APIs and ownership markers retain their providers' names. The repository URL is https://github.com/AdamWaldie/CombatBehaviourEnhancement; the existing local checkout folder remains WaldosAITweaks. Do not rename or move that folder implicitly. Permanent signing authority and protected Workshop inputs are unchanged. Dated reference reviews and archived audit receipts retain historical names as evidence.

## External-controller handover evidence

A pause flag or a main-loop running marker is not exclusive movement authority. Before implementing an adapter, enumerate every current writer, including recovery, push/physics, crew policy, seat callbacks and cleanup. Require an actual owner/token/episode-scoped quiescence acknowledgement before CBE writes, and a real provider resume acknowledgement plus physical authored-order travel afterward. Do not fabricate success from detection, elapsed nominal callback delay or empty main-loop flags. Current HBQ findings and required contract are in `releaseVerificationAndDeployment/referenceReviews/hbq-controller-handover-20261018.json`; Pause does not stop every worker, and already queued callbacks have separate lifetimes. Keep compatibility expansion last; use findings now to improve CBE individual/FSM mutation guards. Never alter protected sources to make a handover test pass.

## Audit predicate scope

Shared SQF wait helpers must reserve distinct parameter/local names such as `_cbeQaWaitPredicate` and `_cbeQaWaitDeadlineTick`. `call` predicates read the active dynamic scope; a helper-local `_until` hides a caller's mission/server-time `_until` and can cause false timeout or acknowledgement findings. Preserve the caller's clock and original deadline. Do not fix a failing audit by assigning production completion state. Prepared procedures remain unrun until fresh in-engine evidence exists.

## Source integration and behaviour acceptance

The implementation strategy is selective functionality improvement across the reference collection. Review each mod for useful AI intent, then keep, merge or redesign complementary methods inside CBE. Whole-mod imitation is not the completion criterion. Rejecting an unsafe method does not remove a required gameplay capability; implement a suitable replacement. Use `reference/sourceReviews/SOURCE-REVIEW-MAP.md` and `reference/sourceReviews/source-review-map.json` for the recoverable review queue, missing evidence and each reference's intended contribution. Preserve foundations-first, Protocol priority, compatibility-only and optional/deferred scopes.

The source collection exists to combine unique capabilities, sound decisions and working improvements into one coherent CBE controller. Evaluate complete intent and execution, not isolated matching functions. For each selected source method, record its contribution, interaction with existing layers, authority, balance and cost, deliberate departures, remaining gaps and physical evidence. Distinguish reviewed, selected, implemented, integrated and physically verified. Parity is useful baseline evidence, not the final goal; reject conflicting controllers and preserve complementary strengths. Compatibility-only sources remain separate. No source-count percentage establishes functional delivery.

## Build-out progress versus acceptance

The user explicitly requests build-out percentages separately from acceptance (2026-10-19). Maintain docs/buildout-progress.json and its generated BUILDOUT-PROGRESS.md. Score concrete scoped capabilities and their integration, with named remaining code gaps and source evidence; give partial build credit. Missing physical acceptance does not imply0% build-out. Keep unknown scope unassessed, never zero; no overall figure until all registered families have explicit denominators. Do not substitute source file, settings, test or review counts. When referenced source changes, reassess the relevant criteria and evidence hashes rather than silently renewing figures. Physical acceptance, runtime balance and performance remain separate evidence, required for release. Run buildout_progress.py --check after rendering the reviewed ledger.

Build-out scope clarification: the 65-row acceptance registry contains 64 product families plus one acceptance-only equal-force battle scenario. Keep the scenario visible but unscored; no fixture credit in product build-out. Whole registered-plan estimates use the declared subsystem/family scope weights, not equal weighting of a small countermeasure feature and a whole operation. Scope weights reflect planning priorities, not measured effort. Current survey is provisional/mostly low-confidence; source parity and the still-unreconciled Workshop expansion denominator remain separate. Do not describe the registered-plan index as the full Workshop implementation percentage.

## Build upward from foundations

User clarification2026-10-19: build upward, not by chasing disconnected tactical feature patches or raising tracker figures. Prioritise shared ownership/admission, interruption and exact restoration, scheduler/FSM lifecycle, movement/sensing primitives and bounded cost. Compose individual behaviours only on those foundations, then buddy/pair work, squad roles, coordination and combined operations. Carry source intent through the layers and keep compatibility expansion last. Finish and validate in-flight work safely, then return to the shared foundation gaps; do not treat another feature checkbox as the next priority by default.

## Settings receipt cleanup

Application-time validation is not sufficient when direct stop/exclusion paths call restoration independently. Use the shared typed receipt boundary at every native settings cleanup. A missing applied or original value grants no restoration authority and must not consume the other half. Skill/aim pairs can retire independently; retain pending metadata. AIProfileReceipt is structural evidence only, not proof of ordered replication, never-profiled state, owner admission acknowledgement or eventual handback. Do not add a timer that reclaims mission-owned settings.

## Validation cost and implementation batches

User clarification 2026-10-19: validation must support implementation rather than dominate it.

- Group related foundation and behaviour changes into a coherent implementation batch. Run focused existing checks during development, then the complete sequential pipeline before delivering or pushing that checkpoint. Do not repeat an unchanged successful full build just because a new turn began or a bookkeeping commit was made.
- Repeat a failed gate after addressing its cause. Broaden checks when changed code, shared dependencies or unresolved findings justify it. Record the exact source and dirty-state provenance of the last successful package; later source changes are not covered by it.
- Prefer extending a meaningful existing regression case. Add a case only for a distinct failure mode or behavioural invariant; avoid a new source-spelling assertion for each guard, branch or helper. Never remove a check merely to reduce the count or conceal a failure.
- Keep static contracts, physical behaviour and measured performance separate. More tests and green source-shape assertions do not establish better AI. Audits remain paused until the user authorises them.
- Do not push micro-commits, dispatch remote checks or mark a draft ready to obtain routine development feedback. Preserve the complete release gates.


## Priority update - 2026-10-20

The user prioritises foundations and FSM lifecycle, with functional parity and improvements over LAMBS danger behaviour, before the next broad implementation wave. LAMBS is a reference, not a required addon. Trace native danger ingestion, actor/group decision ownership, operation start/update/cancel/end, locality transfer, interruption, restoration and finite scheduling against source intent. Improve real execution; do not substitute documentation or matching filenames for functionality.

Next, implement, fix and improve the complete Protocol AI collection. Evaluate every available mod and its complete AI scope, retain useful distinctive behaviour, redesign unsafe methods and merge it into CBE ownership rather than copy competing loops. Do not treat this as compatibility-only. Respect source permissions/dependencies and mission authority. Enumerating locally installed items does not establish that the whole Workshop collection has been found. Existing HBQ priority, protected sources and paused audits remain in force; compatibility expansion stays last.


## Animation quality requirement

User clarification2026-10-24: arm stretching and similar visible body or weapon animation distortions are defects. Preserve normal anatomy, joint proportions, weapon grip/alignment and believable transitions. Do not use forced animation, pose, speed or transform changes that stretch limbs or break weapon handling to make a behaviour appear to work. Use supported engine animation/stance paths and account for the active weapon and character rig. Animation-affecting changes require visual in-engine checks of the affected transitions before acceptance; compilation and static checks do not establish visual quality. Audits remain paused until authorised, so record unverified visual behaviour explicitly. Carry this requirement into implementation reviews and handovers.


## Register recovery when the private master is unavailable

The historical LOCAL_IMPLEMENTATION_LEDGER.md remains missing. Do not replace it with an inferred complete list. Later additions are separately reconciled in ignored .qa/implementation-register-additions.json against tracked referenceReviews/workshop-intake-*.json; the nine locally registered Protocol sources use protocol-implementation-programme-20261020.json. Read the named dated reviews before assigning work: an intake status is not whole-source implementation or physical acceptance. Recovery/backup and archive verification evidence is in local-reference-freshness-20261017.json registerRecovery20261024. Keep private registers/backups out of Git.


## Automatic airborne ground squad

User clarification 2026-10-24: when operating aircrew and passengers share a group, automatically form the original grounded surviving passengers into a separate ground squad after insertion. Preserve the flight crew and its native route. Cargo-only squads retain their group and authored orders. This explicitly authorised membership change is not teleport/recovery or permission to split unrelated mission groups. Keep native/care/reservation and pending restoration gates, exact insertion ownership, real join acknowledgements, partial-failure reporting and passive JIP metadata. Normal group tactics own the new squad; do not create a parallel permanent actor movement controller or count assignment as physical combat completion.

## Optional crew recall

User decision: HBQ-style crew recall must be an optional CBA setting, off by default. Use normal reboarding only, never forced seating. Intentional scripted dismounts must unassign the operator.


## Audit pause and implementation scope

An audit pause blocks installed-game staging and in-engine validation, not source implementation. Continue concrete foundation/FSM and registered-source build gaps while audits are held. Do not mark the entire goal blocked merely because physical acceptance cannot run while substantive implementation remains possible. Do not substitute repeated unchanged builds, speculative guard changes or status restatements for the remaining behaviour work. Retain build-out and physical acceptance as separate evidence.

## Current continuation after PR17

PR17 merged at `2dba3da92af80513e816e1f8fa45dfd6387d9df2` following the user's explicit instruction on26 October2026. Follow-on work is on `Adam/cbe-foundations-followup-20261026`, created from merged origin/main. Determine its current PR from the branch; never append new implementation to closed PR17. All prior source protection, exact checkout checks, audit pause and first-release namespace requirements remain. The current build-out percentage ledger fails its evidence check; reassess changed capability evidence before quoting an updated aggregate. Missing physical acceptance is separate from build-out. No Release/Steam publication is authorised by the checkpoint merge.
