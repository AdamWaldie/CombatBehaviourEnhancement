"""Clearance task replacement must commit against observed authority and actor admission."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
class ClearHandoffCommitTests(unittest.TestCase):
    def test_entry_task_identity_is_captured_before_geometry(self):
        text=source()
        for field in ('_admissionEpoch=','_admissionNativeReceipt=','_admissionOperationIdentity=',
                      '_admissionGarrison=','_admissionDefend='):
            self.assertLess(text.index(field),text.index('_building buildingPos -1'))

    def test_handoff_checks_before_releasing_or_publishing_without_wrapping_route_plan(self):
        text=source()
        commit=text.split('private _handoffFailure="HANDOFF_CHANGED";',1)[1].split('// Route preparation may yield.',1)[0]
        self.assertIn('isNil {',commit)
        release=commit.index('if (!_resume && {_previous isNotEqualTo []})')
        gate=commit[:release]
        for proof in ('local _group','_admissionEpoch','_admissionGeneration','_admissionOperationIdentity',
                      '_admissionGarrison','_admissionDefend','_liveClear','_admissionNativeReceipt',
                      'CBE_AIPass_Active','_deadline min _hardDeadline','CBE_fnc_CortexIsEligible',
                      'call _resumeCurrent','call _admissionStable','_readyCount < _minimumActors',
                      '_team findIf {!([_x] call _actorAdmissible)}'):
            self.assertIn(proof,gate)
        for write in ('CortexReleaseGroup','CortexGarrisonRelease','CortexDefendRelease',
                      'setVariable ["CBE_AIPass_ClearOrder"','call CBE_fnc_OperationStart'):
            self.assertGreater(commit.index(write),release)
        self.assertIn('(_liveClear isEqualTo []) isNotEqualTo (_previous isEqualTo [])',gate)
        self.assertNotIn('buildingPos',commit)
        self.assertNotIn('while',commit)
        self.assertIn('if (!_handoffAccepted) exitWith',commit)
        self.assertGreater(text.index('while {_remaining isNotEqualTo []}'),text.index('// Route preparation may yield.'))

    def test_actor_checks_are_shared_and_resume_retirement_is_atomic(self):
        text=source()
        actor=text.split('private _actorAdmissible={',1)[1].split('private _available =',1)[0]
        for proof in ('local _actor','group _actor == _group','CortexActorMoveReserved',
                      'currentCommand _actor','remoteControlled','CompatibilityExternalControl'):
            self.assertIn(proof,actor)
        self.assertIn('select {[_x] call _actorAdmissible}',text)
        retirement=text.split('private _retireResume={',1)[1].split('if (_resumeRequested && {!(call _resumeCurrent)})',1)[0]
        for proof in ('isNil {','call _resumeCurrent','_admissionEpoch','[_group,_restore] call CBE_fnc_CortexClearRelease'):
            self.assertIn(proof,retirement)
        self.assertIn('if (serverTime >= (_deadline min _hardDeadline)) exitWith {[] call _retireResume; false}',text)
