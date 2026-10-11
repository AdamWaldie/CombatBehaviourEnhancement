# Audit error ledger

Every batch keeps its original RPT files and generated report. Repeated trace lines are not separate root causes. A fix is closed only after an exact packaged candidate completes the relevant retest without recurrence; static checks alone leave it pending.

## Batch runtime-20261010-214346-432

Candidate: clean `89812ab`. Full batch remains active. Snapshot checked 2026-10-10; counts may grow until completion.

| ID | Evidence | Cause and action | Retest status |
| --- | --- | --- | --- |
| E1 | Client RPT lines 759-764, 765-770 777-782 and 789-794; 22:14:46, 22:18:20, 22:24:19 and 22:26:56 | Four notification incidents: body string passed into a numeric text-size parameter. Corrected title/body line arrays in `acc9b93`. | Static/package gates passed; fresh packaged live retest pending. Original batch retains old payload. |
| E2 | Server RPT line 670; startup `a3_characters_f` dependency warning | Root cause unresolved. Previously observed in both addon-present and addon-absent candidates. Do not suppress or infer a missing installed base addon from this warning alone. | Runtime integrity and strict performance acceptance remain blocked. |
| F1 | Building-contact cases and user screenshot/intervention report | Obstructed sightline and inherited disabled Contact gate. User moved the hostile to permit visibility. Fixture repaired in `fba8d86`; current cases are manually assisted. | Unassisted contact/entry retest pending; old recorded results remain intact. |
| F2 | Two-/six-person clearance outcome sampled while RUNNING; terminal INCOMPLETE followed one second later | Audit terminal-settlement race repaired in `f16e084`. | Retest pending. Physical room-visit failures remain separate unresolved behaviour failures. |

Other failed assertions remain in the batch report for individual review. Object-not-found network messages are retained as observations; no proven cause or harmless classification is assigned here.

## Earlier batches

| Batch / candidate | Recorded runtime evidence | Outstanding follow-up |
| --- | --- | --- |
| runtime-20261010-123843-079 / 20fd9d7 | Completed; 755 checks, 62 server findings, no matched SQF/fatal errors, one loader warning | Behaviour failures and loader warning remain unresolved or awaiting repaired-candidate retest. |
| runtime-20261010-143646-413 / c9f6657 | Incomplete; 171 checks, 19 failures, no matched SQF/fatal errors, one loader warning | Missing completion evidence; no acceptance inferred. |
| runtime-20261010-151701-617 / 62d86bd | Completed; 300 checks, native HC registration prerequisite failed, no matched SQF/fatal errors, one loader warning | Native registration diagnostics queued; transfers/adoption not accepted. |

See [completion status](COMPLETION-STATUS.md) for category progress and [performance validation](PERFORMANCE-VALIDATION.md) for strict comparison requirements.

The reporter also rejects standalone parameter/type/generic/arithmetic error lines when an expression/position prefix is absent. Raw trace-line counts are not incident or root-cause counts.

Script-not-found and script-cannot-be-loaded messages are explicit load failures, with or without a Warning Message prefix. This prevents missing packaged/provider entry points from being classified as merely incomplete. The earlier provider path failure was repaired before candidate 62d86bd; native registration remains separately unresolved.

Tracked convoy findings: 15/30/50 m forward resume and turn-direction assertions failed in the active 89812ab batch. Queued repairs daa96ea and b35b53d invalidate stopped commitments and retire the matching lead HALT destination. Tracked 75 m also failed physical HALT with two followers near 30 km/h despite STOP/zero cap; adaptive unsettled-halt cadence is queued. These are unresolved physical failures, not closed by static validation.

Danger mortar handoff: native hostile knowledge/fire passed, but finite owner and warning assertions failed with inherited Contact disabled. The automatic vehicle handoff is below the Contact gate; the fixture now explicitly enables Contact independently of prior suite settings. Physical acceptance remains pending and old failures are retained.

Braking: enabled peak climb was 63.3451 m versus 75.7375 m disabled, so comparative improvement passed but the 10 m operational limit failed. Release reason was not retained in the old fixture log. The audit now captures the existing last-correction result, final velocity and position before deletion; no threshold or controller gain was relaxed. Late activation, timeout and priority/terrain release require evidence before further tuning.

Lateral attack case restarted after its first outcome: production cleanup shortened the audit's longer blocked-until deadline. Cleanup now retains the maximum existing deadline so another plan cannot overwrite the first case's outcome during collection. The actual target-destruction failure remains unresolved; stable evidence and physical retest are required.

Aircraft target eligibility follow-up: the active 89812ab report records `ModuleCurator_F`
for plane ground-target and damageable-target checks. Aircraft discovery accepted any living
hostile-side known/assigned object, including logic. Planning now rejects logic; discovery
and operation fallback skip those entries so they can select a physical hostile instead.
Release requests additionally check live weapon/launch alignment, and lateral selection reads
live turret traverse limits once. These corrections are statically/package validated only;
all original failed delivery and destruction results remain visible pending a new candidate.

