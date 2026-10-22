/*
 * Author: WaldoTheWarfighter
 * Native crew flight vetoes new steering and route recall; exact cap-only release remains separate.
 * Native cap application and queue fallback STOP must confirm before their ownership receipt changes.
 * An unconfirmed write preserves the last confirmed cap/baseline and cannot advance recovery.
 * Pending ordinary cap handback takes the cap-only path before child-controller work;
 * it never captures an unconfirmed old cap as a fresh baseline or restarts recovery.
 * Queued ACE care owns driver/operator task admission before the native HEAL transition.
 * Exact spent bypass parents survive traffic pauses without renewing their deadline or attempt.
 * Exact queue-abort STOP handback uses current safety observations in this existing callback; no failed crossing is marked complete.
 * Repeat/JIP: Original public route/recovery clocks survive migration; acknowledgement never replays movement.
 * Native BACK uses the existing finite rear leg only with distinct driver/effective commander.
 * Its immutable pre-command turn/move receipt and observed acknowledgement bind ownership;
 * no new worker, crew reassignment or command replay is added. Unowned BACK still yields.
 * Recovery is explicitly mode-bound: destination and SIMPLE_BACK have distinct native
 * ownership proof. Unknown modes grant no cleanup, adoption or command authority.
 * Traffic retry journal: current brain/epoch and fresh observation are checked in one unscheduled
 * retry/publication section. Edit an isolated journal; successor/native-order changes prevent
 * publication. Rear recovery aborts on aggregate or per-hitpoint damage increase against its
 * original journal; changed/unknown hitpoint tables refuse recovery. No damage suppression occurs.
 * At most128 hitpoints are compared per rear sample; native table retrieval cost remains engine-dependent.
 * Original damage receipts stay immutable; observed repairs lower per-leg minima, so later increases
 * above those minima abort. Repair and damage wholly between samples remain unobservable.
 * Traffic route refresh keeps one original two-second native acknowledgement request. Only
 * its issued goal refreshes command proof; unchanged state waits without another attempt.
 * Pending issued rear requests retain rear pedestrian/body/support and divergence checks;
 * lack of acknowledgement is not evidence that native movement has not started.
 * Changed or expired unacknowledged requests yield that episode. The public request survives
 * locality changes without renewing its expiry or the existing three-attempt/original deadline.
 * Existing three-attempt/original-deadline limits remain; no queue cascade implied.
 * The original episode progress anchor survives every stage and owner adoption. Merely
 * undoing a reverse cannot replenish attempts; unknown anchors grant no reset credit.
 * Rear destinations retain the actual sampled support height, including raised decks.
 * One short rear option follows a blocked long observation; its selected envelope stays
 * in the original episode. Active safety observes remaining travel plus the original buffer.
 * Terrain water without a supporting structure remains refused by DrivingRearClear.
 * Stationary waits/recovery require finite total linear velocity below1km/h, not forward speed.
 * This instantaneous admission is not physical HOLD/READY or proof of native reversing.
 * An unresolved exact reverse handback blocks fresh assistance until newer intent retires its proof.
 * Purpose: Applies a sparse, owner-local safety speed cap and bounded physical recovery to an
 * ordinary AI ground vehicle that is already following a native waypoint. This is the standalone
 * driving layer; registered convoys retain their separate predecessor-spacing controller. Terrain
 * thresholds are expressed in km/h for settings and diagnostics, then converted to the metres per
 * second required by forceSpeed before the command and ownership lease are recorded.
 * Locality / Authority: Runs only where the vehicle is local. It never creates, replaces or
 * deletes a waypoint and yields to players, Zeus remote control, convoy ownership and specialist
 * driving ownership. Ineffective drivers and immobilized vehicles receive no recovery commands.
 * An authored zero forced-speed hold is retained without recovery commands. A newer cap
 * revokes the old recovery journal before any handback; same-value outside writes remain
 * indistinguishable without an external ownership declaration.
 * Deferred exact reverse handback is reconsidered before fresh assistance at this same callback;
 * changed route/seat/command authority retires it without replaying the old rear command.
 * Persistent stationary traffic admits at most three native route retries in one eighty-second
 * public episode; collision caps remain active and newer seat/command ownership ends retries.
 * Traffic dwell restarts after a six-second observation gap or either hull moving more than
 * 1.5 metres in ASL from its dwell anchor; low-speed motion beyond that bound restarts dwell.
 * Native individual MOVE destinations and deliberate STOP commands block new route recovery;
 * the waypoint match includes elevation so a newer stacked-road destination is not flattened.
 * an exact owned reverse journal alone permits its finite handback to the authored route.
 * Native boarding, service, medical and assembly tasks release the exact speed lease;
 * both driver and effective commander are rechecked at each cap/recovery command boundary.
 * Individual movement reservations also yield assistance, including malformed or nonlocal actor leases.
 * The authored waypoint identity includes conditions, timeouts, synchronized triggers, speed,
 * combat mode and formation. Same-index edits retire the old recovery stage. Every cap/recovery
 * command rechecks that identity; the implicit spawn waypoint never authorizes assistance.
 * Road bends, junctions and absolute road grade share the convoy observer at existing cadence.
 * Finite ordinary-lead bypass planning/following also uses this callback, excludes corridor/rear
 * work and requires fresh next-leg geometry before yielding its exact source obstacle constraint.
 * Registered navigation areas use finite approach/crossing work in this same callback; current
 * traffic caps still win, and active corridor legs suppress ordinary route recovery.
 * Friendly pedestrian hulls constrain ordinary driving as well as opted-in convoys.
 * Forward-lane vehicle hulls constrain speed regardless of heading; aligned predecessors use
 * current hull gaps and actual velocity for continuous following caps. Other occupied hulls
 * receive no assumed forward-speed allowance. This does not establish crossing right-of-way.
 * Recognised forward gate/barrier geometry also constrains approach at the existing cadence.
 * Gate animation or damage does not grant passage; nearby openings use server validation, and no closing command is issued.
 * Close stable static blockage may use the same finite rear recovery after fresh dwell;
 * independent traffic, gate and pedestrian constraints still suppress its admission.
 * Owned traffic stops remain sampled; congestion suppresses reverse. Only bounded native-route
 * retries may reconsider persistent blockage. No crossing priority is inferred. Experimental automatic passing uses separate finite
 * preparation and real owner consent, with no collision exemption.
 * The owned rear leg resamples its body corridor once per second on the existing scheduler,
 * stopping for new obstructions within its original reverse deadline. Qualified longer
 * back-off reallocates time inside the same parent while reserving40s for final handback. Intended direction
 * is checked while stopped; an expired rear leg observes the forward retry before issuing it.
 * Reverse admission uses a fresh body-sized rear corridor observation shared with tracked
 * withdrawal. Actor and solid-geometry clearance does not prove native reverse execution.
 * Rear-path recovery retains original pose/direction and aborts >20 degree turns, forward travel
 * over1m or departure from the2.5m rear corridor; a rear MOVE is not proof of native reversing.
 * Near same-lane or predicted crossing conflicts request one-second observation even
 * before they lower the cap. This local hint survives cap-row overrides, never grants motion
 * and retains the four-second braking reaction margin. Actual scheduler latency is unproven.
 * Only the current leader vehicle can refresh/reverse the shared route. Followers keep native
 * formation movement; a leader/seat/locality change invalidates delayed recovery commands.
 * Deliberate native waits near the completion envelope suppress recovery without evaluating
 * waypoint statement code. Recovery also refuses distant scripted, timed, synchronized or
 * object-attached MOVE orders; even currently active synchronized triggers retain authored control.
 * Native execution and ordinary safety caps remain available.
 * New or newly progressing routes get a 20-second planning/observation grace. A route refresh
 * gets 30 seconds before cautious reverse admission; the reverse leg remains six seconds and
 * the final authored-route retry normally gets60 seconds; qualified longer back-off retains
 * at least40 seconds within the same hard deadline. No new order inherits a spent retry window.
 * Exhausted recovery stays at durable stage four without more route/reverse retries. Existing
 * safety sampling continues; new-route identity or measured forward progress can retire exhaustion.
 * Traffic holds, native waits and becoming a follower cannot renew the spent episode.
 * One group driving FSM admits the existing executor through the shared
 * scheduler; group decisions never issue these commands directly.
 * Repeat/JIP: Ordinary cap/baseline observations are machine-local, not a JIP replay.
 * A new owner admits its current native state; it does not inherit these private records.
 * Public finite recovery metadata requires current native command/cap proof before adoption;
 * metadata alone never reapplies an old owner's cap or rear command. Route changes reset
 * finite recovery; release restores only the baseline whose applied cap is still owned.
 * Arguments:
 * 0: group <GROUP> - local AI group commanding the vehicle.
 * 1: operation brain <HASHMAP, empty> - internal current-owner executor receipt.
 * Return Value: Nothing.
 * Confirmed cap publication also updates an exact bypass/corridor parent journal while
 * child destinations differ; no baseline, clock, anchor or spent allowance is renewed.
 * Exact active bypass-child commands retain only their parent budget; ordinary parent
 * route recovery stays blocked until the child retires. Native return has one finite
 * acknowledgement window capped by the unchanged parent hard deadline.
 * Current callers: CBE_fnc_CortexGroupTick (admission), DrivingOperationStep (execution).
 * Example: [group driver truck1] call CBE_fnc_DrivingAssistStart;
 */

