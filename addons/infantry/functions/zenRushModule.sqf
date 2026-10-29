/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a squad and finite Press attack parameters at the module position.
 * Locality/authority: Interface dialog only; existing curator-authenticated server dispatch
 * validates named parameters and forwards to the current owner for real task admission.
 * Repeat/JIP: One accepted dialog sends one request; no persistent worker or task replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached actor OBJECT,objNull.
 * Return: BOOL, dialog opened, not task/physical circuit acceptance.
 * Current callers: optional ZEN registration and ModuleGarrison for CBE_ModuleRush.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenRushModule;
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
    ["PRESS ATTACK","No selectable AI squad. Place on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
[
    "Press attack",
    [
        ["COMBO",["Squad","AI foot squad for a finite covered advance or close assault toward viable fresh native contact. Roles, morale, threat counters and mission/Zeus orders remain authoritative. Release existing tasks first."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Knowledge range (m)","Maximum native contact distance, capped by CBA engagement range. No hidden enemy positions are read; static/vehicle threats retain existing tactical safeguards."],[50,2000,800,0]],
        ["SLIDER",["Task time limit (s)","Original time limit for the accepted existing tactical drill. It is never renewed. The task does not disable native danger/FSM, force attack policy globally or prove an enemy/room is clear."],[30,300,180,0]]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_range","_duration"];
        [[["order","RUSH"],["group",_group],["huntRange",round _range],
            ["rushDuration",round _duration]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true
