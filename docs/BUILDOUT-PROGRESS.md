# CBE build-out progress

Build-out measures implemented capability and integration. Acceptance, physical reliability and performance are separate criteria.

These are provisional source-based estimates using explicit, equally weighted capabilities. They are not time/effort estimates or claims of working in-game quality. Scores: absent = 0; implemented subset with a named build gap = 0.5; scoped execution path wired = 1. Physical verification is not required for build credit.

**Scope: 64 assessed product families, 1 acceptance-only scenario, 0 unassessed.** Unassessed is unknown, never 0%.

| Feature family | Build-out | Separate acceptance register |
| --- | ---: | --- |
| TERRAIN: Cross-cutting uneven-terrain movement and air attack | ~83% | implemented_partial |
| TERRAIN-BATTLE: Equal-force live battle on measured terrain | Acceptance-only | implemented_partial |
| CORE: Master, exclusions and ownership | ~88% | implemented_partial |
| COMPAT: Specialist ownership and alternative-controller handover | ~50% | implemented_partial |
| SCHED: Scheduler and distance tiers | ~100% | implemented_partial |
| PROFILE: Behaviour profiles and aggression | ~100% | implemented_partial |
| SKILL: AI skill rebalance | ~100% | implemented_partial |
| LAND: Helicopter landing | ~100% | implemented_partial |
| DECEL: Helicopter braking | ~100% | implemented_partial |
| REGROUP: Survivor regroup | ~83% | implemented_partial |
| MEDICAL: Finite squad medical assistance | ~100% | implemented_partial |
| CONTACT: Contact detection | ~88% | implemented_partial |
| POST: Post-contact search | ~100% | implemented_partial |
| FLANK: Flanking bounds | ~83% | implemented_partial |
| CROSS: Road crossing | ~100% | implemented_partial |
| FIRE: Fire distribution and suppression | ~100% | implemented_partial |
| MORALE: Morale and withdrawal | ~100% | implemented_partial |
| SURRENDER: Surrender | ~100% | implemented_partial |
| GRENADE: Grenade avoidance | ~100% | implemented_partial |
| CIVILIAN: Civilian danger response and external ownership | ~100% | implemented_partial |
| AT: Anti-armour and ammunition roles | ~100% | implemented_partial |
| VEH: Vehicle engagement | ~83% | implemented_partial |
| DISMOUNT: Contact passenger dismount | ~100% | implemented_partial |
| REMOUNT: Contact passenger remount | ~83% | implemented_partial |
| WITHDRAW: Damaged vehicle withdrawal | ~83% | implemented_partial |
| COVER: Cover selection and clearance | ~100% | implemented_partial |
| VEH-DRIVING: Ordinary vehicle route safety | ~68% | implemented_partial |
| CNV-MOVE: Mixed convoy path and spacing | ~81% | implemented_partial |
| CNV-FIRE: Convoy weapon crew | ~100% | implemented_partial |
| CNV-COVER: Convoy dismount positions | ~83% | implemented_partial |
| CNV-AVOID: Convoy infantry avoidance | ~100% | implemented_partial |
| CNV-HALT: Convoy contact drills | ~100% | implemented_partial |
| CNV-UNLOAD: Convoy cargo lifecycle | ~100% | implemented_partial |
| HEARING: Gunfire area reports | ~100% | implemented_partial |
| REPORT: Contact sharing | ~100% | implemented_partial |
| REINFORCE: Reinforcement | ~83% | implemented_partial |
| ART: Spotted artillery bursts | ~100% | implemented_partial |
| CB: Counter-battery | ~67% | implemented_partial |
| AIRBORNE: Parachute passengers | ~100% | implemented_partial |
| GARRISON: Garrison and dynamic AO | ~83% | implemented_partial |
| FLARES: Aircraft countermeasures | ~100% | implemented_partial |
| INVESTIGATE: Known-area investigation | ~100% | implemented_partial |
| ASSAULT: Final assault | ~83% | implemented_partial |
| ADVANCE: Bounding advance | ~83% | implemented_partial |
| COORD: Coordinated assault | ~75% | implemented_partial |
| STANCE: Cover stance | ~100% | implemented_partial |
| AMMO: Magazine sharing | ~100% | implemented_partial |
| GUNNERY: Vehicle threat priority | ~83% | implemented_partial |
| ART-SMOKE: Artillery smoke | ~100% | implemented_partial |
| BREAK: Aircraft evasive break | ~100% | implemented_partial |
| DEFEND: Defence orders | ~83% | implemented_partial |
| CLEAR: Building clearance | ~67% | implemented_partial |
| UI: CBA configuration and diagnostics | ~83% | implemented_partial |
| LIFECYCLE: Transfer, disconnect and JIP | ~75% | implemented_partial |
| MULTI-FLANK: Multi-squad flank cohesion | ~67% | implemented_partial |
| MULTI-BOUND: Squad and multi-squad bounding overwatch | ~83% | implemented_partial |
| MULTI-WITHDRAW: Multi-squad screened withdrawal | ~50% | implemented_partial |
| TRANSITIONS: Combat action transitions | ~83% | implemented_partial |
| LIGHTING: Automatic darkness, night vision and illumination | ~100% | implemented_partial |
| DRILL-HANDOVER: Moving flank and advance handed to Zeus | ~83% | implemented_partial |
| DRILL-RECOVERY: Bound continuation and straggler rejoin | ~83% | implemented_partial |
| COMBINED-ARMS: Contact-led combined-arms opportunity | ~88% | implemented_partial |
| COMBINED-OPERATION: Dynamic multi-squad combined operation | ~50% | implemented_partial |
| ATTACK-FLARES: Attack-run approach and departure flares | ~100% | implemented_partial |
| AIR-ATTACK: Threat-aware finite aircraft attack patterns | ~88% | implemented_partial |

## Registered product-plan build-out

The total uses explicit subsystem and family scope weights in the ledger. They reflect planning priorities, not measured effort; cross-cutting features overlap. Small ancillary features do not receive the same total weight as driving or coordinated operations.

| Subsystem | Scope weight | Build-out estimate |
| --- | ---: | ---: |
| Foundations and FSM lifecycle | 10% | ~88% |
| Individual and squad infantry | 15% | ~92% |
| CQB, garrison and defence | 15% | ~74% |
| Coordination and combined operations | 20% | ~67% |
| Driving and convoy | 20% | ~82% |
| Ground vehicles and passengers | 5% | ~86% |
| Aircraft and airborne | 8% | ~96% |
| Reports, reinforcement and artillery | 5% | ~91% |
| Compatibility handovers | 2% | ~50% |

**Current registered-plan build-out index: approximately 80%.** The underlying weighted estimate is 81.0%; rounding avoids false precision. This is provisional and mostly low-confidence. It is not an estimate of remaining time or proof that the behaviour works.

The broad survey uses sampled production call paths and explicit registered intent. New rows are low-confidence provisional engineering estimates, not exhaustive semantic reviews or proof of working balance. The aggregate covers the current registered product plan; broader Workshop-source contributions are not fully reconciled and cannot be described as this percentage complete. No whole-source parity percentage is claimed.

