"""Regression guards for total-motion admission, not native-driving acceptance."""
import math
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingStationarityTests(unittest.TestCase):
    def test_recovery_and_waits_reject_non_forward_motion(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        gate=text.split('private _stationary={',1)[1].split('};',1)[0]
        self.assertIn('vectorMagnitude velocity _candidate',gate)
        self.assertIn('finite _linearSpeed && {_linearSpeed < (1/3.6)}',gate)
        self.assertNotIn('abs speed _vehicle',text)
        self.assertNotIn('abs speed _jamPeer',text)
        self.assertIn('([_jamPeer] call _stationary)',text)
        self.assertGreaterEqual(text.count('[_vehicle] call _stationary'),5)
        self.assertIn('(_jam get "attempts") < 3',text)
        self.assertIn('serverTime < (_jam get "deadline")',text)
    def test_total_motion_threshold_examples(self):
        # Independent arithmetic examples: these do not execute SQF or prove settled vehicles.
        cases=[((0,0,0),True),((0.1,0,0),True),((1,0,0),False),
               ((0,0,1),False),((0,-1,0),False),((float('inf'),0,0),False),
               ((float('nan'),0,0),False),((1/3.6,0,0),False)]
        for velocity,expected in cases:
            magnitude=math.sqrt(sum(axis*axis for axis in velocity))
            self.assertEqual(math.isfinite(magnitude) and magnitude < 1/3.6,expected)
