# Addon lifecycle and feature integration

Combat Behaviour Enhancement (CBE) is an addon, not a mission script bootstrap. Loading the mod registers its functions,
settings and runtime entry points. Missions do not copy its files or execute an initialization script.

## Startup and authority

CBA pre-init loads guarded defaults and registers the shared tuning specification on every machine.
CBA owns global setting persistence and synchronization. Live feature gates require boolean values and an array for group exclusions; invalid values refuse admission instead of throwing inside an owner FSM. Missing values retain the documented fallback. Malformed declared ownership is treated as external control until corrected, and no helper repairs or overwrites the mission value. Post-init starts enabled systems after addon
initialization. The server coordinates cross-group decisions; the current AI owner executes movement,
fire and local handlers. Interface clients provide Zeus controls and interruption monitoring.

CBE functions are registered once under the CBE tag; no legacy product tag is registered. Settings and runtime state use CBE identifiers. CBE owns the base-soldier engine danger slot and provides
the complete danger-response path while loaded. Another addon replacing the same engine slot is incompatible;
specialist actor ownership still yields through explicit finite compatibility markers.
Each server or headless owner verifies the final configured west, east and independent base-soldier
paths before starting infantry tactics. A mismatch fails that tactical runtime closed and reports the
three resolved paths, preventing CBE group operations from competing with a foreign danger brain.
Repeated engine observations are coalesced by expiry, so an older queued duplicate cannot replace the
current cause geometry. Hostile identity is retained on its own freshness track and must remain alive,
hostile and natively known before use. Immediate soldier danger posture is also generation-bounded: the engine danger FSM records the prior
scripted stance, applies one short scripted stance, and restores it only while that exact observable value remains owned by CBE.
Any newer engine, Zeus or specialist stance wins and invalidates the lease without restoration.

## Existing improvements remain in scope

| Subsystem | Existing implementation retained | Runtime mechanism |
| --- | --- | --- |
| Skills and visibility | Profiles, ambient light, equipment heuristics, operator/cargo distinction and dispersion | Local creation/locality events plus bounded refresh |
| Infantry | Contact, cover, fire control, advance, flank, assault, withdrawal, morale, surrender and recovery | Engine danger intake, shared budgeted scheduler and finite group-operation FSMs |
| Buildings | Garrison, clearance, casualty replacement and task handover | Owner-local building tasks with ownership checks; traversal remains subject to live acceptance |
| Coordination | Contact communication, support by fire, multi-squad and combined-arms responder roles | Server decisions and expiring owner-local operations |
| Vehicles | Convoy, passengers, gunnery, obstruction and non-teleport recovery | Native commands with bounded progress jobs and seat ownership |
| Aircraft | Weapon-aware attack choices, defence, countermeasures, landing and braking | Finite owner-local jobs, missile events and terrain checks |
| Support and reactions | Artillery warning/support, airborne/naval operations and civilian reactions | Event-driven requests and finite scheduled responses |
| Operator controls | Per-feature gates, diagnostics, Zeus replacement and script API | Shared setting specification and explicit ownership |

Retention is not acceptance: building traversal, aircraft geometry, coordinated movement and measured
performance still need fresh batched game tests. The feature coverage manifest records outstanding cases.

## Runtime changes

CBA callbacks defer work until addon post-init. Skill/profile changes reconfigure the existing local
skill worker. Master disable releases CBE-owned operations; it does not erase externally owned state.
Grenade-evasion and civilian-reaction switches immediately reconcile their optional handlers through
the repeat-safe installer. Turning them back on must work without restarting the mission. Other
behaviour gates are read by their finite jobs and eligibility checks; this does not justify installing
another worker for each setting.

A newer Zeus or mission order invalidates the current operation. Cleanup restores only state still
owned by that operation. Locality migration retires stale work and lets the new owner adopt eligible AI.
No tactical job waits indefinitely for a grenade animation, a casualty, or every straggler to arrive.

## Choosing addon mechanisms

The shared tuning specification carries each option's activation policy into CBA help and the
generated settings reference. Live controls follow their callback or next owner-local update.
Next-operation controls are guaranteed when new intent starts; active work keeps committed geometry
and may adopt safety values earlier. No runtime control currently requires a restart. Optional engine
policies will require package selection and restart rather than a reversible checkbox.

The script tuning API validates input and changes CBA's server layer. It does not send a second
settings snapshot or install duplicate workers. CBA handles effective-value synchronization and JIP;
the published revision counter is diagnostic only. Settings changes are not a multi-key atomic
transaction. Physical server-enforcement and JIP acceptance remain pending.

Use config for declarations and dependencies, CBA settings for reversible configuration, events for
sparse stimuli, finite FSMs for transitions, and the existing scheduler for bounded due work. A config
change that cannot be undone at runtime must never be presented as a reversible setting. Do not put
terrain queries, global scans or movement reissue loops in unconditional FSM transitions.

Core, infantry, vehicles, aircraft, support and compatibility are separate mandatory PBOs. The
bootstrap registers the function catalogue and starts enabled owner-local systems after its component
dependencies load. Components do not add schedulers. Engine-policy PBOs remain a separate pending
implementation and must not be advertised as available until packaged and validated.

## Validation

The sequential build checks source, config, settings parity, documentation, performance contracts,
FSM validity and packaging. Game validation uses the packaged addon and dedicated-server/client audit.
Next batched acceptance includes disable/re-enable of optional handlers, JIP and headless migration,
Zeus replacement during manoeuvres, active external ownership, and the feature behaviour matrix.
Measured performance compares the same 50 mixed groups against baseline AI: at most 5 percent added
median frame time and 10 percent added p95 frame time. Static checks cannot establish that budget.

Owner-local startup waits for CBA's settings-initialized event after post-init refresh.
Guarded pre-init defaults do not establish effective settings readiness. Direct server start/stop
requests use the CBA server layer; callbacks perform local setup and cleanup.

## Shared queue ownership

Event-driven jobs that represent a single owner and response may supply a stable, owner-local job
key. A repeated observation then refreshes that callback's state and wake time rather than adding a
second callback that will become stale later. Keying is opt-in: separate groups, projectiles,
artillery missions and ordinary operations remain independent queue entries.

Tactics and skill adjustment share one owner-local callback and the configured soft budget.
Skill refresh examines at most ten registered units per second, writes only changed layers and
continues when tactics are disabled or paused. Tactical job delays retain low-FPS backoff;
the bounded skill refresh does not inherit that backoff. Stopping either runtime retires its jobs
without disabling the other. Stopping the last runtime removes the callback. Skill stop advances
its generation so stale jobs cannot revive after a quick restart. No job is replayed across owners;
locality adoption registers the new owner's units.

The scheduler audit checks actual skill refresh with tactics disabled and physical queued movement
with skills disabled, then callback removal when both stop. The c0e9009 packaged scheduler batch
completed server and client acceptance with 267 passing checks and no reported SQF errors.
This validates that focused batch, not combat tactics or frame-time overhead. The shared budget
is soft and cannot pre-empt an executing SQF function; 50 mixed-group
median/p95 frame-time acceptance remains required.

## Finite FSM interruption

Active operation FSMs check cached Zeus-order markers and external ownership before a delayed step is due and while a shared-scheduler callback is pending. A newer owner therefore releases ground tactics, building progression, convoy control, aircraft attack and support reservations without waiting for the watchdog. Cleanup checks the current generation and exact owned token: ground controllers restore only matching overrides, aircraft removes its named temporary waypoint before releasing its flight lease, and support retracts only matching responder reservations. A stale FSM cannot release a newer operation or issue formation-return movement. No geometry or world scan runs in these FSM conditions.

An artillery order already accepted by the engine is treated separately. CBE stops issuing new fire or relocation commands when eligibility changes, but retains the bounded uncertain-shot record until the engine confirms the shot or its quarantine expires. This bookkeeping does not own movement or block a newer Zeus order; it prevents an unconfirmed shot from being retried.

Every scheduler-backed operation FSM has a fifteen-second starvation watchdog while a due callback is pending.
This covers group tactics, building progression, convoy control, aircraft attacks, artillery and support requests.
The watchdog is disabled during SafeStart or ENDEX and remains suppressed through the scheduler's resume grace,
so a deliberate pause or ordinary budget latency cannot create repeated recovery churn. A genuine overdue wait
clears only its local pending flag and wakes the same generation-keyed scheduler entry, so it cannot create a
second brain or grow a parallel queue. Cancellation, disablement, ownership and generation changes end the wait
before a stale callback can act. The callback repeats those checks before implementation logic. Diagnostics expose
watchdog activations per controller; any recurring count is a performance or queue-health finding rather than proof
of successful behaviour.

Tactical drills use a separate fifteen-second same-key recovery before the existing thirty-second
movement-lease cleanup. A missing recurring callback is therefore retried once through the FSM while
persistent callback failure still releases owned PATH, behaviour and ROE state through common cleanup.

Actor recovery is isolated from operation progress. Once an actor receives its one recovery route, only
the remaining manoeuvre element can renew the operation-wide progress clock. Physical travel by the
isolated actor renews its own bounded observation window, arrival rejoins it, and no progress marks only
that actor unavailable. A stalled main element produces an explicit terminal result; support reservations
release as NO_PROGRESS, and withdrawal selects another eligible straggler instead of retrying the same
exhausted actor. These checks do not add a per-unit worker or recurring scan.

The engine danger FSM is a finite response and interruption layer, not a second manoeuvre brain. It separates local physical reflexes from group combat planning: known-friendly near fire may change a finite scripted stance briefly, but cannot create CONTACT, while engage causes require a live hostile source. Casualty and scream causes are local alert/hide evidence only; actual losses still reach morale and role replacement, but the danger record cannot change group behaviour or ROE or invent an attacker. Explicit BLUE/GREEN fire discipline remains authoritative: real-contact awareness and defensive posture remain available, and an idle authored STEALTH element may take one weak finite low-profile stance without receiving a movement or target command. CBE fire control, artillery, reinforcement, combined-arms requests, coordinated assault, flank and advance remain blocked. Direct commander stance orders retain higher engine priority, and a newer scripted stance invalidates CBE's exact lease. New native causes accumulate through the current response and are reconsidered early only when the bounded queue exceeds three records. At group handoff, one strongest event is consumed per finite step and other still-live causes remain queued; an immediate hit therefore cannot erase a simultaneous confirmed contact. The surviving higher-priority physical-response lease still cannot be shortened by those later weaker causes, and native-order interruption remains bound to that surviving lease's actor rather than whichever weaker record was assessed last. Coalesced events retain the actor that received the current response separately from the actor whose native knowledge supports an inherited hostile identity. This prevents an arbitrary group anchor from turning a mixed mounted/foot event into the wrong response domain while still requiring a living local witness for target identity. At the response deadline, a close living hostile may add at most two short follow-up records and an effective vehicle commander may add at most three; every follow-up repeats ownership and interruption checks. Reaching that fixed budget ends the immediate actor chain and hands continuing combat back to native AI and the persistent group brain even while target knowledge remains valid. An engine-confirmed hostile identity is retained only when already known and is checked again against current group knowledge before a mounted response may enter vehicle combat; targetless vehicle danger remains safety-only. Other vehicle crew finish instead of multiplying the response. The waiting state otherwise checks only cheap live gates and explicit ownership markers, so runtime disable, pause, direct curator control, new Zeus orders and declared external ownership terminate the response without a squad scan or delayed command. CBE's cause assessment, finite persistence handoff and one bounded idle-actor cover move are implemented. Immediate incoming danger also gives up to four otherwise idle squad members a generation-owned weak low-profile stance; operation participants, native tasks and actor-level moves remain untouched. Release restores only stance values still matching CBE's exact application, while external handover discards the leases without writing over the new owner. Physical transition, interruption and 50 mixed-group performance acceptance remain outstanding. Queued acceptance covers the multi-actor hide response, known-contact hold-fire, mounted combat, mixed-domain observation, active Zeus replacement and leader-loss continuity; ownership migration and specialist animation preservation remain open.

The group assessment FSM likewise keeps its per-evaluation wait condition to locality, generation,
runtime and Zeus-token comparisons. Full player and specialist ownership checks occur in the bounded
250 ms assessment step, avoiding a per-frame scan of every member in every reacting group. Cause
priority is consistent across the engine and group layers: casualty evidence outranks a scream, while
direct harm, explosion and suppression retain priority over both.

An unidentified hit, explosion or suppression event may wake the finite CONTACT phase and preserve its approximate danger position for immediate safety decisions. It cannot authorise a route, weapon target, artillery request, reinforcement request, coordinated manoeuvre or later search. Those layers require native enemy knowledge. A hazard-only engagement returns directly to calm when its finite contact interval ends. Engine-confirmed contacts use the observer's believed target position, never the observer position, so the handoff cannot manufacture a co-located threat or a zero-length approach.

When that event affects a mounted group, its approximate position may also create a thirty-second passenger-safety lease. The lease invokes only the existing stationary-vehicle check, exact forced-speed-zero ownership and cargo exit. A local crew owner may publish the same bounded geometry to separately grouped allied passengers aboard its vehicle; the passenger owner validates crew authority and exits only its own eligible local cargo. This handover is not target knowledge and cannot authorise vehicle withdrawal, gunnery, tactical movement or contact reporting. Zeus, player and specialist ownership still reject the commands, while group release and shutdown retract the public lease.

The configured engine slot cannot be swapped at runtime. Disabling `CBE_AIPass_Danger_Enable`, pausing the tactical pass or disabling the wider pass makes CBE's FSM finish without issuing a new stance, movement, target or planning command. An exact stance lease already held by CBE is still released safely. Player, Zeus, CARELESS, forced-command, mounted and specialist ownership boundaries take precedence at every action boundary.

## Danger assessment

`CBE_AIPass_Danger_Enable` is a server-enforced, live CBA option under Infantry / Contact, default true.
`CBE_AIPass_DangerSmoke_Enable` is a separate live control, also default true. During a severe hit,
explosion or suppression response, one eligible local soldier may queue one carried-smoke throw. A
generation lease and 45-second group cooldown prevent a burst from consuming the squad's smoke.
The operation does not wait for the throw, and the next-frame weapon release rechecks the setting,
danger generation, Zeus state and specialist ownership.
`CBE_AIPass_StaticSupport_Enable` is a next-operation control, default true. On confirmed contact,
the existing group brain samples at most 75 metres once per contact episode for a live, armed,
simulation-enabled, empty friendly static weapon. One uncommitted nonleader receives a real gunner
assignment and a twenty-second physical boarding window. The group does not wait: its remaining
actors retain fire, manoeuvre, casualty replacement and withdrawal. Failure is recorded without a
retry during that contact. CONTACT cleanup cancels only the exact CBE assignment; Zeus or another
external owner causes a command-free handover. CONTACT and return-to-calm use one release path:
newer actor reservations, protected native tasks, pending medical treatment and changed assignments
prevent native unassignment or exit commands. A release-only call cannot discover or deploy another
weapon. Hidden emplacements are excluded. Already-issued native boarding may still be pending when
CBE yields; cancellation and physical handback remain unverified. CBE never teleports an actor into the seat.
CBE_AIPass_StaticDeploy_Enable is a separate next-operation control, default true. If no
usable emplacement exists, the same finite support opportunity may select one compatible primary
weapon bag and base bag from uncommitted local AI. Selection considers at most 64 group actors and
prefers a complete ready pair over an earlier unmatched primary carrier. The primary backpack
must assemble into a configured static weapon; UAVs and other deployables are outside this path.
Base compatibility follows the primary backpack configuration. A primary with an explicitly empty text base uses the same finite phases with one carrier,
no bag drop or second soldier. Native assembly receives one marked empty ground holder. The actual
assembly event identifies the weapon before ordinary boarding; native disassembly must return one
matching bag, remove the original weapon and physically restore that bag to the carrier. Cleanup
only deletes the exact owned holder while empty; added cargo and all equipment remain untouched.
One-part execution is newly wired and has no physical acceptance evidence. A complete one-part carrier
qualifies alongside complete pairs rather than being hidden by an earlier unmatched kit.
Expired approach phases retire before any new drop/assembly action. The separate normal-only
`staticsolo` audit focus observes actual native assembly, boarding and one-bag recovery; it fails
its prerequisite if no compatible one-part backpack is loaded. It has been prepared, not run. The pair physically moves to one of two bounded,
dry, low-slope positions with a clear firing sector, uses the engine assembly action and gives the
original carrier a real gunner assignment. The squad does not wait. Failure is recorded once for
the contact episode; CBE does not create a weapon, consume bags directly or force-seat the gunner.
During the ordinary post-contact security phase, the same pair receives one bounded recovery attempt:
the gunner exits normally, both actors approach the exact CBE-deployed weapon, native disassembly
creates the two bags and the engine's bag actions return them to their original carriers. A renewed
contact before disassembly remounts the gunner; one arriving during disassembly lets the finite pack
finish before the recovered team may deploy again. Authored movement, Zeus, specialist control,
locality loss, casualties or timeout release CBE ownership without deleting the weapon or loose bags.
Native assembly and disassembly receipts must match the current handler and phase deadline, with
features still enabled and no queued treatment on the affected actors. A late result cannot orient
the weapon or renew bag recovery. Physical equipment already produced remains in the world; these
guards do not establish cancellation of an engine action already in progress.
Return-to-calm uses the same carried-equipment retirement path. It checks each actor before
clearing CBE markers; a newer operation participant, other movement reservation or protected
native task receives no exit or follow command. Follow is limited to actors already on foot.
Changed owner/epoch retires without native commands, and only the installing machine removes
its equipment handler IDs. Movement markers carry local receipts for the original group, owner/epoch, deployment sequence
and exact applied value. Replaced markers are not cleared or adopted; packing cannot claim an
assistant reserved by another task. Missing migration receipts do not authorize command replay.
Identical native replacement orders without a changed marker remain indistinguishable.
`CBE_AIPass_VehicleJink_Enable` is a next-operation control, default true. A slow, intact, crew-only
armed ground vehicle may make one 25-second terrain-checked escape from a close hostile, hit or
explosion generation. The response uses the shared operation and movement lease, covers 35-45 metres
and ends before ordinary route control resumes. It refuses convoy vehicles, passenger loads, foot
elements, active movement, players, Zeus and specialist ownership. It never changes collision,
velocity, damage or physical position directly.
Arma loads CBE's bounded danger FSM for the three soldier base classes. The engine supplies immediate cause,
position, expiry, source and queued records; CBE maps those into detected enemy, gunfire, hit, explosion,
suppression, casualty and scream observations. One owner-local EnemyDetected observer separately retains only
engine-confirmed contact identity already known by a living local group member. It is removed on loss of ownership
or shutdown and never reveals or assigns a target.
The engine FSM explicitly branches through forced-command, vehicle, immediate, hide, engage and assess states.
Its responsibility map is deliberately narrow:

| State | CBE responsibility |
|---|---|
| `ASSESS` | Record bounded geometry and expiry only. It never moves, reveals, targets or fires. |
| `IMMEDIATE` | Apply one exactly-owned weak stance for a hit, explosion or suppression. The existing group-brain tick may move the genuinely idle exposed soldier who received the native event to nearby physical cover; a stale or unavailable observer falls back to the current combat-effective anchor. It does not start another worker. |
| `HIDE` | Treat casualty and scream evidence as mobile awareness. Immediate hit, explosion, suppression and gunfire geometry may give up to four idle, unreserved squad members an exactly-owned weak crouch/prone lease while the observed actor receives the existing single physical cover attempt. Casualty and scream cannot request cover movement from those causes. |
| `ENGAGE` | Require a living hostile source. Native knowledge and the existing group brain retain targeting, firing, suppression, CQB and manoeuvre ownership. Explicit BLUE/GREEN fire discipline remains unchanged and blocks danger-only tactical promotion. |
| `VEHICLE` | Record a bounded vehicle-safety wake only. The finite vehicle layer may stop for eligible passenger exit. An intact armed or armoured platform may request one route-neutral smoke countermeasure for a severe generation, while suppression still requires a native-known hostile. Infantry CONTACT, withdrawal, gunnery and manoeuvre retain their own gates. |
| `FORCED` | Yield to fleeing or a concrete boarding, action, healing, rearm or join task. The local engine FSM records the observation but filters it before group submission; group assessment also clears any older CBE response. No transient tactical wake, posture or movement command is possible. Native `ATTACK` remains eligible because Arma also uses it for autonomous combat. |
| release | Filter the observation before group submission, then restore only the exact stance or cover lease still owned by this FSM generation. Authored CARELESS, disabled movement and other release conditions cannot create a transient CONTACT; a newer order is never overwritten. |

The engine states themselves never issue a destination, target or firing command. Forced commands, player/Zeus control,
external specialist ownership, disabled movement and CARELESS behaviour terminate or bypass CBE action. This keeps
the engine response finite while the group brain owns tactics. The optional cover move runs inside that already-budgeted
group tick, refuses an active operation or native command and cannot create a second movement scheduler.
The queued group assessment repeats the concrete-task and mounted checks before changing behaviour or ROE, so
the delayed handoff cannot undo the immediate FSM's decision to yield. Native `ATTACK` is intentionally not a
yield condition: CBE changes only finite posture here and leaves native targeting, firing and movement intact.
An eligible first engine event starts that same generation-owned group brain immediately when the periodic discovery
sweep has not reached the group yet. It does not create a second worker. Diagnostics count these first-contact
bootstraps, accepted records and finite response modes without publishing target identity.
Cause records are consumed twelve at a time by the engine FSM, then coalesced in a group queue capped at sixteen records. Events expire after two seconds;
Repeated callbacks of the same cause are throttled to 0.25 seconds before any squad eligibility scan;
assessment selects the highest urgency without sorting and breaks equal-priority ties by observation time.
Gunfire records the observer position rather than an unseen attacker. The queue never supplies a target
identity, reveal or firing command.

One finite assessment FSM per affected group runs while observations or its short response lease remain.
It wakes that group's existing scheduler job, at most twice per second, using a local deadline on the same
job state. The response context records cause, approximate observer position, expiry and generation; it is
not target knowledge or a movement request. Stronger causes remain in force over weaker later callbacks.
While the finite response is live, its already-scheduled group decision receives the contact cadence even
outside normal player-distance range. It still reads only native engine knowledge, and does not add a worker,
scan or route owner. The existing job is also exempt from the low-FPS cadence backoff for that response lease;
optional work remains backoff-limited. Expensive knowledge, geometry and tactical decisions retain the shared scheduler budget and normal
participation gates. The configured engine danger FSM replaces the base soldier danger slot while CBE is loaded;
the queued targetless-explosion audit requires a real engine event, physical cover travel and exact lease release, but
has not yet supplied live acceptance evidence.

Owner epochs and FSM generations prevent old callbacks from acting after transfer or restart. Zeus
hold-token changes, replacement waypoints and active external-controller ownership terminate the FSM and
clear the response before another controller can consume it. Interruption explicitly releases only the
temporary behaviour and combat-mode values that the response lease still owns, so a Zeus order, external
controller, feature disable, pause or locality handover cannot leave a stale COMBAT/ROE posture behind.
Eligibility checks preserve external animation/combat ownership. The new owner starts from observations received locally. Queued acceptance
covers priority/expiry, sustained fire, no knowledge leakage, disabled state, leader casualties, Zeus,
external ownership, locality transfer, physical reaction and 50 mixed-group frame-time comparison.


Squad low-profile posture inspects at most 64 members and applies at most four weak stance leases. Actor eligibility excludes declared external ownership, specialist identities and active melee control before acquisition; ordinary actors in the same group remain eligible. This boundary correction is statically validated and still requires specialist coexistence acceptance.

Lifecycle anchoring accepts an eligible ordinary leader immediately, otherwise inspects at most twelve members. Player remote-control, declared ownership, specialist identity and active melee prevent anchor selection. Opportunistic danger smoke inspects at most 64 members and tries at most three ordinary carriers; grenade initiation independently rejects specialist identities. Mixed ordinary actors remain eligible. These corrections await physical coexistence and casualty acceptance.

Grenade requests reject player and remote-controlled actors at initiation and again at asynchronous release. Taking control during the alignment window cancels the queued request. Physical control-transfer acceptance remains pending.

Grenade evasion considers at most 16 nearby actors. Its delayed recovery matches the exact reservation expiry before clearing bookkeeping, and checks the captured operation generation and owner epoch before issuing follow. Player, specialist and native action owners block movement. Cover acquisition and recovery apply the same player/specialist boundary. Physical interruption and repeated-evasion acceptance remain queued.

Squad posture restoration requires the complete six-field lease, matching operation generation and owner epoch. Incomplete records grant no restoration authority. Remote-controlled actors are excluded from acquisition, retention and restoration. Physical takeover and malformed-record acceptance remain pending.

Danger posture renewal preserves its original behaviour and combat-mode baseline while the recorded generation, owner epoch, owner and applied values still match. Lease expiry permits cleanup, but an event arriving before that cleanup cannot adopt CBE-applied COMBAT as the baseline. Renewal after expiry and eventual release still require physical acceptance.

Danger renewals issue group behaviour and combat-mode commands only when the effective value differs from the selected response. Lease renewal remains unchanged; repeated observations do not resend identical posture commands. Physical command-churn and response acceptance remain pending.

Danger renewal compares behaviour and combat-mode ownership independently. An external change to one value does not replace the original baseline of the other value while that value still matches CBE's application. Generation, locality epoch and owner remain mandatory for both. Physical mixed-value renewal acceptance remains pending.

A renewed suppression or hide observation preserves RED engagement only while the exact combat-mode lease is still owned. This avoids RED/YELLOW oscillation during the same finite response. Explicit BLUE/GREEN orders, external changes and release retain priority; this does not issue movement or firing commands. Physical sustained-contact acceptance remains pending.

Disabling stance control clears its bookkeeping but resets posture only for an ordinary local actor without group takeover, player control, remote control or specialist ownership. Cleanup also requires the current posture to match CBE's applied posture. Physical setting-change takeover acceptance remains pending.

Vehicle-gunnery feature-disable and hold-fire cleanup clears CBE's target metadata without issuing doTarget over group takeover, player control, remote control or specialist ownership. For an eligible ordinary actor, the assigned target must still match CBE's recorded target before removal. Physical target handover acceptance remains pending.

Normal CALM restoration preserves stance and targeting during explicit external handover, player/remote control and specialist ownership while clearing CBE metadata. Cover-height stance acquisition excludes players, remote-controlled actors and specialist identities independently of an active external-control marker. Physical mixed-group acceptance remains pending.

Cover-height stance checks inspect at most twelve members and cast at most six rays per group step. The existing rotating cursor advances for every inspected actor, including ineligible members, so large or specialist-heavy groups do not cause an unbounded eligibility scan or permanently starve later members. Frame-time acceptance remains pending.

The cover-height stance entry point rejects null or non-local groups, current Zeus holds and declared group external control before geometry work or posture changes. Per-actor specialist checks remain separate so ordinary members of a mixed specialist group can participate. Direct-call and locality-handover physical acceptance remains pending.

Danger-cover timeout is terminal for the current actor and danger generation. Exact-owned reservation cleanup and eligible failed-approach recovery still run, but the same observation cannot immediately search and recommit its failed destination. A new danger generation permits reassessment. Physical blocked-cover acceptance remains pending.

Operation start releases its old on-foot danger-posture lease before publishing the new operation generation. A live danger response then acquires MAINTAIN under the new generation using the restored baseline. This prevents generation replacement from silently discarding restoration authority. Physical CONTACT-to-manoeuvre/CQB/withdrawal acceptance remains pending.

Operation participant admission and progress use combat-effective local members of the owning group. Captive, surrendering, handcuffed, unconscious, player, remote-controlled and specialist/external-owned actors cannot count as ordinary manoeuvre progress or recovery candidates. Specialist activation excludes that actor on the next bounded step. Physical mixed-group and casualty acceptance remains pending.

Isolated recovery uses actor-local specialist ownership at both command boundaries. A specialist squadmate does not prevent an ordinary participant's recovery; group Zeus/player/declared ownership remains authoritative, and the recovery actor's declared external control yields without consuming its retry. Physical mixed-group recovery acceptance remains pending.

Role rebalancing filters specialist identities, remote-controlled actors and actor-specific external ownership before selecting reserves. Group takeover is checked again before publishing the roster using an ordinary candidate as specialist context; player, Zeus and declared group control remain group-wide. No ordinary candidate yields without recruiting a specialist. Physical casualty reinforcement acceptance remains pending.

Tactical drill rebalancing excludes squad members outside its current live fire-team element. The operation roster therefore tracks actual drill participants rather than unrelated security/support movement. Existing casualty team assignment remains authoritative; physical stalled-bound and replacement acceptance remains pending.

Danger posture respects a live tactical drill's exact groupCombatMode lease while an operation exists. Renewed engagement cannot replace its applied YELLOW discipline with RED and falsely end movement as ROE_CHANGED. Drill team rebuilding also excludes operation-quarantined unavailable actors. Physical sustained-contact and isolated-stall acceptance remains pending.

Danger's tactical fire-mode exemption requires matching operation generation, current owner epoch, drill operation generation and an active START/MOVE/PAUSE/HOLD phase. A leftover mode lease cannot constrain danger after replacement or migration. Physical stale-record transition acceptance remains pending.

Flank, advance and assault drills record the operation owner epoch at creation. Drill cleanup requires that epoch and its operation generation to match current group ownership before restoring AI features, modes or movement. A stale callback cannot gain restoration authority merely because the operation record was cleared. Physical migration/replacement cleanup acceptance remains pending.

Operation replacement synchronously ends a matching outgoing drill before changing generation. Exact matching generation and owner epoch are required; REPLACED releases drill feature holds without formation return, and the incoming operation owns subsequent movement. New drill records lacking the outgoing generation are not consumed. Physical replacement-with-held-features acceptance remains pending.

Zeus release ends a matching drill before incrementing the curator generation. ZEUS cleanup releases tracked feature holds while suppressing posture, mode and formation commands; then generation invalidation rejects old callbacks. Locality adoption retains its separate checkpoint restoration path. Physical Zeus-with-held-features acceptance remains pending.

Locality checkpoint actor restoration requires a live local member without player, remote, specialist or declared actor ownership. This gate covers feature switches, unit modes, behaviour and formation return; formation return additionally yields to native service/action commands. Group ownership eligibility remains mandatory. Physical migration-to-specialist/service acceptance remains pending.

Drill checkpoints record committed mover destinations. Locality formation return may replace a MOVE only when its destination matches that actor's recorded spot within one metre and the expected floor band. A different MOVE, or MOVE without destination proof, survives. Physical migration/new-order acceptance remains pending.

Danger intake checks actor/cause cadence before group ownership scanning. Throttled duplicates return without that scan; rejected eligibility does not advance cadence, and accepted observations retain the existing quarter-second gate. Physical intake responsiveness and frame-time acceptance remain pending.

Danger intake and selection require three numeric coordinates, not merely a three-element position array. Invalid coordinate types are rejected before event storage or geometry consumers. Existing event priority, witness identity and expiry rules remain unchanged. Physical intake acceptance remains pending.

Danger duplicate matching validates record shape and reads cause/witness through typed fields before coalescing. A malformed stored record cannot be indexed as an event or replace a valid witness. The existing selector rejects malformed records and retains its bounded priority pass. Physical malformed-intake acceptance remains pending.

Danger classification rechecks surrender and handcuff state when consuming a queued hostile identity. Intake, inherited-source retention and contact publication also reject handcuffed sources. Native knowledge of a detained or newly surrendering actor cannot alone authorise a fresh engagement. Physical surrender-during-queued-contact acceptance remains pending.

Active flank, advance and assault drills end hostile intent when the retained target begins surrender or becomes handcuffed, alongside existing captive/side-change checks. Target death remains distinct so a valid clear-through can continue after a casualty. Physical surrender-during-manoeuvre acceptance remains pending.

Shared tactical knowledge prunes surrendering and handcuffed actors from cached observations and hostile candidates alongside captive/side checks. Ending an active drill cannot immediately recreate hostile intent through the same detained target's native knowledge. Physical surrender-to-security acceptance remains pending.

Observed-contact cache pruning validates numeric expiry before comparing time and inspects at most the eight newest records, matching the writer's eight-contact cap. Invalid expiry records do not reach recurring knowledge evaluation. Physical intake and performance acceptance remains pending.

Vehicle target cleanup retires CBE's recorded target when dead, captive, surrendering, detained or friendly. It clears the native assignment only when it still matches CBE's target and no newer owner controls the actor. Gunnery ranking independently revalidates protection and hostility, including direct callers with stale candidate lists. Physical surrender/side-change vehicle acceptance remains pending.

Aircraft planning rejects protected targets. Active attack updates revalidate living targets for captive, surrender, detention and side change, releasing CBE attack control as TARGET_NO_LONGER_HOSTILE. A destroyed objective remains distinct and follows the existing physical-attack egress path. Physical protection-during-air-attack acceptance remains pending.

Aircraft cleanup no longer restores enableAttack because the controller does not modify that setting. It preserves later policy changes. Owned-target cleanup additionally requires local ordinary crew without player, remote, specialist or declared actor control; newer target assignments remain untouched. Physical aircraft policy/target handover acceptance remains pending.

Ordinary aircraft route resume selects the actual authored waypoint handle rather than treating a list offset as an engine waypoint ID. Deleted temporary waypoints may leave ID gaps; the selected handle must still match the recorded resume position. Physical resume-after-waypoint-deletion acceptance remains pending.

