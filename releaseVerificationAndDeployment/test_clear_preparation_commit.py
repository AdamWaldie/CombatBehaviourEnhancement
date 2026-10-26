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
        continuity=text.split('// A durable resume is the same visit,',1)[1].split('private _admissionStable=',1)[0]
        for proof in ('"CBE_Cortex_ClearVisitContext"','_resumeRequested','_previous param [10,-1,[0]]',
                      'count _resumeRosterContext != 4','_resumeRosterContext select [0,3]',
                      '(_resumeRosterContext select 3) == ""','RESUME_CONTEXT_PENDING'):
            self.assertIn(proof,continuity)
        for forbidden in ('OperationStart','setVariable','serverTime+'):
            self.assertNotIn(forbidden,continuity)
        self.assertLess(text.index('RESUME_CONTEXT_PENDING'),text.index('_building buildingPos -1'))
        self.assertLess(text.index('RESUME_TRANSFORM_MISMATCH'),text.index('RESUME_CONTEXT_PENDING'))
        self.assertIn('_resume && {(_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isNotEqualTo _resumeRosterContext}',gate)
        visit=text.split('private _visitContext=if (_resume)',1)[1].split('_job set ["visitContext"',1)[0]
        self.assertIn('then {+_resumeRosterContext} else {[]}',visit)
        self.assertIn('if (!_resume) then {',visit)
        self.assertNotIn('count _visitContext != 4',visit)
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
        adoption=text.split('private _reconciledActors=0;',1)[1].split('private _laneAdopted=',1)[0]
        self.assertIn('private _motionRequired=_motionReceipt isNotEqualTo []',adoption)
        self.assertIn('_motionReceipt param [4,[],[[]]]',adoption)
        self.assertIn('_settingsRequired && {_settingsOutcome != "ADOPTED"}',adoption)
        self.assertIn('_settingsOutcome in ["ADOPTED","ABSENT"]',adoption)
        self.assertIn('_settingsOutcome in ["ABSENT","PREPARED"]',adoption)
        self.assertIn('ACTOR_PREPARATION_UNAVAILABLE',adoption)
        self.assertNotIn('if (_resume && {_reconcileFailure',adoption)
        self.assertIn('if (_motionRequired) then {["ADOPT",_motionActor,_job]',adoption)
        self.assertIn('!(_motionAdopted isEqualTo true)',adoption)
        self.assertIn('_reconciledActors != (count _team min 8)',adoption)
        self.assertIn('ACTOR_RECONCILIATION_INTERRUPTED',adoption)
        self.assertIn('[_group,false] call CBE_fnc_CortexClearRelease',adoption)
        self.assertLess(text.index('private _reconciledActors=0;'),text.index('if !([_job] call CBE_fnc_BuildingOperationStart)'))

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
        throttle=journal.split('private _phase=',1)[1].split('private _result=false;',1)[0]
        self.assertIn('_phase isEqualTo (_job getOrDefault ["laneJournalPhase",""])',throttle)
        self.assertEqual(journal.count('_job set ["laneJournalPhase",_phase]'),1)
        self.assertLess(journal.index('if (_mode != "CHECK" && {'),journal.index('_job set ["laneJournalPhase",_phase]'))
        self.assertLess(journal.index('if (_mode != "CHECK" && {'),journal.index('_job set ["laneJournalAfter"'))
        self.assertLess(journal.index('_job set ["laneJournalAfter"'),journal.index('private _positions='))
        self.assertIn('exitWith {_job getOrDefault ["laneJournalLastResult",false]}',journal)
        # EXPORT uses the same validated live-job serializer as SAVE, but may not
        # consume its publication throttle, read old public lanes or mutate the job.
        self.assertIn('private _export=_mode in ["EXPORT","FROZEN"]',journal)
        self.assertIn('private _refused=if (_export) then {[]} else {false}',journal)
        self.assertIn('private _snapshot=if (_export) then {[]} else {',journal)
        self.assertIn('private _encoding=_mode in ["SAVE","EXPORT","FROZEN"]',journal)
        self.assertEqual(journal.count('if (_encoding) then {'),3)
        producer=(ROOT/'addons/infantry/functions/buildingProducerContext.sqf').read_text(encoding='utf-8')
        self.assertIn('call CBE_fnc_BuildingProducerContext',journal)
        for guard in ('"CBE_BuildingBrain"','"job",createHashMap','isNotEqualTo _job',
                      '"ownerEpoch"','"generation"','"cancelled"','"finished"'):
            self.assertIn(guard,producer)
        self.assertNotIn('setVariable',producer)
        self.assertIn('_job getOrDefault ["finished",false]',producer)
        self.assertIn('"producerOwner",-1',producer)
        self.assertIn('if (_frozen) then {',producer)
        self.assertIn('"LOCALITY_CHANGE"',producer)
        self.assertIn('"completed",false',producer)
        self.assertIn('private _ownerContext={if (_frozen) then {!local _group} else {local _group}}',journal)
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text(encoding='utf-8')
        outgoing=locality.split('private _buildingBrain=',1)[1].split('} forEach units _group;',1)[0]
        self.assertIn('private _captureOutgoing=!_gained && {!local _group}',outgoing)
        self.assertLess(outgoing.index('set ["cancelled",true]'),outgoing.index('["FROZEN",_clearJob]'))
        self.assertLess(outgoing.index('["FROZEN",_clearJob]'),outgoing.index('setVariable ["CBE_BuildingBrain",nil]'))
        self.assertLess(locality.index('["FROZEN",_clearJob]'),locality.index('setVariable ["CBE_AIPass_Epoch"'))
        capture=outgoing.split('if (_captureOutgoing) then {',1)[1].split('_group setVariable ["CBE_BuildingBrain",nil]',1)[0]
        self.assertIn('_clearJob get "hardDeadline",_lanes',capture)
        self.assertIn('[_clearJob] call CBE_fnc_BuildingStageJournal',capture)
        self.assertIn('[_clearJob] call CBE_fnc_BuildingRoomJournal',capture)
        self.assertIn('if (count _rooms == 13)',capture)
        self.assertIn('_lanes,_stageBudget,_rooms',capture)
        rooms=(ROOT/'addons/infantry/functions/buildingRoomJournal.sqf').read_text(encoding='utf-8')
        for field in ('cleared','unreachable','retryCounts','failedBy','deadline','lastProgressAt','visitContext'):
            self.assertIn('"'+field+'"',rooms)
        for guard in ('count _positions > 512','count _retries > _size','count _failures != _size',
                      'isNil {_retries select _i}','_retryRows pushBack [_i,_count]',
                      '(_cleared arrayIntersect _unreachable) isNotEqualTo []','count _x > 8'):
            self.assertIn(guard,rooms)
        for guard in ('"actorVisits"','"enteredActors"','count _entered > 64','count _visits > 64',
                      'count _visitKeys != count _enteredIds','!(_x in _cleared)',
                      '_visitRows pushBack [_x,+_indices]','+_entered,_visitRows'):
            self.assertIn(guard,rooms)
        for guard in ('"enteredActorIdentities",false','count _identities != count _entered',
                      'netId _actor isNotEqualTo _originalId','_enteredIds pushBack _originalId',
                      '_identityRows pushBack [_actor,_originalId]'):
            self.assertIn(guard,rooms)
        for effect in ('setVariable','doMove','setDestination','spawn','serverTime+'):
            self.assertNotIn(effect,rooms)

        self.assertIn('if (count _stageBudget == 5)',capture)
        self.assertIn('ClearLaneCaptureLocal",[6,clientOwner',capture)
        self.assertIn('_lanes,_stageBudget,_rooms,_phase,_egress]',capture)
        self.assertNotIn(',true]',capture)  # Machine-private proposal only.
        self.assertIn('call CBE_fnc_BuildingEgressJournal',capture)
        self.assertIn('count _egress == 14',capture)
        self.assertIn('private _egressing=_phase == "EGRESS"',capture)
        egress=(ROOT/'addons/infantry/functions/buildingEgressJournal.sqf').read_text(encoding='utf-8')
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _journal=[_job] call CBE_fnc_BuildingEgressJournal',step)
        for guard in ('count _assignments+count _pending > 8','count _records != 1',
                      'count _uses > 4','count _moves > 64','_next > _until',
                      '_rows apply {+(_x select 1)}','_transform apply {+_x}'):
            self.assertIn(guard,egress)
        for effect in ('setVariable','doMove','setDestination','spawn','serverTime+'):
            self.assertNotIn(effect,egress)
        self.assertIn('"egressDeadlineServer",-1',producer)

        start=(ROOT/'addons/infantry/functions/buildingOperationStart.sqf').read_text(encoding='utf-8')
        self.assertIn('["producerOwner",clientOwner]',start)
        self.assertIn('setVariable ["CBE_Cortex_ClearLaneCaptureLocal",nil]',start)
        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text(encoding='utf-8')
        self.assertIn('setVariable ["CBE_Cortex_ClearLaneCaptureLocal",nil]',stop)
        def may_capture(*,gained=False,local=False,owner=4,client=4,cancelled=False,
                        finished=False,phase='ENTRY',epoch=7,current_epoch=7):
            return (not gained and not local and owner==client and not cancelled
                    and not finished and phase in ('ENTRY','SWEEP','REPLAN','EGRESS') and epoch==current_epoch)
        self.assertTrue(may_capture())
        self.assertTrue(may_capture(phase='EGRESS'))
        self.assertTrue(may_capture(phase='REPLAN'))
        self.assertEqual(journal.count('["ENTRY","SWEEP","REPLAN"]'),2)
        fsm=(ROOT/'addons/main/fsm/buildingOperation.fsm').read_text(encoding='utf-8')
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('_job set ["phase","REPLAN"]',step)
        self.assertIn('class Replan',fsm)
        self.assertIn('"ENTRY","SWEEP","REPLAN","EGRESS"',producer)
        # REPLAN remains an admitted existing lane phase, not a request to rebuild routes.
        adoption=journal.split('if (_mode == "ADOPT") exitWith {',1)[1].split('// Export must',1)[0]
        self.assertIn('_job set ["phase",_phase]',adoption)
        self.assertIn('_job set ["pairRoutes",_copyRoutes]',adoption)
        self.assertNotIn('serverTime+',adoption)

        for changed in ({'gained':True},{'local':True},{'owner':5},{'cancelled':True},
                        {'finished':True},{'phase':'FINISHED'},{'current_epoch':8}):
            self.assertFalse(may_capture(**changed))
        tail=journal.split('private _journal=',1)[1]
        self.assertLess(tail.index('if (_export) exitWith {_journal}'),tail.index('_job set'))
        self.assertLess(tail.index('if (_export) exitWith {_journal}'),tail.index('setVariable'))
        self.assertIn('if (_export && {!(_result isEqualType [])}) then {[]} else {_result}',journal)
        self.assertIn('(_context select 1) apply {+_x}',journal)
        self.assertIn('_contextCopy,_positions apply {+_x}',journal)
        # Export advances no source clock; changing a nested returned transform or
        # request target must leave the private producer data untouched.
        import copy
        job={'context':['house',[[1,2,3],[0,1,0],[0,0,1]],90,'episode'],
             'requests':[['actor',[[4,5,6],7]]], 'publish_after':99}
        before=copy.deepcopy(job)
        exported={'context':[job['context'][0], [list(v) for v in job['context'][1]],
                             job['context'][2],job['context'][3]],
                  'requests':[[r[0],[list(r[1][0]),r[1][1]]] for r in job['requests']]}
        exported['context'][1][0][0]=99
        exported['requests'][0][1][0][0]=99
        self.assertEqual(job,before)
        def encoded_clock(local_observation,local_now,server_now):
            return server_now-(local_now-local_observation)
        self.assertEqual(encoded_clock(25,30,100),95)
        self.assertEqual(encoded_clock(25,40,110),95)  # Same source time, later capture.
        self.assertLess(journal.index('_job set ["laneJournalLastResult",false]'),journal.index('private _positions='))
        self.assertLess(text.index('if (!_laneAdopted) exitWith'),text.index('call CBE_fnc_BuildingOperationStart'))
        preflight=text.split('private _resumeLanePending=false;',1)[1].split('private _generation=-1;',1)[0]
        for proof in ('!_useResumeRoster','count _resumeLanes != 13','_resumeRosterContext','_resumePairs','_positions','arrayIntersect'):
            self.assertIn(proof,preflight)
        self.assertIn('if (_resumeLanePending) exitWith {false};',preflight)
        self.assertIn('_resumeLaneReceipt=+_resumeLanes',preflight)
        phase=text.split('private _resumePhaseReceipts=[];',1)[1].split('private _resumeLaneReceipt=[];',1)[0]
        for key,size,slot in (('ClearEgress',14,13),('ClearFollowBudget',5,4),('ClearStageBudget',5,4),
                              ('ClearEarlyExits',2,0),('ClearReserveAdmission',2,0),
                              ('ClearYield',2,0),('ClearRelief',2,0)):
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
