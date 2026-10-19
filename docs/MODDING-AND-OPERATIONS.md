# Mod build, testing and architecture

CBE requires Arma 3 2.18+ and CBA; ZEN is optional. Other controllers are optional. CBE configures a
bounded engine danger FSM for base soldier classes; packaged physical and compatibility acceptance remains pending.

## Change validation and local deployment

Use Python 3.11+ and HEMTT **1.22.0**. The modern project definition is `.hemtt/project.toml`.
The checked-in `build_mod.ps1` runs the regression suite, SQF validation, feature wiring check and
HEMTT package build sequentially, then writes `cbe-build.json` inside the output folder.

```powershell
./releaseVerificationAndDeployment/build_mod.ps1 -Hemtt C:/Tools/hemtt.exe -Python python
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus airskills -StageOnly
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus supportflows
python releaseVerificationAndDeployment/report_cortex_audit.py .qa/runtime-YYYYMMDD-HHMMSS-fff
```

The default output is `.hemttout/build`. The addon currently contains scripts, config and an FSM;
`--no-bin` keeps builds portable while HEMTT still rapifies the addon config. Add model, animation
or terrain assets only with the corresponding binarization step restored and verified.

Each audit receives its own `@CBE` folder, mission, profiles, manifest and RPT directory.
The launcher verifies every packaged file before staging. It uses a dedicated server, an interface
client, two optional headless clients, `-noBattlEye`, no file patching and a 3840x2160 client profile.
Dependencies default to the installed CBA folder; `-WithZen` adds the optional dialog provider; `-Mods` accepts an explicit
array for compatibility batches. `-Package` also accepts a signed release candidate folder.
An existing Arma session prevents another launch. Processes are left available for inspection.

Join the observer slot and press OK. Confirm VR mission entry, CBE initialization and matching
package fingerprints in the server/client RPTs. Server readiness or a lobby alone does not establish
successful entry. The observer is protected; combat actors retain each suite's authored setup.
The retained movement diagnostics and live-battle suites have separate purposes. A diagnostic with
invulnerable actors cannot establish casualty handling or combat effectiveness.

The launcher stages every retained suite. `terrain` requires real relief and fails its fixture
prerequisite in VR; use a terrain-specific mission before accepting terrain coverage. The current
standalone mission does not certify JIP, HC disconnect or every optional dependency combination.
Those variants remain explicitly pending in `cortexQA/coverage.json`.

## Change and release pipelines

| Pipeline | Trigger | Output and gate |
| --- | --- | --- |
| `testing.yml` | Push or PR | Regression, SQF, feature wiring and HEMTT checks; installable PBO artifact with build manifest |
| `candidate.yml` | Manual dispatch on the intended release commit | Signed PBOs, public key and manifest in `cbe-candidate.zip` |
| Local packaged audit | One requested batch | RPT evidence, physical outcomes and `cortex-results.json` |
| `deploy.yml` | GitHub release published | Promotes the exact tested candidate after complete passing evidence, accepted feature coverage, fingerprint, clean commit, version and cryptographic signature checks |

Download the signed candidate, extract it locally, and pass that folder through `-Package`. Do not
rebuild between acceptance and publication: signatures are part of the package fingerprint. Attach
`cbe-candidate.zip` and the matching `cortex-results.json` to the draft GitHub release, then publish
the release with tag `vMAJOR.MINOR.PATCH`. The workflow uploads the installable versioned archive.
GitHub runners provide packaging checks; they do not run licensed Arma clients or establish combat
acceptance. Steam Workshop publication remains a separate operator action.
Every feature remains marked `implemented_partial` today, so the public release gate intentionally
remains closed until the recorded acceptance work is completed.

Use HEMTT `utils verify` on each PBO and its candidate public key when inspecting a signed candidate.
Preserve keys and signatures for server signature verification. Never distribute private keys.

## Execution method assessment

FSM performance depends on its trigger cadence and state costs. Engine danger FSM integration lets
reaction work follow engine danger causes. Scripted FSM state code can execute unscheduled, so
expensive work there can evade the shared budget. CBE's finite tactical FSM queues its existing
step through the budgeted scheduler and observes completion/locality. It never runs route scans
directly from a per-frame condition. This change needs a live A/B measurement.

### Engine feasibility boundary

The design is viable, but CBE must cooperate with Arma's planners instead of continuously replacing
their work. The engine supports a configured soldier danger FSM, finite scripted FSMs, owner-local
movement, suppression, building positions, land-vehicle paths, artillery orders and vehicle weapon
release. Those are sufficient for event-driven danger response and finite operations.

The engine also defines strict boundaries which CBE treats as acceptance rules:

- A danger FSM interrupts the formation FSM. It must finish regularly and cannot become a second
  persistent movement brain.
- `setDestination` forces a replan. A healthy operation therefore issues one committed movement
  command and retries only after measured physical no-progress.
- Disabling `PATH` or `MOVE` stops navigation and has locality-sensitive effects. CBE uses no such
  lease for ordinary manoeuvre; a terminal garrison hold may use exact-owned `PATH` state and must
  release it on interruption or ownership change.
- `setDriveOnPath` applies only to compatible land vehicles and any other move command or `doStop`
  cancels it. Convoy phases must have one movement owner and aircraft cannot use this controller.
- Building positions are destinations, not a supplied room-connectivity graph. Clearance must prove
  physical visits, retry another entrance or actor, and report unreachable rooms as `INCOMPLETE`.
- Vehicle fire commands do not supply aiming by themselves. Aircraft and turret operations must first
  prove a compatible loaded weapon, native target/aim solution and valid release geometry; elapsed
  time or an issued fire command is not a hit.
- Path calculation is advisory, segmented and may report duplicate callbacks. It can score a bounded
  route candidate but cannot be treated as proof that an actor will traverse it.

This makes perfect navigation and guaranteed weapon impact invalid product promises. CBE's contract
is prompt finite intent, bounded recovery, clean handover and measured physical outcomes. Native
failure remains visible rather than being hidden by teleportation, forced projectiles or fabricated
completion.

| Domain | Preferred method | Conversion and acceptance decision |
| --- | --- | --- |
| Immediate danger and contact | Engine danger FSM with small owner-local decisions | Bounded intake is configured for base soldiers; promote behaviour only after movement, disable, locality, external-owner and Zeus handover tests |
| Squad tactics and combined arms | Event-fed shared opportunity registry, budgeted decisions, finite leases | Keep communication opportunistic; no compulsory rally or assembly barrier; casualty replacements update roles without restarting the whole attack |
| CQB and garrison | Cached building topology and engine navigation; finite team movement | Native CBE task implementation remains the standalone path. Validate rooms, floors, doorway traversal and exit across different buildings before replacing the fallback |
| Turret and launcher policy | Config where supported, owner-local skills for runtime settings | Config cannot be reversed by a CBA toggle. Any new config component must document that distinction and avoid stacking installed external AI controller companion changes |
| Vehicle driving | Native route commands plus sparse progress/obstruction events | Use sparse route-memory and obstruction sampling; preserve intentional roadblocks, crew ownership and Zeus orders; recovery cannot teleport, repair or remove obstacles |
| Air combat | Native flight, weapon-config capabilities and sparse finite attack intent | Match weapon, envelope and terrain clearance; aircraft own aiming and actual ordnance. Avoid fixed-angle projectile creation or repeated short steering points |
| Civilians and specialist actors | Local danger events and explicit external ownership | Externally owned animations and combat retain their actors; CBE yields instead of layering a competing tactical controller |
| Skills, lighting and dispersion | CBA settings plus equipment/locality events and cached profiles | Avoid rescanning every unit every frame; preserve CBE authored skill values where ownership is delegated |

Retain feature gates, intent, locality, cancellation, casualty continuation and diagnostics through
every conversion. Measure native AI, CBE fallback, and relevant external-mod handover separately.
The agreed initial budget is <=5% added median and <=10% added p95 frame time, starting with 50
mixed groups. Protect the observer throughout measurement and record server and client separately.
An isolated fast showcase is insufficient evidence for scale.

## Source references

