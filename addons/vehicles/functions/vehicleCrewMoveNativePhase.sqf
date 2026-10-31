/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one native phase of an already admitted finite selected-platform crew move.
 * Locality/authority: Internal current-owner executor only, never remote execution. The caller
 * validates its worker, exact original seats, task/native-route/Zeus/external authority and
 * supplies current native observations plus physical samples. Work arrivalRadius may narrow
 * the legacy25m artillery arrival area to1..25m; invalid policy requests normal retirement.
 * The current journal, owner,
 * epoch and at most two original active local crew are checked again before native writes.
 * This is not movement admission and cannot mint a session, lease, replacement crew or worker.
 * Repeat/JIP: One synchronous phase, original goal/baseline/reply/cleanup clocks retained.
 * Captured idle/WAIT/MOVE and explicitly journalled FOLLOW baselines have native return semantics.
 * FOLLOW requires original anchor/group-leader identity, a single recorded doFollow after rest,
 * and current native FOLLOW to that exact anchor. No group-wide recall or replacement anchor.
 * Unsupported legacy
 * baselines refuse before any further hold/return command or journal mutation and remain
 * unresolved after an already-issued move, never acknowledged as restored idle.
 * Idle-only and mixed MOVE/idle handback require every surviving idle original active, current idle goals and
 * measured platform rest; empty return arrays never prove retirement by themselves.
 * Nonlocal/inactive return recipients refuse before native order observation.
 * Every active phase also requires MOVE/WAIT/idle native command observations before
 * a hold/return write; matching destinations never authorize replacing FOLLOW or another
 * native task. Unknown/malformed command observations retire unresolved without a hold.
 * No publication, timer, independent FSM or replay. Caller publishes the changed journal
 * and applies its domain-specific terminal/arrival policy in the same unscheduled callback.
 * Arguments: 0 platform OBJECT,objNull; 1 current journal HASHMAP,empty; 2 journal key STRING,"";
 * 3 original seats ARRAY of two OBJECT,[]; 4 active original seats ARRAY of one/two OBJECT,[];
 * 5 current native observation ARRAY of four fields,[]; 6 current arrival ARRAY,[];
 * 7 original source still current BOOL,false; 8 measured platform at rest BOOL,false.
 * Return: ARRAY [next delay NUMBER, terminal reason STRING, retirement proved BOOL, publish journal BOOL].
 * Empty reason means continuation; nonempty reason must enter the caller's exact finalizer.
 * Current callers: ArtilleryCrewMoveStep and VehicleTacticalMoveStep, inside their unscheduled FSM callbacks.
 * Example: private _decision=[_vehicle,_work,_key,_seats,_active,_native,_arrival,
 *     _sourceCurrent,_rest] call CBE_fnc_VehicleCrewMoveNativePhase;
 */
params [["_battery",objNull,[objNull]],["_work",createHashMap,[createHashMap]],
    ["_journalKey","",[""]],["_seats",[],[[]]],["_activeSeats",[],[[]]],
    ["_observations",[],[[]]],["_arrivalSample",[],[[]]],
    ["_sourceCurrent",false,[true]],["_rest",false,[true]]];
private _group=_work getOrDefault ["group",grpNull];
if (remoteExecutedOwner > 0 || {isNull _battery} || {!local _battery}
    || {_journalKey == ""} || {isNull _group} || {!local _group}
    || {(_work getOrDefault ["owner",-1]) != clientOwner}
    || {(_work getOrDefault ["epoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",-2])}
    || {(_battery getVariable [_journalKey,createHashMap]) isNotEqualTo _work}
    || {count _seats != 2} || {!(count _activeSeats in [1,2])}
    || {_activeSeats findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}
        || {!local _x} || {!(_x in _seats)} || {group _x != _group}
        || {objectParent _x != _battery}} >= 0}) exitWith {[-1,"NATIVE_PHASE_AUTHORITY_CHANGED",false]};
