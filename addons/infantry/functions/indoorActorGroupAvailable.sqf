/*
 * Author: WaldoTheWarfighter
 * Purpose: Decide whether an existing infantry operation leaves one actor free for indoor work.
 * Locality/authority: Read-only on the actor/group owner. Explicit disjoint rosters grant no
 * movement authority by themselves; the caller must still validate native orders and actor leases.
 * Repeat/JIP: Stateless; no reservation or operation generation is renewed or replayed.
 * Arguments: 0 actor <OBJECT>, objNull; 1 optional same-callback group context ARRAY.
 * Omitting argument1 always obtains fresh group authority. Explicit snapshots are candidate
 * preflight only; they grant no native command and must not be stored across callbacks.
 * Return: BOOL; false for ambiguous/group-wide/overlapping work or malformed ownership records.
 * Current callers: CortexAirborneGroundHandover (same-call roster preflight),
 * IndoorActorOperation, CortexBuildingDoor, IndoorActorDispatch and
 * IndoorObservationDispatch. Dispatchers and airborne handover supply the optional preflight snapshot.
 * Example: private _free=[soldier1] call CBE_fnc_IndoorActorGroupAvailable;
 */
params [["_actor",objNull,[objNull]],["_context",[],[[]]]];
if (isNull _actor || {!local _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}) exitWith {false};
if (count _this < 2) then {_context=[_group] call CBE_fnc_IndoorActorGroupContext};
if (count _context != 6 || {(_context select 0) isNotEqualTo _group}
    || {(_context select 1) isNotEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {(_context select 2) isNotEqualTo (_group getVariable ["CBE_OperationGeneration",0])}) exitWith {false};
_context params ["_contextGroup","_contextEpoch","_contextGeneration","_participants","_drillUnits","_supportHeld"];
if (!(_participants isEqualType []) || {!(_drillUnits isEqualType [])} || {!(_supportHeld isEqualType [])}
    || {count _participants > 64} || {count _drillUnits > 64} || {count _supportHeld > 64}) exitWith {false};
!(_actor in _participants) && {!(_actor in _drillUnits)} && {!(_actor in _supportHeld)}
