# CBE completion status

Checked against the feature registry and local build evidence on 18 October 2026.
CBE is not production-ready. All **65 feature families remain partial; 0/65 have full acceptance**.
This is an acceptance count, not a claim that implementation is zero percent. The former
implementation percentages were withdrawn because source inventories, registration and offline
test counts did not measure delivered AI behaviour. No defensible overall implementation or
Workshop-parity percentage is available.

## Current evidence boundary

- Normal wheeled convoy QA now prepares rapid public HALT/resume replacement followed by old-FSM retirement, newest applied-cap checks and every vehicle travelling 25 m forward. The fixture is unrun and does not prove every race timing, HC or physical acceptance.

- Refused passage creation/progress/retirement now returns explicit DEFERRED. ConvoyTick stops before consuming refused caps or treating work as ended, retaining prior applied controls for the existing next tick. Physical response and performance remain unverified.

- Previously passed corridor/bypass vehicles now recheck current crew and full hull beyond the exit plane. Returning hulls lose current clearance credit and re-enter existing observation/cap logic without renewed deadlines. Physical reversal, delayed geometry freshness and added bounded cost remain unverified.

- New convoy corridor/bypass passage proposals now publish only while original owner, lead work, route, terminal result, gates, deadline and empty slot remain current. Geometry is prepared separately; physical crossing quality and aggregate cost remain unverified.

- Corridor/bypass tail progress now uses copied rows and publishes only under unchanged episode/owner/original-row context. Bypass capture history commits with those rows; rejected proposals cannot overwrite successor progress. Active creation, geometric freshness and runtime/performance remain unverified.

- Corridor/bypass cancellation now carries captured episode and owner-context receipts. Retirement atomically rechecks current episode/brain/job/epoch/registry before result publication and deletion, preserving retained or replaced successor work. Active passage creation/progress and physical cancellation/cost remain unverified.

- Convoy release retains original brain/job/epoch/registry/local-state/baseline and guards group, per-vehicle and final restoration transactions. FSM release passes its expected job token. Physical cancellation, handover and cost remain unverified.

- Convoy FSM final retirement now rechecks original brain/job/registry after cleanup before clearing brain/FSM slots. A replacement keeps its slots. Cleanup-internal policy/path writes and physical handover still require review and validation.

- Convoy FSM callbacks now recheck original owner epoch, brain/job/configuration and registry after the physical tick and atomically before phase/counter/next-step publication. Replaced callbacks retire without publishing those results. Physical interruption and cost remain unverified.

- Shared convoy command admission now binds the original brain/configuration, job token, registry revision and owner epoch. Lead/follower smoothing cap records publish with admitted speed commands rather than rejected proposals. Mixed-column stop/start and measured cost remain unverified; spacing tuning is unchanged.

- Queue discovery now claims and publishes under the original driving brain/epoch and unchanged traffic observation/retry records. Scheduled discovery cannot adopt a replacement brain for consent submission. This supplies no native queue execution or physical acceptance.

- Recovery retirement now rechecks the selected live teammate identity and both actors at publication, retaining existing 12 m/1.5 m vertical cohesion limits. Stale rally coordinates cannot prove rejoin. Physical navigation and performance remain unverified.

- Separated-actor recovery now copies retry rows and admits each command/attempt journal under the current child, phase and native actor context. Issued attempts persist even if later roster publication yields. Final recovery publication is guarded; physical rejoin freshness and measured cost remain open.

- Arrival-stage and post-grenade clear-through commits now recheck the original physical arrival witnesses against assigned ASL targets, retaining existing quorum, 3 m range and 1.5 m floor tolerance. Departed, transported or unavailable witnesses defer progression; runtime flow and overhead remain unverified.

- Ordinary bound-arrival stages and pause deadlines now publish together under current child/owner, MOVE identity, roster/team and spot checks. Smoke and assault preparation remain scheduled after admission. Physical arrival freshness and tactical flow remain unverified.

- Assault clear-through now rechecks its original MOVE identity, child/owner authority, roster, route, objective and assault feature after grenade preparation before advancing START/index. Refusal defers; movement retains separate admission and physical flow remains unverified.

