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
    def test_destroyed_vehicle_hulls_are_not_removed_by_scan_or_alive_filter(self):
        s=src('drivingFollowingCap')
        self.assertIn('_area=[getPosATL _vehicle,_radius,_radius,0,false,_radius]',s)
        self.assertIn('_area nearEntities [["LandVehicle"],false,false,false]',s)
        self.assertNotIn('alive _other',s)
        self.assertIn('((vectorDir _other) vectorDotProduct _forward) > 0.7',s)
        self.assertIn('_sameHeight',s)
        self.assertIn('count _candidates > 64',s)
        config=(ROOT/'addons/main/config.cpp').read_text()
        self.assertIn('requiredVersion = 2.18',config)

    def test_reverse_overlap_includes_destroyed_vehicles_without_treating_dead_infantry_as_live(self):
        s=src('drivingRearClear')
        self.assertIn('_area nearEntities [["LandVehicle"],false,false,false]',s)
        self.assertIn('_vehicle nearEntities ["CAManBase",_radius]',s)
        self.assertIn('alive _thisActor || {_thisActor isKindOf "LandVehicle"}',s)
        self.assertIn('count _actors > 64',s)
        self.assertIn('forEach [_otherLow select 2,_otherHigh select 2]',s)
        self.assertLess(s.index('private _occupied='),s.index('private _clear=true'))

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
    def test_convoy_closing_envelope_uses_mass_and_forward_velocity(self):
        import math
        s=src('convoyTick')
        for contract in ('velocityModelSpace _front select 1','getMass _vehicle','_deceleration=4/_massFactor','2*_deceleration*_closingRoom','_frontSpeed+3.6*_closingAllowance'):
            self.assertIn(contract,s)
        self.assertNotIn('[abs speed _front,0]',s)
        def allowance(room,mass):
            factor=min(2.5,max(1,1+(mass-3000)/7000))
            decel=4/factor; reaction=4*decel
            return 3.6*(math.sqrt(reaction*reaction+2*decel*room)-reaction)
        self.assertEqual(allowance(0,3000),0)
        self.assertLess(allowance(20,15000),allowance(20,3000))
        self.assertGreater(allowance(30,15000),allowance(20,15000))
        # The modeled relative closing distance cannot exceed available room.
        for mass in (1500,10000,20000):
            for room in (1,10,40):
                relative=allowance(room,mass)/3.6
                decel=4/min(2.5,max(1,1+(mass-3000)/7000))
                self.assertAlmostEqual(4*relative+relative*relative/(2*decel),room)
    def test_prepared_traffic_audit_requires_physical_repeat_outcomes(self):
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingTraffic.sqf').read_text()
        for case in ('physical-approach','physical-separated-hold','release-physical-resume','repeat-physical-stop','repeat-physical-resume','disabled-observation-cleanup'):
            self.assertIn('DRIVING-traffic-'+case,audit)
        self.assertNotIn('call WAIT_fnc_DrivingAssistStart',audit)
        self.assertNotIn('call WAIT_fnc_DrivingOperationStep',audit)
        self.assertNotIn('setVariable ["WAIT_DrivingAssist_State"',audit)
        self.assertNotIn('setPosATL',audit)
        self.assertNotIn('setVelocity',audit)
        self.assertIn('_stableSamples >= 12',audit)
        self.assertIn('_follower distance2D _resumeStart >= 45',audit)
        self.assertIn('_follower distance2D _repeatStart >= 35',audit)
if __name__=='__main__': unittest.main()
