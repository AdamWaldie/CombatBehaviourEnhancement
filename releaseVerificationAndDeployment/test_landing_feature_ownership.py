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
                       'private _matchingLease=count _lease > 0'):
            self.assertIn(marker,before)
        self.assertLess(restore.index('isEqualTo _snapshot'),restore.index('setVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease"'))
        self.assertIn('checkAIFeature "PATH") isEqualTo (_snapshot select 5)',source('improvedHelicopterLandingFeatureReleaseLocal'))
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

    def test_aircraft_feature_release_is_finite_exact_and_never_replays_flight(self):
        helper=source('improvedHelicopterLandingFeatureReleaseLocal')
        for marker in ('_attempt > 60','_attempt >= 60','serverTime >= _until',
                       'isEqualTo _release','isEqualTo _snapshot','== (_snapshot select 0)+1',
                       'FeatureReleaseWork','clientOwner,_epoch','count _lease == 0','_controllerFree'):
            self.assertIn(marker,helper)
        self.assertLess(helper.index('isNil {'),helper.index('enableAI "MOVE"'))
        executable=helper.split('params [[',1)[1]
        for forbidden in ('setVelocity','flyInHeight','setVector','addForce',' land ',
                          'doMove','setWaypoint','nearEntities','addPerFrameHandler'):
            self.assertNotIn(forbidden,executable)
        self.assertEqual(helper.count('call CBA_fnc_waitAndExecute'),1)
        self.assertNotIn('serverTime+60',helper)
        expired=helper.split('private _unresolved={',1)[1].split('// A receipt/worker marker',1)[0]
        self.assertIn('"UNRESOLVED"',expired)
        self.assertNotIn('FeatureSnapshot",nil',expired)
        self.assertLess(helper.index('if (serverTime >= _until'),helper.index('if (_attempt == 0'))
    def test_control_retirement_publishes_one_deadline_before_release_only_service(self):
        restore=source('improvedHelicopterLandingRestoreLocal')
        self.assertEqual(restore.count('serverTime+60'),1)
        self.assertIn('_pendingRelease=[+_snapshot,serverTime+60]',restore)
        self.assertIn('["PENDING",_snapshot select 0,_snapshot select 1,_pendingRelease select 1,serverTime]',restore)
        self.assertNotIn('FeatureSnapshot",nil',restore)
        marker=restore.index('private _featuresRestored=')
        self.assertLess(restore.index('setVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",'),marker)
        self.assertLess(restore.index('if (!_featuresRestored) exitWith {true}'),restore.index('// Actor release can defer'))
        self.assertIn('!([_pilot] call CBE_fnc_CortexActorFireTaskAvailable)',restore)
    def test_pending_aircraft_release_can_resume_on_locality_and_existing_tracker(self):
        for name in ('improvedHelicopterLandingInit','improvedHelicopterLandingStep'):
            text=source(name)
            self.assertIn('CBE_ImprovedHelicopterLanding_FeatureRelease',text)
            self.assertIn('call CBE_fnc_ImprovedHelicopterLandingFeatureReleaseLocal',text)
        config=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class ImprovedHelicopterLandingFeatureReleaseLocal',config)
