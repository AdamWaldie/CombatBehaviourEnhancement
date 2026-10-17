/*
 * Author: WaldoTheWarfighter
 * Checks owner-local permission for defensive reactions on any eligible AI aircraft.
 * Locality/authority: on the aircraft owner; the aircraft does not need to originate from another
 * CBE feature. This prevents the global missile-reaction setting from silently depending on the
 * separate Gunship or Dynamic AA systems.
 * Repeat/JIP: no installation; rechecks the shared player, curator and specialist ownership boundary.
 * No external addon state is changed.
 * Arguments: 0: aircraft <OBJECT>, objNull.
 * Return: Boolean. Current callers: CBE_fnc_CortexDiscover missile handler and delayed flare bursts.
 * Example: private _allowed=[_aircraft] call CBE_fnc_CortexAircraftEligible;
 */
params [["_aircraft",objNull,[objNull]]];
if (isNull _aircraft || {!local _aircraft} || {!alive _aircraft}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
private _pilot=driver _aircraft;
if (isNull _pilot || {!alive _pilot} || {isPlayer _pilot} || {unitIsUAV _aircraft} || {_pilot getVariable ["ACE_isUnconscious",false]} || {lifeState _pilot == "INCAPACITATED"}) exitWith {false};
private _group=group _pilot;
if ([_group] call CBE_fnc_CortexExternalTakeover
    || {[_aircraft] call CBE_fnc_CompatibilityExternalControl}
    || {"ALL" in (_group getVariable ["CBE_AIPass_DisabledFeatures",[]])}) exitWith {false};
private _sideKey=switch (side _group) do {case west:{"WEST"}; case east:{"EAST"}; case independent:{"GUER"}; case civilian:{"CIV"}; default {""}};
if !(_sideKey in (missionNamespace getVariable ["CBE_AIPass_IncludedSides",["WEST","EAST","GUER"]])) exitWith {false};
private _included=missionNamespace getVariable ["CBE_AI_IncludedFactions",[]];
private _excluded=missionNamespace getVariable ["CBE_AI_ExcludedFactions",[]];
private _classes=missionNamespace getVariable ["CBE_AI_ExcludedClasses",[]];
if ([_group,_aircraft] findIf {_x getVariable ["CBE_AI_Exclude",false] || {_x getVariable ["CBE_AIPass_Exclude",false]}} >= 0) exitWith {false};
(units _group) findIf {
    alive _x && {isPlayer _x || {_x getVariable ["CBE_AI_Exclude",false]}
        || {_x getVariable ["CBE_AIPass_Exclude",false]}
        || {[_x] call CBE_fnc_CortexExternalOwner != ""}
        || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {count _included > 0 && {!(faction _x in _included)}}
        || {faction _x in _excluded} || {typeOf _x in _classes}}
} < 0
