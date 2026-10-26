/*
 * Author: WaldoTheWarfighter
 * Purpose: Copy the current producer's bounded exterior-post search/history journal.
 * Locality/authority: Pure data serializer; callers retain current operation/owner or
 * exact outgoing producer-fence validation. Output grants no task or native authority.
 * Repeat/JIP: No job mutation, publication, native command or clock renewal. One
 * unscheduled copy, at most64 actor keys,6 attempted targets and3 entries per key.
 * Arguments: 0 job HASHMAP,empty; original building/transform/visit/deadline and five
 * reserve-stage maps. Missing maps mean empty state; malformed/overflow data refuses.
 * Return: ARRAY five-field [building,hardDeadline,transform,rows,visitContext], or[].
 * Rows retain counts, attempted positions, stage and original blocked-view clocks.
 * Current callers: BuildingOperationStep changed-state publication and CortexLocality
 * outgoing private capture, never an incoming owner or remote behaviour endpoint.
 * Example: private _snapshot=[_job] call CBE_fnc_BuildingStageJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        private _building=_job getOrDefault ["building",objNull];
        private _until=_job getOrDefault ["hardDeadline",-1];
        private _transform=_job getOrDefault ["buildingTransform",[]];
        private _context=_job getOrDefault ["visitContext",[]];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
        if (!(_building isEqualType objNull) || {isNull _building}
            || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0}
            || {!(_transform isEqualType [])} || {count _transform != 3}
            || {_transform findIf {!(_x call _vector)} >= 0}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {(_context select 0) isNotEqualTo _building}
            || {(_context select 1) isNotEqualTo _transform} || {(_context select 2) isNotEqualTo _until}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}) exitWith {[]};
        private _counts=_job getOrDefault ["reserveStageSearchCounts",createHashMap];
        private _targets=_job getOrDefault ["reserveStageTriedTargets",createHashMap];
        private _entries=_job getOrDefault ["reserveStageTriedEntries",createHashMap];
        private _stages=_job getOrDefault ["reserveStages",createHashMap];
        private _views=_job getOrDefault ["reserveStageViewChecks",createHashMap];
        private _maps=[_counts,_targets,_entries,_stages,_views];
        if (_maps findIf {!(_x isEqualType createHashMap) || {count _x > 64}} >= 0) exitWith {[]};
        private _keys=keys _counts;
        if (_keys findIf {!(_x isEqualType "") || {_x == ""}} >= 0
            || {_maps findIf {(keys _x) findIf {!(_x in _counts)} >= 0} >= 0}) exitWith {[]};
        private _rows=[]; private _valid=true;
        {
            private _key=_x;
            private _count=_counts get _key;
            private _tried=_targets getOrDefault [_key,[]];
            private _history=_entries getOrDefault [_key,[]];
            private _savedStage=_stages getOrDefault [_key,[]];
            private _savedView=_views getOrDefault [_key,[]];
            if (!(_count isEqualType 0) || {!finite _count} || {_count != floor _count}
                || {_count < 0} || {_count > 3}
                || {!(_tried isEqualType [])} || {count _tried > 6}
                || {_tried findIf {!(_x call _vector)} >= 0}
                || {!(_history isEqualType [])} || {count _history > 3}
                || {_history findIf {!(_x call _vector)} >= 0}
                || {!(_savedStage isEqualType [])} || {!(count _savedStage in [0,4,7])}
                || {!(_savedView isEqualType [])} || {!(count _savedView in [0,2])}) exitWith {_valid=false};
            if (_savedStage isNotEqualTo [] && {
                !((_savedStage select 0) call _vector) || {!((_savedStage select 1) isEqualType true)}
                    || {!((_savedStage select 2) in ["APPROACH","ARRIVED","REJECTED","EXHAUSTED"])}
                    || {!((_savedStage select 3) isEqualType 0)} || {!finite (_savedStage select 3)}
                    || {(_savedStage select 3) < 0}
                    || {count _savedStage == 7 && {
                        [4,5] findIf {(_savedStage select _x) isNotEqualTo [] && {!((_savedStage select _x) call _vector)}} >= 0
                            || {!((_savedStage select 6) isEqualType true)}
                    }}
            }) exitWith {_valid=false};
            if (_savedView isNotEqualTo [] && {
                _savedView findIf {!(_x isEqualType 0) || {!finite _x}} >= 0
                    || {(_savedView select 0) < 0} || {(_savedView select 1) < -1}
            }) exitWith {_valid=false};
            private _stage=+_savedStage;
            if (_stage isNotEqualTo []) then {
                _stage set [0,+(_stage select 0)];
                if (count _stage == 7) then {{_stage set [_x,+(_stage select _x)]} forEach [4,5]};
            };
            private _viewReceipt=[];
            if (count _savedStage == 7 && {(_savedStage select 2) == "ARRIVED"}
                && {count _savedView == 2} && {(_savedView select 1) >= 0}) then {
                if (!((_savedStage select 4) call _vector)) exitWith {_valid=false};
                _viewReceipt=[+(_savedStage select 0),+(_savedStage select 4),
                    _savedView select 0,_savedView select 1];
            };
            if (!_valid) exitWith {};
            _rows pushBack [_key,_count,_tried apply {+_x},_stage,_history apply {+_x},_viewReceipt];
        } forEach _keys;
        if (!_valid) exitWith {[]};
        [_building,_until,_transform apply {+_x},_rows,
            [_context select 0,(_context select 1) apply {+_x},_context select 2,_context select 3]]
    };
    false
};
_result
