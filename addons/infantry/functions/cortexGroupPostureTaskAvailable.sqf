/*
 * Author: WaldoTheWarfighter
 * Purpose: Check the complete native task/domain footprint before a group-wide posture write.
 * Locality/authority: Read-only, current group owner. This is not movement, fire or external-owner
 * consent; callers must retain those authority and exact native-receipt checks separately.
 * Repeat/JIP: Stateless. At most64 members; oversized groups refuse rather than sample an
 * incomplete footprint. No worker, query of other groups, native command or state mutation.
 * Living mounted, nonlocal, incapacitated/captive, stealth/careless, hold-fire, fleeing or native
 * service-task members keep their policy. Ordinary native travel and CBE manoeuvre remain eligible.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return: BOOL - all living members support this narrow group-posture task boundary.
 * Current callers: DangerReact application and exact restoration.
 * Example: private _free=[group soldier1] call CBE_fnc_CortexGroupPostureTaskAvailable;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {false};
private _members=units _group;
if (_members isEqualTo [] || {count _members > 64}) exitWith {false};
_members findIf {
    alive _x && {!local _x || {isPlayer _x} || {!isNull objectParent _x}
        || {!([_x] call CBE_fnc_CortexCombatEffective)} || {fleeing _x}
        || {behaviour _x in ["CARELESS","STEALTH"]}
        || {unitCombatMode _x in ["BLUE","GREEN"]}
        || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
        || {toUpperANSI currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
            "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
            "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}}
} < 0
