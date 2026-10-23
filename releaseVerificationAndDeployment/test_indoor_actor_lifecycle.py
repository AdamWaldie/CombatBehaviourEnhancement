"""Staged actor investigation must retain finite, scoped ownership contracts."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
class IndoorActorLifecycleTests(unittest.TestCase):
    def test_plain_route_door_assistance_never_takes_movement_or_opens_an_unrelated_door(self):
        route=(ROOT/'addons/infantry/functions/cortexRouteDoors.sqf').read_text()
        door=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        body=route.split('params [[',1)[1]
        self.assertEqual(body.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('nearestObjects',body)
        for proof in ('select [0,64]','(count _actors) min 16','routeDoorNextAt','serverTime+2','routeDoorCursor',
                      '(3 min _length)/_length','_hit select 2','_hit select 3',
                      '_target vectorDistance _goal <= 3','CBE_fnc_CortexBuildingDoor'):
            self.assertIn(proof,body)
        self.assertLess(body.index('routeDoorCursor",(_cursor+_sampleCount)'),body.index('for "_offset"'))
        self.assertLess(body.index('if (!local _actor) then {continue}'),body.index('expectedDestination _actor'))
        for forbidden in ('doMove','doFollow','doStop','setDestination','spawn','waitAndExecute','animateSource'):
            self.assertNotIn(forbidden,body)
        admission=door.split('== "ROUTE") exitWith',1)[1].split('if (count _context != 2',1)[0]
        for proof in ('CBE_AIPass_Epoch','CortexIsPaused','STEALTH','currentCommand _unit != "MOVE"',
                      'waypointStatements','waypointScript','waypointTimeout','synchronizedTriggers',
                      'waypointAttachedObject','CortexActorMoveReserved','IndoorActorGroupAvailable'):
            self.assertIn(proof,admission)
        self.assertEqual(door.count('call _routeDoorRelevant'),2)
        hook=tick.split('// Native authored travel keeps its own planner.',1)[1].split('if !(["CBE_AIPass_Contact_Enable"',1)[0]
        self.assertIn('!_dangerActive',hook)
        self.assertNotIn('{_ordered}',hook)
        self.assertLess(tick.index('call CBE_fnc_CortexRouteDoors'),tick.index('if !(["CBE_AIPass_Contact_Enable"'))
        self.assertIn('!_groupMovementOwned',hook)
        self.assertIn('CBE_fnc_CortexRouteDoors',hook)
        # Geometric admission only: a doorway must lie along, before the native
        # goal and within the narrow approach strip. This proves no Arma entry.
        def relevant(along,lateral,length):return 0<=along<=length and abs(lateral)<=0.8
        self.assertTrue(relevant(2,0.5,20))
        for values in ((-1,0,20),(2,2,20),(4,0,2)):
            self.assertFalse(relevant(*values))

    def test_start_cannot_replace_existing_actor_or_group_owners(self):
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text(encoding='utf-8')
        search=tick.split('case "SEARCH": {',1)[1].split('case "REGROUP": {',1)[0]
        for proof in ('searchIndoorAttempted','searchPointVisited','lastContactObservation',
                      '(_houses select [0,4])','(_team select [0,2])','CBE_fnc_IndoorActorOperation',
                      '["observationOnly",true]','SEARCH_BUILDING_INCOMPLETE','SEARCH_BUILDING_VISITED'):
            self.assertIn(proof,search)
        replacements=search.split('// Shared memory can outlive',1)[1].split('private _searchVisitDone=',1)[0]
        for proof in ('searchIndoorReplacementAttempts','_replacementAttempts < 2','_replacementAttempts >= 2','searchIndoorBuilding','_lostIndoorSlots isNotEqualTo []',
                      'serverTime < (_replacementMemory select 2)','(_replacementMemory select 2) <= _searchDeadline',
                      'CBE_AIPass_Epoch','(_replacementActors select [0,2])',
                      '["searchMemory",+_replacementMemory]','["deadline",_replacementMemory select 2]',
                      '!(_x in _originalInvestigators)','CBE_fnc_CortexActorMoveReserved',
                      'CBE_fnc_IndoorActorGroupAvailable','currentCommand _x == ""'):
            self.assertIn(proof,replacements)
        for forbidden in ('serverTime+45','serverTime + 45','doMove','doFollow','searchPointVisited",true',
                          'searchBuildingVisits",','VISITED','waitAndExecute'):
            self.assertNotIn(forbidden,replacements)
        self.assertIn('["FINISH",_searchActor,_actorBrain] call CBE_fnc_IndoorActorOperation',search)
        self.assertIn('if (_sameIndoorJob && {_casualty}',search)
        self.assertIn('{_team isEqualTo [] && {!_indoorPending}}',search)
        self.assertIn('serverTime-(_observedContact select 2)',tick)
        context=(ROOT/'addons/infantry/functions/indoorActorNativeContext.sqf').read_text(encoding='utf-8')
        for proof in ('SEARCH_MEMORY','_actor distance2D _destination <= 2',
                      '(_x select 2) isEqualTo _searchRoute','_searchTransfer isNotEqualTo []'):
            self.assertIn(proof,context)

        operation=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text(encoding='utf-8')
        dispatch=(ROOT/'addons/infantry/functions/indoorActorDispatch.sqf').read_text(encoding='utf-8')
        selector=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text(encoding='utf-8')
        for proof in ('["defensive",true]','(_actors select [0,3])','_admitted >= 2'):
            self.assertIn(proof,dispatch)
        for proof in ('_node distance2D _origin <= 8','(_origin distance2D _belief)-0.8',
                      'if (_defensive) then {_defensiveOrigin select 2}', '+_searchMemory,_defensive'):
            self.assertIn(proof,selector)
        for proof in ('"REPOSITIONED"','DEFENSIVE_CONTEXT_LOST','if (!_contained',
                      '["defensive",_defensive]','currentCommand _actor == "MOVE"',
                      'if (_ownsLeg && {!_retainDefensive}) then {'):
            self.assertIn(proof,operation)

        memory=operation.split('private _searchMemoryValid=',1)[1].split('private _releaseAvailable=',1)[0]
        for proof in ('count _searchMemory == 4','"phase",""]) == "SEARCH"',
                      'getOrDefault ["searchMemory",[]]) isEqualTo _searchMemory',
                      '(_searchMemory select 3) == (_group getVariable ["CBE_AIPass_Epoch",0])',
                      'serverTime < (_searchMemory select 2)','(_searchMemory select 1)+120',
                      'getOrDefault ["searchDeadline",-1]'):
            self.assertIn(proof,memory)
        self.assertIn('private _selection=if (_assaultEnabled) then {',dispatch)
        self.assertIn('_defensive || {[_group,"CBE_AIPass_Assault_Enable",true]',operation)
        self.assertIn('CBE_AIPass_BuildingCombat_Enable',operation)
        self.assertIn('ASLToAGL _defensiveOrigin',selector)
        self.assertIn('_defensiveOrigin call _positionValid',selector)
        self.assertIn('_positionASL vectorDistance (_brain get "defensiveOrigin") >= 1',operation)
        self.assertIn('["POSITION_LOST"] call _finish',operation)
        self.assertIn('|| {!isNull _contact} || {_clue isNotEqualTo []}',operation)
        self.assertIn('(_belief select 1) isNotEqualTo (_searchMemory select 1)',operation)

        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        start=s.split('if (_mode == "START") exitWith {',1)[1].split('private _current=',1)[0]
        for guard in ('CBE_Cortex_ActorMove','CBE_IndoorActor_Order','CBE_IndoorActor_Brain',
                      'CBE_Operation','CBE_fnc_IndoorActorNativeContext','CBE_IndoorActor_Cooldown',
                      'serverTime-(_belief select 1) > 5','group _actor != _group','count _investigators >= 2'):
            self.assertIn(guard,start)
        self.assertIn('(serverTime+45) min ((_belief select 1)+30)',start)
        self.assertEqual(s.count('_actor doMove _node;'),1)
        self.assertIn('CBE_IndoorActor_Serial',start)
        self.assertIn('_brain,0,_brain get "jobKey"',s)
        self.assertNotIn('netId _actor',s)
        for forbidden in ('setPosATL','setVelocity','forceSpeed','joinSilent','setDamage','doFire'):
            self.assertNotIn(forbidden,s)
    def test_finish_preserves_new_tasks_and_can_run_with_features_disabled(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        finish=s.split('if (_mode == "FINISH") exitWith {',1)[1].split('if (_mode == "START")',1)[0]
        for guard in ('_generation','_epoch','_oldGroup == _group','CBE_OperationGeneration',
                      'CBE_fnc_NativeOrderReceipt','currentCommand _actor == "MOVE"',
                      '_destination vectorDistance _target <= 0.25','isEqualTo _lease',
                      '_reservation isEqualTo _lease || {_migration && {_reservation isEqualTo []}}'):
            self.assertIn(guard,finish)
        self.assertIn('call _releaseAvailable',finish)
        self.assertNotIn('call _available',finish)
        self.assertIn('isNotEqualTo "INDOOR_INVESTIGATE"',finish)
        self.assertIn('_lease call _copyArray',s)
        self.assertIn('(_brain get "route") call _copyArray',s)
        for name in ('cortexLocality','cortexStop'):
            self.assertIn('CBE_fnc_IndoorActorOperation',(ROOT/f'addons/core/functions/{name}.sqf').read_text())
        self.assertIn('CBE_fnc_IndoorActorOperation',(ROOT/'addons/infantry/functions/cortexReleaseGroup.sqf').read_text())
        for name in ('cortexReleaseGroup','cortexOrderLocal'):
            release=(ROOT/f'addons/infantry/functions/{name}.sqf').read_text()
            self.assertIn('["FINISH",_x,_point] call CBE_fnc_PointActorOperation',release)
            self.assertIn('CBE_PointActor_Order',release)
        orders=(ROOT/'addons/infantry/functions/cortexOrderLocal.sqf').read_text()
        self.assertIn('_released=_released || {_garrisonReleased}',orders)
        self.assertIn('_released=_released || {_defendReleased}',orders)
        shared=(ROOT/'addons/infantry/functions/cortexReleaseGroup.sqf').read_text()
        self.assertLess(shared.index('_keepBrain=_keepBrain'),shared.index('private _point='))
        self.assertIn('_reason == "CONTACT_DISABLED"',shared)
        gated=shared.split('if (!_keepBrain) then {',1)[1].split('private _state =',1)[0]
        self.assertIn('call CBE_fnc_PointActorOperation',gated)
        self.assertIn('call CBE_fnc_IndoorActorOperation',gated)

    def test_arrival_is_not_a_room_clear_and_has_finite_failure(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        for guard in ('_height <= 1','_segment isEqualTo []','_roof isNotEqualTo []',
                      '(_hit select 2) == _building','NO_PROGRESS','VISITED','BUILDING_CHANGED'):
            self.assertIn(guard,s)
        self.assertNotIn('_cleared pushBack',s)
        self.assertIn('_positionASL vectorDistance (AGLToASL _target) <= 1.5',s)
        self.assertIn('["progressPosition",getPosASL _actor]',s)
        self.assertNotIn('["progressPosition",getPosATL _actor]',s)
        # Different terrain cells can describe the same actual floor at different ATL heights.
        import math
        self.assertGreater(math.dist((0,0,1),(1,0,4)),1.5)
        self.assertLessEqual(math.dist((0,0,11),(1,0,11)),1.5)

        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        search=tick.split('case "SEARCH": {',1)[1].split('case "REGROUP": {',1)[0]
        self.assertIn('["START",_x,createHashMapFromArray',search)
        self.assertNotIn('["STEP",',tick)
        self.assertNotIn('["QUEUE",',tick)
        fsm=(ROOT/'addons/main/fsm/indoorActor.fsm').read_text()
        self.assertIn('serverTime >= (_brain getOrDefault',fsm)
        self.assertIn('""QUEUE""',fsm)
    def test_planner_has_distinct_native_positions_and_bounded_geometry(self):
        operation=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        history=operation.split('private _recordSearchVisit=',1)[1].split('if (_mode == "FINISH")',1)[0]
        for proof in ('!= "OBSERVE"','vectorDistance (AGLToASL _visitTarget) > 2',
                      'isNotEqualTo _visitTransform','count _visits < 16','searchBuildingVisits',
                      'worldToModel (getPosATL _actor)','_visitSegment isNotEqualTo []',
                      '_visitRoof isEqualTo []','(_visitHit select 3) != _visitHouse'):
            self.assertIn(proof,history)
        self.assertIn('_nodeSearch,_brain getOrDefault ["searchMemory",[]]',operation)
        observe=operation.split('if (_phase == "OBSERVE" &&',1)[1]
        for proof in ('call _recordSearchVisit','_visited < 4','["phase","SELECT"]','VISIT_UNCONFIRMED'):
            self.assertIn(proof,observe)
        self.assertNotIn('["deadline",',observe)
        self.assertNotIn('createHashMap',observe)
        selection=operation.split('if (_phase == "SELECT") exitWith {',1)[1].split('private _target=_brain get "target";',1)[0]
        for proof in ('["ownedRetries",0]) == 0','serverTime-(_brain get "progressAt") >= 12',
                      '_retryOwned || {(getPosASL _actor) vectorDistance (AGLToASL _priorTarget) <= 2}',
                      'if (_retryOwned) then {_brain set ["ownedRetries",1]}',
                      '_escalate || {_retryOwned}','["retryOwned",false]'):
            self.assertIn(proof,selection)
        self.assertNotIn('["deadline",',selection)
        self.assertNotIn('_brain set ["nodeSearch",createHashMap]',selection)
        continuation=operation.split('private _searchLegOwned=',1)[1].split('private _previous=',1)[0]
        for proof in ('call _searchMemoryValid','_native vectorDistance _priorTarget <= 0.25',
                      'vectorDistance (AGLToASL _priorTarget) <= 2','formLeader _actor == (_request select 2)'):
            self.assertIn(proof,continuation)


        s=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text()
        for guard in ('count _positions > 512','_reserved findIf',
                      'abs (_height-_beliefHeight) <= 1.5','_ranked select [0,3]',
                      'private _hit=_hits select 0','_selected isNotEqualTo []'):
            self.assertIn(guard,s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        for proof in ('count _probed >= 12','_previousBinding isNotEqualTo _binding',
                      '_probed findIf {_x vectorDistance _nodeASL < 0.1}',
                      '_search set ["pending"','count _ranked > 3'):
            self.assertIn(proof,s)
        operation=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        self.assertIn('_brain set ["nodeSearch",_nodeSearch]',operation)
        self.assertIn('if (_nodeSearch getOrDefault ["pending",false]) then {-1}',operation)
        # Later native nodes remain selectable without increasing the per-call ray budget.
        def search(nodes,roofed):
            probed=[];counts=[]
            while len(probed)<12:
                batch=[x for x in nodes if x not in probed][:min(3,12-len(probed))]
                if not batch:return None,counts
                counts.append(0)
                for node in batch:
                    probed.append(node);counts[-1]+=1
                    if node in roofed:return node,counts
            return None,counts
        self.assertEqual(search(list(range(20)),{3}),(3,[3,1]))
        self.assertEqual(search(list(range(20)),{11}),(11,[3,3,3,3]))
        self.assertEqual(search(list(range(20)),{12}),(None,[3,3,3,3]))
        self.assertEqual(search([0,1],set()),(None,[2]))

        self.assertNotIn('getPosATL _enemy',s)
        operation=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        self.assertIn('private _initialTarget=if ((_admission select 0) == "OBSERVE")',operation)
        self.assertIn('call _copyArray,+_initialTarget,_lease call _copyArray,false],true]',operation)
        reservation=operation.split('private _reserved=[];',1)[1].split('private _node=',1)[0]
        self.assertIn('_x != _actor',reservation)
        self.assertIn('(_order select 6) isNotEqualTo []',reservation)
        self.assertNotIn('_order select 8',reservation)

    def test_planner_avoids_current_squad_body_overlap_without_enemy_or_world_scan(self):
        s=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text()
        bodies=s.split('private _bodies=[];',1)[1].split('private _ranked=[];',1)[0]
        for guard in ('_x != _actor','alive _x','isNull objectParent _x',
                      'simulationEnabled _x','!isObjectHidden _x','getPosASL _x',
                      '(units group _actor) select [0,16]'):
            self.assertIn(guard,bodies)
        self.assertLess(s.index('_bodies findIf'),s.index('_ranked pushBack'))
        self.assertIn('_searchAllFloors || {abs (_height-_beliefHeight) <= 1.5}',s)
        memory=s.split('private _searchAllFloors=false;',1)[1].split('private _positions=',1)[0]
        for proof in ('isEqualTo _belief','(_searchMemory select 1)+120','searchDeadline','_searchAllFloors=true'):
            self.assertIn(proof,memory)
        self.assertIn('if (_searchAllFloors) then {floor _height} else {0}',s)
        self.assertIn('_positions select (_x select 3)',s)
        self.assertIn('_transform,+_belief,+_searchMemory',s)
        self.assertIn('_x distance2D _nodeASL < 1.5',s)
        self.assertIn('_reservedASL=_reserved apply {AGLToASL _x}',s)
        self.assertIn('_reservedASL findIf {_x vectorDistance _nodeASL < 1.5}',s)
        self.assertIn('_failedNodes findIf {_x vectorDistance _nodeASL < 1.5}',s)

        self.assertIn('abs ((_x select 2)-_height) <= 1',s)
        for forbidden in ('allUnits','nearEntities','nearestObjects','setVariable','_enemy'):
            self.assertNotIn(forbidden,s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        self.assertIn('_ranked select [0,3]',s)
        # Occupancy is floor-specific and temporary, not a failed-node cache entry.
        def occupied(body,node):
            return ((body[0]-node[0])**2+(body[1]-node[1])**2)**0.5<1.5 and abs(body[2]-node[2])<=1
        self.assertTrue(occupied((0.5,0,10),(0,0,10)))
        self.assertFalse(occupied((0.5,0,13),(0,0,10)))
        self.assertFalse(occupied((2,0,10),(0,0,10)))

    def test_physical_fixture_has_real_prerequisites_and_no_positive_shortcuts(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorActors.sqf').read_text()
        for guard in ('INDOOR-idle-owner-prerequisite','INDOOR-pair-physical-entry',
                      'INDOOR-pair-destinations','INDOOR-same-actor-repeat',
                      'INDOOR-stale-belief-refused','INDOOR-reservation-refused',
                      'INDOOR-stop-refused','INDOOR-native-move-handover',
                      '_visits findIf {!_x} < 0','_travel findIf {_x < 5} < 0',
                      '_repeatVisited','_outside','_destinationKept','_targetsStable',
                      '_repeatGeneration > (_generations select 0)','_interruptGeneration'):
            self.assertIn(guard,s)
        self.assertIn('call CBE_fnc_IndoorActorOperation',s)
        for forbidden in ('BIS_fnc_door','enableAI','setDestination','CBE_IndoorActor_Cooldown",nil',
                          'setVariable ["CBE_IndoorActor_Result"','_unit setPos','_actor setPos'):
            self.assertNotIn(forbidden,s)
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text()
        self.assertIn('if (_focus == "indooractors") exitWith',server)
        self.assertIn('cortexQAIndoorActors.sqf',server)
        from mod_pipeline import supported_focuses
        self.assertIn('indooractors',supported_focuses())

    def test_locality_retires_old_private_pointer_even_without_public_journal(self):
        s=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text()
        start=s.index('private _indoor=_unit getVariable')
        end=s.index('// Event-handler IDs',start)
        block=s[start:end]
        self.assertLess(block.index('_indoor set ["finished",true]'),block.index('["TRANSFER"'))
        self.assertIn('isEqualTo _indoor',block)
        self.assertLess(block.index('["TRANSFER"'),block.index('_unit setVariable ["CBE_IndoorActor_Brain",nil]'))
        self.assertIn('_unit setVariable ["CBE_IndoorActor_FSM",nil]',block)
        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertEqual(stop.count('call CBE_fnc_IndoorActorOperation'),1)
        early=stop.split('call CBE_fnc_IndoorActorOperation',1)[0].rsplit('private _indoor=',1)[1]
        self.assertIn('count _indoor > 0',early)
        self.assertNotIn('select [0,16]',stop.split('call CBE_fnc_IndoorActorOperation',1)[1].split('CortexHearingLocal',1)[0])
        actor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        reap=actor.split('if (_mode == "REAP") exitWith {',1)[1].split('if (_mode == "QUEUE")',1)[0]
        self.assertIn('!_current || {!local _actor} || {!local _group}',reap)
        self.assertIn('!completedFSM _handle',reap)
        self.assertIn('if (_alive) exitWith {false}',reap)
        self.assertIn('!(_brain getOrDefault ["finished",false])',reap)
        self.assertIn('(_brain getOrDefault ["reason",""]) == ""',reap)
        self.assertIn('["FINISH",_actor,_brain]',reap)
        self.assertNotIn('doMove',reap)
        self.assertNotIn('"START"',reap)
        self.assertNotIn('serverTime+',reap)
        discovery=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        self.assertIn('count _indoorActors <= 2',discovery)
        self.assertIn('["REAP",_x,_indoorBrain]',discovery)
        self.assertIn('group _x == _group',discovery)
        self.assertIn('"FSM_START_FAILED"',actor)

    def test_owner_helpers_are_installed_and_server_authenticated(self):
        init=(ROOT/'releaseVerificationAndDeployment/auditMission/init.sqf').read_text()
        for name in ('cortexQAPerformanceOwner.sqf','cortexQAIndoorActorOwner.sqf'):
            self.assertIn('preprocessFileLineNumbers "'+name+'"',init)
        self.assertIn('!isNil "CBE_CortexQA_IndoorActorAckServer"',init)
        helper=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorActorOwner.sqf').read_text()
        for guard in ('remoteExecutedOwner != 2','local _actor','local group _actor',
                      '_serial <=','CBE_CortexQA_IndoorConsumed','CBE_CortexQA_IndoorPending',
                      '(_pending select 2) != _sender','owner _actor != _sender',
                      'count _brain == 0','CBE_IndoorActor_Order','_actor doMove _goal'):
            self.assertIn(guard,helper)
        for forbidden in ('setVariable ["CBE_IndoorActor_Order"','setVariable ["CBE_IndoorActor_Result"','enableAI','setPos'):
            self.assertNotIn(forbidden,helper)
        performance=(ROOT/'releaseVerificationAndDeployment/cortexQA/runPerformanceOwner.sqf').read_text()
        self.assertEqual(performance.count('remoteExecutedOwner != 2'),3)
    def test_hc_fixture_requires_real_transfer_and_physical_new_work(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorActorsHC.sqf').read_text()
        for guard in ('Waldo_fnc_HeadlessMigrateGroup','Waldo_Headless_Clients',
                      'call CBE_fnc_HeadlessMigrateGroup','"COMPANION"','owner _actor == _owner',
                      '"STATUS",_owner','"MOVE",_owner','-hc-native-physical',
                      '-return-pointer-retired','-old-callback-overlap','-returned-repeat-physical',
                      '_repeatGeneration > _oldGeneration','call _physicalVisit','_repeatDeadline',
                      'if (_localRetired) then','_targetKept'):
            self.assertIn(guard,s)
        for forbidden in ('setGroupOwner','BIS_fnc_door','enableAI','setDestination',
                          'setVariable ["CBE_IndoorActor_Cooldown"','_actor setPos'):
            self.assertNotIn(forbidden,s)

    def test_native_context_binds_actual_contact_and_protects_mission_paths(self):
        s=(ROOT/'addons/infantry/functions/indoorActorNativeContext.sqf').read_text()
        for guard in ('getAttackTarget _actor','assignedTarget _actor','_assigned != _contact',
                      '_engaging != _contact','_actor knowsAbout _contact >= 1','"PLANNING"',
                      'waypointType _waypoint != "MOVE"','waypointScript _waypoint != ""',
                      'waypointStatements','waypointTimeout','synchronizedTriggers',
                      'synchronizedWaypoints','waypointAttachedObject','waypointAttachedVehicle',
                      '_unitState == "BUSY"','_nativeFiringClear','_destination vectorDistance _belief <= 2.5'):
            self.assertIn(guard,s)
        self.assertIn('["OBSERVE","COMBAT_APPROACH"',s)
        self.assertIn('_unitState in ["INIT","PLANNING","REPLAN"]',s)
        # Preflight shares task vetoes but cannot issue a usable native receipt or ray query.
        self.assertIn('["_preflight",false,[true]]',s)
        self.assertIn('if (!_preflight && {_contactValid}',s)
        self.assertIn('if (_observe && {_preflight}) exitWith {["PREFLIGHT"]}',s)
        self.assertLess(s.index('if (_observe && {_preflight})'),s.index('boundingBoxReal _building'))
        self.assertIn('if (_preflight) exitWith {["PREFLIGHT"]}',s)
        self.assertLess(s.index('if (!_mayIssue)'),s.index('if (_preflight) exitWith {["PREFLIGHT"]}'))
        dispatch=(ROOT/'addons/infantry/functions/indoorActorDispatch.sqf').read_text()
        self.assertIn('[_x,_target,_position,objNull,true] call CBE_fnc_IndoorActorNativeContext',dispatch)
        self.assertLess(dispatch.index('call CBE_fnc_IndoorActorNativeContext'),dispatch.index('call CBE_fnc_BuildingContactSelect'))
        self.assertNotIn('getPosATL _contact',s)
        for command in (' doMove ','doFollow','doTarget','doFire','setDestination'):
            self.assertNotIn(command,s)
    def test_native_ignore_cancels_only_contact_driven_indoor_work(self):
        admission=(ROOT/'addons/infantry/functions/indoorActorNativeContext.sqf').read_text()
        operation=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        door=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        self.assertIn('!((_actor targetKnowledge _contact) param [7,false,[true]])',admission)

        selection=(ROOT/'addons/infantry/functions/buildingContactSelect.sqf').read_text()
        self.assertIn('!captive _enemy',selection)
        for text in (admission,operation,door):
            self.assertIn('captive _contact',text)
        for marker in ('ace_captives_isSurrendering','ace_captives_isHandcuffed'):
            for text in (selection,admission,operation,door):
                self.assertIn(marker,text)
        stop=operation.index('["TARGET_IGNORED"] call _finish')
        self.assertLess(stop,operation.index('private _phase=_brain get "phase";'))
        self.assertIn('(_actor targetKnowledge _contact) param [7,false,[true]]',operation[:stop])
        indoor=door.split('if ((_context select 0) == "INDOOR") exitWith {',1)[1].split('private _combatCommand=',1)[0]
        self.assertIn('(_unit targetKnowledge _contact) param [7,false,[true]]',indoor)
        for source in (admission,operation,door):
            code=re.sub(r'/\*.*?\*/|//[^\n]*','',source,flags=re.S)
            self.assertNotIn(' ignoreTarget ',code)

    def test_native_observation_does_not_issue_until_a_measured_stall(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        observe=s.split('if ((_admission select 0) == "OBSERVE" && {!_escalate}) exitWith {',1)[1].split('if (_escalate',1)[0]
        self.assertNotIn('doMove',observe)
        self.assertNotIn('set ["issued",true]',observe)
        for guard in ('serverTime-(_brain get "progressAt") < 12','["escalations",1]',
                      '_reserved pushBack +(_brain get "target")','currentCommand _actor == "FIRE"',
                      'getUnitState _actor in ["INIT","PLANNING","REPLAN"]','contactRequired','vectorDistance (_brain get "progressPosition") >= 1','_admission isNotEqualTo (_brain get "admission")'):
            self.assertIn(guard,s)
        self.assertEqual(s.split("_brain=createHashMapFromArray",1)[1].count('["deadline",_deadline]'),1)
        self.assertNotIn('_brain set ["deadline",',s)
        self.assertIn('_deadline=_deadline min _requestedDeadline',s)
        self.assertIn('finite _requestedDeadline',s)
        dispatch=(ROOT/'addons/infantry/functions/indoorObservationDispatch.sqf').read_text()
        for guard in ('_expires <= _observed+20','CBE_AIPass_Epoch','select [0,16]',
                      'select [0,4]','select [0,2]','["deadline",_expires]','["observationOnly",true]',
                      'count _nodes <= 512','serverTime >= _expires'):
            self.assertIn(guard,dispatch)
        self.assertEqual(dispatch.count('setVariable ["CBE_Danger_BuildingClue",nil,true]'),1)
        self.assertIn('["observationClue",_clue]',dispatch)
        validation=dispatch.split('private _valid=',1)[1].split('if (!_valid)',1)[0]
        self.assertIn('_witness isEqualType objNull',validation)
        for obsolete in ('!isNull _witness','group _witness','local _witness','[_witness] call CBE_fnc_CortexCombatEffective'):
            self.assertNotIn(obsolete,validation)
        for retained in ('_expires <= _observed+20','serverTime < _expires',
                         '_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])'):
            self.assertIn(retained,validation)
        roster=dispatch.split('private _actors=',1)[1].split('if (_actors isEqualTo [])',1)[0]
        self.assertIn('local _x',roster)
        self.assertIn('CortexCombatEffective',roster)
        self.assertIn('CortexActorMoveReserved',roster)
        for name in ('indoorActorOperation','pointActorOperation'):
            operation=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
            available=operation.split('private _available=',1)[1].split('if (_mode',1)[0]
            self.assertIn('unitCombatMode _actor in ["YELLOW","RED","WHITE"]',available)
            release=operation.split('private _releaseAvailable=',1)[1].split('private _available=',1)[0]
            self.assertNotIn('unitCombatMode',release)
            step=operation.split('if (_mode != "STEP")',1)[1] if name=='pointActorOperation' else operation.split('if (serverTime >= (_brain get "deadline"))',1)[1]
            self.assertIn('call _available',step)
        def permitted(group_mode,actor_mode):
            return group_mode in ('YELLOW','RED','WHITE') and actor_mode in ('YELLOW','RED','WHITE')
        self.assertTrue(permitted('RED','YELLOW'))
        self.assertTrue(permitted('YELLOW','WHITE'))
        self.assertFalse(permitted('RED','GREEN'))
        self.assertFalse(permitted('RED','BLUE'))
        self.assertFalse(permitted('BLUE','RED'))
        for candidate_source in (dispatch,(ROOT/'addons/infantry/functions/indoorActorDispatch.sqf').read_text()):
            candidates=candidate_source.split('private _actors=',1)[1].split('if (_actors isEqualTo [])',1)[0]
            for gate in ('simulationEnabled _x','!isObjectHidden _x',
                         'checkAIFeature "MOVE"','checkAIFeature "PATH"',
                         'getSuppression _x < 0.5','currentWeapon _x != ""','CortexExternalOwner','unitCombatMode _x in ["YELLOW","RED","WHITE"]'):
                self.assertIn(gate,candidates)
            for query in ('lineIntersectsSurfaces','nearestObjects','checkVisibility'):
                self.assertNotIn(query,candidates)
        self.assertIn('!(behaviour _x in ["STEALTH","CARELESS"])',roster)
        self.assertIn('(_rankedActors select [0,2])',dispatch)


        actor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        visits=actor.split('// Keep only historical physical visits',1)[1].split('CBE_IndoorActor_Result',1)[0]
        for proof in ('== "VISITED"','== "OBSERVE"','vectorDistance (AGLToASL _target) <= 2',
                      'isEqualTo _transform','serverTime < (_clue select 2)','count _visits < 16'):
            self.assertIn(proof,visits)
        self.assertNotIn('serverTime+',visits)
        nodes=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text()
        self.assertIn('count _reservedASL >= 16',nodes)
        self.assertIn('(_history select 0) isEqualTo _clue',nodes)
        self.assertIn('CBE_Danger_BuildingVisits",nil', (ROOT/'addons/core/functions/cortexStop.sqf').read_text())

        self.assertNotIn(' doMove ',dispatch)
        self.assertNotIn('["contact",',dispatch)
        self.assertIn('!_observationOnly ||',s)
        self.assertIn('CBE_AIPass_Investigate_Enable',s)

        approach=s.split('if (_phase == "APPROACH") exitWith {',1)[1]
        self.assertLess(approach.index('if (getUnitState _actor in ["INIT","PLANNING","REPLAN"]) exitWith {-1}'),approach.index('if (serverTime-(_brain get "progressAt") >= 12)'))
        finish=s.split('if (_mode == "FINISH") exitWith {',1)[1].split('if (_mode == "START")',1)[0]
        self.assertIn('private _ownsLeg=_issued',finish)
        self.assertIn('_actor doMove waypointPosition _waypoint;',finish)
        # A native issue may not acknowledge its new target before the next callback.
        acknowledgement=s.split('private _awaitingMove=false;',1)[1].split('if (_phase == "APPROACH") exitWith',1)[0]
        for guard in ('"APPROACH"','"issued",false','serverTime-_requestAt < 2',
                      '(expectedDestination _actor) isEqualTo (_before select 1)',
                      'formLeader _actor isEqualTo (_before select 2)',
                      'currentCommand _actor in [_before select 0,"MOVE"]'):
            self.assertIn(guard,acknowledgement)
        self.assertNotIn('doMove',acknowledgement)
        self.assertNotIn('set ["requestIssuedAt"',acknowledgement)
        self.assertLess(s.index('_brain set ["requestIssuedAt",serverTime]'),s.index('_actor doMove _node'))
        self.assertEqual(s.count('_brain set ["requestIssuedAt",serverTime]'),1)

    def test_routine_group_reposition_cannot_steal_an_actor_leg(self):
        s=(ROOT/'addons/infantry/functions/cortexTacticalReposition.sqf').read_text()
        guard=s.index('if ((units _group) findIf {alive _x && {getUnitState _x in ["INIT","PLANNING","REPLAN"]')
        self.assertLess(s.index('call CBE_fnc_CortexRetreat'),guard)
        self.assertLess(guard,s.index('call CBE_fnc_CortexFindCover'))
        self.assertLess(guard,s.index('call CBE_fnc_CortexOwnershipLease'))
        self.assertIn('CBE_fnc_CortexActorFireTaskAvailable',s[guard:s.index('private _toward=',guard)])
        task=(ROOT/'addons/infantry/functions/cortexActorFireTaskAvailable.sqf').read_text()
        self.assertIn('[_actor] call CBE_fnc_CortexActorMoveReserved',task)
        self.assertIn('"HEAL"',task)
        shared=(ROOT/'addons/infantry/functions/cortexActorMoveReserved.sqf').read_text()
        for marker in ('_lease isEqualTo []','finite (_lease select 2)','!_expired'):
            self.assertIn(marker,shared)

    def test_door_side_effect_rechecks_contact_and_higher_priority_tasks(self):
        s=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        indoor=s.split('if ((_context select 0) == "INDOOR") exitWith {',1)[1].split('private _key=switch',1)[0]
        for guard in ('contactRequired','isNull _contact','!alive _contact','_engaging != _contact',
                      '_assigned != _contact','CBE_AIPass_Active','CBE_AIPass_BuildingCombat_Enable',
                      'CBE_AIPass_Assault_Enable','CBE_AIPass_Garrison','CBE_AIPass_Defend',
                      'CBE_AIPass_ClearBuilding','_destination call _vectorValid','_target call _vectorValid',
                      'getSuppression _unit < 0.5','checkAIFeature "PATH"'):
            self.assertIn(guard,indoor)
        final=s.split('if (_near && {_visible}',1)[1].split('call BIS_fnc_door',1)[0]
        self.assertIn('call _orderCurrent',final)
        self.assertIn('(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []',final)
        admission=s.split('if (isNull _unit ||',1)[1].split('private _doorCount=',1)[0]
        self.assertIn('(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []',admission)
        self.assertNotIn('setVariable ["ace_medical_ai_healQueue"',s)

    def test_existing_disjoint_roster_requires_current_bounded_actor_ownership(self):
        s=(ROOT/'addons/infantry/functions/indoorActorGroupAvailable.sqf').read_text()
        context=(ROOT/'addons/infantry/functions/indoorActorGroupContext.sqf').read_text()
        s+=context
        for guard in ('participantsRequired','ownerEpoch','CBE_OperationGeneration','cancelReason',
                      'count _participants > 64','_participants isEqualTo []','group _x != _group',
                      'CBE_Cortex_GroupMoveIntent','supportHeld','CBE_AIPass_ClearBuilding',
                      '!(_actor in _participants)','["ADVANCE","FLANK","ASSAULT"]'):
            self.assertIn(guard,s)
        actor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        self.assertEqual(actor.count('call CBE_fnc_IndoorActorGroupAvailable'),5)
        self.assertIn('CBE_OperationGeneration',actor)
        door=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        self.assertIn('[_unit] call CBE_fnc_IndoorActorGroupAvailable',door)
        available=(ROOT/'addons/infantry/functions/indoorActorGroupAvailable.sqf').read_text()
        self.assertIn('if (count _this < 2)',available)
        self.assertIn('call CBE_fnc_IndoorActorGroupContext',available)
        for name in ('indoorActorDispatch','indoorObservationDispatch'):
            dispatch=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
            self.assertEqual(dispatch.count('call CBE_fnc_IndoorActorGroupContext'),1)
            self.assertLess(dispatch.index('call CBE_fnc_IndoorActorSample'),dispatch.index('call CBE_fnc_IndoorActorGroupContext'))
            self.assertIn('if (_sample isEqualTo []) exitWith {0}',dispatch)
            self.assertIn('[_x,_groupContext] call CBE_fnc_IndoorActorGroupAvailable',dispatch)

        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        admission=tick.split('// Actor admission does not claim',1)[1].split('call CBE_fnc_IndoorActorDispatch;',1)[0]
        self.assertNotIn('!_coordinatedOwnsMovement',admission)
        for guard in ('!_holdFire','_hasTargetKnowledge','!_ordered','!_buildingOwnsMovement'):
            self.assertIn(guard,admission)
        self.assertIn('call CBE_fnc_CortexVehicles) || {_groupMovementOwned}',tick)


    def test_disjoint_generation_acknowledgement_never_renews_actor_work(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        acknowledgement=s.split('private _operationGeneration=_group getVariable',1)[1].split('if (!(call _available)',1)[0]
        for guard in ('count (_group getVariable ["CBE_Operation",createHashMap]) > 0',
                      'CBE_fnc_IndoorActorGroupAvailable','(_journal select 0) == (_brain get "generation")',
                      '(_journal select 1) == (_brain get "ownerEpoch")','(_journal select 2) == _group',
                      '(_journal select 3) == (_brain get "operationGeneration")',
                      '(_journal select 7) isEqualTo (_brain get "lease")','_journal set [3,_operationGeneration]'):
            self.assertIn(guard,acknowledgement)
        for forbidden in ('doMove','doFollow','set ["deadline"','set ["lease"','set ["target"','set ["progressAt"'):
            self.assertNotIn(forbidden,acknowledgement)

    def test_natural_dispatch_is_bounded_and_does_not_claim_the_squad(self):
        s=(ROOT/'addons/infantry/functions/indoorActorDispatch.sqf').read_text()
        for guard in ('"indoorActors",8','CBE_fnc_IndoorActorSample','_admitted >= 2','knowsAbout _contact >= 1',
                      'distance2D (_belief select 0) <= (_range min 40)','CBE_AIPass_BuildingCombat_Range','CBE_IndoorActor_Cooldown',
                      'CBE_fnc_IndoorActorGroupAvailable','CBE_fnc_BuildingContactSelect',
                      '["contact",_contact]','["belief",_belief]'):
            self.assertIn(guard,s)
        for forbidden in ('doMove','doFollow','getPosATL _contact','setVariable ["CBE_Operation"'):
            self.assertNotIn(forbidden,s)
        # Availability must constrain contact choice before any roof queries, not only
        # reject the selected contact afterward. Preserve the bounded shared selector.
        self.assertLess(s.index('private _actors='),s.index('private _actionable='))
        self.assertLess(s.index('private _actionable='),s.index('call CBE_fnc_BuildingContactSelect'))
        self.assertIn('_enemies select [0,8]',s)
        for guard in ('_brain getOrDefault ["building",objNull]','_brain getOrDefault ["contact",objNull]',
                      '_brain getOrDefault ["deadline",-1]','CBE_IndoorActor_Generation','_nonLeaders >= 2',
                      '[_group,_pairCandidates,2,1,_incumbents] call CBE_fnc_CombatElementSelect',
                      '(_rankedActors-_preferred)','forEach _orderedActors'):
            self.assertIn(guard,s)
        self.assertLess(s.index('knowsAbout _contact >= 1'),s.index('call CBE_fnc_CombatElementSelect'))
        self.assertNotIn('call CBE_fnc_CombatPairsPublish',s)

        for name in ('indoorActorDispatch','indoorObservationDispatch'):
            dispatcher=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
            roster=dispatcher.split('private _actors=',1)[1].split('if (_actors isEqualTo [])',1)[0]
            self.assertIn('!fleeing _x',roster)
            self.assertIn('ace_medical_ai_healQueue',roster)
        context=(ROOT/'addons/infantry/functions/indoorActorNativeContext.sqf').read_text()
        self.assertLess(context.index('fleeing _actor'),context.index('checkVisibility'))
        for name in ('indoorActorOperation','pointActorOperation'):
            operation=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
            release=operation.split('private _releaseAvailable=',1)[1].split('private _available=',1)[0]
            self.assertIn('!fleeing _actor',release)
        indoor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        available=indoor.split('private _available=',1)[1].split('// Only STEP',1)[0]
        self.assertIn('!fleeing _actor',available)
        # The nearest two may be queued for care while their native command is still idle.
        candidates=[(1,True,False),(2,True,False),(3,False,True),(4,False,False),(5,False,False)]
        ready=[distance for distance,care,flee in candidates if not care and not flee]
        self.assertEqual(ready[:2],[4,5])

        sample=(ROOT/'addons/infantry/functions/indoorActorSample.sqf').read_text()
        self.assertIn('private _budget=_count min 16;',sample)
        self.assertIn('((_cursor+_offset) mod _count)',sample)
        self.assertLess(sample.index('if (_active >= 2)'),sample.index('indoorActorCursor'))
        self.assertIn('count _investigators > 2',sample)
        self.assertNotIn('doMove',sample)
        operation=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        self.assertNotIn('private _members=(units _group) select [0,16]',operation)
        observation=(ROOT/'addons/infantry/functions/indoorObservationDispatch.sqf').read_text()
        self.assertLess(observation.index('"bodyBuilding",8'),observation.index('call CBE_fnc_IndoorActorSample'))
        def window(roster,cursor,active):
            if active>=2 or not roster:
                return [],cursor
            cursor%=len(roster)
            size=min(16,len(roster))
            return [roster[(cursor+i)%len(roster)] for i in range(size)],(cursor+size)%len(roster)
        for size in (0,1,12,17,32,48,65):
            roster=list(range(size)); cursor=0; seen=set()
            for _ in range((size+15)//16):
                batch,cursor=window(roster,cursor,0)
                self.assertLessEqual(len(batch),16)
                self.assertEqual(len(set(batch)),len(batch))
                seen.update(batch)
            self.assertEqual(seen,set(roster))
        roster=list(range(32)); _,cursor=window(roster,0,0)
        for _ in range(8):
            batch,cursor=window(roster,cursor,2)
            self.assertEqual(batch,[])
            self.assertEqual(cursor,16)
        batch,cursor=window(roster,cursor,1)
        self.assertEqual(batch,list(range(16,32)))

        self.assertIn('_actors findIf',s)
        self.assertIn('[_group,_actionable,_range]',s)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        self.assertLess(tick.index('call CBE_fnc_CortexBuildingContact'),tick.index('call CBE_fnc_IndoorActorDispatch'))
        self.assertLess(tick.index('call CBE_fnc_IndoorActorDispatch'),tick.index('call CBE_fnc_CortexTacticalStart'))
        clear=(ROOT/'addons/infantry/functions/cortexBuildingContact.sqf').read_text()
        self.assertLess(clear.index('CBE_IndoorActor_Actors'),clear.index('call CBE_fnc_CortexClearBuilding'))

    def test_natural_fixture_requires_engine_discovery_and_real_dispatch(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorNatural.sqf').read_text()
        for guard in ('INDOOR-NATURAL-placement-access','INDOOR-NATURAL-engine-knowledge','INDOOR-NATURAL-dispatch-admission',
                      'INDOOR-NATURAL-physical-entry','knowsAbout _enemy >= 1',
                      '_brain getOrDefault ["contact"','_brain getOrDefault ["building"',
                      '_travel findIf {_x < 5} < 0','_roof isNotEqualTo []'):
            self.assertIn(guard,s)
        for forbidden in ('["START"','call CBE_fnc_IndoorActorDispatch','call CBE_fnc_CortexGroupTick',
                          ' reveal ','BIS_fnc_door','setVariable ["CBE_IndoorActor_Result"','enableAI','_actor setPosATL','_enemy setPosATL'):
            self.assertNotIn(forbidden,s)
        from mod_pipeline import supported_focuses
        self.assertIn('indoornatural',supported_focuses())
        pipeline=(ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text()
        self.assertIn("('indooractors','indooractorshc','indoornatural')",pipeline)

    def test_post_contact_and_boarding_treat_unknown_reservations_as_owned(self):
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        predicate=tick.split('private _hasLiveActorMove = {',1)[1].split('private _get =',1)[0]
        for guard in ('_actorMove isEqualTo []','_actorMove isEqualType []',
                      'finite (_actorMove select 2)','count (_actorMove select 1) == 3','!_expired'):
            self.assertIn(guard,predicate)
        passenger=(ROOT/'addons/vehicles/functions/cortexPassengerReady.sqf').read_text()
        for guard in ('if (_reserved) exitWith {false}','!finite (_reservation select 2)',
                      'count (_reservation select 1) != 3','findIf {!(_x isEqualType 0) || {!finite _x}} >= 0'):
            self.assertIn(guard,passenger)

    def test_failed_indoor_nodes_are_temporary_scoped_observations(self):
        actor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        cache=actor.split('// A failed issued leg',1)[1].split('_actor setVariable ["CBE_IndoorActor_Result"',1)[0]
        for guard in ('!_migration','_issued','"NO_PROGRESS"','_oldGroup == _group',
                      'serverTime+60','select [0,4]','_failed deleteAt 0','_transform call _copyArray'):
            self.assertIn(guard,cache)
        self.assertNotIn('true]',cache)
        planner=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text()
        for guard in ('_failedNodes findIf','(_x select 1) isEqualTo _transform',
                      'serverTime < (_x select 3)','(_x select 4) isEqualTo _epoch','select [0,4]'):
            self.assertIn(guard,planner)
        self.assertNotIn('setVariable',planner)

    def test_fresh_group_adoption_precedes_actor_publication(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        start=s.split('if (_mode == "START") exitWith {',1)[1].split('private _current=',1)[0]
        adopt=start.index('[_group,true] call CBE_fnc_CortexLocality')
        self.assertLess(start.index('if !(call _available)'),adopt)
        self.assertLess(adopt,start.index('private _admission='))
        self.assertLess(adopt,start.index('_actor setVariable ["CBE_IndoorActor_Order"'))
        recheck=start[adopt:start.index('private _admission=')]
        for guard in ('call _available','CBE_AIPass_Adopted','CBE_AIPass_Epoch','serverTime-(_belief select 1) > 5'):
            self.assertIn(guard,recheck)

    def test_explicit_clear_preflight_can_replace_only_matching_indoor_jobs(self):
        s=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        preflight=s.split('private _replaceIndoor=',1)[1].split('// Natural contact requires',1)[0]
        for guard in ('!_resume','"preserveBrain",false','isEqualTo false','CBE_fnc_CortexActorMoveReserved',
                      'count _journal == 9','"finished",true','"generation",-1','"ownerEpoch",-1',
                      '(_journal select 2) == _group','(_journal select 7) isEqualTo _reservation',
                      '(_indoor getOrDefault ["lease",[]]) isEqualTo _reservation'):
            self.assertIn(guard,preflight)
        for forbidden in ('setVariable','call CBE_fnc_IndoorActorOperation','doMove','doFollow'):
            self.assertNotIn(forbidden,preflight)
        self.assertLess(s.index('INVALID_ACTOR_MINIMUM'),s.index('call CBE_fnc_CortexReleaseGroup'))
        self.assertLess(s.index('NO_VALID_ROOFED_POSITIONS'),s.index('private _replaceIndoor='))

    def test_explicit_release_retires_indoor_jobs_without_generic_group_reset(self):
        s=(ROOT/'addons/infantry/functions/cortexOrderLocal.sqf').read_text()
        release=s.split('case "RELEASE": {',1)[1].split('case "EXCLUDE": {',1)[0]
        for guard in ('CBE_IndoorActor_Brain','CBE_IndoorActor_Order','["FINISH",_x,_indoor]',
                      '_released=_released || {_retired}','forEach units _group'):
            self.assertIn(guard,release)
        self.assertNotIn('select [0,16]',release)
        self.assertNotIn('CBE_fnc_CortexReleaseGroup',release)
        self.assertNotIn('doMove',release)
        self.assertNotIn('doFollow',release)

    def test_garrison_and_defend_use_same_reservation_boundary(self):
        for name,expected in [('cortexGarrison',3),('cortexGarrisonApplyLocal',4),('cortexDefendApplyLocal',2)]:
            text=(ROOT/('addons/infantry/functions/'+name+'.sqf')).read_text()
            self.assertEqual(text.count('call CBE_fnc_CortexActorMoveReserved'),expected,name)
            self.assertNotIn('_reservation param [2,1e12,[0]]',text)
        garrison=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        teleport=garrison.split('if (_teleport) then {',1)[1]
        self.assertLess(teleport.index('call CBE_fnc_CortexActorMoveReserved'),teleport.index('_unit setPosATL'))
        self.assertIn('{_free}',teleport)

    def test_defend_deferred_actor_keeps_arrival_job_alive(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendApplyLocal.sqf').read_text()
        deferred=s.split('if (_routeCurrent && {!_canIssue}) then {',1)[1].split('if (_canIssue) then {',1)[0]
        self.assertIn('_pending=_pending+1',deferred)
        self.assertIn('set [2,time]',deferred)
        for command in ('doMove','doStop','doFollow','enableAI','forceSpeed'):
            self.assertNotIn(command,deferred)
        self.assertIn('group _unit == _group',s)
        self.assertIn('[2, -1] select (_pending == 0)',s)
    def test_garrison_deferral_preserves_original_deadline_and_retries(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        deferred=s.split('// A reservation defers both route retries',1)[1].split('private _openedDoor',1)[0]
        for guard in ('serverTime <= (_job get "deadline")','_pending=_pending+1',
                      '_deferredRoute set [3,time]','CBE_AIPass_GarrisonFailed','group _x == _group'):
            self.assertIn(guard,deferred)
        self.assertNotIn('serverTime+',deferred)
        self.assertNotIn('doMove',deferred)
        self.assertIn('&& {[_x] call _mayIssueMovement}) then {',deferred)
    def test_release_paths_preserve_unknown_actor_reservations(self):
        for name in ('cortexClearRelease','cortexDefendRelease','cortexGarrisonRelease','dangerEngineRelease'):
            s=(ROOT/('addons/infantry/functions/'+name+'.sqf')).read_text()
            self.assertIn('call CBE_fnc_CortexActorMoveReserved',s,name)
            self.assertNotIn('_reservation param [2,',s,name)
        danger=(ROOT/'addons/infantry/functions/dangerEngineRelease.sqf').read_text()
        self.assertLess(danger.index('call CBE_fnc_CortexActorMoveReserved'),danger.index('_actor setUnitPosWeak'))
    def test_clearance_workers_and_reserves_share_reservation_boundary(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        available=s.split('private _actorAvailable={',1)[1].split('private _actorTaskFree=',1)[0]
        reserve=s.split('private _reserveReady={',1)[1].split('private _reserves=',1)[0]
        for boundary in (available,reserve):
            self.assertIn('call CBE_fnc_CortexActorMoveReserved',boundary)
            self.assertNotIn('_reservation param [2,',boundary)
        for guard in ('_stageCommandFree','call _ownsCurrentMove','!(_candidate in _unavailable)',
                      'CBE_fnc_CompatibilityExternalControl'):
            self.assertIn(guard,reserve)
    def test_post_clear_reserved_stop_retains_changed_order_handover(self):
        s=(ROOT/'addons/infantry/functions/groupBrainStep.sqf').read_text()
        hold=s.split('private _clearHold=',1)[1].split('private _legacyJob=',1)[0]
        retry=hold.split('// A newer individual order retires',1)[1]
        for guard in ('currentCommand _x == "STOP"','group _x == _group',
                      'call CBE_fnc_CortexActorMoveReserved','_deferred pushBackUnique _x',
                      '_clearHold select 0,_clearHold select 1,_clearHold select 2,_deferred'):
            self.assertIn(guard,retry)
        self.assertNotIn('doFollow',retry)
        self.assertNotIn('doMove',retry)
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',hold)
    def test_garrison_refill_cannot_spend_reserved_exit_cover(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        other=s.split('// Never vacate the sole assigned observation post',1)[1].split('} >= 0;',1)[0]
        for guard in ('!([_x] call CBE_fnc_CortexActorMoveReserved)',
                      'currentCommand _x in ["","STOP"]','isNull remoteControlled _x',
                      'isNull objectParent _x','call CBE_fnc_CortexGarrisonArrived'):
            self.assertIn(guard,other)
        self.assertIn('private _free=!([_actor] call CBE_fnc_CortexActorMoveReserved)',s)
    def test_stretched_convoy_does_not_count_reverse_motion_as_forward_progress(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        pacing=s.split('if (_gap > _target*2) then {',1)[1].split('_leadLimit=_leadLimit min _catchup',1)[0]
        self.assertNotIn('abs speed _follower',pacing)
        self.assertIn('velocityModelSpace _follower select 1',pacing)
        self.assertIn('max 0)*3.6',pacing)
        self.assertIn('_followerForwardKmh',pacing)
        self.assertIn('max 5',pacing)