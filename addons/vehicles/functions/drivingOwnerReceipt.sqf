/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads the current driving owner/epoch/generation identity without borrowing
 * this observer's private epoch for a remote group.
 * Locality/authority: Read-only anywhere. Local groups use actual private counters;
 * remote groups require the existing owner-stamped public driving status. This is
 * observation only, never FSM liveness, owner consent, movement or restoration authority.
 * Repeat/JIP: No state/cache/handler/replay. Missing, old-schema or mismatched-owner status
 * returns[] until the actual owner publishes. Private owner epochs are never overwritten.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return: ARRAY [owner NUMBER, epoch NUMBER, generation NUMBER], or[] unavailable.
 * Current callers: DrivingPassContext and DrivingQueueContext.
 * Cost: Constant metadata reads only; status reuses the existing sparse publication.
 * Example: private _identity=[group driver truck1] call CBE_fnc_DrivingOwnerReceipt;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {[]};
private _owner=groupOwner _group;
private _epoch=-1;private _generation=-1;
if (local _group) then {
    _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    _generation=_group getVariable ["CBE_Driving_Generation",-1];
} else {
    private _status=_group getVariable ["CBE_Driving_State",[]];
    if (_status isEqualType [] && {count _status == 6}
        && {(_status select 4) isEqualTo _owner}) then {
        _epoch=_status select 5;_generation=_status select 1;
    };
};
if (!(_epoch isEqualType 0) || {!finite _epoch} || {_epoch < 0}
    || {!(_generation isEqualType 0)} || {!finite _generation} || {_generation < 0}) exitWith {[]};
[_owner,_epoch,_generation]
