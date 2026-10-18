# CBE build-out progress

Build-out measures implemented capability and integration. Acceptance, physical reliability and performance are separate criteria.

These are provisional source-based estimates using explicit, equally weighted capabilities. They are not time/effort estimates or claims of working in-game quality. Scores: absent = 0; implemented subset with a named build gap = 0.5; scoped execution path wired = 1. Physical verification is not required for build credit.

**Assessment coverage: 3/65 feature families.** Unassessed families remain unknown, not 0%. No overall percentage is reported until the full denominator has been assessed.

| Feature family | Build-out | Acceptance status |
| --- | ---: | --- |
| TERRAIN — Cross-cutting uneven-terrain movement and air attack | Unassessed | implemented_partial |
| TERRAIN-BATTLE — Equal-force live battle on measured terrain | Unassessed | implemented_partial |
| CORE — Master, exclusions and ownership | Unassessed | implemented_partial |
| COMPAT — Specialist ownership and alternative-controller handover | Unassessed | implemented_partial |
| SCHED — Scheduler and distance tiers | Unassessed | implemented_partial |
| PROFILE — Behaviour profiles and aggression | Unassessed | implemented_partial |
| SKILL — AI skill rebalance | Unassessed | implemented_partial |
| LAND — Helicopter landing | Unassessed | implemented_partial |
| DECEL — Helicopter braking | Unassessed | implemented_partial |
| REGROUP — Survivor regroup | Unassessed | implemented_partial |
| MEDICAL — Finite squad medical assistance | Unassessed | implemented_partial |
| CONTACT — Contact detection | Unassessed | implemented_partial |
| POST — Post-contact search | Unassessed | implemented_partial |
| FLANK — Flanking bounds | Unassessed | implemented_partial |
| CROSS — Road crossing | Unassessed | implemented_partial |
| FIRE — Fire distribution and suppression | Unassessed | implemented_partial |
| MORALE — Morale and withdrawal | Unassessed | implemented_partial |
| SURRENDER — Surrender | Unassessed | implemented_partial |
| GRENADE — Grenade avoidance | Unassessed | implemented_partial |
| CIVILIAN — Civilian danger response and external ownership | Unassessed | implemented_partial |
| AT — Anti-armour and ammunition roles | Unassessed | implemented_partial |
| VEH — Vehicle engagement | Unassessed | implemented_partial |
| DISMOUNT — Contact passenger dismount | Unassessed | implemented_partial |
| REMOUNT — Contact passenger remount | Unassessed | implemented_partial |
| WITHDRAW — Damaged vehicle withdrawal | Unassessed | implemented_partial |
| COVER — Cover selection and clearance | Unassessed | implemented_partial |
| VEH-DRIVING — Ordinary vehicle route safety | ~68% | implemented_partial |
| CNV-MOVE — Mixed convoy path and spacing | ~81% | implemented_partial |
| CNV-FIRE — Convoy weapon crew | Unassessed | implemented_partial |
| CNV-COVER — Convoy dismount positions | Unassessed | implemented_partial |
| CNV-AVOID — Convoy infantry avoidance | Unassessed | implemented_partial |
| CNV-HALT — Convoy contact drills | Unassessed | implemented_partial |
| CNV-UNLOAD — Convoy cargo lifecycle | Unassessed | implemented_partial |
| HEARING — Gunfire area reports | Unassessed | implemented_partial |
| REPORT — Contact sharing | Unassessed | implemented_partial |
| REINFORCE — Reinforcement | Unassessed | implemented_partial |
| ART — Spotted artillery bursts | Unassessed | implemented_partial |
| CB — Counter-battery | Unassessed | implemented_partial |
| AIRBORNE — Parachute passengers | Unassessed | implemented_partial |
| GARRISON — Garrison and dynamic AO | Unassessed | implemented_partial |
| FLARES — Aircraft countermeasures | Unassessed | implemented_partial |
| INVESTIGATE — Known-area investigation | Unassessed | implemented_partial |
| ASSAULT — Final assault | Unassessed | implemented_partial |
| ADVANCE — Bounding advance | Unassessed | implemented_partial |
| COORD — Coordinated assault | Unassessed | implemented_partial |
| STANCE — Cover stance | Unassessed | implemented_partial |
| AMMO — Magazine sharing | Unassessed | implemented_partial |
| GUNNERY — Vehicle threat priority | Unassessed | implemented_partial |
| ART-SMOKE — Artillery smoke | Unassessed | implemented_partial |
| BREAK — Aircraft evasive break | Unassessed | implemented_partial |
| DEFEND — Defence orders | Unassessed | implemented_partial |
| CLEAR — Building clearance | ~67% | implemented_partial |
| UI — CBA configuration and diagnostics | Unassessed | implemented_partial |
| LIFECYCLE — Transfer, disconnect and JIP | Unassessed | implemented_partial |
| MULTI-FLANK — Multi-squad flank cohesion | Unassessed | implemented_partial |
| MULTI-BOUND — Squad and multi-squad bounding overwatch | Unassessed | implemented_partial |
| MULTI-WITHDRAW — Multi-squad screened withdrawal | Unassessed | implemented_partial |
| TRANSITIONS — Combat action transitions | Unassessed | implemented_partial |
| LIGHTING — Automatic darkness, night vision and illumination | Unassessed | implemented_partial |
| DRILL-HANDOVER — Moving flank and advance handed to Zeus | Unassessed | implemented_partial |
| DRILL-RECOVERY — Bound continuation and straggler rejoin | Unassessed | implemented_partial |
| COMBINED-ARMS — Contact-led combined-arms opportunity | Unassessed | implemented_partial |
| COMBINED-OPERATION — Dynamic multi-squad combined operation | Unassessed | implemented_partial |
| ATTACK-FLARES — Attack-run approach and departure flares | Unassessed | implemented_partial |
| AIR-ATTACK — Threat-aware finite aircraft attack patterns | Unassessed | implemented_partial |

