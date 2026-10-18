/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases the standalone CBE driving safety speed cap and restores the exact pre-CBE
 * forced-speed value only while that cap remains owned by CBE; a newer controller cap is preserved.
 * Matching pass consent retires its exact broker token before ordinary cap cleanup.
 * Matching corridor work retires through its exact command/route handback before cap cleanup.
 * Locality / Authority: Runs only where the vehicle is local; does not alter waypoints, route
 * selection, collision, damage, fuel, simulation or any external driving controller.
 * Repeat/JIP: Safe when called repeatedly or after ownership changes; only a locally stored CBE
 * restore record can be applied. Player, remote-controlled or specialist effective commanders
 * preserve their newer cap even when an ordinary AI driver belongs to another group.
 * A newer finite CBE movement lease also prevents restoration over its tactical speed policy.
 * Exact deferred reverse handback retains its original cap/restoration receipt rather than
 * restoring speed while the rear command is still owned. No deadline or observer is renewed.
 * Arguments:
 * 0: vehicle <OBJECT> - ground vehicle to release.
 * 1: expected group <GROUP, grpNull> - group-scoped cleanup; grpNull permits subsystem shutdown.
 * Return Value: Nothing.
 * Current callers: CBE_fnc_DrivingAssistStart and CBE_fnc_CortexStop.
 * Example: [truck1] call CBE_fnc_DrivingAssistRelease;
 */

params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]]];
if (isNull _vehicle || {!local _vehicle}) exitWith {};
["CANCEL",_expectedGroup,_vehicle] call CBE_fnc_DrivingPassAdmission;
[_vehicle,_expectedGroup] call CBE_fnc_DrivingPassRetireInherited;
private _pass=_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap];
if (count _pass > 0 && {isNull _expectedGroup || {(_pass get "group") == _expectedGroup}}) then {
    [_vehicle,_pass get "group","DRIVING_RELEASED",true] call CBE_fnc_DrivingPassFinish;
};
[_vehicle,_expectedGroup] call CBE_fnc_DrivingPassAgreementRelease;
private _recoveryPending=false;
private _recovery=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
if (count _recovery > 0 && {isNull _expectedGroup || {(_recovery get "group") == _expectedGroup}}) then {
    if ((_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isEqualTo []
        && {abs ((getForcedSpeed _vehicle)-(_recovery get "cap")) <= 0.1}) then {
        _vehicle setVariable ["CBE_DrivingAssist_State",[_recovery get "cap",0,time,_recovery get "group"]];
        _vehicle setVariable ["CBE_DrivingAssist_Restore",+(_recovery get "baseline")];
    };
    private _retired=[_vehicle,_recovery get "group","DRIVING_RELEASED"] call CBE_fnc_DrivingRecoveryRelease;
    _recoveryPending=!_retired && {_recovery getOrDefault ["releasePending",false]}
        && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _recovery};
};
// A failed exact handback is not a completed cap release. Retain the same baseline,
// owned cap and work proof for the existing retry path; never recreate a rear leg.
if (_recoveryPending) exitWith {};
[_vehicle,_expectedGroup,["ORDINARY"],true] call CBE_fnc_DrivingNativePathWatch;
private _corridor=_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap];
private _corridorGroup=_corridor getOrDefault ["group",grpNull];
if (!isNull _corridorGroup && {isNull _expectedGroup || {_expectedGroup == _corridorGroup}}
    && {((_corridor getOrDefault ["controller",["ORDINARY",-1]]) param [0,""]) == "ORDINARY"}) then {
    [_vehicle,_corridorGroup,"DRIVING_RELEASED"] call CBE_fnc_DrivingCorridorRelease;
};
private _bypass=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
private _bypassGroup=_bypass getOrDefault ["group",grpNull];
if (!isNull _bypassGroup && {isNull _expectedGroup || {_expectedGroup == _bypassGroup}}
    && {((_bypass getOrDefault ["controller",["ORDINARY",-1]]) param [0,""]) == "ORDINARY"}) then {
    [_vehicle,_bypassGroup,"DRIVING_RELEASED"] call CBE_fnc_DrivingBypassRelease;
};
private _restore=_vehicle getVariable ["CBE_DrivingAssist_Restore",[]];
private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
if (!isNull _expectedGroup && {(_state param [3,grpNull]) != _expectedGroup}) exitWith {};
private _ownedCap=_state param [0,-1];
private _ownerGroup=_state param [3,grpNull];
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
private _commanderTaken=!isNull _commander && {
    isPlayer _commander || {!isNull remoteControlled _commander}
        || {!isNull (_commander getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_commander] call CBE_fnc_CortexExternalOwner != ""}
        || {[_commander] call CBE_fnc_CompatibilityExternalControl}
};
private _externalControl=(!isNull _ownerGroup && {[_ownerGroup] call CBE_fnc_CortexExternalTakeover})
    || {!isNull _driver && {isPlayer _driver || {!isNull remoteControlled _driver}
        || {[_driver] call CBE_fnc_CortexExternalOwner != ""}}}
    || {_commanderTaken}
    || {!isNull _ownerGroup && {!([_ownerGroup] call CBE_fnc_DrivingMovementAvailable)}}
    || {_vehicle getVariable ["CBE_Convoy_Active",false]};
// Restore only the cap that this driving lease still owns. If another controller changed it,
// clear our state and leave that newer value untouched.
if (_restore isNotEqualTo [] && {_ownedCap >= 0}
    && {!_externalControl}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1}) then {
    _vehicle forceSpeed (_restore param [0,-1]);
};
_vehicle setVariable ["CBE_DrivingAssist_Restore",nil];
_vehicle setVariable ["CBE_DrivingAssist_Next",nil];
_vehicle setVariable ["CBE_DrivingTrafficSeen",nil];
_vehicle setVariable ["CBE_DrivingSolidSeen",nil];
_vehicle setVariable ["CBE_DrivingAssist_State",nil];
_vehicle setVariable ["CBE_DrivingAssist_Traffic",nil];

_vehicle setVariable ["CBE_DrivingAssist_Obstacle",nil];
