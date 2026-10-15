"""Bounded callback history and retired-work attribution contracts, not perf acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SchedulerSampleTests(unittest.TestCase):
    def test_ring_retains_latest_terminal_work_with_fixed_capacity(self):
        ring=[];cursor=0
        for value in range(1000):
            if cursor==len(ring):ring.append(value)
            else:ring[cursor]=value
            cursor=(cursor+1)%256
            self.assertLessEqual(len(ring),256)
        self.assertEqual(set(ring),set(range(744,1000)))
        self.assertEqual(cursor,1000%256)
    def test_recording_precedes_job_retirement_and_excludes_skips(self):
        s=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text(encoding='utf-8')
        recording=s.split('if (!_stale && {!_jobPaused}) then {',1)[1].split('_state set ["lastRunAt"',1)[0]
        self.assertIn('(_cursor+1) mod 256',recording)
        self.assertIn('select [0,160]',recording)
        for forbidden in ('sort ','spawn','remoteExec','nearEntities','allGroups'):
            self.assertNotIn(forbidden,recording)
        self.assertLess(s.index('"WAIT_AIPass_CallbackSamples",_samples'),s.index('if (!isNil "_delay"'))
    def test_report_is_on_demand_and_does_not_claim_frame_budget_acceptance(self):
        s=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('"cortex-callback-samples"',s)
        self.assertIn('["NOT_SAMPLED","MEASURED"]',s)
        self.assertIn('_ranked select [0,8]',s)
        self.assertIn('not matched frame-time overhead',s)
        self.assertIn('ceil (_sampleCount*0.95)-1',s)
if __name__=='__main__':unittest.main()
