/*
 * Author: WaldoTheWarfighter
 * Candidate ranking excludes common executor refusals before consuming bounded slots;
 * full START authority, native context and building checks remain mandatory.
 * Purpose: Admit up to two nearby individual indoor investigations from fresh native group knowledge
 * when the contact decision has not committed a whole-group clearance or coordinated task.
 * Locality/authority: Current group owner only. The actor executor revalidates all ownership,
 * native orders and feature gates before movement; this dispatcher issues no movement itself.
 * Repeat/JIP: At most one building selection per eight seconds per owner-local group state.
 * Sixteen actors and eight native beliefs are checked before the existing three-roof-query selector.
 * Shared native-task preflight adds no visibility/geometry query and grants no command authority.
 * Actor journals, hard deadlines and cooldowns prevent replay; locality does not resume old jobs.
 * Shared reservation admission permits valid expired markers but refuses live or malformed records.
 * Arguments: 0 group <GROUP>, grpNull; 1 group state <HASHMAP>, empty;
 * 2 native knowledge records <ARRAY>, [] (same format as BuildingContactSelect).
 * Return: NUMBER of newly admitted actors, 0..2; admission is not physical entry or clearance.
 * Current callers: CortexGroupTick CONTACT fallback after natural whole-group CLEAR admission.
 * Example: private _admitted=[_group,_state,_knowledge] call CBE_fnc_IndoorActorDispatch;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]]];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}
    || {!([_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {[_state,"indoorActors"] call CBE_fnc_CortexCooldown}) exitWith {0};
private _range=missionNamespace getVariable ["CBE_AIPass_BuildingCombat_Range",100];
if (!(_range isEqualType 0) || {!finite _range} || {_range <= 0}) exitWith {0};
[_state,"indoorActors",8] call CBE_fnc_CortexCooldown;
// Establish the available roster before choosing a contact. Otherwise an unavailable
// nearest contact can consume the selection while another nearby belief is actionable.
private _actors=((units _group) select [0,16]) select {
    local _x && {!isPlayer _x} && {[_x] call CBE_fnc_CortexCombatEffective}
        && {isNull objectParent _x} && {[_x] call CBE_fnc_IndoorActorGroupAvailable}
        // Cheap executor prerequisites keep ineligible nearby actors from consuming
        // the bounded candidate slots; START still repeats full authority admission.
        && {simulationEnabled _x} && {!isObjectHidden _x}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {getSuppression _x < 0.5} && {currentWeapon _x != ""}
        && {unitCombatMode _x in ["YELLOW","RED","WHITE"]}
        && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
        && {serverTime >= (_x getVariable ["CBE_IndoorActor_Cooldown",-1])}
};
if (_actors isEqualTo []) exitWith {0};
// CortexKnowledge supplies at most eight detailed records. Keep that explicit bound
// for direct callers too; only current native beliefs are used, never live positions.
private _actionable=(_enemies select [0,8]) select {
    private _record=_x;
    if !(_record isEqualType []) exitWith {false};
    private _target=_record param [0,objNull,[objNull]];
    private _position=_record param [1,[],[[]]];
    if (isNull _target || {count _position != 3}
        || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {false};
    _actors findIf {_x knowsAbout _target >= 1 && {_x distance2D _position <= (_range min 40)}
        && {([_x,_target,_position,objNull,true] call CBE_fnc_IndoorActorNativeContext) isNotEqualTo []}} >= 0
};
private _selection=[_group,_actionable,_range] call CBE_fnc_BuildingContactSelect;
if (_selection isEqualTo []) exitWith {0};
_selection params ["_building","_contact","_belief"];
private _ranked=[];
{
    if (_x knowsAbout _contact >= 1
        && {_x distance2D (_belief select 0) <= (_range min 40)}) then {
        // Prefer another available soldier over displacing the squad's leader/formation anchor.
        _ranked pushBack [[0,1] select (_x == leader _group),_x distance2D (_belief select 0),_forEachIndex];
    };
} forEach _actors;
_ranked sort true;
private _admitted=0;
{
    if (_admitted >= 2) exitWith {};
    private _actor=_actors select (_x select 2);
    private _accepted=["START",_actor,createHashMapFromArray [
        ["building",_building],["contact",_contact],["belief",_belief]
    ]] call CBE_fnc_IndoorActorOperation;
    if (_accepted) then {_admitted=_admitted+1};
} forEach _ranked;
_admitted