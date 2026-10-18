/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires a matching ordinary recovery journal; only its exact owned reverse can stop
 * and hand back to the unchanged plain authored MOVE. Forward retries retire metadata only.
 * Locality / Authority: Current vehicle/group owner. Original seats, both native destinations,
 * route, external/tactical ownership and crew tasks protect cleanup. No waypoint reconstruction.
 * Active fire, attack, service and other non-route commands forbid movement cleanup.
 * The current forced-speed cap must still match this journal before stopping or redirecting
 * a reverse. A changed cap retires metadata only; it never grants handback authority.
 * Effective-commander absence resolves to the driver exactly as at journal capture.
 * A native STOP or individual movement reservation overrides an unchanged destination receipt
 * and forbids movement cleanup; reservation state is never cleared by recovery release.
 * Repeat/JIP: Public stage clocks and cap baseline survive migration without command replay.
 * Cleanup compares the current journal before clearing; newer work and commands remain untouched.
 * Admission, route metadata, native command checks and handback execute without suspension.
 * Split vehicle/group/crew locality preserves an unchanged issued reverse journal and cap
 * until the existing owner callback can finish cleanup. This retention grants no commands.
 * Changed seats/route/cap/native intent or external ownership revoke retention immediately.
 * An otherwise exactly owned reverse retains its journal while mobility/simulation prevents
 * handback. Receipt-only cleanup survives tactical shutdown only to the original hard deadline.
 * Expired unchanged handback becomes unresolved; its journal/cap remain and automatic retries stop.
 * Newer native orders can still retire metadata without replaying stale commands.
 * A leader on foot or without an eligible mounted target permits stopping our reverse only;
 * no crew follows a dismounted leader. Result field5 distinguishes native handback from a stop.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 reason <STRING, RELEASED>; 3 resume <BOOL, true> permits exact reverse handback.
 * Return Value: BOOL - matching journal retired, never physical recovery success; false also
 * reports deferred exact reverse handback while its journal remains public.
 * Current callers: DrivingAssistStart and DrivingAssistRelease.
 * Example: [truck1,group driver truck1,"DRIVING_RELEASED"] call CBE_fnc_DrivingRecoveryRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]]];
