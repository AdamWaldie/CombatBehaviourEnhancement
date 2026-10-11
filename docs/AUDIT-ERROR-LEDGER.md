# Audit error ledger

Every batch keeps its original RPT files and generated report. Repeated trace lines are not separate root causes. A fix is closed only after an exact packaged candidate completes the relevant retest without recurrence; static checks alone leave it pending.

## CQB entry investigation, 2026-10-11 evening

Addon-absent batch `runtime-20261011-214429-080` completed 50 checks with 18 failed assertions, zero SQF exceptions, zero fatal failures and one unresolved load warning. Both WAIT core and danger addons were confirmed absent, the observer was confirmed noncombatant, and the restored guide was visually verified. Native direct movement and forced replanning on the small-house comparison both visited only position 0. Retrying position 1 with all four door animation phases verified fully open still failed. This reproduces the specific fixture failure without WAIT; it does not establish that all terrain buildings or CQB behaviours are impossible. Existing-terrain batch `runtime-20261011-220008-886` on Altis completed with seven failed assertions. Eleven of twelve initial entry comparisons passed, but only three of eight sequential traversal comparisons visited every node; one open-door retry still failed. Command methods used different house instances, so this is evidence of terrain-fixture improvement, not a controlled ranking of movement commands. Placement diagnostics now record bounded model access points and their terrain clearance alongside object position and orientation. These diagnostics do not reposition houses or prove the cause of the remaining failures. A matched placement comparison and production clearance retest remain required.

Building routing must remain opportunistic during ordinary movement, preserving the current objective. A separate staged traversal order, authored entrance/exit model or scheduled assembly is not the desired implementation. Clearance and garrison still require separate physical acceptance, and incomplete room visits never count as successful tactics.

These normal batches run without headless clients. Retired partial batches retain their failed checks and are not reported as completed acceptance.

| Candidate / batch | Physical evidence | Action and remaining acceptance |
| --- | --- | --- |
| `ec810ba` / runtime-20261011-202220-419 | Fresh two-person clearance retained owner epoch/generation, enabled MOVE/PATH and advancing FSM callbacks. The leader held room index 1 as its engine destination but remained at spawn; the security partner moved outside. Zero interior visits. | This case does not support lost scheduler ownership as its primary cause. Initial room selection and native interior routing require correction. |
| `ce72971` / runtime-20261011-203438-003 | Model-order initial entry let the leader physically enter and visit position 0. The next room was assigned to its outside partner, which stalled. Visits were `[true,false,false,false]`; clearance still failed. | First-entry improvement only. Preserve this failure and test partner entry, successive rooms, all models and handback. |
| `a66d876` / runtime-20261011-204255-310 | Both members of the fresh two-person pair physically entered, but traversal stalled on later nodes. Final room visits were `[true,false,false,false]`; clearance still failed. The remaining batch is running. | Role swaps require recorded physical arrival at the lane's first interior node. The successful entrant continues while exterior security follows the previous room. Static/package checks passed; this is not accepted CQB. |

The persistent `a3_characters_f` load warning remains unresolved and is not waived. Native comparison groups run with the addon loaded; they are scheduler-excluded comparisons, not an addon-absent baseline. Complete building clearance, casualty replacement, blocked routes, locality migration and danger-to-CQB transitions remain unaccepted.

## Running batch runtime-20261011-145921-734

Candidate: clean `543880e`, fingerprint `97e8d2da340e90366c7eca32488cebecc224b68e605ffc7c97b752d10ae3b364`. Dedicated server, observer Zeus, two headless clients and 3840x2160 client mission entry are confirmed. This batch is still running; no final totals or acceptance are claimed.

