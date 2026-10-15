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

    def test_executor_has_one_path_write_finite_budget_and_actual_completion(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text()
        self.assertEqual(s.count('setDriveOnPath'),1)
        self.assertIn('["deadline",serverTime+90]',s)
        self.assertIn('serverTime >= (_work get "deadline")',s)
        self.assertIn('_work set ["side",-1]',s)
        self.assertIn('for "_i" from 1 to 4',s)
        self.assertIn('_origin distance2D (_points select _index) <= 2.5',s)
        self.assertIn('modelToWorldWorld',s)
        self.assertIn('vectorDotProduct (_work get "forward") < 5',s)
        self.assertNotIn('unitReady',s)
        self.assertNotIn('set ["deadline"',s)
        self.assertIn('if (isRemoteExecuted) exitWith',s)
        self.assertIn('call _seatsAvailable',s)
        self.assertIn('bis_fnc_moduleRemoteControl_owner',s)
        self.assertNotIn('["authority",',s)
    def test_controller_preserves_other_constraints_and_excludes_other_paths(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertEqual(s.count('call WAIT_fnc_DrivingBypassStep'),1)
        self.assertIn('!_hadBypass',s)
        self.assertIn('_traffic=+_withoutObstacle;',s)
        self.assertIn('_bypass select 3',s)
        self.assertIn('_obstacleObservation select 8',s)
        self.assertIn('_capMps=_capMps min (_bypass select 1)',s)
        self.assertIn('_pedestrianCap/3.6 < (_traffic select 0)',s)
        self.assertIn('WAIT_DrivingBypass_Work',(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text())
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text()
        for phase in ('BYPASS_PLAN','BYPASS_FOLLOW'):self.assertIn(phase,fsm)
    def test_release_requires_owned_follow_and_both_native_receipts(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassRelease.sqf').read_text()
        for marker in ('(_work get "phase") == "FOLLOW"','expectedDestination _driver',
                       'expectedDestination _operator','CortexExternalTakeover','DrivingRouteReceipt',
                       'count _cooldown >= 32','serverTime+120'):
            self.assertIn(marker,s)
        for forbidden in ('setPos','setVelocity','enableAI','addWaypoint','deleteWaypoint','spawn','waitUntil'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])

    def test_executor_rechecks_plain_order_and_both_crew_tasks_before_writes(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text()
        gate=s.split('private _plainRoute={',1)[1].split('private _work=',1)[0]
        for marker in ('waypointType _waypoint == "MOVE"','waypointScript _waypoint == ""',
                       'waypointTimeout','waypointAttachedVehicle','waypointAttachedObject',
                       'synchronizedWaypoints','synchronizedTriggers','call _plainRoute',
                       'DrivingMovementAvailable','CortexExternalTakeover','CortexZeusHeld',
                       'WAIT_ExternalDrivingOwner','WAIT_Convoy_Active','vehicle leader _group == _vehicle'):
            self.assertIn(marker,gate)
        seats=s.split('private _seatsAvailable={',1)[1].split('private _plainRoute={',1)[0]
        self.assertIn('[_driver,_operator] findIf',seats)
        for task in ('"GET IN"','"SCRIPTED"','"REPAIR"','"CARRY SOLDIER"'):
            self.assertIn(task,seats)
        # Admission and the final path-write boundary both re-evaluate the same predicate.
        self.assertGreaterEqual(s.count('call _mayWrite'),2)
        self.assertLess(s.rindex('call _mayWrite'),s.index('_vehicle setDriveOnPath'))
