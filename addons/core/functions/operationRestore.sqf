/*
 * Author: WaldoTheWarfighter
 * Purpose: Restore exact-owned operation settings without changing movement, targets or formation.
 * Locality/authority: Current group owner; matching operation generation and owner epoch only.
 * Exact operation proof, bounded roster checks, lease consumption and permission write are atomic.
 * At most64 members; no geometry, path planning, wait or recurring observer in the commit.
 * Repeat/JIP: Consumes matching proof only after confirmed restore or explicit supersession.
 * One unconfirmed native write retains a separate unresolved receipt after operation retirement;
 * no automatic retry can fight a mission controller. Migration cleanup does not restore old-owner
 * settings; resumable feature orders retain their original baseline for the destination owner.
 * Player, specialist and declared actor ownership block restoration; unchanged native permission can hand back to Zeus.
 * Arguments: 0 group <GROUP>, grpNull; 1 operation <HASHMAP>, empty; 2 reason <STRING>, RELEASE.
 * Return: Boolean - true when an unchanged owned setting was restored.
 * Current callers: CBE_fnc_OperationCancel and CBE_fnc_OperationRelease.
 * Example: [group player,group player getVariable ["CBE_Operation",createHashMap],"COMPLETE"] call CBE_fnc_OperationRestore;
 */
params [["_group",grpNull,[grpNull]],["_operation",createHashMap,[createHashMap]],["_reason","RELEASE",[""]]];
if (isNull _group || {!local _group} || {count _operation == 0}
    || {toUpperANSI _reason == "OWNERSHIP_LOST"}) exitWith {false};
private _restored=false;
isNil {
_restored=call {
if (isNull _group || {!local _group}) exitWith {false};
private _current=_group getVariable ["CBE_Operation",createHashMap];
if (_current isNotEqualTo _operation
    || {(_current getOrDefault ["generation",-1]) != (_operation getOrDefault ["generation",-2])}
    || {(_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
private _creepPolicy=["RELEASE",_group,_operation] call CBE_fnc_CreepPolicy;
private _restore=_operation getOrDefault ["restore",createHashMap];
private _attack=_restore getOrDefault ["groupAttack",[]];
if (count _attack != 2 || {!((_attack select 0) isEqualType true)} || {!((_attack select 1) isEqualType true)}) exitWith {_creepPolicy == "RELEASED"};
private _report={
    params ["_restored","_decision"];
    if (_decision != "RESTORE_UNCONFIRMED") then {_restore deleteAt "groupAttack"};
    _group setVariable ["CBE_OperationRestoreResult",[
        _operation get "generation",toUpperANSI _reason,_decision,serverTime,
        +_attack,attackEnabled _group,_restored],true];
    _restored
};
private _members=units _group;
if (count _members > 64 || {[_group] call CBE_fnc_CompatibilityExternalControl}
    || {_members findIf {isPlayer _x || {!isNull remoteControlled _x}
        || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {([_x] call CBE_fnc_CortexExternalOwner) != ""} || {[_x] call CBE_fnc_CompatibilityExternalControl}} >= 0}) exitWith {[false,"EXTERNAL_OWNER"] call _report};
private _anchor=leader _group;
if (isNull _anchor) exitWith {[false,"NO_LEADER"] call _report};
if (attackEnabled _anchor != (_attack select 1)) exitWith {[false,"POLICY_CHANGED"] call _report};
if ((_attack select 0) == (_attack select 1)) exitWith {[false,"UNCHANGED_BASELINE"] call _report};
// A later different setting belongs to its new owner. Restoring this unchanged boolean does
// not issue an attack or alter a Zeus waypoint, target, posture or movement command.
if ((_group getVariable ["CBE_OperationAttack_Unresolved",[]]) isNotEqualTo []) exitWith {
    [false,"RESTORE_UNCONFIRMED"] call _report
};
_group enableAttack (_attack select 0);
if (attackEnabled _anchor != (_attack select 0)) exitWith {
    // Keep one bounded metadata receipt after the operation record is retired. Never
    // retry a permission a mission controller may have just refused or overwritten.
    _group setVariable ["CBE_OperationAttack_Unresolved",[
        _operation get "generation",_operation get "ownerEpoch",_attack select 0,_attack select 1,clientOwner,serverTime],true];
    [false,"RESTORE_UNCONFIRMED"] call _report
};
private _unresolved=_group getVariable ["CBE_OperationAttack_Unresolved",[]];
if (_unresolved isEqualType [] && {count _unresolved == 6}
    && {(_unresolved select 0) isEqualTo (_operation get "generation")}
    && {(_unresolved select 1) isEqualTo (_operation get "ownerEpoch")}
    && {(_unresolved select 2) isEqualTo (_attack select 0)}
    && {(_unresolved select 3) isEqualTo (_attack select 1)}
    && {(_unresolved select 4) isEqualTo clientOwner}) then {
    _group setVariable ["CBE_OperationAttack_Unresolved",nil,true];
};
[true,"RESTORED"] call _report
};
};
_restored