Workshop integration is a separate unfinished scope review; no source-parity percentage is inferred. Compatibility-only sources remain separate. Physical acceptance and the 5% median / 10% p95 budget are also separate.


Workshop source-integration/parity percentages are not inferred from these figures. Source contributions need their own explicit scope and disposition. Compatibility-only sources remain separate.

## TERRAIN: Cross-cutting uneven-terrain movement and air attack

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Ground avenue rejection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSelectAvenue](../addons/infantry/functions/cortexSelectAvenue.sqf) |
| Vehicle path/hull terrain checks | 1 / 1 | Scoped production path is wired in the referenced implementation. [drivingPathGeometry](../addons/vehicles/functions/drivingPathGeometry.sqf) |
| Aircraft relief-aware route planning | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: General through-terrain attack/ground operation composition remains incomplete. [cortexAirAttackPlan](../addons/aircraft/functions/cortexAirAttackPlan.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CORE: Master, exclusions and ownership

Source checkpoint: `fb392dd1 + finite pending posture cleanup`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Master/exclusion admission | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexIsEligible](../addons/infantry/functions/cortexIsEligible.sqf); [cortexFeatureEnabled](../addons/infantry/functions/cortexFeatureEnabled.sqf) |
| Danger and group FSM dispatch | 1 / 1 | Scoped production path is wired in the referenced implementation. [groupBrainStep](../addons/infantry/functions/groupBrainStep.sqf); [dangerStep](../addons/infantry/functions/dangerStep.sqf) |
| Owner epoch and actor reservations | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexLocality](../addons/core/functions/cortexLocality.sqf); [cortexActorMoveReserved](../addons/infantry/functions/cortexActorMoveReserved.sqf) |
| All-owner handback integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Unresolved task-specific native-command cases remain across the controllers. [cortexReleaseGroup](../addons/infantry/functions/cortexReleaseGroup.sqf); [cortexRestoreCalm](../addons/infantry/functions/cortexRestoreCalm.sqf) |

Calculation: 3.5 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## COMPAT: Specialist ownership and alternative-controller handover

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Active specialist exclusion | 1 / 1 | Scoped production path is wired in the referenced implementation. [compatibilityExternalControl](../addons/compatibility/functions/compatibilityExternalControl.sqf); [cortexExternalTakeover](../addons/compatibility/functions/cortexExternalTakeover.sqf) |
| Finite movement lease handover | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Provider-specific baseline restoration and migration are not all implemented. [cortexOwnershipLease](../addons/compatibility/functions/cortexOwnershipLease.sqf) |
| HC provider bridge | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Required real-provider ownership transitions remain only partially covered. [compatibilityHeadlessBridge](../addons/compatibility/functions/compatibilityHeadlessBridge.sqf) |
| Complete required specialist-controller adapters | 0 / 1 | Referenced components expose the boundary but do not implement this capability. Remaining: Detection/exclusion is not a complete real handover implementation for every required external controller. [compatibilityExternalControl](../addons/compatibility/functions/compatibilityExternalControl.sqf) |

Calculation: 2 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## SCHED: Scheduler and distance tiers

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Shared due-job queue and callback budget | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexQueueJob](../addons/core/functions/cortexQueueJob.sqf); [cortexSchedulerTick](../addons/core/functions/cortexSchedulerTick.sqf) |
| Pause/distance/cooldown policy | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCooldown](../addons/infantry/functions/cortexCooldown.sqf); [cortexIsPaused](../addons/infantry/functions/cortexIsPaused.sqf) |
| Runtime reconciliation and retirement | 1 / 1 | Scoped production path is wired in the referenced implementation. [schedulerReconcile](../addons/core/functions/schedulerReconcile.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## PROFILE: Behaviour profiles and aggression

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Profile precedence and tuning | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexProfile](../addons/core/functions/cortexProfile.sqf) |
| Aggression selects eligible tactics | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf); [cortexProfile](../addons/core/functions/cortexProfile.sqf) |
| Independent skill/profile application | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiApplyProfile](../addons/core/functions/aiApplyProfile.sqf); [cortexProfile](../addons/core/functions/cortexProfile.sqf); [aiProfileYield](../addons/core/functions/aiProfileYield.sqf); [aiProfileReceipt](../addons/core/functions/aiProfileReceipt.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## SKILL: AI skill rebalance

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Apply stable configured skill profile | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiApplyProfile](../addons/core/functions/aiApplyProfile.sqf); [aiProfileYield](../addons/core/functions/aiProfileYield.sqf); [aiProfileReceipt](../addons/core/functions/aiProfileReceipt.sqf) |
| Exclusions and owner-local refresh | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiRebalanceInit](../addons/core/functions/aiRebalanceInit.sqf) |
| Restore captured skill values | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiRestoreProfile](../addons/core/functions/aiRestoreProfile.sqf); [aiRebalanceStop](../addons/core/functions/aiRebalanceStop.sqf); [aiProfileReceipt](../addons/core/functions/aiProfileReceipt.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## LAND: Helicopter landing

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Authenticated task and local flight owner | 1 / 1 | Scoped production path is wired in the referenced implementation. [improvedHelicopterLandingConfigureServer](../addons/aircraft/functions/improvedHelicopterLandingConfigureServer.sqf); [improvedHelicopterLandingExecuteLocal](../addons/aircraft/functions/improvedHelicopterLandingExecuteLocal.sqf) |
| Approach/touchdown/anchor phases | 1 / 1 | Scoped production path is wired in the referenced implementation. [improvedHelicopterLandingStep](../addons/aircraft/functions/improvedHelicopterLandingStep.sqf); [improvedHelicopterLandingAnchorLocal](../addons/aircraft/functions/improvedHelicopterLandingAnchorLocal.sqf) |
| Owned feature and flight restoration | 1 / 1 | Scoped production path is wired in the referenced implementation. [improvedHelicopterLandingFeatureReleaseLocal](../addons/aircraft/functions/improvedHelicopterLandingFeatureReleaseLocal.sqf); [improvedHelicopterLandingRestoreLocal](../addons/aircraft/functions/improvedHelicopterLandingRestoreLocal.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## DECEL: Helicopter braking

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Envelope-gated correction | 1 / 1 | Scoped production path is wired in the referenced implementation. [helicopterDecelerationStep](../addons/aircraft/functions/helicopterDecelerationStep.sqf) |
| Bounded local flight correction | 1 / 1 | Scoped production path is wired in the referenced implementation. [helicopterDecelerationCorrectLocal](../addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf) |
| Shared scheduler and flight lease release | 1 / 1 | Scoped production path is wired in the referenced implementation. [helicopterDecelerationInit](../addons/aircraft/functions/helicopterDecelerationInit.sqf); [flightLeaseRelease](../addons/aircraft/functions/flightLeaseRelease.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## REGROUP: Survivor regroup

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Casualty eligibility and host selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexRegroupOnKill](../addons/infantry/functions/cortexRegroupOnKill.sqf); [cortexRegroupStep](../addons/infantry/functions/cortexRegroupStep.sqf) |
| Physical approach and finite merge | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexRegroupStep](../addons/infantry/functions/cortexRegroupStep.sqf) |
| Cross-operation survivor integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete interaction with ongoing multi-squad withdrawal and shared rally remains unfinished. [cortexRegroupStep](../addons/infantry/functions/cortexRegroupStep.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## MEDICAL: Finite squad medical assistance

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Eligible local medic/patient selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMedicalStep](../addons/infantry/functions/cortexMedicalStep.sqf) |
| Finite approach and native treatment | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMedicalStep](../addons/infantry/functions/cortexMedicalStep.sqf) |
| Current-task cancellation and owned release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMedicalStep](../addons/infantry/functions/cortexMedicalStep.sqf); [operationRelease](../addons/core/functions/operationRelease.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CONTACT: Contact detection

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Native danger cause intake/selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [dangerSelect](../addons/infantry/functions/dangerSelect.sqf); [dangerEngineSelect](../addons/infantry/functions/dangerEngineSelect.sqf) |
| No omniscient hostile acquisition | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexKnowledge](../addons/infantry/functions/cortexKnowledge.sqf); [dangerEngineSubmit](../addons/infantry/functions/dangerEngineSubmit.sqf) |
| Mounted/foot subsystem handoff | 1 / 1 | Scoped production path is wired in the referenced implementation. [dangerVehicleProfile](../addons/infantry/functions/dangerVehicleProfile.sqf); [dangerReact](../addons/infantry/functions/dangerReact.sqf) |
| Complete tactical response composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Individual danger responses do not yet compose all intended squad/combined-operation behaviours. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf) |

