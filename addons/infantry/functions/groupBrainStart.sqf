/*
 * Author: WaldoTheWarfighter
 * Reuse requires the current generation and a live FSM handle as well as matching owner epoch.
 * A stale map cannot consume a danger wake after its executor has ended.
 * Purpose: Start or wake the one owner-local tactical brain for an eligible ground group.
 * Locality / Authority: Must run where the group is local. It never transfers ownership and never
 * issues movement; the FSM routes bounded decisions through the shared CBE scheduler.
 * Repeat/JIP: Repeated calls reuse the current owner epoch and generation. Locality migration,
 * Zeus, external ownership, disablement or release invalidates the generation before old work can run.
 * Arguments:
 * 0: group <GROUP, default grpNull>
 * 1: wake now <BOOL, default false> - shorten the next decision deadline without adding another job.
 * Return Value: Boolean - true only when the exact current owner brain has a live FSM.
 * Failed startup retires only its own queue state; discovery may retry the recurring brain.
 * Current callers: CBE_fnc_CortexDiscover, CBE_fnc_DangerStep and owner-local adoption.
 * Example: [_group,true] call CBE_fnc_GroupBrainStart;
 */

params [["_group",grpNull,[grpNull]],["_wake",false,[true]]];
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}) exitWith {false};
// Native danger may bootstrap this brain before the discovery sweep reaches its group.
// Establish locality first so discovery cannot later invalidate an epoch-zero live brain.
if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {
    if ([_group] call CBE_fnc_CortexIsEligible) then {[_group,true] call CBE_fnc_CortexLocality};
};
if (!local _group || {!(_group getVariable ["CBE_AIPass_Adopted",false])}) exitWith {false};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _brain=_group getVariable ["CBE_GroupBrain",createHashMap];
private _existingHandle=_group getVariable ["CBE_GroupBrain_FSM",-1];
if (count _brain > 0
    && {(_brain getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {(_brain getOrDefault ["generation",-1]) == (_group getVariable ["CBE_GroupBrain_Generation",0])}
    && {!(_brain getOrDefault ["cancelled",false])}
    && {_existingHandle isEqualType 0} && {finite _existingHandle} && {_existingHandle >= 0}
    && {!completedFSM _existingHandle}) exitWith {
    if (_wake) then {
        _brain set ["wakeAt",time];
        _brain set ["nextAt",time];
        missionNamespace setVariable ["CBE_AIPass_NextJobDue",time];
    };
    true
};
private _generation=(_group getVariable ["CBE_GroupBrain_Generation",0])+1;
_group setVariable ["CBE_GroupBrain_Generation",_generation];
_brain=createHashMapFromArray [
    ["group",_group],
    ["ownerEpoch",_epoch],
    ["generation",_generation],
    ["phase","CALM"],
    ["legacyPhase","CALM"],
    ["pending",false],
    ["completed",false],
    ["cancelled",false],
    ["cancelReason",""],
    ["nextAt",time],
    ["wakeAt",time],
    ["lastStepAt",-1],
    ["lastDelay",-1],
    ["queuedAt",-1],
    ["watchdogCount",0],
    ["responsiveUntil",0]
];
_group setVariable ["CBE_GroupBrain",_brain];
_group setVariable ["CBE_GroupBrain_State",["CALM",_generation,_epoch,serverTime,"STARTED"],true];
private _handle=[_group,_epoch,_generation,_brain] execFSM "\z\cbe\addons\main\fsm\groupTactics.fsm";
_group setVariable ["CBE_GroupBrain_FSM",_handle];
private _accepted=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
    && {local _group} && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {_generation == (_group getVariable ["CBE_GroupBrain_Generation",0])}
    && {(_group getVariable ["CBE_GroupBrain",createHashMap]) isEqualTo _brain}
    && {!(_brain getOrDefault ["cancelled",false])};
if (_accepted) then {
    _group setVariable ["CBE_AIPass_Managed",true];
} else {
    // Do not release settings or specialist operations from a failed tactical startup.
    // Retire only this exact brain; discovery owns the next recurring attempt.
    _brain set ["cancelled",true];
    _brain set ["cancelReason","FSM_START_FAILED"];
    _brain set ["pending",false];
    _brain set ["completed",true];
    if (local _group && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_generation == (_group getVariable ["CBE_GroupBrain_Generation",0])}
        && {(_group getVariable ["CBE_GroupBrain",createHashMap]) isEqualTo _brain}) then {
        _group setVariable ["CBE_AIPass_Managed",false];
        _group setVariable ["CBE_GroupBrain_State",["CALM",_generation,_epoch,serverTime,"FSM_START_FAILED"],true];
    };
};
_accepted
