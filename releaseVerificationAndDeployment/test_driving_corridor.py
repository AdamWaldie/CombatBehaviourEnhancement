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
            segments = math.ceil(2 * (half_length + 10) / 8)
            stations = segments + 1
            self.assertLessEqual(stations, 15)
            self.assertLessEqual(3 * stations + 6 * segments, 129)
            self.assertLessEqual(2 * (half_length + 10) / segments, 8)