| ID | Evidence | Cause and action | Retest status |
| --- | --- | --- | --- |
| E3 | Fresh two-/six-person clear terminal traces show `REPLACED`, absent shared operation, unchanged owner epoch; shared outcome records `RELEASED` | Explicit order entry cancelled the old group brain without synchronously invalidating its generation. Its delayed FSM Finished callback could release the successor CLEAR operation. Repair `94897c0` invalidates generation and removes the retired identity before replacement. | Static/package gates pass; physical corrected-candidate retest pending. |
| F3 | Closed- and open-door garrison arrival, hold and scheduler-excluded building movement fail | Door opening alone does not resolve entry. Comparison still loads WAIT's danger configuration, so it is not an addon-absent native baseline. Sparse permissions, speed, reservation and danger-state evidence added in `0a2751d`. | Pathfinding or competing control remains unresolved. |
| F4 | Fresh-clear cancellation still waited the full observation deadline; unchanged epoch passed owner continuity despite cancellation | Repair `b60e985` recognizes CANCELLED as terminal and fails continuity. Physical room visits and completion requirements remain unchanged. | Audit-only repair statically validated; live retest pending. |
| F5 | Casualty clear cancels before its entry/reserve job is established | Downstream reserve assertions fail without exercising a live clearance roster. Preserve these failures; do not infer casualty-rebalance correctness or failure from missing prerequisite work. | Requires repaired clear lifecycle and physical casualty retest. |
| E2 | Server startup repeats `a3_characters_f` warning while post-load activation reports it present | Root cause remains unresolved; retain strict load failure. | Not waived. |

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

Coordinated bound route selection now includes communicating, non-retired covering responders in its friendly-fire origin list, not only the requester. Moving elements and the candidate mover are excluded. The existing bounded responder list supplies at most six cover origins without a world scan. Distinct-lane, physical movement and live-fire acceptance remain pending; larger-scale strategy is not thereby complete.

The shared line-of-fire check excludes the mounted shooter's own platform, whose hull could otherwise count as a friendly blocker ahead of a rear gunner. Other friendly vehicles remain checked. Captive, surrendered and restrained actors now block the cone regardless of their original side. Existing query range and cadence are unchanged. Vehicle firing, suppression and combined-arms impact acceptance remain pending.

The fire-control batch adds a real captive actor positioned between a shooter and its target for the line-of-fire boundary. Captive state must block the helper; restoring hostile state must remove that protection-only block. The actor is deleted before existing live firing acceptance. This query test cannot pass the separate shot, hit or hold-fire checks and is queued for runtime execution.

Shared role rebalance now initializes a new survivor's physical progress baseline when it joins the operation roster and removes retired roster observations. It does not renew progress timestamps merely because recruitment occurred. This matches building replacement accounting and avoids losing travel between assignment and the next callback. Casualty reinforcement and stalled-element acceptance remain pending.

Standalone driving now collects only vehicles driven by the current group, so cargo groups cannot apply passenger waypoints as driver recovery. Group-scoped release checks the driving-state owner; old passenger/crew cleanup cannot remove a newer driver group's cap. New driver groups retire the prior exact lease before adoption. Subsystem shutdown retains its unrestricted local release path. Physical passenger and driver-handover acceptance remains pending.

Standalone driving recovery no longer resets its finite stages merely because the cautious reverse moved three metres. During recovery, reset requires at least three metres of net approach toward the current native waypoint as well as physical travel. This preserves the final retry and exhaustion path; it does not add waypoints, teleportation or a second controller. Obstruction and roadblock acceptance remain pending.

Standalone driving acceptance adds a separate cargo group physically aboard the existing native-route truck. Boundary calls verify that its assistance cannot adopt driver ownership and its group-scoped release cannot clear the driver cap. The cargo fixture is removed before continuing authored wait/resume checks. These checks are queued and remain separate from actual vehicle travel and obstruction acceptance.

Character dependency diagnostics now print unit-class count and the first eight classes per patch instead of an unbounded unit array. The old startup RPT line truncated before later dependency records, obscuring WAIT_danger evidence. Required addon arrays remain fully logged. The mission dependency warning remains unresolved; no valid dependency is removed or warning ignored.

Cautious reverse now rejects water, steep rear terrain and obstructed rear geometry in addition to nearby people and vehicles. At most three short geometry probes run only at the finite reverse stage; the actual movement boundary rechecks external control. Unsafe rear space records REAR_BLOCKED and proceeds through the existing bounded recovery lifecycle. Walls, terrain and player-roadblock acceptance remain pending.

