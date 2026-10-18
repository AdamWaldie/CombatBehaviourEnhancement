"""CQB room-mutation authority contracts. Native navigation is not simulated."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
class RoomCommitTests(unittest.TestCase):
    def test_mutations_and_assignment_follow_final_actor_and_episode_proof(self):
        body=source().split('// Native mutation commit: geometry above stays scheduled.',1)[1].split('} forEach _pair;',1)[0]
        self.assertLess(body.index('isNil {'),body.index('doStop _unit'))
        for guard in ('call _mayIssueMovement','call _actorAvailable','call _actorTaskFree',
                      'call _roomCommandOwned','CortexZeusHeld','_job get "deadline"',
                      '_job get "hardDeadline"','isEqualTo (_roomSnapshot select 1)',
                      'vectorDistance (_roomSnapshot select 2) <= 1'):
            for mutation in ('doStop _unit','_unit forceSpeed','_unit doMove','_assigned set'):
                self.assertLess(body.index(guard),body.index(mutation))
        self.assertNotIn('call _roomSegmentClear',body)
        self.assertIn('vectorDistance _arrivalPose <= 0.25',body)
        self.assertIn('_roomMoverCommitted=true',body)
        self.assertIn('if (_roomRequestChanged && {_roomMoverCommitted})',source())
    def test_replacement_tasks_require_real_owned_hold_or_original_admission(self):
        owned=source().split('private _roomCommandOwned={',1)[1].split('// Native task ownership also applies',1)[0]
        for requirement in ('call _ownsCurrentMove','_command == "STOP"','"roomHolds"',
                            '"formationFallbackHolds"','vectorDistance (AGLToASL _x) <= 1.5',
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
                            '_job get "hardDeadline"','isEqualTo _retryNative'):
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
