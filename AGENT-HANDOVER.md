# WAIT agent handover

Snapshot verified on 16 October 2026. Resume from the current checkout and revalidate remote state before changing Git. WAIT remains incomplete. All 65 feature families are partial and none has full acceptance. The full production goal remains active.

## Goal and user decisions

Deliver WAIT as a production-ready Arma 3 AI addon using owner-local danger and operation FSMs. Complete tactical infantry, CQB, coordination, combined arms, driving, convoys, aircraft and support. Required external controllers need real execution handovers. Preserve Zeus and multiplayer authority. Physical acceptance and measured overhead within 5% median / 10% p95 are required. Source presence, detection, packaging and static tests cannot establish these outcomes.

Audits are paused by the latest direct user instruction. Do not launch Arma until the user resumes them. Permission to close and restart identified audit processes is already granted for authorised runs. Verify the identified processes have exited. Keep normal/server-owned cases separate from real-provider headless-client batches. No audit or build process was left running at this handover.

Priorities and constraints:

- Reliable individual building blocks, driving controllers, FSM execution and the entirety of HBQ precede higher-level composition. Whole-mod review includes helper branches and callers. Avoid selected-file parity claims.
- CQB must work dynamically and repeatedly through terrain, editor-placed, Zeus-placed and usable modded buildings. Account for inaccessible internal points. Preserve failures. No teleport recovery or test-forced clearance.
- The user reported lead-first entry, stragglers, idle exterior soldiers, wedge formation and identical egress destinations. Implement useful isolation, casualty replacement, pairs, coherent entry and consolidation. Historical improvements do not establish current acceptance.
- CBA owns settings. Zeus/ZEN modules issue behaviour tasks. Consolidate modules with shared intent. Explicit Garrison teleport placement is allowed as a labelled task option. This exception does not extend to natural routing or CQB.
- IKMS, WBK Droids and WBK Zombies are compatibility-only. Compatibility expansion is last. Keep existing specialist ownership protections.
- Workshop IDs 3623550024 and 3798063749 were requested for evaluation across the entire addon. ID 3819636004 was added with Advanced Rappelling and CBA dependency requirements. Consult the implementation register and local sources before claiming coverage.
- Batch coherent pushes. Draft PRs use local validation. Do not trigger CI for every small change, remove checks, mark ready just to trigger CI, merge, publish a GitHub Release or upload to Steam.
- No subagents are authorised. Do not change saved memories unless the user explicitly requests it.

## Repository and review state

WAIT root: `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`

Remote: `https://github.com/AdamWaldie/WaldosAITweaks.git`

Branch: `Adam/owner-local-fsm-signing-20261016`

Latest implementation commit: `2f57b2a5b224aba169eaf9e57489c549eb52183e`. A subsequent checkpoint commit records documentation and this handover.