General Driving adds live maximum safety speed (15-120 km/h, default 70) and physical recovery enable (default true) controls on its existing page. Terrain caps take the lower value and authored lower forced speed remains preserved. Recovery disable prevents new attempts; it does not cancel an already issued native leg. Convoy controls remain independent. Live CBA, persistence and physical acceptance remain pending.

The standalone driving batch edits the live maximum speed through CortexTuning/CBA to 15 km/h, waits for the owner's actual forced-speed cap and records unchanged authored waypoint identity/position. It restores the previous value before continuing wait/resume acceptance. This case remains queued; CBA persistence, JIP and all terrain profiles are separately unaccepted.

Coordinated assault exposes a next-operation concurrent mover cap (one to four squads, default two). Each assault captures it once; later CBA edits cannot reshuffle active roles. Existing distinct-corridor, communication, strength and fire-lane gates still decide whether a slot is viable. This removes a fixed two-element policy limit but does not prove larger-scale combined-arms strategy or performance acceptance.

Standalone driving uses a maximum 10 km/h cap during reverse preparation/observation stages instead of inheriting the normal road cap. Lower authored forced-speed limits remain preserved. Native controls still perform the movement; this does not establish actual reverse gear or correct tracked withdrawal. Physical recovery speed and terrain acceptance remain pending.

Medical feature closure and Zeus/specialist interruption now retire an active aid record through the existing generation-aware cancellation path instead of returning before cleanup. Null or non-local groups remain untouched. This prevents an old medical reservation lingering after disablement; physical treatment and interruption acceptance remain pending.

Medical selection and approach progress use three-dimensional actor distance. Native HealSoldier is requested only within four metres and a 1.5 metre vertical band; an upstairs casualty otherwise remains an approach target under the existing finite no-progress/timeout rules. No treatment success is fabricated. Multi-floor treatment and real health-change acceptance remain pending.

The reactions suite now contains actual medical cases rather than only a registry association: a loaded native medic approaches a wounded squadmate and must improve health through production treatment, then settle naturally. A second, longer approach disables the feature after the real aid record appears and checks release without fabricated healing. No direct medical controller invocation or completion assignment is used. These cases remain queued; specialist, multi-floor and HC medical variants remain incomplete.

The coordinated administrative hand-back stage now closes independent direct assault as well as its support gates; Flank and Advance were already disabled in that fixture. The preceding coordinated attack retains its original controls. This removes a possible new-operation confound from attack-policy and ordinary-order restoration checks, and restores the direct-assault gate after actor cleanup. It does not prove that the historical restoration, travel or backtracking failures were fixture faults. Those findings remain open until the clean packaged rerun records owner/generation and restoration evidence.

Grenade direction evidence from completed runtime-20261011-045348-544 (candidate ecdff24): server RPT lines 862, 884 and 1101 contain three real FRAG FiredMan projectile-velocity traces. Requested-direction errors are 0.316, 2.078 and 0.582 degrees; known-contact errors are 0.644, 2.772 and 0.523 degrees. These three server-owned flat-range releases do not show the reported 180-degree fault. They establish neither smoke direction nor stance, slope, headless, safety or damage acceptance, and do not validate later packaged changes. No grenade physics rewrite is justified by these observations alone; retain the broader finding for the next exact-candidate batch.

Running candidate 543880e aircraft evidence: PLANE-STRAFE ended NO_KNOWN_TARGET with no physical plan or shots (server RPT 16:38:00). Weapon preflight passed, but that does not prove a known-target attack was admitted. Discovery now filters assigned and bounded nearby candidates by positive group knowledge before acquiring a flight lease; fallback seat selection applies the same rule. Explicit unknown-target requests remain rejected. This prevents stale contacts from blocking later viable candidates, but the current failure cause and all weapon/geometry outcomes still require physical retest. Separately, AIR-CORTEX guided-threat defence released real countermeasures, departed 120 metres and survived with zero damage at 16:29:16; this single case does not establish overall air defence acceptance.

