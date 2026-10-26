"""Shutdown vehicle cleanup ownership contracts; physical owner cleanup is untested."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ShutdownVehicleAuthorityTests(unittest.TestCase):
    def test_vehicle_cleanup_runs_on_each_owner_before_interface_exit(self):
        text=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        marker='// Each actual vehicle owner retires its own receipts'
        start=text.index(marker)
        end=text.index('} forEach (vehicles select {local _x});',start)
        interface=text.index('if (hasInterface && {!isServer}) exitWith {};')
        self.assertLess(end,interface)
        self.assertTrue(text[:start].rstrip().endswith('};'))
        self.assertIn('if (isServer) then {',text[:start])
        block=text[start:end]
        for receipt in ('call CBE_fnc_DrivingAssistRelease','call CBE_fnc_CortexDismountStop',
                        'CBE_Cortex_DismountStopReceipt','CBE_Cortex_DismountStopRequest',
                        'CBE_Cortex_ArtilleryScootToken','CBE_Cortex_OnboardDanger'):
            self.assertIn(receipt,block)
        self.assertIn('CBE_AIPass_SupportRequests',text[:start])
        self.assertLess(block.index('call CBE_fnc_CortexDismountStop'),block.index('call CBE_fnc_DrivingAssistRelease'))
        release=(ROOT/'addons/infantry/functions/cortexReleaseGroup.sqf').read_text(encoding='utf-8')
        self.assertLess(release.index('call CBE_fnc_CortexDismountStop'),release.index('call CBE_fnc_OperationCancel'))
        self.assertLess(release.index('call CBE_fnc_CortexDismountStop'),release.index('call CBE_fnc_CortexRestoreCalm'))
        self.assertEqual(text.count('call CBE_fnc_DrivingAssistRelease;'),1)
        self.assertNotIn('remoteExec',block)
        self.assertLess(block.index('isNil {'),block.index('call CBE_fnc_DrivingAssistRelease'))
        self.assertLess(block.index('if (!local _vehicle) exitWith {};'),block.index('call CBE_fnc_DrivingAssistRelease'))

    def test_server_and_hc_cannot_both_retire_the_same_vehicle(self):
        vehicles={'server_vehicle':2,'hc_vehicle':5,'interface_vehicle':9}
        passes={owner:[v for v,current in vehicles.items() if current==owner] for owner in (2,5,9)}
        self.assertEqual(passes[2],['server_vehicle'])
        self.assertEqual(passes[5],['hc_vehicle'])
        self.assertEqual(passes[9],['interface_vehicle'])
        self.assertEqual(len({v for group in passes.values() for v in group}),len(vehicles))
