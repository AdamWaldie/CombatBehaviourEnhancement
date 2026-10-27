/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Serialize original private final-egress state without renewing its clocks.
 * Locality/authority: Pure local data conversion; caller owns actual live publication
 * or the fenced original producer context. No incoming/native authority is granted.
 * Repeat/JIP: No command, mutation, worker, timer, query or publication. Missing or
 * malformed progress refuses instead of substituting new retry or progress values.
 * Arguments: 0 job HASHMAP default empty.
 * Return: ARRAY existing14-field version5 EGRESS journal, or[] on refusal.
 * Current callers: BuildingOperationStep live publication, CortexLocality frozen capture.
 * Example: private _journal=[_job] call CBE_fnc_BuildingEgressJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        private _building=_job getOrDefault ["building",objNull];
        private _transform=_job getOrDefault ["buildingTransform",[]];
        private _context=_job getOrDefault ["visitContext",[]];
        private _hard=_job getOrDefault ["hardDeadline",-1];
        private _started=_job getOrDefault ["egressStartedServer",-1];
        private _until=_job getOrDefault ["egressDeadlineServer",-1];
        private _failed=_job getOrDefault ["egressFailed",false];
        private _entryFailed=_job getOrDefault ["entryFailed",false];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
        private _optionalVector={_this isEqualType [] && {_this isEqualTo [] || {_this call _vector}}};
        if ((_job getOrDefault ["phase",""]) != "EGRESS"
            || {!(_building isEqualType objNull)} || {isNull _building}
            || {!(_transform isEqualType [])} || {count _transform != 4}
            || {(_transform select [0,3]) findIf {!(_x call _vector)} >= 0}
            || {!((_transform select 3) isEqualType 0)} || {!finite (_transform select 3)}
            || {(_transform select 3) <= 0}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {(_context select 0) isNotEqualTo _building} || {(_context select 1) isNotEqualTo _transform}
            || {(_context select 2) isNotEqualTo _hard}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}
            || {[_hard,_started,_until] findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} >= 0}
            || {_until < _started} || {!(_failed isEqualType true)} || {!(_entryFailed isEqualType true)}) exitWith {[]};
        private _assignments=_job getOrDefault ["egressAssignments",false];
        private _pending=_job getOrDefault ["egressPending",false];
        private _progress=_job getOrDefault ["egressProgress",false];
        private _moves=_job getOrDefault ["movementTargets",false];
        private _uses=_job getOrDefault ["egressExitUses",false];
        if ([_assignments,_pending,_progress] findIf {!(_x isEqualType []) || {count _x > 8}} >= 0
            || {count _assignments+count _pending > 8}
            || {!(_moves isEqualType createHashMap)} || {count _moves > 64}
            || {!(_uses isEqualType createHashMap)} || {count _uses > 4}) exitWith {[]};
        private _actors=[];private _rows=[];private _pendingRows=[];private _useRows=[];private _valid=true;
        {
            if (!(_x isEqualType []) || {count _x != 3}) exitWith {_valid=false};
            _x params ["_actor","_target","_arrived"];
            if (!(_actor isEqualType objNull) || {isNull _actor} || {netId _actor == ""}
                || {_actor in _actors} || {!(_target call _vector)} || {!(_arrived isEqualType true)}) exitWith {_valid=false};
            private _records=_progress select {_x isEqualType [] && {count _x == 7} && {(_x select 0) isEqualTo _actor}};
            if (count _records != 1) exitWith {_valid=false};
            private _record=_records select 0;
            private _leg=_moves getOrDefault [netId _actor,[]];
            if (!(_leg call _optionalVector)
                || {[1,2,3,5] findIf {!((_record select _x) isEqualType 0) || {!finite (_record select _x)} || {(_record select _x) < 0}} >= 0}
                || {!((_record select 3) in [0,1])}
                || {[2,5] findIf {(_record select _x) > _until} >= 0}
                || {!((_record select 4) call _optionalVector)} || {!((_record select 6) call _vector)}) exitWith {_valid=false};
            _actors pushBack _actor;
            _rows pushBack [_actor,+_target,_arrived,+_leg,_record select 3,+(_record select 4),
                _record select 1,_record select 2,_record select 5,+(_record select 6)];
        } forEach _assignments;
        if (!_valid) exitWith {[]};
        {
            if (!(_x isEqualType []) || {count _x != 4}) exitWith {_valid=false};
            _x params ["_actor","_leg","_attempts","_next"];
            if (!(_actor isEqualType objNull) || {isNull _actor} || {netId _actor == ""}
                || {_actor in _actors} || {!(_leg call _optionalVector)}
                || {!(_attempts isEqualType 0)} || {!(_attempts in [0,1,2])}
                || {!(_next isEqualType 0)} || {!finite _next} || {_next < 0} || {_next > _until}) exitWith {_valid=false};
            _actors pushBack _actor;_pendingRows pushBack [_actor,+_leg,_attempts,_next];
        } forEach _pending;
        if (!_valid) exitWith {[]};
        {
            private _count=_uses get _x;
            if (!(_x isEqualType "") || {_x == ""} || {!(_count isEqualType 0)}
                || {!finite _count} || {_count != floor _count} || {_count < 0} || {_count > 8}) exitWith {_valid=false};
            _useRows pushBack [_x,_count];
        } forEach keys _uses;
        if (!_valid) exitWith {[]};
        ["EGRESS",_rows apply {+(_x select 1)},_started,_rows,_building,_transform apply {if (_x isEqualType []) then {+_x} else {_x}},_hard,
            _until,_failed,_entryFailed,5,_pendingRows,_useRows,
            [_context select 0,(_context select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_context select 2,_context select 3]]
    };
    false
};
_result