Calculation: 3.5 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## POST: Post-contact search

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Contact/security/search phase dispatch | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf) |
| Owned last-known-position movement | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSearchMoveOwned](../addons/infantry/functions/cortexSearchMoveOwned.sqf); [cortexGroupMove](../addons/infantry/functions/cortexGroupMove.sqf) |
| Recontact and authored-route release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf); [cortexGroupMoveClear](../addons/infantry/functions/cortexGroupMoveClear.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## FLANK: Flanking bounds

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Avenue and successive bound route | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSelectAvenue](../addons/infantry/functions/cortexSelectAvenue.sqf); [cortexFlankStart](../addons/infantry/functions/cortexFlankStart.sqf) |
| Moving/covering pair execution | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Recovery and final consolidation | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Straggler continuation and coherent final consolidation still need refinement. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [recoveryStep](../addons/infantry/functions/recoveryStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CROSS: Road crossing

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Road edge/crossing route markers | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexPlanRoute](../addons/infantry/functions/cortexPlanRoute.sqf) |
| Bounded smoke/preparation | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexThrowGrenade](../addons/infantry/functions/cortexThrowGrenade.sqf); [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Near/far movement under existing drill | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## FIRE: Fire distribution and suppression

Source checkpoint: `b8ac7bae + native MOVE fire-control protection`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Known-target assignment and ammunition | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFireControl](../addons/core/functions/cortexFireControl.sqf) |
| Friendly/civilian lane checks | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexLineOfFireClear](../addons/infantry/functions/cortexLineOfFireClear.sqf) |
| Native direct/suppressive fire and gating | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFireControl](../addons/core/functions/cortexFireControl.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## MORALE: Morale and withdrawal

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Strength/profile morale assessment | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMorale](../addons/infantry/functions/cortexMorale.sqf) |
| Finite withdrawal instead of assault | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf); [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf) |
| Recovery and current-order preservation | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf); [cortexRestoreCalm](../addons/infantry/functions/cortexRestoreCalm.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## SURRENDER: Surrender

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Eligible survivor admission | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSurrender](../addons/infantry/functions/cortexSurrender.sqf) |
| Native surrender/captive transition | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSurrender](../addons/infantry/functions/cortexSurrender.sqf) |
| Owned task release and repeat guards | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSurrender](../addons/infantry/functions/cortexSurrender.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## GRENADE: Grenade avoidance

Source checkpoint: `f5e54d0d + actor danger posture handover`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Relevant danger detection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGrenadeCheck](../addons/infantry/functions/cortexGrenadeCheck.sqf) |
| Finite native escape response | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGrenadeCheck](../addons/infantry/functions/cortexGrenadeCheck.sqf); [dangerEngineAct](../addons/infantry/functions/dangerEngineAct.sqf) |
| Current actor and ownership protection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGrenadeCheck](../addons/infantry/functions/cortexGrenadeCheck.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CIVILIAN: Civilian danger response and external ownership

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Gunfire/hit event intake | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCivilianSetup](../addons/infantry/functions/cortexCivilianSetup.sqf) |
| Finite graded escape and one recovery | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCivilianReact](../addons/infantry/functions/cortexCivilianReact.sqf); [cortexCivilianStep](../addons/infantry/functions/cortexCivilianStep.sqf) |
| External/native interruption | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCivilianStep](../addons/infantry/functions/cortexCivilianStep.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## AT: Anti-armour and ammunition roles

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Capable weapon/target selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAntiArmour](../addons/infantry/functions/cortexAntiArmour.sqf) |
| Backblast and firing-lane checks | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAntiArmour](../addons/infantry/functions/cortexAntiArmour.sqf); [cortexLineOfFireClear](../addons/infantry/functions/cortexLineOfFireClear.sqf) |
| No-AT threat response respects authored hold | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf); [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## VEH: Vehicle engagement

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Mounted domain/crew response | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexVehicles](../addons/vehicles/functions/cortexVehicles.sqf); [cortexVehicleCrewRecover](../addons/vehicles/functions/cortexVehicleCrewRecover.sqf) |
| Finite naval approach/unload/release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexNavalAssault](../addons/vehicles/functions/cortexNavalAssault.sqf); [cortexNavalRelease](../addons/vehicles/functions/cortexNavalRelease.sqf) |
| Vehicle manoeuvre composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Standoff/withdrawal and combined-ground role transitions remain partially integrated. [cortexVehicleJink](../addons/vehicles/functions/cortexVehicleJink.sqf); [cortexVehicleOrient](../addons/vehicles/functions/cortexVehicleOrient.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## DISMOUNT: Contact passenger dismount

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Safe passenger eligibility and crew exclusion | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexVehicleUnloadPolicy](../addons/vehicles/functions/cortexVehicleUnloadPolicy.sqf) |
| Contact-driven native unloading | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexOnboardContact](../addons/infantry/functions/cortexOnboardContact.sqf) |
| Owner-scoped passenger safety | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexOnboardContact](../addons/infantry/functions/cortexOnboardContact.sqf); [cortexPassengerReady](../addons/vehicles/functions/cortexPassengerReady.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## REMOUNT: Contact passenger remount

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Original capable passenger eligibility | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexPassengerReady](../addons/vehicles/functions/cortexPassengerReady.sqf) |
| Seat choice and native boarding | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexOnboardContact](../addons/infantry/functions/cortexOnboardContact.sqf) |
| Distributed simultaneous seat coordination | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Cross-owner simultaneous passenger selection/reservation remains incomplete. [cortexOnboardContact](../addons/infantry/functions/cortexOnboardContact.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## WITHDRAW: Damaged vehicle withdrawal

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Damage/threat admission | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexVehicles](../addons/vehicles/functions/cortexVehicles.sqf); [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf) |
| Finite native withdrawal and smoke | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf); [cortexVehicles](../addons/vehicles/functions/cortexVehicles.sqf) |
| Coordinated withdrawal integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete screened multi-squad withdrawal/rally is unfinished. [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## COVER: Cover selection and clearance

Source checkpoint: `f32bcf1f + native planning and shared admission`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Bounded candidate/clearance query | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFindCover](../addons/infantry/functions/cortexFindCover.sqf) |
| Passable avenue and native movement integration | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSelectAvenue](../addons/infantry/functions/cortexSelectAvenue.sqf); [dangerCoverStep](../addons/infantry/functions/dangerCoverStep.sqf) |
| Posture and owner protection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexStance](../addons/infantry/functions/cortexStance.sqf); [dangerCoverStep](../addons/infantry/functions/dangerCoverStep.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## VEH-DRIVING: Ordinary vehicle route safety

Source checkpoint: `3f56dd8b + default-off automatic queue initiation`; reviewed 2026-10-20; confidence: medium.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Owner-local driving FSM | 1 / 1 | Route-scoped parent, scheduler execution and finite retirement are wired. [drivingOperationStart](../addons/vehicles/functions/drivingOperationStart.sqf); [drivingOperationStep](../addons/vehicles/functions/drivingOperationStep.sqf) |
| Route identity and speed policy | 1 / 1 | Authored route, terrain and following caps are consumed by ordinary driving. [drivingRouteReceipt](../addons/vehicles/functions/drivingRouteReceipt.sqf); [drivingFollowingCap](../addons/vehicles/functions/drivingFollowingCap.sqf); [drivingRoadCap](../addons/vehicles/functions/drivingRoadCap.sqf) |
| Predictive obstacle handling | 0.5 / 1 | Bounded native-path and hull prediction exists. Remaining: Complete dynamic traffic resolution is unfinished. [drivingGeometryCap](../addons/vehicles/functions/drivingGeometryCap.sqf); [drivingPathGeometry](../addons/vehicles/functions/drivingPathGeometry.sqf) |
| Gate interaction | 0.5 / 1 | Indexed barrier detection and authenticated opening are wired. Remaining: Broader gate-action coverage and automatic closure remain incomplete or unsupported. [drivingGateCap](../addons/vehicles/functions/drivingGateCap.sqf); [drivingGateOpenServer](../addons/vehicles/functions/drivingGateOpenServer.sqf) |
| Finite native rear recovery | 1 / 1 | Native rear requests, live corridor/damage monitoring and exact owned release are wired. Finite linear and angular rest now gates stationary recovery and handback. [drivingAssistStart](../addons/vehicles/functions/drivingAssistStart.sqf); [drivingRearClear](../addons/vehicles/functions/drivingRearClear.sqf); [drivingRecoveryRelease](../addons/vehicles/functions/drivingRecoveryRelease.sqf); [drivingRearPlan](../addons/vehicles/functions/drivingRearPlan.sqf) |
| Static bypass and corridor execution | 1 / 1 | Finite owner-local approach/crossing/return executors exist. [drivingBypassStep](../addons/vehicles/functions/drivingBypassStep.sqf); [drivingCorridorStep](../addons/vehicles/functions/drivingCorridorStep.sqf) |
| Negotiated passing | 0.5 / 1 | Consent and finite passing/return execution are wired. Remaining: Stopped-merge recovery and all native handover cases remain unfinished. [drivingPassAgreementOwner](../addons/vehicles/functions/drivingPassAgreementOwner.sqf); [drivingPassStep](../addons/vehicles/functions/drivingPassStep.sqf) |
| Queue discovery and agreement | 0.5 / 1 | Bounded dependency discovery and actual-owner consent are wired. A default-off CBA opt-in now offers one automatic head-on proposal from persistent traffic within the original retry episode, defers competing replans and services at most two authenticated root COMMIT requests. Remaining: Stationary crossing geometry between45and135degrees now has a bounded admission path. General stopped merges and unsupported crossing angles/recovery choices remain unfinished; unsupported native reverse crew arrangements refuse. [drivingQueueProposal](../addons/vehicles/functions/drivingQueueProposal.sqf); [drivingQueueAgreementServer](../addons/vehicles/functions/drivingQueueAgreementServer.sqf); [drivingQueueAgreementOwner](../addons/vehicles/functions/drivingQueueAgreementOwner.sqf); [drivingQueueContext](../addons/vehicles/functions/drivingQueueContext.sqf); [drivingQueueProposalCurrent](../addons/vehicles/functions/drivingQueueProposalCurrent.sqf); [drivingAssistStart](../addons/vehicles/functions/drivingAssistStart.sqf); [drivingQueueCrossingVehicle](../addons/vehicles/functions/drivingQueueCrossingVehicle.sqf); [drivingQueueAutoStep](../addons/vehicles/functions/drivingQueueAutoStep.sqf); [drivingQueuePairGeometry](../addons/vehicles/functions/drivingQueuePairGeometry.sqf) |
| Queue room-making execution | 0.5 / 1 | Explicit internal COMMIT now reaches all-owner holds and preparation, finite reverse dependency phases, crossing planning/installation, zero-cap native path issue, all-owner published-path acknowledgement, root-only motion grant, physical checkpoint/tail observation and exact completion-receipt cleanup through the existing driving callback. Ordinary traffic constraints remain; only frozen held queue hulls delegate to validated path geometry. One original maximum90-second episode, no phase renewal. In-game outcomes remain unverified. Default-off automatic initiation now reaches this same executor through its existing callback, without a new worker or renewed episode. Remaining: Head-on and qualifying stationary crossing pairs share finite native room-making and checked crossing execution. General stopped merges, other angles and unsupported native reverse roles remain unfinished. Physical natural admission, route continuation, delayed replication, normal/HC interruption and overhead remain unverified. [drivingQueueAgreementOwner](../addons/vehicles/functions/drivingQueueAgreementOwner.sqf); [drivingAssistStart](../addons/vehicles/functions/drivingAssistStart.sqf); [drivingQueueReverseCommit](../addons/vehicles/functions/drivingQueueReverseCommit.sqf); [drivingQueueReverseCurrent](../addons/vehicles/functions/drivingQueueReverseCurrent.sqf); [drivingQueueAgreementServer](../addons/vehicles/functions/drivingQueueAgreementServer.sqf); [drivingQueueParentRoom](../addons/vehicles/functions/drivingQueueParentRoom.sqf); [drivingQueueAutoStep](../addons/vehicles/functions/drivingQueueAutoStep.sqf); [drivingQueuePairGeometry](../addons/vehicles/functions/drivingQueuePairGeometry.sqf) |
| Crew handover | 0.5 / 1 | Current seat and replacement-driver ownership paths exist. Remaining: Complete cross-owner crew transitions and native task preservation still need implementation review. [drivingCrewStep](../addons/vehicles/functions/drivingCrewStep.sqf); [drivingRecoveryCrewAdopt](../addons/vehicles/functions/drivingRecoveryCrewAdopt.sqf) |
| Native order and external handback | 0.5 / 1 | Exact owned settings and changed routes are guarded. Remaining: Exact queue-abort STOP supports active/released-cap original-owner cleanup and controlled master-stop epoch adoption. Actual owner migration, missing STOP acknowledgement and repeated identical native commands remain incomplete or unresolved. [drivingAssistRelease](../addons/vehicles/functions/drivingAssistRelease.sqf); [drivingOperationFinish](../addons/vehicles/functions/drivingOperationFinish.sqf); [drivingAbortHandback](../addons/vehicles/functions/drivingAbortHandback.sqf) |

Calculation: 7.5 implemented capability units / 11 scoped units. Acceptance is not part of this calculation.

## CNV-MOVE: Mixed convoy path and spacing

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

## CNV-FIRE: Convoy weapon crew

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Permitted known threat selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyThreat](../addons/vehicles/functions/convoyThreat.sqf) |
| Gunner-only engagement | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyCrewLocal](../addons/vehicles/functions/convoyCrewLocal.sqf) |
| Driver movement/task preservation | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyCrewLocal](../addons/vehicles/functions/convoyCrewLocal.sqf); [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CNV-COVER: Convoy dismount positions

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Available dismount cover selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyDismountLocal](../addons/vehicles/functions/convoyDismountLocal.sqf); [cortexFindCover](../addons/infantry/functions/cortexFindCover.sqf) |
| Native passenger movement | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyDismountLocal](../addons/vehicles/functions/convoyDismountLocal.sqf) |
| Whole dismount/security integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Coherent exterior security and relief roles remain partial rather than isolated cover destinations. [convoyDismountLocal](../addons/vehicles/functions/convoyDismountLocal.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CNV-AVOID: Convoy infantry avoidance

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Short infantry corridor observation | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Bounded stop/cap and clearance response | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Owned cap release after clearance | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CNV-HALT: Convoy contact drills

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Mobile/contact versus pinned policy | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyTick](../addons/vehicles/functions/convoyTick.sqf) |
| Authoritative explicit halt | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyHaltServer](../addons/vehicles/functions/convoyHaltServer.sqf) |
| Revision-scoped resume | 1 / 1 | Scoped production path is wired in the referenced implementation. [simpleAiConvoy](../addons/vehicles/functions/simpleAiConvoy.sqf); [convoySync](../addons/vehicles/functions/convoySync.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CNV-UNLOAD: Convoy cargo lifecycle

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Cargo/operating-crew separation | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyUnloadPolicy](../addons/vehicles/functions/convoyUnloadPolicy.sqf) |
| Owner-local unload and seating controls | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyCrewLocal](../addons/vehicles/functions/convoyCrewLocal.sqf) |
| Release keeps replacement tasks | 1 / 1 | Scoped production path is wired in the referenced implementation. [convoyReleaseLocal](../addons/vehicles/functions/convoyReleaseLocal.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## HEARING: Gunfire area reports

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Local gunfire area observation | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexHearingLocal](../addons/infantry/functions/cortexHearingLocal.sqf) |
| Uncertainty/range retained | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexHearingLocal](../addons/infantry/functions/cortexHearingLocal.sqf) |
| Gated investigation handoff | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexHearingLocal](../addons/infantry/functions/cortexHearingLocal.sqf); [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## REPORT: Contact sharing

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Actual transmitter and mutual radio eligibility | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupTransmitter](../addons/infantry/functions/cortexGroupTransmitter.sqf); [cortexCanTransmit](../addons/infantry/functions/cortexCanTransmit.sqf) |
| Authenticated contact transport | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexReportLocal](../addons/infantry/functions/cortexReportLocal.sqf); [cortexReportServer](../addons/infantry/functions/cortexReportServer.sqf) |
| Original observation age/uncertainty | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexReportServer](../addons/infantry/functions/cortexReportServer.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## REINFORCE: Reinforcement

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Eligible combat-effective responder selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexReinforce](../addons/support/functions/cortexReinforce.sqf) |
| Finite request/reservation and movement | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexReinforce](../addons/support/functions/cortexReinforce.sqf); [cortexSupportLocal](../addons/support/functions/cortexSupportLocal.sqf) |
| Full replacement/relief integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Sustained casualty relief and dynamic combined-operation retasking remain unfinished. [cortexReinforce](../addons/support/functions/cortexReinforce.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## ART: Spotted artillery bursts

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Battery/observer role and ammo selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryRole](../addons/support/functions/cortexArtilleryRole.sqf); [cortexArtilleryAmmo](../addons/support/functions/cortexArtilleryAmmo.sqf) |
| Observed ranging and finite bursts | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryMissionStep](../addons/support/functions/cortexArtilleryMissionStep.sqf); [cortexArtilleryObserve](../addons/support/functions/cortexArtilleryObserve.sqf) |
| Impact safety and native release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryAim](../addons/support/functions/cortexArtilleryAim.sqf); [cortexArtilleryFire](../addons/support/functions/cortexArtilleryFire.sqf) |
| Finite relocation and mission lifecycle | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryScoot](../addons/support/functions/cortexArtilleryScoot.sqf); [artilleryMissionStep](../addons/support/functions/artilleryMissionStep.sqf) |

