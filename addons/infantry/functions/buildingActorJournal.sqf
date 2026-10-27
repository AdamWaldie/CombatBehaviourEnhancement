/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Copy original actor setting baselines and clearance motion at the fenced producer.
 * Locality/authority: Read-only local metadata after actual group locality loss. Requires the
 * original BuildingProducerContext FROZEN fence and acknowledged original registration.
 * Never reads nonlocal native settings/destinations or grants incoming actor readiness.
 * Repeat/JIP: No mutation, command, timer, query, clock renewal or replay. At most64 unique
 * current/original-team actors and two canonical properties each. Unknown/deleted identity
 * refuses; absence is explicit. Canonical context, baseline, applied value and server retry
 * timestamp remain original; foreign setting issuers are copied, never claimed as clearance.
 * Arguments: 0 job HASHMAP default empty.
 * Return: ARRAY [7,visitContext,actorRows,originalRegistration,settingsRetirement,groupPolicy,ownership,recovery] or[] on refusal.
 * Group policy [1,original behaviour,original attack BOOL,continueRoute BOOL,attack lease,original native route].
 * Only the exact CLEAR attack lease is accepted. Unknown group restoration keys refuse.
 * Route copy is bounded to4096 nodes/depth16/512-character strings; it grants no replay.
 * Ownership [1,original team keys,started keys,assignment rows,hold maps,classifications,access flags].
 * Assignments preserve original local progress clocks as server time. All lists/maps are <=64
 * and resolve only original captured actors. No hold or movement is reconstructed.
 * Recovery [2,participant keys,spent attempts,active observations,unavailable keys,common progress].
 * Progress retains phase, original clocks/pose/actor, replans, required/foot/suspended flags,
 * original platform and bounded participant poses/platforms; it grants no new progress credit.
 * Original local observation clocks convert once to server time; no retry or native order is replayed.
 * Row [originalNetId,actor,canonicalSettingRows,motion,mirrorRows,reservation,evasionReturn,retireWindow,entryState].
 * Entry state [1,private record present,private record,public recovery,public alternative].
 * Original server timestamps, spent retry/search counts and foreign-visit headers remain unchanged.
 * Actor reservations/return expiry convert the original local clock to server time once; no renewal. Canonical rows preserve
 * [context,[property,baseline,applied] rows,retryAtServer]. Mirrors retain [name,present,value].
 * Current callers: CortexLocality outgoing checkpoint before private producer retirement.
 * Example: private _actors=[_job] call CBE_fnc_BuildingActorJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        if !(["FROZEN",_job] call CBE_fnc_BuildingProducerContext) exitWith {[]};
        private _group=_job get "group";
        private _visit=_job get "visitContext";
        private _registration=_job getOrDefault ["producerRegistration",[]];
        if (!(_registration isEqualType []) || {count _registration != 7}
            || {[0,1,2,3,4,5,6] findIf {isNil {_registration select _x}} >= 0}
            || {(_registration select [0,6]) isNotEqualTo [_group,clientOwner,_visit,
                _job get "ownerEpoch",_job get "generation",_job get "operationGeneration"]}) exitWith {[]};
        private _localNow=time;private _serverNow=serverTime;
        private _team=_job getOrDefault ["team",false];
        if (!(_team isEqualType []) || {count _team > 64}) exitWith {[]};
        private _actors=+_team;
        {_actors pushBackUnique _x} forEach units _group;
        if (count _actors > 64) exitWith {[]};
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} < 0}};
        private _value={
            params ["_property","_data"];
            if (_property == "STANCE") exitWith {_data isEqualType "" && {_data in ["AUTO","UP","MIDDLE","DOWN"]}};
            _property == "SPEED" && {_data isEqualType 0} && {finite _data} && {_data == -1 || {_data >= 0}}
        };
        private _copyVisit={params ["_source"];[_source select 0,(_source select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_source select 2,_source select 3]};
        private _copiedVisit=[_visit] call _copyVisit;
        // Preserve original group permission and task policy, never a new-owner native read.
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        private _restore=_operation getOrDefault ["restore",createHashMap];
        private _baseBehaviour=_job getOrDefault ["baseBehaviour",""];
        private _baseAttack=_job getOrDefault ["baseAttack",-1];
        private _continueRoute=_job getOrDefault ["continueRoute",-1];
        if (!(_restore isEqualType createHashMap) || {keys _restore findIf {_x != "groupAttack"} >= 0}
            || {!(_baseBehaviour in ["SAFE","AWARE","COMBAT","STEALTH","CARELESS"])}
            || {!(_baseAttack isEqualType true)} || {!(_continueRoute isEqualType true)}) exitWith {[]};
        private _attack=_restore getOrDefault ["groupAttack",[]];
        if (!(_attack isEqualType []) || {count _attack != 2}
            || {_attack findIf {isNil "_x" || {!(_x isEqualType true)}} >= 0}
            || {(_attack select 0) isNotEqualTo _baseAttack} || {_attack select 1}) exitWith {[]};
        private _nativeReceipt=_job getOrDefault ["nativeOrderReceipt",[]];
        if (!(_nativeReceipt isEqualType []) || {!(count _nativeReceipt in [2,3])}
            || {_nativeReceipt findIf {isNil "_x"} >= 0}
            || {[0,1] findIf {!((_nativeReceipt select _x) isEqualType 0)
                || {!finite (_nativeReceipt select _x)}
                || {(_nativeReceipt select _x) != floor (_nativeReceipt select _x)}} >= 0}
            || {(_nativeReceipt select 0) < 0}
            || {if (count _nativeReceipt == 2) then {(_nativeReceipt select 1) != -1} else {
                (_nativeReceipt select 1) < 1 || {(_nativeReceipt select 1) >= (_nativeReceipt select 0)}
                    || {!((_nativeReceipt select 2) isEqualType [])} || {(_nativeReceipt select 2) isEqualTo []}
            }}) exitWith {[]};
        private _policyValid=true;private _policyNodes=0;
        private _copyPolicy={
            params ["_value",["_depth",0]];
            _policyNodes=_policyNodes+1;
            if (_policyNodes > 4096 || {_depth > 16}) exitWith {_policyValid=false;[]};
            if (_value isEqualType []) exitWith {
                if (_depth >= 16 || {count _value > 4096} || {_value findIf {isNil "_x"} >= 0}) exitWith {_policyValid=false;[]};
                private _copy=[];
                {if (!_policyValid) exitWith {};_copy pushBack ([_x,_depth+1] call _copyPolicy)} forEach _value;
                _copy
            };
            if (_value isEqualType 0) then {if (!finite _value) then {_policyValid=false}} else {
                if (_value isEqualType "") then {if (count _value > 512) then {_policyValid=false}} else {
                    if (!(_value isEqualType true || {_value isEqualType objNull} || {_value isEqualType grpNull})) then {_policyValid=false};
                };
            };
            _value
        };
        private _copiedNative=[_nativeReceipt] call _copyPolicy;
        if (!_policyValid) exitWith {[]};
        private _groupPolicy=[1,_baseBehaviour,_baseAttack,_continueRoute,+_attack,_copiedNative];
        private _entryRecovery=_job getOrDefault ["entryRecovery",createHashMap];
        if (!(_entryRecovery isEqualType createHashMap) || {count _entryRecovery > 64}) exitWith {[]};
        private _entryVisitValid={
            _this isEqualType [] && {count _this == 4} && {_this findIf {isNil "_x"} < 0}
                && {(_this select 0) isEqualType objNull}
                && {(_this select 1) isEqualType []} && {count (_this select 1) == 3}
                && {(_this select 1) findIf {!(_x call _vector)} < 0}
                && {(_this select 2) isEqualType 0} && {finite (_this select 2)} && {(_this select 2) >= 0}
                && {(_this select 3) isEqualType ""} && {(_this select 3) != ""}
        };
        private _entryRecordValid={
            params ["_record","_until"];
            _record isEqualType [] && {count _record == 5} && {_record findIf {isNil "_x"} < 0}
                && {[0,1] findIf {!((_record select _x) isEqualType 0) || {!finite (_record select _x)}
                    || {(_record select _x) < 0}} < 0}
                && {(_record select 1) <= _serverNow+1} && {(_record select 1) <= _until}
                && {(_record select 2) isEqualType true}
                && {(_record select 3) call _vector} && {(_record select 4) call _vector}
        };
        private _rows=[];private _keys=[];private _valid=true;
        {
            private _actor=_x;
            if (isNil "_actor" || {!(_actor isEqualType objNull)} || {isNull _actor}) exitWith {_valid=false};
            private _key=netId _actor;
            if (_key in ["","0:0"] || {_key in _keys}) exitWith {_valid=false};
            _keys pushBack _key;
            private _canonical=_actor getVariable ["CBE_ActorSettings",[]];
            private _settings=[];
            if (!(_canonical isEqualType []) || {!(count _canonical in [0,3])}) exitWith {_valid=false};
            if (_canonical isNotEqualTo []) then {
                if ([0,1,2] findIf {isNil {_canonical select _x}} >= 0) exitWith {_valid=false};
                _canonical params ["_context","_owned","_retryAt"];
                if (!(_context isEqualType []) || {count _context != 5}
                    || {[0,1,2,3,4] findIf {isNil {_context select _x}} >= 0}
                    || {!((_context select 0) isEqualType grpNull)} || {isNull (_context select 0)}
                    || {!((_context select 1) isEqualType "")} || {(_context select 1) == ""}
                    || {[2,3] findIf {!((_context select _x) isEqualType 0) || {!finite (_context select _x)}
                        || {(_context select _x) < 0} || {(_context select _x) != floor (_context select _x)}} >= 0}
                    || {!((_context select 4) isEqualType 0)} || {!finite (_context select 4)} || {(_context select 4) < 0}
                    || {!(_retryAt isEqualType 0)} || {!finite _retryAt} || {_retryAt < 0}
                    || {!(_owned isEqualType createHashMap)} || {count _owned < 1} || {count _owned > 2}
                    || {keys _owned findIf {!(_x in ["STANCE","SPEED"])} >= 0}) exitWith {_valid=false};
                private _properties=[];
                {
                    private _property=_x;
                    if (_property in _owned) then {
                        private _pair=_owned get _property;
                        if (!(_pair isEqualType []) || {count _pair != 2}
                            || {[0,1] findIf {isNil {_pair select _x}} >= 0}
                            || {!([_property,_pair select 0] call _value)}
                            || {!([_property,_pair select 1] call _value)}) exitWith {_valid=false};
                        _properties pushBack [_property,_pair select 0,_pair select 1];
                    };
                } forEach ["STANCE","SPEED"];
                if (!_valid) exitWith {};
                _settings=[+_context,_properties,_retryAt];
            };
            if (!_valid) exitWith {};
            private _mirrors=[];
            {
                private _name=_x;
                private _present=!isNil {_actor getVariable _name};
                private _mirror=if (_present) then {_actor getVariable _name} else {[]};
                if (_present && {if (_name in ["CBE_Cortex_ClearStance","CBE_Cortex_ClearSettingToken"]) then {
                    !(_mirror isEqualType "")
                } else {!(_mirror isEqualType 0) || {!finite _mirror}}}) exitWith {_valid=false};
                _mirrors pushBack [_name,_present,_mirror];
            } forEach ["CBE_Cortex_ClearStance","CBE_Cortex_ClearForcedSpeed",
                "CBE_Cortex_ClearAppliedSpeed","CBE_Cortex_ClearSettingToken"];
            if (!_valid || {_settings isEqualTo [] && {_mirrors findIf {_x select 1} >= 0}}) exitWith {_valid=false};
            private _motion=_actor getVariable ["CBE_Cortex_ClearMotion",[]];
            private _copiedMotion=[];
            if (!(_motion isEqualType []) || {!(count _motion in [0,5])}) exitWith {_valid=false};
            if (_motion isNotEqualTo []) then {
                if ([0,1,2,3,4] findIf {isNil {_motion select _x}} >= 0
                    || {(_motion select 0) isNotEqualTo _group} || {(_motion select 1) isNotEqualTo _visit}
                    || {!((_motion select 2) in ["MOVE","HOLD"])} || {!((_motion select 3) call _vector)}
                    || {!((_motion select 4) isEqualType [])} || {!(count (_motion select 4) in [0,3])}) exitWith {_valid=false};
                private _triple=_motion select 4;
                if (_triple isNotEqualTo [] && {[0,1,2] findIf {isNil {_triple select _x}} >= 0
                    || {!( ["STANCE",_triple select 0] call _value)}
                    || {!( ["SPEED",_triple select 1] call _value)} || {!( ["SPEED",_triple select 2] call _value)}}) exitWith {_valid=false};
                _copiedMotion=[_group,[_visit] call _copyVisit,_motion select 2,+(_motion select 3),+_triple];
            };
            if (!_valid) exitWith {};
            private _reservation=_actor getVariable ["CBE_Cortex_ActorMove",[]];
            private _copiedReservation=[];
            if (!(_reservation isEqualType []) || {!(count _reservation in [0,3])}) exitWith {_valid=false};
            if (_reservation isNotEqualTo []) then {
                if ([0,1,2] findIf {isNil {_reservation select _x}} >= 0
                    || {!((_reservation select 0) isEqualType "")} || {(_reservation select 0) == ""}
                    || {!((_reservation select 1) call _vector)}
                    || {!((_reservation select 2) isEqualType 0)} || {!finite (_reservation select 2)}) exitWith {_valid=false};
                _copiedReservation=[_reservation select 0,+(_reservation select 1),
                    _serverNow+((_reservation select 2)-_localNow)];
            };
            if (!_valid) exitWith {};
            private _return=_actor getVariable ["CBE_Cortex_ClearEvasionReturn",[]];
            private _copiedReturn=[];
            if (!(_return isEqualType []) || {!(count _return in [0,6])}) exitWith {_valid=false};
            if (_return isNotEqualTo []) then {
                if ([0,1,2,3,4,5] findIf {isNil {_return select _x}} >= 0
                    || {_copiedMotion isEqualTo []} || {(_return select 0) isNotEqualTo _motion}
                    || {!((_return select 1) call _vector)}
                    || {!((_return select 2) isEqualType 0)} || {!finite (_return select 2)}
                    || {(_return select 3) isNotEqualTo (_job get "ownerEpoch")}
                    || {(_return select 4) isNotEqualTo (_job get "operationGeneration")}
                    || {(_return select 5) isNotEqualTo clientOwner}
                    || {_reservation isNotEqualTo [] && {(_reservation select 0) != "GRENADE_EVASION"
                        || {(_reservation select 1) isNotEqualTo (_return select 1)}
                        || {(_reservation select 2) isNotEqualTo (_return select 2)}}}) exitWith {_valid=false};
                private _returnMotion=[_group,[_visit] call _copyVisit,_motion select 2,+(_motion select 3),+(_motion select 4)];
                _copiedReturn=[_returnMotion,+(_return select 1),_serverNow+((_return select 2)-_localNow),
                    _return select 3,_return select 4,_return select 5];
            };
            if (!_valid) exitWith {};
            private _window=_actor getVariable ["CBE_Cortex_ClearSettingRetireUntil",[]];
            if (!(_window isEqualType []) || {!(count _window in [0,2])}
                || {_window isNotEqualTo [] && {[0,1] findIf {isNil {_window select _x}} >= 0
                    || {!((_window select 0) isEqualType "")} || {(_window select 0) == ""}
                    || {!((_window select 1) isEqualType 0)} || {!finite (_window select 1)}}}) exitWith {_valid=false};
            // Keep private progress and published monotonic retry evidence separately.
            // Foreign-visit history retains its own header; it is not a fresh/current budget.
            private _entryPresent=_key in _entryRecovery;
            private _entryRecord=if (_entryPresent) then {_entryRecovery get _key} else {[]};
            if (_entryPresent && {!([_entryRecord,_job get "hardDeadline"] call _entryRecordValid)}) exitWith {_valid=false};
            private _publishedEntry=_actor getVariable ["CBE_Cortex_ClearEntryRecovery",[]];
            if (!(_publishedEntry isEqualType []) || {!(count _publishedEntry in [0,3])}) exitWith {_valid=false};
            if (_publishedEntry isNotEqualTo [] && {
                _publishedEntry findIf {isNil "_x"} >= 0 || {!((_publishedEntry select 0) isEqualType grpNull)}
                    || {!((_publishedEntry select 1) call _entryVisitValid)}
                    || {!([_publishedEntry select 2,(_publishedEntry select 1) select 2] call _entryRecordValid)}
            }) exitWith {_valid=false};
            private _alternative=_actor getVariable ["CBE_Cortex_ClearEntryAlternative",[]];
            if (!(_alternative isEqualType []) || {!(count _alternative in [0,7])}) exitWith {_valid=false};
            if (_alternative isNotEqualTo [] && {
                _alternative findIf {isNil "_x"} >= 0 || {!((_alternative select 6) call _entryVisitValid)}
                    || {(_alternative select [0,3]) isNotEqualTo [(_alternative select 6) select 0,
                        (_alternative select 6) select 2,(_alternative select 6) select 1]}
                    || {!((_alternative select 3) isEqualType [])}
                    || {(_alternative select 3) isNotEqualTo [] && {!((_alternative select 3) call _vector)}}
                    || {[4,5] findIf {!((_alternative select _x) isEqualType 0) || {!finite (_alternative select _x)}
                        || {(_alternative select _x) < 0} || {(_alternative select _x) != floor (_alternative select _x)}} >= 0}
                    || {(_alternative select 4) > 3} || {(_alternative select 5) > 512}
            }) exitWith {_valid=false};
            _policyNodes=0;
            private _entryCopy=[[1,_entryPresent,_entryRecord,_publishedEntry,_alternative]] call _copyPolicy;
            if (!_policyValid) exitWith {_valid=false};
            _rows pushBack [_key,_actor,_settings,_copiedMotion,_mirrors,_copiedReservation,_copiedReturn,+_window,_entryCopy];
        } forEach _actors;
        if (!_valid || {keys _entryRecovery findIf {!(_x isEqualType "") || {!(_x in _keys)}} >= 0}) exitWith {[]};
        // Native-order ownership is not a geometry cache. Preserve all related
        // source records together; never infer holds/started actors from current AI.
        private _ownershipValid=true;
        private _actorKeys={
            params ["_list"];
            if (!(_list isEqualType []) || {count _list > 64}
                || {_list findIf {isNil "_x" || {!(_x isEqualType objNull)} || {isNull _x}} >= 0}
                || {count (_list arrayIntersect _list) != count _list}) exitWith {_ownershipValid=false;[]};
            private _out=_list apply {netId _x};
            if (_out findIf {!(_x in _keys)} >= 0) then {_ownershipValid=false};
            _out
        };
        private _teamKeys=[_team] call _actorKeys;
        private _startedKeys=[_job getOrDefault ["started",false]] call _actorKeys;
        private _assigned=_job getOrDefault ["assigned",false];
        if (!_ownershipValid || {!(_assigned isEqualType [])} || {count _assigned != count _team}
            || {_assigned findIf {isNil "_x"} >= 0}) exitWith {[]};
        private _assignmentRows=[];
        {
            private _record=_x;private _copy=[];
            if (!(_record isEqualType []) || {!(count _record in [0,5])}) exitWith {_ownershipValid=false};
            if (_record isNotEqualTo []) then {
                if (_record findIf {isNil "_x"} >= 0
                    || {[0,1,3] findIf {!((_record select _x) isEqualType 0) || {!finite (_record select _x)}} >= 0}
                    || {(_record select 0) < 0} || {(_record select 0) != floor (_record select 0)}
                    || {(_record select 0) >= count (_job get "positions")}
                    || {(_record select 3) < 0} || {(_record select 3) != floor (_record select 3)}
                    || {!((_record select 2) call _vector)} || {!((_record select 4) isEqualType true)}) exitWith {_ownershipValid=false};
                _copy=[_record select 0,_serverNow+((_record select 1)-_localNow),
                    +(_record select 2),_record select 3,_record select 4];
                if (!finite (_copy select 1)) exitWith {_ownershipValid=false};
            };
            _assignmentRows pushBack [_teamKeys select _forEachIndex,_copy];
        } forEach _assigned;
        if (!_ownershipValid) exitWith {[]};
        private _holds=[];
        {
            private _name=_x;private _map=_job getOrDefault [_name,createHashMap];
            if (!(_map isEqualType createHashMap) || {count _map > 64}) exitWith {_ownershipValid=false};
            private _mapKeys=keys _map;
            if (_mapKeys findIf {!(_x isEqualType "") || {!(_x in _keys)}} >= 0) exitWith {_ownershipValid=false};
            _mapKeys sort true;
            private _holdRows=[];
            {if (isNil {_map get _x}) exitWith {_ownershipValid=false};
                private _position=_map get _x;
                if (!(_position call _vector)) exitWith {_ownershipValid=false};
                _holdRows pushBack [_x,+_position];
            } forEach _mapKeys;
            if (!_ownershipValid) exitWith {};
            _holds pushBack [_name,_holdRows];
        } forEach ["nativeHoldPositions","roomHolds","formationFallbackHolds"];
        if (!_ownershipValid) exitWith {[]};
        private _classifications=[];
        {
            private _classified=[_job getOrDefault [_x,[]]] call _actorKeys;
            if (!_ownershipValid) exitWith {};
            _classifications pushBack [_x,_classified];
        } forEach ["accessHeld","quarantineHeld","securityActors","rotatedOut","egressDiverted"];
        if (!_ownershipValid) exitWith {[]};
        private _access=[];
        {
            private _flag=_job getOrDefault [_x,false];
            if (!(_flag isEqualType true)) exitWith {_ownershipValid=false};
            _access pushBack [_x,_flag];
        } forEach ["accessAdmitted","accessBlocked","accessReported"];
        if (!_ownershipValid) exitWith {[]};
        private _ownership=[1,_teamKeys,_startedKeys,_assignmentRows,_holds,_classifications,_access];
        // Common recovery belongs to this original CLEAR generation, not a fresh owner.
        // Copy spent attempts even when their native observation has already ended.
        private _recoveryValid=true;
        private _participants=[_operation getOrDefault ["participants",[]]] call _actorKeys;
        if (!_ownershipValid) exitWith {[]};
        private _attemptMap=_operation getOrDefault ["recoveryAttempts",createHashMap];
        private _activeMap=_operation getOrDefault ["recovery",createHashMap];
        if (!(_attemptMap isEqualType createHashMap) || {count _attemptMap > 64}
            || {!(_activeMap isEqualType createHashMap)} || {count _activeMap > 64}) exitWith {[]};
        private _attemptKeys=keys _attemptMap;private _activeKeys=keys _activeMap;
        if ((_attemptKeys+_activeKeys) findIf {!(_x isEqualType "") || {!(_x in _keys)}} >= 0) exitWith {[]};
        _attemptKeys sort true;_activeKeys sort true;
        private _attemptRows=[];
        {
            if (isNil {_attemptMap get _x}) exitWith {_recoveryValid=false};
            private _spent=_attemptMap get _x;
            if (!(_spent isEqualType 0) || {!finite _spent} || {!(_spent in [0,1])}) exitWith {_recoveryValid=false};
            _attemptRows pushBack [_x,_spent];
        } forEach _attemptKeys;
        if (!_recoveryValid) exitWith {[]};
        private _activeRows=[];
        {
            if (isNil {_activeMap get _x}) exitWith {_recoveryValid=false};
            private _observation=_activeMap get _x;
            if (!(_observation isEqualType []) || {count _observation != 4}
                || {_observation findIf {isNil "_x"} >= 0}
                || {(_observation select 0) isNotEqualTo 1}
                || {!((_observation select 1) isEqualType 0)} || {!finite (_observation select 1)}
                || {!((_observation select 2) isEqualType [])} || {!(count (_observation select 2) in [2,3])}
                || {(_observation select 2) findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} >= 0}
                || {!((_observation select 3) call _vector)}
                || {(_attemptMap getOrDefault [_x,-1]) isNotEqualTo 1}) exitWith {_recoveryValid=false};
            private _observedAt=_serverNow+((_observation select 1)-_localNow);
            if (!finite _observedAt) exitWith {_recoveryValid=false};
            _activeRows pushBack [_x,[1,_observedAt,+(_observation select 2),+(_observation select 3)]];
        } forEach _activeKeys;
        if (!_recoveryValid) exitWith {[]};
        private _unavailableKeys=[_operation getOrDefault ["unavailable",[]]] call _actorKeys;
        if (!_ownershipValid) exitWith {[]};
        // Retain the common observer's original progress baseline. Captured motion after a
        // takeover must not look like fresh progress or restart its original stale window.
        private _commonPhase=_operation getOrDefault ["phase",""];
        private _startedAt=_operation getOrDefault ["startedAt",false];
        private _progressAt=_operation getOrDefault ["lastProgressAt",false];
        private _progressPosition=_operation getOrDefault ["lastProgressPosition",false];
        private _progressActor=_operation getOrDefault ["lastProgressActor",false];
        private _replans=_operation getOrDefault ["replans",false];
        private _required=_operation getOrDefault ["participantsRequired",false];
        private _onFoot=_operation getOrDefault ["progressOnFoot",false];
        private _suspended=_operation getOrDefault ["fallbackProgressSuspended",false];
        private _progressPlatform=_operation getOrDefault ["progressPlatform",false];
        if (!(_commonPhase in ["ENTRY","SWEEP","REPLAN","EGRESS"])
            || {[_startedAt,_progressAt,_replans] findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_replans < 0} || {_replans != floor _replans}
            || {!(_progressPosition call _vector)} || {!(_progressActor isEqualType objNull)}
            || {!isNull _progressActor && {!(netId _progressActor in _keys)}}
            || {[_required,_onFoot,_suspended] findIf {!(_x isEqualType true)} >= 0}
            || {!(_progressPlatform isEqualType objNull)}) exitWith {[]};
        private _progressSource=_operation getOrDefault ["participantProgress",false];
        if (!(_progressSource isEqualType []) || {count _progressSource > 64}) exitWith {[]};
        private _progressRows=[];private _progressKeys=[];
        {
            if (isNil "_x" || {!(_x isEqualType [])} || {count _x != 2}
                || {_x findIf {isNil "_x"} >= 0}) exitWith {_recoveryValid=false};
            private _actor=_x select 0;private _pose=_x select 1;
            if (!(_actor isEqualType objNull) || {isNull _actor}
                || {!(netId _actor in _keys)} || {netId _actor in _progressKeys}
                || {!(_pose call _vector)}) exitWith {_recoveryValid=false};
            _progressKeys pushBack netId _actor;
            _progressRows pushBack [netId _actor,+_pose];
        } forEach _progressSource;
        if (!_recoveryValid) exitWith {[]};
        private _platformMap=_operation getOrDefault ["participantPlatforms",false];
        if (!(_platformMap isEqualType createHashMap) || {count _platformMap > 64}) exitWith {[]};
        private _platformKeys=keys _platformMap;
        if (_platformKeys findIf {!(_x isEqualType "") || {!(_x in _keys)}} >= 0) exitWith {[]};
        _platformKeys sort true;
        private _platformRows=[];
        {
            if (isNil {_platformMap get _x}) exitWith {_recoveryValid=false};
            private _platform=_platformMap get _x;
            if (!(_platform isEqualType objNull)) exitWith {_recoveryValid=false};
            _platformRows pushBack [_x,_platform];
        } forEach _platformKeys;
        if (!_recoveryValid) exitWith {[]};
        private _startedServer=_serverNow+(_startedAt-_localNow);
        private _progressServer=_serverNow+(_progressAt-_localNow);
        if (!finite _startedServer || {!finite _progressServer}) exitWith {[]};
        private _commonProgress=[1,_commonPhase,_startedServer,_progressServer,+_progressPosition,
            _progressActor,_replans,_required,_onFoot,_suspended,_progressPlatform,_progressRows,_platformRows];
        private _recoveryState=[2,_participants,_attemptRows,_activeRows,_unavailableKeys,_commonProgress];
        private _copiedRegistration=+_registration;
        _copiedRegistration set [2,[_visit] call _copyVisit];
        private _pending=_group getVariable ["CBE_Cortex_ClearSettingsPending",[]];
        private _pendingValid={
            _this isEqualType [] && {count _this == 4}
                && {[0,1,2,3] findIf {isNil {_this select _x} || {!((_this select _x) isEqualType 0)}
                    || {!finite (_this select _x)} || {(_this select _x) < 0}} < 0}
                && {[0,1,3] findIf {(_this select _x) != floor (_this select _x)} < 0}
        };
        if (_pending isNotEqualTo [] && {!(_pending call _pendingValid)}) exitWith {[]};
        private _cleanupResult=_group getVariable ["CBE_Cortex_ClearSettingsResult",[]];
        private _copiedResult=[];
        if (!(_cleanupResult isEqualType []) || {!(count _cleanupResult in [0,3])}) exitWith {[]};
        if (_cleanupResult isNotEqualTo []) then {
            if ([0,1,2] findIf {isNil {_cleanupResult select _x}} >= 0
                || {!((_cleanupResult select 0) in ["WINDOW_EXPIRED","RETIRED"])}
                || {!((_cleanupResult select 1) isEqualType 0)} || {!finite (_cleanupResult select 1)}
                || {!((_cleanupResult select 2) call _pendingValid)}) exitWith {_valid=false};
            _copiedResult=[_cleanupResult select 0,_cleanupResult select 1,+(_cleanupResult select 2)];
        };
        if (!_valid) exitWith {[]};
        [7,_copiedVisit,_rows,_copiedRegistration,[+_pending,_copiedResult],_groupPolicy,_ownership,_recoveryState]
    };
    false
};
_result
