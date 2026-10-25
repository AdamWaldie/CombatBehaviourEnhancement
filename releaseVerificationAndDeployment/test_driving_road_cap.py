"""Road observation boundaries and speed policy; no native steering acceptance."""
from pathlib import Path
import math
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingRoadCapTests(unittest.TestCase):
    def test_shared_observer_is_bounded_read_only_and_absolute(self):
        s=(ROOT/'addons/vehicles/functions/drivingRoadCap.sqf').read_text(encoding='utf-8')
        for marker in ('from 1 to 8','count _allConnected > 16','_road in _visited',
                       '_travel >= 70','[_road] call _readRoadGeometry','[_nextRoad] call _readRoadGeometry','_cap=_cap min 15'):
            self.assertIn(marker,s)
        executable=s.split('params [[',1)[1]
        for forbidden in ('forceSpeed','doMove','setCurrentWaypoint','setDriveOnPath',
                          'addWaypoint','createVehicle','spawn','waitUntil','setVariable'):
            self.assertNotIn(forbidden,executable)
        self.assertEqual(s.count('nearRoads'),1)
    def test_grade_uses_asl_road_endpoints_including_within_piece_slope(self):
        s=(ROOT/'addons/vehicles/functions/drivingRoadCap.sqf').read_text(encoding='utf-8')
        geometry=s.split('private _readRoadGeometry={',1)[1].split('if (!isNull _road)',1)[0]
        for gate in ['getRoadInfo _piece', '_info param [6,[],[[]]]', '_info param [7,[],[[]]]',
                     '(_begin vectorAdd _end) vectorMultiply 0.5',
                     'abs ((_end select 2)-(_begin select 2))/_length',
                     'if (_bridge) exitWith {[[],0,false]}', 'finite _x']:
            self.assertIn(gate,geometry)
        self.assertNotIn('getTerrainHeightASL',geometry)
        self.assertNotIn('set [2,0]',geometry)
        self.assertIn('_maximumGrade max (_roadGeometry select 1)',s)
        self.assertIn('_maximumGrade max (_nextGeometry select 1)',s)
        self.assertIn('if (!(_nextGeometry select 2)) exitWith {_overBudget=true}',s)

    def test_both_modes_consume_the_observer_before_owned_speed_commands(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertLess(ordinary.index('call CBE_fnc_DrivingRoadCap'),ordinary.index('_vehicle forceSpeed _capMps'))
        self.assertIn('_cap=_cap min (_roadObservation select 0)',ordinary)
        self.assertIn('["roadLookAt",time+3]',convoy)
        self.assertIn('["roadAssist",_roadObservation]',convoy)
        self.assertEqual(convoy.count('call CBE_fnc_DrivingRoadCap'),1)
    def test_policy_never_raises_requested_or_existing_lower_speed(self):
        def cap(requested,turn,grade,junction,dense=False):
            result=min(120,max(0,requested))
            if turn>70:result=min(result,18)
            elif turn>45:result=min(result,25)
            elif turn>25:result=min(result,35)
            if junction:result=min(result,30)
            if grade>0.2:result=min(result,18)
            elif grade>0.12:result=min(result,25)
            if dense:result=min(result,15)
            return result
        for requested in (0,5,15,30,70,120):
            for turn in (0,25,26,45,46,70,71):
                for grade in (0,0.12,0.13,0.2,0.21):
                    for junction in (False,True):
                        self.assertLessEqual(cap(requested,turn,grade,junction),requested)
        self.assertEqual(cap(70,71,0,False),18)
        self.assertEqual(cap(70,0,0.21,False),18)
        self.assertEqual(cap(5,71,0.21,True),5)
        self.assertEqual(cap(70,0,0,False,True),15)
        # Seven ten-degree pieces form a seventy-degree sweep inside the existing
        # look-ahead. Local turns alone stay below the policy threshold; the actual
        # approach bearing identifies the bend without adding a road query.
        points=[(60*(1-math.cos(math.radians(a))),60*math.sin(math.radians(a))) for a in range(10,71,10)]
        headings=[math.degrees(math.atan2(x,y)) for x,y in points]
        local_turn=10
        approach_turn=max(headings)
        self.assertLess(local_turn,25)
        self.assertAlmostEqual(approach_turn,35)
        self.assertEqual(cap(70,local_turn,0,False),70)
        self.assertEqual(cap(70,approach_turn,0,False),35)
        source=(ROOT/'addons/vehicles/functions/drivingRoadCap.sqf').read_text()
        self.assertIn('_vehiclePosition getDir _nextPosition',source)
        self.assertIn('(_maximumTurn max _segmentTurn) max _approachTurn',source)
        self.assertIn('private _segmentHeading=_roadPosition getDir _nextPosition',source)
        self.assertIn('_roadHeading=_segmentHeading',source)
        # A selected road's origin can sit north while its endpoint midpoint lies
        # east of the previous piece. An origin-derived local turn of zero misses
        # the actual right-angle segment even when vehicle-to-piece bearing is small.
        previous=(0,50); midpoint=(10,50); origin=(0,60)
        def bearing(a,b): return math.degrees(math.atan2(b[0]-a[0],b[1]-a[1]))
        origin_turn=abs(bearing(previous,origin))
        endpoint_turn=abs(bearing(previous,midpoint))
        approach=abs(bearing((0,0),midpoint))
        self.assertEqual(origin_turn,0)
        self.assertLess(approach,25)
        self.assertEqual(cap(70,max(origin_turn,approach),0,False),70)
        self.assertEqual(cap(70,max(endpoint_turn,approach),0,False),18)

if __name__=='__main__':unittest.main()


class BridgeGradePolicyTests(unittest.TestCase):
    def test_actual_bridge_uses_deck_grade_after_shared_road_safety_cap(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        policy=text.split('private _surfaceRoad=roadAt _vehicle;',1)[1].split('// The short rear leg',1)[0]
        self.assertIn('isOnRoad _vehicle',policy)
        self.assertIn('!isNull _surfaceRoad',policy)
        self.assertIn('getRoadInfo _surfaceRoad',policy)
        self.assertIn('param [8,false,[true]]',policy)
        self.assertLess(policy.index('if (_onBridge)'),policy.index('if (_maximumGrade > 0.2)'))
        self.assertIn('_maximumGrade=_roadObservation select 2',policy)
        self.assertLess(text.index('_cap=_cap min (_roadObservation select 0)'),text.index('private _surfaceRoad='))
