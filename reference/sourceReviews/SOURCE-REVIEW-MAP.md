# Source review and functionality map

Select useful AI functionality, merge complementary methods into existing CBE owners, fix defects and improve gameplay quality, balance and cost. Rejecting an unsafe source method does not complete its required capability.

48 recoverable Workshop references plus WMP as a separate local integration reference. The historical master ledger is absent. Completeness against lost history is unknown. All top-level Workshop intake/review IDs currently found are covered.

This maps the review queue and intended contributions. It does not reassess all source implementations, renew percentages, claim whole-mod parity or grant physical acceptance. Candidate contributions are evaluation objectives, not findings that the source implements them.

## Review order

1. Finish LAMBS danger/FSM and HBQ driving foundations.
2. Build Protocol functionality upward through individual actors, pairs, squads and combined arms.
3. Merge complementary methods from the other AI references where they improve those behaviours.
4. Keep optional stealth, compatibility-only sources and the later extension in their recorded scope.

For each selected capability, trace its complete execution and writers, record the source disposition, name its CBE owner, then implement the required intent. An unsafe source method needs a replacement when the capability remains required. Physical behaviour and performance stay separate from build-out.

The tables list evaluation objectives. They do not assert that every named mechanism is present in the source. Existing implementation records are retained in [the machine-readable map](source-review-map.json). This queue review does not renew their evidence or percentages.

## foundations

| Reference | Functionality to select or improve | Review position | Next source work |
| --- | --- | --- | --- |
| LAMBS Danger.fsm 2.6.2 (1858075458) | Standalone danger FSM, reactions, assault and task lifecycle | All41 readable danger-addon SQF bodies and civilian FSM runtime branches reviewed; selected main helpers reviewed; whole-source descendants remain incomplete | Reconcile remaining main/wp helpers and concrete capabilities. Civilian exterior/indoor refuge selection, migration observation and idle roofed gunfire retention are implemented, physically unverified; Own-group witnessed-death cues now reuse the finite civilian refuge owner (at most16 roster members, forward unobstructed view within45m); this is a scripted approximation. A bounded nearby own-group injury cue now reuses the existing refuge owner (10s/16members/2probes/30m); this is an injury approximation, not native scream detection. Native body/scream, cross-group cues, later discovery/inspection and broader civilian functionality remain incomplete. Physical behaviour and cost are unverified. Contact and three main communication descendants are now reconciled in [contactCommunicationReview20261028](../../releaseVerificationAndDeployment/referenceReviews/lambs-danger-branch-execution-20261025.json); review only, with range/equipment/API and physical effectiveness gaps retained. Settings modules are not a parity target. |
| HBQ Advanced Driving AI (3812620045) | Driving, traffic, recovery, convoy and crew policy | All28 indexed auxiliary bodies/declarations reviewed; major main-controller branch reviews extended; end-to-end reconciliation incomplete | Reconcile reviewed decisions, issued native work, detached callbacks and cleanup with CBE capability dispositions. Current navigation, obstacle/grinding/watchdog and startup/crew/cadence evidence is in the HBQ intent review; no physical parity inferred. [Travel-direction correction](../../releaseVerificationAndDeployment/referenceReviews/hbq-road-travel-direction-20261028.json): road/terrain anticipation follows observed backing; cadence/bounds retained. [Traffic hull categories](../../releaseVerificationAndDeployment/referenceReviews/hbq-traffic-vehicle-categories-20261028.json): Air/Ship hulls and wrecks enter existing forward/rear and independent pass-corridor observers; limits unchanged. Precision/physical parity remain open. |

## protocol programme

