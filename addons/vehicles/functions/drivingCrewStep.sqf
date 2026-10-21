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
 * unit-local native actions. Authored seat actions may use a remote vehicle; native goal
 * resumption requires local vehicle and actual operating owner.
 * An authored plain MOVE uses the shared DrivingRouteGoal policy, including a finite goal.
 * Native casualty retains only an already admitted vehicle goal. Actual replacement-seat
 * occupancy and one finite original-goal acknowledgement rebind its operating receipt.
 * Active recovery-command casualties remain unsupported. Player, Zeus, specialist, convoy,
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
private _nativeCrew=(_route param [0,"",[""]]) == "NATIVE_MOVE";
private _nativeGoal=if (_nativeCrew) then {_route param [6,[],[[]]]} else {[]};
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
if (_terminal && {((_work get "phase") == "COMPLETE" && {isNull _driver})
    || {!isNull _driver && {_driver != (_work get "driver")} && {!alive _driver}}}) then {
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
        || {_actor == _candidate && {_phase in ["SWITCHING","RETURNING"]} && {currentCommand _actor == "ACTION"}}
};
// The availability check supplies the crew snapshot used for candidate selection.
// Refresh again at each native seat action; do not enumerate an unused entry snapshot.
private _crew=[];
private _tasks=["GET IN","GET OUT","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
    "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
private _nativeSeatTarget={
    params ["_seatActor","_seatTarget"];
    if (_seatActor != _candidate || {!(_phase in ["SWITCHING","RETURNING"])}) exitWith {false};
    private _recordedSeatTarget=(_work getOrDefault ["command",[]]) param [0,[],[[]]];
    count _recordedSeatTarget == 3
        && {_recordedSeatTarget findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_seatTarget vectorDistance _recordedSeatTarget <= 3}
};
private _nativeMissionCurrent={
    if (!_nativeCrew) exitWith {true};
    private _intentOperator=effectiveCommander _vehicle;
    if (isNull _intentOperator || {!alive _intentOperator}) then {_intentOperator=leader _group};
    [leader _group,_intentOperator] findIf {
        private _intentActor=_x;
        isNull _intentActor || {!local _intentActor} || {!alive _intentActor}
            || {private _intentTask=currentCommand _intentActor;
                !(_intentTask in ["","MOVE","WAIT","FOLLOW"]
                    || {_intentActor == _candidate && {_phase in ["SWITCHING","RETURNING"]} && {_intentTask == "ACTION"}})
                || {_intentTask == "MOVE" && {
                    private _intentTarget=(expectedDestination _intentActor) param [0,[],[[]]];
                    count _intentTarget != 3 || {_intentTarget findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
                        || {_intentTarget vectorDistance _nativeGoal > 3
                        && {!([_intentActor,_intentTarget] call _nativeSeatTarget)}}
                }}
            }
    } < 0
};
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
        && {call _nativeMissionCurrent}
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
                    || {currentCommand _actor == "ACTION" && {!(_actor == _candidate && {_phase in ["SWITCHING","RETURNING"]})}}}}
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
private _nativeAtGoal={
    params ["_actor"];
    private _target=(expectedDestination _actor) param [0,[],[[]]];
    currentCommand _actor == "MOVE" && {count _target == 3}
        && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_target vectorDistance _nativeGoal <= 3}
};
private _nativeComplete={
    isNil {
        private _newDriver=driver _vehicle;private _newOperator=effectiveCommander _vehicle;
        if (isNull _newOperator) then {_newOperator=_newDriver};
        if ((_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain
            && {(_brain get "route") isEqualTo _route}
            && {(_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]) isEqualTo _entryWork}
            && {serverTime < (_work get "deadline")} && {_newDriver == _candidate}
            && {local _group} && {local _newDriver} && {local _newOperator}
            && {[_newDriver] call CBE_fnc_CortexCombatEffective}
            && {[_newOperator] call CBE_fnc_CortexCombatEffective}
            && {[_newDriver] call _nativeAtGoal}
            && {[_newOperator] call _nativeAtGoal}) then {
            private _newRoute=["NATIVE_MOVE",_group,_vehicle,_newDriver,_newOperator,
                [currentCommand _newDriver,+(expectedDestination _newDriver),currentCommand _newOperator,+(expectedDestination _newOperator)],
                +_nativeGoal,_brain get "ownerEpoch",clientOwner];
            _work set ["originalRoute",+_route];_work set ["route",_newRoute];
            _brain set ["route",_newRoute];
            ["COMPLETE"] call _finish;
        };
    };
    false
};
if (_nativeCrew && {_phase == "RETURNING"}) exitWith {
    private _resume=_work getOrDefault ["nativeResume",[]];
    private _newOperator=effectiveCommander _vehicle;
    if (isNull _newOperator) then {_newOperator=driver _vehicle};
    if (!(_resume isEqualType []) || {count _resume != 3} || {driver _vehicle != _candidate}
        || {_newOperator != (_work getOrDefault ["resumeOperator",objNull])}
        || {isNull _newOperator} || {!local _newOperator}
        || {!([_candidate] call CBE_fnc_CortexCombatEffective)}
        || {!([_newOperator] call CBE_fnc_CortexCombatEffective)}
        || {!([false] call _available)}) exitWith {["CANCELLED"] call _finish};
    if (!((_resume select 0) isEqualTo _nativeGoal) || {!((_resume select 1) isEqualType 0)}
        || {!finite (_resume select 1)} || {(_resume select 1) > (_work get "deadline")}
        || {!((_resume select 2) isEqualType [])} || {count (_resume select 2) != 4}) exitWith {["CANCELLED"] call _finish};
    if (serverTime >= (_resume select 1)) exitWith {["EXPIRED"] call _finish};
    if ([_candidate] call _nativeAtGoal && {[_newOperator] call _nativeAtGoal}) exitWith {call _nativeComplete};
    private _before=_resume select 2;
    private _pending=[0,1] findIf {
        private _slot=_x*2;
        private _resumeActor=[_candidate,_newOperator] select _x;
        !((expectedDestination _resumeActor) isEqualTo (_before select (_slot+1)))
            && {!([_resumeActor] call _nativeAtGoal)}
            || {!(currentCommand _resumeActor in [_before select _slot,"MOVE"])}
    } < 0;
    if (!_pending) exitWith {["CANCELLED"] call _finish};
    true
};
// Confirmation is observation, not permission to issue another seat action.
if (_phase == "SWITCHING" && {!isNull _candidate} && {driver _vehicle == _candidate}
    && {[_candidate] call CBE_fnc_CortexCombatEffective}) exitWith {
    if (!([false] call _available)) exitWith {["CANCELLED"] call _finish};
    if (!_nativeCrew) exitWith {["COMPLETE"] call _finish};
    private _newOperator=effectiveCommander _vehicle;
    if (isNull _newOperator) then {_newOperator=_candidate};
    if (!local _vehicle || {isNull _newOperator} || {!local _newOperator}
        || {!([_newOperator] call CBE_fnc_CortexCombatEffective)}) exitWith {["CANCELLED"] call _finish};
    if ([_candidate] call _nativeAtGoal && {[_newOperator] call _nativeAtGoal}) exitWith {call _nativeComplete};
    // A newer MOVE/STOP must not be overwritten after seat confirmation. A native
    // seat action may still expose the target recorded by its own seat action.
    private _resumeFree={[_candidate,_newOperator] findIf {
        private _cmd=currentCommand _x;
        private _target=(expectedDestination _x) param [0,[],[[]]];
        !(_cmd in ["","MOVE","WAIT"] || {_x == _candidate && {_cmd == "ACTION"}})
            || {_cmd == "MOVE" && {count _target != 3
                || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
                || {_target vectorDistance _nativeGoal > 3 && {!([_x,_target] call _nativeSeatTarget)}}}}
    } < 0};
    if (!(call _resumeFree)) exitWith {["CANCELLED"] call _finish};
    isNil {
        if ([false] call _available && {(_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]) isEqualTo _entryWork}
            && {serverTime < (_work get "deadline")} && {driver _vehicle == _candidate}
            && {_newOperator == (if (isNull effectiveCommander _vehicle) then {_candidate} else {effectiveCommander _vehicle})}
            && {call _resumeFree}) then {
            private _before=[currentCommand _candidate,+(expectedDestination _candidate),
                currentCommand _newOperator,+(expectedDestination _newOperator)];
            _newOperator doMove _nativeGoal;
            _work set ["nativeResume",[+_nativeGoal,(serverTime+2) min (_work get "deadline"),_before]];
            _work set ["resumeOperator",_newOperator];_work set ["phase","RETURNING"];
            _changed=true;call _publish;
        };
    };
    true
};
if !([true] call _available) exitWith {["CANCELLED"] call _finish};
if (([_group] call CBE_fnc_DrivingRouteGoal) isEqualTo []) exitWith {["CANCELLED"] call _finish};
if (_nativeCrew) then {
    private _leaderTarget=(expectedDestination leader _group) param [0,[],[[]]];
    if (currentCommand leader _group == "MOVE" && {count _leaderTarget != 3
        || {_leaderTarget vectorDistance _nativeGoal > 3}}) then {_nativeGoal=[]};
};
if (_nativeCrew && {_nativeGoal isEqualTo []}) exitWith {["CANCELLED"] call _finish};
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
// Settle exact prior cap ownership before native casualty actions. Recovery-command
// handback with a dead driver is not inferred by this seat executor.
if (_nativeCrew) then {
    if (count (_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) > 0) exitWith {_phase="NATIVE_RECOVERY_UNRESOLVED"};
    [_vehicle,_group] call CBE_fnc_DrivingAssistRelease;
};
if (_phase == "NATIVE_RECOVERY_UNRESOLVED") exitWith {["CANCELLED"] call _finish};
if (_nativeCrew && {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isNotEqualTo []
    || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo []}}) exitWith {call _publish;true};
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
