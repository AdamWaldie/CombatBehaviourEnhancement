/*
 * Author: WaldoTheWarfighter
 * Purpose: Classifies native destination acknowledgement for one existing recovery journal.
 * Locality/authority: Read-only on current owner or during split-locality cleanup observation.
 * This proves command identity only; callers retain cap, route, owner, task and release guards.
 * It never reads current route identity: route readers may classify an exact temporary native leg
 * without recursion. Matching child/parent route metadata is provenance, not current-route authority.
 * Repeat/JIP: Original public request expiry survives migration. No writes, replay, deadline
 * renewal or physical progress inference. SIMPLE_BACK retains its separate input/turn contract.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 journal <HASHMAP, empty>.
 * Return: STRING - OWNED (exact receipt/issued goal), PENDING (original unchanged state),
 * EXPIRED (same state after original wait), LOST (changed/unknown identity), or BYPASS/CORRIDOR
 * (exact child command, including expired work awaiting cleanup; retention only,
 * never parent movement permission). Executors enforce the unchanged deadlines.
 * Distinct native drivers retain their original destination proof; intermediate changes are
 * not inferred to be ours merely because the commander's target was acknowledged.
 * Current callers: DrivingAssistStart and DrivingRecoveryRelease.
 * Example: private _state=[truck1,truck1 getVariable ["CBE_DrivingRecovery_Work",createHashMap]] call CBE_fnc_DrivingRecoveryCommandState;
 */
params [["_vehicle",objNull,[objNull]],["_work",createHashMap,[createHashMap]]];
if (isNull _vehicle || {count _work == 0}
    || {(_work getOrDefault ["commandMode","DESTINATION"]) != "DESTINATION"
        && {(_work getOrDefault ["nativeReturn",[]]) isEqualTo []}}) exitWith {"LOST"};
private _group=_work getOrDefault ["group",grpNull];
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _operator) then {_operator=_driver};
if (isNull _group || {isNull _driver} || {isNull _operator}
    || {group _driver != _group} || {group _operator != _group}
    || {_driver != (_work getOrDefault ["driver",objNull])}
    || {_operator != (_work getOrDefault ["operator",objNull])}) exitWith {"LOST"};
