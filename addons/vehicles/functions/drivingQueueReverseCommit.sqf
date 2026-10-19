/*
 * Author: WaldoTheWarfighter
 * Purpose: Commit one granted queue leaf BACK or its exact native STOP/settled hold.
 * Locality/authority: Local actual vehicle/group/crew owner only, authenticated private
 * EXECUTE consent and current ordinary driving brain. The sole cap writer must already
 * have applied the requested cautious cap (ISSUE) or zero (STOP). This function never
 * changes speed, crew, physics, routes, reservations or ownership.
 * Repeat/JIP: Exact original token/expiry/brain binding; ISSUE never replays a journal.
 * STOP is idempotent and HELD requires native STOP plus one second of measured rest.
 * No worker or timer. Expired commands belong to existing receipt-only release cleanup.
 * Arguments: 0 mode STRING ADMIT/ISSUE/STOP; 1 group GROUP grpNull; 2 vehicle OBJECT objNull;
 * 3 current ordinary driving brain HASHMAP empty.
 * Return: BOOL - ADMIT is current eligibility; ISSUE/STOP indicate own journal exists/was
 * updated. HELD is stationary observation only, never proof of parent room or queue success.
 * Cost: ISSUE at most two shared rear observations and bounded hitpoint snapshot;
 * STOP reads existing receipts and motion only. Every native issue is unscheduled.
 * Current callers: DrivingAssistStart admission and sole cap-writer transaction.
 * Example: ["ISSUE",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueReverseCommit;
 */
