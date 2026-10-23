/*
 * Author: WaldoTheWarfighter
 * Purpose: Remembers retired pass tokens so deferred server messages cannot readmit them.
 * Locality/authority: Machine-private metadata; local calls or authenticated server callbacks only.
 * Repeat/JIP: At most64 live tokens, twice the broker pair bound. Original expiry only;
 * Closures never extend. Overflow refuses admission through the unrecorded token expiry,
 * even if an earlier recorded token expires first. Unknown journals refuse. No worker or JIP command.
 * Arguments: 0 token STRING default empty;1 original expiry NUMBER default -1 (query only).
 * Return: BOOL token closed or journal unknown/full; false means no remembered live closure.
 * Current callers: DrivingPassAgreementOwner and DrivingPassAgreementRelease.
 * Example: private _closed = [_token] call CBE_fnc_DrivingPassTokenClosed;
 */
params [["_token","",[""]],["_closeUntil",-1,[0]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {true};
if (_token == "" || {count _token > 256} || {!finite _closeUntil}) exitWith {true};
private _closed=localNamespace getVariable ["CBE_DrivingPass_Closed",createHashMap];
if (!(_closed isEqualType createHashMap) || {count _closed > 64}) exitWith {true};
private _blockedUntil=localNamespace getVariable ["CBE_DrivingPass_ClosedOverflowUntil",-1];
if (!(_blockedUntil isEqualType 0) || {!finite _blockedUntil}) exitWith {true};
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
    if (_closeUntil <= serverTime+50) then {
        {if (serverTime >= (_closed get _x)) then {_closed deleteAt _x}} forEach keys _closed;
        if (_token in _closed) then {
            _closed set [_token,(_closed get _token) min _closeUntil];
        } else {
            if (count _closed < 64) then {_closed set [_token,_closeUntil]} else {
                // Retain refusal even when earlier journal entries expire before this token.
                _blockedUntil=_blockedUntil max _closeUntil;
                localNamespace setVariable ["CBE_DrivingPass_ClosedOverflowUntil",_blockedUntil];
            };
        };
        localNamespace setVariable ["CBE_DrivingPass_Closed",_closed];
    };
};
(serverTime < (_closed getOrDefault [_token,-1])) || {_live >= 64} || {serverTime < _blockedUntil}
