/*
 * Author: WaldoTheWarfighter
 * Purpose: Native Zeus garrison task choices for squad, radius, placement and post preference.
 * Locality/authority: Interface only; confirmation sends a named task payload through
 * CortexOrderDispatch. The server authenticates the curator and the current group owner
 * validates and executes existing CortexGarrison work. This helper commands no AI.
 * Repeat/JIP: One display-local choice snapshot, revalidated on confirmation. Cancel sends
 * nothing. Existing Zeus child dialogs are preserved. No worker, settings change or JIP replay.
 * Walking,50m radius and higher positions are defaults. Instant placement is an explicit
 * task option for interior defenders; exterior security still walks. It does not clear rooms.
 * Arguments: 0 area centre ATL ARRAY,[]; 1 attached AI soldier OBJECT,objNull.
 * Return: BOOL dialog opened, not authenticated acceptance or physical occupation.
 * Current callers: ModuleGarrison when optional ZEN is unavailable.
 * Example: [getPosATL house1,soldier1] call CBE_fnc_GarrisonTaskDialog;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {isNull _target} || {!(_target isKindOf "CAManBase")} || {isPlayer _target}) exitWith {false};
disableSerialization;
private _curator=findDisplay 312;
if (isNull _curator) exitWith {false};
if (!isNull (displayChild _curator)) exitWith {
    ["GARRISON","Close the current Zeus dialog before placing Garrison area again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
// One bounded choice snapshot; the attached squad is always included explicitly.
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
private _selected=group _target;
_groups=[_selected]+(_groups-[_selected]);
private _radii=[15,25,50,75,100,150];
private _placements=[false,true];
private _heights=[true,false];
private _display=_curator createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {false};
_display setVariable ["CBE_garrisonChoices",[_groups,_radii,_placements,_heights,+_position]];
private _width=0.62 min safeZoneW;
private _left=safeZoneX+(safeZoneW-_width)/2;
private _top=safeZoneY+safeZoneH*0.16;
private _verticalScale=safeZoneH;
private _make={
    params ["_class","_id","_row","_height",["_text",""]];
    private _control=_display ctrlCreate [_class,_id];
    _control ctrlSetPosition [_left+0.02,_top+_row*_verticalScale,_width-0.04,_height*_verticalScale];
    _control ctrlSetText _text;_control ctrlCommit 0;
    _control
};
private _background=_display ctrlCreate ["RscText",-1];
_background ctrlSetPosition [_left,_top-0.02*_verticalScale,_width,0.66*_verticalScale];
_background ctrlSetBackgroundColor [0.06,0.07,0.06,0.98];_background ctrlCommit 0;
["RscText",-1,0,0.04,"Garrison area"] call _make;
["RscText",-1,0.05,0.035,"AI squad"] call _make;
private _squad=["RscCombo",7161,0.09,0.045] call _make;
{_squad lbAdd format ["%1 / %2",side _x,groupId _x]} forEach _groups;
_squad lbSetCurSel 0;
_squad ctrlSetTooltip "Select the exact AI squad. Server and owner revalidate task authority and current orders.";
["RscText",-1,0.15,0.035,"Area radius (m)"] call _make;
private _radius=["RscCombo",7162,0.19,0.045] call _make;
{_radius lbAdd str _x} forEach _radii;
_radius lbSetCurSel 2;
_radius ctrlSetTooltip "Search buildings around this module position. Surplus soldiers receive exterior security assignments.";
["RscText",-1,0.25,0.035,"Placement"] call _make;
private _placement=["RscCombo",7163,0.29,0.045] call _make;
{_placement lbAdd _x} forEach ["Walk into positions","Instant interior placement"];
_placement lbSetCurSel 0;
_placement ctrlSetTooltip "Walking uses native approaches. Instant placement moves eligible interior defenders once; exterior security still walks. Neither mode clears hostile rooms.";
["RscText",-1,0.35,0.035,"Interior post preference"] call _make;
private _height=["RscCombo",7164,0.39,0.045] call _make;
{_height lbAdd _x} forEach ["Higher positions first","Random roofed-first distribution"];
_height lbSetCurSel 0;
_height ctrlSetTooltip "Height preference changes post selection, not route accessibility. Inaccessible posts remain subject to the existing bounded failure policy.";
private _start=["RscButton",7165,0.49,0.045,"Request garrison"] call _make;
private _cancel=["RscButton",7166,0.55,0.04,"Cancel"] call _make;
_cancel ctrlAddEventHandler ["ButtonClick",{(ctrlParent (_this select 0)) closeDisplay 2}];
_start ctrlAddEventHandler ["ButtonClick",{
    params ["_button"];
    private _display=ctrlParent _button;
    private _choices=_display getVariable ["CBE_garrisonChoices",[]];
    if (count _choices != 5) exitWith {};
    _choices params ["_groups","_radii","_placements","_heights","_position"];
    private _indices=[7161,7162,7163,7164] apply {lbCurSel (_display displayCtrl _x)};
    private _options=[_groups,_radii,_placements,_heights];
    if ([0,1,2,3] findIf {(_indices select _x) < 0 || {(_indices select _x) >= count (_options select _x)}} >= 0) exitWith {};
    private _group=_groups select (_indices select 0);
    if (isNull _group || {isNull leader _group} || {!alive leader _group}
        || {units _group findIf {isPlayer _x} >= 0}) exitWith {
        ["GARRISON","Selected AI squad is no longer available. Close and place the task again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
    _button ctrlEnable false;
    private _request=[[["order","GARRISON"],["group",_group],["position",_position],
        ["radius",_radii select (_indices select 1)],
        ["teleport",_placements select (_indices select 2)],
        ["sortByHeight",_heights select (_indices select 3)]],clientOwner] call CBE_fnc_CortexOrderDispatch;
    if (_request) then {_display closeDisplay 1} else {
        _button ctrlEnable true;
        ["GARRISON","Garrison request was refused. Check curator authority and the selected squad.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
}];
ctrlSetFocus _squad;
true
