"""Traffic following authority and bounded-work contracts, not engine behaviour acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name): return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text()
class DrivingTrafficTests(unittest.TestCase):
    def test_observer_is_read_only_bounded_and_size_height_aware(self):
        s=src('drivingFollowingCap')
        for guard in ('local _vehicle','count _candidates > 64','min 250','boundingBoxReal _other','_sameHeight','_minZ','_maxZ','velocity _other','_hullGap'):
            self.assertIn(guard,s)
        for command in ('forceSpeed','doMove','setPos','setVelocity','disableCollisionWith','spawn','waitUntil'):
            # Documentation mentions the caller speed policy; executable observer must not write.
            executable=s.split('params [[',1)[1]
            self.assertNotIn(command,executable)
    def test_traffic_wait_does_not_enter_route_recovery(self):
        s=src('drivingAssistStart')
        self.assertIn('&& {!_trafficLimited} && {abs speed _vehicle < 1',s)
        self.assertIn('_recoveryResult="TRAFFIC_FOLLOW"',s)
        self.assertIn('_progressPosition=getPosATL _vehicle;_progressAt=time;',s)
        self.assertIn('WAIT_DrivingAssist_Traffic',s.split('getForcedSpeed _vehicle == 0',1)[1].split('then {_release=true}',1)[0])
        self.assertIn('_capMps=_capMps min (_traffic select 0)',s)
        self.assertLess(s.index('call WAIT_fnc_DrivingFollowingCap'),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('time+([4,1] select _trafficLimited)',s)
    def test_fsm_uses_existing_queue_and_cleanup_clears_observation(self):
        step=src('drivingOperationStep')
        self.assertIn('"TRAFFIC"',step)
        self.assertIn('time+([4,1] select _traffic)',step)
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text()
        self.assertIn('class TrafficFollowing',fsm)
        self.assertIn('to="TrafficFollowing"',fsm)
        self.assertIn('setVariable ["WAIT_DrivingAssist_Traffic",nil]',src('drivingAssistRelease'))
if __name__=='__main__': unittest.main()
