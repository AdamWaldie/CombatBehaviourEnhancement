/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a sparse, owner-local safety speed cap and bounded physical recovery to an
 * ordinary AI ground vehicle that is already following a native waypoint. This is the standalone
 * driving layer; registered convoys retain their separate predecessor-spacing controller. Terrain
 * thresholds are expressed in km/h for settings and diagnostics, then converted to the metres per
 * second required by forceSpeed before the command and ownership lease are recorded.
 * Locality / Authority: Runs only where the vehicle is local. It never creates, replaces or
 * deletes a waypoint and yields to players, Zeus remote control, convoy ownership and specialist
 * driving ownership. An authored zero forced-speed hold is retained without recovery commands.
 * Repeat/JIP: State is stored on the vehicle and is idempotent. The next local group step resumes
 * it after a locality change; route changes reset finite recovery; release restores only the forced speed captured by this function.
 * Arguments:
 * 0: group <GROUP> - local AI group commanding the vehicle.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [group driver truck1] call WAIT_fnc_DrivingAssistStart;
 */

params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {};
private _enabled=[_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
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
    private _release=false;
    // Driving must make the same ownership decision as every other delayed controller. A group
    // member becoming player-controlled or specialist-owned is enough to retire the sparse speed
    // cap before it can issue a recovery move; the individual driver checks below retain the
    // vehicle-specific local/remote-control safety boundary.
    private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
    if (!_enabled || {!local _vehicle} || {isNull _driver} || {isPlayer _driver}
        || {!isNull (_driver getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_driver] call WAIT_fnc_CortexExternalOwner != ""}
        || {_yieldToOwner}
        || {getForcedSpeed _vehicle == 0}
        || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        || {behaviour leader _group == "CARELESS"}
        || {currentWaypoint _group >= count waypoints _group}) then {_release=true};
    if (_release) then {[_vehicle,_group] call WAIT_fnc_DrivingAssistRelease} else {
        // Terrain sampling is deliberately sparse but may still overlap a newer Zeus or specialist
        // order. Preserve that order at the actual cap/recovery command boundary.
        private _movementOperator=effectiveCommander _vehicle;
        if (isNull _movementOperator) then {_movementOperator=_driver};
        private _mayIssueDriving = {
            !([_group] call WAIT_fnc_CortexExternalTakeover)
                && {local _movementOperator} && {group _movementOperator == _group}
                && {!isPlayer _movementOperator} && {isNull remoteControlled _movementOperator}
                && {_driver checkAIFeature "MOVE"} && {_driver checkAIFeature "PATH"}
                && {_movementOperator checkAIFeature "MOVE"} && {_movementOperator checkAIFeature "PATH"}
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
            private _routeWaypoint=[_group,currentWaypoint _group];
            private _routeIdentity=[_routeWaypoint select 1,waypointType _routeWaypoint,
                waypointPosition _routeWaypoint,waypointCompletionRadius _routeWaypoint,
                waypointBehaviour _routeWaypoint];
            if (_state isNotEqualTo [] && {(_state param [9,[]]) isNotEqualTo _routeIdentity}) then {
                _state set [4,getPosATL _vehicle];
                _state set [5,time];
                _state set [6,0];
                _state set [7,-1];
                _state set [8,"NEW_ROUTE"];
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
            if !(call _mayIssueDriving) then {
                // Do not retain a restore record or claim a lease that WAIT never applied.
                [_vehicle,_group] call WAIT_fnc_DrivingAssistRelease;
            } else {
            _vehicle forceSpeed _capMps;
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
                && {!_inCombat} && {abs speed _vehicle < 1 || {_reverseComplete}}
                && {time-_progressAt >= 12 || {_reverseComplete}} && {time >= _recoveryUntil} && {call _mayIssueDriving}) then {
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
                            private _blockers=(nearestObjects [_rear,["Man","LandVehicle","StaticWeapon"],10]) select {
                                _x != _vehicle && {!(_x in crew _vehicle)} && {alive _x}
                            };
                            private _rearSafe=!surfaceIsWater _rear && {((surfaceNormal _rear) select 2) >= 0.7};
                            private _rearASL=AGLToASL _rear;
                            _rearASL set [2,(_rearASL select 2)+1];
                            private _probeOrigin=(getPosASL _vehicle) vectorAdd [0,0,1];
                            private _probeSide=[-(_direction select 1),_direction select 0,0];
                            if (_rearSafe) then {
                                {
                                    private _probeOffset=_probeSide vectorMultiply _x;
                                    if ((lineIntersectsSurfaces [_probeOrigin vectorAdd _probeOffset,
                                        _rearASL vectorAdd _probeOffset,_vehicle,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {
                                        _rearSafe=false;
                                    };
                                } forEach [-1.5,0,1.5];
                            };
                            if (_blockers isEqualTo [] && {_rearSafe} && {call _mayIssueDriving}) then {
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
            _vehicle setVariable ["WAIT_DrivingAssist_Next",time+4];
            };
            };
        };
    };
} forEach _vehicles;