CQB entry-selection repair: initial pair assignment previously skipped entrance staging within eight metres, while actual doorway arrival used three metres and a 1.5-metre floor band. The initial test now uses those same physical bounds. Nearby actors outside a wall or on another floor retain their real entrance leg before targeting the first interior node. This changes neither room completion nor unreachable criteria and does not establish that the historical path failures are solved. Static/package validation passed; fresh physical clearance, casualty and interruption evidence remains required.

Stopped batch runtime-20261011-145921-734: 823 recorded checks, 266 failed assertions, zero SQF error lines, zero fatal runtime failures and one unresolved addon load warning. User requested shutdown before server/client completion; all four recorded PIDs were terminated and verified absent. Air interception selected an actual HeadlessClient_F (WAIT_HC1) as a ground STANDOFF objective. Discovery, fallback seat selection and the planner now reject headless entities without excluding ordinary players. The historical intercept remains failed; detection of the intended aircraft, air-to-air selection and physical engagement require a fresh authorized batch. No game runs are permitted until user authorization.

Finite scheduler rejection: queued brains rejected for disabled state or stale locality/owner epoch now receive terminal cancellation, completed=true and pending=false. Queue admission applies the same terminal signal when it rejects an obsolete group owner. This prevents FSM watchdogs retrying discarded work. Only the rejected state is changed; restoration remains in generation/identity-guarded FSM cleanup. Legacy callbacks without finite-brain pending/completed fields keep their prior discard behaviour. Full static/package checks passed; physical migration, disable and replacement acceptance remains pending while audits are held.

Convoy missing-trail recovery no longer sends native followers back to the group leader. It retains their committed destination, or issues one initial hold through the effective movement operator until a forward predecessor trail exists. A successful native path commitment clears that hold marker. This changes the missing-trail fallback only; startup/restart admission, spacing, commander routing and physical column behaviour still require the queued batch. Full static/package validation passed. No game audit was launched.

Convoy startup now establishes the native follower's one-time hold rather than following the group leader before a predecessor trail exists. The hold marker is reset on revision setup and cleared by a real native path commitment, preventing a retained marker from hiding re-acquisition after halt/resume. Trail/cursor preservation is unchanged. Full static/package validation passed; mixed tracked/wheeled startup, stop/resume and physical spacing remain unaccepted. Cross-owner route-history preservation remains a separate unresolved requirement.

Convoy live-edit continuity: speed/spacing revisions on an unchanged moving column now retain predecessor destinations, path ownership, hold markers and speed-control history. Startup, a changed column, explicit halt/resume or ownership suspension still require reacquisition. HALT records that requirement before retiring its common operation. This removes the unconditional follower stop/path reset caused by ordinary revisions without changing spacing safety caps. Full static/package checks passed; live-edit motion, restart and new-order physical acceptance remain pending.

Standalone driving now yields to an authored forceSpeed 0 hold before terrain sampling, cap application or route recovery. It preserves the stop rather than replacing it with a positive cap. An additive physical audit holds a simulation-enabled truck at a real MOVE waypoint for eighteen seconds, requires an adopted WAIT group with zero motion and no driving lease, then releases the hold and retains the existing native-travel acceptance. The case is queued, not physically passed. All 590 repository tests and package checks passed; game audits remain held.

Standalone recovery is now scoped to authored waypoint identity (index, type, position, completion radius and behaviour). A changed route resets progress time, reverse/retry stage and exhaustion before cap/recovery selection, including same-index replacement; unchanged routes retain their bounded recovery budget. Resetting does not issue a movement command. Existing replacement, HOLD and physical-travel cases remain queued while audits are held. All 590 tests and package checks passed; no physical acceptance is claimed.

Convoy obstruction recovery now preserves one movement controller: native vehicles retry through the effective movement operator; steering vehicles invalidate one path commitment while retaining steering ownership. Steering refresh is eligible immediately rather than after the old ten-second idle window. Recovery updates its existing follower record instead of clearing destination and hold fields. Navigation targets remain behind the predecessor; physical spacing is enforced by the existing speed controller rather than incorrectly rejecting useful endpoints inside the gap band. Retry count, obstruction classification and final halt remain finite. All 590 tests and package validation passed; actual obstruction recovery and mixed-column motion remain unaccepted while audits are held.

