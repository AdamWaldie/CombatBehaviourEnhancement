/*
 * Author: WaldoTheWarfighter
 * Purpose: Accept release-only pilot feature recovery on an actual actor-locality boundary.
 * Locality/authority: Invoked by native actor Local EH or retroactive CBA init on every machine.
 * Current actor locality is mandatory; this never adopts flight or replays an attack.
 * Repeat/JIP: Exact receipt coalesces per owner. Loss invalidates local adoption and pending chain.
 * Arguments: 0 actor <OBJECT, objNull>; 1 gained locality <BOOL, false>.
 * Return: BOOL, true when a matching receipt was offered for finite release; not restoration proof.
 * Current callers: XEH_postInit actor init/Local handlers.
 * Example: [pilot1,local pilot1] call WAIT_fnc_CortexAirPilotFeatureAdopt;
 */
params [["_actor",objNull,[objNull]],["_gained",false,[true]]];
if (isNull _actor) exitWith {false};
_actor setVariable ["WAIT_AirPilotFeatureLocalEpoch",(_actor getVariable ["WAIT_AirPilotFeatureLocalEpoch",0])+1];
if (!_gained || {!local _actor}) exitWith {
    _actor setVariable ["WAIT_AirPilotFeatureAdoption",nil];
    _actor setVariable ["WAIT_AirPilotFeatureReleaseStarted",nil];
    false
};
private _receipt=_actor getVariable ["WAIT_AirPilotFeatureReceipt",[]];
if (count _receipt != 7 || {(_receipt select 1) isNotEqualTo _actor}) exitWith {false};
// The immutable issuer is provenance. Only this actual actor-local callback authorizes this
// machine's release attempt; neither group ownership nor the public flight lease grants it.
_actor setVariable ["WAIT_AirPilotFeatureAdoption",+_receipt];
[_actor,_receipt] call WAIT_fnc_CortexAirPilotFeatureRelease;
true
