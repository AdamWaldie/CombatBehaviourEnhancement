/*
 * Author: WaldoTheWarfighter
 * Purpose: Validate gate route metadata without reading nonlocal native destinations.
 * Locality/authority: Read only. On the owner, require the exact current route receipt.
 * Server remote validation binds native receipt shape, goal and current operating owners;
 * an authenticated fresh owner witness remains mandatory before any gate animation.
 * Repeat/JIP: Stateless, no replay, cache or controller. Metadata is not movement authority.
 * Arguments: 0 group GROUP grpNull; 1 vehicle OBJECT objNull; 2 route ARRAY [].
 * Return: BOOL metadata matches current route/operating identity, never native intent permission.
 * Current callers: DrivingGateOpenServer and DrivingGateCloseServer.
 * Example: private _same=[group driver truck1,truck1,_route] call CBE_fnc_DrivingGateRouteMatches;
 */
params [["_gateRouteGroup",grpNull,[grpNull]],["_gateRouteVehicle",objNull,[objNull]],
    ["_gateRoute",[],[[]]]];
if (isNull _gateRouteGroup || {isNull _gateRouteVehicle} || {_gateRoute isEqualTo []}) exitWith {false};
if ((_gateRoute param [0,"",[""]]) != "NATIVE_MOVE") exitWith {
    ([_gateRouteGroup] call CBE_fnc_DrivingRouteReceipt) isEqualTo _gateRoute
};
if (count _gateRoute != 9 || {count waypoints _gateRouteGroup > 1}
    || {(_gateRoute select 1) isNotEqualTo _gateRouteGroup}
    || {(_gateRoute select 2) isNotEqualTo _gateRouteVehicle}
    || {vehicle leader _gateRouteGroup != _gateRouteVehicle}) exitWith {false};
private _gateRouteDriver=driver _gateRouteVehicle;
private _gateRouteCommander=effectiveCommander _gateRouteVehicle;
if (isNull _gateRouteCommander) then {_gateRouteCommander=_gateRouteDriver};
if (isNull _gateRouteDriver || {isNull _gateRouteCommander}
    || {(_gateRoute select 3) isNotEqualTo _gateRouteDriver}
    || {(_gateRoute select 4) isNotEqualTo _gateRouteCommander}
    || {group _gateRouteDriver != _gateRouteGroup} || {group _gateRouteCommander != _gateRouteGroup}
    || {[7,8] findIf {!((_gateRoute select _x) isEqualType 0) || {!finite (_gateRoute select _x)}
        || {(_gateRoute select _x) < 0} || {(_gateRoute select _x) != floor (_gateRoute select _x)}} >= 0}) exitWith {false};
private _gateRouteOwner=_gateRoute select 8;
if (_gateRouteOwner <= 0 || {_gateRouteOwner != groupOwner _gateRouteGroup}
    || {_gateRouteOwner != owner _gateRouteVehicle} || {_gateRouteOwner != owner _gateRouteDriver}
    || {_gateRouteOwner != owner _gateRouteCommander}) exitWith {false};
private _gateRouteVector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
if !((_gateRoute select 6) call _gateRouteVector) exitWith {false};
private _gateRouteFrame=_gateRoute select 5;
if (!(_gateRouteFrame isEqualType []) || {count _gateRouteFrame != 4}
    || {[0,2] findIf {!((_gateRouteFrame select _x) isEqualType "")} >= 0}) exitWith {false};
if ([1,3] findIf {
    private _gateRouteDestination=_gateRouteFrame select _x;
    !(_gateRouteDestination isEqualType []) || {count _gateRouteDestination != 3}
        || {!((_gateRouteDestination select 0) call _gateRouteVector)}
        || {!((_gateRouteDestination select 1) isEqualType "")}
        || {!((_gateRouteDestination select 2) isEqualType true)}
} >= 0) exitWith {false};
if (local _gateRouteGroup && {local _gateRouteVehicle} && {local _gateRouteDriver} && {local _gateRouteCommander}) exitWith {
    ([_gateRouteGroup] call CBE_fnc_DrivingRouteReceipt) isEqualTo _gateRoute
};
isServer
