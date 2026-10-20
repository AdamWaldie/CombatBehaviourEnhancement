/*
 * Author: WaldoTheWarfighter
 * Purpose: Hands back an unchanged authored route after an exact owned queue-abort STOP,
 * only when the existing driving observer has fresh clear traffic/geometry and an owned cap.
 * Locality/authority: current ordinary-driving vehicle/group owner and exact original brain
 * identity. New native orders, seats, route, reservations or successor work retire authority.
 * Repeat/JIP: consume once before native issue; original queue expiry plus15s bounds cleanup.
 * Public receipt is diagnostic on JIP, not replay authority. Migration does not auto-adopt it.
 * Arguments: 0 vehicle <OBJECT,objNull>; 1 group <GROUP,grpNull>; 2 brain <HASHMAP,empty>;
 * 3 safety <ARRAY,[]> [traffic observation, gate observation, solid observation, cap m/s];
 * 4 current route/authority predicate <CODE,{false}>, synchronous caller context only.
 * Return: BOOL true when route handoff was issued, not proof of travel or queue completion.
 * Cost: fixed two-seat checks; no search, geometry query, speed write, timer or new controller.
 * Current caller: DrivingAssistStart after its sole speed-cap transaction.
 * Example: [truck1,group driver truck1,_brain,[_traffic,_gate,_solid,_cap],{call _mayRecoverRoute}] call CBE_fnc_DrivingAbortHandback;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_brain",createHashMap,[createHashMap]],["_safety",[],[[]]],["_mayResume",{false},[{}]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle} || {isNull _group} || {!local _group}) exitWith {false};
private _hold=_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap];
if (!(_hold isEqualType createHashMap) || {count _hold == 0}) exitWith {false};
private _retire={
    params ["_result"];
    if ((_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap]) isEqualTo _hold) then {
        _vehicle setVariable ["CBE_DrivingAbort_Hold",nil,true];
        _vehicle setVariable ["CBE_DrivingAbort_Result",[_result,serverTime,_hold getOrDefault ["binding",[]]],true];
    };
};
private _deadline=_hold getOrDefault ["deadline",-1];
private _route=_hold getOrDefault ["route",[]];
private _driver=_hold getOrDefault ["driver",objNull];private _operator=_hold getOrDefault ["operator",objNull];
if (!(_deadline isEqualType 0) || {!finite _deadline} || {serverTime >= _deadline}
    || {(_hold getOrDefault ["group",grpNull]) != _group}
    || {(_hold getOrDefault ["owner",[]]) isNotEqualTo ([_group] call CBE_fnc_DrivingOwnerReceipt)}
    || {_route isNotEqualTo ([_group] call CBE_fnc_DrivingRouteReceipt)}
    || {driver _vehicle != _driver} || {effectiveCommander _vehicle != _operator}
    || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[_group] call CBE_fnc_CortexExternalTakeover} || {[_group] call CBE_fnc_CortexZeusHeld}
    || {[_driver,_operator] findIf {isNull _x || {!local _x} || {group _x != _group}
        || {vehicle _x != _vehicle} || {currentCommand _x != "STOP"}
        || {isPlayer _x} || {!isNull remoteControlled _x}
        || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
        || {[_x] call CBE_fnc_CompatibilityExternalControl}
        || {[_x] call CBE_fnc_CortexActorMoveReserved}} >= 0}
    || {(expectedDestination _driver) isNotEqualTo (_hold getOrDefault ["driverCommand",[]])}
    || {(expectedDestination _operator) isNotEqualTo (_hold getOrDefault ["command",[]])}
    || {formLeader _driver != (_hold getOrDefault ["driverLeader",objNull])}
    || {formLeader _operator != (_hold getOrDefault ["operatorLeader",objNull])}) exitWith {["REPLACED_OR_EXPIRED"] call _retire;false};
if (["CBE_DrivingQueue_Consent","CBE_DrivingBypass_Work","CBE_DrivingPass_Work","CBE_DrivingRecovery_Work"] findIf {
    count (_vehicle getVariable [_x,createHashMap]) > 0
} >= 0 || {(_vehicle getVariable ["CBE_DrivingCorridor_Work",[]]) isNotEqualTo []}) exitWith {["SUCCESSOR"] call _retire;false};
if (count _safety != 4 || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {_brain getOrDefault ["finished",false]} || {_brain getOrDefault ["cancelled",false]}) exitWith {false};
_safety params ["_traffic","_gate","_solid","_cap"];
if (!(_traffic isEqualType []) || {count _traffic < 4}
    || {!((_traffic select 1) isEqualType objNull)}
    || {!((_traffic select 3) isEqualType 0)} || {!finite (_traffic select 3)}
    || {!(_gate isEqualType [])} || {time < (_traffic select 3)} || {time-(_traffic select 3) > 1.5}
    || {!isNull (_traffic select 1)} || {_solid isNotEqualTo []}
    || {_gate isNotEqualTo [] && {count _gate < 4 || {!((_gate select 1) isEqualType objNull)}
        || {!((_gate select 3) isEqualType 0)} || {!finite (_gate select 3)} || {!isNull (_gate select 1)}
        || {time < (_gate select 3)} || {time-(_gate select 3) > 1.5}}}
    || {!(_cap isEqualType 0)} || {!finite _cap} || {_cap <= 0}) exitWith {false};
private _issued=false;
isNil {
    private _assist=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
    private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
    private _input=vehicleMoveInfo _vehicle;
    if ((_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap]) isNotEqualTo _hold
        || {serverTime >= _deadline} || {!(call _mayResume)}
        || {(_hold get "owner") isNotEqualTo ([_group] call CBE_fnc_DrivingOwnerReceipt)}
        || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
        || {!finite _linear} || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
        || {!(_assist isEqualType [])} || {count _assist < 4}
        || {!((_assist select 0) isEqualType 0)} || {!finite (_assist select 0)} || {(_assist select 3) != _group} || {(_assist select 0) != _cap}
        || {abs ((getForcedSpeed _vehicle)-_cap) > 0.1}
        || {toUpperANSI (_input param [0,""]) in ["BACK","DIRECTBYCOMANDER"]}
        || {toUpperANSI (_input param [1,""]) in ["LEFT","RIGHT"]}
        || {currentCommand _driver != "STOP"} || {currentCommand _operator != "STOP"}
        || {(expectedDestination _driver) isNotEqualTo (_hold get "driverCommand")}
        || {(expectedDestination _operator) isNotEqualTo (_hold get "command")}) exitWith {};
    ["HANDOFF_ISSUED"] call _retire;
    if (_driver != _operator) then {_driver doFollow _operator};
    _operator doMove waypointPosition [_group,currentWaypoint _group];
    _issued=true;
};
_issued
