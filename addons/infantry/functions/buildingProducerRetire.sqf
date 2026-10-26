/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe actual completion of the original clearance-related FSM handles after locality loss.
 * Locality/authority: Original machine only, metadata observation. taskGroup deliberately does
 * not grant the nonlocal group shared-scheduler command authority. No successor is cancelled.
 * Repeat/JIP: One exact-capture keyed finite observer, at most8 checks inside the original
 * capture time+3s and episode deadline. Duplicate callbacks do not reset attempts or clocks.
 * Actual completedFSM, old-brain retirement, replaced private pointers and unchanged
 * post-edge actor/settings records are all required. Intentional edge cleanup precedes the baseline.
 * This is original-FSM retirement only, not all-writer quiescence, a server seal or readiness.
 * One original-owner CAPTURE submission follows these checks; no retry or JIP replay.
 * Arguments: 0 state HASHMAP default empty: taskGroup GROUP, capture ARRAY, writers ARRAY,
 * until NUMBER server time, attempts NUMBER, producer NUMBER, done BOOL; records ARRAY
 * [object/group,variableName,present,valueCopy] rows, max578, after intentional edge cleanup.
 * Writer [original object/group,brain variable name,original FSM handle,original brain].
 * Return: NUMBER .25 while waiting, -1 on completion/refusal/expiry.
 * Current callers: CortexLocality via existing CortexQueueJob after original pointer retirement.
 * Example: [CBE_fnc_BuildingProducerRetire,_retire,0,_retireKey] call CBE_fnc_CortexQueueJob;
 */
params [["_state",createHashMap,[createHashMap]]];
private _group=_state getOrDefault ["taskGroup",grpNull];
private _capture=_state getOrDefault ["capture",[]];
private _finish={
    params ["_reason"];
    _state set ["done",true];_state set ["result",_reason];
    _state deleteAt "writers";_state deleteAt "records";
    -1
};
if (_state getOrDefault ["done",false]) exitWith {-1};
if (!(_capture isEqualType []) || {count _capture != 17}
    || {(_capture select 0) != 12} || {(_capture select 1) != clientOwner}
    || {isNull _group} || {local _group} || {isRemoteExecuted}
    || {(_state getOrDefault ["producer",-1]) != clientOwner}
    || {groupOwner _group != (_state getOrDefault ["incomingOwner",-1])}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {(_group getVariable ["CBE_Cortex_ClearRetireLocal",createHashMap]) isNotEqualTo _state}
    || {(_group getVariable ["CBE_Cortex_ClearLaneCaptureLocal",[]]) isNotEqualTo _capture}) exitWith {["REPLACED"] call _finish};
private _until=_state getOrDefault ["until",-1];
private _attempts=_state getOrDefault ["attempts",0];
if (!(_until isEqualType 0) || {!finite _until} || {serverTime >= _until}
    || {!(_attempts isEqualType 0)} || {!finite _attempts} || {_attempts < 0}
    || {_attempts != floor _attempts} || {_attempts >= 8}) exitWith {["UNCONFIRMED"] call _finish};
_state set ["attempts",_attempts+1];
private _writers=_state getOrDefault ["writers",[]];
if (!(_writers isEqualType []) || {count _writers < 1} || {count _writers > 131}) exitWith {["INVALID_WRITERS"] call _finish};
private _pending=false;private _invalid=false;
{
    private _row=_x;
    if (!(_row isEqualType []) || {count _row != 4}
        || {[0,1,2,3] findIf {isNil {_row select _x}} >= 0}) exitWith {_invalid=true};
    _row params ["_object","_variable","_handle","_brain"];
    if (!(_object isEqualType objNull || {_object isEqualType grpNull}) || {isNull _object}
        || {!(_variable isEqualType "")} || {!(_handle isEqualType 0)} || {!finite _handle}
        || {_handle < 0} || {!(_brain isEqualType createHashMap)} || {count _brain == 0}) exitWith {_invalid=true};
    if ((_object getVariable [_variable,createHashMap]) isEqualTo _brain) exitWith {_invalid=true};
    if (!(_brain getOrDefault ["cancelled",false]) && {!(_brain getOrDefault ["finished",false])}) then {_pending=true};
    if (!completedFSM _handle) then {_pending=true};
} forEach _writers;
if (_invalid) exitWith {["WRITER_IDENTITY_CHANGED"] call _finish};
if (_pending) exitWith {0.25};
// Compare after actual old-FSM exit. A mismatch refuses, never refreshes the baseline.
private _records=_state getOrDefault ["records",[]];
if (!(_records isEqualType []) || {count _records < 2} || {count _records > 578}) exitWith {["INVALID_RECORDS"] call _finish};
private _recordsChanged=_records findIf {
    private _record=_x;
    if (!(_record isEqualType []) || {count _record != 4}
        || {[0,1,2,3] findIf {isNil {_record select _x}} >= 0}) exitWith {true};
    _record params ["_object","_variable","_present","_original"];
    if (!(_object isEqualType objNull || {_object isEqualType grpNull}) || {isNull _object}
        || {!(_variable isEqualType "")} || {!(_present isEqualType true)}) exitWith {true};
    private _currentPresent=!isNil {_object getVariable _variable};
    _currentPresent isNotEqualTo _present || {_present && {(_object getVariable _variable) isNotEqualTo _original}}
} >= 0;
if (_recordsChanged) exitWith {["SOURCE_METADATA_CHANGED"] call _finish};
// The callback is unscheduled; only this original private capture gets the observation.
_group setVariable ["CBE_Cortex_ClearFSMRetiredLocal",[_capture select [0,7],serverTime,count _writers]];
// Submission is once and remains explicitly unsealed; this is not a server acknowledgement.
private _registration=(_capture select 16) select 3;
private _submission=[_registration,_capture,serverTime,count _writers,_state get "incomingOwner"];
_state set ["submitted",true];
if (isServer) then {["CAPTURE",_submission] call CBE_fnc_BuildingProducerRegister}
else {["CAPTURE",_submission] remoteExecCall ["CBE_fnc_BuildingProducerRegister",2]};
["ORIGINAL_FSMS_RETIRED"] call _finish
