/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a squad and finite covered point-advance task parameters at the module position.
 * Locality/authority: Interface dialog only; existing curator-authenticated server dispatch
 * validates named parameters and forwards to the current owner for real task admission.
 * Repeat/JIP: One accepted dialog sends one request; no persistent worker or task replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached actor OBJECT,objNull.
 * Return: BOOL, dialog opened, not task/physical arrival acceptance.
 * Current callers: optional ZEN registration and ModuleGarrison for CBE_ModulePointAdvance.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenPointAdvanceModule;
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
    ["ADVANCE_POINT","No selectable AI squad. Place on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
[
    "Advance to position",
    [
        ["COMBO",["Squad","AI foot squad for covered fire-team bounds to this position. Existing tasks refuse; use Release infantry task first. The module position is the destination. No enemy is required or revealed."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Arrival radius (m)","Both fire teams must actually arrive; capable participating actors also stay within a25m-or-radius cohort and the destination floor band. Arrival is not hostile-room clearance."],[5,25,10,0]],
        ["SLIDER",["Task time limit (s)","Original total deadline. Eight approach chunks/64route points also bound the task; no new pursuit worker or retry renewal."],[30,300,180,0]]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_radius","_duration"];
        [[["order","ADVANCE_POINT"],["group",_group],["position",_position],["arrivalRadius",round _radius],
            ["pointDuration",round _duration]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true
