"""Authored air route content and non-executing replacement checks, offline only."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AuthoredRouteTests(unittest.TestCase):
    def test_receipt_covers_metadata_and_normalizes_attached_target_motion(self):
        s=(ROOT/'addons/core/functions/authoredRouteReceipt.sqf').read_text()
        for field in ('waypointStatements','waypointTimeout','waypointSpeed','waypointBehaviour','waypointCombatMode','waypointFormation','waypointScript','waypointAttachedVehicle','waypointAttachedObject','synchronizedTriggers','synchronizedWaypoints','waypointLoiterAltitude'):
            self.assertIn(field+' _waypoint',s)
        self.assertNotIn('currentWaypoint',s)
        self.assertNotIn('compile',s)
        self.assertNotIn('execVM',s)
        self.assertIn('isNull _vehicle && {isNull _object}',s)
        self.assertIn('waypointName _x != _ownedName',s)
    def test_air_controller_compares_same_receipt_before_flight_commands(self):
        s=(ROOT/'addons/aircraft/functions/cortexAirAttack.sqf').read_text()
        self.assertIn('private _routeSignature=[_group] call WAIT_fnc_AuthoredRouteReceipt',s)
        self.assertIn('private _currentRoute=[_group,_ownedWaypointName] call WAIT_fnc_AuthoredRouteReceipt',s)
        self.assertLess(s.index('if (_currentRoute isNotEqualTo'),s.index('_aircraft limitSpeed (_stageSpeeds'))
        self.assertIn('["AUTHORED_ROUTE_CHANGED"] call _finish',s)
if __name__=='__main__': unittest.main()
