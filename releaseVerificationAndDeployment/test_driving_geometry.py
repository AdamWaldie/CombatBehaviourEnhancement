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
