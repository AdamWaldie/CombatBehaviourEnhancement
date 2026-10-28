"""Delayed grenade release must preserve replacement authored tasks."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
class GrenadeNativeHandoverTests(unittest.TestCase):
    def test_receipt_is_captured_before_escape_and_retained_in_callback(self):
        s = (ROOT / "addons/infantry/functions/cortexGrenadeCheck.sqf").read_text()
        admission = s.split('private _grenade =', 1)[1]
        self.assertLess(admission.index('private _nativeRoute=[_group] call CBE_fnc_NativeOrderReceipt;'), admission.index('_unit doMove _spot;'))
        self.assertIn('_group getVariable ["CBE_AIPass_Epoch",0],_nativeRoute,clientOwner,_returnAnchor]', admission)
        self.assertLess(admission.index('private _returnAnchor=formLeader _unit;'), admission.index('_unit enableAI "PATH"'))
        self.assertEqual(s.count('call CBE_fnc_CortexQueueJob'), 2)  # header example and single regroup job
        # Existing movement cleanup must not be postponed as if it were a new reaction.
        self.assertIn('["subsystem","GRENADE_CLEANUP"]',admission)
        self.assertLess(admission.index('call CBE_fnc_CortexQueueJob'),admission.index('call CBE_fnc_SchedulerReconcile'))
        reconcile=(ROOT/'addons/core/functions/schedulerReconcile.sqf').read_text()
        tick=(ROOT/'addons/core/functions/cortexSchedulerTick.sqf').read_text()
        self.assertIn('case "GRENADE_CLEANUP"',reconcile)
        self.assertIn('count _grenadeActors <= 16',reconcile)
        self.assertIn('case "GRENADE_CLEANUP": {"CBE_Grenade_CleanupSchedulerActive"}',tick)
        self.assertIn('if (_subsystem == "GRENADE_CLEANUP") then {_jobPaused=false}',tick)
        self.assertIn('if (_grenadeRetired)',tick)
        throw=(ROOT/'addons/infantry/functions/cortexThrowGrenade.sqf').read_text()
        retry=throw.split('params ["_unit", "_muzzle", "_magazine"',1)[1]
        self.assertLess(retry.index('if (!local _unit || {!local _group}'),retry.index('private _cancel ='))
        self.assertIn('CBE_Cortex_ThrowOwner",[_group,_ownerEpoch,_operationGeneration,_throwGeneration,clientOwner]',throw)
        self.assertEqual(throw.count('private _throwOwner=_actor getVariable'),2)
        self.assertIn('(_pending select 3) isEqualTo (_throwOwner select 3)',throw)
        self.assertIn('CBE_Cortex_FragFlightGeneration',throw)
        self.assertIn('CBE_Cortex_ThrowTracePending",[]]) param [3,-1,[0]]) != _generation',throw)
        self.assertIn('CBE_Cortex_FragFlightGeneration",-1]) != _generation',throw)
        # A cancelled newer request must not strand an older installed listener.
        def timeout_cleanup(handler,installed_handler,generation,installed_generation,same_owner=True):
            return same_owner and handler==installed_handler and generation==installed_generation
        self.assertTrue(timeout_cleanup(3,3,1,1))  # New request2 never installed a listener.
        self.assertFalse(timeout_cleanup(3,3,1,2)) # Reused native ID belongs to successor2.
        self.assertFalse(timeout_cleanup(3,3,1,1,False))
        self.assertIn('[_unit,_traceHandler,_group,_ownerEpoch,_throwGeneration,clientOwner],3',throw)
        self.assertIn('[_unit,_handler,_group,_ownerEpoch,_throwGeneration,clientOwner],10',throw)
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text()
        self.assertLess(locality.index('setVariable ["CBE_Cortex_ThrowGeneration"'),locality.index('private _fragHandler'))
        self.assertIn('setVariable ["CBE_Cortex_ThrowOwner",nil]',locality)
        self.assertIn('setVariable ["CBE_Cortex_FragFlightGeneration",nil]',locality)
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
