/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a squad and finite area-patrol task parameters at the module position.
 * Locality/authority: Interface dialog only; existing curator-authenticated server dispatch
 * validates named parameters and forwards to the current owner for real task admission.
 * Repeat/JIP: One accepted dialog sends one request; no persistent worker or task replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached actor OBJECT,objNull.
 * Return: BOOL, dialog opened, not task/physical circuit acceptance.
 * Current callers: optional ZEN registration and ModuleGarrison for CBE_ModulePatrol.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenPatrolModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"} || {count _position != 3}) exitWith {false};
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected=group _target;
    _groups=[_selected]+(_groups-[_selected]);
};
if (_groups isEqualTo []) exitWith {
    ["PATROL","No selectable AI squad. Place on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
[
    "Patrol area",
    [
        ["COMBO",["Squad","AI foot squad for one finite circuit. Existing tasks refuse; use Release infantry task first. The module position is the area centre."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Area radius (m)","Ground destinations stay within this radius. Normal engine paths may leave the area; inaccessible legs fail within their original budget."],[25,500,100,0]],
        ["SLIDER",["Circuit destinations","Number of ground destinations in one circuit. Existing formation, movement speed, combat mode and lights remain unchanged."],[3,8,4,0]],
        ["SLIDER",["Task time limit (s)","Total original deadline including combat suspension. Finite leg budgets also apply; elapsed time never counts as circuit completion."],[30,1800,900,0]]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_radius","_nodes","_duration"];
        [[["order","PATROL"],["group",_group],["position",_position],["radius",round _radius],
            ["patrolNodes",round _nodes],["patrolDuration",round _duration]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true