private _driverNative=expectedDestination _driver;
private _operatorNative=expectedDestination _operator;
// A native bypass returns both operating actors to the original MOVE. A commander's
// ACK alone cannot retire the temporary journal while its distinct driver still follows
// or holds STOP. Observe both original goals within the same original request window.
private _temporaryReturnState={
    params ["_goal","_until","_before"];
    private _atOriginalGoal={
        params ["_actor","_native"];
        private _point=_native param [0,[],[[]]];
        currentCommand _actor == "MOVE" && {count _point == 3}
            && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_point vectorDistance _goal <= 0.25}
    };
    private _driverAck=[_driver,_driverNative] call _atOriginalGoal;
    private _operatorAck=[_operator,_operatorNative] call _atOriginalGoal;
    if (_driverAck && {_operatorAck}) exitWith {"OWNED"};
    private _driverWaiting=_driverAck || {_driverNative isEqualTo (_before select 1)
        && {currentCommand _driver in [_before select 0,"MOVE"]}};
    private _operatorWaiting=_operatorAck || {_operatorNative isEqualTo (_before select 3)
        && {currentCommand _operator in [_before select 2,"MOVE"]}};
    if (!_driverWaiting || {!_operatorWaiting}) exitWith {"LOST"};
    ["PENDING","EXPIRED"] select (serverTime > _until)
};
private _nativeReturn=_work getOrDefault ["nativeReturn",[]];
if (_nativeReturn isNotEqualTo []) exitWith {
    if (!(_nativeReturn isEqualType []) || {count _nativeReturn != 3}) exitWith {"LOST"};
    _nativeReturn params ["_returnGoal","_returnUntil","_returnBefore"];
    if (!(_returnGoal isEqualType []) || {count _returnGoal != 3}
        || {_returnGoal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        || {!(_returnUntil isEqualType 0)} || {!finite _returnUntil}
        || {!(_returnBefore isEqualType [])} || {count _returnBefore != 4}
        || {!((_returnBefore select 0) isEqualType "")} || {!((_returnBefore select 2) isEqualType "")}
        || {!((_returnBefore select 1) isEqualType [])} || {!((_returnBefore select 3) isEqualType [])}) exitWith {"LOST"};
    if ("bypassReturn" in _work && {((_work getOrDefault ["route",[]]) param [0,"",[""]]) == "NATIVE_MOVE"}) exitWith {
        [_returnGoal,_returnUntil,_returnBefore] call _temporaryReturnState
    };
    private _operatorGoal=_operatorNative param [0,[],[[]]];
    private _driverSame=_driver == _operator || {_driverNative isEqualTo (_returnBefore select 1)
        && {currentCommand _driver in [_returnBefore select 0,"MOVE"]}};
    if (_driverSame && {currentCommand _operator in ["","MOVE","WAIT"]}
        && {count _operatorGoal == 3} && {_operatorGoal vectorDistance _returnGoal <= 0.25}) exitWith {"OWNED"};
    private _unchanged=_driverNative isEqualTo (_returnBefore select 1)
        && {_operatorNative isEqualTo (_returnBefore select 3)}
        && {currentCommand _driver in [_returnBefore select 0,"MOVE"]}
        && {currentCommand _operator in [_returnBefore select 2,"MOVE"]};
    if (!_unchanged) exitWith {"LOST"};
    ["PENDING","EXPIRED"] select (serverTime > _returnUntil)
};
// A finite bypass child intentionally changes the destination. Its exact live receipt
// can retain the parent's budget; it cannot authorise ordinary parent recovery moves.
private _child=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
private _hard=_work getOrDefault ["hardDeadline",-1];
private _childDeadline=_child getOrDefault ["deadline",-1];
if ((_work getOrDefault ["bypassSpent",false]) isEqualTo true
    && {(_work getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}
    && {!(_work getOrDefault ["releasePending",false])}
    && {_hard isEqualType 0} && {finite _hard}
    && {_childDeadline isEqualType 0} && {finite _childDeadline}
    && {_childDeadline <= _hard}
    && {(_child getOrDefault ["controller",[]]) isEqualTo ["ORDINARY",-1]}
    && {(_child getOrDefault ["phase",""]) == "FOLLOW"}
    && {(_child getOrDefault ["group",grpNull]) == _group}
    && {(_child getOrDefault ["driver",objNull]) == _driver}
    && {(_child getOrDefault ["operator",objNull]) == _operator}
    && {(_child getOrDefault ["route",[]]) isEqualTo (_work getOrDefault ["route",[]])}
    && {(_child getOrDefault ["recoveryParent",[]]) isEqualTo
        [_group,_work getOrDefault ["route",[]],_hard,_work getOrDefault ["progressAnchor",[]]]}
    && {_driverNative isEqualTo (_child getOrDefault ["driverCommand",[]])}
    && {_operatorNative isEqualTo (_child getOrDefault ["command",[]])}
    && {toUpperANSI currentCommand _driver == (_child getOrDefault ["driverTask","__MISSING__"])}
    && {toUpperANSI currentCommand _operator == (_child getOrDefault ["operatorTask","__MISSING__"])}) exitWith {"BYPASS"};
// A native corridor is another temporary child of the same finite alternate-path
// episode. Identity can outlive its deadline for cleanup; this grants no new motion.
private _corridor=_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap];
if !(_corridor isEqualType createHashMap) exitWith {"LOST"};
if (count _corridor > 0) exitWith {
    private _phase=_corridor getOrDefault ["phase",""];
    private _until=_corridor getOrDefault ["deadline",-1];
    private _entry=(_corridor getOrDefault ["points",[]]) param [0,[],[[]]];
    private _driverGoal=_driverNative param [0,[],[[]]];
    private _driverCurrent=_driverNative isEqualTo (_corridor getOrDefault ["driverCommand",[]]);
    if (!_driverCurrent && {_phase == "APPROACH"}) then {
        _driverCurrent=count _entry == 3 && {count _driverGoal == 3}
            && {_entry findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_driverGoal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_driverGoal vectorDistance _entry <= 0.25};
    };
    if (count _child == 0 && {(_work getOrDefault ["bypassSpent",false]) isEqualTo true}
        && {(_work getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}
        && {!(_work getOrDefault ["releasePending",false])}
        && {_hard isEqualType 0} && {finite _hard}
        && {_until isEqualType 0} && {finite _until} && {_until <= _hard}
        && {_phase in ["APPROACH","CROSS"]}
        && {(_corridor getOrDefault ["controller",[]]) isEqualTo ["ORDINARY",-1]}
        && {(_corridor getOrDefault ["group",grpNull]) == _group}
        && {(_corridor getOrDefault ["route",[]]) isEqualTo (_work getOrDefault ["route",[]])}
        && {(_corridor getOrDefault ["driver",objNull]) == _driver}
        && {(_corridor getOrDefault ["operator",objNull]) == _operator}
        && {(_corridor getOrDefault ["recoveryParent",[]]) isEqualTo
            [_group,_work getOrDefault ["route",[]],_hard,_work getOrDefault ["progressAnchor",[]]]}
        && {_operatorNative isEqualTo (_corridor getOrDefault ["command",[]])}
        && {_driverCurrent}
        && {[_driver,_operator] findIf {!(currentCommand _x in
            (["","MOVE","WAIT"]+([[],["STOP"]] select (_phase == "CROSS"))))} < 0}) then {"CORRIDOR"} else {"LOST"}
};
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
if ("bypassReturn" in _work && {((_work getOrDefault ["route",[]]) param [0,"",[""]]) == "NATIVE_MOVE"}) exitWith {
    [_goal,_until,_before] call _temporaryReturnState
};
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
