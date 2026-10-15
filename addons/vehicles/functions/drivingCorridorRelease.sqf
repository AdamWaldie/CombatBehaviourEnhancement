/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires one ordinary-driving corridor episode and hands back only its unchanged command.
 * Locality / Authority: Vehicle/group owner only. Exact driver, native destination, route and
 * external/tactical ownership checks protect every stop and route-resume command.
 * Repeat/JIP: Retires public work once; retains a bounded 120-second context cooldown and terminal
 * diagnostic. No movement is replayed to joining clients or over a changed command/seat/route.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 group <GROUP, grpNull>; 2 reason <STRING, RELEASED>;
 * 3 resume <BOOL, true> - permit unchanged plain authored MOVE handback, never force it.
 * Return Value: BOOL - whether this matching episode was retired, not physical success.
 * Current callers: DrivingCorridorStep and DrivingAssistRelease.
 * Example: [truck1,group driver truck1,"AREA_CHANGED"] call WAIT_fnc_DrivingCorridorRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]]];
if (isRemoteExecuted || {isNull _vehicle} || {!local _vehicle} || {isNull _group} || {!local _group}) exitWith {false};
private _work=_vehicle getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
if (count _work == 0 || {(_work getOrDefault ["group",grpNull]) != _group}) exitWith {false};
private _driver=_work getOrDefault ["driver",objNull];
private _operator=_work getOrDefault ["operator",objNull];
private _route=_work getOrDefault ["route",[]];
private _owned=!isNull _driver && {!isNull _operator} && {local _driver} && {local _operator}
    && {driver _vehicle isEqualTo _driver} && {effectiveCommander _vehicle isEqualTo _operator}
    && {group _driver == _group} && {group _operator == _group}
    && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
    && {(expectedDestination _operator) isEqualTo (_work getOrDefault ["command",[]])}
    && {[_group] call WAIT_fnc_DrivingMovementAvailable}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {!([_group] call WAIT_fnc_CortexZeusHeld)}
    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
    && {alive _vehicle} && {canMove _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle};
{
    private _actor=_x;
    _owned=_owned && {[_actor] call WAIT_fnc_CortexCombatEffective} && {!isPlayer _actor}
        && {isNull remoteControlled _actor}
        && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_actor] call WAIT_fnc_CortexExternalOwner == ""}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
            "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
            "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
} forEach [_driver,_operator];
// The owned doStop cancels fixed steering; native-ready is not a path-completion receipt.
if (_owned && {_resume}) then {
    doStop _driver;
    private _index=currentWaypoint _group;
    if (_index > 0 && {_index < count waypoints _group}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {driver _vehicle isEqualTo _driver} && {effectiveCommander _vehicle isEqualTo _operator}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
        if (vehicle leader _group isEqualTo _vehicle) then {
            _operator doMove waypointPosition [_group,_index];
        } else {
            if (leader _group != _driver && {vehicle leader _group isKindOf "LandVehicle"}) then {
                _driver doFollow leader _group;
            };
        };
    };
};
private _key=_work get "context";
private _cooldown=(_vehicle getVariable ["WAIT_DrivingCorridor_Cooldown",[]]) select {
    (_x select 1) > serverTime && {(_x select 0) isNotEqualTo _key}
};
if (count _cooldown >= 32) then {_cooldown deleteAt 0};
_cooldown pushBack [_key,serverTime+120];
_vehicle setVariable ["WAIT_DrivingCorridor_Cooldown",_cooldown,true];
_vehicle setVariable ["WAIT_DrivingCorridor_Result",[_reason,serverTime,_work get "area",_work get "phase"],true];
_vehicle setVariable ["WAIT_DrivingCorridor_Work",nil,true];
true
