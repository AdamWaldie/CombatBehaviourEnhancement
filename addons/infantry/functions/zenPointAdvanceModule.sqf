/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a squad for an explicit advance or withdrawal task at the module position.
 * Locality/authority: Interface dialog only; existing curator-authenticated server dispatch
 * validates named parameters and forwards to the current owner for real task admission.
 * Repeat/JIP: One accepted dialog sends one request; no persistent worker or task replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached actor OBJECT,objNull;2 order STRING ADVANCE_POINT/WITHDRAW_POINT, default ADVANCE_POINT.
 * Return: BOOL, dialog opened, not task/physical arrival acceptance.
 * Current callers: optional ZEN registration and ModulePointAdvance for advance/withdrawal modules.
 * Example: [getPosATL soldier1,soldier1] call CBE_fnc_ZenPointAdvanceModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]],["_order","ADVANCE_POINT",[""]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"} || {count _position != 3}) exitWith {false};
if (!(_order in ["ADVANCE_POINT","WITHDRAW_POINT"])) exitWith {false};
private _withdraw=_order == "WITHDRAW_POINT";
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected=group _target;
    _groups=[_selected]+(_groups-[_selected]);
};
if (_groups isEqualTo []) exitWith {
    [_order,"No selectable AI squad. Place on an AI soldier to include its squad explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
private _help=if (_withdraw) then {
    "AI foot squad withdraws to this ground position. Fixed120s deadline and30m ground arrival;35..2000m from the squad. Existing tasks refuse; use Release infantry task first. Native orders retain priority."
} else {
    "AI foot squad uses covered fire-team bounds to this position. Existing tasks refuse; use Release infantry task first. No enemy is required or revealed."
};
private _fields=[
    ["COMBO",["Squad",_help],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]]
];
if (!_withdraw) then {
    _fields append [
        ["SLIDER",["Arrival radius (m)","Both fire teams must actually arrive; the capable cohort also stays within a25m-or-radius band at the destination floor."],[5,25,10,0]],
        ["SLIDER",["Task time limit (s)","Original total deadline. Eight approach chunks/64route points bound the task; retries never renew the episode."],[30,300,180,0]]
    ];
};
[
    ["Advance to position","Withdraw to position"] select _withdraw,
    _fields,
    {
        params ["_values","_context"];
        _context params ["_position","_order"];
        if (!(_order in ["ADVANCE_POINT","WITHDRAW_POINT"])) exitWith {};
        private _pairs=[["order",_order],["group",_values select 0],["position",_position]];
        if (_order == "ADVANCE_POINT") then {
            _pairs append [["arrivalRadius",round (_values select 1)],["pointDuration",round (_values select 2)]];
        };
        [_pairs,clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},[+_position,_order]
] call zen_dialog_fnc_create;
true