- HOLD assault-route publication now rechecks current phase, roster, route, native actor tasks, feature and reported objective after scheduled avenue selection. Refused proposals defer without publishing an assault or replacing their retry delay with immediate rescheduling. Physical timing remains unverified.

- Consolidation enrollment and its pending START now commit together after current task, roster, route and actor-native checks. Refused issue cannot leave HOLD falsely eligible for completion. Physical follow-through and tactical layout remain unverified.

- Elapsed manoeuvre PAUSE commits its next index/turn and START phase together under current-task checks.
  A refused movement issue retries the pending bound rather than advancing PAUSE again. Physical continuity remains unverified.

- Consolidation actor lists no longer shadow the support-mode boolean read by movement helper
  CODE through SQF dynamic scope. This removes a concrete array/boolean input hazard during
  follow-through; actual consolidation and its remaining task transitions still need physical validation.

- Arrived-phase smoke/fragmentation requests now carry their original group/drill/generation/epoch.
  Queue admission, delayed aiming and final native release refuse a replaced parent instead of
  adopting its new token. Existing selection/safety rules remain; physical throws remain unverified.

- MOVE quorum/straggler recovery, replacement preparation and failure feedback now recheck the
  committed bound records, current tasks/route and fresh arrival/blocked motion before publication.
  Refusal defers; later arrived-phase side effects and physical behaviour still require review/validation.

- A delayed manoeuvre callback no longer marks a newly retried actor stalled immediately. The sole
  admitted retry receives the existing eight-second observation interval; physical progress clocks
  and the fixed bound deadline remain unchanged. Expired bounds issue no retry; live timing remains unverified.

- Manoeuvre feature restoration and recovery team reassignment now use current-context helper
  transactions. Refusal defers instead of restoring over a replacement or reporting recovery losses.
  This does not complete later phase bookkeeping, native acknowledgements or physical acceptance.

- MOVE arrival holds and one-shot retries now commit with copied progress/retry observations under
  the current bound, task and actor-native context. Current waypoint metadata and fresh arrival/motion
  checks must still match; refused proposals spend no retry. Physical interruption remains unverified.

- Manoeuvre progress now measures actual 3D approach/travel and checks the arrival floor band.
  Recovery targets an actual eligible teammate, preferring the buddy, instead of a centroid that
  can fall between floors. Legacy record conversion preserves clocks; terrain/building behaviour remains unverified.

- Drill cleanup now commits its actor/group restoration, handler removal, formation/hold writes and
  feedback under the same current state/token/epoch/generation check. Shared operation release
  remains separate, followed by guarded terminal retirement. Physical cleanup and cost remain unverified.

- Finite manoeuvre cleanup now carries the original child drill token instead of selecting a newer
  drill from a mutable state map. Stage/parent-phase/history publication also atomically requires
  the current child token. Complete cleanup interleavings and physical handover remain unverified.

- Main manoeuvre bound geometry is now prepared before an atomic movement/cover commit. Current
  point, roster, phase, operation/epoch, support role and actor-native observations must still match
  before commands and bound journals publish. Refused proposals defer; physical timing remains unverified.

- Manoeuvre casualty roster proposals now remain private until current drill membership, phase,
  operation/epoch, support role and actor-native observations pass one publication transaction.
  Refused observations defer without cleanup or renewed deadlines; physical refill remains unverified.

- Shared manoeuvre admission/cleanup, medical assistance and stance control now preserve malformed
  or nonfinite actor reservations through the strict owner-local predicate. Stance release for known
  tasks also requires a fully typed record. Physical service interruption and restoration remain unverified.

- Coordinated bounds now match both group and reservation token when retaining active turns.
  Superseded turns disappear without imposing a retry penalty on the replacement; public roles,
  aborts and retry writes recheck the live lease atomically. Network/HC replacement remains unverified.

- Convoy audit capture now retains bounded actual native-command issue histories, including pre-command
  pose, remaining destination distance, elapsed issue age and reason. Normal driving gains no new
  command or tuning. The prepared fixture logs unseen events; mixed-column causation remains unresolved.

