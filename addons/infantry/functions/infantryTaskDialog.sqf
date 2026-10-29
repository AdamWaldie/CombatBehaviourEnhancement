/*
 * Author: WaldoTheWarfighter
 * Purpose: Native Zeus task parameters for Defend, Patrol, Hunt and Press attack.
 * Locality/authority: Interface only. Confirmation sends named values through existing
 * CortexOrderDispatch curator authentication and current-owner CortexOrderLocal execution.
 * This helper neither owns movement nor changes addon settings, actor orders or mission policy.
 * Repeat/JIP: One display-local choice snapshot. Cancel submits nothing, occupied Zeus child
 * dialogs are preserved, and confirmation revalidates choices. No worker or historical replay.
 * Arguments: 0 centre ATL ARRAY,[]; 1 attached AI soldier OBJECT,objNull;
 * 2 order STRING,"" (DEFEND/PATROL/HUNT/RUSH).
 * Return: BOOL display opened, not owner acceptance, physical progress or combat success.
 * Current callers: ModuleGarrison when optional ZEN is unavailable for these four tasks.
 * Example: [getPosATL soldier1,soldier1,"PATROL"] call CBE_fnc_InfantryTaskDialog;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]],["_order","",[""]]];
if (!hasInterface || {!(_order in ["DEFEND","PATROL","HUNT","RUSH"])}
    || {count _position != 3} || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {isNull _target} || {!(_target isKindOf "CAManBase")} || {isPlayer _target}) exitWith {false};
disableSerialization;
private _curator=findDisplay 312;
if (isNull _curator) exitWith {false};
if (!isNull (displayChild _curator)) exitWith {
    ["AI ORDERS","Close the current Zeus dialog before placing this task again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
private _selected=group _target;
_groups=[_selected]+(_groups-[_selected]);
private _title="";
private _parameters=[];
private _times=[30,60,180,300,600,900,1200,1800];
private _ranges=[50,100,250,500,800,1200,1600,2000];
// Each descriptor is [payload key,label,help,numeric choices,default index].
// These are task arguments already supported by the server and current-owner executor.
switch _order do {
    case "DEFEND": {
        _title="Defend area";
        private _facing=(round (getDir _target)) mod 360;
        private _directions=[_facing]+([0,45,90,135,180,225,270,315]-[_facing]);
        _parameters=[
            ["facing","Facing (degrees)","Threat direction: 0 north,90 east,180 south,270 west. Initial choice follows the attached soldier.",_directions,0],
            ["width","Line width (m)","Soldiers occupy a defensive line with a rear reserve. Available cover and accessible approaches depend on the ground.",[15,30,60,90,120,150],2]
        ];
    };
    case "PATROL": {
        _title="Patrol area";
        _parameters=[
            ["radius","Area radius (m)","Ground destinations lie within this area around the module. Native paths may leave it; inaccessible legs retain their original failure budgets.",[25,50,100,150,250,500],2],
            ["patrolNodes","Circuit destinations","One finite circuit. Existing formation, speed, combat mode and lights remain unchanged.",[3,4,5,6,7,8],1],
            ["patrolDuration","Task time limit (s)","Original total deadline includes combat suspension. Leg limits also apply; timeout is not completion.",_times,5]
        ];
    };
    case "HUNT": {
        _title="Hunt known enemy";
        _parameters=[
            ["huntRange","Knowledge range (m)","Requires a recent known ground contact. Search range is also capped by the addon engagement setting.",_ranges,4],
            ["patrolDuration","Task time limit (s)","One finite search sweep with original leg clocks and at most four fresh-belief updates. No claim that enemies or rooms are clear.",_times,5]
        ];
    };
    case "RUSH": {
        _title="Press attack";
        _parameters=[
            ["huntRange","Knowledge range (m)","Approach known contacts by covered advance or close assault, according to available roles, morale and rules of engagement.",_ranges,4],
            ["rushDuration","Task time limit (s)","Maximum time for the advance or assault. Newer orders interrupt the task.",[30,60,120,180,240,300],3]
        ];
    };
};
private _display=_curator createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {false};
_display setVariable ["CBE_infantryChoices",[_groups,+_position,_order,_parameters]];
private _width=0.66 min safeZoneW;
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
["RscText",-1,0,0.04,_title] call _make;
["RscText",-1,0.05,0.035,"AI squad"] call _make;
private _squad=["RscCombo",7171,0.09,0.045] call _make;
{_squad lbAdd format ["%1 / %2",side _x,groupId _x]} forEach _groups;
_squad lbSetCurSel 0;
_squad ctrlSetTooltip "Choose the AI squad. If it already has a task, use Release infantry task before requesting another.";
{
    _x params ["_key","_label","_help","_values","_default"];
    private _row=0.15+_forEachIndex*0.1;
    ["RscText",-1,_row,0.035,_label] call _make;
    private _combo=["RscCombo",7172+_forEachIndex,_row+0.04,0.045] call _make;
    {_combo lbAdd str _x} forEach _values;
    _combo lbSetCurSel _default;
    _combo ctrlSetTooltip _help;
} forEach _parameters;
private _start=["RscButton",7175,0.49,0.045,"Request task"] call _make;
private _cancel=["RscButton",7176,0.55,0.04,"Cancel"] call _make;
_cancel ctrlAddEventHandler ["ButtonClick",{(ctrlParent (_this select 0)) closeDisplay 2}];
_start ctrlAddEventHandler ["ButtonClick",{
    params ["_button"];
    private _display=ctrlParent _button;
    private _choices=_display getVariable ["CBE_infantryChoices",[]];
    if (count _choices != 4) exitWith {};
    _choices params ["_groups","_position","_order","_parameters"];
    private _groupIndex=lbCurSel (_display displayCtrl 7171);
    if (_groupIndex < 0 || {_groupIndex >= count _groups}) exitWith {};
    private _group=_groups select _groupIndex;
    if (isNull _group || {isNull leader _group} || {!alive leader _group}
        || {units _group findIf {isPlayer _x} >= 0}) exitWith {
        ["AI ORDERS","Selected AI squad is no longer available. Close and place the task again.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
    private _payload=[["order",_order],["group",_group],["position",_position]];
    private _valid=true;
    {
        private _index=lbCurSel (_display displayCtrl (7172+_forEachIndex));
        private _values=_x select 3;
        if (_index < 0 || {_index >= count _values}) exitWith {_valid=false};
        _payload pushBack [_x select 0,_values select _index];
    } forEach _parameters;
    if (!_valid) exitWith {};
    _button ctrlEnable false;
    private _request=[_payload,clientOwner] call CBE_fnc_CortexOrderDispatch;
    if (_request) then {_display closeDisplay 1} else {
        _button ctrlEnable true;
        ["AI ORDERS","Task request was refused. Check curator authority and squad eligibility.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    };
}];
ctrlSetFocus _squad;
true
