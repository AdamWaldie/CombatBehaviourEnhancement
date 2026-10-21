/*
 * Author: WaldoTheWarfighter
 * Pending ACE treatment queues veto crew admission and each existing seat-action boundary.
 * Purpose: Executes one finite native internal-seat replacement for an ordinary leader vehicle.
 * A dead driver receives one native Eject action. A vacant seat permits MoveToDriver; after
 * two seconds the same dead AI occupant also permits one native internal seat-swap attempt.
 * This is not forced seating or successful recovery: only actual driver occupancy confirms it.
 * Seat actions require finite total linear speed below1km/h and angular speed below0.01rad/s.
 * Read-only SWITCHING completion may observe a moving new driver within the original
 * deadline; expired/invalid clocks retire before success. All other admission guards remain.
 * Living incapacitated drivers are never displaced. New candidate priority is eligible cargo,
 * commander, other crew, then primary gunner as last resort. An admitted attempt keeps its candidate.
 * Locality / Authority: Internal current group/crew owner only, exact driving brain and
 * unit-local native actions. Vehicle may still belong to another owner; no vehicle command is issued.
 * An authored plain MOVE uses the shared DrivingRouteGoal policy, including a finite goal.
 * Native casualty-seat rebinding remains unsupported. Player, Zeus, specialist, convoy,
 * service and newer orders win.
 * Repeat/JIP: Public original deadline and issued phases survive transfer without replaying actions.
 * Terminal receipts suppress repeated attempts for the same driver and route. No forced seating,
 * physics movement, repair, AI-feature reset, waypoint rewrite or second scheduler is used.
 * Candidate and leader native commands are snapshotted as well as destinations. A newer
 * command, or explicit STOP, cancels seat actions even when its destination is unchanged.
 * The issued candidate seat switch may expose its own asynchronous ACTION phase. A newer
 * indistinguishable ACTION during that window cannot be identified by command observations.
 * Candidate selection requires current assignment to the actual occupied seat, using the
 * existing fullCrew assigned-unit field. Newer seat intent and explicit unassignment defer.
 * Candidate selection and each seat-action boundary preserve strict actor movement reservations.
 * A newly reserved candidate cancels this attempt before ejecting or switching seats.
 * Journals without these command receipts retire without replaying a seat action.
 * Work is copied before editing. Publication compares the exact entry snapshot and current
 * brain/epoch unscheduled; foreign-group journals are never erased by this group.
 * Each native action rechecks the exact live journal and original deadline, then publishes
 * its issued phase in the same unscheduled block. No stale cancellation can replace new work.
 * Arguments: 0 group <GROUP, grpNull>; 1 current driving brain <HASHMAP, empty>;
 * 2 release <BOOL, false> retires a matching journal without further native action.
 * Return Value: BOOL - an admitted native seat action is pending, not restored mobility.
 * Current callers: DrivingOperationStep and DrivingOperationFinish.
 * Example: [group commander truck1,_brain] call CBE_fnc_DrivingCrewStep;
 */
