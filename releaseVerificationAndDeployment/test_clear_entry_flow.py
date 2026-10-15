"""Initial pair support planning must not inherit recovery's unselected lead fallback."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearEntryFlowTests(unittest.TestCase):
    def test_provisional_recovery_target_does_not_preempt_distinct_support_selection(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        recovery=s.split('// Partner entry recovery is independent',1)[1].split('private _entryRecovery=',1)[0]
        self.assertIn('_entryTargets getOrDefault',recovery)
        self.assertIn('_job set ["pairEntryTargets",_entryTargets]',recovery)
        self.assertNotIn('_entryTargets set [_entryKey',recovery)
        support=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        for gate in ('_supportTarget isEqualTo []','distance2D _anchor >= 2.5','distance2D _anchor <= 8','min 24','lineIntersectsSurfaces'):
            self.assertIn(gate,support)
        self.assertIn('_entryTargets set [_entryKey,+_supportTarget]',support)
    def test_new_destinations_prefer_live_unoccupied_nodes_without_reserving_queue(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        helper=s.split('private _occupiedRoomTargets={',1)[1].split('// Callback-local geometry',1)[0]
        for gate in ('select [0,8]','call _actorAvailable','call _ownsCurrentMove','getPosASL _actor','simulationEnabled','isObjectHidden'):
            self.assertIn(gate,helper)
        self.assertNotIn('doMove',helper)
        claim=s.split('// Prefer free room destinations',1)[1].split('private _point=',1)[0]
        self.assertIn('if (_freeCandidates isNotEqualTo [])',claim)
        self.assertNotIn('deleteAt',claim)
        support=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        self.assertIn('private _ranked=_freeRanks+_busyRanks',support)
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
if __name__=='__main__': unittest.main()
