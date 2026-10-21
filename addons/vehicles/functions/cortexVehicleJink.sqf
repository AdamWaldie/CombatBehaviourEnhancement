/*
 * Author: WaldoTheWarfighter
 * Both current control seats are checked and bound for admission, commit and continuation.
 * Horn exclusion uses config inheritance/simulation, never localised display text.
 * Purpose: Starts one short terrain-checked escape by an intact armed ground vehicle after a close
 * hostile, hit or explosion danger generation, without becoming a persistent driving controller.
 * Locality / Authority: Runs on the current group and vehicle owner. It yields to convoy, player,
 * Zeus, specialist, existing operation and foot-element ownership before issuing movement.
 * Repeat/JIP: The caller records both acceptance and refusal for the danger generation. Accepted
 * movement uses the shared operation generation, movement lease and waypoint cleanup, so locality
 * adoption and cancellation follow the same rules as other vehicle movement. The public marker
 * includes the operation generation so retiring an old jink cannot erase a successor marker.
 * Arguments: 0 group <GROUP>; 1 state <HASHMAP>; 2 vehicle <OBJECT>; 3 threat position <ARRAY>;
 * 4 threat object <OBJECT, default objNull>; 5 danger generation <NUMBER, default -1>.
 * Return Value: BOOL - true only when the physical jink operation was started.
 * Current callers: CBE_fnc_CortexVehicles for the exact platform carried by native danger.
 * Example: [group driver apc1,state,apc1,getPosATL enemy1,enemy1,4] call CBE_fnc_CortexVehicleJink;
 */

params [
    ["_group",grpNull,[grpNull]], ["_state",createHashMap,[createHashMap]],
    ["_vehicle",objNull,[objNull]], ["_threatPosition",[],[[]]],
    ["_threat",objNull,[objNull]], ["_dangerGeneration",-1,[0]]
];
private _refuse={
    params ["_reason"];
    _state set ["vehicleJinkRefusal",[_reason,serverTime,_vehicle,_dangerGeneration]];
    false
};
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {count _threatPosition < 2} || {_dangerGeneration < 0}) exitWith {["INVALID_OWNER"] call _refuse};
if !([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled
    && {[_group,"CBE_AIPass_VehicleJink_Enable",true] call CBE_fnc_CortexFeatureEnabled}) exitWith {["DISABLED"] call _refuse};
if ([_group] call CBE_fnc_CortexExternalTakeover
    || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[_vehicle] call CBE_fnc_CompatibilityExternalControl}
    || {_vehicle isKindOf "StaticWeapon"} || {!(_vehicle isKindOf "LandVehicle")}
    || {!alive _vehicle} || {!canMove _vehicle} || {abs speed _vehicle > 25}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}) exitWith {["MOVEMENT_OR_PLATFORM"] call _refuse};
private _driver=driver _vehicle;
if (isNull _driver || {!alive _driver} || {!local _driver} || {isPlayer _driver}
    || {group _driver != _group} || {!isNull (remoteControlled _driver)}) exitWith {["DRIVER"] call _refuse};
// Share the existing protected-task/reservation predicate; refuse before reserving an operation.
if (!([_driver] call CBE_fnc_CortexCombatEffective)
    || {!(_driver checkAIFeature "MOVE")} || {!(_driver checkAIFeature "PATH")}
    || {!([_driver] call CBE_fnc_CortexActorFireTaskAvailable)}) exitWith {["DRIVER_TASK"] call _refuse};
private _jinkSeats=[_driver,effectiveCommander _vehicle];
if (!([_group,_vehicle,_jinkSeats] call CBE_fnc_CortexVehicleCrewAvailable)) exitWith {["CREW_TASK"] call _refuse};
// A vehicle carrying passengers first owes them the normal task-safe dismount decision. The jink
// is reserved for a crewed fighting platform and cannot drag an unloading squad away.
if ((fullCrew [_vehicle,"",false]) findIf {
    private _role=_x select 1;
    alive (_x select 0) && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
} >= 0) exitWith {["PASSENGERS"] call _refuse};
if ((units _group) findIf {alive _x && {vehicle _x == _x}} >= 0) exitWith {["FOOT_ELEMENT"] call _refuse};
private _hasWeapon=([[-1]]+allTurrets [_vehicle,true]) findIf {
    (_vehicle weaponsTurret _x) findIf {
        private _config=configFile >> "CfgWeapons" >> _x;
        !(_x isKindOf ["CarHorn",configFile >> "CfgWeapons"])
            && {!(toLowerANSI getText (_config >> "simulation") in ["carhorn","cmlauncher"])}
    } >= 0
} >= 0;
if (!_hasWeapon) exitWith {["NO_WEAPON"] call _refuse};
private _origin=getPosATL _vehicle;
private _awayBearing=_threatPosition getDir _origin;
private _candidates=[];
{
    _candidates pushBack [_origin getPos [_x select 0,_awayBearing+(_x select 1)]];
} forEach [[35,0],[40,-30],[40,30],[45,-55],[45,55]];
private _route=[_origin,_candidates,_threatPosition,[],_threat,"VEHICLE"] call CBE_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {["NO_ROUTE"] call _refuse};
private _destination=+(_route select -1);
if (!([_group,_vehicle,_jinkSeats] call CBE_fnc_CortexVehicleCrewAvailable)) exitWith {["CREW_CHANGED"] call _refuse};
if !([_group,"VEHICLE_JINK",true,serverTime+25] call CBE_fnc_CortexOwnershipLease) exitWith {["LEASE_BUSY"] call _refuse};
private _operation=[_group,"VEHICLE_JINK",_threat,crew _vehicle,[_destination],"MOVING"] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"VEHICLE_JINK",false] call CBE_fnc_CortexOwnershipLease;
    ["OPERATION_REFUSED"] call _refuse
};
private _generation=_operation get "generation";
_operation set ["vehicleJinkCrew",[_vehicle,+_jinkSeats]];
if (!([_group,_vehicle,_jinkSeats] call CBE_fnc_CortexVehicleCrewAvailable)) exitWith {
    [_group,_generation,"VEHICLE_CREW_CHANGED"] call CBE_fnc_OperationCancel;
    [_group,"VEHICLE_JINK",false] call CBE_fnc_CortexOwnershipLease;
    ["CREW_CHANGED"] call _refuse
};
private _waypoint=[_group,_destination,25,"MOVE",_generation] call CBE_fnc_CortexGroupMove;
if (isNull (_waypoint param [0,grpNull,[grpNull]]) || {(_waypoint param [1,-1,[0]]) < 0}) exitWith {
    [_group,_generation,"INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
    [_group,"VEHICLE_JINK",false] call CBE_fnc_CortexOwnershipLease;
    ["MOVEMENT_REJECTED"] call _refuse
};
_state deleteAt "vehicleJinkRefusal";
_state set ["movementLease",["VEHICLE_JINK",time+25]];
_state set ["vehicleOperationGeneration",_operation get "generation"];
_vehicle setVariable ["CBE_Danger_VehicleJink",[_dangerGeneration,_group,_destination,serverTime+25,_generation],true];
true

