/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Preserve original follow-through legs and spent search/exhaustion history.
 * Locality/authority: Pure local data conversion; caller owns live budget publication
 * or verifies the exact fenced original producer. No native/incoming authority.
 * Repeat/JIP: No mutation, query, worker, clock renewal or publication. Original local
 * progress clocks are represented as server times once; no new observation is supplied.
 * Arguments: 0 job HASHMAP default empty.
 * Return: ARRAY [2,visitContext,legRows,publicBudget,yieldReceipt] or[] on refusal.
 * yieldReceipt is[] for unknown/malformed private yield state, never zero-spent proof.
 * Capture callers must require a known two-field receipt; budget publication is independent.
 * legRows are
 * [originalActorKey,eight-field record]; publicBudget is the existing five-field budget.
 * Current callers: BuildingOperationStep budget publication, CortexLocality source capture.
 * Example: private _follow=[_job] call CBE_fnc_BuildingFollowJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        private _building=_job getOrDefault ["building",objNull];
        private _transform=_job getOrDefault ["buildingTransform",[]];
        private _hard=_job getOrDefault ["hardDeadline",-1];
        private _context=_job getOrDefault ["visitContext",[]];
        private _positions=_job getOrDefault ["positions",[]];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
        if (!(_building isEqualType objNull) || {isNull _building}
            || {!(_hard isEqualType 0)} || {!finite _hard} || {_hard < 0}
            || {!(_transform isEqualType [])} || {count _transform != 4}
            || {(_transform select [0,3]) findIf {!(_x call _vector)} >= 0}
            || {!((_transform select 3) isEqualType 0)} || {!finite (_transform select 3)}
            || {(_transform select 3) <= 0}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {(_context select 0) isNotEqualTo _building} || {(_context select 1) isNotEqualTo _transform}
            || {(_context select 2) isNotEqualTo _hard}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}
            || {!(_positions isEqualType [])} || {count _positions < 1} || {count _positions > 512}) exitWith {[]};
        private _size=count _positions;
        private _index={_this isEqualType 0 && {finite _this} && {_this == floor _this}
            && {_this >= 0} && {_this < _size}};
        private _legs=_job getOrDefault ["followThrough",false];
        private _failures=_job getOrDefault ["followThroughFailures",false];
        private _exhausted=_job getOrDefault ["followThroughExhausted",false];
        private _spent=_job getOrDefault ["followThroughExhaustedKeys",false];
        if ([_legs,_failures] findIf {!(_x isEqualType createHashMap) || {count _x > 64}} >= 0
            || {!(_exhausted isEqualType [])} || {count _exhausted > 64}
            || {_exhausted findIf {!(_x isEqualType objNull)} >= 0}
            || {!(_spent isEqualType [])} || {count _spent > 64}
            || {_spent findIf {!(_x isEqualType "") || {_x == ""} || {!(_x in _failures)}} >= 0}
            || {count (_spent arrayIntersect _spent) != count _spent}
            || {_exhausted findIf {!isNull _x && {!(netId _x in _spent)}} >= 0}) exitWith {[]};
        private _legRows=[];private _budgetRows=[];private _valid=true;
        {
            private _key=_x;
            private _record=_legs get _key;
            if (!(_key isEqualType "") || {_key == ""} || {!(_record isEqualType [])}
                || {!(count _record in [0,8])}) exitWith {_valid=false};
            if (_record isNotEqualTo []) then {
                if (!((_record select 0) call _index)
                    || {[1,2,6] findIf {!((_record select _x) isEqualType 0) || {!finite (_record select _x)} || {(_record select _x) < 0}} >= 0}
                    || {[3,4] findIf {!((_record select _x) isEqualType true)} >= 0}
                    || {!((_record select 5) isEqualType [])}
                    || {(_record select 5) isNotEqualTo [] && {!((_record select 5) call _vector)}}
                    || {!((_record select 7) call _vector)}) exitWith {_valid=false};
                private _copy=+_record;
                _copy set [2,serverTime-(time-(_record select 2))];
                _copy set [6,serverTime-(time-(_record select 6))];
                _copy set [5,+(_record select 5)];_copy set [7,+(_record select 7)];
                _legRows pushBack [_key,_copy];
            } else {_legRows pushBack [_key,[]]};
        } forEach keys _legs;
        if (!_valid) exitWith {[]};
        {
            private _indices=_failures get _x;
            if (!(_x isEqualType "") || {_x == ""} || {!(_indices isEqualType [])} || {count _indices > 3}
                || {_indices findIf {!(_x call _index)} >= 0}
                || {count (_indices arrayIntersect _indices) != count _indices}) exitWith {_valid=false};
            _budgetRows pushBack [_x,+_indices,_x in _spent];
        } forEach keys _failures;
        if (!_valid) exitWith {[]};
        private _contextCopy=[_context select 0,(_context select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_context select 2,_context select 3];
        private _yield=_job getOrDefault ["yieldReceipt",[]];
        private _yieldCopy=[];
        if (_yield isEqualType [] && {count _yield == 2}
            && {!isNil {_yield select 0}} && {!isNil {_yield select 1}}
            && {(_yield select 0) isEqualTo _context}
            && {(_yield select 1) isEqualType []} && {count (_yield select 1) <= 64}
            && {(_yield select 1) findIf {isNil "_x" || {!(_x isEqualType "")} || {_x in ["","0:0"]}} < 0}
            && {count ((_yield select 1) arrayIntersect (_yield select 1)) == count (_yield select 1)}) then {
            _yieldCopy=[[_context select 0,(_context select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_context select 2,_context select 3],+(_yield select 1)];
        };
        [2,_contextCopy,_legRows,[_building,_hard,_transform apply {if (_x isEqualType []) then {+_x} else {_x}},_budgetRows,
            [_context select 0,(_context select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_context select 2,_context select 3]],_yieldCopy]
    };
    false
};
_result
