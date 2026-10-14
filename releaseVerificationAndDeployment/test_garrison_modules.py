"""Offline authority and task-control contracts; physical module acceptance remains pending."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name): return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
class GarrisonModuleTests(unittest.TestCase):
    def test_network_sender_is_authenticated_before_pending_allocation(self):
        dispatch=src('cortexOrderDispatch')
        for required in ('isRemoteExecuted','_requestOwner = _sender','getAssignedCuratorLogic','count _pairs > 16','count _pending >= 64'):
            self.assertIn(required,dispatch)
            self.assertLess(dispatch.index(required),dispatch.index('_pending set [_token'))
        self.assertIn('count _pos == 3',dispatch)
        self.assertIn('_teleport isEqualType true',dispatch)
        self.assertIn('_settings set ["requestSerial",_serial]',dispatch)
    def test_owner_rejects_stale_tasks_before_order_mutation(self):
        local=src('cortexOrderLocal')
        for required in ('remoteExecutedOwner != 2','WAIT_Cortex_LastTaskSerial','WAIT_fnc_NativeOrderReceipt','_token != str _serial'):
            self.assertLess(local.index(required),local.index('setVariable ["WAIT_AIPass_ZeusWaypoints"'))
        self.assertIn('createHashMapFromArray [["teleport",_teleport]]',local)
    def test_garrison_controls_are_explicit_scoped_tasks(self):
        native=src('moduleGarrison'); zen=src('zenGarrisonModule')
        self.assertIn('attachedTo _logic',native)
        self.assertNotIn('nearestObjects',native)
        self.assertNotIn('nearestObjects',zen)
        self.assertIn('[[false,true],["Walk into positions","Instant interior placement"],0]',zen)
        self.assertIn('[15,150,50,0]',zen)
        self.assertIn('call WAIT_fnc_CortexOrderDispatch',zen)
        for text in (native,zen):
            self.assertNotIn('CBA_fnc_addSetting',text)
            self.assertNotIn('CBA_settings_fnc_set',text)
if __name__=='__main__': unittest.main()
