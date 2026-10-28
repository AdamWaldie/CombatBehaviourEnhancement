/*
 * Author: WaldoTheWarfighter
 * Withdraws original remote passenger support consent before group cleanup; no troop/vehicle command is sent.
 * Post-clear hold recall respects unresolved native movement cleanup through the shared
 * reservation gate; no hold/retry deadline or successor task is renewed.
 * Pending landed-foot handover is retired by group release even after the boat operation ended.
 * Finite indoor and point actors release only their exact journal-owned native legs before group cleanup.
 * Contact-only disable may preserve independent jobs after validating its narrow keep-brain scope.
 * Dismount speed handback uses the shared exact crew/native-order receipt; refusal retains evidence.
 * Final post-clear recall yields to native flight, queued care and dormancy.
 * Hands a group back to its own orders and removes everything the pass applied to it.
 *
 * Ends any flank drill (re-enabling only the AI features the drill itself disabled), rejoins the
 * search team, removes pass waypoints, restores behaviour and speed without ordering passengers to board,
 * and releases both scoped SPLIT-mode and blanket CBE-mode COMPAT ownership. Explicit building
 * orders remain in place during ordinary cleanup; a detected Zeus takeover releases them before
 * restoring the rest of Cortex state so no old controller competes with the curator.
 * Locality and authority: call where the group is local; state and flags are machine-local.
 *
 * Review contract: Only the current group owner restores the public COMPAT flag. Changed restoration checkpoints are public and consumed on ownership adoption.
 *
 * A Zeus takeover yields movement, formation, behaviour and speed to the curator while still restoring
 * Cortex-owned AI feature switches and removing Cortex waypoints. Repeat/JIP: only tracked changes are
 * restored; repeated cleanup is harmless and never boards passengers.
 * Public remount intent is cancelled even when owner migration left no local behaviour map.
 * A public actor marker likewise releases only PATH restrictions proven to belong to Cortex.
 * A finite danger-cover move is retired by its exact actor and generation before external control
 * is restored, so an already-issued reflex cannot survive a Zeus or specialist takeover.
 * A crew owner restores a forced speed borrowed for an onboard dismount safe stop only while the
 * exact zero-speed lease remains current and no newer controller owns the group. The crew also
 * retracts its targetless onboard danger report so another passenger owner cannot consume stale work.
 * Ordinary vehicle unload-in-combat leases are released for the tracked exact vehicles. The previous
 * value is restored only without external takeover and only while CBE's applied value is unchanged.
 * Naval cleanup restores the exact boat forced speed and removes only the token-matched CBE plan.
 * Arguments:
 * 0: group <GROUP>
 * 1: forget <BOOL> - also clear the managed flag so discovery may pick the group up again
 *    (optional, default: true)
 * 2: transition reason <STRING> - published with the CALM handover. Empty selects
 *    ZEUS_TAKEOVER or EXTERNAL_TAKEOVER when another controller owns the group, otherwise RELEASED
 *    (optional, default: "").
 * 3: retain independent group brain <BOOL>, default false; internal Contact-disabled release only.
 *    Ignored for full forgetting, nonlocality, Zeus or external takeover.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group] call CBE_fnc_CortexReleaseGroup;
 * Result: the group behaves exactly as it would without the pass.
 *
 * Current callers: Cortex eligibility/stop cleanup, Zeus and AI-order handovers, surrender,
 * defence, garrison and building-clear order entry.
 */