- Coordinated bound admission now checks current state, gates, role/lease, actor availability and
  owner epoch in one unscheduled allocation transaction. A superseded scheduled observation cannot
  create a new local drill. Network cancellation delivery and physical takeover remain unverified.

- Manoeuvre casualty and recovery transfers now prefer an unpaired survivor, then a whole buddy
  pair when donor cover can remain. Minimum surviving movement/cover capacity takes priority.
  Physical refill continuity and interruption remain unverified; no runtime acceptance is added.

- Coordinated bound teams retain eligible existing battle buddies together before balancing remaining
  actors. All available roles stay enrolled; pair cohesion may produce unequal teams. This changes
  roster composition only: physical buddy follow-through, casualty refill and tactical quality remain unverified.

- Coordinated bound selection now uses strict owner-local actor reservation validation. The server
  never expires a nonempty nonlocal reservation from its own clock; remote empty markers are only
  planning candidates, with final admission retained on the group owner. HC timing remains unverified.

- Audits are paused by the user. No new in-game result is claimed here.
- Current driving source adds current-position passing joins, live return monitoring, return-entry timing and gradual static-bypass ramps. Bypass path issue and retirement use unscheduled authority checks. Native queue negotiation, stopped-merge recovery, subsystem-off cleanup observation and measured steering/performance remain incomplete.
- The last independently verified signed Release source remains `48a77bb`, predating the current CBE work. Its complete Release build and fixed-key signing passed; nine signatures verified and nine damaged controls were rejected again after ZIP extraction. These package checks add no behaviour acceptance.
- Recent source changes protect actor ownership across smoke, drill refill, coordinated support, crew replacement and airborne exits. Airborne execution/cleanup uses insertion episodes. CQB preserves unchanged owned MOVE through native readiness changes; opt-in bounded entry diagnostics and stronger independent visit geometry prepare later investigation. These effects remain physically unverified.
- The `a48a6ad4` implementation checkpoint passed **1186 tests** and all sequential offline gates.
  Subsequent checkpoint logs and scoped limits are recorded in `AGENT-HANDOVER.md`; this count is not physical acceptance.
  The current batch adds authenticated combined-ground failure replacement, exact role/operator authority,
  owner-epoch application receipts and durable destination/recovery journals. Active route changes retire
  movement; capability checks retain the original expiry. Routine ground gunnery yields to the live role.
  These offline results provide no new physical or performance acceptance.
- Routine vehicle targeting now tries bounded lower-ranked usable contacts. Driving discovery includes nominal approaching traffic, and native bend hints use path distance instead of node count. Sampled downward undersides retain solid constraints. These changes have offline coverage only.
- Infantry suppression now requires the selected loaded primary bullet muzzle and muzzle-specific nonempty spare magazines. Garrison posture recovery preserves the immediate prior stance only under unchanged assignment/ownership and live building transform; it yields to movement, native service and actor reservations. These source fixes have offline coverage only.
- Fire authority, reserve rejection and real-fire garrison recovery/repeat fixtures are prepared but unrun. Fixture improvements do not retroactively resolve historical audit failures or establish current physical acceptance.
- The normal convoy matrix now records actual lead/follower constraint chains. Mixed-column stop/start causation, native queue recovery, expanded traffic-query cost and physical steering/braking remain unresolved. Source reviews retain explicit gaps and no whole-mod parity credit.
- Ground support checks loaded target-suitable station ammunition before manoeuvre commitment and again
  during travel and arrival. Protected individual tasks and strict actor reservations prevent competing
  gunner orders. Routine vehicle direct fire also checks the shared friendly/civilian firing cone.
  Infantry fire control now uses the same strict reservation predicate as movement admission.
- The prepared combined-arms fixture records local gunner FiredMan events with native projectile
  origin/velocity, admitted operator/token and direction toward the reported contact. This can establish
  directed shots when run; it cannot prove hits, suppression, destruction or HC observation coverage.
