/*
 * Author: WaldoTheWarfighter
 * Purpose: Completes a matching CBE operation after its physical outcome is known.
 * Locality/authority: Current group owner only; final retirement rechecks the captured
 * operation generation, entry epoch and exact operation after cleanup.
 * Repeat/JIP: A cancelled, replaced, previous-owner or externally claimed operation is not reported as complete. The completion record is public.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 result <STRING, COMPLETE>; 3 reason <STRING, COMPLETE>.
 * Return Value: BOOL - true when the matching operation was released.
 * Current callers: OperationStep and finite feature completion paths.
 * Example: [group player,4,"COMPLETE","OBJECTIVE_REACHED"] call CBE_fnc_OperationRelease;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_result","COMPLETE",[""]],["_reason","COMPLETE",[""]]];
if (isNull _group || {!local _group}) exitWith {false};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _entryEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _operationEpoch=_operation getOrDefault ["ownerEpoch",-1];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {false};
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])) exitWith {false};
if ((_operation getOrDefault ["phase",""]) == "CANCELLED") exitWith {false};
// Completion queued before a takeover is no longer an owned physical outcome. Retire only the
// matching generation as cancelled; never publish COMPLETE over a curator/specialist handover.
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {
    private _handoverReason=["EXTERNAL","ZEUS"] select ([_group] call CBE_fnc_CortexZeusHeld);
    [_group,_generation,_handoverReason] call CBE_fnc_OperationCancel;
    false
};
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
private _lateTakeover=false;
isNil {
    private _current=_group getVariable ["CBE_Operation",createHashMap];
    if (local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_current getOrDefault ["generation",-2]) == _generation}
        && {(_current getOrDefault ["ownerEpoch",-2]) == _operationEpoch}
        && {_current isEqualTo _operation}) then {
        // Cancellation owns its terminal result even while its cleanup record is still present.
        if ((_current getOrDefault ["phase",""]) == "CANCELLED") exitWith {};
        if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {_lateTakeover=true};
        _group setVariable ["CBE_Operation",nil,true];
        _group setVariable ["CBE_OperationResult",[_operation getOrDefault ["intent",""],toUpperANSI _result,_generation,serverTime,toUpperANSI _reason],true];
        _retired=true;
    };
};
if (_lateTakeover) exitWith {
    private _handoverReason=["EXTERNAL","ZEUS"] select ([_group] call CBE_fnc_CortexZeusHeld);
    [_group,_generation,_handoverReason] call CBE_fnc_OperationCancel;
    false
};
if (!_retired) exitWith {false};
// Completion can return a group directly to a still-live contact. Reclassify only that existing
// bounded context after the movement owner is gone, so the group keeps its combat posture without
// receiving a second route, target or firing controller. External ownership is rejected downstream.
private _dangerResponse=_group getVariable ["CBE_Danger_Response",[]];
if (_operation getOrDefault ["dangerPosture",false] && {count _dangerResponse == 5}
    && {(_dangerResponse select 4) == (_group getVariable ["CBE_Danger_Generation",-1])}
    && {time < (_dangerResponse select 3)}) then {
    private _dangerEvent=_group getVariable ["CBE_Danger_ResponseEvent",[]];
    if (!(count _dangerEvent in [4,5,6,7])
        || {(_dangerEvent param [0,"",[""]]) != (_dangerResponse select 0)}
        || {(_dangerEvent param [2,-1,[0]]) != (_dangerResponse select 2)}) then {
        _dangerEvent=_dangerResponse select [0,4];
    };
    if (isNull _dangerActor) then {_dangerActor=[_group] call CBE_fnc_CortexGroupAnchor};
    private _dangerAction=[_group,_dangerEvent] call CBE_fnc_DangerActionSelect;
    [_dangerActor,_dangerEvent select 0,_dangerEvent select 1,_dangerAction] call CBE_fnc_DangerReact;
};
true
