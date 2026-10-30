/*
 * Author: WaldoTheWarfighter
 * Explicit attack command gates retain the original task identity, deadline and native-belief objective.
 * Native flight yields active movement and replacement admission. Exact drill-owned PATH
 * restrictions are released for fleeing/queued-care actors without issuing movement.
 * Ordinary new-bound admission rechecks main-muzzle ammunition for the surviving mover
 * minimum and at least one cover actor. Road-exit/consolidation and coordinated roles retain
 * their existing policy. A fresh ordinary bound may request one nearly-empty selected rifle's
 * native reload while a ready covering rifle remains; <=4 mover proposals, no per-sample
 * inventory poll, forced weapon selection, reload-setting change or completion claim. Rebuilt/
 * resumed bounds, crossings, consolidation, close threats and coordinated dispatch skip it.
 * Changed native MOVE destinations and STOP after a recorded MOVE yield the actor. Exact owned cover/arrival holds
 * permit the next bound; only the original two-second MOVE acknowledgement retains a prior hold.
 * Coordinated route-refresh budgets remain in the parent, one per actor/server sequence, across reconstruction.
 * Exact coordinated MOVE observations can migrate without command replay or acknowledgement grace. Initial admission and indistinguishable replacement
 * STOP over an unchanged owned hold remain limits; no native command-origin identity is available.
 * Group attack permission is acquired through OperationAttackPolicy; a refused or changed
 * policy ends admission rather than allowing unowned autonomous attack delegation.
 * Progress: bound approach and physical motion use ASL3D; arrival and recovery rejoin also
 * require the destination floor band. Recovery selects a real eligible peer, preferring its buddy,
 * rather than an average position between floors. Legacy progress conversion retains clocks.
 * Reservation policy: unknown/malformed/nonfinite actor leases remain owned through the
 * shared owner-local CortexActorMoveReserved predicate at admission and command/cleanup gates.
 * Casualty roster proposals remain isolated until current drill/operation/epoch and actor-native
 * observations pass an unscheduled publication boundary; refusal defers without renewing deadlines.
 * Main bound cover geometry is prepared before the local write block; its native movement/cover and bound journals commit
 * together only under unchanged point/roster/phase, owner/operation and actor-native observations.
 * Locality / Authority: Executes on the caller; world changes are limited to locally owned objects or groups, or to server-published state, as guarded below.
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Advances a running drill (flank, bounding advance, direct assault or coordinated bound) by one step: issue a bound, wait for arrival,
 * pause and overwatch, cross streets under smoke, and finish by holding the ground won or assaulting.
 *
 * Casualty refill admits only local actors with empty or fully typed expired movement leases;
 * unknown or malformed reservations remain owned and cannot be added to the drill roster.
 * A reserve outside the current element with an unrecorded native MOVE is also unavailable;
 * admitted participants require their original ADMISSION observation until the first own command;
 * separately verified owned native receipts retain their paths. Formation travel may retain a moving goal.
 * Reserve refill reuses bounded pair-aware element selection, keeping intact available buddies
 * together where vacancies permit, preferring eligible buddies of existing team members.
 * Same-bound casualty rebuilds retain incumbent actor destinations, progress clocks and spent
 * retries through the existing resume records; only acknowledged matching native legs skip reissue.
 * A single required vacancy may still split an unrelated reserve pair. New recruits need rifle
 * capacity on ordinary legs; reserve ranking runs only for actual vacancies. Existing actors stay enrolled.
 * Team casualty/recovery transfers prefer unpaired survivors, then intact pairs when donor
 * strength permits. Relief must bring rifle fire capacity while leaving at least one qualified
 * rifle in the donor; headcount alone cannot preserve cover. Minimum capacity may split a pair.
 * Bounds: each member gets his own spot, spread across a shallow line facing the last known enemy position. A slot on
 * water or a cliff-like side slope contracts towards the bound centre rather than stranding that soldier. Ordinary
 * bounds, the final position and the assault position are snapped to cover facing the enemy
 * (CBE_fnc_CortexFindCover); street crossings and the clearing rush are not. On movement bounds, final approaches and
 * street crossings, group-level RED pursuit is replaced by a finite YELLOW lease, but individual
 * TARGET, AUTOTARGET and AUTOCOMBAT remain enabled. Movers therefore keep acquiring, engaging and
 * reacting to visible threats while one committed doMove destination expresses CBE's tactical intent.
 * A generation-owned group attack-delegation lease prevents competing leader-issued pursuit routes.
 * CBE does not pair doMove with setDestination, clear native targets, or repeatedly fight a live ATTACK
 * command. A mover is reconsidered only after measured physical no-progress; one route refresh is allowed
 * before the actor becomes a recovery straggler and the viable element continues.
 * A RED group first receives a finite YELLOW movement lease: it remains fire-at-will, but the engine must keep
 * formation instead of creating independent ATTACK subgroups that compete with the bounds. The lease begins one
 * scheduler step before the first move, remains active for the whole manoeuvre, and is restored only if the group
 * still has the value Cortex applied. A later Zeus, waypoint or script ROE change cancels the manoeuvre and survives
 * cleanup. Movers retain automatic target acquisition and may fire while moving; the paired fire team and covering
 * squad still provide deliberate supporting fire. Movers watch the known threat direction.
 * Native COMBAT behaviour remains available throughout movement. CBE owns route and role selection,
 * while the engine owns moment-to-moment posture, target engagement and obstacle avoidance.
 * Native-task footprint guards group policy; only confirmed writes acquire restoration proof.
 * The manoeuvre group receives a finite FULL-speed lease so inherited NORMAL or LIMITED travel
 * does not make short tactical bounds crawl. Cleanup restores the prior speed only while Cortex
 * still owns FULL; a later Zeus or script speed change cancels the drill and survives cleanup.
 * Explicit ground-element drills retain their original foot roster during casualty refill;
 * unrelated dismounted crew cannot be silently recruited.
 * Recovery anchors are restricted to the current surviving main element; an empty fire team
 * falls back within that element, never to a mounted or nonparticipant native group leader.
 * Bound handoff never issues doFollow: formation return competes with individual destinations.
 * No explicit attack target is assigned to movers, because that replaced bound destinations in live QA.
 * The lease never uses BLUE or disables firing. Same-frame BLUE/reset experiments did not reliably cancel stale
 * attack orders and briefly silenced the base of fire; they are intentionally not used.
 * Covering and arrived actors receive doStop without disabling PATH, so the following committed move can
 * begin immediately and external orders never inherit a frozen actor. A bound completes when every member
 * is within 3 m of his spot, or after
 * six seconds when at least two soldiers and 60 percent of the assigned element have physically arrived.
 * A remaining soldier who is still making physical progress receives up to six additional seconds
 * from the first physical quorum, capped by the original bound deadline, to finish the bound.
 * That server-time expiry survives owner migration and same-bound roster reconstruction. This short, progress-driven grace avoids turning an active mover into a recovery
 * chase while never holding the element for an actor who has actually stopped.
 * Remaining actors become bounded recovery stragglers and keep moving toward their element; they are
 * never counted as arrived or teleported. CBE_AIPass_Flank_BoundTimeout limits stationary time; four times that value is the absolute bound limit. Stationary movement ends as STALLED; the absolute limit ends as TIME_LIMIT, never arrival. Handoffs occur as soon as physical arrival is established. CBE_AIPass_Flank_BoundPause is an
 * optional deliberate overwatch interval (default zero), never an internal scheduling requirement.
 * Road smoke is dispatched opportunistically without holding the crossing for an animation or bloom.
 * Final, clearing and consolidation transitions use the same optional interval; coordinated bounds
 * already have a covering squad and therefore never add it. A zero-duration handoff is requeued at the
 * next shared-scheduler opportunity instead of inheriting the ordinary 1.5 second observation cadence.
 * Final assault (CBE_AIPass_Assault_Enable): after a flank or advance hold,
 * if the enemy is believed within CBE_AIPass_Assault_Range of the element and morale is STEADY,
 * the whole viable element reaches its assault position and clears through. The behaviour profile's
 * assaultChance controls optional grenade preparation, not whether an enabled, successful manoeuvre
 * arbitrarily abandons its assault transition. One member may throw a fragmentation grenade
 * (CBE_fnc_CortexThrowGrenade, never near friendlies). The approach uses a covered spot
 * 20 m short of the reported enemy and clears 20 m beyond that fixed objective, while the base of fire keeps suppressing. Formation commitment issues the covered approach immediately. Arrival issues the clear-through immediately, whether or not a grenade throw was queued. A queued frag is an opportunistic action: its own next-frame safety check may cancel it, but deployment never gates the assault or aborts movement. The assault axis stays fixed through the crossing; water destinations are rejected.
 * Consolidation: a flank brings its covering element forward even when no final assault
 * is selected; the manoeuvre element holds its gained position. After clearing through,
 * its surviving on-foot covering element moves
 * to a line 12 m beyond the fixed objective while the assault element holds. The same
 * arrival, retry, loss, Zeus and locality rules apply; unresolved stragglers remain PARTIAL.
 * Advance has already moved both elements through the objective.
 * Ending: a completed drill leaves the element holding the ground it took. Members rejoin formation
 * when the leader comes within 30 m, when the squad returns to CALM, or when it retreats . The drill aborts, with members following the leader again, when the group
 * leaves CONTACT, Zeus takes the group (CBE_fnc_CortexZeusHeld), or half the element is lost. It
 * also ends, holding ground, when an enemy is believed within 30 m and assault is disabled. Flanks move only their selected element. Successive advances exchange two elements,
 * including the leader in the second element, only after physical arrival.
 * Coordinated bounds face the matching server role objective even before personal sight;
 * a stale local contact position cannot replace that shared objective.
 * Locality and authority: scheduler job on the group owner.
 *
 * Review contract: Every step rechecks full group eligibility and its behaviour switch. Existing jobs stop after exclusion, remote control or a live disable.
 *
 * Repeat/JIP: each job rechecks its drill token, locality and gates; completion publishes the real ending reason.
 * Every authenticated step renews its heartbeat and standalone movement lease. GroupTick ends a silent
 * controller through CortexFlankEnd, so scheduler loss cannot leave actors restricted indefinitely.
 * A stationary mover receives at most one route refresh per bound after eight seconds of physical
 * no-progress. Native ATTACK is observed for diagnostics but is never treated as an immediate failure.
 * The same bounded retries also detect a return to an unchanged original group waypoint when one
 * actually exists. Contact advances with no authored waypoint keep an empty snapshot.
 * They never change that waypoint, and the eligibility check gives Zeus priority first.
 * Retries never reset the physical-progress clock or count as arrival. A viable majority
 * (at least two movers and 60 percent of the original element) may continue past blocked
 * actors. Separated actors receive one rejoin destination, with an eight-second observation window.
 * Each actor receives one recovery attempt; an unresolved actor is removed from the active element
 * and cannot stall the remaining manoeuvre. Ownership changes cancel this local recovery.
 * Casualties are reassessed only on this group job. A flank draws replacements from surviving
 * uncommitted squad members. Advance and coordinated-bound fire teams first take unassigned
 * survivors, then rebalance only when one team falls below two. Recovery is also checked against the
 * fire team which is about to move: a covering team with more than two available soldiers reinforces
 * an under-strength moving team, a three-person survivor element may instead use two movers and one covering soldier.
 * Otherwise it waits only for actual pending recovery instead of sending one soldier alone. One unsuccessful recovery order ends only an under-strength bound rather than waiting forever.
 * A casualty during movement restarts the same bound so the surviving formation cannot inherit another
 * soldier's destination.
 * Arguments:
 * 0: job <HASHMAP> - current FSM-owned job with group, drillToken, ownerEpoch,
 * operationGeneration and fsmHandle; direct reconstructed jobs have no movement authority.
 *
 * Return Value:
 * Number - seconds until the next step, or -1 when the drill ended
 *
 * Example:
 * [_group getVariable ["CBE_Cortex_DrillFSMJob",createHashMap]] call CBE_fnc_CortexFlankStep;
 * Result: the element moves one stage further.
 *
 * Current caller: the finite tacticalDrill FSM launched by CBE_fnc_CortexDrillStart.
 */

params [["_job", createHashMap, [createHashMap]]];
private _group = _job getOrDefault ["group", grpNull];
if (isNull _group || {!local _group}) exitWith {-1};
private _state = _group getVariable ["CBE_AIPass_State", createHashMap];
private _drill = _state getOrDefault ["drill", createHashMap];
if (count _drill == 0) exitWith {-1};
// A cancelled job may still be queued when another drill starts on this group.
// Retire it without releasing or advancing the replacement drill.
private _token = _job getOrDefault ["drillToken",""];
if (_token == "" || {_token != (_drill getOrDefault ["token",""])}) exitWith {-1};
private _end = {
    [_group, _state, _this, _token] call CBE_fnc_CortexFlankEnd;
    -1
};
// A surviving callback is not an alternate lifecycle controller. Only the registered
// job of this exact owner/operation/FSM may advance; an old job cannot retire a successor.
if (_job getOrDefault ["cancelled",false]
    || {(_group getVariable ["CBE_Cortex_DrillFSMJob",createHashMap]) isNotEqualTo _job}
    || {(_job getOrDefault ["ownerEpoch",-1]) != (_drill getOrDefault ["ownerEpoch",-2])}
    || {(_job getOrDefault ["operationGeneration",-1]) != (_drill getOrDefault ["operationGeneration",-2])}) exitWith {-1};
private _executor=_job getOrDefault ["fsmHandle",-1];
private _executorRecord=_group getVariable ["CBE_Cortex_DrillFSM",[]];
if (count _executorRecord != 2 || {(_executorRecord select 0) != _token}
    || {(_executorRecord select 1) isNotEqualTo _executor}) exitWith {-1};
if (!(_executor isEqualType 0) || {!finite _executor} || {_executor < 0}
    || {completedFSM _executor}) exitWith {"FSM_EXECUTOR_ENDED" call _end};
// Explicit Press attack shares this executor, not a new timer/controller. Its original
// owner-local deadline is checked before policy writes, planning waits or role movement.
private _explicitOrder=_drill getOrDefault ["explicitOrder",[]];
private _pointObjective=_drill getOrDefault ["pointObjective",[]];
private _pointOrder=_pointObjective isNotEqualTo [];
if (_pointOrder && {!(_pointObjective isEqualType []) || {count _pointObjective != 2}
    || {!((_pointObjective select 0) isEqualType [])} || {count (_pointObjective select 0) != 3}
    || {(_pointObjective select 0) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!((_pointObjective select 1) isEqualType 0)} || {!finite (_pointObjective select 1)}
    || {(_pointObjective select 1) < 5} || {(_pointObjective select 1) > 25}
    || {(_drill getOrDefault ["enemyPos",[]]) isNotEqualTo (_pointObjective select 0)}
    || {count _explicitOrder != 4}}) exitWith {"INVALID_POINT_ORDER" call _end};
if (_pointOrder) then {_pointObjective=[+(_pointObjective select 0),_pointObjective select 1]};
private _explicitValid=_explicitOrder isEqualType [] && {count _explicitOrder == 4}
    && {(_explicitOrder select 0) isEqualType 0} && {finite (_explicitOrder select 0)}
    && {(_explicitOrder select 1) == (_group getVariable ["CBE_AIPass_Epoch",-1])}
    && {(_explicitOrder select 2) == (_drill getOrDefault ["operationGeneration",-2])}
    && {(_explicitOrder select 3) == _token};
