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
