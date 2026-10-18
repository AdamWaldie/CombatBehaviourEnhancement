"""Exterior-role roster contracts; neither posts nor path arrival are simulated."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearReserveRosterTests(unittest.TestCase):
    def test_ready_roster_has_no_anchor_exception_or_last_resort_gate(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        roster=text.split('private _reserves=',1)[1].split('// Rotate the bounded service window',1)[0]
        self.assertEqual(roster.strip(),'(units _group) select {[_x] call _reserveReady};')
        staging=text.split('private _reserved=[];',1)[1].split('private _reserveReady=',1)[0]
        self.assertNotIn('CortexGroupAnchor',staging)
        gate=text.split('private _reserveReady={',1)[1].split('// An uncommitted command anchor',1)[0]
        for proof in ('!(_candidate in _reserved)','!(_candidate in _rotatedOut)',
                      '!(_candidate in _unavailable)','!isPlayer _candidate','local _candidate',
                      '"reserveAdmissionCommands"','_stageCommandFree','call CBE_fnc_CortexActorMoveReserved'):
            self.assertIn(proof,gate)
    def test_role_allocation_keeps_existing_fairness_and_promotion_coverage_limits(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('_stageReserves=_stageReserves select [0,8]',text)
        self.assertIn('private _stageSearchBudget=1',text)
        self.assertIn('(_cursor+8) mod count _stageReserves',text)
        promotion=text.split('private _mayPromoteReserve={',1)[1].split('// Replace unavailable',1)[0]
        self.assertIn('call _reserveReady',promotion)
        self.assertIn('"ARRIVED"',promotion)
        self.assertIn('_promotionViewBudget',promotion)
        self.assertIn('_covered',promotion)

    def test_retired_worker_hold_window_rotates_without_weakening_authority(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        hold=text.split('private _quarantineHeld=',1)[1].split('private _reserveReady=',1)[0]
        for marker in ('"quarantineCursor",0','(_cursor+16) mod count _quarantineActors',
                       '_quarantineActors=_quarantineActors select [0,16]',
                       'forEach _quarantineActors','!(_x in _quarantineHeld)',
                       '[_x] call _actorAvailable','[_x] call _actorTaskFree','call _mayIssueMovement'):
            self.assertIn(marker,hold)
        self.assertNotIn('forEach (_rotatedOut select [0,16])',hold)
        # Model only the finite service schedule; this does not simulate native holds.
        for size in (0,1,16,17,24,33,64):
            roster=list(range(size))
            cursor=0
            seen=set()
            for _ in range(max(1,(size+15)//16)):
                window=(roster[cursor:]+roster[:cursor])[:16]
                self.assertLessEqual(len(window),16)
                seen.update(window)
                if size>16:
                    cursor=(cursor+16)%size
            self.assertEqual(seen,set(roster))
