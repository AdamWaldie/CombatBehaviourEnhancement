/*
 * Author: WaldoTheWarfighter
 * Purpose: Qualify same-group native warning delivery by existing voice/radio/jamming rules.
 * Shared warnings require current combat-effective, simulated visible sender/receiver crew
 * before voice or cached-radio acceptance. Own-vehicle defence retains its separate admission.
 * Locality/authority: Read-only world query; caller owns admission. Never acquires actor control.
 * Repeat/JIP: No worker or public state. Optional caller-local cache holds<=32 transmitter reads
 * for one finite planner<=1s; interceptor admission/rechecks pass no cache and read current hooks.
 * Arguments: 0 platform OBJECT,objNull; 1 receiving gunner OBJECT,objNull;
 * 2 group GROUP,grpNull; 3 warned asset OBJECT,objNull; 4 query cache ARRAY,[] of[actor,BOOL].
 * Return: BOOL, warning can be delivered; not target knowledge or fire permission.
 * Current callers: CortexAAAllocate and CortexAAIntercept START/one-second maintenance.
 * Example: private _linked=[_vehicle,_gunner,_group,_victim] call CBE_fnc_CortexAAWarningLink;
 */
params [["_vehicle",objNull,[objNull]],["_gunner",objNull,[objNull]],
    ["_group",grpNull,[grpNull]],["_victim",objNull,[objNull]],["_cache",[],[[]]]];
if (_victim == _vehicle && {!isNull _vehicle}) exitWith {true};
if (isNull _vehicle || {isNull _group} || {isNull _victim} || {!alive _victim}
    || {isNull _gunner} || {gunner _vehicle != _gunner} || {group _gunner != _group}
    || {group gunner _victim != _group}
    || {!([_group,"CBE_AIPass_ContactReports_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {false};
private _sender=gunner _victim;
// A nearby body cannot voice a warning, and cached radio availability cannot
// resurrect an incapacitated crew member during this finite planner.
if (!([_sender] call CBE_fnc_CortexCombatEffective)
    || {!([_gunner] call CBE_fnc_CortexCombatEffective)}
    || {!simulationEnabled _sender} || {isObjectHidden _sender}
    || {!simulationEnabled _gunner} || {isObjectHidden _gunner}) exitWith {false};
private _voice=missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35];
if ((getPosASL _sender) distance (getPosASL _gunner) <= _voice) exitWith {true};
private _range=missionNamespace getVariable ["CBE_AIPass_ContactReports_Radius",500];
if (_sender distance2D _gunner > _range) exitWith {false};
private _transmit={
    params ["_actor"];
    private _index=_cache findIf {(_x select 0) == _actor};
    if (_index >= 0) exitWith {(_cache select _index) select 1};
    if (count _cache >= 32) exitWith {false};
    private _allowed=[_actor] call CBE_fnc_CortexCanTransmit;
    if (count _cache < 32) then {_cache pushBack [_actor,_allowed]};
    _allowed
};
[_sender] call _transmit && {[_gunner] call _transmit}
