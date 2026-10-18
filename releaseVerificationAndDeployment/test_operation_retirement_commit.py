"""Common operation cleanup must not erase an operation installed during cleanup."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class OperationRetirement(unittest.TestCase):
    def test_retirement_rechecks_original_identity_after_cleanup(self):
        for name in ('operationCancel','operationRelease'):
            text=(ROOT/'addons/core/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            commit=text.split('private _retired=false;',1)[1]
            for guard in ('isNil {','local _group','_entryEpoch ==','_current getOrDefault ["generation",-2]',
                          '_current getOrDefault ["ownerEpoch",-2]','_current isEqualTo _operation'):
                self.assertLess(commit.index(guard),commit.index('setVariable ["CBE_Operation",nil,true]'))
            self.assertLess(text.index('CBE_fnc_CortexGroupMoveClear'),text.index('private _retired=false;'))
            self.assertIn('if (!_retired) exitWith {false}',text)
    def test_completion_handles_takeover_without_publishing_success(self):
        text=(ROOT/'addons/core/functions/operationRelease.sqf').read_text(encoding='utf-8')
        commit=text.split('private _retired=false;',1)[1]
        self.assertLess(commit.index('CBE_fnc_CortexExternalTakeover'),commit.index('setVariable ["CBE_OperationResult"'))
        self.assertIn('if (_lateTakeover) exitWith',commit)
        self.assertIn('[_group,_generation,_handoverReason] call CBE_fnc_OperationCancel',commit)
        cancel=(ROOT/'addons/core/functions/operationCancel.sqf').read_text(encoding='utf-8')
        admission=cancel.split('private _cancelAdmitted=false;',1)[1].split('CBE_fnc_OperationRestore',1)[0]
        self.assertLess(admission.index('isNil {'),admission.index('_operation set ["phase","CANCELLED"]'))
        self.assertLess(admission.index('_current isEqualTo _operation'),admission.index('_operation set ["phase","CANCELLED"]'))
        self.assertIn('if (!_cancelAdmitted) exitWith {false}',admission)
if __name__=='__main__': unittest.main()
