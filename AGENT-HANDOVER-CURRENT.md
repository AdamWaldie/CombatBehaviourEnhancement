# CBE continuation checkpoint, 25 October 2026

Continue the full production-ready CBE goal. Implement and physically validate infantry, CQB, coordination, combined arms, driving, convoys, aircraft and support through owner-local danger and operation FSMs. Required provider handovers must work. Preserve Zeus and multiplayer authority, and verify the 5% median / 10% p95 performance budget. The goal is active and incomplete.

Usage was 91% consumed in the weekly window at handover. The user requires a commit, PR update and handover below 10% remaining. No further implementation batch was started after that reading. Audits remain paused. Do not launch Arma, merge, publish a Release, upload to Steam or pause the goal without the required user instruction.

## Repository and checkpoint

Work only in `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`, branch `Adam/cbe-aircraft-release-followup`, remote `https://github.com/AdamWaldie/CombatBehaviourEnhancement.git`. This chat's WaldosMissionPack workspace is unrelated. Verify the root, remote, branch and live draft PR #17 before every Git mutation. Use the current HEAD for the handover commit. The last implementation commit is `20be0777`.

The push result will be recorded in `.qa/handovers/low-usage-push-20261025.json`. Check that receipt and the live remote before assuming the checkpoint was pushed. Historical notes remain in `AGENT-HANDOVER.md`; the current entry supersedes earlier proposed next tasks.

The latest exact unsigned development candidate is `.qa/candidates/group-private-backoff-67bfbf79`, fingerprint `00111b7aa55b992e8dec7f33dd5871c0c971fd01ce408fd3b611c4e815b14ee5`. Its source is the named base plus recorded runtime hashes, with a dirty development checkout. It passed 1,497 offline tests, compilation of 420 SQF files, 11 PBO builds and independent package verification. Engineering notes and tracker edits postdate the package. They do not turn it into a clean signed release or physical acceptance.

Private group wakes now reject non-finite deadlines and apply the existing low-FPS policy. Live danger responsiveness bypasses backoff; illumination and COVER caps apply afterward. Do not implement that task again. Recent work also covers selected artillery crew positioning without group splitting, remote HOLD readiness, convoy reversal navigation yield, reserved-support discovery filtering and clearance-owned grenade interruption. Physical reliability remains unverified.

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