| Reference | Functionality to select or improve | Review position | Next source work |
| --- | --- | --- | --- |
| PROTOCOL AI CQB (3799391254) | Dynamic building entry, clearing and exterior isolation | Readable scripts reviewed; integration/scope gaps remain | Reconcile complete selected execution with CBE entry/pair/reserve/isolation/egress owners; finish named flow and handover gaps. |
| PROTOCOL AI AIRBORNE (3800081309) | Airborne insertion and ground transition | Readable scripts reviewed; integration/scope gaps remain | Complete remaining source/dependency review; reconcile passengers, automatic landed squad and flight crew task preservation. |
| PROTOCOL AI ARTILLERY: RELOCATE & COUNTER-BATTERY (3801354927) | Battery positioning, fire response and counter-battery | Readable scripts reviewed; integration/scope gaps remain | Complete source-to-selected-crew execution mapping; preserve mixed-group membership and unrelated infantry orders. |
| PROTOCOL AI PAIRS (3802121807) | Buddy roles, bounds and casualty replacement | Readable scripts reviewed; integration/scope gaps remain | Reconcile source roles and arrival-driven transitions with current pair allocation and finite advance FSM. |
| PROTOCOL AI CITY TACTICS (3803702313) | Urban movement, cover and smoke | Readable scripts reviewed; integration/scope gaps remain | Reconcile source urban decisions with dynamic routing and one squad/CQB task owner. |
| PROTOCOL AI ANTI-AIR: RELOCATE AND ANTI-MISSILE (3809708209) | AA relocation, warning allocation and point defence | Readable scripts reviewed; integration/scope gaps remain | Complete station/weapon/projectile applicability and interruption review; distinguish existing experimental subset from remaining capability. Shared dedicated role now also accepts strict native air-dominant threat profiles, with existing weapon/task gates retained; generic custom-air gunnery was already implemented. Native Cheetah/Tigris mixed profiles require the category fallback; custom-category mixed clones now have a live per-platform CBE role declaration with active owner-boundary checks (12 selected static chains checked; no physical acceptance). Physical balance/cost remain open. |
| PROTOCOL AI NAVY SEAL (3813369033) | Boat/shore insertion and ground transition | Readable scripts reviewed; integration/scope gaps remain | Complete relevant source handover review across crew/cargo/landing and existing ground squad execution. |
| PROTOCOL AI RAPPELING (3819636004) | AI rappel task and aircraft/passenger handover | Readable scripts reviewed; integration/scope gaps remain | Resolve real finite Advanced Rappelling provider contract and dependencies; detection alone does not implement rappelling. |
| PROTOCOL AI ARMORED FORCE (3822504009) | Armour protection, engagement and repositioning | Readable scripts reviewed; integration/scope gaps remain | Resolve broader/scripted/burst/multistation ATGM and relocation beyond selected native missile observation/standoff/post-shot paths; physical guidance, crew and cost unverified. |

## complementary ai methods

