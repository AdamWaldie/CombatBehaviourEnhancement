/*
 * Author: WaldoTheWarfighter
 * Purpose: Draw selected mission-corridor proposals in Eden at their selected elevation/grade.
 * Locality/authority: Editor interface only. Read-only; never registers tasks or steers actors.
 * Repeat/JIP: Install replaces the active handler receipt; obsolete handlers remove themselves
 * on their next Draw3D callback. Preview/exit stops drawing; returning to Eden installs afresh.
 * Selection cache refreshes every0.25s, inspects at most16 selected logics; no world scan.
 * Arguments: mode STRING "INSTALL" (INSTALL/STOP/DRAW); handler NUMBER -1, engine Draw3D ID.
 * Return: BOOL active/installed; not proof of support, hull clearance or accepted navigation.
 * Current callers: Cfg3DEN CBE event section and its own Draw3D callback. No remote/JIP caller.
 * Example: ["INSTALL"] call CBE_fnc_EdenDrivingCorridorPreview;
 */
params [["_mode","INSTALL",[""]],["_handler",-1,[0]]];
private _key="CBE_EdenCorridorPreview";
if (_mode == "STOP") exitWith {uiNamespace setVariable [_key,[]];true};
if (!is3DEN || {!hasInterface}) exitWith {
    if (_mode == "DRAW" && {_handler >= 0}) then {removeMissionEventHandler ["Draw3D",_handler]};
    false
};
private _display=findDisplay 313;
if (isNull _display) exitWith {
    if (_mode == "DRAW" && {_handler >= 0}) then {removeMissionEventHandler ["Draw3D",_handler]};
    false
};
if (_mode == "INSTALL") exitWith {
    private _id=addMissionEventHandler ["Draw3D",{
        ["DRAW",_thisEventHandler] call CBE_fnc_EdenDrivingCorridorPreview;
    }];
    uiNamespace setVariable [_key,[_id,_display,[], -1]];
    true
};
if (_mode != "DRAW" || {_handler < 0}) exitWith {false};
private _receipt=uiNamespace getVariable [_key,[]];
if (count _receipt != 4 || {(_receipt select 0) != _handler}
    || {!((_receipt select 1) isEqualTo _display)}) exitWith {
    removeMissionEventHandler ["Draw3D",_handler];false
};
if (diag_tickTime >= (_receipt select 3)) then {
    // Cap before filtering: a huge mixed selection cannot make the render callback scan it all.
    private _selected=(get3DENSelected "logic") select [0,16];
    _receipt set [2,_selected select {!isNull _x && {_x isKindOf "CBE_ModuleDrivingCorridorMission"}}];
    _receipt set [3,diag_tickTime+0.25];
    uiNamespace setVariable [_key,_receipt];
};
{
    private _logic=_x;
    if (!isNull _logic) then {
        private _size=(_logic get3DENAttribute "size3") param [0,[]];
        if (_size isEqualType [] && {count _size == 3}
            && {_size findIf {!(_x isEqualType 0) || {!finite _x}} < 0}) then {
            private _width=_size select 0;private _length=_size select 1;
            private _native=vectorDir _logic;
            private _horizontal=vectorMagnitude [_native select 0,_native select 1,0];
            if (_width >= 2 && {_width <= 20} && {_length >= 5} && {_length <= 45}
                && {_horizontal >= 0.1} && {((vectorUp _logic) select 2) >= 0.98}) then {
                private _axis=[(_native select 0)/_horizontal,(_native select 1)/_horizontal,(_native select 2)/_horizontal];
                private _right=[_axis select 1,-(_axis select 0),0];
                private _centre=(getPosASL _logic) vectorAdd [0,0,0.08];
                private _point={
                    params ["_along","_across"];
                    ASLToAGL ((_centre vectorAdd (_axis vectorMultiply _along)) vectorAdd (_right vectorMultiply _across))
                };
                private _a=[-_length,-_width] call _point;private _b=[_length,-_width] call _point;
                private _c=[_length,_width] call _point;private _d=[-_length,_width] call _point;
                private _tail=[-_length,0] call _point;private _head=[_length,0] call _point;
                private _arrowLength=(_length*0.25) min 4;
                private _left=[_length-_arrowLength,-((_width*0.5) min 2)] call _point;
                private _rightTip=[_length-_arrowLength,(_width*0.5) min 2] call _point;
                {drawLine3D [_x select 0,_x select 1,[0.65,0.72,0.5,0.9]]}
                    forEach [[_a,_b],[_b,_c],[_c,_d],[_d,_a],[_tail,_head],[_left,_head],[_rightTip,_head]];
                drawIcon3D ["",[0.85,0.85,0.75,1],ASLToAGL (_centre vectorAdd [0,0,0.5]),
                    0,0,0,"Corridor proposal - support not checked",2,0.025,"PuristaMedium","center"];
            };
        };
    };
} forEach (_receipt select 2);
true
