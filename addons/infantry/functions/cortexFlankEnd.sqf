/*
 * Author: WaldoTheWarfighter
 * ADMISSION observations grant no actor recall/hold authority; exact settings restoration is separate.
 * Group policy restoration respects native tasks; unresolved pairs are historical evidence only.
 * Native STOP cleanup requires a matching current-drill HOLD receipt; MOVE cleanup requires
 * the actual requested destination. Unknown/changed tasks remain untouched. Restoring owned
 * feature settings does not authorize movement recall. Native flight and queued care
 * also prohibit recall; exact owned feature restoration remains independent.
 * Completed ordinary holds retain original issuer and native destination/order provenance.
 * Failed support-bound and transient retry stops remain separate ownership roles.
 * Reservation policy: unknown/malformed/nonfinite actor leases remain owned through the
 * shared owner-local CortexActorMoveReserved predicate at admission and command/cleanup gates.
 * Explicit ground-element cleanup uses a surviving foot member for formation return;
 * it cannot recall that element to a boat-based or nonparticipant native group leader.
 * No available element anchor means no follow command.
 * Ends a drill (flank, bounding advance or direct assault). Restores owned unit and group combat-mode overrides only
 * while the current mode still matches the value Cortex applied; later external changes survive.
 *
 * Restores the leader attack-assignment setting and only the AI features the drill disabled. A drill that completed, or stopped because the
 * enemy is close, leaves its members holding the ground they took: they are recorded as "holders" and
 * rejoin formation later (CBE_fnc_CortexGroupTick, CBE_fnc_CortexRestoreCalm,
 * CBE_fnc_CortexRetreat). Any other ending (losses, the squad leaving contact, Zeus taking the
 * group, or release) orders members to follow the leader again at once, unless replacement
 * orders or external ownership prohibit movement commands. A failed coordinated
 * bound instead holds its gained ground until the next server sequence; it must not regroup
 * Completed ordinary holds capture original issuer and native destination/order provenance.
 * Completed support bounds retain parent support-hold receipts for the next role; passive
 * MOVE-to-COVER handover transfers only exact current-drill STOPs without native commands.
 * This does not turn failed support-bound holds or transient retry stops into ordinary holds.
 * backwards before a retry. Holding uses an ordinary stop order and never disables PATH, so a
 * replacement mission, Zeus order or locality handover cannot inherit frozen actors.
 * The drill's type-specific cooldown starts: advances may resume sooner than wide flanks. Cleanup
 * releases a TACTICAL_DRILL movement lease only; a newer
 * withdrawal, vehicle, artillery or coordinated-assault owner survives a delayed drill callback.
 * Locality and authority: call where the group is local.
 *
 * Repeat/JIP: finite callers bind their original token even when the supplied state map changes;
 * actor/group restoration and feedback share an unscheduled current-identity transaction;
 * terminal retirement rechecks that identity after shared operation cleanup;
 * an empty drill is a no-op; the ending reason is published for observers and JIP.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: reason <STRING> - COMPLETE, CLOSE, ABORT, LOSSES, STALLED, TIME_LIMIT, RELEASE, ZEUS, CALM,
 *    ROE_CHANGED, SPEED_CHANGED, ATTACK_POLICY_CHANGED, GRENADE_UNRESOLVED, AMMO_CAPACITY_LOST, FIRE_CAPACITY_LOST, RECOVERY_FAILED, OWNERSHIP_LOST, FSM_START_FAILED, FSM_EXECUTOR_ENDED or SCHEDULER_STALLED
 * 3: expected drill token <STRING, empty> - finite callbacks pass their original token;
 *    empty retains direct current-task administrative cleanup.
 * Unresolved stragglers change COMPLETE/CLOSE to PARTIAL; main actors hold while stragglers rejoin.
 *
 * Return Value:
 * BOOL - true when matching cleanup reached its terminal publication; false for stale/no authority.
 *
 * Example:
 * [_group, _state, "COMPLETE"] call CBE_fnc_CortexFlankEnd;
 * Result: the element stays on the enemy's flank instead of running back to the leader.
 *
 * Current callers: CortexFlankStep, CortexReleaseGroup, CortexGroupTick, CortexDrillStart and CortexDrillInterrupt.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_reason", "", [""]], ["_expectedToken","",[""]]];
if (isNull _group || {!local _group}) exitWith {false};
private _drill = _state getOrDefault ["drill", createHashMap];
if (count _drill == 0 || {_expectedToken != "" && {(_drill getOrDefault ["token",""]) != _expectedToken}}) exitWith {false};
// An old owner or replaced generation has no authority over feature switches or cleanup.
if ((_drill getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])
    || {(_drill getOrDefault ["operationGeneration",-1]) != (_group getVariable ["CBE_OperationGeneration",0])}) exitWith {false};
private _liveDrill=(_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap];
if (count _liveDrill > 0 && {(_liveDrill getOrDefault ["token",""]) != (_drill getOrDefault ["token",""])}
    || {_expectedToken != "" && {(_liveDrill getOrDefault ["token",""]) != _expectedToken}}) exitWith {false};
private _endingToken=_drill getOrDefault ["token",""];
private _endingEpoch=_drill getOrDefault ["ownerEpoch",-1];
private _endingGeneration=_drill getOrDefault ["operationGeneration",-1];
private _stillEnding={
    private _currentState=_group getVariable ["CBE_AIPass_State",createHashMap];
    private _current=_currentState getOrDefault ["drill",createHashMap];
    local _group && {_currentState isEqualTo _state} && {_endingEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_endingGeneration == (_group getVariable ["CBE_OperationGeneration",0])}
        && {(_current getOrDefault ["token",""]) == _endingToken}
};
private _supportToken="";
private _restorationDone=false;
// Keep actor/group restoration and feedback together; shared operation release below may
// perform separate work and deliberately remains outside this no-geometry transaction.
isNil {
if !(call _stillEnding) exitWith {};
private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
private _sameOperation=count _liveOperation == 0 || {(_liveOperation getOrDefault ["generation",-2]) == (_drill getOrDefault ["operationGeneration",-1])};
private _mayRestore=_sameOperation && {!(_reason in ["ZEUS","OWNERSHIP_LOST","EXTERNAL","REPLACED","ATTACK_POLICY_CHANGED"])}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)};
// A legitimate internal role change restores exact-owned controls without recalling the
// manoeuvre element. The incoming support/cover operation owns the next movement command.
private _endingAuthored=_drill getOrDefault ["authoredOrder",[]];
private _authoredCurrent=_endingAuthored isNotEqualTo [] && {
    _endingAuthored isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)
};
private _mayCommand = _mayRestore && {!(_reason in ["ZEUS","OWNERSHIP_LOST","ROLE_HANDOVER"])}
    && {_authoredCurrent} && {[_group] call CBE_fnc_CortexIsEligible};
private _mayRestoreActor={
    params ["_actor"];
    alive _actor && {local _actor} && {group _actor == _group} && {!isPlayer _actor}
        && {isNull remoteControlled _actor}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
};
private _groupModeLease = _drill getOrDefault ["groupCombatMode",[]];
private _groupSpeedLease = _drill getOrDefault ["groupSpeedMode",[]];
private _policyAvailable=_mayRestore && {[_group] call CBE_fnc_CortexGroupPostureTaskAvailable};
private _unresolvedPolicies=[];
if (_mayRestore && {count _groupModeLease == 2} && {combatMode _group == (_groupModeLease select 1)}) then {
    if (_policyAvailable) then {_group setCombatMode (_groupModeLease select 0)};
    if (!_policyAvailable || {combatMode _group != (_groupModeLease select 0)}) then {
        _unresolvedPolicies pushBack ["COMBAT",+_groupModeLease];
    };
};
if (_mayRestore && {count _groupSpeedLease == 2} && {speedMode _group == (_groupSpeedLease select 1)}) then {
    if (_policyAvailable) then {_group setSpeedMode (_groupSpeedLease select 0)};
    if (!_policyAvailable || {speedMode _group != (_groupSpeedLease select 0)}) then {
        _unresolvedPolicies pushBack ["SPEED",+_groupSpeedLease];
    };
};
// Historical evidence only, never a retry queue or authority for a later write.
if (_unresolvedPolicies isNotEqualTo []) then {
    _group setVariable ["CBE_Cortex_DrillPolicyUnresolved",
        [serverTime,_endingEpoch,_endingGeneration,_reason,_unresolvedPolicies],true];
};
{
    _x params ["_unit", "_feature"];
    if ([_unit] call _mayRestoreActor) then {_unit enableAI _feature};
} forEach (_drill getOrDefault ["disabled", []]);
{
    _x params ["_unit","_mode",["_ownedMode","BLUE"]];
    if (_mayRestore && {[_unit] call _mayRestoreActor} && {unitCombatMode _unit == _ownedMode}) then {_unit setUnitCombatMode _mode};
} forEach (_drill getOrDefault ["combatModes",[]]);
{
    _x params ["_unit","_previous","_owned"];
    if (_mayRestore && {[_unit] call _mayRestoreActor} && {behaviour _unit == _owned}) then {_unit setCombatBehaviour _previous};
} forEach (_drill getOrDefault ["combatBehaviours",[]]);
private _members = (_drill getOrDefault ["units", []]) select {alive _x && {local _x} && {group _x == _group}};
private _returnScoped=_drill getOrDefault ["elementScoped",false];
private _returnLeader=if (_returnScoped) then {
    [_group,_members] call CBE_fnc_CortexGroupAnchor
} else {leader _group};
private _returnElement={
    {if (!isNull _returnLeader && {!_returnScoped || {_x != _returnLeader}}) then {_x doFollow _returnLeader}} forEach _this;
};
// Retire only the temporary throw listener belonging to this cancelled/completed drill.
// Keep the projectile record: cancellation does not remove a live explosive from the world.
{
    private _flight = _x getVariable ["CBE_Cortex_FragFlight",[]];
    if (count _flight == 5 && {(_flight select 0) == (_drill getOrDefault ["token",""])}) then {
        private _handler = _x getVariable ["CBE_Cortex_FragHandler",-1];
        if (_handler >= 0) then {_x removeEventHandler ["FiredMan",_handler]};
        _x setVariable ["CBE_Cortex_FragHandler",-1];
    };
} forEach _members;
// Cleanup may recall only the current drill's exact native movement/hold receipt.
// The acknowledgement interval grants no cleanup right over an unconfirmed native MOVE.
private _ownsNativeMovement={
    params ["_actor"];
    private _row=(_drill getOrDefault ["nativeCommands",createHashMap]) getOrDefault [netId _actor,[]];
    // Admission observed a task but issued none. Settings restoration above stays
    // independent; this actor receives no movement/hold recall from that observation.
    if (_row isEqualType [] && {count _row == 7} && {(_row select 1) == "ADMISSION"}) exitWith {false};
    private _command=currentCommand _actor;
    if !(_command in ["STOP","MOVE"]) exitWith {true};
    if (count _row != 7 || {(_row select 0) != _actor} || {formLeader _actor != (_row select 3)}) exitWith {false};
    private _native=expectedDestination _actor;
    if (_command == "STOP") exitWith {(_row select 1) == "HOLD" && {_native isEqualTo (_row select 2)}};
    private _position=_native param [0,[],[[]]];
    private _goal=_row select 6;
    (_row select 1) == "MOVE" && {count _position == 3} && {count _goal == 3}
        && {_position vectorDistance _goal <= 0.25}
};
// Listener cleanup above still covers the old roster. Movement cleanup below may affect
// only capable foot actors whose current task has not acquired a newer independent owner.
_members=_members select {
    private _free=!([_x] call CBE_fnc_CortexActorMoveReserved);
    simulationEnabled _x && {!isObjectHidden _x} && {!fleeing _x}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && _free && {[_x] call _ownsNativeMovement} && {[_x] call CBE_fnc_CortexCombatEffective} && {!isPlayer _x} && {isNull objectParent _x}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
private _stragglers = ((_drill getOrDefault ["recovery",[]]) apply {_x select 0}) select {_x in _members};
_supportToken=_drill getOrDefault ["supportToken",""];
private _lease=_group getVariable ["CBE_AIPass_SupportLease",[]];
private _supportLeaseCurrent=_supportToken != "" && {(_state getOrDefault ["supportToken",""]) == _supportToken}
    && {_state getOrDefault ["assaulting",false]}
    && {_authoredCurrent}
    && {count _lease == 6} && {(_lease select 0) == _supportToken} && {serverTime < (_lease select 2)};
// A role handover issues no native command. Carry only current-drill owned STOPs
// into the same parent support journal before the child drill retires.
private _nextRole=_group getVariable ["CBE_Cortex_SupportRole",[]];
if (_reason == "ROLE_HANDOVER" && {_mayRestore} && {_supportLeaseCurrent}
    && {count _nextRole == 5} && {(_nextRole select 0) == _supportToken}
    && {(_nextRole select 2) == "COVER"}) then {
    private _handoverHolds=_state getOrDefault ["supportStopHolds",createHashMap];
    if (_handoverHolds isEqualType createHashMap && {count _handoverHolds <= 64}) then {
        {
            if (currentCommand _x == "STOP" && {count _handoverHolds < 64 || {netId _x in _handoverHolds}}) then {
                _handoverHolds set [netId _x,[_x,_supportToken,_endingGeneration,_endingEpoch,
                    +(expectedDestination _x),formLeader _x,_lease select 2]];
            };
        } forEach _members;
        _state set ["supportStopHolds",_handoverHolds];
    };
};
private _holdFailedBound=_mayCommand && {_supportLeaseCurrent}
    && {_reason in ["STALLED","TIME_LIMIT","RECOVERY_FAILED"]}
    && {[_group] call CBE_fnc_CortexIsEligible};
private _hold = _mayCommand && {_reason in ["COMPLETE","CLOSE"]};
if (_hold && {_stragglers isNotEqualTo []}) then {_reason = "PARTIAL"};
_group setVariable ["CBE_Cortex_DrillRecovery",[_reason,_stragglers,_drill getOrDefault ["index",-1]],true];
private _holdCompletedSupport=_hold && {_supportLeaseCurrent};
if (_holdFailedBound || {_holdCompletedSupport}) then {
    // A failed movement remains a failure. Preserve physical gains while the server
    // yields the turn; doFollow here creates repeated outward/return journeys.
    private _supportHolds=_state getOrDefault ["supportStopHolds",createHashMap];
    if !(_supportHolds isEqualType createHashMap) then {_supportHolds=createHashMap};
    if (count _supportHolds <= 64) then {
    {
        if (count _supportHolds < 64 || {netId _x in _supportHolds}) then {
            doStop _x;
            _supportHolds set [netId _x,[_x,_supportToken,_endingGeneration,_endingEpoch,
                +(expectedDestination _x),formLeader _x,_lease select 2]];
        };
    } forEach (if (_holdCompletedSupport) then {_members-_stragglers} else {_members});
    _state set ["supportStopHolds",_supportHolds];
    if (_holdCompletedSupport) then {_stragglers call _returnElement};
    };
} else {
if (_hold) then {
    private _holders = _state getOrDefault ["holders", []];
    private _holdRows=(_state getOrDefault ["holderRecallReceipts",[]]) select {
        _x isEqualType [] && {count _x == 8} && {(_x select 0) in _holders}
    };
    _holdRows=_holdRows select [0,64];
    private _holdOrder=+_endingAuthored;
    {
        private _actor=_x;
        private _slot=_holdRows findIf {(_x select 0) isEqualTo _actor};
        if (_slot >= 0 || {count _holdRows < 64}) then {
            doStop _actor;
            private _row=[_actor,_group,_endingToken,clientOwner,_endingEpoch,_endingGeneration,
                +((expectedDestination _actor) param [0,[]]),+_holdOrder];
            _actor setVariable ["CBE_Cortex_HolderToken",_row select [1,5],true];
            if (_slot < 0) then {_holdRows pushBack _row} else {_holdRows set [_slot,_row]};
            _holders pushBackUnique _actor;
        };
    } forEach (_members-_stragglers);
    _state set ["holderRecallReceipts",_holdRows];
    _stragglers call _returnElement;
    _state set ["holders", _holders];
} else {
    // Zeus has already supplied the replacement movement. Restore Cortex-owned
    // feature switches above, but do not replace that order with formation return.
    if (_mayCommand) then {_members call _returnElement};
};
};
isNil {
if !(call _stillEnding) exitWith {};
if (_supportToken != "") then {
    _group setVariable ["CBE_Cortex_SupportBoundResult",[_supportToken,_drill get "supportSequence",_reason],true];
} else {
    if (_mayCommand && {_state getOrDefault ["attackChanged",false]}) then {_group enableAttack (_state getOrDefault ["baseAttack",true])};
    _state deleteAt "attackChanged";
    _state deleteAt "baseAttack";
};
};
_restorationDone=true;
};
if (!_restorationDone) exitWith {false};
private _type = _drill getOrDefault ["type", "FLANK"];
private _operationGeneration=_drill getOrDefault ["operationGeneration",-1];
// A coordinated bound is a child phase; SupportMaintain owns the parent operation lifetime.
if (_operationGeneration >= 0 && {_supportToken == ""}) then {
    if (_reason in ["COMPLETE","CLOSE","PARTIAL"]) then {
        [_group,_operationGeneration,["COMPLETE","PARTIAL"] select (_reason == "PARTIAL"),_reason] call CBE_fnc_OperationRelease;
    } else {
        [_group,_operationGeneration,_reason] call CBE_fnc_OperationCancel;
    };
};
private _retired=false;
isNil {
if !(call _stillEnding) exitWith {};
_group setVariable ["CBE_Cortex_DrillResult",[_type,_reason,time],true];
[_group,_drill,"ENDED",_reason] call CBE_fnc_CortexDrillSetStage;
// Cancel only this exact queued executor. Its callback may survive until the next
// scheduler opportunity; it must neither refresh a heartbeat nor act on a successor.
private _executorJob=_group getVariable ["CBE_Cortex_DrillFSMJob",createHashMap];
if ((_executorJob getOrDefault ["drillToken",""]) == _endingToken
    && {(_executorJob getOrDefault ["ownerEpoch",-1]) == _endingEpoch}
    && {(_executorJob getOrDefault ["operationGeneration",-1]) == _endingGeneration}) then {
    _executorJob set ["cancelled",true];
    _executorJob set ["done",true];
    private _executorRecord=_group getVariable ["CBE_Cortex_DrillFSM",[]];
    if (count _executorRecord == 2 && {(_executorRecord select 0) == _endingToken}
        && {(_executorRecord select 1) isEqualTo (_executorJob getOrDefault ["fsmHandle",-1])}) then {
        _group setVariable ["CBE_Cortex_DrillFSM",nil];
    };
    _group setVariable ["CBE_Cortex_DrillFSMJob",nil];
};
_state deleteAt "drill";
private _movementLease = _state getOrDefault ["movementLease",[]];
if (count _movementLease == 2 && {(_movementLease select 0) == "TACTICAL_DRILL"}) then {
    [_group,"TACTICAL_DRILL",false] call CBE_fnc_CortexOwnershipLease;
    _state deleteAt "movementLease";
};
private _cooldownName=switch (_type) do {
    case "ADVANCE": {"CBE_AIPass_Advance_Cooldown"};
    case "ASSAULT": {"CBE_AIPass_Assault_Cooldown"};
    default {"CBE_AIPass_Flank_Cooldown"};
};
private _cooldownDefault=switch (_type) do {case "ADVANCE": {20}; case "ASSAULT": {15}; default {90}};
[_state, toLowerANSI _type, missionNamespace getVariable [_cooldownName, _cooldownDefault]] call CBE_fnc_CortexCooldown;
if (_reason == "COMPLETE") then {
    private _counter=switch (_type) do {
        case "ADVANCE": {"CBE_AIPass_AdvancesCompleted"};
        case "ASSAULT": {"CBE_AIPass_AssaultsCompleted"};
        default {"CBE_AIPass_FlanksCompleted"};
    };
    missionNamespace setVariable [_counter,(missionNamespace getVariable [_counter,0])+1];
};
if (missionNamespace getVariable ["CBE_AIPass_Debug", false]) then {diag_log format ["[CBE] %1 %2 end reason=%3", _group, _type, _reason]};
_retired=true;
};
_retired
