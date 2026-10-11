/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases the standalone WAIT driving safety speed cap and restores the exact pre-WAIT
 * forced-speed value only while that cap remains owned by WAIT; a newer controller cap is preserved.
 * Locality / Authority: Runs only where the vehicle is local; does not alter waypoints, route
 * selection, collision, damage, fuel, simulation or any external driving controller.
 * Repeat/JIP: Safe when called repeatedly or after ownership changes; only a locally stored WAIT
 * restore record can be applied.
 * Arguments:
 * 0: vehicle <OBJECT> - ground vehicle to release.
 * 1: expected group <GROUP, grpNull> - group-scoped cleanup; grpNull permits subsystem shutdown.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_DrivingAssistStart and WAIT_fnc_CortexStop.
 * Example: [truck1] call WAIT_fnc_DrivingAssistRelease;
 */

params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]]];
if (isNull _vehicle || {!local _vehicle}) exitWith {};
private _restore=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
private _state=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
if (!isNull _expectedGroup && {(_state param [3,grpNull]) != _expectedGroup}) exitWith {};
private _ownedCap=_state param [0,-1];
private _ownerGroup=_state param [3,grpNull];
private _driver=driver _vehicle;
private _externalControl=(!isNull _ownerGroup && {[_ownerGroup] call WAIT_fnc_CortexExternalTakeover})
    || {!isNull _driver && {isPlayer _driver || {!isNull remoteControlled _driver}
        || {[_driver] call WAIT_fnc_CortexExternalOwner != ""}}}
    || {_vehicle getVariable ["WAIT_Convoy_Active",false]};
// Restore only the cap that this driving lease still owns. If another controller changed it,
// clear our state and leave that newer value untouched.
if (_restore isNotEqualTo [] && {_ownedCap >= 0}
    && {!_externalControl}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
    && {abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1}) then {
    _vehicle forceSpeed (_restore param [0,-1]);
};
_vehicle setVariable ["WAIT_DrivingAssist_Restore",nil];
_vehicle setVariable ["WAIT_DrivingAssist_Next",nil];
_vehicle setVariable ["WAIT_DrivingAssist_State",nil];
