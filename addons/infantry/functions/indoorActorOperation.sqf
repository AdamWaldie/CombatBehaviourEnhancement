/*
 * Author: WaldoTheWarfighter
 * One stalled CBE-issued ISSUE leg may select an alternative node under the same deadline/probe budget.
 * Exact prior native destination/formation and twelve seconds without progress remain mandatory;
 * resumed movement, newer tasks and native planning forbid the retry. No access/clearance verdict.
 * Individual BLUE/GREEN orders defer new investigation and end active execution;
 * exact owned movement cleanup remains available without changing combat mode.
 * Physical progress and arrival use absolute ASL coordinates; native destinations remain ATL.
 * Terrain differences between cells cannot fabricate motion or hide same-floor arrival.
 * Native INIT/planning/replanning blocks new legs and defers stagnation classification within the original deadline.
 * An issued native move has one original two-second acknowledgement window. Only the
 * exact pre-issue destination/form leader and original command or MOVE may wait; new
 * orders preempt immediately. Waiting issues nothing and grants no cleanup or visit proof.
 * Purpose: Own one finite indoor investigation actor, independently of whole-group CLEAR.
 * Existing discovery may REAP an ended current FSM through exact FINISH cleanup.
 * REAP never restarts investigation, renews its deadline or classifies a node as unreachable.
 * Locality/authority: Actor and group owner only; the FSM queues bounded shared-scheduler work.
 * Native/Zeus/specialist tasks, native ignored or surrendered/restrained contacts and overlapping operations preempt this controller. Proven disjoint
 * infantry rosters may coexist when they own no group waypoint. No firing is forced.
 * Repeat/JIP: One exact generation per actor; a public cancellation journal allows a new owner
 * to retire an unchanged native leg without replaying movement or renewing the original deadline.
 * Arguments: 0 mode <STRING>, START; 1 actor <OBJECT>, objNull; 2 context <HASHMAP>, empty.
 * START context: building OBJECT, belief [ATL ARRAY, server timestamp], optional contact OBJECT.
 * Optional deadline NUMBER only shortens the original maximum; position-only clues cannot renew it.
 * Optional searchMemory [ATL position, original server observation, fixed expiry, owner epoch] permits
 * older position-only admission only while identical to current SEARCH state and its deadline.
 * Ordinary beliefs retain five-second freshness; this grants no hostile identity or room-safety proof.
 * Confirmed same-episode physical visits are shared within the existing sixteen-node preference budget.
 * Search-memory investigation may visit up to four nodes per actor under the same original deadline
 * and twelve-probe search. Further legs require the exact unchanged, physically reached owned move.
 * observationOnly BOOL false keeps position-only tasks bound to investigation enable/stealth policy.
 * Optional observationClue ARRAY binds shared visit preference to the exact original body clue;
 * only a physically reached OBSERVE result records a node, never admission/failure/clearance.
 * Idle/plain-route contexts may issue one leg. An unchanged same-contact native approach is
 * observed without a reset; after measured stagnation one alternate-node escalation is permitted.
 * Observed native destinations are recorded at admission and kept distinct from another
 * investigator's selected node; this grants no native-path ownership or cleanup authority.
 * Other modes carry the brain. Neither admission nor escalation renews the original deadline.
 * TRANSFER is locality cleanup only: an absent machine-local lease may use the public journal;
 * a different live actor reservation still forbids command cleanup.
 * Return: BOOL for START/QUEUE/FINISH/TRANSFER/REAP; NUMBER -1 for STEP (one shared-scheduler invocation).
 * Current callers: IndoorActorDispatch, CortexGroupTick post-contact search, indoorActor FSM, CortexDiscover ended-worker cleanup,
 * focused fixtures and locality/release cleanup.
 * Example: ["START",soldier1,createHashMapFromArray [["building",house1],
 * ["belief",[[100,100,2],serverTime]]]] call CBE_fnc_IndoorActorOperation;
 */
