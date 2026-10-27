/*
 * Author: WaldoTheWarfighter
 * Purpose: Maintain the bounded per-gun reservations inside the existing artillery movement domain.
 * Locality/authority: LIST/CHECK/OWNED read replicated metadata. ADD/REPLACE/REMOVE are internal,
 * current group-owner calls inside the caller's unscheduled admission/retirement transaction.
 * First admission retires ordinary driving through CortexOwnershipLease. Peers share that domain,
 * never acquire a second controller or retire another gun. No native commands are issued here.
 * Repeat/JIP: Entries retain original deadlines and group-wide unique serials across deletion.
 * Removal changes only the exact entry; unresolved entries keep the group reserved after expiry.
 * Aggregate public/private lease snapshots prevent cleanup over newer or unknown owners.
 * Arguments: group GROUP,grpNull; mode STRING,CHECK; reference ARRAY,[] (five original fields);
 * replacement ARRAY,[] (REPLACE only); original hold deadline NUMBER,-1 (ADD only).
 * Return: LIST returns up to64 reference ARRAYs, empty on invalid input; other modes return BOOL.
 * Current callers: ArtilleryCrewMoveStart/Step/Current, shared crew retirement/deletion,
 * CortexDiscover/Locality/Stop and CortexArtilleryScoot. This is not a public task API.
 * Example: [_group,"CHECK",_reference] call CBE_fnc_ArtilleryCrewReservation;
 */
params [["_group",grpNull,[grpNull]],["_mode","CHECK",[""]],["_reference",[],[[]]],
    ["_replacement",[],[[]]],["_until",-1,[0]]];
private _reading=_mode in ["LIST","CHECK","OWNED"];
private _failure=if (_mode == "LIST") then {[]} else {false};
if (isNull _group || {!(_mode in ["LIST","CHECK","OWNED","ADD","REPLACE","REMOVE"])}
    || {!_reading && {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {!local _group}}}) exitWith {_failure};
private _rows=_group getVariable ["CBE_ArtilleryCrew_Reservations",[]];
private _typedReference={
    params ["_value"];
    _value isEqualType [] && {count _value == 5} && {(_value select 0) isEqualType objNull}
        && {(_value select 1) isEqualType ""} && {(_value select 1) != ""}
        && {[2,3,4] findIf {!((_value select _x) isEqualType 0)
            || {!finite (_value select _x)} || {(_value select _x) < 0}} < 0}
};
if (!(_rows isEqualType []) || {count _rows > 64} || {_rows findIf {
    !(_x isEqualType []) || {count _x != 2} || {!([_x select 0] call _typedReference)}
        || {!((_x select 1) isEqualType 0)} || {!finite (_x select 1)} || {(_x select 1) < 0}
} >= 0}) exitWith {_failure};
if (_mode == "LIST") exitWith {_rows apply {+(_x select 0)}};
if !([_reference] call _typedReference) exitWith {false};
private _index=_rows findIf {(_x select 0) isEqualTo _reference};
if (_mode == "CHECK") exitWith {_index >= 0};
private _state=if (_reading) then {_group getVariable ["CBE_AIPass_State",createHashMap]}
    else {[_group] call CBE_fnc_CortexGroupState};
private _snapshot=_group getVariable ["CBE_ArtilleryCrew_Lease",[]];
private _public=_group getVariable ["CBE_Cortex_MovementLease",[]];
private _private=_state getOrDefault ["movementLease",[]];
private _snapshotTyped=_snapshot isEqualType [] && {count _snapshot == 2}
    && {_snapshot findIf {!(_x isEqualType []) || {count _x != 2}
        || {(_x select 0) != "ARTILLERY_CREW"} || {!((_x select 1) isEqualType 0)}
        || {!finite (_x select 1)}} < 0};
private _owns=_snapshotTyped && {_public isEqualTo (_snapshot select 0)}
    && {_private isEqualTo (_snapshot select 1)};
