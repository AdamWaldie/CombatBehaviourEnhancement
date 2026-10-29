/*
 * Author: WaldoTheWarfighter
 * Ground-element scope and original roster accompany standalone drill intent; migration must
 * not widen a landed infantry element into its whole mixed crew/passenger group.
 * Coordinated checkpoints retain exact acknowledged MOVE observations and original progress clocks, without replay authority.
 * Loose legacy attack flags are not transported; common operations retain their typed policy.
 * Publishes restoration data and bounded post-contact movement intent after an unscheduled AI job.
 * A missing or stale public phase is repaired through CortexSetPhase with an explicit continuity
 * record; the checkpoint never changes observable phase state outside the common transition path.
 * Locality/authority: current group owner unless stated otherwise below.
 * Repeat/JIP: durable restoration data is public; local jobs are never replayed verbatim.
 * Active native observations and HOLD proof are bounded to64 rows. Actual owned MOVE proof
 * can be observed on the incoming owner; commands and acknowledgement grace are never replayed.
 * Arguments: 0: group <GROUP>, default grpNull.
 * Return Value: Nothing unless a value is explicitly returned below.
 * Current callers: scheduler and locality restoration.
 * Example: [_group] call CBE_fnc_CortexCheckpoint;
 */
params [["_group", grpNull, [grpNull]]];
if (isNull _group || {!local _group}) exitWith {};
private _state = _group getVariable ["CBE_AIPass_State", createHashMap];
private _saved = [];
{
    private _value = _state get _x;
    if (!isNil "_value") then {
        if (_value isEqualType []) then {_value = _value apply {if (_x isEqualType []) then {+_x} else {_x}}};
        _saved pushBack [_x, _value];
    };
} forEach ["supportHeld", "supportAuthoredOrder", "supportAuthoredRevoked", "supportAuthoredRevokedToken", "retreatCombatMode", "retreatSpeedMode", "baseBehaviour", "behaviourChanged", "hadContact", "baseSpeed", "speedChanged", "searchTeam", "searchMoveReceipts", "holders", "holderRecallReceipts", "dismounted"];
private _retreatSpeedLease=_state getOrDefault ["retreatSpeedMode",[]];
if (count _retreatSpeedLease == 2) then {_saved pushBack ["restoreGroupSpeedMode",+_retreatSpeedLease]};
private _drill = _state getOrDefault ["drill", createHashMap];
if (count _drill > 0) then {
    private _groupModeLease = _drill getOrDefault ["groupCombatMode",[]];
    if (_groupModeLease isNotEqualTo []) then {_saved pushBack ["restoreGroupCombatMode",+_groupModeLease]};
    private _groupSpeedLease = _drill getOrDefault ["groupSpeedMode",[]];
    if (_groupSpeedLease isNotEqualTo []) then {_saved pushBack ["restoreGroupSpeedMode",+_groupSpeedLease]};
    _saved pushBack ["restoreDisabled", (_drill getOrDefault ["disabled", []]) apply {+_x}];
    _saved pushBack ["restoreCombatModes",(_drill getOrDefault ["combatModes",[]]) apply {+_x}];
    _saved pushBack ["restoreCombatBehaviours",(_drill getOrDefault ["combatBehaviours",[]]) apply {+_x}];
    _saved pushBack ["restoreMovers", +(_drill getOrDefault ["units", []])];
    private _spots=_drill getOrDefault ["spots",[]];
    private _moveProof=[];
    {
        if (_forEachIndex < count _spots) then {_moveProof pushBack [_x,+(_spots select _forEachIndex)]};
    } forEach (_drill getOrDefault ["movers",[]]);
    _saved pushBack ["restoreMoveDestinations",_moveProof];
    // Serialize semantic drill state, never callbacks or machine-local feature leases.
    // Stable clock anchors avoid broadcasting a changing countdown on every checkpoint.
    private _generation=_drill getOrDefault ["operationGeneration",-1];
    private _points=_drill getOrDefault ["points",[]];
    if ((_drill getOrDefault ["explicitOrder",[]]) isEqualTo []
        && {_generation >= 0} && {count _points <= 64} && {count (_drill getOrDefault ["units",[]]) <= 64}
        && {(_drill getOrDefault ["supportToken",""]) == ""}
        && {(_drill getOrDefault ["stage",""]) in ["START","MOVE","PAUSE","HOLD"]}) then {
        private _clock=[_drill getOrDefault ["boundDeadline",-1],_drill getOrDefault ["pauseUntil",0]];
        private _anchors=_drill getOrDefault ["migrationClocks",[]];
        if (count _anchors != 3 || {(_anchors select 0) isNotEqualTo _clock}) then {
            _anchors=[+_clock,if ((_clock select 0) < 0) then {-1} else {serverTime+(_clock select 0)-time},serverTime+(_clock select 1)-time];
            _drill set ["migrationClocks",_anchors];
        };
        private _payload=[];
        {
            private _value=_drill get _x;
            // Ordinary drills need no duplicate64-actor roster in every checkpoint.
            if (_x == "elementRoster" && {(_drill getOrDefault ["elementScoped",false]) isEqualTo false}) then {_value=nil};
            if (!isNil "_value") then {
                // At most three nested array levels: positions, teams and route records.
                if (_value isEqualType []) then {
                    _value=_value apply {if (_x isEqualType []) then {_x apply {if (_x isEqualType []) then {+_x} else {_x}}} else {_x}};
                };
                _payload pushBack [_x,_value];
            };
        } forEach ["type","buddyBounds","target","units","desiredStrength","teams","teamSizes","teamTurn","points","index","stage","enemyPos",
            "assaulting","assaultObjective","assaultDirection","assaultGrenade","finishFlank","consolidating","boundDeadlineIdentity","boundQuorumUntil","boundWaypoint","authoredOrder","elementScoped","elementRoster"];
        // Carry passive HOLD and currently matching admission/issued-leg provenance. No MOVE replay, acknowledgement grace,
        // local callback or FSM handle becomes portable command authority.
        private _holdProof=[];
        private _nativeProof=[];
        private _nativeCommands=_drill getOrDefault ["nativeCommands",createHashMap];
        if (_nativeCommands isEqualType createHashMap && {count _nativeCommands <= 64}) then {
            {
                private _row=_nativeCommands get _x;
                if (_row isEqualType [] && {count _row == 7}
                    && {(_row select 1) in ["ADMISSION","MOVE"]}
                    && {(_row select 0) in (_drill get "units")}
                    && {[_row select 0,_row] call CBE_fnc_CortexDrillNativeCurrent}) then {
                    // Original observation/issued-leg proof, no portable acknowledgement clock.
                    _nativeProof pushBack [_row select 0,_row select 1,+(_row select 2),_row select 3,-1,[],+(_row select 6)];
                };
                if (_row isEqualType [] && {count _row == 7} && {(_row select 1) == "HOLD"}) then {
                    private _actor=_row select 0;
                    if (_actor isEqualType objNull && {!isNull _actor} && {local _actor}
                        && {group _actor == _group} && {_actor in (_drill get "units")}
                        && {currentCommand _actor == "STOP"}
                        && {(expectedDestination _actor) isEqualTo (_row select 2)}
                        && {formLeader _actor == (_row select 3)}) then {
                        _holdProof pushBack [_actor,+(_row select 2),_row select 3];
                    };
                };
            } forEach (keys _nativeCommands);
        };
        _payload pushBack ["resumeNativeHolds",_holdProof];
        _payload pushBack ["resumeNativeCommands",_nativeProof];
        _payload pushBack ["resumeHoldIssuer",[_drill getOrDefault ["token",""],clientOwner,
            _drill getOrDefault ["ownerEpoch",-1],_generation]];
        _payload pushBack ["resumeSpots",if (_moveProof isEqualTo []) then {+(_drill getOrDefault ["resumeSpots",[]])} else {_moveProof}];
        private _movers=_drill getOrDefault ["movers",[]];
        private _resumeRetries=+(_drill getOrDefault ["resumeRetries",[]]);
        if (_movers isNotEqualTo []) then {
            _resumeRetries=[];
            {_resumeRetries pushBack [_movers param [_forEachIndex,objNull],_x select 0]} forEach (_drill getOrDefault ["retries",[]]);
        };
        _payload pushBack ["resumeRetries",_resumeRetries];
        _payload pushBack ["resumeRecovery",(_drill getOrDefault ["recovery",[]]) apply {[_x select 0,_x select 1]}];
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        _payload pushBack ["resumeUnavailable",+(_operation getOrDefault ["unavailable",[]])];
        private _attempts=_operation getOrDefault ["recoveryAttempts",createHashMap];
        _payload pushBack ["resumeAttempts",(keys _attempts select [0,64]) apply {[_x,_attempts get _x]}];
        _saved pushBack ["drillIntent",[_generation,_drill getOrDefault ["token",""],_payload,_anchors select 1,_anchors select 2]];
    };

};
// Coordinated native observations use the authenticated parent lease, not standalone drill replay.
private _supportToken=_state getOrDefault ["supportToken",""];
private _supportLease=_group getVariable ["CBE_AIPass_SupportLease",[]];
private _supportGeneration=_state getOrDefault ["supportOperationGeneration",-1];
private _supportEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _supportOrder=_state getOrDefault ["supportAuthoredOrder",[]];
if (_supportToken != "" && {count _supportLease == 6} && {(_supportLease select 0) == _supportToken}
    && {serverTime < (_supportLease select 2)} && {_supportGeneration == (_group getVariable ["CBE_OperationGeneration",-2])}
    && {!(_state getOrDefault ["supportAuthoredRevoked",false])}
    && {_supportOrder isNotEqualTo []} && {_supportOrder isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}) then {
    private _proofRows=createHashMap;private _proofOverflow=false;
    private _captureHold={
        params ["_actor","_native","_formationLeader"];
        if (!isNull _actor && {local _actor} && {group _actor == _group} && {currentCommand _actor == "STOP"}
            && {(expectedDestination _actor) isEqualTo _native} && {formLeader _actor == _formationLeader}) then {
            if (count _proofRows >= 64 && {!(netId _actor in _proofRows)}) exitWith {_proofOverflow=true};
            _proofRows set [netId _actor,[_actor,+_native,_formationLeader]];
        };
    };
    private _parentHolds=_state getOrDefault ["supportStopHolds",createHashMap];
    if (_parentHolds isEqualType createHashMap && {count _parentHolds <= 64}) then {
        {private _row=_parentHolds get _x;
            if (_row isEqualType [] && {count _row == 7} && {(_row select 0) isEqualType objNull}
                && {(_row select 1) == _supportToken} && {(_row select 2) == _supportGeneration}
                && {(_row select 3) == _supportEpoch} && {(_row select 6) == (_supportLease select 2)}) then {
                [_row select 0,_row select 4,_row select 5] call _captureHold;
            };
        } forEach (keys _parentHolds);
    };
    // A second transfer before child reconstruction forwards the original observations,
    // not a new observation window. Local changed commands are discarded; nonlocal rows
    // remain proposals that the receiving owner must validate before using them.
    private _supportParent=_group getVariable ["CBE_Operation",createHashMap];
    private _adoptionUntil=_supportParent getOrDefault ["supportAdoptionUntil",-1];
    private _carryNative={
        params ["_row"];
        if (!(_row isEqualType []) || {!(count _row in [3,10])} || {!((_row select 0) isEqualType objNull)}) exitWith {};
        private _actor=_row select 0;
        if (isNull _actor || {group _actor != _group} || {!alive _actor}) exitWith {};
        if (local _actor && {currentCommand _actor != (["STOP","MOVE"] select (count _row == 10))
            || {(expectedDestination _actor) isNotEqualTo (_row select 1)} || {formLeader _actor != (_row select 2)}}) exitWith {};
        if (count _proofRows >= 64 && {!(netId _actor in _proofRows)}) exitWith {_proofOverflow=true};
        _proofRows set [netId _actor,_row apply {if (_x isEqualType []) then {+_x} else {_x}}];
    };
    if (_adoptionUntil isEqualType 0 && {finite _adoptionUntil} && {serverTime < _adoptionUntil}
        && {(_supportParent getOrDefault ["generation",-1]) == _supportGeneration}
        && {(_supportParent getOrDefault ["ownerEpoch",-1]) == _supportEpoch}
        && {(_supportParent getOrDefault ["supportToken",""]) == _supportToken}
        && {(_supportParent getOrDefault ["supportExpiry",-1]) == (_supportLease select 2)}) then {
        private _pending=_state getOrDefault ["supportHoldAdoption",[]];
        if (_pending isEqualType [] && {count _pending == 5}
            && {(_pending select [0,4]) isEqualTo [_supportGeneration,_supportEpoch,_adoptionUntil,_supportLease select 2]}
            && {(_pending select 4) isEqualType []} && {count (_pending select 4) <= 64}) then {
            {[_x] call _carryNative} forEach (_pending select 4);
        };
        private _importedMoves=_state getOrDefault ["supportNativeMoves",createHashMap];
        if (_importedMoves isEqualType createHashMap && {count _importedMoves <= 64}) then {
            {[_importedMoves get _x] call _carryNative} forEach (keys _importedMoves);
        };
    };
    private _childHolds=_drill getOrDefault ["nativeCommands",createHashMap];
    if ((_drill getOrDefault ["supportToken",""]) == _supportToken
        && {(_drill getOrDefault ["operationGeneration",-1]) == _supportGeneration}
        && {(_drill getOrDefault ["ownerEpoch",-1]) == _supportEpoch}
        && {_childHolds isEqualType createHashMap} && {count _childHolds <= 64}) then {
        {private _row=_childHolds get _x;
            if (_row isEqualType [] && {count _row == 7} && {(_row select 0) isEqualType objNull}
                && {(_row select 1) == "HOLD"} && {(_row select 0) in (_drill getOrDefault ["units",[]])}) then {
                [_row select 0,_row select 2,_row select 3] call _captureHold;
            };
            // An acknowledged, unchanged MOVE can be observed on the new owner without replaying it.
            // Carry original progress clocks; the native acknowledgement grace never migrates.
            if (_row isEqualType [] && {count _row == 7} && {(_row select 1) == "MOVE"}
                && {(_drill getOrDefault ["stage",""]) == "MOVE"}) then {
                private _actor=_row select 0;
                private _slot=(_drill getOrDefault ["movers",[]]) find _actor;
                private _samples=_drill getOrDefault ["progress",[]];
                if (_slot >= 0 && {_slot < count _samples} && {!isNull _actor} && {local _actor}
                    && {group _actor == _group} && {currentCommand _actor == "MOVE"}
                    && {formLeader _actor == (_row select 3)} && {count (_row select 6) == 3}
                    && {((expectedDestination _actor) param [0,[],[[]]]) isEqualTo (_row select 6)}) then {
                    if (count _proofRows >= 64 && {!(netId _actor in _proofRows)}) then {_proofOverflow=true} else {
                        private _sample=_samples select _slot;
                        _proofRows set [netId _actor,[_actor,+(expectedDestination _actor),_row select 3,+(_row select 6),
                            _drill get "supportSequence",_drill get "teamTurn",
                            serverTime+(_sample select 1)-time,serverTime+(_sample select 3)-time,
                            _sample select 0,+(_sample select 2)]];
                    };
                };
            };
        } forEach (keys _childHolds);
    };
    if (!_proofOverflow) then {
        _saved pushBack ["supportHoldProof",[_supportToken,_supportGeneration,_supportEpoch,
            _supportLease select 2,+_supportOrder,(keys _proofRows) apply {_proofRows get _x}]];
    };
};
if (_saved isNotEqualTo (_group getVariable ["CBE_AIPass_Checkpoint", []])) then {
    _group setVariable ["CBE_AIPass_Checkpoint", _saved, true];
};