- Delayed defence arrival/retry now checks its exact assignment and issued destination, retiring changed individual commands without movement restoration. Owner adoption now checks published MOVE/HOLD receipts and native route identity; physical migration remains unverified.
- Defence release now requires matching command receipts before watch/formation restoration. Admitted replacement tasks suppress predecessor recall; reserve selection requires a physically nearby owned HOLD. Repeated transitions remain physically unverified.
- Defence reserve planning now rejects overlapping reinforcement slots before assignment changes and excludes busy/reserved actors. Its physical reinforcement and casualty flow remain unverified.
- Defence admission now also refuses changed native/individual orders, task generations or ownership during geometry planning, before old-task cleanup. Reserved actors are excluded from its layout. Offline checks passed; physical interruption remains unverified.
- Experimental passing now preserves pull-out headway during qualification, checks complete oriented hull separation before return, and predicts measured traffic courses against the pass corridor. Discovery covers a nominal 35 m/s approach over the proposal duration, up to 1,250 m; faster modded traffic and measured query cost remain limitations. The Altis normal-only roadpassing fixture and convoy startup observations are prepared but unrun.
- Explicit road-pass cleanup now requires the unchanged authored route and current ownership exclusions before restoring commands. Active consent is context/expiry-bound. Default-off experimental automatic passing now has finite observation/preparation/consent admission; negotiated head-on jam discovery remains unimplemented. Physical and performance acceptance are outstanding.
- Alternate driving admission and gate intent now compare full 3D native destinations. Bypass execution/handback also checks both seat command types; asynchronous propagation, identical commands and physical interruption remain unverified.
- Stationary engine-off vehicle hulls with no living crew now reach the existing finite bypass planner. Occupancy/engine/attachment changes invalidate work; independent traffic caps remain. The normal-only parkedbypass focus now prepares actual empty/wreck passage and native boarding during active work. These cases remain unrun; bypass and interruption are physically unverified.
- The focused `indooractors`, `indooractorshc` and `indoornatural` fixtures are prepared but unrun.
  Natural admission now runs through the contact decision fallback; its existence is not entry evidence.
- Permanent-key signing is configured with a pinned public fingerprint, independent signature checks
  and damaged-signature rejection. The earlier signed artifact predates subsequent behaviour changes;
  do not treat it as the current source package or as tactical acceptance.
- Recent source changes include bounded incremental CQB egress planning with pending-worker
  adoption, target-owned interior observations, current settlement checks, native-task handover
  guards and shared belief-based building-contact selection. They remain physically unverified.
- Retained narrow physical clearance evidence from candidate `f9c3d7d`: two-person
  and six-person fixtures completed their covered room visits. Twelve-person clearance remained
  incomplete; the completed batch retained 13 findings, including casualty-entry failures.
  These results do not validate later changes,
  repeated clearance, hostile-room safety or universal placed/modded-building access.
- Native/Zeus task ownership, separate normal/HC migration, effective combat and the
  **5% median / 10% p95 overhead limits remain unaccepted**.

The [65-family acceptance depth register](../releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md)
provides each intended result, source/fixture wiring and retained evidence. Its source/setting
counts are inventory only. [Historical notes](COMPLETION-HISTORY.md) preserve earlier batches,
failures and superseded statements; they must not be read as current status.

## Implemented areas and remaining acceptance

Every row below remains partial. Presence of a controller does not establish its effectiveness.

