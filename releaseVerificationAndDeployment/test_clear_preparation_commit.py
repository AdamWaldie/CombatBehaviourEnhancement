"""Clearance preparation must not publish through superseded operation authority."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

def clear():return (ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')

class ClearPreparationCommitTests(unittest.TestCase):
    def test_each_commit_rechecks_original_authority_without_wrapping_route_plan(self):
        text=clear()
        gate=text.split('private _commitPreparation={',1)[1].split('// A valid new operation',1)[0]
        for proof in ('isNil {','local _group','CBE_AIPass_ClearGeneration','_preparationEpoch',
                      'CBE_AIPass_Epoch','_operationGeneration','"ownerEpoch"','"CLEAR"','"objective"',
                      'CBE_AIPass_Active','_deadline min _hardDeadline','call _admissionStable',
                      'CBE_fnc_NativeOrderReceipt','CBE_fnc_CortexExternalTakeover'):
            self.assertIn(proof,gate)
        self.assertLess(gate.index('exitWith {};'),gate.index('call _mutation'))
        self.assertNotIn('while',gate)
        self.assertNotIn('buildingPos',gate)
        self.assertLess(text.index('private _commitPreparation='),text.index('while {_remaining isNotEqualTo []}'))
        self.assertLess(text.index('while {_remaining isNotEqualTo []}'),text.index('private _pairs=[];'))

    def test_late_public_metadata_and_pair_selection_are_guarded(self):
        text=clear()
        for field in ('ClearVisitContext','ClearReserveAdmission'):
            self.assertIn('[{_group setVariable ["CBE_Cortex_'+field+'"',text)
        for field in ('ClearEarlyExits','ClearEgress','ClearFollowBudget','ClearStageBudget'):
            self.assertIn('if (!_resume) then {[{_group setVariable ["CBE_Cortex_'+field+'",nil,true]}] call _commitPreparation};',text)
        self.assertIn('[{_pairs=[_group,_team] call CBE_fnc_CombatPairs}] call _commitPreparation;',text)
        self.assertIn('[{_group setVariable ["CBE_Cortex_ClearStatus",["ENTRY"',text)

    def test_operation_edits_preserve_current_map_and_actor_marker_rechecks_native_leg(self):
        text=clear()
        self.assertIn('(_liveOperation get "restore") set ["groupAttack",[_baseAttack,false]]',text)
        for field in ('participantPlatforms','participants','participantProgress','phase'):
            self.assertIn('_liveOperation set ["'+field+'"',text)
        self.assertNotIn('_operation set ["participants"',text)
        self.assertIn('[_liveOperation] call _mutation;',text)
        self.assertEqual(text.count('params ["_liveOperation"];'),2)
        adopted=text.split('_liveOperation set ["phase","EGRESS"]',1)[1].split('}] call _commitPreparation;',1)[0]
        self.assertIn('CBE CLEAR EGRESS ADOPTED',adopted)
        reserve=text.split('// Native intent can change between staged receipt observation and commit.',1)[1].split('}] call _commitPreparation;',1)[0]
        for proof in ('expectedDestination _actor','local _actor','group _actor == _group',
                      'CortexCombatEffective','CortexActorMoveReserved','remoteControlled',
                      '_now vectorDistance _target <= 0.25','currentCommand _actor == "STOP"',
                      '(_stage select 2) != "APPROACH"','<= 0.75',
                      '["CBE_Cortex_ClearReserve",[_generation,_preparationEpoch,+_target]]'):
            self.assertIn(proof,reserve)
        self.assertNotIn('doMove',reserve)
        self.assertNotIn('setPos',reserve)
