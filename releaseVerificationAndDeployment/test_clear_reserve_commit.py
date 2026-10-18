"""Exterior reserve native-write admission, not physical isolation acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
class ReserveCommitTests(unittest.TestCase):
    def test_current_building_actor_and_deadlines_guard_reserve_commits(self):
        text=source()
        helper=text.split('private _reserveCommitReady={',1)[1].split('// An uncommitted command anchor',1)[0]
        for proof in ('call _mayIssueMovement','call _reserveReady','CortexZeusHeld',
                      '_job get "deadline"','_job get "hardDeadline"'):
            self.assertIn(proof,helper)
        self.assertNotIn('doMove',helper)
        self.assertNotIn('doStop',helper)
        self.assertNotIn('serverTime+',helper)
    def test_proposal_cannot_replace_changed_hold_or_native_task(self):
        text=source()
        initial=text.split('private _reserveNativeBefore=',1)[1].split('private _postNative=',1)[0]
        self.assertLess(initial.index('isNil {'),initial.index('doStop _reserve'))
        self.assertLess(initial.index('isEqualTo _reserveNativeBefore'),initial.index('doStop _reserve'))
        leg=text.split('private _postNative=',1)[1].split('if (_valid) then {',1)[1].split('// Arrival proximity',1)[0]
        for proof in ('isNil {','call _reserveCommitReady','isEqualTo _postNative',
                      'isEqualTo _postReceipt','vectorDistance _postPose <= 1'):
            self.assertLess(leg.index(proof),leg.index('_reserve doMove _target'))
        self.assertLess(leg.index('_reserve doMove _target'),leg.index('call _rememberMove'))
    def test_arrival_and_watch_use_fresh_native_and_observed_eye_proof(self):
        text=source()
        arrival=text.split('// Arrival proximity',1)[1].split('// Revalidate one actual eye ray',1)[0]
        for proof in ('isNil {','call _reserveCommitReady','isEqualTo _arrivalNative','vectorDistance (AGLToASL (_stage select 0)) <= 2'):
            self.assertLess(arrival.index(proof),arrival.index('doStop _reserve'))
        view=text.split('private _viewConfirmed=false;',1)[1].split('// A deadline may retire',1)[0]
        self.assertLess(view.index('lineIntersectsSurfaces'),view.index('isNil {'))
        install=view.split('// Public arrival does not replay',1)[1]
        for proof in ('isNil {','call _reserveCommitReady','isEqualTo _viewNative','vectorDistance _viewEye <= 0.25'):
            self.assertLess(install.index(proof),install.index('_reserve doWatch _watch'))
    def test_staged_stop_must_still_occupy_its_recorded_post(self):
        gate=source().split('private _reserveReady={',1)[1].split('private _reserveCommitReady=',1)[0]
        self.assertIn('_command == "" || {[_candidate] call _ownsCurrentMove}',gate)
        self.assertIn('_stagedHere} && {_command == "STOP"}',gate)
        self.assertIn('vectorDistance (AGLToASL _post) <= 2',gate)
        self.assertIn('<= 0.75',gate)
        self.assertIn('!finite _x',gate)
        self.assertIn('"reserveAdmissionCommands"',gate)

    def test_expired_idle_approach_retires_only_exact_owned_target_as_failure(self):
        text=source()
        proof=text.split('private _reserveLegOwned={',1)[1].split('private _reserveCommitReady=',1)[0]
        for required in ('currentCommand _actor in ["","MOVE"]','"movementTargets"',
                         '"CBE_Cortex_ClearReserve"','_job get "generation"','CBE_AIPass_Epoch',
                         '!finite _x','_issued vectorDistance _target <= 0.25',
                         '_native vectorDistance _issued <= 0.25','_post vectorDistance _target <= 0.25'):
            self.assertIn(required,proof)
        timeout=text.split('// A deadline may retire only',1)[1].split('} forEach _stageReserves;',1)[0]
        self.assertEqual(timeout.count('call _reserveLegOwned'),2)
        self.assertLess(timeout.index('isNil {'),timeout.index('doStop _reserve'))
        self.assertIn('"REJECTED"',timeout)
        self.assertIn('"EXHAUSTED"',timeout)
        self.assertNotIn('"ARRIVED"',timeout)
        self.assertNotIn('doMove',timeout)
        self.assertNotIn('_stageSearchCounts set',timeout)

    def test_group_transfer_veto_and_late_journal_publication_are_guarded(self):
        text=source()
        gate=text.split('private _reserveReady={',1)[1].split('private _reserveLegOwned=',1)[0]
        self.assertIn('group _candidate == _group',gate)
        publish=text.split('private _stageBudget=[_building',1)[1].split('// Promotion cannot spend',1)[0]
        self.assertLess(publish.index('isNil {'),publish.index('setVariable ["CBE_Cortex_ClearStageBudget"'))
        self.assertLess(publish.index('call _mayIssueMovement'),publish.index('setVariable ["CBE_Cortex_ClearStageBudget"'))
        self.assertNotIn('private _budgetRows=',publish)