| Area | Source present | Main unresolved requirement |
| --- | --- | --- |
| Core and operation lifecycle | Shared scheduler, generations, owner epochs, cancellation, native-order receipts and finite operation FSMs | Complete interruption, migration, JIP, queue stability and restoration evidence |
| Danger and individual reactions | Engine danger FSM, bounded observations, cover, stance, suppression and immediate reactions | Full source response-depth parity, correct intake and physically effective responses without competing movement |
| Infantry manoeuvre | Pairs, advance, flank, assault, defence, withdrawal and recovery controllers | Coherent physical movement/fire, casualty replacement, straggler handling and repeated transitions |
| CQB, traverse and garrison | Building FSM, native positions, entry/floor progression, reserves, finite failures and egress | Repeatable access/progression across buildings, complete participation, isolation and useful consolidation |
| Individual indoor engagement | Fresh-belief selector, native context observation/escalation and actor reservation infrastructure | **Actor-local indoor executor and bounded natural fallback are wired but physically unverified**; normal and real-provider HC fixtures are unrun; natural-dispatch and physical validation remain |
| Multi-squad coordination | Communication eligibility, support opportunities and finite role assignments | Dynamic lanes/sectors, subordinate contacts, reinforcement, casualties and broad-front execution |
| Combined arms | Contact-led support, vehicle/aircraft capabilities and direct-fire safety | Effective coordinated effects and transitions in balanced damage-enabled battles |
| Driving and convoys | Owner-local driving/convoy FSMs, terrain/traffic observations, predecessor trails and spacing control | Mixed tracked/wheeled stop/start, obstructions, step-off/braking, recovery and actual route handback |
| Crew and passengers | Finite seat/task ownership, dismount/remount and boarding checks | Every command/locality transition and physical continuation |
| Aircraft | Attack/flight ownership, ingress/egress, aiming, defensive and landing/braking controllers | Workable weapons/profiles, real effects, clearance, air-to-air manoeuvres and controller handovers |
| Artillery and support | Artillery FSM, observers, smoke, counter-battery, medical/ammunition and delivery work | Timely physical outcomes, safety, uncertainty, interruption and cleanup |
| Zeus and multiplayer | Native/optional ZEN behaviour tasks, CBA configuration, owner dispatch and HC bridge | Complete authoritative payload/execution, JIP, disconnect, migration and successor-order acceptance |
| Specialist compatibility | Detection/exclusion and partial ownership adapters | Real external-controller handovers; detection alone does not qualify |
| Performance and release | Bounded scheduling/caches, validators, builds, package seals and benchmark fixtures | Matched infantry/mixed/combat measurements, stable queues and exact tested-package promotion |

## Workshop source and intent comparison

| Reference scope | Current disposition |
| --- | --- |
| Complete driving reference suite | Substantial helper/caller reviews and partial counterparts; complete semantic parity, native traffic negotiation/overtaking and real handover remain open. A reviewed helper or registered setting is not implementation credit. |
| Danger, individual assault, memory and task reference modules | Separate active individual engagement from explicit group CQB and helpers without proven incoming callers. The individual executor is staged; automatic admission remains missing; the normal and HC interruption/repeat fixtures are unrun. Retain useful native paths and knowledge; do not import hidden-target transforms, random/proximity clearance or teleport recovery. |
| Other tactical/driving/support references | Compare actual call chains, intent, authority and cleanup across the whole source family. Large suites still have untapped or unproven mechanisms; file association cannot establish parity. |
| Preserved tactical/driving references | Preserved source archive remains the reference. Previously recorded missing original PBOs are not silently treated as recovered; preservation is separate from implementation. |
| New reference modules | Evaluate general behaviour support, not CQB alone. Consolidate shared task intents and expose only options the production executor actually supports. |
| Melee, droid and zombie specialists | Compatibility-only. Excluded from general tactical implementation/parity credit; broad compatibility expansion stays last. |

CBA owns settings. Zeus/ZEN modules issue behaviours. Explicit optional Garrison teleport
placement is permitted; it does not permit teleport CQB, routing or recovery.

## Progression blockers

### B1: runtime integrity

Require exact-candidate mission entry, valid fixture dependencies and no SQF/fatal errors.
Classify native warnings with independent same-process evidence; a clean package alone is
not a clean behavioural run. Retain earlier failed/incomplete findings.

### B2: danger and ownership

Finish individual decision/execution ownership before composing larger operations. Verify
newer native/Zeus orders, exact stance/movement cleanup and disabled-state release. CBA
disablement does not unload the configured danger FSM: addon-absent baselines remain required.

### B3: infantry and building continuity

Integrate and validate the staged finite actor indoor operation, then prove pair/squad movement, physical
entry and connected floor/room progression, casualty replacement, unreachable outcomes,
isolation, egress and repeated task flow. Shared node visits cannot prove each actor entered
or that a hostile room is safe.

### B4: coordination and combined arms

