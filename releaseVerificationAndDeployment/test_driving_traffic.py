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
    def test_convoy_low_speed_smoothing_retains_raw_safety_caps(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        smoothing=s.split('// Tracks accelerate and brake unevenly.',1)[1].split('_limit = [_vehicle',1)[0]
        self.assertNotIn('_frontSpeed > 2',smoothing)
        self.assertIn('_controlGap >= _gapLow && {_closingCap > 0} && {!_frontReversing}',smoothing)
        self.assertIn('min _closingCap',smoothing)
        self.assertLess(smoothing.index('_previous select 0)-4*_elapsed'),smoothing.index('min _closingCap'))
        self.assertIn('if (_frontReversing) then {_limit=0}',smoothing)
        self.assertIn('_limit=_limit min _retainedPathCap',smoothing)
    def test_closing_cap_accounts_for_mass_and_cruise_reaction(self):
        s=src('drivingFollowingCap')
        self.assertIn('getMass _vehicle',s)
        self.assertIn('private _deceleration=4/_massFactor;',s)
        self.assertIn('private _reaction=4;',s)
        self.assertIn('2*_deceleration*_room',s)
        self.assertIn('_allowed=_allowed min (_otherForward+_closingAllowance)',s)
        self.assertLess(s.index('_allowed=_allowed min'),s.index('if (_allowed < _cap)'))
        self.assertNotIn('setMass',s)
if __name__=='__main__': unittest.main()
