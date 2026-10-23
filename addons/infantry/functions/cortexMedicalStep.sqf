/*
 * Author: WaldoTheWarfighter
 * Reservation policy: unknown/malformed/nonfinite actor leases remain owned through the
 * shared owner-local CortexActorMoveReserved predicate at admission and command/cleanup gates.
 * Purpose: Runs one bounded, owner-local vanilla medical assistance operation for a calm friendly squad.
 * Locality / Authority: Runs only on the group owner and commands only local on-foot AI. It yields to Zeus,
 * player control, active combat movement and any detected specialist medical owner. Fleeing, hidden,
 * simulation-disabled or ACE-treatment-queued actors cannot be selected or retain active aid commands.
 * Repeat / JIP: The public operation generation and small aid record are rechecked every group tick. A new owner
 * cancels the old operation rather than resuming a stale treatment command. Approach movement has
 * one native doMove owner and is refreshed only after measured no-progress or an empty command.
 * Authored travel refuses admission; HOLD/SENTRY permits in-place aid only. The captured full native
 * waypoint receipt must match before success and later treatment; changed or missing proof cancels.
 * Admission preserves native MOVE/ATTACK/FIRE/SUPPRESS. During aid only the medic's last requested
 * approach destination can explain MOVE; a patient MOVE or a different destination yields.
 * Terminal cleanup recalls only a still-matching owned approach; generic native healing actions
 * are left intact because their writer/target cannot be identified by currentCommand alone.
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
        && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!fleeing _actor}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
};
private _finish = {
    params ["_result","_reason"];
    private _aid=_group getVariable ["CBE_Cortex_MedicalAid",[]];
    private _generation=_aid param [0,-1];
    // Recall only the approach we can still identify. ACTION/HEAL is deliberately
    // untouched: its native target/writer cannot be proved from the generic command.
    if (count _aid == 9) then {
        isNil {
            private _medic=_aid select 1;
            private _approach=_aid select 8;
            private _operation=_group getVariable ["CBE_Operation",createHashMap];
            if (local _group && {(_group getVariable ["CBE_Cortex_MedicalAid",[]]) isEqualTo _aid}
                && {(_operation getOrDefault ["generation",-1]) == _generation}
                && {(_operation getOrDefault ["intent",""]) == "MEDICAL_AID"}
                && {(_operation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_aid select 7)}
                && {!([_group] call CBE_fnc_CortexExternalTakeover)}
                && {[_medic] call _actorEligible} && {alive _medic} && {group _medic == _group}
                && {isNull objectParent _medic} && {count _approach == 3}
                && {!([_medic] call CBE_fnc_CortexActorMoveReserved)}
                && {currentCommand _medic == "MOVE"}) then {
                private _destination=(expectedDestination _medic) param [0,[]];
                if (count _destination == 3 && {_destination vectorDistance _approach <= 0.25}) then {
                    _medic doFollow leader _group;
                };
            };
        };
    };
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
private _medicalOrder=[_group] call CBE_fnc_NativeOrderReceipt;
private _waypointIndex=currentWaypoint _group;
private _authoredOrder=_waypointIndex > 0 && {_waypointIndex < count waypoints _group};
private _stationaryOrder=_authoredOrder && {waypointType [_group,_waypointIndex] in ["HOLD","SENTRY"]};

private _mayIssueMedical = {
    params ["_medic","_casualty"];
    !([_group] call CBE_fnc_CortexExternalTakeover)
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {!([_group] call CBE_fnc_CompatibilityExternalControl)}
        && {[_medic] call _actorEligible} && {[_casualty] call _actorEligible}
        && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _medicalOrder}
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
    // Missing legacy proof cannot adopt whatever mission order is current now.
    if (count _aid != 9 || {(_aid select 7) isNotEqualTo _medicalOrder}) exitWith {
        ["CANCELLED","ORDER_CHANGED"] call _finish
    };
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
        _reserved || {currentCommand _x in ["ATTACK","FIRE","SUPPRESS","GET IN","GET OUT","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
    } >= 0;
    // Only the medic received our approach MOVE. A patient MOVE or a different medic
    // destination is a new task, not a reason to refresh the old treatment approach.
    private _requestedApproach=_aid select 8;
    if (currentCommand _casualty == "MOVE"
        || {currentCommand _medic == "MOVE" && {
            private _destination=(expectedDestination _medic) param [0,[]];
            count _requestedApproach != 3 || {count _destination != 3}
                || {_destination vectorDistance _requestedApproach > 0.25}
        }}) then {_newActorTask=true};
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
    if (_stationaryOrder && {!_inTreatmentRange}) exitWith {
        ["CANCELLED","STATION_RANGE_LOST"] call _finish
    };
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
                private _approach=getPosATL _casualty;
                _medic doMove _approach;
                _aid set [8,+_approach];
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

// Authored travel remains authoritative. A stationary HOLD/SENTRY permits only aid
// already in reach; it does not grant permission to pull a sentry off its position.
if (_authoredOrder && {!_stationaryOrder}) exitWith {false};

private _members=(units _group) select {
    private _free=!([_x] call CBE_fnc_CortexActorMoveReserved);
    alive _x && {[_x] call _actorEligible} && {group _x == _group} && {_free}
        && {!(currentCommand _x in ["MOVE","ATTACK","FIRE","SUPPRESS","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
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
        if (_medic != _x && {_distance < _best} && {_canApproach}
            && {!_stationaryOrder || {_distance <= 4 && {abs (((getPosASL _medic) select 2)-((getPosASL _x) select 2)) <= 1.5}}} && {_distance <= (missionNamespace getVariable ["CBE_AIPass_MedicalAssist_Range",80])}) then {
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
private _approach=[];
if (_best > 4 || {abs (((getPosASL _medic) select 2)-((getPosASL _casualty) select 2)) > 1.5}) then {
    _approach=getPosATL _casualty;
    _medic doMove _approach;
} else {
    _medic action ["HealSoldier",_casualty];
};
_group setVariable ["CBE_Cortex_MedicalAid",[_operation get "generation",_medic,_casualty,time,time,_best,time,+_medicalOrder,+_approach],true];
true
