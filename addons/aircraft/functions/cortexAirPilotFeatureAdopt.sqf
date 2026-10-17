/*
 * Author: WaldoTheWarfighter
 * Purpose: Accept release-only pilot feature recovery on an actual actor-locality boundary.
 * Locality/authority: Invoked by native actor Local EH or retroactive CBA init on every machine.
 * Current actor locality is mandatory; this never adopts flight or replays an attack.
 * Repeat/JIP: Exact receipt coalesces per owner. Loss invalidates local adoption and pending chain.
 * Arguments: 0 actor <OBJECT, objNull>; 1 gained locality <BOOL, false>;
 * 2 internal receipt lookup attempt <NUMBER, 0>; 3 internal locality epoch <NUMBER, -1>.
 * Return: BOOL, true when a matching receipt was offered for finite release; not restoration proof.
 * Current callers: XEH_postInit actor init/Local handlers.
 * Example: [pilot1,local pilot1] call WAIT_fnc_CortexAirPilotFeatureAdopt;
 */
params [["_actor",objNull,[objNull]],["_gained",false,[true]],["_attempt",0,[0]],["_epoch",-1,[0]]];
if (isNull _actor) exitWith {false};
if (!finite _attempt || {_attempt < 0} || {_attempt > 5} || {_attempt != floor _attempt}) exitWith {false};
if (_attempt == 0) then {
    _actor setVariable ["WAIT_AirPilotFeatureLocalEpoch",(_actor getVariable ["WAIT_AirPilotFeatureLocalEpoch",0])+1];
    _epoch=_actor getVariable ["WAIT_AirPilotFeatureLocalEpoch",0];
};
if (_epoch != (_actor getVariable ["WAIT_AirPilotFeatureLocalEpoch",0])) exitWith {false};
if (!_gained || {!local _actor}) exitWith {
    _actor setVariable ["WAIT_AirPilotFeatureAdoption",nil];
    _actor setVariable ["WAIT_AirPilotFeatureReleaseStarted",nil];
    false
};
private _receipt=_actor getVariable ["WAIT_AirPilotFeatureReceipt",[]];
if (_receipt isEqualTo []) exitWith {
    // Only aircraft occupants may wait for a late public record; ordinary actors queue no work.
    if (_attempt < 5 && {vehicle _actor != _actor} && {(vehicle _actor) isKindOf "Air"}) then {
        [{_this call WAIT_fnc_CortexAirPilotFeatureAdopt},[_actor,true,_attempt+1,_epoch],1] call CBA_fnc_waitAndExecute;
    };
    false
};
if (count _receipt != 7 || {(_receipt select 1) isNotEqualTo _actor}) exitWith {false};
// Init/late lookup on the original owner is observation, not operation termination.
// Only actual cleanup may create its first release window; adoption must not age it early.
private _window=_actor getVariable ["WAIT_AirPilotFeatureReleaseWindow",[]];
if ((_receipt select 5) isEqualTo clientOwner
    && {count _window != 2 || {(_window select 0) isNotEqualTo _receipt}}) exitWith {false};
// The immutable issuer is provenance. Only this actual actor-local callback authorizes this
// machine's release attempt; neither group ownership nor the public flight lease grants it.
_actor setVariable ["WAIT_AirPilotFeatureAdoption",+_receipt];
[_actor,_receipt] call WAIT_fnc_CortexAirPilotFeatureRelease;
true
