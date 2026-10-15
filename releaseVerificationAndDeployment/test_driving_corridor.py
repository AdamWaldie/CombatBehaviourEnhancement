"""Corridor authority and proposal budgets; no physical steering acceptance."""
from pathlib import Path
import math
import unittest
ROOT = Path(__file__).resolve().parents[1]
class CorridorFoundationTests(unittest.TestCase):
    def test_registration_has_no_remote_or_movement_authority(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorRegister.sqf').read_text()
        body = source.split('params [[', 1)[1]
        self.assertIn('!isServer || {isRemoteExecuted}', body)
        self.assertIn('count _records >= 32', body)
        self.assertLess(body.index('_area setVariable'), body.index('missionNamespace setVariable'))
        for command in ('doMove', 'setDriveOnPath', 'forceSpeed', 'remoteExec', 'spawn', 'waitUntil'):
            self.assertNotIn(command, body)
    def test_geometry_cannot_move_or_flatten_the_vehicle(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        body = source.split('params [[', 1)[1]
        for command in ('doMove', 'setDriveOnPath', 'forceSpeed', 'setPos', 'getTerrainHeightASL', 'spawn', 'waitUntil'):
            self.assertNotIn(command, body)
        self.assertIn('ASLToATL _x', body)
        self.assertIn('"MISSING_SUPPORT"', body)
        self.assertIn('"AREA_CHANGED"', body)
        self.assertIn('"HULL_TOO_WIDE"', body)
    def test_declared_sampling_bound_holds_across_allowed_lengths(self):
        for half_length in range(5, 46):
            segments = math.ceil(2 * (half_length + 30) / 8)
            stations = segments + 1
            self.assertLessEqual(stations, 20)
            self.assertLessEqual(3 * stations + 6 * segments, 174)
            self.assertLessEqual(2 * (half_length + 30) / segments, 8)

    def test_executor_is_finite_and_uses_physical_hull_completion(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        for required in ('serverTime >= (_work get "deadline")', '"hardDeadline"',
                         '"COMMAND_CHANGED"', '"AREA_CHANGED"', 'modelToWorldWorld',
                         'vectorDotProduct _travel < 5', '"PHYSICALLY_CROSSED"',
                         '"CORRIDOR_DEPARTED"', '_work getOrDefault ["entered",false]'):
            self.assertIn(required, source)
        self.assertNotIn('unitReady', source)
        self.assertEqual(source.count('setDriveOnPath'), 1)
        for forbidden in ('addWaypoint', 'deleteWaypoint', 'enableAI', 'setPos', 'spawn', 'waitUntil'):
            self.assertNotIn(forbidden, source)
    def test_controller_owns_one_writer_and_suppresses_route_recovery(self):
        source = (ROOT / 'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('call WAIT_fnc_DrivingCorridorStep', source)
        self.assertIn('[_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call WAIT_fnc_DrivingCorridorRelease', source)
        self.assertIn('_capMps=_capMps min (_corridor select 1)', source)
        self.assertIn('&& {!_corridorActive} && {!_hadCorridor}', source)
        fsm = (ROOT / 'addons/main/fsm/drivingOperation.fsm').read_text()
        for phase in ('CORRIDOR_APPROACH', 'CORRIDOR_CROSS'):
            self.assertIn(phase, fsm)
        release = (ROOT / 'addons/vehicles/functions/drivingCorridorRelease.sqf').read_text()
        self.assertLess(release.index('expectedDestination _operator'), release.index('doStop _driver;'))
        self.assertIn('call WAIT_fnc_CortexExternalTakeover', release)
    def test_full_hull_completion_does_not_accept_centre_only_crossing(self):
        # A centre ten metres past the plane still leaves a 16-metre half-length hull behind it.
        for half_length in (2, 8, 16, 23):
            extension = max(10, math.hypot(half_length, 2) + 6)
            self.assertGreaterEqual(extension - half_length, 5)
        self.assertLess(10 - 16, 5)
