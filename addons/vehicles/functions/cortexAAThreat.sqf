/*
 * Author: WaldoTheWarfighter
 * Purpose: Retain authenticated launch affiliation on an exact incoming projectile.
 * Locality/authority: Machine-local receipt; only the native warning observer records it.
 * VALID is read-only and grants neither fire nor projectile-effect authority. Native parent
 * changes invalidate it; loss of a parent after capture does not erase launch affiliation.
 * Repeat/JIP: One immutable receipt/projectile/machine, original15s expiry, no publication,
 * timer, scan or JIP replay. A duplicate warning never renews or replaces the receipt.
 * Arguments: 0 missile OBJECT,objNull; 1 defending group GROUP,grpNull;
 * 2 native launcher OBJECT,objNull; 3 mode STRING,VALID (RECORD from IncomingMissile).
 * Return: BOOL, exact unexpired hostile launch provenance, not interception permission.
 * Current callers: CortexAAObserve, CortexAAAllocate, CortexAAIntercept and its effect.
 * Example: private _hostile=[_missile,_group,_source] call CBE_fnc_CortexAAThreat;
 */
params [["_missile",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_source",objNull,[objNull]],["_mode","VALID",[""]]];
if (isNull _missile || {!alive _missile} || {isNull _group} || {!local _group}
    || {remoteExecutedOwner > 0} || {!(_mode in ["RECORD","VALID"])}) exitWith {false};
private _launch=_missile getVariable ["CBE_AA_LaunchProvenance",[]];
if (_mode == "RECORD" && {_launch isEqualTo []}) then {
    private _parents=getShotParents _missile;
    if (!canSuspend && {!isNull _source} && {(_parents param [0,objNull]) == _source}) then {
        _launch=[clientOwner,_missile,_source,side _source,+_parents,serverTime+15];
        _missile setVariable ["CBE_AA_LaunchProvenance",_launch];
    };
};
if (!(_launch isEqualType []) || {count _launch != 6}
    || {(_launch select 0) != clientOwner} || {(_launch select 1) != _missile}
    || {(_launch select 2) != _source}
    || {!((_launch select 3) isEqualType sideUnknown)}
    || {(_launch select 3) == sideUnknown}
    || {!((_launch select 4) isEqualType [])} || {count (_launch select 4) != 2}
    || {!((_launch select 5) isEqualType 0)} || {!finite (_launch select 5)}
    || {serverTime >= (_launch select 5)}
    || {(side _group) getFriend (_launch select 3) >= 0.6}) exitWith {false};
private _currentParents=getShotParents _missile;
if (count _currentParents != 2) exitWith {false};
// Null parents are only tolerated AFTER an exact native launch capture. A new
// non-null parent must still equal that captured parent; null equality cannot mint proof.
private _changed=false;
{
    if (!isNull _x && {_x != ((_launch select 4) select _forEachIndex)}) exitWith {_changed=true};
} forEach _currentParents;
!_changed