params [["_mode","START",[""]],["_actor",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]]];
_mode=toUpperANSI _mode;
private _observationOnly=_brain getOrDefault ["observationOnly",false];
private _searchMemory=_brain getOrDefault ["searchMemory",[]];
if !(_searchMemory isEqualType []) exitWith {false};
if !(_observationOnly isEqualType true) exitWith {false};
private _migration=_mode == "TRANSFER";
if (_migration) then {_mode="FINISH"};
if (isNull _actor) exitWith {if (_mode == "STEP") then {-1} else {false}};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {
    if (_mode == "STEP") then {-1} else {false}
};
private _group=group _actor;
// Keep proof arrays independent from actor markers and public cancellation journals.
private _copyArray={_this apply {if (_x isEqualType []) then {_x call _copyArray} else {_x}}};
private _vectorValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
// Older belief may only use an immutable episode already owned by the current SEARCH state.
private _searchMemoryValid={
    private _memoryState=_group getVariable ["CBE_AIPass_State",createHashMap];
    _observationOnly && {count _searchMemory == 4}
        && {(_searchMemory select 0) call _vectorValid}
        && {[1,2,3] findIf {!((_searchMemory select _x) isEqualType 0) || {!finite (_searchMemory select _x)}} < 0}
        && {(_memoryState getOrDefault ["phase",""]) == "SEARCH"}
        && {(_memoryState getOrDefault ["searchMemory",[]]) isEqualTo _searchMemory}
        && {(_searchMemory select 3) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {serverTime >= (_searchMemory select 1)} && {serverTime < (_searchMemory select 2)}
        && {(_searchMemory select 2) > (_searchMemory select 1)}
        && {(_searchMemory select 2) <= (_searchMemory select 1)+120}
        && {(_searchMemory select 2) <= (_memoryState getOrDefault ["searchDeadline",-1])}
};
private _releaseAvailable={
    local _actor && {local _group} && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {isNull objectParent _actor} && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
        && {!([_group] call CBE_fnc_CortexZeusHeld)}

    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
};
private _available={
    local _actor && {local _group} && {!isNull _group} && {!isPlayer _actor}
        && {isNull remoteControlled _actor} && {isNull objectParent _actor}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {getSuppression _actor < 0.5} && {currentWeapon _actor != ""}
        && {combatMode _group in ["YELLOW","RED","WHITE"]} && {unitCombatMode _actor in ["YELLOW","RED","WHITE"]}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {[_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible}
        && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
        && {[_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {!_observationOnly || {!(behaviour _actor in ["STEALTH","CARELESS"])
            && {[_group,"CBE_AIPass_Investigate_Enable",true] call CBE_fnc_CortexFeatureEnabled}}}
        && {(_group getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []}
        && {(_group getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
        && {!(_group getVariable ["CBE_AIPass_ClearBuilding",false])}
    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
    && {_searchMemory isEqualTo [] || {call _searchMemoryValid}}
};
// Only STEP after a confirmed OBSERVE can add shared memory; terminal cleanup cannot
// turn an assignment, timeout or changed route into a visit.
private _recordSearchVisit={
    private _visitTarget=_brain getOrDefault ["target",[]];
    private _visitHouse=_brain getOrDefault ["building",objNull];
    private _visitTransform=_brain getOrDefault ["transform",[]];
    if (!(call _searchMemoryValid) || {!(call _releaseAvailable)}
        || {(_brain getOrDefault ["phase",""]) != "OBSERVE"}
        || {(_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) isNotEqualTo _brain}
        || {(_brain getOrDefault ["group",grpNull]) != _group}
        || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {(_brain getOrDefault ["operationGeneration",-1]) != (_group getVariable ["CBE_OperationGeneration",0])}
        || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_brain getOrDefault ["route",[]])}
        || {!(_visitTarget call _vectorValid)} || {(getPosASL _actor) vectorDistance (AGLToASL _visitTarget) > 2}
        || {isNull _visitHouse} || {!alive _visitHouse}
        || {[getPosWorld _visitHouse,vectorDir _visitHouse,vectorUp _visitHouse] isNotEqualTo _visitTransform}) exitWith {false};
    // Arrival proof is two seconds old: proximity alone can now be outside a wall.
    // Recheck the same interior geometry once, when committing this visit.
    private _visitASL=getPosASL _actor;
    private _visitModel=_visitHouse worldToModel (getPosATL _actor);
    private _visitBounds=boundingBoxReal _visitHouse;
    private _visitLow=_visitBounds select 0; private _visitHigh=_visitBounds select 1;
    if ((_visitModel select 0) <= (_visitLow select 0) || {(_visitModel select 0) >= (_visitHigh select 0)}
        || {(_visitModel select 1) <= (_visitLow select 1)} || {(_visitModel select 1) >= (_visitHigh select 1)}
        || {abs ((_visitASL select 2)-((AGLToASL _visitTarget) select 2)) > 1}) exitWith {false};
    private _visitSegment=lineIntersectsSurfaces [eyePos _actor,(AGLToASL _visitTarget) vectorAdd [0,0,1],_actor,objNull,true,1,"GEOM","NONE"];
    if (_visitSegment isNotEqualTo []) exitWith {false};
    private _visitRoofTop=[_visitHouse,_visitBounds] call CBE_fnc_BuildingRoofTop;
    if (_visitRoofTop <= (_visitASL select 2)+0.4) exitWith {false};
    private _visitRoof=lineIntersectsSurfaces [_visitASL vectorAdd [0,0,0.4],
        [_visitASL select 0,_visitASL select 1,_visitRoofTop],_actor,objNull,true,1,"GEOM","NONE"];
    if (_visitRoof isEqualTo []) exitWith {false};
    private _visitHit=_visitRoof select 0;
    if ((_visitHit select 2) != _visitHouse && {(_visitHit select 3) != _visitHouse}) exitWith {false};
    private _memoryState=_group getVariable ["CBE_AIPass_State",createHashMap];
    private _history=_memoryState getOrDefault ["searchBuildingVisits",[]];
    private _visits=if (_history isEqualType [] && {count _history == 2}
        && {(_history select 0) isEqualTo _searchMemory} && {(_history select 1) isEqualType []}) then {
        (_history select 1) select [0,16]
    } else {[]};
    private _row=[_visitHouse,_visitTransform call _copyArray,AGLToASL _visitTarget];
    if (!(_row in _visits) && {count _visits < 16}) then {_visits pushBack _row};
    _memoryState set ["searchBuildingVisits",[_searchMemory call _copyArray,_visits]];
    true
};
if (_mode == "FINISH") exitWith {
    if (count _brain > 0) then {
        _brain set ["finished",true]; _brain set ["pending",false]; _brain set ["completed",true];
    };
    if (!local _actor || {!local _group}) exitWith {false};
    private _journal=_actor getVariable ["CBE_IndoorActor_Order",[]];
    if (count _journal != 9) exitWith {
        if (count _brain > 0 && {(_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) isEqualTo _brain}) then {
            _actor setVariable ["CBE_IndoorActor_Brain",nil]; _actor setVariable ["CBE_IndoorActor_FSM",nil];
        };
        false
    };
    private _valid=(_journal select 0) isEqualType 0 && {finite (_journal select 0)}
        && {(_journal select 1) isEqualType 0} && {finite (_journal select 1)}
        && {(_journal select 2) isEqualType grpNull} && {(_journal select 3) isEqualType 0}
        && {finite (_journal select 3)} && {(_journal select 4) isEqualType 0}
        && {finite (_journal select 4)} && {(_journal select 5) isEqualType []}
        && {(_journal select 6) isEqualType []} && {(_journal select 7) isEqualType []}
        && {(_journal select 8) isEqualType true};
    if (!_valid) exitWith {false};
    private _savedLease=_journal select 7;
    if (count _savedLease != 3 || {(_savedLease select 0) isNotEqualTo "INDOOR_INVESTIGATE"}
        || {!((_savedLease select 1) call _vectorValid)}
        || {!((_savedLease select 2) isEqualType 0)} || {!finite (_savedLease select 2)}
        || {(_journal select 0) < 1} || {(_journal select 0) != floor (_journal select 0)}
        || {(_journal select 1) < 0} || {(_journal select 1) != floor (_journal select 1)}
        || {(_journal select 8) && {!((_journal select 6) call _vectorValid)}}) exitWith {false};
    _journal params ["_generation","_epoch","_oldGroup","_operation","_deadline","_route","_target","_lease","_issued"];
    // A late old FSM cannot retire a successor's public journal or marker.
    if (count _brain > 0 && {(_brain getOrDefault ["generation",-1]) != _generation
        || {(_brain getOrDefault ["ownerEpoch",-1]) != _epoch}}) exitWith {false};
    private _destination=(expectedDestination _actor) param [0,[],[[]]];
    private _reservation=_actor getVariable ["CBE_Cortex_ActorMove",[]];
    private _ownsLeg=_issued && {_oldGroup == _group} && {call _releaseAvailable}
        && {_reservation isEqualTo _lease || {_migration && {_reservation isEqualTo []}}}
        && {(_group getVariable ["CBE_OperationGeneration",0]) == _operation}
        && {[_actor] call CBE_fnc_IndoorActorGroupAvailable}
        && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _route}
        && {currentCommand _actor == "MOVE"}
        && {_destination call _vectorValid} && {_target call _vectorValid}
        && {_destination vectorDistance _target <= 0.25};
    if (_ownsLeg) then {
        private _index=currentWaypoint _group;
        private _waypoint=[_group,_index];
        if (_actor == leader _group && {_index > 0} && {_index < count waypoints _group}
            && {waypointType _waypoint == "MOVE"}) then {
            _actor doMove waypointPosition _waypoint;
        } else {_actor doFollow leader _group};
    };
    if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _lease) then {
        _actor setVariable ["CBE_Cortex_ActorMove",nil];
    };
    // A failed issued leg is a temporary observation for this actor, never an access verdict.
    if (!_migration && {_issued} && {_oldGroup == _group}
        && {(_brain getOrDefault ["reason",""]) == "NO_PROGRESS"}
        && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
        private _house=_brain getOrDefault ["building",objNull];
        private _transform=_brain getOrDefault ["transform",[]];
        if (!isNull _house && {alive _house} && {_target call _vectorValid}
            && {[getPosWorld _house,vectorDir _house,vectorUp _house] isEqualTo _transform}) then {
            private _failed=(_actor getVariable ["CBE_IndoorActor_NodeFailures",[]]) select [0,4];
            _failed=_failed select {_x isEqualType [] && {count _x == 5}
                && {(_x select 3) isEqualType 0} && {finite (_x select 3)} && {serverTime < (_x select 3)}
                && {(_x select 4) isEqualTo _epoch}
                && {!((_x select 0) isEqualTo _house && {(_x select 2) isEqualTo _target})}};
            if (count _failed >= 4) then {_failed deleteAt 0};
            _failed pushBack [_house,_transform call _copyArray,+_target,serverTime+60,_epoch];
            _actor setVariable ["CBE_IndoorActor_NodeFailures",_failed];
        };
    };
    // Keep only historical physical visits from this original finite clue. This is a
    // preference for later investigation, never a room-safe or hostile-occupancy claim.
    private _clue=_brain getOrDefault ["observationClue",[]];
    private _house=_brain getOrDefault ["building",objNull];
    private _transform=_brain getOrDefault ["transform",[]];
    if (!_migration && {_observationOnly} && {count _clue == 5}
        && {(_brain getOrDefault ["reason",""]) == "VISITED"}
        && {(_brain getOrDefault ["phase",""]) == "OBSERVE"}
        && {_oldGroup == _group} && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_operation == (_group getVariable ["CBE_OperationGeneration",0])} && {call _releaseAvailable}
        && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _route}
        && {(_group getVariable ["CBE_Danger_BuildingClue",[]]) isEqualTo _clue}
        && {serverTime < (_clue select 2)} && {_target call _vectorValid}
        && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 2}
        && {!isNull _house} && {alive _house}
        && {[getPosWorld _house,vectorDir _house,vectorUp _house] isEqualTo _transform}) then {
        private _history=_group getVariable ["CBE_Danger_BuildingVisits",[]];
        private _visits=if (_history isEqualType [] && {count _history == 2}
            && {(_history select 0) isEqualTo _clue} && {(_history select 1) isEqualType []}) then {
            (_history select 1) select [0,16]
        } else {[]};
        private _row=[_house,_transform call _copyArray,AGLToASL _target];
        if (!(_row in _visits) && {count _visits < 16}) then {_visits pushBack _row};
        _group setVariable ["CBE_Danger_BuildingVisits",[_clue call _copyArray,_visits]];
    };
    _actor setVariable ["CBE_IndoorActor_Result",[_generation,
        _brain getOrDefault ["reason","RELEASED"],serverTime,+_target],true];
    _actor setVariable ["CBE_IndoorActor_Order",nil,true];
    if (local _oldGroup) then {
        _oldGroup setVariable ["CBE_IndoorActor_Actors",(_oldGroup getVariable ["CBE_IndoorActor_Actors",[]])-[_actor]];
    };
    private _current=_actor getVariable ["CBE_IndoorActor_Brain",createHashMap];
    if (count _brain == 0 || {_current isEqualTo _brain}) then {
        _actor setVariable ["CBE_IndoorActor_Brain",nil];
        _actor setVariable ["CBE_IndoorActor_FSM",nil];
    };
    _actor setVariable ["CBE_IndoorActor_Cooldown",serverTime+20,true];
    true
};
if (_mode == "START") exitWith {
    private _building=_brain getOrDefault ["building",objNull];
    private _belief=_brain getOrDefault ["belief",[]];
    private _contact=_brain getOrDefault ["contact",objNull];
    private _clue=_brain getOrDefault ["observationClue",[]];
    if (_searchMemory isNotEqualTo [] && {!(call _searchMemoryValid)
        || {!isNull _contact} || {_clue isNotEqualTo []}
        || {!(_belief isEqualType [])} || {count _belief != 2}
        || {(_belief select 0) isNotEqualTo (_searchMemory select 0)}
        || {(_belief select 1) isNotEqualTo (_searchMemory select 1)}}) exitWith {false};
    if (!(_clue isEqualType []) || {!((count _clue) in [0,5])}) exitWith {false};
    if (_clue isNotEqualTo [] && {!_observationOnly
        || {(_group getVariable ["CBE_Danger_BuildingClue",[]]) isNotEqualTo _clue}
        || {!((_clue select 0) call _vectorValid)}
        || {[1,2] findIf {!((_clue select _x) isEqualType 0) || {!finite (_clue select _x)}} >= 0}
        || {serverTime < (_clue select 1)} || {serverTime >= (_clue select 2)}
        || {(_clue select 2) > (_clue select 1)+20}
        || {(_clue select 4) isNotEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}}) exitWith {false};
    if (!(_contact isEqualType objNull) || {!(_building isEqualType objNull)} || {isNull _building}
        || {!alive _building} || {!(_belief isEqualType [])} || {count _belief != 2}
        || {!((_belief select 0) call _vectorValid)} || {!((_belief select 1) isEqualType 0)}
        || {!finite (_belief select 1)} || {serverTime-(_belief select 1) < 0}
        || {serverTime-(_belief select 1) > 5 && {!(call _searchMemoryValid)}}) exitWith {false};
    if !(call _available) exitWith {false};
    // Fresh scripted/Zeus-created groups may precede periodic discovery. Establish the
    // owner epoch before publishing an actor journal, never adopt over that new journal later.
    if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {
        [_group,true] call CBE_fnc_CortexLocality;
    };
    if (!(call _available) || {!(_group getVariable ["CBE_AIPass_Adopted",false])}
        || {(_group getVariable ["CBE_AIPass_Epoch",0]) <= 0}
        || {serverTime-(_belief select 1) > 5 && {!(call _searchMemoryValid)}}) exitWith {false};
    private _admission=[_actor,_contact,_belief select 0,_building] call CBE_fnc_IndoorActorNativeContext;
    if (_admission isEqualTo [] || {serverTime < (_actor getVariable ["CBE_IndoorActor_Cooldown",-1])}
        || {[_actor] call CBE_fnc_CortexActorMoveReserved}
        || {(_actor getVariable ["CBE_IndoorActor_Order",[]]) isNotEqualTo []}
        || {count (_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) > 0}
        || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}) exitWith {false};
    // Native command, destination and actual engagement identity remain fixed until SELECT.
    // BUSY combat paths are observation-only; arbitrary individual MOVE tasks are never replaced.
    private _members=(units _group) select [0,16];
    private _investigators=_group getVariable ["CBE_IndoorActor_Actors",[]];
    if (!(_investigators isEqualType []) || {count _investigators > 2}) exitWith {false};
    _investigators=_investigators select {
        _x isEqualType objNull && {!isNull _x} && {group _x == _group}
            && {count (_x getVariable ["CBE_IndoorActor_Brain",createHashMap]) > 0}
            && {!((_x getVariable ["CBE_IndoorActor_Brain",createHashMap]) getOrDefault ["finished",true])}
    };
    if (!(_actor in _members) || {count _investigators >= 2}) exitWith {false};
    private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
    if (_actor in ((_state getOrDefault ["drill",createHashMap]) getOrDefault ["units",[]])
        || {_actor in (_state getOrDefault ["supportHeld",[]])}) exitWith {false};
    private _generation=(_actor getVariable ["CBE_IndoorActor_Generation",0])+1;
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    private _deadline=if (call _searchMemoryValid) then {
        (serverTime+45) min (_searchMemory select 2)
    } else {(serverTime+45) min ((_belief select 1)+30)};
    // Position-only observations may shorten the task to their original clue expiry.
    // This parameter can never extend the ordinary indoor deadline.
    private _requestedDeadline=_brain getOrDefault ["deadline",_deadline];
    if (!(_requestedDeadline isEqualType 0) || {!finite _requestedDeadline}
        || {_requestedDeadline <= serverTime}) exitWith {false};
    _deadline=_deadline min _requestedDeadline;
    if (_clue isNotEqualTo []) then {
        if ((_group getVariable ["CBE_Danger_BuildingClue",[]]) isNotEqualTo _clue
            || {(_clue select 4) isNotEqualTo _epoch} || {serverTime >= (_clue select 2)}) then {
            _deadline=serverTime;
        } else {_deadline=_deadline min (_clue select 2)};
    };
    if (_deadline <= serverTime) exitWith {false};
    private _lease=["INDOOR_INVESTIGATE",+(_belief select 0),time+(_deadline-serverTime)];
    private _initialTarget=if ((_admission select 0) == "OBSERVE") then {+(_admission select 2)} else {[]};
    private _serial=(missionNamespace getVariable ["CBE_IndoorActor_Serial",0])+1;
    missionNamespace setVariable ["CBE_IndoorActor_Serial",_serial];
    _brain=createHashMapFromArray [["jobKey",format ["CBE_INDOOR_%1",_serial]],["actor",_actor],["group",_group],["generation",_generation],
        ["ownerEpoch",_epoch],["operationGeneration",_group getVariable ["CBE_OperationGeneration",0]],
        ["deadline",_deadline],["route",[_group] call CBE_fnc_NativeOrderReceipt],
        ["building",_building],["transform",[getPosWorld _building,vectorDir _building,vectorUp _building]],
        ["belief",[+(_belief select 0),_belief select 1]],["contact",_contact],
        ["searchMemory",_searchMemory call _copyArray],["observationClue",_clue call _copyArray],["observationOnly",_observationOnly],["contactRequired",!isNull _contact],["admission",_admission call _copyArray],["escalations",0],["escalate",false],["lease",_lease call _copyArray],["target",+_initialTarget],["issued",false],
        ["phase","SELECT"],["finished",false],["pending",false],["completed",false],
        ["nextAt",time],["progressAt",serverTime],["progressPosition",getPosASL _actor]];
    // Release only this actor's owned danger posture before publishing the incoming task.
    [_actor] call CBE_fnc_DangerEngineRelease;
    if ((_actor getVariable ["CBE_Danger_EngineStanceLease",[]]) isNotEqualTo []) exitWith {false};
    if !([_group,-1,false,"",objNull,_actor] call CBE_fnc_DangerGroupHideStep) exitWith {false};
    _actor setVariable ["CBE_IndoorActor_Generation",_generation];
    _actor setVariable ["CBE_IndoorActor_Brain",_brain];
    _group setVariable ["CBE_IndoorActor_Actors",_investigators+[_actor]];
    _actor setVariable ["CBE_Cortex_ActorMove",_lease call _copyArray];
    _actor setVariable ["CBE_IndoorActor_Order",[_generation,_epoch,_group,
        _brain get "operationGeneration",_deadline,(_brain get "route") call _copyArray,+_initialTarget,_lease call _copyArray,false],true];
    private _handle=[_actor,_brain] execFSM "\z\cbe\addons\main\fsm\indoorActor.fsm";
    _actor setVariable ["CBE_IndoorActor_FSM",_handle];
    private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
        && {(_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) isEqualTo _brain}
        && {!(_brain getOrDefault ["finished",false])};
    if (!_started && {(_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) isEqualTo _brain}) then {
        _brain set ["reason","FSM_START_FAILED"];
        ["FINISH",_actor,_brain] call CBE_fnc_IndoorActorOperation;
    };
    _started
};
private _current=(_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) isEqualTo _brain
    && {count _brain > 0} && {(_brain getOrDefault ["group",grpNull]) == _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])};
