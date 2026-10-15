/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a sparse, owner-local safety speed cap and bounded physical recovery to an
 * ordinary AI ground vehicle that is already following a native waypoint. This is the standalone
 * driving layer; registered convoys retain their separate predecessor-spacing controller. Terrain
 * thresholds are expressed in km/h for settings and diagnostics, then converted to the metres per
 * second required by forceSpeed before the command and ownership lease are recorded.
 * Locality / Authority: Runs only where the vehicle is local. It never creates, replaces or
 * deletes a waypoint and yields to players, Zeus remote control, convoy ownership and specialist
 * driving ownership. Ineffective drivers and immobilized vehicles receive no recovery commands.
 * An authored zero forced-speed hold is retained without recovery commands.
 * Native boarding, service, medical and assembly tasks release the exact speed lease;
 * both driver and effective commander are rechecked at each cap/recovery command boundary.
 * The authored waypoint identity includes conditions, timeouts, synchronized triggers, speed,
 * combat mode and formation. Same-index edits retire the old recovery stage. Every cap/recovery
 * command rechecks that identity; the implicit spawn waypoint never authorizes assistance.
 * Road bends, junctions and absolute road grade share the convoy observer at existing cadence.
 * Same-direction traffic uses current hull gaps and actual velocity for continuous following caps.
 * Owned traffic stops remain sampled; congestion suppresses route refresh/reverse rather than
 * treating a queue as navigation failure. No crossing priority or passing is inferred here.
 * Reverse admission uses a fresh body-sized rear corridor observation shared with tracked
 * withdrawal. Actor and solid-geometry clearance does not prove native reverse execution.
 * Only the current leader vehicle can refresh/reverse the shared route. Followers keep native
 * formation movement; a leader/seat/locality change invalidates delayed recovery commands.
 * Deliberate native waits near the completion envelope suppress recovery without evaluating
 * waypoint statement code. Recovery also refuses distant scripted, timed, synchronized or
 * object-attached MOVE orders; native execution and ordinary safety caps remain available.
 * One group driving FSM admits the existing executor through the shared
 * scheduler; group decisions never issue these commands directly.
 * Repeat/JIP: State is stored on the vehicle and is idempotent. The next local group step resumes
 * it after a locality change; route changes reset finite recovery; release restores only the forced speed captured by this function.
 * Arguments:
 * 0: group <GROUP> - local AI group commanding the vehicle.
 * 1: operation brain <HASHMAP, empty> - internal current-owner executor receipt.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_CortexGroupTick (admission), DrivingOperationStep (execution).
 * Example: [group driver truck1] call WAIT_fnc_DrivingAssistStart;
 */