params [["_group",grpNull,[grpNull]],["_brain",createHashMap,[createHashMap]],["_release",false,[true]]];
if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
private _previousVehicle=_brain getOrDefault ["crewVehicle",objNull];
if (!_release && {!isNull _previousVehicle} && {_previousVehicle != vehicle leader _group}) then {
    [_group,_brain,true] call CBE_fnc_DrivingCrewStep;
};
private _vehicle=if (_release) then {_brain getOrDefault ["crewVehicle",objNull]} else {vehicle leader _group};
if (isNull _vehicle || {_vehicle == leader _group} || {!(_vehicle isKindOf "LandVehicle")} || {_vehicle isKindOf "StaticWeapon"}) exitWith {false};
private _liveWork=_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap];
private _driver=driver _vehicle;
// Healthy drivers retain the cheap path: no copies, route snapshot or crew enumeration.
if (!_release && {count _liveWork == 0} && {!isNull _driver} && {alive _driver}) exitWith {false};
private _entryWork=+_liveWork;
private _work=+_entryWork;
private _changed=false;
private _publish={
    isNil {
        if (_changed && {local _group}
            && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]) isEqualTo _entryWork}) then {
            _vehicle setVariable ["CBE_DrivingCrew_Work",+_work,true];
            _entryWork=+_work;
            _changed=false;
        };
    };
};
private _route=if (_release) then {[]} else {[_group] call CBE_fnc_DrivingRouteReceipt};
if (_release) exitWith {
    if (count _work > 0 && {(_work get "group") == _group}
        && {(_work get "route") isEqualTo (_brain getOrDefault ["route",[]])}
        && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain}
        && {!((_work get "phase") in ["COMPLETE","CANCELLED","EXPIRED"])}) then {
        _work set ["phase","CANCELLED"];_work set ["ended",serverTime];
        _changed=true;call _publish;
    };
    false
};
if (count _work > 0 && {(_work get "group") != _group}) exitWith {false};
if (count _work > 0 && {(_work get "route") isNotEqualTo _route}) then {
    _work=createHashMap;_changed=true;
};
private _terminal=count _work > 0 && {(_work get "phase") in ["COMPLETE","CANCELLED","EXPIRED"]};
// A later casualty is a distinct episode; a failed vacancy cannot restart every callback.
if (_terminal && {!isNull _driver} && {_driver != (_work get "driver")} && {!alive _driver}) then {
    _work=createHashMap;_terminal=false;_changed=true;
};
if (_terminal || {count _work == 0 && {!isNull _driver} && {alive _driver}}) exitWith {call _publish;false};
private _candidate=if (count _work > 0) then {_work get "candidate"} else {objNull};
private _phase=if (count _work > 0) then {_work get "phase"} else {""};
// A native seat action may expose ACTION asynchronously after its immediate receipt.
// Only this candidate in the already-issued SWITCHING phase may make that transition.
private _commandOwned={
    params ["_actor","_receipt"];
    if (_receipt == "MISSING_RECEIPT") exitWith {false};
    currentCommand _actor == _receipt
        || {_actor == _candidate && {_phase == "SWITCHING"} && {currentCommand _actor == "ACTION"}}
};
// The availability check supplies the crew snapshot used for candidate selection.
// Refresh again at each native seat action; do not enumerate an unused entry snapshot.
private _crew=[];
private _tasks=["GET IN","GET OUT","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
    "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
private _available={
    _crew=fullCrew [_vehicle,"",false];
    params [["_requireStopped",true,[true]]];
    private _motionSafe=true;
    if (_requireStopped) then {
        private _linearMotion=vectorMagnitude velocity _vehicle;
        private _angularMotion=vectorMagnitude angularVelocity _vehicle;
        _motionSafe=finite _linearMotion && {finite _angularMotion}
            && {_linearMotion < (1/3.6)} && {_angularMotion < 0.01};
    };
    // Physical vacancy alone does not release a mission-assigned incoming driver.
    private _driverSeat=(fullCrew [_vehicle,"driver",true]) param [0,[]];
    private _assignedDriver=_driverSeat param [5,objNull];
    local _group && {alive _vehicle} && {canMove _vehicle} && {_motionSafe}
        && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle} && {!lockedDriver _vehicle}
        && {vehicle leader _group == _vehicle}
        && {currentCommand leader _group != "STOP"}
        && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain}
        && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {!(_brain getOrDefault ["cancelled",false])} && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
        && {[_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
        && {[_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
        && {[_group] call CBE_fnc_DrivingMovementAvailable}
        && {!([_group] call CBE_fnc_CortexZeusHeld)} && {!([_group] call CBE_fnc_CortexExternalTakeover)}
        && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
        && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        && {count _crew <= 20} && {count _driverSeat >= 6}
        && {isNull _assignedDriver || {!alive _assignedDriver} || {_assignedDriver == _candidate}}
        && {isNull _candidate || {!([_candidate] call CBE_fnc_CortexActorMoveReserved)}}
        && {_route isNotEqualTo []}
        && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {_crew findIf {
            private _actor=_x select 0;
            isPlayer _actor || {!isNull remoteControlled _actor}
                || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                || {[_actor] call CBE_fnc_CortexExternalOwner != ""}
                || {alive _actor && {group _actor != _group || {!local _actor} || {fleeing _actor}
                    || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
                    || {currentCommand _actor in _tasks}
                    || {currentCommand _actor == "ACTION" && {!(_actor == _candidate && {_phase == "SWITCHING"})}}}}
        } < 0}
};
private _finish={
    params ["_result"];
    if (count _work > 0) then {_work set ["phase",_result];_work set ["ended",serverTime];_changed=true};
    call _publish;false
};
// An observed new occupant after the original deadline cannot be attributed to this
// finite attempt. Validate existing clocks before the early SWITCHING success path.
if (count _work > 0) then {
    private _crewExistingDeadline=_work getOrDefault ["deadline",[]];
    if (!(_crewExistingDeadline isEqualType 0) || {!finite _crewExistingDeadline}) then {
        _phase="INVALID_DEADLINE";
    } else {
        if (serverTime >= _crewExistingDeadline) then {_phase="EXPIRED_DEADLINE"};
    };
};
if (_phase == "INVALID_DEADLINE") exitWith {["CANCELLED"] call _finish};
if (_phase == "EXPIRED_DEADLINE") exitWith {["EXPIRED"] call _finish};
// Confirmation is observation, not permission to issue another action. A successful native
// switch may already be driving by the next sample; retain all other owner/task/route guards.
if (_phase == "SWITCHING" && {!isNull _candidate} && {driver _vehicle == _candidate}
    && {[_candidate] call CBE_fnc_CortexCombatEffective}) exitWith {
    [["CANCELLED","COMPLETE"] select ([false] call _available)] call _finish
};
if !([true] call _available) exitWith {["CANCELLED"] call _finish};
// Seat recovery consumes the same protected plain-MOVE policy as driving recovery.
// Native casualty intent/seat rebinding is a separate contract, not gate eligibility.
if ((_route param [0,"",[""]]) == "NATIVE_MOVE"
    || {([_group] call CBE_fnc_DrivingRouteGoal) isEqualTo []}) exitWith {["CANCELLED"] call _finish};
if (count _work == 0) then {
    if (!isNull _driver && {alive _driver}) exitWith {};
    private _choices=_crew select {
        private _actor=_x select 0;
        alive _actor && {local _actor} && {!fleeing _actor} && {group _actor == _group} && {!isPlayer _actor}
            && {[_actor] call CBE_fnc_CortexCombatEffective}
            && {simulationEnabled _actor} && {!isObjectHidden _actor}
            && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {assignedVehicle _actor == _vehicle}
            && {(_x param [5,objNull]) == _actor}
            && {currentCommand _actor != "STOP"}
    };
    private _cargo=_choices select {toLowerANSI (_x select 1) == "cargo"};
    if (_cargo isNotEqualTo []) then {_choices=_cargo} else {
        // Preserve the primary weapon station whenever another eligible crew member can drive.
        // Native fullCrew row order is not a tactical role preference.
        private _seatCommander=commander _vehicle;
        private _commandCrew=_choices select {(_x select 0) == _seatCommander};
        if (_commandCrew isNotEqualTo []) then {_choices=_commandCrew} else {
            private _primaryGunner=gunner _vehicle;
            private _otherCrew=_choices select {(_x select 0) != _primaryGunner};
            if (_otherCrew isNotEqualTo []) then {_choices=_otherCrew};
        };
    };
    if (_choices isNotEqualTo []) then {
        _candidate=(_choices select 0) select 0;
        _work=createHashMapFromArray [["group",_group],["route",_route],["driver",_driver],["candidate",_candidate],
            ["command",+(expectedDestination _candidate)],["assignment",assignedVehicleRole _candidate],
            ["leader",leader _group],["leaderCommand",+(expectedDestination leader _group)],
            ["nativeCommand",currentCommand _candidate],["leaderNativeCommand",currentCommand leader _group],
            ["deadline",serverTime+25],["phase","READY"],["started",serverTime]];
        _phase="READY";_changed=true;_brain set ["crewVehicle",_vehicle];
    };
};
if (count _work == 0) exitWith {call _publish;false};
_brain set ["crewVehicle",_vehicle];
if (serverTime >= (_work get "deadline")) exitWith {["EXPIRED"] call _finish};
if (isNull _candidate || {!local _candidate} || {fleeing _candidate} || {vehicle _candidate != _vehicle}
    || {!([_candidate] call CBE_fnc_CortexCombatEffective)}
    || {!simulationEnabled _candidate} || {isObjectHidden _candidate}
    || {!(_candidate checkAIFeature "MOVE")} || {!(_candidate checkAIFeature "PATH")}
    || {leader _group != (_work get "leader")}
    || {!([_candidate,_work getOrDefault ["nativeCommand","MISSING_RECEIPT"]] call _commandOwned)}
    || {!([leader _group,_work getOrDefault ["leaderNativeCommand","MISSING_RECEIPT"]] call _commandOwned)}
    || {(expectedDestination leader _group) isNotEqualTo (_work get "leaderCommand")} || {!(assignedVehicle _candidate in [objNull,_vehicle])}
    || {(expectedDestination _candidate) isNotEqualTo (_work get "command")}
    || {assignedVehicleRole _candidate isNotEqualTo (_work get "assignment")}) exitWith {["CANCELLED"] call _finish};
if (!isNull _driver && {_driver != (_work get "driver") || {alive _driver}}) exitWith {["CANCELLED"] call _finish};
// Seat vacancy and native order proof are checked atomically with each action.
private _commandsOwned={
    (_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]) isEqualTo _entryWork
        && {serverTime < (_work get "deadline")}
        && {vehicle _candidate == _vehicle} && {[_candidate] call CBE_fnc_CortexCombatEffective}
        && {!([_candidate] call CBE_fnc_CortexActorMoveReserved)}
        && {simulationEnabled _candidate} && {!isObjectHidden _candidate}
        && {_candidate checkAIFeature "MOVE"} && {_candidate checkAIFeature "PATH"}
        && {leader _group == (_work get "leader")}
        && {currentCommand _candidate != "STOP"}
        && {[_candidate,_work getOrDefault ["nativeCommand","MISSING_RECEIPT"]] call _commandOwned}
        && {[leader _group,_work getOrDefault ["leaderNativeCommand","MISSING_RECEIPT"]] call _commandOwned}
        && {(expectedDestination leader _group) isEqualTo (_work get "leaderCommand")}
        && {(expectedDestination _candidate) isEqualTo (_work get "command")}
        && {assignedVehicle _candidate in [objNull,_vehicle]}
        && {assignedVehicleRole _candidate isEqualTo (_work get "assignment")}
};
if (_phase == "READY" && {!isNull _driver}) then {
    isNil {
        if ([true] call _available && {call _commandsOwned} && {driver _vehicle == _driver} && {!alive _driver}
            && {local _driver} && {!isPlayer _driver} && {simulationEnabled _driver} && {!isObjectHidden _driver}) then {
            _driver action ["Eject",_vehicle];
            _work set ["vacateIssuedAt",serverTime];
            _work set ["phase","VACATING"];_changed=true;_phase="VACATING_ISSUED";
            call _publish;
        };
    };
};
// Native Eject may leave a corpse occupying the seat. The engine also supports an
// internal MoveToDriver swap; try it once without moving/deleting the body ourselves.
private _vacatedOrDead={
    private _occupant=driver _vehicle;
    if (isNull _occupant) exitWith {true};
    private _issued=_work getOrDefault ["vacateIssuedAt",-1];
    _phase == "VACATING" && {_occupant isEqualTo (_work get "driver")}
        && {!alive _occupant} && {local _occupant} && {!isPlayer _occupant}
        && {simulationEnabled _occupant} && {!isObjectHidden _occupant}
        && {_issued isEqualType 0} && {finite _issued} && {_issued >= 0}
        && {serverTime >= _issued+2}
};
if (_phase in ["READY","VACATING"]) then {
    isNil {
        if ([true] call _available && {call _commandsOwned} && {call _vacatedOrDead}) then {
            _candidate action ["MoveToDriver",_vehicle];
            _work set ["nativeCommand",currentCommand _candidate];
            _work set ["leaderNativeCommand",currentCommand leader _group];
            _work set ["command",+(expectedDestination _candidate)];
            _work set ["leaderCommand",+(expectedDestination leader _group)];
            _work set ["assignment",assignedVehicleRole _candidate];
            _work set ["phase","SWITCHING"];_changed=true;
            call _publish;
        };
    };
};
call _publish;
true
