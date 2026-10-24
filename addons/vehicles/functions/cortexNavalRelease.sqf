/*
 * Author: WaldoTheWarfighter
 * Releases a finite Cortex naval landing and restores the exact boat speed borrowed for dismount
 * only while CBE's zero-speed lease remains current.
 *
 * Locality/authority: call on the current group owner. Only the group whose token matches the
 * public boat plan may clear that plan or restore the boat. The stop receipt is public
 * and token/group-bound; a departed owner cannot retire a resumed operation. Passenger groups release only their
 * own movement lease. Zeus takeover and locality cleanup use this same path.
 * Repeat/JIP: public plan tokens, exact saved forced-speed values and the owned zero cap make
 * repeated or late cleanup harmless. Route cleanup requires the matching generation, and a later
 * controller's speed survives release. No unit is boarded, moved or teleported during release.
 * Exact acknowledged foot-egress moves may receive one STOP request before operation retirement;
 * unresolved receipts remain for existing sparse actor discovery, without a fresh deadline.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP> (optional; current Cortex state by default)
 * 2: reason <STRING, CANCELLED> for the matching shared operation.
 *
 * Return Value:
 * Nothing
 *
 * Current callers: CortexNavalAssault and CortexReleaseGroup.
 *
 * Example:
 * [_group, _state] call CBE_fnc_CortexNavalRelease;
 * Result: the boat and squad resume their authored orders.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_reason","CANCELLED",[""]]
];
if (isNull _group || {!local _group}) exitWith {};
// A handover release must clear CBE state without restoring a speed chosen by a later
// curator, mission or specialist controller.
private _externalTakeover=[_group] call CBE_fnc_CortexExternalTakeover;
private _operation=_state getOrDefault ["navalOperation",[]];
if (_operation isEqualTo []) then {
    _operation=_group getVariable ["CBE_Cortex_NavalOperation",[]];
};
private _token=_operation param [0,""];
private _boat=_operation param [1,objNull];
private _durable=_group getVariable ["CBE_Cortex_NavalOperation",[]];
private _durableToken=_durable param [0,""];
private _ground=_group getVariable ["CBE_Cortex_NavalGroundElement",[]];
private _groundToken=_ground param [0,""];
private _retirePublic=(_durableToken == "" || {_durableToken isEqualTo _token})
    && {_groundToken == "" || {_groundToken isEqualTo _token} || {_token == ""}};
if (_retirePublic) then {_group setVariable ["CBE_Cortex_NavalGroundElement",nil,true]};

// Retire only this landing token's actor requests before removing the common operation/route.
// Pending native cleanup retains actor proof for existing sparse discovery; no late replay.
private _cohort=_group getVariable ["CBE_Cortex_NavalEgress",[]];
if (count _cohort == 3 && {(_cohort select 0) == _token}) then {
    {
        private _actor=_x select 0;
        private _proof=_actor getVariable ["CBE_Cortex_NavalEgressMove",[]];
        if (local _actor && {count _proof == 11} && {(_proof select 0) == _group}
            && {(_proof select 1) == _token}) then {
            ["RELEASE",_actor] call CBE_fnc_CortexNavalEgressActor;
        };
    } forEach ((_cohort select 2) select [0,64]);
    _group setVariable ["CBE_Cortex_NavalEgress",nil,true];
};
if (!isNull _boat) then {
    private _plan=_boat getVariable ["CBE_Cortex_NavalPlan",[]];
    if (count _plan == 9 && {_token != ""} && {(_plan select 0) == _token}
        && {(_plan select 1) == _group} && {local _boat}) then {
        private _saved=_boat getVariable ["CBE_Cortex_NavalForcedSpeed",[]];
        private _ownedStop=_saved param [1,-2];
        if (count _saved == 4 && {(_saved select 2) isEqualTo _token}
            && {(_saved select 3) isEqualTo _group}
            && {(_saved select 0) isEqualType 0} && {finite (_saved select 0)} && {(_saved select 0) >= -1}
            && {_ownedStop isEqualType 0} && {finite _ownedStop}
            && {!_externalTakeover} && {_ownedStop >= 0}
            && {abs ((getForcedSpeed _boat)-_ownedStop) <= 0.1}) then {
            _boat forceSpeed (_saved param [0,-1]);
        };
        if (count _saved == 4 && {(_saved select 2) isEqualTo _token}
            && {(_saved select 3) isEqualTo _group}) then {
            _boat setVariable ["CBE_Cortex_NavalForcedSpeed",nil,true];
            _boat setVariable ["CBE_Cortex_NavalStopLocal",nil];
        };
        _boat setVariable ["CBE_Cortex_NavalPlan",nil,true];
    };
};
private _operationGeneration=_state getOrDefault ["navalOperationGeneration",-1];
private _movement=_state getOrDefault ["movementLease",[]];
if (_operationGeneration >= 0 && {(_movement param [0,""]) in ["NAVAL_ASSAULT","NAVAL_LANDING"]}) then {
    [_group,_operationGeneration] call CBE_fnc_CortexGroupMoveClear;
    [_group,_movement param [0,""],false] call CBE_fnc_CortexOwnershipLease;
    _state deleteAt "movementLease";
};
if (_operationGeneration >= 0) then {
    if (toUpperANSI _reason == "COMPLETE") then {
        [_group,_operationGeneration,"COMPLETE","NAVAL_"+toUpperANSI _reason] call CBE_fnc_OperationRelease;
    } else {
        [_group,_operationGeneration,"NAVAL_"+toUpperANSI _reason] call CBE_fnc_OperationCancel;
    };
};
_state deleteAt "navalOperationGeneration";
_state deleteAt "navalOperation";
if (_retirePublic) then {
    _group setVariable ["CBE_Cortex_NavalOperation",nil,true];
    _group setVariable ["CBE_Cortex_NavalStatus",nil,true];
};