params [["_group",grpNull,[grpNull]],["_brain",createHashMap,[createHashMap]]];
if (isNull _group || {!local _group}) exitWith {};
// Normal group decisions admit/reuse the FSM; only its current queued callback writes commands.
if (count _brain == 0) exitWith {[_group] call WAIT_fnc_DrivingOperationStart};
if ((_group getVariable ["WAIT_Driving_Brain",createHashMap]) isNotEqualTo _brain
    || {_brain getOrDefault ["cancelled",false]}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {};
private _enabled=[_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
// Read only the current authored waypoint. Conditions and trigger identities belong to the order,
// just as its position does. A same-index edit must not inherit a reverse request for the old order.
private _readRouteIdentity={[_group] call WAIT_fnc_DrivingRouteReceipt};
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
private _previous=_group getVariable ["WAIT_DrivingAssist_Vehicles",[]];
{
    if !(_x in _vehicles) then {[_x,_group] call WAIT_fnc_DrivingAssistRelease};
} forEach _previous;
_group setVariable ["WAIT_DrivingAssist_Vehicles",_vehicles];
{
    private _vehicle=_x;
    private _driver=driver _vehicle;
    private _movementOperator=effectiveCommander _vehicle;
    if (isNull _movementOperator) then {_movementOperator=_driver};
    private _nativeTaskFree={
        params ["_actor"];
        !isNull _actor && {!(currentCommand _actor in [
            "GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED",
            "ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"
        ])}
    };
    private _routeIdentity=call _readRouteIdentity;
    private _release=false;
    // Driving must make the same ownership decision as every other delayed controller. A group
    // member becoming player-controlled or specialist-owned is enough to retire the sparse speed
    // cap before it can issue a recovery move; the individual driver checks below retain the
    // vehicle-specific local/remote-control safety boundary.
    private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
    if (!_enabled || {!local _vehicle} || {!alive _vehicle} || {!canMove _vehicle}
        || {!([_driver] call WAIT_fnc_CortexCombatEffective)} || {isPlayer _driver}
        || {!isNull (_driver getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_driver] call WAIT_fnc_CortexExternalOwner != ""}
        || {_yieldToOwner}
        || {!([_driver] call _nativeTaskFree)}
        || {!([_movementOperator] call _nativeTaskFree)}
        || {getForcedSpeed _vehicle == 0 && {
            private _heldState=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
            !((_heldState param [0,-1]) == 0 && {(_heldState param [3,grpNull]) == _group}
                && {!isNull ((_vehicle getVariable ["WAIT_DrivingAssist_Traffic",[]]) param [1,objNull])})
        }}
        || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        || {behaviour leader _group == "CARELESS"}
        || {_routeIdentity isEqualTo []}) then {_release=true};
    if (_release) then {[_vehicle,_group] call WAIT_fnc_DrivingAssistRelease} else {
        // Terrain sampling is deliberately sparse but may still overlap a newer Zeus or specialist
        // order. Preserve that order at the actual cap/recovery command boundary.
        private _mayIssueDriving = {
            local _group && {local _vehicle}
                && {[_group] call WAIT_fnc_DrivingMovementAvailable}
                && {driver _vehicle isEqualTo _driver}
                && {(effectiveCommander _vehicle) in [_movementOperator,objNull]}
                && {vehicle _movementOperator isEqualTo _vehicle}
                && {local _driver} && {group _driver == _group}
                && {!isPlayer _driver} && {isNull remoteControlled _driver}
                && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
                && {alive _vehicle} && {canMove _vehicle}
                && {[_driver] call WAIT_fnc_CortexCombatEffective}
                && {[_movementOperator] call WAIT_fnc_CortexCombatEffective}
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
            if (abs speed _vehicle >= 1 || {!unitReady _vehicle}
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
            private _index=currentWaypoint _group;
            if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
            private _waypoint=[_group,_index];
            private _statements=waypointStatements _waypoint;
            private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
            waypointType _waypoint == "MOVE" && {_condition == "true"}
                && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
                && {waypointScript _waypoint == ""}
                && {(waypointTimeout _waypoint param [2,0]) <= 0}
                && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
                && {(synchronizedWaypoints _waypoint) isEqualTo []}
                && {(synchronizedTriggers _waypoint) findIf {!isNull _x && {!triggerActivated _x}} < 0}
        };
        private _mayRecoverRoute = {
            call _mayIssueDriving && {vehicle leader _group isEqualTo _vehicle} && {!(call _nativeWaiting)}
                && {call _recoveryOrderFree}
        };
        private _priorOwner=(_vehicle getVariable ["WAIT_DrivingAssist_State",[]]) param [3,grpNull];
        if (!isNull _priorOwner && {_priorOwner != _group}) then {
            // A new driver group adopts only after retiring the old group's exact cap lease.
            [_vehicle,_priorOwner] call WAIT_fnc_DrivingAssistRelease;
        };
        if (time >= (_vehicle getVariable ["WAIT_DrivingAssist_Next",-1])) then {
            // A new Zeus, mission or specialist cap may not advertise an ownership marker. The
            // last cap we applied is therefore the narrowest reliable lease check: once another
            // value replaces it, release without restoring the stale pre-WAIT value.
            private _previous=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
            private _state=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
            private _ownedCap=_state param [0,-1];
            if (_previous isNotEqualTo [] && {_ownedCap >= 0} && {abs ((getForcedSpeed _vehicle)-_ownedCap) > 0.1}) then {
                [_vehicle,_group] call WAIT_fnc_DrivingAssistRelease;
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
                _state set [8,"NEW_ROUTE"];
            };
            // A follower must not retain the cautious-reverse stage of a former leader.
            // Start a fresh observation interval if it later becomes the leader again.
            if (_state isNotEqualTo [] && {vehicle leader _group isNotEqualTo _vehicle}) then {
                _state set [4,getPosATL _vehicle];
                _state set [5,time];
                _state set [6,0];
                _state set [7,-1];
                _state set [8,"NATIVE_FOLLOWER"];
            };
            if (_state isNotEqualTo [] && {call _nativeWaiting}) then {
                _state set [4,getPosATL _vehicle];_state set [5,time];
                _state set [6,0];_state set [7,-1];_state set [8,"INTENTIONAL_WAIT"];
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
            private _cap=(missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_MaxSpeed",70]) max 15 min 120;
            if (_maximumGrade > 0.2) then {_cap=_cap min 18} else {if (_maximumGrade > 0.12) then {_cap=_cap min 28}};
            // The shared read-only road walk anticipates bends/junctions without choosing a route.
            // It runs at this vehicle's existing sparse cadence; mission and traffic caps still win.
            private _roadObservation=[_vehicle,_cap] call WAIT_fnc_DrivingRoadCap;
            _cap=_cap min (_roadObservation select 0);
            // The short rear leg must not inherit the normal road-speed cap. Retain
            // this cautious cap through reverse observation and the final retry handoff.
            if ((_state param [6,0]) in [1,2]) then {_cap=_cap min 10};
            private _previous=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
            if (_previous isEqualTo []) then {
                _previous=[getForcedSpeed _vehicle];
                _vehicle setVariable ["WAIT_DrivingAssist_Restore",_previous];
            };
            private _saved=_previous param [0,-1];
            // Arma forceSpeed/getForcedSpeed values are metres per second. Keep the policy value
            // readable in km/h, but keep the actual lease in engine units so another controller's
            // cap is detected and the pre-WAIT value can be restored exactly.
            private _capMps=_cap/3.6;
            if (_saved > 0) then {_capMps=_capMps min _saved};
            private _traffic=if ((_state param [6,0]) != 2) then {
                [_vehicle,_capMps] call WAIT_fnc_DrivingFollowingCap
            } else {[_capMps,objNull,-1,time,0]};
            private _trafficLimited=!isNull (_traffic select 1);
            _capMps=_capMps min (_traffic select 0);
            if !(call _mayIssueDriving) then {
                // An initial admission has not applied a cap or created an owning state yet.
                // Discard only that unapplied snapshot; established leases use normal release.
                if (_state isEqualTo []) then {_vehicle setVariable ["WAIT_DrivingAssist_Restore",nil]};
                [_vehicle,_group] call WAIT_fnc_DrivingAssistRelease;
            } else {
            _vehicle forceSpeed _capMps;
            _vehicle setVariable ["WAIT_DrivingAssist_Traffic",_traffic];
            // Retain the owning group for diagnostics only. The lease remains the forced-speed
            // value: this reference never grants route or movement ownership to WAIT.
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
            // Waiting behind traffic is not a route fault. Keep the last progress sample current so
            // clearing the queue does not immediately inherit a stale reverse deadline.
            if (_trafficLimited) then {
                _progressPosition=getPosATL _vehicle;_progressAt=time;
                _recoveryStage=0;_recoveryUntil=-1;_recoveryResult="TRAFFIC_FOLLOW";
            };
            private _routeProgress=true;
            if (_recoveryStage > 0) then {
                private _progressWaypoint=currentWaypoint _group;
                _routeProgress=false;
                if (_progressWaypoint < count waypoints _group) then {
                    private _progressDestination=waypointPosition [_group,_progressWaypoint];
                    _routeProgress=(_progressPosition distance2D _progressDestination)
                        -(_vehicle distance2D _progressDestination) >= 3;
                };
            };
            // Reversing is a recovery leg, not proof that the original route resumed.
            // Do not reset its finite stages merely because the vehicle moved backwards.
            if (_vehicle distance2D _progressPosition >= 3 && {_routeProgress}) then {
                _progressPosition=getPosATL _vehicle;
                _progressAt=time;
                _recoveryStage=0;
                _recoveryUntil=-1;
                _recoveryResult="PROGRESS";
            };
            private _waypointIndex=currentWaypoint _group;
            private _hasRoute=_waypointIndex < count waypoints _group;
            private _inCombat=behaviour leader _group in ["COMBAT","STEALTH"] || {getSuppression _driver > 0.1};
            // A reverse leg has its own finite deadline. It must return to the authored
            // route even while still moving; the ordinary stall timer is not another hold.
            private _reverseComplete=_recoveryStage == 2 && {time >= _recoveryUntil};
            if (_hasRoute && {[_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                && {!_inCombat} && {!_trafficLimited} && {abs speed _vehicle < 1 || {_reverseComplete}}
                && {time-_progressAt >= 12 || {_reverseComplete}} && {time >= _recoveryUntil}
                && {call _mayIssueDriving} && {call _mayRecoverRoute}) then {
                private _waypoint=[_group,_waypointIndex];
                private _destination=waypointPosition _waypoint;
                if (waypointType _waypoint == "MOVE" && {_vehicle distance2D _destination > (waypointCompletionRadius _waypoint max 20)}) then {
                    switch (_recoveryStage) do {
                        case 0: {
                            _movementOperator doMove _destination;
                            _recoveryStage=1;
                            _recoveryUntil=time+8;
                            _recoveryResult="ROUTE_REFRESH";
                        };
                        case 1: {
                            private _rear=_vehicle getPos [8,(getDir _vehicle)+180];
                            // Fresh shared body-width observation; no fixed-width centre probe.
                            private _clearance=[_vehicle,8] call WAIT_fnc_DrivingRearClear;
                            private _rearSafe=(_clearance select 0) && {!surfaceIsWater _rear}
                                && {((surfaceNormal _rear) select 2) >= 0.7};
                            if (_rearSafe && {call _mayIssueDriving} && {call _mayRecoverRoute}) then {
                                _movementOperator doMove _rear;
                                _recoveryResult="CAUTIOUS_REVERSE";
                            } else {
                                _recoveryResult="REAR_BLOCKED";
                            };
                            _recoveryStage=2;
                            _recoveryUntil=time+6;
                        };
                        case 2: {
                            _movementOperator doMove _destination;
                            _recoveryStage=3;
                            _recoveryUntil=time+60;
                            _recoveryResult="FINAL_ROUTE_RETRY";
                        };
                        default {
                            _recoveryResult="EXHAUSTED";
                            _recoveryUntil=time+60;
                        };
                    };
                    _progressPosition=getPosATL _vehicle;
                    _progressAt=time;
                };
            };
            _vehicle setVariable ["WAIT_DrivingAssist_State",[_capMps,_maximumGrade,time,_group,
                _progressPosition,_progressAt,_recoveryStage,_recoveryUntil,_recoveryResult,_routeIdentity]];
            _vehicle setVariable ["WAIT_DrivingAssist_Next",time+([4,1] select _trafficLimited)];
            };
            };
        };
    };
} forEach _vehicles;
