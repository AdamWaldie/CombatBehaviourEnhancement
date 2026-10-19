# Delivery goal

## Product outcome

Deliver a standalone Arma 3 AI addon that improves AI combat without taking control away from Zeus,
players, mission makers, specialist systems or native engine behaviour that is already working. The
addon must make AI more decisive, tactically useful and resilient while keeping its CPU cost bounded.

The release candidate is successful only when it provides the following in real multiplayer play:

- AI responds promptly to confirmed danger, maintains an intention while moving and stops only for a
  meaningful tactical reason.
- Infantry can advance, flank, support, assault, withdraw, recover from losses and hand over to a
  newer Zeus or mission order without movement churn, rally loops or abandoned state.
- Nearby groups coordinate through short-lived opportunities: one group can support while another
  manoeuvres, but every group retains its own route, safety sector and ownership.
- Buildings are entered and cleared through physically reachable positions. A blocked route is
  reported as incomplete; it is never fabricated as complete.
- Vehicles drive safely as ordinary units, while registered convoys stay single file, preserve
  operational passengers, recognise real roadblocks and recover only through physical actions.
- Aircraft choose only attacks their loaded weapons and flight geometry can support, conduct a
  credible ingress, release and egress, and yield immediately to a player, Zeus, landing or another
  valid flight owner.
- Support features, casualty handling and compatibility handovers use the same finite operation
  lifecycle and do not create a second movement owner.
- All work is locality-aware, headless-client safe, JIP-safe and visible in diagnostics.

## Non-negotiable operating rules

1. **One movement owner.** Every operation records its owner, generation, participants, route,
   physical progress and cancellation reason. A later Zeus, player, mission or compatible specialist
   order invalidates CBE work before it issues another movement command.
2. **Continuous intent.** Planning may be delayed under load, but current physical movement and
   immediate danger response are never delayed behind a scheduled rally, grenade animation or an
   unreachable straggler.
3. **Physical recovery only.** Recovery may wait, refresh a route, reverse cautiously or select a
   local alternative. It cannot teleport, repair, unflip, disable collision or bypass a meaningful
   player roadblock.
4. **Bounded cost.** Event handlers collect small observations; the shared owner-local scheduler
   performs bounded work. No global per-frame scans, permanent per-unit movement loops or repeated
   destination issuance.
5. **Evidence before promotion.** A configuration flag, queued job, accepted order or static test
   never proves behaviour. Promotion requires the exact packaged candidate to pass physical audit
   cases.

## Current execution order

1. Stabilise danger and operation FSM decisions, native-order ownership, scheduling and synchronous retirement. Trace the real action writers behind each FSM state.
2. Examine the complete driving reference and build its suitable methods into shared bounded primitives. Include predictive obstacles, gates, traffic, navigation areas, jam negotiation, crew policy, recovery, diagnostics and controls. Give every method an explicit adaptation, redesign or rejection decision.
3. Prove ordinary driving and registered convoy behaviour separately. Mixed vehicle response and physical roadblocks must be part of the design.
4. Complete individual combat response, cover, recovery and dynamic building movement, then compose paired and squad behaviour.
5. Expand communicating squads, independent contacts and combined arms through suitable effects and finite ownership.
6. Complete specialist compatibility expansion after the behavioural foundations. Custom melee, droid and zombie controllers are compatibility-only and earn no general tactical completion credit.

Zeus controls are part of these work packages. Reuse the production executor and authoritative request path. Operator controls need clear selection, current-state feedback and safe interruption. Do not expose unavailable behaviour as a working control.

This order changes priority, not product scope. Existing Zeus, player, external-owner and locality safeguards remain mandatory. Source comparison must examine called mechanisms and changed intent. Physical acceptance remains separate from offline checks. Audits are held until the user resumes them.

## Work packages and exit criteria

| Package | It is complete only when… | Current position |
| --- | --- | --- |
| 1. Core danger and lifecycle | The owner-local danger FSM, operation lifecycle and scheduler preserve native knowledge, react within the configured cadence, release cleanly on ownership change and show bounded diagnostics. | Implemented; static/package checked; physical reaction, interruption and performance cases pending. |
| 2. Infantry tactics | Advance, bounds, flank, assault, withdrawal, surrender and recovery maintain progress with casualties and stuck actors, preserve fire lanes and hand off instantly to Zeus/new orders. | Partly repaired; static checks only; live manoeuvre, casualty and interruption acceptance pending. |
| 3. CQB and garrison | AI enters, traverses, clears or holds reachable building positions across models and squad sizes, rotates survivors and explicitly reports unreachable rooms. | Native ownership corrected; topology and physical building acceptance pending. |
| 4. Driving and convoys | General driving and registered convoy logic are separately configurable, use native routes, preserve a single-file column, classify stops and respect roadblocks, passengers and external owners. | Convoy repairs exist; general driving and all terrain/obstruction acceptance pending. |
| 5. Aircraft, vehicles and support | Capability-valid weapon selection, attack geometry, countermeasures, air-to-air response, artillery warnings, medical help and delivery operations produce real outcomes without competing flight or movement owners. | Design and partial implementation exist; physical weapon, target-effect and handover acceptance pending. |
| 6. Coordination and compatibility | Nearby groups form useful, temporary supporting/manoeuvring relationships without compacting onto one point; affected specialist actors hand over immediately and ordinary actors remain eligible. | Ownership boundaries exist; coexistence acceptance pending. |
| 7. Multiplayer and performance | JIP, locality transfer, headless ownership and server-enforced settings remain correct. Matched 50-group baseline comparisons remain within 5% median and 10% p95 frame-time overhead, with no growing queue or command churn. | Static safeguards exist; no physical benchmark has passed yet. |
| 8. Release evidence | The signed package exactly matches the candidate tested in four batched audits: infantry/CQB, vehicles/convoys, air/support, and compatibility/multiplayer/performance. Remaining failures are visible and block promotion. | Not started; game runs are currently paused by request. |

