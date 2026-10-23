/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a screened nearby indoor refuge after exterior danger cover fails.
 * Locality/authority: Read-only on the actor/group owner. Callers retain task, native-order,
 * generation and movement authority and recheck those before issuing any command.
 * Repeat/JIP: No state, cache, timer or replay. One native House query within18m; inspect at
 * most two houses. Each existing node-selector call ranks at most512 native points and probes
 * at most three roofs, respecting same-floor body separation and known failed actor nodes.
 * Native query cost depends on local density. A returned roofed point is not proof of access,
 * successful arrival, ballistic protection or a safe room. No doors are opened or unlocked.
 * Arguments: 0 actor OBJECT objNull; 1 original actor ATL ARRAY []; 2 threat ATL ARRAY [].
 * Return: ARRAY one native ATL point with current screening, or[] when none qualifies.
 * Current callers: DangerFlight and DangerCoverStep, under their existing finite movement leases.
 * Example: private _refuge=[soldier1,getPosATL soldier1,[100,200,0]] call CBE_fnc_DangerRefugeSelect;
 */
params [["_actor",objNull,[objNull]],["_origin",[],[[]]],["_threat",[],[[]]]];
if (isNull _actor || {!local _actor} || {isNull group _actor} || {!local group _actor}
    || {[_origin,_threat] findIf {count _x != 3 || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {!([group _actor,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {[]};
private _rayStart=(AGLToASL _threat) vectorAdd [0,0,1.6];
private _refugeHouses=nearestObjects [_origin,["House"],18,true];
private _refuge=[];
{
    private _refugeHouse=_x;
    if (alive _refugeHouse) then {
        private _refugeFrame=[getPosWorld _refugeHouse,vectorDir _refugeHouse,vectorUp _refugeHouse];
        private _refugeNode=[_actor,_refugeHouse,_origin,[]] call CBE_fnc_IndoorActorNodeSelect;
        if (count _refugeNode == 3 && {_origin vectorDistance _refugeNode >= 0.6}
            && {_origin vectorDistance _refugeNode <= 18}
            && {[_rayStart,(AGLToASL _refugeNode) vectorAdd [0,0,1],_actor,"COVER"] call CBE_fnc_CortexCoverScreened}
            && {alive _refugeHouse}
            && {_refugeFrame isEqualTo [getPosWorld _refugeHouse,vectorDir _refugeHouse,vectorUp _refugeHouse]}) then {
            _refuge=+_refugeNode;
        };
    };
    if (_refuge isNotEqualTo []) exitWith {};
} forEach (_refugeHouses select [0,2]);
_refuge