Calculation: 4 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## CB: Counter-battery

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Radar registration and acquisition | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexRegisterRadar](../addons/infantry/functions/cortexRegisterRadar.sqf); [cortexCounterBattery](../addons/support/functions/cortexCounterBattery.sqf) |
| Non-radar qualified detection | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Qualified non-radar detection remains incomplete. [cortexCounterObserve](../addons/infantry/functions/cortexCounterObserve.sqf) |
| Side-specific emission retargeting | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Global emission retargeting lacks complete side-specific detection qualification. [cortexCounterBattery](../addons/support/functions/cortexCounterBattery.sqf) |

Calculation: 2 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## AIRBORNE: Parachute passengers

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Altitude/crew/passenger eligibility | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAirborneCheck](../addons/aircraft/functions/cortexAirborneCheck.sqf) |
| Spaced native jump/deployment | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAirborneDropStep](../addons/aircraft/functions/cortexAirborneDropStep.sqf); [cortexParachuteJump](../addons/infantry/functions/cortexParachuteJump.sqf); [cortexParachuteDeploy](../addons/infantry/functions/cortexParachuteDeploy.sqf) |
| Insertion episode and owned protection release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAirborneDropStep](../addons/aircraft/functions/cortexAirborneDropStep.sqf); [cortexParachuteProtectionRelease](../addons/infantry/functions/cortexParachuteProtectionRelease.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## GARRISON: Garrison and dynamic AO

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Runtime slots and walk/explicit teleport choice | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGarrison](../addons/infantry/functions/cortexGarrison.sqf) |
| Owned slot/floor arrival and hold | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGarrisonApplyLocal](../addons/infantry/functions/cortexGarrisonApplyLocal.sqf); [cortexGarrisonArrived](../addons/infantry/functions/cortexGarrisonArrived.sqf) |
| Dynamic refill and interrupted task integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete dynamic relief and unavailable-building-position recovery remain unfinished. [cortexGarrisonRefill](../addons/infantry/functions/cortexGarrisonRefill.sqf); [cortexGarrisonRelease](../addons/infantry/functions/cortexGarrisonRelease.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## FLARES: Aircraft countermeasures

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Threat event and aircraft eligibility | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMissileDefenceStep](../addons/aircraft/functions/cortexMissileDefenceStep.sqf) |
| Real finite countermeasure release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFireCountermeasure](../addons/infantry/functions/cortexFireCountermeasure.sqf) |
| Owner/feature cancellation | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMissileDefenceStep](../addons/aircraft/functions/cortexMissileDefenceStep.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## INVESTIGATE: Known-area investigation

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Reported-area native movement | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupMove](../addons/infantry/functions/cortexGroupMove.sqf) |
| Finite ownership and authored route | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupMove](../addons/infantry/functions/cortexGroupMove.sqf) |
| Interruption/cleanup | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexGroupMoveClear](../addons/infantry/functions/cortexGroupMoveClear.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## ASSAULT: Final assault

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Fresh target and pair admission | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAssaultStart](../addons/infantry/functions/cortexAssaultStart.sqf) |
| Preparation and native clear-through | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Coherent follow-through/consolidation | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Pair flow and post-assault consolidation remain partially refined. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## ADVANCE: Bounding advance

