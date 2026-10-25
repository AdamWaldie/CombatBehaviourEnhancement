/*
 * Author: WaldoTheWarfighter
 * Native WAIT/idle acknowledgement also requires current same-floor physical arrival/rest;
 * the original outward reply deadline still gates admission after that observation.
 * Purpose: Advance one finite selected-gun native crew movement, hold and return lifecycle.
 * Locality/authority: Exact original local vehicle/group/crew/epoch and private FSM only.
 * After either distinct original operator dies, the surviving original seated actor may only
 * stop and return its own admitted native order. No replacement seat inherits outward authority.
 * Commands address only the admitted driver and effective commander. No group waypoint,
 * membership, posture, skill, inventory or physics command is issued.
 * Repeat/JIP: Original token, serial and deadlines fence callbacks. STOPPING and RETURNING
 * are observed; unknown retirement retains its public reservation and never grants handover.
 * A native return may already be WAIT/idle at observation: accept only the matching
 * destination plus measured rest within2m, never idle alone or an elapsed timer.
 * Arguments: 0 battery OBJECT,objNull; 1 token STRING,""; 2 serial NUMBER,-1;
 * 3 machine-local executor serial NUMBER,-1, fences a replaced FSM on the same owner.
 * Return: NUMBER next delay, or -1 when this worker is terminal. READY is not a firing event.
 * Current caller: artilleryCrewMove.fsm; Position/report/shot require its exact HOLD proof.
 * Example: [gun1,_token,_serial,_executorSerial] call CBE_fnc_ArtilleryCrewMoveStep;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_serial",-1,[0]],["_executorSerial",-1,[0]]];
if (remoteExecutedOwner > 0 || {isNull _battery} || {!local _battery}) exitWith {-1};
private _work=_battery getVariable ["CBE_ArtilleryCrew_Work",createHashMap];
if (count _work == 0 || {(_work getOrDefault ["token",""]) != _token}
    || {(_work getOrDefault ["serial",-2]) != _serial}) exitWith {-1};
private _executor=_battery getVariable ["CBE_ArtilleryCrew_FSM",[]];
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
    if ((_battery getVariable ["CBE_ArtilleryCrew_Work",createHashMap]) isEqualTo _work) then {
        _work set ["phase",["UNRESOLVED","RETIRED"] select _retired];
        _work set ["result",_reason];
        _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
        if (_retired && {(_work getOrDefault ["kind","POSITION"]) == "SCOOT"}
            && {(_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token}
            && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo (_work get "session")}) then {
            {_battery setVariable [_x,nil,true]} forEach ["CBE_Cortex_ArtilleryScootToken",
                "CBE_Cortex_ArtilleryScootSession","CBE_Cortex_ArtilleryScootDeadline","CBE_Cortex_ArtilleryScootPurpose"];
        };
        if (_retired && {local _group}
            && {(_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isEqualTo _reference}) then {
            [_group,"ARTILLERY_CREW",false] call CBE_fnc_CortexOwnershipLease;
            _group setVariable ["CBE_ArtilleryCrew_Reference",nil,true];
            private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
            if ((_state getOrDefault ["movementLease",[]]) isEqualTo (_work get "localLease")) then {
                _state deleteAt "movementLease";
            };
        };
    };
    -1
};
if (_phase in ["RETIRED","UNRESOLVED"]) exitWith {-1};
if (!local _group || {(_work get "owner") != clientOwner}
    || {(_work get "epoch") != (_group getVariable ["CBE_AIPass_Epoch",-1])}
    || {(_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isNotEqualTo _reference}) exitWith {
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
private _goal=+(_work get "goal");
private _goalsMatch={
    params ["_point"];
    [1,3] findIf {
        private _position=(_observations select _x) param [0,[],[[]]];
        count _position != 3 || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_position vectorDistance _point > 0.25}
    } < 0
};
private _linearMotion=vectorMagnitude velocity _battery;
private _angularMotion=vectorMagnitude angularVelocity _battery;
private _rest=_linearMotion < 0.278 && {_angularMotion < 0.01};
private _arrivalSample=if (_phase in ["REQUESTED","STOPPING"]) then {
    [ASLToAGL getPosASL _battery,_linearMotion,_angularMotion]
} else {[]};
private _session=_work get "session";
private _scoot=(_work getOrDefault ["kind","POSITION"]) == "SCOOT";
private _purpose=_session select ([6,4] select _scoot);
private _counter=_purpose == "COUNTER";
private _sourceCurrent=!_retirementOnly && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {!([] call CBE_fnc_CortexIsPaused)} && {serverTime < (_work get "holdUntil")}
    && {[_group,false,false,true] call CBE_fnc_CortexIsEligible}
    && {[_group,["CBE_AIPass_Artillery_Enable","CBE_AIPass_CounterBattery_Enable"] select _counter,false]
        call CBE_fnc_CortexFeatureEnabled}
    && {if (_scoot) then {
        (_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token
            && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo _session}
            && {(_session select 1) == (missionNamespace getVariable [
                ["CBE_ArtilleryScoot_SupportGeneration","CBE_ArtilleryScoot_CounterGeneration"] select _counter,0])}
            && {!_counter || {(_session select 2) == (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])}}
            && {missionNamespace getVariable [["CBE_AIPass_Artillery_ShootAndScoot","CBE_AIPass_CounterBattery_ShootAndScoot"] select _counter,true]}
    } else {
        (_battery getVariable ["CBE_AIPass_FireToken",""]) == _token
            && {(_battery getVariable ["CBE_ArtilleryPosition_Session",[]]) isEqualTo _session}
            && {(_session select 5) == (missionNamespace getVariable [
                ["CBE_Artillery_SupportFireGeneration","CBE_AIPass_CounterGeneration"] select _counter,0])}
            && {(_session select 7) != "SMOKE" || {
                (_session select 8) == (missionNamespace getVariable ["CBE_Artillery_SmokeFireGeneration",0])
                && {[_group,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled}}}
    }};
if (!_sourceCurrent && {!(_phase in ["STOPPING","RETURNING"])}) then {
    _work set ["release",true];
};
// Refuse changed native actor orders. An issued MOVE may naturally settle into WAIT/idle.
if (_phase != "ISSUE" && {!([_goal] call _goalsMatch)}
    && {!(_phase in ["REQUESTED","STOPPING","RETURNING"])}) exitWith {["ACTOR_ORDER_REPLACED"] call _finish};
if (_phase == "REQUESTED" && {([_goal,_work get "replyUntil",_work get "before",_observations,serverTime,_arrivalSample]
    call CBE_fnc_VehicleCrewDestinationState) == "LOST"}) exitWith {["ACTOR_ORDER_REPLACED"] call _finish};
// A delayed callback cannot mint or issue a retirement stop after the original window.
// Refuse before changing the goal/before receipt or writing any native command.
if (_work getOrDefault ["release",false] && {_phase != "ISSUE"}
    && {!(_phase in ["STOPPING","RETURNING"])}
    && {serverTime >= (_work getOrDefault ["cleanupUntil",(serverTime+30) min ((_work get "holdUntil")+30)])}) exitWith {
    ["RETIREMENT_TIMEOUT"] call _finish
};
if (_work getOrDefault ["release",false] && {!(_phase in ["STOPPING","RETURNING"])}) then {
    if (_phase == "ISSUE") exitWith {};
    private _hold=getPosATL _battery;
    _work set ["goal",+_hold];_goal=+_hold;
    _work set ["before",_observations];
    // A recovered worker inherits the first retirement window; it cannot mint another.
    if !("cleanupUntil" in _work) then {
        _work set ["cleanupUntil",(serverTime+30) min ((_work get "holdUntil")+30)];
    };
    _work set ["replyUntil",serverTime+2];
    {_x doMove _hold} forEach _activeSeats;
    _work set ["phase","STOPPING"];_phase="STOPPING";
    _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
};
if (_phase == "ISSUE") exitWith {
    if (!_sourceCurrent || {!canMove _battery} || {waterDamaged _battery}
        || {_observations isNotEqualTo (_work get "baseline")}) exitWith {["ADMISSION_CHANGED",true] call _finish};
    _work set ["before",_observations];_work set ["replyUntil",serverTime+2];
    {_x doMove _goal} forEach _activeSeats;
    _work set ["phase","REQUESTED"];
    _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
    0.25
};
if (_phase == "REQUESTED") exitWith {
    private _ack=[_goal,_work get "replyUntil",_work get "before",_observations,serverTime,_arrivalSample]
        call CBE_fnc_VehicleCrewDestinationState;
    if (_ack == "OWNED" && {serverTime <= (_work get "replyUntil")}) then {_work set ["phase","MOVING"];_battery setVariable ["CBE_ArtilleryCrew_Work",_work,true]};
    if (_ack == "LOST") exitWith {["ACTOR_ORDER_REPLACED"] call _finish};
    if (_ack == "EXPIRED" || {serverTime > (_work get "replyUntil")}) then {_work set ["release",true]};
    0.25
};
if (_phase == "MOVING") exitWith {
    private _position=getPosASL _battery;
    if (_position vectorDistance (_work get "progressPosition") >= 3) then {
        _work set ["progressPosition",_position];_work set ["progressAt",serverTime];
    };
    if (_battery distance2D _goal <= 25 && {abs ((getPosATL _battery select 2)-(_goal select 2)) <= 3}
        && {_rest}) then {
        _work set ["phase","HOLD"];_work set ["holdObservations",_observations];
        if (_scoot) then {
            _work set ["scootArrivedAt",serverTime];_work set ["release",true];
        };
        _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
    } else {
        if (serverTime >= (_work get "moveUntil") || {serverTime-(_work get "progressAt") >= 30}
            || {!canMove _battery} || {waterDamaged _battery}) then {_work set ["release",true]};
    };
    1
};
if (_phase == "HOLD") exitWith {
    if (!_rest || {!([_goal] call _goalsMatch)}) then {_work set ["release",true]};
    2
};
if (_phase in ["STOPPING","RETURNING"] && {serverTime >= (_work get "cleanupUntil")}) exitWith {
    ["RETIREMENT_TIMEOUT"] call _finish
};
if (_phase == "STOPPING") exitWith {
    private _ack=[_goal,_work get "replyUntil",_work get "before",_observations,serverTime,_arrivalSample]
        call CBE_fnc_VehicleCrewDestinationState;
    if (_ack == "LOST" && {!([_goal] call _goalsMatch)}) exitWith {["STOP_ORDER_REPLACED"] call _finish};
    if (_ack == "EXPIRED" && {!([_goal] call _goalsMatch)}) exitWith {["STOP_ORDER_UNKNOWN"] call _finish};
    if (_rest && {[_goal] call _goalsMatch}
        && {_activeSeats findIf {!(currentCommand _x in ["","WAIT"])} < 0}) then {
        private _baseline=_work get "baseline";
        private _returns=[];
        {
            private _index=_forEachIndex*2;
            private _point=(_baseline select (_index+1)) param [0,[],[[]]];
            if (!isNull _x && {alive _x} && {_x in _activeSeats} && {(_baseline select _index) == "MOVE"}) then {
                _x doMove _point;_returns pushBack [_x,+_point];
            };
        } forEach (_seats arrayIntersect _seats);
        _work set ["returns",_returns];_work set ["replyUntil",serverTime+2];
        _work set ["phase","RETURNING"];
        _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
    };
    0.25
};
if (_phase == "RETURNING") exitWith {
    private _returns=_work get "returns";
    private _ack=_returns findIf {
        _x params ["_actor","_point"];
        if (isNull _actor || {!alive _actor}) exitWith {false};
        private _native=(expectedDestination _actor) param [0,[],[[]]];
        private _command=currentCommand _actor;
        count _native != 3
            || {_native findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_native vectorDistance _point > 0.25}
            || {!(_command == "MOVE" || {_command in ["","WAIT"] && {_rest}
                && {(getPosATL _battery) vectorDistance _point <= 2}})}
    } < 0;
    if (_ack) exitWith {["NATIVE_RETURN_ACKNOWLEDGED",true] call _finish};
    if (serverTime > (_work get "replyUntil")) exitWith {["NATIVE_RETURN_UNKNOWN"] call _finish};
    0.25
};
["INVALID_PHASE"] call _finish