if (_mode == "REAP") exitWith {
    if (!_current || {!local _actor} || {!local _group}) exitWith {false};
    private _handle=_actor getVariable ["CBE_IndoorActor_FSM",-1];
    private _alive=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle};
    if (_alive) exitWith {false};
    // A dead executor is not evidence of entry or an inaccessible destination.
    // FINISH alone decides whether the original unchanged native leg may be handed back.
    if (!(_brain getOrDefault ["finished",false]) || {(_brain getOrDefault ["reason",""]) == ""}) then {
        _brain set ["reason","EXECUTOR_ENDED"];
    };
    ["FINISH",_actor,_brain] call CBE_fnc_IndoorActorOperation
};
if (_mode == "QUEUE") exitWith {
    if (!_current || {_brain getOrDefault ["finished",false]}) exitWith {false};
    if (_brain getOrDefault ["pending",false]) exitWith {true};
    _brain set ["pending",true]; _brain set ["completed",false];
    [
        {params ["_job"]; ["STEP",_job get "actor",_job] call CBE_fnc_IndoorActorOperation},
        _brain,0,_brain get "jobKey"
    ] call CBE_fnc_CortexQueueJob;
    true
};
if (_mode != "STEP") exitWith {false};
_brain set ["pending",false]; _brain set ["completed",true]; _brain set ["nextAt",time+0.5];
private _finish={
    params ["_reason"];
    _brain set ["reason",_reason];
    ["FINISH",_actor,_brain] call CBE_fnc_IndoorActorOperation;
    -1
};
if (!_current) exitWith {["OWNER_CHANGED"] call _finish};
if (_brain getOrDefault ["finished",false]) exitWith {-1};
// A new explicitly disjoint operation may coexist, but only while its live roster proves it.
// An unseen operation that already ended cannot be reconstructed as harmless after the fact.
private _operationGeneration=_group getVariable ["CBE_OperationGeneration",0];
if (_operationGeneration != (_brain get "operationGeneration")
    && {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    && {[_actor] call CBE_fnc_IndoorActorGroupAvailable}) then {
    private _journal=_actor getVariable ["CBE_IndoorActor_Order",[]];
    if (count _journal == 9 && {(_journal select 0) == (_brain get "generation")}
        && {(_journal select 1) == (_brain get "ownerEpoch")}
        && {(_journal select 2) == _group}
        && {(_journal select 3) == (_brain get "operationGeneration")}
        && {(_journal select 7) isEqualTo (_brain get "lease")}
        && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo (_brain get "lease")}) then {
        _brain set ["operationGeneration",_operationGeneration];
        _journal=+_journal; _journal set [3,_operationGeneration];
        _actor setVariable ["CBE_IndoorActor_Order",_journal,true];
    };
};
if (!(call _available) || {(_group getVariable ["CBE_OperationGeneration",0]) != (_brain get "operationGeneration")}
    || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_brain get "route")}
    || {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo (_brain get "lease")}) exitWith {
    ["PREEMPTED"] call _finish
};
private _building=_brain get "building";
if (isNull _building || {!alive _building}
    || {[getPosWorld _building,vectorDir _building,vectorUp _building] isNotEqualTo (_brain get "transform")}) exitWith {
    ["BUILDING_CHANGED"] call _finish
};
if (serverTime >= (_brain get "deadline")) exitWith {["DEADLINE"] call _finish};
private _contact=_brain getOrDefault ["contact",objNull];
private _engaging=getAttackTarget _actor;
private _assigned=assignedTarget _actor;
if ((!isNull _engaging && {_engaging != _contact}) || {!isNull _assigned && {_assigned != _contact}}) exitWith {
    ["OTHER_CONTACT"] call _finish
};
if ((_brain getOrDefault ["contactRequired",false] && {isNull _contact})
    || {!isNull _contact && {!alive _contact || {captive _contact}
        || {_contact getVariable ["ace_captives_isSurrendering",false]}
        || {_contact getVariable ["ace_captives_isHandcuffed",false]}
        || {(side _group) getFriend (side _contact) >= 0.6}}}) exitWith {
    ["CONTACT_GONE"] call _finish
};
// A later mission ignoreTarget instruction supersedes this contact-driven investigation.
if (!isNull _contact && {(_actor targetKnowledge _contact) param [7,false,[true]]}) exitWith {
    ["TARGET_IGNORED"] call _finish
};
private _phase=_brain get "phase";
if (_phase == "SELECT") exitWith {
    private _retryOwned=_brain getOrDefault ["retryOwned",false];
    private _continuingSearch=(_brain getOrDefault ["searchContinuing",false]) || {_retryOwned};
    // A further investigation leg consumes the same episode and owned native destination.
    // A fresh native task cannot borrow the original admission or acknowledgement window.
    private _searchLegOwned={
        private _priorTarget=_brain getOrDefault ["target",[]];
        private _native=(expectedDestination _actor) param [0,[],[[]]];
        private _request=_brain getOrDefault ["requestBefore",[]];
        (if (_retryOwned) then {(_brain getOrDefault ["ownedRetries",0]) == 0
            && {((_brain get "admission") select 0) == "ISSUE"}
            && {serverTime-(_brain get "progressAt") >= 12}
            && {!(getUnitState _actor in ["INIT","PLANNING","REPLAN"])}
        } else {call _searchMemoryValid})
            && {_brain getOrDefault ["issued",false]}
            && {currentCommand _actor in ["","MOVE"]}
            && {_priorTarget call _vectorValid} && {_native call _vectorValid}
            && {_native vectorDistance _priorTarget <= 0.25}
            && {_retryOwned || {(getPosASL _actor) vectorDistance (AGLToASL _priorTarget) <= 2}}
            && {count _request == 3} && {formLeader _actor == (_request select 2)}
    };
    if (_retryOwned && {(getPosASL _actor) vectorDistance (_brain get "progressPosition") >= 1}) exitWith {
        _brain set ["progressPosition",getPosASL _actor]; _brain set ["progressAt",serverTime];
        _brain set ["retryOwned",false]; _brain set ["phase","APPROACH"];
        -1
    };
    if (_continuingSearch && {!(call _searchLegOwned)}) exitWith {["NATIVE_TASK"] call _finish};
    private _admission=if (_continuingSearch) then {(_brain get "admission") call _copyArray} else {
        [_actor,_contact,(_brain get "belief") select 0,_building] call CBE_fnc_IndoorActorNativeContext
    };
    if (_admission isEqualTo []) exitWith {["NATIVE_TASK"] call _finish};
    private _previous=_brain get "admission";
    // Native AI may start the same-contact path after START. Adopt that newer leg
    // without issuing movement; a new arbitrary native command still refuses above.
    if ((_previous select 0) == "ISSUE" && {(_admission select 0) == "OBSERVE"}
        && {!isNull _contact} && {(_admission select 3) == _contact}) then {
        _brain set ["admission",_admission call _copyArray];
    };
    if (_admission isNotEqualTo (_brain get "admission")) exitWith {["NATIVE_TASK"] call _finish};
    private _escalate=_brain getOrDefault ["escalate",false];
    if ((_admission select 0) == "OBSERVE" && {!_escalate}) exitWith {
        private _target=+(_admission select 2);
        _brain set ["target",_target]; _brain set ["phase","APPROACH"];
        private _journal=+(_actor getVariable ["CBE_IndoorActor_Order",[]]);
        _journal set [6,+_target];
        _actor setVariable ["CBE_IndoorActor_Order",_journal,true];
        -1
    };
    // A stall sample is not authority to reset a path that has since resumed.
    if ((_escalate || {_retryOwned}) && {(getPosASL _actor) vectorDistance (_brain get "progressPosition") >= 1}) exitWith {
        _brain set ["progressPosition",getPosASL _actor]; _brain set ["progressAt",serverTime];
        _brain set ["escalate",false]; _brain set ["retryOwned",false]; _brain set ["phase","APPROACH"];
        -1
    };
    if (_escalate && {(_brain getOrDefault ["escalations",0]) >= 1
        || {serverTime-(_brain get "progressAt") < 12}
        || {(_admission select 0) != "OBSERVE"}
        || {getUnitState _actor in ["INIT","PLANNING","REPLAN"]} || {currentCommand _actor == "FIRE"}}) exitWith {["ESCALATION_REFUSED"] call _finish};
    private _reserved=[];
    // A peer following native AI still occupies its recorded destination. The issued flag
    // grants cleanup rights only; using it here would invite a second actor to the same node.
    {
        if (_x != _actor) then {
            private _order=_x getVariable ["CBE_IndoorActor_Order",[]];
            if (count _order == 9 && {(_order select 6) isNotEqualTo []}) then {
                _reserved pushBack (_order select 6);
            };
        };
    } forEach ((_group getVariable ["CBE_IndoorActor_Actors",[]]) select [0,2]);
    if (_escalate || {_retryOwned}) then {_reserved pushBack +(_brain get "target")};
    private _nodeSearch=_brain getOrDefault ["nodeSearch",createHashMap];
    _brain set ["nodeSearch",_nodeSearch];
    private _node=[_actor,_building,(_brain get "belief") select 0,_reserved,
        _brain getOrDefault ["observationClue",[]],_nodeSearch,_brain getOrDefault ["searchMemory",[]]] call CBE_fnc_IndoorActorNodeSelect;
    if (_node isEqualTo []) exitWith {
        // A roof miss is not an inaccessible building. Continue the bounded search on
        // the existing FSM callback, under the unchanged original operation deadline.
        if (_nodeSearch getOrDefault ["pending",false]) then {-1} else {
            // VISITED records limited historical work, never exhaustive room coverage.
            [if (_continuingSearch && {!_retryOwned}) then {"VISITED"} else {"NO_CANDIDATE"}] call _finish
        }
    };
    // Geometry work grants no command authority; re-read actor, route and operation ownership.
    if (!(call _available)
        || {if (_continuingSearch) then {!(call _searchLegOwned)} else {
            ([_actor,_contact,(_brain get "belief") select 0,_building] call CBE_fnc_IndoorActorNativeContext) isNotEqualTo _admission
        }}
        || {(_actor getVariable ["CBE_IndoorActor_Brain",createHashMap]) isNotEqualTo _brain}
        || {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo (_brain get "lease")}
        || {[getPosWorld _building,vectorDir _building,vectorUp _building] isNotEqualTo (_brain get "transform")}
        || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_brain get "route")}
        || {(_group getVariable ["CBE_OperationGeneration",0]) != (_brain get "operationGeneration")}
        || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}) exitWith {["PREEMPTED"] call _finish};
    // A stall sample is not authority to reset a path that has since resumed.
    if ((_escalate || {_retryOwned}) && {(getPosASL _actor) vectorDistance (_brain get "progressPosition") >= 1}) exitWith {
        _brain set ["progressPosition",getPosASL _actor]; _brain set ["progressAt",serverTime];
        _brain set ["escalate",false]; _brain set ["retryOwned",false]; _brain set ["phase","APPROACH"];
        -1
    };
    _brain set ["requestBefore",[currentCommand _actor,(expectedDestination _actor) call _copyArray,formLeader _actor]];
    _brain set ["requestIssuedAt",serverTime];
    _actor doMove _node;
    if (_escalate) then {_brain set ["escalations",1]};
    if (_retryOwned) then {_brain set ["ownedRetries",1]};
    _brain set ["retryOwned",false];
    _brain set ["escalate",false]; _brain set ["progressAt",serverTime]; _brain set ["progressPosition",getPosASL _actor];
    _brain set ["target",+_node]; _brain set ["issued",true]; _brain set ["phase","APPROACH"];
    private _journal=+(_actor getVariable ["CBE_IndoorActor_Order",[]]);
    _journal set [6,+_node]; _journal set [8,true];
    _actor setVariable ["CBE_IndoorActor_Order",_journal,true];
    -1
};
private _target=_brain get "target";
private _destination=(expectedDestination _actor) param [0,[],[[]]];
private _combatCommand=currentCommand _actor in ["ATTACK","FIRE"] && {!isNull _contact} && {_engaging == _contact};
private _destinationCurrent=_destination call _vectorValid && {_destination vectorDistance _target <= 0.25};
private _awaitingMove=false;
if (_phase == "APPROACH" && {_brain getOrDefault ["issued",false]} && {!_destinationCurrent}) then {
    private _requestAt=_brain getOrDefault ["requestIssuedAt",-1];
    private _before=_brain getOrDefault ["requestBefore",[]];
    _awaitingMove=_requestAt isEqualType 0 && {finite _requestAt} && {_requestAt >= 0}
        && {serverTime >= _requestAt} && {serverTime-_requestAt < 2}
        && {_before isEqualType []} && {count _before == 3}
        && {currentCommand _actor in [_before select 0,"MOVE"]}
        && {(expectedDestination _actor) isEqualTo (_before select 1)}
        && {formLeader _actor isEqualTo (_before select 2)};
};
// Original issue time is never refreshed here. Observation of somebody else's native
// approach cannot borrow this grace, and pending acknowledgement grants no new command.
if (_awaitingMove) exitWith {-1};
if (!(currentCommand _actor in ["","MOVE"] || {_combatCommand}) || {!_destinationCurrent}) exitWith {["NATIVE_TASK"] call _finish};
if (_phase == "APPROACH") exitWith {
    [_actor,_building,["INDOOR",_brain get "generation"]] call CBE_fnc_CortexBuildingDoor;
    private _position=getPosATL _actor;
    private _positionASL=getPosASL _actor;
    private _near=_positionASL vectorDistance (AGLToASL _target) <= 1.5;
    private _inside=false;
    if (_near) then {
        private _model=_building worldToModel _position;
        private _bounds=boundingBoxReal _building;
        private _low=_bounds select 0; private _high=_bounds select 1;
        private _height=abs ((_positionASL select 2)-((AGLToASL _target) select 2));
        private _segment=lineIntersectsSurfaces [eyePos _actor,(AGLToASL _target) vectorAdd [0,0,1],_actor,objNull,true,1,"GEOM","NONE"];
        private _actualASL=_positionASL;
        private _roofTop=[_building,_bounds] call CBE_fnc_BuildingRoofTop;
        private _roof=if (_roofTop > (_actualASL select 2)+0.4) then {
            lineIntersectsSurfaces [_actualASL vectorAdd [0,0,0.4],
                [_actualASL select 0,_actualASL select 1,_roofTop],_actor,objNull,true,1,"GEOM","NONE"]
        } else {[]};
        _inside=(_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
            && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
            && {_height <= 1} && {_segment isEqualTo []} && {_roof isNotEqualTo []}
            && {private _hit=_roof select 0; (_hit select 2) == _building || {(_hit select 3) == _building}};
    };
    if (_inside) then {
        _brain set ["phase","OBSERVE"]; _brain set ["observeUntil",serverTime+2];
    } else {
        if (_positionASL vectorDistance (_brain get "progressPosition") >= 1) then {
            _brain set ["progressPosition",_positionASL]; _brain set ["progressAt",serverTime];
        };
        // Path recalculation is not evidence of an inaccessible node. Observe only;
        // the original FSM deadline still bounds this wait and is never renewed.
        if (getUnitState _actor in ["INIT","PLANNING","REPLAN"]) exitWith {-1};
        if (serverTime-(_brain get "progressAt") >= 12) then {
            // Only our unchanged issued leg may consume one alternative. Native observed
            // movement retains its existing separate escalation path below.
            if ((_brain get "issued") && {((_brain get "admission") select 0) == "ISSUE"}
                && {(_brain getOrDefault ["ownedRetries",0]) == 0}) exitWith {
                _brain set ["retryOwned",true]; _brain set ["phase","SELECT"];
            };
            if (!(_brain get "issued") && {(_brain get "escalations") == 0}
                && {!(getUnitState _actor in ["INIT","PLANNING","REPLAN"])} && {currentCommand _actor != "FIRE"}) then {
                private _admission=[_actor,_contact,(_brain get "belief") select 0,_building] call CBE_fnc_IndoorActorNativeContext;
                if (_admission isNotEqualTo [] && {(_admission select 0) == "OBSERVE"}
                    && {(_admission select 2) isEqualTo _target}) then {
                    _brain set ["admission",_admission call _copyArray];
                    _brain set ["escalate",true]; _brain set ["phase","SELECT"];
                } else {["NO_PROGRESS"] call _finish};
            } else {["NO_PROGRESS"] call _finish};
        };
    };
    -1
};
if (_phase == "OBSERVE" && {serverTime >= (_brain get "observeUntil")}) exitWith {
    // This is a visit/investigation result, never a cleared-room or killed-enemy assertion.
    if (_searchMemory isNotEqualTo []) then {
        if !(call _recordSearchVisit) exitWith {_brain set ["reason","VISIT_UNCONFIRMED"]};
        private _visited=(_brain getOrDefault ["searchVisitCount",0])+1;
        _brain set ["searchVisitCount",_visited];
        if (_visited < 4 && {_brain getOrDefault ["issued",false]}) then {
            _brain set ["searchContinuing",true];
            _brain set ["phase","SELECT"];
        };
    };
    if ((_brain getOrDefault ["reason",""]) == "VISIT_UNCONFIRMED") exitWith {["VISIT_UNCONFIRMED"] call _finish};
    if ((_brain get "phase") == "SELECT") exitWith {-1};
    ["VISITED"] call _finish
};
-1
