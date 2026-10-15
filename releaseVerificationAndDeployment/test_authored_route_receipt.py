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

class OwnedAirLegTests(unittest.TestCase):
    def test_air_owned_leg_edit_is_fenced_before_new_waypoint_commands(self):
        s=(ROOT/'addons/aircraft/functions/cortexAirAttack.sqf').read_text(encoding='utf-8')
        gate=s.index('["OWNED_ROUTE_CHANGED"] call _finish')
        self.assertLess(gate,s.index('_ownedWaypoint setWaypointPosition [_destination,0]'))
        self.assertIn('_reason == "OWNED_ROUTE_CHANGED" || {count _snapshot',s)
        self.assertIn('["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED","OWNED_ROUTE_CHANGED"]',s)
        self.assertLess(s.index('_group setCurrentWaypoint _ownedWaypoint;'),s.index('_job set ["ownedWaypointReceipt"'))
        receipt=(ROOT/'addons/core/functions/authoredRouteReceipt.sqf').read_text(encoding='utf-8')
        self.assertIn('["_ownedOnly",false,[true]]',receipt)
        self.assertIn('_ownedName != "" && {waypointName _x == _ownedName}',receipt)
