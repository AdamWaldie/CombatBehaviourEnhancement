/*
 * Author: WaldoTheWarfighter
 * Purpose: Maintains three-dimensional physical progress for one existing operation and identifies
 * bounded recovery needs. Vertical travel counts; recovery arrival requires the destination floor band.
 * Malformed/nonfinite actor reservations remain owned through the shared predicate. Hidden,
 * simulation-disabled or movement-disabled actors retire recovery observations as temporary
 * ownership, retaining spent retry counts without false progress or capability quarantine.
 * Captured participant/fallback platforms exclude later transport or vehicle switches from progress.
 * Explicitly admitted mounted crews retain their original vehicle domain. Missing legacy receipts
 * permit foot observation only; they never infer a new mounted domain.
 * Queued ACE treatment is temporary task ownership even before the native HEAL command.
 * Recovery observations for no-longer-eligible participants retire before timeout handling;
 * observed incapacitation/capture/owner changes cannot become a stale failure on return.
 * CLEAR destination failures retire the recovery observation without quarantining a capable actor;
 * its building worker retains per-room failure evidence and the generation retry budget stays spent.
 * Locality/authority: Current group owner only; it never creates a replacement route or issues a movement order.
 * Repeat/JIP: Observations use isolated records and commit only against unchanged current input. Cancelled operations cannot be republished. Updates the current generation only. Changed progress, roster and recovery state are public; unchanged no-progress observations are not rebroadcast. Cadence is local and rebuilt after migration.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 minimum progress <NUMBER, 3>; 3 stale seconds <NUMBER, 12>; 4 allow own CBE feature <BOOL, false>.
 * Return Value: STRING - ACTIVE, STALLED, LOST_OWNER, ZEUS, EXTERNAL or REPLACED.
 * Current callers: shared group operation jobs.
 * Example: [group player,4] call CBE_fnc_OperationStep;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_minimum",3,[0]],["_staleSeconds",12,[0]],["_allowFeatureOwner",false,[true]]];
if (isNull _group || {!local _group}) exitWith {"LOST_OWNER"};
// Snapshot bookkeeping before scheduled observations. Arrays and the mutable child maps must
// not alias public state: a stale observation may be discarded without changing its successor.
private _entryEpoch=-1;
private _entryOperation=createHashMap;
isNil {
    _entryEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
    private _live=_group getVariable ["CBE_Operation",createHashMap];
    {
        private _value=_live get _x;
        if (_value isEqualType []) then {_value=+_value};
        if (_value isEqualType createHashMap) then {
            private _child=_value;
            _value=createHashMapFromArray (keys _child apply {
                private _item=_child get _x;
                [_x,if (_item isEqualType []) then {+_item} else {_item}]
            });
        };
        _entryOperation set [_x,_value];
    } forEach keys _live;
};
private _operation=createHashMapFromArray (keys _entryOperation apply {[_x,_entryOperation get _x]});
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {"REPLACED"};
if ((_operation getOrDefault ["phase",""]) == "CANCELLED") exitWith {"REPLACED"};
// The route and callback belong to the owner epoch that created them.  Locality handlers normally
// retire that generation before discovery rebuilds semantic intent, but this guard also covers an
// out-of-order Local event or an HC handoff that races a queued callback.
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])) exitWith {"LOST_OWNER"};
if ([_group] call CBE_fnc_CortexZeusHeld) exitWith {"ZEUS"};
if !([_group,false,false,_allowFeatureOwner] call CBE_fnc_CortexIsEligible) exitWith {"EXTERNAL"};
// Progress belongs to the actors committed to this operation, not automatically to the group
// leader. A leader can deliberately provide exterior security during CLEAR while the entry element
// is advancing through rooms; leader-only accounting would misclassify that working operation as stalled.
private _declaredParticipants=_operation getOrDefault ["participants",[]];
private _participantsRequired=_operation getOrDefault ["participantsRequired",_declaredParticipants isNotEqualTo []];
private _platforms=_operation getOrDefault ["participantPlatforms",createHashMap];
private _legacyFoot=!("participantPlatforms" in _operation);
if (!(_platforms isEqualType createHashMap)) then {_platforms=createHashMap};
private _originalParticipants=_declaredParticipants select {
    private _platform=_platforms getOrDefault [netId _x,[objNull,_x] select _legacyFoot];
    [_x] call CBE_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x} && {group _x == _group}
        && {isNull (remoteControlled _x)} && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
        && {_platform isEqualType objNull} && {!isNull _platform} && {vehicle _x == _platform}
};
// A recovery order has one bounded observation window. If its actor remains stationary after that
// window, record the actor as unavailable and let the remaining element continue. Do not turn one
// failed path into a group-wide retry loop or fabricate the actor's progress.
private _recoverySource=_operation getOrDefault ["recovery",createHashMap];
private _recovery=createHashMapFromArray (keys _recoverySource apply {[_x,_recoverySource get _x]});
private _unavailable=+(_operation getOrDefault ["unavailable",[]]);
private _temporarilyOwned=[];
private _recoveryChanged=false;
private _unavailableCount=count _unavailable;
// An actor excluded before the recovery loop (incapacitated, captured, departed or nonlocal)
// cannot retain a running path observation. Otherwise revival/return ages that old record into
// a false path failure. Retire bookkeeping only; the generation's spent attempt remains spent.
if (count _recovery > 0) then {
    private _eligibleRecoveryKeys=createHashMapFromArray (_originalParticipants apply {[netId _x,true]});
    {
        if (!(_x in _eligibleRecoveryKeys)) then {
            _recovery deleteAt _x;
            _recoveryChanged=true;
        };
    } forEach keys _recovery;
};

{
    private _actor=_x;
    private _key=netId _actor;
    private _record=_recovery getOrDefault [_key,[]];
    private _reserved=[_actor] call CBE_fnc_CortexActorMoveReserved;
    private _nativeTask=(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []
        || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]};
    private _suspended=!simulationEnabled _actor || {isObjectHidden _actor}
        || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")};
    if (_reserved || {_nativeTask} || {_suspended}) then {
        // A newer owner invalidates this recovery observation, not the actor's capability.
        // Keep its retry count in recoveryAttempts; retire no other actor's route or record.
        if (_key in _recovery) then {_recoveryChanged=true};
        _recovery deleteAt _key;
        _temporarilyOwned pushBack _actor;
    };
    if (!_reserved && {!_nativeTask} && {!_suspended} && {_record isEqualType []} && {count _record >= 2}) then {
        _record params ["_attempts","_startedAt",["_destination",[],[[]]],["_startPosition",getPosATL _actor,[[]]]];
        if (_attempts > 0 && {time-_startedAt >= _staleSeconds}) then {
            private _currentPosition=getPosATL _actor;
            if (count _destination >= 2 && {_actor distance2D _destination <= 4}
                && {count _destination < 3 || {abs (((getPosATL _actor) select 2)-(_destination select 2)) <= 1.5}}) then {
                _recovery deleteAt _key;
                _recoveryChanged=true;
            } else {
                private _recoveryDestination=+_destination;
                if (count _recoveryDestination == 2) then {_recoveryDestination pushBack (_startPosition select 2)};
                private _closer=count _recoveryDestination == 3
                    && {(_startPosition vectorDistance _recoveryDestination)-(_currentPosition vectorDistance _recoveryDestination) >= _minimum};
                if (_closer) then {
                    // The isolated actor is approaching its assigned destination. Lateral travel or circling cannot renew the retry. Renew only its observation window; its
                    // travel cannot mask a stalled manoeuvre element or reset operation progress.
                    _recovery set [_key,[_attempts,time,+_destination,_currentPosition]];
                    _recoveryChanged=true;
                } else {
                    // A failed CLEAR destination may be an inaccessible model node, not
                    // an incapable soldier. The building worker retires that room attempt
                    // through failedBy/unreachable and can use this actor in another room.
                    // Keep the generation's retry budget; no recovery attempt is renewed.
                    if ((_operation getOrDefault ["intent",""]) != "CLEAR") then {
                        _unavailable pushBackUnique _actor;
                    };
                    // End this observation without forgetting its generation retry budget.
                    _recovery deleteAt _key;
                    _recoveryChanged=true;
                };
            };
        };
    };
} forEach _originalParticipants;
private _recovering=[];
// Recovery actors are intentionally absent from aggregate progress. Their isolated movement is
// useful, but it must never keep a stationary assault, withdrawal or clearance operation alive.
{
    private _actor=_x;
    private _record=_recovery getOrDefault [netId _actor,[]];
    if (_record isEqualType [] && {count _record >= 2} && {(_record select 0) > 0}) then {
        _recovering pushBack _actor;
    };
} forEach _originalParticipants;
private _participants=_originalParticipants select {!(_x in _unavailable) && {!(_x in _recovering)} && {!(_x in _temporarilyOwned)}};
private _records=_operation getOrDefault ["participantProgress",[]];
private _updated=[];
private _progressed=false;
private _progressActor=objNull;
{
    _x params ["_actor","_lastPosition"];
    if (_actor in _participants) then {
        private _currentPosition=getPosATL _actor;
        private _actorProgressed=simulationEnabled _actor && {!isObjectHidden _actor}
            && {_currentPosition vectorDistance _lastPosition >= _minimum};
        if (_actorProgressed) then {
            _progressed=true;
            _progressActor=_actor;
            _recovery deleteAt (netId _actor);
        };
        // Preserve the last meaningful baseline until this actor crosses the configured
        // distance. Replacing it on every scheduler callback made slow, continuous travel
        // look stationary because sub-threshold increments could never accumulate.
        _updated pushBack [_actor,[_lastPosition,_currentPosition] select _actorProgressed];
    };
} forEach _records;
{
    private _participant=_x;
    if (_updated findIf {(_x select 0) == _participant} < 0) then {
        _updated pushBack [_participant,getPosATL _participant];
    };
} forEach _participants;
// Some finite operations intentionally have no foot participants. Preserve leader-based progress
// only for that case, rather than requiring a vehicle or support operation to manufacture an actor roster.
if (_participants isEqualTo [] && {!_participantsRequired}) then {
    private _leader=leader _group;
    private _position=getPosATL _leader;
    private _platform=_operation getOrDefault ["progressPlatform",objNull];
    private _onFoot=_operation getOrDefault ["progressOnFoot",true];
    private _sameDomain=_onFoot isEqualType true && {
        if (_onFoot) then {vehicle _leader == _leader} else {
            _platform isEqualType objNull && {!isNull _platform} && {vehicle _leader == _platform}
        }
    };
    if (_sameDomain && {simulationEnabled _leader} && {!isObjectHidden _leader}
        && {_position distance2D (_operation getOrDefault ["lastProgressPosition",_position]) >= _minimum}) then {
        _progressed=true;
        _progressActor=_leader;
        _operation set ["lastProgressPosition",_position];
    };
};
private _changed=false;
private _status=if (_progressed) then {
    _operation set ["participantProgress",_updated];
    _operation set ["recovery",_recovery];
    _operation set ["unavailable",_unavailable];
    _operation set ["lastProgressActor",_progressActor];
    if (!isNull _progressActor) then {_operation set ["lastProgressPosition",getPosATL _progressActor]};
    _operation set ["lastProgressAt",time];
    _operation set ["replans",0];
    _changed=true;
    "ACTIVE"
} else {
    _changed=_recoveryChanged || {count _unavailable != _unavailableCount}
        || {_updated isNotEqualTo _records};
    _operation set ["participantProgress",_updated];
    _operation set ["recovery",_recovery];
    _operation set ["unavailable",_unavailable];

    if (_participantsRequired && {_participants isEqualTo []}) then {
        // An isolated retry owns one bounded observation window. An empty aggregate
        // roster must not cancel that fresh attempt before it can physically execute.
        // No progress timestamp is renewed, and another stationary element still stalls.
        private _pendingRecovery=_recovering findIf {
            private _record=_recovery getOrDefault [netId _x,[]];
            count _record >= 2 && {time-(_record select 1) < _staleSeconds}
        } >= 0;
        ["STALLED","ACTIVE"] select _pendingRecovery
    } else {
        if (time-(_operation getOrDefault ["lastProgressAt",time]) >= _staleSeconds) then {"STALLED"} else {"ACTIVE"}
    }
};
// Only publication is unscheduled. Reject a changed roster/retry journal rather than overwriting
// another worker, and never revive a removed or cancelled generation after cleanup.
private _committedStatus="REPLACED";
isNil {
    _committedStatus=call {
        if (isNull _group || {!local _group}
            || {_entryEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {"LOST_OWNER"};
        private _current=_group getVariable ["CBE_Operation",createHashMap];
        if ((_current getOrDefault ["generation",-2]) != _generation
            || {(_current getOrDefault ["phase",""]) == "CANCELLED"}) exitWith {"REPLACED"};
        if ([_group] call CBE_fnc_CortexZeusHeld) exitWith {"ZEUS"};
        if !([_group,false,false,_allowFeatureOwner] call CBE_fnc_CortexIsEligible) exitWith {"EXTERNAL"};
        // Same-generation bookkeeping advanced elsewhere. Defer this observation without
        // renewing any clock or ending the live feature; the next cadence reads fresh inputs.
        if (_current isNotEqualTo _entryOperation) exitWith {"ACTIVE"};
        if (_changed) then {_group setVariable ["CBE_Operation",_operation,true]};
        _status
    };
};
_committedStatus
