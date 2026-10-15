"""Shared solid/gate observation wiring; no physical detour or braking acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingGeometryTests(unittest.TestCase):
    def test_geometry_is_one_bounded_live_observation_without_helpers(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text().split('params [[',1)[1]
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        for required in ('true,4,"GEOM","NONE"','[_left,(_left+_right)*0.5,_right]',
                         'forEach _heights','max 25 min 600','getPosWorld _object','vectorUp _object',
                         'abs (_normal select 2) < 0.7','_object isKindOf "LandVehicle"'):
            self.assertIn(required,s)
        for forbidden in ('createVehicle','allMissionObjects','allDead','spawn','waitUntil','setVariable',
                          'setVelocity','doMove','forceSpeed','animateSource','animationSourcePhase'):
            self.assertNotIn(forbidden,s)
    def test_gate_adapter_preserves_only_gate_result_and_barriers_need_sources(self):
        s=(ROOT/'addons/vehicles/functions/drivingGateCap.sqf').read_text()
        self.assertIn('call WAIT_fnc_DrivingGeometryCap) select 0',s)
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        self.assertIn('_gateClasses getOrDefault',s)
        self.assertIn('for "_index" from 1 to 8',s)
        self.assertIn('isClass (configOf _object >> "AnimationSources"',s)
        self.assertIn('[_gateObservation,_solidObservation]',s)
    def test_solid_constraints_reuse_existing_writers_and_fsm_queue(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertEqual(ordinary.count('call WAIT_fnc_DrivingGeometryCap'),1)
        self.assertEqual(convoy.count('call WAIT_fnc_DrivingGeometryCap'),2)
        self.assertIn('_traffic=_obstacleObservation select [0,5]',ordinary)
        self.assertIn('_leadTraffic=_leadObstacle select [0,5]',convoy)
        self.assertIn('_traffic=_vehicleObstacle select [0,5]',convoy)
        for path in ('drivingOperation','convoyOperation'):
            self.assertIn('""OBSTACLE""',(ROOT/f'addons/main/fsm/{path}.fsm').read_text())
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertIn('WAIT_DrivingAssist_Obstacle",nil',release)

    def test_turn_prediction_is_bounded_read_only_and_keeps_absolute_hull_rows(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        for marker in ('angularVelocityModelSpace _vehicle','_velocity <= 1','_velocity*2.5',
                       '70/57.2957795','>= 3','0.5*_bendLength,_bendLength,_horizon',
                       'count _stations-1','_front*sin _angle','_width*sin _angle',
                       '_segmentStart+_fraction*(_segmentEnd-_segmentStart)','_from vectorDistance _to'):
            self.assertIn(marker,s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('setAngularVelocity',s)
        self.assertNotIn('setVariable',s.split('params [[',1)[1])

    def test_track_measurement_resets_at_ownership_route_and_motion_boundaries(self):
        s=(ROOT/'addons/vehicles/functions/drivingTurnTrack.sqf').read_text()
        for marker in ('clientOwner','driver _vehicle','effectiveCommander _vehicle',
                       '_forward <= 1','_previous select 0) isNotEqualTo _identity',
                       'time-(_previous select 2) > 6','_distanceSquared >= 9',
                       'time-(_previous select 2) >= 1.5','abs _curvature < 0.004',
                       'worldToModel','ASLToAGL'):
            self.assertIn(marker,s)
        for forbidden in ('setVariable','spawn','waitUntil','doMove','forceSpeed','lineIntersectsSurfaces'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        for name in ('drivingAssistStart','convoyTick'):
            self.assertIn('call WAIT_fnc_DrivingTurnTrack',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())

    def test_ordinary_measurements_are_per_vehicle_and_prune_departed_roster(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('private _geometryTracks=createHashMap',s)
        self.assertIn('_priorTracks getOrDefault [netId _x,[]]',s)
        self.assertIn('_geometryTracks getOrDefault [netId _vehicle,[]]',s)
        self.assertIn('_geometryTracks set [netId _vehicle,_turn select 1]',s)
        self.assertNotIn('getOrDefault ["geometryTrack",[]]',s)

    def test_native_path_hint_is_fresh_local_bounded_and_not_a_movement_writer(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text()
        for marker in ('"PathCalculated"','_path select [0,64]','_thisEventHandler',
                       'removeEventHandler','_expectedRevision','time-(_segment select 1) > 5',
                       'expectedDestination _driver','expectedDestination _operator',
                       '_distance < _nearDistance','_distance >= 3','_best=12','(_local select 1) > 1','_nearIndex+3','_oldBinding select 3'):
            self.assertIn(marker,s)
        for forbidden in ('doMove','setDriveOnPath','forceSpeed','calculatePath','createAgent','spawn','waitUntil'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        self.assertNotRegex(s.split('params [[',1)[1],r'setVariable\s*\[[^\n]*,\s*true\s*\]')
        for name in ('drivingAssistRelease','convoyReleaseLocal'):
            self.assertIn('call WAIT_fnc_DrivingNativePathWatch',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())

    def test_native_path_subscription_expires_before_copy_and_feature_off_retires_old_revision(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text()
        event=s.split('private _id=_driver addEventHandler',1)[1].split('_record=[_group',1)[0]
        for marker in ('WAIT_DrivingNativePath_ValidUntil','CortexFeatureEnabled',
                       'bis_fnc_moduleRemoteControl_owner','CortexExternalOwner'):
            self.assertLess(event.index(marker),event.index('_path select [0,64]'))
        self.assertIn('[_unit,effectiveCommander _vehicle] findIf',event)
        self.assertIn('[_driver,_operator] findIf',s)
        self.assertIn('"WAIT_DrivingNativePath_ValidUntil",time+6',s)
        self.assertIn('"WAIT_DrivingNativePath_ValidUntil",nil',s)
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('["CONVOY"],true] call WAIT_fnc_DrivingNativePathWatch',tick)
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        self.assertIn('["CONVOY"],true,_navigation getOrDefault ["revision",-1]',release)

    def test_native_path_crossing_refuses_disconnected_near_stretches(self):
        source=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text(encoding='utf-8')
        for marker in ('_nearRuns=0','_inNearRun=false','_distance <= 3',
                       'if (!_inNearRun) then {_nearRuns=_nearRuns+1}',
                       '_nearIndex < 0 || {_distance < _nearDistance}',
                       '_nearIndex < 0 || {_nearRuns > 1}'):
            self.assertIn(marker,source)
        # Dense consecutive near segments are one stretch; leaving and returning is ambiguous.
        def stretches(flags):
            return sum(flag and (i==0 or not flags[i-1]) for i,flag in enumerate(flags))
        self.assertEqual(stretches([False,True,True,True,False]),1)
        self.assertEqual(stretches([True,True,False,False,True]),2)
        self.assertEqual(stretches([False]*63),0)
        # A self-crossing polyline has two separate stretches near the origin.
        # Its later northbound return must not replace the first northeast approach.
        import math
        def distance_to_segment(a,b):
            dx,dy=b[0]-a[0],b[1]-a[1]
            fraction=max(0,min(1,-(a[0]*dx+a[1]*dy)/(dx*dx+dy*dy)))
            return math.hypot(a[0]+fraction*dx,a[1]+fraction*dy)
        crossing=[(-10,-5),(8,4),(20,20),(0,-10),(0,8)]
        flags=[distance_to_segment(a,b)<=3 for a,b in zip(crossing,crossing[1:])]
        self.assertEqual(flags,[True,False,False,True])
        self.assertEqual(stretches(flags),2)
