/*
 * Author: WaldoTheWarfighter
 * Purpose: Classifies native destination acknowledgement for one existing recovery journal.
 * Locality/authority: Read-only on current owner or during split-locality cleanup observation.
 * This proves command identity only; callers retain cap, route, owner, task and release guards.
 * Repeat/JIP: Original public request expiry survives migration. No writes, replay, deadline
 * renewal or physical progress inference. SIMPLE_BACK retains its separate input/turn contract.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 journal <HASHMAP, empty>.
 * Return: STRING - OWNED (exact receipt/issued goal), PENDING (original unchanged state),
 * EXPIRED (same state after original wait), LOST (changed/unknown identity).
 * Distinct native drivers retain their original destination proof; intermediate changes are
 * not inferred to be ours merely because the commander's target was acknowledged.
 * Current callers: DrivingAssistStart and DrivingRecoveryRelease.
 * Example: private _state=[truck1,truck1 getVariable ["CBE_DrivingRecovery_Work",createHashMap]] call CBE_fnc_DrivingRecoveryCommandState;
 */
params [["_vehicle",objNull,[objNull]],["_work",createHashMap,[createHashMap]]];
if (isNull _vehicle || {count _work == 0}
    || {(_work getOrDefault ["commandMode","DESTINATION"]) != "DESTINATION"}) exitWith {"LOST"};
private _group=_work getOrDefault ["group",grpNull];
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _operator) then {_operator=_driver};
if (isNull _group || {isNull _driver} || {isNull _operator}
    || {group _driver != _group} || {group _operator != _group}
    || {_driver != (_work getOrDefault ["driver",objNull])}
    || {_operator != (_work getOrDefault ["operator",objNull])}) exitWith {"LOST"};
private _driverNative=expectedDestination _driver;
private _operatorNative=expectedDestination _operator;
private _request=_work getOrDefault ["request",[]];
if (_request isEqualTo []) exitWith {
    if (_driverNative isEqualTo (_work getOrDefault ["driverCommand",[]])
        && {_operatorNative isEqualTo (_work getOrDefault ["command",[]])}) then {"OWNED"} else {"LOST"}
};
if (!(_request isEqualType []) || {count _request != 3}) exitWith {"LOST"};
_request params ["_goal","_until","_before"];
if (!(_goal isEqualType []) || {count _goal != 3}
    || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(_until isEqualType 0)} || {!finite _until}
    || {!(_before isEqualType [])} || {count _before != 4}
    || {!((_before select 0) isEqualType "")} || {!((_before select 2) isEqualType "")}
    || {!((_before select 1) isEqualType [])} || {!((_before select 3) isEqualType [])}) exitWith {"LOST"};
private _position=_operatorNative param [0,[],[[]]];
if (currentCommand _operator in ["","MOVE"] && {count _position == 3}
    && {_position vectorDistance _goal <= 0.25}
    && {_driver == _operator || {_driverNative isEqualTo (_work getOrDefault ["driverCommand",[]])}}) exitWith {"OWNED"};
private _unchanged=_driverNative isEqualTo (_before select 1)
    && {_operatorNative isEqualTo (_before select 3)}
    && {currentCommand _driver in [_before select 0,"MOVE"]}
    && {currentCommand _operator in [_before select 2,"MOVE"]};
if (!_unchanged) exitWith {"LOST"};
["PENDING","EXPIRED"] select (serverTime > _until)
