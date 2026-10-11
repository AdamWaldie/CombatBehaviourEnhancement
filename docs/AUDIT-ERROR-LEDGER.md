# Audit error ledger

Every batch keeps its original RPT files and generated report. Repeated trace lines are not separate root causes. A fix is closed only after an exact packaged candidate completes the relevant retest without recurrence; static checks alone leave it pending.

## Batch runtime-20261010-214346-432

Candidate: clean `89812ab`. Completed with 2,375 checks, 462 failed checks, 4,231 SQF trace lines, no fatal runtime failures and one load warning. Its applications were closed with user approval.

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

HC coordination follow-up: at 03:42:17 and 03:42:26 both complete helper rosters were owned by clients 4 and 5 with installed shot samplers. Helper view isolation and requester natural contact passed. At 03:44:34 both helpers already had empty leases and statuses; CONTACT_ENDED followed at 03:45:13. This shows absence of initial reservation, not merely later loss during post-contact. The fixture set the requester to BLUE until after its expected handshake, while production intentionally gates autonomous support requests under BLUE/GREEN. The corrected requester uses YELLOW before contact; helpers retain their initial BLUE posture. Production hold-fire authority is unchanged. All original failures remain; corrected discovery, dispatch and travel require physical retest.

Corrected coordination batch runtime-20261011-035918-630, clean b3a9f70: at 67 checks it recorded ten failures, zero SQF error lines and the existing load warning. Natural contact, support admission and owner position objectives now pass; MOVE roles and actual travel/fire are observed. This is partial coordination, not successful assault. Both multi-flank squads fail physical travel/cohesion; coordinated movement records 15.55 m reverse travel, native attack overrides, RED-mode violations and actors still outside the 50 m objective radius. Later disable/release passes are cleanup evidence only. Replacement tokens report NOT_READY while old drills remain at PAUSE/MOVE. Source inspection established coordinated drills omitted generation/epoch required by cleanup; c46ee45 binds them to the parent operation while preserving that parent's lifetime. 469600d adds an exact-owned RED-to-YELLOW mover lease, and 94f0ae5 retires outgoing support bounds synchronously. Those later repairs are not loaded in this batch and remain physically unaccepted. User screenshot confirms the visible assault was disordered before the hand-back stage; original failed assertions remain unchanged.

## Final coordination batch runtime-20261011-035918-630

Clean candidate `b3a9f70` completed both client and server observations: 453 recorded checks,
30 failed checks, zero matched SQF error lines, zero fatal runtime failures and one load warning.
The running applications were left untouched. Four physical failures have been reviewed;
26 failed cases remain unresolved. Passing settings checks do not establish tactical acceptance.

Movement, pursuit overrides, backtracking and post-operation order following remain failures.
Generation binding, child retirement and mover fire posture repairs committed after this candidate
were not loaded in this batch and still require exact-package retesting. The retained dependency
warning remains unresolved.

Separate-contact admission follow-up: an owner-local tactical drill must be compared with the
server-reported enemy position, not the offset approach destination. Discovery and assault dispatch
now publish a reservation-token-bound contact receipt before delivering the lease. A receipt for
another token cannot authorize replacing a live drill. Pending discovery still acquires no movement.

Queued physical cases: same enemy with an approach offset beyond 75 m must remain admissible;
a live drill against another contact beyond the 75 m contact area must continue without cancellation;
an old-token receipt must not authorize replacement; repeat these cases across server and HC owners,
then issue a Zeus replacement order. Record actual travel, drill generation and cancellation reason.
These cases are pending, not accepted.
FSM follow-up: tacticalDrill now retires immediately when its active drill token is replaced, before watchdog requeue. It cancels only its old queued job and does not interrupt or restore the replacement drill. Physical replacement and HC cases remain pending.

## Completed coordination batch runtime-20261011-045348-544

Candidate: clean ecdff24. Completed: 456 checks, 32 failed checks, no matched SQF errors or fatal failures,
one unresolved load warning; both client and server completion markers are present.

Four failures have explicit physical reviews in the runtime's manual-behaviour-assessments.json:
unequal squad-2 flank travel (0.15 to 139 m), 58.824 m standard-case reverse travel,
37.81 m contact-during-preparation reverse travel, and both standard-case groups retaining
attackEnabled=false after support shutdown. The review does not alter raw assertions or identify
an unproven root cause. Other failed checks remain unresolved pending review.

The HC movement stage has recorded RECOVERY_FAILED and STALLED outcomes. Object-not-found
network messages remain observations; their cause and relation to unavailable actors are unproven.
Tactical/danger stance, service-task, FSM supersession and restoration-evidence changes made
since ecdff24 are not loaded in this batch and require a subsequent exact-package retest.
HC diagnostic fixture repair: runCoordinated previously applied allowDamage=false only on
spawn. That engine permission does not survive locality transfer, so the stated invulnerable
fixture was not guaranteed on an HC. The owner-local sampler now reinstalls diagnostic protection
and publishes an owner/local-damage receipt. Each migration asserts living actors and that receipt.
This repair is restricted to the instrumented fixture; production and damage-enabled battles are
unchanged. Existing HC failures remain recorded and require a fresh valid-fixture run; the defect
does not prove the cause of every death, stalled actor or network message.
Scheduler root-cause candidates awaiting runtime verification: queue admission previously stamped
current epochs onto supplied stale work; keyed coalescing could mutate an old owner's state; and
its nested exitWith returned from the search block rather than the function, then appended another
callback. The code paths are corrected. No completed physical failure is closed on that basis.
The added SCHED-keyed and SCHED-stale/current-epoch cases run with coordination in future packages.
A clean paired retest and the matched 50-group performance arms must establish actual effect.
### Coordination movement evidence refinement