params [["_group",grpNull,[grpNull]],["_brain",createHashMap,[createHashMap]]];
if (isNull _group || {!local _group}) exitWith {};
// Normal group decisions admit/reuse the FSM; only its current queued callback writes commands.
if (count _brain == 0) exitWith {[_group] call CBE_fnc_DrivingOperationStart};
if ((_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain
    || {_brain getOrDefault ["cancelled",false]}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {};
private _enabled=[_group,"CBE_AIPass_DrivingAssist_Enable",true] call CBE_fnc_CortexFeatureEnabled;
// Read only the current authored waypoint. Conditions and trigger identities belong to the order,
// just as its position does. A same-index edit must not inherit a reverse request for the old order.
private _readRouteIdentity={[_group] call CBE_fnc_DrivingRouteReceipt};
// Native speed is model-forward only. Sliding, falling or pivoting is movement,
// not a stationary jam or settled handback. Read both motion components on demand
// so scheduled direct callers do not reuse a pre-yield motion sample.
private _stationary={
    params ["_candidate"];
    private _linearSpeed=vectorMagnitude velocity _candidate;
    private _angularSpeed=vectorMagnitude angularVelocity _candidate;
    finite _linearSpeed && {finite _angularSpeed}
        && {_linearSpeed < (1/3.6)} && {_angularSpeed < 0.01}
};
// Capture/validate engine hit-point identity without changing damage or installing handlers.
private _vehicles=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")} && {!(_vehicle in _vehicles)}
        && {!isNull driver _vehicle} && {group driver _vehicle == _group}) then {
        _vehicles pushBack _vehicle;
    };
} forEach units _group;
// A group can leave its previous vehicle, board an aircraft or become a convoy between sparse
// scheduler steps. Release only the vehicles we previously owned; never touch another group's cap.
private _previous=_group getVariable ["CBE_DrivingAssist_Vehicles",[]];
{
    if !(_x in _vehicles) then {[_x,_group] call CBE_fnc_DrivingAssistRelease};
} forEach _previous;
_group setVariable ["CBE_DrivingAssist_Vehicles",_vehicles];
// Rebuild only the current roster's private measurement map; departed vehicles retain no history.
private _priorTracks=_brain getOrDefault ["geometryTracks",createHashMap];
private _geometryTracks=createHashMap;
{_geometryTracks set [netId _x,_priorTracks getOrDefault [netId _x,[]]]} forEach _vehicles;
_brain set ["geometryTracks",_geometryTracks];
{
    private _vehicle=_x;
    private _pendingCapRelease=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
    if (_pendingCapRelease isNotEqualTo []) then {
        [_vehicle,_group,true,_pendingCapRelease] call CBE_fnc_DrivingAssistRelease;
    } else {
    // Give the actual outgoing owner its original bounded publication window. Native
    // route following continues; no new cap/child may capture the inherited cap as baseline.
    private _capEdge=_vehicle getVariable ["CBE_DrivingCap_LocalEdge",[]];
    private _capLookup=_capEdge isEqualType [] && {count _capEdge == 3}
        && {(_capEdge select 1) isEqualType 0} && {finite (_capEdge select 1)}
        && {(_capEdge select 2) isEqualType 0} && {finite (_capEdge select 2)}
        && {serverTime >= (_capEdge select 1)} && {serverTime < (_capEdge select 2)};
    if (!_capLookup) then {
    [_vehicle] call CBE_fnc_DrivingPassRetireInherited;
    private _driver=driver _vehicle;
    private _movementOperator=effectiveCommander _vehicle;
    if (isNull _movementOperator) then {_movementOperator=_driver};
    private _nativeTaskFree={
        params ["_actor"];
        !isNull _actor && {!fleeing _actor} && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
            && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
            && {!(currentCommand _actor in [
            "GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED",
            "ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"
        ])}
    };
    private _routeIdentity=call _readRouteIdentity;
    private _nativeOnlyRoute=(_routeIdentity param [0,"",[""]]) == "NATIVE_MOVE";
    // Empty safety input performs metadata validation only, before successor work can retire.
    [_vehicle,_group,_brain,[],{false}] call CBE_fnc_DrivingAbortHandback;
    private _recoveryWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
    if (count _recoveryWork > 0 && {(_recoveryWork get "group") == _group}
        && {_recoveryWork getOrDefault ["releasePending",false]}) then {
        // Retire the old exact command before a restored vehicle can acquire fresh assistance.
        // Release rechecks native commands/route/seats and never replays a rear leg.
        [_vehicle,_group,"DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease;
        _recoveryWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
    };
    // A requested native return is observation-only. Do not misclassify its old rear
    // snapshots as a newer order or spend another recovery stage before acknowledgement.
    if ((_recoveryWork getOrDefault ["nativeReturn",[]]) isNotEqualTo []) then {continue};
    // Queue lifetime ends through existing exact native/cap cleanup, not an ordinary
    // forward retry. Do not leave a completed queue STOP parked forever after expiry.
    if ("queueBinding" in _recoveryWork && {(_recoveryWork getOrDefault ["group",grpNull]) == _group}) then {
        private _queueBinding=_recoveryWork get "queueBinding";
        private _queueConsent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        private _queueEnded=!(_queueBinding isEqualType []) || {count _queueBinding != 4}
            || {serverTime >= (_queueBinding param [1,-1])}
            || {(_queueConsent getOrDefault ["token",""]) != (_queueBinding param [0,""])}
            || {[_queueBinding param [0,""]] call CBE_fnc_DrivingQueueTokenClosed};
        if (_queueEnded) then {[_vehicle,_group] call CBE_fnc_DrivingAssistRelease};
        if (_queueEnded) then {_recoveryWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]};
    };
    // Ended queue paths use their exact cleanup receipt before ordinary assistance
    // can interpret the resulting STOP or route. A completed receipt permits handback;
    // cancellation never invents one. Defer fresh acquisition to a later callback.
    private _queuePath=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
    if ((_queuePath getOrDefault ["controller",[]]) isEqualTo ["QUEUE",-1]
        && {(_queuePath getOrDefault ["group",grpNull]) == _group}) then {
        private _binding=_queuePath getOrDefault ["queueCrossingBinding",[]];
        private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        if (!(_binding isEqualType []) || {count _binding != 4} || {serverTime >= (_binding param [1,-1])}
            || {(_consent getOrDefault ["crossingBinding",[]]) isNotEqualTo _binding}
            || {[_binding param [0,""]] call CBE_fnc_DrivingQueueTokenClosed}) then {
            [_vehicle,_group] call CBE_fnc_DrivingAssistRelease;
        };
    };
    if ((_queuePath getOrDefault ["controller",[]]) isEqualTo ["QUEUE",-1]
        && {(_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap]) isNotEqualTo _queuePath}) then {continue};
    // Destination recovery cannot adopt or retire another native command mode.
    if (count _recoveryWork > 0 && {!((_recoveryWork getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"])}) then {continue};
    // This destination executor never issues native BACK. It belongs to a different
    // command authority even when crew destinations still match our old journal.
    private _destinationControlFree={
        private _modeWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        private _info=vehicleMoveInfo _vehicle;
        if ((_modeWork getOrDefault ["commandMode","DESTINATION"]) == "SIMPLE_BACK") exitWith {
            private _queueStopped="queueBinding" in _modeWork && {_modeWork getOrDefault ["queueStopAcknowledged",false]};
            (_modeWork getOrDefault ["group",grpNull]) == _group
                && {(_modeWork getOrDefault ["kind",""]) == "REVERSE"}
                && {_driver != _movementOperator}
                && {(_info param [1,""]) == ((_modeWork getOrDefault ["simpleBefore",[]]) param [1,"MISSING"])}
                && {toUpperANSI (_info param [0,""]) == "BACK" && {!_queueStopped}
                    || {_modeWork getOrDefault ["simpleStopIssued",false] && {toUpperANSI (_info param [0,""]) == "STOP"}}
                    || {!(_modeWork getOrDefault ["simpleAcknowledged",false]) && {!_queueStopped}
                        && {_info isEqualTo (_modeWork getOrDefault ["simpleBefore",[]])}}}
        };
        toUpperANSI (_info param [0,"",[""]]) != "BACK"
    };
    private _recoveryCommandState="OWNED";
    if (count _recoveryWork > 0 && {(_recoveryWork getOrDefault ["commandMode","DESTINATION"]) == "DESTINATION"}) then {
        isNil {
            _recoveryCommandState=[_vehicle,_recoveryWork] call CBE_fnc_DrivingRecoveryCommandState;
            if (_recoveryCommandState == "OWNED" && {"request" in _recoveryWork}
                && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _recoveryWork}
                && {(_recoveryWork get "group") == _group} && {(_recoveryWork get "route") isEqualTo _routeIdentity}
                && {abs ((getForcedSpeed _vehicle)-(_recoveryWork get "cap")) <= 0.1}) then {
                _recoveryWork set ["driverCommand",+(expectedDestination _driver)];
                _recoveryWork set ["command",+(expectedDestination _movementOperator)];
                _recoveryWork deleteAt "request";
                _recoveryWork deleteAt "bypassReturn";
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_recoveryWork,true];
            };
        };
    };
    // An unchanged expired rear request is uncertain, not rejected. Preserve its safety
    // journal through the existing bounded release observer; never create another rear leg.
    if (_recoveryCommandState == "EXPIRED" && {(_recoveryWork getOrDefault ["kind",""]) == "REVERSE"}) then {
        [_vehicle,_group,"NATIVE_ACK_UNRESOLVED"] call CBE_fnc_DrivingRecoveryRelease;
        continue;
    };
    private _recoveryRequestPending=_recoveryCommandState == "PENDING";
    private _recoveryChildCap=(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) param [0,-1,[0]];
    private _recoveryOwned=count _recoveryWork > 0 && {_recoveryCommandState in ["OWNED","PENDING","BYPASS","CORRIDOR"]} && {call _destinationControlFree}
        && {(_recoveryWork get "group") == _group}
        && {(_recoveryWork get "route") isEqualTo _routeIdentity}
        && {(_recoveryWork get "driver") == _driver} && {(_recoveryWork get "operator") == _movementOperator}
        && {if (_recoveryCommandState in ["BYPASS","CORRIDOR"]) then {
            finite _recoveryChildCap && {_recoveryChildCap >= 0}
                && {abs ((getForcedSpeed _vehicle)-_recoveryChildCap) <= 0.1}
        } else {
            _recoveryCommandState in ["OWNED","PENDING"]
                && {abs ((getForcedSpeed _vehicle)-(_recoveryWork get "cap")) <= 0.1}
                && {(expectedDestination _driver) isEqualTo (_recoveryWork get "driverCommand")}
                && {(expectedDestination _movementOperator) isEqualTo (_recoveryWork get "command")}
                && {currentCommand _movementOperator != "STOP"
                    || {_recoveryRequestPending && {"bypassReturn" in _recoveryWork}}}
                && {[_driver,_movementOperator] findIf {
                    !(toUpperANSI currentCommand _x in ["","MOVE","WAIT"])
                        && {!(_recoveryRequestPending && {"bypassReturn" in _recoveryWork} && {currentCommand _x == "STOP"})}
                } < 0}
        }};
    if (count _recoveryWork > 0 && {(_recoveryWork get "group") == _group} && {!_recoveryOwned}) then {
        if ((_recoveryWork get "route") isEqualTo _routeIdentity) then {
            _group setVariable ["CBE_DrivingRecovery_Yield",_routeIdentity,true];
        };
        [_vehicle,_group,"ORDER_OR_SEATS_CHANGED",false] call CBE_fnc_DrivingRecoveryRelease;
        _recoveryWork=createHashMap;
    };
    private _capReleaseWork=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
    private _release=(_group getVariable ["CBE_DrivingRecovery_Yield",[]]) isEqualTo _routeIdentity
        || {_recoveryWork getOrDefault ["releaseUnresolved",false]}
        || {_capReleaseWork isNotEqualTo []};

    // Driving must make the same ownership decision as every other delayed controller. A group
    // member becoming player-controlled or specialist-owned is enough to retire the sparse speed
    // cap before it can issue a recovery move; the individual driver checks below retain the
    // vehicle-specific local/remote-control safety boundary.
    private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;
    if (!_enabled || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)} || {!(call _destinationControlFree)} || {!local _vehicle} || {!alive _vehicle} || {!canMove _vehicle}
        || {!([_driver] call CBE_fnc_CortexCombatEffective)} || {isPlayer _driver}
        || {!isNull (_driver getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_driver] call CBE_fnc_CortexExternalOwner != ""}
        || {_yieldToOwner}
        || {!([_driver] call _nativeTaskFree)}
        || {!([_movementOperator] call _nativeTaskFree)}
        || {getForcedSpeed _vehicle == 0 && {
            private _heldState=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
            !((_recoveryOwned && {(_recoveryWork get "cap") == 0})
                || {_recoveryOwned && {_recoveryCommandState in ["BYPASS","CORRIDOR"]} && {_recoveryChildCap == 0}}
                || {(_heldState param [0,-1]) == 0 && {(_heldState param [3,grpNull]) == _group}
                && {!isNull ((_vehicle getVariable ["CBE_DrivingAssist_Traffic",[]]) param [1,objNull])}})
        }}
        || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        || {behaviour leader _group == "CARELESS"}
        || {_routeIdentity isEqualTo []}
        || {_nativeOnlyRoute && {(_routeIdentity param [2,objNull,[objNull]]) != _vehicle}}) then {_release=true};
    if (_release) then {
        if (_capReleaseWork isEqualTo []) then {[_vehicle,_group] call CBE_fnc_DrivingAssistRelease} else {
            [_vehicle,_group,true,_capReleaseWork] call CBE_fnc_DrivingAssistRelease;
        };
    } else {
        // Terrain sampling is deliberately sparse but may still overlap a newer Zeus or specialist
        // order. Preserve that order at the actual cap/recovery command boundary.
        private _mayIssueDriving = {
            local _group && {local _vehicle} && {call _destinationControlFree}
                && {[_group] call CBE_fnc_DrivingMovementAvailable}
                && {driver _vehicle isEqualTo _driver}
                && {(effectiveCommander _vehicle) in [_movementOperator,objNull]}
                && {vehicle _movementOperator isEqualTo _vehicle}
                && {local _driver} && {group _driver == _group}
                && {!isPlayer _driver} && {isNull remoteControlled _driver}
                && {!([_group] call CBE_fnc_CortexExternalTakeover)}
                && {alive _vehicle} && {canMove _vehicle}
                && {[_driver] call CBE_fnc_CortexCombatEffective}
                && {[_movementOperator] call CBE_fnc_CortexCombatEffective}
                && {local _movementOperator} && {group _movementOperator == _group}
                && {!isPlayer _movementOperator} && {isNull remoteControlled _movementOperator}
                && {_driver checkAIFeature "MOVE"} && {_driver checkAIFeature "PATH"}
                && {_movementOperator checkAIFeature "MOVE"} && {_movementOperator checkAIFeature "PATH"}
                && {[_driver] call _nativeTaskFree} && {[_movementOperator] call _nativeTaskFree}
                && {_routeIdentity isNotEqualTo []}
                && {(call _readRouteIdentity) isEqualTo _routeIdentity}
        };
        // A shared group waypoint authorizes the leader vehicle's route, not independent
        // follower manoeuvres. Keep this separate from the safety cap: followers can still
        // receive a terrain cap while their formation movement stays native.
        private _nativeWaiting = {
            private _index=currentWaypoint _group;
            if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
            private _waypoint=[_group,_index];
            if (!([_vehicle] call _stationary) || {!unitReady _vehicle}
                || {_vehicle distance2D (waypointPosition _waypoint) > ((waypointCompletionRadius _waypoint max 0)+50)}) exitWith {false};
            private _condition=toLowerANSI (((waypointStatements _waypoint) param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
            waypointType _waypoint == "HOLD"
                || {(synchronizedTriggers _waypoint) findIf {!isNull _x && {!triggerActivated _x}} >= 0}
                || {(waypointTimeout _waypoint param [2,0]) > 0}
                || {_condition != "true"}
        };
        // A distant script/timer/synchronization gate is still authored intent. Recovery
        // may refresh only a plain MOVE, never bypass a gate merely because it is far away.
        private _recoveryOrderFree = {
            ([_group] call CBE_fnc_DrivingRouteGoal) isNotEqualTo []
        };
        private _crewBoardingHold=false;private _queueHold=false;
        private _mayRecoverRoute = {
            call _mayIssueDriving && {vehicle leader _group isEqualTo _vehicle} && {!(call _nativeWaiting)}
                && {call _recoveryOrderFree} && {!_crewBoardingHold} && {!_queueHold}
        };
        private _nativeRouteIntent={
            private _command=toUpperANSI currentCommand _movementOperator;
            if (_command == "STOP") exitWith {false};
            if (!(_command in ["MOVE","WAIT"])) exitWith {_command == ""};
            private _native=expectedDestination _movementOperator;
            private _routeGoal=[_group] call CBE_fnc_DrivingRouteGoal;
            if (_command == "MOVE" && {_routeGoal isNotEqualTo []}
                && {(_native param [0,[]]) vectorDistance _routeGoal <= 3}) exitWith {true};
            // The rear leg intentionally differs from the waypoint. Only an unchanged
            // current journal can authorize its own finite forward handback (including owned CBE),
            // not another MOVE or an unowned CBE.
            private _owned=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
            count _owned > 0 && {(_owned get "group") == _group}
                && {(_owned get "route") isEqualTo _routeIdentity}
                && {(_owned get "driver") == _driver} && {(_owned get "operator") == _movementOperator}
                && {(expectedDestination _driver) isEqualTo (_owned get "driverCommand")}
                && {_native isEqualTo (_owned get "command")}
        };
        private _queueNativeActive=false;private _queueCrossing=false;
        private _queueCrossAuthority={
            private _liveQueue=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
            call _mayIssueDriving && {_liveQueue getOrDefault ["crossingGranted",false]}
                && {(_liveQueue getOrDefault ["motionStage",""]) == "CROSSING"}
                && {((_liveQueue getOrDefault ["vehicles",[]]) param [0,objNull]) == _vehicle}
                && {[_liveQueue,true] call CBE_fnc_DrivingQueueReverseCurrent}
        };
        private _mayRecoverOrdinaryRoute={!_queueCrossing && {!_queueNativeActive} && {!_recoveryRequestPending} && {call _mayRecoverRoute} && {call _nativeRouteIntent}
            && {!(_recoveryCommandState in ["BYPASS","CORRIDOR"])}
            // A queue-bound native leg belongs to its finite queue phase, never the
            // ordinary REFRESH/FINAL route retry. Cleanup retains separate exact proof.
            && {!("queueBinding" in (_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]))}
            && {toUpperANSI currentCommand _driver in ["","MOVE","WAIT"]}};
        private _priorOwner=(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) param [3,grpNull];
        if (!isNull _priorOwner && {_priorOwner != _group}) then {
            // A new driver group adopts only after retiring the old group's exact cap lease.
            [_vehicle,_priorOwner] call CBE_fnc_DrivingAssistRelease;
        };
        if (time >= (_vehicle getVariable ["CBE_DrivingAssist_Next",-1])) then {
            // A new Zeus, mission or specialist cap may not advertise an ownership marker. The
            // last cap we applied is therefore the narrowest reliable lease check: once another
            // value replaces it, release without restoring the stale pre-CBE value.
            private _entryRestore=+(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]);
            private _previous=+_entryRestore;
            private _entryForcedSpeed=getForcedSpeed _vehicle;
            private _entryAssistState=+(_vehicle getVariable ["CBE_DrivingAssist_State",[]]);
            private _state=+_entryAssistState;
            if (_state isEqualTo [] && {_recoveryOwned}
                && {abs ((getForcedSpeed _vehicle)-(_recoveryWork get "cap")) <= 0.1}) then {
                private _kind=_recoveryWork get "kind";
                private _stage=switch (_kind) do {case "REFRESH":{1};case "FINAL":{3};case "EXHAUSTED":{4};default {2}};
                private _deadline=_recoveryWork get "deadline";
                if (_stage == 1 && {serverTime >= (_recoveryWork get "hardDeadline")-60}) then {_stage=2};
                _state=[_recoveryWork get "cap",0,time,_group,+(_recoveryWork get "origin"),
                    time-(serverTime-(_recoveryWork get "started")),_stage,time+(_deadline-serverTime),
                    "ADOPTED_RECOVERY",_routeIdentity,_kind == "REVERSE"];
                _previous=+(_recoveryWork get "baseline");
            };
            private _ownedCap=_state param [0,-1];
            if (_previous isNotEqualTo [] && {_ownedCap >= 0} && {abs ((getForcedSpeed _vehicle)-_ownedCap) > 0.1}) then {
                [_vehicle,_group] call CBE_fnc_DrivingAssistRelease;
            } else {
            // Recovery belongs to this authored route, not merely to this vehicle.
            // Same-index waypoint replacement must not inherit an old reverse stage
            // or exhausted timer, nor receive an immediate recovery command.
            _routeIdentity=call _readRouteIdentity;
            if (_state isNotEqualTo [] && {(_state param [9,[]]) isNotEqualTo _routeIdentity}) then {
                _state set [4,getPosATL _vehicle];
                _state set [5,time];
                _state set [6,0];
                _state set [7,-1];
                _state set [8,"NEW_ROUTE"];_state set [10,false];
            };
            // A follower must not retain the cautious-reverse stage of a former leader.
            // Start a fresh observation interval if it later becomes the leader again.
            if (_state isNotEqualTo [] && {vehicle leader _group isNotEqualTo _vehicle}) then {
                // Retire the former leader's exact rear command before returning to formation.
                // Clearing only the stage would leave that native destination running.
                if ((_state param [6,0]) != 4) then {[_vehicle,_group,"NATIVE_FOLLOWER"] call CBE_fnc_DrivingRecoveryRelease};
                _state set [4,getPosATL _vehicle];
                _state set [5,time];
                if ((_state param [6,0]) != 4) then {_state set [6,0];_state set [7,-1]};
                _state set [8,"NATIVE_FOLLOWER"];_state set [10,false];
            };
            if (_state isNotEqualTo [] && {(_state param [6,0]) != 4} && {call _nativeWaiting}) then {
                _state set [4,getPosATL _vehicle];_state set [5,time];
                _state set [6,0];_state set [7,-1];_state set [8,"INTENTIONAL_WAIT"];_state set [10,false];
            };
            private _origin=getPosASL _vehicle;
            private _direction=vectorDir _vehicle;
            _direction set [2,0];
            if (vectorMagnitude _direction < 0.1) then {_direction=[sin (getDir _vehicle),cos (getDir _vehicle),0]};
            _direction=vectorNormalized _direction;
            private _maximumGrade=0;
            private _last=_origin;
            {
                private _sample=_origin vectorAdd (_direction vectorMultiply _x);
                _sample set [2,getTerrainHeightASL _sample];
                private _horizontal=(_sample distance2D _last) max 1;
                _maximumGrade=_maximumGrade max (abs ((_sample select 2)-(_last select 2))/_horizontal);
                _last=_sample;
            } forEach [20,45,70];
            private _cap=(missionNamespace getVariable ["CBE_AIPass_DrivingAssist_MaxSpeed",70]) max 15 min 120;
            // The shared read-only road walk anticipates bends/junctions without choosing a route.
            // It runs at this vehicle's existing sparse cadence; mission and traffic caps still win.
            private _roadObservation=[_vehicle,_cap] call CBE_fnc_DrivingRoadCap;
            _cap=_cap min (_roadObservation select 0);
            // On an actual bridge road, the road observer already evaluates ASL deck endpoints.
            // Terrain beneath the deck is not its grade. Keep terrain policy elsewhere and
            // retain the road observer's conservative cap when bridge endpoints are unavailable.
            private _surfaceRoad=roadAt _vehicle;
            private _onBridge=isOnRoad _vehicle && {!isNull _surfaceRoad}
                && {(getRoadInfo _surfaceRoad) param [8,false,[true]]};
            if (_onBridge) then {_maximumGrade=_roadObservation select 2};
            if (_maximumGrade > 0.2) then {_cap=_cap min 18} else {if (_maximumGrade > 0.12) then {_cap=_cap min 28}};
            // The short rear leg must not inherit the normal road-speed cap. Retain
            // this cautious cap through reverse observation and the final retry handoff.
            if ((_state param [6,0]) in [1,2]) then {_cap=_cap min 10};
            if (_previous isEqualTo []) then {_previous=[_entryForcedSpeed]};
            private _saved=_previous param [0,-1];
            // Arma forceSpeed/getForcedSpeed values are metres per second. Keep the policy value
            // readable in km/h, but keep the actual lease in engine units so another controller's
            // cap is detected and the pre-CBE value can be restored exactly.
            private _capMps=_cap/3.6;
            if (_saved > 0) then {_capMps=_capMps min _saved};
            private _recordRecovery={
                params ["_kind",["_rearHitpointReceipt",[],[[]]],["_commandMode","DESTINATION",[""]],["_simpleBefore",[],[[]]],["_nativeRequest",[],[[]]],["_rearEnvelope",[8,6],[[]]]];
                private _old=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                private _sameEpisode=count _old > 0 && {(_old get "group") == _group}
                    && {(_old get "route") isEqualTo _routeIdentity};
                private _origin=getPosATL _vehicle;
                private _progressAnchor=if (_sameEpisode) then {_old getOrDefault ["progressAnchor",[]]} else {_origin};
                _progressAnchor=if (_progressAnchor isEqualType [] && {count _progressAnchor == 3}
                    && {_progressAnchor findIf {!(_x isEqualType 0) || {!finite _x}} < 0}) then {+_progressAnchor} else {[]};
                private _hard=if (_sameEpisode) then {
                    _old get "hardDeadline"
                } else {serverTime+96};
                // Preserve a queue episode's original binding if this journal is rewritten.
                // This only narrows lifetime; it cannot authenticate or start queue movement.
                private _queueBound=_sameEpisode && {"queueBinding" in _old};
                private _queueBinding=if (_queueBound) then {_old get "queueBinding"} else {[]};
                private _queueBindingValid=_queueBinding isEqualType [] && {count _queueBinding == 4}
                    && {(_queueBinding select 0) isEqualType ""} && {(_queueBinding select 0) != ""}
                    && {_queueBinding select [1,3] findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
                if (_queueBound) then {_hard=if (_queueBindingValid) then {_hard min (_queueBinding select 1)} else {serverTime}};
                private _deadline=switch (_kind) do {case "REFRESH":{_hard-66};case "FINAL":{_hard};case "EXHAUSTED":{_hard};default {_hard-60}};
                if (_queueBound) then {_deadline=_hard};
                if (!_queueBound && {_kind == "REVERSE"} && {(_rearEnvelope param [1,0]) > 6}) then {
                    // Reallocate inside the same parent: retain at least40 seconds for handback.
                    private _reverseRate=if (_saved > 0) then {_saved min (10/3.6)} else {10/3.6};
                    private _reverseSeconds=((_rearEnvelope select 1)/_reverseRate+4) max 6 min 16;
                    _deadline=(_hard-40) min (serverTime+_reverseSeconds);
                };
                private _work=createHashMapFromArray [["group",_group],["route",_routeIdentity],["driver",_driver],["operator",_movementOperator],
                    ["driverCommand",+(expectedDestination _driver)],["command",+(expectedDestination _movementOperator)],
                    ["kind",_kind],["commandMode",_commandMode],["started",serverTime],["deadline",_deadline],["hardDeadline",_hard],
                    ["origin",_origin],["progressAnchor",_progressAnchor],["baseline",+_previous],["cap",_capMps]];
                if (_queueBound) then {_work set ["queueBinding",_queueBinding]};
                // Stage transitions cannot replenish a bypass spent under this same parent.
                if (_sameEpisode && {"bypassSpent" in _old}) then {
                    _work set ["bypassSpent",!((_old get "bypassSpent") isEqualTo false)];
                };
                if (_commandMode == "DESTINATION" && {count _nativeRequest == 3}
                    && {_kind in ["REFRESH","FINAL","REVERSE"]}) then {_work set ["request",_nativeRequest]};
                if (_commandMode == "SIMPLE_BACK") then {
                    _work set ["simpleBefore",+_simpleBefore];
                    _work set ["simpleAcknowledged",toUpperANSI ((vehicleMoveInfo _vehicle) param [0,""]) == "BACK"];
                };
                if (_kind == "REVERSE") then {
                    _work set ["rearEnvelope",+_rearEnvelope];
                    _work set ["rearOriginASL",getPosASL _vehicle];
                    _work set ["rearDirection",vectorDir _vehicle];
                    _work set ["rearDamage",damage _vehicle];
                    _work set ["rearHitpoints",_rearHitpointReceipt apply {+_x}];
                    _work set ["rearMinimumDamage",_work get "rearDamage"];
                    _work set ["rearMinimumHitpoints",_rearHitpointReceipt apply {+_x}];
                };
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
                time+(_deadline-serverTime)
            };
            private _reverseIssued=_state param [10,(_state param [8,""]) == "CAUTIOUS_REVERSE"];
            private _reverseLeg=(_state param [6,0]) == 2 && {_reverseIssued} && {!_recoveryRequestPending}
                && {time < (_state param [7,-1])};
            // An issued doMove may act before expectedDestination acknowledges it.
            // Keep the rear safety envelope while ownership acknowledgement is pending;
            // this does not grant forward retry, completion or a renewed deadline.
            private _pendingRear=_recoveryRequestPending && {_recoveryOwned} && {_reverseIssued}
                && {(_recoveryWork getOrDefault ["kind",""]) == "REVERSE"};
            private _rearSafetyRequired=_reverseLeg || {_pendingRear};
            private _rearPathRejected=false;
            private _rearClearDistance=8;
            if (_rearSafetyRequired) then {
                private _rearWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                private _rearEnvelope=_rearWork getOrDefault ["rearEnvelope",[8,6]];
                private _rearOrigin=_rearWork getOrDefault ["rearOriginASL",[]];
                private _rearDirection=_rearWork getOrDefault ["rearDirection",[]];
                private _rearDamage=_rearWork getOrDefault ["rearDamage",-1];
                private _rearHitpoints=[objNull,_rearWork getOrDefault ["rearHitpoints",[]]] call CBE_fnc_DrivingDamageReceipt;
                private _liveHitpoints=[_vehicle] call CBE_fnc_DrivingDamageReceipt;
                private _liveDamage=damage _vehicle;
                private _minimumDamage=_rearWork getOrDefault ["rearMinimumDamage",-1];
                private _minimumHitpoints=[objNull,_rearWork getOrDefault ["rearMinimumHitpoints",[]]] call CBE_fnc_DrivingDamageReceipt;
                private _extendedEnvelope=_rearEnvelope isEqualType [] && {count _rearEnvelope == 2}
                    && {_rearEnvelope findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                    && {(_rearEnvelope select 1) > 6} && {(_rearEnvelope select 1) <= 24}
                    && {(_rearEnvelope select 1) == floor (_rearEnvelope select 1)}
                    && {(_rearEnvelope select 0) == (_rearEnvelope select 1)+2}
                    && {!("queueBinding" in _rearWork) || {
                        private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
                        private _index=(_consent getOrDefault ["vehicles",[]]) find _vehicle;
                        _index >= 1 && {_rearEnvelope isEqualTo ((_consent getOrDefault ["rearRequirements",[]]) param [_index,[]])}
                            && {(_rearWork get "queueBinding") select [0,2] isEqualTo [
                                _consent getOrDefault ["token",""],_consent getOrDefault ["expires",-1]]}
                            && {serverTime < (_consent getOrDefault ["expires",-1])} && {_recoveryOwned}
                    }};
                private _proofValid=(_rearEnvelope in [[8,6],[3.5,2]] || {_extendedEnvelope}) && {_rearDamage isEqualType 0} && {finite _rearDamage} && {_rearDamage >= 0}
                    && {count _rearHitpoints == 3} && {count _liveHitpoints == 3} && {count _minimumHitpoints == 3}
                    && {_minimumDamage isEqualType 0} && {finite _minimumDamage}
                    && {_minimumDamage >= 0} && {_minimumDamage <= _rearDamage}
                    && {_liveDamage isEqualType 0} && {finite _liveDamage} && {_liveDamage >= 0} && {_liveDamage <= 1}
                    && {(_rearHitpoints select [0,2]) isEqualTo (_liveHitpoints select [0,2])}
                    && {(_rearHitpoints select [0,2]) isEqualTo (_minimumHitpoints select [0,2])}
                    && {count _rearOrigin == 3} && {count _rearDirection == 3}
                    && {_rearOrigin findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                    && {_rearDirection findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                    && {abs ((vectorMagnitude _rearDirection)-1) <= 0.02};
                if (_proofValid) then {
                    private _componentDamage=false;
                    private _historyInvalid=false;
                    private _nextMinimumValues=+(_minimumHitpoints select 2);
                    for "_hitIndex" from 0 to ((count (_rearHitpoints select 2))-1) do {
                        private _minimum=(_minimumHitpoints select 2) select _hitIndex;
                        private _observed=(_liveHitpoints select 2) select _hitIndex;
                        if (_minimum > ((_rearHitpoints select 2) select _hitIndex)) exitWith {_historyInvalid=true};
                        if (_observed > _minimum+0.01) exitWith {_componentDamage=true};
                        _nextMinimumValues set [_hitIndex,_minimum min _observed];
                    };
                    private _delta=(getPosASL _vehicle) vectorDiff _rearOrigin;
                    private _along=_delta vectorDotProduct _rearDirection;
                    private _lateral=vectorMagnitude (_delta vectorDiff (_rearDirection vectorMultiply _along));
                    // Retain the remaining leg plus its original end buffer. Requiring
                    // the full initial distance again would creep the clearance envelope
                    // backwards and stop a valid short leg before its endpoint.
                    _rearClearDistance=(((_rearEnvelope select 0)+_along)
                        max ((_rearEnvelope select 0)-(_rearEnvelope select 1))) min (_rearEnvelope select 0);
                    _rearPathRejected=(vectorDir _vehicle) vectorDotProduct _rearDirection < cos 20
                        || {_along > 1} || {_along < -((_rearEnvelope select 0)+2)} || {_lateral > 2.5}
                        || {_liveDamage > _minimumDamage+0.01} || {_componentDamage} || {_historyInvalid};
                    if (!_rearPathRejected && {(_rearWork getOrDefault ["commandMode","DESTINATION"]) == "SIMPLE_BACK"}
                        && {_along <= -(_rearEnvelope select 1)}) then {
                        // Native BACK has no destination endpoint. End after observed room,
                        // without waiting for overshoot or claiming the authored route resumed.
                        _reverseLeg=false;_state set [7,time];_state set [8,"REAR_ROOM_OBSERVED"];
                    };
                    // Repairs lower observation minima; damage can never raise them. Publish only
                    // a real decrease on this exact live rear leg, without changing its lifetime.
                    private _nextMinimumDamage=_minimumDamage min _liveDamage;
                    private _acknowledgeBack=(_rearWork getOrDefault ["commandMode","DESTINATION"]) == "SIMPLE_BACK"
                        && {!(_rearWork getOrDefault ["simpleAcknowledged",false])}
                        && {toUpperANSI ((vehicleMoveInfo _vehicle) param [0,""]) == "BACK"};
                    if (!_rearPathRejected && {_acknowledgeBack || {_nextMinimumDamage < _minimumDamage}
                        || {_nextMinimumValues isNotEqualTo (_minimumHitpoints select 2)}}) then {
                        isNil {
                            if (call _mayIssueDriving
                                && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain}
                                && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
                                && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                                && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _rearWork}
                                && {(_rearWork getOrDefault ["kind",""]) == "REVERSE"}
                                && {(_rearWork getOrDefault ["route",[]]) isEqualTo _routeIdentity}
                                && {(_rearWork getOrDefault ["rearMinimumDamage",-1]) == _minimumDamage}
                                && {(_rearWork getOrDefault ["rearMinimumHitpoints",[]]) isEqualTo _minimumHitpoints}
                                && {(expectedDestination _driver) isEqualTo (_rearWork getOrDefault ["driverCommand",[]])}
                                && {(expectedDestination _movementOperator) isEqualTo (_rearWork getOrDefault ["command",[]])}
                                && {time < (_state param [7,-1])} && {serverTime < (_rearWork getOrDefault ["deadline",-1])}) then {
                                if (_acknowledgeBack) then {_rearWork set ["simpleAcknowledged",true]};
                                _rearWork set ["rearMinimumDamage",_nextMinimumDamage];
                                _rearWork set ["rearMinimumHitpoints",[+(_minimumHitpoints select 0),+(_minimumHitpoints select 1),_nextMinimumValues]];
                                _vehicle setVariable ["CBE_DrivingRecovery_Work",_rearWork,true];
                            };
                        };
                    };
                } else {_rearPathRejected=true};
                if (_rearPathRejected) then {
                    // A rear destination is not a reverse primitive. Retire a native turn or
                    // unsupported inherited leg through the existing exact route handback.
                    _reverseLeg=false;
                    _state set [7,time];
                    _state set [8,"REAR_PATH_DIVERGED"];
                };
            };
            private _reverseExpired=(_state param [6,0]) == 2 && {_reverseIssued} && {!_reverseLeg}
                && {!_pendingRear || {_rearPathRejected}};
            if (_reverseExpired && {!("queueBinding" in (_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]))}) then {
                // Native backing must stop at its original endpoint/deadline even when
                // combat or a disabled recovery feature currently forbids the forward retry.
                private _endingRear=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                if ((_endingRear getOrDefault ["commandMode","DESTINATION"]) == "SIMPLE_BACK") then {
                    isNil {
                        if (call _mayIssueDriving
                            && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain}
                            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                            && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
                            && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _endingRear}
                            && {(_endingRear get "group") == _group}
                            && {(_endingRear get "driver") == _driver} && {(_endingRear get "operator") == _movementOperator}
                            && {(expectedDestination _driver) isEqualTo (_endingRear get "driverCommand")}
                            && {(expectedDestination _movementOperator) isEqualTo (_endingRear get "command")}
                            && {abs ((getForcedSpeed _vehicle)-(_endingRear get "cap")) <= 0.1}) then {
                            private _stoppedRear=+_endingRear;
                            if (serverTime >= (_endingRear get "hardDeadline")) then {
                                _stoppedRear set ["releasePending",true];
                                _stoppedRear set ["releaseUnresolved",true];
                            } else {
                                if (toUpperANSI ((vehicleMoveInfo _vehicle) param [0,""]) != "STOP") then {
                                    _vehicle sendSimpleCommand "STOP";
                                    _stoppedRear set ["simpleStopIssued",true];
                                };
                                if (toUpperANSI ((vehicleMoveInfo _vehicle) param [0,""]) == "STOP") then {
                                    // Native mode acknowledgement is not physical stationarity.
                                    _stoppedRear set ["kind","REAR_STOP_ACKNOWLEDGED"];
                                    _stoppedRear set ["commandMode","DESTINATION"];
                                    _stoppedRear set ["driverCommand",+(expectedDestination _driver)];
                                    _stoppedRear set ["command",+(expectedDestination _movementOperator)];
                                    _reverseIssued=false;_state set [10,false];
                                };
                            };
                            _vehicle setVariable ["CBE_DrivingRecovery_Work",_stoppedRear,true];
                        };
                    };
                };
            };
            private _retryAllowed=!_reverseExpired || {
                [_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled
                    && {!(behaviour leader _group in ["COMBAT","STEALTH"])} && {getSuppression _driver <= 0.1}
                    && {call _mayRecoverOrdinaryRoute}
            };
            private _queueConsent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
            _queueNativeActive=(_queueConsent getOrDefault ["executionGranted",false])
                && {["ADMIT",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueReverseCommit};
            private _queueJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
            private _queueStarted="queueBinding" in _queueJournal;
            private _queueStop=_queueStarted && {_rearPathRejected || {_reverseExpired}
                || {_queueJournal getOrDefault ["simpleStopIssued",false]}
                || {!(_queueJournal getOrDefault ["simpleAcknowledged",false])
                    && {serverTime >= (_queueJournal getOrDefault ["ackUntil",-1])}}};
            if (_queueNativeActive) then {
                _reverseLeg=true;
                _capMps=if (_queueStop) then {0} else {_capMps min 2};
            };
            _queueCrossing=call _queueCrossAuthority;
            _queueHold=!_queueNativeActive && {!_queueCrossing} && {["OBSERVE",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueHold};
            _crewBoardingHold=!_queueCrossing && {!_queueHold} && {!_queueNativeActive} && {[_group,_vehicle,_brain,{call _mayIssueDriving
                && {call _recoveryOrderFree} && {call _nativeRouteIntent}}] call CBE_fnc_DrivingCrewBoarding};
            private _traffic=if (!_reverseLeg) then {
                [_vehicle,_capMps,objNull,if (_queueCrossing) then {_queueConsent} else {createHashMap}] call CBE_fnc_DrivingFollowingCap
            } else {[_capMps,objNull,-1,time,0]};
            // Preserve this observation before gate/body/pedestrian caps replace the row.
            // It affects callback cadence only, not speed or recovery admission.
            private _trafficWatch=_traffic param [5,false,[true]];
            if (_crewBoardingHold || {_queueHold}) then {_traffic=[0,_vehicle,-1,time,0]};
            if (_rearPathRejected) then {_traffic=[0,_vehicle,-1,time,0]};
            if (_reverseExpired && {((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap])
                getOrDefault ["commandMode","DESTINATION"]) == "SIMPLE_BACK"}) then {
                // A native STOP request is not acknowledgement. Keep the sole speed cap
                // at zero while the exact expired BACK remains pending; never retry forward.
                _traffic=[0,_vehicle,-1,time,0];
            };
            private _turn=[_vehicle,_geometryTracks getOrDefault [netId _vehicle,[]],[_routeIdentity,_brain getOrDefault ["ownerEpoch",-1]]] call CBE_fnc_DrivingTurnTrack;
            _geometryTracks set [netId _vehicle,_turn select 1];
            private _nativeHint=[_vehicle,_group,["ORDINARY",_routeIdentity,_brain getOrDefault ["ownerEpoch",-1]]] call CBE_fnc_DrivingNativePathWatch;
            private _curveHint=if (_nativeHint isEqualTo []) then {[_turn select 0]} else {_nativeHint};
            private _cornerJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
            private _cornerStarted=_cornerJournal getOrDefault ["started",-1];
            private _cornerProbe=!_reverseLeg && {!_crewBoardingHold} && {!_queueHold} && {!_queueNativeActive} && {!_queueCrossing}
                && {_recoveryOwned} && {(_state param [6,0]) == 1}
                && {(_cornerJournal getOrDefault ["kind",""]) == "REFRESH"}
                && {(_cornerJournal getOrDefault ["bypassSpent",false]) isEqualTo false}
                && {_cornerStarted isEqualType 0} && {finite _cornerStarted}
                && {serverTime >= _cornerStarted+3} && {([_vehicle] call _stationary)}
                && {behaviour leader _group in ["SAFE","AWARE"]} && {getSuppression _driver <= 0.1}
                && {isNil {_vehicle getVariable "CBE_DrivingPass_Work"}}
                && {isNil {_vehicle getVariable "CBE_DrivingCorridor_Work"}}
                && {isNil {_vehicle getVariable "CBE_DrivingBypass_Work"}}
                && {call _mayRecoverOrdinaryRoute};
            private _geometry=if (!_reverseLeg) then {[_vehicle,_capMps,false,_curveHint,_cornerProbe] call CBE_fnc_DrivingGeometryCap} else {[[],[]]};
            private _gateObservation=_geometry select 0;
            private _obstacleObservation=_geometry select 1;
            if (_gateObservation isNotEqualTo [] && {(_gateObservation select 0) < (_traffic select 0)}) then {_traffic=_gateObservation};
            private _withoutObstacle=+_traffic;
            private _obstacleLimited=_obstacleObservation isNotEqualTo []
                && {(_obstacleObservation select 0) < (_traffic select 0)};
            if (_obstacleLimited) then {
                _traffic=_obstacleObservation select [0,5];
                if (isNull (_traffic select 1)) then {_traffic set [1,_vehicle]};
            };
            _vehicle setVariable ["CBE_DrivingAssist_Obstacle",_obstacleObservation];
            // Share the convoy observer without adding a second speed writer. Its zero cap
            // uses the existing traffic lease and faster sampling, and cannot trigger recovery.
            // Check the intended rear direction even while stopped. At the finite rear-leg
            // deadline observe the forward retry, so a rear-only obstacle cannot trap handback.
            private _travelIntent=if (_rearSafetyRequired || {_queueNativeActive}) then {-1} else {[0,1] select ((_state param [6,0]) == 2)};
            private _pedestrianCap=[_vehicle,_capMps*3.6,_group,true,_travelIntent] call CBE_fnc_CortexInfantrySpeed;
            if (_rearSafetyRequired && {!_rearPathRejected}) then {
                private _rearObservation=[_vehicle,_rearClearDistance] call CBE_fnc_DrivingRearClear;
                if !(_rearObservation select 0) then {_traffic=[0,_vehicle,-1,time,0]};
            };
            if (_pedestrianCap/3.6 < (_traffic select 0)) then {
                _traffic=[_pedestrianCap/3.6,_vehicle,-1,time,0];
            };
            // An expired owned rear command cannot keep moving just because combat or a
            // recovery feature change currently prevents the forward retry. Hold its exact
            // speed lease until normal retry admission or a newer order/controller takes over.
            if (_reverseExpired && {!_retryAllowed}) then {_traffic=[0,_vehicle,-1,time,0]};
            // Corridor execution is part of this same owner callback, never a second controller.
            // Do not take over an issued/expired rear leg. Existing traffic and pedestrian caps win.
            private _passingHeadway=if (_crewBoardingHold || {_queueHold} || {_queueNativeActive} || {_queueCrossing}) then {-1} else {
                ["OBSERVE",_group,_vehicle,_brain,_traffic,_capMps] call CBE_fnc_DrivingPassAdmission
            };
            if (_passingHeadway isEqualType 0 && {finite _passingHeadway} && {_passingHeadway >= 0}) then {
                _capMps=_capMps min _passingHeadway;
            };
            private _hadPass=!isNil {_vehicle getVariable "CBE_DrivingPass_Work"};
            private _pass=if (_queueNativeActive || {_queueCrossing}) then {[false,1e6,""]} else {[_group,_vehicle,_brain,_mayIssueDriving] call CBE_fnc_DrivingPassStep};
            private _passActive=_pass select 0;
            private _hadBypass=!isNil {_vehicle getVariable "CBE_DrivingBypass_Work"};
            private _hadCorridor=!isNil {_vehicle getVariable "CBE_DrivingCorridor_Work"};
            private _corridor=[false,1e6,""];
            if (!_queueCrossing && {!_passActive} && {!_hadPass} && {!_reverseLeg} && {!_reverseExpired} && {!_hadBypass} && {call _mayRecoverRoute}) then {
                _corridor=[_group,_vehicle,_brain] call CBE_fnc_DrivingCorridorStep;
            } else {
                if (_hadCorridor) then {
                    [_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call CBE_fnc_DrivingCorridorRelease;
                };
            };
            private _corridorActive=_corridor select 0;
            private _bypass=[false,1e6,"",false];
            if (_queueCrossing) then {
                private _queueVehicles=_queueConsent get "vehicles";private _yield=_queueVehicles select 1;
                private _solid=[0,_yield,_vehicle distance _yield,time,0,"STATIC",0,0,[getPosWorld _yield,vectorDir _yield,vectorUp _yield]];
                _bypass=[_group,_vehicle,_brain,_solid,_queueCrossAuthority,"QUEUE"] call CBE_fnc_DrivingBypassStep;
            } else {
            if (!_passActive && {!_hadPass} && {!_corridorActive} && {!_hadCorridor} && {!_reverseLeg} && {!_reverseExpired}
                && {call _mayRecoverRoute}) then {
                _bypass=[_group,_vehicle,_brain,_obstacleObservation,_mayRecoverRoute] call CBE_fnc_DrivingBypassStep;
            } else {
                if (_hadBypass) then {[_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call CBE_fnc_DrivingBypassRelease};
            };
            };
            private _bypassActive=_bypass select 0;
            // Only a freshly validated active leg can yield this exact source object's forward
            // constraint. Other gates, occupied hulls and pedestrians keep their current caps.
            private _bypassWork=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
            if (_bypassActive && {_bypass select 3} && {_obstacleObservation isNotEqualTo []}
                && {(_obstacleObservation select 1) isEqualTo (_bypassWork getOrDefault ["obstacle",objNull])}
                && {(_obstacleObservation select 8) isEqualTo (_bypassWork getOrDefault ["transform",[]])}) then {
                _traffic=+_withoutObstacle;
                if (_pedestrianCap/3.6 < (_traffic select 0)) then {_traffic=[_pedestrianCap/3.6,_vehicle,-1,time,0]};
                _obstacleLimited=false;
            };
            _capMps=_capMps min (_pass select 1);
            if (_passActive && {(_pass select 1) <= 0}) then {_traffic=[0,_vehicle,-1,time,0]};
            _capMps=_capMps min (_bypass select 1);
            _capMps=_capMps min (_corridor select 1);
            // A closer pedestrian/rear constraint can supersede the solid-obstacle sample.
            _obstacleLimited=_obstacleLimited && {abs ((_traffic select 0)-(_obstacleObservation select 0)) <= 0.001};
            private _trafficLimited=!isNull (_traffic select 1);
            // A close static body can stop us before there is room for a bypass proposal.
            // It is not a traffic queue: permit the existing finite rear recovery only after
            // continuous fresh observation, with independent vehicle/gate/pedestrian caps clear.
            private _approachDiagnosis=_bypass param [4,createHashMap,[createHashMap]];
            private _approachBackoff=(_approachDiagnosis getOrDefault ["status",""]) == "BACKOFF";
            // A stricter mission cap can already be below the obstacle braking cap.
            // Missing turning room is still real, but it cannot override another traffic
            // body or pedestrian constraint merely because the vehicle is stationary.
            private _approachUncontested=_approachBackoff && {isNull (_withoutObstacle select 1)}
                && {(_pedestrianCap/3.6) >= _capMps-0.001};
            private _solidCandidate=(_obstacleLimited || {_approachUncontested}) && {count _obstacleObservation == 9}
                && {(_obstacleObservation select 5) == "STATIC"} && {(_obstacleObservation select 2) <= 8 || {_approachBackoff}}
                && {!isNull (_obstacleObservation select 1)} && {([_vehicle] call _stationary)}
                && {(_withoutObstacle select 0) > 0} && {_pedestrianCap > 0}
                && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass};
            private _solidSeen=_vehicle getVariable ["CBE_DrivingSolidSeen",[]];
            private _solidObserver=[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_routeIdentity];
            private _solidReady=false;
            if (_solidCandidate) then {
                private _contact=[_obstacleObservation select 1,_obstacleObservation select 8,_solidObserver];
                private _continuous=count _solidSeen == 3 && {(_solidSeen select 0) isEqualTo _contact}
                    && {serverTime >= (_solidSeen select 2)} && {serverTime-(_solidSeen select 2) <= 6};
                private _since=if (_continuous) then {_solidSeen select 1} else {serverTime};
                _solidReady=serverTime-_since >= 3;
                _vehicle setVariable ["CBE_DrivingSolidSeen",[_contact,_since,serverTime]];
            } else {_vehicle setVariable ["CBE_DrivingSolidSeen",nil]};
            _capMps=_capMps min (_traffic select 0);
            private _capCommitted=false;
            isNil {
                if (!(call _mayIssueDriving)
                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                    || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
                    || {(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isNotEqualTo _entryAssistState}
                    || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo _entryRestore}
                    || {abs ((getForcedSpeed _vehicle)-_entryForcedSpeed) > 0.1}
                    || {_queueHold && {!( ["OBSERVE",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueHold)}}
                    || {_queueNativeActive && {!( ["ADMIT",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueReverseCommit)}}
                    || {_queueCrossing && {!(call _queueCrossAuthority)}}
                    || {_crewBoardingHold && {!([_group,_vehicle,_brain,{call _mayIssueDriving
                        && {call _recoveryOrderFree} && {call _nativeRouteIntent}}] call CBE_fnc_DrivingCrewBoarding)}}) exitWith {false};
                // Publish a minimal current cap receipt together with its original baseline.
                // Cleanup can now restore an applied cap even if later observations yield.
                private _capReceipt=+_state;
                if (_capReceipt isEqualTo []) then {_capReceipt=[_capMps,_maximumGrade,time,_group]} else {
                    _capReceipt set [0,_capMps];
                };
                _vehicle forceSpeed _capMps;
                if (abs ((getForcedSpeed _vehicle)-_capMps) > 0.1) exitWith {false};
                _vehicle setVariable ["CBE_DrivingAssist_Restore",_previous];
                _vehicle setVariable ["CBE_DrivingAssist_State",_capReceipt];
                _vehicle setVariable ["CBE_DrivingCap_Issuer",[
                    [clientOwner,_brain get "ownerEpoch",_brain get "generation"],_driver,effectiveCommander _vehicle]];
                _entryAssistState=+_capReceipt;
                if (_queueHold) then {["APPLIED",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueHold};
                private _capIssueComplete=true;
                if (_queueNativeActive) then {
                    private _nativeQueueMode=if (_queueStarted) then {["ISSUE","STOP"] select _queueStop} else {"ISSUE"};
                    private _queueCommitted=[_nativeQueueMode,_group,_vehicle,_brain] call CBE_fnc_DrivingQueueReverseCommit;
                    if (!_queueCommitted) then {
                        // Refused issue cannot leave a positive cap on the original forward
                        // task. Roll back in this same sole-writer transaction; never replay BACK.
                        _vehicle forceSpeed 0;
                        if (abs (getForcedSpeed _vehicle) > 0.1) then {
                            // A failed STOP did not acquire a zero-speed lease. Keep the
                            // confirmed positive cap/baseline and skip further recovery work.
                            _capIssueComplete=false;
                        } else {
                            _capMps=0;_capReceipt set [0,0];
                            _vehicle setVariable ["CBE_DrivingAssist_State",_capReceipt];
                            _entryAssistState=+_capReceipt;
                        };
                    };
                    private _issuedQueue=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                    if ("queueBinding" in _issuedQueue) then {
                        _state set [6,2];_state set [7,time+((_issuedQueue get "hardDeadline")-serverTime)];
                        _state set [10,true];_reverseIssued=true;
                    };
                };
                _capCommitted=_capIssueComplete;
            };
            if (!_capCommitted) then {
                // Admission/application refusal or unconfirmed queue STOP cannot advance recovery.
                // Preserve the last confirmed receipt; never invent zero-cap ownership or clean a successor.
            } else {
            if (_gateObservation isNotEqualTo [] && {call _mayIssueDriving}) then {
                [_group,_vehicle,_gateObservation] call CBE_fnc_DrivingGateRequest;
            };
            _vehicle setVariable ["CBE_DrivingAssist_Traffic",_traffic];
            if (!_queueNativeActive && {!_queueCrossing} && {!_queueHold} && {!_crewBoardingHold}
                && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass}) then {
                [_vehicle,_group,_brain,[_traffic,_gateObservation,_obstacleObservation,_capMps],
                    {call _mayRecoverRoute}] call CBE_fnc_DrivingAbortHandback;
            };

            // Retain the owning group for diagnostics only. The lease remains the forced-speed
            // value: this reference never grants route or movement ownership to CBE.
            // Native vehicles can abandon an otherwise valid MOVE command after a small collision
            // or navigation fault.  Recovery remains subordinate to that authored waypoint:
            // refresh it once, reverse only into a checked-clear rear area, then retry once.
            // It never adds/replaces a waypoint, changes collision or moves the vehicle directly.
            private _progressPosition=_state param [4,getPosATL _vehicle];
            private _progressAt=_state param [5,time];
            private _recoveryStage=_state param [6,0];
            private _recoveryUntil=_state param [7,-1];
            private _recoveryResult=_state param [8,"IDLE"];
            if (call _nativeWaiting) then {_recoveryResult="INTENTIONAL_WAIT"};
            // Bounded traffic replan: keep collision caps, never recreate the authored waypoint.
            // The public budget survives owner changes; interrupted dwell is not accumulated.
            isNil {
                if (!(call _mayIssueDriving)
                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                    || {time < (_traffic select 3)} || {time-(_traffic select 3) > 1.5}) exitWith {false};
                private _jamPrior=_vehicle getVariable ["CBE_DrivingTrafficRetry",createHashMap];
                private _jam=createHashMapFromArray ((keys _jamPrior) apply {[_x,_jamPrior get _x]});
                private _jamChanged=false;
                if (count _jam > 0 && {(_jam get "route") isNotEqualTo _routeIdentity
                    || {(_jam get "group") != _group}
                    || {(_vehicle distance2D (_jam get "origin")) >= 15
                        && {((_jam get "origin") distance2D ([_group] call CBE_fnc_DrivingRouteGoal))
                            -(_vehicle distance2D ([_group] call CBE_fnc_DrivingRouteGoal)) >= 15}}}) then {
                    _jam=createHashMap;_jamChanged=true;
                };
                private _jamPeer=_traffic select 1;
                private _jamEligible=_trafficLimited && {!isNull _jamPeer} && {_jamPeer != _vehicle}
                    && {_jamPeer isKindOf "LandVehicle"} && {([_jamPeer] call _stationary)} && {([_vehicle] call _stationary)}
                    && {_recoveryStage == 0} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass}
                    && {behaviour leader _group in ["SAFE","AWARE"]} && {getSuppression _driver <= 0.1}
                    && {[_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
                    && {call _mayRecoverOrdinaryRoute};
                private _jamObserver=[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_routeIdentity,_driver,_movementOperator];
                private _jamSeen=_vehicle getVariable ["CBE_DrivingTrafficSeen",[]];
                private _jamOwnPose=getPosASL _vehicle;
                private _jamPeerPose=getPosASL _jamPeer;
                private _jamContinuous=count _jamSeen == 5 && {(_jamSeen select 0) isEqualTo _jamObserver}
                    && {(_jamSeen select 1) == _jamPeer} && {serverTime >= (_jamSeen select 2)}
                    && {serverTime-(_jamSeen select 2) <= 6}
                    && {_jamOwnPose vectorDistance (_jamSeen select 3) <= 1.5}
                    && {_jamPeerPose vectorDistance (_jamSeen select 4) <= 1.5};
                // Anchors belong to the whole dwell, not just the preceding sample: otherwise
                // a slow queue could creep indefinitely while every adjacent displacement is small.
                private _jamOwnAnchor=if (_jamContinuous) then {+(_jamSeen select 3)} else {+_jamOwnPose};
                private _jamPeerAnchor=if (_jamContinuous) then {+(_jamSeen select 4)} else {+_jamPeerPose};
                // This local observation receipt is not replayed or broadcast. Migration/gaps/motion
                // restart only stationary dwell, never the public attempt count or hard deadline.
                _vehicle setVariable ["CBE_DrivingTrafficSeen",if (_jamEligible) then {[_jamObserver,_jamPeer,serverTime,_jamOwnAnchor,_jamPeerAnchor]} else {nil}];
                if (_jamEligible) then {
                    if (count _jam == 0) then {
                        _jam=createHashMapFromArray [["group",_group],["route",_routeIdentity],["driver",_driver],["operator",_movementOperator],
                            ["driverCommand",+(expectedDestination _driver)],["command",+(expectedDestination _movementOperator)],
                            ["origin",getPosATL _vehicle],["deadline",serverTime+80],["next",serverTime+20],
                            ["attempts",0],["peer",_jamPeer],["since",serverTime],["yielded",false]];
                        _jamChanged=true;
                    };
                    private _requestPending=false;
                    private _request=_jam getOrDefault ["request",[]];
                    if (!(_jam get "yielded") && {_request isNotEqualTo []}) then {
                        private _validRequest=_request isEqualType [] && {count _request == 3}
                            && {(_request select 0) isEqualType []} && {count (_request select 0) == 3}
                            && {(_request select 0) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                            && {(_request select 1) isEqualType 0} && {finite (_request select 1)}
                            && {(_request select 2) isEqualType []} && {count (_request select 2) == 2};
                        private _nativeNow=expectedDestination _movementOperator;
                        private _goalNow=_nativeNow param [0,[],[[]]];
                        private _sameSeats=(_jam get "driver") == _driver && {(_jam get "operator") == _movementOperator};
                        if (_validRequest && {_sameSeats} && {count _goalNow == 3}
                            && {_goalNow vectorDistance (_request select 0) <= 0.25}
                            && {currentCommand _movementOperator in ["","MOVE"]}) then {
                            // Consume the issued target, including a late observation, without
                            // replaying the command or renewing the episode/attempt budget.
                            _jam set ["driverCommand",+(expectedDestination _driver)];
                            _jam set ["command",+_nativeNow];_jam deleteAt "request";_jamChanged=true;
                        } else {
                            _requestPending=_validRequest && {_sameSeats} && {serverTime <= (_request select 1)}
                                && {(expectedDestination _driver) isEqualTo (_jam get "driverCommand")}
                                && {_nativeNow isEqualTo (_jam get "command")}
                                && {currentCommand _driver in [(_request select 2) select 0,"MOVE"]}
                                && {currentCommand _movementOperator in [(_request select 2) select 1,"MOVE"]};
                            if (!_requestPending) then {_jam set ["yielded",true];_jamChanged=true};
                        };
                    };
                    if ((_jam get "driver") != _driver || {(_jam get "operator") != _movementOperator}
                        || {(expectedDestination _driver) isNotEqualTo (_jam get "driverCommand")}
                        || {(expectedDestination _movementOperator) isNotEqualTo (_jam get "command")}) then {
                        if !(_jam get "yielded") then {_jam set ["yielded",true];_jamChanged=true};
                    };
                    if (!_jamContinuous || {(_jam get "peer") != _jamPeer} || {(_jam get "since") < 0}) then {
                        _jam set ["peer",_jamPeer];_jam set ["since",serverTime];_jamChanged=true;
                    };
                    private _queueAdmission=[_group,_vehicle,_brain,_jam,_jamPeer,
                        _jamContinuous && {!_requestPending}] call CBE_fnc_DrivingQueueAutoStep;
                    _jamChanged=_jamChanged || {_queueAdmission select 1};
                    if (!(_queueAdmission select 0) && {!(_jam get "yielded")} && {!_requestPending} && {(_jam get "attempts") < 3} && {serverTime < (_jam get "deadline")}
                        && {serverTime >= (_jam get "next")} && {serverTime-(_jam get "since") >= 20}
                        && {call _mayRecoverOrdinaryRoute}) then {
                        private _requestGoal=[_group] call CBE_fnc_DrivingRouteGoal;
                        private _requestTasks=[currentCommand _driver,currentCommand _movementOperator];
                        _movementOperator doMove _requestGoal;
                        _jam set ["request",[+_requestGoal,serverTime+2,_requestTasks]];
                        _jam set ["attempts",(_jam get "attempts")+1];_jam set ["next",serverTime+20];
                        _jam set ["driverCommand",+(expectedDestination _driver)];
                        _jam set ["command",+(expectedDestination _movementOperator)];_jamChanged=true;
                    };
                } else {
                    if (count _jam > 0) then {
                        // Lost dwell eligibility must reach the pending-negotiation cancellation
                        // path too. This cannot discover a new proposal or cancel committed work.
                        private _queueInterrupted=[_group,_vehicle,_brain,_jam,_jamPeer,false]
                            call CBE_fnc_DrivingQueueAutoStep;
                        _jamChanged=_jamChanged || {_queueInterrupted select 1};
                        if ((_jam get "since") >= 0) then {
                            _jam set ["since",-1];_jamChanged=true;
                        };
                    };
                };
                if (_jamChanged && {call _mayIssueDriving}
                    && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain}
                    && {(_vehicle getVariable ["CBE_DrivingTrafficRetry",createHashMap]) isEqualTo _jamPrior}) then {
                    _vehicle setVariable ["CBE_DrivingTrafficRetry",_jam,true];
                };
                false
            };

            // Automatic queue admission is separately opt-in, default off. Pending
            // negotiation defers competing replans; motion still requires all-owner commit.
            // Refusal consumes one attempt in the original jam budget, not a new episode.

            // Waiting behind traffic is not a route fault. Keep the last progress sample current so
            // clearing the queue does not immediately inherit a stale reverse deadline.
            if ((_trafficLimited && {!_solidCandidate}) || {_corridorActive} || {_hadCorridor} || {_bypassActive} || {_hadBypass} || {_passActive} || {_hadPass}) then {
                _progressPosition=getPosATL _vehicle;_progressAt=time;
                // Keep an already-issued rear leg finite. After the pedestrian clears,
                // its expired deadline returns to the authored route instead of losing
                // the rear-leg receipt and treating backward travel as ordinary progress.
                // A spent bypass is part of this recovery episode, not unrelated traffic.
                // Preserve its original budget through active work, exact native return and
                // later obstacle waits. Otherwise the next child callback loses its parent,
                // and a failed child can replenish the same stalled episode indefinitely.
                private _pausedParent=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                private _keepBypassBudget=_recoveryOwned
                    && {(_pausedParent getOrDefault ["bypassSpent",false]) isEqualTo true}
                    && {(_pausedParent getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}
                    && {!(_pausedParent getOrDefault ["releasePending",false])}
                    && {(_pausedParent getOrDefault ["group",grpNull]) == _group}
                    && {(_pausedParent getOrDefault ["route",[]]) isEqualTo _routeIdentity}
                    && {(_pausedParent getOrDefault ["hardDeadline",-1]) isEqualTo (_recoveryWork getOrDefault ["hardDeadline",-2])}
                    && {(_pausedParent getOrDefault ["progressAnchor",[]]) isEqualTo (_recoveryWork getOrDefault ["progressAnchor",[]])}
                    && {([_vehicle,_pausedParent] call CBE_fnc_DrivingRecoveryCommandState) in ["OWNED","PENDING","BYPASS","CORRIDOR"]};
                if (!(_recoveryStage in [2,4]) && {!_keepBypassBudget}) then {
                    [_vehicle,_group,"RECOVERY_PAUSED",false] call CBE_fnc_DrivingRecoveryRelease;
                    _recoveryStage=0;_recoveryUntil=-1;_reverseIssued=false
                };
                _recoveryResult=if (_bypassActive) then {_bypass select 2} else {if (_corridorActive) then {_corridor select 2} else {
                    if (_obstacleLimited) then {["OBSTACLE_WAIT","OBSTACLE_APPROACH"] select (!([_vehicle] call _stationary))} else {
                        ["CORRIDOR_HANDBACK","TRAFFIC_FOLLOW"] select _trafficLimited
                    }
                }};
            };
            if (_passActive) then {_recoveryResult="PASS_"+(_pass select 2)};
            private _routeProgress=true;
            if (_recoveryStage > 0) then {
                private _progressGoal=[_group] call CBE_fnc_DrivingRouteGoal;
                _routeProgress=false;
                private _progressJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                private _progressAnchor=_progressJournal getOrDefault ["progressAnchor",[]];
                // Stage clocks/positions change at each retry. Only progress beyond
                // the original stalled position can replenish this finite episode.
                if (_progressGoal isNotEqualTo []
                    && {(_progressJournal getOrDefault ["group",grpNull]) == _group}
                    && {(_progressJournal getOrDefault ["route",[]]) isEqualTo _routeIdentity}
                    && {_progressAnchor isEqualType []} && {count _progressAnchor == 3}
                    && {_progressAnchor findIf {!(_x isEqualType 0) || {!finite _x}} < 0}) then {
                    private _progressDestination=_progressGoal;
                    _routeProgress=(_progressAnchor distance2D _progressDestination)
                        -(_vehicle distance2D _progressDestination) >= 3;
                };
            };
            // Reversing is a recovery leg, not proof that the original route resumed.
            // Do not reset its finite stages merely because the vehicle moved backwards.
            if (!_queueNativeActive && {_recoveryStage != 2} && {!_trafficLimited} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass} && {_vehicle distance2D _progressPosition >= 3} && {_routeProgress}) then {
                _progressPosition=getPosATL _vehicle;
                _progressAt=time;
                _recoveryStage=0;
                _recoveryUntil=-1;
                _recoveryResult="PROGRESS";_reverseIssued=false;
                [_vehicle,_group,"ROUTE_PROGRESS",false] call CBE_fnc_DrivingRecoveryRelease;
            };
            private _waypointIndex=currentWaypoint _group;
            private _recoveryGoal=[_group] call CBE_fnc_DrivingRouteGoal;
            private _hasRoute=_recoveryGoal isNotEqualTo [];
            private _inCombat=behaviour leader _group in ["COMBAT","STEALTH"] || {getSuppression _driver > 0.1};
            // A reverse leg has its own finite deadline. It must return to the authored
            // route even while still moving; the ordinary stall timer is not another hold.
            private _scheduledRecovery=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
            // A delayed callback must not start an already-expired rear window.
            if (_recoveryStage == 1 && {count _scheduledRecovery > 0}
                && {serverTime >= (_scheduledRecovery get "hardDeadline")-60}) then {
                _recoveryStage=2;_recoveryUntil=time;_reverseIssued=false;
            };
            private _finalExpired=_recoveryStage == 3 && {count _scheduledRecovery > 0}
                && {serverTime >= (_scheduledRecovery get "hardDeadline")};
            private _reverseComplete=_recoveryStage == 2 && {time >= _recoveryUntil};
            // Retiring an expired exact rear command does not grant movement through the
            // blocked forward lane: its already-applied current safety cap remains intact.
            private _reverseHandback=_reverseComplete && {_reverseIssued};
            // Preserve native planning time rather than repeatedly restarting a difficult route.
            // Real progress, a replaced order, follower ownership or an intentional wait already
            // resets this stage and its progress clock above. A rear leg keeps its finite expiry.
            private _observationWindow=[20,30,0,60] param [_recoveryStage,60];
            if (_hasRoute && {_recoveryStage in [0,1,2,3]} && {[_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
                && {!_inCombat} && {!_trafficLimited || {_solidReady} || {_reverseHandback}} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass} && {([_vehicle] call _stationary) || {_reverseComplete}}
                && {time-_progressAt >= _observationWindow || {_reverseComplete} || {_finalExpired}} && {time >= _recoveryUntil}
                && {call _mayIssueDriving} && {call _mayRecoverOrdinaryRoute}) then {
                private _waypoint=[_group,_waypointIndex];
                private _destination=+_recoveryGoal;
                private _arrivalRadius=if (_nativeOnlyRoute) then {20} else {waypointCompletionRadius _waypoint max 20};
                if (_vehicle distance2D _destination > _arrivalRadius) then {
                    private _recoveryTransitioned=false;
                    switch (_recoveryStage) do {
                        case 0: {
                            private _forwardJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                            private _forwardCommands=[currentCommand _driver,+(expectedDestination _driver),
                                currentCommand _movementOperator,+(expectedDestination _movementOperator)];
                            isNil {
                                if (!(call _mayIssueDriving) || {!(call _mayRecoverOrdinaryRoute)}
                                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                                    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                                    || {!([_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
                                    || {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _forwardJournal}
                                    || {[currentCommand _driver,+(expectedDestination _driver),
                                        currentCommand _movementOperator,+(expectedDestination _movementOperator)] isNotEqualTo _forwardCommands}) exitWith {false};
                                if (count _forwardJournal > 0 && {serverTime >= (_forwardJournal get "hardDeadline")}) then {
                                    _recoveryStage=4;_recoveryResult="EXHAUSTED";_reverseIssued=false;
                                    _recoveryUntil=["EXHAUSTED"] call _recordRecovery;
                                } else {
                                    _movementOperator doMove _destination;
                                    _recoveryStage=1;
                                    _recoveryUntil=["REFRESH",[],"DESTINATION",[],[+_destination,serverTime+2,_forwardCommands]] call _recordRecovery;
                                    _recoveryResult="ROUTE_REFRESH";_reverseIssued=false;
                                };
                                _recoveryTransitioned=true;
                            };
                        };
                        case 1: {
                            private _rear=[];
                            private _rearSimpleBefore=+(vehicleMoveInfo _vehicle);
                            private _rearPose=[getPosASL _vehicle,vectorDir _vehicle,time,vectorUp _vehicle];
                            private _rearHitpointReceipt=[_vehicle] call CBE_fnc_DrivingDamageReceipt;
                            private _rearCommands=[currentCommand _driver,+(expectedDestination _driver),
                                currentCommand _movementOperator,+(expectedDestination _movementOperator)];
                            private _rearJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                            // Fresh shared body-width observation; no fixed-width centre probe.
                            private _cornerRate=if (_saved > 0) then {_saved min (10/3.6)} else {10/3.6};
                            private _cornerTravel=(floor (12*_cornerRate)) min 24;
                            private _rearPlan=if (_solidReady && {_obstacleObservation isNotEqualTo []}
                                && {_cornerTravel > 6} && {(_rearJournal getOrDefault ["bypassSpent",false]) isEqualTo false}) then {
                                [_vehicle,_obstacleObservation,_cornerTravel] call CBE_fnc_DrivingRearPlan
                            } else {[_vehicle] call CBE_fnc_DrivingRearPlan};
                            private _clearance=_rearPlan select 0;private _rearEnvelope=_rearPlan select 1;
                            _rear=+(_clearance param [4,[]]);
                            private _rearSafe=(_clearance select 0) && {count _rear == 3} && {count _rearHitpointReceipt == 3};
                            // Geometry uses the current callback context; native issue and its exact command journal
                            // share a short current-owner transaction with the original hard deadline.
                            isNil {
                                if (!(call _mayIssueDriving) || {!(call _mayRecoverOrdinaryRoute)}
                                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                                    || {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _rearJournal}
                                    || {count _rearJournal == 0} || {serverTime >= (_rearJournal get "hardDeadline")-60}
                                    || {(vehicleMoveInfo _vehicle) isNotEqualTo _rearSimpleBefore}
                                    || {([_vehicle] call CBE_fnc_DrivingDamageReceipt) isNotEqualTo _rearHitpointReceipt}
                                    || {time < (_rearPose select 2)} || {time-(_rearPose select 2) > 1}
                                    || {(getPosASL _vehicle) vectorDistance (_rearPose select 0) > 1}
                                    || {(vectorDir _vehicle) vectorDotProduct (_rearPose select 1) < cos 5}
                                    || {(vectorUp _vehicle) vectorDotProduct (_rearPose select 3) < cos 5}
                                    || {(_rearEnvelope select 1) > 6 && {count _obstacleObservation != 9
                                        || {!([_obstacleObservation select 1] call CBE_fnc_DrivingBypassObstacleAvailable)}
                                        || {[getPosWorld (_obstacleObservation select 1),vectorDir (_obstacleObservation select 1),vectorUp (_obstacleObservation select 1)] isNotEqualTo (_obstacleObservation select 8)}}}
                                    || {[currentCommand _driver,+(expectedDestination _driver),
                                        currentCommand _movementOperator,+(expectedDestination _movementOperator)] isNotEqualTo _rearCommands}) exitWith {false};
                                private _rearCommandMode="DESTINATION";
                                if (_rearSafe) then {
                                    // A separate native commander is required; preserve mission crew roles.
                                    // Do not cancel a pre-existing turn merely to make BACK applicable.
                                    if (_driver != _movementOperator && {(_rearSimpleBefore param [1,""]) == "NONE"}) then {
                                        _vehicle sendSimpleCommand "BACK";
                                        _rearCommandMode="SIMPLE_BACK";
                                    } else {
                                        _movementOperator doMove _rear;
                                    };
                                    _recoveryResult="CAUTIOUS_REVERSE";_reverseIssued=true;
                                } else {
                                    _recoveryResult="REAR_BLOCKED";_reverseIssued=false;
                                };
                                _recoveryStage=2;
                                _recoveryUntil=[["BLOCKED","REVERSE"] select _reverseIssued,_rearHitpointReceipt,
                                    _rearCommandMode,_rearSimpleBefore,if (_reverseIssued && {_rearCommandMode == "DESTINATION"}) then {
                                        [+_rear,serverTime+2,_rearCommands]
                                    } else {[]},_rearEnvelope] call _recordRecovery;
                                _recoveryTransitioned=true;
                            };
                        };
                        case 2: {
                            private _forwardJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                            private _forwardCommands=[currentCommand _driver,+(expectedDestination _driver),
                                currentCommand _movementOperator,+(expectedDestination _movementOperator)];
                            isNil {
                                if (!(call _mayIssueDriving) || {!(call _mayRecoverOrdinaryRoute)}
                                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                                    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                                    || {!([_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
                                    || {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _forwardJournal}
                                    || {[currentCommand _driver,+(expectedDestination _driver),
                                        currentCommand _movementOperator,+(expectedDestination _movementOperator)] isNotEqualTo _forwardCommands}) exitWith {false};
                                // The earlier endpoint boundary must acknowledge native STOP
                                // before this path can replace the journal with a forward retry.
                                if ((_forwardJournal getOrDefault ["commandMode","DESTINATION"]) == "SIMPLE_BACK") exitWith {false};
                                if (count _forwardJournal > 0 && {serverTime >= (_forwardJournal get "hardDeadline")}) then {
                                    _recoveryStage=4;_recoveryResult="EXHAUSTED";_reverseIssued=false;
                                    _recoveryUntil=["EXHAUSTED"] call _recordRecovery;
                                } else {
                                    _movementOperator doMove _destination;
                                    _recoveryStage=3;
                                    _recoveryUntil=["FINAL",[],"DESTINATION",[],[+_destination,serverTime+2,_forwardCommands]] call _recordRecovery;
                                    _recoveryResult="FINAL_ROUTE_RETRY";_reverseIssued=false;
                                };
                                _recoveryTransitioned=true;
                            };
                        };
                        default {
                            // Spent retries do not release traffic/terrain safety for this group.
                            // Persist stage four across adoption; only measured route progress or
                            // a new authored route may replenish the recovery episode.
                            private _exhaustedJournal=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                            isNil {
                                if (!(call _mayIssueDriving) || {!(call _mayRecoverOrdinaryRoute)}
                                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                                    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                                    || {count _exhaustedJournal == 0}
                                    || {(_exhaustedJournal get "group") != _group}
                                    || {(_exhaustedJournal get "route") isNotEqualTo _routeIdentity}
                                    || {_exhaustedJournal getOrDefault ["releasePending",false]}
                                    || {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _exhaustedJournal}) exitWith {false};
                                _recoveryResult="EXHAUSTED";_reverseIssued=false;
                                _recoveryStage=4;
                                _recoveryUntil=["EXHAUSTED"] call _recordRecovery;
                                _recoveryTransitioned=true;
                            };
                        };
                    };
                    if (_recoveryTransitioned) then {
                        _progressPosition=getPosATL _vehicle;
                        _progressAt=time;
                    };
                };
            };
            // Scheduled observations and cleanup above cannot recreate a removed state or
            // update another callback's cap receipt. Publish only under the still-current owner.
            isNil {
                if (!(call _mayIssueDriving)
                    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
                    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
                    || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
                    || {(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isNotEqualTo _entryAssistState}
                    || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo _previous}
                    || {abs ((getForcedSpeed _vehicle)-_capMps) > 0.1}) exitWith {false};
                private _liveRecovery=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                if (count _liveRecovery > 0 && {(_liveRecovery get "group") == _group}
                    && {(_liveRecovery get "route") isEqualTo _routeIdentity}
                    && {(_liveRecovery get "driver") == _driver} && {(_liveRecovery get "operator") == _movementOperator}
                    && {((expectedDestination _driver) isEqualTo (_liveRecovery get "driverCommand")
                        && {(expectedDestination _movementOperator) isEqualTo (_liveRecovery get "command")})
                        || {([_vehicle,_liveRecovery] call CBE_fnc_DrivingRecoveryCommandState) in ["BYPASS","CORRIDOR"]}}
                    && {!(_liveRecovery getOrDefault ["releasePending",false])}
                    && {(_liveRecovery get "cap") != _capMps}) then {
                    private _updatedRecovery=createHashMapFromArray (keys _liveRecovery apply {[_x,_liveRecovery get _x]});
                    _updatedRecovery set ["cap",_capMps];
                    _vehicle setVariable ["CBE_DrivingRecovery_Work",_updatedRecovery,true];
                };
                if (_crewBoardingHold) then {_recoveryResult="CREW_BOARDING"};
                if (_queueHold) then {_recoveryResult="QUEUE_HOLD"};
                if (_queueNativeActive) then {
                    _recoveryResult="QUEUE_"+((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) getOrDefault ["queuePhase","ISSUE_REFUSED"]);
                };
                _vehicle setVariable ["CBE_DrivingAssist_State",[_capMps,_maximumGrade,time,_group,
                    _progressPosition,_progressAt,_recoveryStage,_recoveryUntil,_recoveryResult,_routeIdentity,_reverseIssued,_trafficWatch]];
                _vehicle setVariable ["CBE_DrivingAssist_Next",time+([4,1] select (_trafficLimited || {_trafficWatch} || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))];
                if (_passActive || {_queueNativeActive}) then {_vehicle setVariable ["CBE_DrivingAssist_Next",time+1]};
            };
            };
            };
        };
    };
    };
    };
} forEach _vehicles;
