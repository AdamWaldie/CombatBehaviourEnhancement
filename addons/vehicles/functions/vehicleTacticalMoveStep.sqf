/*
 * Author: WaldoTheWarfighter
 * Purpose: Service the exact original crew's finite selected-platform standoff and handback.
 * Locality/authority: Current platform/group owner, exact worker/token/serial/epoch/reference.
 * Only living original operators may retire their own commands after a casualty; no new crew
 * or outward continuation is adopted. New native/Zeus/specialist orders refuse old writes.
 * Repeat/JIP: Shared native phases preserve original reply/cleanup deadlines. Unresolved native
 * work retains its reference; elapsed lease or ended FSM alone never grants another controller.
 * Arrival is measured before HOLD; handback acknowledgement is not physical returned travel.
 * Arguments: platform OBJECT,objNull; token STRING,""; serial NUMBER,-1; executor serial NUMBER,-1.
 * Return: NUMBER next finite-worker delay, or-1 when terminal.
 * Current callers: vehicleTacticalMove.fsm inside one unscheduled callback.
 * Example: [_apc,_token,_serial,_executorSerial] call CBE_fnc_VehicleTacticalMoveStep;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_serial",-1,[0]],["_executorSerial",-1,[0]]];
if (remoteExecutedOwner > 0 || {isNull _battery} || {!local _battery}) exitWith {-1};
private _work=_battery getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
if (count _work == 0 || {(_work getOrDefault ["token",""]) != _token}
    || {(_work getOrDefault ["serial",-2]) != _serial}) exitWith {-1};
private _executor=_battery getVariable ["CBE_VehicleTacticalMove_FSM",[]];
if (count _executor != 5 || {(_executor select 0) != _serial}
    || {(_executor select 4) != _executorSerial}
    || {(_executor select 2) != clientOwner}
    || {(_executor select 3) != (_work getOrDefault ["epoch",-1])}
    || {!((_executor select 1) isEqualType 0)} || {!finite (_executor select 1)}
    || {(_executor select 1) < 0} || {completedFSM (_executor select 1)}) exitWith {-1};
private _group=_work get "group";
private _seats=_work get "crew";
private _reference=_work get "reference";
private _phase=_work get "phase";
private _finish={
    params ["_reason",["_retired",false]];
    if ((_battery getVariable ["CBE_VehicleTacticalMove_Work",createHashMap]) isEqualTo _work) then {
        _work set ["phase",["UNRESOLVED","RETIRED"] select _retired];
        _work set ["result",_reason];
        _battery setVariable ["CBE_VehicleTacticalMove_Work",_work,true];
        if (_retired && {local _group}
            && {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isEqualTo _reference}) then {
            [_group,"VEHICLE_STANDOFF",false] call CBE_fnc_CortexOwnershipLease;
            _group setVariable ["CBE_VehicleTacticalMove_Reference",nil,true];
            [_battery,"RELEASE",_reference] call CBE_fnc_VehicleCrewMoveDeletionWatch;
            private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
            if ((_state getOrDefault ["movementLease",[]]) isEqualTo (_work get "localLease")) then {
                _state deleteAt "movementLease";
            };
            private _generation=_work get "operationGeneration";
            if ((_state getOrDefault ["vehicleOperationGeneration",-1]) == _generation) then {
                _state deleteAt "vehicleOperationGeneration";
            };
            [_group,_generation,["INCOMPLETE","COMPLETE"] select (_work getOrDefault ["arrived",false]),
                _reason] call CBE_fnc_OperationRelease;
        };
    };
    -1
};
if (_phase in ["RETIRED","UNRESOLVED"]) exitWith {-1};
if (!local _group || {(_work get "owner") != clientOwner}
    || {(_work get "epoch") != (_group getVariable ["CBE_AIPass_Epoch",-1])}
    || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo _reference}) exitWith {
    // The new owner must explicitly adopt retirement. The old owner cannot rewrite its
    // journal, renew deadlines or make a terminal native-control claim across this edge.
    -1
};
// ISSUE has never written native movement. Cancellation can retire it without requiring
// the old crew or native route to survive; no restoration command is necessary or allowed.
if (_phase == "ISSUE" && {_work getOrDefault ["release",false]}) exitWith {
    ["CANCELLED_BEFORE_MOVE",true] call _finish
};
private _driver=_seats select 0;private _operator=_seats select 1;
private _live=[driver _battery,effectiveCommander _battery];
if (isNull (_live select 1)) then {_live set [1,_live select 0]};
// Losing an original operating actor is a retirement trigger, not a new crew admission.
// Keep the first survivor identity: a later replacement or resurrection cannot switch writers.
private _driverOnly=!isNull _driver && {alive _driver} && {_driver isEqualTo (_live select 0)}
    && {isNull _operator || {!alive _operator}}
    && {_live findIf {isNull _x || {!alive _x} || {!(_x in _seats)}} < 0};
private _operatorOnly=!isNull _operator && {alive _operator} && {_operator isNotEqualTo _driver}
    && {isNull _driver || {!alive _driver}}
    && {(_live select 1) isEqualTo _operator}
    && {isNull (_live select 0) || {(_live select 0) isEqualTo _driver && {!alive _driver}}};
private _retirementOnly=_work getOrDefault ["retirementOnly",false];
private _retirementActor=_work getOrDefault ["retirementActor",objNull];
if (_phase != "ISSUE" && {!_retirementOnly} && {_driverOnly || {_operatorOnly}}) then {
    _retirementOnly=true;_work set ["retirementOnly",true];
    _retirementActor=[_operator,_driver] select _driverOnly;
    _work set ["retirementActor",_retirementActor];
    // The shared two-seat acknowledgement observes the same one surviving actor.
    // Preserve that actor's original pre-request frame; do not sample a fresh baseline.
    private _before=_work getOrDefault ["before",[]];
    private _offset=[2,0] select _driverOnly;
    if (count _before == 4) then {_work set ["before",[
        _before select _offset,+(_before select (_offset+1)),
        _before select _offset,+(_before select (_offset+1))]]};
};
private _retirementCurrent=(_driverOnly && {_retirementActor isEqualTo _driver})
    || {_operatorOnly && {_retirementActor isEqualTo _operator}};
private _activeSeats=if (_retirementOnly) then {
    [_retirementActor] select {!isNull _x && {alive _x}}
} else {(_seats arrayIntersect _seats) select {!isNull _x && {alive _x}}};
private _control=alive _battery && {simulationEnabled _battery} && {!isObjectHidden _battery}
    && {(!_retirementOnly && {_live isEqualTo _seats}) || {_retirementOnly && {_retirementCurrent}}}
    && {isNil {_battery getVariable "CBE_ExternalDrivingOwner"}}
    && {!([_battery] call CBE_fnc_CompatibilityExternalControl)}
    && {!(_battery getVariable ["CBE_Convoy_Active",false])}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_work get "route")}
    && {_seats findIf {
        if (_retirementOnly && {isNull _x || {!alive _x}}) exitWith {false};
        isNull _x || {!local _x} || {group _x != _group}
        || {objectParent _x != _battery} || {isPlayer _x} || {!isNull remoteControlled _x}
        || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {!simulationEnabled _x} || {isObjectHidden _x}
        || {!([_x] call CBE_fnc_CortexCombatEffective)}
        || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
        || {[_x] call CBE_fnc_CompatibilityExternalControl}
        || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
        || {currentCommand _x == "STOP"}} < 0};
if (!_control) exitWith {
    ["NATIVE_OR_CONTROL_HANDOVER_UNRESOLVED",_phase == "ISSUE"] call _finish
};
private _observedDriver=if (_retirementOnly) then {_retirementActor} else {_driver};
private _observedOperator=if (_retirementOnly) then {_retirementActor} else {_operator};
private _observations=[_observedDriver,_observedOperator] call CBE_fnc_VehicleCrewNativeObservation;
if (count _observations != 4) exitWith {
    ["NATIVE_OR_CONTROL_HANDOVER_UNRESOLVED",_phase == "ISSUE"] call _finish
};
private _linearMotion=vectorMagnitude velocity _battery;
private _angularMotion=vectorMagnitude angularVelocity _battery;
private _rest=_linearMotion < 0.278 && {_angularMotion < 0.01};
private _arrivalSample=if (_phase in ["REQUESTED","STOPPING","RETURNING"]) then {
    [ASLToAGL getPosASL _battery,_linearMotion,_angularMotion]
} else {[]};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _sourceCurrent=!_retirementOnly && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {!([] call CBE_fnc_CortexIsPaused)} && {serverTime < (_work get "holdUntil")}
    && {(_operation getOrDefault ["generation",-2]) == (_work get "operationGeneration")}
    && {(_operation getOrDefault ["ownerEpoch",-2]) == (_work get "epoch")}
    && {(_operation getOrDefault ["intent",""]) == "VEHICLE_STANDOFF"}
    && {(_operation getOrDefault ["phase",""]) != "CANCELLED"}
    && {[_group,false,false,true] call CBE_fnc_CortexIsEligible}
    && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled};
if (!_sourceCurrent && {!(_phase in ["STOPPING","RETURNING"])}) then {_work set ["release",true]};
private _decision=[_battery,_work,"CBE_VehicleTacticalMove_Work",_seats,_activeSeats,
    _observations,_arrivalSample,_sourceCurrent,_rest] call CBE_fnc_VehicleCrewMoveNativePhase;
_decision params ["_delay","_reason","_retired",["_publish",false]];
if (_reason != "") exitWith {[_reason,_retired] call _finish};
if (_phase == "MOVING" && {(_work get "phase") == "HOLD"}) then {_work set ["arrived",true]};
if (_publish) then {_battery setVariable ["CBE_VehicleTacticalMove_Work",_work,true]};
_delay