Source checkpoint: `a498b71a + belief and depleted native engagement`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Authored objective and tactical assessment | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAdvanceStart](../addons/infantry/functions/cortexAdvanceStart.sqf); [cortexTacticalAssess](../addons/infantry/functions/cortexTacticalAssess.sqf) |
| Finite moving/covering teams | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Casualty/straggler continuation | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete continuation without stranded actors remains unfinished. [rebalanceRoles](../addons/infantry/functions/rebalanceRoles.sqf); [recoveryStep](../addons/infantry/functions/recoveryStep.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## COORD: Coordinated assault

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Communicated opportunity and owner ACK | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCoordinatedAssault](../addons/support/functions/cortexCoordinatedAssault.sqf); [cortexSupportAck](../addons/support/functions/cortexSupportAck.sqf) |
| Separated lane allocation | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Full dynamic route complementarity and convergence resolution remain unfinished. [cortexSupportCoordinateStep](../addons/support/functions/cortexSupportCoordinateStep.sqf) |
| Finite local bounds/support roles | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSupportBoundStart](../addons/support/functions/cortexSupportBoundStart.sqf); [cortexSupportLocal](../addons/support/functions/cortexSupportLocal.sqf) |
| Responder replacement and composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete role transitions across casualty/operation changes remain unfinished. [cortexSupportStep](../addons/support/functions/cortexSupportStep.sqf) |

