/*
 * Author: WaldoTheWarfighter
 * Purpose: Remembers retired queue tokens so deferred server messages cannot readmit them.
 * Locality/authority: Machine-private metadata; local calls or authenticated server callbacks only.
 * Repeat/JIP: At most64 live tokens, matching the broker admission bound. Original expiry only;
 * closures never extend, unknown/full journals refuse admission. No worker or JIP command.
 * Arguments: 0 token STRING default empty;1 original expiry NUMBER default -1 (query only).
 * Return: BOOL token closed or journal unknown/full; false means no remembered live closure.
 * Current callers: DrivingQueueAgreementOwner, DrivingQueueAgreementRelease, DrivingQueueAgreementRequest.
 * Example: private _closed = [_token] call CBE_fnc_DrivingQueueTokenClosed;
 */
params [["_token","",[""]],["_closeUntil",-1,[0]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {true};
if (_token == "" || {count _token > 256} || {!finite _closeUntil}) exitWith {true};
private _closed=localNamespace getVariable ["CBE_DrivingQueue_Closed",createHashMap];
if (!(_closed isEqualType createHashMap) || {count _closed > 64}) exitWith {true};
private _unknown=false;
private _live=0;
{
    private _until=_closed get _x;
    if (!(_x isEqualType "") || {!(_until isEqualType 0)} || {!finite _until}) exitWith {_unknown=true};
    if (serverTime < _until) then {_live=_live+1};
} forEach keys _closed;
if (_unknown) exitWith {true};
if (_closeUntil >= 0 && {_closeUntil > serverTime}) then {
    // Only retirement prunes. Queries cannot mutate or renew the journal.
    if (_closeUntil <= serverTime+90) then {
        {if (serverTime >= (_closed get _x)) then {_closed deleteAt _x}} forEach keys _closed;
        if (_token in _closed) then {
            _closed set [_token,(_closed get _token) min _closeUntil];
        } else {
            if (count _closed < 64) then {_closed set [_token,_closeUntil]};
        };
        localNamespace setVariable ["CBE_DrivingQueue_Closed",_closed];
    };
};
(serverTime < (_closed getOrDefault [_token,-1])) || {_live >= 64}
