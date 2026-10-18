"""Shared audit wait callbacks retain caller deadline bindings; not engine acceptance."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AuditPredicateScopeTests(unittest.TestCase):
    def test_wait_uses_reserved_locals_instead_of_hiding_caller_deadlines(self):
        source=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        helper=source.split('private _wait = {',1)[1].split('\n};',1)[0]
        names=set(re.findall(r'\b_[A-Za-z][A-Za-z0-9_]*',helper))
        self.assertEqual(names,{'_cbeQaWaitPredicate','_cbeQaWaitSeconds','_cbeQaWaitDeadlineTick'})
        self.assertIn('diag_tickTime+_cbeQaWaitSeconds',helper)
        self.assertIn('call _cbeQaWaitPredicate',helper)
        # These real callbacks intentionally read their own different-clock deadlines.
        buildings=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        landing=(ROOT/'releaseVerificationAndDeployment/cortexQA/runLanding.sqf').read_text(encoding='utf-8')
        self.assertIn('[{time > _until+1},12] call _wait',buildings)
        self.assertIn('["RELEASED",_revision,_snapshot select 1,_until]',landing)