Compose accepted individual and squad actions through communication, dynamic roles, lanes,
subordinate contacts and finite support. Prove useful suppression/effects, casualty responses
and transitions at larger scale; the small fixture frontage is not a production scale limit.

### B5: vehicle and aircraft effectiveness

Complete driving before fleet behaviour, with mixed-mass acceleration/braking and safe native
traffic/recovery. Prove crew/passenger flow, weapons, flight geometry, physical effects and
handovers. Source crawl/physics shortcuts do not qualify as recovery improvements.

### B6: multiplayer and specialist handover

Prove real provider registration before crediting its transfers. Exercise each operation phase,
JIP, disconnect, player/Zeus takeover and external-controller release. Keep normal and HC
batches separate. Broader specialist compatibility follows the behavioural foundations.

### B7: performance and release

After physical behaviour and ownership acceptance, run matched infantry, mixed and combat
measurements against native controls. Establish queue stability and the 5%/10% limits, then
promote the exact tested signed package. Offline tests, counters and package seals cannot
replace any of these gates.

## Update rule

Record source implementation, offline validation, narrow physical evidence, retained failures
and full acceptance separately. Each new physical claim must identify the tested candidate,
fixture, owner mode and saved outcome. Never increase completion from a test count, file count,
accepted command or review count. Preserve failures until stronger matching evidence resolves
them. [Implementation progress](IMPLEMENTATION-PROGRESS.md) contains detailed dated work;
its older snapshots do not override this page.
## Current implementation work: offline evidence only

The incremental notes have been consolidated below. None of these changes adds accepted
behaviour or establishes the runtime performance budget. The latest full offline build passed
1022 tests, compilation/lint and the sequential repository gates, producing nine PBOs.

| Area | Implemented source | Remaining evidence or execution |
| --- | --- | --- |
| Actor reservations | Admission, clearance workers/reserves, Garrison/Defend, common operation progress/recovery and release paths share typed finite reservation checks. Recovery commits its live retry budget and guarded native command in one unscheduled boundary; suspended actors do not create failed-path quarantine. Recovery observations for ineligible participants retire before timeout processing, retaining spent attempts and using a current-position baseline on return. Unknown/live markers retain ownership. | Physical handover and interruption under reservations. Progress now retains committed participant and fallback foot/vehicle domains; boarding, vehicle switches, replacement enrollment and migration need live validation. |
| Deferred movement | Defend retains reserved arrival jobs without consuming retries. Garrison retains its original deadline. Post-clear changed-waypoint handover retains reserved STOP actors and preserves newer individual orders. | Physical reservation expiry, locality migration and repeated task flow. |
| Casualty refill | Garrison alternate exit cover must be physically settled, locally eligible, unreserved, on foot and idle/stopped before an exterior guard is promoted. CQB ranks replacements near the surviving buddy and protects sole exit cover. Delayed reserve admission now retains episode-bound native command/formation-leader receipts and rechecks eligibility before promotion. Dead, unavailable or early-exited historical entrants no longer preserve a reinforced lane's entry state. Filtered room workers map mover and motion state back to original actor slots. Lone exterior survivors also retire stale entry state without needing a reserve promotion; normal physical regression fixtures for both casualty slots are prepared, unrun. | Real casualty replacement and continuous exterior isolation. Alternate observers now need actual body heading within 75 degrees of the assigned watch point before the existing fresh geometry check; turning/contact timing is unverified. |
| Convoy pacing | A reversing follower no longer counts as forward progress for a stretched column. Existing closing caps, smoothing and finite recovery remain. | Mixed tracked/wheeled step-off, stop/start, gaps and reverse recovery. |
| Road-pass proposals | Bounded road discovery preserves ASL geometry and each vehicle's road-segment lane offset. Smooth pull-out requires room before the predecessor hull; the guide returns to the original lane and remains within its travel budget. | Actual road/vehicle variants, native steering feasibility and automatic admission. |
| Pass geometry/traffic | Overlapping 12-station support/body/oriented-footprint samples have a 243-ray maximum per call and 20 m half-length bound. Fresh bounded traffic observations include dead/parked hulls and approaching traffic. Dense or stale results refuse. | Continuous swept-volume proof is not claimed. Live support, bends, traffic prediction and measured scan cost remain unverified. |
| Pass preparation | Crew, locality, native orders, guide and time/travel budgets are bound to finite caller-owned work. Geometry slices precede a final traffic observation. The original two-second preparation deadline never renews. | Runtime scheduling/expiry, physical correctness and performance. READY_PROPOSAL grants no movement authority. |
| Pass consent | Authenticated server BEGIN/ACK/RELEASE, distinct expected-owner replies, unique tokens and exact-token shutdown cleanup are implemented. The private 32-pair registry uses localNamespace; ACK checks only its own pair. | Normal and real-provider HC exchange tests remain unrun. Pass execution and default-off automatic admission are prototyped; both remain physically unverified. Consent grants no priority or collision exemption. |

