"""Casualty role-transaction contracts, not physical cover or HC acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
class PromotionCommitTests(unittest.TestCase):
    def test_role_commit_rechecks_candidate_casualty_slot_and_actual_operation(self):
        text=source()
        commit=text.split('private _promoted=false;',1)[1].split('if (!_promoted) then {continue}',1)[0]
        self.assertLess(commit.index('isNil {'),commit.index('_reserves deleteAt'))
        for proof in ('call _mayIssueMovement','call _promotionProofCurrent',
                      '(_reserves param [_replacementIndex,objNull]) == _replacement',
                      'param [_slot,objNull]) == _member','!([_member] call _actorAvailable)',
                      '_promotionOperation getOrDefault ["generation"',
                      '_promotionOperation getOrDefault ["intent"',
                      '_promotionOperation getOrDefault ["ownerEpoch"'):
            for change in ('_reserves deleteAt','_pair set [_slot','doWatch objNull'):
                self.assertLess(commit.index(proof),commit.index(change))
        self.assertNotIn('doStop _replacement',commit)
        self.assertNotIn('doMove',commit)
        self.assertNotIn('recoveryAttempts',commit)
        self.assertNotIn('_job set ["hardDeadline"',commit)
    def test_final_cover_proof_uses_same_current_observer_without_second_ray(self):
        text=source()
        proof=text.split('private _promotionProofCurrent={',1)[1].split('private _pairRosterChanged=',1)[0]
        for check in ('serverTime-(_proof get "at") > 1','call _reserveCommitReady',
                      'isNotEqualTo (_proof get "stage")','isNotEqualTo (_proof get "receipt")',
                      'vectorDistance (_proof get "pose") > 1','_observer in _reserves',
                      'isEqualTo _source','isEqualTo _observerNative','isEqualTo _lease',
                      'vectorDistance _eye <= 0.25','<= 0.75','<= 75'):
            self.assertIn(check,proof)
        for forbidden in ('lineIntersectsSurfaces','terrainIntersectASL','doWatch','doMove','setVariable'):
            self.assertNotIn(forbidden,proof)
        pool=text.split('private _promotionViewBudget=1;',1)[1].split('private _pairRosterChanged=',1)[0]
        self.assertEqual(pool.count('lineIntersectsSurfaces'),1)
        self.assertIn('private _promotionProofs=createHashMap',pool)
    def test_roster_and_stage_publication_follow_successful_role_change(self):
        text=source()
        commit=text.split('private _promoted=false;',1)[1].split('if (!_promoted) then {continue}',1)[0]
        self.assertLess(commit.index('_liveOperation set ["pairs"'),commit.index('setVariable ["CBE_Operation"'))
        self.assertIn('(_job get "assigned") set [_team find _replacement,[]]',commit)
        self.assertIn('_reserveStages deleteAt (netId _replacement)',commit)
        self.assertIn('_stageJournalChanged=true',commit)
        self.assertLess(text.index('if (_pairRosterChanged) then'),text.index('private _budgetRows='))
        pairs=text.split('if (_pairRosterChanged) then {',1)[1].split('// Build the migration journal',1)[0]
        self.assertLess(pairs.index('isNil {'),pairs.index('call CBE_fnc_CombatPairsPublish'))
        self.assertLess(pairs.index('call _mayIssueMovement'),pairs.index('call CBE_fnc_CombatPairsPublish'))

        publisher=(ROOT/'addons/infantry/functions/combatPairsPublish.sqf').read_text()
        self.assertLess(publisher.index('isNil {'),publisher.index('setVariable ["CBE_CombatPairs"'))
        self.assertLess(publisher.index('if (!local _group)'),publisher.index('setVariable ["CBE_CombatPairs"'))
