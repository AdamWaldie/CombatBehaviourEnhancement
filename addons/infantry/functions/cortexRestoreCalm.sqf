/*
 * Author: WaldoTheWarfighter
 * Calm remount intent retains its original native waypoint receipt and operation generation;
 * replacement orders retire boarding without seat cleanup, and migration keeps the original deadline.
 * Generic recall and marker retirement preserve unresolved flight/naval native cleanup
 * through the shared typed reservation gate; no restoration window is renewed.
 * Ordinary current-owner support teardown uses release-only native hold handback before
 * erasing its token. External yields and checkpoint-only restoration never invoke that executor.
 * Named ordinary post-contact restoration preserves only an exact finite deferred static pack;
 * explicit release/disable/external/locality teardown still retires it without native fire theft.
 * Remount cleanup preserves a newer vehicle assignment from Zeus or another controller.
 * Attack permission is restored only by its common operation owner, never loose state flags.
 * Returns a group to CALM and releases the engagement controls it still owns.
 * Group behaviour/combat/speed restoration shares one atomic native-task footprint gate.
 * Blocked or unconfirmed pairs survive in the latest CalmPolicyUnresolved evidence receipt;
 * no automatic retry or late restoration authority is inferred from it.
 * Live independent actor-movement reservations survive generic cleanup; only their
 * feature owner may retire them. Unknown/malformed reservations cannot authorize recall.
 * Ends an active drill synchronously before consuming its restoration data; queued
 * steps then find no matching drill and cannot revive the old movement.
 *
 * Restores recorded changes: a retreat combat-mode lease goes back to its prior value only while
 * the group still has Cortex's applied value; behaviour goes back to the value
 * recorded at first contact only if the pass changed it and the group is still in COMBAT (a squad
 * that was SAFE before an actual firefight comes back AWARE, not SAFE); speed goes
 * back only if the pass changed it. Pass waypoints are removed so the group resumes its own
 * waypoints, the search or investigation team and soldiers holding ground from a drill rejoin
 * formation, stances still matching the recorded Cortex value go back to AUTO, and infantry
 * dismounted by the pass remount their
 * vehicle. Morale is kept and recovers slowly.
 * Locality and authority: call where the group is local.
 *
 * Review contract: Investigation can change SAFE to AWARE; cleanup restores that recorded behaviour as well as a COMBAT change. Only the local group owner performs restoration.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP> - from CBE_fnc_CortexGroupState
 *
 * 2: allow remount <BOOL>, true; false during stop, ownership restoration or external takeover.
 * 3: yield to external order <BOOL>, false; when true Cortex removes its owned controls and
 *    preserves identifiable replacement commands, behaviour and speed.
 * 4: transition reason <STRING>, "RESTORED"; published with the CALM handover.
 * 5: force transition record <BOOL>, false; used only when a new owner must replace a stale public
 *    phase even though its fresh local state already begins in CALM.
 * 6: preserve phase during adoption <BOOL>, false; internal locality continuation only.
 *    Suppresses an artificial CALM record while a validated unfinished drill is reconstructed.
 * Repeat/JIP: removes only CBE transient orders and restores recorded values.
 * Explicitly tracked Cortex holds and their public actor markers restore PATH and resume formation
 * even if local state vanished during migration or combat relabelled doStop as ATTACK/FIRE.
 * Search teams never restore PATH because Cortex did not disable it for that action;
 * ordinary cleanup ends their stale search move, while external takeover preserves a replacement
 * MOVE or other command. Commands which cannot be a combat-side effect of a hold survive.
 * Pending remount intent is public for owner migration; GroupTick retries for up to 60 seconds.
 * Any finite COMPAT movement handover is released before its local support token is erased.
 * The per-engagement native-contact marker and targetless vehicle dismount lease are also cleared,
 * so a later danger-only wake cannot inherit permission to search or exit from an earlier event.
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group, _state] call CBE_fnc_CortexRestoreCalm;
 * Result: the group carries on with its mission as it was before contact.
 *
 * Recall yields to dormancy, native flight and queued care; owned PATH handback remains separate.
 * PATH restoration requires the actual legacy support marker; ordinary drill holders never
 * enable PATH. Return-to-formation excludes active clearance, Zeus, services and actor reservations.
 * Current callers: CortexGroupTick, CortexReleaseGroup, CortexLocality and CortexOnboardContact.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_allowRemount",true,[true]], ["_yieldToExternal",false,[true]], ["_reason","RESTORED",[""]], ["_forcePhase",false,[true]], ["_preservePhase",false,[true]]];
private _reverseCleanup=_group getVariable ["CBE_VehicleReverse",[]];
if (local _group && {count _reverseCleanup == 9}) then {
    [_group,_state,objNull,[],"RELEASE",_reverseCleanup select 1] call CBE_fnc_CortexVehicleReverseStep;
};
if (isNull _group || {!local _group}) exitWith {};
// A cleanup can run before the engine elects a replacement leader. All CBE-owned followers use
// this viable local anchor; external handovers still suppress the follow command below.
private _leader=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
// A pending drill step may not run until after a checkpoint or ownership change.
// Restore its movement restrictions now, before clearing the checkpoint below.
if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
    [_group,_state,"CALM"] call CBE_fnc_CortexFlankEnd;
};
// Finish exact coordinated native holds before generic teardown erases their support token.
// Checkpoint-only restoration and external yields must not turn into a fresh release executor.
if (!_yieldToExternal && {(_group getVariable ["CBE_AIPass_State",createHashMap]) isEqualTo _state}
    && {(_state getOrDefault ["supportToken",""]) != ""}) then {
    [_group,_state,"RELEASE"] call CBE_fnc_CortexSupportMaintain;
};
// Generic engagement cleanup is not the owner of every finite actor task. An
// unknown reservation is also not permission to issue a return-to-formation order.
private _actorMoveFree={
    params ["_actor"];
    !([_actor] call CBE_fnc_CortexActorMoveReserved)
};
private _releaseOwnedHold={
    params ["_unit",["_restorePath",true],["_returnSearchTeam",false]];
    // Only the actual legacy PATH marker proves that this cleanup disabled PATH.
    // A historical list entry or an ordinary doStop holder is not such a lease.
    isNil {
    private _leader=[_group] call CBE_fnc_CortexGroupAnchor;
    private _pathOwned=_restorePath && {_unit getVariable ["CBE_Cortex_SupportPathHold",false]};
    if (local _unit && {group _unit == _group} && {!isPlayer _unit}
        && {isNull (remoteControlled _unit)} && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}) then {
        if (_pathOwned) then {
            _unit enableAI "PATH";
            _unit setVariable ["CBE_Cortex_SupportPathHold",nil,true];
        };
        private _command=toUpperANSI currentCommand _unit;
        private _ownedHold=_command in ["","STOP","ATTACK","FIRE","SUPPRESS"];
        // A replacement controller may intentionally leave a unit stationary, firing or holding
        // position. Remove only CBE's PATH lease during that handover; do not turn a neutral
        // engine command into a new follow order.
        private _recallOwned=if (_returnSearchTeam) then {
            [_group,_state,_unit] call CBE_fnc_CortexSearchMoveOwned
        } else {
            if (_restorePath) then {_ownedHold} else {[_group,_state,_unit] call CBE_fnc_CortexHolderRecallOwned}
        };
        if (!_yieldToExternal && {_recallOwned}
            && {simulationEnabled _unit} && {!isObjectHidden _unit} && {!fleeing _unit}
            && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
            && {!isNull _leader} && {[_leader] call CBE_fnc_CortexCombatEffective}
            && {isNull objectParent _unit} && {[_unit] call CBE_fnc_CortexCombatEffective}
            && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo []}
            && {!([_group] call CBE_fnc_CortexZeusHeld)}
            && {!([_group,false,_unit] call CBE_fnc_CortexExternalTakeover)}
            && {[_unit] call _actorMoveFree}) then {
            _unit doFollow _leader;
            if (!_restorePath && {!_returnSearchTeam}) then {_unit setVariable ["CBE_Cortex_HolderToken",nil,true]};
        };
    };
    };
};
private _supportHeld=_state getOrDefault ["supportHeld",[]];
{
    if (_x getVariable ["CBE_Cortex_SupportPathHold",false]) then {_supportHeld pushBackUnique _x};
} forEach units _group;
{[_x,true,false] call _releaseOwnedHold} forEach _supportHeld;
_state deleteAt "supportHeld";
_state deleteAt "supportBoundSequence";
// Withdrawals, calm restoration and external handovers retire the shared assignment.
private _supportLease=_group getVariable ["CBE_AIPass_SupportLease",[]];
if (count _supportLease == 7 && {(_state getOrDefault ["supportToken",""]) == (_supportLease select 0)}) then {
    [_group,_supportLease select 0,false,_supportLease,clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck",2];
};
[_group,"SUPPORT",false] call CBE_fnc_CortexOwnershipLease;
private _movementOwner=(_state getOrDefault ["movementLease",[]]) param [0,""];
if (_movementOwner != "") then {[_group,_movementOwner,false] call CBE_fnc_CortexOwnershipLease};
{_state deleteAt _x} forEach ["supportHeld","supportBoundSequence","supportToken","responding","assaulting","respondingTo","respondUntil"];
// Native attack permission belongs to the common operation's typed receipt.
// Loose legacy state flags cannot restore it or supply a default mission baseline.
private _retreatModeLease = _state getOrDefault ["retreatCombatMode",[]];
// The three group policy components restore together below, before remount admission.
// Search movement never disables PATH. Do not enable a mission-disabled feature while
// returning a search team. During an ordinary handback its Cortex MOVE is explicitly
// retired; during a Zeus takeover a MOVE may already be the curator's replacement order.
{if (alive _x) then {[_x,false,true] call _releaseOwnedHold}} forEach (_state getOrDefault ["searchTeam", []]);
// Current drill holders use ordinary doStop and never disable PATH. Their return must
// preserve a mission-disabled PATH feature; legacy support PATH leases were handled above.
{if (alive _x) then {[_x,false,false] call _releaseOwnedHold}} forEach (_state getOrDefault ["holders", []]);
// Consume original hold/search route receipts before our own temporary route is removed.
// Preserve only split-locality ordinary holds. Current actor tokens exclude already recalled rows.
private _pendingHolds=if (_yieldToExternal) then {[]} else {
    ((_state getOrDefault ["holderRecallReceipts",[]]) select [0,64]) select {
        _x isEqualType [] && {count _x == 8} && {(_x select 0) isEqualType objNull}
        && {!isNull (_x select 0)} && {!local (_x select 0)}
        && {group (_x select 0) == _group}
        && {((_x select 0) getVariable ["CBE_Cortex_HolderToken",[]]) isEqualTo (_x select [1,5])}
    }
};
[_group] call CBE_fnc_CortexGroupMoveClear;
// Changed routes are not adopted as new proof by this bounded handback.
if (_pendingHolds isNotEqualTo []) then {[_group,_pendingHolds] call CBE_fnc_CortexHolderRecallPending};
{
    if (local _x && {_x getVariable ["CBE_AIPass_StanceSet", false]}) then {
        private _routineProof=[_group,_x] call CBE_fnc_CortexStanceReceipt;
        private _routineAuthority=!_yieldToExternal && {!isPlayer _x} && {isNull (remoteControlled _x)}
            && {([_x] call CBE_fnc_CortexExternalOwner) == ""};
        if (_routineAuthority && {count _routineProof == 4}) then {
            if (toUpperANSI (unitPos _x) == (_x getVariable ["CBE_Cortex_AppliedStance",""])) then {_x setUnitPos "AUTO"};
        };
        if (!_routineAuthority || {count _routineProof != 4}
            || {([_group,_x,true] call CBE_fnc_CortexStanceReceipt) isEqualTo []}) then {
            _x setVariable ["CBE_Cortex_AppliedStance",nil,true];
            _x setVariable ["CBE_Cortex_StanceReceipt",nil,true];
            _x setVariable ["CBE_AIPass_StanceSet",nil,true];
        };
    };
    if (local _x) then {
        if ((_x getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isNotEqualTo createHashMap) then {
            ["RELEASE",_x] call CBE_fnc_LauncherMove;
        };
        private _target = _x getVariable ["CBE_AIPass_VehicleTarget",objNull];
        if (!_yieldToExternal && {!isPlayer _x} && {isNull (remoteControlled _x)}
            && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!isNull _target} && {assignedTarget _x == _target}) then {_x doTarget objNull};
        _x setVariable ["CBE_AIPass_VehicleTarget",nil,true];
        _x setVariable ["CBE_AIPass_TargetHold",nil];
        // Feature-specific release below retains its own tag/actor checks. Do not
        // erase a live successor's proof merely because group contact has ended.
        if ([_x] call _actorMoveFree) then {_x setVariable ["CBE_Cortex_ActorMove",nil]};
    };
} forEach units _group;
// Use the same exact-assignment release as CONTACT; never start a deployment during CALM.
[_group,_state,[],true,_yieldToExternal] call CBE_fnc_CortexStaticSupport;
_group setVariable ["CBE_Danger_StaticAttempt",nil,true];
// Carried equipment shares its executor's actor-task-safe retirement boundary.
private _preserveStaticPacking=!_yieldToExternal && {_reason in [
    "CONTACT_ENDED","DANGER_EXPIRED","REGROUP_TIMEOUT","REGROUP_COHESIVE",
    "INVESTIGATION_COMPLETE","INVESTIGATION_TIMEOUT"]};
[_group,_state,[],false,true,_yieldToExternal,_preserveStaticPacking] call CBE_fnc_CortexStaticDeployStep;
_group setVariable ["CBE_Danger_StaticDeployAttempt",nil,true];
private _vehicleJink=_state getOrDefault ["vehicleDangerJink",[]];
private _jinkVehicle=_vehicleJink param [1,objNull,[objNull]];
if (!isNull _jinkVehicle && {local _jinkVehicle}) then {
    private _jinkMarker=_jinkVehicle getVariable ["CBE_Danger_VehicleJink",[]];
    if (_jinkMarker param [1,grpNull,[grpNull]] == _group
        && {(_state getOrDefault ["vehicleOperationGeneration",-1]) >= 0}
        && {(_jinkMarker param [4,-1,[0]]) == (_state getOrDefault ["vehicleOperationGeneration",-2])}) then {
        _jinkVehicle setVariable ["CBE_Danger_VehicleJink",nil,true];
    };
};
// Public turn proof survives this local state cleanup until native acknowledgement.
[_group,"RELEASE"] call CBE_fnc_VehicleTurnRetire;
// Group policy cleanup is a short atomic commit, not three scattered native writes.
// Native settings which still equal CBE's application may nevertheless belong to a new
// task. Preserve those pairs as unresolved evidence rather than overriding that task or
// claiming restoration. This receipt does not grant any automatic late-write authority.
private _unresolvedPolicies=[];
private _retreatSpeedLease=_state getOrDefault ["retreatSpeedMode",[]];
isNil {
    private _policyAvailable=[_group] call CBE_fnc_CortexGroupPostureTaskAvailable;
    if (!_yieldToExternal && {count _retreatModeLease == 2} && {combatMode _group == (_retreatModeLease select 1)}
        && {(_retreatModeLease select 0) != (_retreatModeLease select 1)}) then {
        if (_policyAvailable) then {_group setCombatMode (_retreatModeLease select 0)};
        if (combatMode _group != (_retreatModeLease select 0)) then {
            _unresolvedPolicies pushBack ["COMBAT_MODE",_retreatModeLease select 0,_retreatModeLease select 1,
                ["NATIVE_TASK","UNCONFIRMED"] select _policyAvailable];
        };
    };
    if (!_yieldToExternal && {_state getOrDefault ["behaviourChanged", false]} && {behaviour _leader in ["COMBAT", "AWARE"]}) then {
        private _base = _state getOrDefault ["baseBehaviour", "AWARE"];
        // After a real firefight retain alertness rather than returning to SAFE.
        if (_base == "SAFE" && {_state getOrDefault ["hadContact", false]}) then {_base = "AWARE"};
        private _applied=behaviour _leader;
        if (_base != _applied) then {
            if (_policyAvailable) then {_group setBehaviour _base};
            if (behaviour _leader != _base) then {
                _unresolvedPolicies pushBack ["BEHAVIOUR",_base,_applied,
                    ["NATIVE_TASK","UNCONFIRMED"] select _policyAvailable];
            };
        };
    };
    if (!_yieldToExternal && {count _retreatSpeedLease == 2}
        && {speedMode _group == (_retreatSpeedLease select 1)}
        && {(_retreatSpeedLease select 0) != (_retreatSpeedLease select 1)}) then {
        if (_policyAvailable) then {_group setSpeedMode (_retreatSpeedLease select 0)};
        if (speedMode _group != (_retreatSpeedLease select 0)) then {
            _unresolvedPolicies pushBack ["SPEED_MODE",_retreatSpeedLease select 0,_retreatSpeedLease select 1,
                ["NATIVE_TASK","UNCONFIRMED"] select _policyAvailable];
        };
    };
};
if (_unresolvedPolicies isNotEqualTo []) then {
    _group setVariable ["CBE_Cortex_CalmPolicyUnresolved",[serverTime,
        _group getVariable ["CBE_AIPass_Epoch",0],_group getVariable ["CBE_OperationGeneration",0],
        _reason,_unresolvedPolicies],true];
};
// This finite episode keeps its admitting native order, including same-position policy edits.
// Publish before native seat commands; JIP metadata alone never issues boarding.
private _boarding=_state getOrDefault ["dismounted",[]];
private _remountDeadline=serverTime+60;
private _remountGeneration=_group getVariable ["CBE_OperationGeneration",0];
private _remountOrder=[_group] call CBE_fnc_NativeOrderReceipt;
if (_allowRemount && {!_yieldToExternal} && {_boarding isNotEqualTo []}) then {
    _group setVariable ["CBE_Cortex_Remount",[_remountDeadline,+_boarding,_remountGeneration,+_remountOrder],true];
};
{
    _x params ["_unit", "_vehicle"];
    if (_allowRemount && {!_yieldToExternal}
        && {_remountGeneration == (_group getVariable ["CBE_OperationGeneration",0])}
        && {_remountOrder isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {group _unit == _group}
        && {isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}}
        && {[_group,"CBE_AIPass_VehicleRemount_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_unit,_vehicle,true] call CBE_fnc_CortexPassengerReady}) then {
        _unit assignAsCargo _vehicle;
        [_unit] orderGetIn true;
    };
} forEach _boarding;
_group setVariable ["CBE_Cortex_DismountContinuation",nil,true];
if (!_allowRemount || {_yieldToExternal}) then {
    private _retiringRemount=_group getVariable ["CBE_Cortex_Remount",[]];
    private _retiringCurrent=count _retiringRemount == 4
        && {(_retiringRemount select 2) isEqualTo (_group getVariable ["CBE_OperationGeneration",0])}
        && {(_retiringRemount select 3) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)};
    // Yielding to another owner never cancels that owner's matching seat command.
    if (!_yieldToExternal && {_retiringCurrent}) then {
        {
            _x params ["_unit","_vehicle"];
            if (local _unit && {group _unit == _group} && {isNull objectParent _unit}
                && {assignedVehicle _unit == _vehicle}) then {[_unit] orderGetIn false; unassignVehicle _unit};
        } forEach (_retiringRemount select 1);
    };
    _group setVariable ["CBE_Cortex_Remount",nil,true];
};
[_group,_state] call CBE_fnc_CortexSearchHoldRelease;
private _retiringPoint=_state getOrDefault ["pointWithdrawal",[]];
if (_retiringPoint isNotEqualTo []) then {
    if ((_group getVariable ["CBE_PointWithdrawal_Result",[]]) isEqualTo []) then {
        _group setVariable ["CBE_PointWithdrawal_Result",["INCOMPLETE",_reason,+(_retiringPoint select 0),[],serverTime],true];
    };
    _group setVariable ["CBE_PointWithdrawal_Status",["ENDED",_reason,serverTime],true];
    _state deleteAt "pointWithdrawal";
};
{_state deleteAt _x} forEach [
    "consolidationRoutes", "baseAttack", "attackChanged", "areaInvestigation", "enemyPos", "behaviourChanged", "speedChanged", "searchTeam", "searchMoveReceipts", "searchDeadline", "searchMemory", "searchIndoorJobs", "searchIndoorAttempted", "searchPointVisited", "lastContactObservation", "searchBuildingVisits", "dismounted", "onboardContactUntil", "reinforceRequested", "reinforceDispatchedAt",
    "withdrawn", "contactLeader", "lastSeen", "contactKnowledge", "dangerDismount", "holders", "holderRecallReceipts", "baseBehaviour", "baseSpeed", "armourSeen",
    "armourRequested", "antiArmourRelocation", "coordinated", "coordinatedPendingUntil", "retreatCombatMode", "retreatSpeedMode", "retreatRetryAt", "movementLease", "retreatStart", "retreatTarget", "retreatProgress", "withdrawOperationGeneration", "vehicleDangerJink", "vehicleDangerOrient", "reserveCommitted", "arrivedAt", "assaulting", "hadContact"
];
_group setVariable ["CBE_Cortex_Withdrawal",nil,true];
_group setVariable ["CBE_Cortex_WithdrawalIntent",nil,true];
_group setVariable ["CBE_Cortex_WithdrawalOrder",nil,true];
_group setVariable ["CBE_Cortex_TransitionIntent",nil,true];
_group setVariable ["CBE_AIPass_Checkpoint", [], true];
// Explicit terminal handovers remain observable even when the tactical phase was already CALM.
_forcePhase=_forcePhase || {_reason in ["CORTEX_STOPPED","ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]};
if (!_preservePhase || {_reason != "OWNERSHIP_ADOPTED"}) then {
    [_group,_state,"CALM",_reason,time,_forcePhase] call CBE_fnc_CortexSetPhase;
};
if (missionNamespace getVariable ["CBE_AIPass_Debug", false]) then {diag_log format ["[CBE] %1 CALM restored", _group]};
