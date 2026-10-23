/*
 * Author: WaldoTheWarfighter
 * Matching policy values never repeat the engine command on acquisition or restoration.
 * Immobilisation or native flight of the driver/effective commander retires an unchanged
 * owned retention policy to its original value; ordinary cargo panic does not. Two actor reads only.
 * No forced dismount or alteration of the engine immobile-crew policy is issued.
 * Initial acquisition defers for assigned incoming native GET IN or unknown remote intent;
 * at most64 returned seat rows are inspected before the first engine policy write. No boarding is issued.
 * Purpose: Acquires/adopts or releases the convoy's exact unload-in-combat policy lease.
 * A changed value retires the lease and blocks reacquisition for the same convoy group until
 * explicit release; HALT/resume revisions and locality migration do not erase that decision.
 * Locality/authority: Vehicle owner only; ACQUIRE requires the current server revision and
 * registered vehicle/group. RELEASE restores only a matching current value when permitted.
 * Repeat/JIP: Public lease and blocked-group records survive migration; unchanged leases are
 * adopted without repeating engine writes. No handlers or scheduled work are installed.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 convoy group <GROUP, grpNull>;
 * 2 action <STRING, ACQUIRE>; 3 revision <NUMBER, -1> (required for ACQUIRE);
 * 4 restore previous policy <BOOL, true> (RELEASE only).
 * Return: BOOL, true when the matching lease is owned/adopted or cleanly released.
 * Current callers: ConvoyTick, ConvoyCrewLocal, ConvoyReleaseLocal.
 * Example: [_truck,_convoy,"ACQUIRE",12] call CBE_fnc_ConvoyUnloadPolicy;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_action","ACQUIRE",[""]],["_revision",-1,[0]],["_restore",true,[false]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _vehicle || {isNull _group} || {!local _vehicle}) exitWith {false};
_action=toUpperANSI _action;
private _lease=_vehicle getVariable ["CBE_Convoy_UnloadPolicyLease",[]];
private _blocked=_vehicle getVariable ["CBE_Convoy_UnloadPolicyBlocked",grpNull];
if (_action == "RELEASE") exitWith {
    private _ours=count _lease == 5 && {(_lease select 0) == _group};
    if (_ours) then {
        _lease params ["_leaseGroup","_leaseRevision","_previous","_applied","_owner"];
        if (_restore && {getUnloadInCombat _vehicle isEqualTo _applied} && {_previous isNotEqualTo _applied}) then {
            _vehicle setUnloadInCombat _previous;
        };
        _vehicle setVariable ["CBE_Convoy_UnloadPolicyLease",nil,true];
    };
    if (_blocked == _group) then {_vehicle setVariable ["CBE_Convoy_UnloadPolicyBlocked",nil,true]};
    _ours
};
private _operator=effectiveCommander _vehicle;
if (isNull _operator) then {_operator=driver _vehicle};
if (_action != "ACQUIRE" || {_revision < 0}
    || {_revision != (_group getVariable ["CBE_Convoy_Revision",-2])}
    || {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    || {(_vehicle getVariable ["CBE_Convoy_Group",grpNull]) != _group}
    || {isNull _operator} || {group _operator != _group}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
if (_blocked == _group) exitWith {false};
if (count _lease == 5 && {(_lease select 0) != _group || {(_lease select 1) > _revision}}) exitWith {false};
if (count _lease == 5 && {getUnloadInCombat _vehicle isNotEqualTo (_lease select 3)}) exitWith {
    // A newer controller changed the policy. Revision churn must not take it back.
    _vehicle setVariable ["CBE_Convoy_UnloadPolicyLease",nil,true];
    _vehicle setVariable ["CBE_Convoy_UnloadPolicyBlocked",_group,true];
    false
};
// Native flight owns the operating crew even while the platform can still move.
// Cargo panic alone does not revoke the whole carrier's policy. Read only its two operators.
private _nativeCrewFlight=[driver _vehicle,effectiveCommander _vehicle] findIf {
    !isNull _x && {fleeing _x}
} >= 0;
// Disabled carriers and native-fleeing operators relinquish only our unchanged policy.
// Restore the captured value; this never forces dismount or enables a mission-disabled bailout.
if (!canMove _vehicle || {_nativeCrewFlight}) exitWith {
    if (count _lease == 5) then {[_vehicle,_group,"RELEASE",_revision,true] call CBE_fnc_ConvoyUnloadPolicy};
    false
};
// First acquisition alone can change engine boarding state. Refusal must leave
// without publishing a lease, tracked membership or a success result.
private _incomingBoarding=false;
if (count _lease != 5 && {getUnloadInCombat _vehicle isNotEqualTo [false,false]}) then {
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
    if ((_lease select 1) != _revision || {(_lease select 4) != clientOwner}) then {
        _lease set [1,_revision];_lease set [4,clientOwner];
        _vehicle setVariable ["CBE_Convoy_UnloadPolicyLease",_lease,true];
    };
} else {
    private _previous=getUnloadInCombat _vehicle;
    private _applied=[false,false];
    if (_previous isNotEqualTo _applied) then {_vehicle setUnloadInCombat _applied};
    _vehicle setVariable ["CBE_Convoy_UnloadPolicyLease",[_group,_revision,_previous,_applied,clientOwner],true];
};
true