if (_explicitOrder isNotEqualTo [] && {!_explicitValid}) exitWith {"INVALID_EXPLICIT_TASK" call _end};
if (count _explicitOrder == 4 && {time >= (_explicitOrder select 0)}) exitWith {"EXPLICIT_TIME_LIMIT" call _end};
private _explicitGate=if ((_drill getOrDefault ["type",""]) == "ADVANCE") then {
    "CBE_AIPass_Advance_Enable"
} else {"CBE_AIPass_Assault_Enable"};
if (count _explicitOrder == 4 && {!(missionNamespace getVariable ["CBE_AIPass_Active",false])
    || {!((_state getOrDefault ["phase",""]) in ["CALM","CONTACT"])}
    || {!_pointOrder && {!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)}}
    || {!([_group,_explicitGate,true] call CBE_fnc_CortexFeatureEnabled)}}) exitWith {"ABORT" call _end};
// A waypoint edit may leave its index and position intact. Preserve conditions,
// scripts, attachments and synchronisation through the same frozen authored receipt.
private _authoredOrder=_drill getOrDefault ["authoredOrder",[]];
if (_authoredOrder isNotEqualTo [] && {
    _authoredOrder isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)
}) exitWith {"REPLACED" call _end};
// The generic lifecycle owns interruption and physical-progress accounting.  The drill remains
// responsible for its own finite bound recovery, but it cannot continue after a replacement
// order, Zeus intervention, ownership migration or external controller handover.
private _operationGeneration=_drill getOrDefault ["operationGeneration",-1];
private _operationEndReason="";
if (_operationGeneration >= 0) then {
    private _operationStale=missionNamespace getVariable ["CBE_AIPass_Flank_BoundTimeout",25];
    private _operationStatus=[_group,_operationGeneration,3,_operationStale] call CBE_fnc_OperationStep;
    if (_operationStatus in ["LOST_OWNER","ZEUS","EXTERNAL","REPLACED","STALLED"]
        && {_operationStatus != "STALLED" || {!((_drill getOrDefault ["stage",""]) in ["START","MOVE"])}}) then {_operationEndReason=_operationStatus};
    // MOVE has actor-specific retry/replacement and a hard bound deadline below. Aggregate
    // no-progress must not pre-empt that finite recovery path or pretend that progress occurred.
};
if (_operationEndReason != "") exitWith {_operationEndReason call _end};
// External control and replacement orders win before any mode or movement mutation.
if !([_group] call CBE_fnc_CortexIsEligible) exitWith {"OWNERSHIP_LOST" call _end};
private _intentTarget=_drill getOrDefault ["target",objNull];
// Retain a clear-through after a casualty, but surrender or a side change ends hostile intent.
// Never continue a committed approach against a now-protected object merely because its old
// native position remains in the drill's route record.
if (!isNull _intentTarget && {captive _intentTarget
    || {_intentTarget getVariable ["ace_captives_isSurrendering",false]}
    || {_intentTarget getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _group) getFriend (side _intentTarget) >= 0.6}}) exitWith {
    "TARGET_NO_LONGER_HOSTILE" call _end
};

// A queued drill can run after a new direct owner appears. Recheck only at actual command
// writes; route scoring and progress accounting remain bounded and do not issue movement.
// These local receipts belong to this already-validated token/epoch/generation only.
// Checkpoints may carry acknowledged coordinated MOVE observations. No acknowledgement grace migrates.
private _recordNativeCommand={
    params ["_actor","_kind",["_goal",[],[[]]]];
    private _commands=_drill getOrDefault ["nativeCommands",createHashMap];
    private _key=netId _actor;
    if (count _commands >= 64 && {!(_key in _commands)}) then {
        {private _row=_commands get _x;
            if (isNull (_row select 0) || {!alive (_row select 0)} || {group (_row select 0) != _group}) then {_commands deleteAt _x};
        } forEach (keys _commands);
    };
    if (count _commands >= 64 && {!(_key in _commands)}) exitWith {_drill set ["nativeCommandsFull",true]};
    private _previous=_commands getOrDefault [_key,[]];
    // Only our previous covering/arrival hold can survive the short native MOVE acknowledgement.
    private _priorHold=if (_kind == "MOVE" && {count _previous == 7} && {(_previous select 1) == "HOLD"}) then {
        _previous select [0,4]
    } else {[]};
    _commands set [_key,[_actor,_kind,+(expectedDestination _actor),formLeader _actor,serverTime+2,_priorHold,+_goal]];
    _drill set ["nativeCommands",_commands];
};
// One refresh per actor/server bound survives child reconstruction. This shares the
// parent operation, not a second retry controller; standalone policy is unchanged.
private _supportRetryAvailable={
    params ["_retryActor"];
    if ((_drill getOrDefault ["supportToken",""]) == "") exitWith {true};
    private _retryParent=_group getVariable ["CBE_Operation",createHashMap];
    private _budget=_retryParent getOrDefault ["boundRetryAttempts",createHashMap];
    if (!(_budget isEqualType createHashMap) || {count _budget > 64}
        || {count _budget >= 64 && {!(netId _retryActor in _budget)}}) exitWith {false};
    if (!(netId _retryActor in _budget)) exitWith {true};
    private _used=_budget get (netId _retryActor);
    _used isEqualType [] && {count _used == 2}
        && {_used findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} < 0}
        && {(_used select 0) < (_drill get "supportSequence") || {
            (_used select 0) == (_drill get "supportSequence") && {(_used select 1) < 1}
        }}
};
private _nativeCommandAvailable={
    params ["_actor"];
    private _command=currentCommand _actor;
    if !(_command in ["STOP","MOVE"]) exitWith {true};
    private _row=(_drill getOrDefault ["nativeCommands",createHashMap]) getOrDefault [netId _actor,[]];
    // Natural starts preflight STOP and may transfer only exact completed CBE holds.
    // Coordinated and resumed starts transfer only their exact separately validated HOLD proof.
    if (_row isEqualTo []) exitWith {
        !(_drill getOrDefault ["nativeCommandsFull",false])
            && {_command != "MOVE"}
            && {_command != "STOP" || {!(_drill getOrDefault ["nativeAdmissionChecked",false])}}
    };
    if (count _row != 7 || {(_row select 0) != _actor}) exitWith {false};
    if ((_row select 1) == "ADMISSION") exitWith {
        [_actor,_row] call CBE_fnc_CortexDrillNativeCurrent
    };
    private _native=expectedDestination _actor;
    private _acknowledging=serverTime <= (_row select 4);
    if (_command == "MOVE") exitWith {
        private _position=_native param [0,[],[[]]];
        private _goal=_row select 6;
        private _owned=(_row select 1) == "MOVE" && {count _position == 3} && {count _goal == 3}
            && {_position vectorDistance _goal <= 0.25};
        // Native command/destination acknowledgement may lag our admitted write. Only the
        // unchanged sampled native receipt can bridge that original two-second interval.
        (_owned || {_acknowledging && {_native isEqualTo (_row select 2)}})
            && {formLeader _actor == (_row select 3)}
    };
    private _hold=if ((_row select 1) == "HOLD") then {_row select [0,4]} else {
        if (_acknowledging) then {_row select 5} else {[]}
    };
    count _hold == 4 && {(_hold select 0) == _actor} && {(_hold select 1) == "HOLD"}
        && {_native isEqualTo (_hold select 2)
            || {(_row select 1) == "MOVE" && {_native isEqualTo (_row select 2)}}}
        && {formLeader _actor == (_hold select 3)
            || {(_row select 1) == "MOVE" && {formLeader _actor == (_row select 3)}}}
};
private _actorTaskFree={
    params ["_actor"];
    private _free=!([_actor] call CBE_fnc_CortexActorMoveReserved);
    _free && {[_actor] call _nativeCommandAvailable} && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!fleeing _actor}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {local _actor} && {!isPlayer _actor} && {group _actor == _group} && {isNull objectParent _actor}
        && {isNull remoteControlled _actor}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
private _mayIssueMovement = {
    params ["_actor"];
    !([_group] call CBE_fnc_CortexExternalTakeover) && {[_actor] call _actorTaskFree}
        && {(_drill getOrDefault ["supportToken",""]) == "" || {
            serverTime < (_drill getOrDefault ["supportDeadline",-1])
                && {(_drill getOrDefault ["supportClock",[]]) isEqualTo
                    (_group getVariable ["CBE_Cortex_SupportRoleDeadline",[]])}
        }}
};
// The original server clock caps every child/owner lifetime. A transient missing
// or successor receipt suspends new commands without renewing this finite deadline.
private _supportExpired=false;private _supportAwaitClock=false;
if ((_drill getOrDefault ["supportToken",""]) != "") then {
    private _supportUntil=_drill getOrDefault ["supportDeadline",-1];
    _supportExpired=!(_supportUntil isEqualType 0) || {!finite _supportUntil} || {serverTime >= _supportUntil};
    _supportAwaitClock=(_drill getOrDefault ["supportClock",[]]) isNotEqualTo
        (_group getVariable ["CBE_Cortex_SupportRoleDeadline",[]]);
};
if (_supportExpired) exitWith {"TIME_LIMIT" call _end};
if (_supportAwaitClock) exitWith {_drill set ["lastStep",time];0.25};
// A committed bound owns movement, not weapon aiming. Prevent the native leader from
// delegating a competing ATTACK route while TARGET/AUTOTARGET/FIREWEAPON remain untouched.
// The common operation consumes this exact-value lease on release; an external policy edit
// ends the drill rather than being forced back on every callback.
private _movementOperation=_group getVariable ["CBE_Operation",createHashMap];
if (_operationGeneration >= 0 && {(_movementOperation getOrDefault ["generation",-1]) == _operationGeneration}) then {
    private _policy=[_group,_movementOperation,false] call CBE_fnc_OperationAttackPolicy;
    if !(_policy in ["ACQUIRED","OWNED"]) then {
        _operationEndReason=if (_policy == "POLICY_CHANGED") then {"ATTACK_POLICY_CHANGED"} else {"ATTACK_POLICY_REFUSED"};
    };
};
if (_operationEndReason != "") exitWith {_operationEndReason call _end};
// YELLOW preserves fire-at-will while discouraging independent RED pursuit subgroups. Give the
// engine one scheduler step to settle the group mode before issuing the committed destination.
private _groupModeLease = _drill getOrDefault ["groupCombatMode",[]];
private _groupSpeedLease = _drill getOrDefault ["groupSpeedMode",[]];
// Posture permission is not movement permission. A protected nonparticipant must not
// veto healthy movers; only a native write attempted but unconfirmed needs settling.
private _policyReady=true;
private _modeSettling=false;
isNil {
    if (!([_group] call CBE_fnc_CortexGroupPostureTaskAvailable)) exitWith {};
    _policyReady=true;
    if (_groupModeLease isEqualTo [] && {combatMode _group == "RED"}) then {
        _group setCombatMode "YELLOW";
        if (combatMode _group == "YELLOW") then {
            _drill set ["groupCombatMode",["RED","YELLOW"]];
            _groupModeLease=_drill get "groupCombatMode";
        } else {_policyReady=false};
        _modeSettling=true;
    };
    if (!_modeSettling && {_groupSpeedLease isEqualTo []} && {speedMode _group != "FULL"}) then {
        private _priorSpeed=speedMode _group;
        _group setSpeedMode "FULL";
        if (speedMode _group == "FULL") then {
            _drill set ["groupSpeedMode",[_priorSpeed,"FULL"]];
            _groupSpeedLease=_drill get "groupSpeedMode";
        } else {_policyReady=false};
    };
};
if (!_policyReady || {_modeSettling}) exitWith {0.25};
if (_groupModeLease isNotEqualTo [] && {combatMode _group != (_groupModeLease select 1)}) exitWith {
    "ROE_CHANGED" call _end
};
if (_groupSpeedLease isNotEqualTo [] && {speedMode _group != (_groupSpeedLease select 1)}) exitWith {
    "SPEED_CHANGED" call _end
};
private _supportToken=_drill getOrDefault ["supportToken",""];
private _support=_supportToken != "";
private _supportRole=_group getVariable ["CBE_Cortex_SupportRole",[]];
private _supportValid=_support && {count _supportRole == 5}
    && {(_supportRole select 0) == _supportToken}
    && {(_supportRole select 1) == (_drill get "supportSequence")}
    && {(_supportRole select 2) == "MOVE"}
    && {_state getOrDefault ["assaulting",false]};