Workshop source-integration/parity percentages are not inferred from these figures. Source contributions need their own explicit scope and disposition. Compatibility-only sources remain separate.

## VEH-DRIVING — Ordinary vehicle route safety

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: medium.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Owner-local driving FSM | 1 / 1 | Route-scoped parent, scheduler execution and finite retirement are wired. [drivingOperationStart](../addons/vehicles/functions/drivingOperationStart.sqf); [drivingOperationStep](../addons/vehicles/functions/drivingOperationStep.sqf) |
| Route identity and speed policy | 1 / 1 | Authored route, terrain and following caps are consumed by ordinary driving. [drivingRouteReceipt](../addons/vehicles/functions/drivingRouteReceipt.sqf); [drivingFollowingCap](../addons/vehicles/functions/drivingFollowingCap.sqf); [drivingRoadCap](../addons/vehicles/functions/drivingRoadCap.sqf) |
| Predictive obstacle handling | 0.5 / 1 | Bounded native-path and hull prediction exists. Remaining: Complete dynamic traffic resolution is unfinished. [drivingGeometryCap](../addons/vehicles/functions/drivingGeometryCap.sqf); [drivingPathGeometry](../addons/vehicles/functions/drivingPathGeometry.sqf) |
| Gate interaction | 0.5 / 1 | Indexed barrier detection and authenticated opening are wired. Remaining: Broader gate-action coverage and automatic closure remain incomplete or unsupported. [drivingGateCap](../addons/vehicles/functions/drivingGateCap.sqf); [drivingGateOpenServer](../addons/vehicles/functions/drivingGateOpenServer.sqf) |
| Finite native rear recovery | 1 / 1 | Native rear request, live corridor/damage monitoring and owned release are implemented. [drivingAssistStart](../addons/vehicles/functions/drivingAssistStart.sqf); [drivingRearClear](../addons/vehicles/functions/drivingRearClear.sqf); [drivingRecoveryRelease](../addons/vehicles/functions/drivingRecoveryRelease.sqf) |
| Static bypass and corridor execution | 1 / 1 | Finite owner-local approach/crossing/return executors exist. [drivingBypassStep](../addons/vehicles/functions/drivingBypassStep.sqf); [drivingCorridorStep](../addons/vehicles/functions/drivingCorridorStep.sqf) |
| Negotiated passing | 0.5 / 1 | Consent and finite passing/return execution are wired. Remaining: Stopped-merge recovery and all native handover cases remain unfinished. [drivingPassAgreementOwner](../addons/vehicles/functions/drivingPassAgreementOwner.sqf); [drivingPassStep](../addons/vehicles/functions/drivingPassStep.sqf) |
| Queue discovery and agreement | 1 / 1 | Bounded dependency discovery, owner agreement and monotonic retirement are wired. [drivingQueueProposal](../addons/vehicles/functions/drivingQueueProposal.sqf); [drivingQueueAgreementServer](../addons/vehicles/functions/drivingQueueAgreementServer.sqf); [drivingQueueAgreementOwner](../addons/vehicles/functions/drivingQueueAgreementOwner.sqf) |
| Queue room-making execution | 0 / 1 | Agreement handler records consent; it issues no movement. Remaining: COMMIT/HOLD/settled READY/rear-first movement/crossing/handback executor is absent. [drivingQueueAgreementOwner](../addons/vehicles/functions/drivingQueueAgreementOwner.sqf) |
| Crew handover | 0.5 / 1 | Current seat and replacement-driver ownership paths exist. Remaining: Complete cross-owner crew transitions and native task preservation still need implementation review. [drivingCrewStep](../addons/vehicles/functions/drivingCrewStep.sqf); [drivingRecoveryCrewAdopt](../addons/vehicles/functions/drivingRecoveryCrewAdopt.sqf) |
| Native order and external handback | 0.5 / 1 | Exact owned settings and changed routes are guarded. Remaining: Separate crew STOP and repeated identical native command cases are not completely resolved. [drivingAssistRelease](../addons/vehicles/functions/drivingAssistRelease.sqf); [drivingOperationFinish](../addons/vehicles/functions/drivingOperationFinish.sqf) |

