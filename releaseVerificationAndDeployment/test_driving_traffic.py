"""Traffic following authority and bounded-work contracts, not engine behaviour acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name): return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text()
class DrivingTrafficTests(unittest.TestCase):
    def test_observer_is_read_only_bounded_and_size_height_aware(self):
        s=src('drivingFollowingCap')
        for guard in ('local _vehicle','count _candidates > 64','_radius > 500','boundingBoxReal _other','_sameHeight','_minZ','_maxZ','velocity _other','_hullGap'):
            self.assertIn(guard,s)
        for command in ('forceSpeed','doMove','setPos','setVelocity','disableCollisionWith','spawn','waitUntil'):
            # Documentation mentions the caller speed policy; executable observer must not write.
            executable=s.split('params [[',1)[1]
            self.assertNotIn(command,executable)
    def test_destroyed_vehicle_hulls_are_not_removed_by_scan_or_alive_filter(self):
        s=src('drivingFollowingCap')
        self.assertIn('_area=[getPosATL _vehicle,_radius,_radius,0,false,_radius]',s)
        self.assertIn('_area nearEntities [["LandVehicle"],false,false,false]',s)
        admission=s.split('if (_other != _vehicle',1)[1].split('then {',1)[0]
        self.assertNotIn('alive _other',admission)
        self.assertIn('((vectorDir _other) vectorDotProduct _forward) > 0.7',s)
        self.assertIn('_sameHeight',s)
        self.assertIn('count _candidates > 64',s)
        config=(ROOT/'addons/main/config.cpp').read_text()
        self.assertIn('requiredVersion = 2.18',config)

    def test_angled_hulls_are_admitted_without_assuming_their_forward_clearance(self):
        s=src('drivingFollowingCap')
        admission=s.split('if (_other != _vehicle',1)[1].split('then {',1)[0]
        self.assertNotIn('vectorDir',admission)
        self.assertIn('private _otherForward=if (_following)',s)
        self.assertIn('} else {0}',s)
        self.assertIn('private _ahead=_maxY > _front-0.25',s)
        self.assertNotIn('private _centre=',s)
        # Forward projection must admit a long rotated hull whose centre is behind
        # our bumper, while excluding a hull entirely behind or above the corridor.
        def occupied(min_x,max_x,max_y,min_z,max_z):
            return max_y>3-0.25 and max_x>=-1.25 and min_x<=1.25 and max_z>=-0.75 and min_z<=2.25
        self.assertTrue(occupied(-2,2,5,0,2))
        self.assertFalse(occupied(-2,2,2,0,2))
        self.assertFalse(occupied(3,5,8,0,2))
        self.assertFalse(occupied(-2,2,8,5,7))

    def test_convoy_observes_external_hulls_without_replacing_predecessor_spacing(self):
        s=src('convoyTick')
        self.assertIn('[_lead,_leadLimit/3.6] call CBE_fnc_DrivingFollowingCap',s)
        self.assertIn('[_vehicle,_limit/3.6,_front] call CBE_fnc_DrivingFollowingCap',s)
        self.assertEqual(s.count('call CBE_fnc_DrivingFollowingCap'),2)
        observer=src('drivingFollowingCap')
        admission=observer.split('if (_other != _vehicle',1)[1].split('then {',1)[0]
        self.assertNotIn('_predecessor',admission)
        self.assertIn('private _spacingOwned=_other == _predecessor && {alive _other}',observer)
        self.assertIn('>= cos 25',observer)
        self.assertIn('if (_other == _predecessor && {!_spacingOwned}) then {_following=false}',observer)
        self.assertIn('if (_hullGap < 2 && {_cap > 0}) then {_cap=0;',observer)
        self.assertIn('private _leadTrafficBlocked=!isNull (_leadTraffic select 1)',s)
        self.assertIn('if (!_routeDone && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_leadTrafficBlocked}',s)
        self.assertIn('if (!_trafficBlocked && {time - (_progress select 1) > 20}',s)
        self.assertIn('|| {_trafficBlocked} || {_limit <= 0}',s)
        self.assertLess(s.index('_limit=_limit min ((_traffic select 0)*3.6)'),s.index('private _ownedSpeed=_limit/3.6'))

    def test_reverse_overlap_includes_destroyed_vehicles_without_treating_dead_infantry_as_live(self):
        s=src('drivingRearClear')
        self.assertIn('_area nearEntities [["LandVehicle"],false,false,false]',s)
        self.assertIn('_vehicle nearEntities ["CAManBase",_radius]',s)
        self.assertIn('alive _thisActor || {_thisActor isKindOf "LandVehicle"}',s)
        self.assertIn('count _actors > 64',s)
        self.assertIn('private _scheduledObservation=canSuspend',s)
        self.assertIn('if (!_crewObserved || {_scheduledObservation})',s)
        self.assertIn('_ownCrew=crew _vehicle;_crewObserved=true',s)
        self.assertIn('!(_thisActor in _ownCrew)',s)
        self.assertIn('_projectedLow set [_axis',s)
        self.assertIn('_projectedHigh set [_axis',s)
        self.assertLess(s.index('private _occupied='),s.index('private _clear=true'))

    def test_discovery_covers_fast_approach_even_at_low_own_speed(self):
        import math
        s=src('drivingFollowingCap')
        self.assertIn('private _horizon=6;',s)
        self.assertIn('private _approachAllowance=35*_horizon;',s)
        self.assertIn('*_horizon+_approachAllowance+20+(abs _front)',s)
        self.assertIn('_ownIn < _horizon && {_otherIn < _horizon}',s)
        self.assertLess(s.index('_radius > 500'),s.index('_area nearEntities'))
        # Independent courses meet after four seconds: own 3 m/s, peer 30 m/s.
        own_arrival=12/3
        peer_arrival=120/30
        self.assertEqual(own_arrival,peer_arrival)
        distance=math.hypot(12,120)
        old_own_travel_radius=3*6+20+5
        self.assertGreater(distance,old_own_travel_radius)
        self.assertLess(distance,35*6)
        # An oncoming peer 210 m ahead closes at 55 m/s, inside six seconds.
        self.assertLess(210/(20+35),6)
        self.assertGreater(210,20*6+20+5)
        self.assertLess(210,(20+35)*6)

    def test_traffic_wait_does_not_enter_route_recovery(self):
        s=src('drivingAssistStart')
        self.assertIn('&& {!_trafficLimited || {_solidReady} || {_reverseHandback}} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass} && {([_vehicle] call _stationary)',s)
        self.assertIn('["CORRIDOR_HANDBACK","TRAFFIC_FOLLOW"] select _trafficLimited',s)
        self.assertIn('_progressPosition=getPosATL _vehicle;_progressAt=time;',s)
        self.assertIn('CBE_DrivingAssist_Traffic',s.split('getForcedSpeed _vehicle == 0',1)[1].split('then {_release=true}',1)[0])
        self.assertIn('_capMps=_capMps min (_traffic select 0)',s)
        self.assertLess(s.index('call CBE_fnc_DrivingFollowingCap'),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('time+([4,1] select (_trafficLimited || {_trafficWatch} || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))',s)
    def test_fsm_uses_existing_queue_and_cleanup_clears_observation(self):
        step=src('drivingOperationStep')
        self.assertIn('"TRAFFIC"',step)
        self.assertIn('time+([4,1] select (_crewPending || {_traffic} || {_watchTraffic} || {_obstacle} || {_rearLeg} || {_corridor != ""} || {_bypass != ""} || {_passing}))',step)
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text()
        self.assertIn('class TrafficFollowing',fsm)
        self.assertIn('to="TrafficFollowing"',fsm)
        self.assertIn('setVariable ["CBE_DrivingAssist_Traffic",nil]',src('drivingAssistRelease'))
    def test_convoy_low_speed_smoothing_retains_raw_safety_caps(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        smoothing=s.split('// Tracks accelerate and brake unevenly.',1)[1].split('_limit = [_vehicle',1)[0]
        self.assertNotIn('_frontSpeed > 2',smoothing)
        self.assertIn('_controlGap >= _gapLow && {_closingCap > 0} && {!_frontReversing}',smoothing)
        self.assertIn('(_controlGap-_gapLow)/((_desiredGap-_gapLow) max 1)',smoothing)
        self.assertIn('max 0)*_smoothingBlend',smoothing)
        import math
        def cap(gap,front,previous,mass,blend):
            limit=max(0,front+(gap-50)*.4)
            if gap>60:limit+=min((gap-60)*math.sqrt(gap-60)*.15,8)
            if gap<40:limit=min(limit,max(0,front-(40-gap)*1.2))
            decel=4/max(1,min(2.5,1+(mass-3000)/7000));reaction=4*decel
            closing=min(50,front+3.6*max(0,math.sqrt(reaction**2+2*decel*max(0,gap-40))-reaction))
            if gap>=40 and closing>0:
                weight=max(0,min(1,(gap-40)/10)) if blend else 1
                limit=max(limit,max(0,previous-4)*weight)
            return max(0,min(limit,previous+4,closing))
        self.assertAlmostEqual(cap(40.00001,2,5,3000,False)-cap(39.99999,2,5,3000,False),1)
        for mass in (3000,15000,30000):
            for front in (0,2,10,30):
                for previous in (0,5,20):
                    for boundary in (40,50,60):
                        self.assertLess(abs(cap(boundary+.00001,front,previous,mass,True)-cap(boundary-.00001,front,previous,mass,True)),.001)
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
        occupied=s.split('if (_ahead && {_sameLane} && {_sameHeight})',1)[1]
        self.assertLess(occupied.index('_allowed=_allowed min'),occupied.index('if (_allowed < _cap)'))
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
        self.assertNotIn('call CBE_fnc_DrivingAssistStart',audit)
        self.assertNotIn('call CBE_fnc_DrivingOperationStep',audit)
        self.assertNotIn('setVariable ["CBE_DrivingAssist_State"',audit)
        self.assertNotIn('setPosATL',audit)
        self.assertNotIn('setVelocity',audit)
        self.assertIn('_stableSamples >= 12',audit)
        self.assertIn('_follower distance2D _resumeStart >= 45',audit)
        self.assertIn('_follower distance2D _repeatStart >= 35',audit)

    def test_crossing_prediction_preserves_physical_occupancy_and_bounded_query(self):
        s=src('drivingFollowingCap')
        self.assertEqual(s.count('nearEntities'),1)
        prediction=s.split('// Project crossing occupancy',1)[1].split('if (_ahead && {_sameLane}',1)[0]
        for marker in ('_sameHeight','_otherSpeed > 0.8','vectorDotProduct _right > 0.25',
                       'abs _denominator > 0.2','_ownIn < _horizon','_otherIn < _horizon',
                       '_ownOut > 0','_otherOut > 0','_ownIn < _otherOut+1',
                       '_otherIn < _ownOut+1','_arrivalCap min _brakingCap',
                       '_room <= _stoppingRoom','_allowed=0'):
            self.assertIn(marker,prediction)
        self.assertIn('if (_ahead && {_sameLane} && {_sameHeight})',s)
        self.assertNotIn('setVariable',prediction)
        self.assertNotIn('lineIntersectsSurfaces',prediction)
        self.assertNotIn('forceSpeed',prediction)

    def test_corner_physical_acceptance_requires_real_encounter_braking_and_travel(self):
        source=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        block=source.split('// Normal-only physical observation:',1)[1].split('["CNV-02b-travel-cargo-mounted"',1)[0]
        for marker in ('CBE_CortexQA_HeadlessBatch','diag_tickTime+150','_angle > 25','_closing > 0.5',
                       '_actualSpeed > 1.5','_event isEqualTo []','diag_tickTime-(_event select 1) <= 8',
                       '_actualSpeed <= (_event select 0)-1','_room < 0','damage _x >',
                       'CNV-corner-turning-predecessor-prerequisite','CNV-corner-physical-onward-travel'):
            self.assertIn(marker,block)
        for forbidden in ('forceSpeed','doMove','setPos','setVelocity','call CBE_fnc_ConvoyTick','call CBE_fnc_DrivingFollowingCap'):
            self.assertNotIn(forbidden,block)

if __name__=='__main__': unittest.main()


class CrossingUnacknowledgedPeerTests(unittest.TestCase):
    def test_imminent_left_crossing_is_not_assumed_to_yield(self):
        def constrain(from_right, room, stopping_room, candidate, current):
            allowed=0 if room <= stopping_room else candidate
            return min(current,allowed) if from_right or room <= stopping_room else current
        self.assertEqual(constrain(False,10,20,3,12),0)
        self.assertEqual(constrain(True,10,20,3,12),0)
        self.assertEqual(constrain(False,50,20,3,12),12)
        self.assertEqual(constrain(True,50,20,3,12),3)

    def test_sides_share_occupancy_horizon_and_physical_constraints(self):
        source=src('drivingFollowingCap')
        prediction=source.split('// Project crossing occupancy',1)[1].split('if (_ahead && {_sameLane}',1)[0]
        self.assertIn('if (_sameHeight && {_otherSpeed > 0.8})',prediction)
        self.assertIn('(_fromRight || {_room <= _stoppingRoom})',prediction)
        self.assertIn('_ownIn < _otherOut+1',prediction)
        self.assertIn('_otherIn < _ownOut+1',prediction)
        self.assertIn('if (_room <= _stoppingRoom) then {_allowed=0}',prediction)
        self.assertEqual(source.count('nearEntities'),1)


class ConvoyLeadGapMetricTests(unittest.TestCase):
    def test_lateral_drift_does_not_reserve_cruise_speed_as_rearward_gap(self):
        import math
        def gap(along,side,heading_difference,target):
            raw=math.hypot(along,side)
            return max(along,0) if heading_difference <= 25 and raw <= target*1.8 else raw
        self.assertEqual(gap(40,30,0,40),40)
        self.assertGreater(math.hypot(40,30),42)
        self.assertEqual(gap(50,0,0,40),50)
        self.assertEqual(gap(40,30,90,40),50)
        self.assertEqual(gap(80,0,0,40),80)

    def test_lead_pacing_reuses_bounded_stretch_sample(self):
        source=src('convoyTick')
        self.assertIn('private _spacingGaps=[0]',source)
        self.assertIn('_spacingGaps pushBack _pairGap',source)
        pacing=source.split('private _catchupThreshold=',1)[0].rsplit('for "_i"',1)[1]
        self.assertIn('private _gap=_spacingGaps select _i',pacing)
        self.assertNotIn('distance2D',pacing)
        self.assertIn('if (_gap > _target*2)',source)
        self.assertIn('((_gap-_target*2)/((_target*0.2) max 3)) min 1',source)
        self.assertIn('_catchup=_catchup+(_paced-_catchup)*_pacingBlend',source)
        self.assertIn('(_gap-_catchupThreshold)*0.4',source)
        # The lead cap must not jump by the accumulated deadband at first admission.
        # This models the spacing request only, not physical acceleration or braking.
        for target in (10,30,50,100):
            threshold=target+max(target*.05,1)
            def request(gap):
                return 50 if gap<=threshold else max(50-min((gap-threshold)*.4,8),5)
            self.assertEqual(request(threshold),50)
            self.assertLess(abs(request(threshold+.001)-request(threshold-.001)),.001)
            self.assertEqual(request(threshold+20),42)
            self.assertEqual(request(threshold+100),42)

        # Independent endpoint requirements: the blend must preserve the reserve at
        # entry, reach actual-speed pacing at the tolerance edge, and have no jump.
        for target in (10,30,50,100):
            width=max(target*.2,3)
            reserve,paced=42,5
            caps=[reserve+(paced-reserve)*min(max(offset/width,0),1)
                  for offset in (0,.001,width/2,width,width+1)]
            self.assertEqual(caps[0],reserve)
            self.assertEqual(caps[-1],paced)
            self.assertEqual(caps[2],(reserve+paced)/2)
            self.assertLess(abs(caps[1]-caps[0]),.02)
            self.assertEqual(caps,sorted(caps,reverse=True))

        self.assertIn('_limit = ((_limit min ((_previous select 0)+4*_elapsed)) min _closingCap) max 0',source)

    def test_approaching_lane_hull_retains_closing_speed_during_reaction_and_braking(self):
        import math
        s=src('drivingFollowingCap')
        branch=s.split('private _approachSpeed=',1)[1].split('private _closing=',1)[0]
        for proof in ('_room-_approachSpeed*_reaction','_approachSpeed+_reactionSpeed',
                      '_approachCoefficient^2','2*_deceleration*_remainingRoom',
                      '_approachSpeed*(_reaction+_ownForward/_deceleration)',
                      '_room <= _actualStoppingRoom','_allowed=_allowed min _approachAllowance'):
            self.assertIn(proof,branch)
        self.assertNotIn('nearEntities',branch)
        self.assertNotIn('forceSpeed',branch)
        self.assertNotIn('doMove',branch)
        # Solve the stated constant-approach model independently over light/heavy envelopes.
        # Infeasible room (peer reaches the reserve during reaction alone) requires zero.
        for a in (1.6,2.5,4):
            for room in (0,10,40,100,200):
                stationary=math.sqrt((a*4)**2+2*a*room)-a*4
                for approach in (1,5,10,25):
                    coefficient=approach+a*4
                    cap=math.sqrt(coefficient**2+2*a*max(0,room-approach*4))-coefficient
                    self.assertGreaterEqual(cap,-1e-12)
                    self.assertLessEqual(cap,stationary+1e-9)
                    if room<=approach*4:self.assertAlmostEqual(cap,0)
                    else:
                        closing=cap*4+cap**2/(2*a)+approach*(4+cap/a)
                        self.assertAlmostEqual(closing,room,places=7)
        # At 80m bumper room a 10m/s own vehicle cannot retain its old positive
        # stationary-obstacle allowance while a peer approaches at another10m/s.
        room=80-6;own=10;approach=10;a=4
        old_cap=math.sqrt((a*4)**2+2*a*room)-a*4
        actual_room=own*4+own**2/(2*a)+approach*(4+own/a)
        self.assertGreater(old_cap,0)
        self.assertGreater(actual_room,room)

    def test_oncoming_fixture_requires_actual_encounter_braking_and_hull_separation(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingTraffic.sqf').read_text(encoding='utf-8')
        case=qa.split('// Opposing native MOVE orders are the only stimulus.',1)[1].split('// Queue room-making must first',1)[0]
        for proof in ('CBE_Headless_ExcludeGroup','_closing > 5','_peerApproach > 1',
                      'vectorDotProduct (vectorDir _peer)) < -0.7','abs speed _own > 5',
                      'abs speed _peer > 5','_observation param [1,objNull]',
                      '_actual <= (_opposingPeaks select _forEachIndex)-3','boundingBoxReal _peer',
                      'modelToWorld [_xx,_yy,_x]','_gap < 1','_opposingDamage',
                      'DRIVING-oncoming-actual-lane-approach','DRIVING-oncoming-production-observed-braking',
                      'DRIVING-oncoming-separated-no-damage'):
            self.assertIn(proof,case)
        for forbidden in ('forceSpeed','call CBE_fnc_DrivingFollowingCap','call CBE_fnc_DrivingAssistStart',
                          'setVariable ["CBE_DrivingAssist_Traffic"','setVelocity'):
            self.assertNotIn(forbidden,case)