Calculation: 3 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## STANCE: Cover stance

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Actual cover-based stance | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexStance](../addons/infantry/functions/cortexStance.sqf) |
| Task/reservation exclusions | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexStance](../addons/infantry/functions/cortexStance.sqf) |
| Exact owned posture restoration | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexStance](../addons/infantry/functions/cortexStance.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## AMMO: Magazine sharing

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Compatible donor/recipient selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAmmoShare](../addons/infantry/functions/cortexAmmoShare.sqf); [cortexCapabilities](../addons/infantry/functions/cortexCapabilities.sqf) |
| Conservative magazine transfer | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAmmoShare](../addons/infantry/functions/cortexAmmoShare.sqf) |
| Role/gate/current-actor protection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAmmoShare](../addons/infantry/functions/cortexAmmoShare.sqf); [cortexUnitRole](../addons/infantry/functions/cortexUnitRole.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## GUNNERY: Vehicle threat priority

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Known threat/platform/ammo suitability | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexVehicles](../addons/vehicles/functions/cortexVehicles.sqf); [cortexGroundFireReady](../addons/infantry/functions/cortexGroundFireReady.sqf) |
| Native gunner fire authority | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexVehicles](../addons/vehicles/functions/cortexVehicles.sqf) |
| Standoff/combined-role composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete arbitration between routine standoff and coordinated ground roles remains partial. [cortexVehicles](../addons/vehicles/functions/cortexVehicles.sqf); [cortexCombinedGroundStep](../addons/infantry/functions/cortexCombinedGroundStep.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## ART-SMOKE: Artillery smoke

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Strict smoke ammunition classification | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryAmmo](../addons/support/functions/cortexArtilleryAmmo.sqf) |
| Finite screened mission dispatch | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryFire](../addons/support/functions/cortexArtilleryFire.sqf); [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf) |
| Battery mission safety/retirement | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexArtilleryMissionStep](../addons/support/functions/cortexArtilleryMissionStep.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## BREAK: Aircraft evasive break

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Actual threat and flight owner admission | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMissileDefenceStep](../addons/aircraft/functions/cortexMissileDefenceStep.sqf) |
| Bounded break-away correction | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexMissileDefenceStep](../addons/aircraft/functions/cortexMissileDefenceStep.sqf) |
| Flight lease cleanup and native return | 1 / 1 | Scoped production path is wired in the referenced implementation. [flightLeaseRelease](../addons/aircraft/functions/flightLeaseRelease.sqf); [cortexMissileDefenceStep](../addons/aircraft/functions/cortexMissileDefenceStep.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## DEFEND: Defence orders

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Validated explicit defence task | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexDefend](../addons/infantry/functions/cortexDefend.sqf) |
| Slot allocation and native arrival | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexDefendApplyLocal](../addons/infantry/functions/cortexDefendApplyLocal.sqf); [cortexDefendStep](../addons/infantry/functions/cortexDefendStep.sqf) |
| Dynamic security/relief composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Full relief and cross-squad defence role composition remain unfinished. [cortexDefendStep](../addons/infantry/functions/cortexDefendStep.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## CLEAR: Building clearance

Source checkpoint: `603a6088c5eac70220ba774af43dca515d6719dc`; reviewed 2026-10-20; confidence: medium.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Clear task and operation ownership | 1 / 1 | Explicit task dispatch, generation and owner-local operation are wired. Matching episode/transform adoption retains validated casualty-post history as metadata without restoring movement authority. [cortexClearBuilding](../addons/infantry/functions/cortexClearBuilding.sqf); [buildingOperationStart](../addons/infantry/functions/buildingOperationStart.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |
| Dynamic building topology and access | 0.5 / 1 | Runtime entrances, nodes and bounded selection exist. Remaining: Reliable classification of inaccessible modded points and general through-building routing remain unfinished. [cortexClearBuilding](../addons/infantry/functions/cortexClearBuilding.sqf); [indoorActorNodeSelect](../addons/infantry/functions/indoorActorNodeSelect.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |
| Individual native interior movement | 1 / 1 | Finite native movement, command context, progress and cancellation paths are wired. [indoorActorOperation](../addons/infantry/functions/indoorActorOperation.sqf); [indoorActorDispatch](../addons/infantry/functions/indoorActorDispatch.sqf) |
| Buddy and pair flow | 0.5 / 1 | Pair assignment, progress and follow-through paths exist. Remaining: Coherent concurrent entry and straggler handling still require logic refinement. [combatPairs](../addons/infantry/functions/combatPairs.sqf); [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |
| Casualty replenishment | 0.5 / 1 | Survivor/pair replacement and role safeguards are wired. Bounded candidate and substitute-observer windows rotate through the full current eligible roster; known guard loss can retain an existing relief leg. Remaining: Whole-pair replacement continuity and relief of failed assaulters remain incomplete. [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |
| Exterior isolation/security | 0.5 / 1 | Exterior posts, actual exit observation and lane exclusions are wired. Known guard casualties can trigger one reassignment from a duplicated post using existing coverage proof and original allocation budgets. Matching owner adoption retains casualty history; complete admitted post exclusions are checked before planning. Remaining: General isolation across approaches, uncovered-exit reassessment without redundant reserve cover, and complete security-role relief remain unfinished. Physical normal/HC/repeated-use outcomes remain separate unverified work. [buildingExteriorCandidate](../addons/infantry/functions/buildingExteriorCandidate.sqf); [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |
| Egress and consolidation | 0.5 / 1 | Separated exterior assignments, physical exit tracking and bounded allocation retries with owner-adopted budgets are wired. Remaining: Coherent post-clear security/consolidation and broader straggler flow remain incomplete. [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf); [buildingExteriorProposal](../addons/infantry/functions/buildingExteriorProposal.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |
| Door handling | 1 / 1 | Production proximity/ownership door handling exists. [cortexBuildingDoor](../addons/infantry/functions/cortexBuildingDoor.sqf); [cortexRouteDoors](../addons/infantry/functions/cortexRouteDoors.sqf) |
| Interruption, repeat and handback | 0.5 / 1 | Generation-scoped interruption, exact movement retirement and shared settings-only release with finite existing-brain retries are wired. Remaining: Complete post-clear security/repeat lifecycle and deferred settings release after brain shutdown or retry expiry remain unfinished. [cortexClearRelease](../addons/infantry/functions/cortexClearRelease.sqf); [buildingOperationStep](../addons/infantry/functions/buildingOperationStep.sqf); [cortexClearSettingsRelease](../addons/infantry/functions/cortexClearSettingsRelease.sqf); [actorSettings](../addons/core/functions/actorSettings.sqf); [cortexClearSettingsApply](../addons/infantry/functions/cortexClearSettingsApply.sqf) |

Calculation: 6 implemented capability units / 9 scoped units. Acceptance is not part of this calculation.

## UI: CBA configuration and diagnostics

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| CBA typed settings and effective values | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiTweaksRegisterSettings](../addons/core/functions/aiTweaksRegisterSettings.sqf); [aiTweaksSettingChanged](../addons/core/functions/aiTweaksSettingChanged.sqf) |
| Diagnostics and notifications | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiGetDiagnostics](../addons/core/functions/aiGetDiagnostics.sqf); [aiTweaksDiagnosticReport](../addons/core/functions/aiTweaksDiagnosticReport.sqf) |
| Behaviour task dialogs/dispatch | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: The full selected-reference behaviour-module catalogue has not been reconciled or implemented. [zenClearModule](../addons/infantry/functions/zenClearModule.sqf); [zenDefendModule](../addons/infantry/functions/zenDefendModule.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## LIFECYCLE: Transfer, disconnect and JIP

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Epoch/current-owner execution | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexLocality](../addons/core/functions/cortexLocality.sqf); [operationStep](../addons/core/functions/operationStep.sqf) |
| Authenticated task dispatch/results | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexOrderDispatch](../addons/infantry/functions/cortexOrderDispatch.sqf); [cortexOrderLocal](../addons/infantry/functions/cortexOrderLocal.sqf); [cortexOrderResult](../addons/infantry/functions/cortexOrderResult.sqf) |
| Job and control restoration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Task-specific exact handbacks and successor-control cases remain open. [operationRelease](../addons/core/functions/operationRelease.sqf); [operationRestore](../addons/core/functions/operationRestore.sqf) |
| Complete provider/JIP replay composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Cross-provider episode adoption and full side-effect replay remain partial. [cortexCheckpoint](../addons/infantry/functions/cortexCheckpoint.sqf); [aiHeadlessAdoptLocal](../addons/core/functions/aiHeadlessAdoptLocal.sqf) |

Calculation: 3 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## MULTI-FLANK: Multi-squad flank cohesion

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Independent local manoeuvre executors | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Complementary squad lanes | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete lane convergence and conflict resolution remain unfinished. [cortexSupportCoordinateStep](../addons/support/functions/cortexSupportCoordinateStep.sqf) |
| Cross-squad continuation/relief | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: All multi-squad casualty and retasking transitions are not implemented. [cortexSupportMaintain](../addons/support/functions/cortexSupportMaintain.sqf) |

Calculation: 2 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## MULTI-BOUND: Squad and multi-squad bounding overwatch

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Within-squad pair movement/cover | 1 / 1 | Scoped production path is wired in the referenced implementation. [combatPairs](../addons/infantry/functions/combatPairs.sqf); [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Cross-squad finite turn allocation | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSupportCoordinateStep](../addons/support/functions/cortexSupportCoordinateStep.sqf) |
| Complete role exchange/recovery composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Cross-squad readiness and casualty continuity remain partial. [cortexSupportMaintain](../addons/support/functions/cortexSupportMaintain.sqf); [recoveryStep](../addons/infantry/functions/recoveryStep.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## MULTI-WITHDRAW: Multi-squad screened withdrawal

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Individual squad withdrawal | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf) |
| Multiple independent escape lanes | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: A shared screened withdrawal plan is not fully composed. [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf); [cortexSelectAvenue](../addons/infantry/functions/cortexSelectAvenue.sqf) |
| Alternating cross-squad overwatch and rally | 0 / 1 | Referenced components expose the boundary but do not implement this capability. Remaining: Independent withdrawal does not implement coordinated alternating overwatch and shared rally. [cortexRetreat](../addons/infantry/functions/cortexRetreat.sqf) |

Calculation: 1.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## TRANSITIONS: Combat action transitions

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Explicit phase/stage and terminal outcomes | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexSetPhase](../addons/infantry/functions/cortexSetPhase.sqf); [cortexDrillSetStage](../addons/infantry/functions/cortexDrillSetStage.sqf) |
| Generation-bound deferred effects | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexThrowGrenade](../addons/infantry/functions/cortexThrowGrenade.sqf); [cortexFlankStep](../addons/infantry/functions/cortexFlankStep.sqf); [operationAttackPolicy](../addons/core/functions/operationAttackPolicy.sqf) |
| Complete cross-operation chaining | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Broader combined-operation/subcontact retasking remains unfinished. [cortexGroupTick](../addons/infantry/functions/cortexGroupTick.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## LIGHTING: Automatic darkness, night vision and illumination

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Ambient/NVG/flashlight capability policy | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiLightingStep](../addons/core/functions/aiLightingStep.sqf) |
| Stable skill refresh without compounding | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiApplyProfile](../addons/core/functions/aiApplyProfile.sqf); [aiRestoreProfile](../addons/core/functions/aiRestoreProfile.sqf); [aiProfileYield](../addons/core/functions/aiProfileYield.sqf); [aiProfileReceipt](../addons/core/functions/aiProfileReceipt.sqf) |
| Shared scheduler and specialist exclusion | 1 / 1 | Scoped production path is wired in the referenced implementation. [aiLightingStep](../addons/core/functions/aiLightingStep.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## DRILL-HANDOVER: Moving flank and advance handed to Zeus

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| New order interrupts current drill | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexDrillInterrupt](../addons/infantry/functions/cortexDrillInterrupt.sqf) |
| Owned movement/settings retirement | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexFlankEnd](../addons/infantry/functions/cortexFlankEnd.sqf) |
| Settled-holder delayed handback | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Standing/support holds and all nonlocal native-command cases remain incomplete. [cortexHolderRecallOwned](../addons/infantry/functions/cortexHolderRecallOwned.sqf); [cortexHolderRecallPending](../addons/infantry/functions/cortexHolderRecallPending.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## DRILL-RECOVERY: Bound continuation and straggler rejoin

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Actual separated-actor observation | 1 / 1 | Scoped production path is wired in the referenced implementation. [recoveryStep](../addons/infantry/functions/recoveryStep.sqf) |
| Buddy/role-preserving reassignment | 1 / 1 | Scoped production path is wired in the referenced implementation. [rebalanceRoles](../addons/infantry/functions/rebalanceRoles.sqf) |
| Complete viable-bound rejoin | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Unresolved stragglers and final cohesion still need continuation refinements. [recoveryStep](../addons/infantry/functions/recoveryStep.sqf) |

Calculation: 2.5 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## COMBINED-ARMS: Contact-led combined-arms opportunity

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Fresh contact and capability requests | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCombinedArmsRequest](../addons/infantry/functions/cortexCombinedArmsRequest.sqf); [cortexCombinedArmsServer](../addons/infantry/functions/cortexCombinedArmsServer.sqf) |
| Finite ground roles and actual fire readiness | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCombinedGroundStep](../addons/infantry/functions/cortexCombinedGroundStep.sqf); [cortexGroundFireReady](../addons/infantry/functions/cortexGroundFireReady.sqf) |
| Air request/fallback and owner release | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCombinedAirFallbackServer](../addons/infantry/functions/cortexCombinedAirFallbackServer.sqf); [cortexCombinedArmsLocal](../addons/infantry/functions/cortexCombinedArmsLocal.sqf) |
| All role replacement/retasking composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete operation-wide replacement and overlapping-contact arbitration remain unfinished. [cortexCombinedGroundFallbackServer](../addons/infantry/functions/cortexCombinedGroundFallbackServer.sqf); [cortexCombinedRejectServer](../addons/infantry/functions/cortexCombinedRejectServer.sqf) |