| Pass execution | Default-off experimental admission observes sustained slow traffic and runs one finite preparation per owner, requiring real broker consent. Begin/Step/Finish work runs through the existing ordinary-driving FSM and sole speed writer. OUT, measured separation, bounded return scan, RETURN and DROP_BACK retain the original deadline. | Unrun prototype. Exact inherited-leg cleanup is prototyped through adoption, existing driving callbacks and bounded discovery; delayed replication and real HC transfers remain untested. A finite group STOP observer now vetoes native recall for observed interruptions. Repeated identical STOP delivery and own-event timing remain unverified. Physical pass, abort, handback and performance acceptance remain open. |

Audits remain paused. All physical acceptance and the 5% median / 10% p95 overhead requirement
remain open. The sealed signing artifact is a separate historical candidate; later source work
must not be represented as included in that artifact.
## CQB native movement adoption - 2026-10-18

Clearance now records episode-bound native MOVE/physical STOP metadata and adopts matching interior work during true owner resume. Adoption checks actual command, destination or held position, current operation membership, building transform, route and immutable visit context; it does not replay orders, extend deadlines or award visits. Terminal/explicit release retires only the original receipt. Existing room callbacks coalesce acknowledged motion records, without a new scheduler or world scan. Native acknowledgement timing, casualty-roster replication, physical migration, coherent entry and runtime cost remain unaccepted; audits remain paused.

True CQB resume now prefers eligible members of the matching common CLEAR roster over separately replicated buddy metadata, and rechecks roster/visit snapshots before committing admission. Casualty promotion records its existing owned MOVE or physical STOP within the same local transaction as participant publication. Cross-machine receipt delivery is still not atomic; delayed/missing replicated state and physical migration remain unaccepted.

Locality cleanup cancels and removes the common operation before discovery resumes clearance. A separate visit-context roster journal now preserves eligible entry selection across that path. Initial admission and casualty promotion publish it under current operation guards; resume verifies its exact episode and unchanged snapshot before acquisition. Terminal and explicit release retire only a matching episode. The journal does not authorize movement, restore commands or renew lifetime. Discovery already retries unapplied clears; network ordering and physical adoption remain unverified.

Locality checkpoint mover recall now requires the exact finite 3D destination of an actual MOVE, with no active durable clearance or actor reservation. Later STOP/idle/combat tasks no longer inherit old drill movement ownership. Exact PATH-holder release remains separate. Source review confirms OperationRestore does not restore old-owner settings on OWNERSHIP_LOST; physical locality behaviour remains unverified.

Calm cleanup restores PATH only with the actual legacy support marker; ordinary drill holders no longer enable PATH. Search-team return is restricted to movement/hold command classes and yields to active clearance, Zeus, external control, reservations, mounted or ineffective actors. Exact search MOVE/neutral hold provenance remains incomplete, so this does not establish complete handover safety or physical continuation.

Investigation/search now records per-actor destinations only after admitted native MOVE issue, with current group state/epoch/route and actor-task guards. Checkpoints retain bounded receipts. Contact, search completion and calm handback require the actual MOVE or completed idle destination within0.25m3D and unchanged authored route, preserving newer STOP/service/MOVE tasks and clearance. No replay or new scheduler is added. Physical transition/migration and native acknowledgement timing remain unverified; neutral holder provenance is still incomplete.

