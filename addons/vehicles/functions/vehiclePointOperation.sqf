/*
 * Author: WaldoTheWarfighter
 * Purpose: Position one selected land vehicle through the existing finite selected-crew FSM.
 * Locality/authority: Current group/platform owner; server2 authenticated dispatch or local scripts.
 * Only original driver/commander move. No group waypoint, membership, passenger or weapon policy changes.
 * Repeat/JIP: Atomic START/CANCEL; one original30..300s deadline,10m arrival/3m height and30s
 * no-progress bound. Arrival holds until the deadline or explicit cancel, then requests native
 * return. Unsupported native baselines and unresolved older workers refuse new admission.
 * Migration retires existing commands only, never replays the outward leg. Cancellation is a
 * retirement request, not proof of a stopped vehicle. Ordinary driver assistance must hand back;
 * if its tracked roster includes another platform, refuse before group-scoped retirement.
 * Arguments: 0 mode STRING START/CANCEL;1 vehicle OBJECT objNull;2 goal ATL ARRAY3,[];
 * 3 original total duration NUMBER180 (30..300). Goal must be dry ground10..2000m away.
 * Return: BOOL admitted/retirement requested; physical arrival/native handback remain separate.
 * Current callers: CortexOrderLocal and owner-local mission scripts; VehicleTacticalMoveStart owns movement.
 * Example: ["START",apc1,[1200,1800,0],180] call CBE_fnc_VehiclePointOperation;
 */
params [["_mode","START",[""]],["_vehicle",objNull,[objNull]],["_goal",[],[[]]],["_duration",180,[0]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _vehicle || {!local _vehicle}) exitWith {false};
private _accepted=false;
isNil {
_accepted=call {
    private _work=_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
    if (_mode == "CANCEL") exitWith {
        if ((_work getOrDefault ["kind",""]) != "POINT"
            || {(_work getOrDefault ["phase",""]) in ["RETIRED","UNRESOLVED"]}) exitWith {false};
        private _originalGroup=_work getOrDefault ["group",grpNull];
        if (isNull _originalGroup || {!local _originalGroup}
            || {(_work getOrDefault ["owner",-1]) != clientOwner}
            || {(_work getOrDefault ["epoch",-1]) != (_originalGroup getVariable ["CBE_AIPass_Epoch",-2])}
            || {(_originalGroup getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo (_work get "reference")}) exitWith {false};
        _work set ["pointCancelled",true];
        [_vehicle,_work get "token",_work get "serial",true] call CBE_fnc_VehicleTacticalMoveRetire
    };
    if (_mode != "START" || {!finite _duration} || {_duration < 30} || {_duration > 300}
        || {count _goal != 3} || {_goal findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}
        || {(_goal select 2) < -0.5} || {(_goal select 2) > 2.5} || {surfaceIsWater _goal}
        || {!(_vehicle isKindOf "LandVehicle")} || {_vehicle isKindOf "StaticWeapon"}
        || {_vehicle distance2D _goal < 10} || {_vehicle distance2D _goal > 2000}
        || {waterDamaged _vehicle} || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {getForcedSpeed _vehicle == 0}) exitWith {false};
    private _driver=driver _vehicle;private _commander=effectiveCommander _vehicle;
    if (isNull _driver || {isNull _commander}) exitWith {false};
    private _group=group _driver;private _seats=[_driver,_commander];
    if (isNull _group || {!local _group} || {count units _group > 64}
        || {units _group findIf {isPlayer _x} >= 0}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}
        || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}
        || {!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_group,_vehicle,_seats] call CBE_fnc_CortexVehicleCrewAvailable)}
        || {_seats findIf {!(currentCommand _x in ["","MOVE","WAIT"])} >= 0}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
        || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}) exitWith {false};
    // Adopt before taking a lease: adoption may retire inherited native work.
    if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {[_group,true] call CBE_fnc_CortexLocality};
    if (!local _group || {!(_group getVariable ["CBE_AIPass_Adopted",false])}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
        || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}
        || {!([_group,_vehicle,_seats] call CBE_fnc_CortexVehicleCrewAvailable)}) exitWith {false};
    // Retiring group-wide driving must not alter another platform's speed/controller.
    private _driving=_group getVariable ["CBE_Driving_Brain",createHashMap];
    if (count _driving > 0 && {
        private _tracked=_group getVariable ["CBE_DrivingAssist_Vehicles",[]];
        private _route=_driving getOrDefault ["route",[]];
        private _crewVehicle=_driving getOrDefault ["crewVehicle",objNull];
        !(_tracked isEqualType []) || {count _tracked > 64}
            || {_tracked findIf {!(_x isEqualType objNull) || {!isNull _x && {_x != _vehicle}}} >= 0}
            || {!(_crewVehicle isEqualType objNull)} || {!isNull _crewVehicle && {_crewVehicle != _vehicle}}
            || {_route isEqualTo []} || {([_group] call CBE_fnc_DrivingRouteReceipt) isNotEqualTo _route}
            || {(_route param [0,"",[""]]) == "NATIVE_MOVE" && {count _route != 9 || {(_route select 2) isNotEqualTo _vehicle}}}
            || {units _group findIf {
                private _occupied=objectParent _x;
                !isNull _occupied && {_occupied != _vehicle} && {_occupied isKindOf "LandVehicle"}
                    && {!(_occupied isKindOf "StaticWeapon")}
                    && {driver _occupied in units _group || {effectiveCommander _occupied in units _group}}
            } >= 0}
    }) exitWith {false};
    private _until=serverTime+_duration;
    if (!([_group,"VEHICLE_POINT",true,_until] call CBE_fnc_CortexOwnershipLease)) exitWith {false};
    private _operation=[_group,"VEHICLE_POINT",+_goal,_seats arrayIntersect _seats,[],"MOVING"] call CBE_fnc_OperationStart;
    if (count _operation == 0) exitWith {[_group,"VEHICLE_POINT",false] call CBE_fnc_CortexOwnershipLease;false};
    _operation set ["pointUntil",_until];_operation set ["pointVehicle",_vehicle];
    _group setVariable ["CBE_Operation",_operation,true];
    private _generation=_operation get "generation";
    private _started=[_group,_vehicle,+_goal,_seats,_generation,_until,[],[],"VEHICLE_POINT"] call CBE_fnc_VehicleTacticalMoveStart;
    if (!_started) then {
        [_group,"VEHICLE_POINT",false] call CBE_fnc_CortexOwnershipLease;
        [_group,_generation,"INCOMPLETE","POINT_ADMISSION_REFUSED"] call CBE_fnc_OperationRelease;
    };
    _started
};
};
_accepted
