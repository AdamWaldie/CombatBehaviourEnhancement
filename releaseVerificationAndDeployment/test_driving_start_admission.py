"""Ordinary-driving FSM admission identity; engine timing remains physically unaccepted."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/vehicles/functions/drivingOperationStart.sqf').read_text(encoding='utf-8')
class DrivingStartAdmissionTests(unittest.TestCase):
    def test_route_is_captured_after_adoption_and_preflight_does_not_clear_yield(self):
        text=source()
        self.assertLess(text.index('call CBE_fnc_CortexLocality'),text.index('private _route='))
        preflight=text.split('private _entryRoute=',1)[1].split('private _accepted=',1)[0]
        self.assertNotIn('setVariable',preflight)
        self.assertNotIn('DrivingOperationFinish',preflight)
    def test_replacement_commit_guards_original_route_epoch_brain_and_yield(self):
        text=source();commit=text.split('isNil {',1)[1]
        gate=commit.split('private _hasVehicle=',1)[0]
        for proof in ('_epoch ==','DrivingRouteReceipt','isEqualTo _route','CBE_AIPass_Active',
                      'DrivingAssist_Enable','DrivingMovementAvailable','CortexZeusHeld',
                      'CortexExternalTakeover','isEqualTo _yieldSnapshot','_yieldSnapshot isNotEqualTo _route',
                      'CBE_Driving_Brain','isNotEqualTo _current'):
            self.assertIn(proof,gate)
        self.assertLess(commit.index('if (!_hasVehicle) exitWith'),commit.index('[_current,"REPLACED"]'))
        post=commit.split('[_current,"REPLACED"]',1)[1]
        self.assertLess(post.index('call _available'),post.index('setVariable ["CBE_DrivingRecovery_Yield",nil'))
        self.assertIn('_after isNotEqualTo _current',post)
        self.assertNotIn('nearEntities',commit)
        self.assertNotIn('while',commit)
    def test_duplicate_and_exhausted_route_do_not_publish_new_worker(self):
        text=source()
        duplicate=text.split('if (count _current > 0 &&',1)[1].split('private _hasVehicle=',1)[0]
        self.assertIn('isEqualTo _route',duplicate)
        self.assertIn('exitWith',duplicate)
        self.assertIn('"cancelled",false',duplicate)
        self.assertIn('"finished",false',duplicate)
        self.assertNotIn('setVariable',duplicate)
        self.assertNotIn('execFSM',duplicate)
        self.assertIn('!completedFSM _existingHandle',text)
        self.assertIn('_accepted=_workerAlive',duplicate)
        self.assertIn('_workerAlive || {_current getOrDefault ["cancelled",false]}',duplicate)
        self.assertIn('!completedFSM _handle',text)
        failure=text.split('if (!_accepted &&',1)[1]
        self.assertIn('"FSM_START_FAILED"',failure)
        self.assertIn('call CBE_fnc_DrivingOperationFinish',failure)
        self.assertNotIn('doMove',failure)
        self.assertNotIn('serverTime+',failure)
        resume=text.split('if (_resumeEnded) then {',1)[1].split('} else {',1)[0]
        self.assertIn('"EXECUTOR_RESTART"',resume)
        self.assertNotIn('DrivingOperationFinish',resume)
        self.assertNotIn('DrivingAssistRelease',resume)
        self.assertIn('_brain set ["crewVehicle",_current getOrDefault ["crewVehicle",objNull]]',text)
        self.assertIn('(_current getOrDefault ["executorRestarts",0]) >= 1',text)
        self.assertIn('[_current,"FSM_RESTART_EXHAUSTED"] call CBE_fnc_DrivingOperationFinish',text)
        self.assertIn('if (_resumeEnded) then {1+(_current getOrDefault ["executorRestarts",0])} else {0}',text)

        finish=(ROOT/'addons/vehicles/functions/drivingOperationFinish.sqf').read_text()
        self.assertIn('_reason in ["EXHAUSTED","FSM_START_FAILED","FSM_RESTART_EXHAUSTED"]',finish)
        step=(ROOT/'addons/vehicles/functions/drivingOperationStep.sqf').read_text(encoding='utf-8')
        gate=step.split('private _executor=',1)[1].split('if ([_group] call',1)[0]
        for proof in ('CBE_Driving_FSM','_executor isEqualType 0','finite _executor',
                      '_executor < 0','completedFSM _executor','["pending",false]','["completed",true]'):
            self.assertIn(proof,gate)
        for mutation in ('["cancelled",true]','["finished",true]','execFSM','DrivingOperationFinish','deadline'):
            self.assertNotIn(mutation,gate)
        self.assertLess(step.index('completedFSM _executor'),step.index('call CBE_fnc_DrivingCrewStep'))



    def test_prepared_duplicate_fixture_requires_real_prior_movement_and_same_handle(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingTraffic.sqf').read_text(encoding='utf-8')
        case=qa.split('private _duplicateDrivingAccepted=',1)[1].split('private _frontLength=',1)[0]
        for proof in ('isNil {','_followerGroup getVariable ["CBE_Driving_Brain"',
                      'call CBE_fnc_DrivingOperationStart','isEqualTo _liveBrain','isEqualTo _liveHandle',
                      '"cancelled",false','"finished",false','_ready && {_approached}',
                      'DRIVING-traffic-duplicate-worker-preserved'):
            self.assertIn(proof,case)
        self.assertNotIn('setVariable',case)
        self.assertNotIn('forceSpeed',case)
        self.assertNotIn('doMove',case)
