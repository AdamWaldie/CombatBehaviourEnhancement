"""Convoy halt/restart source contracts, not engine command propagation proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class ConvoyHaltReceipt(unittest.TestCase):
    def test_halt_command_and_receipt_share_actual_seat_and_registry_transaction(self):
        s=source('convoyCrewLocal').split('private _stopDriver=',1)[1].split('} forEach _vehicles;',1)[0]
        self.assertLess(s.index('isNil {'),s.index('_vehicle setDriveOnPath []'))
        for gate in ('driver _vehicle != _stopDriver','CBE_Convoy_LocalRegistry','CortexActorMoveReserved','currentCommand _x'):
            self.assertLess(s.index(gate),s.index('_vehicle forceSpeed 0'))
        self.assertLess(s.index('doStop driver _vehicle'),s.index('setVariable ["CBE_Convoy_HaltReceipt"'))
        for value in ('_haltDriver,_haltOperator','currentCommand _haltDriver','expectedDestination _haltOperator','CBE_fnc_AuthoredRouteReceipt'):
            self.assertIn(value,s)
    def test_resume_refuses_stale_seats_commands_route_or_controller(self):
        s=source('convoyTick').split('// Resume only the actual steering HALT',1)[1].split('{[_x,_group,"ACQUIRE"',1)[0]
        self.assertIn('count _haltReceipt == 6',s)
        for gate in ('(_haltReceipt select 1) == driver _lead','(_haltReceipt select 2) == _leadOperator',
                     '(_haltReceipt select 3) isEqualTo','(_haltReceipt select 5) isEqualTo _resumeRoute',
                     '[_resumeWaypoint] call _mayRecoverWaypoint','[_lead,_leadOperator] call _mayIssueDriving',
                     'CBE_Convoy_LocalRegistry','CBE_Convoy_Brain'):
            self.assertLess(s.index(gate),s.index('_lead move waypointPosition'))
        self.assertLess(s.index('isNil {'),s.index('doFollow leader _group'))
        self.assertGreater(s.index('setVariable ["CBE_Convoy_HaltReceipt",nil]'),s.index('_lead move waypointPosition'))
if __name__=='__main__': unittest.main()
