"""Pedestrian safety policy regressions; native braking remains unverified."""
import math
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class PedestrianSpeedTests(unittest.TestCase):
    def test_braking_envelope_stops_at_bumper_and_never_raises_request(self):
        def cap(request,gap,mass):
            a=4/min(2.5,max(1,1+(mass-3000)/7000))
            room=max(0,gap-3)
            return min(request,max(0,math.sqrt((4*a)**2+2*a*room)-4*a)*3.6)
        for mass in (1000,10000,40000):
            for request in (0,1,3,5,30,70,120):
                self.assertEqual(cap(request,2,mass),0)
                values=[cap(request,gap,mass) for gap in (0,3,5,10,30,100)]
                self.assertEqual(values,sorted(values))
                self.assertTrue(all(0<=v<=request for v in values))
        self.assertLess(cap(70,30,40000),cap(70,30,1000))
    def test_shared_owner_path_and_recovery_suppression(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('[_vehicle,_capMps*3.6,_group,true,_travelIntent] call CBE_fnc_CortexInfantrySpeed',s)
        self.assertLess(s.index('private _pedestrianCap='),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('_traffic=[_pedestrianCap/3.6,_vehicle,-1,time,0]',s)
        self.assertIn('if ((_trafficLimited && {!_solidCandidate}) || {_corridorActive} || {_hadCorridor} || {_bypassActive} || {_hadBypass} || {_passActive} || {_hadPass}) then {',s)
        self.assertIn('if (!(_recoveryStage in [2,4]) && {!_keepBypassBudget}) then {',s)
        self.assertIn('RECOVERY_PAUSED',s)
        self.assertIn('if (!_queueNativeActive && {_recoveryStage != 2} && {!_trafficLimited} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_passActive} && {!_hadPass} && {_vehicle distance2D',s)
    def test_hull_geometry_and_bounded_read_only_observation(self):
        s=(ROOT/'addons/infantry/functions/cortexInfantrySpeed.sqf').read_text(encoding='utf-8')
        for marker in ('count _people > 32','min 250','_maxZ >=','_minZ <=',
                       '_minY-_edge-3','_along=_heading vectorMultiply _sign',
                       '_right=[_heading select 1,-(_heading select 0),0]',
                       '[_vehicle,_origin,_right,_along,[0,0,1]]',
                       '[_person,_origin,_right,_along,[0,0,1]]',
                       'if (count _hull != 6) exitWith {_limit=0}'):
            self.assertIn(marker,s)
        self.assertNotIn('worldToModel',s)
        self.assertNotIn(' modelToWorld ',s)
        span=(ROOT/'addons/vehicles/functions/drivingHullInterval.sqf').read_text(encoding='utf-8')
        self.assertIn('_span append [_thirdMinimum-0.05,_thirdMaximum+0.05]',span)
        self.assertIn('!_dual || {count _thirdAxis != 3}',span)
        self.assertIn('if (_span findIf {!finite _x} >= 0) exitWith {[]}',span)
        self.assertEqual(span.count('modelToWorldWorld'),2) # one corner plus the three-edge loop
        # Independent corner geometry exposes the old unit/frame mismatch.
        from itertools import product
        low=(-1,-4,-1);high=(1,2,2)
        for scale in (.5,1,2):
            forward_gap=9.7-high[1]*scale
            old_model_gap=9.7/scale-high[1]
            self.assertAlmostEqual(old_model_gap*scale,forward_gap)
            if scale!=1:self.assertNotAlmostEqual(old_model_gap,forward_gap)
            reverse_gap=9.7+low[1]*scale
            self.assertLess(reverse_gap,forward_gap)
        angle=math.radians(30);c=math.cos(angle);t=math.sin(angle)
        world=[(x,c*y-t*z,t*y+c*z) for x,y,z in product(*zip(low,high))]
        own_z=(min(p[2] for p in world),max(p[2] for p in world))
        for level in (0,8):
            people=[(x,y,z+level) for x,y,z in product((-.3,.3),(9.7,10.3),(0,1.8))]
            pedestrian_z=(min(p[2] for p in people),max(p[2] for p in people))
            overlap=pedestrian_z[1]>=own_z[0]-.3 and pedestrian_z[0]<=own_z[1]+.3
            old_z=[-t*y+c*z for x,y,z in people]
            old_overlap=max(old_z)>=low[2]-.3 and min(old_z)<=high[2]+.3
            self.assertEqual(overlap,level==0)
            self.assertEqual(old_overlap,level==8)
        executable=s.split('params [[',1)[1]
        for forbidden in ('forceSpeed','doMove','spawn','setVariable','waitUntil'):
            self.assertNotIn(forbidden,executable)
        self.assertEqual(s.count('nearEntities'),1)
if __name__=='__main__':unittest.main()
