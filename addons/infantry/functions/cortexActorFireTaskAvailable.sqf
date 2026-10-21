/*
 * Author: WaldoTheWarfighter
 * Purpose: Refuse scripted fire assignment while an actor has a protected native task or movement reservation.
 * Vehicle movement starts reuse the same native-task/reservation check for driver admission.
 * Locality/authority: Read-only on the actor owner. Callers retain health, ROE, station and target authority.
 * Repeat/JIP: No state changes or renewal; reads the current task on every admission and fire boundary.
 * Arguments: 0 actor <OBJECT, objNull>; 1 permitted finite fire-owner token STRING, empty.
 * Return: BOOL, true only for a local actor without a protected task or movement reservation.
 * Current callers: CortexCombinedArmsLocal, CortexCombinedGroundStep, CortexVehicles,
 * CortexAssaultStart, CortexFlankStart, CortexAdvanceStart, CortexTacticalAssess, ConvoyCrewLocal,
 * CortexVehicleOrient/Jink and orientation teardown.
 * Example: private _available=[gunner tank1] call CBE_fnc_CortexActorFireTaskAvailable;
 */
params [["_actor",objNull,[objNull]],["_fireOwner","",[""]]];
private _aaLease=_actor getVariable ["CBE_AA_InterceptOwner",[]];
if (_aaLease isNotEqualTo []) then {
    private _typed=_aaLease isEqualType [] && {count _aaLease == 2}
        && {(_aaLease select 0) isEqualType ""} && {(_aaLease select 1) isEqualType 0}
        && {finite (_aaLease select 1)};
    if (!_typed || {time < (_aaLease select 1) && {(_aaLease select 0) != _fireOwner}}) exitWith {_fireOwner="REFUSED"};
};
if (_fireOwner == "REFUSED") exitWith {false};
if (isNull _actor || {!local _actor}
    || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {[_actor] call CBE_fnc_CortexActorMoveReserved}) exitWith {false};
!(toUpperANSI currentCommand _actor in [
    "GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
    "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED",
    "ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"
])
