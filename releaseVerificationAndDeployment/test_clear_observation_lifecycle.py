"""CQB observation lease boundaries; these checks do not prove physical watching."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
INFANTRY = ROOT / "addons/infantry/functions"


class ClearObservationLifecycle(unittest.TestCase):
    def test_explicit_release_fences_commands_and_metadata_separately(self):
        text = (INFANTRY / "cortexClearRelease.sqf").read_text(encoding="utf-8")
        command = text.split('private _exitWatch=', 1)[1].split('if (_releaseOwnedSettings && {unitPos', 1)[0]
        for guard in ('_releaseOwnedSettings', '_taskFree', 'currentCommand _x in ["","STOP"]',
                      'CBE_AIPass_ClearGeneration', 'CBE_AIPass_Epoch',
                      'CBE_Cortex_ClearExitWatchLocal', 'isEqualTo _exitWatch'):
            self.assertIn(guard, command)
        self.assertIn('_x doWatch objNull', command)
        retirement = text.split('private _retiredWatch=', 1)[1].split('CBE_Cortex_ClearReserve', 1)[0]
        self.assertIn('CBE_AIPass_ClearGeneration', retirement)
        self.assertIn('CBE_AIPass_Epoch', retirement)
        self.assertIn('isEqualTo _retiredWatch', retirement)
        for forbidden in ('doMove', 'doFollow', 'doWatch', 'setDestination'):
            self.assertNotIn(forbidden, retirement)

    def test_terminal_retirement_preserves_successor_and_does_not_issue_orders(self):
        text = (INFANTRY / "buildingOperationStep.sqf").read_text(encoding="utf-8")
        retirement = text.split('private _retiredWatch=', 1)[1].split('CBE_Cortex_ClearReserve', 1)[0]
        self.assertIn('(_retiredWatch select 0) == (_job get "generation")', retirement)
        self.assertIn('(_retiredWatch select 1) == (_brain get "ownerEpoch")', retirement)
        self.assertIn('isEqualTo _retiredWatch', retirement)
        for forbidden in ('doMove', 'doFollow', 'doWatch', 'setDestination'):
            self.assertNotIn(forbidden, retirement)

    def test_casualty_promotion_checks_current_authority_before_retiring_watch(self):
        text = (INFANTRY / "buildingOperationStep.sqf").read_text(encoding="utf-8")
        promotion = text.split('private _exitWatch=_replacement', 1)[1].split('_pair set [_slot', 1)[0]
        for guard in ('(_job get "generation")', 'CBE_AIPass_Epoch',
                      'call _actorTaskFree', 'call _mayIssueMovement'):
            self.assertLess(promotion.index(guard), promotion.index('doWatch objNull'))
        self.assertIn('CBE_Cortex_ClearExitWatchLocal', promotion)


    def test_reserve_watch_requires_current_actual_eye_ray_with_existing_budget(self):
        text=(INFANTRY / "buildingOperationStep.sqf").read_text(encoding="utf-8")
        watch=text.split('private _viewWatch=_stage param',1)[1].split('// A deadline may retire',1)[0]
        self.assertIn('private _viewConfirmed=false;', watch)
        self.assertLess(watch.index('eyePos _reserve'),watch.index('_viewConfirmed=_viewValid;'))
        self.assertLess(watch.index('terrainIntersectASL'),watch.index('_viewConfirmed=_viewValid;'))
        self.assertLess(watch.index('lineIntersectsSurfaces'),watch.index('_viewConfirmed=_viewValid;'))
        install=watch.split('private _watchLease=',1)[1]
        self.assertLess(install.index('&& {_viewConfirmed}'),install.index('_reserve doWatch _watch'))
        self.assertIn('_key == _stageViewKey',watch)
        self.assertIn('_stageViewBudget=_stageViewBudget-1',watch)
        self.assertIn('if (_blockedSince != (_viewCheck select 1)) then {_stageJournalChanged=true}',watch)
        proposal=text.split('if (_valid) then {',1)[1].split('// Native acknowledgement may arrive',1)[0]
        self.assertLess(proposal.index('_reserve doMove _target'),proposal.index('_stageViewChecks deleteAt _key'))
        journal=(INFANTRY/'buildingStageJournal.sqf').read_text(encoding='utf-8')
        self.assertIn('private _stageBudget=[_job] call CBE_fnc_BuildingStageJournal',text)
        self.assertIn('(_savedStage select 2) == "ARRIVED"',journal)
        self.assertIn('_viewReceipt=[+(_savedStage select 0),+(_savedStage select 4)',journal)
        for forbidden in ('setVariable','_job set','doMove','doStop','doWatch','serverTime+'):
            self.assertNotIn(forbidden,journal)
        for bound in ('count _x > 64','count _tried > 6','count _history > 3',
                      '_count > 3','_count != floor _count','_maps findIf',
                      '!(count _savedStage in [0,4,7])','!(count _savedView in [0,2])'):
            self.assertIn(bound,journal)
        for copy in ('_tried apply {+_x}','_history apply {+_x}',
                     '_stage set [0,+(_stage select 0)]','forEach [4,5]',
                     '_transform apply {+_x}','(_context select 1) apply {+_x}'):
            self.assertIn(copy,journal)
        self.assertIn('_stageViewChecks',text)
        attach=text.index('_job set ["reserveStages",_reserveStages]')
        self.assertLess(attach,text.index('_stageSearchCounts set [_key,(_searchCount+1) min 3]'))
        self.assertEqual(text.count('_job set ["reserveStages",_reserveStages]'),1)
        import copy
        source_row={'targets':[[1,2,3]],'stage':[[4,5,6],True,'ARRIVED',60,[7,8,9],[10,11,12],True],
                    'view':[30,20], 'count':3}
        before=copy.deepcopy(source_row)
        exported=copy.deepcopy(source_row)
        exported['targets'][0][0]=99
        exported['stage'][0][0]=99
        exported['stage'][4][0]=99
        self.assertEqual(source_row,before)
        self.assertEqual(exported['view'],[30,20])
        self.assertEqual(exported['count'],3)
        admission=(INFANTRY/'cortexClearBuilding.sqf').read_text(encoding='utf-8')
        resume=admission.split('private _stageBudget=',1)[1].split('// Resume restores native-work bookkeeping',1)[0]
        for guard in ('(_viewReceipt select 0) isEqualTo (_stage select 0)',
                      '(_viewReceipt select 1) isEqualTo (_stage select 4)',
                      '(_viewReceipt select 3) <= serverTime',
                      '(_viewReceipt select 2) <= _hardDeadline+2',
                      '"reserveStageViewChecks",_stageViews'):
            self.assertIn(guard,resume)
        adopted=resume.split('if (_postCommitted) then {',1)[1]
        self.assertIn('_stageViews set [_key,[_viewReceipt select 2,_viewReceipt select 3]]',adopted)
        self.assertNotIn('serverTime+',adopted)

        self.assertEqual(watch.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('setVariable ["_viewConfirmed"',watch)


    def test_terminal_watch_clear_requires_the_actual_owned_exit_watch(self):
        text=(INFANTRY / "buildingOperationStep.sqf").read_text(encoding="utf-8")
        clear=text.split('private _exitWatch=_x getVariable',1)[1].split('if (_reason == "COMPLETE")',1)[0]
        for guard in ('count _exitWatch == 3',
                      '(_exitWatch select 0) == (_job get "generation")',
                      '(_exitWatch select 1) == (_brain get "ownerEpoch")',
                      'CBE_Cortex_ClearExitWatchLocal', 'isEqualTo _exitWatch'):
            self.assertLess(clear.index(guard),clear.index('_x doWatch objNull'))
        self.assertEqual(clear.count('doWatch objNull'),1)


if __name__ == "__main__":
    unittest.main()
