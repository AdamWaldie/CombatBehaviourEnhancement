/*
 * Author: WaldoTheWarfighter
 * Purpose: Select an explicit AI squad and request release of its CBE infantry tasks, including finite patrol.
 * Locality/authority: Interface dialog only. Existing server authentication, current-owner
 * serial/deadline/native-order checks and scoped release executors decide the actual result.
 * Repeat/JIP: One request per accepted dialog; no handler, task replay or addon setting changes.
 * No task-free squad, newer mission order or unrelated controller is reset by this dialog.
 * Arguments: 0 module position ATL ARRAY,[] (unused by release); 1 attached actor OBJECT,objNull.
 * Return: BOOL, dialog opened, not native handback or physical formation recovery.
 * Current callers: optional ZEN registration and ModuleGarrison for CBE_ModuleRelease.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenReleaseModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"}) exitWith {false};
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected=group _target;
    _groups=[_selected]+(_groups-[_selected]);
};
if (_groups isEqualTo []) exitWith {
    ["RELEASE TASK","No selectable AI squad. Place the module on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
[
    "Release infantry task",
    [
        ["COMBO",["Squad","Request release of CBE clearance, garrison, defensive-line, patrol and temporary infantry actor tasks. The current owner preserves newer orders and protected actors. Pending native handback may remain unresolved."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]]
    ],
    {
        params ["_values"];
        _values params ["_group"];
        [[["order","RELEASE"],["group",_group]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},[]
] call zen_dialog_fnc_create;
true
