/*
 * Author: WaldoTheWarfighter
 * Purpose: Register a pre-placed Eden navigation-corridor behaviour through the existing area registry.
 * Locality/authority: Trusted server module execution only, never interface or curator ownership.
 * Repeat/JIP: Persistent module is its own area. Equal activation retains revision; deactivation
 * removes the definition. Server publishes passive snapshots to JIP; no movement is replayed.
 * Existing geometry consumes live transforms and invalidates an in-flight route when the area moves.
 * Arguments: logic OBJECT objNull; synchronized units ARRAY []; activated BOOL true.
 * objectArea supplies half-width/half-length/angle/rectangle/height; arrow defines route direction.
 * CBE_DrivingCorridor_EdenSpeed is a task parameter NUMBER 15, validated 5..30 km/h.
 * Return: BOOL registration accepted, never physical crossing or native steering success.
 * Current caller: CBE_ModuleDrivingCorridorMission module framework; trusted server scripts.
 * Example: [corridorMissionLogic,[],true] call CBE_fnc_ModuleDrivingCorridorMission;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (!isServer || {is3DEN} || {isNull _logic}
    || {!(_logic isKindOf "CBE_ModuleDrivingCorridorMission")}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _answer=[];
if (!_activated) then {
    _answer=[_logic,[]] call CBE_fnc_DrivingCorridorRegister;
} else {
    private _area=_logic getVariable ["objectArea",[5,25,0,true,-1]];
    private _speed=_logic getVariable ["CBE_DrivingCorridor_EdenSpeed",15];
    private _valid=_area isEqualType [] && {count _area in [4,5]}
        && {[0,1,2] findIf {!((_area select _x) isEqualType 0) || {!finite (_area select _x)}} < 0}
        && {(_area select 3) isEqualType true} && {_area select 3}
        && {_speed isEqualType 0} && {finite _speed};
    if (_valid) then {
        // Do not flatten or recreate this world object; its current elevation and facing matter.
        _answer=[_logic,[_area select 1,_area select 0,_speed]] call CBE_fnc_DrivingCorridorRegister;
    } else {_answer=[false,"INVALID_EDEN_AREA",-1]};
};
_logic setVariable ["CBE_DrivingCorridor_MissionResult",_answer,true];
if !(_answer select 0) then {diag_log format ["[CBE] Mission navigation corridor %1 refused: %2",_logic,_answer select 1]};
_answer select 0
