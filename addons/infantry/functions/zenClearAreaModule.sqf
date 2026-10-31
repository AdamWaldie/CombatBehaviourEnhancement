/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a squad and finite area-clearance task parameters at the module position.
 * Locality/authority: Interface dialog only; existing curator-authenticated server dispatch
 * validates named parameters and forwards to the current owner for real task admission.
 * Repeat/JIP: One accepted dialog sends one request; no persistent worker or task replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached actor OBJECT,objNull.
 * Return: BOOL, dialog opened, not task/traversal acceptance.
 * Current callers: optional ZEN registration and ModuleGarrison for CBE_ModuleClearArea.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenClearAreaModule;
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
    ["CLEAR_AREA","No selectable AI squad. Place on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
[
    "Clear buildings in area",
    [
        ["COMBO",["Squad","AI foot squad for one finite building queue. Existing tasks refuse; use Release infantry task first. The module position is the area centre."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Area radius (m)","Candidate buildings are within this radius. A fixed bounded queue is chosen once; changed or inaccessible buildings retain incomplete results."],[10,150,50,0]],
        ["SLIDER",["Building limit","At most this many buildings are selected. More candidates than this limit produce PARTIAL, not whole-area completion."],[1,8,4,0]],
        ["SLIDER",["Task time limit (s)","Original total deadline, including every child approach/entry/sweep/egress. Inaccessible positions and refused buildings remain incomplete; elapsed time never counts as a visit."],[30,1800,900,0]]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_radius","_nodes","_duration"];
        [[["order","CLEAR_AREA"],["group",_group],["position",_position],["radius",round _radius],
            ["areaBuildings",round _nodes],["areaDuration",round _duration]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true
