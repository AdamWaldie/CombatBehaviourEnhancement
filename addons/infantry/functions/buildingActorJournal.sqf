/*
 * Author: WaldoTheWarfighter
 * Purpose: Copy original actor setting baselines and clearance motion at the fenced producer.
 * Locality/authority: Read-only local metadata after actual group locality loss. Requires the
 * original BuildingProducerContext FROZEN fence and acknowledged original registration.
 * Never reads nonlocal native settings/destinations or grants incoming actor readiness.
 * Repeat/JIP: No mutation, command, timer, query, clock renewal or replay. At most64 unique
 * current/original-team actors and two canonical properties each. Unknown/deleted identity
 * refuses; absence is explicit. Canonical context, baseline, applied value and server retry
 * timestamp remain original; foreign setting issuers are copied, never claimed as clearance.
 * Arguments: 0 job HASHMAP default empty.
 * Return: ARRAY [4,visitContext,actorRows,originalRegistration,settingsRetirement,groupPolicy] or[] on refusal.
 * Group policy [1,original behaviour,original attack BOOL,continueRoute BOOL,attack lease,original native route].
 * Only the exact CLEAR attack lease is accepted. Unknown group restoration keys refuse.
 * Route copy is bounded to4096 nodes/depth16/512-character strings; it grants no replay.
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
        private _copyVisit={params ["_source"];[_source select 0,(_source select 1) apply {+_x},_source select 2,_source select 3]};
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
        [4,_copiedVisit,_rows,_copiedRegistration,[+_pending,_copiedResult],_groupPolicy]
    };
    false
};
_result
