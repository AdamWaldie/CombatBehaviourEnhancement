"""Native planning grace and finite recovery timing contracts; no live acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingPlanningGraceTests(unittest.TestCase):
    def test_stages_have_distinct_observation_windows(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('private _observationWindow=[20,30,0,60] param [_recoveryStage,60]',s)
        self.assertIn('time-_progressAt >= _observationWindow || {_reverseComplete}',s)
        refresh=s.split('case 0: {',1)[1].split('case 1:',1)[0]
        reverse=s.split('case 1: {',1)[1].split('case 2:',1)[0]
        retry=s.split('case 2: {',1)[1].split('default {',1)[0]
        self.assertIn('_recoveryUntil=time+30',refresh)
        self.assertIn('_recoveryUntil=time+6',reverse)
        self.assertIn('_recoveryUntil=time+60',retry)
    def test_new_order_and_real_progress_reset_observation_before_admission(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        changed=s.split('(_state param [9,[]]) isNotEqualTo _routeIdentity',1)[1].split('// A follower',1)[0]
        for marker in ('_state set [5,time]','_state set [6,0]','_state set [7,-1]'):
            self.assertIn(marker,changed)
        progress=s.split('if (!_trafficLimited && {!_corridorActive} && {!_hadCorridor} && {_vehicle distance2D',1)[1].split('private _waypointIndex=',1)[0]
        self.assertIn('_progressAt=time',progress)
        self.assertIn('_recoveryStage=0',progress)
    def test_timing_model_never_escalates_before_required_observation(self):
        windows=(20,30,0,60)
        def due(stage,elapsed,deadline_elapsed,traffic=False):
            reverse_complete=stage==2 and deadline_elapsed
            return not traffic and deadline_elapsed and (elapsed>=windows[stage] or reverse_complete)
        for stage,window in ((0,20),(1,30),(3,60)):
            self.assertFalse(due(stage,window-0.01,True))
            self.assertTrue(due(stage,window,True))
            self.assertFalse(due(stage,window+100,True,traffic=True))
        self.assertFalse(due(2,5,False))
        self.assertTrue(due(2,6,True))
if __name__=='__main__':unittest.main()