Search/contact and calm formation handback now commit ownership checks and native recall within the same unscheduled block. Tick handback verifies the current state and leader; calm handback selects a current combat-effective anchor. This closes a scheduled check/write gap without a new worker, but does not prove physical migration or neutral-hold provenance.

Gate opening now commits final authority checks and animation atomically: original request expiry, actual crew/owners/native services, live convoy revision/TRAVEL membership, route, locks, pose and unchanged animation phases must remain valid. Concurrent opening records are rechecked without geometry queries in the commit. Gate automation is partly implemented; directional passage, automatic closure, unknown gate models and physical braking/passability remain incomplete.

Passing negotiation now refuses live or malformed queue consent. Queue validation uses an explicit internal eligibility mode while retaining its independent passing-consent refusal, preventing overlapping pending/agreed roles. Expired well-formed queue consent does not indefinitely block passing. This is negotiation exclusion only: queue HOLD/READY/reverse/dependency execution remains unimplemented.

Ordinary rear-path recovery now records its start pose/direction and rejects native turns over20degrees, forward displacement over1m, rear travel over10m or lateral departure over2.5m. Missing inherited pose proof also retires the rear leg. The existing exact route handback retains original deadlines, with a zero safety cap during rejection. This constrains a rear MOVE; it does not establish native reverse capability, queue room-making or continuous collision safety. Physical wheels/tracks/slope testing remains outstanding.

Native driver/commander locality now offers pending driving cleanup through the existing actor init/Local handler, covering crew arrivals after the vehicle adoption lookup expired. Passengers and nonlocal vehicles cannot register through this path. The same finite lookup and exact cleanup checks apply; no rear leg or movement deadline is renewed. Receipt delivery with no later locality event remains unresolved, and physical owner/crew timing remains unverified.

Tracked reverse release now checks the exact published reverse and command records in the same unscheduled block as native STOP/turn retirement. Local progress edits use copied arrays rather than mutating public records before commit. Replaced episodes retain their controls and metadata. Native start/steering commit boundaries and physical reverse remain under review; this is not queue execution.

Tracked reverse START and steering now commit native commands with current operation/epoch, exact crew/native route/records, feature/Zeus/reservation gates and fresh pose/geometry checks. Planning remains scheduled; commit requires observation age<=1s, pose drift<=1m and heading drift<=5degrees. Initial expiry is captured before planning. Refused steering releases only matching work and returns RELEASED. Native reverse effectiveness, sampling limits and queue-specific execution remain unverified.

Tracked reverse now refreshes its no-progress clock only after at least2m net separation along the original away axis while still threat-facing. Sideways travel, forward drift and oscillation back to a previous anchor no longer count. The original leg deadline remains unchanged. Numerical/source checks do not establish native reverse effectiveness or terrain handling.

Temporary group-route admission now validates its captured operation generation and owner epoch before reuse, edited-route marking and atomic replacement. Unscoped admission refuses if an operation appeared after capture. Tracked reverse fallback callers pass their original generation instead of adopting whichever operation is live later. Caller phase publication and full native-route interruption remain separate review items; physical handover remains unverified.

Common operation completion/cancellation now retire their public operation and result atomically only if the original record, generation and entry owner epoch remain current after cleanup. Completion rechecks external takeover and delegates matching cancellation instead of publishing COMPLETE. This protects successor state; earlier cleanup side effects and physical lifecycle transitions still require review and in-game validation.

Operation attack-permission restoration now checks the exact current operation and performs its existing bounded roster/lease/value checks in the same unscheduled block as lease consumption and enableAttack. No movement, geometry query or additional observer is added. This closes a scheduled check/write gap; same-value external setting edits and physical handover remain unverified.

Vehicle withdrawal now publishes RETREAT/MOVING and marks the hull withdrawn only after matching current reverse admission or a committed generation-bound fallback waypoint. State/operation/epoch are rechecked in the transaction; lease timing derives from original operation start. Refusal retires only the matching incomplete operation and releases its lease only after matching termination with no successor. Existing sparse retry remains; physical withdrawal and long-contact retry policy remain unverified.
