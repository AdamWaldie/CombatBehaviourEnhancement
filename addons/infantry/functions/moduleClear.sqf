/*
 * Author: WaldoTheWarfighter
 * Purpose: Native Zeus physical-clearance task with explicit squad/building selectors.
 * Locality/authority: Curator interface only; authenticated CortexOrderDispatch and the
 * current group owner's existing CortexClearBuilding own validation and all AI commands.
 * Repeat/JIP: Disposable placement; one modal display, no task on cancel or historical replay.
 * Optional ZEN uses the existing labelled dialog. Native fallback keeps choices on its display;
 * it never guesses a squad/building, changes addon settings or installs a recurring worker.
 * Arguments: 0 logic OBJECT objNull; 1 synced units ARRAY []; 2 activated BOOL true.
 * Return: BOOL dialog admitted, not request acceptance, traversal or hostile-room clearance.
 * Current callers: CBE_ModuleClear curator module.
 * Example: [clearLogic,[],true] call CBE_fnc_ModuleClear;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}
    || {_logic getVariable ["CBE_processed",false]}) exitWith {false};
disableSerialization;
_logic setVariable ["CBE_processed",true];
private _position=getPosATL _logic;
private _target=attachedTo _logic;
deleteVehicle _logic;
if (!isNil "zen_dialog_fnc_create") exitWith {[_position,_target] call CBE_fnc_ZenClearModule};
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected=group _target;
    _groups=[_selected]+(_groups-[_selected]);
};
private _buildings=nearestObjects [_position,["House"],150,true];
_buildings resize ((count _buildings) min 128);
_buildings=_buildings select {alive _x && {(_x buildingPos -1) isNotEqualTo []}};
if (!isNull _target && {_target isKindOf "House"} && {alive _target}
    && {(_target buildingPos -1) isNotEqualTo []}) then {
    _buildings=[_target]+(_buildings-[_target]);
};
if (_groups isEqualTo [] || {_buildings isEqualTo []}) exitWith {
    ["CLEAR","No selectable AI squad or building reporting interior positions. Place near the intended building or on its squad.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
private _curator=findDisplay 312;
if (isNull _curator) exitWith {false};
// createDisplay replaces an existing child. Never destroy another active Zeus dialog.
if (!isNull (displayChild _curator)) exitWith {
    ["CLEAR","Close the current Zeus dialog before placing Clear building again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
private _display=_curator createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {false};
_display setVariable ["CBE_clearChoices",[_groups,_buildings,+_position]];
private _width=0.56 min safeZoneW;
private _left=safeZoneX+(safeZoneW-_width)/2;
private _top=safeZoneY+safeZoneH*0.28;
private _verticalScale=safeZoneH;
private _make={
    params ["_class","_id","_row","_height",["_text",""]];
    private _control=_display ctrlCreate [_class,_id];
    _control ctrlSetPosition [_left+0.02,_top+_row*_verticalScale,_width-0.04,_height*_verticalScale];
    _control ctrlSetText _text;
    _control ctrlCommit 0;
    _control
};
private _background=_display ctrlCreate ["RscText",-1];
_background ctrlSetPosition [_left,_top-0.02*_verticalScale,_width,0.43*_verticalScale];
_background ctrlSetBackgroundColor [0.06,0.07,0.06,0.98];_background ctrlCommit 0;
["RscText",-1,0,0.04,"Clear building"] call _make;
["RscText",-1,0.05,0.035,"AI squad"] call _make;
private _squad=["RscCombo",7101,0.09,0.045] call _make;
{_squad lbAdd format ["%1 / %2",side _x,groupId _x]} forEach _groups;
_squad lbSetCurSel 0;
["RscText",-1,0.15,0.035,"Building"] call _make;
private _house=["RscCombo",7102,0.19,0.045] call _make;
{
    private _name=getText (configOf _x >> "displayName");
    if (_name == "") then {_name=typeOf _x};
    _house lbAdd format ["%1 / %2 m",_name,round (_position distance2D _x)];
} forEach _buildings;
_house lbSetCurSel 0;
_house ctrlSetTooltip "Reported interior points may be inaccessible. The owner records physical visits and partial failures; task acceptance does not mean a building is safe.";
_squad ctrlSetTooltip "Select the exact AI squad. Server and current owner revalidate curator authority and native task eligibility.";
private _start=["RscButton",7103,0.29,0.045,"Request clearance"] call _make;
private _cancel=["RscButton",7104,0.35,0.04,"Cancel"] call _make;
_cancel ctrlAddEventHandler ["ButtonClick",{(ctrlParent (_this select 0)) closeDisplay 2}];
_start ctrlAddEventHandler ["ButtonClick",{
    params ["_button"];
    private _display=ctrlParent _button;
    private _choices=_display getVariable ["CBE_clearChoices",[]];
    if (count _choices != 3) exitWith {};
    _choices params ["_groups","_buildings","_position"];
    private _groupIndex=lbCurSel (_display displayCtrl 7101);
    private _houseIndex=lbCurSel (_display displayCtrl 7102);
    if (_groupIndex < 0 || {_groupIndex >= count _groups}
        || {_houseIndex < 0} || {_houseIndex >= count _buildings}) exitWith {};
    private _group=_groups select _groupIndex;
    private _building=_buildings select _houseIndex;
    if (isNull _group || {isNull _building} || {!alive _building}) exitWith {
        ["CLEAR","Selected squad or building is no longer available. Close and place the task again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
    _button ctrlEnable false;
    private _request=[[["order","CLEAR"],["group",_group],["building",_building],
        ["position",_position]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    if (_request) then {_display closeDisplay 1} else {
        _button ctrlEnable true;
        ["CLEAR","Clearance request was refused. Check curator authority and the selected squad/building.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
}];
ctrlSetFocus _squad;
true
