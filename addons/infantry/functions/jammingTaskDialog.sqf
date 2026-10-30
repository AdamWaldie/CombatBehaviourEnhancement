/*
 * Author: WaldoTheWarfighter
 * Purpose: Native Zeus task dialog for an explicit emitter, radius and affected AI sides.
 * Locality/authority: Interface only; named confirmation goes through CortexJammingField's
 * authenticated server path. No addon setting or player radio/voice control is changed.
 * Repeat/JIP: One display context; cancel sends nothing, confirm disables itself. Server
 * sequence/expiry/target checks handle replay. Existing Zeus child dialogs are preserved.
 * Arguments: 0 emitter OBJECT,objNull, required exact object; no nearest-object fallback.
 * Return Value: BOOL dialog opened, not field acceptance or observed communications denial.
 * Current callers: ModuleJamming and the optional ZEN AI radio-denial behaviour entry.
 * Example: [jammerVehicle] call CBE_fnc_JammingTaskDialog;
 */
params [["_emitter",objNull,[objNull]]];
if (!hasInterface) exitWith {false};
if (isNull _emitter) exitWith {
    ["AI RADIO DENIAL","Place this task on the exact emitter object. No nearby object is selected.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    false
};
disableSerialization;
private _curator=findDisplay 312;
if (isNull _curator || {!isNull displayChild _curator}) exitWith {false};
private _display=_curator createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {false};
private _radii=[50,100,200,500,1000,2000,5000,10000,50000,100000];
_display setVariable ["CBE_jammingChoices",[_emitter,_radii]];
private _width=0.62 min safeZoneW;
private _left=safeZoneX+(safeZoneW-_width)/2;
private _top=safeZoneY+safeZoneH*0.14;
private _make={
    params ["_class","_id","_row","_height",["_text",""]];
    private _control=_display ctrlCreate [_class,_id];
    _control ctrlSetPosition [_left+0.02,_top+_row*safeZoneH,_width-0.04,_height*safeZoneH];
    _control ctrlSetText _text;_control ctrlCommit 0;
    _control
};
private _background=_display ctrlCreate ["RscText",-1];
_background ctrlSetPosition [_left,_top-0.02*safeZoneH,_width,0.70*safeZoneH];
_background ctrlSetBackgroundColor [0.06,0.07,0.06,0.98];_background ctrlCommit 0;
["RscText",-1,0,0.04,"AI radio-denial task"] call _make;
["RscText",-1,0.05,0.03,"Task action"] call _make;
private _action=["RscCombo",7261,0.08,0.04] call _make;
{_action lbAdd _x} forEach ["Start/update denial","End denial"];
_action lbSetCurSel 0;
_action ctrlSetTooltip "Only CBE AI radio checks are affected. Player voice, ACRE/TFAR and native UAV control are unchanged.";
["RscText",-1,0.14,0.03,"Radius (m)"] call _make;
private _radius=["RscCombo",7262,0.17,0.04] call _make;
{_radius lbAdd str _x} forEach _radii;_radius lbSetCurSel 2;
_radius ctrlSetTooltip "Field follows this emitter's current position. Destruction/deletion removes its effect; no movement controller is created.";
["RscText",-1,0.23,0.03,"Affected AI sides (select at least one to start)"] call _make;
{
    private _row=0.27+_forEachIndex*0.055;
    private _box=_display ctrlCreate ["RscCheckbox",7270+_forEachIndex];
    _box ctrlSetPosition [_left+0.02,_top+_row*safeZoneH,0.035,0.04*safeZoneH];
    _box cbSetChecked false;_box ctrlCommit 0;
    private _label=["RscText",-1,_row,0.04,_x] call _make;
    _label ctrlSetPosition [_left+0.065,_top+_row*safeZoneH,_width-0.085,0.04*safeZoneH];
    _label ctrlCommit 0;
    _label ctrlSetTooltip "Select only sides whose AI radio traffic this emitter should deny. Voice can still work at close range.";
} forEach ["BLUFOR","OPFOR","Independent","Civilian"];
private _confirm=["RscButton",7263,0.53,0.045,"Issue task"] call _make;
private _cancel=["RscButton",7264,0.59,0.04,"Cancel"] call _make;
_cancel ctrlAddEventHandler ["ButtonClick",{(ctrlParent (_this select 0)) closeDisplay 2}];
_confirm ctrlAddEventHandler ["ButtonClick",{
    params ["_button"];
    private _display=ctrlParent _button;
    (_display getVariable ["CBE_jammingChoices",[]]) params ["_emitter","_radii"];
    private _action=lbCurSel (_display displayCtrl 7261);
    private _radiusIndex=lbCurSel (_display displayCtrl 7262);
    private _sides=[];
    {if (cbChecked (_display displayCtrl (7270+_forEachIndex))) then {_sides pushBack _x}}
        forEach [west,east,resistance,civilian];
    if (isNull _emitter || {!(_action in [0,1])} || {_radiusIndex < 0}
        || {_radiusIndex >= count _radii} || {_action == 0 && {_sides isEqualTo []}}) exitWith {
        ["AI RADIO DENIAL","Select an emitter, radius and affected sides before starting.","ERROR"] call CBE_fnc_AITweaksNotifyLocal
    };
    private _serial=(missionNamespace getVariable ["CBE_EW_LocalSerial",0])+1;
    missionNamespace setVariable ["CBE_EW_LocalSerial",_serial];
    _button ctrlEnable false;
    private _submitted=[["mode",["EMIT","STOP"] select (_action == 1)],
        ["emitter",_emitter],["radius",_radii select _radiusIndex],["sides",_sides],
        ["serial",_serial],["expires",serverTime+10]] call CBE_fnc_CortexJammingField;
    if (_submitted) then {_display closeDisplay 1} else {
        _button ctrlEnable true;
        ["AI RADIO DENIAL","Task refused; check curator authority and emitter.","ERROR"] call CBE_fnc_AITweaksNotifyLocal
    };
}];
ctrlSetFocus _action;
true