private _phase = _state getOrDefault ["phase","CALM"];
if (_phase != (_group getVariable ["CBE_AIPass_PublicPhase",""])) then {
    [_group,_state,_phase,"CHECKPOINT_REPAIR",_state getOrDefault ["phaseStart",time],true] call CBE_fnc_CortexSetPhase;
};

// Engine MOVE commands are local to their issuing owner. Preserve the small amount of
// semantic state needed to rebuild an unfinished investigation or search after migration;
// never serialize a scheduled callback or claim that an accepted command completed.
private _transitionIntent = [];
if (_phase in ["INVESTIGATE","SEARCH"]) then {
    private _target = _state getOrDefault ["enemyPos",[]];
    if (count _target >= 2) then {
        private _duration = missionNamespace getVariable [
            ["CBE_AIPass_PostContact_SearchSeconds","CBE_AIPass_Investigate_Seconds"] select (_phase == "INVESTIGATE"),
            [45,60] select (_phase == "INVESTIGATE")
        ];
        private _startedAt = serverTime-((time-(_state getOrDefault ["phaseStart",time])) max 0);
        private _transitionDeadline=if (_phase == "SEARCH") then {_state getOrDefault ["searchDeadline",_startedAt+_duration]} else {_startedAt+_duration};
        _transitionIntent = [_phase,+_target,_startedAt,_transitionDeadline,_state getOrDefault ["areaInvestigation",""],+(_state getOrDefault ["searchTeam",[]])];
    };
};
if (_transitionIntent isNotEqualTo (_group getVariable ["CBE_Cortex_TransitionIntent",[]])) then {
    _group setVariable ["CBE_Cortex_TransitionIntent",_transitionIntent,true];
};

private _token = _state getOrDefault ["supportToken",""];
private _arrived = _state getOrDefault ["arrivedAt",-1];
private _status = if (_token == "") then {[]} else {[_token,if (_arrived < 0) then {-1} else {round (serverTime-(time-_arrived))},_state getOrDefault ["responding",false],_state getOrDefault ["assaulting",false]]};
if (_status isNotEqualTo (_group getVariable ["CBE_AIPass_SupportStatus",[]])) then {_group setVariable ["CBE_AIPass_SupportStatus",_status,true]};

// Public tactical roles change only at fire-team transitions, not every movement sample.
private _teams=if ((_drill getOrDefault ["supportToken",""]) == "") then {[]} else {
    [_drill get "supportToken",_drill get "supportSequence",_drill get "stage",_drill get "teamTurn",_drill get "teams",_drill getOrDefault ["movers",[]]]
};
if (_teams isNotEqualTo (_group getVariable ["CBE_Cortex_SupportTeams",[]])) then {_group setVariable ["CBE_Cortex_SupportTeams",_teams,true]};
