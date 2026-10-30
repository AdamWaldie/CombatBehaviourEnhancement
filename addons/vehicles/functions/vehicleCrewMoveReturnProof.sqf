/*
 * Author: WaldoTheWarfighter
 * Purpose: Read positive native retirement evidence after the exact original local worker ended.
 * Locality/authority: Read-only on current local platform/group/original actors. The producer
 * must still own the exact journal/reference. An actual completed private original FSM,
 * matching local worker serial/owner/episode epoch are required. RETURN additionally needs
 * recorded original return orders and every surviving idle original at its retained stop goal.
 * A remote done flag, ended timer or changed seat alone
 * is never sufficient.
 * Current group epoch and any recorded tactical generation must still match; this passive
 * check grants no new command authority. Caller runs it inside its unscheduled retirement call.
 * Repeat/JIP: No commands, publication, worker, replay or deadline renewal. Late evidence can
 * retire metadata after the old window, never grant another stop/return command. This does
 * not confirm a foreign owner's worker termination or arbitrary native supersession.
 * EXTERNAL_STOP only observes a newer native STOP on every surviving original operator,
 * aboard the original platform or dismounted, with measured platform rest. Dismounted
 * originals must also have measured individual rest. Another occupied platform refuses.
 * STOP is intentionally perpetual, so readiness is not required.
 * It never restores or cancels that newer order. A legacy FOLLOW baseline can be
 * superseded by this positive STOP proof; RETURN still refuses FOLLOW as unrestored.
 * EXTERNAL_FOLLOW retires only an ended issued-phase worker: every surviving original
 * must show current native FOLLOW to a living different formation anchor in its own group,
 * aboard this platform or dismounted. Replacement operators/another occupied platform refuse.
 * Native FOLLOW may still be moving; neither rest nor completed travel is inferred. It may
 * reflect native fallback rather than a new authored order. This proves only that this
 * completed positional worker no longer owns those native commands, not original formation
 * restoration. The caller retires the interrupted task; it never resumes a support bound.
 * Arguments: platform OBJECT,objNull; journal HASHMAP,empty; private worker ARRAY,[];
 * current private worker serial NUMBER,-1; optional evidence mode STRING,RETURN
 * (EXTERNAL_STOP: ended UNRESOLVED; EXTERNAL_FOLLOW: ended issued phase, never ISSUE).
 * Return: BOOL original return or positive native STOP/FOLLOW observed, not physical returned travel.
 * Current callers: VehicleCrewMoveRetire for exact ended-worker retirement.
 * Example: [_vehicle,_work,_privateWorker,_workerSerial] call CBE_fnc_VehicleCrewMoveReturnProof;
 */
params [["_battery",objNull,[objNull]],["_work",createHashMap,[createHashMap]],
    ["_executor",[],[[]]],["_executorSerial",-1,[0]],["_mode","RETURN",[""]]];
