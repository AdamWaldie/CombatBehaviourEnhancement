"""Physical bypass proposal contract, not native steering or performance acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingBypassTests(unittest.TestCase):
    def test_preflight_has_no_movement_or_physics_authority(self):
        for name in ('drivingBypassPlan','drivingPathGeometry'):
            body=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text().split('params [[',1)[1]
            for forbidden in ('doMove','doStop','doFollow','forceSpeed','setDriveOnPath','createVehicle',
                              'setVelocity','setPos','enableAI','spawn','waitUntil','setVariable'):
                self.assertNotIn(forbidden,body)
    def test_proposal_binds_actual_source_and_vehicle_geometry(self):
        body=(ROOT/'addons/vehicles/functions/drivingBypassPlan.sqf').read_text()
        for gate in ('time-_sampled > 1.5','_gap > 50','abs speed _vehicle > 8',
                     '(_observed select 5) != "STATIC"','_observed select 8','boundingBoxReal _obstacle',
                     'modelToWorldWorld','_radius > 12','count _guide+_segments > 24',
                     '"GEOMETRY_CHANGED"','call WAIT_fnc_DrivingPathGeometry'):
            self.assertIn(gate,body)
        self.assertEqual(body.count('call WAIT_fnc_DrivingPathGeometry'),1)
        self.assertNotIn('lineIntersectsSurfaces',body.split('params [[',1)[1])
    def test_shared_validator_keeps_three_body_heights_and_bounded_support(self):
        s=(ROOT/'addons/vehicles/functions/drivingPathGeometry.sqf').read_text()
        for gate in ('count _guide > 24','_length > 8.01','"REVERSING_PATH"','"INVALID_IGNORED_OBJECT"',
                     '"MISSING_SUPPORT"','"WET_SUPPORT"','"CROSS_SLOPE"','"LONGITUDINAL_SLOPE"',
                     '[0.5,(_height+0.5)*0.5,_height]','forEach _bodyHeights','ASLToATL _x'):
            self.assertIn(gate,s)
        corridor=(ROOT/'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        self.assertIn('call WAIT_fnc_DrivingPathGeometry',corridor)
        self.assertNotIn('lineIntersectsSurfaces',corridor)
    def test_sampling_bounds_match_declared_limits(self):
        self.assertEqual(24*3+23*9,279)
        self.assertEqual(20*3+19*9,231)
        # Circumscribed clearance covers the hull at any planar orientation.
        import math
        for width,length in ((1,2),(2,5),(3,9)):
            radius=math.hypot(width,length)+1
            for angle in range(0,91,5):
                projected=abs(width*math.cos(math.radians(angle)))+abs(length*math.sin(math.radians(angle)))
                self.assertGreater(radius,projected)
