"""Numerical progress invariants, not proof of native reverse execution."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def useful(position, anchor, away=(0,-1), facing=True):
    return sum((p-a)*d for p,a,d in zip(position,anchor,away)) >= 2 and facing
class ReverseProgress(unittest.TestCase):
    def test_only_net_rear_separation_refreshes_observation(self):
        self.assertFalse(useful((10,0),(0,0)))
        self.assertFalse(useful((0,3),(0,0)))
        self.assertFalse(useful((0,-1.9),(0,0)))
        self.assertTrue(useful((0,-2),(0,0)))
        self.assertFalse(useful((0,-3),(0,0),facing=False))
        self.assertFalse(useful((0,-2),(0,-2)))
        self.assertFalse(useful((0,-1),(0,-2)))
        self.assertTrue(useful((0,-4),(0,-2)))
    def test_executor_uses_directional_anchor_without_renewing_leg_deadline(self):
        text=(ROOT/'addons/vehicles/functions/cortexVehicleReverseStep.sqf').read_text(encoding='utf-8')
        body=text.split('private _rearIncrement=',1)[1].split('private _bearing=',1)[0]
        for proof in ('vectorDotProduct _awayAxis','_rearIncrement >= 2','_frontBearing',
                      '_record set [6,time]','_record set [7,getPosATL _vehicle]'):
            self.assertIn(proof,body)
        self.assertNotIn('_record set [5,',body)
        self.assertNotIn('distance2D (_record select 7)',text)
        self.assertIn('time-(_record select 6) > 6',body)
if __name__=='__main__': unittest.main()
