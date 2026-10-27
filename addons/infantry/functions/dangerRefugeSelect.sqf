/*
 * Author: WaldoTheWarfighter
 * Geometry identity includes object scale: rescaling invalidates cached selection and active work.
 * Purpose: Select a screened nearby indoor refuge after exterior danger cover fails.
 * Locality/authority: Read-only on the actor/group owner. Callers retain task, native-order,
 * generation and movement authority and recheck those before issuing any command.
 * Repeat/JIP: No state, cache, timer or replay. One native House query within18m; inspect at
 * most two houses. Each existing node-selector call ranks at most512 native points and probes
 * at most three roofs, respecting same-floor body separation and known failed actor nodes.
 * Native query cost depends on local density. A returned roofed point is not proof of access,
 * successful arrival, ballistic protection or a safe room. No doors are opened or unlocked.
 * Arguments: 0 actor OBJECT objNull; 1 original actor ATL ARRAY []; 2 threat ATL ARRAY [];
 * 3 withBinding BOOL false; 4 reserved native ATL destinations ARRAY [] maximum16.
 * With binding, success returns [nativePoint,building,geometry] for caller-owned lifecycle checks.
 * Return: ARRAY one native ATL point by default, or [point,building,geometry] withBinding;
 * [] when none qualifies. Screening never grants access, arrival or room-safety proof.
 * Current callers: DangerFlight, DangerCoverStep and CivilianReact, under existing finite movement ownership.
 * Example: private _refuge=[soldier1,getPosATL soldier1,[100,200,0]] call CBE_fnc_DangerRefugeSelect;
 */
params [["_actor",objNull,[objNull]],["_origin",[],[[]]],["_threat",[],[[]]],["_withBinding",false,[true]],["_reserved",[],[[]]]];
if (count _reserved > 16 || {isNull _actor} || {!local _actor} || {isNull group _actor} || {!local group _actor}
    || {([_origin,_threat]+_reserved) findIf {!(_x isEqualType []) || {count _x != 3} || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {!([group _actor,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {[]};
private _rayStart=(AGLToASL _threat) vectorAdd [0,0,1.6];
private _refugeHouses=nearestObjects [_origin,["House"],18,true];
private _refuge=[];private _binding=[];
{
    private _refugeHouse=_x;
    if (alive _refugeHouse) then {
        private _refugeFrame=[getPosWorld _refugeHouse,vectorDir _refugeHouse,vectorUp _refugeHouse,getObjectScale _refugeHouse];
        private _refugeNode=[_actor,_refugeHouse,_origin,_reserved] call CBE_fnc_IndoorActorNodeSelect;
        if (count _refugeNode == 3 && {_origin vectorDistance _refugeNode >= 0.6}
            && {_origin vectorDistance _refugeNode <= 18}
            && {[_rayStart,(AGLToASL _refugeNode) vectorAdd [0,0,1],_actor,"COVER"] call CBE_fnc_CortexCoverScreened}
            && {alive _refugeHouse}
            && {_refugeFrame isEqualTo [getPosWorld _refugeHouse,vectorDir _refugeHouse,vectorUp _refugeHouse,getObjectScale _refugeHouse]}) then {
            _refuge=+_refugeNode;
            _binding=[_refugeHouse,_refugeFrame];
        };
    };
    if (_refuge isNotEqualTo []) exitWith {};
} forEach (_refugeHouses select [0,2]);
if (_withBinding && {_refuge isNotEqualTo []}) then {[_refuge,_binding select 0,_binding select 1]} else {_refuge}