- [Bohemia: creating an addon](https://community.bohemia.net/wiki/Arma_3%3A_Creating_an_Addon): mod folders, PBOs, config, keys and addon tools.
- [Bohemia: FSM](https://community.bohemia.net/wiki/FSM) and [execFSM](https://community.bohemia.net/wiki/execFSM): state execution and scripted lifecycle semantics.
- [Bohemia: doMove](https://community.bohemia.net/wiki/doMove), [expectedDestination](https://community.bohemia.net/wiki/expectedDestination) and [disableAI](https://community.bohemia.net/wiki/disableAI): native movement planning, forced replans and movement-feature ownership.
- [Bohemia: setDriveOnPath](https://community.bohemia.net/wiki/setDriveOnPath) and [AI car steering](https://community.bohemia.net/wiki/Arma_3%3A_AICarSteeringComponent): compatible land-vehicle path control and cancellation semantics.
- [Bohemia: buildingPos](https://community.bohemia.net/wiki/buildingPos) and [calculatePath](https://community.bohemia.net/wiki/calculatePath): building destinations and advisory path calculation limits.
- [Bohemia: fireAtTarget](https://community.bohemia.net/wiki/fireAtTarget), [forceWeaponFire](https://community.bohemia.net/wiki/forceWeaponFire) and [targeting configuration](https://community.bohemia.net/wiki/A3_Targeting_config_reference): weapon ownership, aiming and release constraints.
- [HEMTT configuration](https://hemtt.dev/configuration/index.html), [version](https://hemtt.dev/configuration/version.html), [build](https://hemtt.dev/commands/build.html) and [release](https://hemtt.dev/commands/release.html): project layout, package outputs and signing.
- [CBA settings implementation](https://github.com/CBATeam/CBA_A3/blob/master/addons/settings/fnc_addSetting.sqf): global settings and callback contract.
- CBE local `releaseVerificationAndDeployment/launch_pr_review_audit.ps1`, `testing.yml` and `deploy.yml`: fresh staging, readiness, dedicated/client operation and published-release flow examined for this pipeline.

These references guide original implementation. Existing compatibility detection does not mean a
Workshop feature has been recreated or that its physical behaviour passes CBE acceptance.

## Source and documentation gates

The local build and both build/candidate workflows enforce SQF validation for production and audit helpers, config structure, opening source-header contracts, local documentation/image links, shared CBA/Zeus/script setting parity and recurring performance risks. HEMTT compiles and lints addon SQF/config; its warnings remain visible for review. The static performance scanner rejects new high-severity patterns and starts with no accepted exceptions. It does not measure frame time.

See [contribution requirements](../CONTRIBUTING.md) for feature guides, PR evidence and multiplayer acceptance. [The settings reference](SETTINGS-REFERENCE.md) is generated from the live tuning specification. Run `python releaseVerificationAndDeployment/zeus_script_parity_checker.py --write-reference` after editing that specification. CI rejects a stale reference, duplicate keys, invalid defaults or missing function exports.

The GitHub wiki is generated from `docs/` by `releaseVerificationAndDeployment/wiki_sync.py`. Each guide becomes a page of the same name, the README becomes **Overview**, and [`docs/wiki/Home.md`](wiki/Home.md) is the custom wiki home page. Local links are rewritten to wiki pages, or to repository files the wiki does not carry. The build gates run `wiki_sync.py check`, which fails on a broken wiki-internal link and warns about absolute wiki links to pages that do not exist. After a push to `main` that changes the docs, the **Publish wiki** workflow replaces the wiki contents, so direct wiki edits are overwritten. Add a new guide to the sidebar sections in `wiki_sync.py`; until then it is listed under **More guides**.

After approval to close a batch, use `stop_mod_audit.ps1 -Runtime <runtime folder>`. It validates every recorded process against the selected batch, force-terminates matching client/server/HC processes, waits for exit and writes `shutdown.json` only after no matching process remains. Do not treat closing a window or a completed report as process termination. The launcher already refuses a new live batch while any Arma process is running.

### Clearance release and replacement actor movement

Explicit clearance release restores formation only when an actor has no live MOVE or its destination still matches the clearance job receipt within 0.25 m. A newer individual MOVE is preserved; unchanged clearance speed and posture leases can still be released. If the job receipt is missing, a live MOVE is not presumed owned. This guard has static validation only; dedicated normal and headless-client handover retests remain pending while audits are paused.

### Combined ground-fire operator readiness

Direct ground-fire support and the ground maneuver arrival firing branch require a combat-effective local gunner, in addition to combat-mode, player/external ownership and clear-fire-lane checks. An incapacitated gunner returns `NO_FIRE_OPERATOR` through the existing provider rejection path. This change requires a live casualty/provider-fallback retest; audits remain paused.

### Passenger cover reservation scope

Passenger dismount cover selection excludes destinations only from the matching convoy group and configuration revision while their deadline is live. Historical destinations cannot consume current cover slots. Existing and newly selected current destinations remain excluded within the bounded two-search step. Concurrent-owner selection and physical spacing still require live validation.

### Passenger-owner post-exit continuation

The finite remote passenger-owner HALT job retains on-foot actors with the matching convoy/revision unload receipt. This lets cover steps continue after physical exit instead of filtering the actor out as soon as boarding ends. New vehicle assignments and external orders remain protected. Separate-HC exit/cover and concurrent-owner spacing retests remain pending.

### Sliced passenger cover exclusions

Separate passenger-owner retries process a bounded actor slice but pass the full cargo roster separately for read-only destination exclusions. Existing live reservations outside the current slice remain visible. This does not serialize simultaneous selection across owners; that race remains unverified and requires a separate design and live audit.

### Passenger cover cleanup ownership

Passenger cover cleanup recalls an eligible MOVE/STOP only when the expected destination matches the recorded cover destination within 0.25 m in 3D. A newer nearby destination is not owned merely because it lies within two horizontal metres of the former cover point. Live nearby-order handover validation remains pending.

### CQB reserve staging search budget

A building step starts at most one pending reserve stage selection per callback. Other reserves do not consume their attempt until processed; all existing stages retain arrival checks and casualty promotion remains independent. Staging search direction and screening use the building horizontal bounds centre, avoiding assumptions about model origins. The fixed fan is replaced by bounded nearby cover selection with shared destinations of other currently eligible reserves, exterior bounds and at least three metres of primary-entry clearance plus proximity exclusion around every configured same-floor exit. This is not proof of clear route traffic. Rejected candidates retain an explicit current-position hold; rejected selection retries after five seconds with at most three searches per reserve and previously selected candidates excluded. A still-owned native approach retires after sixty seconds without arrival and may select an alternate within the same three-search cap. Exhausted approaches retain a safe hold; local path recovery beyond alternate selection remains unfinished. Physical staging and runtime performance are unvalidated.

### Reserve stage evidence

Owner-local reserve stage receipts distinguish `REJECTED` current-position holds from `APPROACH` and physically verified `ARRIVED`. The hold flag alone is not stage success. This diagnostic distinction does not add a network polling loop or establish tactical security; stage recovery and live acceptance remain pending.

### Reserve search budget replay

A bounded public array journal preserves reserve search consumption and tried candidates across a true clearance resume. It is keyed to the target building, original hard deadline and transform; explicit new clearance clears it. Journal publication occurs only when content changes under current movement authority. An exhausted budget cannot start another search after adoption. Active reserve approaches adopt bookkeeping only when the recorded episode/transform and exact live MOVE destination still match. No movement request is reissued. Retry and approach deadlines use serverTime and survive adoption. Held reserve stages additionally require a live STOP with the exact recorded destination and current 3D/floor proximity before bookkeeping adoption. This preserves rejected retry delays and exhausted status without replaying movement. Interior worker reconstruction and physical HC validation remain incomplete.

### Terminal reserve evidence

Clearance terminal route evidence includes clearing/security actors, capped at sixteen, and appends up to sixteen reserve stage records with consumed search counts. Existing result/reason indices remain unchanged. This preserves rejected/approaching/arrived/exhausted distinctions alongside actual actor positions before cleanup, without adding geometry work or recurring logging. These records support diagnosis and do not prove tactical security.

### Reserve route reachability

Stage endpoints require dry usable slope, standing-space geometry and exterior/exit clearance. A straight observer-to-endpoint ray is not a route prerequisite: native pathfinding may go around an obstacle. The finite owned approach and physical arrival receipt determine success; timeout can select a bounded alternate. No endpoint check claims native route feasibility. Corner-routing behavior still needs live acceptance.

### Grenade release orientation evidence

The one-shot native grenade release trace appends actor position, body/view bearings and target errors, view availability, stance and animation state at FiredMan release. Existing launch/contact fields retain their indices. Command-time alignment and actual release orientation can now be compared; no actor direction or projectile velocity is changed. The reported opposite-contact throws still require live provenance-matched investigation.

### Controlled smoke direction audit

The `grenades` focus stages twelve fresh server-owned smoke cases: standing/crouched/prone and four cardinal target bearings. Each case requires stance, a queued real helper request and an actual nonzero projectile launch vector within thirty degrees of the requested bearing. Missing release/direction fails. Cases use separate origins and delete observed projectiles only after recording launch evidence, limiting cross-case smoke contamination. Flight/impact and smoke delivery are outside this launch-only fixture. This isolated fixture has no hostile actors; it does not validate contact selection, fragmentation, native controls or HC migration. It is unrun while audits are paused.

### Aircraft pilot readiness

Aircraft attack planning, command admission and airborne checks require the shared combat-effective pilot predicate. Alive unconscious, incapacitated or captive pilots cannot start new attack work. Native aircraft command boundaries also re-read aircraft survival, current pilot effectiveness, active/pause state and flight-lease validity. Existing locality, player/Zeus and external ownership gates remain in force. Pilot incapacitation/recovery and cleanup across airborne ownership changes still require physical acceptance.

Active clearance arrests native formation fallback once per committed actor request when the command is empty. Both `DoNotPlanFormation` and `FORMATION PLANNED` are recognized. Current generation, owner and order checks remain in force; explicit FOLLOW, newer MOVE and specialist tasks are preserved. This hold neither grants a room visit nor resets retry budgets. The existing finite room recovery supplies subsequent movement. A normal live audit exposed the previously missed planned formation state; physical validation of this correction and HC validation remain pending.

Clearance egress assigns distinct exterior destinations rather than one shared endpoint per exit. Each actor considers at most twelve nearby slots, separated by at least three metres, requiring dry ground, usable slope and standing clearance. Arrival requires one metre horizontal proximity on the destination floor. Missing slots retain an incomplete result. This removes the shared-endpoint cause of the reported post-CQB pile; physical separation, obstacle routing and HC acceptance remain pending.

Normal-owner repeatability acceptance now repeats clearance with the same two- and six-person squads after ordinary waypoint movement. No cleanup, teleport or actor reset precedes the second episode. A new generation, fresh independently observed room visits by every member and COMPLETE settlement are required. This case is added but unrun; sustained multi-building flow, live combat and separate HC repeatability remain outstanding.

Alternate entrance recovery checks the assigned actor's own physical entry receipt instead of the pair-wide entry flag. An exterior mover can therefore try remaining native entrances even after its buddy entered. During that approach, already-entered partners retain their interior movement/hold; recovery never rallies them outside. Existing entrance history, finite retries and episode deadline remain. The six-person repeat exposed this admission gap; physical validation of the correction is pending.

Room handoff preserves an exact matching active native movement request: if the actor's current MOVE still matches its owned destination and that destination is unchanged, the next pair room claim does not resend it. This especially protects a partner still approaching the same entry point while its lead advances. A changed target and the existing finite no-progress recovery still issue normally. No visit is inferred from planning or movement; physical validation remains pending.

The one-time formation fallback hold does not wait for unitReady: a live trace showed an entered actor already following a FORMATION PLANNED route out of the house with an empty command while still busy. The exact owned generation/order checks and per-request hold limit remain. Explicit FOLLOW and MOVE are excluded. Physical validation of this refinement is pending.

A compact terminal CQB diagnostic records entry/egress failure flags, bounded per-actor visit counts and exit receipts before cleanup. It disambiguates an INCOMPLETE result with full shared room coverage without relying on truncated route traces. Diagnostics cannot grant or modify acceptance.

Exit-slot selection rejects destinations already claimed by another worker, wet ground and unusable slopes before standing-clearance geometry. It retains the twelve-candidate cap and identical acceptance constraints, avoiding repeated rays for slots that cannot be selected. This is a source-level cost reduction; the full median/p95 performance budget still needs measured acceptance.

A modded building's reported interior position may lack a native accessible route. Finite lane/entrance retries retain room-specific failedBy/unreachable evidence and unresolved coverage remains INCOMPLETE. Common CLEAR recovery therefore expires a failed destination observation without quarantining the otherwise capable soldier: it can attempt another room through normal bounded commands. Its generation-wide recovery budget is not renewed. Casualty and external-owner exclusions remain active. No model blacklist, teleport, invented point or inaccessible-room success is introduced; physical invalid-node and mixed reachable/unreachable building acceptance remain pending.

Interior follow-through can retire a failed native room target after its measured no-progress recovery window and try another reported room point. Each actor retains failed target indices and may retire at most three; candidate ranking is capped at twenty-four. Real visits and the common generation-wide recovery budget are preserved. Exhausted alternatives or the immutable episode deadline retain INCOMPLETE; changing targets cannot manufacture progression. Physical inaccessible-point and repeat-clearance validation remain pending.

A room handoff that changes the mover to an already-entered buddy cancels the pair's pending entrance staging leg. The successor continues interior progression instead of inheriting an exterior actor's approach. Only a prior physical room receipt permits this cancellation; entrance proximity grants no entry. Physical handoff and locality replay acceptance remain pending.

Failed follow-through target limits survive true ownership resume in a compact public journal updated only on target retirement or exhaustion. Replay requires the same building, transform and original hard deadline, accepts at most sixty-four actor rows with up to three valid room indices, and restores only failure bookkeeping for the same actor IDs. It grants no visits and issues no movement. New clearance, explicit release and terminal cleanup discard the journal. Separate two-HC physical replay acceptance remains pending.

Physically visited destination-floor access takes priority over cached geometry-only floor connectors. The connector fallback no longer replaces an established access checkpoint with an exterior current-floor detour. This uses existing bounded room coverage, introduces no extra geometry scans or movement writer, and preserves finite retries, unresolved-point INCOMPLETE results and immediate newer-order cancellation. Physical multi-storey retest remains pending.

When bounded recovery exhausts an interior access checkpoint, CLEAR retires that checkpoint once and attempts the assigned room directly before recording a pair failure for that room. A claim-scoped tombstone prevents rebuilding the failed leg. Durable retry counts, recovery budgets and hard deadlines remain unchanged; no visit is inferred. This addresses observed room classification while the actual failed request was a different access node. Physical retest remains pending.

Floor connector source selection now ranks up to twenty-four physically visited current-floor room points ahead of thirty-two raw transit candidates. Source-specific cache keys prevent reusing an exterior source after interior access is established. The eight-record geometry budget remains unchanged; this selection runs only when constructing a changed room approach. Destination-floor access already physically visited still has priority. A proven source does not prove the floor connection, and all arrival, finite recovery and incomplete-result gates remain. Physical retest pending.

CLEAR records its first entry-failure cause once per operation: stranded worker, exhausted follow-through or missing sweep participation. The record includes the actor or bounded sixteen-actor physical participation snapshot at the decision boundary and is appended to terminal diagnostics. It adds no geometry query or recurring log and does not clear failure history or alter completion. This is needed to diagnose an observed repeated six-person INCOMPLETE result despite later full coverage, participation and egress. Fresh physical diagnostic replay pending.

Partner entry recovery no longer requires a previously cached support-entry target. It initializes a missing target from the lane anchor before tracking the unentered partner. This removes a gate that could leave an exterior partner without any recovery receipt when entrance handling preceded support selection. Existing owner/service guards, measured no-progress window, one-shot recovery and shared deadline remain. Fresh physical replay is pending; the observed missing receipts do not alone prove this was the only entry failure cause.

When a single casualty replacement is still outside and its surviving buddy has physically entered, the survivor retains the mover role. The replacement joins through existing bounded partner-entry recovery rather than inheriting the removed actor's current interior leg. Whole-pair exterior reset, shared room coverage, retry counts, hard deadlines and newer-order authority remain unchanged. Selection uses the existing pair roster only. Repeated single-replacement entry failures motivated this correction; fresh physical validation remains pending.

The single-replacement role rule also covers casualties before entry: if neither actor has entered, a healthy original buddy retains the mover role while the reserve follows partner entry. Entered survivors remain preferred. A wholly replaced lane has no original survivor and keeps its exterior reset. This extends the earlier entered-survivor correction to the actual early-casualty audit trigger; fresh physical acceptance remains pending.

CONTACT continuation now includes the matching live owner/generation CLEAR operation and uncancelled building brain. Loss of sight therefore cannot advance contact cleanup over clearance's movement and autonomous-attack lease. CLEAR still ends through its existing finite deadlines, physical result or immediate replacement/Zeus cancellation; contact cleanup resumes after that owner is gone. This closes a source-level continuation gap found while diagnosing native ATTACK diversion. Physical causality and repair remain pending.

An exterior partner whose one-shot entry recovery has made no approach progress for twenty-four seconds may select one different physically visited current-floor point before full shared room coverage. Selection examines at most twenty-four proven points within thirty metres and stores one public building/hard-deadline/transform receipt per actor, including failed selection, so locality replay cannot replenish this alternative. The same guarded owner-local clearance callback records the shared pair target before issuing movement, including when that pair's room queue has ended. Later pair steps preserve the matching active path; no independent movement worker is added. Changing the target resets its distance baseline but does not renew the progress timestamp, deadline or common recovery budget. No visit is inferred. This addresses partners waiting outside while one unrelated room blocks the later full-coverage follow-through stage; fresh physical validation is pending.

### Friendly infantry around moving vehicles

Ordinary driving assistance now applies the shared friendly-pedestrian speed observer under `CBE_AIPass_DrivingAssist_Enable`. Registered convoys retain their separate, default-off `CBE_Convoy_AvoidInfantry_Enable` option. The existing owner-local operation applies the result after other lower speed caps; no additional movement controller is started. Pedestrian constraints use the existing traffic phase and suppress stuck recovery. Player, Zeus and external-controller handovers retain the driving operation's authority checks.

The observer projects pedestrian hull corners into the vehicle frame, checks lateral and vertical overlap, and measures clearance from the front or rear hull according to actual travel direction. A continuous braking envelope includes a provisional four-second response allowance and mass-adjusted deceleration. Occupied near-hull space requests zero immediately; there is no minimum crawl or small-change filter that can discard a stop. Each observation evaluates at most 32 pedestrian hulls within a speed-dependent radius capped at 250 metres; denser sets request a stop. It retains no clearance cache, handlers or JIP side effects.

This is not crossing prediction, a steering avoidance manoeuvre or proof of collision prevention. Native braking, fast lateral crossings, turning swept hulls, reversing from rest, slopes/bridges, crowd response, repeated restart and locality migration require physical validation. Audits are currently held; performance acceptance remains unmeasured.

Ordinary forward traffic observation also admits occupied vehicle hulls at any heading, including sideways parked vehicles and destroyed vehicle entities. Only aligned, non-reversing predecessors receive a measured forward-speed allowance. Other hulls overlapping the forward lane and vertical corridor are treated as stationary occupied space for the speed ceiling; a centre behind the bumper does not hide a protruding hull. Existing candidate limits, traffic wait/recovery suppression and ownership cleanup remain. This does not predict a crossing before it enters the lane, choose right-of-way, route around wrecks, or guarantee stopping against an approaching vehicle. Those behaviours and physical angled-obstacle tests remain outstanding.

Convoy driving assist now applies the same forward-lane hull observer to the lead and every follower on the existing one-second convoy tick. The exact registered predecessor retains the configured size-aware convoy pacing only while alive, aligned within 25 degrees and not reversing along the follower's forward axis. Its hull is still observed: contact-range bumper room below two metres stops the follower; a turned, reversing or destroyed predecessor receives ordinary occupied-hull constraints. Crossing predictions still apply. Other vehicles and wrecks remain obstacles. This adds at most one predecessor hull evaluation within the existing 64-candidate limit, with no new query or scheduler. Physical cornering, mixed-hull braking and stopping-distance acceptance remain unverified. These caps apply after acceleration/spacing smoothing and before the existing speed writer. Observed traffic and zero-speed holds refresh progress timers and suppress stuck recovery, preventing an immediate stale retry when the road clears. Disabling `CBE_Convoy_DrivingAssist_Enable` removes this observation along with its road/path assistance; convoy spacing and the separate opt-in pedestrian check retain their own scope.

Cost is at most one area query and 64 eight-corner hull projections per convoy vehicle per tick, with a 250 m query-radius cap and a maximum 20 registered vehicles. This bounded cost has not been measured against the frame-time budget. Physical tests must cover unrelated parked and angled obstacles, wrecks, release/restart, configured short gaps, mixed tracked/wheeled braking, bends where other convoy hulls intersect, and HC migration. No crossing priority, passing or timeout-based permission to drive through the blockage is introduced.

Convoy unload policy now has its own exact lease: controlling group, accepted revision, previous policy, applied policy and machine owner. Startup and five-second crew upkeep call the same owner-local helper. Unchanged leases are adopted across revisions and migration without repeating the engine write. If a script changes the current policy, CBE retires its lease and blocks reacquisition for that convoy group until explicit release; HALT/resume does not override the change. Release restores the locally captured previous policy only when the lease still belongs to that group, its applied value remains current and no player/Zeus/external controller owns the handover. A missing lease does not authorize restoration from the older server snapshot. Successor-retained vehicles keep their lease. No settings, handlers or new recurring jobs are added. Live script mutation, release/re-register, successor retention and HC migration still require physical verification.

A physically arrived clearance reserve installs its exit watch only in the callback where its actual eye-to-watch VIEW ray succeeds. A staging-point proposal ray, arrival flag or earlier owner's watch receipt cannot substitute for that check. The existing oldest-due rotation and one-ray-per-callback budget remain; newly arrived or adopted observers wait for their turn. Persistent blocked views retain the existing finite search/reposition budget, and no watch creates room-clearance credit. Physical outside-security, occlusion, casualty and HC validation remain pending while audits are held.

Casualty promotion recognizes physically settled early-exit clearing workers as potential substitutes for an established reserve's doorway watch. Both kinds of substitute must still hold the same exit with current generation/owner watch receipts, remain physically at their post, be available and pass a fresh actual-eye VIEW check. An approaching, diverted or unavailable worker cannot supply cover. A rotated observer roster avoids repeatedly spending the shared one-ray budget on the same blocked first post; at most sixteen reserves and eight early-exit records are considered. This adds no movement writer, ray budget or deadline renewal. If no real substitute exists, the established watch remains protected. Physical casualty flow, blocked views and separate HC validation remain pending.

Natural contact clearance opts into `continueRoute`: only a COMPLETE result with successful participation and egress may return settled actors to their unchanged plain authored MOVE after the common clearance operation releases. Explicit clearance defaults to settlement; scripts may request the typed BOOL option `continueRoute` (default false). The choice persists through room-progress publication and owner resume; older receipts default false. The owner rechecks generation, current brain, unchanged authored metadata, no successor operation, task availability and each actor's actual STOP before handback. The leader must qualify before followers rejoin it. New individual movement, scripted/timed/synchronized/attached routes, missing routes and incomplete results retain their current orders/holds. No waypoint or behaviour/ROE is rewritten, and room visitation does not prove hostiles eliminated. Physical route continuation, combat response, repeat clearance and separate HC cases remain unverified while audits are held.

The building audit retains the original no-route natural-entry case and adds a separate `BUILD-CONTINUE` controller-flow case. One plain patrol waypoint is established before contact. Native knowledge must trigger clearance and independent physical entry before the posted defender becomes vulnerable to real gunfire. A pass additionally requires independently observed visits to all roofed fixture room targets, a real squad-caused casualty, COMPLETE clearance, every living on-foot member travelling at least 25 metres with at least 20 metres of progress toward the unchanged waypoint, and retained authored route identity. No later test-side movement, route replacement or completion assignment assists the handback. Protected attackers mean this does not validate combat effectiveness. The case is prepared but unrun; normal and HC acceptance remain separate.

Terminal clearance clears an observation command only when the actor carries the matching public and local exit-watch receipt for that clearance generation and owner epoch. Interior workers without that receipt are no longer sent a blanket `doWatch objNull`. Existing movement diversion, native-task and external-owner guards still apply; stale watch metadata retires separately. An external script changing an identical watch without replacing an ownership receipt remains indistinguishable to this lease protocol. Physical newer-watch and owner-transition validation remain pending.

Ordinary-driving assistance includes finite static-obstacle bypass and navigation-area passage while retaining the authored waypoint. This does not implement moving-vehicle overtaking or cooperative jam clearance: stopped peers remain occupied hulls, and existing finite native-route retries do not authorize another group to back up. A future cooperative manoeuvre must be admitted by each current owner, preserve route/seat/command receipts, retain fresh physical clearance, and end on expiry or a newer order. Public peer requests alone cannot grant movement authority. These gaps remain unaccepted while physical audits are held.

Prepared normal-convoy corner acceptance now requires a measured turning/closing predecessor encounter, physical speed reduction of at least 1 m/s within eight seconds of the first such event, sampled hull separation without new damage, and all vehicles physically reaching the outgoing leg. A route that never produces the encounter fails the prerequisite instead of passing the braking check. No added fixture movement or direct production callback supplies these results. The observer uses two eight-corner projections at 5 Hz for at most 150 seconds and is not a performance measurement arm. Sampling can miss contacts; zero damage alone does not prove collision freedom. This case is unrun; headless acceptance remains separate.

Finite danger-cover movement now binds its owner epoch, operation generation and full authored native waypoint receipt. A same-index condition, script, attachment or synchronization edit invalidates continuation and return-to-formation cleanup; legacy leases lacking that proof retire metadata only. A new nearby danger observation can retain an unchanged screened route without extending its deadline. The final new move and failed-approach return recheck the order context. This adds authored-route metadata reads on existing cover callbacks, not a new timer or world scan; route enumeration cost still depends on mission waypoint count. Physical route edits, actor interruption and locality handover remain unrun while audits are held.

Shared direct/suppressive-fire protection now queries the complete target corridor instead of a shooter-centred search truncated at 600 metres. A single rectangular area includes live people inside vehicles, then the existing ASL cone projection checks friendly, civilian and protected-captive positions. The shooter's own platform and occupants are excluded. Non-finite/malformed targets, spans above 6000 metres and more than 64 native query candidates refuse fire rather than ignore part of the corridor. No recurring scan or weapon/movement writer is added; native area-query cost remains engine-dependent. This position-based veto does not establish blast, hull, penetration or future-motion safety, and does not authorize destructive building fire. Long-range, mounted-protected-person, steep-terrain and dense-scene physical acceptance remain unrun while audits are held.

Alternate driving-path admission now requires both driver and effective commander to be idle or executing a native MOVE to the current authored destination. Native STOP, FOLLOW, ATTACK and unowned CBE cannot start a static bypass or navigation-corridor approach. Bypass PLAN rechecks this before fixed steering; corridor APPROACH rejects a new STOP or other non-movement task before CROSS. The owned FOLLOW/CROSS phases retain their intentional two-seat `doStop` contract, so this is not a blanket STOP veto. A later external STOP indistinguishable from that owned STOP remains unresolved. Separate-commander native destination propagation, real path acquisition, interruption and handback require physical testing. No timer, query or movement writer was added.

Native driving-path curvature hints now refuse multiple disconnected path stretches within the current three-metre/floor proximity band. At self-crossings or close parallel returns, the observer cannot infer which later stretch belongs to the current approach. It returns no hint and the existing travelled-motion curvature fallback remains in use. Equal-distance ties within one contiguous stretch retain the first segment. Duplicate zero-length nodes do not split a stretch. The existing 64-node/63-segment bound, subscriptions, expiry and route/seat receipts remain unchanged, with no new query, timer or path command. This is ambiguity rejection, not path selection or clearance proof; physical intersection/loop/overpass behaviour remains unrun while audits are held.

Convoy mounted-fire upkeep now uses the shared full-corridor protected-position veto before explicit target/fire requests. Each eligible operating crew member must be combat-effective, visible and simulation-enabled along with its platform. A blocked lane or unavailable operator retires the convoy target only while the current assigned target still matches its recorded assignment. Cargo, ROE, external ownership and the existing five-second cadence remain authoritative. This is not continuous fire cessation, blast safety or proof that a previously ordered burst has stopped. Actual rounds, blocked-lane interruption and resumed mounted fire remain physically unrun.

The current convoy path has no source-specific external driving pause/restore adapter. Generic declared ownership can make CBE yield, but cannot suspend an undeclared external controller. Earlier coverage wording claiming otherwise is withdrawn. Required dependency-loaded controller handovers remain unfinished; compatibility expansion stays deferred behind behaviour foundations.

## Combining source behaviours

CBE combines complementary source intentions through its own owner-local FSMs. A source method must have a recorded contribution, interaction with current behaviour, balance and performance implications, deliberate changes and physical acceptance evidence. Review, selection, implementation, integration and physical verification are separate milestones. Matching file counts do not establish parity or improvement.

Queue consent remains metadata only. An expected owner's negative acknowledgement now immediately retires an already agreed server episode and sends RELEASED to participants; duplicate positive acknowledgements retain the original deadline. This adds no HOLD, settled READY, reverse movement, crossing or handback executor. Deferred owner-message replay and physical queue flow still need resolution and validation. Audits remain paused.

Queue retirement also remembers each closed token until its original consent expiry in a machine-private journal. This blocks delayed VERIFY/AGREED messages after refusal, cancellation or phase expiry, including a terminal result received while the participant is nonlocal. The journal retains at most64 live tokens (the broker admission bound); unknown or full records refuse admission, expired entries are pruned only during retirement, and duplicate closure cannot extend expiry. No recurring worker, movement or public/JIP state is added. A new owner still needs the existing authenticated broker and current-context checks. Native execution and physical handback remain unfinished and unvalidated.

### Finite clearance exit allocation retries

A temporary exterior-position allocation failure retains the worker's exact owned native leg instead of dropping that worker immediately. Each actor has at most three allocation batches, separated by two server seconds; one due actor is planned per existing operation callback. Later batches try different exterior search bearings. Each batch retains the existing three/four-proposal limit and actor/slot/lane/geometry checks. Existing exit travel continues while another actor waits to retry.

The original 45-second egress deadline is unchanged. The version3 journal preserves allocation attempts and next retry time through owner adoption; legacy version2 pending rows start with their original zero-attempt semantics. Admission never issues movement or renews the clock. Replaced actor/native orders remain excluded, and allocation does not count as physical exit or clearance completion. Exhaustion remains INCOMPLETE; no current-position fallback, teleport or new worker is added. Worst-case allocation work rises to at most twelve native proposals per actor across the whole phase, not per callback. Physical flow, geometry quality and aggregate cost remain unverified while audits are paused.

### Clearance settings release during native tasks

Terminal and explicit clearance cleanup share one settings-only release path. An unchanged CBE speed cap or forced upright posture can be released while an ordinary native treatment or boarding task continues; this issues no movement, watch, target or formation command. A different current setting is preserved. Player, remote, mounted, reserved, hidden, frozen or specialist-owned actors retain their saved baseline rather than having it deleted without restoration.

A refused release can retain one original 30-second retry window on the existing group brain. It handles at most one pending actor per callback, scans no more than64 group members and pauses restoration while another operation or clearance owns the group. The retry does not renew its deadline. Locality adoption updates only the generation/epoch fields and retains that deadline; actual release still requires current actor locality and authority. Expiry retires the retry window while preserving unresolved baseline data. A stopped/disabled group brain does not start an extra worker, so eventual restoration after shutdown or after the window expires remains incomplete. Fresh clear admission must preserve that unresolved baseline. Physical native-task, reservation, repeat and HC-transfer outcomes and added callback/network cost remain unverified while audits are paused.

### Shared operation attack permission

`CBE_fnc_OperationAttackPolicy` is the setting acquisition boundary used by clearance and committed infantry manoeuvres. It requires the current group, common operation generation and owner epoch, a live operation, a local leader and roster, and no player, remote-control, curator hold or specialist takeover. Oversized rosters refuse before the ownership helpers scan members. The call changes only native autonomous attack delegation; it grants no movement, target, firing or formation authority.

The first successful call captures the native baseline and requested applied permission in the common operation's `restore.groupAttack` receipt. Repeated calls check the receipt and native value without issuing another command or replacing the baseline. Malformed receipts and conflicting requested values refuse. A later different native value returns `POLICY_CHANGED`; the manoeuvre ends rather than disabling attack again. A resumed clearance can provide the original baseline from its already-admitted durable order. Fresh clearance persists the baseline acquired after predecessor retirement, so subsequent owner adoption does not inherit a temporary policy observed before cleanup. Common `OperationRestore` remains the release path.

Clearance refuses before starting its worker if permission acquisition fails. Cleanup is attempted only through that preparation's original generation/epoch/order gate. Manoeuvres use the same boundary on subsequent steps. No new setting, module, recurring job, geometry query or deadline is added. Admission inspects at most 64 members; helper calls still have a bounded per-member cost that requires measurement in game.

This is a shared control foundation, not demonstrated CQB flow or whole-mod settings-lease parity. Same-value external edits cannot be distinguished by comparing a boolean. Generic actor speed/posture ownership, release retention after brain shutdown, movement provenance, migration and interruption acceptance remain open. Audits remain paused; offline gates do not establish physical or performance acceptance.

## Temporary actor settings ownership

Clearance uses the shared ActorSettings contract for temporary stance and forced speed. Its receipt records the group, issuer, operation generation, owner epoch and original hard deadline, plus the original and last applied value of each setting. Only the actual actor/group owner can apply controls. A later native setting change refuses further application rather than becoming a new baseline.

The clearance adapter binds acquisition to the current operation, building transform, authored route and live job. Native movement remains independently owned; a settings receipt grants no movement authority. Room movement requires acknowledged settings. Locality adoption changes receipt metadata without reissuing native controls. A fresh task can retire its known predecessor before capturing new settings; foreign or incomplete metadata cannot grant takeover.

Release restores a setting only while its native value still matches the last CBE value. Later mission edits survive. Unconfirmed restoration retains the remaining original/applied pairs and permits at most one retry per second through the existing finite cleanup caller. It creates no worker and does not renew the caller deadline. Existing clearance mirrors support the movement journal but cannot replace the canonical receipt.

This foundation currently serves clearance. Initial network receipt readiness, cleanup after the finite caller expires and adoption by other behaviour subsystems remain incomplete. Static readback guards do not prove engine acknowledgement, physical movement or performance.

Native stance-rule reads are normalised to uppercase before settings enum validation and receipt comparison. Arma documents mixed-case `unitPos` values; their spelling must not make a valid actor fail settings admission. This reads the position rule, not the current animation stance.


## Per-vehicle driving-aid exclusions

CBA remains the source of global driving settings. A mission can additionally disable selected aids on one vehicle by publishing a `CBE_Driving_DisabledFeatures` array on that vehicle. It is a disable-only filter: removing an entry cannot enable a globally disabled feature, bypass group exclusions, take control from another controller or grant native-command ownership. An invalid container refuses the selected aids until corrected. CBE does not rewrite the mission's value.

Supported keys follow the existing CBA scopes: `CBE_AIPass_DrivingAssist_Enable`, `CBE_AIPass_DrivingAssist_Recovery_Enable`, `CBE_AIPass_DrivingAssist_Passing_Enable`, `CBE_Convoy_DrivingAssist_Enable` and `CBE_Convoy_RouteRecovery_Enable`. `ALL` excludes these driving aids. It does not cancel an explicitly assigned convoy task or replace the external-controller ownership contract. The passing key controls automatic preparation, as its CBA setting does; admitted passes and issued recovery legs retain their finite safety and handback rules.

For example, a server or trusted mission script can publish `truck1 setVariable ["CBE_Driving_DisabledFeatures", ["CBE_AIPass_DrivingAssist_Recovery_Enable"], true];`. Publish an empty array to remove that vehicle's exclusions. The optional fourth argument to `CBE_fnc_CortexFeatureEnabled` supplies the actual vehicle: `[group driver truck1, "CBE_AIPass_DrivingAssist_Recovery_Enable", true, truck1] call CBE_fnc_CortexFeatureEnabled`. Queries remain read-only; actual task/driver/route authority is validated by the executor.

Existing owner callbacks re-read the filter at admission and native issue boundaries. Disabling ordinary assistance uses its existing exact-owner release path. Recovery and passing changes prevent fresh attempts/preparation while preserving already issued legs and pending native uncertainty. Gate requests and deferred path observations also recheck the target vehicle. Each convoy follower evaluates its own optional traffic/path aid independently of the lead; predecessor spacing and the convoy task remain in force. Stop/locality handling uses existing journals, and JIP receives the published filter without replaying commands. No new timer, handler, worker, UI setting or Zeus settings module is introduced. Live toggles, normal/HC handover and overhead remain unverified while audits are paused.


## Pre-placed navigation corridors in Eden

Place **Navigation corridor (mission)** from the CBE module category. Size its rectangular area over the route and point its arrow along the passage. The area uses half-width 2-20 m and half-length 5-45 m; defaults are 5 m and 25 m. The labelled task-speed selector defaults to 15 km/h and offers 5, 10, 15, 20 and 30 km/h. These are parameters of that corridor, not global addon settings. Keep the module at the intended bridge-deck elevation rather than flattening it to sea level.

The persistent module is the area object. On the server it registers the same revisioned definition consumed by ordinary driving and convoy navigation. With no synchronized trigger it is active at mission start. A synchronized trigger can remove the definition on deactivation and register it again on activation. Repeated identical activation or already-absent deactivation does not renew the registry revision. New definitions use the existing 32-area budget and dimension validation. Invalid area data is refused and reported in the server log and the module's public `CBE_DrivingCorridor_MissionResult` result; it is not silently clamped.

Zeus placement keeps its disposable frontend and creates a persistent corridor area as before. An explicitly selected mission corridor can also use the existing optional ZEN update/remove dialog when it is editable by that curator; the server checks the exact object, permission and transform. Live object transforms remain authoritative, and movement/deletion invalidates matching in-flight navigation. Removal through the dialog deletes that selected area object, including a pre-placed module. Trigger reactivation uses the module's authored dimensions and task speed.

The module does not command a vehicle or register a second controller. Existing routes must make the passage useful, the whole vehicle/convoy envelope must fit, and current geometry, traffic and ownership checks must permit it. It does not add shallow-ford support, ignore obstacles, repair navigation metadata or guarantee a crossing. Server-only setup publishes passive definitions to JIP; clients and headless owners do not replay registration or old vehicle commands. No timer, handler or transform-following loop is added. Editor layout, trigger repeat/deactivation, multiplayer editable-object handling, JIP/HC and physical bridge traversal remain unverified while audits are paused.

### Combat gunner replacement and incoming crew

A confirmed danger episode may ask an eligible commander to replace a lost primary gunner through the native internal seat action. A living crew member already assigned to that gunner seat retains it, including while outside the vehicle or incapacitated. An explicit STOP, another vehicle assignment, hidden/suspended simulation or disabled movement/pathfinding refuses the replacement. Auxiliary turret assignments remain independent. No incoming assignment is cleared and no crew member is teleported. This is command admission; actual seat transition and subsequent firing still require in-game verification.

Routine passenger boarding preserves explicit STOP and disabled MOVE/PATH. Both routine boarding and dismount admission refuse hidden or simulation-disabled actors and vehicles. These shared guards apply to the existing convoy/contact/remount callers; they do not introduce operating-crew return or change emergency engine bailouts. Live boarding, interruption and locality handback remain unverified.

### Operating crew already ordered to board

Ordinary driving now cooperates with native GET IN orders for assigned operating crew. For the leader vehicle on its unchanged plain MOVE route, an eligible local crew member within 100 m who is assigned to an empty non-cargo, non-FFV seat can request a vehicle wait. The existing driving speed writer applies the zero cap; no second controller, crew movement order or seat reassignment is installed. Boarding itself stays native.

Each actor/role/turret-path attempt gets one original 60-second limit. The existing samples also retain an absolute-position anchor and original progress clock: twelve seconds without two metres of measured actor motion ends cooperation. Real detours and stairs can supply motion; they do not prove boarding. Progress never extends the original 60-second limit. These passive progress receipts survive owner migration. The passive receipt survives owner changes on the same route, and an expired attempt does not restart while that actor remains outside and assigned to the seat. Physical boarding or assignment removal/change retires that identity. A route change is a new context. New actor tasks, tactical ownership, invalid simulation or unavailable movement end cooperation; split actor locality grants no wait and no renewed lifetime. No repeated native boarding command is sent.

Combat, convoy ownership, reverse recovery and active pass/bypass/corridor operations prevent this wait. Fresh native route/crew intent is checked again at the cap commit. Existing collision and pedestrian protections remain. Diagnostics identify CREW_BOARDING, which means a requested wait, not actual boarding success. At expiry the ordinary route cap resumes under its usual ownership checks; native GET IN is neither cancelled nor forced on.

This supports crew already trying to enter a driven vehicle. It does not automatically recall crew: a retained assignment alone cannot distinguish an intentional orderGetIn false. It also does not solve an absent driver's return, cross-group crew pickup or blocked native boarding geometry. These remain separate gaps. Engine boarding, repeated departures, interruption, normal/HC migration and the runtime cost remain unverified while audits are paused. The helper reads one native seat table (refuses more than 20 rows), retains at most 20 attempts and publishes only changes; no world scan or new scheduler is added. An active wait repeats the bounded seat observation at the existing cap commit.

### Animated wall and fence gates

The shared ordinary-driving/convoy geometry observer recognises native Wall/Fence-derived objects with a supported indexed door/gate animation source even when their names omit gate or barrier. Recognition uses the same bounded source checks as animated barriers. Static walls remain solid obstacles; ordinary house doors gain no generic fallback. Gate opening still requires authoritative route/crew/lock validation, and fresh physical geometry controls passage regardless of animation or timeout. Unknown animation conventions, automatic closure and physical traversal remain unverified or unimplemented as recorded in the source reviews.

### Queue negotiation motion boundary

Queue proposals and every deferred owner/server revalidation require finite total linear motion below 1 km/h and angular motion below 0.01 rad/s. Pivoting, sliding or falling vehicles cannot qualify through a near-zero forward speed. These are instantaneous admission observations; owner consent still does not establish a held or physically settled vehicle. Automatic queue admission remains inactive pending dependency-ordered native movement and exact phase cancellation/handback. Explicit committed hold and sampled readiness are described below. No speed or reverse command is issued by negotiation.

### Explicit queue hold and measured readiness (development protocol)

A completed queue agreement can now be explicitly committed by its initiating vehicle's actual owner. COMMIT is a separate authenticated server request; AGREED alone never stops a vehicle. Every participant owner must still hold the exact AGREED token, serial, canonical crew/order context and original expiry. One initial commit delivery and one delivery retry are permitted per token. Duplicates preserve the original values and do not reset dwell or expiry. Automatic queue requests remain inactive.

For a current committed participant, the existing ordinary driving callback requests a zero cap from its sole speed writer. It records APPLIED only after writing that cap. READY additionally requires the matching token/current brain, a still-owned zero cap, and samples at least one second apart with total linear speed below 0.1 m/s and angular speed below 0.01 rad/s. These are sampled observations, not a continuous physics guarantee. The server authenticates the reporting participant owner and independently rechecks topology, the reporting vehicle and all participants' current motion before setting aggregate readiness. The record is not an ongoing lease; a future movement phase must revalidate current ownership, hold and physical room. Public markers are never substituted for owner acknowledgement. A held participant sends at most two READY reports, separated by at least two seconds, through its existing driving callback. This bounded retry tolerates a stale server motion sample without renewing consent or granting movement. Delivery is not guaranteed; the original expiry remains in force.

Hold metadata lives inside the private agreement, so its original expiry timer retires it even if tactical scheduling stops. The existing driving release owns cap restoration. Changed cap, native order, context, controller or locality revokes cooperation; a changed cap after application is never reacquired by this hold. No new speed writer, movement worker, recurring timer, native STOP, reverse or waypoint is added. Active holds use the existing one-second constrained-driving cadence. Canonical checks cover at most four participants; their engine/metadata cost remains unmeasured.

Explicit local development example, after the initiating vehicle has received AGREED:

```sqf
private _agreement = leadVehicle getVariable ["CBE_DrivingQueue_Consent", createHashMap];
if ((_agreement getOrDefault ["phase", ""]) == "AGREED") then {
    ["COMMIT", [_agreement get "token"]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer", 2];
};
```

READY currently ends at the server's hold-readiness record. It does not start a reverse leg, grant passing priority or establish a cleared queue. Dependency-leaf reverse, independently measured full-hull clearance for parent movement, phase-specific native receipts and exact handback remain to implement. Normal/HC interruption, duplicate/delayed delivery, expiry, restoration and actual stationary readiness remain physically unverified while audits are paused. No Zeus module advertises this incomplete behaviour.

### Queued work after an operation FSM ends

Driving, convoy, building-clearance, aircraft-attack, support-request and artillery callbacks now require a live current FSM handle before executing their queued observation/command path. The scheduler delivers queued work on a later tick, so this execution check happens after startup publishes its handle. An ended or invalid handle retires only that queued callback and clears its pending flag. It does not start another FSM, clear movement/room evidence, cancel the admitted task, restore controls or renew a deadline. The existing bounded restart/discovery path retains responsibility for resuming the same admitted context and preserving its budgets. Aircraft retain their original flight lease, support retains the registered request serial, and artillery retains its fire token or original finite relocation-observation session. An ended callback cannot dispatch responder roles, continue an attack or advance a fire mission on its own. This guards callback authority; forced FSM termination, restart flow and normal/HC interruption still require in-game verification.

### Ended aircraft attack jobs

An exact original aircraft job can resume its existing cleanup/egress after the target object is deleted, provided its original flight lease, group and epoch remain valid. No replacement target is selected and no phase deadline or lease is renewed. If the FSM has ended and that original context is lost, discovery now retires the exact job through its existing executor-failure cleanup instead of leaving the attack-active flag stranded. An unrelated new request cannot use this retirement path. An ended exact job with no pilot group also retires; a nonlocal crew group defers because it may be a temporary ownership split. Live executors retain their normal loss handling; native restoration remains conditional on exact original ownership and value receipts. Target deletion, lease expiry, crew changes and normal/HC handback remain physically unverified.

The recurring infantry group decision callback also checks its current FSM handle before cleanup or tactical decisions. If that executor ended, the queued callback retires without commands; the existing discovery sweep can replace the brain. This does not add a restart timer or change direct danger-assessment execution. Forced termination and replacement still need in-game verification.

Routine vehicle gunnery distinguishes very recent reports from older contact estimates. Within the existing fifteen-second report window, reports older than three seconds use fixed-position suppression rather than another object-target fire order. This requires a ground platform below 30 km/h, at least 50 m separation, no ongoing burst or unrelated engagement, terrain visibility, existing friendly-fire checks and a compatible loaded nonexplosive bullet muzzle with at least twenty rounds. The existing eight-second hold and native burst behaviour remain. This does not establish building destruction, fire effect or current visual sight.

Coordinated ground-fire safety checks use the local gunner native believed position, falling back to the original admitted report when personal belief is unavailable. Arrival never substitutes the hidden target current pose or refreshes report age. Native targeting remains the requested role action; the safety cone is not proof of blast safety or fire effect.

Immediate coordinated ground fire confirms the compatible loaded muzzle has actually become selected before issuing fire. A pending native switch uses the existing group retry and original expiry, with a distinct muzzle-selection status. It does not count as applied fire or restart the opportunity. Manoeuvre-arrival fire keeps the same selection requirement.

Routine vehicle standoff cannot move a platform under a live coordinated ground-fire reservation. When a viable escape proposal exists, the owner requests retirement of the exact stationary fire role once; the server can offer its slot to another asset under the original report and expiry. Standoff waits for role removal and a later callback. Emergency reactions remain separate, and manoeuvre roles keep their own controller.

When a garrison interior route exhausts its retry/deadline budget, that exact post leaves the current order candidate pool. Refill cannot offer it again after the failed actor later dies, and another actor cannot select it in the same callback. Existing held posts remain assigned. A fresh explicit garrison order rebuilds candidates; exhaustion is not a permanent building-accessibility verdict.

An issued reverse destination keeps rear pedestrian, hull/support and path-divergence checks active while native acknowledgement is pending. The original acknowledgement and recovery deadlines remain fixed. Pending acknowledgement cannot authorize a forward retry or count as completed movement; a rear hazard still applies the existing zero speed cap. Observation occurs on the existing rear-stage callback, so hazards arising wholly between samples remain unverified.

Queue proposals refuse yielding/rear roles when the driver is also the effective movement commander or native turn input is not NONE. These are prerequisites of the existing native BACK path, not proof of physical reverse capability. The crossing holder does not require this reverse arrangement. The broker and actual owner recheck these prerequisites before consent, commit and hold; no crew is reassigned and no turn input is cleared. Ordinary destination recovery remains separate. Queue manoeuvre execution is still incomplete and automatic queue initiation is disabled.

If a reverse destination remains unacknowledged after its original acknowledgement window, cleanup can lower its own positive speed cap to zero. It requires current vehicle/group/crew ownership, unchanged route/native command, the same applied cap and restoration baseline, and no newer Zeus, specialist or actor task. It retains the issued request and original deadlines rather than inferring rejection or replaying movement. A zero speed cap is not proof of physical braking or stationarity. Split-locality cleanup remains metadata-only.

Ordinary rear recovery prefers its existing eight-metre clearance envelope. If spatial obstruction or support prevents it, one fresh 3.5-metre option is checked. Ownership, density/scan overflow and turn-envelope failures do not trigger this retry. The selected envelope stays in the original public recovery receipt and survives owner adoption. Native BACK observes a six-metre travel limit for the long option or two metres for the short option; destination mode uses the supported point returned by the clearance observer and remains subject to path monitoring. Active checks retain remaining travel plus the original end buffer. Neither option renews the recovery budget or proves physical reversing.

Ordinary recovery retains its original stalled-position anchor across refresh, reverse, final retry and owner adoption. Returning toward the waypoint from a reversed position does not replenish the episode. Reset requires at least three metres of waypoint-distance progress beyond that original anchor, plus the existing physical movement and safety checks. Missing or malformed inherited anchors grant no reset credit. A new authored route remains a distinct intent; no waypoint is reconstructed or changed.

Queue proposals use one shared, stable crossing/yield selection. If only one participant meets the native reverse prerequisites, that participant takes the yielding role. Otherwise both owners derive the same crossing candidate from distinct network identities. Missing or ambiguous identity refuses selection. This is not right of way or consent: full current-owner, task, route and FSM checks remain required. A mirrored initiator refuses before rear-chain discovery, without commanding the selected peer. Automatic queue movement remains disabled pending its complete executor.

Shared vehicle path proposals use the same resolved parent/proxy object for support stability and water/deck checks. Bare submerged terrain, vehicle/person support, moving props, insufficient height and excessive slopes remain refused. This adds no rays or searches. Proxy-only deck behavior still needs in-game confirmation and is not a proven explanation for prior route failures.

Passing clearance keeps the complete oriented bounding-box interval for both vehicles. Its affine projection uses four model transforms per hull instead of eight and adds a small outward tolerance. Existing ahead/behind margins, live peer context, return-entry checks and traffic observations remain. Independent offline corner comparisons cover tilt, scale and asymmetric boxes; native precision and runtime performance remain in-game verification items.

Ordinary driving cap and baseline observations are local to each machine. Ownership transfer is not a replay of the old owner's cap or restoration value. A new owner evaluates current native control; public finite recovery metadata still needs matching native command and cap evidence before it can be adopted or released. Queue consent is also private and must be negotiated again after owner changes. Exact cap/command behavior across transfer remains an in-game verification item.

A retiring driving brain can withdraw its original machine-private queue consent after vehicle locality is lost. The captured original owner, group, epoch and generation must still match, and the broker authenticates the sender as an original participant. This cancellation never commands the migrated vehicle or restores speed. Native cleanup remains behind the current-owner guard; a successor consent receipt is preserved.

Passing consent uses the same original-participant cancellation rule after locality loss. A retiring driving brain cancels only its matching preparation/observations and pending, active or passive pass consent before native cleanup admission. Preparation cancellation binds brain, epoch and generation; consent cancellation binds both crew receipts to the retiring group, epoch and generation, without requiring active pass work. Successor work survives. The private metadata transaction is atomic for scheduled script callers, and the server still authenticates the original participant. Public native-leg provenance is retained for its existing current-owner cleanup; no movement is replayed.

Passing and queue observations read local owner counters only for local groups. Remote groups require the owner-stamped identity in the existing sparse driving status; missing or obsolete identity refuses admission until the current owner publishes. This metadata never substitutes for a live owner FSM or explicit consent, and private epochs are not overwritten by replication.

Queue rear-chain discovery and deferred validation use padded oriented vehicle-body gaps up to25m, rather than a fixed centre-distance cutoff. Long vehicles remain discoverable inside the existing120m query. Overlapping or unavailable rear bounds refuse cooperation. Discovery projects each of at most64 candidates once, then reuses those intervals; deferred checks project at mostfour participants. The same four-transform bounds helper supplies passing clearance. No extra world query, movement worker or automatic queue initiation is added. Bounds are conservative observation, not proof of a traversable reverse path or successful crossing.

If an exactly owned reverse is still pending cleanup at its original hard deadline, cleanup lowers its own unchanged positive cap to zero before recording an unresolved result. This also covers an unacknowledged native BACK stop after the ordinary callback ends. Crew, native command, route, cap lease and restoration baseline must remain unchanged; newer orders/caps and split locality grant no write. The unresolved receipt and original deadlines remain. Zero cap is not physical stopping proof, and expiry grants no new native STOP or route command.

Queue consent preflights the dependency leaf on its actual owner. It shares ordinary recovery's8m observation with one3.5m fallback for spatial/support obstruction only. A blocked leaf refuses VERIFY; COMMIT rechecks and requests broker release if the space has changed. Other owners may briefly hold until that release arrives. Parents are not required to have rear space before the leaf moves. No clearance or target is stored for replay: eventual native issue still requires a fresh observation, original expiry and exact command authority. Automatic queue movement remains inactive.

A steering convoy follower that is physically stopped within3m of its exact recorded endpoint may continue on fresh ordered predecessor trail once its new endpoint advances more than3m. Moving legs retain the8m refresh threshold, and a zero safety cap grants no endpoint continuation. Matching height, group, revision, epoch, crew and both native destination receipts are required. The public steering lease now includes the driver destination as well as the movement operator destination; release refuses native stop/handback after either changes. Older incomplete leases grant no native cleanup authority. This removes a code-level endpoint wait; its effect on mixed-convoy stop/start behaviour remains unverified in Arma.

Ongoing convoy movement also preserves individual driver orders. Native and steering movement receipts use eight fields, retaining the operator destination and pending request plus the driver command/destination proof. A distinct driver destination change or a newly observable STOP yields the current server revision before a pending commander goal can acknowledge; acknowledgement cannot adopt that replacement driver order. When driver and operator are the same actor, the original requested-goal acknowledgement updates the single actor proof. Internal native STOP retirement checks the distinct driver proof too. Paused audit readers require the complete acknowledged receipt and retain real physical-travel checks.

Ordinary authored infantry MOVE can now request an unlocked nearby door without starting clearance or replacing native navigation. This uses Building Combat enablement independently of the Contact toggle. On an existing CALM group tick without active danger, response or group movement ownership, one eligible actor from a rotating sixteen-member roster may probe3m along its current native goal. The first blocking House or proxy parent is inspected; building-centre distance is irrelevant. The probe plus existing door visibility checks use at mostfive rays, without a nearby-building radius query. A minimum two-second observation gap does not increase the existing group tick rate. Conditional, scripted, timed, attached and synchronized waypoints are excluded. At animation, the actor must still own the same group/epoch, have a current plain MOVE toward that waypoint, lack combat targets/reservations/external control, and approach the door within3m on the same floor. The door must lie within0.8m of the forward native-goal line and pass the existing lock and fresh visibility checks. STEALTH/CARELESS actors receive no automatic route opening. This issues no movement, route, unlock or visit/clearance command. Bent native paths and unrecognised modded door metadata may receive no assistance; inaccessible navigation and complete through-building routing remain separate gaps. Physical behaviour and cost remain unverified while audits are paused.

Clearance now recognises native INIT and REPLAN alongside PLANNING/BUSY within its existing exact-owned finite planning allowance. Partner/recovery acknowledgement still uses the original issue timestamp, two-second grace and thirty-second maximum; changing planner state renews none of them. Room retry still requires real no-progress timing and retains original attempt/episode limits. Indoor selection, escalation and clue admission also preserve native INIT rather than treating it as idle. INITFAILED/DELAY do not acquire the active-planning allowance. This aligns planner-state handling; it does not establish an observed straggler root cause or change the provisional timing without physical evidence.

Active clearance records the actual position of each native stop it issues. Room work, egress and explicit release recognise STOP only at a recorded same-floor hold; posture or speed settings alone do not grant movement authority. New owned movement retires the earlier hold. The check observes at most four stored positions without geometry queries or another scheduler. A replacement STOP at the same observable position cannot be distinguished. Completed-clearance public holds also carry each stopped actor's position. New-order handback and addon shutdown require the same spatial proof, while owner migration retains the original positions without replay. These changes do not establish coherent physical entry or exit.

Initial buddy entry connectivity is a bounded target-ranking preference. It inspects at most four ranked native nodes per pair, uses the existing sixteen-probe room callback budget and leaves its final eight probes for later physical observations when available. Blocked straight rays or exhausted preference budget retain a distinct native-node path attempt; they do not establish inaccessibility, serialise both actors on the lead, or grant room-visit credit. No new polling worker is added.

Post-clear handback retains the original hold receipt during temporary split actor/group locality for living, same-group, on-foot non-player actors still observed stopped. This grants no remote command or new stopping position. When actor locality converges, ordinary ownership, external-controller, current-task and recorded-position checks decide whether native formation return is still permitted. A changed native task retires the stale hold.

Queue execution preparation follows committed, measured zero-speed holds. Every actual participant owner validates all of its applied holds before acknowledging; the server counts owners once and rechecks simultaneous stillness under the original expiry. Preparation is metadata only. The separate acknowledged-reverse observer freezes other participant orders and poses and bounds the leaf reverse; no producer currently grants that moving phase. Queue-bound recovery journals retain original expiry and identity and cannot enter ordinary forward retry. Native queue issue, acknowledgement transition, endpoint hold, parent advance, crossing and complete handback remain unfinished, and automatic initiation remains disabled.
