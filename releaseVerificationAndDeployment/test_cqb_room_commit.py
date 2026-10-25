"""CQB room-mutation authority contracts. Native navigation is not simulated."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
class RoomCommitTests(unittest.TestCase):
    def test_mutations_and_assignment_follow_final_actor_and_episode_proof(self):
        body=source().split('// Native mutation commit:',1)[1].split('} forEach _pair;',1)[0]
        for proof in ('private _buddyTargetChanged=_unit != _point','count _arrivalTarget == 3',
                      '_buddyCommitted vectorDistance _arrivalTarget > 0.25','_issue || {[_unit] call _evasionReturnOwned} || {_buddyTargetChanged}'):
            self.assertIn(proof,body)
        buddy=body.split('private _buddyCommitted=',1)[1].split('if (_unitIssue',1)[0]
        self.assertNotIn('lastProgress',buddy)
        self.assertNotIn('deadline',buddy)
        self.assertLess(body.index('isNil {'),body.index('doStop _unit'))
        for guard in ('call _mayIssueMovement','call _actorAvailable','call _actorTaskFree',
                      'call _roomCommandOwned','CortexZeusHeld','_job get "deadline"',
                      '_job get "hardDeadline"','isEqualTo (_roomSnapshot select 1)',
                      'vectorDistance (_roomSnapshot select 2) <= 1'):
            for mutation in ('doStop _unit','call CBE_fnc_CortexClearSettingsApply','_unit doMove','_assigned set'):
                self.assertLess(body.index(guard),body.index(mutation))
        self.assertNotIn('call _roomSegmentClear',body)
        self.assertIn('vectorDistance _arrivalPose <= 0.25',body)
        self.assertIn('_roomMoverCommitted=true',body)
        self.assertIn('if (_roomRequestChanged && {_roomMoverCommitted})',source())
    def test_replacement_tasks_require_real_owned_hold_or_original_admission(self):
        owned=source().split('private _roomCommandOwned={',1)[1].split('// Native task ownership also applies',1)[0]
        helper=(ROOT/'addons/infantry/functions/buildingActorHoldOwned.sqf').read_text()
        for proof in ('currentCommand _actor != "STOP"','"roomHolds"','"formationFallbackHolds"',
                      'vectorDistance (ATLToASL _x) <= 1.5','<= 0.75'):
            self.assertIn(proof,helper)
        for requirement in ('call _ownsCurrentMove','call CBE_fnc_BuildingActorHoldOwned',
                            'if (_ownedHold) exitWith {true}',
                            'if (_actor in (_job get "started")) exitWith {false}',
                            '"reserveAdmissionCommands"','formLeader _actor == (_admitted select 3)',
                            '_native isEqualTo (_admitted select 2)'):
            self.assertIn(requirement,owned)
        self.assertNotIn('doMove',owned)
        self.assertNotIn('doStop',owned)
        self.assertNotIn('setVariable',owned)
    def test_retry_credit_requires_actual_room_mover_issue(self):
        body=source().split('private _retriedMover=false;',1)[1].split('// An interior access leg',1)[0]
        self.assertLess(body.index('isNil {'),body.index('_x doMove _unitTarget'))
        for requirement in ('call _mayIssueMovement','call _actorAvailable','call _actorTaskFree',
                            'call _roomCommandOwned','CortexZeusHeld','_job get "deadline"',
                            '_job get "hardDeadline"','isEqualTo _retryNative',
                            '!([_x,_unitTarget] call _nativeMoveAwaited)'):
            self.assertLess(body.index(requirement),body.index('_x doMove _unitTarget'))
        self.assertLess(body.index('_x doMove _unitTarget'),body.index('if (_x == _point) then {_retriedMover=true}'))
        self.assertLess(body.index('if (_retriedMover) then'),body.index('_retries=_retries+1'))
        self.assertNotIn('serverTime+',body)

    def test_all_building_retries_use_atomic_building_admission_and_record_only_issue(self):
        text=source()
        wrapper=text.split('private _recoverClearActor={',1)[1].split('// Before exterior actors commit',1)[0]
        self.assertLess(wrapper.index('isNil {'),wrapper.index('call CBE_fnc_RecoveryStep'))
        for proof in ('call _mayIssueMovement','call _actorAvailable','call _actorTaskFree',
                      'call _roomCommandOwned','CortexZeusHeld','_job get "deadline"','_job get "hardDeadline"'):
            self.assertLess(wrapper.index(proof),wrapper.index('call CBE_fnc_RecoveryStep'))
        self.assertLess(wrapper.index('_result == "RECOVERING"'),wrapper.index('call _rememberMove'))
        self.assertEqual(text.count('call CBE_fnc_RecoveryStep'),1)
        self.assertEqual(text.count('call _recoverClearActor'),4)
        self.assertNotIn('serverTime+',wrapper)
        self.assertNotIn('doMove',wrapper)
    def test_common_recovery_honours_zeus_before_budget_and_native_issue(self):
        text=(ROOT/'addons/infantry/functions/recoveryStep.sqf').read_text(encoding='utf-8')
        self.assertEqual(text.count('call CBE_fnc_CortexZeusHeld'),2)
        final=text.split('isNil {',1)[1]
        self.assertLess(final.index('CortexZeusHeld'),final.index('_used set [_key,_attempts+1]'))
        self.assertLess(final.index('CortexZeusHeld'),final.index('_actor doMove _destination'))


class IndependentBuddyAdmissionTests(unittest.TestCase):
    def test_first_buddy_request_is_independent_without_replaying_started_actors(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        block=text.split('private _unitIssue=',1)[1].split('// A buddy yielding space',1)[0]
        self.assertIn('_unit != _point',block)
        self.assertIn('!(_unit in (_job get "started"))',block)
        self.assertIn('!(_unit in (_job getOrDefault ["enteredActors",[]]))',block)
        self.assertIn('if (_unitIssue && {_settingsReady} && {call _mayIssueMovement}',block)
        self.assertIn('if (!_unitIssue && {!_awaitingNative} && {currentCommand _unit == ""}',block)
        self.assertIn('if (!_sameActiveTarget',block)
        self.assertNotIn('_lastProgress=_now',block)


class EntryTimingEvidenceTests(unittest.TestCase):
    def test_native_request_observation_never_substitutes_for_physical_entry(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        observed=text.split('private _entryTimingJob=',1)[1].split('private _seen=_memberVisits',1)[0]
        for proof in ('currentCommand _worker == "MOVE"','_nativeEntry vectorDistance _issuedEntry <= 0.25',
                      '_rooms findIf {_nativeEntry vectorDistance _x <= 0.25}',
                      'isEqualTo []','_admissionJob getOrDefault ["generation"','CBE CLEAR FIRST NATIVE ENTRY REQUEST'):
            self.assertIn(proof,observed)
        for forbidden in ('doMove','setPos','_memberFirstVisit set','_visits set','call _check'):
            self.assertNotIn(forbidden,observed)
        physical=text.split('private _seen=_memberVisits',1)[1].split('} forEach _clearingMembers;',1)[0]
        self.assertLess(physical.index('call _observedRoomVisit'),physical.index('_memberFirstVisit set'))


class NativeRequestGraceTests(unittest.TestCase):
    def test_idle_fallback_waits_for_exact_recent_issued_target(self):
        text=source()
        remember=text.split('private _rememberMove={',1)[1].split('private _ownsCurrentMove=',1)[0]
        self.assertIn('_requestTimes set [netId _actor,[+_target,serverTime]]',remember)
        self.assertNotIn('lastProgress',remember)
        self.assertNotIn('deadline',remember)
        fallback=text.split('private _request=(_job getOrDefault ["movementRequestTimes"',1)[1].split('// Native formation must not reclaim',1)[0]
        for proof in ('(_request select 0) isEqualTo _issued','serverTime >= (_request select 1)',
                      'serverTime-(_request select 1) < 2','!_awaitingNative'):
            self.assertLess(fallback.index(proof),fallback.index('doStop _unit'))
        self.assertNotIn('doMove',fallback)


class BuildingTailAuthorityTests(unittest.TestCase):
    def test_phase_and_egress_journal_cannot_revive_cancelled_operation(self):
        text=source()
        tail=text.split('// Complete private callback signalling',1)[1]
        guard=tail.split('if (!_tailOwned',1)[0]
        for proof in ('isNil {','CBE_BuildingBrain','isEqualTo _job','cancelled',
                      'CBE_AIPass_ClearGeneration','ownerEpoch','!= "CANCELLED"'):
            self.assertIn(proof,guard)
        refusal=tail.index('if (!_tailOwned')
        for write in ('_currentOperation set ["phase"','setVariable ["CBE_Cortex_ClearEgress",_journal',
                      'setVariable ["CBE_BuildingBrain_State"','_brain set ["nextAt"'):
            self.assertLess(refusal,tail.index(write))
        self.assertIn('_delay < 0 && {count _currentOperation == 0}',tail)
        self.assertNotIn('doMove',tail)
        self.assertNotIn('lineIntersects',tail)
