/*
 * Author: WaldoTheWarfighter
 * Locality/authority: Current group owner; native vehicle writes require actual vehicle/crew ownership.
 * Repeat/JIP: Existing owner-local group ticks maintain finite vehicle work; current
 * epoch, operation and native-order receipts reject stale commands after ownership changes.
 * Passenger stop/continuation proof retains the full current native waypoint identity;
 * same-position policy, script, attachment or synchronization edits end old cooperation.
 * Reactive mortar reports carry current native believed geometry and its server-time observation.
 * Active vehicle manoeuvres cancel on their master or owning feature gate before outcome evaluation.
 * Active jinks retire when either original movement-control seat changes or gains a protected task.
 * Refused standoff native admission releases its exact attempted generation and leases;
 * no moving state is published, and the existing cooldown defers another attempt for eight seconds.
 * Horn exclusion uses config inheritance/simulation, never localised display text.
 * Danger-derived hostile actions retain the original identity expiry/witness; close-range
 * crew safety uses native believed geometry, never the hidden enemy object position.
 * Ground gunnery selects the freshly qualified loaded station muzzle before requesting fire.
 * Native selection must be observed; no magazine loading, ammunition creation or forced shot.
 * Ground contact ranking may reuse a completed failed station scan within the same frame;
 * the selected target receives a fresh default ammunition check before target/fire commands.
 * Vehicle drills for a squad in contact: dismount infantry under fire, and pull a
 * damaged vehicle back behind smoke. A targetless hit, explosion or suppression may invoke only
 * the safe-stop and passenger-exit path; target work, movement and reporting remain unavailable.
 *
 * Dismount safe-stop acquisition uses exact crew/native-order proof; retirement returns only an unchanged
 * owned cap under the original eligible crew, without replaying movement (CortexDismountStop).
 * Dismount records ownership before issuing exit commands, then cancels outstanding boarding orders.
 * Exit handlers can therefore identify the initiating controller without racing bookkeeping.
 * Crew owners publish a bounded, expiring approximate contact report for separate onboard groups.
 * A validated passenger-owner request temporarily forces the vehicle to zero speed, preserving and
 * restoring any earlier forced-speed value once that passenger squad is out or the request expires,
 * but only while the zero-speed lease remains current and no newer controller has replaced it.
 * Scripted danger abandonment preserves protected individual tasks, reservations and STOP orders.
 * Separate passenger groups handle only their own local cargo. Only the operating
 * crew group may order vehicle withdrawal or gunnery; convoy ownership remains excluded.
 * The operating crew also leases the engine unload-in-combat policy for an ordinary occupied
 * ground vehicle. This prevents native autonomous unloading from bypassing CBE's passenger task,
 * safety and Zeus checks. The exact previous value is restored only while CBE's applied value is
 * still current; convoy, external ownership and a newer policy change always win.
 * Dismount: infantry riding as cargo in a ground vehicle get out once an enemy is
 * believed within 400 m, instead of dying inside a truck. They are recorded and ordered back in when
 * the squad returns to CALM (CBE_fnc_CortexRestoreCalm).
 * Withdraw: a vehicle that can still move but is at 50% damage or (if it carries a real weapon, not
 * just a horn or countermeasure launcher) has lost its weapons, with an enemy
 * within 800 m, fires its smoke launcher (CBE_fnc_CortexFireCountermeasure). If the whole squad is
 * mounted, it withdraws towards one of five terrain-checked points roughly 300 m away from the enemy
 * (RETREAT phase, through an inserted waypoint). Each vehicle withdraws once per engagement.
 * Gunnery (CBE_AIPass_VehicleGunnery_Enable): a fresh mounted danger event may orient the exact
 * affected armed platform and request one safe suppression response against an already known hostile.
 * Captive, surrendering and handcuffed sources cannot authorize targeted danger responses.
 * Routine standoff first retires an exact stationary ground-fire role through server
 * fallback, once per role, and waits for its removal; it never moves under that assignment.
 * Routine reports older than3s use native believed-position suppression, not hidden aimPos.
 * Both ground danger and routine point suppression require nonexplosive station bullets/20 loaded rounds, >=50m separation, <30km/h,
 * no unrelated engagement and the existing eight-second fire hold; no new controller.
 * Mounted danger watch converts its ASL firing point back to AGL; suppressive fire
 * retains ASL, so elevation does not offset the watch point a second time.
 * Danger suppression uses the effective commander's native believed contact position, never
 * the hidden enemy's exact aim position. An unavailable estimate cannot authorize suppression.
 * A stopped or slow armed vehicle whose primary gunner has been lost may ask an existing dedicated
 * AI commander to change to that seat once for the exact DETECTED generation. The driver never moves.
 * An intact armed or armoured platform may also request its own smoke countermeasure once for a
 * hit, explosion or suppression generation. A slow, crew-only fighting vehicle may make one short,
 * terrain-checked jink away from a close hostile or severe impact. A stopped tracked fighting vehicle
 * may instead make one generation-owned chassis turn toward a real known hostile. Convoy, passengers
 * and any existing movement owner remain authoritative.
 * Native-AA aircraft ranking shares transient native engagement hints across at most sixteen
 * roster platforms; other-station load breaks ties inside a threat tier, before distance.
 * One native target read/platform plus bounded metadata comparisons, no extra knowledge scan.
 * Held engagements remain hints; fresh dispatched intents reserve only this callback, not shots.
 * During sustained contact the AI gunner is pointed at the most dangerous
 * enemy seen in the last 15 s within 600 m: anti-tank infantry first, then armour, then anything
 * else, nearest first, held for 8 s. Scripted fire requires an available current group gunner,
 * a safe firing lane and (for ground platforms) target-suitable loaded station ammunition.
 * Native AA editor-role platforms prefer fresh aircraft out to the configured engagement range.
 * A recent owner/epoch-matched native missile warning raises its firer above other aircraft
 * only while that same aircraft is independently present in fresh personal native knowledge.
 * Loaded air-suitable station ammunition must qualify this preference before aircraft rows merge.
 * Two rotating vehicle-roster slots also admit custom-category air-capable ground stations.
 * They retain AT/armour priority and acquire no AA relocation role; native AA keeps air priority.
 * One additional aircraft-only knowledge pass per group callback avoids nearby ground-contact
 * crowding; at most sixteen rows merge and eight receive station/lane checks. Other vehicles
 * retain the ordinary policy. This is native gunnery, not anti-munition interception.
 * Up to eight known contacts are considered in threat order, stopping at the first usable lane;
 * an incompatible or blocked first choice cannot starve a lower-priority usable target.
 * A live combined-ground role suppresses competing routine ground targeting until its original
 * expiry or retirement; natural engagement and independent safety responses remain available. A fully mounted tank or APC that knows of an anti-tank soldier
 * within 60% of CBE_AIPass_Vehicles_StandoffDistance backs off to that distance, at most once a
 * minute, through a finite selected-platform native crew worker with original-order handback.
 * Standoff captures the original local driver/commander pair and rechecks movement fitness,
 * native task and external control at admission and continuation; changed crew cancels it.
 * Withdrawal owns its tagged route. Native standoff reserves movement until its original
 * crew has acknowledged handback; an expired ordinary lease never clears pending native work. Other Cortex manoeuvres may continue their combat layers but cannot replace that
 * movement. Conversely, this layer preserves and yields to every active non-vehicle movement lease
 * while continuing composable gunnery, reporting and passenger handling. A withdrawal outranks
 * standoff inside the same evaluation.
 * Vehicles owned by other CBE features never reach this function (CBE_fnc_CortexIsEligible).
 * Locality and authority: call where the group is local.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked. A vehicle withdrawal publishes
 * its origin, target, deadline and progress so the new group owner resumes it after migration;
 * countermeasures are not fired again. Selected standoff retains native cleanup independently;
 * incoming owners may retire its original commands, never resume its outward leg.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: enemies <ARRAY> - from CBE_fnc_CortexKnowledge
 * 3: lifecycle only <BOOL, false> - service existing vehicle lease without new combat work
 *
 * Return Value:
 * Boolean - true while vehicle withdrawal, standoff, danger jink or tracked orientation owns group movement
 *
 * Example:
 * [_group, _state, _enemies] call CBE_fnc_CortexVehicles;
 * Result: a squad caught in its truck bails out and fights on foot.
 *
 * Current caller: CBE_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]], ["_lifecycleOnly",false,[true]]];
if ((_group getVariable ["CBE_VehicleTurn_Work",createHashMap]) isNotEqualTo createHashMap) then {
    [_group,"SERVICE"] call CBE_fnc_VehicleTurnRetire;
};
private _vehicleMove = _state getOrDefault ["movementLease",[]];
private _activeVehicleMove = false;
if (_vehicleMove isNotEqualTo []) then {
    private _vehicleOwnsLease = (_vehicleMove param [0,""]) in ["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"];
    if (_vehicleOwnsLease) then {
        private _movementOwner=_vehicleMove param [0,""];
        private _movementFeature=switch (_movementOwner) do {
            case "VEHICLE_JINK": {"CBE_AIPass_VehicleJink_Enable"};
            case "VEHICLE_WITHDRAW": {"CBE_AIPass_VehicleWithdraw_Enable"};
            default {"CBE_AIPass_VehicleGunnery_Enable"};
        };
        private _vehicleFeatureDisabled=!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)
            || {!([_group,_movementFeature,true] call CBE_fnc_CortexFeatureEnabled)};
        private _orientControllerExternal=false;
        private _orientDriverProtected=false;
        private _orientCommanderProtected=false;
        private _orientOrderChanged=false;
        private _orientOperationChanged=false;
        private _orientThreatInvalid=false;
        private _orientInputChanged=false;
        private _vehicleRouteChanged=false;
        private _vehicleCrewChanged=false;
        if (_movementOwner == "VEHICLE_ORIENT") then {
            private _orientState=_state getOrDefault ["vehicleDangerOrient",[]];
            private _orientVehicle=_orientState param [1,objNull,[objNull]];
            private _marker=if (!isNull _orientVehicle) then {
                _orientVehicle getVariable ["CBE_Danger_VehicleOrient",[]]
            } else {[]};
            private _targetPosition=_marker param [2,[],[[]]];
            private _turnDirection=_marker param [8,"",[""]];
            private _turnInput=if (isNull _orientVehicle) then {[]} else {vehicleMoveInfo _orientVehicle};
            private _observedTurn=toUpperANSI (_turnInput param [1,"",[""]]);
            _orientInputChanged=!(_turnDirection in ["LEFT","RIGHT"])
                || {toUpperANSI (_turnInput param [0,"",[""]]) in ["BACK","DIRECTBYCOMANDER"]}
                || {!(_observedTurn in ["NONE",_turnDirection])};
            _orientControllerExternal=!isNull _orientVehicle && {
                !isNil {_orientVehicle getVariable "CBE_ExternalDrivingOwner"}
                    || {[_orientVehicle] call CBE_fnc_CompatibilityExternalControl}
            };
            private _turnDriver=_marker param [5,objNull,[objNull]];
            _orientDriverProtected=isNull _turnDriver || {driver _orientVehicle != _turnDriver}
                || {!local _turnDriver} || {group _turnDriver != _group} || {isPlayer _turnDriver}
                || {!isNull remoteControlled _turnDriver}
                || {!([_turnDriver] call CBE_fnc_CortexCombatEffective)}
                || {!(_turnDriver checkAIFeature "MOVE")} || {!(_turnDriver checkAIFeature "PATH")}
                || {!([_turnDriver] call CBE_fnc_CortexActorFireTaskAvailable)};
            private _turnCommander=_marker param [7,objNull,[objNull]];
            _orientCommanderProtected=isNull _turnCommander || {effectiveCommander _orientVehicle != _turnCommander}
                || {!local _turnCommander} || {group _turnCommander != _group} || {isPlayer _turnCommander}
                || {!isNull remoteControlled _turnCommander}
                || {!([_turnCommander] call CBE_fnc_CortexCombatEffective)}
                || {_turnCommander != _turnDriver && {!([_turnCommander] call CBE_fnc_CortexActorFireTaskAvailable)}};
            _orientOrderChanged=(_marker param [6,[],[[]]]) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt);
            private _orientOperation=_group getVariable ["CBE_Operation",createHashMap];
            private _turnThreat=_orientOperation getOrDefault ["objective",objNull];
            _orientThreatInvalid=!(_turnThreat isEqualType objNull) || {isNull _turnThreat} || {!alive _turnThreat}
                || {_turnThreat isKindOf "Logic"} || {_turnThreat isKindOf "HeadlessClient_F"}
                || {captive _turnThreat} || {_turnThreat getVariable ["ace_captives_isSurrendering",false]}
                || {_turnThreat getVariable ["ace_captives_isHandcuffed",false]}
                || {(side _group) getFriend (side _turnThreat) >= 0.6};
            private _turnGeneration=_marker param [4,-1,[0]];
            _orientOperationChanged=_turnGeneration != (_state getOrDefault ["vehicleOperationGeneration",-2])
                || {_turnGeneration != (_orientOperation getOrDefault ["generation",-2])}
                || {(_orientOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                || {(_orientOperation getOrDefault ["intent",""]) != "VEHICLE_ORIENT"}
                || {(_orientOperation getOrDefault ["phase",""]) == "CANCELLED"};
            _activeVehicleMove=!_orientControllerExternal && {!_orientDriverProtected} && {!_orientCommanderProtected}
                && {!_orientOrderChanged} && {!_orientOperationChanged} && {!_orientThreatInvalid} && {!_orientInputChanged} && {count _marker == 9}
                && {_marker param [1,grpNull,[grpNull]] == _group}
                && {serverTime < (_marker param [3,0,[0]])}
                && {count _targetPosition >= 2}
                && {!isNull _orientVehicle} && {alive _orientVehicle} && {canMove _orientVehicle}
                && {private _relative=_orientVehicle getRelDir _targetPosition; _relative > 20 && {_relative < 340}}
                && {!([_group] call CBE_fnc_CortexExternalTakeover)};
        } else {
            private _reverse=_group getVariable ["CBE_VehicleReverse",[]];
            private _reverseVehicle=_reverse param [0,objNull,[objNull]];
            private _reverseActive=_movementOwner == "VEHICLE_WITHDRAW"
                && {count _reverse == 9}
                && {(_reverse select 1) == (_state getOrDefault ["vehicleOperationGeneration",-1])}
                && {(_reverse select 2) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                && {time < (_reverse select 5)}
                && {!isNull _reverseVehicle} && {local _reverseVehicle} && {alive _reverseVehicle}
                && {(_reverseVehicle getVariable ["CBE_VehicleReverseOwner",[]]) isEqualTo [_group,_reverse select 1]};
            // A native reverse leg intentionally has no forward waypoint. Its matching finite
            // record is movement evidence; GroupTick owns its progress and fallback checks.
            // A label elsewhere in the route cannot retain this operation's movement lease.
            // Compare only the committed node; never evaluate authored conditions/statements.
            private _moveIntent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
            private _moveGeneration=_state getOrDefault ["vehicleOperationGeneration",-1];
            private _moveOperation=_group getVariable ["CBE_Operation",createHashMap];
            private _moveWaypoint=_moveIntent getOrDefault ["waypoint",[]];
            private _movePosition=_moveIntent getOrDefault ["position",[]];
            private _routeOwned=count _moveWaypoint == 2
                && {(_moveWaypoint select 0) isEqualTo _group}
                && {(_moveWaypoint select 1) >= currentWaypoint _group}
                && {(_moveWaypoint select 1) < count waypoints _group}
                && {_moveGeneration >= 0}
                && {_moveGeneration == (_moveIntent getOrDefault ["operationGeneration",-2])}
                && {_moveGeneration == (_moveOperation getOrDefault ["generation",-2])}
                && {(_moveOperation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                && {(_moveOperation getOrDefault ["intent",""]) == _movementOwner}
                && {(_moveOperation getOrDefault ["phase",""]) != "CANCELLED"}
                && {waypointDescription _moveWaypoint == "CBE AI PASS"}
                && {count _movePosition >= 2}
                && {waypointPosition _moveWaypoint distance2D _movePosition <= 1}
                && {abs (((waypointPosition _moveWaypoint) param [2,0])-(_movePosition param [2,0])) <= 1.5}
                && {waypointType _moveWaypoint == (_moveIntent getOrDefault ["type",""])}
                && {abs (waypointCompletionRadius _moveWaypoint-(_moveIntent getOrDefault ["radius",-1])) <= 0.1};
            if (_routeOwned) then {
                private _rows=[_group,"",false,_moveWaypoint select 1] call CBE_fnc_AuthoredRouteReceipt;
                private _row=_rows param [0,[]];
                private _policy=if (count _row >= 7) then {[_row select 3,_row select [6]]} else {[]};
                _routeOwned=_policy isNotEqualTo []
                    && {_policy isEqualTo (_moveIntent getOrDefault ["nativePolicy",[]])};
            };
            // Passing the committed node is ordinary completion; an edited/replaced current or
            // future node is interruption and must never be reported as objective completion.
            _vehicleRouteChanged=!_reverseActive && {!_routeOwned}
                && {count _moveWaypoint != 2 || {(_moveWaypoint select 1) >= currentWaypoint _group}};
            if (_movementOwner == "VEHICLE_JINK") then {
                private _jinkCrew=_moveOperation getOrDefault ["vehicleJinkCrew",[]];
                _vehicleCrewChanged=!(_jinkCrew isEqualType []) || {count _jinkCrew != 2};
                if (!_vehicleCrewChanged) then {
                    _vehicleCrewChanged=!([_group,_jinkCrew select 0,_jinkCrew select 1] call CBE_fnc_CortexVehicleCrewAvailable);
                };
            };
            _activeVehicleMove = _reverseActive || {_routeOwned && {time < (_vehicleMove select 1)}};
            if (_vehicleCrewChanged) then {_activeVehicleMove=false};
            // Native selected standoff has no temporary group waypoint. Its independent
            // worker owns cleanup; the reference, including unresolved work, reserves it.
            if (_movementOwner == "VEHICLE_STANDOFF"
                && {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}) then {
                _activeVehicleMove=true;_vehicleRouteChanged=false;_vehicleCrewChanged=false;
            };

        };
        if (_vehicleFeatureDisabled) then {_activeVehicleMove=false};
        if (!_activeVehicleMove) then {
            private _finishedOwner=_vehicleMove param [0,""];
            private _generation=_state getOrDefault ["vehicleOperationGeneration",-1];
            if (_generation >= 0) then {
                if (_vehicleFeatureDisabled) then {
                    [_group,_generation,"FEATURE_DISABLED"] call CBE_fnc_OperationCancel;
                } else {if (_finishedOwner == "VEHICLE_ORIENT") then {
                    private _orientState=_state getOrDefault ["vehicleDangerOrient",[]];
                    private _orientVehicle=_orientState param [1,objNull,[objNull]];
                    private _orientMarker=if (!isNull _orientVehicle) then {
                        _orientVehicle getVariable ["CBE_Danger_VehicleOrient",[]]
                    } else {[]};
                    private _targetPosition=_orientMarker param [2,[],[[]]];
                    private _aligned=!isNull _orientVehicle && {count _targetPosition >= 2}
                        && {private _relative=_orientVehicle getRelDir _targetPosition;
                            _relative <= 20 || {_relative >= 340}};
                    if (_orientControllerExternal || {_orientDriverProtected} || {_orientCommanderProtected} || {_orientOrderChanged} || {_orientOperationChanged} || {_orientThreatInvalid} || {_orientInputChanged}
                        || {[_group] call CBE_fnc_CortexExternalTakeover}) then {
                        private _reason=if (_orientOperationChanged) then {"OPERATION_REPLACED"} else {
                            if (_orientOrderChanged) then {"NATIVE_ORDER_CHANGED"} else {
                                if (_orientInputChanged) then {"NATIVE_INPUT_CHANGED"} else {
                                    if (_orientThreatInvalid) then {"CONTACT_INVALID"} else {
                                        if (_orientCommanderProtected) then {"COMMANDER_TASK_OR_SEAT"} else {
                                            ["EXTERNAL_OWNER","DRIVER_TASK_OR_SEAT"] select _orientDriverProtected
                                        }
                                    }
                                }
                            }
                        };
                        [_group,_generation,_reason] call CBE_fnc_OperationCancel;
                    } else {
                        [_group,_generation,["INCOMPLETE","COMPLETE"] select _aligned,
                            ["VEHICLE_ORIENT_TIMEOUT","VEHICLE_ORIENT_ALIGNED"] select _aligned]
                            call CBE_fnc_OperationRelease;
                    };
                } else {
                    if (_vehicleCrewChanged) then {
                        [_group,_generation,"VEHICLE_CREW_CHANGED"] call CBE_fnc_OperationCancel;
                    } else {if (_vehicleRouteChanged) then {
                        [_group,_generation,"VEHICLE_ROUTE_REPLACED"] call CBE_fnc_OperationCancel;
                    } else {
                    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
                    private _position=_intent getOrDefault ["position",[]];
                    private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
                    private _arrived=count _position >= 2 && {!isNull _anchor}
                        && {vehicle _anchor distance2D _position <= (_intent getOrDefault ["radius",25])};
                    [_group,_generation,["INCOMPLETE","COMPLETE"] select _arrived,
                        ["VEHICLE_MOVE_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived] call CBE_fnc_OperationRelease;
                    };};
                };
                };
                _state deleteAt "vehicleOperationGeneration";
            };
            if (_finishedOwner == "VEHICLE_JINK") then {
                private _jinkState=_state getOrDefault ["vehicleDangerJink",[]];
                private _jinkVehicle=_jinkState param [1,objNull,[objNull]];
                if (!isNull _jinkVehicle && {local _jinkVehicle}) then {
                    private _marker=_jinkVehicle getVariable ["CBE_Danger_VehicleJink",[]];
                    if (_marker param [1,grpNull,[grpNull]] == _group
                        && {_generation >= 0} && {(_marker param [4,-1,[0]]) == _generation}) then {
                        _jinkVehicle setVariable ["CBE_Danger_VehicleJink",nil,true];
                    };
                };
            };
            if (_finishedOwner == "VEHICLE_ORIENT") then {
                [_group,"RELEASE"] call CBE_fnc_VehicleTurnRetire;
                _state deleteAt "vehicleDangerOrient";
            };
            [_group,_finishedOwner,false] call CBE_fnc_CortexOwnershipLease;
            _state deleteAt "movementLease";
        };
    } else {
        // The group tick has already validated direct tactical/support owners.
        // Yield to them without requiring a waypoint or deleting their lease.
        _activeVehicleMove = count _vehicleMove == 2 && {time < (_vehicleMove select 1)};
    };
};
// Movement ownership blocks only another destination. Reporting, dismount handling and
// gunnery remain composable for the duration of the physical move.
private _movementOwned = _activeVehicleMove
    || {(_group getVariable ["CBE_VehicleTurn_Work",createHashMap]) isNotEqualTo createHashMap}
    || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []};
if (_lifecycleOnly) exitWith {_movementOwned};
private _vehicles = [];
{
    private _vehicle = vehicle _x;
    if (_vehicle != _x && {alive _x} && {!(_vehicle in _vehicles)} ) then {_vehicles pushBack _vehicle};
} forEach units _group;
private _externalTakeover=[_group] call CBE_fnc_CortexExternalTakeover;
private _unloadPolicyVehicles=[];
if (!_externalTakeover
    && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_VehicleDismount_Enable",true] call CBE_fnc_CortexFeatureEnabled}) then {
    _unloadPolicyVehicles=_vehicles select {
        private _vehicle=_x;
        local _vehicle && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")}
            && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
            && {effectiveCommander _vehicle in units _group}
            && {(fullCrew [_vehicle,"",false]) findIf {
                private _unit=_x select 0;
                private _role=_x select 1;
                alive _unit && {!isPlayer _unit}
                    && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
            } >= 0}
    };
};
// Reconcile the public tracked set before any early return. This also releases a vehicle whose
// commander dismounted, whose passengers left, which entered convoy control, or whose feature gate
// closed. External takeover clears proof without restoring a value into the new owner's task.
{
    if (local _x && {!(_x in _unloadPolicyVehicles)}) then {
        [_x,_group,"RELEASE",!_externalTakeover] call CBE_fnc_CortexVehicleUnloadPolicy;
    };
} forEach +(_group getVariable ["CBE_Cortex_UnloadPolicyVehicles",[]]);
{
    [_x,_group,"ACQUIRE"] call CBE_fnc_CortexVehicleUnloadPolicy;
} forEach _unloadPolicyVehicles;
if (_vehicles isEqualTo []) exitWith {_movementOwned};
// Vehicle contact work can select an escape route or rank targets before it reaches the local
// crew command. A newer curator, player or specialist owner must win at that point rather than
// being followed by a stale forced speed, dismount, withdrawal or gunner request.
private _mayIssueVehicle = {
    !([_group] call CBE_fnc_CortexExternalTakeover)
};
// A live combined ground role owns this group's scripted ground targeting. Routine
// gunnery must not retarget its support gun or fire before manoeuvre arrival. This is
// reservation scope only: natural engine engagement, smoke and passenger safety remain available.
private _combinedGroundRole=_group getVariable ["CBE_Cortex_CombinedRole",[]];
private _combinedGroundFireOwned=_combinedGroundRole isEqualType []
    && {count _combinedGroundRole in [7,8]}
    && {(_combinedGroundRole select 4) in ["GROUND_FIRE","GROUND_MANOEUVRE"]}
    && {(_combinedGroundRole select 5) isEqualType 0} && {finite (_combinedGroundRole select 5)}
    && {serverTime < (_combinedGroundRole select 5)};
if (!_combinedGroundFireOwned) then {_state deleteAt "vehicleStandoffYield"};
private _tacticalCommandActors=[];
private _tacticalFireUnknown=false;
private _tacticalReference=_group getVariable ["CBE_VehicleTacticalMove_Reference",[]];
if (_tacticalReference isNotEqualTo []) then {
    _tacticalFireUnknown=true;
    if (_tacticalReference isEqualType [] && {count _tacticalReference == 5}) then {
        private _tacticalPlatform=_tacticalReference param [0,objNull,[objNull]];
        private _tacticalWork=if (isNull _tacticalPlatform) then {createHashMap} else {
            _tacticalPlatform getVariable ["CBE_VehicleTacticalMove_Work",createHashMap]
        };
        private _tacticalCrew=_tacticalWork getOrDefault ["crew",[]];
        if ((_tacticalWork getOrDefault ["reference",[]]) isEqualTo _tacticalReference
            && {_tacticalCrew isEqualType []} && {count _tacticalCrew == 2}) then {
            _tacticalCommandActors=+_tacticalCrew;_tacticalFireUnknown=false;
        };
    };
};
private _crewActorAvailable={
    params ["_vehicle","_gunner"];
    !_tacticalFireUnknown && {!(_gunner in _tacticalCommandActors)}
        && {!isNull _gunner} && {local _gunner} && {group _gunner == _group}
        && {[_gunner] call CBE_fnc_CortexCombatEffective}
        && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
        && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
        && {isNull (_gunner getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {([_gunner] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_gunner] call CBE_fnc_CompatibilityExternalControl)}
        && {[_gunner] call CBE_fnc_CortexActorFireTaskAvailable}
};
if (_externalTakeover) exitWith {_movementOwned};
if !([] call _mayIssueVehicle) exitWith {_movementOwned};
// Shared dismount path for identified contact and a bounded targetless danger lease. It owns only
// the stop request and local passenger exit. It never creates target knowledge or vehicle movement.
private _dismountAtThreat = {
    params ["_vehicle","_threatPosition",["_publishDanger",false,[true]]];
    if !(_vehicle isKindOf "LandVehicle" && {!(_vehicle isKindOf "StaticWeapon")}
        && {_vehicle distance2D _threatPosition < 400}
        && {[_group,"CBE_AIPass_VehicleDismount_Enable",true] call CBE_fnc_CortexFeatureEnabled}) exitWith {};
    private _commandsVehicle=effectiveCommander _vehicle in units _group;
    if (_publishDanger && {_commandsVehicle} && {local _vehicle}
        && {(fullCrew [_vehicle,"",false]) findIf {
            private _unit=_x select 0;
            private _role=_x select 1;
            alive _unit && {group _unit != _group} && {side group _unit == side _group}
                && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
        } >= 0}) then {
        // The crew cannot command another group out. Publish only bounded hazard geometry so the
        // passenger owner can run the same safety checks without receiving target knowledge.
        _vehicle setVariable ["CBE_Cortex_OnboardDanger",[_group,groupOwner _group,+_threatPosition,serverTime+30],true];
    };
    // A combined crew/passenger group has no cross-group report consumer. The same bounded
    // handshake safely stops it. A separate passenger group publishes the request for the crew
    // owner's next tick and handles only its locally owned passengers.
    private _onboardCargo=(fullCrew [_vehicle,"",false]) select {
        private _unit=_x select 0;
        private _role=_x select 1;
        alive _unit && {group _unit == _group}
            && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
    };
    if (_onboardCargo isNotEqualTo []) then {
        _vehicle setVariable ["CBE_Cortex_DismountStopRequest",[_group,groupOwner _group,serverTime+30],true];
        if (_commandsVehicle && {local _vehicle}) then {
            [_vehicle,_group,"ACQUIRE"] call CBE_fnc_CortexDismountStop;
        };
    };
    private _cargo=(crew _vehicle) select {
        group _x == _group && {[_x,_vehicle] call CBE_fnc_CortexPassengerReady}
    };
    if (_cargo isNotEqualTo []) then {
        private _dismounted=_state getOrDefault ["dismounted",[]];
        {
            private _unit=_x;
            // Publish ownership before GetOut handlers can observe the command.
            if (_dismounted findIf {(_x select 0) == _unit} < 0) then {
                _dismounted pushBack [_unit,_vehicle];
                _group setVariable ["CBE_Cortex_DismountContinuation",[serverTime+60,
                    _group getVariable ["CBE_OperationGeneration",0],+_dismounted,
                    [_group] call CBE_fnc_NativeOrderReceipt],true];
            };
            _state set ["dismounted", _dismounted];
            if ([] call _mayIssueVehicle && {toUpperANSI (currentCommand _unit) != "GET OUT"}) then {
                [_unit] orderGetIn false;
                unassignVehicle _unit;
                doGetOut _unit;
            };
        } forEach _cargo;
        _state set ["dismounted", _dismounted];
    };
};
// Cross-group safe-stop handshake. The passenger owner publishes only an expiring identity request;
// the vehicle authority validates current occupants and changes speed locally. This avoids remote
// driver commands, unsafe moving exits and permanent stops after an interrupted/expired handover.
{
    private _vehicle=_x;
    private _request=_vehicle getVariable ["CBE_Cortex_DismountStopRequest",[]];
    private _valid=false;
    if (count _request == 3 && {local _vehicle} && {effectiveCommander _vehicle in units _group}) then {
        _request params ["_passengerGroup","_passengerOwner","_requestExpiry"];
        _valid=_passengerGroup isEqualType grpNull && {!isNull _passengerGroup}
            && {_passengerOwner isEqualType 0} && {_requestExpiry isEqualType 0}
            && {groupOwner _passengerGroup == _passengerOwner}
            && {side _passengerGroup == side _group}
            && {serverTime < _requestExpiry} && {_requestExpiry <= serverTime+30}
            && {(fullCrew [_vehicle,"",false]) findIf {
                private _unit=_x select 0;
                private _role=_x select 1;
                alive _unit && {group _unit == _passengerGroup}
                    && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
            } >= 0 || {
                private _continuation=_passengerGroup getVariable ["CBE_Cortex_DismountContinuation",[]];
                private _crewProof=_vehicle getVariable ["CBE_Cortex_DismountStopOrder",[]];
                count _continuation == 4 && {count _crewProof == 2}
                    && {(_continuation select 0) isEqualType 0} && {(_continuation select 1) isEqualType 0}
                    && {(_continuation select 2) isEqualType []} && {(_continuation select 3) isEqualType []}
                    && {serverTime < (_continuation select 0)} && {(_continuation select 0) <= serverTime+60}
                    && {(_continuation select 1) == (_passengerGroup getVariable ["CBE_OperationGeneration",0])}
                    && {(_continuation select 3) isEqualTo ([_passengerGroup] call CBE_fnc_NativeOrderReceipt)}
                    && {_crewProof isEqualTo [_group getVariable ["CBE_OperationGeneration",0],
                        [_group] call CBE_fnc_NativeOrderReceipt]}
                    && {!_movementOwned} && {!([_passengerGroup] call CBE_fnc_CortexExternalTakeover)}
                    && {[_passengerGroup,"CBE_AIPass_VehicleRemount_Enable",true] call CBE_fnc_CortexFeatureEnabled}
                    && {((_continuation select 2) select [0,8]) findIf {
                        if !(_x isEqualType [] && {count _x == 2}
                            && {(_x select 0) isEqualType objNull} && {(_x select 1) isEqualType objNull}) exitWith {false};
                        _x params ["_unit","_originalVehicle"];
                        alive _unit && {group _unit == _passengerGroup} && {_originalVehicle == _vehicle}
                            && {isNull objectParent _unit} && {_unit distance2D _vehicle <= 100}
                            && {isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}}
                    } >= 0}
            } || {
                private _boarding=_passengerGroup getVariable ["CBE_Cortex_Remount",[]];
                _boarding isEqualType [] && {count _boarding == 2}
                    && {(_boarding select 0) isEqualType 0} && {(_boarding select 1) isEqualType []}
                    && {serverTime < (_boarding select 0)} && {(_boarding select 0) <= serverTime+60}
                    && {!_movementOwned} && {_enemies isEqualTo []}
                    && {!([_passengerGroup] call CBE_fnc_CortexExternalTakeover)}
                    && {[_passengerGroup,"CBE_AIPass_VehicleRemount_Enable",true] call CBE_fnc_CortexFeatureEnabled}
                    && {((_boarding select 1) select [0,8]) findIf {
                        if !(_x isEqualType [] && {count _x == 2}
                            && {(_x select 0) isEqualType objNull} && {(_x select 1) isEqualType objNull}) exitWith {false};
                        _x params ["_unit","_originalVehicle"];
                        !isNull _unit && {alive _unit} && {group _unit == _passengerGroup}
                            && {_originalVehicle == _vehicle} && {isNull objectParent _unit}
                            && {_unit distance2D _vehicle <= 100}
                            && {isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}}
                    } >= 0}
            }};
    };
    if (_valid) then {
        [_vehicle,_group,"ACQUIRE"] call CBE_fnc_CortexDismountStop;
    } else {
        [_vehicle,_group,"RELEASE",true] call CBE_fnc_CortexDismountStop;
        if (_request isNotEqualTo []) then {_vehicle setVariable ["CBE_Cortex_DismountStopRequest",nil,true]};
    };
} forEach _vehicles;
private _dangerDismount=_state getOrDefault ["dangerDismount",[]];
if (_dangerDismount isNotEqualTo []) then {
    if (count _dangerDismount == 9) then {
        _dangerDismount params ["_dangerPosition","_dangerExpiry","_dangerProfile","_dangerCause",
            "_dangerVehicle","_dangerSource","_dangerGeneration","_dangerSourceUntil","_dangerWitness"];
        // The current danger producer always carries the exact occupied platform. Never recover a
        // stale or malformed record by widening it to every vehicle in the group: one engine event
        // must not stop, unload, abandon or turn unrelated platforms in a mixed vehicle element.
        if (time < _dangerExpiry && {!isNull _dangerVehicle} && {_dangerVehicle in _vehicles}) then {
            private _affectedVehicles=[_dangerVehicle];
            private _dangerHostile=_dangerSourceUntil isEqualType 0 && {finite _dangerSourceUntil}
                && {time < _dangerSourceUntil} && {!isNull _dangerSource} && {alive _dangerSource}
                && {!captive _dangerSource}
                && {!(_dangerSource getVariable ["ace_captives_isSurrendering",false])}
                && {!(_dangerSource getVariable ["ace_captives_isHandcuffed",false])}
                && {(side _group) getFriend (side _dangerSource) < 0.6}
                && {[_dangerWitness] call CBE_fnc_CortexCombatEffective}
                && {local _dangerWitness} && {group _dangerWitness == _group}
                && {_dangerWitness knowsAbout _dangerSource > 0}
                && {!((_dangerWitness targetKnowledge _dangerSource) param [7,false,[true]])};
            // A safety alert can outlive source identity, but never renew that identity or
            // obtain hidden exact range from the enemy object after the native handoff.
            private _dangerBelief=if (_dangerHostile) then {_dangerWitness getHideFrom _dangerSource} else {[]};
            private _dangerBeliefValid=count _dangerBelief == 3 && {_dangerBelief isNotEqualTo [0,0,0]}
                && {_dangerBelief findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
            // Targetless damage and incoming rounds justify passenger safety. Other vehicle danger
            // causes may unload only when they retain a real hostile already known by this group.
            // Merely classifying a mounted callback never fabricates a contact or empties a carrier.
            if (_dangerProfile in ["TRANSPORT","ARMED","ARMOURED"]
                && {_dangerCause in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"] || {_dangerHostile}}) then {
                {[_x,_dangerPosition,true] call _dismountAtThreat} forEach _affectedVehicles;
            };
            {
                private _vehicle=_x;
                private _knownCloseThreat=_dangerHostile
                    && {_dangerBeliefValid} && {_vehicle distance2D _dangerBelief < 25};
                private _emplacementUnsafe=_dangerProfile in ["STATIC","ARTILLERY"]
                    && {!someAmmo _vehicle || {_knownCloseThreat}}
                    && {!(_vehicle isKindOf "Tank" && {count (allTurrets [_vehicle,false]) > 1})};
                private _disabledUnsafe=!(_vehicle isKindOf "StaticWeapon")
                    && {_dangerCause in ["HIT","EXPLOSION"]}
                    && {!canMove _vehicle || {damage _vehicle >= 0.85}};
                if ((_emplacementUnsafe || {_disabledUnsafe}) && {local _vehicle} && {[] call _mayIssueVehicle}) then {
                    // Abandon only the exact locally owned platform which generated the response. This
                    // is a terminal crew-safety action, not the ordinary passenger contact dismount:
                    // a mobile useful gun retains its route and crew, while an empty emplacement, a
                    // close overrun or a disabled wreck releases its own living AI occupants.
                    {
                        // Scripted abandonment respects the same individual authority as gunnery.
                        // Native emergency bailouts do not depend on this contact action.
                        if ([_vehicle,_x] call _crewActorAvailable
                            && {toUpperANSI currentCommand _x != "STOP"}) then {
                            [_x] orderGetIn false;
                            unassignVehicle _x;
                            doGetOut _x;
                        };
                    } forEach crew _vehicle;
                    _vehicle setVariable ["CBE_Danger_AbandonReason",
                        [["DISABLED","EMPLACEMENT"] select _emplacementUnsafe,_dangerCause,serverTime],true];
                };
                // An intact armed platform should not sit inert while its effective commander already
                // knows the hostile which caused this exact native danger response. Orient and request
                // one bounded suppression action, but retain the current route, speed and waypoint.
                // The generation record prevents the shared scheduler from repeating the command every
                // contact tick; ordinary native/CBE gunnery owns subsequent target decisions.
                private _reaction=_state getOrDefault ["vehicleDangerReaction",[]];
                private _gunner=gunner _vehicle;
                private _crewRecovery=_state getOrDefault ["vehicleDangerCrewRecovery",[]];
                private _freshCrewRecovery=_dangerGeneration >= 0
                    && {_crewRecovery param [0,-2,[0]] != _dangerGeneration};
                if (_freshCrewRecovery && {_dangerHostile}
                    && {_dangerProfile in ["ARMED","ARMOURED"]}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}) then {
                    private _crewRecoveryIssued=[_group,_vehicle,_dangerSource,_dangerCause,_dangerGeneration]
                        call CBE_fnc_CortexVehicleCrewRecover;
                    // Record both acceptance and refusal for this generation. An impossible seat
                    // change must not be reconsidered every scheduler tick during the same danger.
                    _state set ["vehicleDangerCrewRecovery",
                        [_dangerGeneration,_vehicle,_crewRecoveryIssued,serverTime]];
                    if (_crewRecoveryIssued) then {_gunner=gunner _vehicle};
                };
                private _knownHostile=_dangerHostile
                    && {!isNull _gunner} && {alive _gunner} && {local _gunner} && {!isPlayer _gunner}
                    && {(effectiveCommander _vehicle) in units _group}
                    && {(effectiveCommander _vehicle) knowsAbout _dangerSource > 0}
                    && {_dangerProfile in ["STATIC","ARMED","ARMOURED"]};
                private _freshGeneration=_dangerGeneration >= 0
                    && {_reaction param [0,-2,[0]] != _dangerGeneration};
                // Defensive smoke is independent from the gunner response: consuming one must not
                // suppress the other. Record the generation even when no compatible loaded launcher
                // exists, so a two-second danger lease cannot repeat the same inventory/config scan.
                // BLUE/GREEN, convoy, player, Zeus and specialist ownership remain authoritative.
                private _countermeasureReaction=_state getOrDefault ["vehicleDangerCountermeasure",[]];
                private _freshCountermeasureGeneration=_dangerGeneration >= 0
                    && {_countermeasureReaction param [0,-2,[0]] != _dangerGeneration};
                if (_freshCountermeasureGeneration
                    && {_dangerProfile in ["ARMED","ARMOURED"]}
                    && {_dangerCause in ["HIT","EXPLOSION","SUPPRESSED"]}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {combatMode _group in ["YELLOW","RED"]}
                    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
                    && {[] call _mayIssueVehicle}) then {
                    private _countermeasureFired=[_vehicle] call CBE_fnc_CortexFireCountermeasure;
                    _state set ["vehicleDangerCountermeasure",[_dangerGeneration,_vehicle,_countermeasureFired,serverTime]];
                    _vehicle setVariable ["CBE_Danger_VehicleCountermeasure",
                        [_dangerGeneration,effectiveCommander _vehicle,_dangerSource,serverTime,_countermeasureFired],true];
                };
                // A close hostile or severe incoming danger may justify one short escape by an
                // otherwise intact fighting vehicle. The helper owns one 25-second operation and
                // refuses convoys, passengers, foot elements and any existing movement owner.
                private _jink=_state getOrDefault ["vehicleDangerJink",[]];
                private _freshJinkGeneration=_dangerGeneration >= 0
                    && {_jink param [0,-2,[0]] != _dangerGeneration};
                if (_freshJinkGeneration && {_dangerProfile in ["ARMED","ARMOURED"]}
                    && {_dangerCause in ["HIT","EXPLOSION"] || {_knownCloseThreat}}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}) then {
                    private _jinkStarted=[_group,_state,_vehicle,_dangerPosition,_dangerSource,_dangerGeneration]
                        call CBE_fnc_CortexVehicleJink;
                    _state set ["vehicleDangerJink",[_dangerGeneration,_vehicle,_jinkStarted,serverTime]];
                    if (_jinkStarted) then {_movementOwned=true};
                };
                // A stopped tracked fighting vehicle can turn its hull toward the exact known
                // hostile without receiving a destination. This runs after the more urgent escape
                // decision: a jink or any other movement owner refuses the orientation operation.
                private _orient=_state getOrDefault ["vehicleDangerOrient",[]];
                private _freshOrientGeneration=_dangerGeneration >= 0
                    && {_orient param [0,-2,[0]] != _dangerGeneration};
                if (_freshOrientGeneration && {_knownHostile} && {_dangerProfile == "ARMOURED"}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {_dangerCause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE","SUPPRESSED"]}) then {
                    private _orientStarted=[_group,_state,_vehicle,_dangerPosition,_dangerSource,_dangerGeneration]
                        call CBE_fnc_CortexVehicleOrient;
                    _state set ["vehicleDangerOrient",[_dangerGeneration,_vehicle,_orientStarted,serverTime]];
                    if (_orientStarted) then {_movementOwned=true};
                };
                // A useful static mortar answers the same real, known hostile through the finite
                // artillery mission owner. The server revalidates locality, knowledge, allegiance,
                // ammunition, range and friendly safety; this call never fires a shell directly.
                // Recording the generation before dispatch prevents one danger event from queuing
                // repeatedly while the server accepts or rejects the request.
                if (_dangerProfile == "ARTILLERY" && {_dangerHostile} && {_dangerBeliefValid} && {_freshGeneration}
                    && {_vehicle isKindOf "StaticMortar"} && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}
                    && {combatMode _group in ["YELLOW","RED"]}
                    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
                    && {[] call _mayIssueVehicle}) then {
                    _state set ["vehicleDangerReaction",[_dangerGeneration,_vehicle,_dangerSource,serverTime]];
                    _vehicle setVariable ["CBE_Danger_VehicleReaction",[_dangerGeneration,_gunner,_dangerSource,serverTime],true];
                    [_vehicle,+_dangerBelief,25,"HE",1,false,"DANGER",objNull,_dangerSource,grpNull,serverTime] call CBE_fnc_CortexArtilleryFire;
                };
                if (_knownHostile && {_freshGeneration} && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {!(_vehicle isKindOf "LandVehicle") || {!_combinedGroundFireOwned}}
                    && {[_vehicle,_gunner] call _crewActorAvailable}
                    && {canFire _vehicle}
                    && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}
                    && {combatMode _group in ["YELLOW","RED"]}
                    && {unitCombatMode _gunner in ["YELLOW","RED"]}
                    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
                    && {[] call _mayIssueVehicle}) then {
                    // Knowledge authorizes an estimate, not the hidden object's exact pose.
                    // Use the same native believed ATL contract as CortexKnowledge.
                    private _believed=(effectiveCommander _vehicle) getHideFrom _dangerSource;
                    private _aimPosition=(ATLToASL _believed) vectorAdd [0,0,1];
                    private _dangerFireObservation=createHashMap;
                    private _dangerGround=_vehicle isKindOf "LandVehicle";
                    private _engaging=getAttackTarget _gunner;
                    private _assigned=assignedTarget _gunner;
                    // A point estimate is suppression, not authority to spend an arbitrary
                    // explosive round. Preserve native engagements and the existing burst hold.
                    private _dangerSuppressionReady=_believed isNotEqualTo [0,0,0] && {
                        !_dangerGround || {
                            abs speed _vehicle < 30 && {_vehicle distance2D _believed >= 50}
                                && {toUpperANSI currentCommand _gunner != "SUPPRESS"}
                                && {time >= (_gunner getVariable ["CBE_AIPass_TargetHold",0])}
                                && {isNull _engaging || {_engaging == _dangerSource}}
                                && {isNull _assigned || {_assigned == _dangerSource}}
                                && {!terrainIntersectASL [eyePos _gunner,_aimPosition]}
                                && {[_vehicle,_gunner,_dangerSource,_dangerFireObservation,false,true] call CBE_fnc_CortexGroundFireReady}
                        }
                    };
                    if (_dangerSuppressionReady
                        && {[_gunner,_aimPosition] call CBE_fnc_CortexLineOfFireClear}
                        && {[] call _mayIssueVehicle}) then {
                        private _muzzleSelected=!_dangerGround
                            || {[_vehicle,_gunner,_dangerFireObservation] call CBE_fnc_CortexGroundSelectMuzzle};
                        if (_muzzleSelected) then {
                            // Watching consumes ground-relative position; suppression consumes ASL.
                            _gunner doWatch (ASLToAGL _aimPosition);
                            _gunner doSuppressiveFire _aimPosition;
                            if (_dangerGround) then {_gunner setVariable ["CBE_AIPass_TargetHold",time + 8]};
                            _state set ["vehicleDangerReaction",[_dangerGeneration,_vehicle,_dangerSource,serverTime]];
                            _vehicle setVariable ["CBE_Danger_VehicleReaction",[_dangerGeneration,_gunner,_dangerSource,serverTime],true];
                        };
                    };
                };
            } forEach _affectedVehicles;
        } else {
            _state deleteAt "dangerDismount";
        };
    } else {
        _state deleteAt "dangerDismount";
    };
};
if (_enemies isEqualTo []) exitWith {_movementOwned};
// One additional bounded native-knowledge pass shared by eligible platforms. Probe two
// rotating roster slots for custom-category air-capable stations; native AA retains its role.
private _airContacts=[];private _airContactsRead=false;
// Transient allocation hints only: sixteen native-AA platforms, one native engagement
// observation each. Include held native engagements; never treat an old CBE intent as fire.
// No persistent reservation survives this callback or a locality/operation change.
private _aaAllocationVehicles=(_vehicles select [0,16]) select {
    toLower getText (configOf _x >> "editorSubcategory") == "edsubcat_aas"
};
private _aaEngagements=[];
private _airProbeCount=(count _vehicles) max 1;
private _airProbeStart=(_state getOrDefault ["airGunneryProbeCursor",0]) mod _airProbeCount;
private _airProbeSlots=[_airProbeStart,(_airProbeStart+1) mod _airProbeCount];
_state set ["airGunneryProbeCursor",(_airProbeStart+2) mod _airProbeCount];
private _airRange=missionNamespace getVariable ["CBE_AIPass_EngageRange",800];
private _enemyPos = (_enemies select 0) select 1;
private _selectVehicleEscape = {
    params ["_vehicle","_threatPosition","_threatObject","_distance",["_requireScreenedEndpoint",false]];
    private _origin=getPosATL _vehicle;
    private _awayBearing=_threatPosition getDir _origin;
    private _candidates=[];
    {
        _candidates pushBack [_origin getPos [_distance,_awayBearing+_x]];
    } forEach [0,-25,25,-45,45];
    private _selected=[_origin,_candidates,_threatPosition,[],_threatObject,"VEHICLE",_vehicle,_requireScreenedEndpoint]
        call CBE_fnc_CortexSelectAvenue;
    if (_selected isEqualTo []) then {[]} else {_selected select ((count _selected)-1)}
};
private _withdrawn = +(_state getOrDefault ["withdrawn", []]);
{
    private _vehicle = _x;
    private _vehicleIndex=_forEachIndex;
    private _distance = _vehicle distance2D _enemyPos;
    private _commandsVehicle = effectiveCommander _vehicle in units _group;
    // Onboard reports carry no target object or reveal. Only the actual vehicle authority
    // publishes, at most once per five seconds and only when another squad is aboard.
    if (_commandsVehicle && {local _vehicle} && {_vehicle isKindOf "LandVehicle"}
        && {(_enemies select 0) select 2 <= 10}
        && {serverTime >= (_vehicle getVariable ["CBE_Cortex_OnboardReportDue",-1])}
        && {(crew _vehicle) findIf {alive _x && {group _x != _group} && {side group _x == side _group}} >= 0}) then {
        private _reportedPosition=[25*round ((_enemyPos select 0)/25),25*round ((_enemyPos select 1)/25),0];
        // The far scheduler tier is 20 seconds. A shorter report could expire between the
        // independently scheduled crew and passenger jobs and make a valid handover impossible.
        _vehicle setVariable ["CBE_Cortex_OnboardReport",[_group,groupOwner _group,_reportedPosition,serverTime+35],true];
        _vehicle setVariable ["CBE_Cortex_OnboardReportDue",serverTime+5];
    };
    [_vehicle,_enemyPos,false] call _dismountAtThreat;
    // Horns and countermeasure launchers are CfgWeapons entries too; only a real weapon makes a
    // vehicle "armed", so an unarmed truck is never treated as having lost its guns. Read live (and
    // only once canFire already says no), because Vehicle Weapon Loadout can change a vehicle's guns.
    private _hasRealWeapon = {
        ([[-1]] + allTurrets [_vehicle, true]) findIf {
            (_vehicle weaponsTurret _x) findIf {
                private _weaponConfig = configFile >> "CfgWeapons" >> _x;
                !(_x isKindOf ["CarHorn",configFile >> "CfgWeapons"])
                && {!(toLowerANSI getText (_weaponConfig >> "simulation") in ["carhorn","cmlauncher"])}
            } >= 0
        } >= 0
    };
    if (_commandsVehicle && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}} && {_vehicle isKindOf "LandVehicle"} && {[_group, "CBE_AIPass_VehicleWithdraw_Enable", true] call CBE_fnc_CortexFeatureEnabled} && {local _vehicle} && {alive _vehicle} && {canMove _vehicle} && {!(_vehicle in _withdrawn)} && {_distance < 800}
        && {serverTime >= (_vehicle getVariable ["CBE_Cortex_WithdrawRetryAt",0])}
        && {damage _vehicle >= 0.5 || {!canFire _vehicle && {call _hasRealWeapon}}}) then {
        // A rejected route is not a completed withdrawal. Reconsider sparsely after geometry
        // or ownership changes; no every-tick replanning or repeated smoke request.
        _vehicle setVariable ["CBE_Cortex_WithdrawRetryAt",serverTime+8,true];
        if ((units _group) findIf {alive _x && {vehicle _x == _x}} < 0) then {
            private _threat=(_enemies select 0) select 0;
            private _away=[_vehicle,_enemyPos,_threat,300] call _selectVehicleEscape;
            if (_away isNotEqualTo [] && {[] call _mayIssueVehicle} && {[_group,"VEHICLE_WITHDRAW",true,serverTime+120] call CBE_fnc_CortexOwnershipLease}) then {
                private _operation=[_group,"VEHICLE_WITHDRAW",_threat,[],[_away],"MOVING"] call CBE_fnc_OperationStart;
                if (count _operation == 0) then {
                    [_group,"VEHICLE_WITHDRAW",false] call CBE_fnc_CortexOwnershipLease;
                } else {
                    [_vehicle] call CBE_fnc_CortexFireCountermeasure;
                    private _reverse=[_group,_state,_vehicle,_enemyPos,"START",_operation get "generation"] call CBE_fnc_CortexVehicleReverseStep;
                    private _withdrawStarted=false;
                    isNil {
                        private _current=_group getVariable ["CBE_Operation",createHashMap];
                        private _sameOwner=local _group && {local _vehicle}
                            && {(_group getVariable ["CBE_AIPass_State",createHashMap]) isEqualTo _state}
                            && {(_current getOrDefault ["generation",-1]) == (_operation get "generation")}
                            && {(_current getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                            && {(_current getOrDefault ["intent",""]) == "VEHICLE_WITHDRAW"}
                            && {(_current getOrDefault ["phase",""]) != "CANCELLED"}
                            && {[] call _mayIssueVehicle};
                        if (_sameOwner) then {
                            private _reverseNow=_group getVariable ["CBE_VehicleReverse",[]];
                            private _moveAccepted=_reverse == "REVERSE" && {count _reverseNow == 9}
                                && {(_reverseNow select 0) == _vehicle}
                                && {(_reverseNow select 1) == (_operation get "generation")}
                                && {(_reverseNow select 2) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                                && {(_vehicle getVariable ["CBE_VehicleReverseOwner",[]]) isEqualTo [_group,_operation get "generation"]};
                            if (_reverse == "FALLBACK") then {
                                if (_reverseNow isEqualTo []) then {
                                    private _fallback=[_group, _away, 40,"MOVE",_operation get "generation"] call CBE_fnc_CortexGroupMove;
                                    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
                                    _moveAccepted=count _fallback == 2 && {(_fallback select 0) == _group}
                                        && {(_fallback select 1) >= 0}
                                        && {(_intent getOrDefault ["waypoint",[]]) isEqualTo _fallback}
                                        && {(_intent getOrDefault ["operationGeneration",-1]) == (_operation get "generation")};
                                };
                            };
                            _current=_group getVariable ["CBE_Operation",createHashMap];
                            if (_moveAccepted && {(_current getOrDefault ["phase",""]) != "CANCELLED"}
                                && {(_current getOrDefault ["generation",-1]) == (_operation get "generation")}
                                && {(_current getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
                                _withdrawn pushBackUnique _vehicle;
                                _state set ["withdrawn",_withdrawn];
                                _state set ["movementLease",["VEHICLE_WITHDRAW",(_operation get "startedAt")+120]];
                                _state set ["vehicleOperationGeneration",_operation get "generation"];
                                private _origin = getPosATL _vehicle;
                                _state set ["retreatStart",_origin];
                                _state set ["retreatTarget",_away];
                                _state set ["retreatProgress",[time,0,0]];
                                _group setVariable ["CBE_Cortex_Withdrawal",["MOVING",0,0],true];
                                _group setVariable ["CBE_Cortex_WithdrawalIntent",["VEHICLE",_origin,_away,_enemyPos,
                                    serverTime-((time-(_operation get "startedAt")) max 0),0,0],true];
                                _group setVariable ["CBE_Cortex_WithdrawalOrder",[
                                    (_group getVariable ["CBE_Cortex_WithdrawalIntent",[]]) select 4,
                                    [_group] call CBE_fnc_NativeOrderReceipt],true];
                                _movementOwned = true;
                                [_group,_state,"RETREAT","VEHICLE_DISABLED",time] call CBE_fnc_CortexSetPhase;
                                _withdrawStarted=true;
                            };
                        };
                    };
                    if (!_withdrawStarted) then {
                        isNil {
                            private _current=_group getVariable ["CBE_Operation",createHashMap];
                            if (local _group && {(_current getOrDefault ["generation",-1]) == (_operation get "generation")}
                                && {(_current getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
                                private _retired=[_group,_operation get "generation","INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
                                private _ended=_group getVariable ["CBE_OperationResult",[]];
                                private _cancelled=count _ended == 5 && {(_ended select 2) == (_operation get "generation")}
                                    && {(_ended select 1) in ["CANCELLED","INCOMPLETE"]};
                                if ((_retired || {_cancelled}) && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}) then {
                                    [_group,"VEHICLE_WITHDRAW",false] call CBE_fnc_CortexOwnershipLease;
                                };
                            };
                        };
                    };
                };
            };
        };
    };
    // Gunner priorities and standoff (CBE_AIPass_VehicleGunnery_Enable): anti-tank infantry
    // first, then armour, then everything else; armour keeps its distance from known AT teams.
    // Reports older than3s use fixed-position bullet suppression within the existing15s window.
    // A real main-cannon Fired receipt may request one short screened move while idle;
    // its original20s deadline and current mission/native order authority remain mandatory.
    if (_commandsVehicle && {alive _vehicle} && {[_group, "CBE_AIPass_VehicleGunnery_Enable", true] call CBE_fnc_CortexFeatureEnabled}) then {
        private _standoffSeats=[driver _vehicle,effectiveCommander _vehicle];
        private _standoff = missionNamespace getVariable ["CBE_AIPass_Vehicles_StandoffDistance", 250];
        private _postShot=[];private _postShotIndex=-1;
        if ((_vehicle isKindOf "Tank" || {_vehicle isKindOf "Wheeled_APC_F"})
            && {!_movementOwned} && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
            && {_state getOrDefault ["phase",""] == "CONTACT"}
            && {_standoffSeats findIf {isNull _x || {!(currentCommand _x in ["","WAIT"])}} < 0}
            && {!([_state,"armourCover"] call CBE_fnc_CortexCooldown)}) then {
            _postShot=[_vehicle,"TAKE"] call CBE_fnc_VehicleArmourShot;
            if (count _postShot == 4) then {
                [_state,"armourCover",20] call CBE_fnc_CortexCooldown;
                _postShotIndex=_enemies findIf {(_x select 0) == (_postShot select 0) && {(_x select 2) <= 3}};
            };
        };
        private _atIndex = _enemies findIf {
            (_x select 0) isKindOf "CAManBase" && {(_x select 2) <= 30} && {(_vehicle distance2D (_x select 1)) < _standoff * 0.6}
            && {"AT" in ([_x select 0,true] call CBE_fnc_CortexCapabilities)}
        };
        private _postShotMove=_atIndex < 0 && {_postShotIndex >= 0};
        if (!_movementOwned && {_state getOrDefault ["phase",""] == "CONTACT"} && {_atIndex >= 0 || {_postShotMove}}
            && {_vehicle isKindOf "Tank" || {_vehicle isKindOf "Wheeled_APC_F"}} && {canMove _vehicle}
            && {[_group,_vehicle,_standoffSeats] call CBE_fnc_CortexVehicleCrewAvailable}
            && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
            && {_postShotMove || {!([_state, "standoff"] call CBE_fnc_CortexCooldown)}}) then {
            private _threatIndex=[_atIndex,_postShotIndex] select _postShotMove;
            private _atPos = (_enemies select _threatIndex) select 1;
            private _atThreat=(_enemies select _threatIndex) select 0;
            private _height=0;private _eye=[];private _alreadyScreened=false;
            if (_postShotMove) then {
                _height=(((boundingBoxReal _vehicle) select 1) select 2) max 1 min 4;
                _eye=(ATLToASL _atPos) vectorAdd [0,0,1.6];
                _alreadyScreened=[_eye,(getPosASL _vehicle) vectorAdd [0,0,_height],_vehicle,"COVER",_atThreat]
                    call CBE_fnc_CortexCoverScreened;
            };
            // Do not plan another avenue when the current observation is already screened.
            private _away=[];
            if (!_alreadyScreened) then {
                _away=[_vehicle,_atPos,_atThreat,
                    if (_postShotMove) then {25} else {(_standoff - (_vehicle distance2D _atPos)) max 60},_postShotMove]
                    call _selectVehicleEscape;
            };
            if (_postShotMove && {_away isNotEqualTo []}) then {
                // Screening is a point observation, not whole-hull cover or arrival proof.
                if (!([_eye,(ATLToASL _away) vectorAdd [0,0,_height],_vehicle,"COVER",_atThreat]
                    call CBE_fnc_CortexCoverScreened)) then {_away=[]};
            };
            // A stationary support gun may need distance from an AT threat, but its
            // original fire assignment must be retired before routine hull movement.
            // Let the authenticated server replace that slot without refreshing its report.
            if (_away isNotEqualTo [] && {_combinedGroundFireOwned}
                && {(_combinedGroundRole select 4) == "GROUND_FIRE"}
                && {(_state getOrDefault ["vehicleStandoffYield",[]]) isNotEqualTo _combinedGroundRole}
                && {(_group getVariable ["CBE_Cortex_CombinedRole",[]]) isEqualTo _combinedGroundRole}
                && {[] call _mayIssueVehicle}) then {
                _state set ["vehicleStandoffYield",+_combinedGroundRole];
                [_group,+_combinedGroundRole,"OTHER_INTENT_ACTIVE",clientOwner]
                    remoteExecCall ["CBE_fnc_CortexCombinedRejectServer",2];
            };
            // A local synchronous reply also waits for the next callback. The captured
            // role cannot be borrowed as permission to move after requesting its release.
            private _standoffUntil=if (_postShotMove) then {_postShot select 2} else {serverTime+60};
            isNil {
            if (_away isNotEqualTo [] && {!_combinedGroundFireOwned} && {(_group getVariable ["CBE_Cortex_CombinedRole",[]]) isEqualTo _combinedGroundRole}
                && {[] call _mayIssueVehicle}
                && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
                && {[_group,_vehicle,_standoffSeats] call CBE_fnc_CortexVehicleCrewAvailable}
                && {[_group,"VEHICLE_STANDOFF",true,_standoffUntil] call CBE_fnc_CortexOwnershipLease}) then {
                private _operation=[_group,"VEHICLE_STANDOFF",_atThreat,_standoffSeats arrayIntersect _standoffSeats,[_away],"MOVING"] call CBE_fnc_OperationStart;
                if (count _operation == 0) then {
                    [_group,"VEHICLE_STANDOFF",false] call CBE_fnc_CortexOwnershipLease;
                } else {
                    private _generation=_operation get "generation";
                    // Start captures exact native baseline and rechecks original seats
                    // after synchronous predecessor cleanup. No group waypoint is inserted.
                    private _accepted=[_group,_vehicle,_away,_standoffSeats,_generation,_standoffUntil,
                        if (_postShotMove) then {[(ATLToASL _atPos) vectorAdd [0,0,1.6],_atThreat,gunner _vehicle]} else {[]}]
                        call CBE_fnc_VehicleTacticalMoveStart;
                    if (!_accepted) then {
                        [_group,_generation,"INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
                        [_group,"VEHICLE_STANDOFF",false] call CBE_fnc_CortexOwnershipLease;
                        if (!_postShotMove) then {[_state,"standoff",8] call CBE_fnc_CortexCooldown};
                    } else {
                        _movementOwned=true;_tacticalCommandActors=+_standoffSeats;
                        if (!_postShotMove) then {[_state,"standoff",60] call CBE_fnc_CortexCooldown};
                    };
                };
            };
            };
        };
        private _gunner = gunner _vehicle;
        // Native editor role is a preference, never ammunition or engagement permission.
        // Custom air-capable stations can join known-air gunnery without changing their
        // tactical role, ground-threat priority or movement ownership.
        private _airDefence=toLowerANSI getText (configOf _vehicle >> "editorSubcategory") == "edsubcat_aas";
        private _airCandidate=_airDefence || {_vehicle isKindOf "LandVehicle" && {_vehicleIndex in _airProbeSlots}};
        private _warnedBy=objNull;
        if (_airDefence) then {
            private _warning=_vehicle getVariable ["CBE_AA_MissileWarning",[]];
            if (_warning isEqualType [] && {count _warning == 6}
                && {(_warning param [0,-1,[0]]) == clientOwner}
                && {(_warning param [1,grpNull,[grpNull]]) == _group}
                && {(_warning param [2,-1,[0]]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                && {private _until=_warning param [3,-1,[0]]; finite _until && {serverTime < _until}}) then {
                _warnedBy=_warning param [5,objNull,[objNull]];
            };
        };
        private _airPreference=false;
        private _stationSelection=createHashMap;
        private _gunneryContacts=+(_enemies select [0,8]);
        // Do not spend native knowledge or station queries while routine targeting
        // cannot act. The final live checks below remain the firing boundary.
        if (_airCandidate && {[_vehicle,_gunner] call _crewActorAvailable}
            && {!(_vehicle isKindOf "LandVehicle") || {!_combinedGroundFireOwned}}
            && {canFire _vehicle}
            && {combatMode _group in ["YELLOW","RED"]} && {unitCombatMode _gunner in ["YELLOW","RED"]}
            && {(_gunner getVariable ["CBE_AIPass_TargetHold",-1]) < time}) then {
            if (!_airContactsRead) then {
                _airContacts=([_group,-1,"AIR"] call CBE_fnc_CortexKnowledge) select 0;
                _airContactsRead=true;
                {
                    private _aaGunner=gunner _x;
                    if ([_x,_aaGunner] call _crewActorAvailable && {canFire _x}
                        && {combatMode _group in ["YELLOW","RED"]}
                        && {unitCombatMode _aaGunner in ["YELLOW","RED"]}) then {
                        private _nativeTarget=getAttackTarget _aaGunner;
                        if (!isNull _nativeTarget && {_nativeTarget isKindOf "Air"}) then {
                            _aaEngagements pushBack [_aaGunner,_nativeTarget];
                        };
                    };
                } forEach _aaAllocationVehicles;
            };
            private _freshAircraft=_airContacts select {(_x select 2) <= 3};
            // Metadata cannot spend all eight target slots on aircraft when this actual
            // loaded station only has ground ammunition. A failed full scan can be reused
            // for ground selection in this frame; success is still not firing authority.
            if (_freshAircraft isNotEqualTo []) then {
                _airPreference=[_vehicle,_gunner,(_freshAircraft select 0) select 0,_stationSelection,true]
                    call CBE_fnc_CortexGroundFireReady;
            };
            if (_airPreference) then {
                {
                    private _airRow=_x;
                    if (_gunneryContacts findIf {(_x select 0) == (_airRow select 0)} < 0) then {
                        _gunneryContacts pushBack _airRow;
                    };
                } forEach _freshAircraft;
            };
        };
        private _ranked = [];
        {
            _x params ["_enemy", "_position", "_age"];
            private _distance = _vehicle distance2D _position;
            private _freshAir=_airPreference && {_enemy isKindOf "Air"} && {_age <= 3};
            private _contactRange=[600,_airRange] select _freshAir;
            if (_age <= 15 && {_distance <= _contactRange} && {alive _enemy} && {!captive _enemy}
                && {!(_enemy getVariable ["ace_captives_isSurrendering",false])}
                && {!(_enemy getVariable ["ace_captives_isHandcuffed",false])}
                && {(side _group) getFriend (side _enemy) < 0.6}) then {
                private _warningPriority=false;
                if (_freshAir && {_airDefence} && {_enemy == _warnedBy}) then {
                    private _warningKnowledge=_gunner targetKnowledge _enemy;
                    private _warningAge=time-(_warningKnowledge param [2,-1,[0]]);
                    _warningPriority=(_warningKnowledge param [1,false,[true]])
                        && {!(_warningKnowledge param [7,false,[true]])}
                        && {_warningAge >= 0} && {_warningAge <= 3};
                };
                private _priority = switch (true) do {
                    case (_warningPriority): {-2};
                    case (_freshAir && {_airDefence}): {-1};
                    case (_enemy isKindOf "CAManBase" && {"AT" in ([_enemy,true] call CBE_fnc_CortexCapabilities)}): {0};
                    case (_enemy isKindOf "Tank" || {_enemy isKindOf "Wheeled_APC_F"}): {1};
                    default {2};
                };
                // Count other stations, not this gunner's incumbent. Allocation is only
                // a tie-break within the threat tier, never permission to fire or a veto.
                private _airLoad=0;
                if (_freshAir && {_vehicle in _aaAllocationVehicles}) then {
                    _airLoad={(_x select 0) != _gunner && {(_x select 1) == _enemy}} count _aaEngagements;
                };
                _ranked pushBack [_priority, _airLoad, _distance, _forEachIndex];
            };
        } forEach _gunneryContacts;
        _ranked sort true;
        // One highest-priority fresh contact may request native reserve loading. Later
        // callbacks observe it; no delayed target/fire action is queued with the request.
        private _reloadStatus="REFUSED";
        if (_ranked isNotEqualTo [] && {_vehicle isKindOf "LandVehicle"}
            && {!_combinedGroundFireOwned} && {[_vehicle,_gunner] call _crewActorAvailable}) then {
            private _reloadContact=_gunneryContacts select ((_ranked select 0) select 3);
            if ((_reloadContact select 2) <= 3) then {
                _reloadStatus=[_vehicle,_gunner,_reloadContact select 0,serverTime-(_reloadContact select 2)]
                    call CBE_fnc_CortexGroundReload;
            };
        };
        if (_ranked isNotEqualTo [] && {[_vehicle,_gunner] call _crewActorAvailable}
            && {!(_reloadStatus in ["REQUESTED","PENDING"])}
            && {!(_vehicle isKindOf "LandVehicle") || {!_combinedGroundFireOwned}}
            && {canFire _vehicle}
            && {combatMode _group in ["YELLOW", "RED"]} && {unitCombatMode _gunner in ["YELLOW", "RED"]}
            && {(_gunner getVariable ["CBE_AIPass_TargetHold", -1]) < time}) then {
            // Two bounded knowledge domains supply at most sixteen ranked rows; inspect only
            // eight. Preserve threat order, but
            // an unusable first contact must not starve the next safe, compatible target.
            // Each candidate gets at most one station/lane observation; stop on first success.
            private _target=objNull;
            private _suppressionPoint=[];private _targetLanePoint=[];
            private _suppressionGeometryChecks=0;
            {
                private _contactRow=_gunneryContacts select (_x select 3);
                private _candidate=_contactRow select 0;
                private _reported=+(_contactRow select 1);
                private _suppressOnly=(_contactRow select 2) > 3;
                private _reportedASL=(ATLToASL _reported) vectorAdd [0,0,1];
                // Older native reports authorize a fixed estimate, never a hidden live aimPos.
                // Preserve an existing burst and unrelated native engagement. No explosive
                // station ammunition is selected for this routine suppression fallback.
                private _engaging=getAttackTarget _gunner;
                private _assigned=assignedTarget _gunner;
                private _suppressionAllowed=!_suppressOnly || {
                    _vehicle isKindOf "LandVehicle" && {abs speed _vehicle < 30}
                        && {_vehicle distance2D _reported >= 50}
                        && {toUpperANSI currentCommand _gunner != "SUPPRESS"}
                        && {isNull _engaging || {_engaging == _candidate}}
                        && {isNull _assigned || {_assigned == _candidate}}
                        && {_suppressionGeometryChecks < 3}
                };
                private _stationReady=_suppressionAllowed && {
                    !(_vehicle isKindOf "LandVehicle")
                        || {[_vehicle,_gunner,_candidate,_stationSelection,true,_suppressOnly] call CBE_fnc_CortexGroundFireReady}
                };
                if (_stationReady && {_suppressOnly}) then {
                    _suppressionGeometryChecks=_suppressionGeometryChecks+1;
                    _reportedASL=[_gunner,_reportedASL,50] call CBE_fnc_CortexSuppressionAim;
                    _stationReady=_reportedASL isNotEqualTo [];
                };
                if (_stationReady && {[_gunner,_reportedASL,_stationSelection getOrDefault ["loadedMagazine",""]] call CBE_fnc_CortexLineOfFireClear}) exitWith {
                    _target=_candidate;_targetLanePoint=+_reportedASL;
                    if (_suppressOnly) then {_suppressionPoint=+_reportedASL};
                };
            } forEach (_ranked select [0,8]);
            if (!isNull _target) then {
                // Selection may reuse one complete same-frame observation. It is not
                // fire authority: fresh native rounds must still qualify this target.
                private _fireObservation=createHashMap;
                private _freshStationReady=!(_vehicle isKindOf "LandVehicle")
                    || {[_vehicle,_gunner,_target,_fireObservation,false,_suppressionPoint isNotEqualTo []] call CBE_fnc_CortexGroundFireReady};
                // If native loading changed the selected magazine, its blast envelope
                // cannot borrow the earlier candidate's cone/point observation.
                private _freshLaneSafe=_freshStationReady && {
                    (_fireObservation getOrDefault ["loadedMagazine",""]) == (_stationSelection getOrDefault ["loadedMagazine",""])
                        || {[_gunner,_targetLanePoint,_fireObservation getOrDefault ["loadedMagazine",""]] call CBE_fnc_CortexLineOfFireClear}
                };
                if (_freshLaneSafe && {[] call _mayIssueVehicle}) then {
                    private _muzzleSelected=!(_vehicle isKindOf "LandVehicle")
                        || {[_vehicle,_gunner,_fireObservation] call CBE_fnc_CortexGroundSelectMuzzle};
                    // Exact native turret acknowledgement, not selection request, grants fire.
                    if (_muzzleSelected) then {
                        if (_suppressionPoint isEqualTo []) then {
                            if (!([_state,"armourCover"] call CBE_fnc_CortexCooldown)) then {
                                [_vehicle,"ARM",[_target,+_targetLanePoint,_fireObservation]] call CBE_fnc_VehicleArmourShot;
                            };
                            if (assignedTarget _gunner != _target) then {_gunner doTarget _target};
                            _gunner doFire _target;
                        } else {
                            _gunner doWatch (ASLToAGL _suppressionPoint);
                            _gunner doSuppressiveFire _suppressionPoint;
                        };
                        if (_vehicle in _aaAllocationVehicles) then {
                            // Replace this station's hint only after native dispatch. The
                            // reservation is provisional, not acknowledgement/shot evidence.
                            private _oldAllocation=_aaEngagements findIf {(_x select 0) == _gunner};
                            if (_oldAllocation >= 0) then {_aaEngagements deleteAt _oldAllocation};
                            if (_suppressionPoint isEqualTo [] && {_target isKindOf "Air"}) then {
                                _aaEngagements pushBack [_gunner,_target];
                            };
                        };
                        _gunner setVariable ["CBE_AIPass_TargetHold", time + 8];
                        _gunner setVariable ["CBE_AIPass_VehicleTarget", _target, true];
                    };
                };
            };
        };

    };
} forEach _vehicles;
_movementOwned
