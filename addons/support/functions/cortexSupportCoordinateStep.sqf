/*
 * Author: WaldoTheWarfighter
 * Coordinates reserved assault squads through short bounds while other squads provide cover.
 * Publishes the original MOVE deadline with token/sequence/point before its role; owners
 * require both matching receipts, never presumed cross-machine event ordering.
 * Locality/authority: server publishes tokened roles; each group owner executes its fire teams.
 * Repeat/JIP: roles are durable snapshots; only changed roles are broadcast. Existing support
 * lease expiry, exclusion and Zeus cancellation remain authoritative. At most six groups are read.
 * Local actor reservations use the shared strict validator; nonlocal nonempty markers remain
 * reserved because only their owner can interpret expiry. Owner execution still validates admission.
 * Exact group/token membership retires superseded bounds without penalising a successor. Public
 * roles, retry clocks and aborts revalidate that reservation inside unscheduled write boundaries.
 * A partial bound is useful progress and hands movement to the next squad, but never completes
 * the final assault objective; that squad remains eligible to finish its committed approach. Stalls are counted per
 * squad; one unreliable element can recover or retire without cancelling the other manoeuvre and
 * base-of-fire roles. Retirement publishes the exact reservation token for owner-side release; an
 * older abort cannot cancel a replacement task. A squad which can no longer form two viable fire
 * teams is retired immediately instead of keeping the whole action alive until lease expiry. The server watchdog follows the
 * configured owner-side bound timeout and retries after eight seconds. Bound length scales with
 * remaining distance to avoid slow fixed-step movement. Each new bound chooses once among the direct
 * line and two shallow alternatives through the shared terrain/fire-lane selector, so a valid overall
 * approach does not place the next bound in water, on a cliff-like slope or across supporting fire.
 * The configured number of squads on separated approaches
 * may bound concurrently; each still alternates its own moving and covering fire teams. This removes
 * the former four-deep serial queue without turning the whole force into one unsupported rush.
 * Arguments: 0: request <HASHMAP>; 1: accepted leases <ARRAY>, required.
 * Return: Nothing. Current caller: CortexSupportStep.
 * Example: [_job,_kept] call CBE_fnc_CortexSupportCoordinateStep;
 */
