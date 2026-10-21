/*
 * Author: WaldoTheWarfighter
 * Target identity respects native ignoreTarget policy; no ignore setting is changed.
 * Purpose: Classifies a coalesced danger observation for the native AI and CBE diagnostics without
 * creating a second target, route, firing or movement owner.
 * Locality/authority: Runs on the current group owner after CBE_fnc_DangerSelect has already bounded
 * and validated an observation. It reads one bounded living group representative and an existing operation.
 * Retained hostile identity requires the original local source witness to retain native knowledge.
 * Repeat/JIP: Pure selection with no side effects. The caller publishes the finite result with its
 * generation, so a new owner reconstructs it from a fresh local observation.
 * Arguments: 0: group <GROUP>; 1: selected event <ARRAY>
 * [cause, position, observedAt, expires, optional hostile source, optional response observer,
 * optional source observer].
 * Return Value: STRING - RELEASE, FORCED, MAINTAIN, VEHICLE, HIDE or ENGAGE.
 * Current callers: CBE_fnc_DangerStep, CBE_fnc_OperationCancel and CBE_fnc_OperationRelease.
 * Example: [group player,["SUPPRESSED",getPosATL player,time,time + 2]] call CBE_fnc_DangerActionSelect;
 */

params [["_group",grpNull,[grpNull]], ["_event",[],[[]]]];
if (isNull _group || {!local _group} || {!(count _event in [4,5,6,7])}) exitWith {"RELEASE"};
// This is intentionally the same handover boundary used by the danger FSM, operation cleanup and
// vehicle helpers. Keeping local copies here allowed a newly-recognised owner (for example a player
// in the group) to receive a reaction after the other danger paths had already yielded.
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {"RELEASE"};
private _actor=_event param [5,objNull,[objNull]];
// An explicit witness carries response-domain ownership. Its loss cannot be repaired by
// substituting a foot leader for a crew member or an unrelated surviving soldier.
if (count _event >= 6 && {!([_actor] call CBE_fnc_CortexCombatEffective)
    || {!local _actor} || {group _actor != _group}}) exitWith {"RELEASE"};
// Only older position-only callers intentionally use the current group representative.
if (count _event < 6) then {
    _actor=[_group] call CBE_fnc_CortexGroupAnchor;
    if (isNull _actor) then {_actor=leader _group};
};
if (!([_actor] call CBE_fnc_CortexCombatEffective) || {!local _actor} || {isPlayer _actor}
    || {group _actor != _group}
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}) exitWith {"RELEASE"};
// A concrete native task remains authoritative through the group handoff as well as the immediate
// engine branch. ATTACK is deliberately absent: Arma also assigns it during ordinary autonomous
// combat, and CBE's response changes only a finite posture while native targeting and movement stay
// authoritative. Zeus, players and declared external owners have already yielded above.
if ((_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []
    || {fleeing _actor} || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {"FORCED"};
private _cause=_event select 0;
private _source=_event param [4,objNull,[objNull]];
private _sourceObserver=_event param [6,_actor,[objNull]];
private _sourceIgnored=!isNull _source && {!isNull _sourceObserver} && {local _sourceObserver}
    && {group _sourceObserver == _group}
    && {(_sourceObserver targetKnowledge _source) param [7,false,[true]]};
if (_sourceIgnored && {_cause in ["DETECTED","PROXIMITY","CANFIRE"]}) exitWith {"RELEASE"};
if (!isNull objectParent _actor) exitWith {"VEHICLE"};
// Detection, proximity, a firing opportunity and audible fire require the native-known hostile
// retained in the event before they can become an engagement. Resolve this before MAINTAIN: an
// approximate observation during an existing operation may preserve that route, but it cannot gain
// CONTACT authority merely because CBE already owns movement.
// A retained identity is not permanent hostility. Zeus/mission side changes and surrender
// invalidate engagement authority even while native knowledge still remembers that object.
if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {!isNull _source}
    && {_source isKindOf "Logic" || {_source isKindOf "HeadlessClient_F"} || {!alive _source} || {captive _source}
        || {_source getVariable ["ace_captives_isSurrendering",false]}
        || {_source getVariable ["ace_captives_isHandcuffed",false]}
        || {(side _group) getFriend (side _source) >= 0.6}}) exitWith {"RELEASE"};
if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]
    && {isNull (_event param [4,objNull,[objNull]])}) exitWith {"HIDE"};
// Identity belongs to the original native knowledge witness, not whichever actor
// currently represents the group. Lost knowledge leaves an approximate alert only.
if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]
    && {!([_sourceObserver] call CBE_fnc_CortexCombatEffective)
        || {!local _sourceObserver} || {group _sourceObserver != _group}
        || {_sourceObserver knowsAbout _source <= 0} || {_sourceIgnored}}) exitWith {"HIDE"};
// A current operation has already committed a physical route and owns its restoration. A danger
// event raises its priority but must not send the group back to an earlier reaction position.
if (count (_group getVariable ["CBE_Operation",createHashMap]) > 0) exitWith {"MAINTAIN"};
if (_cause in ["HIT","EXPLOSION","SUPPRESSED","SCREAM","CASUALTY","BODY_FOUND"]) exitWith {"HIDE"};
"ENGAGE"