At server RPT line 2136 (23:26:02), bomb prediction began repeated `vectorMultiply:
Type Not a Number` exceptions in the drag integration. The live report reached 4200
SQF error lines at 707 checks; this is repeated trace volume, not 4200 distinct defects.
Replace unstable acceleration integration with bounded dissipative velocity retention;
retain gravity and the measured impact basket. Physical bomb delivery remains unaccepted.

Lifecycle fixture classification: HC1/HC2 `LIFE-refused-transfer-registry-retained`
failed with empty companion-provider registry in the standalone engine-transfer batch. That assertion
contradicted the fixture's declared provider absence and demanded fabricated integration
state. The standalone case now checks no native registry was created; retained physical
owner/actor checks remain separate. Dedicated native-provider registration, pruning and
adoption cases remain unchanged and unaccepted. Original batch failures remain recorded.

Performance arm management cause: the preceding lifecycle case left autonomous Contact
disabled. The patrol fixture toggled only master enable, while CortexGroupTick deliberately
releases group ownership with Contact disabled. The next fixture explicitly enables Contact
for its matched arms. Existing zero-managed samples remain invalid. Queue latency and
physical route progress are separate measures; observed slow travel is not proven to be
scheduler delay by this run. No production cadence or native travel speed was changed.

Server RPT 23:54:07: `CortexCanTransmit` line 30 raised undefined `_factor` during
artillery smoke request acceptance. With no optional jamming hook, the default empty
code returned nil. The default now returns zero; nil from an unavailable installed hook
is treated as absent contribution. Numeric factors retain the 0.5 blocking threshold.
The original ART-SMOKE request and delivery failures remain recorded pending retest.

Server RPT 00:35:10, lines 17311-17319: multi-contact combat fixture used the full
`[enemies, seenCount]` knowledge return as an enemy list. Numeric seenCount then reached
`select 2`, and the failed prerequisite expression left the recorder's `_ok` undefined.
The fixture now selects the enemy array before range checks. Production tactics and
physical completion requirements are unchanged; original failures remain recorded.

Server RPT 01:02:08: ADVANCE-AWARE terminated STALLED on bound 0. Actor 2:8960
was 53.85 m short with ATTACK and no physical progress for 25.84 s. At 01:16:46,
ADVANCE-YELLOW terminated STALLED on bound 1 with actors 2:9188 and 2:9180
55-64 m short under ATTACK. These are physical movement failures, not FSM-load
failures. The original audit's assault and clear-through transition checks passed
when no assault was observed; that vacuous condition is removed in the queued fixture.

A manoeuvre operation now leases leader attack delegation without disabling native
TARGET/AUTOTARGET/FIREWEAPON. A newer policy edit cancels without formation recall.
Consolidation admission excludes recovery and independently owned actors. These fixes
remain physically unaccepted. The combat trace now includes actor, assigned target and
attack-target identities at its existing cadence to distinguish hostile pursuit from
observer/logic contamination. An observer-target cause for the infantry detour is not
established; the observer already receives captive protection. Original failures remain.

Startup warning follow-up (2026-10-11): extracted only config.bin from the installed
base characters PBO and derapified it in ignored QA storage. CfgPatches explicitly
contains A3_Characters_F with its base dependencies. The runtime post-init patch-presence
diagnostic also reports it present. Therefore an absent local base config is not a
supported explanation, and removing the valid required addon is not a demonstrated fix.
The mission startup deleted-content warning remains unresolved and still invalidates
strict performance acceptance; inspection of installed files is not live warning clearance.


The 89812ab batch's short-screen coordinated-clean comparison failed `CLEAN-COORD-helper-view-blocked` at server RPT 02:51:03. Later prepared-assault dispatch also failed with empty roles. The occlusion failure invalidates isolation of communication-led helper behaviour; it does not identify a production coordination cause. The queued fixture retains its prerequisite and records each helper's eye positions, bounded VIEW/GEOM hits and sampled wall bounds, plus an independent requester sightline check. No reveal, target relocation or forced passing result is added. Physical geometry reassessment remains pending.

The running 89812ab coordinated case recorded CONTACT -> CALM / CONTACT_ENDED at 03:15:37, followed by empty responder roles at 03:16:07. The fixture required a SECURITY handoff but configured only the lost-contact duration, inheriting disabled Post Contact behaviour from earlier cases. The corrected fixture explicitly enables that dependency. This explains this handoff failure and subsequent reservation release; it does not establish that the remaining coordinated movement checks work. Existing failures remain recorded and the corrected case awaits packaged physical retest.