Calculation: 3.5 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## COMBINED-OPERATION: Dynamic multi-squad combined operation

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Existing contact-led support components | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexCombinedArmsServer](../addons/infantry/functions/cortexCombinedArmsServer.sqf); [cortexSupportCoordinateStep](../addons/support/functions/cortexSupportCoordinateStep.sqf) |
| Dynamic multi-squad/asset role composition | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: A complete operation-wide role lifecycle is not composed. [cortexCombinedArmsLocal](../addons/infantry/functions/cortexCombinedArmsLocal.sqf); [cortexSupportMaintain](../addons/support/functions/cortexSupportMaintain.sqf) |
| Independent subcontact allocation/retasking | 0 / 1 | Referenced components expose the boundary but do not implement this capability. Remaining: The full intended subcontact/operation hierarchy is not implemented. [cortexCombinedArmsServer](../addons/infantry/functions/cortexCombinedArmsServer.sqf) |
| Screened transitions and operation handback | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Complete chained operation termination/relief remains unfinished. [cortexSupportStep](../addons/support/functions/cortexSupportStep.sqf); [operationRelease](../addons/core/functions/operationRelease.sqf) |

Calculation: 2 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

## ATTACK-FLARES: Attack-run approach and departure flares

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Approach/departure episode selection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAttackRunFlares](../addons/infantry/functions/cortexAttackRunFlares.sqf) |
| Actual finite countermeasure requests | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAttackRunFlares](../addons/infantry/functions/cortexAttackRunFlares.sqf); [cortexFireCountermeasure](../addons/infantry/functions/cortexFireCountermeasure.sqf) |
| Owner/feature/interruption protection | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAttackRunFlares](../addons/infantry/functions/cortexAttackRunFlares.sqf) |

