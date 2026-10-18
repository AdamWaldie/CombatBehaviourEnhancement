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
