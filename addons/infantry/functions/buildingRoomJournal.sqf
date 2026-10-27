/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Copy the original private clearance room progress for outgoing capture.
 * Locality/authority: Pure local data conversion. CortexLocality must first fence and
 * validate the original producer through BuildingProducerContext FROZEN. This grants no
 * incoming authority, physical visit, native acknowledgement or permission to replay.
 * Repeat/JIP: No publication, clock renewal, worker or JIP side effect. Malformed or
 * missing state refuses; sparse retry entries retain their original indices and length.
 * Arguments: 0 job HASHMAP default empty.
 * Return: ARRAY [3,visitContext,positions,cleared,unreachable,retryLength,retryRows,
 * failedBy,deadline,lastProgressAt,enteredActors,actorVisitRows,identities], or[] on refusal.
 * Version3 identities are[originalActor,originalNetId], recorded before deletion.
 * Deleted references are historical only; actorVisitRows retain original keys.
 * retryRows are[index,count]; no original identity is guessed from a replacement.
 * Current callers: CortexLocality outgoing frozen producer capture only.
 * Example: private _rooms=[_job] call CBE_fnc_BuildingRoomJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        private _context=_job getOrDefault ["visitContext",[]];
        private _building=_job getOrDefault ["building",objNull];
        private _transform=_job getOrDefault ["buildingTransform",[]];
        private _hard=_job getOrDefault ["hardDeadline",-1];
        private _positions=_job getOrDefault ["positions",[]];
        private _cleared=_job getOrDefault ["cleared",false];
        private _unreachable=_job getOrDefault ["unreachable",false];
        private _retries=_job getOrDefault ["retryCounts",false];
        private _failures=_job getOrDefault ["failedBy",false];
        private _deadline=_job getOrDefault ["deadline",-1];
        private _progress=_job getOrDefault ["lastProgressAt",-1];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
        if (!(_building isEqualType objNull) || {isNull _building}
            || {!(_transform isEqualType [])} || {count _transform != 4}
            || {(_transform select [0,3]) findIf {!(_x call _vector)} >= 0}
            || {!((_transform select 3) isEqualType 0)} || {!finite (_transform select 3)}
            || {(_transform select 3) <= 0}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {(_context select 0) isNotEqualTo _building}
            || {(_context select 1) isNotEqualTo _transform}
            || {(_context select 2) isNotEqualTo _hard}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}
            || {[_hard,_deadline,_progress] findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} >= 0}
            || {!(_positions isEqualType [])} || {count _positions < 1} || {count _positions > 512}
            || {_positions findIf {!(_x call _vector)} >= 0}) exitWith {[]};
        private _size=count _positions;
        private _index={_this isEqualType 0 && {finite _this} && {_this == floor _this}
            && {_this >= 0} && {_this < _size}};
        if ([_cleared,_unreachable] findIf {!(_x isEqualType []) || {count _x > _size}
                || {_x findIf {!(_x call _index)} >= 0}
                || {count (_x arrayIntersect _x) != count _x}} >= 0
            || {(_cleared arrayIntersect _unreachable) isNotEqualTo []}
            || {!(_retries isEqualType [])} || {count _retries > _size}
            || {!(_failures isEqualType [])} || {count _failures != _size}) exitWith {[]};
        private _valid=true;private _retryRows=[];private _failureRows=[];
        for "_i" from 0 to (count _retries-1) do {
            // set at a later room index may leave earlier SQF array entries nil.
            // Preserve absence; do not turn it into fresh or synthetic retry credit.
            if (!isNil {_retries select _i}) then {
                private _count=_retries select _i;
                if (!(_count isEqualType 0) || {!finite _count} || {_count < 0}
                    || {_count != floor _count}) exitWith {_valid=false};
                _retryRows pushBack [_i,_count];
            };
        };
        if (!_valid) exitWith {[]};
        private _laneIds=[];
        for "_i" from 0 to 7 do {_laneIds pushBack format ["PAIR_%1",_i]};
        {
            if (!(_x isEqualType []) || {count _x > 8}
                || {_x findIf {!(_x in _laneIds)} >= 0}
                || {count (_x arrayIntersect _x) != count _x}) exitWith {_valid=false};
            _failureRows pushBack (+_x);
        } forEach _failures;
        if (!_valid) exitWith {[]};
        // These are prior physical observations, not current actor suitability or
        // native-motion authority. Preserve original identities even after group changes.
        private _entered=_job getOrDefault ["enteredActors",false];
        private _identities=_job getOrDefault ["enteredActorIdentities",false];
        private _visits=_job getOrDefault ["actorVisits",false];
        if (!(_entered isEqualType []) || {count _entered > 64}
            || {_entered findIf {!(_x isEqualType objNull)} >= 0}
            || {!(_identities isEqualType [])} || {count _identities != count _entered}
            || {!(_visits isEqualType createHashMap)} || {count _visits > 64}) exitWith {[]};
        private _enteredIds=[];private _identityRows=[];
        {
            if (!(_x isEqualType []) || {count _x != 2}) exitWith {_valid=false};
            _x params ["_actor","_originalId"];
            if (!(_actor isEqualType objNull) || {_actor isNotEqualTo (_entered select _forEachIndex)}
                || {!(_originalId isEqualType "")} || {_originalId == ""}
                || {!isNull _actor && {netId _actor isNotEqualTo _originalId}}) exitWith {_valid=false};
            _enteredIds pushBack _originalId;_identityRows pushBack [_actor,_originalId];
        } forEach _identities;
        if (!_valid) exitWith {[]};
        private _visitKeys=keys _visits;
        if (count (_enteredIds arrayIntersect _enteredIds) != count _enteredIds
            || {count _visitKeys != count _enteredIds}
            || {_visitKeys findIf {!(_x isEqualType "") || {!(_x in _enteredIds)}} >= 0}) exitWith {[]};
        private _visitRows=[];
        {
            private _indices=_visits get _x;
            if (!(_indices isEqualType []) || {count _indices < 1} || {count _indices > _size}
                || {_indices findIf {!(_x call _index) || {!(_x in _cleared)}} >= 0}
                || {count (_indices arrayIntersect _indices) != count _indices}) exitWith {_valid=false};
            _visitRows pushBack [_x,+_indices];
        } forEach _visitKeys;
        if (!_valid) exitWith {[]};
        [3,[_context select 0,(_context select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_context select 2,_context select 3],
            _positions apply {+_x},+_cleared,+_unreachable,count _retries,_retryRows,
            _failureRows,_deadline,_progress,+_entered,_visitRows,_identityRows]
    };
    false
};
_result
