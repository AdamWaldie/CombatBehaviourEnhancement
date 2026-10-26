/*
 * Author: WaldoTheWarfighter
 * The existing finite native-adoption window carries passive holds and exact MOVE observations, never an acknowledgement grace.
 * Coordinated adoption restores bounded recovery and route-refresh journals before acknowledgement.
 * Waits for the matching server reservation before issuing a support order on its current owner.
 * Locality/authority: queued only by authenticated SupportLocal; all execution gates are checked again.
 * Repeat/JIP: at most five seconds waiting for ordered lease/contact state; stale tokens never issue movement.
 * A support update may replace its own lease. A server-selected coordinated attack route may
 * replace the exact local tactical drill only within the same 75 m contact area; it never replaces withdrawal, vehicle or artillery movement.
 * When coordinated assault is enabled, the first shared-contact delivery acknowledges eligibility
 * without acquiring movement, compatibility or operation ownership. The squad keeps its native
 * combat and any local tactical drill while the server selects a safe avenue. Only a returned viable
 * attack route may release that exact drill and atomically acquire coordinated-assault ownership.
 * Rally movement is retained for reinforcement
 * when coordinated assault is explicitly disabled. Assault hands a COORDINATED_ASSAULT lease to
 * server-assigned squad roles and owner-local successive fire-team bounds; it does not issue a
 * competing whole-squad waypoint. A nearby squad already in CONTACT or SECURITY may join the same
 * finite action when it has no other movement owner; requiring CALM here made mutually aware squads
 * fight beside one another without ever composing support-by-fire and manoeuvre roles.
 * During assault, each bound leases pursuit features only from its current moving fire team.
 * The covering fire team and other squads retain native target sharing and engagement.
 * New infantry support requires at least three available combat-effective dismounts; dormant,
 * hidden, fleeing and care-busy members do not qualify. Existing token delivery/adoption retains
 * its established health roster; later owner execution remains authoritative. Mounted passenger groups
 * and operating vehicle crews reject this lease instead of executing infantry movement in vehicles.
 * In COMPAT SPLIT mode, the finite support lease temporarily pauses COMPAT group manoeuvres for the
 * responder only. The base-of-fire group and every config-only COMPAT add-on remain active.
 * Reinforcement and coordinated assault independently authorize discovery, while acceptance requires
 * the requester and responder to share the mode which will consume the lease. A mismatched pair is
 * rejected instead of entering RESPONDING with no possible successor state.
 * Rally movement also uses 10 m completion; readiness requires physical squad arrival in GroupTick.
 * Ownership adoption reuses a matching public lease/status pair rather than inventing a second
 * support lifecycle. It reconstructs only semantic state and lets SupportMaintain consume the
 * current public role on the new owner. Coordinated adoption requires the original
 * full authored-order receipt; a same-position waypoint edit cannot become its new baseline.
 * Server owner-change redelivery waits for the canonical locality-adopted parent and may
 * only acknowledge it. It never recreates an operation or recaptures its journals.
 * Qualified passive holds enter one original five-second actor-locality window, bounded by
 * the original lease expiry. Duplicate actual-owner adoption never restarts that window.
 * Coordinated adoption requires the original parent recovery budget snapshot. Spent counts
 * and unavailable actors survive; running recovery commands/timers are never replayed.
 * Arguments: 0: job <HASHMAP> containing group, lease, waitUntil and optional adopt <BOOL>, authoredOrder <ARRAY> and authoredRevoked <BOOL> holdProof <ARRAY> and recoveryProof <ARRAY> for coordinated adoption.
 * Return Value: Retry delay in seconds or -1 after acknowledgement.
 * Current callers: SupportLocal through the existing scheduler and CortexLocality adoption.
 * Example: [_job] call CBE_fnc_CortexSupportApply;
 * Result: a valid reservation becomes one owner-local rally or coordinated-assault assignment.
 */