The completed ecdff24 coordination batch records bound retries with currentCommand ATTACK and expectedDestination LEADER PLANNED differing from the committed bound (server RPT lines 1155-1160). Later HC retries retain MOVE and the exact committed destination (lines 1336-1338) while physical progress remains insufficient. Treat competing native destinations and retained-route stalls as separate investigation paths. This evidence does not establish that the recent scheduler or FSM guards resolve either outcome. Preserve all original backtracking, idle and physical-travel failures for the next packaged batch.

The next candidate records at most sixteen initial bound handoffs per drill in WAIT_Cortex_DrillMovementHandoffs, with operation generation/token, actor, bound, pre-command, previous expected destination, committed destination and attack-delegation state. This is diagnostic evidence, not a movement fix or acceptance result. It preserves native aiming and introduces no additional scan or worker.

The scheduler batch also includes a detached support-FSM retirement case on an empty isolated group. It checks that the real packaged FSM preserves the registered support brain and a reservation sentinel. This is an authority/cleanup boundary check, not proof of physical support coordination or a valid combat reservation; runtime execution is pending.

### Building pair handoff after physical visits

Room visits are recorded before pair-route progression. The old cursor loop skipped cleared rooms before applying the entered flag, previous interior support position or mover rotation; the later cleared-room branch was bypassed in normal progression. The cursor loop now applies those handoff updates for physically cleared rooms before advancing. Unreachable rooms do not establish entry or rotate the pair. Existing physical entry and room-visit audits remain required; this production correction is not yet accepted in game.

The fresh two-person building audit retains both-participate and successive-position checks, and adds both-progress-through-interior when the fixture offers at least four interior positions. Both actors must physically visit at least two sampled positions. Role flags and doorway arrival cannot satisfy it. The new case is queued, not passed.

The building handoff additionally requires a member of the retiring pair to be physically within the completed interior position radius and floor band. Shared completion by another lane advances the cursor only; it cannot establish this pair's entry, previous interior support position or mover rotation. This refinement preserves multi-pair physical evidence and remains queued for acceptance.

### Assigned mover entrance staging

Entrance approach formerly ended when either pair member was within three metres of the entry. The security partner deliberately holds at that distance outside, so its arrival could prematurely send a distant mover directly to the interior. Staging now requires the assigned mover within the entry radius and floor band. Doorway arrival still does not establish interior entry or complete a room. Physical retest remains pending.

Artillery smoke request acceptance now includes a bounded prerequisite snapshot: transmitter, requester/battery eligibility, effective gates, battery role, pause state, crew locality/ROE, selected magazine, range and reservation after dispatch. A reservation after successful dispatch is expected, not evidence of a pre-existing conflict. This diagnostic cannot pass delivery or close the historical request failure; the updated fixture remains queued.

Fixed forward helicopter stations now retain a target-crossing STRAFE/OFFSET/HOOK delivery leg rather than a lateral endpoint. OFFSET/HOOK change the approach bearing; their exits remain distinct. Turret-mounted attacks retain their separate geometry. Pilot-fixed legs do not use the off-axis rotorcraft ingress shortcut. This corrects planned geometry only; actual aiming, shots, impacts and safe exits require packaged acceptance.

The fixed-wing geometry audit previously required the target to lie inside every delivery segment, including STANDOFF. That contradicts the inbound stand-off endpoint. Direct runs retain the target-crossing assertion; STANDOFF now requires a forward target beyond the delivery endpoint. Cross-track, length, altitude and angle checks remain. Physical release, damage and target destruction are unchanged and still required. Historical results are preserved; the corrected geometry check is queued.

The aircraft batch adds armed helicopter OFFSET and HOOK rocket fixtures with pilot-fixed station prerequisites, target-crossing delivery geometry and the existing real-shot, impact and destruction requirements. Fixed-wing envelope limits remain unchanged; helicopter geometry uses its own lower altitude and shorter run envelope. These cases are queued and do not establish successful native weapon delivery.

Explicit artillery batteries now receive loaded-magazine target-range validation before mission token or busy reservation, matching automatic battery selection. Later safe-aim and firing checks remain. The smoke batch adds out-of-range rejection and unchanged-reservation checks before its valid delivery request. This admission fix does not close the historical smoke-delivery failure.

Fragmentation release retains the existing 8-40 metre range and protected-actor blast-radius rules. Their check now precedes trace-handler installation and records UNSAFE_RELEASE at callback scope, so a refused throw cannot leave a newly armed trace handler behind. The former later check is removed; no duplicate scan, projectile steering or group hold is added. Physical throw and cancellation acceptance remain pending.

Native danger handover now updates the shared scheduler deadline alongside the existing group-brain wake/next timestamps. A pending decision could otherwise remain behind the idle cache until its old due time. Normal danger observations already update that cache. This adds no worker or scan; prompt handover acceptance remains pending.
