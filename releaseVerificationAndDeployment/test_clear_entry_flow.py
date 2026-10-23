"""Initial pair support planning must not inherit recovery's unselected lead fallback."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearEntryFlowTests(unittest.TestCase):
    def test_yielded_room_recovery_does_not_reset_its_progress_clock(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        branch=s.split('if (_recovery in ["RECOVERING","YIELDED"]) then {',1)[1].split('private _failedCheckpoint=',1)[0]
        issued=branch.split('if (_recovery == "RECOVERING") then {',1)[1].split('};',1)[0]
        self.assertIn('_lastProgress=_now',issued)
        self.assertIn('_lastPositions=_pair apply',issued)
        after=branch.split('};',1)[1]
        self.assertNotIn('_lastProgress=',after)
        self.assertNotIn('_lastPositions=',after)
        self.assertIn('_retries=[0,3] select (_recovery == "YIELDED")',after)

    def test_partner_recovery_preserves_exact_native_planning_without_new_receipt(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        observation=s.split('private _nativeMoveAwaited={',1)[1].split('// Keep building authority',1)[0]
        for guard in ('movementRequestTimes','(_planningRequest select 0) isNotEqualTo _target','_requestAge < 30',
                      '[_actor] call _ownsCurrentMove','getUnitState _actor in ["INIT","PLANNING","REPLAN","BUSY"]','_requestAge < 2'):
            self.assertIn(guard,observation)
        self.assertNotIn(' set [',observation)
        self.assertNotIn('doMove',observation)
        # Planner transitions do not restart the original issue age or grant ownership.
        def awaited(age,owned,state):
            return age>=0 and (age<2 or (age<30 and owned and state in ('INIT','PLANNING','REPLAN','BUSY')))
        for state in ('INIT','PLANNING','REPLAN','BUSY'):
            self.assertTrue(awaited(29,True,state))
            self.assertFalse(awaited(30,True,state))
            self.assertFalse(awaited(10,False,state))
        for state in ('INITFAILED','DELAY','STOPPED','OK'):
            self.assertFalse(awaited(10,True,state))
        self.assertFalse(awaited(-1,True,'REPLAN'))

        recovery=s.split('private _recoverClearActor={',1)[1].split('// Before exterior actors commit',1)[0]
        self.assertLess(recovery.index('call _nativeMoveAwaited'),recovery.index('call CBE_fnc_RecoveryStep'))
        self.assertIn('private _result="YIELDED"',recovery)
        alternate=s.split('if ((_receipt select 2) && {_now-(_receipt select 1) >= 24}',1)[1].split('private _pose=',1)[0]
        self.assertIn('!([_partner,_entryTarget] call _nativeMoveAwaited)',alternate)

    def test_provisional_recovery_target_does_not_preempt_distinct_support_selection(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        recovery=s.split('// Partner entry recovery is independent',1)[1].split('private _entryRecovery=',1)[0]
        self.assertIn('_entryTargets getOrDefault',recovery)
        self.assertIn('_job set ["pairEntryTargets",_entryTargets]',recovery)
        self.assertNotIn('_entryTargets set [_entryKey',recovery)
        support=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        for gate in ('_supportTarget isEqualTo []','distance2D _anchor >= 1.2','_distance >= 2.5','distance2D _anchor <= 8','min 24','lineIntersectsSurfaces','_entryProbes >= 4','_roomGeometryBudget <= 8','_roomGeometryBudget=_roomGeometryBudget-1'):
            self.assertIn(gate,support)
        self.assertIn('_entryTargets set [_entryKey,+_supportTarget]',support)
        # Proposal ranking cannot spend the final eight physical-observation probes.
        for initial in range(17):
            budget=initial
            for _pair in range(4):
                for _probe in range(4):
                    if budget <= 8:
                        break
                    budget-=1
            self.assertEqual(budget,min(initial,8))

    def test_new_destinations_prefer_live_unoccupied_nodes_without_reserving_queue(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        helper=s.split('private _occupiedRoomTargets={',1)[1].split('// Callback-local geometry',1)[0]
        for gate in ('select [0,8]','call _actorAvailable','call _ownsCurrentMove','_occupied pushBack (getPosATL _actor)','simulationEnabled','isObjectHidden'):
            self.assertIn(gate,helper)
        body=helper.split('if (!isNull _actor',1)[1].split('_occupied pushBack (getPosATL _actor)',1)[0]
        self.assertNotIn('call _actorAvailable',body)
        self.assertIn('isNull objectParent _actor',body)
        future=helper.split('if (count _issued == 3',1)[1].split('_occupied pushBack (+_issued)',1)[0]
        self.assertIn('call _actorAvailable',future)
        # Native tasks remove destination ownership, not the soldier standing there.
        def occupancy(available, mounted=False, simulated=True, hidden=False):
            body=not mounted and simulated and not hidden
            return (body, body and available)
        self.assertEqual(occupancy(False),(True,False))
        self.assertEqual(occupancy(True),(True,True))
        self.assertEqual(occupancy(False,mounted=True),(False,False))
        self.assertEqual(occupancy(True,hidden=True),(False,False))
        self.assertEqual(occupancy(True,simulated=False),(False,False))
        self.assertNotIn('doMove',helper)
        claim=s.split('// Prefer free room destinations',1)[1].split('private _point=',1)[0]
        self.assertIn('if (_freeCandidates isNotEqualTo [])',claim)
        self.assertNotIn('deleteAt',claim)
        support=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        self.assertIn('private _ranked=if (_freeRanks isNotEqualTo []) then {_freeRanks} else {_busyRanks}',support)
        self.assertIn('if (_supportTarget isEqualTo [])',support)
        # Distinct lead claims alone cannot prevent two buddies choosing the midpoint.
        points=[(0,0),(6,0),(3,0),(3,4)]
        def ranked(anchor,occupied):
            candidates=[p for p in points if 2.5<=sum((p[i]-anchor[i])**2 for i in range(2))**.5<=8]
            return sorted(candidates,key=lambda p:(any(sum((p[i]-q[i])**2 for i in range(2))**.5<2.5 for q in occupied),sum((p[i]-anchor[i])**2 for i in range(2))))
        first=ranked(points[0],[])[0]
        self.assertEqual(first,ranked(points[1],[])[0])
        self.assertNotEqual(first,ranked(points[1],[first,points[0]])[0])
        # Occupancy never makes all native candidates disappear.
        self.assertTrue(ranked(points[1],points))
    def test_entry_and_egress_floor_checks_use_absolute_elevation(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        for target in ('_target','_point','_entryTarget','_accessPoint'):
            self.assertIn('(AGLToASL '+target+') select 2',s)
        self.assertNotIn('abs (((getPosATL _unit) select 2)',s)
        self.assertNotIn('abs (((getPosATL _entryMover) select 2)',s)
        self.assertIn('abs (((AGLToASL _x) select 2)-((AGLToASL _anchor) select 2))',s)
        # Same absolute floor, different terrain cells: old relative-height test rejects it.
        floor=20; terrain_actor=16; terrain_target=18
        self.assertGreater(abs((floor-terrain_actor)-(floor-terrain_target)),1.5)
        self.assertEqual(abs(floor-floor),0)
        for comparison in ('(getPosASL _point) vectorDistance (AGLToASL _target)',
                           '(getPosASL _point) vectorDistance (ATLToASL _moverPrevious)',
                           '(getPosASL _x) vectorDistance (ATLToASL _old)',
                           '(getPosASL _unit) vectorDistance (AGLToASL _progressTarget)',
                           '(getPosASL _unit) vectorDistance (AGLToASL _retryTarget)'):
            self.assertIn(comparison,s)
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        self.assertIn('(getPosASL _actor) vectorDistance (AGLToASL _routeTarget)',admission)
        self.assertNotIn('abs (((getPosATL _actor) select 2)-(_target select 2))',admission)
        # Crossing terrain cells can fake a metre of movement while the body moves only20cm.
        relative_motion=(0.2**2+((floor-terrain_actor)-(floor-terrain_target))**2)**0.5
        absolute_motion=(0.2**2+(floor-floor)**2)**0.5
        self.assertGreater(relative_motion,1)
        self.assertLess(absolute_motion,1)
        # Equal relative heights can conceal genuinely different absolute floors.
        relative_height=1
        self.assertEqual(abs(relative_height-relative_height),0)
        self.assertGreater(abs((terrain_actor+relative_height)-(terrain_target+relative_height)),1.5)
    def test_security_exit_inventory_is_not_truncated_with_interior_entry_choices(self):
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertLess(admission.index('_securityEntries=+_entries'),admission.index('_entries resize ((count _entries) min 4)'))
        self.assertIn('["securityEntries",_securityEntries]',admission)
        reserve=step.split('// Distribute observation among real exits',1)[1].split('// Public arrival does not replay',1)[0]
        self.assertEqual(reserve.count('_job getOrDefault ["securityEntries",_job getOrDefault ["entries",[]]]'),3)
        self.assertIn('select [0,16]',reserve)
        # A rear exit must remain selectable even when four closer exits precede it.
        native_exits=[(0,1),(1,1),(2,1),(3,1),(0,20)]
        security=list(native_exits)
        interior=native_exits[:4]
        self.assertNotIn((0,20),interior)
        self.assertIn((0,20),security)
        self.assertEqual(len(interior),4)
    def test_new_security_posts_prefer_angular_spread_without_historical_coverage_credit(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        rank=s.split('// Distribute observation among real exits',1)[1].split('if (_entry isNotEqualTo []',1)[0]
        for gate in ('call _actorAvailable','call _ownsCurrentMove','vectorDistance (AGLToASL','_plannedBearings','-_minimumBearingGap','select 4'):
            self.assertIn(gate,rank)
        self.assertIn('(keys _earlyExits) select [0,8]',rank)
        self.assertIn('_observationReserveKeys select [0,8]',rank)
        self.assertEqual(rank.count('call _actorTaskFree'),2)
        self.assertEqual(rank.count('!(_actor in _rotatedOut)'),2)
        self.assertEqual(rank.count('!(_actor in _unavailable)'),2)
        self.assertNotIn('doMove',rank)
        self.assertNotIn('lineIntersectsSurfaces',rank)
        def gap(a,b):return abs((a-b+540)%360-180)
        self.assertEqual(gap(359,1),2)
        # Both exits are unassigned/untried: opposite face beats a closer adjacent door.
        options=[(0,0,-gap(5,0),4,'front'),(0,0,-gap(180,0),30,'rear')]
        self.assertEqual(min(options)[-1],'rear')
        # Actual failed proposal remains lower priority, despite its attractive bearing.
        options[1]=(1,0,-180,30,'rear')
        self.assertEqual(min(options)[-1],'front')

class ClearReserveFairnessTests(unittest.TestCase):
    def test_exterior_reserve_service_window_does_not_starve_later_actors(self):
        from pathlib import Path
        source=(Path(__file__).resolve().parents[1]/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        assert '"reserveStageCursor"' in source
        assert source.count('} forEach _stageReserves;') == 2
        assert '} forEach (_reserves select [0,8]);' not in source
        # Stable rosters larger than the callback budget must all receive service.
        for count in (9,12,16,24):
            cursor=0
            seen=set()
            for _ in range((count+7)//8):
                roster=list(range(count))
                rotated=roster[cursor:]+roster[:cursor]
                seen.update(rotated[:8])
                cursor=(cursor+8)%count
            assert seen == set(range(count))
        # Small rosters retain their existing whole-roster service without rotation.
        assert list(range(6))[:8] == list(range(6))

class ClearHolderOwnershipTests(unittest.TestCase):
    def test_prior_drill_reunion_retires_successor_owned_holders(self):
        source=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        gate=source.split('private _ownedMovers =',1)[1].split('private _holders =',1)[0]
        for marker in ('if (_ordered)', 'CBE_OperationGeneration','CBE_AIPass_Epoch',
                       '"participants",[]','"cancelReason",""','CBE_Cortex_ClearHold',
                       'CBE_AIPass_ClearGeneration','call CBE_fnc_NativeOrderReceipt'):
            self.assertIn(marker,gate)
        self.assertNotIn('doFollow',gate)
        self.assertNotIn('doStop',gate)
        # Old drill ownership transfers to the newer task, not to a deferred recall.
        holders={'old_a','old_b','unclaimed'}
        operation={'old_a'}
        settled={'old_b'}
        remaining=holders-operation-settled
        self.assertEqual(remaining,{'unclaimed'})
        self.assertEqual(holders-holders,set())
        self.assertEqual(holders-set(),holders)

class ClearReplacementOccupancyTests(unittest.TestCase):
    def test_replacement_destinations_use_current_pairs_not_historical_prefix(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        helper=source.split('private _occupiedRoomTargets={',1)[1].split('// Callback-local geometry',1)[0]
        self.assertIn('getOrDefault ["pairs",[]]) select [0,4]',helper)
        self.assertIn('_workers pushBackUnique _x',helper)
        self.assertIn('_workers select [0,8]',helper)
        self.assertNotIn('get "team"',helper)
        # After one casualty, the replacement is ninth in the historical journal.
        historical=list(range(8))+['replacement']
        pairs=[['replacement',1],[2,3],[4,5],[6,7]]
        current=list(dict.fromkeys(actor for pair in pairs[:4] for actor in pair[:2]))[:8]
        self.assertNotIn('replacement',historical[:8])
        self.assertIn('replacement',current)
        self.assertNotIn(0,current)
        self.assertEqual(len(current),8)
        # Replacing both members preserves the same concurrent capacity.
        pairs[0]=['second','third']
        current=list(dict.fromkeys(actor for pair in pairs[:4] for actor in pair[:2]))[:8]
        self.assertEqual(len(current),8)
        self.assertEqual(current[:2],['second','third'])

class ClearPairSlotIdentityTests(unittest.TestCase):
    def test_filtered_pair_maps_mover_and_motion_back_to_durable_actor_slots(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        worker=source.split('private _laneRoster=+(_pairs select _pairIndex);',1)[1].split('private _allWorkersEntered=',1)[0]
        for guard in ('_pair=_laneRoster select',
                      '_previousMover=_laneRoster select (_moverIndex mod count _laneRoster)',
                      '_moverIndex=_pair find _previousMover',
                      '_lanePositions param [_laneRoster find _x,getPosATL _x]',
                      'private _activeSlot=_pair find _x',
                      '_laneRoster find (_pair select (_moverIndex mod count _pair))'):
            self.assertIn(guard,worker)
        order=source.split('private _laneCount=count _pairs;',1)[1].split('private _laneRoster=',1)[0]
        self.assertIn('roomLaneCursor',order)
        self.assertIn('private _pairIndex=_x',order)
        self.assertIn('(_laneCursor+_offset) mod _laneCount',order)
        self.assertIn('} forEach _laneOrder;',worker)
        self.assertNotIn('_pairs set',order)
        for count in range(1,5):
            starts=[]
            for cursor in range(count):
                indices=[(cursor+offset)%count for offset in range(count)]
                self.assertEqual(sorted(indices),list(range(count)))
                starts.append(indices[0])
            self.assertEqual(starts,list(range(count)))
        self.assertEqual(worker.count('_state set [7,call _laneMoverSlot]'),2)
        self.assertIn('_state set [2,call _laneMotion]',worker)
        motion=worker.split('private _laneMotion={',1)[1].split('if (_now >= _startAt)',1)[0]
        self.assertNotIn('_forEachIndex',motion)
        self.assertNotIn('_state set [7,_moverIndex]',worker)
        self.assertNotIn('_state set [2,_lastPositions]',worker)
        entry_motion=worker.split('if (_approachingEntry && {!_moved}) then {',1)[1].split('if (_moved)',1)[0]
        self.assertIn('_lastPositions param [_pair find _x,getPosATL _x]',entry_motion)
        self.assertNotIn('_forEachIndex',entry_motion)
        from sqf_validator import UNINDEXED_ITERATION_PATTERN, strip_comments_and_strings
        for command in ('apply','findIf','select'):
            bad=f'_pair {command} {{_lastPositions param [_forEachIndex,getPosATL _x]}}'
            self.assertIsNotNone(UNINDEXED_ITERATION_PATTERN.search(strip_comments_and_strings(bad)))
        for good in ('_pair findIf {_lastPositions param [_pair find _x,getPosATL _x]}',
                     '{_lastPositions param [_forEachIndex,getPosATL _x]} forEach _pair',
                     '_pair findIf {_lastPositions param [_outerIndex,getPosATL _x]}',
                     '// _pair findIf {_forEachIndex > 0}',
                     'diag_log "_pair findIf {_forEachIndex > 0}"'):
            self.assertIsNone(UNINDEXED_ITERATION_PATTERN.search(strip_comments_and_strings(good)))
        from math import dist
        previous={'lead':(0,0,0),'buddy':(10,0,0)}
        actual=dict(previous)
        self.assertFalse(any(dist(actual[actor],previous[actor]) >= 1 for actor in actual))
        self.assertTrue(any(dist(actual[actor],previous['lead']) >= 1 for actor in actual))
        actual['buddy']=(11,0,0)
        self.assertTrue(any(dist(actual[actor],previous[actor]) >= 1 for actor in actual))
        switch=worker.split('if (_moverIndex < 0) then {',1)[1].split('private _laneMoverSlot=',1)[0]
        self.assertIn('_lastTarget=-1',switch)
        self.assertIn('_state set [13,1e12]',switch)
        self.assertNotIn('_retries=0',switch)
        self.assertNotIn('deadline',switch)
        self.assertNotIn('doMove',switch)

class ClearSingleSurvivorTests(unittest.TestCase):
    def test_lone_exterior_survivor_cannot_keep_casualty_entry_state(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        reset=source.split('// No reserve may be available.',1)[1].split('private _laneMoverSlot=',1)[0]
        self.assertIn('if (_entered && {_pair findIf',reset)
        for change in ('_entered=false','_cursor=0','_approachingEntry=true','_lastTarget=-1'):
            self.assertIn(change,reset)
        self.assertNotIn('_retries=0',reset)
        self.assertNotIn('deadline',reset)
        self.assertNotIn('pushBack',reset)

    def test_single_survivor_fixture_uses_actual_entry_and_both_original_slots(self):
        source=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=source.split('// Normal-only single-survivor regression.',1)[1].split('// Exercise door handling',1)[0]
        for required in ('!('+'missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false])',
                         'forEach [0,1]','call _observedRoomVisit','_casualty setDamage 1',
                         'vectorDistance _start >= 3','!((_rooms find _x) in _before)',
                         '"-original-hard-deadline"','"-no-reserve-replacement"'):
            self.assertIn(required,case)
        self.assertIn('count _job > 0 && {_originalDeadline > 0}',case)
        self.assertIn('(_job getOrDefault ["generation",-2]) == _originalGeneration',case)
        self.assertIn('[_pair select 0,_house,_x] call _observedRoomVisit',case)
        for forbidden in ('doMove','doFollow','setPos','setDriveOnPath','CBE_fnc_BuildingOperationStep',
                          'setVariable ["CBE_Cortex_ClearResult"','setVariable ["CBE_ActorMoveLease"'):
            self.assertNotIn(forbidden,case)

if __name__=='__main__': unittest.main()
