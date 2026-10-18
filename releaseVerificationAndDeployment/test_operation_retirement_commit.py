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
    def test_cancelled_completion_and_recovery_remain_terminal(self):
        release=(ROOT/'addons/core/functions/operationRelease.sqf').read_text(encoding='utf-8')
        admission,commit=release.split('private _retired=false;',1)
        self.assertLess(admission.index('== "CANCELLED"'),admission.index('CBE_fnc_OperationRestore'))
        self.assertLess(commit.index('== "CANCELLED"'),commit.index('setVariable ["CBE_Operation",nil,true]'))
        recovery=(ROOT/'addons/infantry/functions/recoveryStep.sqf').read_text(encoding='utf-8')
        admission,commit=recovery.split('isNil {',1)
        self.assertIn('== "CANCELLED"',admission)
        self.assertLess(commit.index('== "CANCELLED"'),commit.index('_currentOperation set ["recoveryAttempts"'))
        self.assertLess(commit.index('== "CANCELLED"'),commit.index('doMove'))

    def test_progress_is_isolated_and_current_at_publication(self):
        text=(ROOT/'addons/core/functions/operationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _unavailable=+(',text)
        self.assertIn('private _recovery=createHashMapFromArray',text)
        self.assertIn('_entryOperation set [_x,_value]',text)
        commit=text.split('private _committedStatus="REPLACED";',1)[1]
        for guard in ('isNil {','!local _group','_entryEpoch !=','== "CANCELLED"',
                      '_current isNotEqualTo _entryOperation','CBE_fnc_CortexZeusHeld','CBE_fnc_CortexIsEligible'):
            self.assertLess(commit.index(guard),commit.index('setVariable ["CBE_Operation"'))
        self.assertIn('if (_current isNotEqualTo _entryOperation) exitWith {"ACTIVE"}',commit)
        self.assertEqual(text.count('setVariable ["CBE_Operation"'),1)
        self.assertNotIn('doMove',text)

    def test_posture_cleanup_cannot_release_a_successor_lease(self):
        for name in ('operationCancel','operationRelease'):
            text=(ROOT/'addons/core/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            cleanup=text.split('private _dangerActor=objNull;',1)[1].split('private _retired=false;',1)[0]
            for proof in ('isNil {','local _group','_entryEpoch ==','_current isEqualTo _operation',
                          'CBE_OperationGeneration','count _postureLease == 8',
                          '(_postureLease select 5) == _generation','(_postureLease select 6) == _operationEpoch'):
                self.assertLess(cleanup.index(proof),cleanup.index('call CBE_fnc_DangerReact'))

    def test_group_route_checks_native_edits_and_tasks_at_commit(self):
        text=(ROOT/'addons/infantry/functions/cortexGroupMove.sqf').read_text(encoding='utf-8')
        adoption=text.split('if (_sameRequest) exitWith {',1)[1].split('private _committed=',1)[0]
        self.assertIn('call _nativeTaskBusy',adoption)
        self.assertIn('call _routeUnchanged',adoption)
        commit=text.split('_committed=call {',1)[1]
        self.assertLess(commit.index('call _routeUnchanged'),commit.index('call CBE_fnc_CortexGroupMoveClear'))
        self.assertEqual(commit.count('call _nativeTaskBusy'),2)
        geometry=text.split('private _routeUnchanged={',1)[1].split('// Keep an established',1)[0]
        for field in ('waypointDescription','waypointPosition','waypointType','waypointCompletionRadius'):
            self.assertIn(field,geometry)

    def test_danger_restore_owns_exact_lease_at_native_boundary(self):
        text=(ROOT/'addons/infantry/functions/dangerReact.sqf').read_text(encoding='utf-8')
        restore=text.split('private _restoreResult="IGNORED";',1)[1].split('if !(_cause in ["HIT"',1)[0]
        for proof in ('isNil {','!local _actor','group _actor != _group','!local _group',
                      'CBE_AIPass_Epoch','CBE_OperationGeneration','isNotEqualTo _lease'):
            self.assertLess(restore.index(proof),restore.index('setVariable ["CBE_Danger_ReactionLease"'))
            self.assertLess(restore.index(proof),restore.index('_group setBehaviour'))
        self.assertLess(restore.index('CBE_fnc_CortexExternalTakeover'),restore.index('_group setCombatMode'))
        self.assertIn('private _lease=+(',text)

    def test_danger_application_and_baseline_share_authority_boundary(self):
        text=(ROOT/'addons/infantry/functions/dangerReact.sqf').read_text(encoding='utf-8')
        commit=text.split('private _postureResult="IGNORED";',1)[1]
        for proof in ('isNil {','!local _actor','!local _group','group _actor != _group',
                      'CBE_AIPass_Epoch','CBE_OperationGeneration','isNotEqualTo _lease',
                      'CBE_fnc_CortexExternalTakeover','combatMode _group in ["BLUE","GREEN"]',
                      'currentCommand _actor','== "CANCELLED"'):
            self.assertLess(commit.index(proof),commit.index('_group setBehaviour'))
            self.assertLess(commit.index(proof),commit.index('setVariable ["CBE_Danger_ReactionLease"'))
        self.assertIn('_tacticalModeOwned',commit)
        for forbidden in ('doMove','doFollow','lineIntersects','nearestObjects','waitUntil'):
            self.assertNotIn(forbidden,commit)

    def test_permission_restore_consumes_only_current_lease_in_atomic_scope(self):
        text=(ROOT/'addons/core/functions/operationRestore.sqf').read_text(encoding='utf-8')
        for proof in ('isNil {','_current isNotEqualTo _operation','ownerEpoch','count _members > 64',
                      'attackEnabled _anchor != (_attack select 1)'):
            self.assertLess(text.index(proof),text.index('_group enableAttack'))
        self.assertLess(text.index('isNil {'),text.index('_restore deleteAt "groupAttack"'))
        body=text.split('_restored=call {',1)[1]
        self.assertLess(body.index('!local _group'),body.index('_group enableAttack'))
        self.assertIn('!isNull remoteControlled _x',body)
        self.assertIn('bis_fnc_moduleRemoteControl_owner',body)
        for forbidden in ('lineIntersects','nearestObjects','spawn {','waitUntil','doMove','doFollow'):
            self.assertNotIn(forbidden,text)
if __name__=='__main__': unittest.main()
