/*
 * Author: WaldoTheWarfighter
 * Reservation policy: unknown/malformed/nonfinite actor leases remain owned through the
 * shared owner-local CortexActorMoveReserved predicate at admission and command/cleanup gates.
 * Purpose: Runs one bounded, owner-local vanilla medical assistance operation for a calm friendly squad.
 * Locality / Authority: Runs only on the group owner and commands only local on-foot AI. It yields to Zeus,
 * player control, active combat movement and any detected specialist medical owner.
 * Repeat / JIP: The public operation generation and small aid record are rechecked every group tick. A new owner
 * cancels the old operation rather than resuming a stale treatment command. Approach movement has
 * one native doMove owner and is refreshed only after measured no-progress or an empty command.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP> - current Cortex group state.
 * 2: phase <STRING> - current Cortex phase.
 * Return Value: BOOL - true while CBE owns a finite aid operation.
 * Current callers: CBE_fnc_CortexGroupTick.
 * Example: [group player,createHashMap,"CALM"] call CBE_fnc_CortexMedicalStep;
 * Result: an eligible local medic physically approaches and uses the native treatment command, or CBE leaves the squad unchanged.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_phase","",[""]]
];
if (isNull _group || {!local _group}) exitWith {false};

private _actorEligible={
    params ["_actor"];
    !isNull _actor && {local _actor} && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
};
private _finish = {
    params ["_result","_reason"];
    private _aid=_group getVariable ["CBE_Cortex_MedicalAid",[]];
    private _generation=_aid param [0,-1];
    if (_generation >= 0) then {
        if (_result == "COMPLETE") then {
            [_group,_generation,"COMPLETE",_reason] call CBE_fnc_OperationRelease;
        } else {
            [_group,_generation,_reason] call CBE_fnc_OperationCancel;
        };
    };
    _group setVariable ["CBE_Cortex_MedicalAid",nil,true];
    false
};

private _medicalEnabled=[_group,"CBE_AIPass_MedicalAssist_Enable",true] call CBE_fnc_CortexFeatureEnabled;
private _medicalInterrupted=[_group] call CBE_fnc_CortexZeusHeld
    || {[_group] call CBE_fnc_CompatibilityExternalControl};
if (!_medicalEnabled || {_medicalInterrupted}) exitWith {
    if ((_group getVariable ["CBE_Cortex_MedicalAid",[]]) isNotEqualTo []) then {
        ["CANCELLED",["FEATURE_CLOSED","EXTERNAL"] select _medicalInterrupted] call _finish
    } else {false}
};

// Ownership can change after the tick-level eligibility check and immediately before an engine
// command. Recheck at each movement or treatment write so Zeus and specialist controllers never
// receive a stale CBE command from this finite operation.
private _mayIssueMedical = {
    params ["_medic","_casualty"];
    !([_group] call CBE_fnc_CortexExternalTakeover)
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {!([_group] call CBE_fnc_CompatibilityExternalControl)}
        && {[_medic] call _actorEligible} && {[_casualty] call _actorEligible}
};

private _aid=_group getVariable ["CBE_Cortex_MedicalAid",[]];
private _dangerResponse=_group getVariable ["CBE_Danger_Response",[]];
private _dangerActive=count _dangerResponse == 5
    && {(_dangerResponse select 4) == (_group getVariable ["CBE_Danger_Generation",-1])}
    && {time < (_dangerResponse select 3)};
if (_aid isNotEqualTo []) exitWith {
    // Medical runs before the normal contact planner in CortexGroupTick. Retire it here when the
    // danger FSM has produced a live response, then return false so the same group tick can consume
    // that response instead of waiting for another medical interval.
    if (_dangerActive) exitWith {["CANCELLED","COMBAT_RESUMED"] call _finish};
    _aid params ["_generation","_medic","_casualty","_startedAt","_lastOrderAt","_bestDistance","_lastProgressAt"];
    // Treatment may legitimately make no spatial progress, but it still needs the same
    // generation/owner proof as approach movement before counting success or issuing HealSoldier.
    private _currentAidOperation=_group getVariable ["CBE_Operation",createHashMap];
    if ((_currentAidOperation getOrDefault ["generation",-1]) != _generation
        || {(_currentAidOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {(_currentAidOperation getOrDefault ["intent",""]) != "MEDICAL_AID"}) exitWith {
        ["CANCELLED","REPLACED"] call _finish
    };
    if (isNull _medic || {isNull _casualty} || {!alive _medic} || {!alive _casualty}
        || {!([_medic] call _actorEligible)} || {!([_casualty] call _actorEligible)}
        || {!local _medic} || {!local _casualty} || {group _medic != _group} || {group _casualty != _group}
        || {vehicle _medic != _medic} || {vehicle _casualty != _casualty}
        || {!([_medic] call CBE_fnc_CortexCombatEffective)}
        || {!([_casualty] call CBE_fnc_CortexCombatEffective)}) exitWith {
        ["CANCELLED","ACTOR_UNAVAILABLE"] call _finish
    };
    // A new finite actor task is ownership, even when the group itself remains ordinary.
    // The medic's own HealSoldier action may report ACTION/HEAL, so those commands are
    // not treated as unrelated work here. Explicit other services and reservations yield.
    private _newActorTask=[_medic,_casualty] findIf {
        private _reserved=[_x] call CBE_fnc_CortexActorMoveReserved;
        _reserved || {currentCommand _x in ["GET IN","GET OUT","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
    } >= 0;
    if (_newActorTask) exitWith {["CANCELLED","ACTOR_TASK_CHANGED"] call _finish};
    if (damage _casualty < (missionNamespace getVariable ["CBE_AIPass_MedicalAssist_DamageThreshold",0.35])) exitWith {
        missionNamespace setVariable ["CBE_AIPass_MedicalAssists",(missionNamespace getVariable ["CBE_AIPass_MedicalAssists",0])+1];
        ["COMPLETE","TREATED"] call _finish
    };
    if (_phase in ["CONTACT","RETREAT"] || {time-_startedAt >= (missionNamespace getVariable ["CBE_AIPass_MedicalAssist_Timeout",45])}) exitWith {
        ["CANCELLED",["COMBAT_RESUMED","TIMEOUT"] select (time-_startedAt >= (missionNamespace getVariable ["CBE_AIPass_MedicalAssist_Timeout",45]))] call _finish
    };
    private _distance=(getPosASL _medic) vectorDistance (getPosASL _casualty);
    private _inTreatmentRange=_distance <= 4
        && {abs (((getPosASL _medic) select 2)-((getPosASL _casualty) select 2)) <= 1.5};
    // At treatment range the medic's lack of displacement is expected: the native HealSoldier action can work
    // in place. The shared progress monitor is only meaningful while this finite operation is
    // physically approaching its casualty, otherwise it would incorrectly cancel a working aid.
    if (!_inTreatmentRange && {!(_medic checkAIFeature "MOVE") || {!(_medic checkAIFeature "PATH")}}) exitWith {
        ["CANCELLED","MOVEMENT_DISABLED"] call _finish
    };
    private _cancelReason="";
    if (!_inTreatmentRange) then {
        private _operationState=[_group,_generation,2,12] call CBE_fnc_OperationStep;
        if (_operationState in ["LOST_OWNER","ZEUS","EXTERNAL","REPLACED"]) then {_cancelReason=_operationState};
        if (_operationState == "STALLED") then {_cancelReason="NO_PROGRESS"};
    };
    if (_cancelReason != "") exitWith {["CANCELLED",_cancelReason] call _finish};
    if !([_medic,_casualty] call _mayIssueMedical) exitWith {["CANCELLED","EXTERNAL"] call _finish};
    if (_distance < _bestDistance-2) then {
        _bestDistance=_distance;
        _lastProgressAt=time;
    };
    if (!_inTreatmentRange && {time-_lastProgressAt >= 12}) exitWith {
        ["CANCELLED","NO_PROGRESS"] call _finish
    };
    if (time-_lastOrderAt >= 8 && {[_medic,_casualty] call _mayIssueMedical}) then {
        if (!_inTreatmentRange) then {
            if (_medic checkAIFeature "MOVE" && {_medic checkAIFeature "PATH"}
                && {currentCommand _medic in ["","STOP"] || {time-_lastProgressAt >= 8}}) then {
                _medic doMove getPosATL _casualty;
                _aid set [4,time];
            };
        } else {
            _medic action ["HealSoldier",_casualty];
            _aid set [4,time];
        };
        _aid set [5,_bestDistance];
        _aid set [6,_lastProgressAt];
        _group setVariable ["CBE_Cortex_MedicalAid",_aid,true];
    };
    true
};

// Treatment is a security action, not a substitute for a current assault, withdrawal, building task,
// passenger procedure or direct order. Restrict selection to CALM/SECURITY and only when no finite
// CBE operation already owns the group.
if (_dangerActive) exitWith {false};
if !(_phase in ["CALM","SECURITY"]) exitWith {false};
if (count (_group getVariable ["CBE_Operation",createHashMap]) > 0
    || {_group getVariable ["CBE_AIPass_ClearBuilding",false]}
    || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}) exitWith {false};

private _members=(units _group) select {
    private _free=!([_x] call CBE_fnc_CortexActorMoveReserved);
    alive _x && {[_x] call _actorEligible} && {group _x == _group} && {_free}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
        && {vehicle _x == _x} && {[_x] call CBE_fnc_CortexCombatEffective}
        && {!(_x getVariable ["ACE_isUnconscious",false])}
};
private _threshold=missionNamespace getVariable ["CBE_AIPass_MedicalAssist_DamageThreshold",0.35];
// Command succession is independent of medical eligibility. A wounded current leader still needs a
// living medic; the pair selection below excludes only self-treatment.
private _casualties=_members select {damage _x >= _threshold};
if (_casualties isEqualTo []) exitWith {false};
private _medics=_members select {_x getUnitTrait "Medic" || {(_x getVariable ["ace_medical_medicClass",0]) > 0}};
if (_medics isEqualTo []) exitWith {false};
private _pair=[];
private _best=1e9;
{
    private _medic=_x;
    {
        private _distance=(getPosASL _medic) vectorDistance (getPosASL _x);
        private _canApproach=(_medic checkAIFeature "MOVE" && {_medic checkAIFeature "PATH"})
            || {_distance <= 4 && {abs (((getPosASL _medic) select 2)-((getPosASL _x) select 2)) <= 1.5}};
        if (_medic != _x && {_distance < _best} && {_canApproach} && {_distance <= (missionNamespace getVariable ["CBE_AIPass_MedicalAssist_Range",80])}) then {
            _best=_distance;
            _pair=[_medic,_x];
        };
    } forEach _casualties;
} forEach _medics;
if (_pair isEqualTo []) exitWith {false};
_pair params ["_medic","_casualty"];
private _operation=[_group,"MEDICAL_AID",_casualty,[_medic], [getPosATL _casualty],"APPROACH"] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {false};
private _generation=_operation get "generation";
if !([_medic,_casualty] call _mayIssueMedical) exitWith {
    [_group,_generation,"EXTERNAL"] call CBE_fnc_OperationCancel;
    false
};
if ((_best > 4 || {abs (((getPosASL _medic) select 2)-((getPosASL _casualty) select 2)) > 1.5})
    && {!(_medic checkAIFeature "MOVE") || {!(_medic checkAIFeature "PATH")}}) exitWith {
    [_group,_generation,"MOVEMENT_DISABLED"] call CBE_fnc_OperationCancel; false
};
if (_best > 4 || {abs (((getPosASL _medic) select 2)-((getPosASL _casualty) select 2)) > 1.5}) then {
    _medic doMove getPosATL _casualty;
} else {
    _medic action ["HealSoldier",_casualty];
};
_group setVariable ["CBE_Cortex_MedicalAid",[_operation get "generation",_medic,_casualty,time,time,_best,time],true];
true