| Reference | Functionality to select or improve | Review position | Next source work |
| --- | --- | --- | --- |
| LAMBS Suppression (1808238502) | Suppression and aim recovery balance | Selected scope reviewed; remaining scope needs disposition | Reconcile the complete native policy with danger, firing and mission skill ownership; retain optional scope. |
| LAMBS RPG (1858070328) | Launcher target selection and firing policy | Selected scope reviewed; remaining scope needs disposition | Trace all relevant launcher decisions and ammunition tradeoffs beyond the selected vanilla config subset. |
| LAMBS Turrets (1862208264) | Turret firing, dispersion and ammunition economy | Selected scope reviewed; remaining scope needs disposition | Compare relevant firing branches and termination with native firing; retain interruption and friendly safety. |
| isky's A.I Skill Tweaks (2905259701) | AI parameter policy that coexists with mission skills | Selected scope reviewed; remaining scope needs disposition | Decoded config was read; reconcile effective engine declarations and selective CBE policy without repeated skill overrides. |
| FPV AI Drones (3380337397) | AI FPV decisions and safe drone allocation | Source review pending | Read AI flight/target/payload/ownership paths and reuse restrictions; distinguish native decisions from scripted physics. |
| AI Helicopter Decelerate No Climbing (3496308284) | Helicopter deceleration without unwanted climbing | Installed1.0.5.0 readable bodies recovered; selected finite CBE owner reconciled and full authored-order guard implemented offline | Physical flight/order-edit/locality and full-receipt cost remain unverified. See helicopter-deceleration-source-20261026.json; no whole-source/compiled parity inferred. |
| Simple Civilian Behaviour (3529745801) | Civilian reactions and task continuity | Complete AI script and entry/action callbacks reviewed; native pass-by trigger integrated into existing finite CBE response offline | Shelter/body awareness, vehicle escape and operator tasks remain open. Event delivery, escape quality/locality/cost need physical evidence. See simple-civilian-source-20261026.json. |
| Pinned Down Combat Suppression (3559900745) | Combat suppression response | Core10AI SQF bodies and6-state/8-link FSM reviewed; selected settings/config; wider source incomplete | [Lifecycle dispositions](../../releaseVerificationAndDeployment/referenceReviews/pinned-suppression-source-20261027.json) include startup-owner, stale skill and native-fire limits. Remaining capability/physical evidence stays open. |
| Pinned Down Surrender (3579551673) | Surrender and capture behaviour | Verified extracted source available; deep review unreconciled | Use the verified extracted snapshot to trace triggers, weapons/captive state, interruption and repeat restoration. |
| AI Zeus - Autonomous Battlefield Commander (3623550024) | Battlefield decisions and force allocation | Selected scope reviewed; remaining scope needs disposition | Read deterministic decision/execution/cancellation paths and relevant behaviour modules; assess provider/LLM paths separately. |
| SCAI Artillery Support (3679457651) | Artillery observation and support response | Unreconciled; older evidence pointer missing | Recover provenance; compare spotting, fire allocation, deconfliction and finite battery ownership with Protocol artillery. |
| Smart Aircraft AI (3682445063) | Aircraft decisions and support behaviour | Installed 2.6.0 core readable source reconciled; attack-readiness veto offline verified | Recovery destination/service and native handback remain open; Antistasi deferred. See `releaseVerificationAndDeployment/referenceReviews/smart-aircraft-source-20261027.json`. |
| Realistic Civilians (3690291228) | Civilian routine and reactions | Unreconciled; older evidence pointer missing | Recover provenance; compare useful civilian methods with Simple Civilian Behaviour and existing CBE danger. |
| Pinned Down Medical Solution (3709853140) | Squad medical assistance | Verified extracted source available; deep review unreconciled | Use the verified extracted snapshot to trace aid allocation, casualty approach and ACE/native medical task ownership. |
| Smart Merge AI (3721618614) | Survivor regroup and group merging | All36 readable bodies/config/settings reviewed; selected cohort/live-host/task-policy fixes implemented | Readable source dispositions complete; physical joining/task/cohort/repeat/locality and measured cost pending. |
| DiGii reference (identity needs reconciliation) (3742481604) | AI contribution to identify | Unreconciled; older evidence pointer missing | Resolve actual mod identity and readable AI scope before selecting any mechanism. |
| AI Culler: Optimized Warfare (3744994173) | AI processing cost and simulation policy | Unreconciled; older evidence pointer missing | Recover provenance; inspect what is culled and its effects on contact, objectives, locality and simulation-dependent tasks. |
| Pinned Down Steel Rain (3763118318) | Artillery behaviour to compare | Verified extracted source available; deep review unreconciled | Use the verified extracted snapshot to identify actual artillery methods and combine useful intent with the single CBE support lifecycle. |
| BHL AI (3771745732) | Helicopter approach, braking, terrain clearance and landing handover | Both readable controller bodies reviewed; finite lifetimes and full landing-node write/cleanup guards implemented | Physical flight/hold/onward/repeat/locality, dynamic obstacle coverage and cost evidence pending. |
| Pinned Down Cover and Concealment (3775025723) | Cover selection and concealment use | Selected eligibility/FSM/caller review; whole-source reconciliation open | Finish position selection, reachability, threat-facing and defence against existing movement/posture owners. See the machine-readable map for review evidence. |
| Pinned Down Tracks and Boots (3776232873) | Infantry and vehicle cooperation | Selected positioning and registration/support/release command graph traced; whole-source/physical handback open | [Selected integration](../../releaseVerificationAndDeployment/referenceReviews/pinned-tracks-boots-source-20261027.json): passenger custody, failed search caching and up to three finite original-cargo troop-body support legs through the existing selected-crew FSM, with actual prior worker/native handback and local consent or authenticated cross-host passenger acknowledgement/withdrawal. Actual native boarding retires old cargo identity; leases and boarding-batch deadlines stay finite. Physical repeat/cross-host cooperation and sustained escort remain open. Existing fire-lane anchor preserved; no forced seat/group/route replay. |
| Scorpion's Advanced AI (3778948165) | General AI methods to compare | Unreconciled; older evidence pointer missing | Recover provenance; inventory relevant sensing, reaction and task execution methods; identify unique contributions. |
| Pinned Down Combat Awareness (3785056303) | Combat awareness and information sharing | All14 recovered readable files reviewed; selected sound-mode intent integrated/offline verified | Existing local hearing now resolves selected attachment/muzzle/mode sound metadata. Global scans, permanent identity accumulation and sound-based object reveal are rejected. Wider anonymous sensing, custom/native sound behaviour, locality and performance remain open; see pinned-awareness-source-20261027.json. |
| MRPH Infantry Charge - Rewrite Edition (3798063749) | Infantry assault and commitment | Unreconciled; older evidence pointer missing | Review the complete AI scope beyond CQB, including admission, approach, interruption and handback. |
| Pinned Down Conductor (3799629858) | Coordination contribution to identify | Verified extracted source available; deep review unreconciled | Use the verified extracted snapshot to identify actual coordination decisions and ensure complementary methods share one CBE owner. |
| Smart Combat AI - Realistic Reactions & Tactics V2 (3800356547) | Infantry reactions, tactical tasks and support methods | Installed8.0.1 selected state/registry/hazard/building bodies reviewed; endpoint allocation, garrison motion and failed-post reuse source implemented/offline verified; other features open | Continue unread actual feature callers/settings and group cleanup methods or another concrete registered gap. Failed-post memory is now integrated through current garrison ownership; see smart-combat-state-source-20261027.json#garrisonFailedPostMemory20261027. Quiet shelter remains a candidate. Physical native/placed/modded CQB flow, casualty/isolation/egress/repeat and measured cost remain pending under audit pause. |
| Drongo's Grenade Tweaks Lite (3806472028) | AI grenade and UGL choice | Selected scope reviewed; remaining scope needs disposition | Review remaining relevant AI policy and balance; keep player damage/cost changes outside selected scope. |
| AEGIS-M - Integrated Air Defence Framework (3815260246) | Module-free AI layered air defence | Selected scope reviewed; remaining scope needs disposition | Review munition interception, group allocation, threat priority, human crew response and CIWS correction; exclude unrelated framework features. |
| Emergency Air Support (3818040165) | Useful air-support decisions and task composition | Source review pending | Read complete relevant AI support paths and select complementary methods; no wholesale air-support framework port. |
| FPVSCARE (3820669449) | AI reactions to FPV threats | Source reviewed; design/implementation pending | Finish design from reviewed source, including credible threat cues, cover/evasion and original task handback. |
| Pinned Down Combat Suppression (3820871877) | AI-only combat suppression improvements | Current T66 PBO archived and14selected source files compared; changed AI delta reviewed | [Current source comparison](../../releaseVerificationAndDeployment/referenceReviews/pinned-down-combat-suppression-3820871877.json). Preserve actual incoming-fire trigger without permanent shooter identity reveal. Player features excluded; physical/performance gaps remain. |

