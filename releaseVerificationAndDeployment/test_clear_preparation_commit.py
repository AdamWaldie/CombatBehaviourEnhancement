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

        journal=(ROOT/'addons/infantry/functions/buildingLaneJournal.sqf').read_text(encoding='utf-8')
        for proof in ('isNil {','CBE_Cortex_ClearVisitContext','CBE_AIPass_ClearGeneration',
                      'CBE_AIPass_Epoch','serverTime >=','_snapshot select 3','_snapshot select 4',
                      '_nodeCount > 512','_laneCount > 8','count _routes != _laneCount',
                      '_key in _claimed','_copyStates','serverTime+1.5'):
            self.assertIn(proof,journal)
        for forbidden in (' doMove ',' doFollow ','doStop ','setUnitPos','setVariable ["CBE_Cortex_ClearVisits"'):
            self.assertNotIn(forbidden,journal)
        self.assertIn('_laneAdopted=["ADOPT",_job] call CBE_fnc_BuildingLaneJournal',text)
        self.assertIn('"securityEntries"',journal)
        self.assertIn('_job set ["entries",_entryNodes apply {+_x}]',journal)
        self.assertIn('count _snapshot != 13',journal)
        requests=journal.split('// Keep request age',1)[1].split('private _journal=',1)[0]
        self.assertIn('_request select 1',requests)
        self.assertIn('_job set ["movementRequestTimes",_requestTimes]',requests)
        self.assertNotIn('"movementTargets"',requests)
        self.assertNotIn('serverTime+2',requests)
        self.assertNotIn('serverTime+30',requests)
        self.assertIn('netId _actor in _requestTimes',requests)
        targets=journal.split('// Keep the selected buddy destination',1)[1].split('// Keep request age',1)[0]
        for proof in ('count _targets > _laneCount','count _entryTargets != count _targets',
                      '_entryTargets=_snapshot select 12','str _slot in _copyEntryTargets',
                      '_target call _vectorValid','_slot >= _laneCount'):
            self.assertIn(proof,targets)
        self.assertIn('_job set ["pairEntryTargets",_copyEntryTargets]',journal)
        adoption=journal.split('if (_mode == "ADOPT") exitWith {',1)[1].split('private _journal=',1)[0]
        self.assertNotIn('doMove',adoption)
        self.assertNotIn('"movementTargets"',adoption)
        self.assertNotIn('serverTime+',adoption)
        # Lane-specific proposals survive intact with their request ages. Rebuilding
        # from current nearest geometry would mix an old budget with a new target.
        cached={0:[10,20,1],1:[11,25,4]}
        snapshot=[[slot,target.copy()] for slot,target in cached.items()]
        adopted={slot:target.copy() for slot,target in snapshot}
        self.assertEqual(adopted,cached)
        adopted[0][0]=99
        self.assertEqual(cached[0],[10,20,1])
        def valid_targets(rows,lanes):
            import math
            seen=set()
            for row in rows:
                if not isinstance(row,list) or len(row)!=2:return False
                slot,target=row
                if (type(slot) not in (int,float) or not math.isfinite(slot)
                    or slot!=int(slot) or not 0<=slot<lanes or slot in seen):return False
                if (not isinstance(target,list) or len(target)!=3
                    or any(type(v) not in (int,float) or not math.isfinite(v) for v in target)):return False
                seen.add(slot)
            return len(rows)<=lanes
        self.assertTrue(valid_targets(snapshot,2))
        for invalid in ([[0,[1,2,3]],[0,[4,5,6]]],[[2,[1,2,3]]],
                        [[0.5,[1,2,3]]],[[0,[1,2]]],[[0,[1,2,float('nan')]]]):
            self.assertFalse(valid_targets(invalid,2))
        self.assertEqual(journal.count('_job set ["laneJournalAfter",serverTime+1.5]'),1)
        self.assertLess(journal.index('if (_mode != "CHECK" && {'),journal.index('_job set ["laneJournalAfter"'))
        self.assertLess(journal.index('_job set ["laneJournalAfter"'),journal.index('private _positions='))
        self.assertIn('exitWith {_job getOrDefault ["laneJournalLastResult",false]}',journal)
        self.assertLess(journal.index('_job set ["laneJournalLastResult",false]'),journal.index('private _positions='))
        self.assertLess(text.index('if (!_laneAdopted) exitWith'),text.index('call CBE_fnc_BuildingOperationStart'))
        preflight=text.split('private _resumeLanePending=false;',1)[1].split('private _generation=-1;',1)[0]
        for proof in ('!_useResumeRoster','count _resumeLanes != 13','_resumeRosterContext','_resumePairs','_positions','arrayIntersect'):
            self.assertIn(proof,preflight)
        self.assertIn('if (_resumeLanePending) exitWith {false};',preflight)
        self.assertIn('_resumeLaneReceipt=+_resumeLanes',preflight)
        phase=text.split('private _resumePhaseReceipts=[];',1)[1].split('private _resumeLaneReceipt=[];',1)[0]
        for key,size,slot in (('ClearEgress',14,13),('ClearFollowBudget',5,4),('ClearStageBudget',5,4),
                              ('ClearEarlyExits',2,0),('ClearReserveAdmission',2,0)):
            self.assertIn('["CBE_Cortex_'+key+'",'+str(size)+','+str(slot)+']',phase)
        for forbidden in ('setVariable','OperationStart','CortexClearRelease','serverTime+'):
            self.assertNotIn(forbidden,phase)
        self.assertIn('if (_resumePhasePending) exitWith {false};',phase)
        self.assertLess(text.index('"RESUME_PHASE_CHANGED"'),text.index('call CBE_fnc_OperationStart'))

        self.assertIn('["CHECK",_laneCheck] call CBE_fnc_BuildingLaneJournal',preflight)
        self.assertIn('["expectedSnapshot",_resumeLanes]',preflight)
        self.assertIn('_snapshot isNotEqualTo (_job getOrDefault ["expectedSnapshot",[]])',journal)

        self.assertLess(text.index('private _securityEntries=[];'),text.index('private _resumeLanePending=false;'))
        self.assertEqual(text.count('_building buildingExit _exitIndex'),1)
        self.assertIn('if (_mode in ["ADOPT","CHECK"]) then {',journal)
        self.assertLess(journal.index('if (_mode == "CHECK") exitWith {true};'),journal.index('_job set ["pairEntryTargets"'))
        common=journal.split('if (_mode != "CHECK" && {',1)[0]
        for guard in ('CBE_Cortex_ClearVisitContext','CBE_AIPass_ClearGeneration','CBE_AIPass_Epoch','serverTime >='):
            self.assertIn(guard,common)

        commit=text.split('private _handoffFailure="HANDOFF_CHANGED";',1)[1].split('if (!_handoffAccepted)',1)[0]
        self.assertIn('isNotEqualTo _resumeLaneReceipt',commit)
        self.assertLess(commit.index('"RESUME_LANES_CHANGED"'),commit.index('call CBE_fnc_OperationStart'))
        lane_guard=commit.split('if (_resumeLaneReceipt isNotEqualTo []',1)[1].split('_handoffFailure="RESUME_LANES_CHANGED"',1)[0]
        for mutation in ('setVariable','CortexClearRelease','OperationStart','serverTime+'):
            self.assertNotIn(mutation,lane_guard)
        for forbidden in ('setVariable','_retireResume','_refuse','CortexClearRelease','serverTime+'):
            self.assertNotIn(forbidden,preflight)
        self.assertLess(text.index('serverTime >= (_deadline min _hardDeadline)'),text.index('private _resumeLanePending=false;'))
        self.assertLess(text.index('if (_resumeLanePending) exitWith'),text.index('private _handoffAccepted=false;'))
        refusal=text.split('if (!_laneAdopted) exitWith {',1)[1].split('if !([_job]',1)[0]
        self.assertIn('}] call _commitPreparation',refusal)
        self.assertLess(refusal.index('[{'),refusal.index('call CBE_fnc_CortexClearRelease'))
        # Shared-clock transport retains elapsed age across distinct machine clocks.
        saved_progress=100-(50-42)
        adopted_progress=8-(105-saved_progress)
        self.assertEqual(8-adopted_progress,13)
        self.assertIn('serverTime-(time-(_row select 3))',journal)
        self.assertIn('time-(serverTime-(_row select 3))',journal)
        tail=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertLess(tail.index('if (!_tailOwned'),tail.index('if (_liveClear && {_delay >= 0})'))
        promotion=tail.split('if (_pairRosterChanged) then {',1)[1].split('// Rebalance one duplicated live post',1)[0]
        self.assertIn('_job set ["laneJournalAfter",-1];',promotion)
        self.assertLess(promotion.index('if (call _mayIssueMovement)'),promotion.index('_job set ["laneJournalAfter",-1]'))
        self.assertNotIn('hardDeadline',promotion)
        self.assertNotIn('pairStates',promotion)

    def test_late_public_metadata_and_pair_selection_are_guarded(self):
        text=clear()
        for field in ('ClearVisitContext','ClearReserveAdmission'):
            self.assertIn('[{_group setVariable ["CBE_Cortex_'+field+'"',text)
        for field in ('ClearEarlyExits','ClearEgress','ClearFollowBudget','ClearStageBudget'):
            self.assertIn('if (!_resume) then {[{_group setVariable ["CBE_Cortex_'+field+'",nil,true]}] call _commitPreparation};',text)
        self.assertIn('[{_pairs=[_group,_team,true,_pairPreference] call CBE_fnc_CombatPairs}] call _commitPreparation;',text)
        self.assertIn('[{_group setVariable ["CBE_Cortex_ClearStatus",["ENTRY"',text)

    def test_operation_edits_preserve_current_map_and_actor_marker_rechecks_native_leg(self):
        text=clear()
        self.assertIn('[_group,_liveOperation,false,_originalPolicy] call CBE_fnc_OperationAttackPolicy',text)
        for field in ('participantPlatforms','participants','participantProgress','phase'):
            self.assertIn('_liveOperation set ["'+field+'"',text)
        self.assertNotIn('_operation set ["participants"',text)
        self.assertIn('[_liveOperation] call _mutation;',text)
        self.assertEqual(text.count('params ["_liveOperation"];'),3)
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
