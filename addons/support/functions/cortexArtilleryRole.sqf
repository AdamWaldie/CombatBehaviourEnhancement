/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Returns which fire missions a battery takes: squads' support calls, counter-battery, or both.
 *
 * Read from the battery's CBE_AIPass_ArtilleryRole, then its gun crew's group, then
 * CBE_AIPass_Artillery_DefaultRole (default "BOTH"). Set it with CBE_fnc_CortexSetArtilleryRole,
 * from the gun's init field, or with the AI Orders Zeus module.
 * Locality and authority: read-only; callable anywhere.
 *
 * Arguments:
 * 0: battery <OBJECT> - artillery vehicle or static weapon
 * 1: mission <STRING> (optional, default: "") - "SUPPORT" or "COUNTER" to test that mission instead
 *
 * Return Value:
 * String - "SUPPORT", "COUNTER" or "BOTH"; or, when a mission is given, Boolean - true when the
 * battery takes that mission
 *
 * Example:
 * if ([_gun, "COUNTER"] call CBE_fnc_CortexArtilleryRole) then {...};
 * Result: only guns allowed to do counter-battery answer enemy artillery.
 *
 * Current callers: CBE_fnc_CortexArtilleryRequest, CBE_fnc_CortexCounterBattery and
 * CBE_fnc_CortexRetreat.
 */

params [["_battery", objNull, [objNull]], ["_mission", "", [""]]];
private _default = toUpperANSI (missionNamespace getVariable ["CBE_AIPass_Artillery_DefaultRole", "BOTH"]);
private _role = toUpperANSI (_battery getVariable ["CBE_AIPass_ArtilleryRole",
    (group gunner _battery) getVariable ["CBE_AIPass_ArtilleryRole", _default]]);
if !(_role in ["SUPPORT", "COUNTER", "BOTH"]) then {_role = "BOTH"};
if (_mission == "") exitWith {_role};
_role == "BOTH" || {_role == toUpperANSI _mission}

