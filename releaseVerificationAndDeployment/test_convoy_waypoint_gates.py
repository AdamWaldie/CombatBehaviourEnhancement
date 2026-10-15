"""Convoy route recovery must preserve authored waits and same-index replacements."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyWaypointGateTests(unittest.TestCase):
    def test_recovery_reads_gates_without_executing_them(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=s.split('private _mayRecoverWaypoint=',1)[1].split('// A stalled engine route',1)[0]
        for field in ('waypointStatements','waypointScript','waypointTimeout','synchronizedTriggers','triggerActivated'):
            self.assertIn(field,gate)
        for forbidden in ('compile','execVM','call compile'):
            self.assertNotIn(forbidden,gate)
        self.assertIn('[_watchedWaypoint] call _mayRecoverWaypoint',s)
        self.assertIn('[_waypoint] call _mayRecoverWaypoint',s)
    def test_watched_metadata_and_lead_retry_identity_are_checked(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('isEqualTo _watchedReceipt',s)
        self.assertIn('isEqualTo _leadRouteReceipt',s)
        self.assertIn('_state set ["leadRouteReceipt",_leadRouteReceipt]',s)
        self.assertIn('_leadProgress=[getPosATL _lead,time,0]',s)
        helper=(ROOT/'addons/core/functions/authoredRouteReceipt.sqf').read_text(encoding='utf-8')
        self.assertIn('["_waypointIndex",-1,[0]]',helper)
        self.assertIn('(_x select 1) == _waypointIndex',helper)
if __name__=='__main__': unittest.main()
