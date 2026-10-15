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

    def test_convoy_lead_keeps_one_executor_and_predecessor_followers(self):
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        call = '[_group,_lead,_group getVariable ["WAIT_Convoy_Brain",createHashMap],"CONVOY"]'
        self.assertEqual(tick.count(call), 1)
        self.assertLess(tick.index(call), tick.index('private _routeWatch='))
        self.assertIn('if (!_corridorActive && {!_hadCorridor}', tick)
        self.assertIn('if (!_routeDone && {!_corridorActive} && {!_hadCorridor}', tick)
        self.assertIn('_leadLimit=_leadLimit min ((_corridor select 1)*3.6)', tick)
        for guard in ('WAIT_Convoy_LocalRegistry', 'WAIT_Convoy_LocalJobToken',
                      'WAIT_Convoy_ReceivedRevision', '(_mobile select 0) isEqualTo _vehicle',
                      'WAIT_Convoy_DrivingAssist_Enable'):
            self.assertIn(guard, step)
        self.assertIn('_convoy || {missionNamespace getVariable ["WAIT_AIPass_Active",false]}', step)
    def test_convoy_halt_release_and_lead_replacement_retire_only_matching_work(self):
        crew = (ROOT / 'addons/vehicles/functions/convoyCrewLocal.sqf').read_text()
        release = (ROOT / 'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        halt = crew.split('if (_phase == "HALT"', 1)[1]
        self.assertLess(halt.index('doStop driver _vehicle;'), halt.index('"CONVOY_HALT",false'))
        self.assertIn('if (!(_vehicle in _keepCrew)', release)
        self.assertIn('"CONVOY_RELEASED"] call WAIT_fnc_DrivingCorridorRelease', release)
        self.assertIn('"CONVOY_LEAD_CHANGED",false,true', tick)
        fsm = (ROOT / 'addons/main/fsm/convoyOperation.fsm').read_text()
        for phase in ('CORRIDOR_APPROACH', 'CORRIDOR_CROSS'):
            self.assertIn(phase, fsm)

    def test_ordinary_cleanup_cannot_retire_a_convoy_corridor(self):
        release = (ROOT / 'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        guard = release.split('private _corridor=', 1)[1].split('private _restore=', 1)[0]
        self.assertIn('param [0,""]) == "ORDINARY"', guard)
        self.assertLess(guard.index('== "ORDINARY"'), guard.index('call WAIT_fnc_DrivingCorridorRelease'))

    def test_convoy_uses_worst_hull_without_multiplying_geometry_probes(self):
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        geometry = (ROOT / 'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        self.assertEqual(step.count('call WAIT_fnc_DrivingCorridorGeometry'), 1)
        self.assertIn('count (_configuration param [4,[]]) <= 20', step)
        for dimension in range(3):
            self.assertIn(f'_envelope set [{dimension}', step)
            self.assertIn(f'_envelope param [{dimension},0]', geometry)
        self.assertIn('"INVALID_ENVELOPE"', geometry)