private _group=_work getOrDefault ["group",grpNull];
if (isNull _battery || {!local _battery} || {!(_group isEqualType grpNull)}
    || {isNull _group} || {!local _group} || {!(_mode in ["RETURN","EXTERNAL_STOP","EXTERNAL_FOLLOW"])}
    || {_mode == "RETURN" && {!("returns" in _work)}}
    || {_mode == "EXTERNAL_STOP" && {(_work getOrDefault ["phase",""]) != "UNRESOLVED"}}
    || {if (_mode == "EXTERNAL_FOLLOW") then {
        !((_work getOrDefault ["phase",""]) in ["REQUESTED","MOVING","HOLD","STOPPING","RETURNING","UNRESOLVED"])
    } else {!((_work getOrDefault ["phase",""]) in ["RETURNING","UNRESOLVED"])}}
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
// Current producers admit idle/WAIT/MOVE; legacy work may retain FOLLOW. Neither
// baseline is STOP and the worker only issues positional movement. A current STOP
// therefore supersedes the old native request; it does not prove FOLLOW restoration. Retire
// metadata only after the exact original private FSM has actually completed.
if (_mode == "EXTERNAL_STOP") exitWith {
    if (!(_seats isEqualType []) || {count _seats != 2}
        || {_seats findIf {!(_x isEqualType objNull)} >= 0}
        || {!(_baseline isEqualType [])} || {count _baseline != 4}
        || {[0,2] findIf {!((_baseline select _x) in ["","WAIT","MOVE","FOLLOW"])} >= 0}) exitWith {false};
    private _stoppedWriters=(_seats arrayIntersect _seats) select {!isNull _x && {alive _x}};
    if (_stoppedWriters isEqualTo [] || {_stoppedWriters findIf {
        private _parent=objectParent _x;
        !local _x || {group _x != _group}
            || {!isNull _parent && {_parent != _battery}}
            || {currentCommand _x != "STOP"}
            // The old vehicle being still does not prove a dismounted original
            // has stopped. Observe actual rest without issuing a stop/return.
            || {isNull _parent && {
                private _speed=vectorMagnitude velocity _x;
                !finite _speed || {_speed >= 0.278}
            }}
    } >= 0} || {[driver _battery,effectiveCommander _battery] findIf {
        !isNull _x && {alive _x} && {!(_x in _stoppedWriters)}
    } >= 0}) exitWith {false};
    private _linear=vectorMagnitude velocity _battery;
    private _angular=vectorMagnitude angularVelocity _battery;
    finite _linear && {finite _angular} && {_linear < 0.278} && {_angular < 0.01}
};
// This executor only issues positional movement. Positive current FOLLOW therefore
// belongs to native/another control path, not to an outstanding request from this worker.
// Observe every surviving original, never guess an anchor or issue formation recall.
if (_mode == "EXTERNAL_FOLLOW") exitWith {
    if (!(_seats isEqualType []) || {count _seats != 2}
        || {_seats findIf {!(_x isEqualType objNull)} >= 0}
        || {!(_baseline isEqualType [])} || {count _baseline != 4}
        || {[0,2] findIf {!((_baseline select _x) in ["","WAIT","MOVE","FOLLOW"])} >= 0}) exitWith {false};
    private _followingWriters=(_seats arrayIntersect _seats) select {!isNull _x && {alive _x}};
    if (_followingWriters isEqualTo [] || {_followingWriters findIf {
        if (!local _x || {group _x != _group}
            || {currentCommand _x != "FOLLOW"}) exitWith {true};
        private _parent=objectParent _x;
        private _anchor=formLeader _x;
        !isNull _parent && {_parent != _battery}
            || {isNull _anchor} || {!alive _anchor} || {_anchor == _x}
            || {group _anchor != _group}
    } >= 0} || {[driver _battery,effectiveCommander _battery] findIf {
        !isNull _x && {alive _x} && {!(_x in _followingWriters)}
    } >= 0}) exitWith {false};
    true
};
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
// MOVE recipients cannot vouch for a different surviving original's idle handback.
// Reuse the two cached native observations; no extra actor command/query or deadline.
private _idleOriginalsCurrent=_writers findIf {
    private _originalOffset=2*(_original find _x);
    if ((_baseline select _originalOffset) == "MOVE") exitWith {false};
    private _observationOffset=2*(_writers find _x);
    private _command=_observations select _observationOffset;
    private _destination=_observations select (_observationOffset+1);
    private _sample=[_command,_destination,_command,_destination];
    !(_command in ["","WAIT"]) || {
        ([_work getOrDefault ["goal",[]],_until,_sample,_sample,serverTime,_arrival]
            call CBE_fnc_VehicleCrewDestinationState) != "OWNED"
    }
} < 0;
if (!_idleOriginalsCurrent) exitWith {false};
_expected findIf {
    _x params ["_actor","_point"];
    private _offset=2*(_writers find _actor);
    private _sample=[_observations select _offset,_observations select (_offset+1),
        _observations select _offset,_observations select (_offset+1)];
    ([_point,_until,_sample,_sample,serverTime,_arrival] call CBE_fnc_VehicleCrewDestinationState) != "OWNED"
} < 0