params [["_group", grpNull, [grpNull]], ["_forget", true, [false]], ["_reason", "", [""]], ["_keepBrain",false,[false]]];
if (isNull _group) exitWith {};
[_group,"CLOSE"] call CBE_fnc_CortexMechanisedRemote;
[_group,true] call CBE_fnc_CortexIlluminationStep;
// Only the Contact-disabled reconciliation may preserve the independent actor/brain work.
// Validate before actor retirement; full release and takeover cannot inherit this exemption.
_keepBrain=_keepBrain && {_reason == "CONTACT_DISABLED"} && {!_forget} && {local _group}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)};
if (!_keepBrain) then {
[_group,"RELEASE"] call CBE_fnc_VehicleTurnRetire;
{
    if (local _x && {(_x getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isNotEqualTo createHashMap}) then {
        ["RELEASE",_x] call CBE_fnc_LauncherMove;
    };
    if ((_x getVariable ["CBE_FiringPosition_Order",[]]) isNotEqualTo []) then {
        ["RETIRE",_x] call CBE_fnc_FiringPositionOperation;
    };
    private _point=_x getVariable ["CBE_PointActor_Brain",createHashMap];
    if (count _point > 0 || {(_x getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo []}) then {
        ["FINISH",_x,_point] call CBE_fnc_PointActorOperation;
    };
    private _indoor=_x getVariable ["CBE_IndoorActor_Brain",createHashMap];
    if (count _indoor > 0 || {(_x getVariable ["CBE_IndoorActor_Order",[]]) isNotEqualTo []}) then {
        ["FINISH",_x,_indoor] call CBE_fnc_IndoorActorOperation;
    };
} forEach units _group;
};
private _state = _group getVariable ["CBE_AIPass_State", createHashMap];
private _brain=_group getVariable ["CBE_GroupBrain",createHashMap];
if (count _brain > 0 && {!_keepBrain}) then {
    _brain set ["cancelled",true];
    _brain set ["cancelReason",if (_reason == "") then {"RELEASED"} else {_reason}];
    _brain set ["wakeAt",time];
    // Retire this FSM's identity synchronously. Its later Finished state must not
    // release a replacement CLEAR or other operation started in this same frame.
    _group setVariable ["CBE_GroupBrain_Generation",(_group getVariable ["CBE_GroupBrain_Generation",0])+1];
    _group setVariable ["CBE_GroupBrain",nil];
    _group setVariable ["CBE_GroupBrain_FSM",nil];
    _group setVariable ["CBE_Cortex_GroupJob",nil];
};
private _yieldToZeus=local _group && {[_group] call CBE_fnc_CortexZeusHeld};
// The helper covers player members, curator possession, specialist ownership and explicit
// compatibility markers. Do not restore a stale CBE formation or posture when any one of those
// arrives between the original operation and this release.
private _yieldToExternal=local _group && {!_yieldToZeus} && {[_group] call CBE_fnc_CortexExternalTakeover};
if (_reason == "") then {
    _reason=if (_yieldToZeus) then {"ZEUS_TAKEOVER"} else {if (_yieldToExternal) then {"EXTERNAL_TAKEOVER"} else {"RELEASED"}};
};
private _externalTakeover=_yieldToZeus || {_yieldToExternal} || {_reason in ["ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]};
// Release an interrupted cross-group dismount without stranding the vehicle at forced speed zero.
private _releasedVehicles=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {!(_vehicle in _releasedVehicles)}
        && {local _vehicle} && {effectiveCommander _vehicle in units _group}) then {
        _releasedVehicles pushBack _vehicle;
        [_vehicle,_group,"RELEASE",!_externalTakeover] call CBE_fnc_CortexDismountStop;
        _vehicle setVariable ["CBE_Cortex_DismountStopRequest",nil,true];
        _vehicle setVariable ["CBE_Cortex_OnboardDanger",nil,true];
    };
} forEach units _group;
// Stop restoration precedes operation/route cleanup, which can change our own native receipt.
// Full shutdown must release a native STOP acquired after a successful clear.
// Ordinary contact-state cleanup does not undo the explicit post-clear hold.
private _clearHold=_group getVariable ["CBE_Cortex_ClearHold",[]];
if (local _group && {count _clearHold == 5} && {_externalTakeover || {_reason == "CORTEX_STOPPED"}}) then {
    _group setVariable ["CBE_Cortex_ClearHold",nil,true];
    if (!_externalTakeover && {(_clearHold select 0) == (_group getVariable ["CBE_AIPass_ClearGeneration",0])}
        && {(_clearHold select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}) then {
        private _anchor=leader _group;
        private _deferredClear=[];
        private _issuedClear=[];
        private _priorAttempts=_group getVariable ["CBE_Cortex_ClearHoldRetireAttempts",[]];
        private _priorAttemptActors=if (count _priorAttempts == 3 && {(_priorAttempts select 0) == (_clearHold select 0)}) then {
            _priorAttempts select 2
        } else {[]};
        private _holdJob=createHashMapFromArray [["group",_group],["nativeHoldPositions",createHashMapFromArray (_clearHold select 4)]];
        {
            if (local _x && {group _x == _group} && {!isPlayer _x} && {currentCommand _x == "STOP"} && {[_x,_holdJob] call CBE_fnc_BuildingActorHoldOwned}
                && {isNull objectParent _x} && {isNull remoteControlled _x}
                && {[_x] call CBE_fnc_CortexCombatEffective}
                && {simulationEnabled _x} && {!isObjectHidden _x} && {!fleeing _x}
                && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                && {!([_group,true,_x] call CBE_fnc_CortexExternalTakeover)}
                && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
                && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
                && {!(_x in _priorAttemptActors)}) then {
                _issuedClear pushBackUnique _x;
                _x doFollow _anchor;
            };
            if (local _x && {group _x == _group} && {alive _x} && {!isPlayer _x}
                && {[_x,_holdJob] call CBE_fnc_BuildingActorHoldOwned}
                && {!([_group,true,_x] call CBE_fnc_CortexExternalTakeover)}) then {
                _deferredClear pushBackUnique _x;
            };
        } forEach (_clearHold select 3);
        if (_deferredClear isNotEqualTo []) then {
            private _retainedHold=+_clearHold;
            _retainedHold set [3,_deferredClear];
            _retainedHold set [4,(_clearHold select 4) select {(_x select 0) in (_deferredClear apply {netId _x})}];
            _group setVariable ["CBE_Cortex_ClearHold",_retainedHold,true];
            private _window=_group getVariable ["CBE_Cortex_ClearHoldRetire",[]];
            if (!(count _window == 4 && {(_window select [0,2]) isEqualTo (_clearHold select [0,2])}
                && {(_window select 3) == clientOwner})) then {
                private _retireUntil=serverTime+30;
                if (_window isEqualType [] && {count _window == 4}
                    && {(_window select 2) isEqualType 0} && {finite (_window select 2)}) then {
                    _retireUntil=_retireUntil min (_window select 2);
                };
                _group setVariable ["CBE_Cortex_ClearHoldRetire",[_clearHold select 0,_clearHold select 1,_retireUntil,clientOwner],true];
            };
            private _activeWindow=_group getVariable ["CBE_Cortex_ClearHoldRetire",[]];
            private _oldAttempts=_group getVariable ["CBE_Cortex_ClearHoldRetireAttempts",[]];
            private _attempts=if (count _oldAttempts == 3
                && {(_oldAttempts select [0,2]) isEqualTo [_clearHold select 0,_activeWindow select 2]}) then {
                +(_oldAttempts select 2)
            } else {[]};
            {_attempts pushBackUnique _x} forEach _issuedClear;
            _group setVariable ["CBE_Cortex_ClearHoldRetireAttempts",[_clearHold select 0,_activeWindow select 2,_attempts],true];
        };
    };
};
// New curator intent invalidates pending operation work even when no common record
// is active. Advance on the owner once per token; repeated cleanup is a no-op here.
if (local _group && {_reason == "ZEUS_TAKEOVER"}) then {
    private _curatorToken=_group getVariable ["CBE_AIPass_ZeusHold",[]];
    if (count _curatorToken == 2
        && {(_group getVariable ["CBE_OperationCuratorToken",-1]) != (_curatorToken select 0)}) then {
        // Release exact-owned drill feature holds before invalidating their generation.
        // ZEUS suppresses posture, mode and formation restoration; the curator keeps its order.
        if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
            [_group,_state,"ZEUS"] call CBE_fnc_CortexFlankEnd;
        };
        _group setVariable ["CBE_OperationCuratorToken",_curatorToken select 0];
        _group setVariable ["CBE_OperationGeneration",(_group getVariable ["CBE_OperationGeneration",0])+1,true];
    };
};
// Explicit holding orders can survive without a tactical map while contact automation is off.
// A terminal release still needs one authoritative diagnostic record, not a stale checkpoint.
if (local _group && {count _state == 0}
    && {_reason in ["CORTEX_STOPPED","ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]}) then {
    _state set ["phase",_group getVariable ["CBE_AIPass_PublicPhase","CALM"]];
};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if (local _group && {count _operation > 0}) then {
    [_group,_operation getOrDefault ["generation",-1],_reason] call CBE_fnc_OperationCancel;
};
if ((_state getOrDefault ["navalOperation",[]]) isNotEqualTo []
    || {(_group getVariable ["CBE_Cortex_NavalOperation",[]]) isNotEqualTo []}
    || {(_group getVariable ["CBE_Cortex_NavalGroundElement",[]]) isNotEqualTo []}) then {
    [_group,_state] call CBE_fnc_CortexNavalRelease;
};
// Defence in depth for every caller, including a release delivered after locality migration. The
// curator client normally retires these public tokens before dispatch, but cleanup must never depend
// on that client-side write arriving first.
if (_externalTakeover) then {
    _group setVariable ["CBE_Cortex_CombinedRole",nil,true];
    _group setVariable ["CBE_Cortex_CombinedApplied",nil,true];
    _group setVariable ["CBE_Cortex_CombinedOpportunity",nil,true];
};
// CBE building operations are movement owners too. Zeus replacement orders terminate them before
// general group state is restored.
if (_externalTakeover) then {
    // Defence is an explicit movement owner too. Retire its public assignment so
    // discovery/locality replay cannot restore the old line after a curator edit.
    [_group,false] call CBE_fnc_CortexDefendRelease;
    [_group,false] call CBE_fnc_CortexClearRelease;
    [_group,false] call CBE_fnc_CortexGarrisonRelease;
};
private _markedSupportHold=(units _group) findIf {_x getVariable ["CBE_Cortex_SupportPathHold",false]} >= 0;
if (local _group && {count _state > 0 || {_markedSupportHold} || {(_group getVariable ["CBE_Cortex_Remount",[]]) isNotEqualTo []}}) then {
    if (count (_state getOrDefault ["drill", createHashMap]) > 0) then {[_group, _state, ["RELEASE","ZEUS"] select _externalTakeover] call CBE_fnc_CortexFlankEnd};
    [_group, _state, false, _externalTakeover, _reason] call CBE_fnc_CortexRestoreCalm;
};
if (local _group && {!_keepBrain}) then {
    _group setVariable ["CBE_Cortex_DismountContinuation",nil,true];
    [_group,-1,false,""] call CBE_fnc_DangerGroupHideStep;
    _group setVariable ["CBE_Danger_CoverPending",nil];
    private _dangerCoverLease=_group getVariable ["CBE_Danger_CoverLease",[]];
    if (count _dangerCoverLease >= 2) then {
        [_group,_dangerCoverLease select 0,[],_dangerCoverLease select 1,true] call CBE_fnc_DangerCoverStep;
    };
    private _dangerActor=[_group] call CBE_fnc_CortexGroupAnchor;
    if (isNull _dangerActor) then {_dangerActor=leader _group};
    [_dangerActor,"RELEASE"] call CBE_fnc_DangerReact;
    // The engine FSM may have applied a separate weak stance to any local member, including an
    // observer which is not the current group anchor. Retire every exact actor lease now so a
    // feature shutdown restores CBE-owned posture and an external takeover simply discards it.
    {
        if (local _x) then {[_x] call CBE_fnc_DangerEngineRelease};
    } forEach units _group;
    [_group,"",false] call CBE_fnc_CortexOwnershipLease;
    // A release or Zeus takeover invalidates any still-published danger handoff before another
    // controller can consume it. Event handlers will create a fresh, owner-local response later.
    _group setVariable ["CBE_Danger_Response",nil,true];
    _group setVariable ["CBE_Danger_ResponseEvent",nil];
    _group setVariable ["CBE_Danger_Action",nil,true];
    _group setVariable ["CBE_Danger_Contact",nil,true];
    _group setVariable ["CBE_Danger_VehicleContext",nil,true];
    private _currentBrain=_group getVariable ["CBE_GroupBrain",createHashMap];
    if (count _currentBrain > 0) then {_currentBrain deleteAt "responsiveUntil"};
};
// General driving owns a speed cap, never a route. Its former vehicle may no longer contain this
// group by the time Zeus, a player or another controller takes ownership, so release the tracked
// local set as well as currently occupied vehicles.
if (local _group) then {
    if (!_keepBrain) then {
        private _drivingBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
        if (count _drivingBrain > 0) then {[_drivingBrain,_reason] call CBE_fnc_DrivingOperationFinish};
        _group setVariable ["CBE_Driving_Brain",nil];
        {[_x,_group] call CBE_fnc_DrivingAssistRelease} forEach (_group getVariable ["CBE_DrivingAssist_Vehicles",[]]);
        _group setVariable ["CBE_DrivingAssist_Vehicles",nil];
    };
    {
        if (local _x) then {
            [_x,_group,"RELEASE",!_externalTakeover] call CBE_fnc_CortexVehicleUnloadPolicy;
        };
    } forEach +(_group getVariable ["CBE_Cortex_UnloadPolicyVehicles",[]]);
};
_group setVariable ["CBE_AIPass_State", nil];
if (_forget) then {
    _group setVariable ["CBE_AIPass_Managed",nil];
    _group setVariable ["CBE_GroupBrain_Generation",(_group getVariable ["CBE_GroupBrain_Generation",0])+1];
    _group setVariable ["CBE_GroupBrain",nil];
    _group setVariable ["CBE_GroupBrain_FSM",nil];
    _group setVariable ["CBE_Cortex_GroupJob",nil];
};