## optional stealth

| Reference | Functionality to select or improve | Review position | Next source work |
| --- | --- | --- | --- |
| Root's Adaptive Detection System (RADS) (3817252579) | Optional stealth recognition of concealed occupants | Source review pending | Trace recognition and side/captive/targetability changes; assess scenario disruption and default-off restoration. |
| Identity unresolved (3822271074) | Optional stealth contribution, identity unresolved | Source review pending | Locate and identify the source first; then assess requested stealth benefits and scenario risks. Keep optional/default off. |

## compatibility only

| Reference | Functionality to select or improve | Review position | Next source work |
| --- | --- | --- | --- |
| WBK Droids (2567352444) | Specialist droid ownership compatibility | Compatibility review only; expansion last | Review movement/animation writers and actual takeover/release contract only. |
| WebKnight's Zombies And Creatures (2789152015) | Specialist creature ownership compatibility | Compatibility review only; expansion last | Review movement/animation writers and actual takeover/release contract only. |
| IKMS / IMS-SOG reference (compatibility only) (3310205676) | Specialist melee ownership compatibility | Compatibility review only; expansion last | Identify current provider writers and actual handover; exclude melee gameplay implementation. |

## follow-on extension

| Reference | Functionality to select or improve | Review position | Next source work |
| --- | --- | --- | --- |
| TEKILLA Dynamic AI Reactions (3823619778) | Later AI dynamic-reaction extension | Registered for later evaluation | Retain for later evaluation; inspect animation/grip quality, exact equipment restoration and finite task ownership when scheduled. |