Aircraft resume validates local group authority and the stored authored position before searching waypoints. An absent resume position yields no waypoint search or route replay; attack completion/cancellation still retires its finite lease. Physical no-authored-route acceptance remains pending.

Aircraft attack cleanup resets speed and restores its pilot feature switches only while the original AIR_ATTACK flight lease remains valid. A newer landing, braking, evasion or attack owner keeps its controls. Pilot feature restoration also requires eligible local ordinary control. Physical flight-owner transition acceptance remains pending.

Flight lease acquisition and validation both require a combat-effective current pilot, excluding unconscious, incapacitated, captive, surrendering or detained actors. The lease itself has no time-based expiry; finite controller deadlines govern release. Reacquisition retains identity rather than promising an expiry refresh. Physical pilot-incapacitation acceptance remains pending.

Operation start, cancellation and release reuse danger posture only from an unexpired response matching the current danger generation. An older response cannot be renewed merely because its timestamp has not elapsed after reset or handover. Physical disable/reset and migration transition acceptance remains pending.

The selected danger response retains one exact owner-local event, including hostile source and witness. Operation release/cancel reclassification uses it only when cause and observation time match the live generation-checked response. Targetless fallback remains targetless; it cannot fabricate a witness or enemy. Response cleanup removes the local event, adding no network payload. Physical contact-to-operation-to-contact acceptance remains pending.

Operation start classifies the retained matching danger event after publication and applies posture through its original observer. Mounted and native forced-task witnesses remain VEHICLE/FORCED observation-only; valid ordinary foot contact becomes MAINTAIN through the shared classifier. Lost witnesses are not replaced with unrelated actors. Physical mixed-domain start acceptance remains pending.

An unavailable explicit danger witness retires its finite response instead of transferring response identity to the group anchor. Exact-owned group posture is released using a viable actor; queued observations from other witnesses remain available. Native-task handover removes only the original witness's queued events. Physical witness-casualty and mixed-witness acceptance remains pending.

Engine weak-stance renewal and release require complete six-field leases. Group-hide baseline transfer also requires its complete generation/epoch proof. Incomplete records are discarded without posture mutation or restoration; they cannot confer ownership through legacy short-record fallbacks. Physical malformed-lease and posture-transfer acceptance remains pending.

On-foot operation start releases owned engine weak-stance leases for at most 64 members, then group-hide posture, before changing operation generation. Each release retains its exact-value and external-owner checks. This prevents temporary posture becoming the new operation's authored baseline. Physical danger-to-movement posture acceptance remains pending.

Building entry selection and actor availability exclude remote-controlled actors and full specialist identities. Cancellation rechecks group takeover before any stance, speed, watch or formation restoration, including early disabled/deleted-building exits. Metadata cleanup remains finite. Physical mixed-group and early-cancellation acceptance remains pending.

Building egress rechecks operation quarantine every step; losing an assigned actor keeps the egress result incomplete rather than routing that actor again. Room-visit credit requires a combat-effective local ordinary actor without player, remote or specialist ownership, in addition to the existing three-dimensional physical arrival check. Physical quarantine-during-egress and controlled-visitor acceptance remains pending.

Building approach deadline renewal requires a new best three-dimensional distance to the committed target, accumulating at least one metre of improvement. Backtracking and repeated circles cannot repeatedly renew the budget. A changed entry/room target establishes its own baseline; physical room visits retain their existing renewal path. Physical doorway-circle acceptance remains pending.

Building room retries reset their no-progress timestamp only for a new best approach distance, not arbitrary walking. Circling reaches existing finite retries, alternate-entry selection and isolated recovery while other pairs continue. Physical detour, stair and doorway cases must verify the retry timing remains appropriate; acceptance remains pending.

Building reserve selection excludes operation-quarantined actors even when they are outside current pairs, plus remote-controlled actors and full specialist identities. Those actors cannot be inserted into a casualty vacancy before later availability checks reject them. Physical casualty/reserve mixed-group acceptance remains pending.

CQB reserve replacement retires only the removed actor's active recovery observation in the matching CLEAR generation and owner epoch. Common operation quarantine also retires that actor's observation. Both retain the generation's retry budget and unavailable roster: rotating reserves cannot grant a failed actor unlimited retries. Other actors continue their existing routes. Physical casualty, blocked-entry and replacement cases remain pending while game audits are suspended.

Danger-cover timeout cleanup treats a wrong-floor arrival as an unfinished approach, even when its horizontal distance is within two metres. Return-to-formation recovery requires the native expected destination to still match the owned spot horizontally and vertically; a newer destination on another floor is preserved. Existing player, Zeus, specialist and operation exclusions remain. Multi-floor timeout and newer-order cases require physical retesting.

Engine danger classification, follow-up recycling, submission and EnemyDetected intake exclude handcuffed actors as well as captive and surrendering actors. This aligns immediate FSM eligibility with group threat selection without changing reactions to anonymous explosions or incoming hazards. Capture during an active response and later release require physical transition acceptance.

Finite engine responses record operation generation, owner epoch and group identity. Their waiting gate drains an old response immediately after operation replacement, group reassignment or owner-epoch change, before recycling. Initial native intake remains available; the check reads only the affected actor and group and adds no squad scan or worker. Physical replacement and HC-transition acceptance remain pending.

Engine queue selection and submission accept only two- or three-coordinate numeric positions before adding a floor coordinate or applying geometry. Malformed positions drain without creating danger intent. Existing expiry tolerance, priority and twelve-record callback limit remain unchanged; this adds at most three primitive type checks per accepted record. Physical delayed-contact acceptance remains pending.

Squad low-profile acquisition includes stationary native ATTACK, FIRE and SUPPRESS actors, instead of requiring an empty command. A speed cap of 0.5 km/h excludes actors already moving; operation participants, actor reservations, native service tasks and specialist ownership remain excluded. Only weak stance changes, never targets, firing or movement. This repairs an intake mismatch for soldiers already engaging; physical fire continuity and cover readability remain unaccepted.

Tactical reposition revalidates a retained target's hostility and protected state before committing movement. Missing contact geometry falls back only to the local representative's native believed position while knowledge exists; absent or malformed belief declines reposition rather than reading the target's exact live location. Existing close-armour withdrawal and screened lateral options remain. Physical occluded-contact and protection transitions are pending.

Tactical reposition reports started only after group movement returns a valid waypoint handle. A rejected final movement boundary immediately releases the exact generation as INCOMPLETE/MOVEMENT_REJECTED, drops its ownership reservation and records a bounded retry cooldown. It does not install an active movement lease or claim physical progress. Native-task and Zeus refusal cases remain pending physical acceptance.

Vehicle jink and artillery relocation require a valid returned group waypoint before publishing movement leases or active platform evidence. Rejection releases the exact new operation as INCOMPLETE/MOVEMENT_REJECTED and drops its matching feature reservation; artillery also clears its pending relocation request. Neither substitutes another route or overwrites the native task that refused movement. Physical refusal and subsequent ordinary-order acceptance remain pending.

Infantry withdrawal validates local group eligibility, player/Zeus/external ownership, a combat-effective anchor and native service tasks before route selection or any support, PATH, attack or behaviour mutation. A refused boarding, treatment, assembly or supply task leaves its existing state intact instead of creating a partially applied withdrawal. Ordinary native combat remains eligible. Entry/refusal and resumed-locality cases require physical acceptance.

Withdrawal replanning updates its target and moving state only after a valid group waypoint is returned. Missing routes and refused commands consume the existing bounded replan attempt and observation interval; they cannot claim travel or trigger fresh geometry on every callback. Physical distance remains measured independently. Blocked-route, native-task refusal and eventual INCOMPLETE outcomes remain pending in-game acceptance.

Tactical reposition completion checks the matching operation's remaining capable participants, excluding quarantined and externally controlled actors. COMPLETE requires a nonempty element within the twelve-metre destination radius and 1.5-metre floor band; anchor-only arrival is insufficient. This is terminal evidence, not an assembly gate: normal expiry still releases the operation as INCOMPLETE when the element did not arrive. Physical split-element and floor-band cases remain pending.

Tactical reposition issues the first committed avenue leg, then the shared group callback advances at most one leg after the anchor physically reaches its six-metre radius and floor band. Generation, owner epoch, deadline and a sixteen-leg bound gate progression. Final completion still uses the remaining element's arrival; no separate worker or repeated destination issuance is added. Actual covered-corridor travel and Zeus interruption require physical acceptance.

All tactical reposition legs, including the final leg and one-leg routes, run common operation progress accounting through the existing callback. A stalled element may select one stationary, non-quarantined participant without an active recovery record for isolated recovery toward the current leg; common retry limits and actor ownership checks still apply. Other participants retain their route. This adds no worker and bounds selection to sixty-four declared participants. Physical obstruction and continuation acceptance remain pending.

Reposition recovery selection excludes actors whose generation-owned retry budget is exhausted even after their active observation was retired. One already-used actor cannot repeatedly occupy the first selection slot and prevent another stuck participant from receiving its bounded attempt. Existing reservation and common command-boundary ownership checks remain. Multi-actor obstruction acceptance is pending.

Actor danger stance renewal avoids reissuing an unchanged weak-stance engine command. Existing leases retain their original baseline and updated finite deadline; transferred squad-hide baselines remain intact. When the authored baseline already matches the desired stance, CBE owns no restoration and stores no stance lease. Physical posture continuity and performance remain unaccepted.

Combined ground-support admission requires a valid firing-area waypoint before publishing APPLIED, installing its movement lease or queuing its finite movement job. Refusal records MOVEMENT_REJECTED for the opportunity token, releases the exact new operation and feature reservation, and leaves native orders authoritative. This also closes the post-operation takeover refusal leak. Physical combined support and external takeover acceptance remain pending.

Combined ground-support continuation rechecks the current operation owner epoch and handcuffed target state. Its single bounded route reacquisition verifies the returned waypoint; refusal ends the role as MOVEMENT_REJECTED rather than renewing an apparently active move. An unchanged owned destination remains committed through normal group-move coalescing. Physical obstruction, target protection and migration acceptance remain pending.

Combined ground-support jobs capture their operation owner epoch at admission. A stale epoch returns without route cleanup, reservation mutation or terminal result publication. Matching cleanup additionally requires the exact operation generation, intent and epoch before clearing its waypoint. New-owner adoption must queue a fresh job through normal admission. Physical HC handover and late-callback acceptance remain pending.

Shared ground waypoint adoption and cleanup compare height as well as horizontal position. A floor change greater than 1.5 metres invalidates CBE ownership; cleanup preserves the edited waypoint instead of deleting it. Destination coalescing does not treat different floor bands as the same route. Two-coordinate requests receive an explicit zero height rather than a nil coordinate. Physical floor-edited Zeus orders and terrain waypoint normalization remain pending acceptance.

