/*
 * Author: WaldoTheWarfighter
 * Purpose: Own one same-group naval passenger's finite foot egress after physical disembarkation.
 * Locality/authority: Actor and group owner only. Existing naval operation, token, original
 * deadline, native route and individual task authority are required before RecoveryStep issues
 * its single move. This helper creates no FSM, queue, polling loop, waypoint or boarding task.
 * Repeat/JIP: Public request/result receipts prevent replay after owner changes. A replacement
 * owner retires the old context rather than issuing it again. Original naval expiry is never
 * renewed. Exact pending cleanup remains reserved and is observed by existing DangerSetup.
 * Unchanged pre-request state is not rejection. Release requests STOP only for an acknowledged
 * exact owned MOVE, never over newer orders. STOP is observed, not assumed. After the original
 * expiry plus30s, unresolved proof remains but grants no late command or fresh cleanup clock.
 * Arguments: 0 mode STRING STEP/RELEASE/REAP; 1 actor OBJECT objNull;
 * 2 STEP context ARRAY [token,boat,goal ATL,original naval expiry,generation,route receipt].
 * STEP is called unscheduled by the current group job; its shared route snapshot is read once
 * per group pass. Scheduled callers re-read it. Native issue and retirement are unscheduled
 * transactions; RELEASE/REAP independently read native intent.
 * Return: STRING ACTIVE/WAIT/ARRIVED/INTERRUPTED/RELEASED/UNRESOLVED/NONE.
 * At most one actor and existing operation bookkeeping per call; no world or group roster query.
 * Arrival proves position only, not protection, combat effectiveness or complete naval delivery.
 * Current callers: CortexNavalAssault, CortexNavalRelease and existing sparse DangerSetup.
 * Example: ["RELEASE",soldier1] call CBE_fnc_CortexNavalEgressActor;
 */