Calculation: 7.5 implemented capability units / 11 scoped units. Acceptance is not part of this calculation.

## CNV-MOVE — Mixed convoy path and spacing

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: medium.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Convoy operation lifecycle | 1 / 1 | Public task, server revision and owner-local execution are wired. [simpleAiConvoy](../addons/vehicles/functions/simpleAiConvoy.sqf); [convoyOperationStep](../addons/vehicles/functions/convoyOperationStep.sqf); [convoySync](../addons/vehicles/functions/convoySync.sqf) |
| Predecessor trails and native goals | 1 / 1 | Followers consume ordered predecessor travel with native goal continuity. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Mixed-vehicle spacing control | 0.5 / 1 | Gap correction, braking envelope and bounded acceleration are implemented. Remaining: Known mixed-column stop/start and gap convergence faults leave control/balance work open. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Lead pacing | 1 / 1 | Lead pacing responds to aligned follower stretch. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Public halt and resume | 1 / 1 | Revision-scoped halt/resume and applied-cap ownership paths exist. [convoyOperationStep](../addons/vehicles/functions/convoyOperationStep.sqf); [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Replacement native orders | 0.5 / 1 | Native MOVE identity and operator STOP yield are implemented. Remaining: Repeated identical STOP under fixed steering and separate crew-command cases remain open. [convoyRetireMoveReceipt](../addons/vehicles/functions/convoyRetireMoveReceipt.sqf); [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Whole-column passages | 0.5 / 1 | Lead passage and follower whole-hull/tail tracking are composed. Remaining: Stopped-merge recovery and complete interrupted-passage continuation remain unfinished. [convoyCorridorStep](../addons/vehicles/functions/convoyCorridorStep.sqf); [convoyBypassStep](../addons/vehicles/functions/convoyBypassStep.sqf) |
| Crew and cargo integration | 1 / 1 | Crew/cargo policy and revision-scoped owner adoption are wired. [convoyUnloadPolicy](../addons/vehicles/functions/convoyUnloadPolicy.sqf); [convoyHeadlessAdoptLocal](../addons/vehicles/functions/convoyHeadlessAdoptLocal.sqf) |

Calculation: 6.5 implemented capability units / 8 scoped units. Acceptance is not part of this calculation.

## CLEAR — Building clearance

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: medium.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Clear task and operation ownership | 1 / 1 | Explicit task dispatch, generation and owner-local operation are wired. [cortexClearBuilding](../addons/infantry/functions/cortexClearBuilding.sqf); [buildingOperationStart](../addons/infantry/functions/buildingOperationStart.sqf) |
| Dynamic building topology and access | 0.5 / 1 | Runtime entrances, nodes and bounded selection exist. Remaining: Reliable classification of inaccessible modded points and general through-building routing remain unfinished. [cortexClearBuilding](../addons/infantry/functions/cortexClearBuilding.sqf); [indoorActorNodeSelect](../addons/infantry/functions/indoorActorNodeSelect.sqf) |
| Individual native interior movement | 1 / 1 | Finite native movement, command context, progress and cancellation paths are wired. [indoorActorOperation](../addons/infantry/functions/indoorActorOperation.sqf); [indoorActorDispatch](../addons/infantry/functions/indoorActorDispatch.sqf) |
| Buddy and pair flow | 0.5 / 1 | Pair assignment, progress and follow-through paths exist. Remaining: Coherent concurrent entry and straggler handling still require logic refinement. [combatPairs](../addons/infantry/functions/combatPairs.sqf); [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf) |
| Casualty replenishment | 0.5 / 1 | Survivor/pair replacement and role safeguards exist. Remaining: Whole-pair replacement continuity and relief of failed assaulters remain incomplete. [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf) |
| Exterior isolation/security | 0.5 / 1 | Exterior posts, exit observation and lane exclusions are implemented. Remaining: Complete dynamic isolation across approaches/exits and relief behaviour are unfinished. [buildingExteriorCandidate](../addons/infantry/functions/buildingExteriorCandidate.sqf); [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf) |
| Egress and consolidation | 0.5 / 1 | Separated exterior assignment and physical egress tracking exist. Remaining: One failed exterior allocation currently discards a pending worker; coherent post-clear flow remains incomplete. [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf); [buildingExteriorProposal](../addons/infantry/functions/buildingExteriorProposal.sqf) |
| Door handling | 1 / 1 | Production proximity/ownership door handling exists. [cortexBuildingDoor](../addons/infantry/functions/cortexBuildingDoor.sqf) |
| Interruption, repeat and handback | 0.5 / 1 | Generation-scoped interruption and exact movement/settings retirement are implemented. Remaining: Complete post-clear security/repeat lifecycle still needs refinement. [cortexClearRelease](../addons/infantry/functions/cortexClearRelease.sqf); [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf) |

Calculation: 6 implemented capability units / 9 scoped units. Acceptance is not part of this calculation.

