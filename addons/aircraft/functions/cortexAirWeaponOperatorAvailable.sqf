/*
 * Author: WaldoTheWarfighter
 * Purpose: Read whether an aircraft attack may command its selected weapon operator.
 * Locality/authority: Read-only on the aircraft, group and actor owner; no cross-group
 * crew authority is inferred from owning the pilot or the airframe.
 * Repeat/JIP: No state, handlers or timers; every call reads live crew/task ownership.
 * Arguments: 0 aircraft <OBJECT, objNull>; 1 attack group <GROUP, grpNull>;
 * 2 selected operator <OBJECT, objNull>. Callers retain exact station and flight-lease checks.
 * Return: BOOL, local combat-effective owned operator with no protected task/reservation,
 * specialist/player/remote control or individual BLUE/GREEN fire restriction.
 * Current callers: CortexAirAttackPlan and CortexAirAttack execution/Fired observation.
 * Example: [heli1,group driver heli1,gunner heli1] call WAIT_fnc_CortexAirWeaponOperatorAvailable;
 */
params [["_aircraft",objNull,[objNull]],["_group",grpNull,[grpNull]],["_operator",objNull,[objNull]]];
if (isNull _aircraft || {isNull _group} || {isNull _operator}
    || {!local _aircraft} || {!local _group} || {!local _operator}) exitWith {false};
alive _aircraft && {vehicle _operator == _aircraft} && {group _operator == _group}
    && {[_operator] call WAIT_fnc_CortexCombatEffective}
    && {simulationEnabled _operator} && {!isObjectHidden _operator}
    && {!isPlayer _operator} && {isNull remoteControlled _operator}
    && {isNull (_operator getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {([_operator] call WAIT_fnc_CortexExternalOwner) == ""}
    && {!([_operator] call WAIT_fnc_CompatibilityExternalControl)}
    && {!([_group,false,_operator] call WAIT_fnc_CortexExternalTakeover)}
    && {[_operator] call WAIT_fnc_CortexActorFireTaskAvailable}
    && {!(unitCombatMode _operator in ["BLUE","GREEN"])}
