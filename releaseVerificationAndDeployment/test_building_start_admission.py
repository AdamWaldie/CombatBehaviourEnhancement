"""Startup authority contracts; prepared runtime cases remain physically unaccepted."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

def source(name):
    return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')

class BuildingStartAdmissionTests(unittest.TestCase):
    def test_start_retains_admitted_epoch_and_validates_before_old_worker_mutation(self):
        clear=source('cortexClearBuilding')
        self.assertIn('["ownerEpoch",_operation get "ownerEpoch"]',clear)
        start=source('buildingOperationStart')
        self.assertIn('private _epoch=_job getOrDefault ["ownerEpoch",-1];',start)
        self.assertNotIn('private _epoch=_group getVariable',start)
        commit=start.split('isNil {',1)[1]
        gate=commit.split('private _old=',1)[0]
        for proof in ('CBE_AIPass_ClearGeneration','CBE_AIPass_Epoch','operationGeneration',
                      'ownerEpoch','"CLEAR"','"objective"','CBE_AIPass_ClearBuilding',
                      'CBE_AIPass_Active','"deadline"','"hardDeadline"','alive _building',
                      'buildingTransform','nativeOrderReceipt','CBE_fnc_CortexIsEligible'):
            self.assertIn(proof,gate)
        self.assertLess(commit.index('exitWith {};'),commit.index('_old set ["cancelled",true]'))
        self.assertLess(commit.index('exitWith {};'),commit.index('execFSM'))
        self.assertNotIn('CortexQueueJob',start)

    def test_live_duplicate_does_not_restart_or_cancel_worker(self):
        start=source('buildingOperationStart')
        duplicate=start.split('if (count _old > 0 &&',1)[1].split('if (count _old > 0) then',1)[0]
        for proof in ('== _generation','exitWith','isEqualTo _job','== _epoch','"cancelled"','"finished"'):
            self.assertIn(proof,duplicate)
        self.assertNotIn('execFSM',duplicate)
        self.assertNotIn('_old set',duplicate)
        self.assertIn('!completedFSM _existingHandle',start)
        step=source('buildingOperationStep')
        gate=step.split('private _executor=',1)[1].split('private _delay=call',1)[0]
        self.assertIn('CBE_BuildingBrain_FSM',gate)
        self.assertIn('completedFSM _executor',gate)
        self.assertIn('["pending",false]',gate)
        self.assertIn('["completed",true]',gate)
        for mutation in ('["cancelled",true]','["finished",true]','execFSM','ClearRelease','deadline'):
            self.assertNotIn(mutation,gate)
        self.assertIn('&& {_workerAlive}',duplicate)
        self.assertIn('(_job getOrDefault ["executorRestarts",0]) < 1',start)
        self.assertIn('!completedFSM _handle',start)
        discovery=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        recovery=discovery.split('private _clearAlive=',1)[1].split('if (_clear isNotEqualTo [] && {!(',1)[0]
        self.assertIn('[_clearJob] call CBE_fnc_BuildingOperationStart',recovery)
        self.assertIn('isEqualTo _clear',recovery)
        self.assertIn('isEqualTo _clearJob',recovery)
        self.assertIn('[_group,false] call CBE_fnc_CortexClearRelease',recovery)
        self.assertNotIn('serverTime+',recovery)
        self.assertNotIn('doMove',recovery)


    def test_start_refusal_is_returned_and_only_matching_episode_retires(self):
        clear=source('cortexClearBuilding')
        refusal=clear.split('if !([_job] call CBE_fnc_BuildingOperationStart) exitWith {',1)[1].split('diag_log format ["[CBE] %1 clearing',1)[0]
        for proof in ('isNil {','local _group','_job get "ownerEpoch"',
                      'CBE_AIPass_Epoch','CBE_AIPass_ClearGeneration','== _operationGeneration',
                      '"CLEAR"','WORKER_START_REFUSED','[_group,false] call CBE_fnc_CortexClearRelease','false'):
            self.assertIn(proof,refusal)
        self.assertNotIn('remoteExec',refusal)
        self.assertNotIn('setVariable',refusal)

    def test_prepared_fixture_reuses_real_job_and_checks_duplicate_and_stale_starts(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        case=qa.split('private _originalBuildingBrain=',1)[1].split('deleteVehicle _movedHouse;',1)[0]
        for proof in ('getOrDefault ["job",createHashMap]','CLEAR-transform-duplicate-worker-preserved',
                      'CBE_BuildingBrain_FSM','isEqualTo _liveHandle','!_cancelledWorkerStarted',
                      '!_replacedWorkerStarted','_replacementPreserved'):
            self.assertIn(proof,case)
        self.assertEqual(case.count('[_originalBuildingJob] call CBE_fnc_BuildingOperationStart'),3)
        self.assertNotIn('_originalBuildingJob set',case)
