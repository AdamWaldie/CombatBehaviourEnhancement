/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Adds one job to this machine's Smart AI Pass scheduler.
 *
 * A job is code that takes one state HASHMAP and returns the number of seconds until it should run
 * again, or -1 when it has finished. Jobs never sleep: the scheduler runs them unscheduled inside a
 * per-tick time budget. New jobs wait in a pending list that the next tick merges, so a job may
 * safely queue another job while it runs. The earliest queued due time is cached so the frame
 * scheduler callback can return without walking every group while all work is still waiting.
 * Locality and authority: machine-local. Jobs and their state are never broadcast.
 *
 * Arguments:
 * 0: job <CODE> - receives [state] and returns the next delay in seconds or -1
 * 1: state <HASHMAP> - job-owned state carried between runs
 * 2: delay <NUMBER> - finite seconds before the first run (optional, default: 0).
 * Invalid delay retires the supplied finite state without publishing a queue entry.
 * 3: jobKey <STRING> - optional owner-local key. A later job with this key updates and wakes the existing callback instead of appending a competing callback.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [CBE_fnc_CortexRegroupStep, createHashMapFromArray [["group", _group]], 5] call CBE_fnc_CortexQueueJob;
 * Result: the regroup step runs on this machine about five seconds later.
 *
 * Current callers: group/indoor/building/driving/convoy/air/support FSM queue adapters,
 * discovery, finite tactical reactions, aircraft observers and skill-lighting initialization.
 */

params [["_job", {}, [{}]], ["_state", createHashMap, [createHashMap]], ["_delay", 0, [0]], ["_jobKey", "", [""]]];
private _group = _state getOrDefault ["group", grpNull];
private _rejectFiniteBrain={
    params [["_queueReason","STALE_QUEUE_OWNER",[""]]];
    _state set ["cancelled",true];
    _state set ["cancelReason",_queueReason];
    if ("pending" in _state && {"completed" in _state}) then {
        _state set ["pending",false];
        _state set ["completed",true];
        _state set ["cancelled",true];
        _state set ["cancelReason",_queueReason];
    };
};
// Reject invalid scheduling before owner metadata or queue publication changes.
if (!finite _delay || {!finite (time + (_delay max 0))}) exitWith {["INVALID_JOB_DELAY"] call _rejectFiniteBrain};
if ("group" in _state && {isNull _group}) exitWith {[] call _rejectFiniteBrain};
// A queue is not an ownership-adoption boundary. Preserve supplied authority proof:
// stamping today's epoch onto an old brain would make stale work appear current.
if (!isNull _group && {!local _group
    || {(_state getOrDefault ["ownerEpoch",_group getVariable ["CBE_AIPass_Epoch",0]])
        != (_group getVariable ["CBE_AIPass_Epoch",0])}}) exitWith {[] call _rejectFiniteBrain};
if (!isNull _group) then {_state set ["ownerEpoch", _group getVariable ["CBE_AIPass_Epoch", 0]]};
if (_jobKey == "") then {_jobKey = _state getOrDefault ["jobKey", ""]};
if (_jobKey != "") then {_state set ["jobKey", _jobKey]};
private _dueAt = time + (_delay max 0);
// Only callers with a deliberate, stable key are coalesced. This keeps independent grenade,
// artillery and group operations separate while a burst of updates for the same owner wakes its
// existing finite callback immediately.
private _existingState = createHashMap;
private _found = false;
if (_jobKey != "") then {
    // Search existing arrays in priority order without copying the complete queue for
    // every keyed wake. Neither search mutates a queue; publication follows below.
    {
        {
            private _candidateState = _x param [2, createHashMap, [createHashMap]];
            if ((_candidateState getOrDefault ["jobKey", ""]) == _jobKey
                && {!(_candidateState getOrDefault ["cancelled",false])}
                && {!(_candidateState getOrDefault ["finished",false])}
                && {!(_candidateState getOrDefault ["done",false])}
                && {(_candidateState getOrDefault ["generation",-1]) == (_state getOrDefault ["generation",-1])}
                && {(_candidateState getOrDefault ["group",grpNull]) == _group}
                && {isNull _group || {(_candidateState getOrDefault ["ownerEpoch",-1]) == (_state get "ownerEpoch")}}) exitWith {
                _existingState = _candidateState;
                _found = true;
            };
        } forEach (missionNamespace getVariable [_x, []]);
        if (_found) exitWith {};
    } forEach ["CBE_AIPass_Jobs", "CBE_AIPass_PendingJobs"];
};
// Function-scope return: an exit inside the key-search block would still append a duplicate.
if (_found) exitWith {
    private _wakeAt=_dueAt min (_existingState getOrDefault ["wakeAt",_dueAt]);
    {_existingState set [_x, _y]} forEach _state;
    _existingState set ["wakeAt", _wakeAt];
    private _nextDue = missionNamespace getVariable ["CBE_AIPass_NextJobDue", -1];
    if (_nextDue < 0 || {_dueAt < _nextDue}) then {missionNamespace setVariable ["CBE_AIPass_NextJobDue", _dueAt]};
};
private _pending = missionNamespace getVariable ["CBE_AIPass_PendingJobs", []];
_pending pushBack [_dueAt, _job, _state];
missionNamespace setVariable ["CBE_AIPass_PendingJobs", _pending];
private _nextDue = missionNamespace getVariable ["CBE_AIPass_NextJobDue", -1];
if (_nextDue < 0 || {_dueAt < _nextDue}) then {missionNamespace setVariable ["CBE_AIPass_NextJobDue", _dueAt]};