params ["_job","_leases"];
if (!isServer || {!(_job getOrDefault ["assaultIssued",false])}) exitWith {};
// A group identity alone does not preserve the authority of its previous reservation.
// Use this again inside every public-write transaction after scheduled scoring/observation.
private _sameLease={
    params ["_group","_token"];
    if (isNull _group) exitWith {false};
    private _lease=_group getVariable ["CBE_AIPass_SupportLease",[]];
    count _lease == 6 && {(_lease select 0) == _token}
        && {serverTime < (_lease select 2)} && {(_lease select 5) isNotEqualTo []}
};
private _teams=[];
{
    _x params ["_group","_token","","","_accepted"];
    private _lease=_group getVariable ["CBE_AIPass_SupportLease",[]];
    if (_accepted == "ACCEPTED" && {count _lease == 6} && {(_lease select 0) == _token}
        && {serverTime < (_lease select 2)} && {(_lease select 5) isNotEqualTo []}
        && {[_group,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled}) then {
        _teams pushBack [_group,_token,_lease select 5];
    };
} forEach _leases;
if (_teams isEqualTo []) exitWith {};
private _completed=_job getOrDefault ["boundCompleted",[]];
private _retired=_job getOrDefault ["boundRetired",[]];
private _failuresByToken=_job getOrDefault ["boundFailuresByToken",createHashMap];
private _activeRaw=_job getOrDefault ["boundActive",[]];
// Accept the pre-concurrency single record during a live mission update, then publish the new list.
private _active=if (_activeRaw isEqualTo []) then {[]} else {
    if ((_activeRaw select 0) isEqualType grpNull) then {[_activeRaw]} else {+_activeRaw}
};
private _stillActive=[];
{
    _x params ["_group","_sequence","_deadline","_final","_token"];
    isNil {
    if (_teams findIf {(_x select 0) == _group && {(_x select 1) == _token}} < 0
        || {!([_group,_token] call _sameLease)}) exitWith {};
    private _result=_group getVariable ["CBE_Cortex_SupportBoundResult",[]];
    private _finished=count _result == 3 && {(_result select 0) == _token} && {(_result select 1) == _sequence};
    if (_finished || {serverTime >= _deadline}) then {
        private _outcome=if (_finished) then {_result select 2} else {"TIMEOUT"};
        private _progressed=_outcome in ["COMPLETE","PARTIAL"];
        // A failed mover yields its turn; it cannot freeze or cancel the other squads.
        if (!_progressed) then {
            _group setVariable ["CBE_Cortex_SupportRetryAfter",serverTime+8];
            private _failures=(_failuresByToken getOrDefault [_token,0])+1;
            _failuresByToken set [_token,_failures];
            _job set ["boundFailuresByToken",_failuresByToken];
            if (_failures >= 2) then {
                _retired pushBackUnique _token;
                _job set ["boundRetired",_retired];
                _group setVariable ["CBE_Cortex_SupportAbort",
                    [_token,serverTime,"BOUND_FAILURES",_failures],true];
            };
        };
        // Partial progress yields a turn but is not completion of the final assault. Keep the
        // same objective available so the next committed bound finishes the remaining distance.
        if (_outcome == "COMPLETE" && {_final}) then {
            _completed pushBackUnique _token;
            _job set ["boundCompleted",_completed];
        };
    } else {
        _stillActive pushBack _x;
    };
    };
} forEach _active;
_active=_stillActive;
_job set ["boundActive",_active];
private _sequence=_job getOrDefault ["boundSequence",0];
private _routeFailuresByToken=_job getOrDefault ["routeFailuresByToken",createHashMap];
// Casualties can make a formerly valid responder unable to field a moving and covering pair.
// Retire it here so it cannot be reconsidered every two seconds until the lease ends.
{
    _x params ["_group","_token"];
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _unavailable=_operation getOrDefault ["unavailable",[]];
    private _fit=(units _group) select {
        [_x] call CBE_fnc_CortexCombatEffective && {isNull objectParent _x}
            && {!(_x in _unavailable)} && {!isPlayer _x} && {isNull remoteControlled _x}
            && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
            && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
    };
    if (count _fit < 3 && {!(_token in _completed)} && {!(_token in _retired)}) then {
        isNil {
            if !([_group,_token] call _sameLease) exitWith {};
            _retired pushBackUnique _token;
            _group setVariable ["CBE_Cortex_SupportAbort",
                [_token,serverTime,"INSUFFICIENT_STRENGTH",count _fit],true];
        };
    };
} forEach _teams;
_job set ["boundRetired",_retired];

private _cursor=_job getOrDefault ["boundCursor",0];
private _maxConcurrent=(count _teams) min (_job getOrDefault ["boundMaxConcurrent",2]);
for "_slot" from count _active to (_maxConcurrent-1) do {
    private _next=grpNull;
    private _point=[];
    private _nextIndex=-1;
    for "_offset" from 0 to ((count _teams)-1) do {
        // Eligibility is not route acceptance. Try another element after unsafe geometry,
        // but stop before any further scoring once this slot has a viable bound.
        if (!isNull _next) exitWith {};
        private _index=(_cursor+_offset) mod count _teams;
        (_teams select _index) params ["_group","_token","_goal"];
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _unavailable=_operation getOrDefault ["unavailable",[]];
    private _fit=(units _group) select {
        [_x] call CBE_fnc_CortexCombatEffective && {isNull objectParent _x}
            && {!(_x in _unavailable)} && {!isPlayer _x} && {isNull remoteControlled _x}
            && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
            && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
    };
        _fit=_fit select {
            private _reservation=_x getVariable ["CBE_Cortex_ActorMove",[]];
            // Reservation deadlines use the actor owner's clock. The coordinator may inspect
            // an empty remote marker, but cannot declare a remote or malformed lease expired.
            private _free=if (local _x) then {
                !([_x] call CBE_fnc_CortexActorMoveReserved)
            } else {
                _reservation isEqualTo []
            };
            _free && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
        };
        if (count _fit >= 3 && {serverTime >= (_group getVariable ["CBE_Cortex_SupportRetryAfter",0])}
            && {!(_token in _completed)} && {!(_token in _retired)}
            && {_active findIf {(_x select 4) == _token} < 0}
            // Concurrent movers need genuinely different approach lanes. A second squad on the
            // same endpoint remains COVER until the first has yielded its turn.
            && {_active findIf {
                private _activeGroup=_x select 0;
                private _activeTeam=_teams findIf {(_x select 0) == _activeGroup};
                _activeTeam >= 0 && {((_teams select _activeTeam) select 2) distance2D _goal < 60}
            } < 0}) then {
            private _centre=[0,0,0];
            {_centre=_centre vectorAdd getPosATL _x} forEach _fit;
            _centre=_centre vectorMultiply (1/count _fit);
            private _remaining=_centre distance2D _goal;
            private _boundLength=(_remaining*0.35) max 45 min 70;
            private _distance=_boundLength min _remaining;
            private _bearing=_centre getDir _goal;
            private _candidateRoutes=[];
            {
                _candidateRoutes pushBack [_centre getPos [_distance,_bearing+_x]];
            } forEach [0,-18,18];
            private _requester=_job getOrDefault ["requester",grpNull];
            private _requesterTransmitter=[_requester] call CBE_fnc_CortexGroupTransmitter;
            private _supportOrigins=if (isNull _requesterTransmitter) then {[]} else {[getPosATL _requesterTransmitter]};
            // Other covering elements also own live fire lanes. Reuse this operation's
            // bounded responder list; do not scan nearby groups or moving elements.
            {
                _x params ["_coverGroup","_coverToken"];
                if (_coverGroup != _group && {!(_coverToken in _completed)}
                    && {!(_coverToken in _retired)}
                    && {_active findIf {(_x select 0) == _coverGroup} < 0}) then {
                    private _coverTransmitter=[_coverGroup] call CBE_fnc_CortexGroupTransmitter;
                    if (!isNull _coverTransmitter) then {
                        _supportOrigins pushBackUnique (getPosATL _coverTransmitter);
                    };
                };
            } forEach (_teams select [0,6]);
            private _selected=[_centre,_candidateRoutes,_job get "assaultEnemy",_supportOrigins]
                call CBE_fnc_CortexSelectAvenue;
            if (_selected isNotEqualTo []) then {
                _routeFailuresByToken deleteAt _token;
                _point=+(_selected select ((count _selected)-1));
                _next=_group;
                _nextIndex=_index;
                _sequence=_sequence+1;
                _job set ["boundSequence",_sequence];
                private _boundTimeout=missionNamespace getVariable ["CBE_AIPass_Flank_BoundTimeout",25];
                private _watchdog=(((_boundTimeout max 10)*4)+15) min 180;
                _active pushBack [_group,_sequence,serverTime+_watchdog,_point distance2D _goal < 2,_token,+_point];
            } else {
                // Geometry failure must not become a repeated hot-path scan or indefinite cover.
                // One delayed retry can exploit changed positions; retire only this element after it.
                isNil {
                if !([_group,_token] call _sameLease) exitWith {};
                private _routeFailures=(_routeFailuresByToken getOrDefault [_token,0])+1;
                _routeFailuresByToken set [_token,_routeFailures];
                _group setVariable ["CBE_Cortex_SupportRetryAfter",serverTime+8];
                if (_routeFailures >= 2) then {
                    _retired pushBackUnique _token;
                    _group setVariable ["CBE_Cortex_SupportAbort",[_token,serverTime,"NO_SAFE_BOUND",_routeFailures],true];
                };
                };
            };
        };
    };
    if (!isNull _next) then {_cursor=(_nextIndex+1) mod count _teams};
};
_job set ["routeFailuresByToken",_routeFailuresByToken];
_job set ["boundRetired",_retired];
_job set ["boundCursor",_cursor];
_job set ["boundActive",_active];
{
    _x params ["_group","_token","_goal"];
    private _old=_group getVariable ["CBE_Cortex_SupportRole",[]];
    private _activeIndex=_active findIf {(_x select 0) == _group && {(_x select 4) == _token}};
    private _moving=_activeIndex >= 0;
    private _role=if (_moving) then {
        private _record=_active select _activeIndex;
        private _activePoint=_record param [5,[]];
        if (_activePoint isEqualTo [] && {count _old == 5}
            && {(_old select 0) == _token} && {(_old select 1) == (_record select 1)}) then {
            +_old
        } else {
            [_token,_record select 1,"MOVE",+_activePoint,+(_job get "assaultEnemy")]
        }
    } else {
        [_token,_sequence,"COVER",[],+(_job get "assaultEnemy")]
    };
    isNil {
        if !([_group,_token] call _sameLease) exitWith {};
        // Publish the original server bound lifetime with its exact role identity.
        // Owner admission waits for both receipts; arrival order cannot create extra time.
        private _roleDeadline=[];
        if (_moving) then {
            private _record=_active select _activeIndex;
            private _leaseNow=_group getVariable ["CBE_AIPass_SupportLease",[]];
            _roleDeadline=[_token,_record select 1,(_record select 2) min (_leaseNow select 2),+(_role select 3)];
        };
        if ((_group getVariable ["CBE_Cortex_SupportRoleDeadline",[]]) isNotEqualTo _roleDeadline) then {
            _group setVariable ["CBE_Cortex_SupportRoleDeadline",_roleDeadline,true];
        };
        // Compare the live role here: neither a stale unchanged-role observation nor a
        // cancelled lease may overwrite a successor while the scorer was scheduled.
        if ((_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _role) then {
            _group setVariable ["CBE_Cortex_SupportRole",_role,true];
        };
    };
} forEach _teams;

if (_teams findIf {!((_x select 1) in _completed) && {!((_x select 1) in _retired)}} < 0) then {
    _job set ["expiry",(_job get "expiry") min (serverTime+10)]
};
