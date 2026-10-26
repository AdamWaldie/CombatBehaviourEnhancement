"""Delayed grenade release must preserve replacement authored tasks."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
class GrenadeNativeHandoverTests(unittest.TestCase):
    def test_receipt_is_captured_before_escape_and_retained_in_callback(self):
        s = (ROOT / "addons/infantry/functions/cortexGrenadeCheck.sqf").read_text()
        admission = s.split('private _grenade =', 1)[1]
        self.assertLess(admission.index('private _nativeRoute=[_group] call CBE_fnc_NativeOrderReceipt;'), admission.index('_unit doMove _spot;'))
        self.assertIn('_group getVariable ["CBE_AIPass_Epoch",0],_nativeRoute,clientOwner]', admission)
        self.assertEqual(s.count('call CBE_fnc_CortexQueueJob'), 2)  # header example and single regroup job
    def test_legacy_rows_only_clean_up_and_new_orders_veto_follow(self):
        s = (ROOT / "addons/infantry/functions/cortexGrenadeCheck.sqf").read_text()
        callback = s.split('private _grenade =', 1)[0]
        follow = callback.index('_unit doFollow')
        for guard in ('["_nativeRoute",[],[[]]]', '_nativeRoute isNotEqualTo []',
                      '([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _nativeRoute',
                      'count _destination == 3', '_destination vectorDistance _spot <= 0.25'):
            self.assertLess(callback.index(guard), follow)
        self.assertIn('(expectedDestination _unit) param [0,[],[[]]]', callback)
        cleanup = callback.index('_unit setVariable ["CBE_Cortex_ActorMove",nil]')
        self.assertGreater(cleanup, follow)
        self.assertIn('if (_ownsEvasion && {local _unit}) then {', callback)
        self.assertIn('_actorMove isEqualTo ["GRENADE_EVASION",_spot,_expires]', callback)
        fence=callback.split('private _sourceCurrent=',1)[1].split('private _destination=',1)[0]
        for guard in ('_issuer == clientOwner','local _group','group _unit == _group',
                      'groupOwner _group == clientOwner','CBE_AIPass_Epoch','== _epoch',
                      'CBE_OperationGeneration','== _generation','if (!_sourceCurrent) exitWith {}'):
            self.assertIn(guard,fence)
        self.assertLess(callback.index('if (!_sourceCurrent) exitWith {}'),cleanup)
        self.assertLess(callback.index('if (!_sourceCurrent) exitWith {}'),callback.index('expectedDestination _unit'))
        def may_cleanup(exact=True,actor_local=True,group_local=True,same_group=True,
                        issuer=7,owner=7,epoch=3,original_epoch=3,operation=4,original_operation=4):
            return (exact and actor_local and group_local and same_group and issuer==owner==7
                    and epoch==original_epoch and operation==original_operation)
        self.assertTrue(may_cleanup())
        for change in ({'group_local':False},{'same_group':False},{'issuer':8},
                       {'owner':8},{'epoch':4},{'operation':5},{'exact':False}):
            self.assertFalse(may_cleanup(**change))
