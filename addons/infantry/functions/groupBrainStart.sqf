/*
 * Author: WaldoTheWarfighter
 * Purpose: Start or wake the one owner-local tactical brain for an eligible ground group.
 * Locality / Authority: Must run where the group is local. It never transfers ownership and never
 * issues movement; the FSM routes bounded decisions through the shared CBE scheduler.
 * Repeat/JIP: Repeated calls reuse the current owner epoch and generation. Locality migration,
 * Zeus, external ownership, disablement or release invalidates the generation before old work can run.
 * Arguments:
 * 0: group <GROUP, default grpNull>
 * 1: wake now <BOOL, default false> - shorten the next decision deadline without adding another job.
 * Return Value: Boolean - true when a brain exists for the current owner.
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
if (count _brain > 0
    && {(_brain getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {!(_brain getOrDefault ["cancelled",false])}) exitWith {
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
_group setVariable ["CBE_AIPass_Managed",true];
true
