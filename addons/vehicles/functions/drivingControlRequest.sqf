/*
 * Author: WaldoTheWarfighter
 * Purpose: Validates a targeted driving operator request and dispatches an ordered snapshot.
 * Locality / Authority: Server authenticates curator sender and owns settings/revisions; executor runs on current group owner.
 * Repeat/JIP: Revisioned group exclusion state is public; command effects are owner-local.
 * No JIP command replay. Repeated and stale acknowledgements cannot replace newer requests.
 * Arguments: 0 target <OBJECT, objNull>; 1 settings <ARRAY, []> - named operation ENABLE/RELEASE/INSPECT.
 * Return Value: BOOL - request dispatch, not physical success.
 * Current callers: ModuleDriving and ZenDrivingModule.
 * Example: [truck1,[["operation","INSPECT"]]] call WAIT_fnc_DrivingControlRequest;
 */
params [["_target",objNull,[objNull]],["_settings",[],[[]]]];
if (!isServer) exitWith {_this remoteExecCall ["WAIT_fnc_DrivingControlRequest",2];true};
private _sender=if (remoteExecutedOwner > 0) then {remoteExecutedOwner} else {2};
if (_sender != 2 && {(allCurators findIf {
    private _unit=getAssignedCuratorUnit _x;
    !isNull _unit && {isPlayer _unit} && {owner _unit == _sender}
}) < 0}) exitWith {false};
private _fail={params ["_reason"];["DRIVING",_reason,"ERROR"] remoteExecCall ["WAIT_fnc_AITweaksNotifyLocal",_sender];false};
if (_settings findIf {!(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}} >= 0) exitWith {["Invalid driving request payload."] call _fail};
private _payload=createHashMapFromArray _settings;
private _operation=_payload getOrDefault ["operation",""];
if !(_operation isEqualType "") exitWith {["Invalid driving operation type."] call _fail};
_operation=toUpperANSI _operation;
if (!(_operation in ["ENABLE","RELEASE","INSPECT"])) exitWith {["Invalid driving operation."] call _fail};
if (isNull _target || {!(_target isKindOf "LandVehicle")} || {_target isKindOf "StaticWeapon"}
    || {isNull driver _target} || {!alive driver _target} || {isPlayer driver _target}) exitWith {
    ["Select a crewed AI land vehicle; no nearby target is guessed."] call _fail
};
private _group=group driver _target;
private _disabled=+(_group getVariable ["WAIT_AIPass_DisabledFeatures",[]]);
private _feature="WAIT_AIPass_DrivingAssist_Enable";
if (_operation == "ENABLE") then {_disabled=_disabled-[_feature]};
if (_operation == "RELEASE") then {_disabled pushBackUnique _feature};
if (_operation != "INSPECT") then {_group setVariable ["WAIT_AIPass_DisabledFeatures",_disabled,true]};
private _revision=(_group getVariable ["WAIT_Driving_ControlRevision",0])+1;
_group setVariable ["WAIT_Driving_ControlRevision",_revision,true];
private _owner=groupOwner _group;
_group setVariable ["WAIT_Driving_ControlPending",[_revision,_sender,_owner,_operation,time]];
[_target,_group,_revision,_operation,_disabled] remoteExecCall ["WAIT_fnc_DrivingControlLocal",_owner];
// One finite acknowledgement timeout; it never repeats a stale command on a successor owner.
[{
    params ["_group","_revision","_sender"];
    if (!isNull _group && {((_group getVariable ["WAIT_Driving_ControlPending",[]]) param [0,-1]) == _revision}) then {
        _group setVariable ["WAIT_Driving_ControlPending",nil];
        ["DRIVING","Owner acknowledgement timed out. Inspect the current owner before retrying.","WARNING"] remoteExecCall ["WAIT_fnc_AITweaksNotifyLocal",_sender];
    };
},[_group,_revision,_sender],10] call CBA_fnc_waitAndExecute;
true
