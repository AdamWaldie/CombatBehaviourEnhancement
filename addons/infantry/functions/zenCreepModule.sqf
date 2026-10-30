/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a squad and finite cautious-approach parameters at the module position.
 * Locality/authority: Interface dialog only; existing curator-authenticated server dispatch
 * validates named parameters and forwards to the current owner for real task admission.
 * Repeat/JIP: One accepted dialog sends one request; no persistent worker or task replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached actor OBJECT,objNull.
 * Return: BOOL, dialog opened, not task/physical circuit acceptance.
 * Current callers: optional ZEN registration and ModuleGarrison for CBE_ModuleCreep.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenCreepModule;
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
    ["CREEP","No selectable AI squad. Place on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
[
    "Cautious approach",
    [
        ["COMBO",["Squad","AI foot squad to cautiously approach its own native enemy belief. No known recent ground contact means refusal. The module location does not reveal enemies. Release existing tasks first."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Knowledge range (m)","Maximum believed contact distance, also capped by the CBA engagement range. No hidden enemy positions are read."],[50,2000,800,0]],
        ["SLIDER",["Task time limit (s)","Limited pace and self-defence fire discipline until stand-off or nearby danger, then original policies return. No posture/formation reset or permission to fire is forced."],[30,300,180,0]]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_range","_duration"];
        [[["order","CREEP"],["group",_group],["huntRange",round _range],
            ["creepDuration",round _duration]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true
