/*
 * Author: WaldoTheWarfighter
 * Purpose: Native Zeus covered point-advance task with an explicit squad selector.
 * Locality/authority: Curator interface only; authenticated CortexOrderDispatch and the
 * current group owner's PointAdvanceOperation and existing drill own validation and all AI commands.
 * Repeat/JIP: Disposable placement; one modal display, no task on cancel or historical replay.
 * Optional ZEN uses the existing labelled dialog. Native fallback keeps choices on its display;
 * it never guesses a squad or invents an enemy, changes addon settings or installs a recurring worker.
 * Arguments: 0 logic OBJECT objNull; 1 synced units ARRAY []; 2 activated BOOL true.
 * Return: BOOL dialog admitted, not request acceptance, physical arrival or hostile-room clearance.
 * Current callers: CBE_ModulePointAdvance curator module.
 * Example: [advanceLogic,[],true] call CBE_fnc_ModulePointAdvance;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}
    || {_logic getVariable ["CBE_processed",false]}) exitWith {false};
disableSerialization;
_logic setVariable ["CBE_processed",true];
private _position=getPosATL _logic;
private _target=attachedTo _logic;
deleteVehicle _logic;
if (!isNil "zen_dialog_fnc_create") exitWith {[_position,_target] call CBE_fnc_ZenPointAdvanceModule};
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
private _curator=findDisplay 312;
if (isNull _curator) exitWith {false};
// createDisplay replaces an existing child. Never destroy another active Zeus dialog.
if (!isNull (displayChild _curator)) exitWith {
    ["ADVANCE_POINT","Close the current Zeus dialog before placing Advance to position again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
private _display=_curator createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {false};
_display setVariable ["CBE_pointAdvanceChoices",[_groups,+_position]];
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
["RscText",-1,0,0.04,"Advance to position"] call _make;
["RscText",-1,0.05,0.035,"AI squad"] call _make;
private _squad=["RscCombo",7101,0.09,0.045] call _make;
{_squad lbAdd format ["%1 / %2",side _x,groupId _x]} forEach _groups;
_squad lbSetCurSel 0;
["RscText",-1,0.15,0.04,format ["Destination grid: %1",mapGridPosition _position]] call _make;
["RscText",-1,0.20,0.04,"10 m arrival radius / 180 s time limit"] call _make;
_squad ctrlSetTooltip "Select the exact AI squad. Server and current owner revalidate curator authority and native task eligibility.";
private _start=["RscButton",7103,0.29,0.045,"Request advance"] call _make;
private _cancel=["RscButton",7104,0.35,0.04,"Cancel"] call _make;
_cancel ctrlAddEventHandler ["ButtonClick",{(ctrlParent (_this select 0)) closeDisplay 2}];
_start ctrlAddEventHandler ["ButtonClick",{
    params ["_button"];
    private _display=ctrlParent _button;
    private _choices=_display getVariable ["CBE_pointAdvanceChoices",[]];
    if (count _choices != 2) exitWith {};
    _choices params ["_groups","_position"];
    private _groupIndex=lbCurSel (_display displayCtrl 7101);
    if (_groupIndex < 0 || {_groupIndex >= count _groups}) exitWith {};
    private _group=_groups select _groupIndex;
    if (isNull _group) exitWith {
        ["ADVANCE_POINT","Selected squad is no longer available. Close and place the task again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
    _button ctrlEnable false;
    private _request=[[["order","ADVANCE_POINT"],["group",_group],["position",_position],
        ["arrivalRadius",10],["pointDuration",180]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    if (_request) then {_display closeDisplay 1} else {
        _button ctrlEnable true;
        ["ADVANCE_POINT","Advance request was refused. Check curator authority, squad readiness and the destination.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
}];
ctrlSetFocus _squad;
true