Calculation: 3 implemented capability units / 3 scoped units. Acceptance is not part of this calculation.

## AIR-ATTACK: Threat-aware finite aircraft attack patterns

Source checkpoint: `8fa63881e466bb6599a6aff5a6b35815069e0e44`; reviewed 2026-10-19; confidence: low.

| Capability | Built | Implementation / remaining build gap |
| --- | ---: | --- |
| Platform/threat/ammo pattern planning | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAirAttackPlan](../addons/aircraft/functions/cortexAirAttackPlan.sqf) |
| Finite ingress/attack/egress execution | 1 / 1 | Scoped production path is wired in the referenced implementation. [airAttackOperationStep](../addons/aircraft/functions/airAttackOperationStep.sqf); [cortexAirAttack](../addons/aircraft/functions/cortexAirAttack.sqf) |
| Weapon operator and flight ownership | 1 / 1 | Scoped production path is wired in the referenced implementation. [cortexAirWeaponOperatorAvailable](../addons/aircraft/functions/cortexAirWeaponOperatorAvailable.sqf); [flightLeaseValid](../addons/aircraft/functions/flightLeaseValid.sqf) |
| Complete fallback and handback integration | 0.5 / 1 | An implemented subset exists; the named remainder is still open. Remaining: Cross-role flight controller restoration and all attack replacement paths remain partial. [cortexAirHandoverRestoreLocal](../addons/infantry/functions/cortexAirHandoverRestoreLocal.sqf); [cortexAirPilotFeatureRelease](../addons/aircraft/functions/cortexAirPilotFeatureRelease.sqf) |

Calculation: 3.5 implemented capability units / 4 scoped units. Acceptance is not part of this calculation.

