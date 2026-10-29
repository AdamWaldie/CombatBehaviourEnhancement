/*
 * Author: WaldoTheWarfighter
 * Purpose: Read whether native attachment or an actor movement reservation prevents routine task admission.
 * Locality/authority: Read-only on the actor owner; remote/nonlocal actors refuse admission.
 * Repeat/JIP: No mutation, detach or expiry renewal. A native attachment reserves the actor until detached.
 * Without an attachment or pending journal, empty markers are free; unknown/malformed markers
 * remain reserved. Unresolved flight/naval-egress, point and indoor journals also block admission
 * after the ordinary marker expires; only their exact cleanup may retire pending native proof.
 * Only a fully typed finite three-field lease without that journal can expire on its local clock.
 * Arguments: 0 actor <OBJECT>, objNull.
 * Return: BOOL, true for attached/reserved/unknown/nonlocal actor; false only for an otherwise free actor.
 * Current callers: CortexAdvanceStart/FlankStart/AssaultStart and CortexClearBuilding admission,
 * CortexGarrison instant placement, CortexGarrisonApplyLocal, CortexDefendApplyLocal,
 * CortexClearRelease/DefendRelease/GarrisonRelease, DangerEngineRelease, OperationStep
 * and RecoveryStep; CortexFireControl and CortexAntiArmour protect the same reservations from injected targeting.
 * Example: private _reserved=[soldier1] call CBE_fnc_CortexActorMoveReserved;
 */
params [["_actor",objNull,[objNull]]];
if (isNull _actor || {!local _actor}) exitWith {true};
// An attachment owns the transform independently of seating or the ordinary CBE lease.
if (!isNull (attachedTo _actor)) exitWith {true};
// An expired ordinary marker cannot admit a new task over an unconfirmed native flight request.
// Only that feature's exact cleanup retires its journal; this predicate grants no native command.
if ((_actor getVariable ["CBE_Danger_FlightLease",[]]) isNotEqualTo []) exitWith {true};
if ((_actor getVariable ["CBE_Cortex_NavalEgressMove",[]]) isNotEqualTo []) exitWith {true};
if ((_actor getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isNotEqualTo createHashMap) exitWith {true};
// A finite observer deadline is not acknowledgement of its outstanding native request.
// Point/indoor FINISH and transfer cleanup use exact own-journal proof independently;
// ordinary admission cannot claim the actor until that owner actually retires the journal.
if ((_actor getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo []) exitWith {true};
if ((_actor getVariable ["CBE_IndoorActor_Order",[]]) isNotEqualTo []) exitWith {true};
if ((_actor getVariable ["CBE_FiringPosition_Order",[]]) isNotEqualTo []) exitWith {true};
private _lease=_actor getVariable ["CBE_Cortex_ActorMove",[]];
if (_lease isEqualTo []) exitWith {false};
private _expired=_lease isEqualType [] && {count _lease == 3}
    && {(_lease select 0) isEqualType ""}
    && {(_lease select 1) isEqualType []} && {count (_lease select 1) == 3}
    && {(_lease select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {(_lease select 2) isEqualType 0} && {finite (_lease select 2)}
    && {time >= (_lease select 2)};
!_expired