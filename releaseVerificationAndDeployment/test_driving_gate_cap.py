"""Gate approach uses live body geometry under the existing single speed writer."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingGateCapTests(unittest.TestCase):
    def test_observation_is_bounded_live_and_has_no_world_mutation(self):
        s=(ROOT/'addons/vehicles/functions/drivingGateCap.sqf').read_text()
        for gate in ['modelToWorldWorld', 'true,4,"GEOM","NONE"',
                     '[_left,(_left+_right)*0.5,_right]', 'forEach [0.45,0.9]',
                     'max 25 min 600', '_nearest-6', '_deceleration=4/_massFactor']:
            self.assertIn(gate,s)
        for command in ['animateSource','animateDoor','forceSpeed','setVelocity','doMove','remoteExec','animationSourcePhase']:
            self.assertNotIn(command,s)
        self.assertNotIn('alive _object',s)
        self.assertNotIn('damage _object',s)
    def test_existing_executors_combine_gate_before_speed_and_recovery(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertLess(ordinary.index('call WAIT_fnc_DrivingGateCap'),ordinary.index('_vehicle forceSpeed _capMps'))
        self.assertIn('if (!_reverseLeg) then {',ordinary)
        self.assertEqual(convoy.count('call WAIT_fnc_DrivingGateCap'),2)
        self.assertIn('then {_leadTraffic=_gate}',convoy)
        self.assertIn('then {_traffic=_gate}',convoy)
        self.assertIn('!_leadTrafficBlocked',convoy)
        self.assertIn('!_trafficBlocked',convoy)
if __name__=='__main__': unittest.main()
