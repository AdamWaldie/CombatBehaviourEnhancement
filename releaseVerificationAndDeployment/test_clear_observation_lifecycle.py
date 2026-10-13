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
                      'WAIT_AIPass_ClearGeneration', 'WAIT_AIPass_Epoch',
                      'WAIT_Cortex_ClearExitWatchLocal', 'isEqualTo _exitWatch'):
            self.assertIn(guard, command)
        self.assertIn('_x doWatch objNull', command)
        retirement = text.split('private _retiredWatch=', 1)[1].split('WAIT_Cortex_ClearReserve', 1)[0]
        self.assertIn('WAIT_AIPass_ClearGeneration', retirement)
        self.assertIn('WAIT_AIPass_Epoch', retirement)
        self.assertIn('isEqualTo _retiredWatch', retirement)
        for forbidden in ('doMove', 'doFollow', 'doWatch', 'setDestination'):
            self.assertNotIn(forbidden, retirement)

    def test_terminal_retirement_preserves_successor_and_does_not_issue_orders(self):
        text = (INFANTRY / "buildingOperationStep.sqf").read_text(encoding="utf-8")
        retirement = text.split('private _retiredWatch=', 1)[1].split('WAIT_Cortex_ClearReserve', 1)[0]
        self.assertIn('(_retiredWatch select 0) == (_job get "generation")', retirement)
        self.assertIn('(_retiredWatch select 1) == (_brain get "ownerEpoch")', retirement)
        self.assertIn('isEqualTo _retiredWatch', retirement)
        for forbidden in ('doMove', 'doFollow', 'doWatch', 'setDestination'):
            self.assertNotIn(forbidden, retirement)

    def test_casualty_promotion_checks_current_authority_before_retiring_watch(self):
        text = (INFANTRY / "buildingOperationStep.sqf").read_text(encoding="utf-8")
        promotion = text.split('private _exitWatch=_replacement', 1)[1].split('_pair set [_slot', 1)[0]
        for guard in ('(_job get "generation")', 'WAIT_AIPass_Epoch',
                      'call _actorTaskFree', 'call _mayIssueMovement'):
            self.assertLess(promotion.index(guard), promotion.index('doWatch objNull'))
        self.assertIn('WAIT_Cortex_ClearExitWatchLocal', promotion)


if __name__ == "__main__":
    unittest.main()
