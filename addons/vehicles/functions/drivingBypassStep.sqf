/*
 * Author: WaldoTheWarfighter
 * Purpose: Runs one finite ordinary-lead bypass PLAN/FOLLOW step through the existing controller.
 * Locality / Authority: Internal synchronous owner callback only. Current driving brain and the
 * caller's fresh plain-route authority predicate protect every movement command. Never remote.
 * Repeat/JIP: Public serializable work stores original 90-second deadline, two-side attempt budget,
 * path/checkpoint/seat/route receipts. New owners adopt without command replay or clock renewal.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 brain <HASHMAP, empty>;
 * 3 fresh solid observation <ARRAY, []>; 4 authority predicate <CODE, {false}>, local only.
 * Return Value: ARRAY [active BOOL, capMps NUMBER, phase STRING, sourceConstraintMayYield BOOL].
 * Bounds: one side proposal per callback (max two); FOLLOW validates one actual next segment
 * (at most 15 rays) and advances at most four physical checkpoints per callback. No new scheduler.
 * Full ordered checkpoint visit and actual tail clearance alone complete. Invalid geometry,
 * command/owner changes and deadline expiry retain failure; no elapsed-time or ready success.
 * Current callers: DrivingAssistStart. Registered convoys retain their current writer; bypass
 * integration for those follows separately. Neither path acceptance nor this API is physical QA.
 * Example: [_group,_vehicle,_brain,_solid,_mayRecoverRoute] call WAIT_fnc_DrivingBypassStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_brain",createHashMap,[createHashMap]],
    ["_observed",[],[[]]],["_authority",{false},[{}]]];
private _inactive=[false,1e6,"",false];
if (isRemoteExecuted) exitWith {_inactive};
private _route=[_group] call WAIT_fnc_DrivingRouteReceipt;
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
private _seatsAvailable={
    [_driver,_operator] findIf {
        isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _vehicle}
            || {!([_x] call WAIT_fnc_CortexCombatEffective)} || {isPlayer _x}
            || {!isNull remoteControlled _x} || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
    } < 0
};
private _mayWrite={
    !isNull _group && {local _group} && {!isNull _vehicle} && {local _vehicle}
        && {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isEqualTo _brain}
        && {!(_brain getOrDefault ["cancelled",false])}
        && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {_route isNotEqualTo []} && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {call _authority} && {call _seatsAvailable} && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
        && {[_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {isAISteeringComponentEnabled _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {isNil {_vehicle getVariable "WAIT_DrivingCorridor_Work"}}
};
private _work=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
if (!(call _mayWrite)) exitWith {
    [_vehicle,_group,"AUTHORITY_ENDED"] call WAIT_fnc_DrivingBypassRelease;_inactive
};
if (count _work > 0 && {(_work get "group") != _group}) then {
    _vehicle setVariable ["WAIT_DrivingBypass_Work",nil,true];_work=createHashMap;
};
if (count _work == 0) then {
    if (count _observed == 9 && {(_observed select 5) == "STATIC"} && {!isNull (_observed select 1)}
        && {abs speed _vehicle <= 8}) then {
        private _context=[_group,_route,_observed select 1,_driver,_operator];
        private _cooldown=_vehicle getVariable ["WAIT_DrivingBypass_Cooldown",[]];
        private _waypoint=[_group,currentWaypoint _group];
        private _command=expectedDestination _operator;
        if (_cooldown findIf {(_x select 0) isEqualTo _context && {(_x select 1) > serverTime}} < 0
            && {currentCommand _operator != "MOVE" || {(_command param [0,[]]) distance2D waypointPosition _waypoint <= 3}}) then {
            _work=createHashMapFromArray [["group",_group],["route",_route],["driver",_driver],["operator",_operator],
                ["context",_context],["obstacle",_observed select 1],["transform",_observed select 8],
                ["deadline",serverTime+90],["side",1],["phase","PLAN"],["index",0],
                ["command",+_command],["driverCommand",+(expectedDestination _driver)]];
            _vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true];
        };
    };
};
if (count _work == 0) exitWith {_inactive};
private _obstacle=_work get "obstacle";private _reason="";
if ((_work get "route") isNotEqualTo _route || {(_work get "driver") != _driver} || {(_work get "operator") != _operator}
    || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
    || {(expectedDestination _driver) isNotEqualTo (_work get "driverCommand")}) then {_reason="COMMAND_CHANGED"};
if (_reason == "" && {isNull _obstacle || {abs speed _obstacle > 0.5}
    || {[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle] isNotEqualTo (_work get "transform")}}) then {_reason="OBSTACLE_CHANGED"};
if (_reason == "" && {serverTime >= (_work get "deadline")}) then {_reason="TIMEOUT"};
if (_reason != "") exitWith {[_vehicle,_group,_reason,_reason != "COMMAND_CHANGED"] call WAIT_fnc_DrivingBypassRelease;_inactive};
if ((_work get "phase") == "PLAN") exitWith {
    if (count _observed != 9 || {(_observed select 1) != _obstacle} || {(_observed select 8) isNotEqualTo (_work get "transform")}) exitWith {
        [_vehicle,_group,"OBSERVATION_CHANGED"] call WAIT_fnc_DrivingBypassRelease;_inactive
    };
    private _proposal=[_vehicle,_observed,_work get "side"] call WAIT_fnc_DrivingBypassPlan;
    if (!(_proposal select 0)) exitWith {
        if ((_work get "side") == 1) then {
            _work set ["side",-1];_vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true];
            [true,8/3.6,"BYPASS_PLAN",false]
        } else {[_vehicle,_group,_proposal select 1] call WAIT_fnc_DrivingBypassRelease;_inactive}
    };
    private _points=_proposal select 2;private _asl=_proposal select 3;
    private _destination=ATLToASL waypointPosition [_group,currentWaypoint _group];
    private _forward=vectorDir _vehicle;_forward set [2,0];_forward=vectorNormalized _forward;
    private _exit=_asl select ((count _asl)-1);
    if ((_destination vectorDiff _exit) vectorDotProduct _forward < 0) exitWith {
        [_vehicle,_group,"DESTINATION_CLEARANCE"] call WAIT_fnc_DrivingBypassRelease;_inactive
    };
    if (!(call _mayWrite) || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
        || {(expectedDestination _driver) isNotEqualTo (_work get "driverCommand")}) exitWith {_inactive};
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;
    private _halfWidth=(abs (_low select 0)) max (abs (_high select 0));
    private _halfLength=(abs (_low select 1)) max (abs (_high select 1));
    private _radius=sqrt ((_halfWidth^2)+(_halfLength^2))+1;
    if (_operator != _driver) then {doStop _operator};doStop _driver;
    _vehicle setDriveOnPath _points;
    _work set ["phase","FOLLOW"];_work set ["points",_asl];_work set ["index",1];
    _work set ["radius",_radius];_work set ["height",(_high select 2)-(_low select 2)];
    _work set ["forward",_forward];_work set ["far",_exit vectorDiff (_forward vectorMultiply (_radius+10))];
    _work set ["command",+(expectedDestination _operator)];_work set ["driverCommand",+(expectedDestination _driver)];
    _vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true];
    [true,8/3.6,"BYPASS_FOLLOW",false]
};
private _points=_work get "points";private _index=_work get "index";private _origin=getPosASL _vehicle;
for "_i" from 1 to 4 do {
    if (_index < count _points && {_origin distance2D (_points select _index) <= 2.5}
        && {abs ((_origin select 2)-((_points select _index) select 2)) <= 2}) then {_index=_index+1};
};
if (_index != (_work get "index")) then {_work set ["index",_index];_vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true]};
if (_index >= count _points) exitWith {
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;private _clear=true;
    {private _xCoord=_x;{private _yCoord=_x;{
        private _corner=_vehicle modelToWorldWorld [_xCoord,_yCoord,_x];
        if ((_corner vectorDiff (_work get "far")) vectorDotProduct (_work get "forward") < 5) then {_clear=false};
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    if (_clear) then {[_vehicle,_group,"PHYSICALLY_PASSED"] call WAIT_fnc_DrivingBypassRelease;_inactive}
    else {[true,8/3.6,"BYPASS_FOLLOW",false]}
};
private _next=_points select _index;
private _health=[_vehicle,[_origin,_next],_work get "radius",_work get "height"] call WAIT_fnc_DrivingPathGeometry;
if (!(_health select 0)) exitWith {[_vehicle,_group,"LEG_"+(_health select 1)] call WAIT_fnc_DrivingBypassRelease;_inactive};
[true,8/3.6,"BYPASS_FOLLOW",true]