if (_mode == "OWNED") exitWith {_index >= 0 && {_owns}};
if (_mode == "ADD") exitWith {
    if (_index >= 0 || {count _rows >= 64} || {!finite _until} || {_until <= serverTime}
        || {isNull (_reference select 0)} || {!local (_reference select 0)}
        || {(_reference select 3) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
        || {(_reference select 4) != clientOwner}
        || {_rows findIf {private _peer=_x select 0;
            (_peer select 0) isEqualTo (_reference select 0) || {(_peer select 2) == (_reference select 2)}
                || {(_peer select 3) != (_reference select 3)} || {(_peer select 4) != clientOwner}
                || {isNull (_peer select 0)} || {!local (_peer select 0)}
                || {private _work=(_peer select 0) getVariable ["CBE_ArtilleryCrew_Work",createHashMap];
                    (_work getOrDefault ["reference",[]]) isNotEqualTo _peer}
        } >= 0}
        || {(_group getVariable ["CBE_VehicleTurn_Work",createHashMap]) isNotEqualTo createHashMap}
        || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}) exitWith {false};
    if (_rows isEqualTo []) then {
        _owns=false;
        if (_snapshot isEqualTo [] && {[_group,"ARTILLERY_CREW",true,_until]
            call CBE_fnc_CortexOwnershipLease}) then {_owns=true};
    } else {
        // Peer admission must not run group-wide ordinary-driving cleanup again.
        if (count (_group getVariable ["CBE_Driving_Brain",createHashMap]) > 0) then {_owns=false};
    };
    if (!_owns) exitWith {false};
    _rows=+_rows;_rows pushBack [+_reference,_until];
    private _expiry=_until;
    {_expiry=_expiry max (_x select 1)} forEach _rows;
    private _lease=["ARTILLERY_CREW",_expiry];
    private _localLease=["ARTILLERY_CREW",time+(_expiry-serverTime)];
    _group setVariable ["CBE_Cortex_MovementLease",_lease,true];
    _state set ["movementLease",_localLease];
    _group setVariable ["CBE_ArtilleryCrew_Lease",[_lease,_localLease],true];
    _group setVariable ["CBE_ArtilleryCrew_Reservations",_rows,true];
    true
};
if (_index < 0) exitWith {false};
if (_mode == "REPLACE") exitWith {
    if (!([_replacement] call _typedReference)
        || {(_replacement select [0,3]) isNotEqualTo (_reference select [0,3])}
        || {(_replacement select 3) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
        || {(_replacement select 4) != clientOwner}) exitWith {false};
    _rows=+_rows;_rows set [_index,[+_replacement,(_rows select _index) select 1]];
    _group setVariable ["CBE_ArtilleryCrew_Reservations",_rows,true];
    // A new local group state may lack the old private clock. Rebind only retirement's
    // reservation and only while the original aggregate public identity still matches.
    if (_snapshotTyped && {_public isEqualTo (_snapshot select 0)} && {_private isEqualTo []}) then {
        private _localLease=["ARTILLERY_CREW",time+((_public select 1)-serverTime)];
        _state set ["movementLease",_localLease];
        _group setVariable ["CBE_ArtilleryCrew_Lease",[+_public,_localLease],true];
    };
    true
};
// REMOVE is called only after this producer's positive retirement/deletion proof.
// It never infers quiescence, issues a stop, or clears another gun's entry.
private _canRetireLease=_snapshotTyped && {_public isEqualTo (_snapshot select 0)}
    && {_private isEqualTo [] || {_private isEqualTo (_snapshot select 1)}};
_rows=+_rows;_rows deleteAt _index;
if (_rows isEqualTo []) then {
    if (_canRetireLease) then {
        [_group,"ARTILLERY_CREW",false] call CBE_fnc_CortexOwnershipLease;
        if (_private isNotEqualTo []) then {_state deleteAt "movementLease"};
    };
    _group setVariable ["CBE_ArtilleryCrew_Lease",nil,true];
    _group setVariable ["CBE_ArtilleryCrew_Reservations",nil,true];
} else {
    if (_canRetireLease) then {
        private _expiry=(_rows select 0) select 1;
        {_expiry=_expiry max (_x select 1)} forEach _rows;
        private _lease=["ARTILLERY_CREW",_expiry];
        private _localLease=["ARTILLERY_CREW",time+(_expiry-serverTime)];
        _group setVariable ["CBE_Cortex_MovementLease",_lease,true];
        _state set ["movementLease",_localLease];
        _group setVariable ["CBE_ArtilleryCrew_Lease",[_lease,_localLease],true];
    };
    _group setVariable ["CBE_ArtilleryCrew_Reservations",_rows,true];
};
true
