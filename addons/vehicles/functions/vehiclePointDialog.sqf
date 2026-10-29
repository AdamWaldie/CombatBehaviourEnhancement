/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one actual AI land vehicle for a finite point task or exact release.
 * Locality/authority: Curator interface only; named request uses authenticated server dispatch
 * and current group/platform-owner admission. UI selection never grants movement authority.
 * Repeat/JIP: One modal dialog; cancel submits nothing. At most128 world vehicles are shown,
 * plus an explicitly attached platform. No recurring query, addon setting change or task replay.
 * Arguments: 0 position ATL ARRAY3,[];1 attached vehicle/crew OBJECT,objNull;
 * 2 release BOOL,false. Native defaults180s; optional ZEN exposes30..300s total duration.
 * Return: BOOL dialog opened, not owner/native/physical acceptance.
 * Current callers: ModuleVehiclePoint and optional ZEN registration.
 * Example: [[1200,1800,0],apc1,false] call CBE_fnc_VehiclePointDialog;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]],["_release",false,[true]]];
if (!hasInterface || {isNull findDisplay 312} || {count _position != 3}) exitWith {false};
disableSerialization;
if (!isNull _target && {_target isKindOf "CAManBase"}) then {_target=objectParent _target};
private _vehicles=vehicles;
_vehicles resize ((count _vehicles) min 128);
if (!isNull _target) then {_vehicles=[_target]+(_vehicles-[_target])};
_vehicles=_vehicles select {
    !isNull _x && {_x isKindOf "LandVehicle"} && {!(_x isKindOf "StaticWeapon")}
        && {if (_release) then {
            ((_x getVariable ["CBE_VehicleTacticalMove_Work",createHashMap]) getOrDefault ["kind",""]) == "POINT"
        } else {
            alive _x && {!isNull driver _x} && {!isPlayer driver _x}
                && {units group driver _x findIf {isPlayer _x} < 0}
        }}
};
if (_vehicles isEqualTo []) exitWith {
    ["VEHICLE TASK","No selectable AI vehicle. Place on an AI vehicle or its seated crew to include it explicitly.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;false
};
private _order=["VEHICLE_POINT","VEHICLE_POINT_RELEASE"] select _release;
private _title=["Position vehicle","Release vehicle position task"] select _release;
private _help=["Only the selected vehicle moves. Dry ground10..2000m away;10m arrival, original30..300s move/hold limit, then native handback. Passengers retain their orders.",
    "Requests retirement of this exact point task. No forced stop; unresolved native handback remains reserved."] select _release;
private _labels=_vehicles apply {format ["%1 / %2 / grid %3",getText (configOf _x >> "displayName"),groupId group effectiveCommander _x,mapGridPosition _x]};
if (!isNil "zen_dialog_fnc_create") exitWith {
    private _fields=[["COMBO",["AI vehicle",_help],[_vehicles,_labels,0]]];
    if (!_release) then {_fields pushBack ["SLIDER",["Total move/hold limit (s)","Arrival holds for the remaining original duration. Release can end it earlier. Stuck movement retires after30s without progress; retries do not renew the task."],[30,300,180,0]]};
    [_title,_fields,{
        params ["_values","_context"];
        _context params ["_position","_order","_release"];
        private _vehicle=_values select 0;
        private _group=if (_release) then {(_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap]) getOrDefault ["group",grpNull]} else {group driver _vehicle};
        private _pairs=[["order",_order],["group",_group],["vehicle",_vehicle]];
        if (!_release) then {_pairs append [["position",+_position],["pointDuration",round (_values select 1)]]};
        [_pairs,clientOwner] call CBE_fnc_CortexOrderDispatch;
    },{},[+_position,_order,_release]] call zen_dialog_fnc_create;
    true
};
private _curator=findDisplay 312;
if (!isNull displayChild _curator) exitWith {
    ["VEHICLE TASK","Close the current Zeus dialog before placing this task again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;false
};
private _display=_curator createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {false};
_display setVariable ["CBE_vehiclePointChoices",[_vehicles,+_position,_order,_release]];
private _width=0.64 min safeZoneW;
private _left=safeZoneX+(safeZoneW-_width)/2;private _top=safeZoneY+safeZoneH*0.28;
private _make={
    params ["_class","_id","_row","_height",["_text",""]];
    private _control=_display ctrlCreate [_class,_id];
    _control ctrlSetPosition [_left+0.02,_top+_row*safeZoneH,_width-0.04,_height*safeZoneH];
    _control ctrlSetText _text;_control ctrlCommit 0;_control
};
private _background=_display ctrlCreate ["RscText",-1];
_background ctrlSetPosition [_left,_top-0.02*safeZoneH,_width,0.39*safeZoneH];
_background ctrlSetBackgroundColor [0.06,0.07,0.06,0.98];_background ctrlCommit 0;
["RscText",-1,0,0.04,_title] call _make;
["RscText",-1,0.05,0.035,"AI vehicle"] call _make;
private _choice=["RscCombo",7201,0.09,0.045] call _make;
{_choice lbAdd _x} forEach _labels;_choice lbSetCurSel 0;_choice ctrlSetTooltip _help;
["RscText",-1,0.15,0.04,format ["Destination grid: %1",mapGridPosition _position]] call _make;
["RscText",-1,0.20,0.04,["10 m arrival / 180 s total move and hold","Exact task retirement; native proof may remain pending"] select _release] call _make;
private _start=["RscButton",7203,0.26,0.045,["Request position","Request release"] select _release] call _make;
private _cancel=["RscButton",7204,0.32,0.04,"Cancel"] call _make;
_cancel ctrlAddEventHandler ["ButtonClick",{(ctrlParent (_this select 0)) closeDisplay 2}];
_start ctrlAddEventHandler ["ButtonClick",{
    params ["_button"];
    private _display=ctrlParent _button;
    private _choices=_display getVariable ["CBE_vehiclePointChoices",[]];
    if (count _choices != 4) exitWith {};
    _choices params ["_vehicles","_position","_order","_release"];
    private _index=lbCurSel (_display displayCtrl 7201);
    if (_index < 0 || {_index >= count _vehicles}) exitWith {};
    private _vehicle=_vehicles select _index;
    if (isNull _vehicle) exitWith {};
    private _group=if (_release) then {(_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap]) getOrDefault ["group",grpNull]} else {group driver _vehicle};
    private _pairs=[["order",_order],["group",_group],["vehicle",_vehicle]];
    if (!_release) then {_pairs append [["position",+_position],["pointDuration",180]]};
    _button ctrlEnable false;
    if ([_pairs,clientOwner] call CBE_fnc_CortexOrderDispatch) then {_display closeDisplay 1} else {_button ctrlEnable true};
}];
ctrlSetFocus _choice;
true
