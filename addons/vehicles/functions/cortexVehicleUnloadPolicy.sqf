/*
 * Author: WaldoTheWarfighter
 * Initial acquisition defers for assigned incoming native GET IN or unknown remote intent;
 * at most64 returned seat rows are inspected before the first engine policy write. No boarding is issued.
 * Owns the engine unload-in-combat policy for one ordinary CBE-controlled ground vehicle.
 *
 * ACQUIRE prevents the engine from independently unloading cargo while CBE is responsible for
 * deliberate contact dismounts. The exact crew group, group epoch, previous value and applied value
 * are recorded on the vehicle. A later owner adopts the unchanged lease without reissuing the
 * command. If any other controller changes the value, CBE drops its lease and blocks reacquisition
 * for that group epoch instead of fighting the newer owner.
 * RELEASE restores the previous value only when requested, the vehicle is local, the lease still
 * belongs to the supplied group and the current value still exactly matches CBE's applied value.
 * Zeus, player and specialist handovers use release without restoration. Convoys retain their own
 * independent unload policy and are never acquired here.
 *
 * Locality and authority: call on the machine local to the vehicle. The effective commander's group
 * must be the supplied local group for ACQUIRE. Lease and tracked-vehicle records are public so a
 * replacement owner can adopt or release them after locality migration.
 * Repeat/JIP: Unchanged ACQUIRE publishes neither lease nor tracked roster. Adoption writes
 * only a changed epoch/owner; RELEASE changes the tracked roster only when membership changes. No loop or
 * scheduled work is created.
 *
 * Arguments:
 * 0: vehicle <OBJECT>, default objNull
 * 1: crew group <GROUP>, default grpNull
 * 2: action <STRING> - ACQUIRE or RELEASE, default ACQUIRE
 * 3: restore previous value <BOOL> - RELEASE only, default true
 *
 * Return Value:
 * Boolean - true when CBE owns or cleanly released the matching lease
 *
 * Current callers: CBE_fnc_CortexVehicles, CBE_fnc_CortexReleaseGroup and CBE_fnc_CortexStop.
 *
 * Example:
 * [_truck, group effectiveCommander _truck, "ACQUIRE"] call CBE_fnc_CortexVehicleUnloadPolicy;
 * Result: the engine keeps passengers aboard until CBE deliberately dismounts them or yields.
 */

params [
    ["_vehicle",objNull,[objNull]],
    ["_group",grpNull,[grpNull]],
    ["_action","ACQUIRE",[""]],
    ["_restore",true,[false]]
];
if (isNull _vehicle || {isNull _group} || {!local _vehicle}) exitWith {false};
_action=toUpperANSI _action;
private _lease=_vehicle getVariable ["CBE_Cortex_UnloadPolicyLease",[]];
private _removeTracked={
    private _previousTracked=_group getVariable ["CBE_Cortex_UnloadPolicyVehicles",[]];
    private _tracked=_previousTracked - [_vehicle];
    if (_tracked isNotEqualTo _previousTracked) then {
        if (_tracked isEqualTo []) then {
            _group setVariable ["CBE_Cortex_UnloadPolicyVehicles",nil,true];
        } else {
            _group setVariable ["CBE_Cortex_UnloadPolicyVehicles",_tracked,true];
        };
    };
};

if (_action == "RELEASE") exitWith {
    if (count _lease != 5 || {(_lease select 0) != _group}) exitWith {
        call _removeTracked;
        false
    };
    _lease params ["_leaseGroup","_leaseEpoch","_previous","_applied","_leaseOwner"];
    if (_restore && {getUnloadInCombat _vehicle isEqualTo _applied}) then {
        _vehicle setUnloadInCombat _previous;
    };
    _vehicle setVariable ["CBE_Cortex_UnloadPolicyLease",nil,true];
    _vehicle setVariable ["CBE_Cortex_UnloadPolicyBlocked",nil,true];
    call _removeTracked;
    true
};

if (_action != "ACQUIRE" || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!local _group} || {!((effectiveCommander _vehicle) in units _group)}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _blocked=_vehicle getVariable ["CBE_Cortex_UnloadPolicyBlocked",[]];
if (count _blocked == 2 && {(_blocked select 0) == _group} && {(_blocked select 1) == _epoch}) exitWith {false};

if (count _lease == 5 && {(_lease select 0) != _group}) exitWith {false};
if (count _lease == 5 && {getUnloadInCombat _vehicle isNotEqualTo (_lease select 3)}) exitWith {
    // A newer controller changed the engine policy. Preserve its value and do not reacquire
    // until this group's next ownership epoch.
    _vehicle setVariable ["CBE_Cortex_UnloadPolicyLease",nil,true];
    _vehicle setVariable ["CBE_Cortex_UnloadPolicyBlocked",[_group,_epoch],true];
    call _removeTracked;
    false
};
// First acquisition alone can change engine boarding state. Refusal must leave
// without publishing a lease, tracked membership or a success result.
private _incomingBoarding=false;
if (count _lease != 5) then {
    private _seats=fullCrew [_vehicle,"",true];
    _incomingBoarding=count _seats > 64 || {_seats findIf {
        private _incoming=_x param [5,objNull];
        !isNull _incoming && {alive _incoming} && {assignedVehicle _incoming == _vehicle}
            && {objectParent _incoming != _vehicle}
            && {!local _incoming || {toUpperANSI currentCommand _incoming == "GET IN"}}
    } >= 0};
};
if (_incomingBoarding) exitWith {false};
if (count _lease == 5) then {
    if ((_lease select 1) != _epoch || {(_lease select 4) != clientOwner}) then {
        _lease=+_lease;
        _lease set [1,_epoch];
        _lease set [4,clientOwner];
        _vehicle setVariable ["CBE_Cortex_UnloadPolicyLease",_lease,true];
    };
} else {
    private _previous=getUnloadInCombat _vehicle;
    private _applied=[false,false];
    _vehicle setUnloadInCombat _applied;
    _vehicle setVariable ["CBE_Cortex_UnloadPolicyLease",[_group,_epoch,_previous,_applied,clientOwner],true];
    _vehicle setVariable ["CBE_Cortex_UnloadPolicyBlocked",nil,true];
};
private _tracked=_group getVariable ["CBE_Cortex_UnloadPolicyVehicles",[]];
if !(_vehicle in _tracked) then {
    _tracked pushBack _vehicle;
    _group setVariable ["CBE_Cortex_UnloadPolicyVehicles",_tracked,true];
};
true
