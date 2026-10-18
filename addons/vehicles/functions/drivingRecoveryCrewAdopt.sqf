/*
 * Author: WaldoTheWarfighter
 * Purpose: Offers pending reverse cleanup when actual driving crew locality arrives late.
 * Locality/Authority: Native actor init/Local on each machine; local driver or effective
 * commander of a local LandVehicle only. This registers observation, never grants commands.
 * Repeat/JIP: Reuses vehicle adoption's epoch-bound finite five-lookups window; no replay,
 * extra loop, world scan, renewed movement deadline or passenger-triggered registration.
 * Arguments: 0 actor <OBJECT, objNull>; 1 gained locality <BOOL, false>.
 * Return Value: BOOL - an existing pending receipt was offered, not native handback success.
 * Current callers: Extended post-init CAManBase init and existing Local handler.
 * Example: [driver truck1,true] call CBE_fnc_DrivingRecoveryCrewAdopt;
 */
params [["_actor",objNull,[objNull]],["_gained",false,[true]]];
if (remoteExecutedOwner > 0 || {!_gained} || {isNull _actor} || {!local _actor}) exitWith {false};
private _vehicle=vehicle _actor;
if (_vehicle == _actor || {!local _vehicle} || {!(_vehicle isKindOf "LandVehicle")}
    || {_vehicle isKindOf "StaticWeapon"}
    || {!(_actor in [driver _vehicle,effectiveCommander _vehicle])}) exitWith {false};
[_vehicle,true] call CBE_fnc_DrivingRecoveryAdopt
