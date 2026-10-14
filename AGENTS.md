# Contribution guidance

- Every SQF file must begin with a useful documentation block naming `WaldoTheWarfighter` as author and documenting purpose, locality, repeat/JIP behaviour, arguments, return value, callers and an example.
- AI operations must be finite, locality-aware and immediately interruptible by Zeus or a newer mission order.
- Preserve feature gates and public intent. Do not add global per-frame scans or permanent movement controllers.
- Static tests are regression gates. Arma behavior requires the checked-in dedicated-server/client audit and fresh runtime evidence.
- Optional AI addons receive explicit ownership; never run two movement controllers over the same group.

- Follow CONTRIBUTING.md for source, feature-guide and PR documentation requirements.
- Run the complete build_mod.ps1 gates, including config, documentation/link checks, CBA/Zeus/script parity and static performance regression checks. HEMTT compilation/lint and FSM validation are mandatory.
- Never blanket-accept performance findings or claim static/package success as live tactical acceptance. Preserve the exact packaged candidate for audit and release.

## Standing user scope and priorities

These are established user requirements, not new discoveries. Carry them into every follow-up and handoff. The latest direct user instruction overrides a stale status note.

- IKMS (the melee reference), WBK Droids and WBK Zombies are **compatibility-only**. Review their ownership, animation and handover requirements, but do not count them as general tactical implementations, behaviour parity or feature-completion progress. Compatibility expansion is last. Existing specialist takeover safeguards remain required throughout.
- Prioritise FSM decision/execution ownership and the **entire HBQ driving source**. Every source function and every major branch needs a recorded disposition, including startup/locality, settings, terrain/navigation areas, predictive obstacles, gates, traffic, jams, recovery, crew policy, damage policy, diagnostics and performance. A selected-function review is not a whole-mod review. Methods that violate physical recovery or mission authority must be redesigned or explicitly rejected, not silently omitted or copied.
- Build reliable individual behaviours before composing pairs, squads, multi-squad coordination and combined arms. Preserve the dynamic intent and the real execution path of source methods. Filename association earns no implementation credit.
- Use Zeus modules and existing native/optional ZEN controls as operator entry points for useful behaviours. Trace registration, labelled controls, payload, server authentication/validation, current-owner execution, acknowledgement, interruption, cleanup and repeat use. Never expose a module that bypasses the production executor or represents an unavailable behaviour as working.
- No implementation-completion percentage is justified by source inventory, setting coverage, registered tests or file-review counts. Distinguish implemented source, offline validation, narrow physical evidence, retained failures and complete acceptance.
- Current audits are held by user request. Do not launch until the user resumes them. Audit stop/restart permission is already granted when runs are authorised. Stop only the identified audit processes and verify that they actually exit. Normal and headless-client cases use separate batches.
- The chat may be attached to a different repository. WAIT is currently at `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`, remote `https://github.com/AdamWaldie/WaldosAITweaks.git`. Before every Git mutation, verify the actual repository root, remote, branch and intended PR. Do not commit WAIT work to another checkout. PR 12 was merged. Follow-up currently belongs to PR 13, but verify its live state before updating it.

Current local source comparison: `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`. Its deep-review items remain open. The source index is structural evidence only. Preserved Pinned Down sources are under `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`; verify its manifest before relying on it. Keep raw sources and assets out of published product content.