private _phase=_work get "phase";
private _finish={params ["_reason",["_retired",false]];[-1,_reason,_retired]};
private _goal=+(_work get "goal");
private _goalsMatch={
    params ["_point"];
    [1,3] findIf {
        private _position=(_observations select _x) param [0,[],[[]]];
        count _position != 3 || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_position vectorDistance _point > 0.25}
    } < 0
};
private _followTargets=_work getOrDefault ["followTargets",[]];
private _hasFollow=(_work getOrDefault ["baseline",[]]) findIf {_x isEqualTo "FOLLOW"} >= 0;
private _followContextValid=!_hasFollow || {
    _followTargets isEqualType [] && {count _followTargets == 2}
        && {_followTargets findIf {!(_x isEqualType objNull)} < 0}
        && {(_work getOrDefault ["followGroupLeader",objNull]) == leader _group}
        && {[0,1] findIf {
            if (((_work get "baseline") select (_x*2)) != "FOLLOW") exitWith {false};
            private _anchor=_followTargets select _x;
            isNull _anchor || {!alive _anchor} || {_anchor == (_seats select _x)}
                || {group _anchor != _group}
        } < 0}
};
private _publish=false;
private _nativePhaseResult=call {
// Match passive return proof: current WAIT after our hold cannot stand in for an
// uncaptured legacy FOLLOW or another unimplemented native command. Refuse every phase before
// changing the journal or issuing a retirement hold as well as outward/return orders.
// Already-issued legacy work remains unresolved; refusal cannot undo its native request.
private _returnBaseline=_work getOrDefault ["baseline",[]];
private _baselineRestorable=_returnBaseline isEqualType [] && {count _returnBaseline == 4}
    && {[0,2] findIf {!((_returnBaseline select _x) in ["","MOVE","WAIT","FOLLOW"])
        || {!((_returnBaseline select (_x+1)) isEqualType [])}} < 0};
if (!_baselineRestorable || {!_followContextValid}) exitWith {
    ["NATIVE_RETURN_BASELINE_UNSUPPORTED",_phase == "ISSUE"] call _finish
};
// An asynchronous first MOVE can leave the original FOLLOW visible during its reply
// window. Its anchor may move, so compare identity rather than freezing coordinates.
// This grants PENDING only: FOLLOW can never satisfy positional OWNED acknowledgement.
private _pendingOriginalFollow={
    params ["_slot"];
    if (_phase != "REQUESTED" || {!_hasFollow} || {serverTime > (_work get "replyUntil")}
        || {(_observations select _slot) != "FOLLOW"}) exitWith {false};
    private _actor=_activeSeats param [_slot/2,_activeSeats select 0];
    private _originalIndex=_seats find _actor;
    _originalIndex >= 0 && {(_returnBaseline select (_originalIndex*2)) == "FOLLOW"}
        && {formLeader _actor == (_followTargets select _originalIndex)}
        && {((_work get "before") select _slot) == "FOLLOW"}
};
private _requestBefore=+(_work getOrDefault ["before",[]]);
if (_phase == "REQUESTED" && {count _observations == 4} && {count _requestBefore == 4}) then {
    {
        if ([_x] call _pendingOriginalFollow) then {
            _requestBefore set [_x+1,+(_observations select (_x+1))];
        };
    } forEach [0,2];
};
// Matching goal coordinates cannot make another native command ours. In particular,
// FOLLOW may retain the old endpoint while the engine changes formation intent. Refuse
// before retirement can replace that command with a hold/return, in every active phase.
if (_phase != "ISSUE" && {count _observations != 4
    || {[0,2] findIf {isNil {_observations select _x}
        || {!((_observations select _x) in ["","WAIT","MOVE"]) && {!([_x] call _pendingOriginalFollow)} && {
            // Only our recorded RETURNING request may observe FOLLOW without interruption.
            private _actor=_activeSeats param [_x/2,_activeSeats select 0];
            _phase != "RETURNING" || {!_hasFollow} || {(_observations select _x) != "FOLLOW"}
                || {(_work getOrDefault ["followReturns",[]]) findIf {
                    (_x select 0) == _actor && {(_x select 1) == formLeader _actor}
                } < 0}
        }}} >= 0}}) exitWith {
    ["ACTOR_NATIVE_COMMAND_REPLACED"] call _finish
};
// Refuse changed native actor orders. An issued MOVE may naturally settle into WAIT/idle.
if (_phase != "ISSUE" && {!([_goal] call _goalsMatch)}
    && {!(_phase in ["REQUESTED","STOPPING","RETURNING"])}) exitWith {["ACTOR_ORDER_REPLACED"] call _finish};
if (_phase == "REQUESTED" && {([_goal,_work get "replyUntil",_requestBefore,_observations,serverTime,_arrivalSample]
    call CBE_fnc_VehicleCrewDestinationState) == "LOST"}) exitWith {["ACTOR_ORDER_REPLACED"] call _finish};
// A delayed callback cannot mint or issue a retirement stop after the original window.
// Refuse before changing the goal/before receipt or writing any native command.
if (_work getOrDefault ["release",false] && {_phase != "ISSUE"}
    && {!(_phase in ["STOPPING","RETURNING"])}
    && {serverTime >= (_work getOrDefault ["cleanupUntil",(serverTime+30) min ((_work get "holdUntil")+30)])}) exitWith {
    ["RETIREMENT_TIMEOUT"] call _finish
};
if (_work getOrDefault ["release",false] && {!(_phase in ["STOPPING","RETURNING"])}) then {
    if (_phase == "ISSUE") exitWith {};
    private _hold=getPosATL _battery;
    _work set ["goal",+_hold];_goal=+_hold;
    _work set ["before",_observations];
    // A recovered worker inherits the first retirement window; it cannot mint another.
    if !("cleanupUntil" in _work) then {
        _work set ["cleanupUntil",(serverTime+30) min ((_work get "holdUntil")+30)];
    };
    _work set ["replyUntil",serverTime+2];
    {_x doMove _hold} forEach _activeSeats;
    _work set ["phase","STOPPING"];_publish=true;_phase="STOPPING";
};
if (_phase == "ISSUE") exitWith {
    if (!_sourceCurrent || {!canMove _battery} || {waterDamaged _battery}
        || {[0,1] findIf {
            private _offset=_x*2;
            private _command=_returnBaseline select _offset;
            (_observations select _offset) != _command || {
                if (_command == "FOLLOW") exitWith {
                    formLeader (_seats select _x) != (_followTargets select _x)
                };
                (_observations select (_offset+1)) isNotEqualTo (_returnBaseline select (_offset+1))
            }
        } >= 0}) exitWith {["ADMISSION_CHANGED",true] call _finish};
    _work set ["before",_observations];_work set ["replyUntil",serverTime+2];
    {_x doMove _goal} forEach _activeSeats;
    _work set ["phase","REQUESTED"];_publish=true;
    0.25
};
if (_phase == "REQUESTED") exitWith {
    private _ack=[_goal,_work get "replyUntil",_requestBefore,_observations,serverTime,_arrivalSample]
        call CBE_fnc_VehicleCrewDestinationState;
    if (_ack == "OWNED" && {serverTime <= (_work get "replyUntil")}) then {_work set ["phase","MOVING"];_publish=true};
    if (_ack == "LOST") exitWith {["ACTOR_ORDER_REPLACED"] call _finish};
    if (_ack == "EXPIRED" || {serverTime > (_work get "replyUntil")}) then {_work set ["release",true]};
    0.25
};
if (_phase == "MOVING") exitWith {
    private _arrivalRadius=_work getOrDefault ["arrivalRadius",25];
    if (!(_arrivalRadius isEqualType 0) || {!finite _arrivalRadius}
        || {_arrivalRadius < 1} || {_arrivalRadius > 25}) exitWith {
        _work set ["release",true];_publish=true;0.25
    };
    private _position=getPosASL _battery;
    if (_position vectorDistance (_work get "progressPosition") >= 3) then {
        _work set ["progressPosition",_position];_work set ["progressAt",serverTime];
    };
    if (_battery distance2D _goal <= _arrivalRadius && {abs ((getPosATL _battery select 2)-(_goal select 2)) <= 3}
        && {_rest}) then {
        _work set ["phase","HOLD"];_work set ["holdObservations",_observations];_publish=true;
        } else {
        if (serverTime >= (_work get "moveUntil") || {serverTime-(_work get "progressAt") >= 30}
            || {!canMove _battery} || {waterDamaged _battery}) then {_work set ["release",true]};
    };
    1
};
if (_phase == "HOLD") exitWith {
    if (!_rest || {!([_goal] call _goalsMatch)}) then {_work set ["release",true]};
    2
};
if (_phase in ["STOPPING","RETURNING"] && {serverTime >= (_work get "cleanupUntil")}) exitWith {
    ["RETIREMENT_TIMEOUT"] call _finish
};
if (_phase == "STOPPING") exitWith {
    private _ack=[_goal,_work get "replyUntil",_work get "before",_observations,serverTime,_arrivalSample]
        call CBE_fnc_VehicleCrewDestinationState;
    if (_ack == "LOST" && {!([_goal] call _goalsMatch)}) exitWith {["STOP_ORDER_REPLACED"] call _finish};
    if (_ack == "EXPIRED" && {!([_goal] call _goalsMatch)}) exitWith {["STOP_ORDER_UNKNOWN"] call _finish};
    if (_rest && {[_goal] call _goalsMatch}
        && {_activeSeats findIf {!(currentCommand _x in ["","WAIT"])} < 0}) then {
        private _baseline=_work get "baseline";
        private _returns=[];
        private _followReturns=[];
        {
            private _index=_forEachIndex*2;
            private _point=(_baseline select (_index+1)) param [0,[],[[]]];
            if (!isNull _x && {alive _x} && {_x in _activeSeats} && {(_baseline select _index) == "MOVE"}) then {
                _x doMove _point;_returns pushBack [_x,+_point];
            };
            if (!isNull _x && {alive _x} && {_x in _activeSeats} && {(_baseline select _index) == "FOLLOW"}) then {
                private _anchor=_followTargets select _forEachIndex;
                // Record before the native request; RETURNING observes only, never retries it.
                _followReturns pushBack [_x,_anchor];
                _work set ["followReturns",+_followReturns];
                _x doFollow _anchor;
            };
        } forEach (_seats arrayIntersect _seats);
        _work set ["followReturns",_followReturns];
        _work set ["returns",_returns];_work set ["replyUntil",serverTime+2];
        _work set ["phase","RETURNING"];_publish=true;
        };
    0.25
};
if (_phase == "RETURNING") exitWith {
    private _returns=_work get "returns";
    private _baseline=_work get "baseline";
    // A nonempty MOVE return list says nothing about the other original's idle order.
    // Use the caller's same-frame two-seat observation, including survivor duplication.
    private _originals=_seats arrayIntersect _seats;
    private _survivingOriginals=_originals select {!isNull _x && {alive _x}};
    private _idleOriginalsCurrent=(_returns isEqualTo [] && {!_hasFollow}) || {_survivingOriginals isNotEqualTo []
        && {_survivingOriginals findIf {!(_x in _activeSeats)} < 0}
        && {_survivingOriginals findIf {
            private _originalOffset=2*(_originals find _x);
            if ((_baseline select _originalOffset) == "MOVE") exitWith {false};
            if ((_baseline select _originalOffset) == "FOLLOW") exitWith {false};
            private _observationOffset=2*(_activeSeats find _x);
            private _command=_observations select _observationOffset;
            private _destination=_observations select (_observationOffset+1);
            private _sample=[_command,_destination,_command,_destination];
            !(_command in ["","WAIT"]) || {
                ([_goal,_work get "replyUntil",_sample,_sample,serverTime,_arrivalSample]
                    call CBE_fnc_VehicleCrewDestinationState) != "OWNED"
            }
        } < 0}};
    // Empty return orders mean an original idle baseline, not automatic handback.
    // Reuse the same current-goal/physical-rest evidence as passive retirement proof.
    private _ack=if (_returns isEqualTo [] && {!_hasFollow}) then {
        private _survivors=(_seats arrayIntersect _seats) select {!isNull _x && {alive _x}};
        _rest && {_survivors isNotEqualTo []}
            && {_survivors findIf {!(_x in _activeSeats)} < 0}
            && {_activeSeats findIf {!(currentCommand _x in ["","WAIT"])} < 0}
            && {([_goal,_work get "replyUntil",_observations,_observations,serverTime,_arrivalSample]
                call CBE_fnc_VehicleCrewDestinationState) == "OWNED"}
    } else {
        _returns findIf {
            _x params ["_actor","_point"];
            if (isNull _actor || {!alive _actor}) exitWith {false};
            if (!local _actor || {!(_actor in _activeSeats)}) exitWith {true};
            private _native=expectedDestination _actor;
            private _command=currentCommand _actor;
            private _sample=[_command,_native,_command,_native];
            ([_point,_work get "replyUntil",_sample,_sample,serverTime,_arrivalSample]
                call CBE_fnc_VehicleCrewDestinationState) != "OWNED"
        } < 0
    };
    private _followAck=!_hasFollow || {
        private _expectedFollow=[];
        {
            if ((_baseline select (_forEachIndex*2)) == "FOLLOW" && {_x in _activeSeats}) then {
                _expectedFollow pushBack [_x,_followTargets select _forEachIndex];
            };
        } forEach _originals;
        private _recorded=_work getOrDefault ["followReturns",[]];
        // Dead originals need no recall, but missing/changed living recipients never pass.
        (_recorded select {(_x select 0) in _activeSeats}) isEqualTo _expectedFollow
            && {_survivingOriginals findIf {!(_x in _activeSeats)} < 0}
            && {_expectedFollow findIf {
                _x params ["_actor","_anchor"];
                currentCommand _actor != "FOLLOW" || {formLeader _actor != _anchor}
            } < 0}
    };
    if (_ack && {_idleOriginalsCurrent} && {_followAck}) exitWith {["NATIVE_RETURN_ACKNOWLEDGED",true] call _finish};
    if (serverTime > (_work get "replyUntil")) exitWith {["NATIVE_RETURN_UNKNOWN"] call _finish};
    0.25
};
["INVALID_PHASE"] call _finish

};
if (_nativePhaseResult isEqualType []) exitWith {_nativePhaseResult};
[_nativePhaseResult,"",false,_publish]
