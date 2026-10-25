# CBE continuation checkpoint, 25 October 2026

Continue the full production-ready CBE goal. Implement and physically validate infantry, CQB, coordination, combined arms, driving, convoys, aircraft and support through owner-local danger and operation FSMs. Required provider handovers must work. Preserve Zeus and multiplayer authority, and verify the 5% median / 10% p95 performance budget. The goal is active and incomplete.

Usage was 91% consumed in the weekly window at handover. The user requires a commit, PR update and handover below 10% remaining. A handover was pushed at `65fccad6`; subsequent goal continuations added the scoped vehicle editor controls below. The pause/continue question remains unanswered. Audits remain paused. Do not launch Arma, merge, publish a Release, upload to Steam or pause the goal without the required user instruction.

## Repository and checkpoint

Work only in `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`, branch `Adam/cbe-aircraft-release-followup`, remote `https://github.com/AdamWaldie/CombatBehaviourEnhancement.git`. This chat's WaldosMissionPack workspace is unrelated. Verify the root, remote, branch and live draft PR #17 before every Git mutation. Use the current HEAD for the handover commit. The previous implementation commit was `20be0777`. The latest scoped implementations are recorded in `hbq-vehicle-editor-exclusions-20261025.json` and `hbq-legacy-gate-channels-20261025.json`; inspect current HEAD and its source hashes.

The push result will be recorded in `.qa/handovers/low-usage-push-20261025.json`. Check that receipt and the live remote before assuming the checkpoint was pushed. Historical notes remain in `AGENT-HANDOVER.md`; the current entry supersedes earlier proposed next tasks.

The latest exact unsigned development candidate is `.qa/candidates/artillery-hold-platform-616cbc0c`, fingerprint `8dd62cdaedd1488946a953ba6e3b5aac38b2648cac0d03bef57bd1e0503d7a5d`. Its source is the named base plus recorded runtime hashes, with a dirty development checkout. It passed 1,497 offline tests, compilation of 422 SQF files, 11 PBO builds and independent package verification. Engineering notes and tracker edits postdate the package. They do not turn it into a clean signed release or physical acceptance.

Private group wakes now reject non-finite deadlines and apply the existing low-FPS policy. Live danger responsiveness bypasses backoff; illumination and COVER caps apply afterward. Do not implement that task again. Recent work also covers selected artillery crew positioning without group splitting, remote HOLD readiness, convoy reversal navigation yield, reserved-support discovery filtering and clearance-owned grenade interruption. Physical reliability remains unverified.

Eight Eden driving opt-outs now publish a separate server-owned editor exclusion list, preserving CBA/global gates and mission-authored exclusions. No extra movement controller or worker was added. Full offline build and independent verification passed; editor/runtime behaviour remains unverified. See `releaseVerificationAndDeployment/referenceReviews/hbq-vehicle-editor-exclusions-20261025.json`. Private follow-up source comparisons are `.qa/handovers/hbq-recovery-next-read-20261025.json` and `.qa/handovers/hbq-vehicle-controls-next-20261025.json`; the latter's frontend gap is now built, not physically accepted.

Legacy source-empty gates with paired indexed literal animate actions now retain their channel through opening/closure. Model presence, lock and existing geometry checks are required; arbitrary/unindexed/scripted gates remain unsupported. See `releaseVerificationAndDeployment/referenceReviews/hbq-legacy-gate-channels-20261025.json`. This supersedes the simple unsupported-legacy hypothesis in `.qa/handovers/hbq-gate-channel-gap-20261025.json` only for the admitted subset. Actual animatability and passage remain unverified. CQB exit source trace is `.qa/handovers/cqb-exit-next-evidence-20261025.json`; it does not resolve historical clustering.

The indexed authored-route reader now slices a single handle before metadata filtering; full-route reads retain all authored metadata. Native array retrieval still scales with route size. See `releaseVerificationAndDeployment/referenceReviews/route-index-receipt-20261025.json` for exact source hashes, build result and selected main-loop/watchdog source dispositions. Private worker-source review is `.qa/handovers/hbq-physics-workers-review-20261025.json`. These reviews do not establish whole-controller parity or physical acceptance.

Selected-gun HOLD validation now checks current platform convoy/external-driving markers before accepting a remote owner HOLD. Native task/destination/FSM proof remains owner-local. See `releaseVerificationAndDeployment/referenceReviews/artillery-hold-platform-20261025.json`. This closes a shared receipt-validation omission, not the remaining physical casualty/handback work. Current mixed-convoy smoothing trace is `.qa/handovers/mixed-convoy-current-control-20261025.json`; no coefficient change was justified without runtime traces.

## Next work and evidence

Prioritise foundations/FSM lifecycle and the entire HBQ driving intent, then individual behaviours and composition. Use LAMBS as an implementation baseline without requiring it as a dependency. Protocol work remains incomplete, including controlled rappelling, artillery casualty/native handback, CQB ordered owner-ready replay and finite post-clear consolidation. Mixed-convoy tuning needs physical traces when audits are authorised. Do not replace those gaps with more detection or packaging claims.

`docs/buildout-progress.json` separates build-out from acceptance. Its global freshness check still fails; 136 source paths had stale evidence at the last inventory. Scores were not inflated. Scheduler criteria received scoped current-source reassessments. Review the remaining evidence before renewing hashes or reporting a current whole-mod percentage. The generated report remains historical.

## Registers and protected stores

- Private mod register: `.qa/mod-by-mod-recoverable-tracker.json`; additions: `.qa/implementation-register-additions.json`. These recovered records are not proof that the historical master register is complete.
- Current source dispositions: `releaseVerificationAndDeployment/referenceReviews`. Start with `group-private-backoff-20261025.json`, `private-timer-deadlines-20261025.json` and `buildout-scoped-reconciliation-20261025.json`.
- HBQ complete snapshot: `.qa/hbq-complete-source-20261025`; LAMBS: `.qa/lambs-2621-review`; other extracts: `.qa/source-refresh-20261011/inventory`. Preserve all snapshots.
- Register backup: `C:/Users/AdamW/Documents/AI-Reference-Archives/CBE-Implementation-Register/20261024-airborne-preflight-234416342678`.
- Installed Workshop originals: `E:/SteamLibrary/steamapps/workshop/content/107410`. PinnedDown archive: `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`. The latter contains eight recovered extracted snapshots, not original PBO/signature backups.
- Permanent signing pair: `C:/Users/AdamW/OneDrive/Documents/Arma3ModsBikey`. Never regenerate, rename, overwrite or expose it. Public-key SHA-256: `297f847320561498d0c04e8db2e0570f60b770f1f932adcdcc20c45c2275c889`.

Never edit installed Workshop sources or preserved archives. Use new disposable copies and retain provenance. Keep private inventories and source assets out of commits and packages. IKMS, WBK Droids and WBK Zombies are compatibility-only and last. CBA owns settings; Zeus/ZEN modules issue behaviours. Avoid forced poses, teleport recovery, repair, immunity and physics pushes. Preserve mission skill ownership. Normal and actual-provider HC audits must remain separate when authorised.

Preserve the existing unrelated deletions under `.github`, artwork and branding, the deleted deployment requirements file, and the dirty `docs/PERFORMANCE-VALIDATION.md`. Every Python text edit must specify UTF-8 or preserve raw bytes. A default-decoding error was repaired; do not repeat it.
