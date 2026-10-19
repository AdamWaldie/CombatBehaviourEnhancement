/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases queue consent belonging to one retiring driving brain, without native commands.
 * Locality/authority: Current vehicle owner; local call or trusted server call. Both captured crew
 * receipts must belong to the supplied group, owner epoch and driving generation. The server
 * independently authenticates the exact-token release. No successor receipt is overwritten.
 * Repeat/JIP: Missing, malformed or replaced receipts do nothing. No handlers, timer renewal,
 * movement, speed restoration, peer state writes or JIP replay. Old expiry timers remain harmless.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 expected owner epoch <NUMBER, -1>; 3 expected driving generation <NUMBER, -1>.
 * Return: BOOL, exact local consent retired and server release requested; not queue execution.
 * Current callers: DrivingOperationFinish before its current-brain native cleanup guard.
 * Example: [truck1,_group,_brain get "ownerEpoch",_brain get "generation"] call CBE_fnc_DrivingQueueAgreementRelease;
 */
params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]],
    ["_expectedEpoch",-1,[0]],["_expectedGeneration",-1,[0]]];
if (isNull _vehicle || {!local _vehicle} || {isNull _expectedGroup}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {!finite _expectedEpoch} || {_expectedEpoch < 0}
    || {!finite _expectedGeneration} || {_expectedGeneration < 0}) exitWith {false};
private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
if (!(_consent isEqualType createHashMap) || {count _consent == 0}) exitWith {false};
private _token=_consent getOrDefault ["token",""];
private _context=_consent getOrDefault ["context",[]];
if (!(_token isEqualType "") || {_token == ""}
    || {!((_consent getOrDefault ["phase",""]) in ["PENDING","AGREED"])}
    || {!(_context isEqualType [])} || {count _context < 2} || {count _context > 4}) exitWith {false};
private _index=_context findIf {_x isEqualType [] && {count _x == 6} && {(_x select 0) isEqualTo _vehicle}};
if (_index < 0) exitWith {false};
private _row=_context select _index;
if ((_row select 1) != clientOwner) exitWith {false};
private _matches=true;
{
    private _actorReceipt=_row select _x;
    if (!(_actorReceipt isEqualType []) || {count _actorReceipt != 11}
        || {(_actorReceipt select 2) isNotEqualTo _expectedGroup}
        || {(_actorReceipt select 4) isNotEqualTo _expectedEpoch}
        || {(_actorReceipt select 5) isNotEqualTo _expectedGeneration}) exitWith {_matches=false};
} forEach [2,3];
if (!_matches) exitWith {false};
private _retired=false;
isNil {
    if (local _vehicle && {(_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isEqualTo _consent}) then {
        [_token,_consent getOrDefault ["expires",-1]] call CBE_fnc_DrivingQueueTokenClosed;
        _vehicle setVariable ["CBE_DrivingQueue_Consent",nil];
        _retired=true;
    };
};
if (!_retired) exitWith {false};
["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
true
