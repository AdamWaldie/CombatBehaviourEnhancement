/*
 * Author: WaldoTheWarfighter
 * Selects and starts one viable local infantry manoeuvre from the squad's live tactical context.
 *
 * CBE_fnc_CortexTacticalAssess first distinguishes close infantry, authored forward movement,
 * armour overmatch, fortified or elevated positions, and open versus concealed approaches. It
 * returns at most two candidate intents and one already-known contact. This dispatcher tries those
 * candidates in order, so a failed avenue or cooldown can immediately fall back without leaving a
 * capable squad idle. The assessment is deterministic from live evidence; no random permission
 * roll, scheduled assembly or separate tactical worker is introduced.
 *
 * Locality and authority: call only where the group is local. It reads the current server-published
 * feature gates and the live authored order/contact context, then delegates to owner-local starts.
 * Repeat/JIP: start functions reject active leases, drills and cooldowns, so repeated calls are safe.
 * Publishes one completed assessment per invocation; successful fallback records its actual intent.
 * Feature and order changes apply on the next group tick; no state is replayed to JIP clients.
 *
 * Arguments:
 * 0: group <GROUP> - local infantry group in contact
 * 1: state <HASHMAP> - current Cortex group state
 * 2: enemies <ARRAY> - current CBE_fnc_CortexKnowledge result
 * 3: flank enabled <BOOL> - authoritative live feature gate (default true)
 * 4: advance enabled <BOOL> - authoritative live feature gate (default true)
 * 5: assault enabled <BOOL> - authoritative live feature gate (default true)
 *
 * Return Value:
 * Boolean - true when either manoeuvre started
 *
 * Current caller: CBE_fnc_CortexGroupTick.
 *
 * Example:
 * private _started = [_group, _state, _enemies, true, true, true] call CBE_fnc_CortexTacticalStart;
 * Result: Cortex follows the live objective/contact context and immediately tries the other viable
 * manoeuvre if the first cannot start.
 */

params [
    ["_group", grpNull, [grpNull]],
    ["_state", createHashMap, [createHashMap]],
    ["_enemies", [], [[]]],
    ["_flankEnabled", true, [true]],
    ["_advanceEnabled", true, [true]],
    ["_assaultEnabled", true, [true]]
];
if (isNull _group || {!local _group}) exitWith {false};

if (!_flankEnabled && {!_advanceEnabled} && {!_assaultEnabled}) exitWith {false};
private _assessment=[_group,_state,_enemies,_flankEnabled,_advanceEnabled,_assaultEnabled] call CBE_fnc_CortexTacticalAssess;
private _intent=_assessment getOrDefault ["intent","HOLD"];
private _reason=_assessment getOrDefault ["reason","NO_VIABLE_CONTACT"];
private _targetIndex=_assessment getOrDefault ["targetIndex",-1];
private _candidates=_assessment getOrDefault ["candidates",[]];
private _evidence=_assessment getOrDefault ["evidence",[]];
if (_targetIndex < 0 || {_candidates isEqualTo []}) exitWith {
    private _handoff=switch (_reason) do {
        case "VEHICLE_DOMAIN": {"VEHICLE_LAYER_HANDOFF"};
        case "ACTOR_TASKS_BUSY": {"ACTOR_TASK_HANDOFF"};
        case "MORALE_NOT_STEADY": {"MORALE_HANDOFF"};
        case "NO_MANOEUVRE_TARGET": {"WEAPON_LAYER_HANDOFF"};
        case "NO_VIABLE_CONTACT": {"NATIVE_CONTACT_HANDOFF"};
        default {"NATIVE_COMBAT_HANDOFF"};
    };
    _group setVariable ["CBE_Cortex_TacticalAssessment",[
        _intent,_reason,serverTime,_evidence,_enemies apply {_x param [0,objNull,[objNull]]},_handoff
    ],true];
    false
};
private _prioritiseContact={
    params ["_contacts","_index"];
    if (_index <= 0) exitWith {+_contacts};
    [_contacts select _index]
        + (_contacts select [0,_index])
        + (_contacts select [_index+1])
};
private _orderedEnemies=[_enemies,_targetIndex] call _prioritiseContact;
private _started=false;
{
    switch (_x) do {
        case "ASSAULT": {_started=[_group,_state,_orderedEnemies] call CBE_fnc_CortexAssaultStart};
        case "FLANK": {_started=[_group,_state,_orderedEnemies] call CBE_fnc_CortexFlankStart};
        case "ADVANCE": {_started=[_group,_state,_orderedEnemies] call CBE_fnc_CortexAdvanceStart};
        case "REPOSITION": {_started=[_group,_state,_orderedEnemies,0,_reason] call CBE_fnc_CortexTacticalReposition};
    };
    if (_started) exitWith {_intent=_x};
} forEach _candidates;
// A viable manoeuvre can still be rejected by terrain, a live-fire lane or a temporary role loss.
// Do not convert that refusal into an unexplained pause: make one short screened improvement and
// reassess from there. The helper is generation-owned and cooldown-bound, so it cannot churn routes.
if (!_started && {!(_intent in ["HOLD","REPOSITION"])} && {_orderedEnemies isNotEqualTo []}) then {
    _started=[_group,_state,_orderedEnemies,0,"NO_SAFE_MANOEUVRE"] call CBE_fnc_CortexTacticalReposition;
    if (_started) then {
        _intent="REPOSITION";
        _reason="NO_SAFE_MANOEUVRE";
    };
};
// Publish only the completed decision, once. A rejected primary candidate must not
// remain the reported intent after another candidate starts successfully.
_group setVariable ["CBE_Cortex_TacticalAssessment",[
    _intent,_reason,serverTime,_evidence,_enemies apply {_x param [0,objNull,[objNull]]},
    ["NATIVE_REASSESS","STARTED"] select _started
],true];
_started