params [["_mode","STEP",[""]],["_actor",objNull,[objNull]],["_context",[],[[]]]];
if (isNull _actor || {!local _actor} || {!(_mode in ["STEP","RELEASE","REAP"])}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {"NONE"};
private _callWasScheduled=canSuspend;
private _result="NONE";
isNil {
_result=call {
private _group=group _actor;
private _vector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _available={!isNull _group && {local _group} && {!isPlayer _actor}
    && {[_actor] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _actor}
    && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!fleeing _actor}
    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {isNull remoteControlled _actor}
    && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
    && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
    && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
    && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}};
private _journal=_actor getVariable ["CBE_Cortex_NavalEgressMove",[]];
if (_journal isEqualTo []) exitWith {
    if (_mode != "STEP" || {count _context != 6}) exitWith {"NONE"};
    _context params ["_token","_boat","_goal","_expires","_generation","_route"];
    private _previousResult=_actor getVariable ["CBE_Cortex_NavalEgressResult",[]];
    if (count _previousResult >= 2 && {(_previousResult select 0) == _token}) exitWith {_previousResult select 1};
    if (!(_goal call _vector) || {!(_expires isEqualType 0)} || {!finite _expires}
        || {serverTime >= _expires} || {!call _available}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}
        || {!([_group,"CBE_AIPass_NavalAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!(toUpperANSI currentCommand _actor in ["","ATTACK","FIRE","SUPPRESS"])} || {getUnitState _actor in ["INIT","PLANNING","REPLAN"]}
        || {[_actor] call CBE_fnc_CortexActorMoveReserved}) exitWith {"WAIT"};
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    private _plan=_boat getVariable ["CBE_Cortex_NavalPlan",[]];
    if (count _plan != 9 || {(_plan select 0) != _token} || {(_plan select 1) != _group}
        || {(_plan select 7) != _expires} || {(_plan select 8) != "DISEMBARK"}
        || {(_operation getOrDefault ["generation",-2]) != _generation}
        || {(_operation getOrDefault ["ownerEpoch",-1]) != _epoch}
        || {(_operation getOrDefault ["intent",""]) != "NAVAL_ASSAULT"}
        || {_route isEqualTo []} || {_callWasScheduled && {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _route}}) exitWith {"WAIT"};
    if (surfaceIsWater _goal || {(surfaceNormal _goal select 2) < 0.65}) exitWith {
        _actor setVariable ["CBE_Cortex_NavalEgressResult",[_token,"INTERRUPTED",serverTime,+_goal],true];"INTERRUPTED"
    };
    // Declare this original landing participant before using the shared one-attempt executor.
    private _participants=+(_operation getOrDefault ["participants",[]]);
    if !(_actor in _participants) then {
        _participants pushBack _actor;
        _operation set ["participants",_participants];
        _group setVariable ["CBE_Operation",_operation,true];
    };
    private _before=[currentCommand _actor,+(expectedDestination _actor),formLeader _actor];
    private _issued=serverTime;
    private _status=[_group,_generation,_actor,_goal] call CBE_fnc_RecoveryStep;
    if (_status == "EXHAUSTED") exitWith {
        _actor setVariable ["CBE_Cortex_NavalEgressResult",[_token,"INTERRUPTED",serverTime,+_goal],true];"INTERRUPTED"
    };
    if (_status != "RECOVERING") exitWith {"WAIT"};
    private _reservation=["NAVAL_EGRESS",+_goal,time+(_expires-serverTime)];
    _actor setVariable ["CBE_Cortex_ActorMove",_reservation];
    _actor setVariable ["CBE_Cortex_NavalEgressMove",[_group,_token,_expires,_generation,_epoch,
        +_route,+_goal,"MOVING",_before,_issued,+_reservation],true];
    "ACTIVE"
};
if (!(_journal isEqualType []) || {count _journal != 11}) exitWith {"UNRESOLVED"};
_journal params ["_oldGroup","_token","_expires","_generation","_epoch","_route","_goal","_phase","_before","_issued","_reservation"];
if (!(_goal call _vector) || {!(_expires isEqualType 0)} || {!finite _expires}
    || {!(_before isEqualType [])} || {count _before != 3}) exitWith {"UNRESOLVED"};
// Active requests are monitored by their group job; discovery only reaps expired/retired work.
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _sameOwner=_group == _oldGroup && {!isNull _group} && {local _group}
    && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {_generation == (_group getVariable ["CBE_OperationGeneration",-1])};
private _roleActive=_sameOwner && {(_operation getOrDefault ["intent",""]) == "NAVAL_ASSAULT"}
    && {(_operation getOrDefault ["phase",""]) != "CANCELLED"}
    && {serverTime < _expires} && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {!([] call CBE_fnc_CortexIsPaused)}
    && {[_group,"CBE_AIPass_NavalAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled};
if (_mode == "REAP" && {_roleActive} && {_phase == "MOVING"}) exitWith {"ACTIVE"};
private _liveRoute=if (_mode == "STEP" && {count _context == 6} && {!_callWasScheduled}) then {_context select 5}
    else {[_group] call CBE_fnc_NativeOrderReceipt};
private _sameContext=_sameOwner && {_liveRoute isEqualTo _route};
private _sameReservation=(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _reservation;
private _report={
    params ["_outcome"];
    if (((_actor getVariable ["CBE_Cortex_NavalEgressResult",[]]) select [0,2]) isNotEqualTo [_token,_outcome]) then {
        _actor setVariable ["CBE_Cortex_NavalEgressResult",[_token,_outcome,serverTime,+_goal],true];
    };
};
private _retire={
    params ["_result"];
    if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _reservation) then {_actor setVariable ["CBE_Cortex_ActorMove",nil]};
    if ((_actor getVariable ["CBE_Cortex_NavalEgressMove",[]]) isEqualTo _journal) then {
        _actor setVariable ["CBE_Cortex_NavalEgressMove",nil,true];
        _actor setVariable ["CBE_Cortex_NavalEgressResult",[_token,_result,serverTime,+_goal],true];
    };
    _result
};
if (!_sameContext || {!_sameReservation} || {!call _available}) exitWith {["INTERRUPTED"] call _retire};
private _command=toUpperANSI currentCommand _actor;
private _destination=(expectedDestination _actor) param [0,[],[[]]];
private _owns=_command == "MOVE" && {_destination call _vector} && {_destination vectorDistance _goal <= 0.25};
private _pending=currentCommand _actor in [_before select 0,"MOVE"]
    && {(expectedDestination _actor) isEqualTo (_before select 1)}
    && {formLeader _actor isEqualTo (_before select 2)} && {!_owns};
if (_phase == "STOP_PENDING") exitWith {
    if (_command in ["STOP","WAIT",""] && {vectorMagnitude velocity _actor < 0.5}) exitWith {["RELEASED"] call _retire};
    if (!_owns) exitWith {["INTERRUPTED"] call _retire};
    if (serverTime >= _expires+30) then {
        ["UNRESOLVED"] call _report;
    };
    "ACTIVE"
};
if ((getPosASL _actor) vectorDistance (AGLToASL _goal) <= 3) exitWith {["ARRIVED"] call _retire};
if (_mode == "RELEASE" || {!_roleActive}) exitWith {
    if (_pending || {_owns && {serverTime >= _expires+30}}) exitWith {
        ["UNRESOLVED"] call _report;"UNRESOLVED"
    };
    if (_owns) exitWith {
        _journal set [7,"STOP_PENDING"];
        _actor setVariable ["CBE_Cortex_NavalEgressMove",_journal,true];
        doStop _actor;
        "ACTIVE"
    };
    ["INTERRUPTED"] call _retire
};
if (!_owns && {!_pending}) exitWith {["INTERRUPTED"] call _retire};
"ACTIVE"
};
false
};
_result