private _gate=if (_support) then {"CBE_AIPass_CoordinatedAssault_Enable"} else {
    switch (_drill getOrDefault ["type","FLANK"]) do {
        case "ADVANCE": {"CBE_AIPass_Advance_Enable"};
        case "ASSAULT": {"CBE_AIPass_Assault_Enable"};
        default {"CBE_AIPass_Flank_Enable"};
    }
};
if (!(missionNamespace getVariable ["CBE_AIPass_Active", false])
    || {if (_support) then {!_supportValid} else {
        if (count _explicitOrder == 4) then {
            !((_state getOrDefault ["phase",""]) in ["CALM","CONTACT"])
                || {!_pointOrder && {!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)}}
        } else {(_state getOrDefault ["phase",""]) != "CONTACT"}
    }}
    || {!([_group,_gate,true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {"ABORT" call _end};
// This callback is the drill's liveness heartbeat. Standalone drills also renew their
// movement ownership instead of relying on one fixed five-minute lease. GroupTick uses
// the heartbeat to release every owned PATH/behaviour change if this job disappears or
// scheduler pressure prevents it from running for a bounded interval.
_drill set ["lastStep",time];
private _movementLease=_state getOrDefault ["movementLease",[]];
if (count _movementLease == 2 && {(_movementLease select 0) == "TACTICAL_DRILL"}) then {
    _state set ["movementLease",["TACTICAL_DRILL",time+90]];
    [_group,"TACTICAL_DRILL",true,serverTime+90] call CBE_fnc_CortexOwnershipLease;
};
// Rebuild depleted manoeuvre elements from the surviving squad inside this existing group job.
// There is no casualty event handler or per-unit scheduler. A change during a live bound restarts
// that bound from the same route point so spot indexes cannot drift after a casualty.
// A native task must not inherit our cover PATH restriction. This callback has already
// validated the current drill/operation/owner; restoration is not a new movement order.
// Keep unconfirmed records for normal cleanup and never touch another actor controller.
private _nativeTaskDisabled=[];
{
    _x params ["_actor","_feature"];
    if (_feature == "PATH" && {alive _actor} && {local _actor} && {group _actor == _group}
        && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {fleeing _actor || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}}) then {
        _actor enableAI "PATH";
        if !(_actor checkAIFeature "PATH") then {_nativeTaskDisabled pushBack _x};
    } else {_nativeTaskDisabled pushBack _x};
} forEach (_drill getOrDefault ["disabled",[]]);
_drill set ["disabled",_nativeTaskDisabled];
private _ownedPathUnits=(_drill getOrDefault ["disabled",[]]) select {(_x select 1) == "PATH"} apply {_x select 0};
private _rosterEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _unavailable=+((_group getVariable ["CBE_Operation",createHashMap]) getOrDefault ["unavailable",[]]);
private _entryTeams=(_drill getOrDefault ["teams",[]]) apply {+_x};
private _entryUnits=+(_drill get "units");
private _entryPhase=[_drill getOrDefault ["stage",""],_drill getOrDefault ["index",0],_drill getOrDefault ["teamTurn",0]];
private _fitSquad=(units _group) select {!(_x in _unavailable)} select {[_x] call CBE_fnc_CortexCombatEffective && {local _x}
    && {isNull objectParent _x} && {group _x == _group} && {_x checkAIFeature "MOVE"}
    && {_x checkAIFeature "PATH" || {_x in _ownedPathUnits}} && {[_x] call _actorTaskFree}};
if (_drill getOrDefault ["elementScoped",false]) then {
    private _elementRoster=_drill getOrDefault ["elementRoster",[]];
    _fitSquad=_fitSquad select {_x in _elementRoster};
};
private _rosterNative=_fitSquad apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x]};
private _teams=_entryTeams apply {+_x};
private _desiredStrength=_drill getOrDefault ["desiredStrength",count (_drill get "units")];
private _reinforcements=[];
// Prefer an orphan over breaking a surviving buddy pair. If only intact pairs remain,
// transfer a whole pair when the donor can retain its required cover; otherwise surviving
// movement/cover capacity takes priority over cohesion. Selection never issues actor commands.
private _buddyPairs=_group getVariable ["CBE_CombatPairs",[]];
if !(_buddyPairs isEqualType []) then {_buddyPairs=[]};
_buddyPairs=_buddyPairs select [0,16];
// Same-bound casualty rebuilds reuse the existing resume format. Preserve actor-addressed
// destinations, physical clocks and spent retries before clearing index-addressed arrays.
// This is local data only; issue still revalidates the exact native leg before skipping a write.
private _captureBound={
    private _oldMovers=_drill getOrDefault ["movers",[]];
    private _oldSpots=_drill getOrDefault ["spots",[]];
    private _oldProgress=_drill getOrDefault ["progress",[]];
    private _oldRetries=_drill getOrDefault ["retries",[]];
    private _savedSpots=[];private _savedProgress=[];private _savedRetries=[];private _nativeMoves=[];
    {
        private _actor=_x;
        private _oldIndex=_forEachIndex;
        private _spot=_oldSpots param [_oldIndex,[],[[]]];
        if (!isNull _actor && {count _spot == 3}) then {
            _savedSpots pushBack [_actor,+_spot];
            _nativeMoves pushBack _actor;
            private _row=_oldProgress param [_oldIndex,[],[[]]];
            if (count _row == 4 && {(_drill getOrDefault ["progressCoordinates",""]) == "ASL3D"}) then {
                _savedProgress pushBack [_actor,serverTime+(_row select 1)-time,
                    serverTime+(_row select 3)-time,_row select 0,+(_row select 2)];
            };
            private _retry=_oldRetries param [_oldIndex,[],[[]]];
            if (count _retry == 2) then {_savedRetries pushBack [_actor,_retry select 0]};
        };
    } forEach (_oldMovers select [0,64]);
    _drill set ["resumeSpots",_savedSpots];
    _drill set ["resumeProgress",_savedProgress];
    _drill set ["resumeRetries",_savedRetries];
    _drill set ["resumeNativeMoves",_nativeMoves];
};
private _selectRelief={
    params ["_donors","_keep"];
    if (count _donors <= _keep) exitWith {[]};
    // Roster members already passed current actor-task/fitness gates. Apply the same rifle
    // ammunition/ROE permission policy as next-bound admission before splitting their roles.
    private _leg=(_drill getOrDefault ["points",[]]) param [_drill getOrDefault ["index",0],[]];
    private _exitLeg=(_leg param [1,"",[""]]) in ["CROSS_FAR","CONSOLIDATE"];
    // Preserve the existing dry-actor road-exit/consolidation exemption: leaving danger
    // is movement accounting, not admission of a fresh fire-and-manoeuvre bound.
    private _fireReady=if (_exitLeg) then {+_donors} else {
        _donors select {unitCombatMode _x in ["YELLOW","RED"]
            && {_x checkAIFeature "FIREWEAPON"} && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}}
    };
    if (count _fireReady < 2) exitWith {[]};
    private _intact=[];
    private _paired=[];
    {
        if (_x isEqualType [] && {count _x == 2}
            && {(_x select 0) != (_x select 1)}
            && {_x findIf {!(_x in _donors) || {_x in _paired}} < 0}) then {
            _intact pushBack _x;
            _paired append _x;
        };
    } forEach _buddyPairs;
    private _orphan=_donors findIf {!(_x in _paired) && {_x in _fireReady}};
    if (_orphan >= 0) exitWith {[_donors select _orphan]};
    if (count _donors-_keep >= 2) then {
        // A whole pair may consume every useful rifle even while dry actors satisfy headcount.
        _intact=_intact select {(_x arrayIntersect _fireReady) isNotEqualTo []
            && {(_fireReady-_x) isNotEqualTo []}};
    } else {_intact=[]};
    if (_intact isNotEqualTo []) exitWith {+(_intact select 0)};
    // Preserve one rifle in the donor even when cohesion has to yield to minimum capacity.
    [_fireReady select ((count _fireReady)-1)]
};
private _rankCandidates={
    params ["_candidates"];
    // Reserve selection must honour finite actor tasks before the drill mutates its own roster;
    // the later shared operation roster check cannot undo a carrier already added to a fire team.
    // These are unassigned replacements, so no current drill cover/arrival hold grants a STOP override.
    _candidates=_candidates select {
        private _reservationFree=!([_x] call CBE_fnc_CortexActorMoveReserved);
        _reservationFree && {currentCommand _x != "STOP"}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _refillLeg=(_drill getOrDefault ["points",[]]) param [_drill getOrDefault ["index",0],[]];
    if !((_refillLeg param [1,"",[""]]) in ["CROSS_FAR","CONSOLIDATE"]) then {
        _candidates=_candidates select {unitCombatMode _x in ["YELLOW","RED"]
            && {_x checkAIFeature "FIREWEAPON"} && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}};
    };
    private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
    if (isNull _anchor) then {_anchor=leader _group};
    private _rifles=_candidates select {!(([_x] call CBE_fnc_CortexUnitRole) in ["MG","AT","LEADER"])};
    private _supportRoles=_candidates select {!(_x in _rifles) && {_x != _anchor}};
    _rifles+_supportRoles+(_candidates select {_x == _anchor})
};
private _units=[];
if (_teams isEqualTo []) then {
    _units=(_drill get "units") select {_x in _fitSquad};
    private _candidates=if (count _units < _desiredStrength) then {[_fitSquad-_units] call _rankCandidates} else {[]};
    while {count _units < _desiredStrength && {_candidates isNotEqualTo []}} do {
        private _vacancies=(_desiredStrength-count _units) min 5;
        private _relief=[_group,_candidates select [0,16],_vacancies,1,_units select [0,16]] call CBE_fnc_CombatElementSelect;
        if (_relief isEqualTo []) exitWith {};
        {
            _units pushBack _x;
            _reinforcements pushBack ["MANOEUVRE",netId _x];
        } forEach _relief;
        _candidates=_candidates-_relief;
    };
} else {
    _teams=_teams apply {_x select {_x in _fitSquad}};
    private _assigned=[];
    {_assigned append _x} forEach _teams;
    private _desiredSizes=_drill getOrDefault ["teamSizes",_teams apply {count _x}];
    private _needsRefill=false;
    {
        if (count _x < (_desiredSizes param [_forEachIndex,count _x])) exitWith {_needsRefill=true};
    } forEach _teams;
    private _candidates=if (_needsRefill) then {[_fitSquad-_assigned] call _rankCandidates} else {[]};
    {
        private _team=_x;
        private _desired=_desiredSizes param [_forEachIndex,count _team];
        while {count _team < _desired && {_candidates isNotEqualTo []}} do {
            private _teamIndex=_forEachIndex;
            private _vacancies=(_desired-count _team) min 5;
            private _relief=[_group,_candidates select [0,16],_vacancies,1,_team select [0,16]] call CBE_fnc_CombatElementSelect;
            if (_relief isEqualTo []) exitWith {};
            {
                _team pushBack _x;
                _reinforcements pushBack [format ["TEAM_%1",_teamIndex+1],netId _x];
            } forEach _relief;
            _candidates=_candidates-_relief;
        };
    } forEach _teams;
    if (count _teams == 2) then {
        private _first=_teams select 0;
        private _second=_teams select 1;
        if (count _first < 2 && {count _second > 2}) then {
            {
                private _replacement=_x;
                _second deleteAt (_second find _replacement);
                _first pushBack _replacement;
                _reinforcements pushBack ["TEAM_1_REBALANCE",netId _replacement];
            } forEach ([_second,2] call _selectRelief);
        };
        if (count _second < 2 && {count _first > 2}) then {
            {
                private _replacement=_x;
                _first deleteAt (_first find _replacement);
                _second pushBack _replacement;
                _reinforcements pushBack ["TEAM_2_REBALANCE",netId _replacement];
            } forEach ([_first,2] call _selectRelief);
        };
    };
    {_units append _x} forEach _teams;
    _units=_units arrayIntersect _units;
};
// Candidate selection prepares private arrays before local publication. Do not publish a roster,
// transition or replacement history through a superseded task/native actor observation.
private _rosterCommitted=false;
isNil {
    private _liveState=_group getVariable ["CBE_AIPass_State",createHashMap];
    private _liveDrill=_liveState getOrDefault ["drill",createHashMap];
    private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
    if (!local _group || {_rosterEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {_liveState isNotEqualTo _state} || {(_liveDrill getOrDefault ["token",""]) != _token}
        || {(_liveDrill getOrDefault ["teams",[]]) isNotEqualTo _entryTeams}
        || {(_liveDrill getOrDefault ["units",[]]) isNotEqualTo _entryUnits}
        || {[_liveDrill getOrDefault ["stage",""],_liveDrill getOrDefault ["index",0],_liveDrill getOrDefault ["teamTurn",0]] isNotEqualTo _entryPhase}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}
        || {!([_group,_gate,true] call CBE_fnc_CortexFeatureEnabled)}
        || {if (_support) then {!(_liveState getOrDefault ["assaulting",false])} else {
            (_liveState getOrDefault ["phase",""]) != "CONTACT"
        }}
        || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {_support && {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _supportRole}}
        || {_operationGeneration >= 0 && {
            (_liveOperation getOrDefault ["generation",-2]) != _operationGeneration
                || {(_liveOperation getOrDefault ["ownerEpoch",-1]) != _rosterEpoch}
                || {(_liveOperation getOrDefault ["phase",""]) == "CANCELLED"}
                || {(_liveOperation getOrDefault ["unavailable",[]]) isNotEqualTo _unavailable}
        }}
        || {_units findIf {!([_x] call _actorTaskFree) || {!(_x checkAIFeature "MOVE")}
            || {!(_x checkAIFeature "PATH") && {!(_x in _ownedPathUnits)}}} >= 0}
        || {_rosterNative findIf {
            _x params ["_actor","_command","_destination","_leader"];
            currentCommand _actor != _command || {(expectedDestination _actor) isNotEqualTo _destination}
                || {formLeader _actor != _leader}
        } >= 0}) exitWith {};
// New reserves freeze their pre-command observation under this same roster commit.
// Never replace a retained original row when rebalancing or rebuilding a bound.
private _admissions=_drill getOrDefault ["nativeCommands",createHashMap];
{
    if (!(netId _x in _admissions) && {count _admissions < 64}) then {
        _admissions set [netId _x,[_x,"ADMISSION",+(expectedDestination _x),formLeader _x,-1,[],[currentCommand _x]]];
    };
} forEach _reinforcements;
_drill set ["nativeCommands",_admissions];
_drill set ["teams",_teams];
_drill set ["units",_units];
if (_operationGeneration >= 0) then {
    // The drill's live units are the desired operation participants, not an exclusion list. Passing
    // them as excluded removed the whole active element from physical-progress accounting and could
    // make the operation appear leader-only or stalled after an otherwise valid casualty rebalance.
    // Exclude actors outside the committed live element, rather than admitting unrelated
    // security or support actors whose movement could mask a stalled bound.
    [_group,_operationGeneration,count _units,(units _group)-_units] call CBE_fnc_RebalanceRoles;
};
if (_reinforcements isNotEqualTo []) then {
    private _history=_group getVariable ["CBE_Cortex_DrillReinforcements",[]];
    _history pushBack [serverTime,_drill getOrDefault ["type",""],_drill getOrDefault ["index",-1],_reinforcements];
    // Diagnostics must not grow the public payload for a long-lived casualty/recovery operation.
    // Current participants remain authoritative; retain only the latest replacement transitions.
    if (count _history > 32) then {_history=_history select [(count _history)-32,32]};
    _group setVariable ["CBE_Cortex_DrillReinforcements",_history,true];
    if ((_drill getOrDefault ["stage",""]) == "MOVE") then {
        call _captureBound;
        [_group,_drill,"START","CASUALTY_REINFORCEMENT"] call CBE_fnc_CortexDrillSetStage;
        _drill set ["spots",[]];
        _drill set ["boundStart",time];
    };
};
_rosterCommitted=true;
};
// Reconsider from fresh observations without recalling actors, releasing a successor or
// renewing progress/deadlines. A replaced token retires at the next normal callback entry.
if (!_rosterCommitted) exitWith {0.25};
// Shared admission for small no-geometry helper transactions. The original callback
// token/epoch and parent operation must still own this current state and feature.
private _helperCurrent={
    private _currentState=_group getVariable ["CBE_AIPass_State",createHashMap];
    private _currentDrill=_currentState getOrDefault ["drill",createHashMap];
    private _currentOperation=_group getVariable ["CBE_Operation",createHashMap];
    local _group && {_rosterEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_currentState isEqualTo _state} && {(_currentDrill getOrDefault ["token",""]) == _token}
        && {!_pointOrder || {(_currentDrill getOrDefault ["pointObjective",[]]) isEqualTo _pointObjective}}
        && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
        && {!([] call CBE_fnc_CortexIsPaused)}
        && {[_group,_gate,true] call CBE_fnc_CortexFeatureEnabled}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}
        && {if (_support) then {
            _currentState getOrDefault ["assaulting",false]
                && {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isEqualTo _supportRole}
        } else {
            if (_explicitOrder isEqualTo []) then {
                (_currentState getOrDefault ["phase",""]) == "CONTACT"
            } else {
                // Admission and the actual command boundary use the same finite task.
                (_currentDrill getOrDefault ["explicitOrder",[]]) isEqualTo _explicitOrder
                    && {_explicitValid} && {time < (_explicitOrder select 0)}
                    && {(_currentState getOrDefault ["phase",""]) in ["CALM","CONTACT"]}
                    && {_pointOrder || {[_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled}}
                    && {[_group,_explicitGate,true] call CBE_fnc_CortexFeatureEnabled}
            }
        }}
        && {_operationGeneration < 0 || {
            (_currentOperation getOrDefault ["generation",-2]) == _operationGeneration
                && {(_currentOperation getOrDefault ["ownerEpoch",-1]) == _rosterEpoch}
                && {(_currentOperation getOrDefault ["phase",""]) != "CANCELLED"}
        }}
};
// Two ordinary survivors can still alternate a covered movement pair. Loss of half the
// original roster alone is not a reason to discard their committed route; morale owns retreat.
// Reserved multi-squad roles retain their existing three-person admission contract.
private _minimumStrength=[2,3] select _support;
if (count _units < _minimumStrength) exitWith {"LOSSES" call _end};
// A three-person advance or coordinated responder can use a 2+1 partition. Once the first
// element has arrived, the singleton follows under its two-person cover. Do not
// steal a soldier back out of that arrived pair merely to make the follow team two.
private _movingMinimum={
    params ["_total"];
    private _singletonFollow=_total == 3
        && {(_drill getOrDefault ["teamTurn",0]) == 1}
        && {count _teams == 2} && {count (_teams select 0) == 2} && {count (_teams select 1) == 1};
    [2,1] select ((!_support && {_total == 2}) || {_singletonFollow})
};
private _minimumMovers=[count _units] call _movingMinimum;
// Recovery stays in this existing bounded group job; no per-soldier loop is spawned.
private _recoveryEntry=(_drill getOrDefault ["recovery",[]]) apply {+_x};
private _recoveryIdentity=[_drill getOrDefault ["stage",""],_drill get "index",_drill getOrDefault ["teamTurn",0]];
private _recovery = (_recoveryEntry select {(_x select 0) in _units}) apply {+_x};
private _recoveryCurrent={
    call _helperCurrent
        && {(_drill getOrDefault ["recovery",[]]) isEqualTo _recoveryEntry}
        && {[_drill getOrDefault ["stage",""],_drill get "index",_drill getOrDefault ["teamTurn",0]] isEqualTo _recoveryIdentity}
};
private _recoveryDeferred=false;
private _recovering = _recovery apply {_x select 0};
private _main = _units - _recovering;
private _rejoined = [];
private _rejoinWitnesses=[];
if (_main isNotEqualTo []) then {
    {
        _x params ["_actor","_attempts","_next"];
        private _recoveryNative=[currentCommand _actor,+(expectedDestination _actor),formLeader _actor];
        // Rejoin this actor's element, not the empty space between separated bounds.
        private _peers = _main;
        private _teamIndex = _teams findIf {_actor in _x};
        if (_teamIndex >= 0) then {_peers = (_teams select _teamIndex) select {_x in _main}};
        private _rallyActor=[_group,_main] call CBE_fnc_CortexGroupAnchor;
        if (isNull _rallyActor) exitWith {_recoveryDeferred=true};
        private _rally = getPosATL _rallyActor;
        if (_peers isNotEqualTo []) then {
            // A centroid across floors may be empty air. Recover toward an actual
            // eligible teammate, preferring the surviving buddy in this fire team.
            private _buddy=objNull;
            {
                if (!isNull _buddy) exitWith {};
                if (_x isEqualType [] && {_actor in _x}) then {
                    private _partners=_x select {_x != _actor && {_x in _peers}};
                    if (_partners isNotEqualTo []) exitWith {_buddy=_partners select 0};
                };
            } forEach _buddyPairs;
            if (isNull _buddy) then {
                private _nearest=1e12;
                {
                    private _distance=(getPosASL _actor) vectorDistance (getPosASL _x);
                    if (_distance < _nearest) then {_nearest=_distance;_buddy=_x};
                } forEach _peers;
            };
            _rallyActor=_buddy;
            _rally=getPosATL _buddy;
        };
        private _rallyASL=ATLToASL _rally;
        if ((getPosASL _actor) vectorDistance _rallyASL <= 12
            && {abs (((getPosASL _actor) select 2)-(_rallyASL select 2)) <= 1.5} && {_actor checkAIFeature "PATH"}
            && {_actor checkAIFeature "MOVE"} && {(_drill getOrDefault ["stage",""]) != "MOVE"}) then {
            _rejoinWitnesses pushBack [_actor,_rallyActor];
        } else {
            if (time >= _next && {_attempts < 1} && {_actor checkAIFeature "PATH"} && {_actor checkAIFeature "MOVE"}) then {
                // Recovery owns only movement. Preserve the actor's current target so a
                // separated soldier can fight while closing on the correct fire team.
                isNil {
                    if (!(call _recoveryCurrent)
                        || {!([_actor] call _mayIssueMovement)}
                        || {[currentCommand _actor,expectedDestination _actor,formLeader _actor] isNotEqualTo _recoveryNative}) exitWith {_recoveryDeferred=true};
                    private _recoveryResult="YIELDED";
                    if (_operationGeneration >= 0) then {
                        _recoveryResult=[_group,_operationGeneration,_actor,_rally] call CBE_fnc_RecoveryStep;
                    } else {
                        if ([_actor] call _mayIssueMovement) then {
                            _actor doMove _rally;
                            _recoveryResult="RECOVERING";
                        };
                    };
                    if (_recoveryResult == "RECOVERING") then {[_actor,"MOVE",_rally] call _recordNativeCommand};
                    // Refused movement is not an issued attempt. Preserve the retry budget
                    // while another finite task owns this actor; the remaining element continues.
                    switch (_recoveryResult) do {
                        case "RECOVERING": {_x set [1,_attempts+1]; _x set [2,time+8]};
                        case "EXHAUSTED": {_x set [1,1]; _x set [2,time]};
                        default {_x set [2,time+2]};
                    };
                    // Persist this exact attempt with its command, even if a later actor
                    // or the final roster publication must yield. Never refund an issued move.
                    private _retryRecord=+_x;
                    private _retryIndex=_recoveryEntry findIf {(_x select 0) == _actor};
                    _recoveryEntry set [_retryIndex,_retryRecord];
                    _drill set ["recovery",_recoveryEntry apply {+_x}];
                };
            };
        };
    } forEach _recovery;
};
private _recoveryPublished=false;
isNil {
    if (_recoveryDeferred || {!(call _recoveryCurrent)}) exitWith {};
    // A moving/dead/transferred peer cannot prove present cohesion at a stale rally.
    _rejoined=(_rejoinWitnesses select {
        _x params ["_actor","_peer"];
        private _pose=getPosASL _actor;
        private _peerPose=getPosASL _peer;
        !isNull _peer && {local _actor} && {local _peer}
            && {group _actor == _group} && {group _peer == _group}
            && {_peer in _main} && {isNull objectParent _actor} && {isNull objectParent _peer}
            && {[_actor] call CBE_fnc_CortexCombatEffective} && {[_peer] call CBE_fnc_CortexCombatEffective}
            && {[_actor] call _actorTaskFree} && {[_peer] call _actorTaskFree}
            && {_actor checkAIFeature "PATH"} && {_actor checkAIFeature "MOVE"}
            && {(_drill getOrDefault ["stage",""]) != "MOVE"}
            && {_pose vectorDistance _peerPose <= 12}
            && {abs ((_pose select 2)-(_peerPose select 2)) <= 1.5}
    }) apply {_x select 0};
    _recovery = _recovery select {!((_x select 0) in _rejoined)};
    _drill set ["recovery",_recovery];
    _recovering = _recovery apply {_x select 0};
    private _recoverySnapshot = [["NONE","REJOINING"] select (_recovering isNotEqualTo []),_recovering,_drill getOrDefault ["index",-1]];
    if (_recoverySnapshot isNotEqualTo (_group getVariable ["CBE_Cortex_DrillRecovery",[]])) then {
        _group setVariable ["CBE_Cortex_DrillRecovery",_recoverySnapshot,true];
    };
    _recoveryPublished=true;
};
if (!_recoveryPublished) exitWith {0.25};
_units = _units - _recovering;
// Validate the actual moving element after recovery actors have been removed. The earlier
// squad-wide strength gate cannot prevent a two-person team becoming a one-man assault.
// Prefer two covering soldiers; three capable survivors can use two movers and one cover.
// Never wait for a recovery actor which does not exist.
private _waitForTeam=false;
private _teamRecoveryFailed=false;
private _teamDeferred=false;
private _ensureMovingTeam={
    params ["_turn","_available",["_repartition",false]];
    private _answer=[[],[]];
    private _committed=false;
    isNil {
    if (!(call _helperCurrent)
        || {_turn != (_drill getOrDefault ["teamTurn",0])}
        || {_teams isNotEqualTo (_drill getOrDefault ["teams",[]])}
        || {_available findIf {!([_x] call _actorTaskFree) || {!(_x checkAIFeature "MOVE")}
            || {!(_x checkAIFeature "PATH") && {!(_x in _ownedPathUnits)}}} >= 0}) exitWith {};
    if (_repartition && {(_drill getOrDefault ["buddyBounds",false]) isEqualTo true}
        && {count _available >= 2} && {count _available <= 16}) then {
        private _pairRoles=[_group,_available,_group getVariable ["CBE_CombatPairs",[]],_teams]
            call CBE_fnc_CombatPairElements;
        if (_pairRoles isNotEqualTo []) then {
            _teams=_pairRoles;
            _drill set ["teams",_teams];
            _minimumMovers=[count _available] call _movingMinimum;
        };
    };
    private _otherTurn=1-_turn;
    private _movingAvailable=(_teams select _turn) select {_x in _available};
    private _coverAvailable=(_teams select _otherTurn) select {_x in _available};
    if (!_support && {count _available == 2} && {_coverAvailable isEqualTo []}
        && {count _movingAvailable == 2}) then {
        private _coverer=_movingAvailable deleteAt 1;
        (_teams select _turn) deleteAt ((_teams select _turn) find _coverer);
        (_teams select _otherTurn) pushBack _coverer;
        _coverAvailable pushBack _coverer;
        _drill set ["teams",_teams];
        if ((_drill getOrDefault ["stage",""]) == "MOVE") then {
            call _captureBound;
            [_group,_drill,"START","SURVIVOR_PAIR_REBALANCE"] call CBE_fnc_CortexDrillSetStage;
            _drill set ["spots",[]];
        };
    };
    while {count _movingAvailable < _minimumMovers && {count _coverAvailable > 1}} do {
        private _relief=[_coverAvailable,1] call _selectRelief;
        // No fire-safe transfer is a finite refusal, never a non-progressing recovery loop.
        if (_relief isEqualTo []) exitWith {};
        {
            _coverAvailable deleteAt (_coverAvailable find _x);
            (_teams select _otherTurn) deleteAt ((_teams select _otherTurn) find _x);
            (_teams select _turn) pushBack _x;
            _movingAvailable pushBack _x;
        } forEach _relief;
        _drill set ["teams",_teams];
        if ((_drill getOrDefault ["stage",""]) == "MOVE") then {
            // Membership changed: rebuild slots for this same committed bound before indexing them.
            call _captureBound;
            [_group,_drill,"START","RECOVERY_REINFORCEMENT"] call CBE_fnc_CortexDrillSetStage;
            _drill set ["spots",[]];
        };
        private _history=_group getVariable ["CBE_Cortex_DrillReinforcements",[]];
        _history pushBack [serverTime,_drill getOrDefault ["type",""],_drill getOrDefault ["index",-1],
            _relief apply {[format ["TEAM_%1_RECOVERY",_turn+1],netId _x]}];
        if (count _history > 32) then {_history=_history select [(count _history)-32,32]};
        _group setVariable ["CBE_Cortex_DrillReinforcements",_history,true];
    };
    _answer=[_movingAvailable,_coverAvailable];
    _committed=true;
    };
    if (!_committed) then {_teamDeferred=true};
    _answer
};
if (_teams isNotEqualTo []) then {
    private _turn=_drill getOrDefault ["teamTurn",0];
    private _roster=[_turn,_units] call _ensureMovingTeam;
    _roster params ["_movingAvailable","_coverAvailable"];
    if (count _movingAvailable < _minimumMovers) then {
        private _pendingRecovery=_recovery select {(_x select 0) in (_teams select _turn)};
        private _exhausted=_pendingRecovery isEqualTo [] || {_pendingRecovery findIf {
            (_x select 1) >= 1 && {time >= (_x select 2)}
        } >= 0};
        if (_exhausted) then {_teamRecoveryFailed=true} else {_waitForTeam=true};
    };
};
if (_teamDeferred) exitWith {0.25};
if (_teamRecoveryFailed) exitWith {"RECOVERY_FAILED" call _end};
if (_waitForTeam) exitWith {1.5};
if (count _units < 2) exitWith {"RECOVERY_FAILED" call _end};
private _centroid = [0, 0, 0];
{_centroid = _centroid vectorAdd getPosATL _x} forEach _units;
_centroid = _centroid vectorMultiply (1 / count _units);
// Reserved squads may still be CALM without personal sight. Their authenticated
// role carries the shared objective; local discovery may contain an older position.
private _enemyPos = if (_support) then {+(_supportRole select 4)} else {
    // An explicit episode owns its accepted native belief, not an older group contact
    // or a later targetless danger position. Normal autonomous decisions retain their context.
    if (count _explicitOrder == 4) then {+(_drill get "enemyPos")} else {
        _state getOrDefault ["enemyPos", _drill get "enemyPos"]
    }
};
private _assaulting = _drill getOrDefault ["assaulting", false];
private _assaultEnabled = [_group,"CBE_AIPass_Assault_Enable", true] call CBE_fnc_CortexFeatureEnabled;
if (_assaulting && {!_assaultEnabled}) exitWith {"ABORT" call _end};
if (!_pointOrder && {!_support} && {!_assaulting} && {!_assaultEnabled} && {_centroid distance2D _enemyPos < 30}) exitWith {"CLOSE" call _end};