[PR 16](https://github.com/AdamWaldie/WaldosAITweaks/pull/16) is open and draft. The previous pushed source was `71e4d45af4f6139fbdc1a2d7808c926465162b64`. Revalidate the live head and inspect `git log origin/Adam/owner-local-fsm-signing-20261016..HEAD` for outstanding commits. This handover is tracked with the driving review checkpoint and excluded from player packages. Preserve any unrelated dirty files.

The chat is attached to WMP at `C:/Users/AdamW/OneDrive/Documents/GitHub/WaldosMissionPack`. That checkout has unrelated work. Do not put WAIT changes there. The execution sandbox may require escalation for writes, Git and builds in WAIT. Elevated GitHub CLI works. A non-elevated authentication failure can be misleading.

Before each Git mutation, verify root, remote, branch, staged files and the intended open PR. Stage exact files. Preserve other changes. Use author `WaldoTheWarfighter` with `adamwaldie@users.noreply.github.com`. Never reset, force-push or rewrite preserved branches.

Preserved history includes `Adam/driving-fsm-foundations`, its old draft PR 14, and `Adam/pre-consolidation-20261016`. PRs 12 and 13 were merged previously. Continued work belongs to PR 16 unless live state changes.

Read `AGENTS.md` and `CONTRIBUTING.md`. Every changed SQF file needs its required useful header. Keep operations finite, owner-local, interruptible and generation-bound. A newer mission task or Zeus order must survive cleanup.

## Latest validation and signed package

Latest local implementation validation:

- Driving changes through `2f57b2a` passed 1,057 tests, all sequential offline gates, HEMTT build and FSM inspections. The process exited 0.
- Nine PBOs compiled from 310 production SQF sources.
- Log: `.qa/workshop-comparison-20261014/driving-underside-build.log`.
- Unsigned package fingerprint: `3c980830d56a4a2e090a7e809fc59e63f97222fdba04cdd93f206c7bf2774ff3`.
- A new clean driving Release build uses `.qa/workshop-comparison-20261014/driving-checkpoint-release.log`. Its signed candidate/report, if successfully created, are under `releases/review-driving-20261016/`. Read the report for the exact source and hash. These paths do not themselves prove completion.

Earlier signed review candidate verified at capture:

- Clean source: `71e4d45af4f6139fbdc1a2d7808c926465162b64`.
- Artifact: `releases/review-checkpoint-71e4d45/wait-candidate.zip`.
- Report: `releases/review-checkpoint-71e4d45/signing-verification.json`.
- Archive SHA-256: `23edee770d5363689d23224b16f7d76f99e45d9f504f0623cf7c023d3b39b97d`.
- Package fingerprint: `649f890b7630b245e3488a0ca4cce21ffff4a88514ce48bd3c376c81a8de1c1a`.
- Complete Release pipeline passed 1,052 tests. Native signing produced nine signatures. Independent HEMTT verification accepted all nine and rejected all nine damaged-signature controls. Extracting the ZIP and repeating verification also passed.
- Inventory: 42 files, including nine PBOs, nine signatures and one pinned public key. No private key material.
- Release log: `.qa/workshop-comparison-20261014/combined-checkpoint-release.log`.
- Draft validation run 38924876669 completed as skipped, as intended. No release was published.

The driving checkpoint updates `docs/COMPLETION-STATUS.md` to the 1,057-test evidence boundary. PR/artifact reports retain their exact source identities. Do not silently relabel an older signed ZIP as containing later code.

Permanent signing identity:

- Existing pair lives at `C:/Users/AdamW/OneDrive/Documents/Arma3ModsBikey`.
- Filenames: `WaldoTheWarfighter.biprivatekey` and `WaldoTheWarfighter.bikey`.
- Public-key SHA-256: `297f847320561498d0c04e8db2e0570f60b770f1f932adcdcc20c45c2275c889`.
- Never regenerate, rename or overwrite this pair. Never print private bytes or encoded secrets. Never include them in Git, logs or packages.
- Repository secret `WALDO_SIGNING_KEYPAIR` is already configured. It holds JSON fields `privateKey` and `publicKey` as base64 values, configured through stdin. Do not reset it unnecessarily.
- `releaseVerificationAndDeployment/signing-identity.json` pins the authority, public fingerprint and signer. The retained armake2 patch handles file ordering and compiled SQF.
- Local signing uses the pinned native tool at `C:/Program Files (x86)/Steam/steamapps/common/Arma 3 Tools/DSSignFile/DSSignFile.exe`. The signing script validates its hash and uses temporary key files outside the checkout, removing them afterward.
- The supplemental native checker previously accepted a damaged control. Its result is inconclusive and receives no verification credit. Independent HEMTT positive/negative checks provide the credited evidence.

## Current investigation and next action

The mixed-convoy investigation found that detailed control capture existed but the normal matrix never enabled it. Commit `4b88ab6` wires it into WAIT cases and adds lead constraint/write observations. Engine baselines leave capture disabled. No convoy gains changed. Retained stop/restart results do not distinguish speed-policy effects from native path-planning pauses.

Subsequent scoped source comparisons produced two driving observation repairs: approaching-traffic discovery and density-independent native bend hints. The latest sensing repair preserves downward underside hits. Physical acceptance remains open.
Start with `addons/vehicles/functions/convoyTick.sqf`:

- Around lines 247-252, cached specs contain configured maximum speed and physical length.
- Around 365-380, column cruise uses the minimum of the requested speed and 80% of each configured maximum. Desired gaps account for vehicle length. This does not measure actual tracked step-off or braking response.
- Around 465-535, spacing uses longitudinal projection for nearby aligned pairs. Lead pacing reserves some cruise speed for gap closure. Only substantially stretched gaps use actual follower forward speed.
- Around 632-715, follower speed starts from predecessor forward speed plus proportional gap error. Outer-band catch-up is nonlinear. Body clearance and a mass-based closing cap constrain motion. Smoothing cannot override closing, reverse, obstacle or pedestrian limits.
- Later path writers retain predecessor trails, native/fixed-path ownership, grade/path caps and exact command receipts. Do not create a second steering or speed writer.

Next: trace the whole lead/follower control and trail commitment paths with the refreshed source comparison. Identify a concrete cause before tuning constants. Consider attainable column pace and delayed tracked launch, while retaining physical closing and braking safety. A configured top speed is not observed capability. Avoid feeding transient acceleration lag back through every follower until the column ratchets down to walking speed. Preserve deliberate roadblocks and native authored waits.

Useful source locations:

- HBQ: `.qa/source-refresh-20261011/inventory/3812620045/hbq_advanced_driving_ai/functions/fn_driveAssist.sqf`.
- Convoy reference: `.qa/source-refresh-20261011/inventory/3778948165/saai_vehicles/functions/fn_convoyTick.sqf`.
- Comparison: `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`.
- Branch-review index: `.qa/workshop-comparison-20261014/HBQ-SEMANTIC-REVIEWS.json`. Verify each indexed file hash before relying on its detailed review.
- The index explicitly leaves whole-HBQ review, cooperative passing, queue cascade, moving overtaking, corner manoeuvring, physical outcomes and performance incomplete.
- Convoy startup observation was extended to include the initial 20 seconds because later warm-up sampling missed step-off. Prepared normal-only bypass/passing cases remain unrun.

No live test should be launched under the current pause. Prepare a focused case only after the implementation and its failure hypothesis are concrete.

## Recent implementation details to preserve

### Combined ground and fire ownership

`cortexCombinedArmsLocal.sqf` admits exact server-published opportunities with original contact age and expiry. Local application identity includes the complete opportunity, owner and epoch. Duplicate delivery repairs replay metadata without repeating reveal, fire or route acquisition.

`cortexCombinedGroundStep.sqf` uses a common finite COMBINED_GROUND operation. A public ten-field journal retains opportunity, asset, spent stall count, progress time, last position, destination, original native-order receipt, driver, operator and ACTIVE/COMPLETE/FAILED state. Owner replay preserves these values. Malformed matching journals refuse safely. Recovery spends its one retry before issuing the new route. Terminal work does not restart after migration.

Exact route metadata and issued waypoint receipts protect native edits and cleanup. Arrival completes movement into the firing area. Fire effects remain unproven. Ground support checks current group gunner authority and target-suitable loaded station ammunition before movement, every four seconds during travel, and at arrival. Dormancy defers without renewing expiry. Definite failures clean up owned movement, authenticate exact retirement on the server and may spend one bounded retained fallback slot.

`cortexActorFireTaskAvailable.sqf` protects native service tasks and actor movement reservations. `cortexGroundFireReady.sqf` checks actual loaded gunner-station ammunition and configured target suitability. Keep authority policy separate from ammunition capability.

Routine vehicle targeting and danger suppression yield scripted ground fire to a live group-level combined-ground reservation. Smoke, passenger safety and natural engagement remain available. Routine gunnery checks gunner group, health, simulation, remote/specialist ownership, protected task, ammunition and firing lane.

Commit `a16cc75` adds bounded target fallback: rank known threats, consider at most eight, select the first compatible safe lane and stop. It retains the successful-fire hold. Worst-case query cost and actual engagement remain unverified.

Infantry `cortexFireControl.sqf` now uses `CortexActorMoveReserved`, so malformed/unknown reservations remain protected. Reserved movers retain natural engine aiming/fire and receive no injected target/fire/suppression command from this layer.

The prepared combined-arms fixture uses local gunner FiredMan projectile origin/course plus the admitted operator/token. It can observe directed shots when run. It cannot establish hits, suppression, destruction or HC observation coverage. Normal and HC fixtures must stay separate.

Open investigation: combined-ground direct fire and arrival targeting still need a complete finite command-ownership/retirement review. Clearing an assigned target solely because it equals an old target can overwrite an observationally identical newer command. Do not claim this cleanup is solved.

### Driving and CQB boundaries

Driving uses the existing owner-local FSM, shared scheduler and speed writer. Recent work includes stationary empty/wreck bypass, full 3D destination and seat-command receipts, finite recovery and default-off experimental passing. Passing checks owner consent, original expiry, oriented hull separation and measured traffic courses. Discovery is capped at 1,250 m and 64 actors, using a nominal 35 m/s approach allowance. Faster modded traffic and query cost remain limitations. Cooperative head-on jam clearance is unfinished.

CQB source includes pair replacement, actor-local indoor work, finite entry/egress, reserve admission and task-owned exterior settlement. The latest retained narrow physical evidence is older candidate `f9c3d7d`: two- and six-person covered visits completed, twelve-person clearance remained incomplete, and the batch retained 13 findings. These results do not validate current code. Terrain versus placed-building behaviour, dynamic routing, full participation, casualty flow, isolation, repeated use and consolidation remain acceptance work.

Preserved Pinned Down archive: `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`. Earlier checks verified 320 manifest entries, while eight installed original PBOs were missing. Revalidate the archive manifest before using it. Keep raw sources/assets out of published packages. No whole-Workshop parity percentage is justified.

## Validation and continuation procedure

Use the bundled Python runtime:

`C:/Users/AdamW/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`

From the WAIT root, the required full local pipeline is:

```powershell
$env:TEMP = [IO.Path]::GetTempPath()
$env:TMP = $env:TEMP
./releaseVerificationAndDeployment/build_mod.ps1 -Mode Build `
  -Python 'C:/Users/AdamW/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' `
  -Hemtt './.tmp/hemtt/bin/hemtt.exe' *> .qa/your-focused-build.log
```

Use Release mode for a new signed candidate. Wait for the same process handle to exit 0. Nine PBOs in the log is not terminal completion. Run sequentially. Do not modify source or start another builder while a build is active. Keep progress updates within about a minute and avoid repeated short polls.

The pipeline covers unit tests, SQF/config/header/link checks, wiki, CBA/script parity, static performance, feature coverage, HEMTT and FSM inspection. New sources need CfgFunctions registration and semantic coverage. Regenerate the feature report with `check_cortex_coverage.py --write-report releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md`. New settings also require the settings reference/parity update.

Useful canonical records:

- `docs/COMPLETION-STATUS.md`: evidence boundary and remaining acceptance.
- `releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md` and `coverage.json`: 65-family wiring and evidence.
- `docs/Smart-AI-Pass.md`: behaviour/authority guide.
- `releaseVerificationAndDeployment/cortexQA/PERFORMANCE.md`: runtime measurement requirements.
- `.qa/workshop-comparison-20261014/`: local review details and build logs. These ignored files are available on this machine and may be absent from a fresh clone.

Keep the goal active. When audits resume, rebuild a fresh exact candidate, verify mission entry/RPT and observe real physical outcomes and measured performance. Retain failed checks. Mark completion only when the entire stated goal is proven.

## Driving changes since the earlier signed source

- `a16cc75`: routine gunnery considers up to eight ranked known contacts, stopping at the first usable station/lane. Physical engagement and query overhead remain unverified.
- `4b88ab6`: normal matrix timing records actual lead/follower cap chains and write flags. Use this to diagnose mixed-column stops when audits resume.
- `4c15e3f`: scoped queue/jam source review records forced-velocity execution and timestamp-only back-up requests. A native authenticated queue-cascade executor remains missing. See `releaseVerificationAndDeployment/referenceReviews/hbq-jam-cascade-20261016.json`.
- `8ac3b95`: FollowingCap discovery includes own six-second travel plus nominal 35 m/s approaching travel and 20 m margin. It refuses envelopes above 500 m and candidate sets over 64. One query remains. Faster approaches, large modded hulls, physical braking and query overhead remain unaccepted. See `hbq-traffic-prediction-20261016.json` in the same engineering directory.
- `b058168`: native path hints walk six metres along retained path distance and interpolate sparse segments. They preserve the 64-node bound, exact fresh context, floor/forward limits and disconnected-stretch rejection. No movement command or new world query is added.
- `2f57b2a`: DrivingGeometryCap excludes upward support using signed surface-normal Z. Sampled downward underside hits retain solid constraints. Ray count, cadence and writers are unchanged. The source-derived predicate regression covers support, walls and sloping/horizontal undersides.

The curved-helper/Sense comparison is `releaseVerificationAndDeployment/referenceReviews/hbq-curved-observation-20261016.json`. Engineering attribution stays outside product guides. Whole-source parity and all physical/performance requirements remain open.

The retained mixed-column evidence is under `.qa/workshop-evaluation-20261012/`: `mixed-convoy-startup-control-review.json`, `mixed-convoy-control-review-20261013.json` and `convoy-historical-stop-start-baseline-20261013.json`. Read it before tuning gains. The source comparison still needs grade/deck observation, native queue execution and remaining helper/caller dispositions. No audit ran during these changes.