params ["_job"];
private _group = _job get "group";
private _lease = _job get "lease";
if (!local _group) exitWith {-1};
private _current = _group getVariable ["CBE_AIPass_SupportLease",[]];
if (_current isNotEqualTo _lease) exitWith {
    if (serverTime < (_job get "waitUntil")) then {0.25} else {
        // A superseded delivery must not reject a newer order with the same reservation token.
        -1
    }
};
_lease params ["_token","_requester","_expiry","_rally","_needAT","_attack"];
private _state = [_group] call CBE_fnc_CortexGroupState;
private _publicStatus=_group getVariable ["CBE_AIPass_SupportStatus",[]];
private _adopting=_job getOrDefault ["adopt",false]
    && {count _publicStatus == 4}
    && {(_publicStatus select 0) == _token}
    && {_publicStatus select 2};
private _same = (_state getOrDefault ["supportToken",""]) == _token || {_adopting};
private _movementLease = _state getOrDefault ["movementLease",[]];
private _movementOwner = _movementLease param [0,""];
private _movementLeaseActive = count _movementLease == 2 && {time < (_movementLease select 1)};
private _supportOwnsMovement = _same && {_movementOwner in ["SUPPORT_RALLY","COORDINATED_ASSAULT"]};
private _fit = (units _group) select {[_x] call CBE_fnc_CortexCombatEffective};
// New admission needs usable actors now. Repeated delivery/adoption preserves the
// established assignment; its owner-side execution and capacity gates remain separate.
private _footFit = _fit select {isNull objectParent _x};
if (!_same) then {
    _footFit=_footFit select {simulationEnabled _x && {!isObjectHidden _x} && {!fleeing _x}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}};
};
// Group-level rally destinations also reach native operating crews. A foot subset alone does
// not make that authority safe: vehicle support retains its own movement operation.
private _operatingCrew = (units _group) findIf {
    private _platform=objectParent _x;
    alive _x && {!isNull _platform}
        && {_x in [driver _platform,gunner _platform,commander _platform]}
} >= 0;
private _phase = _state getOrDefault ["phase","CALM"];
private _requesterReinforce = !isNull _requester && {[_requester,"CBE_AIPass_Reinforce_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _requesterCoordinated = !isNull _requester && {[_requester,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _responderReinforce = [_group,"CBE_AIPass_Reinforce_Enable",true] call CBE_fnc_CortexFeatureEnabled;
private _responderCoordinated = [_group,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled;
private _sharedReinforce = _requesterReinforce && {_responderReinforce};
private _sharedCoordinated = _requesterCoordinated && {_responderCoordinated};
private _contactPeer = _phase in ["CONTACT","SECURITY"] && {_sharedCoordinated};
private _supportEnabled = _sharedReinforce || {_sharedCoordinated};
private _groupTransmitter = [_group] call CBE_fnc_CortexGroupTransmitter;
private _requesterTransmitter = [_requester] call CBE_fnc_CortexGroupTransmitter;
private _attackAllowed = _attack isNotEqualTo [] && {_sharedCoordinated};
// Server redelivery after an owner change is an acknowledgement request only.
// Locality adoption must first reconstruct and validate the original semantic journals.
private _ownerDelivery=_job getOrDefault ["ownerChange",false];
private _deliveryParent=_group getVariable ["CBE_Operation",createHashMap];
private _deliveryReady=!_ownerDelivery || {
    _adopting && {(_state getOrDefault ["supportToken",""]) == _token}
        && {(_state getOrDefault ["supportOperationGeneration",-1]) == (_deliveryParent getOrDefault ["generation",-2])}
        && {(_deliveryParent getOrDefault ["generation",-1]) == (_group getVariable ["CBE_OperationGeneration",-2])}
        && {(_deliveryParent getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_deliveryParent getOrDefault ["supportOwner",-1]) == clientOwner}
        && {(_deliveryParent getOrDefault ["supportToken",""]) == _token}
        && {(_deliveryParent getOrDefault ["supportExpiry",-1]) == _expiry}
        && {(_deliveryParent getOrDefault ["phase",""]) != "CANCELLED"}
        && {(_deliveryParent getOrDefault ["intent",""]) == (["SUPPORT_RALLY","COORDINATED_ASSAULT"] select _attackAllowed)}
};
if (!_deliveryReady) exitWith {
    if (serverTime < (_job get "waitUntil")) then {0.25} else {
        [_group,_token,false,_lease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
        -1
    }
};
if (_ownerDelivery) then {
    _job set ["authoredOrder",+(_state getOrDefault ["supportAuthoredOrder",[]])];
    _job set ["authoredRevoked",_state getOrDefault ["supportAuthoredRevoked",false]];
};
private _directCoordinationPending = _attack isEqualTo [] && {_sharedCoordinated};
private _adoptedOrder=_job getOrDefault ["authoredOrder",[]];
private _adoptOrderCurrent=!(_adopting && {_attackAllowed}) || {
    !(_job getOrDefault ["authoredRevoked",false]) && {_adoptedOrder isNotEqualTo []} && {
        _adoptedOrder isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)
    }
};
// Revalidate on the actor owner: proximity to the requester does not imply a shared contact.
// Keep an existing drill committed when its live target belongs to a different engagement.
private _localDrill = _state getOrDefault ["drill",createHashMap];
private _localTarget = _localDrill getOrDefault ["target",objNull];
private _contactReceipt=_group getVariable ["CBE_Cortex_SupportContact",[]];
private _requestContact=if (count _contactReceipt in [2,3] && {(_contactReceipt select 0) == _token}) then {_contactReceipt select 1} else {[]};
private _contactConfirmedAt=_contactReceipt param [2,-1,[0]];
private _contactFresh=count _requestContact == 3 && {count _contactReceipt == 3}
    && {_contactConfirmedAt >= 0} && {_contactConfirmedAt <= serverTime+1}
    && {serverTime-_contactConfirmedAt <= 60};
private _committedAttack=_attackAllowed && {_same} && {count _publicStatus == 4}
    && {(_publicStatus select 0) == _token} && {_publicStatus select 2} && {_publicStatus select 3}
    && {_adopting || {_state getOrDefault ["assaulting",false]}};
if (_attackAllowed && {!_committedAttack} && {count _requestContact != 3 || {count _contactReceipt != 3}}
    && {serverTime < (_job get "waitUntil")}) exitWith {0.25};
// Public contact and lease state can arrive separately during delivery or HC adoption.
// Wait only inside the original finite delivery window; acquire no controls while waiting.
if (_attackAllowed && {_movementOwner == "TACTICAL_DRILL"} && {!isNull _localTarget}
    && {alive _localTarget} && {count _requestContact != 3}
    && {serverTime < (_job get "waitUntil")}) exitWith {0.25};
private _localBelief=_localDrill getOrDefault ["enemyPos",[]];
private _beliefValid=_localBelief isEqualType [] && {count _localBelief in [2,3]}
    && {_localBelief findIf {!(_x isEqualType 0)} < 0};
private _sharedDrillContact = isNull _localTarget || {!alive _localTarget}
    || {count _requestContact == 3 && {_beliefValid} && {_localBelief distance2D _requestContact <= 75}};
private _replaceLocalDrill = _attackAllowed && {_sharedDrillContact} && {_movementOwner == "TACTICAL_DRILL"}
    && {count (_state getOrDefault ["drill",createHashMap]) > 0};
private _prepareAlongsideDrill=_directCoordinationPending && {_movementOwner == "TACTICAL_DRILL"}
    && {count (_state getOrDefault ["drill",createHashMap]) > 0};
// Communication remains tied to a qualified transmitter, but local tactical readiness must survive
// the formal leader becoming a casualty before the engine elects a replacement.
private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
private _okay = missionNamespace getVariable ["CBE_AIPass_Active",false] && {!([] call CBE_fnc_CortexIsPaused)}
    && {serverTime < _expiry} && {!isNull _requester} && {side _requester == side _group}
    && {!isNull _groupTransmitter} && {!isNull _requesterTransmitter}
    && {[_group] call CBE_fnc_CortexIsEligible} && {[_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {_supportEnabled} && {_adoptOrderCurrent}
    && {!(_job getOrDefault ["adopt",false]) || {_adopting}}
    && {(_state getOrDefault ["supportAuthoredRevokedToken",""]) != _token} && {!_attackAllowed || {_committedAttack} || {_contactFresh}}
    && {!_operatingCrew} && {count _footFit >= 3} && {!isNull _anchor} && {behaviour _anchor != "CARELESS"} && {!fleeing _anchor}
    && {_same || {getSuppression _anchor <= ([0.2,0.65] select _contactPeer)}}
    && {_groupTransmitter distance2D _requesterTransmitter <= (missionNamespace getVariable ["CBE_AIPass_Reinforce_Radius",600])}
    && {(_group getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []} && {(_group getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
    && {!(_group getVariable ["CBE_AIPass_ClearBuilding",false])} && {!(_group getVariable ["CBE_AIPass_RegroupQueued",false])}
    && {_same || {(_phase == "CALM" || {_contactPeer}) && {!(_state getOrDefault ["responding",false])}}}
    // A support order may update its own movement. Only a server-selected attack route may
    // replace the exact local tactical drill; all other movement owners remain authoritative.
    && {!_movementLeaseActive || {_supportOwnsMovement} || {_replaceLocalDrill} || {_prepareAlongsideDrill}}
    && {_fit findIf {private _v = vehicle _x; _v isKindOf "Air" || {_v isKindOf "StaticWeapon"} || {getNumber (configOf _v >> "artilleryScanner") == 1}} < 0}
    && {!_needAT || {_footFit findIf {"AT" in ([_x] call CBE_fnc_CortexCapabilities)} >= 0}};
// Eligibility acknowledgement is not an operation and owns no movement. A route-rejected or
// delayed coordination request therefore cannot make this responder idle.
if (_okay && {_directCoordinationPending}) exitWith {
    [_group,_token,true,_lease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
    -1
};
// Repeated adoption delivery acknowledges the existing actual-owner parent without
// recreating its generation or renewing a pending hold-locality window.
private _existingParent=_group getVariable ["CBE_Operation",createHashMap];
if (_okay && {_adopting} && {(_state getOrDefault ["supportToken",""]) == _token}
    && {(_state getOrDefault ["supportOperationGeneration",-1]) == (_existingParent getOrDefault ["generation",-2])}
    && {(_existingParent getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {(_existingParent getOrDefault ["intent",""]) == (["SUPPORT_RALLY","COORDINATED_ASSAULT"] select _attackAllowed)}
    && {(_existingParent getOrDefault ["supportOwner",-1]) == clientOwner}
    && {(_existingParent getOrDefault ["supportToken",""]) == _token}
    && {(_existingParent getOrDefault ["supportExpiry",-1]) == _expiry}
    && {(_existingParent getOrDefault ["phase",""]) != "CANCELLED"}) exitWith {
    [_group,_token,true,_lease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
    -1
};
// A delivery labelled as ownership-change acknowledgement may never fall through
// into fresh operation admission, even if its observed parent was superseded above.
if (_ownerDelivery) exitWith {
    [_group,_token,false,_lease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
    -1
};
if (_okay && {_replaceLocalDrill}) then {
    [_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd;
};
if (_okay) then {
    _okay = [_group,"SUPPORT",true,_expiry] call CBE_fnc_CortexOwnershipLease;
};
if (_okay && {_adopting || {!_same} || {_attackAllowed && {!(_state getOrDefault ["assaulting",false])}}}) then {
    // The reservation token is durable across locality, but it also needs the shared generation
    // record so a later Zeus/mission order can retire this exact support move without allowing a
    // stale owner callback to recreate it.  The coordinated server will provide the detailed
    // fire-team routes; this entry records only the finite cross-squad intent and live objective.
    private _intent=["SUPPORT_RALLY","COORDINATED_ASSAULT"] select _sharedCoordinated;
    // Lease attack is one ATL position, not an array of route points.
    private _objective=if (_attackAllowed) then {+_attack} else {+_rally};
    private _sourceRecovery=_job getOrDefault ["recoveryProof",[]];
    private _recoveryValid=!(_adopting && {_attackAllowed}) || {
        _sourceRecovery isEqualType [] && {count _sourceRecovery == 9}
            && {(_sourceRecovery select 0) isEqualTo _token} && {(_sourceRecovery select 3) isEqualTo _expiry}
            && {(_sourceRecovery select 1) isEqualTo (_group getVariable ["CBE_OperationGeneration",-1])}
            && {(_sourceRecovery select 2) isEqualType 0} && {finite (_sourceRecovery select 2)}
            && {(_sourceRecovery select 2) >= 0}
            && {(_sourceRecovery select 4) isEqualType []} && {count (_sourceRecovery select 4) <= 64}
            && {(_sourceRecovery select 4) findIf {!(_x isEqualType objNull)} < 0}
            && {(_sourceRecovery select 5) isEqualType []} && {count (_sourceRecovery select 5) <= 64}
            && {(_sourceRecovery select 5) findIf {
                !(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}
                    || {(_x select 0) == ""} || {!((_x select 1) isEqualType 0)}
                    || {!finite (_x select 1)} || {(_x select 1) < 0}
                    || {(_x select 1) != floor (_x select 1)}
            } < 0}
    };
    if (_recoveryValid && {_adopting} && {_attackAllowed}) then {
        _recoveryValid=(_sourceRecovery select 6) isEqualType [] && {count (_sourceRecovery select 6) <= 64}
            && {(_sourceRecovery select 6) findIf {
                !(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}
                    || {(_x select 0) == ""} || {!((_x select 1) isEqualType [])} || {count (_x select 1) != 2}
                    || {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} >= 0}
            } < 0};
    };
    private _sourceBoundProgress=[];
    if (_recoveryValid && {_adopting} && {_attackAllowed}) then {
        _sourceBoundProgress=_sourceRecovery select 7;
        _recoveryValid=_sourceBoundProgress isEqualType [] && {
            _sourceBoundProgress isEqualTo [] || {count _sourceBoundProgress == 4
                && {(_sourceBoundProgress select 0) isEqualType 0} && {finite (_sourceBoundProgress select 0)}
                && {(_sourceBoundProgress select 0) >= 0} && {(_sourceBoundProgress select 0) == floor (_sourceBoundProgress select 0)}
                && {(_sourceBoundProgress select 1) isEqualType []} && {count (_sourceBoundProgress select 1) == 3}
                && {(_sourceBoundProgress select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {(_sourceBoundProgress select 3) in [0,1,2]}
                && {(_sourceBoundProgress select 2) isEqualType []} && {count (_sourceBoundProgress select 2) == 2}
                && {(_sourceBoundProgress select 2) findIf {!(_x isEqualType []) || {count _x > 64}
                    || {_x findIf {!(_x isEqualType objNull)} >= 0}} < 0}
                && {private _roster=(_sourceBoundProgress select 2) select 0;
                    private _all=+_roster; _all append ((_sourceBoundProgress select 2) select 1);
                    count _all <= 64 && {private _present=_all select {!isNull _x};
                        count (_present arrayIntersect _present) == count _present}}
            }
        };
    };
    private _adoptionUntil=-1;
    if (_recoveryValid && {_adopting} && {_attackAllowed}) then {
        _adoptionUntil=_sourceRecovery select 8;
        _recoveryValid=_adoptionUntil isEqualType 0 && {finite _adoptionUntil}
            && {_adoptionUntil == -1 || {_adoptionUntil >= 0 && {_adoptionUntil <= _expiry}}};
        if (_recoveryValid && {_adoptionUntil == -1}) then {_adoptionUntil=(serverTime+5) min _expiry};
    };
    private _sourceBoundAttempts=createHashMap;
    private _sourceAttempts=createHashMap;
    if (_recoveryValid && {_adopting} && {_attackAllowed}) then {
        _sourceAttempts=createHashMapFromArray (_sourceRecovery select 5);
        _sourceBoundAttempts=createHashMapFromArray (_sourceRecovery select 6);
        _recoveryValid=count _sourceAttempts == count (_sourceRecovery select 5)
            && {count _sourceBoundAttempts == count (_sourceRecovery select 6)};
    };
    if (!_recoveryValid) exitWith {
        _okay=false;
        [_group,"SUPPORT",false] call CBE_fnc_CortexOwnershipLease;
    };
    private _sourceHoldRows=[];
    private _holdProof=_job getOrDefault ["holdProof",[]];
    if (_adopting && {_attackAllowed} && {_holdProof isEqualType []} && {count _holdProof == 6}
        && {(_holdProof select 0) isEqualTo _token} && {(_holdProof select 3) isEqualTo _expiry}
        && {(_holdProof select 1) isEqualTo (_group getVariable ["CBE_OperationGeneration",-1])}
        && {(_holdProof select 2) isEqualType 0} && {finite (_holdProof select 2)} && {(_holdProof select 2) >= 0}
        && {(_holdProof select 4) isEqualTo _adoptedOrder}
        && {(_holdProof select 5) isEqualType []} && {count (_holdProof select 5) <= 64}) then {
        _sourceHoldRows=+(_holdProof select 5);
    };
    private _operation=[_group,_intent,_objective,_footFit,[+_objective],"ACCEPTED"] call CBE_fnc_OperationStart;
    if (count _operation == 0) exitWith {
        _okay=false;
        [_group,"SUPPORT",false] call CBE_fnc_CortexOwnershipLease;
    };
    _operation set ["supportToken",_token];
    _operation set ["supportOwner",clientOwner];
    _operation set ["supportExpiry",_expiry];
    _operation set ["supportAdoptionUntil",_adoptionUntil];
    if (_adopting && {_attackAllowed}) then {
        _operation set ["unavailable",+(_sourceRecovery select 4)];
        _operation set ["recoveryAttempts",_sourceAttempts];
        _operation set ["boundRetryAttempts",_sourceBoundAttempts];
        _operation set ["boundProgress",_sourceBoundProgress];
    };
    _group setVariable ["CBE_Operation",_operation,true];
    private _generation=_operation get "generation";
    private _movementReady=true;
    if (!_attackAllowed) then {
        private _waypoint=[_group,_rally,10,"MOVE",_generation] call CBE_fnc_CortexGroupMove;
        _movementReady=!isNull (_waypoint param [0,grpNull,[grpNull]]) && {(_waypoint param [1,-1,[0]]) >= 0};
    };
    if (!_movementReady) exitWith {
        _okay=false;
        [_group,_generation,"INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
        [_group,"SUPPORT",false] call CBE_fnc_CortexOwnershipLease;
    };
    _state set ["supportOperationGeneration",_generation];
    _state deleteAt "supportHoldAdoption";
    _state set ["supportNativeMoves",createHashMap];
    if (_sourceHoldRows isNotEqualTo [] && {serverTime < _adoptionUntil}) then {
        _state set ["supportHoldAdoption",[_generation,_operation get "ownerEpoch",
            _adoptionUntil,_expiry,_sourceHoldRows]];
    };
    _state set ["supportAuthoredRevoked",false];
    _state deleteAt "supportAuthoredRevokedToken";
    if (_attackAllowed) then {
        _state set ["supportAuthoredOrder",if (_adopting) then {+_adoptedOrder} else {
            [_group] call CBE_fnc_NativeOrderReceipt
        }];
    } else {_state deleteAt "supportAuthoredOrder"};
    if (_attackAllowed) then {
        _state set ["movementLease",["COORDINATED_ASSAULT",time+(_expiry-serverTime)]];
    } else {
        _state set ["movementLease",["SUPPORT_RALLY",time+(_expiry-serverTime)]];
    };
    _state set ["assaulting",_attackAllowed];
    _state set ["responding",true]; _state set ["respondingTo",_requester];
    _state set ["respondUntil",time+(_expiry-serverTime)]; _state set ["supportToken",_token];
    if (_adopting) then {
        private _arrivedServerTime=_publicStatus select 1;
        _state set ["arrivedAt",if (_arrivedServerTime < 0) then {-1} else {time-((serverTime-_arrivedServerTime) max 0)}];
        _state set ["supportBoundSequence",-1];
    };
};
[_group,_token,_okay,_lease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
-1
