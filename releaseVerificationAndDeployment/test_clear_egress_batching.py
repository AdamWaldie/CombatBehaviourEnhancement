"""Bounded egress planning must preserve physical completion and migration semantics."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class ClearEgressBatchingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.step = (ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        cls.start = (ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()

    def test_transition_does_not_search_or_command_pending_workers(self):
        transition = self.step.split('// Defer expensive exterior planning;',1)[1].split('\n    };\n    if (serverTime >',1)[0]
        for forbidden in ('call _chooseExteriorExit', ' doMove ', 'getPosATL _unit;'):
            self.assertNotIn(forbidden, transition)
        self.assertIn('_pending pushBack [_unit,+(_moves getOrDefault', transition)
        self.assertIn('"egressDeadlineServer",serverTime+45', transition)

    def test_one_allocation_still_services_existing_travel_and_pending_blocks_success(self):
        block = self.step.split('// End exterior planner;',1)[1].split('    private _positions = _job get',1)[0]
        self.assertEqual(block.count('call _chooseExteriorExit'),1)
        self.assertEqual(block.count('_pending deleteAt _readyIndex'),1)
        self.assertIn('time < (_job get "egressDeadline")',block)
        self.assertIn('private _arrived=_pending isEqualTo [] &&',block)
        self.assertIn('if (_pending isNotEqualTo []) then {_job set ["egressFailed",true]}',block)
        self.assertIn('forEach _assignments',block)
        self.assertNotIn('serverTime+45',block)
        dispatch=block.split('private _target=',1)[1].split('private _assignments=',1)[0]
        self.assertLess(dispatch.index('call _exitMovementOwned'),dispatch.index('_unit doMove'))
        self.assertNotIn('_target=getPosATL',dispatch)

    def test_pending_adoption_is_typed_unique_and_cannot_renew_or_issue_movement(self):
        replay=self.start.split('// Adopt a transform/episode-bound exit journal',1)[1].split('// Keep reserve search consumption',1)[0]
        for marker in ('count _egressJournal in [10,13]', 'in [2,3]',
                       'count (_egressJournal select 11)+count (_egressJournal select 3) <= 8',
                       '(_x select 0) isEqualType objNull','count (_x select 1) in [0,3]',
                       '_assignments+_pending','_live vectorDistance _leg <= 0.25',
                       '"egressPending",_pending','"egressExitUses",_uses',
                       '((_egressJournal select 7)-serverTime) max 0'):
            self.assertIn(marker,replay)
        for forbidden in (' doMove ', 'doStop', 'doFollow','serverTime+45'):
            self.assertNotIn(forbidden,replay)

    def test_allocation_retries_are_finite_due_and_replayed_without_budget_reset(self):
        block=self.step.split('// End exterior planner;',1)[1].split('private _assignments=',1)[0]
        self.assertIn('_pending findIf {serverTime >= (_x param [3,0,[0]])}',block)
        retry=block.split('// A temporary occupied/blocked proposal',1)[1]
        for guard in ('_target isEqualTo []','_planAttempts < 2',
                      'serverTime+2 < (_job get "egressDeadlineServer")',
                      'call _actorAvailable','call _exitMovementOwned','call _mayIssueMovement'):
            self.assertIn(guard,retry)
        self.assertIn('_pending pushBack [_unit,+_leg,_planAttempts+1,serverTime+2]',retry)
        self.assertNotIn(' doMove ',retry)
        self.assertNotIn('set ["egressDeadline',retry)
        self.assertIn('false,[],2*_planAttempts] call _chooseExteriorExit',block)
        replay=self.start.split('// Version 2 appends pending',1)[1].split('if (_assignments isEqualTo',1)[0]
        for guard in ('private _pendingSize=[2,4]','(_x select 2) in [0,1,2]',
                      'finite (_x select 3)','(_x select 3) <= (_egressJournal select 7)',
                      '_pending pushBack [_actor,+_leg,_planAttempts,_nextPlanAt]'):
            self.assertIn(guard,replay)
        self.assertNotIn('serverTime+2',replay)

    def test_journal_and_observer_retain_incremental_assignments(self):
        journal=self.step.split('// Publish only material egress changes.',1)[1]
        self.assertIn('"egressPending",[]',journal)
        self.assertIn('"egressExitUses",createHashMap',journal)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        observation=qa.split('private _exit=_group getVariable ["CBE_Cortex_ClearEgress",[]];',1)[1].split('forEach _egressAssignments;',1)[0]
        self.assertIn('count _exit in [4,10,13]',observation)
        self.assertIn('_egressAssignments findIf',observation)
        self.assertIn('_egressAssignments pushBack +_x',observation)
        self.assertNotIn('!_egressSeen',observation)

    def test_hc_fixture_requires_pending_roster_and_actual_exit_for_every_worker(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=qa.split('// Separate headless-batch acceptance:',1)[1].split('if (local _group) then {[_group] call CBE_fnc_CortexClearRelease}',1)[0]
        for marker in ('HC-CLEAR-EGRESS-pending-observed','private _pendingBefore=+',
                       'count _expectedActors == count _members',
                       'count _currentActors != count _expectedActors',
                       'forEach _pendingBefore','isNotEqualTo _leg',
                       '_targets pushBack [_actor,+(_x select 1),_x select 4]',
                       'count _targets == count _expectedActors',
                       '[_actor,_house,_target] call _observedExit'):
            self.assertIn(marker,case)
        observe=case.split('private _terminal=[{',1)[1].split('HC-CLEAR-EGRESS-journal-preserved',1)[0]
        for forbidden in (' doMove ', 'doStop','setPos','setVelocity','enableSimulation'):
            self.assertNotIn(forbidden,observe)