Convoy release now checks vehicle-level external ownership and retained-vehicle membership before recalling a driver to group formation. Speed and unload restoration already respected those external markers; the final recall did not. An obsolete release therefore cannot divert a vehicle retained by the successor convoy or owned externally while group ownership remains unchanged. Existing group/player/Zeus/crew checks remain. All 590 tests and package validation passed; physical retained-route and external-owner handover acceptance remains pending while audits are held.

Danger-contact classification now rejects HeadlessClient_F identities through event setup/intake, retained contact requests, engine mode selection, close-threat recycling and group contact publication. The aircraft audit demonstrated the broader non-combat entity risk; infantry danger paths lacked the same exclusion. Ordinary players remain eligible hostile contacts, and valid hazard observations still permit finite assessment/cover without turning an HC into an engagement objective. All 590 tests and package validation passed. Physical danger/HC acceptance remains pending; this is core target validity, not completion of external-controller compatibility.

Convoy threat reporting now validates the live contact side rather than the side cached by nearTargets. Logic objects, headless entities and captive/surrendered/handcuffed actors cannot trigger its contact response. Existing knowledge, recent-observation and sixteen-candidate bounds remain. This prevents stale mission-side changes or non-combat targets from authorizing a new convoy drill without adding scans. All 590 tests and package validation passed; physical contact, side-change and cleanup cases remain pending while game audits are held.

Convoy recovery validates its destination against retained predecessor trail points rather than the predecessor's current heading. A bend can place a valid trailing route point ahead of that new heading; the old test rejected it. The bounded check requires a three-dimensional recorded point and runs only on the existing stalled-actor recovery cadence. Spacing control and retry limits remain unchanged. All 590 tests and package validation passed; physical curved-road and obstruction recovery remain pending while audits are held.

Aircraft attack jobs now bind to their original pilot group. Repeated admission cannot rewrite that binding; pilot reassignment retires the run as PILOT_GROUP_CHANGED. Common-operation cleanup and owned-waypoint removal use the original group, avoiding generation-number collisions with a new pilot group. Flight/target restoration additionally requires the retained flight lease and matching group; newer flight controllers retain their target. Native command checks require local group ownership and the same pilot-group binding. All 590 tests and package validation passed. Group reassignment, matching-generation isolation, migration and Zeus physical handover remain pending while audits are held.

Live normal convoy batch runtime-20261011-175607-317, candidate e6b3f1d: WHEELED-15 now has matching group/brain epoch 1 and recurring physical callbacks; all followers move. The sixty-second window still failed speed and progress (averages 6.60223/6.61132/6.5763 km/h), spacing and stop fraction. Source inspection found actual-follower-speed pacing activated at only 1.2 times target gap, feeding transient follower acceleration into lead speed. That pacing now requires a substantially stretched two-times gap; ordinary closure retains cruise-based reserve. This repair passed 590 tests and package validation but is not in the running candidate and has no physical proof yet. Original failures and acceptance thresholds remain unchanged.


Live candidate e6b3f1d physical subcases: WHEELED-30 and WHEELED-50 each passed all fourteen recorded matrix checks. Average speeds were 28.9209/29.189/29.4464 and 29.0804/29.2803/29.6558 km/h respectively. Both follower gaps stayed in band for all sixty samples; no stopped samples or restarts were recorded. Both halt/resume and no-turnaround checks passed, with crew retained and fixtures cleaned. This evidence is limited to straight flat VR geometry, server ownership, three wheeled vehicles and a 30 km/h request. Tight spacing, tracked/mixed vehicles, speed variants, corners, terrain, casualties, HC migration and the performance budget remain unaccepted. The batch is incomplete and its addon load warning remains open.