Shared waypoint ownership stores the engine-returned position as its edit baseline, separately retaining requestedPosition. Radius-zero native placement can adjust the request and must not itself trigger a takeover. Explicit elevated ATL destinations use exact ASL placement with negative radius; ordinary ground requests retain safe native placement. See [addWaypoint engine semantics](https://community.bistudio.com/wiki/addWaypoint). Terrain, elevated-route and edited-waypoint physical acceptance remain pending.

The queued tactical-assessment armour case retains its leader-travel result and adds an independent physical element-travel check: at least half of the six-person fixture must move fifteen metres from their own recorded origins within a bounded observation. This is partial movement evidence, not route completion or combat effectiveness. No reveal, teleport or solved-state injection is added. The case has not run while audits are suspended.

Support admission emits one final refusal acknowledgement when operation creation fails, instead of an inner refusal followed by a stale success. It releases its matching SUPPORT reservation. Ordinary rally support also requires a valid waypoint before publishing movement/response state; refusal releases the exact operation as INCOMPLETE/MOVEMENT_REJECTED and acknowledges false. Coordinated attack admission still delegates detailed routes to its existing controller. Physical server acknowledgement and refusal cleanup acceptance remain pending.

Withdrawal applies temporary autonomous-attack, combat-mode and behaviour changes only after its group waypoint is accepted. Refused movement releases the exact operation and INFANTRY_WITHDRAW reservation, reports MOVEMENT_REJECTED and returns false before setting the retreat phase, movement lease or screen effects. Earlier support/drill retirement remains intentional replacement cleanup. Physical native-task refusal, Zeus replacement and normal retreat acceptance remain pending.

Shared group movement rejects destinations outside the two-/three-numeric-coordinate contract before adoption, route cleanup or engine commands. Invalid script input returns the normal refused waypoint handle and preserves the existing route. Omitted height remains zero; the documented operation-generation argument binds cleanup to the current operation. Physical script/refusal parity remains pending.

Danger posture cleanup and common autonomous-attack restoration consume their matching leases without reissuing commands when prior and applied values are identical. Changed values still require exact current-value ownership before restoration. This removes redundant group commands; no measured frame-time improvement or physical acceptance is claimed.

Danger posture duration selection uses fixed branches rather than allocating an eleven-entry map per response. Hit, explosion, suppression, casualty, observation and gunfire durations are unchanged, as are lease renewal and public restoration ownership. This is an allocation reduction only; frame-time budget acceptance still requires the matched physical benchmark.

Reposition recovery selection skips disabled MOVE/PATH, mounted, player/remote-controlled, specialist, live actor-reservation and native-service-task actors before selecting its one candidate. An ineligible first participant cannot repeatedly consume the selection slot while another participant remains recoverable. The recovery helper still revalidates authority at command time. Physical mixed-eligibility and isolated obstruction cases remain pending.

Common isolated recovery rejects malformed coordinates before recording an attempt and enforces operation quarantine at initial and final command boundaries. An unavailable participant returns EXHAUSTED without movement or retry-budget mutation, even when a caller retained an earlier roster snapshot. Physical late-quarantine and invalid-script-input acceptance remain pending.

Frag safety excludes handcuffed actors inside the existing twelve-metre target safety radius at both admission and delayed release. This matches danger threat protection and handles a capture state changed during alignment without adding a new scan or pausing movement. Physical capture-during-throw and friendly-safety cases remain pending.

## Engine FSM disabled-state boundary

The danger addon replaces SoldierWB/SoldierEB/SoldierGB fsmDanger at config load. Runtime disablement makes the initial continuation gate end the CBE response; it does not write another config path or launch an unverified stock FSM through execFSM. Disabled-state acceptance must prove restored native movement/fire and absence of CBE commands, leases and queue churn. It must not claim native danger equivalence solely from an empty CBE operation. The matched performance baseline remains addon-absent. See [Arma 3 AI config reference](https://community.bistudio.com/wiki/Arma_3%3A_AI_Config_Reference). This behavioural boundary remains physically unaccepted.

Withdrawal speed uses an exact prior/applied lease. Calm cleanup restores it only while the group still has the applied FULL mode; a newer different mission speed is preserved. Checkpoints expose that lease through the existing exact group-speed restoration path for headless migration, and cleanup consumes the withdrawal metadata. Physical speed edits, stop/restart and HC resume remain pending.

On-foot engine danger classification does not treat disabled MOVE as loss of all combat response. Stationary defenders may receive finite weak posture and native hostile awareness; cover moves and evasive actions retain their independent MOVE/PATH guards and never enable disabled movement. Native service tasks, explicit ownership and mounted domain precedence remain unchanged. Physical stationary-defender and authored-stance acceptance remain pending.

Queued contact acceptance adds a stationary defender with MOVE/PATH disabled and an attributed native grenade stimulus. It checks physical crouch/prone during a finite engine response, no travel, unchanged disabled permissions and lease cleanup. No danger state or solved outcome is injected. This instrumented reflex case does not establish combat effectiveness and has not run while audits are suspended.

Group danger RELEASE/RESTORE may retire a dead local observer's lease through a surviving combat-effective anchor. If none remains, cleanup discards metadata without issuing group commands. New danger acquisition still requires a live observer, and generation/epoch/external-owner checks continue to govern restoration. Physical observer casualty and group collapse acceptance remain pending.

Incoming-missile jobs retain whether the warning supplied a concrete projectile. Deletion or death of that known projectile ends the matching finite defence response and flight lease, including before its first scheduled sample. A null reference after deletion cannot be mistaken for an originally unknown projectile. Warnings without a projectile retain the existing twelve-sample maximum. Physical destruction, interception and attack/landing handover acceptance remain pending.

Missile countermeasure-only response does not acquire flight-correction ownership. Live break disable releases only its exact missile-defence lease while flare emission can continue; closing both gates retires the response. Attack and landing ownership are therefore not preempted merely to fire countermeasures. Physical live-gate and flight-controller handover acceptance remain pending.

Aircraft discovery filters captive, surrendering and handcuffed objects before selecting assigned or native-known attack contacts. A protected first candidate cannot mask a later valid hostile merely because the planner subsequently rejects it. Native knowledge limits and bounded contact selection remain unchanged; the planner still revalidates at admission. Physical capture/retarget and air-to-air contact acceptance remain pending.

Aircraft ATTACK validates the selected station's actual operator before weapon selection, target/watch assignment or release requests. Locality, combat effectiveness, player/remote control and actor-context group eligibility govern this boundary, including gunners belonging to a different group from the pilot. Refusal ends the run as WEAPON_OPERATOR_RELEASED. Physical gunner casualty, separate-group Zeus ownership and specialist activation acceptance remain pending.

Aircraft target cleanup checks each crew member's own group takeover with actor-local specialist context, in addition to the pilot-group boundary. A separate-group gunner under a newer Zeus, player or explicit external order retains target/watch commands even when assignedTarget still equals CBE's former hostile. Ordinary exact-owned targets can still retire. Physical separate-group interruption and cleanup acceptance remain pending.

Combined air support acknowledges APPLIED only when attack startup succeeds or a live flight-lease-owning brain already addresses the same target/platform. A different existing target or refused flight lease reports AIR_BUSY_OR_REFUSED and requests the existing fallback path without replacing the aircraft's current intent. A busy marker alone is not acceptance. Physical competing-target, landing/evasion ownership and fallback acceptance remain pending.

Combined air fallback requires the rejecting group's exact current opportunity token, requester and AIR_ATTACK role, then consumes that role before advancing the candidate cursor. Duplicate notices cannot dispatch extra aircraft; newer roles and the rejected aircraft's existing attack brain remain untouched. Physical duplicate delivery, stale-owner and busy-aircraft acceptance remain pending.

Combined air fallback revalidates requester eligibility/communication and live target hostility/protection after consuming the exact refusal. Invalid opportunities retire their matching fallback record. Candidate selection preserves another unexpired opportunity rather than overwriting its role. Existing aircraft brains remain untouched. Physical changed-requester, capture and competing-role acceptance remain pending.

The packaged audit launcher supports -WaitForCompletion with a bounded -BatchTimeoutSeconds observation window (default four hours). It records retained process handles, observed exit codes and separate completion markers in batch-status.json. Process exit and observation timeout remain incomplete results; the monitor never stops applications or restarts a batch. Completion markers do not override failed behaviour cases in the audit report.

Building audit comparisons excluded from CBE scheduling are not addon-absent native baselines: fsmDanger remains replaced by the loaded addon. The fixture records effective danger/formation FSM paths and labels this scope explicitly while retaining historical case IDs and failed outcomes. Native building-path parity requires a separate addon-absent candidate; exclusion alone cannot establish a game-engine limitation.

Garrison initial application and scheduled arrival/recovery now require actor combat effectiveness and actor-context takeover clearance. Captive, surrendered, handcuffed or specialist-controlled soldiers cannot receive new movement or PATH locks from those paths. The existing temporarily incapacitated pending-route policy remains bounded by the order deadline. Physical activation/release acceptance remains pending.

Garrison hit/suppression reactions, delayed duck restoration and release posture/watch/speed/formation commands now use combat-effective actor and actor-context ownership gates too. Capture or specialist activation between the event and delayed callback cannot reacquire that actor. Removal of CBE-owned PATH-lock metadata remains separate from tactical restoration. Physical capture and specialist transitions remain unaccepted.

Garrison and defence admission allocate positions and initial strength only from local combat-effective actors without player/specialist ownership. Captive or unconscious members no longer consume limited interior/line/reserve slots merely to be rejected during application. An empty capable set refuses the request before retiring the previous order. Physical mixed-eligibility allocation and casualty rebalancing remain pending.

Defence reserve activation requires local group authority and combat-effective, unowned reserve actors. Line losses count incapacitated/captive actors as unavailable, allowing a reserve to fill their recorded slot without ordering those actors. Activation retains its finite one-commit policy and existing terrain checks. Physical casualty/capture reinforcement acceptance remains pending.

Fresh CQB audit cases retain the 245-second physical sampling budget and add at most 15 seconds for a queued terminal result to settle before restoration/outcome assertions. A separate terminal-settlement check fails if no result arrives. The settlement interval adds no physical visits and calls no cleanup; failed entry and room visits remain failures.

Building-operation termination captures CBE_Cortex_ClearRouteEvidence once before cleanup: timestamp/reason, at most eight pair states and sixteen actor IDs, positions, commands, expected destinations and MOVE/PATH permissions. This complements visit evidence without recurring logging or geometry work. Physical route conclusions require an audit of the candidate containing this instrumentation.

Defence continuation retires its scheduler job and published order when group eligibility is lost, replacing an indefinite delayed-job state. Initial application, arrival/recovery and release watch/formation commands also recheck combat-effective actor ownership. Metadata cleanup remains unconditional so old orders cannot reappear after handover. Physical Zeus/player/specialist transitions remain pending.

The shared unlocked-door helper now requires combat-effective actor eligibility and actor-context ownership before opening a door. Group eligibility alone cannot authorize a captured or specialist-controlled actor's door interaction. Locks, distance and request cooldown remain unchanged; opening still does not establish physical entry.

Natural building-contact QA now searches bounded room/approach combinations for a clear VIEW ray before spawning, verifies an actual actor-eye sightline and enables the required contact feature through the tuning API. Missing visibility fails a distinct fixture prerequisite; native knowledge remains necessary and no reveal or clearance order is injected. The earlier batch contact stage was manually assisted by the user and cannot establish unassisted acceptance.

CBE local notifications pass title and body as separate CBA line arrays. The previous body string occupied the first line's numeric size parameter and caused a real client Params type error during convoy warning delivery. Static validation does not establish live rendering; the next exact-candidate batch must verify the warning appears without the client error.

Convoy IMMOBILE halts now retain their distinct operation phase through start, step and FSM routing, instead of being labelled OBSTRUCTION. They use the existing bounded halt cadence and shared scheduler, with unchanged stop/recovery decisions. This is diagnostic state fidelity, not proof of physical recovery.

Convoy release clears a crew target command only for combat-effective actors without actor-context takeover whose assigned target still matches CBE's recorded target. Protected actors retain their newer command while stale convoy target metadata is retired. Physical separate-crew-group and Zeus target handover remain pending.

Convoy FSM spacing diagnostics reuse dimensions cached by the immediately preceding ConvoyTick and the same aligned forward-gap projection as driving. They no longer repeat bounding-box queries every callback or report a lateral offset as longitudinal spacing. No driving policy, cadence or new worker is introduced; measured performance acceptance remains pending.

Convoy revision reacquisition retains predecessor trails/cursors but invalidates follower native/path command commitments once, because setup stops those followers. An unchanged endpoint can no longer suppress the first resumed movement command. Tracked 15 m resume failed in the active old candidate; this plausible contributor requires physical retest, especially for turn direction. Matrix resume assertions now include actual position/travel, speed, heading, command, destination and forced speed.

Tracked convoy resume replaces CBE's matching lead-vehicle current-position HALT command once with its existing MOVE waypoint destination. It requires the same group/owner halt marker and current driving authority, and retires that marker after issue. No waypoint replacement, fixed heading or recurring command is added. Tracked resume failures at 15/30 m remain unaccepted pending exact-candidate physical retest.

Convoy HALT retains one-second shared-scheduler cadence while any live local registered vehicle moves at least 1 km/h, then drops to the existing thirty-second settled hold cadence. This avoids treating an accepted halt as a physical stop and permits bounded crew/braking retries during deceleration. No extra worker or global scan is added. Tracked 75 m halt failure remains open until physical retest.

Separate convoy passenger owners now retry HALT unloading through a finite revision-scoped shared-scheduler job. It checks current registry identity, actor locality/ownership and remaining mounted cargo, handles at most sixteen records per callback at five-second cadence, and expires after ninety seconds. Vehicle movement remains with the convoy owner; all seat/safe-stop/new-task checks stay in ConvoyCrewLocal. Physical split-owner unload acceptance remains pending.

Survivor regroup is subordinate to newer group operations. Casualty-created and directly
queued jobs capture the operation generation once; a changed generation retires the job
without recalling its held actors. Surrendered, captive, incapacitated and externally owned
actors cannot become movers or receive regroup restoration. Host selection and continuation
use a capable local anchor, with capable strength distinct from the total membership cap.
Locality adoption retires this opportunistic merge; it does not fabricate a migrated merge
commitment. These changes require physical casualty, surrender, host-loss and handover retests.

Finite tracked reverse observes a bounded rear swept area for live infantry and vehicles.
A newly occupied rear area ends the reverse leg through its existing release path; collision,
damage and native pathfinding remain active. Physical obstruction and pedestrian acceptance
is still pending. Smoke delivery audits retain actual shell/landing requirements; rejected
requests fail delivery immediately rather than consuming an impossible 150-second wait.


### Standalone tactical drill migration

An unfinished advance, flank or assault publishes a bounded semantic checkpoint through the shared scheduler. It contains the committed route, bound index, fire teams, current actor destinations, absolute bound deadline and spent retry/recovery budgets. Stable server-time clock anchors keep countdowns from generating repeated network updates. The checkpoint is capped at 64 route records and 64 actors; it contains no FSM handles, scheduled callbacks or previous-owner feature leases.

Locality adoption checks the source operation generation, target, feature gate, external ownership, unchanged waypoint and applied combat/speed/attack policies before suppressing return-to-formation. It restores old leases, then allocates a fresh generation and owner epoch for the same intent. Current moving destinations are reused; completed bound destinations are discarded before the next phase. Member locality may settle for at most five seconds through the existing shared scheduler. Valid adoption preserves the combat phase instead of publishing an artificial CALM episode; failed settling records a release. A resumed assault retains its assault operation phase. A newer order, expired deadline, protected target or unsupported owner refuses resumption.

Coordinated bounds continue to use their server-role adoption path; this standalone checkpoint does not replace that protocol. `ADVANCE-HC-CONTINUATION` retains the hostile and checks route continuity, unchanged deadline and physical progress under the resumed generation. `ADVANCE-HC-HANDOVER` removes the hostile and separately checks native permission restoration and travel. Both cases are queued for a fresh packaged batch. Static validation is not physical acceptance, and continuity under disconnects, specialist interruption and performance load remains unaccepted.


Clearance egress retains each actor's exit destination while it makes new best approach progress. Arrived actors receive no additional movement command. One native route refresh is allowed after eight seconds without approach progress; the original 45-second exit deadline remains unchanged. Unlocked-door actions do not repeatedly reset a progressing exit route. Fresh clearance audits independently sample actor position and exit floor band, and record the bounded retry evidence. Physical egress remains unaccepted until the next packaged batch.


A stand-off pass without a firing solution enters its existing immutable egress leg before releasing flight ownership. The finite exit has a 75-second deadline and retains `NO_FIRE_SOLUTION` as the failed-delivery result. A physical exit cannot turn the missed attack into success. Zeus, external ownership and safety interruptions still release immediately through their existing guards. Physical no-solution egress is queued for packaged acceptance.


Coordinated acknowledgement, responder adoption and MOVE-to-COVER role changes end the outgoing drill as `ROLE_HANDOVER`. Matching posture, combat/speed and attack-permission leases are released without a follow, stop or return-to-leader command from drill cleanup. The incoming role remains the next movement owner. Actor feature restoration additionally rejects player, remote, specialist and declared external ownership. Physical role-transition continuity and specialist activation during release remain queued for packaged acceptance.


Coordinated admission distinguishes authenticated eligibility from an executing support operation. The server acknowledges the exact current-owner lease and publishes a token, owner and expiry for route preparation. Both requester and server dispatch consume that eligibility; only an executing assault status can claim the requester as base of fire. Prepared acknowledgement may coexist with an existing tactical drill but cannot claim its movement. Direct coordination uses the helper's live position as reservation metadata and does not require a safe rear rally route; reinforcement-only admission retains its separate rally routing. Physical direct-contact composition and HC re-acknowledgement remain unaccepted.


Coordinated bounds now use the same three-person minimum as responder admission. Three capable dismounts begin with two movers and one coverer; role changes rebalance the moving element before issuing a bound. Transferring a donor removes that actor from the available covering list immediately, preventing duplicate selection and false two-person strength. Fewer than three capable actors retires the coordinated role. Physical three-person movement, casualty replacement and unique-participant acceptance remain queued.

Coordinated support leases store their attack destination as one ATL position. Operation admission retains that complete position as its objective and initial route point; it must not interpret the coordinate array as a route and reduce the objective to altitude. This handoff correction awaits physical acceptance.

Coordinated covering roles retain their finite lease without requiring travel every thirty seconds. Their moving bounds retain separate physical-progress watchdogs. Cover stop orders are issued once per token/sequence transition and exclude player, remotely controlled and specialist-owned actors; normal rally still retains aggregate no-progress failure.

Legacy support PATH holds retire their CBE marker during calm, support and withdrawal cleanup. Restoring PATH or issuing follow commands separately requires an ordinary local actor without player, remote or specialist ownership. Removing CBE metadata is not permission to alter the replacement controller's movement state.

Support acknowledgements must match the exact six-field lease and current owner. A delayed acceptance becomes rejection when either the lease or request has expired; it cannot publish fresh prepared eligibility. Matching rejection remains valid for cleanup.

Coordinated bound selection continues through its bounded responder list when an eligible element has no safe next route. It stops scoring after the first viable bound. Eligibility alone must not consume a movement slot or prevent another element from progressing.

A coordinated next-bound geometry rejection permits one retry after eight seconds, without blocking other elements. A second rejection retires that token as NO_SAFE_BOUND. Selecting a viable route clears its geometry-failure count. This is finite failure handling, not proof of route success or physical acceptance.

Building room progression opens usable doors without replacing committed movement solely because a door changed. Interior no-progress retries affect the room mover, retaining the partner's security destination; entrance staging can still retry the pair. Physical room visits remain the only completion evidence.

A CQB reserve replacement rebases best-distance observation at its actual position. The committed room cursor and generation-owned recovery budget remain unchanged; a removed actor's closer baseline must not hide real approach progress by the reserve.

Moving bounds lease individual RED orders as YELLOW while retaining native target and fire features. Cover/release restores the exact prior mode only if unchanged. BLUE/GREEN holds are not escalated. This repair follows native ATTACK diversion in the b3a9f70 batch and requires physical retest.

Between-bound restoration uses the same actor-task ownership guard as movement admission. New player, remote, specialist, boarding, treatment and independent actor reservations block restoration of former CBE combat modes, behaviour and AI features, even when the former applied value is unchanged.

Support release retires its exact token-matched tactical bound before shared operation cleanup. It uses ROLE_HANDOVER without formation recall, preventing an old queued drill from blocking a replacement bound as NOT_READY. A different drill token is untouched.

Coordinated fire-team bounds inherit the existing support operation generation and owner epoch after validation. They do not start a second operation. This enables the common interruption, attack-delegation and exact restoration paths already used by standalone tactical drills.

Combined-arms discovery preserves an asset's unexpired role from another opportunity. Separate requesters cannot overwrite that reservation; matching tokens or expired roles remain eligible for validated dispatch. This protects simultaneous local contacts without creating a battle-wide assembly controller.

Combined ground manoeuvre admission refuses OTHER_INTENT_ACTIVE when an existing local operation has a different intent or target. It does not cancel that operation or reveal the new target through the refused move. Fire-only support remains a separate non-movement opportunity. Compatible same-target combined intent can continue through normal generation validation.

Ground-support refusal retires its exact reservation on the server through current-owner and snapshot validation. It retains the refusal result, clears only matching role metadata, and never cancels the asset's existing operation. Repeated or replaced replies are no-ops; aircraft retains its separate fallback path.

Combined ground-fire admission checks both group and gunner fire permissions, current operator ownership and the shared friendly/civilian firing-lane guard. NO_FIRE_OPERATOR and BLOCKED_FIRE_LANE retire the exact reservation instead of publishing APPLIED. This is one admission check, not a persistent scanning loop; native aiming and weapon release remain responsible for actual fire.

Combined ground arrival uses the same fire permissions, actor ownership and friendly-lane checks as direct fire admission. CombinedFireDecision records ORDER_ISSUED or a refusal, separately from physical POSITION_REACHED. Neither receipt proves shots, suppression or destruction; combat acceptance still requires fired and target-effect evidence.

### Scheduler and tactical FSM authority

Queue admission rejects a non-local group or a supplied owner epoch that differs from the current
epoch. It assigns the current epoch only to new work without a conflicting proof. Keyed coalescing
requires the same group and epoch, updates the existing state and due time, and returns from the
function before append. A stale callback cannot become fresh by being queued again.

Tactical FSMs retire when their drill token or operation generation is superseded. Building queue,
callback and finalization boundaries require the current brain and owner epoch. Aircraft waiting
states retire replaced/non-local brains before invoking control-handover actions. These checks
retire old work; they do not complete, restore or command a successor operation.

Real tactical stage changes update the matching operation to MANOEUVRE, ASSAULT, SUPPORT or SECURITY.
Ending a coordinated child never completes its parent. Danger posture reads the matching child's
moving and recovery actors rather than treating every participant as a mover. Cover actors retain
native low-profile protection; active movers retain mobile protection.

The coordination batch now includes scheduler component and physical movement cases. Component
cases measure one keyed callback, updated state, retirement, rejection without epoch rewriting,
fresh-owner execution and no old-epoch execution. They supplement physical movement, interruption,
HC and performance acceptance; they are queued and have not passed in game.
A keyed callback may request an earlier wake while it is running. The scheduler carries that wake into both the rescheduled job and its cached earliest deadline, so the idle gate cannot postpone immediate reassessment until the callback's normal cadence. The additive scheduler audit checks a self-wake against a twenty-second return delay; physical acceptance remains pending.

Keyed updates coalesce only within the same explicit generation as well as group and owner epoch. Stable aircraft observer keys therefore cannot adopt an earlier generation's braking or landing progress after locality changes. The retired callback retains its original generation for its existing release checks; fresh work receives separate state. The additive generation-isolation audit remains pending in game.

Group decision admission and execution also require the supplied brain to match CBE_GroupBrain on the current group. A detached brain with a matching numeric generation is rejected before queuing or tactical commands; execution records SUPERSEDED only on that detached state. This safeguard follows the existing building and aircraft brain contract. In-game interruption acceptance remains pending.

Convoy admission, execution and FSM replacement transitions require the registered CBE_Convoy_Brain as well as the registry revision and job token. Delay watches token or brain replacement immediately, including a thirty-second settled hold; replacement does not wait for the next due step. Physical convoy replacement and locality acceptance remain pending.

The group tactical FSM watches registered-brain replacement in Router, Delay and Waiting. Finished cleanup additionally requires the captured owner epoch and registered brain before clearing group state or releasing tactics. A detached same-generation FSM audit executes the packaged FSM and checks retirement without clearing the live brain; this case remains pending in game.

Support and artillery Delay states watch registered-brain replacement as well as generation changes. Support Waiting retires superseded work before invoking Zeus or external cleanup callbacks. Final bookkeeping requires the matching generation and registered brain. Existing current-generation interruption cleanup remains active; these paths await packaged runtime acceptance.

Building Router, Delay and Waiting now watch registered-brain replacement directly, matching queue and execution guards. A detached same-generation packaged-FSM case verifies retirement without altering the registered sweep brain. This lifecycle case remains pending; physical entry, room visits and traversal are still separately unaccepted.

### Clearance exit progress

Each exit assignment retains physical arrival within five horizontal metres and the 1.5 metre floor band for its current owner and operation generation. Once observed, that exit is complete even if native formation later moves the actor away; CBE does not pull it back while a partner descends. Replacement ownership still cancels routing, and an unavailable actor or unvisited exit retains failure evidence. The existing one-refresh recovery bound and 45-second deadline remain. This uses the existing bounded building callback, with no extra scanner or per-unit worker. The two-person case has physical clearance and handover evidence; the larger-house exit-latching repair still requires its next packaged retest.

Clearance replacement orders suppress formation recall independently of setting cleanup. Ordinary local actors release unchanged CBE speed and posture leases even when a temporary curator hold preserves the new movement destination. Direct control, specialist ownership, explicit external ownership, conflicting actor reservations and native action tasks still prohibit writes. Edited settings survive. This repairs a receipt-erasure path that could leave an indoor speed cap applied after cancellation; physical replacement-order validation remains pending.

Room recovery consults durable native retry counts before starting another isolated actor attempt. Reserve replacement and owner replay cannot reopen that room budget: one lane permits one recovery cycle, and multiple lanes permit at most two before exhaustion is handed to another lane or recorded incomplete. A yielded native task keeps its claim without new movement or an unreachable classification; the existing operation safety deadline still applies. No room is credited without physical arrival. This bounds a twelve-person repeated-replacement failure; packaged physical acceptance remains pending.

### Native order cancellation during clearance

Clearance captures a bounded receipt of the current native waypoint and waypoint count. Its callback compares that receipt before any room, recovery, speed or posture write. A new or edited authored order cancels the matching clear as NEW_ORDER, releases unchanged owned settings without formation recall and advances the operation generation. The implicit spawn waypoint is excluded. The durable clearance order retains the receipt so locality replay refuses a superseded intent. This adds no waypoint scan or new worker; physical replacement-order and HC acceptance remain pending.

Clearance checks the individual native task immediately before initial room movement, posture/speed changes, stalled retries and exit commands. Boarding, medical, service, joining and assembly actions yield without fresh movement or consuming route-failure retries; other lanes continue. The existing finite deadline remains. These guards use current actor command state in the existing callback; native-task physical regression acceptance remains pending.
# Clearance exit arrival ownership

Room movement keeps native building positions as its destinations. The geometry-only nearby floor adjustment was removed after a normal live audit showed its converted 8.62 m ASL target producing a native path endpoint at ground-floor 5 m ASL. Floor support does not establish native navigation connectivity. Physically established access checkpoints and finite recovery remain; no adjusted point grants room coverage. Upper-floor reliability and performance acceptance remain pending.

Clearance records only its issued native movement destinations, including finite recovery requests. On a changed group waypoint, an ordinary actor still executing MOVE is released to the current leader only when its live destination matches that issued request within 0.25 metres and actor/task/external ownership remains eligible. A different actor destination is preserved. Active cancellation releases matching moves and known STOP holds directly after the old operation retires, rechecking the owner, epoch, generation, registered brain, actual command and new order. Already completed STOP holds retain their receipt-based handover. The physical audit includes a newer, distinct actor destination with actual travel and old-clearance retirement requirements. Planner-adjusted endpoints outside the conservative match remain unaccepted; this is not a blanket movement reset or general external-script ownership guarantee.

The normal clearance audit also observes the real actors' native PathCalculated events, with a maximum of 24 samples per actor, eight-second spacing and 24 sampled path points plus the last point. Handlers are removed before disposable actor cleanup. This is diagnostic only: a calculated endpoint is not a physical visit, and segmented routes are not automatically classified as failed paths. The accompanying insideBuilding sound-interior value is supplementary evidence, not a universal geometric admission requirement.

Physical room/support arrival now holds that actor once per destination between pair handoffs; an unchanged stopped support target is not restarted. Follow-through arrivals hold once while remaining members finish. Newer native orders include these room holds in the same receipt-based release. An ordinary mover stranded by exhausted recovery remains a failed-participation result even when replacements or other members complete shared room coverage. Death/incapacitation replacement remains a separate contingency. These changes require fresh physical acceptance.

Initial exterior admission waits when every cached recognised door is locked and closed. The bounded building job holds ordinary admitted actors once, observes live locks and resumes the normal first-room request when access becomes available; expiry remains a failed/cancelled operation. It does not unlock or open locked doors. Actors initially inside the live model bounds are exempt from this exterior barrier. Unknown door conventions, partially locked access, per-entrance routing and mid-clear locking remain unaccepted; model bounds alone do not establish a safe room. Status is published only on admission transitions, without repeated broadcast or movement writes.

Active clearing members must each physically visit two distinct reported positions (or the sole available position) before successful egress. Shared coverage alone cannot finish a member parked at the first node. Once coverage and entry are established, a finite native follow-through chooses from at most 24 remaining visited nodes, preferring the current floor; common recovery remains one attempt and failure cannot become a successful visit. An independent audit now checks every initially admitted worker, with reserves outside that admission kept separate. These are navigation receipts, not proof that a hostile room is safe.

Reserves receive an initial actual-position hold before their single staging geometry attempt. If that attempt is rejected, the hold remains rather than leaving native formation following an interior leader. Ordinary room movers retired by common recovery likewise receive one guarded hold; player, specialist, medical, actor-reservation and newer-order ownership still prevent commands. This prevents two sources of exterior wedge formation but does not provide tactical security sectors. Existing terminal handover/cleanup includes these actors.

A newer native waypoint releases pre-completion holds through the clearance owner's cancellation path. It clears its old hold receipt before any release command and does not depend on an ordinary group brain remaining live after a failed clear. External takeover receives no old formation command. Completed-clear holds remain governed by the separate public receipt path. Physical interruption acceptance remains required.

Interior mover changes retain one finite route checkpoint when the new mover is off the next room's floor: the pair's preceding physically visited node must lie on that target floor. The actor must actually arrive within the existing three-dimensional tolerance before the final room request resumes. The checkpoint does not mark a room clear, change a floor coordinate or add a recurring controller; existing room recovery and cancellation bounds apply. This dynamic route-continuity change requires packaged physical validation and does not claim to solve all stairs or model path faults.

During the finite EGRESS phase, each clearing actor receives one native exit destination. Confirmed horizontal and floor arrival records a monotonic receipt and issues one owner-guarded stop at the actual arrival position. Later steps do not rewrite that hold. This prevents an early arrival from resuming formation while its partners are still exiting. New native orders, Zeus or specialist ownership still supersede the controller. Terminal settlement retains actual positions and an order-scoped hold even when the result is INCOMPLETE; it must not recall workers around an interior leader. Cancellation retains its existing cleanup path. This change adds no recurring actor controller or geometry scan. It does not yet provide security sectors or a complete tactical consolidation phase, and requires a fresh packaged physical retest.

### Clearance leader handover correction

The d61afa9 normal clearance batch completed 408 checks with nine failed assertions, all in the twelve-person case. Two- and six-person admitted-worker progression and physical handover passed in this run. Twelve-person upper-floor routing, settlement and handover remain unaccepted. The geometry-supported floor alternative was used but native paths still projected its target onto the ground.

Recorded handback receipts showed a healthy, local stopped leader following itself. New ordinary MOVE waypoint handover now sends only that held leader to the current authored waypoint position; followers resume following the leader. Waypoint lists remain intact, different actor destinations remain protected, and non-MOVE waypoint semantics receive no positional substitute. The same correction applies to the completed-hold consumer. Physical retest is pending. This does not establish tactical consolidation or coherent reserve security.

### Shared physical floor access

An entered pair whose preceding node is on the wrong floor may use another lane's physically visited node on the destination floor as a native access checkpoint. Selection examines at most 24 original visited nodes once per changed coverage snapshot, chooses the nearest matching floor, and caches one approach per claimed room. Actors must physically reach that checkpoint before the assigned destination is requested; neither checkpoint selection nor arrival clears the assigned node. No model route table, coordinate lifting or additional actor controller is introduced. Physical retest is pending; this change does not assert that the native planner can reach every reported building position.

A stalled unentered partner uses its existing one-shot entry recovery to retry the original lane anchor after that anchor has been physically visited. A nearby geometry-connected candidate is not treated as a proven native access path. The shared entry target is changed once at recovery and subsequent pair steps retain it; actual interior visits and common recovery limits still govern success. No additional retries, immunity or simulated entry are granted. Physical retest is pending.

### Absolute clearance episode lifetime

Physical progress may renew the existing 240-second stall lease, but cannot renew the separate absolute episode boundary. Initial admission sets that boundary using 60 seconds per filtered interior node, with a 240-second minimum and 900-second maximum. The eleventh public clear-order field carries its server-clock timestamp across owner migration; legacy orders retain their published deadline as the boundary rather than receiving a fresh lifetime. Progress publication preserves this field unchanged. Exhaustion moves into the existing finite 45-second egress phase and preserves missing room/worker participation as failure. Wholly locked admission obeys the same earlier boundary. No elapsed timer passes physical clearance. Absolute-lifetime physical acceptance remains pending.

Once shared coverage is complete, entered workers continue their finite individual follow-through without waiting for every partner to enter. Unentered partners remain with entry recovery; they are not assigned interior follow-through or counted as successful. Missing entry and successive visits still latch an incomplete result before egress. The episode boundary is checked before further follow-through movement is issued. This removes a collective waiting barrier, not the individual participation requirement. Physical retest remains pending.

The clearance audit retains its original 245-second physical sampling and 15-second settlement findings. If a hard boundary exists and settlement is still missing, a separate diagnostic waits only through that absolute boundary plus the existing 45-second egress budget and ten seconds of observation tolerance. This does not rewrite original findings, collect substitute room visits, inject movement or call cleanup; it checks finite terminal publication before the subsequent ordinary waypoint handover.

### Native planning-mode traversal diagnostic

Independent excluded actors now include a fourth FORMATION control alongside DIRECT, HOUSE-WAYPOINT and REPLAN. It issues ordinary native movement and a forced FORMATION PLANNED destination for the original model node, then observes actual 3D entry and successive visits under the same node budgets. Original controls remain, placement is recorded rather than corrected for this native comparison, and a skipped node remains failed. Different fixture instances prevent treating one run as a definitive mode ranking. No production routing mode changes are made from this diagnostic alone. Physical results are pending.

### Exposed model positions retained for transit

Clearance retains the complete original engine position array separately from its roof-covered target set. Exposed positions remain excluded from clearance coverage but may supply a floor-access candidate during an off-floor interior request. Selection examines at most 32 exposed positions in original metadata order, requires a same-building upward floor surface within 0.75 metres of the original point, and caches success or absence once per half-metre floor bucket, with at most eight buckets per episode. A preceding visited same-floor checkpoint remains preferred. If no supported exposed point is found, the existing bounded shared-interior checkpoint search remains available. Actual checkpoint arrival is required before the assigned room request; it cannot clear that room. No classname routes, coordinate lifting, object repositioning or second movement writer are added. Native raw large-house controls reached exposed upstairs positions across all three movement modes while later interior nodes failed, motivating this routing distinction; production physical retest is pending.

An initial lane assigned above its actor's current floor may also request this transit approach before its first covered-node visit; transit selection itself does not establish entry. Checkpoint completion requires 3D proximity within 1.5 metres and feet on the checkpoint floor within 0.75 metres, preventing a nearby actor on lower stair treads from prematurely switching to the room target. Partner flow and progressive reserve admission remain unaccepted.

Covered-node visit receipts and arrival holds now require feet within 0.75 metres of the node's absolute floor elevation as well as 1.5-metre 3D proximity. Pair handoffs consume the visit collector's actor-specific receipts rather than creating separate proximity-only entry receipts. Matching production audit samples apply the same floor requirement. Transit buckets and off-floor comparisons use absolute ASL elevations, avoiding terrain-relative floor comparisons on slopes; native destination coordinates remain unchanged. These stricter checks may expose additional failures and remain pending physical retest. They do not prove a room safe or establish full CQB acceptance.

### Actor-specific buddy handoff route

An unentered or off-floor mover that has not personally visited its buddy's preceding covered node first receives that original node as a physical handoff checkpoint. An already-entered mover on the destination floor requests its next room directly, avoiding a redundant stop at its buddy's occupied security node. An off-floor request may then append one destination-floor access checkpoint, using visited shared access before unvisited supported transit candidates. Each actor/pair/room retains an ordered approach of at most two legs. Three-dimensional arrival and absolute floor proximity are required before advancing; new actors receive their own approach identity. Neither a handoff nor a transit arrival clears the assigned room, resets the durable room/actor recovery budget, or extends the episode lifetime. The previous target-floor-only approach could skip the preceding ground-floor room during mover rotation. Physical retest is pending.

### Native leg commitment and hold receipts

Room visitation tolerance is separate from native movement completion. An actor whose MOVE destination still matches this job's issued target is allowed to finish that leg before a room handoff, checkpoint advancement or arrival hold. Native readiness or precise arrival within 0.4 metres ends this commitment; the episode and recovery bounds still apply. Arrival holds cannot stop a different live MOVE destination. Each new owned request retires its prior room-hold receipt, and a stopped actor displaced from its recorded target is not treated as already settled. Confirmed exit-arrival records remain explicit handover candidates when a new waypoint interrupts egress. This adds no second movement controller. Physical retest remains pending.

Successful coverage transitions also wait for active owned native legs to settle before exit dispatch. Deadline exhaustion and unreachable work retain their finite failure cleanup. Terminal restoration skips a different live MOVE destination; releasing unchanged CBE stance/speed settings remains separate from taking movement ownership.

Active clearance workers also retain movement ownership when a failed native path silently returns them to formation. The existing owner-local building step holds the actor's actual position once per issued request only when no new request is being issued, the command is empty, unitReady is true and the planner reports DoNotPlanFormation. Explicit FOLLOW, newer MOVE, specialist tasks and takeover remain untouched. The next owned movement request retires this fallback hold; newer native order cleanup includes stopped fallback actors. Existing finite retries still recover or fail the route. This prevents one identified source of wedge drift; physical repeatability and coherent security/consolidation remain unaccepted.

Reserve staging acceptance excludes soldiers promoted into the active clearing roster. Their old staging record is not their current movement assignment.

Geometry-supported raw transit nodes are provisional access candidates. During clearance, a candidate that stalls under the existing observation interval is abandoned once for that actor/room claim. The original room remains the objective and is issued through the same owned movement writer. An abandonment tombstone keeps its arrival flag false and prevents immediate recreation; it neither marks coverage nor renews the progress deadline or resets retries. Covered buddy handoff checkpoints are not abandoned by this path. Physical room recovery and locality migration acceptance remain pending.


Reserve staging arrival requires three-dimensional proximity, matching floor height and completion of CBE's own native movement leg. A different MOVE or FOLLOW cannot be stopped by a stale stage receipt. This uses the existing callback and movement receipts; no recurring controller is added. Physical reserve and newer-order interruption acceptance remains pending while game audits are paused.


A current-generation staged reserve with a different live individual MOVE or FOLLOW is excluded from staging and casualty promotion until that command ends. Its owned stage MOVE remains eligible for promotion. This protects the individual command boundary that the group waypoint receipt does not represent; it adds no scan or movement writer. Staging metadata is not an independent movement controller, so its retention alone does not explain CQB entry delay. Physical replacement-order and casualty acceptance remains pending with audits paused.


Standalone driving retires its cap when the vehicle is destroyed/immobilized or its driver is combat-ineffective. Immediately before recovery/cap commands it rechecks vehicle mobility plus driver and effective-commander ability, alongside existing ownership and MOVE/PATH boundaries. It does not repair damage, fuel, relocate vehicles or force seat changes. Crew casualty replacement remains a distinct incomplete capability. This source correction follows local controller review; physical casualty/immobilization acceptance and runtime performance remain pending while audits are paused.


Convoy follower pacing distinguishes predecessor reverse motion from forward travel using the existing vehicle-local longitudinal velocity sample. Below -0.5 m/s, follower requested speed is zero after smoothing/lateral recapture and before infantry safety limiting. Route commitments remain intact; ordinary pacing resumes when reverse motion ends. No extra sensor loop, waypoint replacement or recovery budget is introduced. The prior absolute-speed input could command forward travel toward a backing predecessor. This source fault is separate from unresolved mixed tracked/wheeled stop/start and spacing observations; physical reverse-yield, restart and convoy acceptance remain pending with audits paused.


Tracked reverse admission/continuation requires combat-effective driver and commander, not alive crew alone. Reverse cleanup sends STOPTURNING only when the live LEFT/RIGHT command matches its recorded last turn; a different turn is preserved. Generation, epoch, vehicle marker and external-owner checks remain required. This matching guard cannot distinguish an identical later native command without an ownership/order receipt, so universal successor preservation is not claimed. Reverse distance, timeout and facing limits remain unchanged. Physical crew incapacity and different-turn handover are pending with audits paused.


Convoy mobility eligibility is computed once before locality filtering. The same combat-effective-driver roster is used for split-locality comparison, so an unconscious/incapacitated driver no longer masquerades as an eligible remote vehicle and indefinitely bypasses the tick. Real eligible split locality still defers commands; no effective vehicles still reaches the existing IMMOBILE request. Remaining mobile vehicles retain existing continuation/contact policy. This does not implement seat replacement or prove casualty continuation; physical incapacity, migration and halt acceptance remain pending while audits are paused.


Convoy horizontal projections now use unit bearings derived from vehicle heading. Zeroing vectorDir's vertical component without renormalizing previously shrank forward distance by the cosine of vehicle pitch and fabricated lateral offset: a straight 30 m gap at 30 degrees pitch appeared about 26 m forward and 15 m lateral. Spacing/phase diagnostics, obstruction classification and forward trail acquisition now share the corrected horizontal metric. Physical gap/speed thresholds and turn handling remain unchanged; the audit retains its independent route-axis observation. This proves a calculation fault, not its contribution to observed mixed-convoy stop/start or physical terrain acceptance. Audits remain paused.


Convoy operation brains explicitly carry subsystem CONVOY into the shared queue. The prior omitted tag defaulted them to TACTICS, selecting the infantry active gate and pause deferral despite the dedicated convoy registry/scheduler flag. Correct classification uses the existing CBE_Convoy_SchedulerActive gate and existing safety-subsystem scheduling rule; no extra loop or new setting is introduced. ConvoyTick still enforces its own pause, Zeus and external-owner command boundaries, so this does not authorize movement during a tactical pause. Driver incapacity itself does not retire convoy callbacks through a leader-effectiveness gate. Physical pause, disable, incapacity and migration acceptance remains pending while audits are paused.


Temporary global tactical pause is recorded as PAUSED rather than EXTERNAL_OWNER in convoy lease release. The finite convoy brain remains registered, reports SUSPENDED and observes at five-second cadence through the existing queue. CBE local driving leases release once; pause is not a fabricated arrival, obstruction or transfer of ownership. On resumption the tick reacquires from current native state, while player/Zeus/specialist/external takeover still terminates old ownership. Semantic suspension clears obsolete spacing/recovery counts. Physical pause/resume, persistent HALT and locality migration remain unaccepted; no game audit was launched.


Suspended convoy resumption clears common operation state only when its saved operation generation, CONVOY intent and current owner epoch still match. Previously it unconditionally erased CBE_Operation after eligibility returned, including a successor explicit operation. Current-route reacquisition remains required. Eligibility rejection still combines feature/faction filters with external actor orders; its early return can retain old driving leases. That broader suspension/restoration distinction remains unresolved and is not repaired by this successor guard. Physical resume/handback acceptance remains pending while audits are paused.


Shared ownership takeover now recognizes the already-supported active curator garrison and suppression actor flags during cleanup/command boundaries as well as admission. Actor-local contexts remain limited to that actor; ordinary group commands retain group-wide protection. Addon presence alone grants no ownership. This closes an admission-versus-restoration discrepancy and supports safer filter reasoning, but does not by itself resolve all convoy eligibility-filter lease release or establish controller handover acceptance. Broad compatibility expansion remains deferred. Physical curator-order interruption/cleanup remains pending while audits are paused.


Old convoy cleanup treats a different current movement-operator group as successor ownership, including ordinary AI groups without an external-controller marker. It preserves that vehicle's speed/unload policy and does not recall a driver from another group. Empty vehicles can still release their unchanged old cap; old-group metadata is retired without overwriting a new group's receipt. This closes a group-transfer restoration gap but does not establish all callback/event-handler transfer or filter-only lease cleanup. Physical AI-group reassignment/handback remains pending while audits are paused.


Convoy hit-handler IDs now carry a local group/machine ownership receipt. Current crew processing adopts the generic handler for its active convoy without duplicating it; cleanup removes only a matching local receipt and preserves a successor group's adopted handler. Unreceipted legacy handler cleanup is not presumed owned. The existing passenger-HALT follow-up job is also tagged CONVOY, using the registry scheduler gate and its existing revision checks. Neither correction creates a polling loop or completes handover/JIP acceptance. Physical hostile-hit continuity, repeated cleanup, owner migration and suspended passenger processing remain pending with audits paused.


Clearance topology requires an overhead GEOM hit belonging to the target building or its parent object. The existing ten-metre roof probe examines at most four hits per original model node. Neighbouring overhead objects cannot classify a point as a room, and an empty owned-roof set is refused/logged rather than promoting all exposed model positions into clearance. Original coordinates remain unchanged; garrison/raw transit metadata remains separate. This is an admission/topology correction, not wall-separated actor visit proof or universal building support. Tall/unusual models outside the probe envelope and repeatable physical clearance still need evidence. Audits remain paused.


Production room visit/entry receipts and close room holds now reject intervening target-building GEOM surfaces at body height. Existing proximity/floor bands remain required. Callback-local pose/target caching caps new geometry probes at sixteen, each with at most eight hits; saturated results and exhausted budget cannot grant a receipt. Worker observation rotates each callback to avoid permanent first-worker preference. Original coordinates, movement ownership, retries and deadlines are unchanged. This source implementation still needs an independent exterior-wall audit, furniture/door/floor edge cases, dense-worker fairness and matched performance evidence. Existing audit proximity flags remain weaker and cannot establish this new boundary's acceptance. Game audits remain paused.


Building command boundaries and room-geometry cache reads now recheck registered brain identity, cancelled/finished flags, locality, owner epoch, clear generation and the bound common-operation generation. Building existence/transform, external takeover and authored native order remain live checks. Thus cached geometry cannot authorize room receipts or movement after a replacement operation or moved/deleted building invalidates ownership. The callback-local cache/budget remains unchanged; no new observer or lifetime extension is added. Physical supersession during work, transform cancellation and performance acceptance remain pending with audits paused.


CQB geometry queries that cannot grant a receipt now return before repeated ownership/config scans when their ray quota is exhausted or the exact callback-local pose/target already has a negative result. Cached positives and new probes still pass current brain/generation/epoch/order/transform and external-ownership checks. No dynamic ownership decision is cached, no query becomes a positive through budget exhaustion, and the sixteen-probe ceiling remains. This reduces avoidable source work without mutating the read-only ownership gate; measured runtime benefit and performance acceptance remain pending with audits paused.

Reserve staging constructs its bounded migration journal only when a search is consumed, an approach physically arrives, or an owned approach times out. Unchanged callbacks retain the previous receipt; authority and content comparison still gate publication. This reduces idle allocation work but has not been measured against the live frame-time budget.

Convoy lateral recapture retains the longitudinal closing-distance cap. A sideways offset beside a stopped predecessor cannot raise the requested speed above the safe closing cap merely to regain the trail. This adds no scans or controller. Physical offset recovery, mixed tracked/wheeled stop/start and convoy acceptance remain pending.

Reinforcement casualty assessment compares current combat-effective strength with the retained peak living roster. Unconscious, incapacitated, captive and surrendered actors do not count as available combat strength; conscious wounded actors still do. The existing responder cap, request tokens, bounded retry and 300-second assignment expiry remain. Physical casualty-triggered reinforcement arrival and CQB replacement remain unaccepted.

The owner-local group decision job defers planning for five seconds when every living member is hidden or simulation-disabled. It retains the same shared scheduler job and does not force simulation on, create a pending-order worker, release ownership merely for dormancy, or extend finite operation deadlines. Dead groups still retire. One awake visible member permits ordinary reassessment; individual operation participant readiness and explicit dormant-order admission remain separate work. Physical dynamic-simulation wake, hidden actors, Zeus replacement and HC migration tests remain pending.

Clearance room-visit evidence requires a visible, simulation-enabled combat-effective actor. A dormant or hidden participant cannot credit a new visit from a frozen stored position. Existing geometric, distance and floor checks remain. This does not change cleanup or solve dormant participant routing; physical dormancy and clearance tests remain pending.

Clearance command checks now require simulation-enabled visible actors; reserve staging and promotion use the same dormancy conditions. The existing owned-actor predicate remains separate, preserving roster obligations and guarded setting restoration for dormant workers. This does not extend operation deadlines, enable simulation or make dormancy a casualty. Explicit dormant admission and comprehensive egress/recovery handling remain pending, as do physical tests.

Clearance egress preserves an already observed exit but cannot establish a new exit from a hidden or simulation-disabled actor position. Dormant unresolved assignments remain in the exit roster and skip retry bookkeeping until awake; the original finite egress deadline still ends an unresolved exit as incomplete. No simulation or deadline is changed. Physical dormant exit/wake tests remain pending.

Common native recovery returns YIELDED for hidden or simulation-disabled actors before reading recovery history and again before committing a retry. Dormancy therefore issues no recovery move and consumes no attempt; current roster ownership, operation generation and original lifetime remain. Wake can reconsider the same finite generation if it is still valid. Physical wake, casualty and HC recovery acceptance remain pending.

Shared operation progress requires a visible simulation-enabled observer, for both declared participants and the leader fallback used by participant-free operations. Hidden or dormant position changes cannot renew lastProgressAt or reset replans; participant baselines remain at the last meaningful physical observation. Recovery observation timing and dormant wake baselines still need separate policy. Physical evidence and performance acceptance remain pending.

Defence initial movement and arrival use three-dimensional distance; holding additionally requires the destination height within 1.5 m. Horizontal proximity on another storey cannot establish a held defence slot. Existing owner/generation guards and bounded route refresh remain. Physical raised-position defence, routing and cleanup acceptance remain pending.

Garrison records every issued native movement destination with group, generation and owner epoch. Release recalls MOVE only when the live three-dimensional destination matches that receipt within 0.25 m; newer MOVE/FOLLOW is preserved while owned PATH cleanup stays separate. Receipts are retired on release. Continuation command fencing and owner-migration adoption still need completion; physical release tests remain pending.

Garrison continuation movement gates now compare current MOVE against the retained exact group/generation/epoch destination receipt and reject FOLLOW. Door-triggered movement, arrival holds and bounded retries therefore yield to a different individual MOVE/FOLLOW. Initial admission, migration adoption and post-yield assignment cleanup remain separate unfinished work; physical interruption tests remain pending.

Garrison release accepts an optional third argument containing actor objects; an empty list retains whole-group release. The existing owner-local decision job detects individually replaced MOVE/FOLLOW against exact garrison receipts and releases only affected actors with formation recall disabled. Their owned PATH locks, handlers and assignments retire; other actors and the group order remain. Example: `[_group,false,[_soldier]] call CBE_fnc_CortexGarrisonRelease;`. Migration adoption, native service-task reconciliation and physical partial handover remain pending.

After actor-scoped garrison release, the group order remains only while at least one member retains a garrison assignment. Releasing the final assignment retires the published order, candidates and applied marker so subsequent group decisions can use ordinary behaviour. Remaining defenders retain their assignments. Physical final-actor handover and repeat/locality tests remain pending.

The existing garrison actor reconciliation also yields assignments to native boarding, service, medical, carry and assembly tasks. It invokes subset release without movement recall. Owned PATH and handler metadata retire; the release task guard preserves task-owned posture/watch/speed. No replacement command or extra scheduler is added. Physical service handover, partial occupancy and migration remain unaccepted.

Support handover compares the coordinated request contact area with the drill retained numeric believed enemy position, within the existing 75 m area. It no longer reads the live target object location for this match. Missing/malformed belief declines handover of a live-target drill; target liveness, movement ownership and finite delivery guards remain. Hidden-target movement, stale contact and independent subcontact coordination remain physically unaccepted.

Coordinated attack dispatch now carries the requester confirmed-contact time on the shared serverTime clock to server and helper owner. Both require it within the existing 60-second window; delivery and HC migration do not refresh it. Discovery position-only receipts still permit provisional eligibility, but attack execution requires timestamped contact. The internal SupportAssaultServer fourth argument is required for execution; its default -1 declines unknown age. This uses the existing lastSeen confirmation, not exact native per-target age/error provenance; those and ongoing contact refresh remain open. Physical delayed-delivery/migration tests remain pending.

Confirmed-contact freshness gates new attack authorization, while an exact already executing assault token may continue or adopt ownership under its unchanged finite lease. This requires matching published active/assaulting status plus local assault state or explicit owner adoption; a provisional rally cannot use it. No confirmation time or expiry is refreshed. Ongoing contact-loss and physical HC continuation acceptance remain open.

Owner-local artillery shots require a combat-effective operating gunner at preflight and immediately before doArtilleryFire. The final boundary also requires the same gunner, local battery, current mission token and group eligibility after safety/ammunition checks. Changed or incapacitated operators reject rather than receive the command. Physical medical/operator replacement and support/smoke/counter-battery fire remain unaccepted.

Assigned artillery observers must be visible and simulation-enabled before producing a fix. Fix generation is read-only: it neither draws binoculars nor changes native watch/target orders. Native and mission weapon selections are not overwritten by group-tick cleanup. Dormant observers return no observation; this does not establish counter-battery acquisition or physical fire acceptance. Counter-battery radar/visual qualification is implemented by the later changes below; audio localization, report-age provenance and physical effects remain unresolved.

Explicit counter-battery observer requests scan at most four cached observers per scheduler step and expire fifteen seconds after admission. Each step cancels on pause, inactive CBE or disabled counter-battery, and each observer must retain its group feature gate before observation reports. This finite legacy observation path is not yet connected to automatic emission acquisition; detector provenance and qualified relocation remain open.

Convoy follower speed smoothing now extends to the safe lower spacing boundary while the predecessor moves above 2 km/h. The existing closing cap still overrides smoothing, and stopped/reversing predecessors retain immediate braking. This removes the requested-gap discontinuity in smoothing without granting extra compression clearance. Mixed tracked startup, spacing and restart remain physically unaccepted.

When clearance replaces lane members and no physically entered member survives, that lane restarts admission at its retained first route room. It clears inherited entry and previous-room state without erasing shared coverage, rebuilding routes or extending the deadline. A physically entered survivor retains its current lane progress. Whole-pair casualty replacement and coherent physical join-up remain unaccepted pending separate normal/HC audits.

Combined-arms opportunity dispatch preserves the supplied visual-contact age in its observation timestamp. Nonfinite, negative-age, missing-time and future-time observations reject before asset selection; delayed delivery cannot reset the original observation age. The separate ground-fire, ground-manoeuvre and aircraft roles remain partial: live effects, multi-contact allocation, physical migration and performance acceptance are pending.

Combined ground direct-fire and manoeuvre-arrival fire commands require visible, simulation-enabled platform and gunner as well as the existing combat-effective/local/authority/ROE gates. Dormant assets cannot receive those commands. This guard does not establish operator-station ammunition compatibility or real suppression/destruction; those remain open with physical acceptance.

Combined ground fire now rereads the selected gunner seat, current station weapons and loaded turret magazines at both immediate and arrival fire boundaries. A damaging magazine must have rounds, belong to that exact turret and be compatible with an exposed station weapon; ammunition on another station does not qualify. NO_STATION_AMMO rejects the fire command. The read-only check creates no scheduler or movement owner. Engine weapon choice, multi-turret edge cases and physical effects remain unaccepted.

Counter-battery retargeting no longer consumes the global firing-event position. Observer-backed missions use the current owner-local spotter query/report path between bursts. Missions without a spotter may update relocation from a side-specific radar-qualified emission no more than 120 seconds old. The later acquisition repair below adds radar/visual qualification; audio localization, report-age provenance and physical fire acceptance remain unresolved.

Automatic counter-battery acquisition now requires registered same-side radar coverage for an emission-coordinate mission. The firing event also schedules one delayed observer wakeup per event cooldown; current server/headless owners scan cached assigned observers in finite four-actor slices. Only fresh native visual knowledge, visibility, transmission and observer readiness can produce a non-radar fix through the existing authenticated fire request. The event provides identity, not actionable coordinates, to that path. No new movement writer or global observer scan is added. Audio-only localization, delivery-age provenance, normal/HC physical fire and matched performance remain incomplete.

Initial observer-backed counter-battery requests carry native last-seen time converted to server time; admission rejects missing, nonfinite, future or older-than-ten-second observations before battery selection/reservation. CortexArtilleryFire argument 10 is the observation timestamp (default -1). Legacy calls with a local spotter may derive its native last-seen timestamp; remote spotter callers must supply it. SUPPORT, radar and DANGER calls retain their existing arguments. Network/locality age handling remains physically unaccepted.

Each ranging observer reply now transports native last-seen time as CortexArtilleryReport argument 5 (default -1). A fix update requires the expected/current owner and mission phase, an active visible combat-effective observer, finite coordinates and nonnegative finite error, and an observation no older than ten seconds or more than one second in the future. Invalid fixes do not overwrite the existing mission estimate; the existing finite sequence proceeds without a new correction. Physical delayed-report, owner migration and ranging effects remain unaccepted.

Combined air discovery, owner-side asset resolution and fallback revalidation require the aircraft pilot's group, matching AirAttackOperationStart. Separate commander or passenger groups cannot reserve flight authority. The aircraft and pilot group must still be local at startup; cross-owner crew migration remains subject to refusal and requires live validation. Ground commander/driver eligibility remains unchanged.

Garrison deferred entrance-anchor recovery restores its topology cache from the queued job payload. Alternate-entrance and interior reassignment callbacks no longer rely on the initial apply function's expired private scope. Physical recovery acceptance remains pending.

Garrison building assignments capture their world transform. Initial owner adoption, deferred approach/reassignment and the existing held-state group tick invalidate changed or deleted building bindings through actor-subset release. Stale candidate slots are excluded from recovery. Unaffected actors retain their posts; explicit inPlace holds remain unbound. No new monitor or automatic re-garrison is introduced. Physical relocation/deletion and HC migration acceptance remain pending.

CQB exterior observation retries prefer real exits not yet attempted by that actor before repeating an exit. Existing assignment coverage and distance rank candidates within that preference. The three-search cap, one-search callback budget and original deadline remain unchanged. Exit history is replayed through the existing transform-bound migration journal; older rows without history remain readable. Physical multi-exit isolation and HC replay acceptance remain pending.

Terminal CQB route evidence includes each exterior actor's attempted exits after its stage and search count. Existing evidence indices remain unchanged. This records finite recovery choices without adding geometry queries or claiming physical isolation.

Convoy audit timing rows retain their original eight fields and append local controller evidence: follower limit/timestamp, lead limit/timestamp, last progress time, recovery count, retained native and steering targets, and steering mode. Remote owner state is explicitly unavailable. Sampling remains within the existing finite audit window and does not change driving or acceptance thresholds.

Garrison owner adoption preserves exhausted-route failure flags and does not restart those positions. Fresh explicit garrison orders still clear old assignments through release before admitting new routes. This prevents locality migration from renewing a failed position's recovery budget. Physical inaccessible-position and repeated-HC acceptance remain pending.

Explicit garrison orders publish one 240-second server-time approach deadline. Owner adoption reuses it; pending assignments after expiry are marked failed without another movement request. Arrived posts remain held. Full release or retirement of the last assignment clears the deadline; a new explicit order creates a fresh one. Legacy orders without a deadline initialize it once. Physical repeated-HC deadline acceptance remains pending.

Garrison approach speed restoration metadata is public on the actor. Owner adoption preserves the original forced speed instead of saving the current CBE cap as the original. Release clears both published values and still restores only an unchanged applied cap. Physical HC transfer and newer-controller speed acceptance remain pending.

Expired garrison adoption restores an unchanged published approach-speed lease before marking a locally owned AI route failed. It uses the existing actor-authority gate and preserves newer speed caps. This closes the adoption path that bypasses ordinary callback failure cleanup; physical HC expiry acceptance remains pending.

A garrison approach job with no pending routes and every surviving assigned actor marked failed publishes INCOMPLETE / ALL_ROUTES_FAILED with bounded actor-position/assignment evidence before normal release. Successful or unresolved assigned actors prevent this full-failure retirement. New explicit orders clear the previous result; release preserves it for diagnosis. Physical wholly inaccessible-building acceptance remains pending.

Garrison approach records the applied UP stance as an actor-public lease. Release restores the saved original stance only while the current stance still matches that lease and existing actor/external-owner guards permit restoration. Duck restoration remains separately guarded; release clears both applied stance records. Physical repeated-order and HC stance acceptance remain pending.

Garrison surplus actors now retain EXTERIOR_PENDING assignments rather than native formation slots. The existing job searches one actor per callback, at most three times per actor, and keeps the original deadline. It ranks real exits by attempt history, existing coverage and distance, validates exterior geometry and observation separately from cover, then commits a distinct direct route. Arrival holds watch the selected exit approach; exterior failure cannot reassign an interior slot. Actor-public attempts and assignment purpose support owner adoption; release retires them. Physically inaccessible or exhausted selection remains failed, not accepted security. Live overflow isolation, HC adoption and runtime cost remain pending.

Garrison exterior selection builds its reservation and exit-use maps in one squad pass instead of scanning the squad for every exit. Failed or combat-ineffective assignments do not count as live coverage or reserve destinations. Shared geometry validation still excludes physically occupied positions. This reduces selector bookkeeping without changing its one-search cadence, finite attempts or deadline; runtime overhead remains unaccepted.

Garrison exterior recovery retains up to six attempted candidate positions per actor and excludes them on later cover searches. The history is public for owner adoption and retired by release. This prevents repeated rejection of the same point on a single-exit building without adding searches, moving actors artificially or extending deadlines. Physical alternate-position recovery remains pending.

The normal building audit now includes a capacity-plus-two garrison fixture with independent physical interior/exit-observation checks, stable holding, finite search counts and real ordinary-waypoint handover. It reuses placement and room-observation validation and injects no actor relocation, door opening or completion. Large-only and transform-only focuses remain separate. This fixture is not yet run and does not establish HC or combat effectiveness.

When an exterior cover/search point fails geometry, the same finite garrison search may make one short-range engine empty-space query around a reservation-adjusted exit approach. The proposal must pass the existing exterior bounds, exit clearance, support, occupancy, separation and observation-ray checks; accepted fallback records covered=false. Three searches, original deadlines and owner-authority gates remain unchanged. No actor is moved artificially and native query success is not path evidence. Live open-ground multi-observer and cost acceptance remain pending.

The shared exterior validator optionally checks committed observer lanes in both directions: the candidate body must not occlude an existing planned view, and an existing planned body must not occlude the candidate view. Garrison passes its live reservation lanes and adjusts empty-space proposals laterally using those directions and the actor's current side. Actual object/terrain rays and endpoint separation remain required. More than 64 supplied lanes is refused; no lane is silently ignored. Physical mutual observation and runtime cost remain pending.

CQB exterior selection passes live APPROACH/ARRIVED observer lanes to the shared geometry validator. Promoted, unavailable and historical stages do not reserve a planned view. Endpoint spacing, actual visibility and finite search budgets remain independent requirements; physical isolation and migration acceptance remain pending.

CQB and garrison share BuildingExteriorProposal for one uncovered native empty-space query after a rejected observation candidate. It corrects a proposal centre once against actual reservations and planned observation directions, refuses excessive/malformed inputs and does not issue commands. CQB retains at most six attempted points across its three searches and owner migration. Covered=false is recorded for this fallback; existing geometry/arrival gates and order deadlines remain authoritative. Open-ground multi-reserve isolation, dynamic obstruction and performance acceptance remain pending.

Active CQB exterior posts now revalidate actual eye-to-watch visibility and continued physical occupation. The existing clearance callback samples at most one post ray, with a two-second actor throttle and at least three seconds of persistent failure before retirement; transient bodies do not immediately trigger movement. A failed post releases only its matching generation/epoch watch and becomes REJECTED or EXHAUSTED using the existing three-search budget and hard deadline. No new movement controller, global scan or command is added to retirement. The local sampling grace restarts on owner adoption, while public search/deadline limits remain preserved. Dynamic blockage, migration and performance acceptance remain pending.

CQB observation sampling selects the oldest due eligible post from the current eight-reserve slice; it does not repeatedly favour the first roster actor. The one-ray callback budget and two-second actor throttle remain unchanged.

CQB egress now uses one bounded native exterior proposal per admitted worker instead of a fixed three-column grid. Proposed positions avoid committed exit destinations and live reserve posts/observation lanes, then pass the shared bounds, support, occupancy, exit-clearance and visibility checks. Each actor retains a distinct movement destination and one-metre arrival hold. No valid proposal records failed consolidation and retains the actor's actual point; it never claims a shared success. Existing 45-second exit lifetime, route recovery, newer-order protection and physical participation requirements remain unchanged. Dynamic egress, casualty flow, HC replay and performance acceptance remain pending.

CQB egress now publishes a material-change journal bound to the target building, transform and original hard deadline. It retains separate actor destinations, exact owned native route legs, arrival flags, checkpoint/retry consumption and the original server-clock exit deadline. A resumed owner adopts only eligible actors whose MOVE still matches the saved leg or whose stopped physical arrival matches its destination; diverted actors remain failures. Adoption issues no movement and never resets the exit lifetime or retry count. Sampling/progress grace is local, bounded by the retained exit deadline. Older unbound diagnostic snapshots do not provide egress replay. HC physical mid-egress replay and cost acceptance remain pending.

The separate headless building batch now includes a fresh four-actor multi-storey clearance transferred while an actor is still physically inside and exiting. It requires two registered HCs, real owner adoption in EGRESS, unchanged transform/deadline/destinations, nondecreasing consumed retries, independent room participation and physical exterior arrival with COMPLETE outcome. No freeze, teleport, door assistance or receipt injection is applied. Failure to reach the mid-exit prerequisite remains a failure, not a skipped pass. This added fixture is unrun; it does not establish HC acceptance.

The HC egress fixture also returns the group through the real migration API, then issues an ordinary MOVE waypoint and requires every original actor to travel at least 20 m with leader arrival. It performs no cleanup/reset before that successor order. Owner adoption requires a fresh post-transfer building-brain timestamp, preventing the old owner's public state from passing. This fixture remains unrun.

Garrison PATH locking now requires actual physical post validation rather than a bare two-metre distance. Interior posts require 1.5 m proximity, 0.75 m floor agreement, actual building bounds and no target-building surface across the pose-to-post segment. Exterior posts require two-metre/floor proximity, an exterior pose and actual eye-to-watch visibility. Setup, expired owner adoption and queued arrival use the same transported self-contained predicate; commands still require current authority. Geometry runs only within proximity, under the existing finite approach lifetime. Repeatability and performance acceptance remain pending.

CQB egress selection now tries at most three native proposals per admitted worker, rather than one. Existing real entrances rank by committed exit use and current actor distance; other entrances precede a repeated search at the first entrance. Rejected candidate history is included in reservation adjustment and validation, with no grid/fan or authored model route. At most eight admitted workers bound this one-time selection to 24 native queries; the original 45-second exit deadline, distinct destinations and physical arrival/retry requirements remain unchanged. Each proposal records compact diagnostic evidence. Six/twelve-person physical reliability and measured runtime cost remain pending.

Pair support separation now detects a stationary partner occupying the mover's actual straight approach segment, even when endpoint spacing is sufficient. This trigger requires a target-building-clear segment through the existing shared geometry budget; it does not treat a line through a wall as a native route. Replacement support points remain physically visited, same-floor points within eight metres and clear of live reservations and the mover segment. Negative searches can reconsider changed live mover/partner poses; successful choices remain cached unless their route/coverage/reservations become invalid. The existing pair writer issues any yield; deadlines and recovery budgets are unchanged. Cross-pair/stair traffic and higher-concurrency physical acceptance remain pending.

Scoped physical evidence: normal candidate 67d29d9 passed the fresh six-person Big01 clearance, all actor participation and genuine distinct exterior exits, then post-clear holding and ordinary movement. The proposal log confirms a rejected first point followed by a successful alternative at another actual entrance. The stricter garrison overflow fixture passed physical interior/exterior posts and handover. These cases do not establish repeated, higher-concurrency, HC, combat, modded-building or performance acceptance; the full normal batch remains in progress.

BuildingExteriorCandidate retains BOOL return by default. Optional argument 8 (BOOL false) enables [BOOL, named measurement pairs] for diagnosis, with the identical acceptance gates. Active CQB reserve searches log compact cover/uncovered proposal results and distinguish no native proposal from geometry rejection. Standing geometry remains short-circuited and explicitly NOT_CHECKED when earlier gates reject; no extra geometry ray or movement query is added. Existing one-search callback, three-search actor and original deadline budgets remain unchanged. Physical isolation and runtime cost acceptance remain pending.

Exterior rejection diagnostics distinguish initial uncovered SEARCH results from actual COVER selections. Dry/slope/standing fields retain NOT_CHECKED when the original short-circuit path did not evaluate them; diagnosis never executes extra engine checks merely to fill those fields.

New CQB room claims now prioritize the lowest unfinished native room band in ASL world height. Claimed lower rooms remain unfinished until a physical visit or existing bounded failure; merely removing a claim from the pending queue cannot release upper-floor claims. The wave cache recomputes only when coverage/failure counts change and is reconstructed on owner adoption. Idle waiting pairs receive one current-position hold through the existing room-hold bookkeeping and pair writer; active native legs, specialist tasks and newer authority remain protected. Waiting creates no visits, failures, retries or deadline renewal. Existing worker capacity and follow-through participation remain unchanged. Physical multi-floor flow, headless replay and performance acceptance are pending.

Exterior native-search envelopes now preserve the supplied reservation and observation-corridor exclusions after centre correction. The query radius is capped by post spacing, the nearest committed corridor segment and the selected exit's 3-18 m band, with a small numerical margin. The native area radius is zero so it cannot enlarge that envelope. A conflicting centre or out-of-envelope native result is rejected within the existing attempt history. This adds at most one arithmetic pass over the existing 128 reservations and 64 lanes, no world scans/rays and no additional native queries. Geometry/visibility, physical arrival, inaccessible-point failure and original deadlines remain authoritative. This addresses query displacement that could undo exclusion correction; physical multi-reserve/egress, modded buildings and performance acceptance remain pending.

Interior follow-through previously used only decreasing target distance to trigger recovery at 12 seconds and retire a failed target at 24 seconds. It now additionally requires eight seconds without at least one metre of actual motion, preserving native stair/corridor detours within the original hard deadline and shared three-target recovery budget. This mirrors the existing egress motion safeguard; it neither grants visit receipts nor changes an exhausted outcome. Normal larger-case, casualty, HC replay and runtime cost remain physically unvalidated. Exact a422403 egress recount: two of 24 proposals were accepted (2:179 and 2:183); the earlier all-rejected statement has been corrected.

CQB follow-through now ranks unvisited native points by current ASL floor, live occupancy/owned destination and actual distance. A lazy callback-local snapshot contains at most eight admitted workers; subsequent commands in that callback update their reservations so later selections see them. Historical destinations without an owned MOVE do not reserve space. If every point is occupied, ranking does not fabricate a free point or silently classify a room inaccessible: ordinary finite native attempts/recovery and physical receipts remain required. This adds bounded arithmetic over at most 24 points per selecting worker, no world scan, ray or independent movement writer. Larger-case, casualty, headless and performance acceptance remain pending.

Focused normal 3cb1c9d audit 20261014-195342-594 was stopped at user request after 20 checks; no comparison completion and no recorded SQF/fatal/genuine load errors. Both exact processes were terminated and verified exited. All partial evidence remains preserved. Further audits are held by request while implementation continues. Ordinary-driving assist now excludes native service/boarding/medical/assembly tasks on both driver and effective commander at admission and final command boundaries, releasing only its exact unchanged speed lease through existing cleanup. No new controller, scan or retry is added; physical task handover and performance remain unvalidated.

Workshop-informed convoy catch-up: the locally archived Better Convoy 2801179774 lead/link speed functions separate leader pacing from nonlinear follower gap correction. CBE retains its owner-local FSM/shared scheduler and linear normal-band control, adding only an outer-band excess-gap correction proportional to excess^1.5 and capped at 8 km/h. The existing acceleration limit, shared vehicle cruise/terrain maximum, closing cap, immediate compressed-gap braking, stopped/reversing predecessor protection and infantry safety still constrain the result. No authored speed mode, road preference, independent loop, waypoint or tight stopping band is added. This aims to restore large gaps after mixed-vehicle step-off/path acquisition; convoy gap convergence, stop/start behaviour and performance remain physically unvalidated. The archived local code is a method reference, not proof of current Workshop parity.

Convoy follower path safety now persists across spacing-only ticks. Previously curve/grade analysis limited only the refresh callback, while the next ordinary spacing calculation could raise speed before new trail geometry was considered. Each existing follower record now retains the latest path cap at field 8; legacy field 7 remains the native hold receipt. Fresh three-point trail analysis replaces the cap, including straight/level relaxation; an insufficient trail retains the known constraint. Disabling DrivingAssist clears it, and existing convoy release/reacquisition boundaries retire or retain the associated follower state. One group feature lookup replaces repeated per-follower refresh lookups. There are no new scans, rays, schedulers, path commands or public state broadcasts. This is an implementation repair; bent-route, mixed-vehicle, stop/resume, ownership migration and performance acceptance remain pending while audits are held.

Coordinated assault no longer uses the same 45/65/85 m approach radii for every engagement. Inner radius now derives from live requester-contact axis length and responder-contact distance, clamped to 45-180 m; a second radial depth adds 70 m up to 250 m, and oblique candidates scale with the inner radius. The existing six-candidate budget, actual responder origin, preserved side, 60 m endpoint separation, terrain/ballistic fire-lane checks, authority tokens and finite bound/recovery lifetimes remain in force. This expands geometry for wider engagements without a shared rally or additional discovery scan. It does not implement independent contact clustering, broad tactical command hierarchy or full large-force acceptance. Physical coordinated movement, fire support, contact separation and performance remain unvalidated; audits are held by request.

Combined-arms ground refusal contract corrected: the owner-local station preflight emitted NO_STATION_AMMO, but the server refusal whitelist omitted it. The exact authenticated reservation now retires immediately for that reason instead of holding an incapable asset until expiry. Snapshot equality, current owner authentication, accepted ground-role checks and metadata-only cleanup remain unchanged; no authored movement or other operation is cancelled. A cross-file regression contract checks all literal/direct and dynamic fire-refusal reasons emitted by the owner against the server whitelist. This resolves a protocol defect, not broad weapon-effect selection, ground fallback, suppression/destruction, subcontact planning or physical acceptance. Audits remain held by request.

Combined ground fire now checks target suitability after confirming actual loaded gunner-station ammunition. A target inside another platform is classified by that platform. Explicit CfgAmmo usage flags select infantry/vehicle/air/armour intent; allowAgainstInfantry=0 blocks infantry use. Missing flags preserve soft-target legacy rounds, require airLock for air, and require a non-AA heavy shell/rocket/missile with hit >=100 for armour, matching the existing conservative launcher fallback. Omitted target preserves the two-argument API. Direct-role refusal NO_TARGET_AMMO retires the exact authenticated reservation; manoeuvre arrival records that decision without claiming a fire effect. Native weapon selection still owns which suitable station weapon fires; these checks cannot prove damage, range, penetration, suppression or destruction. Config reference: https://community.bistudio.com/wiki/CfgAmmo . Modded config tuning, effective weapon choice, physical fire, HC/locality and performance acceptance remain pending. Audits remain held.

Ground combined-arms refusals now advance a shared pool of at most 32 already-ranked asset/group pairs. Exact authenticated retirement precedes fallback; a per-group token/role consumption receipt rejects duplicate notices. The cursor never rescans discovery, resets on rejection or extends the original opportunity. Current asset commander/driver ownership, requester/candidate eligibility, feature gates, convoy exclusion, communications, target protection, believed-position tolerance and absence of any other live role are revalidated. One replacement receives the same ground role/context and must pass its owner-local loaded-station/target suitability preflight. Each replacement expires under the original clock while preserving terminal outcomes. Existing manoeuvre roles remain independent; the fallback does not replan their routes or claim complete suppression/destruction, ground effect selection or cross-arm fire-lane acceptance. Audits are held; physical refusal replacement, competing contacts, HC migration and performance remain unvalidated.

Garrison suppression posture is limited to available stationary actors. Immediate duck and delayed recovery both yield to native MOVE/FOLLOW, medical/boarding/service/assembly commands, mounted or remote control and typed actor movement reservations. Already-prone actors are not raised. Recovery uses the immediate pre-duck stance only while the same group, generation, owner epoch, full assignment, expiry token and applied stance remain valid; it does not restore a pre-garrison stance over a newer task. Default epoch zero matches explicit garrison movement receipts before group scheduling begins. General native/danger reactions remain available during approach. Offline regression and packaging checks pass; live incoming-fire, changed assignment, interrupted movement and headless ownership migration remain unverified while audits are paused.

Garrison hit/suppression posture checks also compare the assigned building against its current position, direction and up vector before ducking and before delayed recovery. A moved, rotated or deleted post cannot retain posture authority merely because its stored assignment is unchanged. Assignments without a building-transform receipt retain the documented legacy path. Physical Zeus movement/deletion during incoming fire remains unverified.

Morale bounds native suppression samples to0..1 before averaging. A local unavailable/disabled sample (-1) contributes zero pressure, never a morale bonus. Script-set values above one cannot exceed the existing20% suppression contribution. No skill penalty, synthetic hearing pressure or additional scan is added. Live disabled-suppression and mixed-pressure cases remain unverified.

Anti-armour selection, grenade-evasion probability and smoke candidate ranking also bound suppression arithmetic to0..1. Unavailable/disabled suppression cannot improve a gunner rank or grant a grenade-reaction bonus. Smoke task admission uses the shared typed reservation predicate; unknown or malformed movement leases remain reserved. Existing hazard thresholds, skill-based probability, ammunition, native-task and fire-safety rules remain. Physical selection/evasion and concurrent reserved-task cases remain unverified.

Queued danger-smoke release and each bounded aiming retry recheck the same strict actor movement reservation used in selection. A new, unknown or malformed lease cancels the throw before facing or weapon commands; a stale local expiry shortcut cannot grant release authority. Existing throw generation, operation/owner epoch, contact, ammunition and native-task guards remain. Live next-frame reservation takeover remains unverified.

Flank, advance and assault casualty replacement uses the shared strict actor reservation predicate before changing its fire-team roster. Unknown or malformed reservations remain owned; only local actors with empty or fully typed expired leases qualify. Existing specialist/native task exclusions still apply. Concurrent casualty replacement and actor-task takeover remain physically unverified.

Coordinated support rechecks strict local actor reservations both before forming moving fire teams and before stopping covering actors. Unknown or malformed leases do not authorize either command. Server eligibility remains provisional; the current owner can refuse execution. Live bound/cover task takeover and cross-owner coordination remain unverified.

Grenade evasion preserves unknown or malformed actor reservations at admission. Its delayed regroup retires only the exact issued lease, including destination and deadline; a nearby replacement destination is not the original lease. Existing drill, native-task, route, generation and locality safeguards remain. Live evasion/replacement and migration acceptance remain outstanding.

Ordinary driver casualty replacement excludes reserved candidates and rechecks the same strict actor reservation before dead-driver ejection and internal seat switching. A newer actor reservation cancels the finite attempt without clearing that reservation. Existing route, seat, native-command and owner receipts remain required. Physical casualty replacement, task takeover and migration remain unverified.

Combat gunner-loss recovery preserves the commander's actor reservation, direct remote-control ownership and specialist controller before assigning or requesting a gunner seat. Rejection records ACTOR_OWNERSHIP without clearing another task. This remains distinct from ordinary driver replacement; successful physical seat transfer and casualty recovery remain unverified.

Airborne DROP rechecks live pilot and effective-commander readiness, player/remote control and external takeover before each passenger exit. Parachute exit also preserves the passenger's actor reservation and specialist ownership before changing damage permission or leaving the aircraft. Already-started exit callbacks retain their existing cleanup. Damage-protection overlap and mid-exit locality continuation remain unresolved; physical takeover/exit acceptance is outstanding.

Pending airborne selection skips unavailable passengers rather than repeatedly retrying the first refused actor. Eligible squad members may continue; skipped actors stay aboard. LAND still requires actual touchdown of the living squad and retains its deadline, so a partial drop is not reported as complete.

Airborne insertions retain a group/serial/owner-epoch episode on the job, passenger group and aircraft. Steps lacking the current group episode or owner epoch do no work; an aircraft episode replacement retires only the old group episode. Cleanup clears aircraft drop state only when its episode still matches. This prevents stale-job cleanup but is not cross-owner shared-aircraft admission arbitration. Live replacement/migration remains unverified.

For focused owner-local entry diagnostics, set the group variable CBE_Cortex_ClearCaptureEntry to true before clearance. Entry samples retain generation/epoch, actor/lane/mover identity, intended destination, physical ASL pose, native expected destination/command, speed and physical-entry status. Capture is off by default, limited to256 records and16 actors per job at2s per actor, and performs no geometry scan, network replay or movement write. Instrumented cases are not performance-budget evidence; diagnostic records do not prove path reachability or clearance.

Clearance preserves an unchanged exact-owned MOVE request even when native unitReady becomes true. Readiness still governs physical handoffs; it no longer authorizes per-callback destination reissue. Existing finite no-progress retry timing remains responsible for refreshing that path. Entry diagnostics include native readiness to distinguish this state. Physical effects on entry stalls and responsiveness remain unverified.

The same CQB no-reissue rule also covers an ended native command only while its retained destination exactly matches CBE's unchanged committed destination. New/changed destinations remain distinct requests. This does not broaden movement ownership to empty commands: only the initial writer coalesces that duplicate; existing timed recovery and handoff authority remain unchanged. Physical stall/route responsiveness remains unverified.

CQB buddy separation and room-mover progress use separate decision flags. A support actor can yield a blocking position without resetting the assaulter's no-progress clock or motion baseline. New room requests and measured improvement retain their existing timing effects; finite stuck recovery remains available even while the buddy adjusts. Physical congestion/straggler effects remain unverified.

Parachute exit applies inherited chute velocity only after the soldier actually occupies the created chute. Failed boarding deletes only that newly created chute when it remains local and empty; an occupied or transferred chute is preserved. Existing damage restoration still runs. This prevents an abandoned moving object, but does not establish successful deployment or solve damage-protection overlap and mid-exit locality continuation. Physical failed-boarding acceptance remains outstanding.

Ordinary driving assistance checks both the driver and effective commander for individual movement reservations as well as native service tasks. A live, malformed or nonlocal reservation refuses new cap/recovery commands. Recovery release checks the same reservation before stopping or following the authored route; it retires its journal without clearing the actor reservation. Valid expired reservations remain eligible through the shared predicate. Physical takeover during a rear leg remains unverified.

Bypass and navigation-corridor execution apply the same strict driver/commander actor-reservation boundary in ordinary and convoy-lead modes. Acquisition, approach and fixed-path writes refuse a newly reserved seat. Release retires matching work without issuing stop/follow/route-resume over that reservation or clearing it. This guards command ownership; it does not prove that an engine fixed path already in progress has stopped after an external takeover. Live takeover and fixed-steering termination remain acceptance requirements.

Ordinary route recovery now refuses every synchronized trigger link, including one currently activated. This matches its handback contract and preserves authored trigger control throughout a finite manoeuvre. Native waypoint travel and ordinary safety sampling remain available; the change does not remove a waypoint or evaluate its condition. Physical repeating-trigger and reverse-interruption cases remain unverified.

CQB casualty reinforcement invalidates the changed lane's cached buddy-entry proposal. The next normal planner selects against current geometry and occupied destinations instead of inheriting the removed partner's proposal. The surviving actor's physical entry, room coverage, route and operation deadline remain intact. This changes target selection, not proof of native building access; replacement entry and flow still require physical acceptance.

Opt-in convoy control capture now distinguishes follower navigation requests from speed writes. Follower sample field 9 records native destination or fixed-path endpoint/count at actual movement writes; field 10 records the pre-write native command, readiness, expected destination, committed native/path endpoints and trail cursor. It retains no complete path or growing history and adds no scan/publication. Existing matrix capture receives these local fields. This prepares diagnosis of path churn versus spacing/braking; it does not establish the cause of historical mixed-column stop/start or change pacing.

Direct CortexBuildingDoor calls without an operation context require an unreserved actor whose native command is idle or MOVE. They cannot open doors on behalf of an unrelated actor reservation, service, FOLLOW or combat task. Owned INDOOR combat requests retain their exact contact/lease checks; CLEAR/GARRISON retain their existing receipts. Door proximity remains 3m with floor and visibility checks. This closes a direct-call ownership gap; no new physical door/entry acceptance is claimed.

DrivingRearClear returns `[false,"INVALID_REAR_DISTANCE",time,0]` for non-finite requested distances before hull calculations, entity discovery or ray queries. Finite distances retain the existing 1..60m clamp. This protects script-call scan bounds; it neither projects future road support nor establishes physical reverse clearance.

Ground-fire readiness now reads native `weaponState [vehicle,turretPath,weapon,muzzle]` for the gunner station. Turret inventory previously let a nonempty reserve magazine qualify even without loaded rounds. Each accepted muzzle must report its matching weapon/muzzle, a magazine and positive finite rounds, then pass the existing damaging-ammunition and target-class checks. Unselected coaxial/secondary muzzles can qualify when actually loaded. Observation is bounded to16 weapons,8 muzzles each and32 state queries; excess/unsupported states provide no permission. No weapon selection, reload or fire command is added. Loaded rounds do not prove the reload cycle has finished, shots occurred or effects were achieved. Live multi-muzzle/reload and modded-turret cases remain unverified. API reference: https://community.bistudio.com/wiki/weaponState

An admitted combined-ground manoeuvre now waits one scheduler step instead of failing ammunition/fire-platform capability while native weaponState reports a matching damaging, target-suitable magazine reload in progress. GroundFireReady remains false without positive loaded rounds; its optional caller-local observation supplies reload evidence only. Travel and firing-position checks retain original expiry, route, ownership and progress clocks; reload never grants fire or renews the opportunity. Unknown magazine identities and unrelated smoke/unsuitable reloads do not defer failure. Direct one-shot GROUND_FIRE admission still has no reload retry job; live reload/fallback behaviour remains unverified.

Ground fire-only and manoeuvre admission now retain a finite opportunity during a relevant native magazine reload. They remain unapplied; the existing group tick retries until original expiry, with no new timer or renewal. A pending owner/epoch receipt binds asset, gunner and native route; changes reject the old admission. Shared contact reveal occurs once per exact owner application receipt rather than on every retry. Server expiry records WAITING_FOR_RELOAD as EXPIRED before clearing the role. No reload means normal refusal/fallback. Live reload, expiry, route replacement and owner transfer remain unverified.

The prepared normal combined-arms audit now starts with a disposable gun-truck readiness diagnostic. Native weaponState must prove loaded damaging rounds before the positive check. After test-only ammunition setup, native state must prove all station weapons empty while turret stock contains rounds before reserve-only rejection can pass. Missing preconditions fail visibly. It deletes the diagnostic before the natural-contact scenario spawns; no role, readiness result or shot is injected into that scenario. This fixture remains unrun and gives no fire/effect, other-turret or HC acceptance.

Routine ground contact ranking can reuse a completed failed station scan for later candidates in the same local frame. The optional GroundFireReady selection-pass mode stores at most32 native state rows in a caller-local map, bound to vehicle, gunner, owner, frame and station. Successful short-circuit scans are never cached as complete. Default calls collect/reuse no rows. The selected contact receives a fresh default native ammunition check before targeting/fire. No cross-frame/world cache or handler is added. This bounds duplicate native queries for unsuitable contacts; it does not establish measured performance-budget compliance.

Aircraft release now requires native weaponState for the selected turret/weapon to report the exact planned magazine and positive finite rounds. Inventory stock no longer qualifies release. Dynamic-pylon/ordinary inventory still supplies planning candidates; this is capability selection, not proof of a loaded muzzle. Missing/mismatched native state refuses scripted release without inventory fallback. Native pylon switching, multi-muzzle aircraft and reload-cycle behaviour remain unverified, and the existing Fired-event/effect checks remain required.

Aircraft planning now builds own-aircraft candidates from native weaponState at each exposed station weapon, bounded to16 stations/16 weapons and64 state queries. Driver weapons retain the union of vehicle weapons and driver-turret weapons. Positive loaded rounds bind exact weapon/magazine; lateral selection reuses those same bindings rather than rescanning reserve inventory. Pylon magazine metadata still classifies rocket/bomb/guided delivery, but cannot fabricate loading. The release executor rechecks native state independently. Unreported pylon states, alternate muzzles and load transitions provide no fallback candidate and require physical retests; no new firing/effect acceptance is claimed.

Aircraft weapon planning/execution now shares a live selected-operator predicate: local airframe/group/actor, same-group aboard, combat-effective, visible/simulated, no player/remote/specialist control, protected native task or actor reservation, and no individual BLUE/GREEN restriction. Planning skips unavailable stations; attack entry retires an unavailable selected operator. Selection, targeting and each native fire request recheck it. Fired credit/guidance also requires the actual operator to match the selected station. Cleanup preserves actors with new reserved/service work. Owning a pilot does not authorize another group's turret crew. This is source authority protection; split-locality, casualty replacement and actual attack/cleanup handover remain physically unverified.

Aircraft attack plans retain their accepted weapon operator identity. A different station occupant during ingress or attack cancels with `WEAPON_OPERATOR_CHANGED`; targeting flags and asynchronous fire receipts never transfer to the replacement. Fired attribution requires both current station identity and retained plan identity. A fresh operation may reassess the new crew without extending the old retry budget. Physical seat replacement and locality migration remain unverified.

Aircraft target cleanup records the exact operator/target pair only after issuing its target/watch orders. Cleanup cannot clear another crew member merely because they target the same enemy. A pilot surface run that received no explicit target/watch assignment creates no such cleanup permission. Existing takeover and protected-task checks still apply. Same-actor replacement orders naming the identical target remain an observation limitation; this receipt alone cannot distinguish them.

Aircraft attack admission and flight-command boundaries require a local pilot without actor movement reservations or protected service tasks. Lateral pilot feature cleanup also yields to such a task. These guards preserve the new task rather than reenabling features over it; restoring a suspended task after it ends requires that task owner's lifecycle. Native flight cessation and cleanup overlap remain physical retest requirements.

Lateral aircraft feature snapshots retain the exact pilot they changed. Cleanup cannot apply that snapshot to a replacement driver; restoration additionally requires the original actor still aboard in the original group and existing flight/task authority. Protected, departed or migrated actors are left untouched. Eventual deferred restoration across such transitions remains an unresolved lifecycle requirement, not accepted handback.

Every aircraft attack FSM Finished path now submits its original job's pilot receipt to the finite release helper after matching flight-lease release and before retiring the matching brain. It does not rerun the old attack executor or clear a successor job. Actor-local/original-issuer guards still apply when airframe locality was lost. This closes local terminal bypass of feature release, but does not establish actor migration adoption or cleanup of every other attack resource.

Pilot feature recovery uses one public schema2 receipt: `[2, actor, aircraft, originalGroup, flightToken, issuerOwner, originallyEnabledFeatures, releaseUntil]`. It is published before disabling features, with releaseUntil=-1. Exact-owner safe ordinary cleanup restores and clears it. Otherwise the first authorised release callerâ€”original actor owner or explicit native-locality adopterâ€”changes only releaseUntil to serverTime+60 and publishes the snapshot and clock together. Later owners reuse that absolute deadline; no separate release-window variable or issuer-only missing-window dependency exists. Immutable issuer provenance remains unchanged. Malformed/unknown schema records grant no restoration authority.

Original-issuer init/adoption leaves an unstarted record to actual cleanup, so observing a live attack cannot age its future restoration window. A different actual actor owner may start release after migration even if the previous issuer never ran cleanup. Each callback requires the exact current receipt and captured local epoch. Restoration still requires an absent flight lease, the original actor aboard/in the original group, and no protected task/player/remote/specialist ownership. The chain is independent of the tactics scheduler and ends at the shared deadline or60 attempts. Timeout retains the unresolved record and blocks baseline overwrite by a new attack.

One native Local handler per CAManBase is installed through CBA init, including existing actors/JIP. Adoption waits at most five seconds for a late receipt only for aircraft occupants. No world polling, ground eligibility or attack replay is added. Physical migration/replication ordering, stale flight lease retirement, late receipt beyond five seconds, departed actors, external same-value feature ownership and handler cost remain unaccepted. Version1 experimental records are not silently upgraded into permission; reload a fresh candidate for testing.

### Pilot restoration after aircraft ownership transfer

The current local aircraft owner may retire a previous-owner AIR_ATTACK lease only when its controller, token and immutable issuer match the original pilot feature receipt. The actor must also be local, aboard the original aircraft and group, within the original release deadline, and free of protected task or external control. An active local attack brain blocks this retirement. Current-owner leases and other controllers remain untouched, including when generation tokens collide across machines. The check and lease retirement run together without suspension. Ordinary feature restoration still requires an absent lease and the existing task safeguards.

This closes a source-level handover blocker; split actor/aircraft ownership, late receipt delivery and physical multiplayer restoration still require in-engine validation. Audits remain paused.

The recorded pilot may also recover once fully on foot in the original group. This path restores only that actor's recorded features and does not clear the former aircraft lease; another aircraft occupant receives no inherited baseline. GET OUT, movement reservations, specialist or player control and other protected tasks still veto restoration. The final restoration rechecks actual locality, receipt identity, epoch, deadline, live lease and actor/task eligibility together without suspension. Changing groups or boarding a different vehicle remains unresolved rather than guessing restoration authority.

### Ordinary driving recovery handback

Recovery cleanup checks the current journal, vehicle mobility/simulation, original crew seats, native commands, route identity and task authority without suspension before issuing any stop or forward handback. The plain authored MOVE must pass its metadata checks before either crew member receives a stop command. Hidden, immobile or simulation-disabled vehicles retire matching bookkeeping without movement commands. This does not demonstrate successful native reverse or resolve the retained mixed-convoy stalls.

Reverse cleanup may stop its exact owned reverse without resuming a route when the leader is on foot or the mounted follow target is incapacitated, immobile, hidden or simulation-disabled. It does not order the crew to follow an on-foot leader. `CBE_DrivingRecovery_Result` retains its first five fields and appends the handback outcome: `AUTHORED_ROUTE`, `MOUNTED_LEADER`, `STOP_ONLY` or `METADATA_ONLY`. A stop or metadata retirement is not successful route continuation. A later explicit order is required for a stopped crew; automatic recovery after this leadership change remains unaccepted.

An exactly owned reverse now retains its command journal with `DEFERRED` when vehicle mobility, simulation or visibility prevents handback. The existing driving callback reconsiders it before fresh assistance, rereading route, seats, native commands and external authority; it never reissues the rear leg or renews recovery deadlines. Changed authority still retires bookkeeping without movement. This supersedes the earlier description of immediate metadata retirement for such an owned reverse. There is no independent observer: while driving is disabled, no automatic resumed handback is guaranteed. Physical reactivation and subsystem-off recovery remain unaccepted.

### Natural indoor destination crowding

Indoor investigation excludes native positions within1.5m horizontally and1m vertically of another living, simulated, visible squad member on foot. It samples at most16 current squad positions once per selection, alongside the existing destination reservations and temporary failed-node observations. Other groups and hidden enemy transforms are not scanned. Occupancy grants no room-clear credit and creates no inaccessible-node record; it is reconsidered on later selections. The existing512-node and three-roof-query limits remain. Physical pair flow, cross-group crowding and cost at battle scale remain unaccepted.

The shared buddy register preserves intact eligible pairs before repairing or creating pairs. Unpaired actors choose the nearest remaining eligible teammate by3D distance; roster order breaks ties. This changes partner selection only, with no movement command, world scan or forced reassignment of an intact pair. Walls, stairs and native path reachability can make the geometrically nearest teammate slower to reach; this preference is not a route-connectivity guarantee.

### Deferred post-clear hold release

When an authored order changes, the existing group callback releases matching post-clear STOP holds only for simulated, visible, effective actors with MOVE/PATH enabled and current task authority. A living on-foot actor that still owns the same STOP retains the original hold record through temporary simulation, visibility, mobility-feature or incapacitation changes, as well as movement reservations. New individual commands, boarding, player/external control and stale generations do not gain a delayed recall. No new callback loop is installed. Physical reactivation, gated waypoint semantics and behaviour while the whole subsystem is disabled remain unaccepted.

Post-clear handover after a new authored order now returns eligible held actors to native group behaviour with `doFollow`, including the leader. This supersedes the earlier leader-only positional MOVE shortcut: CBE no longer translates the new waypoint into a point or handles its condition, script, synchronization or attachment itself. The hold actor list, current STOP, generation/epoch, reservation and external-control checks still scope the release. Bohemia documents leader return after scripted doStop in the [doFollow reference](https://community.bistudio.com/wiki/doFollow). Native response to each waypoint type and player-issued commands still requires physical testing; no waypoint-completion credit is inferred.

The same native return applies when a new authored order interrupts an active clearance, independently of whether the ordinary group brain is still running. It still requires the original issued MOVE destination or owned STOP, matching clearance generation/epoch and no newer actor/task owner. Opt-in continuation after successful clearance retains its separate unchanged plain-MOVE checks.

Prepared normal-owner building cases cover active-clearance interruption and completed-clearance hold release followed by HOLD or condition-gated MOVE. They require actual clearance movement or independently observed interior coverage, both soldiers travelling, retained waypoint metadata/index through an eight-second observation, and old clearance retirement before cleanup. They are excluded from HC batches. These cases have not run; attached/moving-object and scripted-task handover remain additional physical cases.

Parachute exit refuses on-foot, ground-vehicle and parachute-as-airframe calls. Both actor and aircraft must be simulated and visible. Actor locality, current aircraft occupancy, reservations and external control are rechecked without suspension before capturing damage permission or issuing exit mutations. Failed final admission queues no chute callback. Existing delayed damage restoration is unchanged: overlapping protection and mid-exit migration remain unresolved and physically unaccepted.

### Parachute exit protection receipt

Each accepted CBE exit publishes `[1,actor,issuer,token,originalDamagePermission,absoluteDeadline]` before disabling damage. Another CBE exit refuses while that receipt remains. `CBE_fnc_CortexParachuteProtectionRelease` restores only the exact live receipt on the actor owner at its original3.8-second deadline; remote calls refuse; release uses actual actor-local observation, with immutable issuer provenance. Unchanged protection retains its original baseline, while a newer visible damage-permission value is preserved. Native actor init/Local observation reuses the existing handler and queues release independently of tactics settings, without replaying exit or chute motion. Late callbacks cannot clear a replacement receipt.

Bare remote allowDamage callbacks are removed. A delayed chute callback uses the last accepted exit token to reject replacement exits; protection expiry alone does not cancel chute deployment or renew invulnerability. This is release-only migration support: chute-phase continuation after locality transfer, late receipt publication beyond the native observation, and same-value external invulnerability writes remain unresolved. No general vehicle damage policy or full protection compatibility is claimed. Physical overlap, existing invulnerability, release timing, remote/JIP and performance remain unaccepted.

### Parachute exit command outcomes

A requested dismount must leave the actor local and on foot before exit position or velocity is applied. Failed dismount returns false and queues no chute, while the acquired protection still retires at its original deadline. Delayed chute creation and boarding recheck actor locality, simulation, visibility, combat readiness, reservations, player/remote control, external ownership and the accepted exit token in one unscheduled block. A takeover cancels boarding without cancelling damage cleanup. No extra scan or observer is added. This does not resume deployment after owner migration or prove physical dismount/boarding behaviour; those cases remain unaccepted while audits are paused.

### Finite parachute deployment adoption

After an observed dismount and exit motion, the soldier publishes an exact schema1 deployment receipt containing actor, accepted exit token, original group, validated chute class, inherited velocity, deployment time and the original protection deadline. Native actor init/Local observation adopts this phase on the actual owner; remote execution refuses. At the original0.8-second deployment time the actor owner consumes only the exact current receipt before creating one chute. Old callbacks cannot consume a replacement, repeat the dismount or replay exit position/velocity. Boarding requires the original group, an airborne on-foot actor and unchanged player/remote/external/reservation eligibility. Ground contact, expiry or takeover consumes the phase without deployment. Failed boarding deletes only the newly created local empty chute. Public result records BOARDED, BOARDING_FAILED, CANCELLED or EXPIRED; these are diagnostics, not physical acceptance.

Deployment is now bounded by the original3.8-second protection deadline, so a scheduler-delayed callback cannot deploy a chute indefinitely after the exit. Damage cleanup remains separate and never renews its deadline. This uses one bounded callback per observed owner and the existing native handler, with no recurring scan. Receipt delivery after the new owner's init/Local observation can still be missed. Physical server/HC transfer before and during deployment, duplicate callbacks, failed boarding, player takeover and frame-time acceptance remain untested while audits are paused.

### Airborne passenger attempt fairness

DROP attempts rotate through the original passenger roster after every attempt, including a refused dismount. The cursor uses the original roster so removing a successfully exited passenger does not skip the next one. Only living passengers still in the original group and aboard the aircraft remain pending; current owner/readiness/reservation/external controls still gate each exit. If pending passengers are temporarily unavailable, DROP waits without issuing commands and keeps its original deadline. It enters LAND when no original-group passenger remains aboard or the aircraft is lost. Deadline expiry terminates the insertion without inventing a landing or ground attack. Actors moved into another group are never recalled.

The job retains only its last attempt as `[actor,accepted,time]`. Accepted means exit movement was admitted, not that the chute boarded or the soldier landed. Only acceptance refreshes the aircraft drop hold. Attempts retain the existing jump interval, scans remain bounded to the original passenger roster, and no retry loop or deadline renewal is introduced. Physical refused-dismount fairness, reservation recovery, split locality, casualty flow and mixed-owner insertion remain unaccepted while audits are paused.

### Finished native convoy endpoints

A native follower can accept the next recorded endpoint after more than3m of advance when it is stopped within3m of its previous endpoint on the same floor and its movement operator is ready. The original driver/operator and both expected destinations must still match the captured receipt; only native MOVE/idle commands qualify. A fresh STOP, FOLLOW, changed destination or crew change does not gain this retry. Every write still passes the convoy takeover guard and refreshes its movement receipt. Moving legs retain the existing8m destination threshold, spacing/traffic/infantry caps remain independent, and no route refresh loop or observer is added.

This addresses a completed short leg waiting for8m of predecessor advance; it does not prove that mixed tracked/wheeled stop/start has been resolved. Native readiness and endpoint completion, explicit interruption, slow step-off, bends, bridges and performance require physical acceptance when audits resume.

### Prepared native endpoint acceptance observation

With internal convoy diagnostic capture enabled, each registered native follower retains only its latest completed-endpoint advance event, including the pre-command pose, readiness, command, old/new endpoints and ownership receipt. Capture off removes the local event map. These observations never grant movement authority or count as physical travel.

The normal tracked/mixed30m matrix cases now require a real3..8m finished-endpoint event and at least3m measured travel toward its successor with at least2m destination improvement under the same convoy revision/epoch. Missing event prerequisite fails separately from missing physical continuation. The test injects no follow, stop, path, position, velocity or controller-completion state. These cases are PREPARED_NOT_RUN while audits are paused; actual native completion metadata and behaviour remain unaccepted. Headless cases remain separate.

### Deferred recovery cap retirement

When an exact owned reverse cannot hand back because vehicle mobility or simulation is unavailable, ordinary-driving release now preserves its original speed-cap state and restoration baseline alongside the matching pending recovery journal. A deferred return is not treated as completed cleanup. Later existing driving callbacks can finish the same journal before new assistance; they do not recreate the rear leg or renew its deadlines. A retired, replaced or non-pending journal does not gain this protection, and the existing exact cap/newer-controller checks still govern final restoration.

This adds no observer or timer. Recovery while the entire driving subsystem remains stopped still lacks a guaranteed observation path. Physical immobility/repair, simulation changes, repeated release, owner migration and newer external caps remain unaccepted while audits are paused.

### Vehicle-owner shutdown cleanup

Each machine now runs shutdown vehicle cleanup only for vehicles it actually owns, before interface clients take their tactical early exit. The server retains global support and artillery bookkeeping, but does not erase an HC or interface owner's vehicle restoration tokens. The vehicle owner handles its driving cap, unload policy, safe-stop baseline, onboard danger, delayed relocation token and aircraft presentation cleanup. Existing exact speed-cap and local-state checks remain; no remote cleanup endpoint or recurring observer is added.

This repairs the shutdown dispatch boundary, not every cleanup policy. Native owner migration during shutdown, external-controller replacement, deferred reverse while simulation remains off and late CBA state delivery still require physical acceptance. The administrative vehicle pass scales with world vehicle count per participating machine; no runtime performance budget is claimed.

### Crew handover journal isolation

Ordinary-driving crew replacement now copies its entry journal before changing phases. Every publication compares the exact original live journal, current driving brain and owner epoch in an unscheduled block. Another group's journal is refused rather than cleared. Native Eject/MoveToDriver actions also recheck that snapshot and the original deadline, and publish their issued phase in the same unscheduled block. A stale cancellation or release cannot replace a successor journal.

The existing route, vacancy, driver/candidate, assignment, native command, actor reservation, simulation and takeover checks remain. No new seating shortcut, worker or deadline renewal is introduced. Actual asynchronous seat completion, same-value external ACTION ambiguity, owner transfer and delayed publication ordering still require physical acceptance while audits are paused.

### Prepared late crew-order acceptance

The normal crew fixture adds LATE_STOP and LATE_GETOUT after an actual production VACATING journal, confirmed empty driver seat and physical corpse exit. Missing prerequisites fail. STOP must remain intact through the original journal deadline plus3s. GETOUT uses a native dismount order, followed only after real dismount by an explicit new movement order; it must produce25m travel and20m destination improvement. Both require the original journal to remain cancelled without renewed deadline or subsequent driver-seat acquisition.

These are PREPARED_NOT_RUN. The fixture never assigns a production journal/phase, invokes the crew executor, forces replacement seating or relocates an actor after the casualty. Actual late-order timing, same-value command ambiguity and migration remain unaccepted; actual-provider HC cases stay separate.

### Clearance coverage belongs to a building transform

Durable clearance orders now append the admission transform at field13. Owner resume may reuse visited/unreachable room indices only when that transform exactly matches the current building pose. Missing or changed proof refuses resume and releases only the same observed order/generation. A fresh explicit order starts with empty coverage at the new pose; it receives no historical visit credit.

Admission captures the transform before reading model positions, rechecks it before replacement handoff and public order publication, and gives the worker that original snapshot. Geometry planned before an intervening move cannot be silently relabelled with a later pose. Existing worker transform guards still cancel moved targets before movement. An interruption after task handoff can still leave the prior task released; no rollback or completion is fabricated. Physical editor/Zeus movement, rotation, owner transfer and fresh-order entry remain unaccepted while audits are paused.

Clearance resume is adoption of an existing episode, never an implicit fresh task. Discovery supplies its observed durable order and generation; admission requires the same live snapshot and building, and rechecks the snapshot before task handoff and publication. Missing, cancelled, replaced or different-target requests refuse without releasing the successor. A missing or destroyed target retires only the still-matching resumed order. Explicit fresh orders retain ordinary validation/replacement semantics. These are source guarantees pending separate owner-migration and interruption observation; no new retry loop or lifetime is introduced.

Building FSM startup retains the owner epoch from common-operation admission. Its short unscheduled commit validates the exact CLEAR operation generation/epoch/objective, clear generation/active flags, original deadlines, target transform, native order and current eligibility before cancelling an older worker or publishing a new brain. Repeating startup for the identical live job reuses that worker. A refused start returns false; only the still-matching local episode may be released, without formation recall. Lost-owner and successor records remain for their current owner. The moved-building fixture includes duplicate-worker and stale-worker attempts using real captured production jobs; those checks remain prepared, not run.

After common-operation admission, clearance route preparation remains scheduled. Its later pair selection, status/visit/exit/search records, group attack policy and reserve marker writes use short unscheduled commits against the original operation generation, owner epoch, clear generation, target pose, native order, active gate, lifetime and external ownership. Egress adoption edits the current operation map rather than publishing a stale captured copy. Reserve markers also recheck the actor's current leg/arrival and availability at commit. The room-route loop is not moved into an unscheduled block. These checks constrain post-admission writes; the earlier task handoff/public-order admission remains a separate multi-stage review boundary, and runtime interruption/performance evidence is still required.

Clearance handoff now compares the owner epoch, native order, common-operation identity, clear generation/target and garrison/defence assignments captured before geometry validation. After rechecking current actor/task eligibility and the requested minimum against the original roster, the outgoing-task release, own-cleanup native receipt and new clear/common-operation publication execute in one unscheduled handoff block. Geometry queries and the room-route loop remain outside it. A cancelled/completed/replaced entry task causes refusal rather than acquisition of a later task. Missing/expired/transformed resume retirement likewise checks its exact order/generation/epoch in one block. This does not roll back an already-authorised handoff if a later worker start fails, and its one-time cleanup cost and runtime ordering still require measurement.


Roof observation for clearance discovery, clearance visits and natural indoor node/arrival checks uses BuildingRoofTop, a read-only eight-corner transformed model bound plus one metre. The previous ten-metre cutoff could reject tall interiors. Clearance callback bounds are lazy and callback-local; discovery/node selection computes the endpoint once per invocation. Ray counts and nearest-hit ownership checks remain unchanged for runtime observers; discovery retains its existing target-hit filter. This is observation range, not proof that configured interior points are accessible or safe. Open-roof, malformed geometry, actual traversal and model-size-dependent query cost remain unverified.


Clearance no-progress retries allow a still-owned matching native PLANNING/BUSY path thirty seconds before reissue; ordinary moving requests retain twelve seconds and ended commands four. This preserves planning without renewing progress clocks, retry counts or the original episode deadline. The allowance retains a valid busy path without changing target selection. Thirty seconds is provisional until physical timing/flow and performance are measured; it is not proof that native planning will succeed.


Combined-arms spatial candidate discovery explicitly includes live mounted crews within the existing spherical response envelope. The primary nearby-Man query omitted crew inside vehicles and could miss armour and aircraft groups. Group deduplication, communications, role reservations and actual-owner weapon/movement admission remain required. The crew-aware area query uses the addon's existing minimum engine version2.18. Discovery population and mounted-crew query cost still need runtime measurement; discovering a group does not establish a support effect.


Ordinary area-report discovery includes live mounted receivers. Delivery beyond voice range requires currently communicating members at both sender and receiver; nearby voice reports remain possible when radio is unavailable. The receiving owner repeats the range/communication checks after queue delay, so a receiver becoming jammed before delivery rejects the radio report. Existing eight-receiver delivery batches and original report expiry remain unchanged. Reports retain approximate positions and do not reveal or track target objects. Physical radio/voice/crew and JIP/HC validation remains pending.


Area-report storage and its thirty-second expiry use the original sighting timestamp rather than relay time. A later resend of an older or identical sighting cannot refresh it or replace a fresher stored observation. Server and receiver reject nonfinite/out-of-bounds coordinates, invalid confidence and invalid observation/send times; invalid report sets do not consume the sender's server cooldown. Transport still expires independently, and reports remain approximate areas rather than target tracking.


When one contact-report batch contains old and newer sightings, the receiver first excludes observations no newer than its stored area timestamp, then preserves sender priority among the eligible rows. An old first row cannot suppress a later fresh row. The receiver still stores only one approximate area and never renews older evidence.


Knowledge summary first ranks native candidates by group belief, then evaluates at most eight contacts across eight eligible members. Within that detail pass, the member with knownByUnit and the most recent native seen/threat timestamp supplies an updated getHideFrom belief; group-level knowsAbout does not identify a personal observer. Group belief remains the fallback, and the bounded result is re-sorted after refinement. No hostile live transform or reveal is used. The coarse candidate population is not newly bounded; observer refinement and its additional bounded native reads require physical/overhead validation.


Native ignored targets are removed from the bounded danger-event contact cache and excluded from the detailed tactical knowledge summary using the engine's ignored-target flag. The addon does not clear or rewrite that flag. This summary filter does not yet establish cancellation for every already-running aircraft, support or indoor operation; those execution paths require separate acceptance.


### Finite late parachute-receipt observation

An accepted exit requests one server-published CBA JIP wake carrying its protection and optional deployment receipt. Connected and joining peers cache that proposal until the original protection deadline plus one second. Only the actual actor owner observes pending replication at 0.1-second intervals; unrelated actors are not polled. Native init/locality callbacks can resume the cached proposal. Exact local queue serials prevent an old callback from consuming a replacement observer after locality changes.

The wake supplies no exit, damage or boarding authority. Existing readers still require the matching live replicated receipt, actor locality and their original mutation guards. Observing after the deployment deadline cannot create a chute; the extra second permits protection cleanup only. No deadline, dismount, position or actor exit velocity is replayed. Duplicate wakes do not extend the observation window. One expiry callback per connected peer removes the cached proposal.

The server coalesces publication by the original exit token and removes its exact CBA JIP entry at the original deadline plus one second, independently of actor deletion or issuer disconnection. Duplicate requests cannot replace a proposal or renew its expiry. The JIP payload is an observation proposal, never a deployment command. This covers joining peers that receive the wake and live receipts within the finite window; later delivery remains unsupported. Same-value external damage ownership, physical migration/boarding/JIP and runtime overhead remain unverified. Audits remain paused.


### Individual investigation engagement orders

Natural contact-led and body-clue building investigation excludes individual BLUE/GREEN actors before ranking candidates. Both the indoor actor and own-group casualty-point executors require group and individual YELLOW/RED/WHITE modes at admission and on active steps. A later individual hold/disengage order ends CBE investigation through its existing cleanup. Exact owned-movement restoration remains available; cleanup never changes the soldier's engagement mode. No scan, movement worker, setting or perception is added. Physical interruption and formation handback remain unverified while audits are paused.


### Combat replacement preserves the commander's seat intent

A mounted commander can replace a lost primary gunner only while still assigned to the actual commander turret they occupy. Recovery reads that vehicle's commander seat and compares its assigned occupant and turret path with the candidate's native assignment. Explicit unassignment, a different vehicle, or a newer driver/cargo/other-turret assignment refuses before assignment or internal seat action. No fixed commander turret path is assumed. The existing incoming-gunner, native task, owner, reservation and once-per-generation guards remain. This adds one filtered crew-seat observation per attempted combat recovery, with no scan or worker. Physical seat transitions and performance remain unverified while audits are paused.


### Driver replacement admission preserves seat intent

Ordinary dead-driver replacement selects only occupied crew members still assigned to that vehicle and that actual seat. It reads the assigned-unit field from the existing crew snapshot. Explicit unassignment and another seat assignment cannot become a recovery baseline merely because the actor remains physically aboard. Hidden or suspended candidates also defer before selection, so they cannot consume an attempt before a usable alternative. Cargo, commander, other crew and primary-gunner priority applies after this eligibility filter. Existing command/assignment receipts still protect the admitted attempt and native seat-action boundaries. No additional crew query, scan, timer or forced seating is added. Actual seat switching, repeated recovery, HC transfer and performance remain unverified while audits are paused.


### Individual indoor selection continues after roof misses

An individual investigation can test up to twelve distinct native positions over the existing FSM callbacks, with at most three roof queries per callback. Previously, three nearby unroofed positions ended selection even when a valid fourth position existed. The operation retains only its tested ASL nodes, bound to the same actor, building transform and belief. Other current reservations and squad body positions are still checked on every selection.

Pending selection retains the original deadline and adds no movement worker or timer. Exhausted, changed or empty candidates still finish without a visit or accessibility claim. A selected roofed node still requires native command admission and physical arrival. This increases the maximum selection work from three to twelve roof probes per operation; physical entry and frame-time effects remain unverified while audits are paused.


### Magazine sharing separates rifle and underbarrel reserves

Magazine sharing uses the recipient's primary weapon main muzzle rather than every muzzle. It chooses the configured `this` muzzle, or the first configured muzzle when the weapon uses named muzzles. Underbarrel grenades therefore neither hide a rifle-ammunition shortage nor qualify as the transferred rifle reserve. The existing low-reserve and donor-surplus thresholds, two-transfer maximum, twenty-second cadence, proximity/capacity checks and actual removed-round accounting remain. No ammunition is fabricated or weapon selection commanded. This adds one weapon-config muzzle lookup per receiver evaluation; physical inventory behaviour and performance remain unverified.


### Tactical rifle capacity requires ammunition

Tactical assessment and close-assault admission count a rifle operator only when the primary main muzzle has loaded ammunition or a compatible nonempty reserve. Underbarrel grenades cannot supply this capacity. A carried reserve qualifies without forcing a reload; firing readiness and permission remain separate native/executor checks. Physical squad strength stays separate, and AT/AA capability still uses its existing live launcher classifier. The low-firepower reposition policy is unchanged, but now receives ammunition-qualified rifle counts.

The shared read-only check reads the weapon's configured main muzzle and its loaded count. Only an empty main muzzle requires compatible-reserve enumeration. It adds no controller, cache, scan or weapon-selection command. Ammo exhaustion during an already-running drill still uses existing native firing and recovery rules; this change governs assessment/admission. Physical small-element behaviour and frame-time cost remain unverified while audits are paused.


### Flank and advance retain usable covering firepower

Flank and advance admission now size the selected rifle manoeuvre element from operators with primary main-muzzle ammunition. At least two ammunition-qualified actors must remain for cover. A squad with four usable rifles and four dry weapons can therefore form two rifle movers with two rifle cover actors, while retaining the existing physical squad and cover rosters. Dry weapons do not inflate the selected element or its covering-fire capacity. Existing role preference, minimum physical group size, casualty-strength, native-task and route checks remain.

Each start computes ammunition-qualified membership once through the shared read-only predicate. Native firing/reloading and active-drill casualty/ammunition reassessment remain separate; no inventory or weapon selection is commanded. Physical bounding, mixed ammunition loads and performance remain unverified while audits are paused.


### Ordinary bounds recheck ammunition at commitment

Before issuing a new ordinary tactical bound, the existing drill callback requires the surviving mover minimum to have main-muzzle ammunition and at least one eligible squad cover actor to retain it. It checks at the issue boundary rather than every movement sample. Losing that capacity ends the tactical override with `AMMO_CAPACITY_LOST` through existing exact cleanup and operation cancellation; no next bound, forced reload or synthetic completion is issued. Physical participants are retained through cleanup.

The check does not cancel an in-flight movement leg. It also permits the road-exit and consolidation legs to finish, so ammunition loss does not stop a soldier halfway across a road or prevent regrouping. Coordinated roles retain their existing parent protocol and require a separate ammunition/readiness review. Ammunition sharing remains on its existing group cadence. Physical interruption, authored-order continuation, resupply and performance remain unverified while audits are paused.


### Coordinated movers require owner-reported ammunition capacity

While a helper owns a COVER role, its existing maintenance callback samples eligible local actors at most every two seconds, or on a role change. It reports native-task availability and main-muzzle ammunition capacity through the existing authenticated support acknowledgement. Version2 reports bind the exact lease, COVER role, parent generation, owner epoch and observation time, with at most six seconds of validity. The owner checks its private epoch before reporting. At receipt and again before MOVE selection, the server requires the published coordinated parent to match that generation, epoch, current owner, support token and original lease expiry. A server-local group also requires the current private epoch; a remote group must not be compared with the server machine's unrelated private counter. Missing or delayed parent publication refuses capacity until an ordinary later report matches; it does not create an operation or renew any deadline. Version1 reports are rejected. The server stores them in its request job and rejects wrong owners, roles, epochs, stale observations, invalid counts and delayed rewinds. Rejection retires the token's capacity record. No new remote endpoint or polling worker is added.

New MOVE admission requires a fresh report for that helper with at least three eligible ammunition-qualified actors. Initial dispatch therefore publishes COVER first; owners report before a later server pass may select movement. Role changes, owner changes and expiry invalidate old capacity. Existing in-flight bounds keep their original deadlines. Inventory is never queried on a nonlocal actor by the coordinator.

This reports the prospective moving squad's capacity. It is not proof of settled cover positions, actual fire or the requester's base-of-fire capacity. Those external-cover checks remain unfinished. Native owner admission still validates team formation, actor orders and the operation. Physical bootstrap/role flow, delayed reports, HC migration and frame-time cost remain unverified while audits are paused.

Coordinated child bounds also recheck the current moving and covering teams through the shared bound executor before issuing movement. Dispatch capacity can expire or change during execution; loss of required rifle ammunition ends the child through its existing failure/cleanup path, without declaring completion. Crossing exits and consolidation retain their movement exception. Hidden or simulation-disabled actors cannot enter a new coordinated child roster. No per-frame inventory polling or ammunition manipulation is added. Physical casualty, ammunition-loss and ownership-transfer behaviour remains unverified.

Three-person coordinated responders retain their admitted two-plus-one partition: two move first, then the singleton follows while the arrived pair covers. Only that second turn with three live participants and the exact two-plus-one partition permits one mover. Larger teams and the first turn retain the two-mover minimum; ordinary two-survivor behaviour is unchanged. This avoids borrowing an arrived buddy merely to meet a contradictory follow-team minimum. Original movement, arrival, ammunition and deadline checks remain required. Physical repeatability remains unverified.

Initial coordinated fire-team allocation distributes whole buddy pairs by primary-ammunition capacity before balancing headcount. Dry participants remain enrolled; no pair is split and no equipment is changed. At most 64 participants are sampled once, with three bounded passes over pair/singleton chunks. Reconstructed bounds retain their saved partition and completed-turn history. Allocation improves capacity distribution but cannot manufacture ammunition or guarantee a feasible partition when pair constraints prevent one; execution still validates actual movers and cover. Physical balance and performance remain unverified.

After armed chunks are allocated, wholly dry pairs and singletons are balanced by headcount alone. Sending them repeatedly to the lower-ammunition element cannot repair its ammunition deficit and would produce oversized teams. Whole pairs and all roster members remain retained; this changes no movement authority or ammunition checks.

At a physically verified casualty visit, an empty-primary actor may attempt one native compatible-magazine pickup when ammunition sharing is enabled. Only the observed casualty uniform, vest and backpack containers are inspected; candidate selection checks at most 128 cargo rows per container. The engine performs the transfer; CBE neither clones inventory nor picks up weapons/backpacks. A separate generation-bound recovery journal reports VERIFIED only when positive acquired rounds equal removed source rounds and the primary weapon is unchanged. Replication delay or missing deltas remain UNVERIFIED; the observation result is still VISITED. This adds no timer, action cancellation or deadline extension. Native corpse-container transfer, animation, multiplayer replication and performance require physical validation; audits remain paused.

Live coordinated COVER helpers cap their existing group-brain callback delay at two seconds after tactical distance/reaction tuning. This services the six-second owner capacity report without another worker. The cap requires an active assault, exact role/lease token and unexpired lease; ordinary groups and other roles retain their chosen cadence. Scheduler overload can still delay actual execution, in which case stale capacity remains unusable. Runtime cost of servicing distant active helpers more often remains unmeasured.

Each admitted casualty investigation initializes its own recovery record as NOT_ATTEMPTED, so earlier verified pickups cannot appear to belong to a later visit. Pickup also requires two-metre distance and line of sight to the current body immediately before the native action; the original observation position alone does not grant inventory access. The existing body-movement cancellation threshold and observation result are unchanged.

Recovery accounting admits at most 128 magazine rows per source or receiver snapshot. Oversized source containers are skipped, an oversized receiver defers pickup, and oversized post-action evidence cannot verify a transfer. Totals are never truncated to manufacture conservation. Native snapshot creation still has engine-dependent cost; these limits bound CBE loops, not the native command implementation.

Infantry fire-control admission excludes hidden, simulation-disabled and FIREWEAPON-disabled actors before close-target, distribution or suppression work. These live actor gates supplement group/individual fire orders and native task ownership; CBE does not enable firing or simulation to make an actor eligible. Runtime benefit and physical mission-state handover remain unverified.

Infantry suppression now assesses obstruction separately from protected-actor safety. A one-metre vertical proxy above the unchanged ATL belief is checked against terrain, then one nearest FIRE/GEOM surface. A non-terrain surface within three metres of the objective can become the near-face suppression point; unrelated intervening cover rejects the lane. The protected-actor cone uses the actual issued point. At most three ammunition-qualified lanes are assessed per pass, with cursor rotation after blocked batches to avoid starvation. This issues no movement, does not disclose the enemy object and does not model penetration or prove suppressive effect. Added ray cost, windows, vertical geometry and physical firing remain unverified.

Suppression requires both the belief proxy and the resolved cover face to remain at least 20 metres from the shooter, matching the existing close-threat priority boundary. The final-point check matters because cover clipping can shorten a previously suitable lane. This affects scripted suppression only; close direct targeting and native engagement retain their own authority. This uses the existing close-threat boundary rather than introducing a separate tuning setting. Physical boundary behaviour remains unverified.

Tactical assessment uses the same visibility, simulation and FIREWEAPON availability gates as infantry fire control when counting usable rifle/launcher actors. Physical roster strength remains separate. If every actor is unavailable, the existing task handoff preserves current work instead of treating that as a low-firepower reposition request. No mission AI feature is changed. Suppression obstruction samples remain partial observations and do not independently authorize whole-group movement.

Manoeuvre fire-capacity counts require individual YELLOW/RED permission and FIREWEAPON as well as primary ammunition. This applies to tactical assessment, close-assault admission, initial flank/advance armed selection, coordinated capacity reports/pair allocation and the shared new-bound boundary. Physical flank/advance/support rosters remain enrolled; no hold-fire order is overwritten and no actor is forced to reload or fire. Existing crossing-exit/consolidation exceptions preserve committed movement. Permission loss can refuse a new bound through existing failure cleanup. Ammunition availability remains a separate read-only inventory predicate. Physical mission-order transitions and performance remain unverified.

Ground station readiness excludes incomplete or unknown native magazine reload phases before
ranking loaded weapons. A reloading preferred main gun cannot hide a completed usable alternate
muzzle. When none is ready, the existing reload observation retains its original finite operation
wait; no deadline is renewed. Final selection still independently verifies the selected station,
loaded magazine, rounds and completed reload. This changes no ammunition, route or movement owner.
Physical alternate-weapon selection during reload and its effectiveness remain unverified.

Tracked danger orientation shares the platform driving boundary used by group movement.
A declared external driving owner or platform external-control marker refuses new turn commands.
If ownership appears during the finite turn, CBE cancels its operation and removes its markers
without sending STOPTURNING into the successor controller. Return-to-calm uses the same boundary.
This is command ownership protection, not proof that either controller's queued engine actions
have stopped. Physical takeover, native turn quiescence and performance remain unverified.

Danger orientation and jink starts require a combat-effective local driver whose MOVE/PATH remain
enabled and whose native tasks, medical queue and actor reservation are free. Both refuse declared
platform driving ownership before creating an operation. Orientation records the original driver;
a seat change or protected task cancels it and suppresses late turn cleanup in the group tick and
return-to-calm. Existing eight-second orientation and twenty-five-second jink budgets are unchanged.
These checks preserve identifiable task authority; they do not stop or acknowledge queued native
turning, nor establish physical medical/seat handback or external-controller interoperability.

Tracked orientation also binds the full current authored native waypoint receipt. Changes to the
current node, count, script, attachment or native movement policy cancel the old turn without a
late STOPTURNING during normal or calm cleanup. The receipt helper reads authored metadata only;
it does not run waypoint conditions or statements. This adds a current-node receipt comparison
on the existing active turn callback, with no new worker or world scan. Direct script movement
that changes neither the authored waypoint nor a protected actor marker remains indistinguishable;
physical route replacement, engine turn quiescence and overhead remain unverified.

The turn's stored generation must match both the vehicle state and current operation, with the
original owner epoch and VEHICLE_ORIENT intent still live. Cancellation or replacement retires
permission rather than inheriting another operation. Cleanup removes only its matching generation's
marker; an old callback or calm snapshot preserves a newer turn marker. This establishes source
ownership checks, not actual engine stop acknowledgement.


Vehicle manoeuvre continuation now requires the exact committed waypoint and operation generation,
current owner epoch, unchanged native policy and geometry. Another CBE-labelled node cannot retain
an old jink, standoff or withdrawal. Edited/replaced routes cancel rather than report objective
completion; existing generation-bound cleanup preserves edited and successor orders. The existing
reverse controller retains its separate receipt. The group tick delegates these four vehicle
lifecycles, including expiry, to CortexVehicles; it no longer rejects current turn markers using
the obsolete five-field schema. No new worker or deadline renewal is introduced. The route check
reads one node's native metadata; actual engine handover and performance remain unverified while
audits are paused.

Vehicle retirement has one normal group-tick executor: the old generic turn/jink teardown is
removed. Jink markers now carry their operation generation, and ordinary/CALM cleanup removes
only a matching marker. A legacy marker without that proof cannot grant cleanup authority.
CALM turn-stop also requires that no newer operation generation has started, even if native
waypoint content is unchanged. The existing vehicle drill checks the new jink receipt before
its unchanged real-travel and crew-retention checks; that drill remains prepared, not run.

Vehicle withdrawal adoption now starts a fresh current-owner VEHICLE_WITHDRAW operation and
binds its accepted route and local state to that generation. Previously it rebuilt only a
waypoint/lease, which lacked the operation proof required by continuation and progress checks.
The episode start and remaining 120-second budget survive transfer; the former three-second
minimum is removed so repeated migration cannot extend expiry. A refused operation or route
retires its matching work and never publishes a successful resumed RETREAT. Smoke and reverse
actions are not replayed. The separate HC migration fixture now requires a matching public
operation/route generation and owner epoch before its existing physical-continuation checks.
It remains prepared, not run; split crew/vehicle ownership, actual repeated transfers and
performance still need in-engine verification. No new loop, worker or reference addon is added.

Vehicle withdrawal migration also requires the original episode's native-order receipt. It is
captured after accepted initial movement, refreshed after an accepted owned replan, and compared
on the locality edge before old-operation cancellation removes the temporary route. A new owner
cannot revive the retreat from durable intent alone after a mission changes the current native
order. Unknown/legacy receipts conservatively refuse vehicle resumption; infantry withdrawal is
unchanged. Accepted adoption records its own route receipt with the same original episode start.
CALM/completion clear the proof. NativeOrderReceipt covers current-node metadata and waypoint
count; future-node edits without a changed current receipt and same-value native commands remain
indistinguishable. This adds no recurring world scan or extra movement controller. Actual repeated
HC transfer, mission replacement and overhead remain unverified while audits are paused.

Rear recovery support now follows the existing forward-path policy: terrain and static
bridge/deck hits remain eligible, while vehicle/person hulls and moving-prop hits are rejected.
The same parent-first hit resolution runs on existing corridor and destination rays; there are
no extra rays, entity queries or workers. Existing support refusal reasons and recovery deadlines
remain unchanged. This closes a support-policy mismatch between rear and forward observation;
it does not prove continuous clearance or native reverse capability.
Actual bridge, moving support, parked hull and repeated recovery cases remain unverified.

Queue crossing keeps at most two side-plan attempts within its original agreement. If both
return refusal, the server now releases that exact token immediately through the existing
owner cancellation path. Previously it left all participants held until agreement expiry
without another planning action. No completion binding or successful route-resume permission
is published; existing native-command handback still requires its own receipts. The first
refusal retains its one alternate-side attempt. No new retry, timer, movement writer or
extended deadline is added. This improves failed-plan retirement; it does not supply missing
turn room or establish successful all-participant recovery. Physical refusal/cleanup and
subsequent mission travel remain unverified while audits are paused.

Clearance exterior reserves now use the same live task-free predicate as interior actor
commands. Pending medical care blocks reserve staging, watch/hold commits and casualty
promotion before a native treatment command starts. Existing reserve readiness is rechecked
at command boundaries, so admission alone cannot retain permission. The medical queue is
read only; no treatment is cancelled or cleared. Duplicate simulation/hidden/native-task
checks are replaced by the shared predicate, with no new scheduler, scan or recovery budget.
This closes a reserve/interior task-policy mismatch; actual casualty replacement, useful
exterior isolation and physical post-clear flow remain unverified.

Door assistance respects pending medical care in every request context. The owner reads the
existing care queue before interaction visibility checks and again before door animation;
metadata-only discovery remains read-only and available. No queue is cleared, door unlocked
or interaction radius changed. Existing three-metre, same-floor, lock, task, ownership and
fresh visibility gates remain. This avoids an unrelated world interaction while treatment
is pending; it does not establish successful building entry or improve inaccessible model paths.

Clearance egress ownership now combines its exact native move/hold receipt with the shared
live task-free check. Queued medical care can therefore veto the first exit command as well
as later arrival, retry and handback paths using that predicate. An actor diverted by a
new task is not recalled or counted as a successful egress; the existing incomplete result
is retained. Passive movement receipts remain available for diagnostics and cleanup.
Room retry exhaustion still cannot create a physical visit or successful clearance. No
new retry, timer, scan or deadline is introduced. Real treatment-to-movement transitions
and post-clear flow remain unverified.

Clearance proposal diagnostics are opt-in through the existing addon Debug setting or
the per-group entry-capture flag. Ordinary reserve selection now uses the validator's
boolean fast path, so invalid bounds/reservations can reject before unnecessary visibility
rays and occupancy work. Detailed cover/uncovered proposal arrays and proposal logs remain
available when requested; egress proposal logging uses the same gate. Terminal failure and
retry-exhaustion evidence remain available. Acceptance predicates, actor/geometry budgets,
movement authority and deadlines are unchanged. This removes avoidable work by inspection;
no measured frame-time or 5% median/10% p95 budget claim is made.

Cover selection accepts an optional intended actor after its screening-mode argument. Danger
cover, anti-armour relocation, grenade avoidance and clearance reserve selection pass their
actual recipient. Occupancy excludes only that actor, and every object ray ignores the same
actor so its body cannot fabricate cover or invalidate standing room. Other soldiers retain
their existing occupancy and geometry constraints. Unassigned formation-slot searches keep
the default null actor. The helper remains read-only; native task/movement ownership is still
checked by each executor. No search radius, query/ray budget, reservation or deadline changes.
Actual stable-cover retention and movement quality remain unverified.

A new nearby danger event may retain an already committed cover approach only after a
fresh check using its recorded screening class. COVER uses the selection path's material
ray policy; CONCEALMENT uses its visual policy. The decision must match the actor and
original lease generation, and the incoming generation must still be current. Unknown
screening proof cannot authorize adoption. Existing threat-distance, native movement and
order receipts remain required; no doMove is repeated and the original deadline is not
extended. Endpoint heights and recipient exclusion match selection. At most one object
ray plus a terrain-intersection check runs for this eligible event transition. Physical
screening and performance remain unverified.

Cover selection and active danger-leg adoption now share a read-only screening predicate.
Human surfaces cannot establish either cover or concealment. Parent/direct hit resolution
checks at most four returned surfaces from the existing single object ray, allowing a solid
object behind a passing person to qualify within that bound. Terrain screening, recorded
mode and intended-actor exclusion remain. Saturation may conservatively miss an obstruction
behind several human hits. The source-body offset is capped to half the segment length,
so a close threat cannot reverse the ray beyond its endpoint; invalid or degenerate segments
refuse. No movement, persistent cache, new setting or scheduler is introduced. The ray count
is unchanged; returned-hit processing grows from one to at most four. Physical screening
and frame-time cost remain unverified.

Buddy-pair publication retains an untouched living same-group partner as a singleton when its former buddy receives a new active assignment. Active assignments still win and each actor appears once, within the existing sixteen-row bound. Retained identity grants no fitness, movement or fire authority. This avoids losing dormant partner identity during partial roster updates; casualty flow and performance still require physical verification.

Ordinary drill casualty refill uses the existing pair-aware element selector for up to five vacancies from sixteen ranked eligible reserve candidates per selection. Intact reserve buddies can join the same depleted team together; one remaining vacancy prefers an orphan when available, with minimum capacity allowed to split a pair. Original actor-task, native-order and owner-generation commit checks remain authoritative. No new worker, movement controller or deadline is added; physical cohesion remains unverified.

Casualty refill first prefers an eligible reserve whose recorded buddy is already in the receiving team, before allocating unrelated intact reserve pairs. The read-only selector accepts up to sixteen receiving-team identities, disjoint from its sixteen ranked eligible candidates. This preference cannot recruit an unavailable actor or bypass the existing final authority checks. Initial element selection retains its default empty receiving team. Actual reunion movement remains unverified.

CQB casualty promotion ranks the existing rotating window of up to sixteen reserves by distance to the surviving buddy, or the building when no buddy is available, before consuming cover verification. Equal-distance candidates use stable actor identity order. This prevents a farther roster entry from spending the single shared VIEW ray ahead of a nearer reserve. The original one-ray budget, established exit-cover proof, final authority checks and deadline remain unchanged; this does not guarantee the nearest reserve outside the current window or prove physical replacement flow.

When a CQB replacement candidate actually consumes the single cover-proof ray, the pending casualty slot remembers that actor identity. Its next proposal starts after that actor in the current distance-ranked window; successful promotion clears the cursor. This prevents repeatedly blocked near posts from monopolising proof while retaining the same ray budget. Cursors hold no movement or coverage authority and do not renew any deadline. Changed windows or actor movement can alter ordering; larger-roster fairness and physical flow remain unverified.

Actor danger posture treats actual movement at or above 0.5 km/h as mobile regardless of native command label, including ATTACK travel. Native MOVE and INIT/PLANNING/REPLAN remain protected while stationary. Immediate danger can apply a weak crouch to a moving actor, but does not force it prone or trigger idle lateral evasion. Stationary combatants retain existing prone/evasion rules. One speed sample is reused within the response; no route, target, firing command, worker or query is added. Physical assault continuity and performance remain unverified.

Tracked orientation binds the original effective commander as well as the driver and authored order. Both must remain local, combat-effective and free of protected native tasks, queued treatment and movement reservations. A changed commander or protected task cancels the old orientation and suppresses late STOPTURNING in ordinary and CALM cleanup. The marker now includes commander identity; unknown old markers grant no turn-cleanup command. This is conservative retirement, not proof that a previously issued native turn has stopped. Jink already uses the shared group-movement crew-task guard. Physical crew changes and handover remain unverified.

Tracked orientation rechecks its operation contact for death/deletion, friendly allegiance, captive, surrender and handcuff status through the existing lifecycle callback. Invalid contact cancels with CONTACT_INVALID rather than alignment/completion credit. Admission applies the same hostility checks. It still faces the recorded belief point without sampling a hidden live target position. Normal exact-authority cleanup may stop the old turn; changed crew, orders or ownership still block that command. Physical ceasefire transitions remain unverified.

Avenue exposure scoring shares the non-human cover/concealment predicate used by cover selection and adoption. A soldier intersecting an exposure ray cannot make an avenue score as screened. The supplied belief point remains the ray origin, and the optional source object remains excluded without reading its live transform. Candidate, terrain-safety, support-fire corridor and three exposure samples per leg remain unchanged. Each object ray can now return four surfaces rather than one; an uncovered sample may perform one additional terrain test for concealment. Runtime cost and physical route quality remain unmeasured.

Tracked orientation refuses a driver who is also effective commander, native BACK/direct-commander movement and an existing turn. Its nine-field marker records the requested LEFT/RIGHT direction. A later contradictory turn or BACK/direct input cancels with NATIVE_INPUT_CHANGED. Normal and CALM STOPTURNING require the current turn to equal the recorded direction as well as all existing crew/order/generation guards. NONE is allowed while waiting, but supplies no cleanup-turn authority. Same-direction replacement remains indistinguishable, and native command acknowledgement and physical handback remain unverified.

Shared temporary group-waypoint admission, same-route adoption and final insertion yield to native BACK/direct-commander input or LEFT/RIGHT simple turns on ground vehicles whose driver or effective commander belongs to the group. The existing platform-owner scan deduplicates crew parents before inspecting each vehicle. Static weapons and aircraft do not acquire this ground-input restriction. No turn is cancelled and no crew is reassigned to admit movement. This protects jink and other shared vehicle route callers; it is not convoy-spacing tuning or proof of smoother mixed convoys. Same-value commands and physical handback remain unverified.

CQB room-lane execution rotates its first processed lane on each callback, after the separately rotated physical-visit observer pass. It iterates original lane IDs: pair membership, pair-state slots, room routes, claims and progress clocks are not reordered. This prevents a fixed lane zero priority when the shared sixteen-ray geometry allowance runs short. The budget, lane count, callbacks and deadlines are unchanged. Owner adoption may reset only the proposal-order cursor; actual entry flow and large-squad fairness remain unverified.

CQB entry motion compares each available actor against that actor's previous position sample. The former findIf body read an outer forEach index, so separate stationary buddies could appear to move and defer doorway recovery. Actor identity now selects the filtered pair slot, including after a casualty. This changes neither the progress threshold nor retry/deadline limits. Its effect on observed doorway stalls remains an in-game retest item.

For ordinary fire-and-manoeuvre legs, drill relief transfers qualify rifle ammunition, individual YELLOW/RED engagement permission and FIREWEAPON before moving a donor actor between roles. A relief must include a qualified rifle and leave at least one in the donor team as well as its required headcount. Orphan-first and whole-pair preferences remain subordinate to those constraints; a pair containing every useful rifle cannot leave dry actors as nominal cover. This check runs only when a depleted role requests relief, through the existing callback. Ammunition availability is not immediate firing readiness or effective cover; physical casualty bounds and overhead remain unverified.

Relief on CROSS_FAR and CONSOLIDATE retains ordinary headcount/pair selection without a rifle requirement, so ammunition loss does not prevent actors leaving a road or reaching consolidation. This matches the existing next-bound exemption.

New drill reserve recruits on ordinary fire-and-manoeuvre legs must have primary rifle ammunition, YELLOW/RED engagement permission and FIREWEAPON enabled before pair-aware selection. Existing participants are not expelled when ammunition changes. Road-exit/consolidation recruitment keeps the existing movement exemption. Both individual-element and two-team refill rank reserves only when a real vacancy exists, avoiding reserve task/role/ammunition checks on intact-roster callbacks. Missing useful reserves cannot renew the drill deadline. Physical replacement flow, balance and overhead remain unverified.

Declaring a unit CBE_AI_SkillOwner now releases the optional profile layer on its next existing lighting pass even if lighting, equipment and seat signature are unchanged. Nonempty or invalid-type ownership blocks reapplication; only unchanged exact skill/aim pairs restore, preserving mission edits and incomplete receipts. After cleanup, a sticky owner with no receipts skips restoration parsing. The ten-unit callback bound is unchanged, with no new watcher or routine native skill polling. Clearing ownership retains the existing explicit reacquisition contract. Mission and HC sequencing remain physically unverified.


### Native driver casualty during acknowledged reverse recovery

The existing driving FSM first runs `DrivingRecoveryCrewHandback` when an admitted native vehicle loses its driver during an acknowledged reverse. It requires the original surviving local commander, exact current cap issuer and recovery journal, and no competing child controller. A pending destination request is observation-only: the original surviving commander must acknowledge its recorded goal before the original reply deadline. The existing exact cap is constrained to zero while waiting; no request or recovery clock is renewed. It confirms its owned cap at zero, issues one native stop, observes native acknowledgement and measured linear/angular rest, then issues the original goal once. Each reply has at most two seconds within the original recovery hard deadline. A newer command, cap, task, Zeus or external owner cancels the handback; failed phases do not replay.

After original-goal acknowledgement and rest, the journal becomes FINAL with its original hard deadline, progress anchor, baseline and spent allowances. The ordinary crew executor still has to confirm actual replacement seating and goal acknowledgement before rebinding operating receipts. No driver insertion, waypoint rewriting or recovery-budget renewal occurs. An already issued native return is also observation-only: its recorded goal must match the original route, its original reply deadline must remain live, and acknowledgement plus measured rest convert it to FINAL. Cleanup offers this observation to the same live owner FSM before classifying a dead or deleted driver; changed journal proof retires the old cleanup ticket. A lost/dead commander and crew-episode transfer remain unsupported. Expired or changed requests refuse handback rather than replaying them. This path has offline validation only; physical behaviour and performance remain unverified while audits are paused.


### Current danger observation handoff to fire control

Native CANFIRE suppression consumes the current eight-field danger observation as well as legacy six/seven-field records. The opportunity stays bound to its original contact, original source expiry and surviving local identity witness. That witness must still know the hostile and must not ignore it. The group knowledge record supplies the believed position; the danger event never reveals a position or assigns a target. Existing range, movement, ammunition and protected-actor firing-lane checks still govern the burst. Finishing the matching danger FSM clears both the response and its saved event. This repairs the observation-format handoff; physical suppression and runtime performance remain unverified while audits are paused.


Danger-cover cleanup checks the previous leased soldier independently when another observer supplies the current event. A failed approach may return to formation only while that previous soldier remains combat-effective and is not fleeing, in addition to the existing exact route, task, owner and movement-receipt checks. A new healthy observer grants no authority to recall an incapacitated or fleeing previous responder. Retiring the old CBE marker does not clear the native flight or care state.


### Finite danger-stance handback after tactical shutdown

Disabling tactics retires tactical jobs while retaining the existing bounded posture-cleanup job for exact pending weak-stance receipts. The controlled same-machine shutdown epoch carries only the original group/generation, unchanged applied stance and original expiry plus thirty-second restoration window. It grants no danger event, route or tactical planning authority. Zeus, player, specialist, changed stance and unrelated ownership still win; medical, flight or native-task blocks can wait only inside that original window.

The shared scheduler remains active solely while valid finite cleanup jobs remain, then releases that runtime. It pops one of at most sixty-four queued actors per callback, and checks for final runtime retirement only when a cleanup job actually ends. A direct blocked release can wake its existing queue entry without adding another actor or renewing the receipt. Expiry records unresolved restoration; it never forces a late stance change. Runtime shutdown/medical/flight transitions and performance still require physical validation; audits remain paused.


Shared operation attack-permission acquisition confirms the native `attackEnabled` value before publishing its reversible receipt or returning ACQUIRED. A refused native write leaves no newly claimed permission ownership; existing CQB and flanking admission handles that refusal. Existing receipts remain read-only and a changed native permission is never reapplied. This readback establishes property state, not physical combat behaviour.


Attack-permission release reports RESTORED only after native readback confirms the original value. An unconfirmed write retains its receipt and publishes one unresolved group record containing the issuing generation, epoch, original/applied values, owner and observation time. Repeated release does not replay that write. Operation cancellation/completion can retire movement while this separate evidence remains. Fresh attack-policy acquisition refuses while the old restriction is still applied, rather than treating it as mission baseline. Observation of the original native value can retire this metadata, including on a later local owner; it never authorises a delayed restore command. No automatic retry, worker or eventual-restoration claim is added. A mission/controller that refuses the native change must relinquish or change its permission before this acquisition can proceed. Physical override, release and ownership-transition cases remain unverified while audits are paused.


### Native flight and ordinary driving ownership

Either operating crew member entering native fleeing revokes ordinary steering and route-recall permission, even before its native MOVE destination changes. The existing ordinary command gate, pass/queue consent and commits, corridor/bypass steering and cleanup, reverse handback and queue-abort resume all check this boundary. Cleanup may retire matching CBE task metadata; it cannot issue STOP, fixed steering, route MOVE or follow merely because the old destination still matches. Exact speed-cap baseline release remains separate so yielding does not require another movement command. No fleeing state, morale policy or native AI feature is changed. Physical flight/traffic/handover cases and runtime performance remain unverified while audits are paused.

Queued ACE treatment is an independent veto at corridor/bypass steering and movement cleanup, including abort route wakeup. Native MOVE/STOP can remain unchanged before a medical task begins; a matching route does not override that queue. CBE reads the existing queue without clearing or changing it. Exact cap-only cleanup remains independent. Physical treatment/steering transitions remain unverified while audits are paused.

### Illumination weapon handback

Flare release and rifle restoration are separate observations. Illumination result field five records NOT_CHANGED, BASELINE_OBSERVED, RESTORED, SUPERSEDED or UNCONFIRMED. Only a local native selection readback establishes restoration. When an exact selected launcher remains and cleanup cannot restore the original weapon, the original/applied selection fact survives action retirement. A later eligible local admission observes it without retrying a command; the still-applied launcher cannot become a new baseline. An original or different native selection retires the fact; malformed proof blocks that actor. No timer or delayed restore is added, and native fleeing prevents illumination commands. Watch identity, physical illumination and refused/asynchronous selection timing remain engine-validation requirements; audits are paused.

Morale distinguishes remembered armour pressure (within400m and30s) from immediate heavy-armour overmatch (within120m and10s). One pass over the existing bounded native-belief contact list finds both; a stale first armour record cannot hide a fresh later threat. Usable carried AT and authored HOLD/SENTRY retain their independent overmatch vetoes. No hostile transform, extra sensing, worker or inventory policy is added. Physical withdrawal and performance remain unverified while audits are paused.

### Reactive mortar evidence lifetime

A mounted danger response requests mortar fire using the current owner witness native believed position, after the original identity lease and belief remain valid. The authenticated request includes its server-time observation. DANGER admission rejects missing, future beyond tolerance, or expired observations; its10s expiry is stored once and carried unchanged through the server mission and shot identity. The battery owner rechecks it in the existing session gate before native fire, so queue delay cannot renew evidence. Server admission does not compare belief with the unseen enemy transform. Existing allegiance, knowledge, ammunition, range, safety, feature, task and token checks remain. An expired already-issued shot stays uncertain rather than being replayed or declared cancelled. Physical mortar timing and performance remain unverified; audits are paused.

Artillery request idempotence includes refused serials. The battery owner retains one separate last-refused token/serial/signature fact; the existing issued-shot receipt remains firing-command provenance only. Within a token, the highest observed issued or refused serial prevents replay after a task/safety change. A rejection reply includes its exact serial and can settle only that current pending server request. Neither receipt proves a projectile fired, nor guarantees ordered replication across owner migration. No new worker or retry is added; delayed/migrated physical cases remain unverified.

### Deferred clearance settings after shutdown

Exact post-clear speed/stance handback uses a finite restoration-only job on the existing shared scheduler, independent of tactical enablement or pause. One actor from at most64 members is offered per callback within the original30s window. The former group-brain retry loop is removed. Controlled same-machine stop carries only the matching pending generation/epoch and retains its deadline; existing validated locality adoption queues cleanup without replaying clearance. ActorSettings still checks actor authority, reservations, issuer and unchanged applied values. New operations block restoration; expiry records unresolved evidence and retires the callback while actor baselines remain. The final job removes the cleanup runtime. No movement, targeting or new native setting acquisition is authorised. Physical shutdown/restoration and performance remain unverified while audits are paused.

Clearance and garrison now share ActorSettingsCleanupStep on the same SETTINGS_CLEANUP runtime. Clearance keeps its original group window; garrison pops one of at most64 pending actors and retains each original issuer-bound retirement deadline. The old garrison retry loop is removed from GroupBrainStep. Garrison release, controlled stop and actual locality adoption queue only already-pending restoration facts. Neither path replays garrison assignment, duck, watch or movement, and no expired window is renewed. Canonical ActorSettings validates every native write. This consolidates the executor; it does not establish physical shutdown, owner-transfer or performance acceptance.


### Aircraft attack release authority

Aircraft attack cleanup edits its named temporary waypoint only on the current group owner. Vehicle locality alone does not authorize group commands. The one-time Zeus route replay requires the original group and pilot to be local, an active waypoint hold, and a seven-field snapshot bound to that hold token. A fresh waypoint lookup must match its position, type, behaviour, speed and combat mode. Missing or superseded snapshots and removed waypoints cause no replay, height command or immediate-handover result; cleanup never falls back to a possibly reused waypoint index. Generic external-controller release does not itself grant Zeus route authority.

This adds no worker or scan: the existing finite cleanup searches the current waypoint list once. It does not prove cross-owner route retirement or physical aircraft travel. Dedicated-client/HC handover and performance remain unverified while audits are paused.


### Danger action-state behaviour replacement

The engine danger FSM classifies a response in Init and executes it in a later action state. DangerEngineAct rechecks CARELESS before evasion, observation, posture, or attack-pace requests; changing to this authored behaviour between states therefore returns zero delay without a final CBE reaction. Classification and Waiting retain their existing release checks. The shared action helper covers the engine-loaded FSM without adding a second controller or repeating terrain/roster work. Existing owned cleanup still runs. Physical state-transition timing remains unverified while audits are paused.


### Clearance expiry before sweep work

An expired clearance callback now enters the existing egress transition before reserve promotion, room observation or further entry/sweep movement. This prevents a late callback from issuing another room request or renewing an already-expired stall deadline from a newly observed visit. Successful coverage and expiry share one egress transition, retaining actual participation checks, newer-task diversion, early-exit receipts and the existing45-second exit budget. Expiry grants no room visit or clearance success. No new scheduler or per-actor worker is added. Physical repeated clearance, casualty replacement, egress and runtime cost remain unverified while audits are paused.


### Clearance cancellation after settings retirement

Explicit clearance release recognises an exact live MOVE to its saved job destination even if speed/posture settings have already retired. Previously the outer participant check could skip that actor and retire movement metadata while leaving the native room leg running. Recognition requires finite three-component targets within0.25m; the existing later task/destination check still governs recall, and changed destinations, player/external control, reserved actors and mounted actors retain their protections. Restore=false still issues no formation recall. No retry, timer or worker is added. A native recall request is not acknowledgement or proof of physical handback; repeated and cross-owner outcomes remain unverified while audits are paused.


### Garrison refill preserves disabled pathfinding

An unassigned spare with mission-disabled PATH is not recruited as a walking garrison replacement. Previously it could reserve a vacant post despite being unable to approach it. Exterior promotion remains separate: a CBE-owned disabled-PATH guard at a verified post can be released only with the existing physical exit-cover checks. Refill never enables a spare's mission-disabled pathfinding and grants no arrival from selection. The change adds one feature query to the existing bounded candidate pass, with no worker or retry. Physical vacancy turnover, preserved exterior coverage and performance remain unverified while audits are paused.


### Garrison vacancy observation cost

The settled refill callback reads each living member's interior assignment once before examining candidate posts. This replaces up to64x64 repeated assignment-variable reads with at most64 reads in the vacancy pass; up to4096 building/position comparisons remain. An empty candidate list exits before collecting occupancy. Living incapacitated members still reserve posts, exterior assignments do not occupy interior slots, and the same building and distance-below1m checks select vacancies. The snapshot exists only inside the current callback; candidate readiness and movement authority retain their existing checks. This is a structural reduction in script/native reads, not measured frame-time improvement or proof of the5% median/10% p95 budget. Audits remain paused.


### Withdrawal attack-permission ownership

Infantry withdrawal acquires disabled autonomous attack through OperationAttackPolicy after retiring any drill and starting its current operation, before issuing its new route. A refused or unconfirmed acquisition releases that exact operation and movement lease with ATTACK_POLICY_REFUSED. Retreat no longer creates a separate baseAttack/attackChanged state lease or writes enableAttack directly. Completion, cancellation and the existing locality adoption path use the common operation's confirmed baseline and applied value; successful completion restores its unchanged permission before regrouping. This does not add coordinated multi-squad withdrawal, a new controller or a timer. Physical pursuit suppression, restoration, migration and performance remain unverified while audits are paused; identical external writes remain indistinguishable without provider cooperation.


### Withdrawal expiry and policy interruption

The RETREAT callback checks its original120-second phase budget before morale, straggler recovery or route replanning. An expired episode uses the same end transition as physical completion. That transition releases the captured operation generation and the correct infantry/vehicle withdrawal lease, then clears the generation-bound route before regrouping. Vehicle withdrawal no longer falls through infantry-only completion cleanup. Infantry also checks its existing confirmed attack-permission receipt without acquiring or reapplying policy: a missing or changed receipt cancels withdrawal and yields through calm restoration before further recovery. No timer, roster scan or independent controller is added. Physical interruption, vehicle handback, HC migration and performance remain unverified while audits are paused.

Fleeing infantry prefer screened exterior cover. If none is found and building combat is enabled, the existing danger-flight action checks at most two nearby houses within 18 metres. It reuses the indoor node selector on the actor's original floor (at most 512 ranked positions and three roof probes per house), respects known failed nodes and squad body separation, and requires current threat screening and an unchanged building transform. The same single movement request and original 4â€“12 second lease apply. Native navigation still determines access; roofed positions do not prove accessible interiors or safe rooms. No door unlocking, additional controller or forced movement reset is introduced. Physical entry and performance remain unverified while audits are paused.

Scripted danger abandonment uses the shared local crew-actor admission check before cancelling boarding, unassigning or requesting exit. Player/remote/specialist control, incapacitation, hidden or suspended simulation, native protected tasks and movement reservations defer that actor; explicit STOP also defers. Other eligible occupants may still leave. The reason marker records the danger decision, not successful evacuation. Native emergency bailouts remain independent. No vehicle stop, seat teleport, crew recall or new worker is added.

Driving recovery applies the original hard deadline even when its first cleanup callback arrives late. Exactly owned expired rear work retains its command/baseline proof and existing safety-cap retirement path, records an unresolved deadline and cannot replay either an authored or native route. A prior release-pending marker is not required to enforce expiry. Changed or superseding orders still use the separate ownership checks. This does not prove physical recovery or handback.

Infantry suppression counts an ongoing native SUPPRESS command against the configured suppressor limit even after its eight-second timestamp window. Soldiers already executing that command receive no repeat suppression request. The eight-second request/rest window and existing group spacing, loaded-ammunition, ROE and firing-lane checks remain. This observes command state, not actual shots or suppression effectiveness; Arma selects native burst duration ([command reference](https://community.bistudio.com/wiki/doSuppressiveFire)). No burst cancellation or new timing worker is added.

Ordinary immediate danger cover now shares DangerRefugeSelect with native fleeing. After exterior solid-cover failure, the same-floor roofed and screened indoor fallback runs inside the existing selection pass, before recording a failed search. The existing three-second negative cache covers that combined failure; concealment-only retries do not repeat the house search. Authority, posture handoff, one movement command and original 4-12 second lease remain in DangerCoverStep. Indoor hiding introduces no forced speed/stance reset or delayed stop callback. Entry, useful protection and performance remain unverified while audits are paused.

General infantry rifle fire control now checks the current native weapon-state weapon and magazine before admitting an actor. Carrying a primary rifle is insufficient while a launcher, handgun or underbarrel non-bullet magazine is selected. Those actors retain native/specialist combat, including the separate anti-armour path; this pass neither switches weapons nor forces a rifle selection. The read-only selection check runs once per otherwise eligible roster member with no new query or worker. Existing suppression readiness checks still run at its issue boundary. Weapon switching, shots and balance remain unverified in-engine.

The combined ground manoeuvre's single stall retry now explicitly refreshes its own unchanged current temporary waypoint. Ordinary same-destination requests remain idempotent; a refresh requires matching operation generation, current waypoint and exact live route policy at the mutation boundary. Only the CBE temporary node is recreated, and the job stores the resulting waypoint/receipt for later continuation and cleanup. Original role expiry and one-retry budget remain unchanged. This requests a genuine native replan; it does not establish travel or recovery success, and never clones mission/Zeus waypoints.

Naval approach and passenger egress publish moving state only after the common waypoint executor accepts their exact operation generation. Refusal retires the attempted generation/lease; passenger and crew continuation also stop at an outer action boundary if operation creation fails. Draft boat admission interrupted by external takeover cancels its captured generation before publishing a public plan. Vehicle standoff likewise releases refused movement rather than claiming ownership; the existing cooldown waits eight seconds before another failed-admission attempt, retaining its normal sixty-second accepted cadence. Acceptance remains a request result, not proof of travel or landing.

Ordinary vehicle and convoy unload-retention policies relinquish their unchanged owned lease while the current driver or effective commander is natively fleeing, as they already do for immobilisation. Only those two operating seats are observed; one panicked passenger does not revoke the whole carrier policy. Release restores the exact captured unload settings, so a mission-disabled bailout stays disabled. It issues no exit, boarding, suppression, fuel or crew command. Once native flight ends, existing acquisition and incoming-boarding checks govern normal retention again. Physical native bailout behaviour and balance remain unverified.

Naval episodes now retire at an outer action boundary when their original local, reconstructed durable or matching boat-plan deadline expires. They cannot fall through into a fresh plan in that callback, and expiry never publishes landing success. Completion requires DISEMBARK with no living cargo still aboard. Starting infantry delivery requires living cargo and refuses an oversized crew result above sixty-four rows; empty gunboats retain other/native combat. No deadline is extended. These lifecycle checks do not establish passenger egress ownership, physical landing or crew safety.

Same-group naval passengers now retain a token-bound landing roster after departure from the boat. Exit requests preserve current actor assignment/tasks and require boat linear speed below0.5m/s and angular speed below0.1rad/s. Foot egress waits for physical detach and native exit completion, then uses the existing RecoveryStep once-per-generation executor under the current naval operation. Its public native-request receipt prevents replay after handover; shared actor reservations exclude competing scripted movement/fire. The original naval expiry is unchanged. Physical three-dimensional arrival is observed; unfinished or interrupted same-group egress cannot complete the landing. Release requests STOP only for an acknowledged exact owned move, observes the reply, and retains unresolved proof; it never follows the boat leader or reboards a passenger. Existing sparse DangerSetup reaps cleanup without a new worker. A request unacknowledged through original expiry plus thirty seconds retains proof and grants no late command. These are implementation checks; naval travel, waves, dismount, egress, ownership interruptions and performance require in-engine verification.

Naval continuation also requires its current common operation generation, intent, owner epoch and non-cancelled state. A cancelled or replaced operation releases the old boat/passenger plan. Same-group foot dispatch admits at most two new moves per group callback while observing up to sixty-four retained landing members; unchanged participant bookkeeping and unresolved results are not republished. This bounds dispatch work, not measured frame-time overhead.

Separate naval passenger squads reconsider still-embarked members on their existing group tick when an earlier protected task clears. A retry requires the same boat plan, token and original deadline, disembark phase and measured low boat motion; individual assignment/task authority still gates the request. An active native exit is not reissued, no forced exit or new timer is used, and foot egress waits for actual detach. This continuation remains unverified in Arma.

Naval passenger completion observes every surviving combat-effective member on foot, on dry ground and within the existing thirty-metre egress area in three dimensions. Leader arrival alone is insufficient. A survivor boarding another platform cancels the old landing rather than directing that new carrier to shore. The original landing expiry still bounds stragglers; no new readiness timer or progress deadline is created. Physical acceptance remains pending.

Actor manoeuvres can select a read-only anchor from an explicit ground element through `[_group,_members] call CBE_fnc_CortexGroupAnchor`. This inspects at most64 supplied members and returns only a current local, combat-effective, simulated foot member of that group and element. An explicit empty/unavailable element returns `objNull`; it never falls back to a mounted or nonparticipant native leader. Ordinary one-argument lifecycle callers retain their twelve-member fallback. Assault admission uses its foot roster; recovery uses its surviving main element and defers without issuing movement if no anchor exists. No native leader or group membership changes. This builds the element boundary but does not yet enable independent mixed-group tactical assessment or prove naval ground-command parity.

After successful same-group naval egress, CBE retains the landed cargo roster for the existing forty-five-second landed interval. This semantic handover is bound to the original boat/plan token, owner epoch and unchanged native route; feature closure, takeover, migration or a changed route retires it. The existing group job may admit that foot element to the existing actor-only close-assault or bounding-advance executor using current believed contact positions, the foot anchor and normal feature, morale, ammunition, task and avenue gates. Flank and group reposition fallbacks remain unavailable: operating crew never receive a land waypoint. Explicit element advance validates the native order type but uses fresh reported contact as its objective, so the boat's authored destination cannot become an infantry goal. Normal whole-squad advance retains authored-objective behaviour. Both actor executors have their existing finite lifecycle, restricted casualty refill roster, checkpoint scope and element-local recovery/formation handback. The reserve pool retains the original admitted element, including temporarily unavailable landing members; only currently eligible actors can fill vacancies, and operating crew outside that original roster remain excluded. No native leader change, group split or additional polling worker is used. This implements one finite landed-element manoeuvre; sustained independent ground command, CQB continuation and actual engine behaviour/performance remain unfinished or unverified.

Standalone drill checkpoints retain explicit ground-element scope and its original roster. Replacement-owner resume validates the scope flag, bounded object roster and membership of every saved drill participant before acquiring even its locality-settling lease. Missing or widened scoped rosters refuse instead of becoming whole-group drills; ordinary older checkpoints without a scope flag retain their existing behaviour. Native movement proof and original clock handling remain separate from this semantic scope. Physical headless-client migration remains unverified.

CONTACT can propose individual indoor work even while a separate movement layer is active. Existing `IndoorActorGroupAvailable` checks remain decisive: a group waypoint, ambiguous or unsupported common operation, overlapping drill/support participants, live actor reservation or protected task refuses admission. Only explicitly disjoint available actors can enter the existing two-investigator FSM; whole-group clearance, coordination and manoeuvre still respect exclusive movement ownership. The shared eight-second selection cooldown, rotating sixteen-member sample and bounded native beliefs/roof queries remain unchanged. An idle vehicle-layer result also no longer erases another active movement owner in the group decision. This enables complementary individual investigation; it does not establish full building clearance or physical CQB acceptance.

Indoor contact/body-clue dispatch now validates shared group ownership once before filtering its bounded actor sample. `IndoorActorGroupContext` produces an ephemeral local snapshot containing the group identity, epoch, generation and excluded participant/drill/support rosters; it is neither stored nor broadcast. Candidate filtering can therefore avoid repeating the same maximum64 participant locality/group checks for up to sixteen sampled actors. Native actor tasks, reservations, health and feature checks remain per actor. Actual START/STEP and door execution still call `IndoorActorGroupAvailable` without a snapshot, forcing fresh authority checks at command boundaries. Sampling retains its existing cursor behaviour; a full investigator capacity or empty sample exits before group roster validation. No worker or persistent cache is added, and the five/ten-percent runtime budget still requires in-engine measurement.

Individual hostile-building investigation now reuses persistent buddy metadata when choosing up to two investigators. Among actors already passing current contact knowledge, range, health, native task and ownership checks, the existing read-only element selector prefers an eligible partner of a live investigator working that same building/contact, then intact eligible pairs. The dispatcher retains non-leader preference when enough alternatives exist, keeps the formation anchor last within the preferred set and preserves the original distance order for all fallback candidates. Each actor still passes independent START authority and capacity checks; a refused or unavailable buddy causes no wait or fabricated paired-entry result. No new pair is published and no movement/cover synchronisation is implied by selection alone. Physical cohesion and entry flow remain unverified.


Indoor preflight also refuses an empty common operation while a movement lease, drill or responding/assaulting claim remains active. This covers the deferred locality-resume settling interval before the participant roster is rebuilt. Local state leases use time; public movement leases use serverTime. Malformed nonempty leases refuse admission; expired well-formed leases alone do not. No lease is changed or renewed. Valid current participant-scoped operations retain disjoint actor admission. Physical migration and entry remain unverified; audits are paused.


Individual indoor investigation cleanup has a final native-command cutoff at its original server deadline plus thirty seconds, shared by normal finish, locality transfer and later discovery of an ended FSM. Before the cutoff, only the existing exact unchanged movement receipt permits return to the native route/leader. Afterward cleanup can retire its own metadata but issues no new doMove/doFollow. It does not restart the investigation or refresh the deadline. This bounds stale callback authority; it is not an acknowledgement protocol or physical proof of movement handback.


Ordinary driving skips forward hull discovery and forward gate/obstacle geometry while a validated native-crew boarding hold or queue hold requires zero speed. Forward clearance cannot relax that hold. The final cap boundary still rechecks the specific hold, and a vanished hold refuses that write; later motion gets fresh observations rather than cached clearance. Pedestrian and rear safety, recovery clocks, cleanup and the existing callback cadence remain. Gate opening is deferred until forward observation resumes. This removes discarded observations; runtime savings and physical boarding/queue release remain unmeasured.


Immediate danger evasion now includes a short native lateral tactical dodge for an idle standing or crouched primary-weapon rifleman after a hit/near round. Existing task, treatment, specialist, movement/path, committed-route and feature gates remain. Direction uses only the observed danger position; two short side segments at lower-body/eye height veto a known obstruction. A blocked direction keeps posture without another route. The same three-second cooldown bounds successful actions and failed probes. Successful lateral action retains a mobile crouch instead of immediately receiving the idle hard-cover prone request. No forward/back rush, destination, forced physics, timer or separate controller is added. Segment clearance does not prove swept-body clearance, footing or animation displacement; physical evasion and balance remain unverified.


Clearance casualty replacement now uses the shared combat-element identity preference inside its existing rotating sixteen-reserve window. It prefers a registered buddy of the healthy receiving member, then an intact reserve pair, with distance order as fallback. Already-promoted actors are removed from the candidate window before the next slot. Failed VIEW-probe rotation remains after preference ordering so a blocked preferred actor cannot monopolise confirmation. Existing reserve/task readiness, physically established substitute exit coverage, final promotion proof, fresh entry receipts and original deadlines remain mandatory. This improves roster continuity; it does not prove coherent physical pair entry or remove whole-pair replacement gaps.


Clearance room travel, motion progress, exit retry distances and locality-resumed exit settlement now compare absolute ASL positions consistently. Native targets retain AGL and saved actor poses retain ATL; each uses its corresponding ASL conversion when measured. Relative terrain height under different points can no longer create false progress or a false vertical distance in these paths. Existing floor-aware arrival, exact command receipts, retry counters and deadlines remain. This corrects coordinate interpretation, not native building navigation or historical VR failures; physical slope/multistorey/transfer behavior remains unverified.

Coordinate detail: native building/movement targets use AGLToASL; saved getPosATL actor-motion samples use ATLToASL. Those formats coincide on land but differ over water, so the motion baseline retains its explicit terrain-relative conversion.


Clearance exit journals now retain each assigned actor's best remaining distance, server-time distance/motion clocks and absolute motion anchor through owner transfer. Egress monitoring uses the same server clock directly, avoiding a new stall-grace interval or repeated clock conversion on every journal publication. Version-four adoption validates the saved progress evidence, observes the unchanged native leg and preserves retry use and the original exit deadline. Legacy receipts lack this evidence and keep their prior observation-baseline behavior; they are not claimed to preserve missing clocks. No movement is replayed by adoption. Physical repeated transfer and exit flow remain unverified.


True clearance resume now passes its episode-bound lane pairs into the shared pair builder ahead of general buddy metadata. This closes the gap where participant priority survived a casualty replacement but a lagging general pair registry could rebuild different partners. Only intact preferred rows wholly inside the current eligible supplied roster take precedence; unavailable or out-of-scope actors gain no admission. Ordinary callers retain the default registry policy, and normal publication still retains untouched out-of-scope buddies. No movement, lane-route replay, new deadline or worker is added. Physical replacement/transfer flow remains unverified.


Partner entry recovery now retains its five-field progress/target/motion/spent-retry record on the actual actor, bound to the clearance group and visit episode. Its observation clock uses serverTime through retry, alternative-entry and follow-through decisions. A true resume or lane-slot change can consume the existing record without issuing movement or refreshing its clock. Observed spent retry remains spent; malformed matching evidence defers that lane instead of becoming a new budget. Fresh/different episodes do not adopt old observations. Publication occurs only on changed evidence under current brain/generation/epoch and local actor/group ownership. No new roster scan, timer or worker is added. This preserves the actor recovery record, not full lane cursor/mover state or an ordered replication protocol; physical repeated transfer and cost remain unverified.


Authored commander-MOVE corridor returns now retain a machine-local, read-only command observation after corridor work retires. The existing four-ticket recovery cleanup service checks the original route, operating seats, owner epoch/controller identity and original corridor deadline. Both operating actors must acknowledge the original MOVE goal; a changed intent retires as lost, and expiry remains unresolved rather than granting another command. This observation neither delays native handback with an artificial rest phase nor owns/restores a speed cap. No command is replayed on cleanup or locality transfer. Follower-only formation return and native-route corridor return keep their existing paths; physical route travel and separate-commander planning remain unverified.


Finite flight and casualty-point cleanup preserve the saved native subformation rather than always recalling an actor to the squad leader. A different current formation assignment revokes the old recall; a dead or departed saved anchor may fall back to the current group leader under the existing exact native-leg and task checks. Leader-self formation return remains valid. Casualty-point follow cleanup is additionally limited to the original server deadline plus30seconds, matching the finite indoor cleanup principle; delayed acknowledgement grants no late movement authority. No new groups, pair publication, scans, timers or native-order bypass are added. Command acknowledgement and physical reunion remain unverified.


Individual indoor investigation now retains its original native formation leader as the tenth field of its public order. Locality cleanup uses that typed episode receipt rather than reconstructing a target from a missing local brain. Selection and exact cleanup yield to a changed formation assignment; a valid saved subformation receives the existing return request. Group-leader authored MOVE resumes only for its original self-led formation. Dead/departed/ineffective saved anchors may use the existing group-leader fallback. The order carries one extra object reference; existing target/issued and disjoint-operation updates retain it unchanged. This does not implement ordered snapshot delivery, native return acknowledgement or physical reunion.


Combat gunner replacement now accepts the same finite known-hostile danger generation after detection, hit, explosion, suppression or gunfire. An immobilised but useful armed platform no longer fails admission solely because it cannot move. Existing unsafe-emplacement/disabled-hit abandonment takes priority in the caller; the driver is never reassigned, occupied or assigned incoming gunner seats remain protected, and queued ACE care explicitly vetoes the commander request before either assignment or native seat action. Speed, task, player/Zeus/provider, assignment and once-per-generation limits remain unchanged. This is a seat-change request, not proof of successful gunner recovery or resumed fire.


Building-clearance speed acquisition now follows live STEALTH intent through its existing canonical settings adapter: requested movement pace is capped at1m/s, including an unrestricted request, while lower mission-owned caps remain lower. Normal non-stealth approach/room pressure and arrival pacing remain unchanged. CHECK/ADOPT/PREPARE do not apply a new speed; owner transfer, original baseline and exact finite restoration stay with ActorSettings. This unifies clearance pacing with existing danger-attack pacing without a second speed writer, behaviour/combat-mode change, timer or settings surface. Physical stealth approach/entry/exit and pacing balance remain unverified.


The shared driving path validator stops further support or body rays as soon as the proposal is rejected. A known longitudinal-slope rejection issues no body rays; an obstruction stops remaining height and edge samples. Clear proposals still receive the complete existing support, slope and body checks, and the returned ray count records only issued casts. This applies to existing bypass, corridor, passing and convoy callers without changing routes, permissions or retry budgets. It reduces discarded query work; no measured frame-time or safety-coverage improvement is claimed.


Successful natural clearance route continuation now uses the native formation relationships already retained in its episode admission record. After the unchanged plain-MOVE leader request, followers rejoin only an admitted same-group anchor whose continuation was already requested. Up to16 bounded passes resolve at most16 follower identities; each eligible actor receives its existing native-authority check at most once. Missing, cyclic, unavailable or refused branches remain in the exact exterior hold receipt rather than being flattened to the squad leader. Explicit completed-clear holding and newer-order handback remain separate. No new groups, pair registry, timer, network schema or movement controller is introduced. Requests are not acknowledgement or physical reunion evidence.

Tactical-reposition and withdrawal straggler retries leave native STOP orders intact. Those route-following callers do not hold an individual stop receipt and therefore cannot treat a stopped actor as a stalled participant. Clearance and drill recovery retain their separate proof-based handling of their own holds. This changes candidate selection only; the shared finite retry budget and operation lifetime are unchanged.

Quiet danger rejoin prefers the idle follower's usable native formation anchor. A null, departed, ineffective or self anchor falls back to the squad leader. Existing distant-contact, personal-pressure, suppression, actor and anchor eligibility checks still govern the single native follow request. This creates no flight lease or pair registry and does not prove acknowledged or physical reunion.

Clearance owner resume now adopts a coherent episode-scoped lane snapshot: exact node positions, original entrance order/goal and pair roster, claimed lane routes, pending-room partition, cursor, mover, progress and retry state. Local progress/stagger clocks travel as server time and rebase without a fresh age. The existing callback samples at most once per 1.5 seconds, with at most eight two-person lanes and 512 nodes; unchanged samples are not published. Adoption issues no native command, grants no physical entry and changes no deadline. Missing, malformed or mismatched entry/sweep snapshots refuse worker startup rather than rebuild a fresh lane allocation; independently restored egress uses its existing journal. Delivery freshness/order and network/frame cost remain unverified while audits are paused.

The lane snapshot also retains each matched lane actor's original native request target/time observation. Adoption preserves its server timestamp rather than granting another acknowledgement grace. This restores no owned-movement target or reservation; actual native command proof remains separate. Missing or stale snapshots can still omit more recent requests, and no exactly-once handover is claimed.

Lane-snapshot sampling consumes its 1.5-second cadence after current operation authority is confirmed, even when the subsequent data validation refuses. A throttled SAVE retains the previous result rather than reporting a failed sample as successful. This bounds repeated bad-data validation on the existing callback; it does not establish a measured frame or network budget.

Clearance's existing bounded native-planning allowance includes INITFAILED (planner data not ready) and DELAY (native repeat search), alongside its existing planning states. Both partner recovery/alternative-entry waiting and room-mover retry timing still require the exact owned MOVE. Existing 30-second allowances, original request/progress clocks, attempt counts and hard deadline are unchanged; an ended or replaced order receives no planner extension. These states do not prove a navigable room or successful travel.

Individual indoor admission, observation-candidate selection, approach retries and escalation also yield to native INITFAILED and DELAY states. These represent data preparation or repeat search, not proven inactivity or an inaccessible room. Existing actor/native-command ownership, original operation deadlines and issued-attempt limits remain in force; no new grace, worker or query is introduced. Exterior watch installation remains limited to its existing idle/stopped actors.

Native INITFAILED and DELAY states also retain planner ownership in the danger FSM's route classification, cover admission/final issue, quiet-flight/rejoin, group-hide selection and ordinary stance eligibility. A stationary actor waiting for path data is not idle permission for a new cover leg or imposed posture. These extend existing planner exclusions only; physical-threat handling, native commands, feature gates and all finite response/cleanup budgets remain otherwise unchanged.

The remaining native-planner admission checks also preserve INITFAILED/DELAY during fire-control and anti-armour selection, small-element assault, fallback reposition, illumination and naval foot-egress admission. The urgent close-armour withdrawal precedes the unchanged fallback guard. Existing native GET IN cooperation treats data preparation/delayed search as pending only within its original 60-second seat deadline; motion timestamps and expiry are not reset, and the observer issues no boarding command. BUSY or WAIT without motion still do not extend a stalled boarding observation.

A mixed boat group's landed foot cohort remains eligible for subsequent actor-only assault/advance children during its original 45-second naval handover window. A new child requires no active common operation or drill, a still-current boat plan/native route/owner epoch, live feature permission and an expired existing type cooldown. Both unavailable types skip tactical assessment. Starting a child does not refresh the cohort deadline; boat routes, group membership and native leader are unchanged. This is finite post-landing continuation, not a sustained independent ground command or proof of physical landing/combat success.

Grenade task cooperation: smoke and fragmentation admission, queued aiming and the final native release check the selected weapon loading phases. Active round or magazine reload cancels the opportunistic throw rather than replacing that engine task. A settled empty/removed magazine is permitted; incomplete or malformed native state is refused. No reload, weapon selection, additional callback or renewed aiming window is introduced. The existing smoke cooldown and frag cancellation/assault continuation remain in force. Physical reload/throw transitions and modded weapon behaviour remain unverified while audits are paused.

Danger-cover arrival and native-destination continuation compare absolute height, retaining the existing horizontal and 1.5-metre floor bounds. Terrain-relative height alone cannot establish arrival across terrain cells. Cleanup retires an actor movement marker only when its stored point exactly matches the committed CBE point and its existing type/deadline match; a nearby or different-floor marker is preserved. This adds no route, deadline, world scan or worker. A screened indoor point still does not prove access, room safety or physical arrival; uneven-terrain, native-order replacement and building-refuge cases await live validation.


### Occupied-platform ownership during cleanup

The shared external-owner check includes the actor's current occupied platform. A vehicle-only external-control declaration therefore blocks crew posture restoration and group command/cleanup paths that use this check, even when the crew themselves have no declaration. Group-wide calls inspect each distinct occupied platform once per call; actor-scoped calls inspect only that actor's parent while retaining group-wide player and curator authority. A merely assigned vehicle does not affect an actor on foot. No provider marker is cleared or borrowed as CBE ownership. Existing exact-release paths retain their own retirement rules; this boundary does not cancel previously issued native movement, prove provider shutdown or implement a controlled rappelling executor. Physical transition and performance validation remain pending while audits are paused.


The shared external-owner predicate uses one fresh pass for group-wide player/remote-control checks and one scoped pass for garrison, suppression, specialist and occupied-platform claims. Distinct platforms are still deduplicated within the call. This replaces six separate member-list traversals on the normal path without retaining an ownership result between calls or weakening a command-boundary check. Actual frame-time impact remains unmeasured.

Danger smoke screens use half the retained contact distance, capped at18m. A close contact therefore does not put the planned smoke target beyond the threat. Before release, the existing queued throw cancels if the retained contact moves inside the planned target distance or its bearing changes beyond the existing limit. This controls the requested aim point, not the grenade landing point, wind drift or effective concealment; those still need physical validation. No extra observer, worker or scan is added.

A cancelled queued danger-smoke throw releases its own unchanged carrier/generation reservation and reduces its unchanged45-second queue cooldown to the existing3-second retry backoff. A newer throw generation, group operation/owner epoch, carrier, reservation or edited cooldown is preserved. Successful release keeps its normal cooldown. Cancellation is not counted as an observed grenade release.

Selected-platform armour standoff can admit a mixed group with dismounted infantry. Admission and commit both require no existing CBE operation, so routine standoff does not replace infantry work. Its original driver/effective-commander pair alone receives native movement; the first selected crew participant anchors the operation progress/posture classification instead of an unrelated foot leader. Group membership and group waypoints remain unchanged. Native formation followers may still respond to their own leader under engine rules; this does not establish independent same-group concurrent CBE operations. Physical mixed-group behaviour remains unverified.

A mixed-group standoff preserves unchanged infantry danger-posture cleanup receipts across its internal operation-generation change. It carries the original baseline, danger generation and expiry; it does not reapply posture or manufacture a fresh response. Changed owner/epoch/native posture proofs are not adopted.

Queue reverse preflight requires the complete explicitly agreed rear envelope, including the minimum6m travel/8m clearance request. It cannot approve that request through ordinary recovery's2m fallback. VERIFY/COMMIT also compare the returned envelope to the original requirement. Ordinary unbound recovery keeps its existing short fallback; native execution still requires fresh clearance and current authority. This closes an admission mismatch, not physical queue or reverse acceptance.

Clearance lane-journal sampling is throttled within the same ENTRY/SWEEP phase. A phase change bypasses the existing1.5-second sampling interval so the producer attempts the new-phase snapshot before publishing the operation phase. Refused samples remain bounded within that phase and do not count as current snapshot proof. This does not add ordered cross-owner checkpoint transport or actor-ready acknowledgement.

Same-group point-defence allocation counts coverage only from unfinished responses with a living local platform, its original living local gunner, the current owner epoch and exact original fire lease. Finished responses and replaced crew/leases do not discourage another available responder from covering that warning. This is reservation coverage, not evidence of firing or interception. Existing urgency, own-victim preference, default-off policy and per-platform warning budgets remain unchanged.

Point-defence allocation samples valid existing response reservations once across its bounded platform list per callback, then counts matching missiles during ranking. This replaces repeated crew/lease validation for each warning with one ephemeral sample; it adds no persistent cache and grants no fire authority. START still performs its own current admission. Reduced metadata reads are structural evidence, not a measured frame-time result.

Loaded explosive fire adds one first-surface FIRE/GEOM observation to the shared firing-lane check. The existing bounded corridor query checks protected people/vehicles against blast exclusion at both the intended target and that possible near impact. A person beside a nearer wall can therefore veto the shot even outside its narrow firing cone. Ordinary nonexplosive fire adds no ray. This is a straight-line conservative veto, not a ballistic/penetration/impact prediction or permission to destroy a building.

The shared actor fire-task gate refuses active native SUPPRESS commands. Native suppression is an engine-managed burst, so a CBE lease/cooldown ending is not evidence that its firing has stopped. Scripted gunnery, combined ground support, convoy targeting and callers reusing that gate defer replacement admission until the native command changes. This adds no forced cancellation, burst timer, worker or synthetic handover receipt. Native burst duration and actual handback still need in-game verification.

Selected armour standoff requires physical rest within5m horizontally of its selected destination, retaining the existing vertical tolerance. It no longer inherits the shared artillery25m arrival area. The shared native phase defaults to25m for existing artillery producers; an explicit invalid1..25m radius requests normal retirement rather than declaring arrival or abandoning native cleanup. Movement, stall and original handback deadlines are unchanged. Physical route accuracy remains unverified.

Armour can make one short post-shot reposition from an exposed idle position toward a screened destination. Only a real matching main-turret cannon Fired event qualifies: exact original AI gunner, weapon/muzzle/ammunition, projectile parents, owner epoch, native route and task generation. Fire requests, missiles, AA and artillery do not qualify. An authored movement order, active CBE operation, combined role, convoy or external controller refuses this path. Driver/commander must be idle; ordinary native FIRE admission limits still apply to two-seat vehicles.

The observer has one original20-second episode and cannot renew. The next eligible contact callback consumes its shot proof once, requires a current report within3 seconds, retains immediate AT-escape priority and considers one bounded25m escape avenue. It moves only when the current top-height point is exposed and the candidate point screened; a group20-second attempt cooldown prevents repeated sampling. Selected native movement keeps the observer's original deadline and5m rested arrival. Arrival and HOLD recheck screening plus original gunner/target belief context; changed orders, lost context or lost screening request normal retirement. No group split, group waypoint, forced shots, ammunition, physics changes or damage shortcuts. Screening is point-based, not whole-hull protection. Actual firing, travel, repeated use, balance, owner migration and performance remain unverified while audits are paused.

Post-shot armour destination selection requires the final candidate endpoint to pass the shared avenue selector's three existing upper-envelope material-screening observations before scoring. An exposed route cannot win merely on road/terrain preference and then suppress another screened candidate. Missing or oversized platform bounds refuse this mandatory mode. Ordinary route callers retain optional cover scoring. The candidate and ray limits do not increase; these sparse observations still do not establish a native path or whole-hull protection.

Native danger evasions now share a short lateral-space check for prone rolls and upright tactical steps. Two body-height side segments must be unobstructed; two downward midpoint/endpoint probes must find terrain or a walkable model surface within0.75m vertically and with an upward normal of at least0.7. Actors and vehicles cannot supply footing. The original three-second cooldown bounds refused attempts too; no alternative direction, movement destination, worker or physics change is issued. These are sparse safety vetoes, not proof of full-body clearance or reliable native animation displacement. Physical rooftop, stair, bridge and modded-building behaviour remains unverified while audits are paused.

Traffic following projects both the observing and other vehicle hulls into one level world-metre frame before lane, vertical-overlap, bumper-gap and crossing-window comparisons. This removes the previous mixture of tilted/model-scaled extents with horizontal world velocities and braking distances. Each other hull uses four model-to-world transforms instead of four transform pairs; the observing hull is projected once per callback. Discovery, dense refusal,64 prediction limit, reaction/braking coefficients, convoy delegation and speed-authority gates are unchanged. No world query or clearance permission is added. Pitch/roll/scale projection is mathematical evidence; native travel, supported scaling and runtime performance remain unverified.

Exterior clearance guards now use the shared native-motion journal through their exact current reserve-post receipt, even though they intentionally remain outside the interior assault roster. MOVE metadata must match that assigned post; HOLD metadata stays within2m and0.75m vertically. Actual native command/endpoint/rest, current operation/visit/route, eligibility and live-producer checks still apply. This allows an issued guard move to retain settled WAIT/arrival proof instead of being rejected solely for its exterior role. No actor is added to the assault roster, no movement is issued by the journal, and arbitrary group members remain excluded. Coherent producer checkpoint delivery and complete exterior adoption/readiness remain unfinished; physical isolation and migration are unverified.

Exterior APPROACH also records a delayed actual native MOVE acknowledgement through that same journal when its exact target has become current. The existing callback attempts this only until the current group/visit/target receipt exists. It does not call the issue helper, replay movement or renew request/progress/search/deadline clocks; settled WAIT still requires the recorded native proof.

A clearance resume now requires its original building/transform/hard-deadline/nonce visit context before room geometry preparation or operation admission. Missing, malformed or different context defers through existing discovery; it cannot mint a fresh visit and thereby orphan spent recovery history. Expired original orders still retire. Preparation commits compare that captured context, and only an explicit fresh clearance creates a nonce. This adds no worker, replay or deadline extension. It does not supply coherent checkpoint delivery, source authentication or complete actor-ready handover.

During exterior-stage resume, a validated unchanged phase journal may provide a temporary private post proposal solely for the shared read-only motion CHECK. It must still match the original actor/group/visit MOVE receipt and actual native MOVE or settled WAIT, including endpoint/rest/floor checks. The proposal is removed immediately after each check and cannot publish, ADOPT, set a reserve marker or issue movement. Existing preparation establishes the current local marker only after its separate live native/authority recheck. This resolves the dependency where the new marker was required to validate the old settled leg. Phase-journal inputs remain bounded to64 rows; full coherent producer delivery/readiness is still unfinished and physical migration remains unverified.

Resumed exterior stage/movement bookkeeping is retained only after that final live check actually commits the current local reserve marker. A refused preparation or changed native order leaves the proposed post unoccupied in the new job; historical casualty posts remain separate evidence.

The experimental same-owner AA direct-pass fuse now checks collateral risk from the incoming missile's warhead, not just the fired bullet. After actual pass/arming proof, damaging/explosive warheads use the existing conservative blast policy of at least12m or four times indirectHitRange; unsupported radii above250m refuse. One current-position sphere includes living infantry, land vehicles, aircraft, ships and occupants, refusing friendlies, civilians, captives or more than64 results. A veto is reused only within the current engine time sample; clear results never persist. The effect is restricted to its unscheduled current-owner callback so geometry cannot be carried across scheduled suspension. Native firing remains unchanged. This adds a rare one-query effect veto, not cross-owner interception, complete hull/obstruction blast modelling or physical/performance acceptance.


### Incoming-missile launch identity

Native AA `IncomingMissile` observation now records the exact projectile and native
launcher/parent pair, launch affiliation, recording machine and original 15-second
expiry. A duplicate warning cannot refresh or replace that receipt. The warning
and allocation payload layouts remain unchanged. Allocation and finite interception
use that captured affiliation with the defending group's current side relationships;
launcher crew loss or deletion alone no longer converts a hostile missile into an
ended threat. A new non-null projectile parent invalidates the receipt. Missing or
expired capture refuses admission, including after migration until a new qualifying
native warning is observed. Nothing is broadcast or replayed for JIP.

The existing eight-second group response lifetime, epoch, defended-asset link,
retargeting, fire lease, ROE, mission-order and external-owner checks remain in force.
This is neither target discovery nor permission to fire. The optional default-off
scripted direct-pass fuse still refuses a missing launcher and requires its current
native parent match, actual local rounds, geometry and collateral checks. It does
not infer successful interception from a receipt or effect request.

Cost is one private receipt per observed projectile and one two-parent comparison
per validation, with no world query, new timer or worker. The existing allocation
bounds remain unchanged. Offline regression/compilation must be checked for this
candidate; crew-loss/deletion, parent replacement, locality changes and physical
interception remain unverified while audits are paused. No performance-budget
acceptance follows from these bounds.


### Selected-crew interruption by a newer native STOP

Artillery positioning/scooting and selected-platform tactical movement can retire
an unresolved reservation after positive evidence of a newer native STOP. The exact
original machine-local FSM must have completed; its serial, executor serial, owner,
epoch, group reference and any tactical operation generation must still match.
Every surviving original operator must remain local, in the original group and
report native STOP. Operators may remain aboard the original platform or be on foot;
another occupied vehicle refuses. Dismounted originals must each have finite measured
speed below 1km/h, independently of the platform. Dismounting alone is not handback.
STOP is a perpetual task; readiness is not required. No replacement operating actor
is adopted.
The actual platform must be below 1km/h and 0.01rad/s. An empty surviving crew is not
STOP evidence; the existing separate dead-crew path retains its own checks.

This passive path issues no stop, return or other native command. It releases only
the original journal/reference and matching public/local lease. A newer public lease
is protected even if it uses the same owner label with a different deadline. Artillery
clears only its exact matching scoot token/session. Tactical interruption reports
INCOMPLETE, even if the old position had previously been reached; STOP is not a
successful handback or completion of the requested manoeuvre. Group membership and
unrelated infantry orders remain untouched.

Existing maintenance performs at most two original-operator command checks and
one platform velocity/angular-velocity sample for this proof, plus at most two
individual velocity samples when the surviving originals are on foot. There is no new worker, scan
or timer. Cross-owner termination, different native orders, missing actors and
replacement crews remain unresolved unless separate positive proof is available.
Offline checks cannot establish native STOP acknowledgement timing or the total performance
budget; these require a future authorised physical pass.

The [native STOP command](https://community.bistudio.com/wiki/commandStop) never
finishes. Requiring `unitReady` here would keep the reservation indefinitely; active
STOP, measured rest and exact ended-worker evidence serve distinct purposes.


### CQB exterior observation history across handover

An arrived exterior guard's first obstructed-eye-ray timestamp now travels with its
exact post and watch coordinates in the existing finite stage journal. Resume
validates those coordinates, finite timestamps, original episode/transform/deadline
and the actor's current native role before retaining the history. Invalid supplied
history cannot admit a live post. This restores timing only: the next callback still
requires its own actual eye ray before installing watch or deciding an obstruction
persists. Migration cannot manufacture a fresh obstruction grace period.

A successfully committed different post clears the previous post's obstruction
history. This preserves the short transient-occlusion grace for the new location
without adding a staging attempt, renewing the search budget or extending the task
lifetime. An invalid or merely proposed location cannot perform that reset.

Blockage start/clear and existing stage transitions publish the journal. Periodic
unchanged rays do not add broadcasts; at most 64 existing rows carry one extra
bounded receipt. The existing one-ray-per-callback and two-second local recheck
limits remain unchanged. A transfer may recheck earlier than the last local due time
if it was not part of a published transition, but cannot reset the original blocked
start time. Physical isolation, native movement and measured overhead remain pending
an authorised game pass; this is not proof of complete perimeter coverage.


### Convoy native endpoint observed as settled WAIT

A short native convoy MOVE can finish before the next owner callback. Its exact
recorded endpoint may then report WAIT. The native request acknowledgement and
short-leg continuation now retain this case only when the original movement
operator is ready, both original crew/destination receipts still match, and the
actual vehicle rests within 3m horizontally and 1.5m vertically of the issued point.
Rest retains the existing finite total-linear-speed and angular-speed limits.
Unchanged native endpoint geometry is checked before extra motion sampling.

This permits the existing continuation after more than 3m of fresh ordered trail,
including advances below the moving-leg refresh threshold of 8m. It does not request
a new path on every callback. Native STOP still yields the convoy revision; altered
crew goals, other native tasks, moving vehicles and a different floor cannot use
this settled acknowledgement. Identical replacement native orders remain
observationally indistinguishable.

The same rest helper serves acknowledgement and continuation. No worker, world
scan, timer, speed-policy change or acknowledgement-deadline renewal is added.
Pending exact WAIT acknowledgement may add one measured velocity/angular-velocity
sample after the cheap endpoint/proximity tests pass. The existing audit fixture
can observe WAIT at a recorded endpoint but still requires subsequent physical
travel. Audits remain paused; native ready/WAIT timing, mixed-convoy flow and the
5% median / 10% p95 performance budget are not established by offline checks.


### Infantry illumination candidate priority

Opt-in autonomous illumination now tries available nonleaders before the leader
within the same first-16-actor roster. If only the leader has an eligible loaded or
carried flare, that actor can use the existing finite native illumination action.
No candidate is removed to make room: a leader outside the original prefix is not
appended. A player, remote-controlled, busy or otherwise ineligible leader still
refuses through the same actor and weapon checks.

The feature remains off by default. Native idle command, no assigned/attack target,
readiness, settled planner/reload state, ROE, visibility, suppression, actor reservation
and group-operation checks remain in force. This does not admit native STOP or WAIT,
or interrupt a commander who is already moving or engaging. Flare load/selection,
aim, actual FiredMan observation and weapon handback retain the original deadlines
and receipts. No movement, seating, group-leadership or inventory shortcut is added.

Reordering at most 16 existing entries replaces repeated leader reads with one
selection-time read. There is no new worker, timer or world query. Static candidate
selection does not prove actual upward aim, release, illumination effect, weapon
restoration or the frame-time budget; those remain pending a physical pass.


### Selected-platform deletion after original crew cleanup

The existing local platform-deletion handler now retains the two original crew
references in its private installation record. Both objects must exist when that
record is first captured. During the genuine platform-deletion callback, the
current work journal must still match those references and the exact episode.
Each original actor must then be deleted, or remain local and dead. This permits
cleanup when corpse removal happened before gun or vehicle removal; a missing
initial crew record cannot establish that history.

Cleanup removes only the old reference and its unchanged reservation. A newer or
unknown public lease continues to protect private movement and operation state.
Tactical operations end INCOMPLETE, never as successful movement. No living crew,
replacement crew, native command, additional handler, timer or scan is introduced.
Repeated installation retains the same snapshot; locality loss removes the local
handler. A new owner with already-missing actors cannot reconstruct this private
proof and still refuses cleanup. Actual deletion ordering, migration and repeated
use remain physically unverified while audits are paused.


### Exterior clearance approach continuity

On owner resume, an exterior guard's completed approach may appear as native idle
or WAIT. Both states now use the existing read-only motion check during observation
and immediately before committing the local post marker. The original episode
receipt, unchanged endpoint, actual rest, target proximity and floor band are still
required. STOP remains a distinct hold; an absent motion receipt does not qualify.
No new destination, settings application, post search, visit credit or deadline is
created by this admission. Coherent producer checkpoint delivery and full exterior
readiness remain unfinished; this change does not certify cross-owner continuity.


### Current producer lane export

`BuildingLaneJournal` supports an internal `EXPORT` mode for the current local
ENTRY/SWEEP producer. It returns the same validated 13-field lane format used by
SAVE directly from the job, independently of the public lane journal and its
1.5-second publication throttle. The exact current CLEAR operation and live private
building brain/job, epoch, generation, visit identity, transform and original hard
deadline must still match. Refusal returns an empty array. Other phases are not lane
exports.

EXPORT changes no job field, publication budget, native order or deadline. Nested
transform vectors, routes, progress rows, request targets and buddy proposals are
copied so the result cannot mutate the producer through those arrays. Original local
progress/start clocks are encoded as server times using the existing SAVE conversion.
SAVE keeps its existing throttle and shares the same serialization path.

This is a snapshot component, not enabled ownership transport. It refuses after
locality loss and does not capture all egress, exterior, settings or interruption
state. Producer registration, a final fenced seal, authenticated replay and actual
incoming-actor reconciliation remain required. No new periodic export, network
message, worker or readiness flag is added. Physical handover and runtime overhead
remain unverified while audits are paused.


### Private outgoing lane capture

The existing group-locality handler fences its original building brain, then calls
read-only `BuildingLaneJournal` FROZEN before clearing that private pointer or
advancing the machine-local epoch. FROZEN requires actual loss of group locality,
the original private producer owner/job/generation, the LOCALITY_CHANGE fence and
unchanged operation/visit/transform/deadline identity. It uses the same bounded lane
serializer as SAVE and EXPORT. Refusal produces no valid capture.

A successful ENTRY/SWEEP capture remains in one machine-private record with its
original owner, generations, epoch and hard deadline. Duplicate loss callbacks do
not recreate it without an active original producer. New producer admission, gained
locality and master stop clear obsolete local captures. No public variable, network
message, replay, new worker, timer, actor command or readiness flag is introduced.

This captures the lane component only. It does not seal other actor, exterior,
egress, settings or interruption writers, and does not prove the old FSM completed.
The incoming owner cannot consume this private record yet. Authenticated producer
registration, complete phase state, final seal/replay transport and actual native
reconciliation remain required. Physical ownership ordering and performance remain
unverified while audits are paused.


### Exterior-post producer snapshot

Live changed-state publication and outgoing locality capture now use the same pure
`BuildingStageJournal` serializer. Its existing five-field journal retains each
actor's spent search count, attempted post/entry positions, stage and blocked-view
observation times. Nested vectors are copied independently. At most64 actor keys,
six attempted targets and three entries per key are admitted; malformed or overflow
state refuses instead of truncating away spent history. No budget is reset or
extended, and unblocked view checks still use the existing later-owner recheck path.

The outgoing private capture is now version2 with nine fields: the original eight
fields followed by this stage snapshot. It is retained only when both the lane and
stage components validate. A valid five-field stage journal with no rows means empty
exterior state; an empty array means refusal and cannot substitute for it. The
normal publication keeps its changed-state and current-owner checks. No new periodic
serialization, network delivery or native command is introduced. Full phase/actor
capture, registration, authenticated replay and actual incoming readiness remain
unfinished; physical behaviour and transfer cost remain unverified.


Outgoing clearance capture now also serializes original room progress from the fenced private job through `BuildingRoomJournal`. The machine-private capture is version3 with ten fields: the version2 lane and exterior components plus the room component. Room state carries the exact visit context and ordered positions, physically visited and unreachable indices separately, sparse retry length/indexed counts, per-room failed lane identities and original deadline/progress clocks. Missing or malformed state refuses capture rather than creating progress or refreshing budgets. This is still a partial producer checkpoint: actor visit history, egress, motion/settings and retirement domains plus authenticated transfer/replay and incoming native readiness remain required. No receiver or periodic job is introduced. See `clear-room-producer-boundary-20261026.json` for current limits and offline evidence.


The room component is now version2 with twelve fields, appending original entered actor objects and keyed physical visit lists. The outer capture is version4 and retains ten fields. Shared coverage alone never supplies individual participation: each keyed list must refer to the same original entered identity and unique physically cleared room indices. Historical actors that changed group can retain evidence; a deleted or missing original object identity refuses capture rather than silently attributing its observations to a replacement. ENTRY/SWEEP scope remains unchanged. Egress, authenticated delivery and actual incoming native readiness are not supplied by this component. See `clear-actor-visit-capture-20261026.json`.


Final-egress publication and outgoing capture now share pure `BuildingEgressJournal`, retaining the existing14-field version5 public schema. `BuildingProducerContext` binds capture to the actual source brain/job, CLEAR parent, visit identity and original phase deadline. The original finite egress deadline is distinct from the sweep hard deadline; neither is renewed. Outer private capture is version5 with twelve fields, appending phase and egress. ENTRY/SWEEP retains lanes with empty egress, while EGRESS retains its journal with empty lanes. Missing original progress records refuse serialization. This remains a partial source checkpoint, with no incoming consumer, native readiness or all-writer quiescence claim. REPLAN and other component/transport gaps remain explicit in `clear-egress-producer-capture-20261026.json`.


The existing clearance REPLAN phase now shares ENTRY/SWEEP lane serialization, read-only validation, adoption and source export. The prior phase restriction could leave an older lane journal when the executor published a retry change. REPLAN retains its exact lane routes/pending work and original hard deadline; it is not fresh planning. The version1 lane schema and version5 outer capture are unchanged. Existing bounds, changed-only writes and1.5second SAVE throttle remain. See `clear-replan-journal-phase-20261026.json`; ordered transfer/authentication, other components and native readiness remain unfinished.


Original historical entrant identity is now recorded privately at the first qualified physical entry, or valid adoption of an existing episode-bound visit receipt. Room component version3 has thirteen fields and appends aligned `[originalActor,originalNetId]` rows; outer capture version6 retains twelve fields. A later null object reference can retain its original historical visit key, while any surviving object must still match that key. No replacement receives those observations, and missing original identity still refuses. Active lane/native eligibility and full transfer delivery remain separate incomplete requirements. See `clear-original-visit-identity-20261026.json`.


`BuildingFollowJournal` now shares live budget and outgoing follow-through encoding. Its four-field component retains original eight-field legs with server-time representations of their original progress clocks, plus the unchanged five-field public failed/exhausted budget. Original exhaustion keys are recorded when spent, before deletion can erase an object reference. Private maps attach before follow-through work. Outer capture version7 has thirteen fields and appends this component; existing incoming resume does not replay the new leg records. Bounds remain64 rows and three failed room indices per actor key. Early-exit/reserve/yield, other native/settings state, authenticated transfer and actual readiness remain unfinished. See `clear-follow-producer-capture-20261026.json`.


Early-exit publication and source capture now share `BuildingEarlyExitJournal`. PUBLIC retains the existing `[visitContext,rows]` format and returns before historical observation work; CAPTURE retains original keyed rows, motion/view clocks and rotation cursor in a six-field component. Early maps attach before service. Outer capture version8 has fourteen fields and appends that component. No incoming consumer or native readiness is supplied. Existing legacy early receipt adoption still accepts truncated4/5-field rows; strict preflight/adoption alignment is a remaining requirement, as are reserve/yield/relief and full ordered transfer. See `clear-early-producer-capture-20261026.json`.


Incoming early-exit phase preflight now uses the same seven-field row validator through `BuildingEarlyExitJournal` CHECK. Truncated, unset, malformed, duplicate or identity-mismatched nonempty data defers before operation startup, preserving the durable order. Adoption consumes the receipt already admitted/rechecked at commit and no longer supplies missing retry defaults; unadoptable exit work remains marked incomplete. CHECK is data validation, not native readiness or authenticated delivery. Missing original actor identity and absent-journal ambiguity still require the full transfer contract. See `clear-early-resume-admission-20261026.json`.


One-time follow-through yield membership is now owned by the original private job and mirrored publicly. Fresh episodes publish an explicit zero-spent receipt; resume keeps its admitted original receipt, with absence treated as unknown. Actual spends update private/public membership before native movement and require the current public mirror to match. Unknown/replaced state grants no extra yield. Follow component version2 adds the receipt as field4; normal five-field budget publication is independent, while outgoing capture requires known membership. Outer capture version9 retains fourteen fields. Attempt recording proves no physical movement or coverage. Reserve/relief and full authenticated transfer remain unfinished; see `clear-yield-attempt-ledger-20261026.json`.


Casualty-relief attempt history is now private to its original job and mirrored publicly. `BuildingReliefJournal` validates/copies at most8 original attempts at preparation, preflight, new-attempt admission and outgoing capture; ordinary callbacks reuse the canonical private receipt. Fresh tasks publish explicit zero-attempt state, while absent resume state is unknown. Unchanged private/public state and all existing native/observer/casualty/deadline checks are required before spending and issuing. Attempt commit remains before exterior planning. Outer capture version10/fifteen fields appends the typed receipt. Typed historical data is not current native or casualty proof, and no incoming sealed replay exists yet. Reserve/native/settings/retirement and full delivery remain incomplete. See `clear-relief-attempt-ledger-20261026.json`.

### Native-path grade and convoy pacing

With convoy driving assistance enabled, the lead and followers now consume the same fresh native-path grade policy. Absolute grade above 12% lowers the requested ceiling to 25 km/h; above 20% lowers it to 18 km/h. Existing road, spacing, traffic, corridor and infantry limits can reduce speed further. Missing native path evidence retains those existing policies. The lead previously ignored the native grade value while followers used it, which could stretch an off-road column.

This uses the existing owner-local, both-seat-bound, six-metre path observation. It adds fixed comparisons and an optional diagnostic cap entry, with no new query, worker, timer or setting. Existing convoy driving-assist gates and final native-command authority checks remain. Grade evidence grants no clearance or arrival credit. Mixed tracked/wheeled slope flow, braking and measured runtime cost still need physical validation; audits remain paused.

### Dense traffic admission

The existing unscheduled observer can project up to 256 vehicle hulls before admitting at most 64 motion predictions. It now excludes finite hulls on another height level and non-occupying parallel courses below the existing crossing cutoff from that prediction budget. Those cases cannot constrain either current braking branch. Occupied-lane hulls, intersecting courses and unknown data remain candidates. The 256 discovery and 64 retained-prediction refusals stay in place; scheduled direct callers retain the original 64-candidate refusal.

This avoids a density-only stop caused by a separate overpass stream or an adjacent parallel stream. It adds bounded arithmetic before prediction admission, with no extra discovery query, ray, worker or timer. The current model still does not predict later steering or future height changes. Physical dense-scene flow and the median/p95 runtime budget remain unverified; audits remain paused.

### Pedestrian braking geometry

Friendly-pedestrian braking now projects the observing vehicle and each pedestrian into the same horizontal world-metre frame, with absolute vertical separation. The travel axis reverses for an owned rear leg. Existing reaction/deceleration policy and the three-metre stopping margin consume actual metre gaps, including pitched or scaled transforms. The existing lateral and vertical margins remain, with the shared helper's outward 0.05 m boundary padding.

The shared hull helper can return three axis intervals from its existing four transforms; older one- and two-axis calls keep their output shape. Pedestrian observation replaces eight forward/inverse transform pairs per person with four world transforms and one observing-hull projection. It retains the single capped discovery query, 32-person refusal, friendly/on-foot filter and existing feature gates. Invalid geometry returns a zero cap. No native movement authority changes. Physical slope/overpass/reverse braking, supported object scaling and runtime cost remain unverified; audits remain paused.

### Reverse clearance in metres

Reverse observation keeps the vehicle's body orientation and now expresses hull extents, requested rear distance, support/solid probes and velocity prediction in the same metre frame. Object scale no longer multiplies an already metre-based rear request or mixes model-unit gaps with metre-per-second motion. The shared hull projection replaces inverse model-coordinate actor transforms; a unit world basis places the existing probes.

The two-second overlap checks, turning veto, dry/static support checks, 64-actor limit, discovery bounds and ray counts remain. Unknown actor geometry or velocity refuses clearance. Changed ownership, or a changed pose during a scheduled direct observation, also refuses a clear result without returning its target. Normal unscheduled callbacks skip the extra pose sample. These unavailable/context failures do not enter the existing shorter-plan fallback. No new query type, ray, timer, movement or physics command is added. Physical slopes, turns, supported scaling, normal/HC repeatability and measured runtime cost remain unverified; audits stay paused.

### Native attack pace acknowledgement

A finite native ATTACK pace response now continues only while its exact canonical speed-only settings lease remains present and the actual native forced speed matches the recorded applied value. Missing, replaced, pending-restoration, malformed or changed settings refuse continuation through the existing FSM finish/cleanup path. Response metadata alone cannot confirm an applied speed cap.

The condition reads one speed property and bounded lease fields. It performs no squad/configuration scan, settings write, timer renewal or movement command. Existing original restoration windows and protection of newer mission values remain. Full imported-state readiness and broader foreign-owner retirement remain separate unfinished work. Native timing, repeated response/cleanup, owner migration and runtime cost still need physical validation; audits remain paused.

After the original restoration window closes, exact old speed-only bookkeeping can retire when the actual native speed has demonstrably changed. This path removes only the matching settings and pace records in the current owner transaction; it issues no native command. Missing, foreign, malformed or still-applied settings remain unresolved. The restoration window does not renew, and a later task cannot inherit an unconfirmed successful restore.


### Clearance settings before handoff

Clearance resume now inspects inherited actor settings before replacing the operation. A partial property map, changed native stance/speed, pending restoration or inconsistent clearance mirrors defers startup and leaves the durable order available for the existing discovery retry. Motion records that carried a settings triple require the same original baseline/applied values. A speed-only receipt cannot acknowledge a successor that requires both stance and speed.

The read-only ActorSettings INSPECT mode checks the original issuer, generation and deadline under current actor/group ownership. It returns ADOPTABLE only for the requested properties whose recorded values still match native settings. It neither applies settings nor acknowledges a successor operation. The clearance adapter also checks its original mirrors. Up to eight interior actors are inspected once during preparation and again in the final handoff transaction, where their canonical, mirror and motion snapshots must remain unchanged. The original deadlines do not renew; no worker, query or movement command is added.

Actual adoption still runs through the existing operation and actor authority checks. Missing state remains distinct from a coherent original-producer delivery receipt. This change prevents known settings failures from consuming an order; it does not complete authenticated transfer, motion readiness, all-writer retirement or exterior readiness. Physical migration, repeated flow and the added bounded startup cost remain unverified while audits are paused.


### Clearance settings before handoff

Clearance resume now inspects inherited actor settings before replacing the operation. A partial property map, changed native stance/speed, pending restoration or inconsistent clearance mirrors defers startup and leaves the durable order available for the existing discovery retry. Motion records that carried a settings triple require the same original baseline/applied values. A speed-only receipt cannot acknowledge a successor that requires both stance and speed.

The read-only ActorSettings INSPECT mode checks the original issuer, generation and deadline under current actor/group ownership. It returns ADOPTABLE only for the requested properties whose recorded values still match native settings. It neither applies settings nor acknowledges a successor operation. The clearance adapter also checks its original mirrors. Up to eight interior actors are inspected once during preparation and again in the final handoff transaction, where their canonical, mirror and motion snapshots must remain unchanged. The original deadlines do not renew; no worker, query or movement command is added.

BuildingActorMotion OBSERVE shares the existing native MOVE, settled WAIT and HOLD checks before startup. It accepts only the bounded proposed interior roster under current owner, visit, route and original deadlines. This result grants no operation or movement authority. Actual CHECK/ADOPT retains the live common-operation checks. A changed destination can therefore defer the attempt before cleanup consumes the order.

Actual adoption still runs through the existing operation and actor authority checks. Missing state remains distinct from a coherent original-producer delivery receipt. This change prevents known settings and motion failures from consuming an order; it does not complete authenticated transfer, all-writer retirement or exterior readiness. Physical migration, repeated flow and the added bounded startup cost remain unverified while audits are paused.


### Forward geometry and curvature in metres

Forward gate and solid-obstacle probes now express body extents, straight/curved travel stations, contact offsets and support-height comparisons in world metres. A unit body basis retains the vehicle's pitch and roll. Object scale affects its real hull dimensions once, without multiplying the requested travel horizon or inverse-metre curvature. Native-path and travelled-position hints use the same unit convention; the travelled hint's local identity distinguishes the new metre receipt.

The existing shared hull helper supplies all three body spans with its four model transforms and outward 0.05 m padding. One origin transform plus basis arithmetic replaces native forward/inverse transforms at individual probe points. Ray counts, hit bounds, curvature limits, gate classification, support ambiguity checks and the original braking model remain. Unavailable pose, hull or motion supplies a zero solid constraint, without inventing a gate or a bypass target. Existing owner-local writers retain command authority.

No worker, query, ray, setting or timer is added. Actual probe accuracy, slopes, tight corners, supported scaling, braking and measured runtime cost remain unverified while audits are paused. Ordinary autonomous reversing still needs a coherent rear-traffic/intent treatment; this forward-unit correction does not provide it.


### Ordinary native backing observations

Ordinary driving assistance now faces vehicle, solid and pedestrian observations along measured backing instead of continuing to constrain the front bumper. The existing traffic and solid observers accept an explicit forward/reverse direction; their default remains forward for other callers. Rear observation uses the actual rear hull and existing two-metre rear end buffer rather than the forward six-metre stand-off, yields to crossing traffic from both sides and cannot delegate convoy predecessor or forward queue spacing. Forward path curvature/support hints are not reused for rear geometry. The existing cautious 10 km/h ceiling applies and the current scheduler requests its one-second constrained cadence while backing.

A private observation binds the owner, driving brain, route, driver, commander and both native travel destinations/form leaders. MOVE, settled WAIT and idle planning labels share a travel observation key; they do not grant command authority. The rear observation survives a cap-induced stop under unchanged task/cap ownership. Forward movement above 0.15 m/s, explicit forward mode, changed task/context or a newly observed usable forward path replaces it. Actual command admission retains its full native-task checks. Scheduled direct callers recheck the observation key before writing the cap. Unknown motion gives zero constraints and does not overwrite known direction. Successful exact cap retirement removes the private observation.

This adds no reverse destination, steering command, worker, timer or CBA setting, and no additional query or ray per observation. Requesting the existing one-second cadence can increase aggregate work during backing; its runtime cost is unmeasured. New forward pass/corridor/bypass/backoff admission is suppressed during ordinary backing. Dedicated CBE reverse/queue/path operations retain their existing executors. Rear gates constrain movement, but automatic opening remains forward-validated; no rear gate request is sent. An unchanged MOVE label cannot prove gear intent, and a path hint is not native drive acknowledgement. Physical start/stop/reversal, ambiguous native planning, rear gates and measured scheduler/runtime cost remain unverified while audits are paused.


Short current native paths can establish forward direction without supplying curvature. A qualified 0.5 to less than 3 m forward leg returns a separate five-field direction-only result; bend consumers retain their existing fallback unless the normal four-field hint is present. A stopped rear observation retains its original path timestamp until current forward evidence can replace it, rather than consuming a new but temporarily unusable path. Native subscription age, floor, owner, route, crew and destination checks remain. No path-age renewal, movement or clearance permission is added.

### Rear gate opening under ordinary native movement

The owner sends the observed direction through the existing finite gate request. A reverse request is ordinary-driving only: the crew owner rechecks its private direction observation against the current brain epoch/generation, route, seats, native task frame and acknowledged speed cap. Actual forward motion/mode, a changed task or a newer path while held refuses the request. The server authenticates its existing single-use owner witness and observes the rear hull with the same direction before opening recognised unlocked leaves. A direction value alone grants nothing. Forward convoy requests retain their existing authority path. No new worker, timer or movement command is added. Optional closure still requires observed complete hull passage and its original native-intent checks. This is implementation and offline evidence only; native planning ambiguity and physical/performance behaviour require audits, which remain paused.

### Measured reverse bend observation

Ordinary backing uses the same bounded travelled-chord measurement as forward driving, projected into reversed unit side/forward axes. Direction is part of the private measurement identity, so changing direction resets the sample rather than borrowing a forward bend. Existing three-metre/1.5-second sampling, six-second age limit, slow-motion reset and curvature clamp remain. Forward native path/support hints are never applied to rear travel. This adds no history scan, query, ray, worker or timer; callers keep the existing observation cadence. Physical reverse bends and performance are unverified while audits remain paused.

### Original clearance producer registration

A successfully started building FSM sends its original visit, owner epoch, clear generation and common-operation generation to the server once. The server binds the request to the actual current group owner and unexpired building pose, retains exact duplicate identity/serial, and refuses a conflicting producer for the same visit. Server acknowledgements attach only to the matching live original job. Registration does not depend on a separately replicated visit variable arriving first. The registry holds at most512 group entries, prunes expired/deleted entries during registration and clears on shutdown; its serial remains monotonic. There is no permanent worker or JIP replay. This establishes producer identity only. Final all-writer sealing, ordered checkpoint delivery, incoming actor/settings reconciliation and physical normal/HC handover validation remain unfinished. Registration arriving after ownership has already changed refuses; no retroactive owner claim is accepted.

### Original actor settings and motion in the outgoing checkpoint

The frozen clearance producer now captures at most64 original/current team actors through BuildingActorJournal. Each row retains the original network identity, canonical setting context, ordered baseline/applied property pairs and unchanged server retry timestamp, plus the clearance motion target and presence-labelled setting mirrors. Nested visit geometry and target arrays are copied. Acknowledged original producer registration is included in this component; missing registration, unknown/deleted identity or malformed data refuses capture. Foreign setting issuers remain explicit in their original context and gain no clearance authority. The private outer capture is now version12/seventeen fields, appending this four-field actor component. No native settings/destination readback is attempted on nonlocal actors. This remains a source proposal: interruption records, complete writer sealing, authenticated delivery and incoming native/settings reconciliation remain required. Audits are paused; no physical handover or performance acceptance is implied.