## Local integration reference

WaldosMissionPack: locate AI skill setters and their timing, preserve mission-authored baselines, and avoid competing periodic skill writes. This is a read-only reference for the current CBE task.

## Verified source recovery

Eight Pinned Down extracted snapshots were verified against their preserved manifest on 26 October 2026: 320 manifest-listed files passed, including 297 readable source/configuration/FSM files. Their locations and verification record are linked in the machine-readable map. Original PBOs/signatures were not recovered. Deep source reviews remain open. Installed-directory observations for all 48 references are presence checks only.

## Missing evidence and protected stores

The historical master ledger and `.qa/source-refresh-20261011/code-inventory.json` are absent. Missing review pointers do not establish that raw Workshop sources were lost. Recover their provenance from preserved snapshots and manifests. Keep unresolved entries explicit.

Working directory: `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`. Source/archive locations are listed in the machine-readable map and the current handover. Originals remain read-only. Raw upstream code, assets and private signing material stay out of commits and packages.

Audits remain paused. The map itself provides no physical acceptance or performance result.

Current HBQ foundation follow-up (28 October): forward traffic refuses degenerate/nonfinite heading and nonfinite own/peer hull projection through the existing zero-cap unavailable sentinel. See `releaseVerificationAndDeployment/referenceReviews/hbq-traffic-vehicle-categories-20261028.json#unknownGeometryRefusal20261028`. Existing projection, query, prediction, cadence and command owners remain; audits paused, physical behaviour and cost unverified.

LAMBS individual-cover follow-up (28 October): original exterior primary posts retain priority; bounded lateral fallback supplies alternative posts behind the same object when central posts fail reservations/validation. See `releaseVerificationAndDeployment/referenceReviews/lambs-danger-branch-execution-20261025.json#coverPostAlternatives20261028`. At most10 objects/16 post checks; no movement/stance owner added. Failed-search cost can increase; physical effectiveness and performance unverified, audits paused.

LAMBS static-find follow-up (28 October): native incoming gunner assignments and explicit STOP are preserved at bounded nearby-static recruitment and existing cleanup; final boarding rechecks original context unscheduled. See `releaseVerificationAndDeployment/referenceReviews/lambs-fsm-foundations-20261020.json#staticFindSeatAuthority20261028`. Cross-host arbitration, late native handback and physical/performance acceptance remain open; audits paused.

