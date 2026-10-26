/*
 * Author: WaldoTheWarfighter
 * Purpose: Read whether a finite actor movement reservation prevents routine task admission.
 * Locality/authority: Read-only on the actor owner; remote/nonlocal actors refuse admission.
 * Repeat/JIP: No mutation or expiry renewal. Empty markers are free; unknown/malformed markers
 * remain reserved. Unresolved flight/naval-egress journals also block admission after the
 * ordinary marker expires; only their exact cleanup may retire pending native proof.
 * Only a fully typed finite three-field lease without that journal can expire on its local clock.
 * Arguments: 0 actor <OBJECT>, objNull.
 * Return: BOOL, true for reserved/unknown/nonlocal actor; false only for empty or valid expired lease.
 * Current callers: CortexAdvanceStart/FlankStart/AssaultStart and CortexClearBuilding admission,
 * CortexGarrison instant placement, CortexGarrisonApplyLocal, CortexDefendApplyLocal,
 * CortexClearRelease/DefendRelease/GarrisonRelease, DangerEngineRelease, OperationStep
 * and RecoveryStep; CortexFireControl and CortexAntiArmour protect the same reservations from injected targeting.
 * Example: private _reserved=[soldier1] call CBE_fnc_CortexActorMoveReserved;
 */
params [["_actor",objNull,[objNull]]];
if (isNull _actor || {!local _actor}) exitWith {true};
// An expired ordinary marker cannot admit a new task over an unconfirmed native flight request.
// Only that feature's exact cleanup retires its journal; this predicate grants no native command.
if ((_actor getVariable ["CBE_Danger_FlightLease",[]]) isNotEqualTo []) exitWith {true};
if ((_actor getVariable ["CBE_Cortex_NavalEgressMove",[]]) isNotEqualTo []) exitWith {true};
private _lease=_actor getVariable ["CBE_Cortex_ActorMove",[]];
if (_lease isEqualTo []) exitWith {false};
private _expired=_lease isEqualType [] && {count _lease == 3}
    && {(_lease select 0) isEqualType ""}
    && {(_lease select 1) isEqualType []} && {count (_lease select 1) == 3}
    && {(_lease select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {(_lease select 2) isEqualType 0} && {finite (_lease select 2)}
    && {time >= (_lease select 2)};
!_expired