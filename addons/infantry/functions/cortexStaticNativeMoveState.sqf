/*
 * Author: WaldoTheWarfighter
 * Purpose: Classify an on-foot static-team actor's current native MOVE/STOP without issuing commands.
 * Locality / Authority: Read-only on the actor/group owner. CURRENT is only absence of an
 * observed movement replacement; callers still own phase, task, health, route and action checks.
 * Mounted native commands and nonmovement tasks remain under those existing caller policies.
 * Repeat/JIP: Stateless. Exact private move receipt is not replayed after locality change.
 * Planner/unknown-goal WAIT grants no action or renewed time; the caller keeps its original deadline.
 * Native goal publication gets at most2s from an actual issued leg; phase/reservation updates
 * never renew that allowance. Native leg identity is separate from the phase reservation point.
 * Arguments: 0 actor OBJECT objNull; 1 group GROUP grpNull; 2 deployment record ARRAY [].
 * Return Value: STRING CURRENT, WAIT or YIELD. Same-value replacement orders remain indistinguishable.
 * Current callers: CortexStaticDeployStep active observation, equipment events and retirement.
 * Example: private _state=[_gunner,_group,_record] call CBE_fnc_CortexStaticNativeMoveState;
 */
params [["_actor",objNull,[objNull]],["_group",grpNull,[grpNull]],["_record",[],[[]]]];
if (isNull _actor || {isNull _group} || {!local _actor} || {!local _group}
    || {group _actor != _group}) exitWith {"YIELD"};
if (!isNull objectParent _actor) exitWith {"CURRENT"};
private _command=toUpperANSI currentCommand _actor;
if (!(_command in ["MOVE","STOP"])) exitWith {"CURRENT"};
private _move=_actor getVariable ["CBE_Cortex_ActorMove",[]];
private _owned=(_record param [27,-1,[0]]) >= 0
    && {_move isEqualType []} && {count _move == 3}
    && {(_move param [0,"",[""]]) in ["STATIC_DEPLOY","STATIC_PACK"]}
    && {(_actor getVariable ["CBE_Danger_StaticMoveReceipt",[]]) isEqualTo
        [_group,_record param [19,[],[[]]],_record param [27,-1,[0]],_move]};
// A released assistant (or a vacated ACTIVE gunner) may still show an ended
// original MOVE. Observe only settled physical arrival; missing markers alone
// never establish completion or restore a previously active movement lease.
private _phase=_record param [1,"",[""]];
private _gunner=_record param [2,objNull,[objNull]];
private _releasedActor=_move isEqualTo [] && {
    _actor == (_record param [3,objNull,[objNull]]) && {_actor != _gunner}
        && {_phase in ["ASSEMBLING","MOUNTING","ACTIVE","PACK_EXITING"]}
    || {_actor == _gunner && {_phase == "ACTIVE"}}
};
if (!_owned && {!(_command == "MOVE" && {_releasedActor})}) exitWith {"YIELD"};
// Only the original explicit on-sector stop may remain. A later movement issue
// clears this receipt; a coincident same-value external STOP cannot be identified.
if (_command == "STOP") exitWith {
    private _stop=_record param [31,[],[[]]];
    private _point=_stop param [1,[],[[]]];
    if (count _stop == 2 && {(_stop param [0,objNull,[objNull]]) == _actor}
        && {count _point == 3} && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {(getPosASL _actor) vectorDistance _point <= 0.5}) then {"CURRENT"} else {"YIELD"}
};
if (getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY","BUSY"]) exitWith {"WAIT"};
private _leg=_actor getVariable ["CBE_Danger_StaticNativeLeg",[]];
if (!(_leg isEqualType []) || {count _leg != 5}
    || {(_leg select [0,3]) isNotEqualTo [_group,_record param [19,[],[[]]],_record param [27,-1,[0]]]}
    || {!((_leg select 4) isEqualType 0)} || {!finite (_leg select 4)}
    || {time < (_leg select 4)}) exitWith {"WAIT"};
private _goal=(expectedDestination _actor) param [0,[],[[]]];
private _destination=_leg param [3,[],[[]]];
if ([_goal,_destination] findIf {count _x != 3
    || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0) exitWith {"WAIT"};
if ((AGLToASL _goal) vectorDistance (AGLToASL _destination) <= 1) exitWith {
    if (!_releasedActor || {unitReady _actor && {abs speed _actor < 0.5}
        && {(getPosASL _actor) vectorDistance (AGLToASL _destination) <= 2}}) then {"CURRENT"} else {"WAIT"}
};
if (time-(_leg select 4) < 2) then {"WAIT"} else {"YIELD"}
