/*
 * Author: WaldoTheWarfighter
 * Purpose: Cancels one matching CBE operation and removes only its owned movement state.
 * Locality/authority: Current group owner only; callers forward before invoking when required.
 * Final retirement atomically checks original generation/operation and entry owner epoch after cleanup.
 * Repeat/JIP: A missing or superseded generation is a no-op. Previous-owner work is rejected except for the new owner's explicit OWNERSHIP_LOST cleanup.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 reason <STRING, CANCELLED>.
 * Return Value: BOOL - true when the matching operation was cancelled.
 * Current callers: OperationStart, Zeus handover, release and recovery failure paths.
 * Example: [group player,4,"ZEUS"] call CBE_fnc_OperationCancel;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_reason","CANCELLED",[""]]];
if (isNull _group || {!local _group}) exitWith {false};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _entryEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _operationEpoch=_operation getOrDefault ["ownerEpoch",-1];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {false};
if (toUpperANSI _reason != "OWNERSHIP_LOST"
    && {(_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
private _cancelAdmitted=false;
isNil {
    private _current=_group getVariable ["CBE_Operation",createHashMap];
    if (local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_current getOrDefault ["generation",-2]) == _generation}
        && {(_current getOrDefault ["ownerEpoch",-2]) == _operationEpoch}
        && {_current isEqualTo _operation}) then {
        _operation set ["cancelReason",toUpperANSI _reason];
        _operation set ["phase","CANCELLED"];
        _cancelAdmitted=true;
    };
};
if (!_cancelAdmitted) exitWith {false};
[_group,_operation,_reason] call CBE_fnc_OperationRestore;
[_group,createHashMap,objNull,[],"RELEASE",_generation] call CBE_fnc_CortexVehicleReverseStep;
[_group,_generation] call CBE_fnc_CortexGroupMoveClear;
// Only an on-foot operation can have acquired a danger posture lease. Air, vehicle and naval
// operations share the generation record without touching their native combat state on release.
private _dangerActor=objNull;
if (_operation getOrDefault ["dangerPosture",false]) then {
    // Resolve and release posture only while this operation still owns the lease. Cleanup
    // before this point can yield; a successor must retain its own reaction and baseline.
    isNil {
        private _current=_group getVariable ["CBE_Operation",createHashMap];
        private _postureLease=_group getVariable ["CBE_Danger_ReactionLease",[]];
        if (local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_current getOrDefault ["generation",-2]) == _generation}
            && {_current isEqualTo _operation}
            && {(_group getVariable ["CBE_OperationGeneration",-1]) == _generation}
            && {count _postureLease == 8} && {(_postureLease select 5) == _generation}
            && {(_postureLease select 6) == _operationEpoch}) then {
            _dangerActor=[_group] call CBE_fnc_CortexGroupAnchor;
            if (isNull _dangerActor) then {_dangerActor=leader _group};
            [_dangerActor,"RELEASE"] call CBE_fnc_DangerReact;
        };
    };
};
// Cleanup can yield or trigger a successor. Retire only the operation captured at entry.
private _retired=false;

isNil {
    private _current=_group getVariable ["CBE_Operation",createHashMap];
    if (local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_current getOrDefault ["generation",-2]) == _generation}
        && {(_current getOrDefault ["ownerEpoch",-2]) == _operationEpoch}
        && {_current isEqualTo _operation}) then {

        _group setVariable ["CBE_Operation",nil,true];
        _group setVariable ["CBE_OperationResult",[_operation getOrDefault ["intent",""],"CANCELLED",_generation,serverTime,toUpperANSI _reason],true];
        _retired=true;
    };
};

if (!_retired) exitWith {false};
// Cancellation can return a group directly to the still-live contact that began the operation.
// Re-evaluate only the existing bounded context after clearing the old movement owner; the danger
// layer itself rejects Zeus, player and specialist ownership and issues no destination or target.
private _dangerResponse=_group getVariable ["CBE_Danger_Response",[]];
if (_operation getOrDefault ["dangerPosture",false] && {count _dangerResponse == 5}
    && {(_dangerResponse select 4) == (_group getVariable ["CBE_Danger_Generation",-1])}
    && {time < (_dangerResponse select 3)}) then {
    private _dangerEvent=_group getVariable ["CBE_Danger_ResponseEvent",[]];
    if (!(count _dangerEvent in [4,5,6,7,8])
        || {(_dangerEvent param [0,"",[""]]) != (_dangerResponse select 0)}
        || {(_dangerEvent param [2,-1,[0]]) != (_dangerResponse select 2)}) then {
        _dangerEvent=_dangerResponse select [0,4];
    };
    if (isNull _dangerActor) then {_dangerActor=[_group] call CBE_fnc_CortexGroupAnchor};
    private _dangerAction=[_group,_dangerEvent] call CBE_fnc_DangerActionSelect;
    [_dangerActor,_dangerEvent select 0,_dangerEvent select 1,_dangerAction] call CBE_fnc_DangerReact;
};
true