## Status vocabulary

- **Designed:** behaviour, ownership and acceptance rules are specified.
- **Implemented:** production code exists but has not yet cleared all checks.
- **Statically checked:** source, configuration, packaging and regression gates passed.
- **Physically accepted:** a fresh packaged dedicated-server/client audit demonstrated the required
  in-game outcome.
- **Promoted:** all required physical and performance gates for the package have passed.

No work package may skip directly from **implemented** or **statically checked** to **promoted**.

## Combining reference behaviours

The reference collection exists to combine unique capabilities, effective decisions and working improvements into one coherent addon. Preserve useful intent while redesigning unsafe shortcuts and conflicting ownership. Each selected contribution needs evidence of implementation, interaction with existing layers, balance, bounded cost and actual physical effectiveness. Reviewed, selected, implemented, integrated and physically verified are separate milestones. A file association or narrow fixture cannot establish source parity, and parity alone is not proof of an improvement.

Driving room-making must coexist with continuous following: stopped participants acknowledge applied holds, settle physically, make real rear-first room, pass only through usable hull clearance and hand back every original route. Queue agreement alone provides none of those outcomes. Keep this operation inside the existing owner-local driving lifecycle; a generic takeover that cancels its own parent is not an implementation.

## Build upward from shared foundations

Implementation order follows the user's explicit clarification: shared ownership/admission, interruption and exact restoration first; then scheduler/FSM lifecycle and bounded movement/sensing primitives. Build individual behaviours on those contracts, then buddy/pair flow, squad roles, multi-squad coordination and combined operations. Compatibility expansion stays last. Source functionality and intent should reinforce these layers rather than add competing controllers.

The next foundation gap is consistent actor settings ownership: captured baseline, applied value, issuer generation/epoch, current-owner permission, refused-release retention and finite handback must have one shared contract. The current operation restoration primarily handles group attack policy; feature-specific speed/posture cleanup remains fragmented. The new clearance settings release is an interim repair, not completion of that shared foundation. Build-out estimates describe scope; they do not set the implementation order.

## Behavioural foundation and source integration

Implement the useful functionality and tactical intent of the reference danger system within CBE, then evolve it with suitable contributions from the other reference mods. Preserving the upstream code or architecture is not the objective. Trace decisions through their actual action writers and repair missing or regressed functionality before layering further behaviour.

Integrate useful methods into shared owner-local primitives and one coherent decision/execution lifecycle. Resolve conflicting movement, sensing, settings and task ownership. Build upward through individual behaviour, buddies, squads and combined operations. Maintain useful source functionality and improve reliability, balance, mission control and physical behaviour while bounding scheduler, sensing and network cost. Extra controllers and feature counts are not improvements by themselves.

The implementation register guides source examination and integration; it is not the product architecture. Maintain the better behaviour as code evolves. Audits remain paused while implementation proceeds.

## Current delivery direction

Deliver the full CBE scope described above through this order:

1. Establish shared owner-local admission, ownership, interruption and exact restoration, including mission edits and required external-controller handovers.
2. Complete danger and operation FSM execution, scheduler lifecycle and bounded movement/sensing primitives. Every decision needs a working action and a finite interruption/cleanup path.
3. Build reliable individual combat, driving and building behaviours on those foundations, followed by buddy flow and squad roles.
4. Compose coordination, convoys, aircraft, support and combined operations without introducing competing controllers. Retain the complete product scope; this order is not a scope reduction.
5. Integrate reference functionality by useful outcome, balancing unique capabilities, reliability and execution cost. Prioritise the complete primary driving reference implementation and reference danger functionality. Specialist compatibility expansion remains last.
6. When audits resume, physically validate the exact candidate, repeat use, Zeus authority, multiplayer/JIP/HC handovers and the 5% median/10% p95 frame-time overhead budget. Current audit pause remains in force.

Report build-out and physical acceptance separately. Do not claim whole-mod superiority from source counts, package checks or an isolated successful scenario. Continue implementation while audits are paused; do not substitute acceptance paperwork for working improvements.
