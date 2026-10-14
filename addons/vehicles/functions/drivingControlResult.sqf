/*
 * Author: WaldoTheWarfighter
 * Purpose: Authenticates one expected owner acknowledgement and reports the result to the requester.
 * Locality / Authority: Server-only; acknowledgement must match the exact dispatched owner and latest pending revision.
 * Repeat/JIP: Revisioned group exclusion state is public; command effects are owner-local.
 * No JIP command replay. Repeated and stale acknowledgements cannot replace newer requests.
 * Arguments: 0 group <GROUP>; 1 revision <NUMBER>; 2 message <STRING>; 3 accepted <BOOL>.
 * Return Value: Nothing.
 * Current callers: DrivingControlLocal.
 * Example: [_group,1,"Released",true] call WAIT_fnc_DrivingControlResult;
 */
params [["_group",grpNull,[grpNull]],["_revision",-1,[0]],["_message","",[""]],["_accepted",false,[false]]];
if (!isServer || {isNull _group}) exitWith {};
private _pending=_group getVariable ["WAIT_Driving_ControlPending",[]];
if (count _pending != 5 || {(_pending select 0) != _revision}) exitWith {};
private _sender=if (remoteExecutedOwner > 0) then {remoteExecutedOwner} else {2};
if (_sender != (_pending select 2)) exitWith {};
_group setVariable ["WAIT_Driving_ControlPending",nil];
["DRIVING",_message,["WARNING","INFO"] select _accepted] remoteExecCall ["WAIT_fnc_AITweaksNotifyLocal",_pending select 1];
