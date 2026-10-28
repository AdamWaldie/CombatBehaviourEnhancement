/*
 * Author: WaldoTheWarfighter
 * Purpose: Read whether a drill admission observation or previously issued MOVE still matches.
 * Locality/authority: Read-only on the actor owner. Caller binds group/token/epoch/generation.
 * ADMISSION is observation only, never native movement or cleanup ownership. MOVE means the
 * caller retained a real issued-leg receipt; this reader supplies no acknowledgement grace.
 * Repeat/JIP: Stateless. Native formation points may move under the same planning policy and
 * formation leader; direct goals require the original absolute3D point within0.25m. Same-mode
 * formation edits and same-value replacement orders remain indistinguishable.
 * Arguments: 0 actor OBJECT objNull; 1 original seven-field drill native row ARRAY [].
 * Return: BOOL current observation; false for malformed, nonlocal or changed native state.
 * Current callers: CortexFlankStep admission, CortexCheckpoint and CortexDrillResume.
 * Example: private _same=[soldier1,_originalRow] call CBE_fnc_CortexDrillNativeCurrent;
 */
params [["_actor",objNull,[objNull]],["_row",[],[[]]]];
if (isNull _actor || {!local _actor} || {count _row != 7}
    || {!((_row select 0) isEqualType objNull)} || {(_row select 0) != _actor}
    || {!((_row select 3) isEqualType objNull)} || {formLeader _actor != (_row select 3)}
    || {!((_row select 4) isEqualType 0)} || {!finite (_row select 4)}
    || {!((_row select 5) isEqualType [])}) exitWith {false};
private _kind=_row param [1,"",[""]];
if (!(_kind in ["ADMISSION","MOVE"])) exitWith {false};
private _command=currentCommand _actor;
private _native=expectedDestination _actor;
private _original=_row param [2,[],[[]]];
private _goal=_row param [6,[],[[]]];
if (_kind == "ADMISSION") then {
    if ((_row select 4) != -1 || {(_row select 5) isNotEqualTo []}
        || {count _original != 3} || {count _native != 3}
        || {!((_original select 1) isEqualType "")} || {!((_native select 1) isEqualType "")}
        || {!((_original select 2) isEqualType true)} || {!((_native select 2) isEqualType true)}
        || {[_original param [0,[],[[]]],_native param [0,[],[[]]]] findIf {
            count _x != 3 || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        } >= 0}) exitWith {_kind="REFUSED"};
    private _originalCommand=_goal param [0,"INVALID",[""]];
    if (count _goal != 1 || {_command != _originalCommand} || {_command == "STOP"}) exitWith {_kind="REFUSED"};
    if (_command != "MOVE") exitWith {_kind="IDLE"};
    if (count _original != 3 || {count _native != 3}
        || {(_original select [1,2]) isNotEqualTo (_native select [1,2])}) exitWith {_kind="REFUSED"};
    private _planning=_original param [1,"",[""]];
    if (_planning in ["DoNotPlan","DoNotPlanFormation","FORMATION PLANNED"]) exitWith {_kind="FORMATION"};
    if (!(_planning in ["LEADER PLANNED","LEADER DIRECT"])) exitWith {_kind="REFUSED"};
    _goal=_original param [0,[],[[]]];
};
if (_kind in ["IDLE","FORMATION"]) exitWith {true};
if (_kind == "REFUSED" || {_command != "MOVE"}) exitWith {false};
private _position=_native param [0,[],[[]]];
if ([_goal,_position] findIf {count _x != 3 || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0) exitWith {false};
_goal=AGLToASL _goal;_position=AGLToASL _position;
_goal vectorDistance _position <= 0.25