LAMBS carried-static follow-up (28 October): original authored waypoint receipt now binds active execution, native assembly/disassembly callbacks and command-free retirement. See `releaseVerificationAndDeployment/referenceReviews/lambs-fsm-foundations-20261020.json#staticDeployAuthoredOrder20261028`. Direct actor MOVE/STOP retry identity and native action handback remain material gaps before dependent static expansion. No physical/performance acceptance; audits paused.

LAMBS static actor-native follow-up (28 October): `lambs-fsm-foundations-20261020.json#staticDeployNativeActor20261028` resolves the selected changed-goal/STOP retry gap through a shared reader and independent actual-issued-leg receipt. Reservation/phase changes do not renew native publication allowance; retries retain original limits. Same-value, mounted/nonmovement and real all-writer handback gaps remain, with physical/performance evidence paused.

Carried-static artillery integration (28 October): `lambs-fsm-foundations-20261020.json#staticArtilleryOwnership20261028` follows deployment into the existing artillery owner. Static packing/retirement preserve a pending-fire gunner; final native shot admission refuses non-ACTIVE equipment phases even with expired movement markers. No second controller, timer or squad hold. Distributed/native ordering, later recovery after static metadata retirement and full source/physical/cost evidence remain open.

Protocol pairs native-task refill (28 October): `protocol-pairs-3802121807-20261020.json#unrecordedReserveMove20261028` records a concrete shared-drill admission repair. A reserve outside the current element cannot enter casualty refill on an unrecorded native MOVE. Existing admitted/owned moves, idle candidates, pair selection and original budgets remain. Physical opposite roles, covering fire, replacement/arrival and performance remain unverified.

Initial drill native admission (28 October): `lambs-fsm-foundations-20261020.json#firstBoundNativeAdmissionImplementation20261028` freezes original native observations at shared start and reserve commit; direct travel retains its point while native formation can retain moving goals under the same policy/leader. Standalone resume rechecks original matching source proof without grace or a missing MOVE rebaseline. ADMISSION is excluded from movement/hold cleanup authority. Same-value/mode changes, publication/locality and all physical/cost evidence remain open.

Air-support terrain foundation (28 October): `air-relief-route-alternatives-20261028.json` extends the current CBE planner with failure-only -35/+35degree whole-pattern alternatives. Original passing routes and known-AA defensive axes remain; all candidates retain existing join/clearance/lift policy. At most3corridors/990corridor samples, not general3Dsearch or measured flight safety/performance. Registered Emergency Air Support intent remains selective; no upstream algorithm or assets imported.


## Assault descendant reconciliation - 30 October 2026

The complete readable `doAssaultSpeed`, `doAssault`, `doAssaultMemory` and `doAssaultCQB` helper bodies are compared with selected current CBE admission, settings, movement, investigation and physical-visit branches in [the assault descendant record](../../releaseVerificationAndDeployment/referenceReviews/lambs-assault-descendants-20261030.json). Exact source/product hashes and caller edges identify the comparison. This closes the stale request to implement another assault-speed helper; native attack pacing and clearance pacing already have owners. No runtime change was made in this review.

Useful known-belief assault, sympathetic investigation, paced entry and building progression intents remain required. Random room-point consumption, unversioned delayed movement, live hostile-floor lookup and blanket group follow/speed resets are rejected methods. Their rejection does not prove whole-mod parity. Physical movement/entry, incoming all-writer CQB handover, remaining source descendants and measured performance remain incomplete. Audits remain paused.


## Conductor garrison operator and role graph - 30 October 2026

[The selected garrison/ownership comparison](../../releaseVerificationAndDeployment/referenceReviews/conductor-garrison-role-graph-20261030.json) records ten verified source-file hashes with explicit readable scopes and eight selected CBE revisions. Existing walking/instant building garrison and contact-episode static support are distinct from the source explicit garrison static/vehicle-turret roles. Those explicit roles and role-aware firing/protected posts remain implementation gaps. Raw height sorting is not firing-lane proof; source broad resets and forced seating are not adopted. Finish activation/tick/native boarding/release and LOS/role dependencies before adding genuine options to the existing task surfaces. This review changes no runtime capability or acceptance status.

