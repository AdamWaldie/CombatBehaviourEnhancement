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
if __name__=='__main__': unittest.main()
