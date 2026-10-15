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
if __name__=='__main__': unittest.main()
