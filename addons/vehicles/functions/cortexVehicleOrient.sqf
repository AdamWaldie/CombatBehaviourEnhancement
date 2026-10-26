/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one finite chassis-orientation response for a stopped tracked fighting vehicle
 * toward the real hostile retained by the current native danger generation.
 * Locality / Authority: Runs on the current group and vehicle owner. It yields to convoy, player,
 * Zeus, specialist, declared platform driving ownership, existing operation and movement ownership
 * before issuing a turn command. Platform takeover retires the turn receipt without replay.
 * Repeat/JIP: Public VehicleTurn_Work survives state cleanup until native stop/replacement
 * observation; VehicleTurnRetire owns its finite cancellation. No new turn starts over that proof.
 * Acceptance and refusal are recorded by the caller for one danger generation. An
 * accepted response binds its original driver, effective commander and authored native order, and uses the shared
 * operation generation and movement
 * lease. A replaced/protected driver retires without late turn commands; the normal group tick
 * proves alignment or timeout and releases only the matching command owner.
 * Arguments: 0 group <GROUP>; 1 state <HASHMAP>; 2 vehicle <OBJECT>; 3 threat position <ARRAY>;
 * 4 threat object <OBJECT>; 5 danger generation <NUMBER, -1>.
 * Return Value: BOOL - true only when the finite orientation operation was started.
 * Current callers: CBE_fnc_CortexVehicles for the exact tracked platform carried by native danger.
 * Example: [group driver tank1,state,tank1,getPosATL enemy1,enemy1,4] call CBE_fnc_CortexVehicleOrient;
 */

params [
    ["_group",grpNull,[grpNull]], ["_state",createHashMap,[createHashMap]],
    ["_vehicle",objNull,[objNull]], ["_threatPosition",[],[[]]],
    ["_threat",objNull,[objNull]], ["_dangerGeneration",-1,[0]]
];
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {isNull _threat} || {!alive _threat} || {!(count _threatPosition in [2,3])}
    || {_threatPosition findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _dangerGeneration} || {_dangerGeneration < 0} || {_dangerGeneration != floor _dangerGeneration}
    || {(_group getVariable ["CBE_VehicleTurn_Work",createHashMap]) isNotEqualTo createHashMap}) exitWith {false};
if !([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled
    && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}) exitWith {false};
if ([_group] call CBE_fnc_CortexExternalTakeover
    || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[_vehicle] call CBE_fnc_CompatibilityExternalControl}
    || {!(_vehicle isKindOf "Tank")} || {!alive _vehicle} || {!canMove _vehicle}
    || {abs speed _vehicle > 5}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}) exitWith {false};
private _commander=effectiveCommander _vehicle;
private _driver=driver _vehicle;
if (isNull _commander || {!alive _commander} || {!local _commander} || {isPlayer _commander}
    || {group _commander != _group} || {!isNull (remoteControlled _commander)}
    || {isNull _driver} || {!alive _driver} || {!local _driver} || {isPlayer _driver}
    || {group _driver != _group} || {!isNull remoteControlled _driver}
    || {!([_driver] call CBE_fnc_CortexCombatEffective)}
    || {!(_driver checkAIFeature "MOVE")} || {!(_driver checkAIFeature "PATH")}
    || {!([_driver] call CBE_fnc_CortexActorFireTaskAvailable)}) exitWith {false};
if (!([_commander] call CBE_fnc_CortexCombatEffective)
    || {_commander != _driver && {!([_commander] call CBE_fnc_CortexActorFireTaskAvailable)}}) exitWith {false};
// Remembered identity cannot authorise a hostile manoeuvre after allegiance/captivity changes.
if (_threat isKindOf "Logic" || {_threat isKindOf "HeadlessClient_F"} || {captive _threat}
    || {_threat getVariable ["ace_captives_isSurrendering",false]}
    || {_threat getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _group) getFriend (side _threat) >= 0.6}) exitWith {false};
if (_commander knowsAbout _threat <= 0 || {_commander == _driver}) exitWith {false};
private _input=vehicleMoveInfo _vehicle;
if (toUpperANSI (_input param [0,"",[""]]) in ["BACK","DIRECTBYCOMANDER"]
    || {toUpperANSI (_input param [1,"",[""]]) != "NONE"}) exitWith {false};
private _relative=_vehicle getRelDir _threatPosition;
if (_relative <= 20 || {_relative >= 340}) exitWith {false};
if !([_group,"VEHICLE_ORIENT",true,serverTime+8] call CBE_fnc_CortexOwnershipLease) exitWith {false};
private _operation=[_group,"VEHICLE_ORIENT",_threat,crew _vehicle,[],"ORIENTING"] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"VEHICLE_ORIENT",false] call CBE_fnc_CortexOwnershipLease;
    false
};
private _operationGeneration=_operation get "generation";
private _nativeOrder=[_group] call CBE_fnc_NativeOrderReceipt;
private _turnDirection=["LEFT","RIGHT"] select (_relative < 180);
private _turnGoal=+_threatPosition;
if (count _turnGoal == 2) then {_turnGoal pushBack 0};
private _marker=[_dangerGeneration,_group,_turnGoal,serverTime+8,
    _operationGeneration,_driver,_nativeOrder,_commander,_turnDirection];
// Publish the immutable turn and native-seat context before the native command.
_vehicle setVariable ["CBE_Danger_VehicleOrient",_marker,true];
_group setVariable ["CBE_VehicleTurn_Work",createHashMapFromArray [
    ["vehicle",_vehicle],["marker",+_marker],["sourceOwner",clientOwner],
    ["ownerEpoch",_group getVariable ["CBE_AIPass_Epoch",0]],
    ["nativeSeats",[[currentCommand _driver,expectedDestination _driver],
        [currentCommand _commander,expectedDestination _commander]]],
    ["cleanupUntil",(_marker select 3)+30],["phase","TURN"]],true];
_vehicle sendSimpleCommand _turnDirection;
_state set ["movementLease",["VEHICLE_ORIENT",time+8]];
_state set ["vehicleOperationGeneration",_operationGeneration];
true