params [["_mode","",[""]],["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]]];
private _result=false;
isNil {
_result=call {
if (remoteExecutedOwner > 0 || {!(_mode in ["ADMIT","ISSUE","STOP"])}
    || {isNull _group} || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
    || {!([_group] call CBE_fnc_DrivingMovementAvailable)}
    || {!([_group] call CBE_fnc_CortexIsEligible)} || {[_group] call CBE_fnc_CortexZeusHeld}
    || {[_group] call CBE_fnc_CortexExternalTakeover}
    || {_mode != "STOP" && {[] call CBE_fnc_CortexIsPaused}}
    || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
    || {(_group getVariable ["CBE_Driving_FSM",-1]) < 0}
    || {completedFSM (_group getVariable ["CBE_Driving_FSM",-1])}) exitWith {false};
private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
private _token=_consent getOrDefault ["token",""];private _expires=_consent getOrDefault ["expires",-1];
private _vehicles=_consent getOrDefault ["vehicles",[]];
private _binding=[_token,_expires,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["generation",-1]];
if (_token == "" || {!(_expires isEqualType 0)} || {!finite _expires} || {serverTime >= _expires}
    || {[_token] call CBE_fnc_DrivingQueueTokenClosed}
    || {!(_consent getOrDefault ["executionGranted",false])}
    || {(_consent getOrDefault ["executionPreparation",[]]) isNotEqualTo _binding}
    || {(_consent getOrDefault ["motionStage",""]) != "ARMED"}
    || {count _vehicles < 2} || {count _vehicles > 4}
    || {(_vehicles select (count _vehicles-1)) != _vehicle}
    || {(_consent getOrDefault ["motionBinding",[]]) isNotEqualTo [_vehicle,_token,_expires,8]}) exitWith {false};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _driver || {isNull _operator} || {_driver == _operator}
    || {!alive _vehicle} || {!canMove _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[_driver,_operator] findIf {
        !local _x || {group _x != _group} || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!simulationEnabled _x} || {isObjectHidden _x} || {!(_x checkAIFeature "MOVE")}
            || {!(_x checkAIFeature "PATH")} || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {[_x] call CBE_fnc_CortexActorMoveReserved}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
    } >= 0}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
private _cap=getForcedSpeed _vehicle;
private _baseline=_vehicle getVariable ["CBE_DrivingAssist_Restore",[]];
if ((_state param [3,grpNull]) != _group || {abs ((_state param [0,-100])-_cap) > 0.001}
    || {!(_baseline isEqualType [])} || {count _baseline != 1}
    || {!((_baseline select 0) isEqualType 0)} || {!finite (_baseline select 0)}
    || {!finite _cap} || {_cap < 0} || {_cap > (10/3.6)}) exitWith {false};
private _input=vehicleMoveInfo _vehicle;
private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
if (!finite _linear || {!finite _angular} || {toUpperANSI (_input param [1,""]) != "NONE"}) exitWith {false};
if (_mode == "ADMIT") exitWith {
    [_consent,true] call CBE_fnc_DrivingQueueReverseCurrent
};
if (_mode == "ISSUE") exitWith {
    // A duplicate cannot replay BACK, regardless of its current acknowledgement phase.
    if (count _work > 0) exitWith {
        (_work getOrDefault ["queueBinding",[]]) isEqualTo _binding
            && {(_work getOrDefault ["group",grpNull]) == _group}
            && {(_work getOrDefault ["driver",objNull]) == _driver}
            && {(_work getOrDefault ["operator",objNull]) == _operator}
    };
    if (_cap <= 0 || {_linear >= 0.1} || {_angular >= 0.01}
        || {!([_consent,true] call CBE_fnc_DrivingQueueReverseCurrent)}) exitWith {false};
    private _plan=[_vehicle] call CBE_fnc_DrivingRearPlan;
    private _observation=_plan select 0;private _envelope=_plan select 1;
    private _hitpoints=[_vehicle] call CBE_fnc_DrivingDamageReceipt;
    if (!(_observation select 0) || {count (_observation param [4,[]]) != 3}
        || {count _hitpoints != 3}
        || {serverTime >= _expires}
        || {(_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isNotEqualTo _consent}
        || {(vehicleMoveInfo _vehicle) isNotEqualTo _input}) exitWith {false};
    private _route=[_group] call CBE_fnc_DrivingRouteReceipt;
    private _origin=getPosATL _vehicle;
    private _next=createHashMapFromArray [["group",_group],["route",_route],
        ["driver",_driver],["operator",_operator],["driverTask",currentCommand _driver],
        ["operatorTask",currentCommand _operator],["driverCommand",+(expectedDestination _driver)],
        ["command",+(expectedDestination _operator)],["kind","REVERSE"],["commandMode","SIMPLE_BACK"],
        ["started",serverTime],["deadline",_expires],["hardDeadline",_expires],
        ["origin",+_origin],["progressAnchor",+_origin],["baseline",+_baseline],["cap",_cap],
        ["queueBinding",+_binding],["queuePhase","REVERSING"],["ackUntil",(serverTime+2) min _expires],
        ["simpleBefore",+_input],["rearEnvelope",+_envelope],["rearOriginASL",getPosASL _vehicle],
        ["rearDirection",vectorDir _vehicle],["rearDamage",damage _vehicle],
        ["rearMinimumDamage",damage _vehicle],["rearHitpoints",_hitpoints apply {+_x}],
        ["rearMinimumHitpoints",_hitpoints apply {+_x}]];
    _vehicle sendSimpleCommand "BACK";
    _next set ["simpleAcknowledged",toUpperANSI ((vehicleMoveInfo _vehicle) param [0,""]) == "BACK"];
    _vehicle setVariable ["CBE_DrivingRecovery_Work",_next,true];
    true
};
// STOP is permitted only for this exact issued journal after the sole writer applies zero.
if (count _work == 0 || {_cap > 0.001}
    || {(_work getOrDefault ["queueBinding",[]]) isNotEqualTo _binding}
    || {(_work getOrDefault ["group",grpNull]) != _group}
    || {(_work getOrDefault ["driver",objNull]) != _driver}
    || {(_work getOrDefault ["operator",objNull]) != _operator}
    || {(_work getOrDefault ["commandMode",""]) != "SIMPLE_BACK"}
    || {(_work getOrDefault ["route",[]]) isNotEqualTo ([_group] call CBE_fnc_DrivingRouteReceipt)}
    || {(_work getOrDefault ["baseline",[]]) isNotEqualTo _baseline}
    || {currentCommand _driver != (_work getOrDefault ["driverTask","__MISSING__"])}
    || {currentCommand _operator != (_work getOrDefault ["operatorTask","__MISSING__"])}
    || {(expectedDestination _driver) isNotEqualTo (_work getOrDefault ["driverCommand",[]])}
    || {(expectedDestination _operator) isNotEqualTo (_work getOrDefault ["command",[]])}
    || {_work getOrDefault ["queueStopAcknowledged",false]
        && {toUpperANSI (_input param [0,""]) != "STOP"}}
    || {toUpperANSI (_input param [0,""]) != "BACK"
        && {!(_work getOrDefault ["simpleStopIssued",false]) || {toUpperANSI (_input param [0,""]) != "STOP"}}
        && {_work getOrDefault ["simpleAcknowledged",false]
            || {_input isNotEqualTo (_work getOrDefault ["simpleBefore",[]])}}}) exitWith {false};
private _next=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
_next set ["cap",0];_next set ["queuePhase","STOPPING"];
if (!(_next getOrDefault ["simpleStopIssued",false])) then {
    _vehicle sendSimpleCommand "STOP";_next set ["simpleStopIssued",true];
};
private _stopAcknowledged=toUpperANSI ((vehicleMoveInfo _vehicle) param [0,""]) == "STOP";
if (_stopAcknowledged) then {_next set ["queueStopAcknowledged",true]};
private _stopped=_stopAcknowledged && {_linear < 0.1} && {_angular < 0.01};
private _since=_next getOrDefault ["queueStillSince",-1];
if (!_stopped) then {_next set ["queueStillSince",-1]} else {
    if (_since < 0) then {_since=serverTime;_next set ["queueStillSince",_since]};
    if (serverTime-_since >= 1) then {_next set ["queuePhase","HELD"]};
};
if (_next isNotEqualTo _work) then {_vehicle setVariable ["CBE_DrivingRecovery_Work",_next,true]};
true
};
};
_result
