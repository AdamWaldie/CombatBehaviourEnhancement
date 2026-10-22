/*
 * Author: WaldoTheWarfighter
 * Legacy PATH handback requires the actual marker; modern holder lists grant no PATH or recall authority.
 * Cover STOP and native recalls yield to queued care and dormant actors. Exact hold
 * bookkeeping/restoration stays separate; treatment queues and original deadlines never change.
 * Current COVER capacity is sampled owner-locally at most every two seconds (or role change)
 * through the existing acknowledgement endpoint, with six-second maximum freshness.
 * This reports eligible main-ammunition capacity, not position/arrival or actual covering fire.
 * Older server role sequences never rewind the parent bound progress or consumed local sequence.
 * Actual COVER stops retain separate token/generation/epoch/native destination receipts. Release
 * recalls only unchanged current-owner holds, without enabling PATH. Deferred/changed proof is
 * retained locally. A missing/incapacitated formation leader defers release without consuming
 * its receipt; the existing finite retry window is unchanged. Pending cleanup uses the existing group callback, original lease expiry+30s
 * and at most64 single-actor attempts; migration alone grants no cleanup authority.
 * Coordinated parent support keeps its original authored-order receipt. Edits retire the
 * assignment before covering/bound writes and suppress native cleanup over the replacement.
 * Passive hold adoption uses this callback for at most five original seconds, bounded by
 * lease expiry. Current native/actor checks precede new-owner receipts; no native command is replayed.
 * Owner execution preserves unknown/malformed actor reservations through the shared strict predicate.
 * Releases only the current CBE support assignment when it expires, is revoked or loses every
 * feature gate capable of owning it. A mode must remain enabled at both ends of the reservation;
 * independent requester/responder checks could otherwise preserve a lease whose next state no
 * longer existed. Disabling reinforcement still cannot cancel a shared coordinated assault.
 * Locality/authority: server owns reservations; current group owners validate and execute orders.
 * Restores the recorded autonomous-attack setting when the support move is released.
 * Measures physical rally arrival in both calm and contact phases; seeing an enemy
 * does not cancel an accepted reinforcement reservation.
 * A failed bound keeps its actors at the ground gained with an ordinary stop order until a new
 * MOVE sequence or reservation release. Cover roles never disable PATH, allowing Zeus, locality
 * handover and later operations to move an actor without first repairing hidden AI state.
 * A MOVE role which cannot form two viable local teams reports NOT_READY immediately;
 * the server can yield the turn instead of waiting for its 180-second safety timeout.
 * A server retirement is consumed only when its token matches this local assignment, then releases
 * its PATH holds and movement immediately while the other coordinated squads continue.
 * On release, actors held by Cortex resume formation even when engine combat has
 * relabelled the owned doStop as ATTACK/FIRE. Commands which can only have arrived
 * after the hold are preserved, and new-bound movement is not replaced.
 * Movement ownership uses SUPPORT_RALLY and COORDINATED_ASSAULT leases. Cleanup removes only those
 * lease types and checks that a rally waypoint is still pending, so a completed waypoint is not
 * mistaken for active movement and a newer feature route is never deleted.
 * A live gate closure rejects the exact accepted token back to the server before clearing local
 * state, so a stopped responder cannot retain a coordinated role or consume a support slot.
 * Releasing support also restores the responder's pre-existing COMPAT group-AI setting. The scoped
 * lease prevents COMPAT and Cortex from issuing movement to the same group during rally or assault.
 * Repeat/JIP: unique tokens, shared deadlines and owner acknowledgements retire stale assignments.
 * Route cleanup requires a matching generation and never touches a replacement operation.
 * Arguments: 0: group <GROUP>; 1: local state <HASHMAP>;
 * 2: mode <STRING>, default MAINTAIN; PENDING services registered cleanup only;
 * RELEASE retires the current assignment without starting another role or bound.
 * Return Value: Nothing for maintenance; cleanup-only returns the internal commit BOOL, not reunion.
 * Current callers: GroupTick (MAINTAIN), GroupBrainStep (PENDING), CortexRestoreCalm (RELEASE).
 * Example: [_group, _state] call CBE_fnc_CortexSupportMaintain;
 * Result: the active assignment advances, holds, or releases without competing movement owners.
 */
