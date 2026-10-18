"""Landing feature handover contracts, not physical flight acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return (ROOT/'addons/aircraft/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class LandingFeatureOwnershipTests(unittest.TestCase):
    def test_admission_records_original_pilot_before_disabling_and_refuses_owned_features(self):
        start=source('improvedHelicopterLandingExecuteLocal')
        admission=start.split('// A landing task cannot adopt',1)[1].split('private _group =',1)[0]
        for marker in ('local _pilot','checkAIFeature "MOVE"','checkAIFeature "PATH"',
                       'checkAIFeature "FSM"','CBE_AirPilotFeatureReceipt'):
            self.assertIn(marker,admission)
        snapshot=start.index('setVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot"')
        self.assertLess(snapshot,start.index('_entryPilot disableAI "FSM"'))
        self.assertIn('[2,_entryPilot,_helicopter,_group,"LANDING:"+_flightLeaseToken,clientOwner,["FSM"],-1]',start)
        loop=start.split('while {',1)[1].split('} do {',1)[0]
        self.assertIn('currentPilot _helicopter == _entryPilot',loop)
        self.assertIn('_groupedAbort, _controlRevision] call CBE_fnc_ImprovedHelicopterLandingRestoreLocal',start)
    def test_cleanup_requires_exact_snapshot_and_preserves_successor_flight_and_pilot(self):
        restore=source('improvedHelicopterLandingRestoreLocal')
        before=restore.split('private _restored=false;',1)[0]
        for marker in ('count _snapshot != 6','_releasedRevision != _expectedRevision',
                       '(_snapshot select 0) isNotEqualTo _expectedRevision',
                       '(_lease getOrDefault ["owner",-1]) == (_snapshot select 1)',
                       'count _lease > 0 && {!_matchingLease}'):
            self.assertIn(marker,before)
        self.assertLess(restore.index('isEqualTo _snapshot'),restore.index('enableAI "MOVE"'))
        self.assertIn('checkAIFeature "PATH") isEqualTo (_snapshot select 5)',restore)
        self.assertNotIn('_pilot enableAI "FSM"',restore)
        for marker in ('(_pilotReceipt select 2) isEqualTo _helicopter',
                       '(_pilotReceipt select 5) isEqualTo (_snapshot select 1)',
                       '(_pilotReceipt select 6) isEqualTo ["FSM"]',
                       'call CBE_fnc_CortexAirPilotFeatureRelease'):
            self.assertIn(marker,restore)
        self.assertLess(restore.index('currentPilot _helicopter != _pilot'),restore.index('_helicopter land "LAND"'))
    def test_anchor_retains_feature_receipt_and_does_not_capture_replacement_pilot(self):
        anchor=source('improvedHelicopterLandingAnchorLocal')
        self.assertIn('(_featureSnapshot select 2) isNotEqualTo _pilot',anchor)
        self.assertLess(anchor.index('_featureSnapshot set [5,true]'),anchor.index('_helicopter enableAI "PATH"'))
        self.assertNotIn('_pilot disableAI "FSM"',anchor)
        self.assertIn('"PILOT_CHANGED"',anchor)
        release=source('cortexAirPilotFeatureRelease')
        self.assertIn('["AUTOCOMBAT","TARGET","AUTOTARGET","FSM"]',release)
        self.assertIn('(_actor getVariable ["CBE_AirPilotFeatureReceipt",[]]) isEqualTo _receipt',release)
        self.assertIn('_attempt >= 60',release)

    def test_final_flight_handback_and_late_snapshot_release_are_separately_fenced(self):
        restore=source('improvedHelicopterLandingRestoreLocal')
        final=restore.split('// Actor release can defer',1)[1]
        for marker in ('isNil {','!local _helicopter','currentPilot _helicopter != _pilot',
                       'count _nativeLease > 0','!= _expectedRevision+1'):
            self.assertLess(final.index(marker),final.index('_helicopter land "LAND"'))
        step=source('improvedHelicopterLandingStep')
        probe=step.split('private _oldFeatureSnapshot=',1)[1].split('private _lastSignature',1)[0]
        self.assertIn('(_oldFeatureSnapshot select 1) != clientOwner',probe)
        self.assertIn('(_oldFeatureSnapshot select 0) isEqualTo',probe)
        self.assertIn('call CBE_fnc_ImprovedHelicopterLandingRestoreLocal',probe)
        self.assertNotIn('disableAI',probe)

    def test_scheduled_vector_and_anchor_writes_recheck_original_pilot_in_atomic_commit(self):
        approach=source('improvedHelicopterLandingExecuteLocal')
        commit=approach.split('// This controller is scheduled:',1)[1].split('uiSleep',1)[0]
        for marker in ('isNil {','!local _helicopter','currentPilot _helicopter != _entryPilot',
                       '!= _controlRevision','call CBE_fnc_FlightLeaseValid'):
            self.assertLess(commit.index(marker),commit.index('setVectorDirAndUp'))
        self.assertIn('_entryPilot action ["LandGear"',commit)
        anchor=source('improvedHelicopterLandingAnchorLocal')
        force=anchor.split('// Scheduled anchor mutation commit:',1)[1].split('if (diag_tickTime',1)[0]
        for marker in ('isNil {','currentPilot _helicopter != _entryPilot','call CBE_fnc_FlightLeaseValid','CBE_fnc_CortexExternalTakeover'):
            self.assertLess(force.index(marker),force.index('addForce'))
        self.assertEqual(anchor.count('private _entryPilot='),1)
        self.assertNotIn('_entryPilot = currentPilot',anchor)
