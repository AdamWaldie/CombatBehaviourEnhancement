/*
 * Author: WaldoTheWarfighter
 * Purpose: Sample at most sixteen group members fairly for individual indoor investigation.
 * Locality/authority: Current group owner only; changes a cursor in the supplied local group
 * state, never actor orders, reservations, knowledge or operation authority.
 * Repeat/JIP: Shared cursor for contact/body-clue dispatch; no worker, public replay or timer.
 * Full two-investigator occupancy freezes the cursor rather than repeatedly skipping whole
 * roster windows while admission is impossible. Stable rosters rotate across later dispatches.
 * Arguments: 0 group GROUP,grpNull; 1 current group state HASHMAP,empty.
 * Return: ARRAY of0..16 OBJECTS; callers still filter eligibility and execute full START checks.
 * Current callers: IndoorActorDispatch and IndoorObservationDispatch at their existing cadence.
 * Cost: One native units snapshot (existing cost); <=2 investigator metadata reads and16 indices.
 * Example: private _sample=[group soldier1,_state] call CBE_fnc_IndoorActorSample;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]]];
if (isNull _group || {!local _group}) exitWith {[]};
private _investigators=_group getVariable ["CBE_IndoorActor_Actors",[]];
if (!(_investigators isEqualType []) || {count _investigators > 2}) exitWith {[]};
private _active=0;
{
    if (_x isEqualType objNull && {!isNull _x} && {alive _x} && {local _x} && {group _x == _group}) then {
        private _brain=_x getVariable ["CBE_IndoorActor_Brain",createHashMap];
        if (_brain isEqualType createHashMap && {count _brain > 0}
            && {!(_brain getOrDefault ["finished",true])}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {serverTime < (_brain getOrDefault ["deadline",-1])}) then {_active=_active+1};
    };
} forEach _investigators;
if (_active >= 2) exitWith {[]};
private _roster=units _group;private _count=count _roster;
if (_count == 0) exitWith {[]};
private _cursor=_state getOrDefault ["indoorActorCursor",0];
if (!(_cursor isEqualType 0) || {!finite _cursor} || {_cursor < 0} || {_cursor != floor _cursor}) then {_cursor=0};
_cursor=_cursor mod _count;
private _sample=[];private _budget=_count min 16;
for "_offset" from 0 to (_budget-1) do {_sample pushBack (_roster select ((_cursor+_offset) mod _count))};
_state set ["indoorActorCursor",(_cursor+_budget) mod _count];
_sample
