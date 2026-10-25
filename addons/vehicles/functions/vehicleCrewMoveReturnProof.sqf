/*
 * Author: WaldoTheWarfighter
 * Purpose: Read positive native return evidence after the exact original local worker ended.
 * Locality/authority: Read-only on current local platform/group/original actors. The producer
 * must still own the exact journal/reference. An actual completed private original FSM,
 * matching local worker serial/owner/episode epoch and recorded original return orders are
 * required; a remote done flag, ended timer or changed seat alone is never sufficient.
 * Current group epoch and any recorded tactical generation must still match; this passive
 * check grants no new command authority. Caller runs it inside its unscheduled retirement call.
 * Repeat/JIP: No commands, publication, worker, replay or deadline renewal. Late evidence can
 * retire metadata after the old window, never grant another stop/return command. This does
 * not confirm a foreign owner's worker termination or arbitrary native supersession.
 * Arguments: platform OBJECT,objNull; journal HASHMAP,empty; private worker ARRAY,[];
 * current private worker serial NUMBER,-1.
 * Return: BOOL current original return acknowledgement observed, not physical returned travel.
 * Current callers: VehicleCrewMoveRetire for ended RETURNING/UNRESOLVED episodes.
 * Example: [_vehicle,_work,_privateWorker,_workerSerial] call CBE_fnc_VehicleCrewMoveReturnProof;
 */
params [["_battery",objNull,[objNull]],["_work",createHashMap,[createHashMap]],
    ["_executor",[],[[]]],["_executorSerial",-1,[0]]];
private _group=_work getOrDefault ["group",grpNull];
if (isNull _battery || {!local _battery} || {!(_group isEqualType grpNull)}
    || {isNull _group} || {!local _group} || {!("returns" in _work)}
    || {!((_work getOrDefault ["phase",""]) in ["RETURNING","UNRESOLVED"])}
    || {count _executor != 5} || {!finite _executorSerial} || {_executorSerial < 0}
    || {[0,1,2,3,4] findIf {!((_executor select _x) isEqualType 0)
        || {!finite (_executor select _x)}} >= 0}
    || {(_executor select 0) < 0} || {(_executor select 3) < 0}
    || {(_executor select 0) != (_work getOrDefault ["serial",-1])}
    || {(_executor select 2) != clientOwner} || {(_work getOrDefault ["owner",-1]) != clientOwner}
    || {(_executor select 3) != (_work getOrDefault ["epoch",-1])}
    || {(_work getOrDefault ["epoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",-2])}
    || {(_executor select 4) != _executorSerial} || {(_executor select 1) < 0}
    || {!completedFSM (_executor select 1)}) exitWith {false};
private _generation=_work getOrDefault ["operationGeneration",-1];
if ("operationGeneration" in _work && {!(_generation isEqualType 0) || {!finite _generation}
    || {_generation < 0} || {_generation != (_group getVariable ["CBE_OperationGeneration",-2])}}) exitWith {false};
private _seats=_work getOrDefault ["crew",[]];
private _baseline=_work getOrDefault ["baseline",[]];
private _returns=_work get "returns";
private _until=_work getOrDefault ["replyUntil",-1];
private _cleanup=_work getOrDefault ["cleanupUntil",-1];
if (!(_seats isEqualType []) || {count _seats != 2} || {_seats findIf {!(_x isEqualType objNull)} >= 0}
    || {!(_baseline isEqualType [])} || {count _baseline != 4}
    || {[0,2] findIf {!((_baseline select _x) in ["","MOVE","WAIT"])
        || {!((_baseline select (_x+1)) isEqualType [])}} >= 0}
    || {!(_returns isEqualType [])} || {count _returns > 2}
    || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0}
    || {!(_cleanup isEqualType 0)} || {!finite _cleanup} || {_cleanup < 0}) exitWith {false};
private _original=_seats arrayIntersect _seats;
private _writers=_original select {!isNull _x && {alive _x}};
if (_writers isEqualTo [] || {_writers findIf {!local _x || {group _x != _group}
    || {objectParent _x != _battery}} >= 0}
    || {[driver _battery,effectiveCommander _battery] findIf {
        !isNull _x && {alive _x} && {!(_x in _writers)}
    } >= 0}) exitWith {false};
// Every recorded return belongs to an original MOVE baseline. All living originals
// with that baseline must be accounted for; dead original recipients need no new order.
if (_returns findIf {
    !(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType objNull)}
        || {!((_x select 1) isEqualType [])} || {count (_x select 1) != 3}
        || {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        || {private _index=_original find (_x select 0);
            _index < 0 || {(_baseline select (_index*2)) != "MOVE"}
                || {(_x select 1) isNotEqualTo ((_baseline select (_index*2+1)) param [0,[],[[]]])}}
} >= 0) exitWith {false};
private _returnedActors=_returns apply {_x select 0};
if (count (_returnedActors arrayIntersect _returnedActors) != count _returnedActors) exitWith {false};
private _expected=[];
{
    private _index=_forEachIndex*2;
    if (_x in _writers && {(_baseline select _index) == "MOVE"}) then {
        private _point=(_baseline select (_index+1)) param [0,[],[[]]];
        _expected pushBack [_x,+_point];
    };
} forEach _original;
if ((_returns select {(_x select 0) in _writers}) isNotEqualTo _expected) exitWith {false};
private _observations=[_writers select 0,_writers param [1,_writers select 0]]
    call CBE_fnc_VehicleCrewNativeObservation;
if (count _observations != 4) exitWith {false};
private _arrival=[ASLToAGL getPosASL _battery,vectorMagnitude velocity _battery,
    vectorMagnitude angularVelocity _battery];
if (_expected isEqualTo []) exitWith {
    // No original MOVE to restore: require current idle, retained stop goal and physical rest.
    [0,2] findIf {!((_observations select _x) in ["","WAIT"])} < 0
        && {([_work getOrDefault ["goal",[]],_until,_observations,_observations,serverTime,_arrival]
            call CBE_fnc_VehicleCrewDestinationState) == "OWNED"}
};
_expected findIf {
    _x params ["_actor","_point"];
    private _offset=2*(_writers find _actor);
    private _sample=[_observations select _offset,_observations select (_offset+1),
        _observations select _offset,_observations select (_offset+1)];
    ([_point,_until,_sample,_sample,serverTime,_arrival] call CBE_fnc_VehicleCrewDestinationState) != "OWNED"
} < 0
