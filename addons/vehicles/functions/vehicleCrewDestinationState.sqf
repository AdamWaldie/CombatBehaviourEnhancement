/*
 * Author: WaldoTheWarfighter
 * Purpose: Classify a two-seat native MOVE acknowledgement from explicit caller observations.
 * Locality/authority: Pure comparison. The executor must sample its actual driver/operator,
 * native commands and expected destinations, and retain vehicle, group, token, epoch and task authority.
 * No actor is inferred and no driving-recovery journal is required or created.
 * Repeat/JIP: Stateless; no handlers, commands, replay, expiry renewal or movement ownership.
 * OWNED means both observed MOVE goals match, not physical arrival, stop, handover or permission.
 * A matching late observation remains observable for retirement; callers enforce their original
 * execution deadlines before mutations. Unchanged pre-request observations become EXPIRED.
 * Arguments: 0 goal ARRAY of three finite NUMBER,[]; 1 original reply deadline NUMBER,-1;
 * 2 before ARRAY [driverCommand STRING,driverDestination ARRAY,operatorCommand STRING,operatorDestination ARRAY],[];
 * 3 current ARRAY of the same shape,[]; 4 observed server time NUMBER,serverTime.
 * Destination arrays are actual expectedDestination results, not only their position field.
 * Return: STRING OWNED, PENDING, EXPIRED or LOST. Invalid geometry/observations return LOST.
 * Current caller: DrivingRecoveryCommandState for finite native child return acknowledgements.
 * Example: private _state=[_goal,_until,_before,_now,serverTime] call CBE_fnc_VehicleCrewDestinationState;
 */
params [["_goal",[],[[]]],["_until",-1,[0]],["_before",[],[[]]],["_current",[],[[]]],["_observedAt",serverTime,[0]]];
if (count _goal != 3 || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _until} || {!finite _observedAt}
    || {[_before,_current] findIf {count _x != 4 || {!((_x select 0) isEqualType "")}
        || {!((_x select 2) isEqualType "")} || {!((_x select 1) isEqualType [])}
        || {!((_x select 3) isEqualType [])}} >= 0}) exitWith {"LOST"};
private _atGoal={
    params ["_command","_native"];
    private _point=_native param [0,[],[[]]];
    _command == "MOVE" && {count _point == 3}
        && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_point vectorDistance _goal <= 0.25}
};
private _driverAck=[_current select 0,_current select 1] call _atGoal;
private _operatorAck=[_current select 2,_current select 3] call _atGoal;
if (_driverAck && {_operatorAck}) exitWith {"OWNED"};
private _driverWaiting=_driverAck || {(_current select 1) isEqualTo (_before select 1)
    && {(_current select 0) in [_before select 0,"MOVE"]}};
private _operatorWaiting=_operatorAck || {(_current select 3) isEqualTo (_before select 3)
    && {(_current select 2) in [_before select 2,"MOVE"]}};
if (!_driverWaiting || {!_operatorWaiting}) exitWith {"LOST"};
["PENDING","EXPIRED"] select (_observedAt > _until)
