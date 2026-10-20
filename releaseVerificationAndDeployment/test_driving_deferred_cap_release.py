"""Deferred reverse cap lifecycle contracts; no physical command simulation."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingDeferredCapReleaseTests(unittest.TestCase):
    def test_final_release_preserves_successor_receipts(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        commit=text.split('// Final cap restoration and receipt retirement',1)[1]
        self.assertIn('_abort set ["releasedCap",_baseline]',commit)
        self.assertLess(commit.index('_vehicle forceSpeed'),commit.index('_abort set ["releasedCap",_baseline]'))
        self.assertIn('abs ((getForcedSpeed _vehicle)-_baseline) <= 0.1',commit)
        cleanup=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text()
        self.assertIn('(_head+4) min count _queue',cleanup)
        self.assertIn('[_vehicle,_proof,"ABORT"]',cleanup)
        self.assertIn('CBE_DrivingAbort_CleanupTicket',cleanup)
        self.assertGreaterEqual(cleanup.count('serverTime < _abortUntil'),2)
        self.assertGreaterEqual(cleanup.count('!isNull _abortGroup && {local _abortGroup}'),2)

        self.assertIn('call CBE_fnc_DrivingAbortHandback',cleanup)
        handback=(ROOT/'addons/vehicles/functions/drivingAbortHandback.sqf').read_text()
        self.assertIn('_hold set ["observeAt",serverTime+1]',handback)
        self.assertIn('CAP_REPLACED_OR_HELD',handback)
        self.assertIn('call CBE_fnc_DrivingFollowingCap',handback)
        self.assertIn('call CBE_fnc_DrivingGeometryCap',handback)
        self.assertNotIn('CBA_fnc_waitAndExecute',handback)

        for proof in ('isNil {','!local _vehicle','isNotEqualTo _releaseState',
                      'isNotEqualTo _releaseRestore','_releaseEpoch !='):
            self.assertLess(commit.index(proof),commit.index('_vehicle forceSpeed'))
            self.assertLess(commit.index(proof),commit.index('setVariable ["CBE_DrivingAssist_State",nil]'))
        self.assertLess(text.index('_releaseState=+('),text.index('call CBE_fnc_DrivingPassAdmission'))
        self.assertIn('getOrDefault ["commandMode","DESTINATION"]',text)
        self.assertLess(text.index('if !(call _destinationReleaseAvailable)'),text.index('_releaseState=+('))
        self.assertLess(commit.index('if !(call _destinationReleaseAvailable)'),commit.index('_vehicle forceSpeed'))
        adoption=text.split('private _recovery=_vehicle getVariable',1)[1].split('private _retired=',1)[0]
        self.assertIn('isEqualTo _releaseState',adoption)
        self.assertIn('isEqualTo _releaseRestore',adoption)
        self.assertIn('isEqualTo _recovery',adoption)


    def test_exact_pending_handback_preserves_cap_and_restore_receipt(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        guard=text.split('private _retired=',1)[1].split('if (_recoveryPending) exitWith {[_vehicle] call CBE_fnc_DrivingRecoveryCleanup};',1)[0]
        for item in ('call CBE_fnc_DrivingRecoveryRelease','!_retired',
                     'getOrDefault ["releasePending",false]','isEqualTo _recovery'):
            self.assertIn(item,guard)
        boundary=text.index('if (_recoveryPending) exitWith {[_vehicle] call CBE_fnc_DrivingRecoveryCleanup};')
        for mutation in ('_vehicle forceSpeed (_restore param',
                         'setVariable ["CBE_DrivingAssist_Restore",nil]',
                         'setVariable ["CBE_DrivingAssist_State",nil]',
                         'call CBE_fnc_DrivingNativePathWatch;'):
            self.assertLess(boundary,text.index(mutation))
        self.assertNotIn('waitAndExecute',text)
        self.assertNotIn('addPerFrameHandler',text)

    def test_nonmatching_or_retired_journal_never_gains_deferred_cap_ownership(self):
        def defer(retired,pending,expected,live):return not retired and pending and live==expected
        self.assertTrue(defer(False,True,'old','old'))
        self.assertFalse(defer(True,True,'old','old'))
        self.assertFalse(defer(False,False,'old','old'))
        self.assertFalse(defer(False,True,'old','new'))
        text=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        # Existing exact cap ownership and newer external-controller protections remain.
        self.assertIn('abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1',text)
        self.assertIn('&& {!_externalControl}',text)
        self.assertIn('isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}',text)
