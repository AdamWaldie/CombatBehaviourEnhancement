/*
 * Author: WaldoTheWarfighter
 * Purpose: Reports whether a group is currently under player, direct curator remote, specialist or explicitly
 * declared external control, including active curator garrison/suppression orders. Cleanup uses this narrow question instead of broad eligibility so a
 * CBE feature shutdown can restore its own holds without writing into another controller's order.
 * Locality / Authority: Read-only and callable on any machine; callers still issue commands only
 * on the current group owner.
 * Repeat/JIP: Re-evaluates live ownership markers on every call and changes no public state.
 * Current occupied platforms share declared ownership with their crew. One local per-call set
 * deduplicates platforms; no assigned-vehicle inheritance, world query or retained permission.
 * Arguments:
 * 0: group <GROUP>, default grpNull.
 * 1: ignore temporary Zeus hold <BOOL>, default false. Direct remote control and all other
 *    external ownership still take priority when true.
 * 2: actor-local context <OBJECT>, objNull. A valid member narrows specialist checks to that actor;
 * player, curator and explicit group ownership remain group-wide. Group command callers omit it.
 * Return Value: Boolean - true when CBE must not restore formation, posture or combat state.
 * Current callers: explicit-order, regroup, convoy, support and delegated-building cleanup.
 * Example: if ([group soldier1] call CBE_fnc_CortexExternalTakeover) exitWith {};
 * Result: a cleanup routine removes its own state without replacing a curator's order.
 */

params [["_group",grpNull,[grpNull]], ["_ignoreZeusHold",false,[true]], ["_actorContext",objNull,[objNull]]];
if (isNull _group) exitWith {true};
// This is called immediately before every CBE command boundary. Cache the membership once and
// evaluate specialist ownership once per actor; the leader is a group member, so a separate
// leader probe only duplicated configuration and marker reads on the most frequent path.
private _members=units _group;
if (!isNull _actorContext && {group _actorContext != _group}) exitWith {true};
private _specialistSubjects=if (isNull _actorContext) then {_members} else {[_actorContext]};

// One cheap group footprint pass precedes the scoped specialist/platform pass.
// Keep these fresh per call: a cached result is not command authority.
private _directTakeover=_members findIf {
    isPlayer _x || {!isNull (remoteControlled _x)}
        || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
} >= 0;
_directTakeover
|| {!_ignoreZeusHold && {[_group] call CBE_fnc_CortexZeusHeld}}
|| {
    private _checkedPlatforms=[];
    _specialistSubjects findIf {
        if ((_x getVariable ["zen_ai_garrisoned",false])
            || {_x getVariable ["zen_ai_isSuppressing",false]}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}) exitWith {true};
        // Current occupancy only; actor-scoped calls retain their narrow footprint.
        private _platform=objectParent _x;
        if (isNull _platform || {_platform in _checkedPlatforms}) exitWith {false};
        _checkedPlatforms pushBack _platform;
        [_platform] call CBE_fnc_CompatibilityExternalControl
    } >= 0
}
|| {[_group] call CBE_fnc_CompatibilityExternalControl}