params ["_group","_state",["_mode","MAINTAIN",[""]]];
_mode=toUpperANSI _mode;
if (!(_mode in ["MAINTAIN","PENDING","RELEASE"]) || {!local _group}) exitWith {};
private _cleanupOnly=_mode == "PENDING";
// The reservation may expire in the same scheduler turn that Zeus or another
// controller claims the group. Retire CBE's lease either way. A normal feature
// shutdown still restores the support hold; only an actual replacement owner keeps
// the saved combat permissions and follower commands out of its task.
private _externalTakeover = [_group] call CBE_fnc_CortexExternalTakeover;
private _supportAuthored=_state getOrDefault ["supportAuthoredOrder",[]];
private _authoredReplaced=(_state getOrDefault ["supportAuthoredRevoked",false]) || {
    _supportAuthored isNotEqualTo [] && {
        _supportAuthored isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)
    }
};
// Seeing a replacement permanently revokes this assignment's delayed cleanup permission.
// A later waypoint edit back to the old values cannot reactivate its pending recall.
if (_authoredReplaced) then {
    _state set ["supportAuthoredRevoked",true];
    private _revokedToken=_state getOrDefault ["supportToken",""];
    if (_revokedToken != "") then {_state set ["supportAuthoredRevokedToken",_revokedToken]};
};
private _mayRestoreGroup=!_externalTakeover && {!_authoredReplaced};
private _movementLease = _state getOrDefault ["movementLease",[]];
private _movementOwner = _movementLease param [0,""];
private _movementLeaseActive = count _movementLease == 2 && {time < (_movementLease select 1)} && {
    switch (_movementOwner) do {
        case "SUPPORT_RALLY": {
            (waypoints _group) findIf {
                (_x select 1) >= currentWaypoint _group && {waypointDescription _x == "CBE AI PASS"}
            } >= 0
        };
        case "COORDINATED_ASSAULT": {_state getOrDefault ["assaulting",false]};
        default {true};
    }
};
private _supportOwnsMovement = _movementLeaseActive && {_movementOwner in ["SUPPORT_RALLY","COORDINATED_ASSAULT"]};
private _token = _state getOrDefault ["supportToken",""];
if (_token == "" && {!_cleanupOnly}) exitWith {
    // A locality/checkpoint loss can leave the public movement lease after the local support token.
    // There is no remaining Cortex assignment to own movement, so return it immediately.
    private _dangerLease = _group getVariable ["CBE_Cortex_OwnershipLease",[]];
    if (count _dangerLease == 3 && {(_dangerLease select 0) == "SUPPORT"}) then {
        [_group,"SUPPORT",false] call CBE_fnc_CortexOwnershipLease;
    };
};
private _operationGeneration=_state getOrDefault ["supportOperationGeneration",-1];
private _cleanup=_state getOrDefault ["supportStopCleanup",[]];
if (_cleanupOnly) then {
    if (_cleanup isEqualType [] && {count _cleanup == 5}) then {
        _token=_cleanup select 0; _operationGeneration=_cleanup select 1;
    };
};
private _finishOperation={
    params ["_result","_reason"];
    if (_operationGeneration >= 0) then {
        if (_result == "COMPLETE") then {
            [_group,_operationGeneration,"COMPLETE",_reason] call CBE_fnc_OperationRelease;
        } else {
            [_group,_operationGeneration,_reason] call CBE_fnc_OperationCancel;
        };
    };
    _state deleteAt "supportOperationGeneration";
};
private _restoreAttack={
    if (_mayRestoreGroup && {_state getOrDefault ["attackChanged",false]}) then {_group enableAttack (_state getOrDefault ["baseAttack",true])};
    _state deleteAt "attackChanged"; _state deleteAt "baseAttack";
};
private _lease = _group getVariable ["CBE_AIPass_SupportLease",[]];
private _requester = _lease param [1,grpNull,[grpNull]];
private _sharedReinforce = !isNull _requester
    && {[_requester,"CBE_AIPass_Reinforce_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_Reinforce_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _sharedCoordinated = !isNull _requester
    && {[_requester,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _supportEnabled = _sharedReinforce || {_sharedCoordinated};
// Record native stops separately from legacy PATH restrictions: these holds never disabled PATH.
// Only actual stop issuers populate this bounded local map; later orders retain their destination.
private _releaseStopHolds={
    isNil {
        if (!local _group || {(_group getVariable ["CBE_AIPass_State",createHashMap]) isNotEqualTo _state}) exitWith {};
        private _holds=_state getOrDefault ["supportStopHolds",createHashMap];
        if (!(_holds isEqualType createHashMap) || {count _holds > 64}) exitWith {};
        if (_cleanupOnly) then {
            private _typed=_cleanup isEqualType [] && {count _cleanup == 5}
                && {(_cleanup select 0) isEqualType ""} && {(_cleanup select 0) != ""}
                && {[1,2,3,4] findIf {!((_cleanup select _x) isEqualType 0) || {!finite (_cleanup select _x)} || {(_cleanup select _x) < 0}} < 0}
                && {[1,2,4] findIf {(_cleanup select _x) != floor (_cleanup select _x)} < 0};
            if (!_typed || {serverTime >= (_cleanup select 3)} || {(_cleanup select 4) >= 64}
                || {(_cleanup select 1) != (_group getVariable ["CBE_OperationGeneration",-1])}
                || {(_cleanup select 2) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
                || {(_state getOrDefault ["supportToken",""]) != ""}) exitWith {
                _state set ["supportStopCleanupResult",["UNRESOLVED_OR_SUPERSEDED",serverTime,+_cleanup]];
                _state deleteAt "supportStopCleanup";
            };
        };
        // The preceding exit belongs to its if block, so enforce retirement at function scope.
        if (_cleanupOnly && {isNil {_state get "supportStopCleanup"}}) exitWith {};
        private _keys=(keys _holds) select {
            private _row=_holds get _x;
            _row isEqualType [] && {count _row == 7} && {(_row select 0) isEqualType objNull}
                && {(_row select 1) == _token} && {(_row select 2) == _operationGeneration}
        };
        private _dueKeys=_keys;
        if (_cleanupOnly && {_keys isNotEqualTo []}) then {
            _dueKeys=[_keys select ((_cleanup select 4) mod count _keys)];
        };
        private _returnLeader=leader _group;
        private _leaderReady=!isNull _returnLeader && {group _returnLeader == _group}
            && {[_returnLeader] call CBE_fnc_CortexCombatEffective};
        if (_leaderReady && {_mayRestoreGroup} && {!([_group] call CBE_fnc_CortexExternalTakeover)}
            && {(_cleanupOnly && {(_state getOrDefault ["supportToken",""]) == ""})
                || {!_cleanupOnly && {(_state getOrDefault ["supportToken",""]) == _token}}}) then {
        {
            private _row=_holds get _x;
            _row params ["_actor","_issuer","_generation","_epoch","_native","_formationLeader","_expiry"];
            if (_generation == (_group getVariable ["CBE_OperationGeneration",-1])
                && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",-1])}
                && {!isNull _actor} && {local _actor} && {group _actor == _group}
                && {[_actor] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _actor}
                && {!isPlayer _actor} && {isNull remoteControlled _actor}
                && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
                && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
                && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
                && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
                && {simulationEnabled _actor} && {!isObjectHidden _actor}
                && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                && {toUpperANSI currentCommand _actor in ["","STOP","ATTACK","FIRE","SUPPRESS"]}
                && {(expectedDestination _actor) isEqualTo _native} && {formLeader _actor == _formationLeader}) then {
                _actor doFollow _returnLeader;
                _holds deleteAt _x;
            };
        } forEach _dueKeys;
        };
        _state set ["supportStopHolds",_holds];
        private _remaining=_keys select {_x in _holds};
        if (_cleanupOnly) then {
            if (_remaining isEqualTo []) then {
                _state set ["supportStopCleanupResult",[["NO_MATCHING_HOLDS","FOLLOW_ISSUED"] select (_keys isNotEqualTo []),serverTime,+_cleanup]];
                _state deleteAt "supportStopCleanup";
            } else {
                private _next=+_cleanup; _next set [4,(_cleanup select 4)+1];
                _state set ["supportStopCleanup",_next];
            };
        } else {
            private _deadline=1e12;
            {
                private _expiry=(_holds get _x) select 6;
                if (_expiry isEqualType 0 && {finite _expiry}) then {_deadline=_deadline min (_expiry+30)};
            } forEach _remaining;
            if (_remaining isNotEqualTo [] && {_deadline < 1e12} && {serverTime < _deadline}) then {
                private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
                private _previous=_state getOrDefault ["supportStopCleanup",[]];
                private _attempts=0;
                if (_previous isEqualType [] && {count _previous == 5}
                    && {(_previous select [0,3]) isEqualTo [_token,_operationGeneration,_epoch]}
                    && {(_previous select 3) isEqualType 0} && {finite (_previous select 3)}
                    && {(_previous select 4) isEqualType 0} && {finite (_previous select 4)}
                    && {(_previous select 4) >= 0} && {(_previous select 4) == floor (_previous select 4)}) then {
                    _deadline=_deadline min (_previous select 3); _attempts=_previous select 4;
                };
                _state set ["supportStopCleanup",[_token,_operationGeneration,_epoch,_deadline,_attempts]];
            };
        };
    };
};
if (_cleanupOnly) exitWith {call _releaseStopHolds};
private _releaseSupport={
    params [["_reason","SUPPORT_RELEASED"]];
    // Retire the exact outgoing bound before a replacement reservation can be admitted.
    // Waiting for its queued callback leaves an old drill blocking SupportBoundStart.
    private _outgoingDrill=_state getOrDefault ["drill",createHashMap];
    if ((_outgoingDrill getOrDefault ["supportToken",""]) == _token) then {
        [_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd;
    };
    call _releaseStopHolds;
    // Reject only the exact lease snapshot accepted by this owner. The server validates token,
    // snapshot and sender again, making repeated cleanup and a racing replacement lease harmless.
    if (count _lease == 6 && {_token == (_lease select 0)}) then {
        [_group,_token,false,_lease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
    };
    // Delete only this support assignment's route. A later withdrawal, vehicle
    // manoeuvre, artillery scoot or tactical drill survives stale support cleanup.
    if (_operationGeneration >= 0
        && {(_supportOwnsMovement || {!_movementLeaseActive})}
        && {_state getOrDefault ["responding",false] || {_state getOrDefault ["assaulting",false]}}) then {
        [_group,_operationGeneration] call CBE_fnc_CortexGroupMoveClear;
    };
    if (_supportOwnsMovement) then {_state deleteAt "movementLease"};
    ["CANCELLED",_reason] call _finishOperation;
    [_group,"SUPPORT",false] call CBE_fnc_CortexOwnershipLease;
    call _restoreAttack;
    {_state deleteAt _x} forEach ["supportToken","responding","respondingTo","respondUntil","arrivedAt","assaulting","supportBoundSettling","supportHoldAdoption","supportNativeMoves","supportCapacityRole","supportCapacityNextAt"];
};
// Engagement teardown requests release only; it must never consume a fresh role or start a bound.
if (_mode == "RELEASE") exitWith {
    if ((_group getVariable ["CBE_AIPass_State",createHashMap]) isEqualTo _state) then {
        ["ENGAGEMENT_HANDOVER"] call _releaseSupport;
    };
};
// The cached operation step is intentionally infrequent. A curator or specialist can claim this
// group between those steps, so retire the matching support lease before any covering hold or bound
// setup below is allowed to write movement. Release observes _mayRestoreGroup and therefore never
// restores CBE's former command over the new owner.
if (_externalTakeover) exitWith {
    ["EXTERNAL"] call _releaseSupport;
};
if (_authoredReplaced) exitWith {
    ["REPLACED"] call _releaseSupport;
};
private _abort = _group getVariable ["CBE_Cortex_SupportAbort",[]];
if (count _abort == 4 && {(_abort select 0) == _token}) exitWith {
    _group setVariable ["CBE_Cortex_SupportAbort",nil,true];
    ["SERVER_RETIREMENT"] call _releaseSupport;
};
if (_lease isEqualTo [] || {(_lease select 0) != _token} || {serverTime >= (_lease select 2)}
    || {!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!_supportEnabled}) exitWith {
    ["LEASE_EXPIRED"] call _releaseSupport
};

if (_state getOrDefault ["assaulting",false] && {!([_group,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {
    ["FEATURE_DISABLED"] call _releaseSupport
};

// Keep the common record current without adding a separate worker.  An external owner, a Zeus
// command or a locality transition wins immediately; the reservation cleanup below then only
// clears the matching token and never restores an older route.
private _operationEndReason="";
if (_operationGeneration >= 0) then {
    private _operationState=[_group,_operationGeneration,3,30,true] call CBE_fnc_OperationStep;
    if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) then {
        _operationEndReason=_operationState;
    };
    // Coordinated cover is deliberately stationary. Its bound drill/server watchdog owns
    // physical movement failure; only ordinary rally uses this aggregate travel timeout.
    if (_operationState == "STALLED" && {!(_state getOrDefault ["assaulting",false])}) then {_operationEndReason="NO_PROGRESS"};
};
// This exit belongs to the function scope. An exitWith nested inside the preceding condition block
// returned only from that block and allowed an invalid reservation to continue into rally/hold work.
if (_operationEndReason != "") exitWith {
    [_operationEndReason] call _releaseSupport;
};

// Consume passive holds and exact acknowledged MOVE observations through this existing callback as actor locality settles.
// Local mismatches retire immediately; nonlocal actors get only the original five seconds.
private _adoption=_state getOrDefault ["supportHoldAdoption",[]];
if (_adoption isNotEqualTo []) then {
    if (_adoption isEqualType [] && {count _adoption == 5}
        && {(_adoption select 0) == _operationGeneration}
        && {(_adoption select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {serverTime < (_adoption select 2)} && {(_adoption select 3) == (_lease select 2)}
        && {(_adoption select 4) isEqualType []} && {count (_adoption select 4) <= 64}) then {
        private _adoptedHolds=_state getOrDefault ["supportStopHolds",createHashMap];
        private _adoptedMoves=_state getOrDefault ["supportNativeMoves",createHashMap];
        private _remainingHolds=[];
        if (_adoptedHolds isEqualType createHashMap && {count _adoptedHolds <= 64}
            && {_adoptedMoves isEqualType createHashMap} && {count _adoptedMoves <= 64}) then {
            {
                if (_x isEqualType [] && {count _x in [3,10]} && {(_x select 0) isEqualType objNull}
                    && {(_x select 1) isEqualType []} && {(_x select 2) isEqualType objNull}) then {
                    private _nativeProof=_x;
                    private _isMove=count _nativeProof == 10;
                    private _moveProofValid=!_isMove || {
                        (_nativeProof select 3) isEqualType [] && {count (_nativeProof select 3) == 3}
                            && {(_nativeProof select 3) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                            && {(_nativeProof select [4,4]) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                            && {(_nativeProof select 4) >= 0} && {(_nativeProof select 4) == floor (_nativeProof select 4)}
                            && {(_nativeProof select 5) in [0,1]}
                            && {(_nativeProof select 6) <= serverTime} && {(_nativeProof select 7) <= serverTime}
                            && {(_nativeProof select 8) isEqualType 0} && {finite (_nativeProof select 8)} && {(_nativeProof select 8) >= 0}
                            && {(_nativeProof select 9) isEqualType []} && {count (_nativeProof select 9) == 3}
                            && {(_nativeProof select 9) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                            && {(_nativeProof select 1) param [0,[],[[]]] isEqualTo (_nativeProof select 3)}
                    };
                    _x params ["_heldActor","_heldNative","_heldLeader"];
                    if (_moveProofValid && {!isNull _heldActor} && {group _heldActor == _group} && {alive _heldActor}) then {
                        if (!local _heldActor) then {_remainingHolds pushBack _x} else {
                            if ([_heldActor] call CBE_fnc_CortexCombatEffective && {isNull objectParent _heldActor}
                                && {simulationEnabled _heldActor} && {!isObjectHidden _heldActor}
                                && {!isPlayer _heldActor} && {isNull remoteControlled _heldActor}
                                && {([_heldActor] call CBE_fnc_CortexExternalOwner) == ""}
                                && {!([_heldActor] call CBE_fnc_CompatibilityExternalControl)}
                                && {!([_heldActor] call CBE_fnc_CortexActorMoveReserved)}
                                && {_heldActor checkAIFeature "MOVE"} && {_heldActor checkAIFeature "PATH"}
                                && {currentCommand _heldActor == (["STOP","MOVE"] select _isMove)}
                                && {(expectedDestination _heldActor) isEqualTo _heldNative} && {formLeader _heldActor == _heldLeader}
                                && {count _adoptedHolds < 64 || {netId _heldActor in _adoptedHolds}}) then {
                                if (_isMove) then {
                                    if (count _adoptedMoves < 64 || {netId _heldActor in _adoptedMoves}) then {
                                        _adoptedMoves set [netId _heldActor,+_nativeProof];
                                    };
                                } else {
                                    _adoptedHolds set [netId _heldActor,[_heldActor,_token,_operationGeneration,
                                        _adoption select 1,+_heldNative,_heldLeader,_adoption select 3]];
                                };
                            };
                        };
                    };
                };
            } forEach (_adoption select 4);
            _state set ["supportStopHolds",_adoptedHolds];
            _state set ["supportNativeMoves",_adoptedMoves];
        };
        if (_remainingHolds isEqualTo []) then {_state deleteAt "supportHoldAdoption"} else {
            private _pendingHolds=+_adoption;_pendingHolds set [4,_remainingHolds];
            _state set ["supportHoldAdoption",_pendingHolds];
        };
    } else {_state deleteAt "supportHoldAdoption"};
};
// Contact can begin before the rally is reached. Readiness must not depend on CALM.
if ((_state getOrDefault ["supportToken",""]) == _token
    && {_state getOrDefault ["responding",false]}
    && {!(_state getOrDefault ["assaulting",false])}
    && {(_state getOrDefault ["arrivedAt",-1]) < 0}
    && {count _lease == 6}) then {
    private _fit=(units _group) select {[_x] call CBE_fnc_CortexCombatEffective};
    if (count _fit >= 3 && {_fit findIf {_x distance2D (_lease select 3) > 45} < 0}) then {
        _state set ["arrivedAt",time];
    };
};

// Server roles own inter-squad timing; the existing drill owns the two local fire teams.
private _role=_group getVariable ["CBE_Cortex_SupportRole",[]];
private _coordinating=(_state getOrDefault ["supportToken",""]) == _token
    && {_state getOrDefault ["assaulting",false]} && {count _role == 5} && {(_role select 0) == _token};
// A late role cannot rewind a consumed or partially completed server bound.
private _boundProgress=(_group getVariable ["CBE_Operation",createHashMap]) getOrDefault ["boundProgress",[]];
if (_coordinating && {_boundProgress isEqualType []} && {count _boundProgress == 4}
    && {(_role select 1) < (_boundProgress select 0)}) exitWith {-1};
private _moving=_coordinating && {(_role select 2) == "MOVE"};
// Retain cleanup for holds created by an older packaged version. New cover roles use doStop only.
private _held=_state getOrDefault ["supportHeld",[]];
{
    if (_x getVariable ["CBE_Cortex_SupportPathHold",false]) then {_held pushBackUnique _x};
} forEach units _group;
private _newMove=_moving && {(_state getOrDefault ["supportBoundSequence",-1]) < (_role select 1)};
if (_newMove || {!_coordinating}) then {
    _state deleteAt "supportCoverIdentity";
    {
        private _pathOwned=_x getVariable ["CBE_Cortex_SupportPathHold",false];
        if (_pathOwned && {local _x} && {group _x == _group} && {!isPlayer _x}
            && {isNull (remoteControlled _x)} && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}) then {
            _x enableAI "PATH";
            if (_x checkAIFeature "PATH") then {_x setVariable ["CBE_Cortex_SupportPathHold",nil,true]};
            // The legacy PATH marker is required, not list membership alone. Combat may
            // relabel its hold; concrete replacement tasks and live actor routes still win.
            private _command=toUpperANSI currentCommand _x;
            if (_mayRestoreGroup && {!_coordinating} && {_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]}
                && {simulationEnabled _x} && {!isObjectHidden _x} && {!fleeing _x}
                && {[_x] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _x}
                && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
                && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
                && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}) then {
                _x doFollow leader _group;
            };
        };
    } forEach _held;
    _state set ["supportHeld",[]];
};
if (_coordinating) then {
    if (_moving) then {
        if ((_state getOrDefault ["supportBoundSequence",-1]) < (_role select 1)) then {
            // Group locality may arrive before member locality. Do not turn that transient
            // ownership edge into NOT_READY or consume the sequence; the existing server
            // bound deadline still applies and this allowance lasts at most five seconds.
            private _settling=_state getOrDefault ["supportBoundSettling",[]];
            private _settleIdentity=[_token,_role select 1,_group getVariable ["CBE_AIPass_Epoch",0]];
            if (count _settling != 2 || {(_settling select 0) isNotEqualTo _settleIdentity}) then {
                _settling=[_settleIdentity,serverTime+5];
                _state set ["supportBoundSettling",_settling];
            };
            private _roleClock=_group getVariable ["CBE_Cortex_SupportRoleDeadline",[]];
            private _clockReady=_roleClock isEqualType [] && {count _roleClock == 4}
                && {(_roleClock select 0) isEqualTo _token} && {(_roleClock select 1) isEqualTo (_role select 1)}
                && {(_roleClock select 3) isEqualTo (_role select 3)}
                && {(_roleClock select 2) isEqualType 0} && {finite (_roleClock select 2)};
            private _localityPending=(units _group) findIf {alive _x && {!local _x}} >= 0 || {!_clockReady};
            if (!_localityPending || {serverTime >= (_settling select 1)}) then {
            private _started=[_group,_state,_role] call CBE_fnc_CortexSupportBoundStart;
            if (!_started) then {
                _state set ["supportBoundSequence",_role select 1];
                _group setVariable ["CBE_Cortex_SupportBoundResult",
                    [_token,_role select 1,"NOT_READY"],true];
            };
            _state deleteAt "supportBoundSettling";
            };
        };
    } else {
        _state deleteAt "supportBoundSettling";
        private _drill=_state getOrDefault ["drill",createHashMap];
        if ((_drill getOrDefault ["supportToken",""]) == _token) then {[_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd};
        private _coverIdentity=[_token,_role select 1];
        if ((_state getOrDefault ["supportCoverIdentity",[]]) isNotEqualTo _coverIdentity) then {
            isNil {
            if (!local _group || {(_group getVariable ["CBE_AIPass_State",createHashMap]) isNotEqualTo _state}
                || {(_state getOrDefault ["supportToken",""]) != _token}
                || {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _role}
                || {(_group getVariable ["CBE_AIPass_SupportLease",[]]) isNotEqualTo _lease}
                || {serverTime >= (_lease select 2)} || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {};
            private _coverOperation=_group getVariable ["CBE_Operation",createHashMap];
            if ((_coverOperation getOrDefault ["generation",-2]) != _operationGeneration
                || {(_coverOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                || {(_coverOperation getOrDefault ["intent",""]) != "COORDINATED_ASSAULT"}
                || {(_coverOperation getOrDefault ["phase",""]) == "CANCELLED"}) exitWith {};
            _coverOperation set ["phase","SUPPORT"];
            _coverOperation set ["supportAdoptionUntil",-1];
            _group setVariable ["CBE_Operation",_coverOperation,true];
            private _stopHolds=_state getOrDefault ["supportStopHolds",createHashMap];
            if !(_stopHolds isEqualType createHashMap) then {_stopHolds=createHashMap};
            if (count _stopHolds > 64) exitWith {};
            // Old invalid/dead/moved-group rows grant no recall authority and consume no new slot.
            {private _row=_stopHolds get _x;
                if (!(_row isEqualType []) || {count _row != 7} || {!((_row select 0) isEqualType objNull)}
                    || {isNull (_row select 0)} || {!alive (_row select 0)} || {group (_row select 0) != _group}) then {_stopHolds deleteAt _x};
            } forEach (keys _stopHolds);
            {
                if (local _x && {group _x == _group} && {isNull objectParent _x}
                    && {simulationEnabled _x} && {!isObjectHidden _x}
                    && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                    && {[_x] call CBE_fnc_CortexCombatEffective} && {!isPlayer _x}
                    && {isNull (remoteControlled _x)} && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
                    && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
                    && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
                    && {!(toUpperANSI currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
                    && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
                    && {toUpperANSI currentCommand _x != "STOP" || {
                        [_group,_state,_x,_token,_operationGeneration,_lease select 2] call CBE_fnc_CortexSupportStopOwned
                    }}
                    && {count _stopHolds < 64 || {netId _x in _stopHolds}}) then {
                    doStop _x;
                    _stopHolds set [netId _x,[_x,_token,_operationGeneration,
                        _group getVariable ["CBE_AIPass_Epoch",0],+(expectedDestination _x),formLeader _x,_lease select 2]];
                };
            } forEach units _group;
            _state set ["supportStopHolds",_stopHolds];
            _state set ["supportCoverIdentity",_coverIdentity];
            };
        };
    };
};

// Observe only the current local COVER roster, on this existing maintenance cadence.
// Capacity is not a hold/arrival acknowledgement or proof of effective covering fire.
if (_coordinating && {!_moving} && {(_role select 2) == "COVER"}
    && {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isEqualTo _role}
    && {(_group getVariable ["CBE_AIPass_SupportLease",[]]) isEqualTo _lease}
    && {serverTime < (_lease select 2)}
    && {(_state getOrDefault ["supportCapacityRole",[]]) isNotEqualTo _role
        || {serverTime >= (_state getOrDefault ["supportCapacityNextAt",-1])}}) then {
    private _members=units _group;
    private _fit=[];
    if (count _members <= 64) then {
        _fit=_members select {
            local _x && {!isPlayer _x} && {isNull objectParent _x}
                && {[_x] call CBE_fnc_CortexCombatEffective}
                && {simulationEnabled _x} && {!isObjectHidden _x}
                && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
                && {isNull remoteControlled _x}
                && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
                && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
                && {[_x] call CBE_fnc_CortexActorFireTaskAvailable}
                && {toUpperANSI currentCommand _x in ["","STOP","ATTACK","FIRE","SUPPRESS"]}
        };
    };
    private _armed=if (combatMode _group in ["YELLOW","RED"]) then {
        {unitCombatMode _x in ["YELLOW","RED"] && {_x checkAIFeature "FIREWEAPON"}
            && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}} count _fit
    } else {0};
    private _observed=serverTime;
    private _capacity=[1,+_role,_group getVariable ["CBE_AIPass_Epoch",0],_observed,
        (_observed+6) min (_lease select 2),count _fit,_armed];
    [_group,_token,true,_lease,clientOwner,_capacity] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
    _state set ["supportCapacityRole",+_role];
    _state set ["supportCapacityNextAt",_observed+2];
};