The native VR diagnostic now compares identical small houses at three placement heights (0, 0.3 and 0.6 metres) using direct movement and replanning, with doors consistently open. It requires physical arrival at both initial nodes and preserves earlier failures. This is queued evidence gathering, not a production height adjustment or accepted CQB repair.

Access logging in `runtime-20261011-221633-668` confirms negative terrain clearance for several spawned-model exit nodes. Garrison recovery previously accepted those nodes unconditionally; it now rejects nodes buried more than the 0.05 metre numerical tolerance. Clearance uses the same tolerance instead of allowing 0.25 metres below terrain. Both retain original coordinates and native interior planning; neither lifts structures nor invents an entrance. Physical regression acceptance remains pending.

The evidence reporter also retained a VR-only mission directory when validating staged script hashes. Altis evidence therefore received a false provenance failure. The reporter now resolves the supported world from the manifest, rejects missing/unsupported paths, and retains VR fallback for older manifests. This correction does not remove any physical assertion or load-warning failure.

Controlled native batch `runtime-20261011-221633-668` completed 62 checks with 20 failed assertions, zero SQF exceptions, zero fatal failures and one load warning. The identical small-house height comparison failed both first-node and second-node visits at height 0 under both commands; both nodes were physically reached at heights 0.3 and 0.6 under both commands. This supports placement height as a cause for that specific spawned fixture. It does not establish full clearance, other-model success or a safe automatic repositioning policy for editor/curator buildings. Production recovery guards were committed later and were not exercised by this addon-absent batch.

Fresh production clearance fixtures now validate model access clearance before actors spawn. A small lift is derived only when the highest access node is buried by at most 0.35 metres, targeting 0.15 metre clearance in 0.05 metre increments. This changes new audit houses only and logs the original clearance and applied lift. Original native ground-level failures remain. The upcoming production batch must prove interior visits, operation results and handover; placement validation alone cannot pass clearance.

The first production restart `runtime-20261011-223048-589` was stopped after discovering pre-commit dirty package metadata. Its results are not acceptance evidence. Shutdown verified no matching processes remained. Replacement `runtime-20261011-223215-032` uses clean commit `0f1428d47c1a6118d5a2451d7e12925b28d77940` and fingerprint `be6a03614cbc41d3d08e974b019f3448a15958609479c08a5376f3e6eb411cbb`. The launcher now rejects dirty or missing committed identities before starting any game process; stage-only inspection remains available.

The same bounded placement validation is now queued for newly spawned casualty, door-interruption and natural-contact fixtures. Previously those dependent cases still used buried-access houses even after the scale fixtures were corrected. Native controls and controlled-height fixtures remain unchanged. The current running batch contains the earlier fixture version and will not be silently relabelled as testing this later change.

Live partial evidence from clean WAIT batch `runtime-20261011-223215-032`: the two-person fresh small-house case completed at 22:40:07 with all four independent room visits, both actors progressing through successive interior positions, matching local/shared COMPLETE results, restored attack delegation and bounded egress. Ordinary waypoint handover physically passed at 22:40:26. The six-person larger-house case is now running. This is one successful clearance fixture, not broad CQB, terrain, combat, migration or performance acceptance; the original native controls still fail.

The six-person fresh larger-house case in `runtime-20261011-223215-032` physically visited all nine interior nodes and all three assigned exits, yet reported INCOMPLETE with 9/9 rooms because exit eligibility required simultaneous proximity. Native formation carried an already exited partner away before other actors finished descending. Exit arrival is now latched only after the existing physical distance/floor-band checks within the matching generation. Exited actors are not sent back; missing/unavailable actors and unvisited exits still fail. This repair is queued for the next candidate and is not loaded in the running batch.

The twelve-person fresh case in `runtime-20261011-223215-032` visited five of six covered interior objectives before its observation deadline; it remained RUNNING with live callbacks and stable ownership. This is unresolved route/recovery progression, not a scheduler shutdown. The native controlled-height matrix is expanded to three models and all bounded model nodes, retaining failed nodes when a diagnostic timeout advances. Its results are pending and cannot establish WAIT tactical acceptance.
