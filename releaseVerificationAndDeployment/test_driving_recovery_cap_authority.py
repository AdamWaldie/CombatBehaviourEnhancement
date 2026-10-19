"""Recovery movement cleanup requires the same speed lease as ordinary assistance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class RecoveryCapAuthorityTests(unittest.TestCase):
    def test_handback_and_deferral_require_journal_cap_before_any_native_write(self):
        text=source('drivingRecoveryRelease')
        owned=text.split('private _owned=',1)[1].split('private _executable=',1)[0]
        self.assertIn('abs ((getForcedSpeed _vehicle)-(_work get "cap")) <= 0.1',owned)
        self.assertLess(text.index('getForcedSpeed _vehicle'),text.index('if (_owned && {!_executable})'))
        self.assertLess(text.index('getForcedSpeed _vehicle'),text.index('doStop _driver'))
        self.assertIn('if (_owned) then {',text)
        self.assertIn('private _handback="METADATA_ONLY"',text)
        self.assertNotIn('forceSpeed',text.split('params [[',1)[1])
    def test_main_callback_yields_changed_cap_journal_before_release_or_reacquisition(self):
        text=source('drivingAssistStart')
        owned=text.split('private _recoveryOwned=',1)[1].split('private _release=',1)[0]
        self.assertIn('abs ((getForcedSpeed _vehicle)-(_recoveryWork get "cap")) <= 0.1',owned)
        self.assertIn('!_recoveryOwned',owned)
        self.assertIn('setVariable ["CBE_DrivingRecovery_Yield",_routeIdentity,true]',owned)
        self.assertIn('"ORDER_OR_SEATS_CHANGED",false] call CBE_fnc_DrivingRecoveryRelease',owned)
        self.assertLess(text.index('private _recoveryOwned='),text.index('private _mayIssueDriving ='))
        # Vehicle-level BACK is independent of unchanged unit destinations.
        mode='param [0,"",[""]]) != "BACK"'
        self.assertIn(mode,text)
        self.assertIn('count _recoveryWork > 0 && {_recoveryCommandState in ["OWNED","PENDING"]} && {call _destinationControlFree}',text)
        self.assertIn('if (!_enabled || {!(call _destinationControlFree)}',text)
        boundary=text.split('private _mayIssueDriving = {',1)[1].split('// A shared group waypoint',1)[0]
        self.assertIn('call _destinationControlFree',boundary)
        release=source('drivingRecoveryRelease')
        self.assertIn(mode,release)
        self.assertIn('if (_commandMode == "SIMPLE_BACK") then',release)
        self.assertIn('simpleAcknowledged',release)
        self.assertIn('simpleBefore',release)
        self.assertLess(release.index('waypointType _waypoint == "MOVE"'),release.index('sendSimpleCommand "STOP"'))
        self.assertIn('if (_nativeStopPending) exitWith {}',release)
        self.assertIn('if (_nativeStopPending) exitWith {',release)

        self.assertIn('private _owned=_resume && {_commandState == "OWNED"} && {_destinationControlFree}',release)
        self.assertIn('private _retainAcrossLocality=_resume && {_destinationControlFree}',release)

    def test_operator_fallback_matches_capture_without_accepting_replacement_commander(self):
        release=source('drivingRecoveryRelease')
        self.assertIn('private _liveOperator=effectiveCommander _vehicle;',release)
        self.assertIn('if (isNull _liveOperator) then {_liveOperator=driver _vehicle}',release)
        self.assertIn('_liveOperator == _operator',release)
        capture=source('drivingAssistStart')
        self.assertIn('if (isNull _movementOperator) then {_movementOperator=_driver}',capture)
        # Identity policy only; no model claims native commander transition completion.
        def operator(commander,driver):return driver if commander is None else commander
        self.assertEqual(operator(None,'original-driver'),'original-driver')
        self.assertNotEqual(operator('new-commander','original-driver'),'original-driver')
    def test_changed_cap_cannot_gain_pending_retention(self):
        release=source('drivingRecoveryRelease')
        self.assertLess(release.index('getForcedSpeed _vehicle'),release.index('set ["releasePending",true]'))
        self.assertLess(release.index('getForcedSpeed _vehicle'),release.index('call _releaseExpired'))
        assist_release=source('drivingAssistRelease')
        self.assertIn('abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1',assist_release)
        self.assertIn('if (_recoveryPending) exitWith {[_vehicle] call CBE_fnc_DrivingRecoveryCleanup};',assist_release)
        self.assertIn('isEqualTo _recovery',assist_release)