The remaining readable Conductor garrison activation and tick bodies were subsequently inspected. CBE interior arrival discarded upstairs watch height through getPos offset syntax; its existing arrival callback now constructs the watch endpoint at actual eye ASL altitude and converts there. Exterior exit watch, post choice, original owners and deadlines are retained. Explicit garrison weapon roles and protected firing-post selection remain gaps; source final-approach snapping, stuck teleport and broad resets are not adopted. See the lifecycleAndWatchCorrection20261030 entry in the same evidence file; offline verification is recorded there, separately from paused physical acceptance.

Registered Conductor wake path confirmed: XEH_postInit -> PD_start (server/idempotent) -> 1 s CBA tick -> garrisonTick. The similarly named fn_start is not assumed registered. Actual CBE StaticSupport and CALM release were traced: a surviving weapon assignment did not protect newer native MOVE/FOLLOW from boarding cancellation/GetOut. Both boundaries now yield to MOVE or a changed/unrecorded FOLLOW anchor; original anchor is captured once and final admission rechecks it. No extra controller, deadline renewal or forced seating. Exact station identity, native execution-end proof and explicit garrison weapon tasks remain open. See staticNativeMovement20261030 in the existing evidence.

Static support now also matches its original issuing machine, locality epoch and exact native gunner/turret role before active continuation or direct native cleanup. Same-weapon role changes and incoming owners cannot mint new authority from the old journal. Its nine-field lease retains the original eight fields and one captured assignment receipt; no role fallback or renewed deadline. This strengthens actor/station identity without claiming native execution has ended. See staticAssignmentOwner20261030 in the same evidence.

Conductor weapon-crew role intent adapted to fresh contact static support: prefer eligible riflemen, then AT/MG, with native/ACE medics last and still available as fallback. At most64 nearest eligible actors are classified once per fresh contact attempt; the nearest rifleman ends selection and active crews are not reshuffled. Reuses current CBE role/equipment helper; does not claim full marksman/observer/AA classification, garrison weapon module parity or physical balance. See staticCrewRoles20261030.

Garrison geometry dependencies reconciled at2e7caf83: CoverScreened accepts proposed ASL endpoints and can supply non-human screening without new movement; outdoor FindCover is not an interior allocator. Shared BuildingRoofTop already computes the transformed model top, but current Garrison still uses a fixed15m roof ray. That can miss a higher roof and is the next bounded classification fix, not an established cause of old CQB entry failures. No runtime change in this review; see garrisonPostGeometry20261030.

The queued roof-classification correction is now implemented: Garrison reuses BuildingRoofTop once per nonempty living building, skips invalid bounds, retains other valid buildings and never casts downward. Existing search/position budgets, one roof ray per applicable post and prior-task admission guards remain. Full1506tests/489SQF/11PBO and independent package verification pass; physical access/role protection/firing fields and measured cost remain unverified. See roofLimitImplementation20261030; do not requeue the fixed15m endpoint gap.

Near-opening watch intent is now implemented inside actual guarded interior arrival: preferred bearing then at most4 building-relative headings, separate5m terrain/VIEW/FIRE probes and original-direction fallback. Exterior exit observation and current ownership/physical arrival/PATH gates remain. This changes one existing watch point, not location, targets, fire authority or role allocation, and adds no recurring scanner. Actual timing/behaviour remain unverified; see nearWatchOpening20261030.

Bounded medic/MG garrison post preference now shares one read-only selector across initial admission, genuine casualty refill and finite rerouting:16 new geometry profiles per admission,4 per refill/reroute callback. In-place poses, existing occupants, original owner/native guards and retry/deadline limits remain. Full role model, actual native-end acknowledgement and measured/physical results remain open; see rolePostPreference20261030 in the Conductor review.
