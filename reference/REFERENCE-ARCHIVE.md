# Permanent reference archives

The current archive is recorded in [the archive index](../reference/reference-archive-current.json). It preserves 63 of 68 registered references: 55 installed originals and eight extracted-only Pinned Down references, plus older FPVSCARE/LAMBS/Protocol snapshots and review/register records. Each of the two permanent copies contains 1,680 manifest-covered files. The five source gaps are listed explicitly in the index.

Primary: `E:/AI-Reference-Archives/CBE-Reference-Library/20261108-complete-local-snapshot`

Existing secondary backup: `C:/Users/AdamW/Documents/AI-Reference-Archives/CBE-Reference-Library/20261108-complete-local-snapshot`

Manifest SHA-256: `04d4d6ad83a48ca288140364a311d477420537fc5aba9708ee584ba7a083efc3`

The files are independent of Steam installation, temporary folders and the repository checkout. Both copies were verified by hash. These are local backups, not an off-machine/disaster-recovery guarantee. Installed originals include package, signature and metadata files. Historical Pinned Down backups contain extracted source, not original signed packages. Availability does not establish licence, implementation parity or behaviour.

## Verify and restore

Run from the permanent CBE checkout:

```powershell
python releaseVerificationAndDeployment/reference_archive.py verify "C:/Users/AdamW/Documents/AI-Reference-Archives/CBE-Reference-Library/20261108-complete-local-snapshot"
python releaseVerificationAndDeployment/reference_archive.py verify "E:/AI-Reference-Archives/CBE-Reference-Library/20261108-complete-local-snapshot"
```

The snapshot also carries its verifier at `catalog/reference_archive.py`, so integrity checking does not require a surviving checkout. Use `reference-index.json` inside the snapshot to locate a mod. Restore a separate working copy for research; keep the archive unchanged. Restore the private implementation register from `catalog/implementation-register-additions.json` if necessary. Raw reference code/assets stay outside Git and release packages.

## New sources and updates

Before implementation or changing the local source installation, register the exact Workshop ID/scope and create a fresh snapshot:

```powershell
python releaseVerificationAndDeployment/reference_archive.py create --mirror-root "C:/Users/AdamW/Documents/AI-Reference-Archives/CBE-Reference-Library" --report .qa/reference-archive-result.json
```

E: is the default primary archive and preserved-source location. Future project work, builds and caches should use E: when possible. A mirror destination is required explicitly, so the tool never starts writing another C: copy by default. The example uses the existing C: secondary backup; prefer another non-C permanent backup destination when available. Never discard the existing C: copy merely to change the primary. New snapshots use a fresh UTC directory name. The utility refuses existing, temporary or in-checkout archive targets, compares source/destination hashes, detects file changes during copying and verifies both copies. Never overwrite an older snapshot. Update the tracked archive index and agent handover only after verification. Keep every unavailable source explicit; source-review documents are not raw backups. Do not run archival copies in CI or at every build.

Missing: Universal Difficulty Overhaul (1809358689), AI Stow NVGs (3443045523), Turret Tweaks (3475038178), Smart Merge AI (3721618614), and Infiltration AI Enhancement (3822271074). The first, second, third and fifth were already unavailable locally before recovery. Smart Merge AI's prior temporary raw copy is unlocated; its review/hashes survive. Official Steam metadata supplied no anonymous direct package download. Reacquire these packages/source and archive them as a new version; do not mark them preserved prematurely.

The implementation goal and audits remain paused. Archiving launches no game or audit and executes no reference addon.