// Preserve the complete live participant set before selecting the fire team for this bound.
// HOLD uses this snapshot to bring the base-of-fire element forward; without it the
// consolidation transition can terminate and leave only the current team assaulting.
private _allUnits = +_units;
private _fit = +_allUnits;
if (_teams isNotEqualTo []) then {_units = (_teams select (_drill getOrDefault ["teamTurn",0])) select {_x in _fit}};
if (_units isEqualTo [] || {_teams isNotEqualTo [] && {count (_fit - _units) == 0}}) exitWith {"LOSSES" call _end};
private _points = _drill get "points";
private _now = time;
private _restoreFeatures = {
    private _restored=false;
    isNil {
    if !(call _helperCurrent) exitWith {};
    private _stillRecovering = (_drill getOrDefault ["recovery",[]]) apply {_x select 0};
    private _keptBehaviours = [];
    {
        _x params ["_unit","_previous","_owned"];
        if (_unit in _stillRecovering && {[_unit] call _mayIssueMovement} && {behaviour _unit == _owned}) then {
            _keptBehaviours pushBack _x;
        } else {
            if (behaviour _unit == _owned) then {
                if ([_unit] call _mayIssueMovement) then {_unit setCombatBehaviour _previous};
                // An unavailable actor still needs its unchanged restoration proof later.
                if (behaviour _unit == _owned && {_previous != _owned}) then {_keptBehaviours pushBack _x};
            };
        };
    } forEach (_drill getOrDefault ["combatBehaviours",[]]);
    _drill set ["combatBehaviours",_keptBehaviours];
    private _keptModes = [];
    {
        _x params ["_unit","_mode",["_ownedMode","BLUE"]];
        if (_unit in _stillRecovering && {[_unit] call _mayIssueMovement} && {unitCombatMode _unit == _ownedMode}) then {
            _keptModes pushBack _x;
        } else {
            if (unitCombatMode _unit == _ownedMode) then {
                if ([_unit] call _mayIssueMovement) then {_unit setUnitCombatMode _mode};
                if (unitCombatMode _unit == _ownedMode && {_mode != _ownedMode}) then {_keptModes pushBack _x};
            };
        };
    } forEach (_drill getOrDefault ["combatModes",[]]);
    _drill set ["combatModes",_keptModes];
    private _kept = [];
    {
        _x params ["_unit", "_feature"];
        if (_unit in _stillRecovering && {_feature in ["AUTOTARGET","TARGET","AUTOCOMBAT"]}) then {_kept pushBack _x} else {
            if (alive _unit && {[_unit] call _mayIssueMovement}) then {_unit enableAI _feature};
            if (alive _unit && {!(_unit checkAIFeature _feature)}) then {_kept pushBack _x};
        };
    } forEach (_drill get "disabled");
    _drill set ["disabled", _kept];
    _restored=true;
    };
    _restored
};
private _issue = {
    // PAUSE can change teamTurn in this callback; derive the new turn minimum now.
    _minimumMovers=[count _fit] call _movingMinimum;
    if !([] call _restoreFeatures) exitWith {_result=0.25};
    private _viable=true;
    if (_teams isNotEqualTo []) then {
        // PAUSE can swap the team inside this same callback. Rebalance the newly selected
        // movers before any destination write, not one scheduler interval afterward.
        private _roster=[_drill get "teamTurn",_fit,true] call _ensureMovingTeam;
        _units=_roster select 0;
        _viable=count _units >= _minimumMovers && {count (_roster select 1) >= 1};
    };
    if (_teamDeferred) exitWith {_result=0.25};
    if (!_viable) exitWith {_result="RECOVERY_FAILED" call _end};
    (_points select (_drill get "index")) params ["_point", "_kind"];
    // Check ammunition only at the next bound, not every movement sample.
    // Finishing a road crossing or consolidating must not strand dry actors in place.
    // Coordinated dispatch capacity cannot replace this current local team check.
    if (!(_kind in ["CROSS_FAR","CONSOLIDATE"])) then {
        private _armedMovers={unitCombatMode _x in ["YELLOW","RED"]
            && {_x checkAIFeature "FIREWEAPON"} && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}} count _units;
        // Separated actors are still moving under recovery, not available cover.
        private _coverCandidates=if (_teams isEqualTo []) then {(_fitSquad-_units)-_recovering} else {_fit-_units};
        private _armedCover=_coverCandidates findIf {unitCombatMode _x in ["YELLOW","RED"]
            && {_x checkAIFeature "FIREWEAPON"} && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}} >= 0;
        if (_armedMovers < _minimumMovers || {!_armedCover}) then {_viable=false};
    };
    if (!_viable) exitWith {_result="FIRE_CAPACITY_LOST" call _end};
    // Slot ordering is not a new roster/role assignment. Keep currently eligible buddies
    // adjacent before geometry selection; do not recruit a partner from another element.
    // Resume spots remain actor-addressed and override these new-bound slot preferences.
    if (count _units > 1 && {count _units <= 16}) then {
        private _slotPairs=_group getVariable ["CBE_CombatPairs",[]];
        if !(_slotPairs isEqualType []) then {_slotPairs=[]};
        _slotPairs=_slotPairs select [0,16];
        private _orderedMovers=[];
        {
            private _actor=_x;
            if !(_actor in _orderedMovers) then {
                _orderedMovers pushBack _actor;
                private _pairIndex=_slotPairs findIf {
                    _x isEqualType [] && {count _x == 2} && {(_x select 0) != (_x select 1)}
                        && {_actor in _x} && {_x findIf {!(_x in _units)} < 0}
                };
                if (_pairIndex >= 0) then {
                    private _partners=(_slotPairs select _pairIndex)-[_actor];
                    _orderedMovers pushBackUnique (_partners select 0);
                };
            };
        } forEach _units;
        if (count _orderedMovers == count _units) then {_units=_orderedMovers};
    };
    _point=+_point;
    private _issueEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
    private _issuePhase=[_drill getOrDefault ["stage",""],_drill get "index",_drill getOrDefault ["teamTurn",0]];
    private _issueTeams=(_drill getOrDefault ["teams",[]]) apply {+_x};
    private _issueUnits=+(_drill get "units");
    private _issueNative=_fit apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x]};
    private _planned=[];
    private _direction = if (_kind in ["ASSAULT","CLEAR","CONSOLIDATE"]) then {_drill get "assaultDirection"} else {_point getDir _enemyPos};
    private _spots = [];
    private _resumeSpots=_drill getOrDefault ["resumeSpots",[]];
    private _reservedSpots=(_resumeSpots select {(_x select 0) in _units}) apply {+(_x select 1)};
    private _slotsAvailable=true;
    private _terrainAvailable=true;
    // Retain only still-owned recovery overrides across the main element's next bound.
    // FlankEnd restores the same records on cancellation, migration or completion.
    private _disabled = +(_drill get "disabled");
    private _combatModes = +(_drill getOrDefault ["combatModes",[]]);
    private _combatBehaviours = +(_drill getOrDefault ["combatBehaviours",[]]);
    {
        private _unit = _x;
        private _spacing = [5, 3] select (_kind == "CLEAR");
        private _lateral = (_forEachIndex - (count _units - 1) / 2) * _spacing;
        // Tactical bounds form a shallow threat-facing line. Copying the group's
        // ordinary WEDGE formation here put fire teams in depth and repeatedly
        // exposed their flanks to the objective.
        private _depth = 0;
        if (_teams isNotEqualTo []) then {_lateral = _lateral + ([-8,8] select (_drill get "teamTurn"))};
        private _spot = (_point getPos [_lateral, _direction + 90]) getPos [_depth, _direction];
        private _resumeIndex=_resumeSpots findIf {(_x select 0) == _unit};
        if (_resumeIndex >= 0) then {
            // Adoption retains the committed actor destination. Do not spend geometry budget
            // selecting cover that will immediately be discarded or reroll the approach.
            _spot=+((_resumeSpots select _resumeIndex) select 1);
        } else {
            // A replacement cannot consume an incumbent's preserved slot, even when
            // that incumbent occurs later in the reordered roster. Try five local slots.
            if (_reservedSpots isNotEqualTo []) then {
                private _slotFound=false;
                private _preferredSpot=+_spot;
                {
                    private _candidate=_preferredSpot getPos [_x*_spacing,_direction+90];
                    if (!surfaceIsWater _candidate && {((surfaceNormal _candidate) select 2) >= 0.55}
                        && {(_spots+_reservedSpots) findIf {_candidate distance2D _x < 2} < 0}) exitWith {
                        _spot=_candidate;_slotFound=true;
                    };
                } forEach [0,1,-1,2,-2];
                if (!_slotFound) then {_slotsAvailable=false};
            };
            if (surfaceIsWater _spot || {((surfaceNormal _spot) select 2) < 0.55}) then {
                {
                    private _alternative=(_point getPos [_lateral*_x,_direction+90]) getPos [_depth,_direction];
                    if (!surfaceIsWater _alternative && {((surfaceNormal _alternative) select 2) >= 0.55}) exitWith {
                        _spot=_alternative;
                    };
                } forEach [0.65,0.35,0];
            };
            // All local alternatives may fail. Refuse this plan instead of issuing
            // the original water/cliff destination; do not reroll or extend the bound.
            if (surfaceIsWater _spot || {((surfaceNormal _spot) select 2) < 0.55}) then {
                _terrainAvailable=false;
            };
            if (_kind in ["BOUND", "FINAL", "ASSAULT"]) then {
                private _cover = ([_spot, _enemyPos, 3, _spots+_reservedSpots, _group] call CBE_fnc_CortexFindCover) select 0;
                // Cover may lie beyond the search radius on a large object. Preserve the formation slot.
                if (_cover distance2D _spot <= 2 && {(_spots+_reservedSpots) findIf {_cover distance2D _x < 2} < 0}) then {_spot = _cover};
            };
        };
        _spots pushBack _spot;
        _planned pushBack [_unit,+_spot];
    } forEach _units;
    if (!_terrainAvailable) exitWith {_result="NO_SAFE_BOUND_TERRAIN" call _end};
    if (!_slotsAvailable) exitWith {_result="NO_REPLACEMENT_SPACE" call _end};
    // Geometry is prepared above the local commit. Native writes and their journals commit only while
    // the same drill point, roster and observed actor tasks still own this entire bound.
    private _issued=false;
    isNil {
        private _liveState=_group getVariable ["CBE_AIPass_State",createHashMap];
        private _liveDrill=_liveState getOrDefault ["drill",createHashMap];
        private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
        if (!local _group || {_issueEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {_liveState isNotEqualTo _state} || {(_liveDrill getOrDefault ["token",""]) != _token}
            || {[_liveDrill getOrDefault ["stage",""],_liveDrill getOrDefault ["index",0],_liveDrill getOrDefault ["teamTurn",0]] isNotEqualTo _issuePhase}
            || {(_liveDrill getOrDefault ["teams",[]]) isNotEqualTo _issueTeams}
            || {(_liveDrill getOrDefault ["units",[]]) isNotEqualTo _issueUnits}
            || {((_liveDrill getOrDefault ["points",[]]) param [_issuePhase select 1,[]]) isNotEqualTo [_point,_kind]}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {[] call CBE_fnc_CortexIsPaused}
            || {!([_group,_gate,true] call CBE_fnc_CortexFeatureEnabled)}
            || {if (_support) then {!(_liveState getOrDefault ["assaulting",false])} else {
                (_liveState getOrDefault ["phase",""]) != "CONTACT"
            }}
            || {_support && {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _supportRole}}
            || {[_group] call CBE_fnc_CortexExternalTakeover}
            || {_operationGeneration >= 0 && {
                (_liveOperation getOrDefault ["generation",-2]) != _operationGeneration
                    || {(_liveOperation getOrDefault ["ownerEpoch",-1]) != _issueEpoch}
                    || {(_liveOperation getOrDefault ["phase",""]) == "CANCELLED"}
            }}
            || {_issueNative findIf {
                _x params ["_actor","_command","_destination","_leader"];
                !([_actor] call _mayIssueMovement) || {currentCommand _actor != _command}
                    || {(expectedDestination _actor) isNotEqualTo _destination}
                    || {formLeader _actor != _leader}
            } >= 0}) exitWith {};
    if (_teams isNotEqualTo []) then {
        {
            // Cover is a movement command too. A specialist or newer actor task may
            // have claimed this soldier since the roster was selected.
            if ([_x] call _mayIssueMovement) then {
                doStop _x;
                [_x,"HOLD"] call _recordNativeCommand;
                _x doWatch _enemyPos;
            };
        } forEach (_fit - _units);
    };
    {
        _x params ["_unit","_spot"];
        // Release only Cortex's matching cover stance when this soldier starts moving.
        // A later mission-maker or Zeus stance remains authoritative.
        if ([_unit] call _mayIssueMovement
            && {count ([_group,_unit] call CBE_fnc_CortexStanceReceipt) == 4}
            && {_unit getVariable ["CBE_AIPass_StanceSet",false]}
            && {toUpperANSI (unitPos _unit) == (_unit getVariable ["CBE_Cortex_AppliedStance",""])}) then {
            _unit setUnitPos "AUTO";
            if (toUpperANSI unitPos _unit != (_unit getVariable ["CBE_Cortex_AppliedStance",""])) then {
                _unit setVariable ["CBE_AIPass_StanceSet",nil,true];
                _unit setVariable ["CBE_Cortex_AppliedStance",nil,true];
                _unit setVariable ["CBE_Cortex_StanceReceipt",nil,true];
            };
        };
        // Preserve native target acquisition, autonomous combat and the actor's current behaviour.
        // CBE commits a route and role but leaves moment-to-moment combat to the engine.
        // Do not issue doFollow or setDestination: either can create a second movement owner.
        if ([_unit] call _mayIssueMovement) then {
            // Individual RED overrides the group's YELLOW bound policy. Lease only that
            // permissive mode; keep firing enabled and preserve authored hold-fire modes.
            if (unitCombatMode _unit == "RED") then {
                _combatModes pushBack [_unit,"RED","YELLOW"];
                _unit setUnitCombatMode "YELLOW";
            };
            private _handoff=[serverTime,netId _unit,_drill get "index",
                currentCommand _unit,expectedDestination _unit,+_spot,attackEnabled _group];
            // A previous covering role may have received a CBE target assignment. Retire
            // only that exact local receipt before the actor becomes a mover; native knowledge
            // and a newer external assignment remain available to ordinary engine aiming.
            private _fireTarget=_unit getVariable ["CBE_Cortex_FireTarget",[]];
            if (count _fireTarget == 3 && {(_fireTarget select 0) == _group}
                && {(_fireTarget select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                && {!isNull (_fireTarget select 2)} && {assignedTarget _unit == (_fireTarget select 2)}) then {
                _unit doTarget objNull;
            };
            _unit setVariable ["CBE_Cortex_FireTarget",nil];
            if ([_unit] call _mayIssueMovement) then {
                // A transferred exact native leg continues in the engine. Observing it grants
                // neither another doMove nor a fresh command-acknowledgement interval.
                private _continueNative=_unit in (_drill getOrDefault ["resumeNativeMoves",[]])
                    && {currentCommand _unit == "MOVE"} && {
                        private _nativeGoal=(expectedDestination _unit) param [0,[],[[]]];
                        count _nativeGoal == 3 && {_nativeGoal vectorDistance _spot <= 0.25}
                    } && {[_unit] call _nativeCommandAvailable};
                if (!_continueNative) then {
                    _unit doWatch _enemyPos;
                    _unit doMove _spot;
                    [_unit,"MOVE",_spot] call _recordNativeCommand;
                };
            };
            // Keep a bounded pre-command record; native aiming remains untouched.
            private _handoffs=_drill getOrDefault ["movementHandoffs",[]];
            if (count _handoffs < 16) then {
                _handoffs pushBack _handoff;
                _drill set ["movementHandoffs",_handoffs];
            };
        };
    } forEach _planned;
    // Preparation belongs to this successful fresh-bound transaction, not admission or a
    // detached timer. Keep the covering team firing; never replay on recovered native legs.
    private _reloadBound=[_drill get "index",_drill getOrDefault ["teamTurn",0]];
    private _lastPreparation=_drill getOrDefault ["lastReloadPreparation",[]];
    if (!_support && {_resumeSpots isEqualTo []} && {!(_kind in ["CROSS_NEAR","CROSS_FAR","CONSOLIDATE"])}
        && {_planned isNotEqualTo []}
        && {[_lastPreparation param [2,-1],_lastPreparation param [3,-1]] isNotEqualTo _reloadBound}) then {
        private _coverWitness=objNull;
        {
            private _cover=_x;
            if ([_cover] call _actorTaskFree && {unitCombatMode _cover in ["YELLOW","RED"]}
                && {_cover checkAIFeature "FIREWEAPON"} && {getSuppression _cover < 0.2}
                && {primaryWeapon _cover != ""} && {currentWeapon _cover == primaryWeapon _cover}) then {
                private _weapon=primaryWeapon _cover;
                private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
                private _main=if ("this" in _muzzles) then {_weapon} else {_muzzles param [0,_weapon]};
                private _weaponState=_cover weaponState _main;
                if (currentMuzzle _cover == _main && {count _weaponState == 7}
                    && {(_weaponState select 4) isEqualType 0} && {finite (_weaponState select 4)}
                    && {(_weaponState select 4) > 0} && {(_weaponState select 5) isEqualTo 0}
                    && {(_weaponState select 6) isEqualTo 0}) then {_coverWitness=_cover};
            };
            if (!isNull _coverWitness) exitWith {};
        } forEach (if (_teams isEqualTo []) then {(_fitSquad-_units)-_recovering} else {_fit-_units});
        if (!isNull _coverWitness) then {
            private _reloadChecks=0;private _reloadSpent=false;
            {
                private _actor=_x select 0;
                if (_reloadSpent || {_reloadChecks >= 4}) exitWith {};
                if ([_actor] call _mayIssueMovement && {getSuppression _actor < 0.2}
                    && {_actor distance2D _enemyPos > 35} && {unitCombatMode _actor in ["YELLOW","RED"]}
                    && {_actor checkAIFeature "FIREWEAPON"}) then {
                    _reloadChecks=_reloadChecks+1;
                    private _proposal=[_actor] call CBE_fnc_CortexRifleReloadPlan;
                    if (_proposal isNotEqualTo [] && {reloadEnabled _actor}
                        && {currentMuzzle _actor == (_proposal select 0)}
                        && {(_actor weaponState (_proposal select 0)) isEqualTo (_proposal select 2)}) exitWith {
                        // Native request acceptance is not loaded-round evidence. No reload
                        // cancellation, animation acceleration, ammo insertion or new wait.
                        _reloadSpent=true;
                        private _preparation=[_actor,_coverWitness,_reloadBound select 0,
                            _reloadBound select 1,serverTime,false];
                        _drill set ["lastReloadPreparation",_preparation];
                        private _requested=_actor reload (_proposal select [0,2]);
                        _preparation set [5,_requested];
                    };
                };
            } forEach _planned;
        };
    };
    private _waypointIndex = currentWaypoint _group;
    private _waypointSnapshot = [];
    if (_waypointIndex < count waypoints _group) then {
        _waypointSnapshot = [_waypointIndex,waypointPosition [_group,_waypointIndex]];
    };
    _drill set ["boundWaypoint",_waypointSnapshot];
    _drill set ["spots", _spots];
    _group setVariable ["CBE_Cortex_DrillMovementHandoffs",[
        _operationGeneration,_token,+(_drill getOrDefault ["movementHandoffs",[]])
    ],true];
    _drill set ["movers", +_units];
    _drill set ["arrivedUnits",[]];
    private _progress = [];
    {
        private _actor=_x;
        private _savedProgress=(_drill getOrDefault ["resumeProgress",[]]) select {(_x select 0) == _actor};
        private _distanceClock=_now; private _motionClock=_now;
        private _distance=(getPosASL _actor) vectorDistance (ATLToASL (_spots select _forEachIndex));
        private _lastPose=getPosASL _actor;
        if (_savedProgress isNotEqualTo []) then {
            _distanceClock=time+((_savedProgress select 0) select 1)-serverTime;
            _motionClock=time+((_savedProgress select 0) select 2)-serverTime;
            _distance=(_savedProgress select 0) select 3;
            _lastPose=+((_savedProgress select 0) select 4);
        };
        _progress pushBack [_distance,_distanceClock,_lastPose,_motionClock];
    } forEach _units;
    _drill set ["progress",_progress];
    _drill set ["progressCoordinates","ASL3D"];
    private _resumeRetries=_drill getOrDefault ["resumeRetries",[]];
    _drill set ["retries",_units apply {
        private _actor=_x;
        private _record=_resumeRetries findIf {(_x select 0) == _actor};
        private _count=if (_record < 0) then {0} else {(_resumeRetries select _record) select 1};
        if (_support) then {
            private _budget=(_group getVariable ["CBE_Operation",createHashMap]) getOrDefault ["boundRetryAttempts",createHashMap];
            private _used=if (_budget isEqualType createHashMap && {count _budget <= 64}) then {
                _budget getOrDefault [netId _actor,[]]
            } else {[]};
            if (_used isEqualType [] && {count _used == 2}
                && {(_used select 0) == (_drill get "supportSequence")}
                && {(_used select 1) isEqualType 0} && {finite (_used select 1)}) then {_count=_count max (_used select 1)};
        };
        [_count,_now]
    }];
    _drill deleteAt "resumeNativeMoves";
    _drill deleteAt "resumeProgress";
    _drill deleteAt "resumeSpots";
    _drill deleteAt "resumeRetries";
    _drill set ["disabled", _disabled];
    _drill set ["combatModes",_combatModes];
    _drill set ["combatBehaviours",_combatBehaviours];
    private _boundIdentity=[_drill get "index",_drill getOrDefault ["teamTurn",0]];
    if (_boundIdentity isNotEqualTo (_drill getOrDefault ["boundDeadlineIdentity",[]])) then {
        _drill set ["boundDeadlineIdentity",_boundIdentity];
        _drill set ["boundDeadline",_now+4*(missionNamespace getVariable ["CBE_AIPass_Flank_BoundTimeout",25])];
        _drill deleteAt "boundQuorumUntil";
    };
    // Replacing casualties or blocked movers cannot renew this bound's hard travel limit.
    _drill set ["boundStart", _now];
    [_group,_drill,"MOVE",format ["BOUND_%1_ISSUED",_drill get "index"]] call CBE_fnc_CortexDrillSetStage;
    _issued=true;
    };
    if (!_issued) then {_result=0.25};
};

private _result = 1.5;
switch (_drill get "stage") do {
    case "START": {call _issue};
    case "MOVE": {
        private _spots = (_drill get "spots") apply {+_x};
        private _movers = +(_drill get "movers");
        private _moveIdentity=[_drill get "index",_drill getOrDefault ["teamTurn",0]];
        private _moveNative=(_movers select {_x in _units}) apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x]};
        private _moveWaypointIndex=currentWaypoint _group;
        private _moveRoute=[_group,"",false,_moveWaypointIndex] call CBE_fnc_AuthoredRouteReceipt;
        private _moveActions=[];
        private _arrived = true;
        private _arrivedUnits = [];
        private _stalled = false;
        private _blocked = [];
        private _timeout = missionNamespace getVariable ["CBE_AIPass_Flank_BoundTimeout",25];
        private _moveDeadline=_drill getOrDefault ["boundDeadline",(_drill get "boundStart")+_timeout*4];
        private _entryMoveProgress=(_drill get "progress") apply {[_x select 0,_x select 1,+(_x select 2),_x select 3]};
        private _progress = _entryMoveProgress apply {[_x select 0,_x select 1,+(_x select 2),_x select 3]};
        private _entryMoveCoordinates=_drill getOrDefault ["progressCoordinates",""];
        if (_entryMoveCoordinates != "ASL3D") then {
            // Legacy live records used ATL positions and 2D range. Convert the recorded
            // pose without inventing movement, resetting clocks or renewing retry budget.
            {
                private _pose=ATLToASL (_x select 2);
                _x set [2,_pose];
                _x set [0,_pose vectorDistance (ATLToASL (_spots select _forEachIndex))];
            } forEach _progress;
        };
        private _entryMoveRetries=(_drill getOrDefault ["retries",_movers apply {[0,_now]}]) apply {+_x};
        private _retries = _entryMoveRetries apply {+_x};
        private _previousArrivals=+(_drill getOrDefault ["arrivedUnits",[]]);
        {
            private _unit = _x;
            if (alive _unit && {_unit in _units}) then {
                private _pose=getPosASL _unit;
                private _targetASL=ATLToASL (_spots select _forEachIndex);
                private _remaining = _pose vectorDistance _targetASL;
                if (_remaining <= 3 && {abs ((_pose select 2)-(_targetASL select 2)) <= 1.5}) then {
                    _arrivedUnits pushBack _unit;
                    if !(_unit in _previousArrivals) then {
                        if ([_unit] call _mayIssueMovement) then {
                            _moveActions pushBack ["ARRIVE",_unit,_forEachIndex,+_pose];
                        };
                    };
                } else {
                    _arrived = false;
                    private _last = _progress select _forEachIndex;
                    if ((_last select 0)-_remaining >= 0.5) then {_last set [0,_remaining]; _last set [1,_now]};
                    // A valid obstacle detour can temporarily increase target distance.
                    // Keep net approach and physical movement clocks separate.
                    if (_pose vectorDistance (_last select 2) >= 0.5) then {_last set [2,+_pose]; _last set [3,_now]};
                    private _retry = _retries select _forEachIndex;
                    private _retryPending=false;
                    // Native formation movement can resume the group's original waypoint
                    // while this actor is still outside its bound. Physical movement alone
                    // is not evidence that the owned destination is still being followed.
                    private _waypoint = _drill getOrDefault ["boundWaypoint",[]];
                    private _returnedToWaypoint = count _waypoint == 2
                        && {currentWaypoint _group == (_waypoint select 0)}
                        && {waypointPosition [_group,_waypoint select 0] isEqualTo (_waypoint select 1)}
                        && {(_waypoint select 1) distance2D (_spots select _forEachIndex) > 5}
                        && {((expectedDestination _unit) select 0) distance2D (_waypoint select 1) < 1};
                    if ((_now-(_last select 3) >= 8 || {_returnedToWaypoint}) && {_now-(_retry select 1) >= 8}
                        && {(_retry select 0) < 1} && {_now <= _moveDeadline}
                        && {_unit checkAIFeature "PATH"}
                        && {_unit checkAIFeature "MOVE"} && {[_unit] call _mayIssueMovement}
                        && {[_unit] call _supportRetryAvailable}) then {
                        // Replan the same destination; do not move the actor or waive arrival.
                        // One native route refresh is allowed only after measured no-progress.
                        // Target and combat behaviour remain engine-owned.
                        _moveActions pushBack ["RETRY",_unit,_forEachIndex,+_pose];
                        _retryPending=true;
                    };
                    // A delayed callback must not issue its sole retry and immediately
                    // cancel it using pre-retry no-progress age. Retain real progress clocks;
                    // only the existing8-second observation interval applies, never past
                    // the unchanged hard deadline checked below and at native admission.
                    if (_now-(_last select 3) > _timeout && {!_retryPending}
                        && {(_retry select 0) == 0 || {_now-(_retry select 1) >= 8}}) then {
                        _stalled = true; _blocked pushBack _unit
                    };
                };
            };
        } forEach _movers;
        private _moveCommitted=false;
        isNil {
            private _liveState=_group getVariable ["CBE_AIPass_State",createHashMap];
            private _liveDrill=_liveState getOrDefault ["drill",createHashMap];
            private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
            if (!local _group || {_rosterEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
                || {_liveState isNotEqualTo _state} || {(_liveDrill getOrDefault ["token",""]) != _token}
                || {(_liveDrill getOrDefault ["stage",""]) != "MOVE"}
                || {[_liveDrill getOrDefault ["index",0],_liveDrill getOrDefault ["teamTurn",0]] isNotEqualTo _moveIdentity}
                || {(_liveDrill getOrDefault ["spots",[]]) isNotEqualTo _spots}
                || {(_liveDrill getOrDefault ["movers",[]]) isNotEqualTo _movers}
                || {(_liveDrill getOrDefault ["progress",[]]) isNotEqualTo _entryMoveProgress}
                || {(_liveDrill getOrDefault ["progressCoordinates",""]) != _entryMoveCoordinates}
                || {(_liveDrill getOrDefault ["boundDeadline",(_drill get "boundStart")+_timeout*4]) != _moveDeadline}
                || {(_liveDrill getOrDefault ["retries",_movers apply {[0,_now]}]) isNotEqualTo _entryMoveRetries}
                || {(_liveDrill getOrDefault ["arrivedUnits",[]]) isNotEqualTo _previousArrivals}
                || {currentWaypoint _group != _moveWaypointIndex}
                || {([_group,"",false,_moveWaypointIndex] call CBE_fnc_AuthoredRouteReceipt) isNotEqualTo _moveRoute}
                || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
                || {[] call CBE_fnc_CortexIsPaused}
                || {!([_group,_gate,true] call CBE_fnc_CortexFeatureEnabled)}
                || {[_group] call CBE_fnc_CortexExternalTakeover}
                || {if (_support) then {!(_liveState getOrDefault ["assaulting",false])} else {(_liveState getOrDefault ["phase",""]) != "CONTACT"}}
                || {_support && {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _supportRole}}
                || {_operationGeneration >= 0 && {
                    (_liveOperation getOrDefault ["generation",-2]) != _operationGeneration
                        || {(_liveOperation getOrDefault ["ownerEpoch",-1]) != _rosterEpoch}
                        || {(_liveOperation getOrDefault ["phase",""]) == "CANCELLED"}
                }}
                || {_moveNative findIf {
                    _x params ["_actor","_command","_destination","_leader"];
                    !([_actor] call _mayIssueMovement) || {currentCommand _actor != _command}
                        || {(expectedDestination _actor) isNotEqualTo _destination}
                        || {formLeader _actor != _leader}
                } >= 0}
                || {_arrivedUnits findIf {
                    private _pose=getPosASL _x;
                    private _target=ATLToASL (_spots select (_movers find _x));
                    _pose vectorDistance _target > 3 || {abs ((_pose select 2)-(_target select 2)) > 1.5}
                } >= 0}
                || {_moveActions findIf {
                    _x params ["_action","_actor","_slot","_observedPose"];
                    private _pose=getPosASL _actor;
                    private _target=ATLToASL (_spots select _slot);
                    private _atTarget=_pose vectorDistance _target <= 3 && {abs ((_pose select 2)-(_target select 2)) <= 1.5};
                    if (_action == "ARRIVE") then {!_atTarget} else {
                        time > _moveDeadline || {_atTarget} || {_pose vectorDistance _observedPose >= 0.5}
                    }
                } >= 0}) exitWith {};
            {
                _x params ["_action","_unit","_slot"];
                if ([_unit] call _mayIssueMovement) then {
                    if (_action == "ARRIVE") then {
                        doStop _unit;
                        [_unit,"HOLD"] call _recordNativeCommand;
                        _unit doWatch _enemyPos;
                    } else {
                        if ([_unit] call _supportRetryAvailable) then {
                            if (_support) then {
                                private _budget=_liveOperation getOrDefault ["boundRetryAttempts",createHashMap];
                                _budget set [netId _unit,[_drill get "supportSequence",1]];
                                _liveOperation set ["boundRetryAttempts",_budget];
                                _group setVariable ["CBE_Operation",_liveOperation,true];
                            };
                            _unit doMove (_spots select _slot);
                            [_unit,"MOVE",_spots select _slot] call _recordNativeCommand;
                            private _retry=_retries select _slot;
                            _retry set [0,(_retry select 0)+1];
                            _retry set [1,time];
                            diag_log format ["[CBE] Bound retry group=%1 unit=%2 bound=%3 attempt=%4 remaining=%5 command=%6 destination=%7 committed=%8 assignedTarget=%9",_group,netId _unit,_drill get "index",_retry select 0,(getPosASL _unit) vectorDistance (ATLToASL (_spots select _slot)),currentCommand _unit,expectedDestination _unit,_spots select _slot,assignedTarget _unit];
                        };
                    };
                };
            } forEach _moveActions;
            _drill set ["progress",_progress];
            _drill set ["progressCoordinates","ASL3D"];
            _drill set ["retries",_retries];
            _drill set ["arrivedUnits",_arrivedUnits];
            _moveCommitted=true;
        };
        if (!_moveCommitted) exitWith {_result=0.25};
        // Later recovery/failure decisions may be separated from measurement by a
        // deferred callback or synchronous helper re-entry. Bind them to the committed records and current native tasks.
        private _decisionProgress=_progress apply {[_x select 0,_x select 1,+(_x select 2),_x select 3]};
        private _decisionRetries=_retries apply {+_x};
        private _decisionRecovery=(_drill getOrDefault ["recovery",[]]) apply {+_x};
        _recovery=_recovery apply {+_x};
        private _decisionNative=_units apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x,getPosASL _x]};
        private _decisionCurrent={
            call _helperCurrent && {(_drill getOrDefault ["stage",""]) == "MOVE"}
                && {[_drill get "index",_drill getOrDefault ["teamTurn",0]] isEqualTo _moveIdentity}
                && {(_drill getOrDefault ["spots",[]]) isEqualTo _spots}
                && {(_drill getOrDefault ["movers",[]]) isEqualTo _movers}
                && {(_drill getOrDefault ["progress",[]]) isEqualTo _decisionProgress}
                && {(_drill getOrDefault ["retries",[]]) isEqualTo _decisionRetries}
                && {(_drill getOrDefault ["arrivedUnits",[]]) isEqualTo _arrivedUnits}
                && {(_drill getOrDefault ["recovery",[]]) isEqualTo _decisionRecovery}
                && {(_drill getOrDefault ["boundDeadline",(_drill get "boundStart")+_timeout*4]) == _moveDeadline}
                && {currentWaypoint _group == _moveWaypointIndex}
                && {([_group,"",false,_moveWaypointIndex] call CBE_fnc_AuthoredRouteReceipt) isEqualTo _moveRoute}
                && {_decisionNative findIf {
                    _x params ["_actor","_command","_destination","_leader","_pose"];
                    !([_actor] call _actorTaskFree) || {currentCommand _actor != _command}
                        || {(expectedDestination _actor) isNotEqualTo _destination}
                        || {formLeader _actor != _leader}
                        || {_actor in _blocked && {(getPosASL _actor) vectorDistance _pose >= 0.5}}
                } < 0}
                && {_arrivedUnits findIf {
                    private _pose=getPosASL _x;
                    private _target=ATLToASL (_spots select (_movers find _x));
                    _pose vectorDistance _target > 3 || {abs ((_pose select 2)-(_target select 2)) > 1.5}
                } < 0}
        };
        private _decisionDeferred=false;
        private _originalElement = if (_teams isEqualTo []) then {_allUnits} else {_teams select (_drill getOrDefault ["teamTurn",0])};
        // Use the live assigned movers for this bound. Casualty replacement, recovery and
        // consolidation can change the original team; a stale denominator must not hold the
        // whole action after a viable majority physically arrives.
        private _minimumArrivals = ((ceil (count _units * 0.6)) max 2) min count _units;
        private _boundAge = _now - (_drill get "boundStart");
        private _lateMovers = _units - _arrivedUnits;
        private _lateMoverProgressing = _lateMovers findIf {
            private _progressIndex = _movers find _x;
            _progressIndex >= 0 && {_now - ((_progress select _progressIndex) select 3) <= 3}
        } >= 0;
        // Slow, successful bounds must not consume their straggler allowance before
        // a majority reaches its actual spots. Freeze one server-time expiry for this
        // bound identity; casualty reconstruction and owner migration cannot renew it.
        private _quorumUntil=_drill getOrDefault ["boundQuorumUntil",-1];
        if (!_arrived && {_boundAge >= 6} && {count _arrivedUnits >= _minimumArrivals}
            && {_lateMoverProgressing} && {_quorumUntil == -1}) then {
            isNil {
                if !(call _decisionCurrent) exitWith {_decisionDeferred=true};
                _quorumUntil=(serverTime+6) min (serverTime+((_moveDeadline-_now) max 0));
                _drill set ["boundQuorumUntil",_quorumUntil];
            };
        };
        if (_decisionDeferred) exitWith {_result=0.25};
        private _quorumReady = !_arrived
            && {_boundAge >= 6}
            && {count _arrivedUnits >= _minimumArrivals}
            && {!_lateMoverProgressing || {_quorumUntil >= 0 && {serverTime >= _quorumUntil}}};
        if (_quorumReady) then {
            isNil {
            if !(call _decisionCurrent) exitWith {_decisionDeferred=true};
            private _stragglers = _units - _arrivedUnits;
            {
                private _straggler = _x;
                if ((_recovery findIf {(_x select 0) == _straggler}) < 0) then {
                    _recovery pushBack [_straggler,0,_now];
                };
            } forEach _stragglers;
            _drill set ["recovery",_recovery];
            _group setVariable ["CBE_Cortex_DrillRecovery",["REJOINING",_recovery apply {_x select 0},_drill get "index"],true];
            diag_log format ["[CBE] Bound role complete group=%1 arrived=%2/%3 recovery=%4",_group,count _arrivedUnits,count _units,_stragglers];
            _arrived = true;
            _stalled = false;
            _decisionRecovery=_recovery apply {+_x};
            };
        };
        if (_decisionDeferred) exitWith {_result=0.25};
        if (_stalled && {count (_units - _blocked) >= 2}
            && {count (_units - _blocked) >= ceil (count _originalElement * 0.6)}) then {
            isNil {
            if !(call _decisionCurrent) exitWith {_decisionDeferred=true};
            // Continue with a viable majority. These actors are separated, not arrived.
            {_recovery pushBack [_x,0,_now]} forEach _blocked;
            _drill set ["recovery",_recovery];
            _group setVariable ["CBE_Cortex_DrillRecovery",["REJOINING",_recovery apply {_x select 0},_drill get "index"],true];
            diag_log format ["[CBE] Bound continues with stragglers group=%1 separated=%2 continuing=%3",_group,_blocked,_units-_blocked];
            _stalled = false;
            _decisionRecovery=_recovery apply {+_x};
            };
        };
        if (_decisionDeferred) exitWith {_result=0.25};
        private _neededReplacements=(2-count (_units-_blocked)) max 0;
        private _availableCover=(_fit-_units)-_recovering;
        if (!_arrived && {_stalled} && {_teams isNotEqualTo []}
            && {_neededReplacements > 0} && {count _availableCover >= (_neededReplacements+1)}
            && {_now <= (_drill getOrDefault ["boundDeadline",(_drill get "boundStart")+_timeout*4])}) exitWith {
            _result=0.25;
            isNil {
            if !(call _decisionCurrent) exitWith {};
            {
                private _blockedActor=_x;
                if (_recovery findIf {(_x select 0) == _blockedActor} < 0) then {
                    _recovery pushBack [_blockedActor,0,_now];
                };
            } forEach _blocked;
            _drill set ["recovery",_recovery];
            // Next callback removes isolated actors and rebalances at most two coverers.
            // Keep this exact bound and its remaining actors; never return to an old rally.
            [_group,_drill,"START","STALLED_ELEMENT_REINFORCEMENT"] call CBE_fnc_CortexDrillSetStage;
            diag_log format ["[CBE] Bound replacement pending group=%1 isolated=%2 reserve=%3",_group,_blocked,_availableCover];
            _result=1.5;
            };
        };
        if (!_arrived && {_stalled || {_now > (_drill getOrDefault ["boundDeadline",(_drill get "boundStart")+_timeout*4])}}) exitWith {
            private _reason = ["TIME_LIMIT","STALLED"] select (_stalled && {_now <= _moveDeadline});
            private _measurements = [];
            {
                private _unit = _x;
                if (_unit in _units) then {
                    _measurements pushBack [netId _unit,(getPosASL _unit) vectorDistance (ATLToASL (_spots select _forEachIndex)),
                        _now-((_progress select _forEachIndex) select 1),currentCommand _unit,expectedDestination _unit,
                        _now-((_progress select _forEachIndex) select 3),
                        ["movementOwner",attackEnabled _group,behaviour _unit,unitCombatMode _unit,
                            assignedTarget _unit,getAttackTarget _unit,_unit checkAIFeature "PATH",_unit checkAIFeature "MOVE",
                            _unit checkAIFeature "AUTOTARGET",_unit checkAIFeature "TARGET",_unit checkAIFeature "AUTOCOMBAT",
                            groupOwner _group,_group getVariable ["CBE_Cortex_SupportRole",[]]]];
                };
            } forEach _movers;
            private _failure = [_reason,_drill get "index",(_points select (_drill get "index")) select 1,
                _now-(_drill get "boundStart"),_timeout,_measurements];
            private _failureCommitted=false;
            isNil {
                if !(call _decisionCurrent) exitWith {};
                _group setVariable ["CBE_Cortex_DrillFailure",_failure,true];
                diag_log format ["[CBE] Drill movement ended group=%1 details=%2",_group,_failure];
                _failureCommitted=true;
            };
            if (_failureCommitted) then {_result = _reason call _end} else {_result=0.25};
        };
        if (_arrived) then {
            // Revalidate the actual witnesses, not a centroid or a historical arrival flag.
            // Recovery may leave stragglers behind; retain the existing required quorum.
            private _arrivalWitnesses=_arrivedUnits apply {[_x,ATLToASL (_spots select (_movers find _x))]};
            private _arrivalPresent={
                count _arrivalWitnesses >= _minimumArrivals && {_arrivalWitnesses findIf {
                    _x params ["_actor","_targetASL"];
                    private _pose=getPosASL _actor;
                    !local _actor || {group _actor != _group} || {!isNull objectParent _actor}
                        || {!([_actor] call CBE_fnc_CortexCombatEffective)}
                        || {!([_actor] call _actorTaskFree)}
                        || {_pose vectorDistance _targetASL > 3}
                        || {abs ((_pose select 2)-(_targetASL select 2)) > 1.5}
                } < 0}
            };
            if !(call _restoreFeatures) exitWith {_result=0.25};
            private _arrivalRoster=+(_drill get "units");
            private _arrivalTeams=(_drill getOrDefault ["teams",[]]) apply {+_x};
            private _arrivalKind=(_points select (_drill get "index")) select 1;
            private _arrivalCommitted=false;
            private _arrivalSmoke=false;
            private _arrivalAssault=false;
            isNil {
                if (!(call _helperCurrent) || {!(call _arrivalPresent)}
                    || {(_drill getOrDefault ["stage",""]) != "MOVE"}
                    || {!([_drill get "index",_drill getOrDefault ["teamTurn",0]] isEqualTo _moveIdentity)}
                    || {(_drill get "units") isNotEqualTo _arrivalRoster}
                    || {(_drill getOrDefault ["teams",[]]) isNotEqualTo _arrivalTeams}
                    || {(_drill getOrDefault ["spots",[]]) isNotEqualTo _spots}
                    || {(((_drill get "points") select (_moveIdentity select 0)) select 1) != _arrivalKind}) exitWith {};
                if (_teams isNotEqualTo [] && {(_drill get "teamTurn") == 0}) then {
                    [_group,_drill,"PAUSE","FIRE_TEAM_ARRIVED"] call CBE_fnc_CortexDrillSetStage;
                    // A separate squad already covers a coordinated bound. Avoid stacking
                    // a fixed team pause on top of the inter-squad handoff.
                    private _teamPause=if (_support) then {0} else {missionNamespace getVariable ["CBE_AIPass_Flank_BoundPause",0]};
                    _drill set ["pauseUntil",_now + _teamPause];
                } else {
                switch ((_points select (_drill get "index")) select 1) do {
                    case "CROSS_NEAR": {
                        [_group,_drill,"PAUSE","ROAD_EDGE_ARRIVED"] call CBE_fnc_CortexDrillSetStage;
                        _drill set ["pauseUntil", _now];
                        _arrivalSmoke=true;
                    };
                    case "FINAL": {
                        [_group,_drill,"HOLD","FINAL_BOUND_ARRIVED"] call CBE_fnc_CortexDrillSetStage;
                        private _pause = if (_support) then {0} else {missionNamespace getVariable ["CBE_AIPass_Flank_BoundPause",0]};
                        private _multiplier = [1,2] select (!_support && {(_drill getOrDefault ["type","FLANK"]) == "FLANK"});
                        _drill set ["pauseUntil",_now + _pause * _multiplier];
                    };
                    case "ASSAULT": {_arrivalAssault=true};
                    case "CONSOLIDATE": {
                        [_group,_drill,"HOLD","CONSOLIDATION_ARRIVED"] call CBE_fnc_CortexDrillSetStage;
                        _drill set ["pauseUntil",_now + (missionNamespace getVariable ["CBE_AIPass_Flank_BoundPause",0])];
                    };
                    case "CLEAR": {
                        [_group,_drill,"HOLD","CLEAR_THROUGH_ARRIVED"] call CBE_fnc_CortexDrillSetStage;
                        _drill set ["pauseUntil",_now + (missionNamespace getVariable ["CBE_AIPass_Flank_BoundPause",0])];
                    };
                    default {
                        [_group,_drill,"PAUSE","BOUND_ARRIVED"] call CBE_fnc_CortexDrillSetStage;
                        _drill set ["pauseUntil", _now + (missionNamespace getVariable ["CBE_AIPass_Flank_BoundPause", 0])];
                    };
                };
                };
                _arrivalCommitted=true;
            };
            if (!_arrivalCommitted) exitWith {_result=0.25};
            // Grenade inventory/safety preparation stays outside the local stage commit.
            if (_arrivalSmoke) then {
                {
                    if ([_x, _enemyPos, "SMOKE",["DRILL",_group,_token,_operationGeneration,_rosterEpoch]] call CBE_fnc_CortexThrowGrenade) exitWith {};
                } forEach _units;
            };
            if (_arrivalAssault) then {
                private _objective = +(_drill get "assaultObjective");
                private _clearIdentity=[_drill get "index",_drill getOrDefault ["teamTurn",0]];
                private _clearRoster=+(_drill get "units");
                private _clearTeams=(_drill getOrDefault ["teams",[]]) apply {+_x};
                private _clearPoints=_points apply {[+(_x select 0),_x select 1]};
                // Both advance elements have arrived here. Check available carriers
                // across the fit assault force; one empty inventory must not suppress
                // every other soldier's carried grenade. The helper owns ammo/safety checks.
                private _throwers = _fit select {_x distance2D _objective <= 40};
                private _thrower = objNull;
                private _queued = false;
                if (_drill getOrDefault ["assaultGrenade",false]) then {
                    {
                        if ([_x,_objective,"FRAG",["DRILL",_group,_token,_operationGeneration,_rosterEpoch]] call CBE_fnc_CortexThrowGrenade) exitWith {
                            _thrower = _x;
                            _queued = true;
                        };
                    } forEach _throwers;
                };
                // Grenades support the assault but never reserve its movement phase. The helper
                // owns the asynchronous throw and safety cancellation; the element commits its
                // clear-through in this same owner-local step.
                private _clearCommitted=false;
                isNil {
                    if (!(call _helperCurrent) || {!(call _arrivalPresent)}
                        || {(_drill getOrDefault ["stage",""]) != "MOVE"}
                        || {!([_drill get "index",_drill getOrDefault ["teamTurn",0]] isEqualTo _clearIdentity)}
                        || {(_drill get "units") isNotEqualTo _clearRoster}
                        || {(_drill getOrDefault ["teams",[]]) isNotEqualTo _clearTeams}
                        || {(_drill get "points") isNotEqualTo _clearPoints}
                        || {(_drill get "assaultObjective") isNotEqualTo _objective}
                        || {!([_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {};
                    _drill set ["pauseUntil",_now];
                    _drill set ["grenadeThrower",_thrower];
                    _drill set ["grenadeActionUntil",_now];
                    _drill set ["teamTurn",0];
                    _drill set ["index",(_drill get "index")+1];
                    [_group,_drill,"START",["ASSAULT_POSITION","ASSAULT_GRENADE_DISPATCHED"] select _queued] call CBE_fnc_CortexDrillSetStage;
                    _clearCommitted=true;
                };
                if (!_clearCommitted) exitWith {_result=0.25};
                call _issue;
            };
        };
    };
    case "PAUSE": {
        private _pauseIdentity=[_drill get "index",_drill getOrDefault ["teamTurn",0],_drill get "pauseUntil"];
        private _pauseCommitted=false;
        isNil {
            if (!(call _helperCurrent)
                || {(_drill getOrDefault ["stage",""]) != "PAUSE"}
                || {!([_drill get "index",_drill getOrDefault ["teamTurn",0],_drill get "pauseUntil"] isEqualTo _pauseIdentity)}
                || {time < (_drill get "pauseUntil")}) exitWith {};
            if (_teams isNotEqualTo [] && {(_drill get "teamTurn") == 0}) then {
                _drill set ["teamTurn",1];
            } else {
                _drill set ["teamTurn",0];
                _drill set ["index", (_drill get "index") + 1];
            };
            // Persist the pending bound before attempting movement. A refused issue
            // retries START rather than advancing this PAUSE a second time.
            [_group,_drill,"START","PAUSE_ELAPSED"] call CBE_fnc_CortexDrillSetStage;
            _pauseCommitted=true;
        };
        if (!_pauseCommitted) exitWith {_result=0.25};
        if ((_drill get "index") >= count _points) then {_result = "COMPLETE" call _end} else {call _issue};
    };
    case "HOLD": {
        if (_now >= (_drill get "pauseUntil")) then {
            // A flank left its leader/support weapons behind. Move those soldiers
            // forward under the assault element's cover before declaring completion.
            // Advance already brought both elements through the objective.
            if ((_assaulting || {_drill getOrDefault ["finishFlank",false]}) && {_teams isEqualTo []} && {!(_drill getOrDefault ["consolidating",false])}) exitWith {
                // Recovery and independent actor tasks are not spare consolidation participants.
                // Reuse the capable roster instead of bypassing its ownership/path checks.
                // _support is the outer BOOL consumed dynamically by helper CODE. Never
                // shadow it with this actor array before calling _issue/_helperCurrent.
                private _consolidationActors = (_fitSquad - (_allUnits + _recovering)) select {[_x] call _actorTaskFree};
                if (_consolidationActors isEqualTo []) then {
                    _result = "COMPLETE" call _end;
                } else {
                    private _consolidationIdentity=[_drill get "index",_drill getOrDefault ["teamTurn",0],_drill get "pauseUntil"];
                    private _consolidationRoster=+(_drill get "units");
                    private _consolidationPoints=_points apply {[+(_x select 0),_x select 1]};
                    private _consolidationNative=_consolidationActors apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x]};
                    private _rally = if (_assaulting) then {(_drill get "assaultObjective") getPos [12,_drill get "assaultDirection"]} else {+_centroid};
                    private _consolidationCommitted=false;
                    isNil {
                        if (!(call _helperCurrent)
                            || {(_drill getOrDefault ["stage",""]) != "HOLD"}
                            || {_drill getOrDefault ["consolidating",false]}
                            || {(_drill getOrDefault ["teams",[]]) isNotEqualTo []}
                            || {!([_drill get "index",_drill getOrDefault ["teamTurn",0],_drill get "pauseUntil"] isEqualTo _consolidationIdentity)}
                            || {time < (_drill get "pauseUntil")}
                            || {(_drill get "units") isNotEqualTo _consolidationRoster}
                            || {(_drill get "points") isNotEqualTo _consolidationPoints}
                            || {_consolidationNative findIf {
                                _x params ["_actor","_command","_destination","_formationLeader"];
                                !local _actor || {group _actor != _group} || {!isNull objectParent _actor}
                                    || {!([_actor] call CBE_fnc_CortexCombatEffective)}
                                    || {!([_actor] call _actorTaskFree)}
                                    || {!(_actor checkAIFeature "MOVE")}
                                    || {!(_actor checkAIFeature "PATH") && {!(_actor in _ownedPathUnits)}}
                                    || {_actor in ((_group getVariable ["CBE_Operation",createHashMap]) getOrDefault ["unavailable",[]])}
                                    || {currentCommand _actor != _command}
                                    || {(expectedDestination _actor) isNotEqualTo _destination}
                                    || {formLeader _actor != _formationLeader}
                            } >= 0}) exitWith {};
                        if (!_assaulting) then {_drill set ["assaultDirection",_centroid getDir _enemyPos]};
                        _drill set ["consolidating",true];
                        _teams = [+_allUnits,+_consolidationActors];
                        _drill set ["teams",_teams];
                        _drill set ["units",_allUnits + _consolidationActors];
                        _fit append _consolidationActors;
                        _drill set ["teamTurn",1];
                        _drill set ["index",count _points];
                        _points pushBack [_rally,"CONSOLIDATE"];
                        // Retain this pending movement if movement admission refuses it.
                        [_group,_drill,"START","CONSOLIDATION_PENDING"] call CBE_fnc_CortexDrillSetStage;
                        _consolidationCommitted=true;
                    };
                    if (!_consolidationCommitted) exitWith {_result=0.25};
                    call _issue;
                };
            };
            if (_drill getOrDefault ["consolidating",false]) exitWith {_result = "COMPLETE" call _end};
            // A responder accepted into a coordinated assault has already passed the requester's
            // coordinated tactic roll. Its final approach must flow into the assault and clear-through
            // instead of rolling a second independent chance and stopping on the flank. Screened
            // coordinated approaches can finish at 85 m, so give them a small handover margin.
            // Only an arrived HOLD may refresh an explicit approach. No target transform,
            // restarted operation or renewed deadline is used to pursue a contact.
            if (_pointOrder && {_centroid distance2D (_pointObjective select 0) <= (_pointObjective select 1)}
                && {_fit findIf {getPosASL _x vectorDistance (AGLToASL (_pointObjective select 0)) > ((_pointObjective select 1) max 25)
                    || {abs (((getPosASL _x) select 2)-((AGLToASL (_pointObjective select 0)) select 2)) > 1.5}} < 0}) exitWith {
                private _missing=(_drill getOrDefault ["elementRoster",[]]) select {[_x] call CBE_fnc_CortexCombatEffective
                    && {group _x == _group} && {!local _x || {!isNull objectParent _x} || {!isNull attachedTo _x}
                        || {_x distance2D (_pointObjective select 0) > ((_pointObjective select 1) max 25)}
                        || {abs (((getPosASL _x) select 2)-((AGLToASL (_pointObjective select 0)) select 2)) > 1.5}}};
                _group setVariable ["CBE_PointAdvance_Result",[+(_pointObjective select 0),_pointObjective select 1,+_missing],true];
                _result=(["COMPLETE","PARTIAL"] select (_missing isNotEqualTo [])) call _end;
            };
            if (_pointOrder) then {
                private _sample=_state getOrDefault ["explicitKnowledge",[]];
                if (count _sample == 3 && {(_sample select 1) == _rosterEpoch} && {time >= (_sample select 0)}) then {
                    private _elapsed=time-(_sample select 0);
                    private _fresh=(_sample select 2) apply {
                        private _record=+_x;_record set [1,+(_x select 1)];
                        _record set [2,(_x select 2)+_elapsed];_record set [3,_centroid distance2D (_x select 1)];_record
                    };
                    _fresh=_fresh select {(_x select 2) >= 0 && {(_x select 2) <= 10}};
                    private _assessment=[_group,_state,_fresh,false,true,true] call CBE_fnc_CortexTacticalAssess;
                    if ((_assessment getOrDefault ["reason",""]) in ["ARMOUR_OVERMATCH","AIR_OVERMATCH"]) then {
                        _result="POINT_THREAT_CHANGED" call _end;
                    };
                };
            };
            if (_result < 0) exitWith {};
            private _holdObjective=+_enemyPos;
            private _explicitKnowledge=[];
            private _rushTarget=_drill getOrDefault ["target",objNull];
            private _rushObservedAge=0;
            private _rushRefusal="";
            if (_explicitValid && {!_pointOrder} && {!_assaulting}) then {
                _explicitKnowledge=_state getOrDefault ["explicitKnowledge",[]];
                if (count _explicitKnowledge != 3 || {(_explicitKnowledge select 1) != _rosterEpoch}
                    || {time < (_explicitKnowledge select 0)}) then {
                    _rushRefusal="EXPLICIT_KNOWLEDGE_STALE";
                } else {
                    private _elapsed=time-(_explicitKnowledge select 0);
                    private _fresh=(_explicitKnowledge select 2) apply {
                        private _record=+_x;
                        _record set [1,+(_x select 1)];
                        _record set [2,(_x select 2)+_elapsed];
                        _record set [3,_centroid distance2D (_x select 1)];
                        _record
                    };
                    private _assessment=[_group,_state,_fresh,false,
                        [_group,"CBE_AIPass_Advance_Enable",true] call CBE_fnc_CortexFeatureEnabled,
                        _assaultEnabled,_fit] call CBE_fnc_CortexTacticalAssess;
                    private _selected=_assessment getOrDefault ["targetIndex",-1];
                    if (!((_assessment getOrDefault ["intent",""]) in ["ADVANCE","ASSAULT"])
                        || {_selected < 0} || {_selected >= count _fresh}) then {
                        _rushRefusal="EXPLICIT_NO_SAFE_MANOEUVRE";
                    } else {
                        private _contact=_fresh select _selected;
                        _rushObservedAge=_contact select 2;
                        if (_rushObservedAge < 0 || {_rushObservedAge > 10}
                            || {(_contact select 3) > (_drill getOrDefault ["rushRange",0])}) then {
                            _rushRefusal="EXPLICIT_KNOWLEDGE_STALE";
                        } else {
                            _enemyPos=+(_contact select 1);
                            _rushTarget=_contact select 0;
                        };
                    };
                };
            };
            if (_rushRefusal != "") exitWith {_result=_rushRefusal call _end};
            private _assaultRange = missionNamespace getVariable ["CBE_AIPass_Assault_Range",80];
            if (_support) then {_assaultRange = _assaultRange max 100};
            private _assault = !_pointOrder && {!_assaulting}
                && {_assaultEnabled}
                && {(_state getOrDefault ["moraleState", "STEADY"]) == "STEADY"}
                && {_centroid distance2D _enemyPos <= _assaultRange};
            private _assaultDirection = _centroid getDir _enemyPos;
            private _assaultCandidates=[];
            {
                private _crossingDirection=_assaultDirection+_x;
                // Leave room for 3 m arrival tolerance and up to 2 m cover adjustment
                // outside the grenade helper's 12 m friendly exclusion radius.
                private _approach=_enemyPos getPos [20,_crossingDirection+180];
                private _clear=_enemyPos getPos [20,_crossingDirection];
                _assaultCandidates pushBack [_approach,_clear];
            } forEach [0,-15,15,-30,30];
            private _rushPoints=[];
            if (_explicitValid && {!_assaulting} && {_pointOrder || {_centroid distance2D _enemyPos > _assaultRange}}) then {
                if ((_drill getOrDefault ["approachChunks",1]) >= 8 || {count _points >= 64}
                    || {!([_group,"CBE_AIPass_Advance_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) then {
                    _rushRefusal="EXPLICIT_APPROACH_LIMIT";
                } else {
                    private _small=count _fit <= 3;
                    private _buddy=_drill getOrDefault ["buddyBounds",false];
                    private _bound=(missionNamespace getVariable ["CBE_AIPass_Flank_BoundDistance",55]) max 15;
                    if (_small) then {_bound=_bound min 20};
                    if (_buddy) then {_bound=_bound min 25};
                    private _travel=((_centroid distance2D _enemyPos)-([20,0] select _pointOrder)) min (_bound*3);
                    private _axis=_centroid getDir _enemyPos;
                    private _goal=if (_pointOrder && {_travel >= _centroid distance2D _enemyPos}) then {+_enemyPos} else {_centroid getPos [_travel max 0,_axis]};
                    private _offset=((_travel*0.25) max 20) min 55;
                    private _candidates=[[_goal]];
                    {
                        _candidates pushBack [(_centroid getPos [_travel*0.55,_axis]) getPos [_offset,_axis+_x],_goal];
                    } forEach [90,-90,55,-55];
                    private _legs=[_centroid,_candidates,_enemyPos,[],_rushTarget] call CBE_fnc_CortexSelectAvenue;
                    if (_legs isNotEqualTo []) then {
                        _rushPoints=[_centroid,_legs,"FINAL",_group,if (_small) then {20} else {[0,25] select _buddy}]
                            call CBE_fnc_CortexPlanRoute;
                    };
                    if (_rushPoints isEqualTo []) then {_rushRefusal="EXPLICIT_NO_SAFE_AVENUE"};
                    if (count _points+count _rushPoints > 64) then {_rushRefusal="EXPLICIT_APPROACH_LIMIT"};
                };
            };
            if (_explicitValid && {_assault} && {count _points+2 > 64}) then {
                _rushRefusal="EXPLICIT_APPROACH_LIMIT";
            };
            if (_rushRefusal != "") exitWith {_result=_rushRefusal call _end};
            private _holdIdentity=[_drill get "index",_drill getOrDefault ["teamTurn",0],_drill get "pauseUntil"];
            private _holdPoints=_points apply {[+(_x select 0),_x select 1]};
            private _holdRoster=+(_drill get "units");
            private _holdTeams=(_drill getOrDefault ["teams",[]]) apply {+_x};
            private _holdNative=_fit apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x]};
            private _assaultRoute=if (_assault) then {
                [_centroid,_assaultCandidates,_enemyPos] call CBE_fnc_CortexSelectAvenue
            } else {[]};
            if (_explicitValid && {!_assaulting} && {_rushPoints isEqualTo []}
                && {_assaultRoute isEqualTo []}) exitWith {
                _result="EXPLICIT_NO_SAFE_AVENUE" call _end;
            };
            private _holdCommitted=false;
            private _holdComplete=false;
            private _holdIssue=false;
            isNil {
                if (!(call _helperCurrent)
                    || {(_drill getOrDefault ["stage",""]) != "HOLD"}
                    || {!([_drill get "index",_drill getOrDefault ["teamTurn",0],_drill get "pauseUntil"] isEqualTo _holdIdentity)}
                    || {time < (_drill get "pauseUntil")}
                    || {(_drill get "points") isNotEqualTo _holdPoints}
                    || {(_drill get "units") isNotEqualTo _holdRoster}
                    || {(_drill getOrDefault ["teams",[]]) isNotEqualTo _holdTeams}
                    || {(_drill getOrDefault ["assaulting",false]) != _assaulting}
                    || {_explicitKnowledge isNotEqualTo [] && {
                        (_state getOrDefault ["explicitKnowledge",[]]) isNotEqualTo _explicitKnowledge
                            || {_rushObservedAge+(time-_now) > 10}
                    }}
                    || {([_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled) != _assaultEnabled}
                    || {(_state getOrDefault ["moraleState","STEADY"]) != "STEADY" && {_assault}}
                    || {!_support && {
                        private _currentObjective=if (_explicitOrder isEqualTo []) then {
                            _state getOrDefault ["enemyPos",_drill get "enemyPos"]
                        } else {_drill get "enemyPos"};
                        _currentObjective isNotEqualTo _holdObjective
                    }}
                    || {_holdNative findIf {
                        _x params ["_actor","_command","_destination","_formationLeader"];
                        !([_actor] call _mayIssueMovement) || {currentCommand _actor != _command}
                            || {(expectedDestination _actor) isNotEqualTo _destination}
                            || {formLeader _actor != _formationLeader}
                    } >= 0}) exitWith {};
                if (_explicitKnowledge isNotEqualTo []) then {
                    _drill set ["enemyPos",+_enemyPos];
                    _drill set ["target",_rushTarget];
                };
                if (_rushPoints isNotEqualTo []) then {
                    private _nextIndex=count _points;
                    _points append _rushPoints;
                    _drill set ["approachChunks",(_drill getOrDefault ["approachChunks",1])+1];
                    _drill set ["index",_nextIndex];
                    _drill set ["teamTurn",0];
                    [_group,_drill,"START","EXPLICIT_NEXT_APPROACH"] call CBE_fnc_CortexDrillSetStage;
                    _holdIssue=true;
                } else {
                    if (_assaultRoute isNotEqualTo []) then {
                        private _approachPoint=+(_assaultRoute select 0);
                        private _clearPoint=+(_assaultRoute select 1);
                        _assaultDirection=_approachPoint getDir _clearPoint;
                        // Snapshot the reported objective. New reports must not drag this crossing
                        // behind the actors or reverse their frontage halfway through the assault.
                        _drill set ["assaulting", true];
                        _drill set ["assaultObjective",+_enemyPos];
                        _drill set ["assaultDirection",_assaultDirection];
                        _drill set ["assaultGrenade",random 1 < ([_group,"assaultChance"] call CBE_fnc_CortexProfile)];
                        _points pushBack [_approachPoint, "ASSAULT"];
                        _points pushBack [_clearPoint, "CLEAR"];
                        missionNamespace setVariable ["CBE_AIPass_Assaults", (missionNamespace getVariable ["CBE_AIPass_Assaults", 0]) + 1];
                        // Route selection already committed a safe avenue. Preserve the diagnostic
                        // transition, then issue its first approach in this same budgeted group step.
                        [_group,_drill,"START","ASSAULT_COMMITTED"] call CBE_fnc_CortexDrillSetStage;
                        _drill set ["teamTurn",0];
                        _drill set ["index",count _points-2];
                        _holdIssue=true;
                    } else {
                        if ((_drill getOrDefault ["type","FLANK"]) == "FLANK" && {_teams isEqualTo []}) then {
                            // No assault is a valid tactical choice, not permission to leave
                            // the leader and covering element permanently at the old position.
                            _drill set ["finishFlank",true];
                            _drill set ["pauseUntil",_now];
                        } else {_holdComplete=true};
                    };
                    };
                _holdCommitted=true;
            };
            if (!_holdCommitted) exitWith {_result=0.25};
            if (_holdIssue) then {call _issue};
            if (_holdComplete) then {_result = "COMPLETE" call _end};
        };
    };
};
// PAUSE and HOLD remain explicit observable FSM phases, but a ready zero-duration handoff must not
// inherit the ordinary movement observation cadence. Queue it for the next bounded scheduler
// opportunity; the scheduler still enforces its global work budget and never spins this callback.
if (_result >= 0 && {_result != 0.25}
    && {(_drill getOrDefault ["stage",""]) in ["PAUSE","HOLD"]}
    && {_now >= (_drill getOrDefault ["pauseUntil",_now])}) then {
    _result=0;
};
_result