// No scheduled yield may separate the ownership proof from native commands or retirement.
private _released=false;
isNil {
    _released=call {
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
// A blocked exact handback has only the original recovery lifetime. Expiry preserves
// command/cap provenance but never grants a late command or a newly renewed cleanup window.
// Call this only after proving unchanged ownership; newer orders still retire metadata normally.
private _releaseExpired={
    if (!_resume || {!(_work getOrDefault ["releasePending",false])}) exitWith {false};
    private _until=_work getOrDefault ["hardDeadline",-1];
    private _invalid=!(_until isEqualType 0) || {!finite _until} || {_until < 0};
    if (!(_work getOrDefault ["releaseUnresolved",false]) && {!_invalid} && {serverTime < _until}) exitWith {false};
    if !(_work getOrDefault ["releaseUnresolved",false]) then {
        _work set ["releaseUnresolved",true];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        private _outcome=["UNRESOLVED_DEADLINE","UNRESOLVED_INVALID_DEADLINE"] select _invalid;
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[
            _reason,serverTime,_group,_work get "kind",_until,_outcome
        ],true];
        diag_log format ["CBE driving cleanup %1: vehicle=%2 group=%3 originalDeadline=%4",_outcome,netId _vehicle,_group,_until];
    };
    true
};
private _driver=_work get "driver";private _operator=_work get "operator";
private _liveOperator=effectiveCommander _vehicle;
if (isNull _liveOperator) then {_liveOperator=driver _vehicle};
// Vehicle locality can arrive before group/crew locality. Do not mistake that gap
// for revoked command identity and erase the only public cleanup receipt. This proof
// permits retention only; ordinary handback below still requires every actual owner.
private _retainAcrossLocality=_resume && {(_work get "kind") == "REVERSE"}
    && {alive _vehicle} && {!isNull _group} && {!isNull _driver} && {!isNull _operator}
    && {driver _vehicle == _driver} && {_liveOperator == _operator}
    && {abs ((getForcedSpeed _vehicle)-(_work get "cap")) <= 0.1}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
    && {[_driver,_operator] findIf {
        !alive _x || {group _x != _group} || {vehicle _x != _vehicle}
            || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
            || {(_x getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo []}
            || {!(toUpperANSI currentCommand _x in ["","MOVE","WAIT"])}
    } < 0};
if (_retainAcrossLocality && {!local _group || {!local _driver} || {!local _operator}}) exitWith {
    if (call _releaseExpired) exitWith {false};
    if !(_work getOrDefault ["releasePending",false]) then {
        _work set ["releasePending",true];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[
            _reason,serverTime,_group,_work get "kind",_work get "hardDeadline","DEFERRED_LOCALITY"
        ],true];
    };
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
    false
};
private _handback="METADATA_ONLY";
private _owned=_resume && {(_work get "kind") == "REVERSE"}
    && {alive _vehicle}
    && {local _group} && {!isNull _driver} && {!isNull _operator}
    && {driver _vehicle == _driver} && {_liveOperator == _operator}
    && {abs ((getForcedSpeed _vehicle)-(_work get "cap")) <= 0.1}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {[_group] call CBE_fnc_DrivingMovementAvailable}
    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}};
{
    _owned=_owned && {!isNull _x} && {local _x} && {group _x == _group} && {vehicle _x == _vehicle}
        && {[_x] call CBE_fnc_CortexCombatEffective}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_x] call CBE_fnc_CortexExternalOwner == ""}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {currentCommand _x != "STOP"}
        && {toUpperANSI currentCommand _x in ["","MOVE","WAIT"]}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
} forEach [_driver,_operator];
if (_owned && {call _releaseExpired}) exitWith {false};
private _executable=canMove _vehicle && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
    && {[_driver,_operator] findIf {!simulationEnabled _x || {isObjectHidden _x}} < 0};
if (_owned && {!_executable}) exitWith {
    // Keep proof of the issued rear command; do not turn a failed release into a fresh retry.
    // This receipt is not a motion lease and never renews the original recovery deadlines.
    if !(_work getOrDefault ["releasePending",false]) then {
        _work set ["releasePending",true];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[
            _reason,serverTime,_group,_work get "kind",_work get "hardDeadline","DEFERRED"
        ],true];
    };
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
    false
};
if (_owned) then {
    private _index=currentWaypoint _group;private _waypoint=[_group,_index];private _statements=waypointStatements _waypoint;
    private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
    if (_index > 0 && {_index < count waypoints _group} && {waypointType _waypoint == "MOVE"} && {_condition == "true"}
        && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
        && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
        && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
        && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []}) then {
        private _leader=leader _group;
        private _leaderVehicle=vehicle _leader;
        private _mountedTarget=!isNull _leader && {[_leader] call CBE_fnc_CortexCombatEffective}
            && {_leaderVehicle != _leader} && {_leaderVehicle isKindOf "LandVehicle"}
            && {alive _leaderVehicle} && {canMove _leaderVehicle}
            && {simulationEnabled _leaderVehicle} && {!isObjectHidden _leaderVehicle};
        [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
        doStop _driver;if (_operator != _driver) then {doStop _operator};
        _handback="STOP_ONLY";
        // Following an on-foot leader could cause crew dismount; never invent that task.
        if (_leaderVehicle == _vehicle || {_mountedTarget}) then {
            if (_driver != _operator) then {_driver doFollow _operator};
            if (_leaderVehicle == _vehicle) then {
                _operator doMove waypointPosition _waypoint;_handback="AUTHORED_ROUTE";
            } else {
                _operator doFollow _leader;_handback="MOUNTED_LEADER";
            };
        };
    };
};
if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work) then {
    _vehicle setVariable ["CBE_DrivingRecovery_Result",[_reason,serverTime,_group,_work get "kind",_work get "hardDeadline",_handback],true];
    _vehicle setVariable ["CBE_DrivingRecovery_Work",nil,true];
};
true

    };
};
_released
