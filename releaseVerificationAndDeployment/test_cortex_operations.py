"""Cortex operational regression contracts. Engine acceptance is in cortexQA, not simulated here."""
from pathlib import Path
import json
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'addons/main/functions/Cortex'
def source(name): return next((ROOT/'addons').rglob(name+'.sqf')).read_text(encoding='utf-8')
class CortexOperations(unittest.TestCase):
    def test_air_departed_pilot_restores_only_original_actor_with_live_atomic_guards(self):
        release=source('cortexAirPilotFeatureRelease')
        safe=release.split('private _actorSafe={',1)[1].split('private _safe=',1)[0]
        self.assertIn('group _actor == _group',safe)
        self.assertIn('vehicle _actor == _actor || {!isNull _aircraft && {vehicle _actor == _aircraft}}',safe)
        self.assertIn('CortexActorFireTaskAvailable',safe)
        self.assertIn('CortexExternalTakeover',safe)
        restore=release.split('private _restored=false;',1)[1].split('if (_restored)',1)[0]
        for guard in ('isNil {', 'local _actor', 'serverTime < _releaseUntil',
                      'CBE_AirPilotFeatureLocalEpoch', 'isEqualTo _receipt',
                      'call _actorSafe', 'vehicle _actor == _actor || {count _lease == 0}'):
            self.assertLess(restore.index(guard),restore.index('_actor enableAI'))
        self.assertNotIn('setVariable ["CBE_FlightLease",nil',restore)
        self.assertNotIn('driver _aircraft',restore)
        self.assertLess(restore.index('getVariable ["CBE_FlightLease"'),restore.index('_actor enableAI'))
        task=source('cortexActorFireTaskAvailable')
        self.assertIn('"GET OUT"',task)

    def test_air_stale_lease_retirement_requires_original_issuer_and_airframe_authority(self):
        release=source('cortexAirPilotFeatureRelease')
        retirement=release.split('// An owner transfer invalidates the old lease',1)[1].split('// On foot, the original actor',1)[0]
        for guard in ('_safe && {vehicle _actor == _aircraft} && {local _aircraft} && {_issuer != clientOwner}',
                      'isNil {', 'local _actor && {local _aircraft} && {!_activeBrain}',
                      'serverTime < _releaseUntil',
                      'CBE_AirPilotFeatureLocalEpoch', 'isEqualTo _receipt',
                      '["controller",""]) == "AIR_ATTACK"',
                      '["token",""]) == _token', '["owner",-1]) == _issuer',
                      '["finished",false]', '["cancelled",false]'):
            self.assertIn(guard,retirement)
        # A delayed old receipt must not use token equality to clear a successor.
        self.assertLess(retirement.index('["owner",-1]) == _issuer'),
                        retirement.index('setVariable ["CBE_FlightLease",nil,true]'))
        self.assertIn('_lease=_aircraft getVariable ["CBE_FlightLease",createHashMap]',retirement)
        generic=source('flightLeaseRelease')
        self.assertIn('["owner",-1]) != clientOwner',generic)
        self.assertNotIn('remoteExec',retirement)
        self.assertNotIn('doMove',retirement)

    def test_role_replacement_consumes_each_donor_and_supports_three_survivors(self):
        step=source('cortexFlankStep')
        transfer=step.split('while {count _movingAvailable < _minimumMovers',1)[1].split('if (count _movingAvailable < _minimumMovers)',1)[0]
        self.assertIn('private _relief=[_coverAvailable,1] call _selectRelief;',transfer)
        self.assertIn('_coverAvailable deleteAt (_coverAvailable find _x)',transfer)
        self.assertIn('(_teams select _otherTurn) deleteAt ((_teams select _otherTurn) find _x)',transfer)
        self.assertIn('} forEach _relief;',transfer)
        self.assertLess(transfer.index('_coverAvailable deleteAt'),transfer.index('_movingAvailable pushBack _x'))
        start=source('cortexSupportBoundStart')
        coordinator=source('cortexSupportCoordinateStep')
        self.assertIn('if (count _fit < 3)',start)
        self.assertEqual(step.count('call _ensureMovingTeam'),2)
        issue=step.split('private _issue = {',1)[1].split('private _result =',1)[0]
        self.assertLess(issue.index('call _ensureMovingTeam'),issue.index('_unit doMove _spot'))
        self.assertIn('count _units >= _minimumMovers && {count (_roster select 1) >= 1}',issue)
        self.assertIn('private _minimumMovers=[count _units] call _movingMinimum',step)
        self.assertLess(issue.index('_minimumMovers=[count _fit] call _movingMinimum'),issue.index('call _ensureMovingTeam'))
        for guard in ('_singletonFollow=_total == 3', 'count _teams == 2',
                      'count (_teams select 0) == 2', 'count (_teams select 1) == 1'):
            self.assertIn(guard,step)
        def minimum(support,total,turn,teams):
            singleton=support and total == 3 and turn == 1 and teams == (2,1)
            return 1 if (not support and total == 2) or singleton else 2
        self.assertEqual(minimum(True,3,0,(2,1)),2)
        self.assertEqual(minimum(True,3,1,(2,1)),1)
        self.assertEqual(minimum(True,4,1,(3,1)),2)
        self.assertEqual(minimum(True,3,1,(1,2)),2)
        self.assertEqual(minimum(False,2,1,(1,1)),1)
        self.assertIn('private _minimumStrength=[2,3] select _support',step)
        self.assertIn('count _first < 2 || {count _second < 1}',start)
        self.assertIn('count _fit < 3',coordinator)
        self.assertIn('count _fit >= 3',coordinator)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text()
        self.assertIn('for "_i" from 0 to (_helperSize-1)',qa)
        self.assertIn('coordinatedsmall',runner)
        self.assertIn('[_smallCheck,_phase,_wait,[],true,true,3]',runner)


    def test_prepared_coordination_is_separate_from_execution_and_rally(self):
        brain=source('groupBrainStep')
        maintenance=brain.split('// Capacity freshness is a protocol deadline',1)[1].split('private _legacyPhase=',1)[0]
        for guard in ('count _supportLease == 6','count _supportRole == 5',
                      '(_supportRole select 0) == (_supportLease select 0)',
                      '(_supportRole select 2) == "COVER"','serverTime < (_supportLease select 2)',
                      '_delay=_delay min 2'):
            self.assertIn(guard,maintenance)
        self.assertLess(brain.index('_delay=_delay min 2'),brain.index('_brain set ["nextAt",time+_delay]'))
        for delay in (0.5,2,20,80):
            self.assertLessEqual(min(delay,2),2)
        ack=source('cortexSupportAck')
        self.assertLess(ack.index('HeadlessResolveSender'),ack.index('CBE_Cortex_SupportEligibility'))
        self.assertLess(ack.index('_lease isNotEqualTo _snapshot'),ack.index('CBE_Cortex_SupportEligibility'))
        self.assertIn('[_token,groupOwner _group,_lease select 2]',ack)
        self.assertIn('CBE_Cortex_SupportPreparedReceipt',ack)
        report=ack.split('if (_capacity isNotEqualTo []) exitWith {',1)[1].split('// A delayed owner reply',1)[0]
        for proof in ('count _capacity != 7','_epoch != (_group getVariable',
                      '_until > _observed+6','_armed > _fit','capacityByToken',
                      '(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _role'):
            self.assertIn(proof,report)
        self.assertLess(ack.index('HeadlessResolveSender'),ack.index('if (_capacity isNotEqualTo [])'))
        self.assertLess(ack.index('_lease isNotEqualTo _snapshot'),ack.index('if (_capacity isNotEqualTo [])'))
        maintain=source('cortexSupportMaintain')
        self.assertIn('_observed+2',maintain)
        self.assertIn('(_observed+6) min (_lease select 2)',maintain)
        self.assertIn('count _members <= 64',maintain)
        self.assertIn('CortexPrimaryAmmoAvailable',maintain)
        coordinator=source('cortexSupportCoordinateStep')
        self.assertIn('[_group,_token] call _capacityReady',coordinator)
        self.assertNotIn('magazinesAmmo',coordinator)
        self.assertNotIn('CortexPrimaryAmmoAvailable',coordinator)
        self.assertIn('(_entry select 1) != groupOwner _group',coordinator)
        self.assertIn('serverTime < (_report select 4)',coordinator)
        def capacity(owner,current_owner,role,current_role,epoch,current_epoch,now,until,fit,armed):
            return owner==current_owner and role==current_role and epoch==current_epoch and now<until and fit>=3 and armed>=3
        self.assertTrue(capacity(4,4,'cover1','cover1',2,2,1,6,4,3))
        self.assertFalse(capacity(4,5,'cover1','cover1',2,2,1,6,4,3))
        self.assertFalse(capacity(4,4,'cover1','move1',2,2,1,6,4,3))
        self.assertFalse(capacity(4,4,'cover1','cover1',2,3,1,6,4,3))
        self.assertFalse(capacity(4,4,'cover1','cover1',2,2,6,6,4,3))
        self.assertFalse(capacity(4,4,'cover1','cover1',2,2,1,6,4,2))

        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombinedOperation.sqf').read_text()
        self.assertIn('COMBINED-OP-prepared-contact-becomes-coordinated-movement',qa)
        self.assertIn('_receipt select 0) == (_status select 0)',qa)
        self.assertIn('_receipt select 0) == (_role select 0)',qa)
        self.assertIn('_travelSquads >= 2',qa)
        for name in ['cortexCoordinatedAssault','cortexSupportAssaultServer']:
            code=source(name)
            self.assertIn('CBE_Cortex_SupportEligibility',code)
            self.assertIn('(_eligibility select 1) == groupOwner _helper',code)
            self.assertIn('serverTime < (_eligibility select 2)',code)
            self.assertIn('_prepared || {_executing}',code)
        requester=source('cortexCoordinatedAssault')
        self.assertIn('if (_executing && {_status select 3}) then {_acknowledged = true}',requester)
        apply=source('cortexSupportApply')
        self.assertIn('_prepareAlongsideDrill',apply)
        self.assertIn('_directCoordinationPending && {_movementOwner == "TACTICAL_DRILL"}',apply)
        pending=apply.split('if (_okay && {_directCoordinationPending}) exitWith {',1)[1].split('};',1)[0]
        self.assertNotIn('OperationStart',pending)
        self.assertNotIn('responding',pending)
        self.assertNotIn('doMove',pending)
        step=source('cortexSupportStep')
        direct=step.split('if (_sharedCoordinated) then {',1)[1].split('} else {',1)[0]
        self.assertIn('_rally=getPosATL _helperTransmitter',direct)
        self.assertNotIn('CortexSelectAvenue',direct)
        self.assertIn('CBE_Cortex_SupportEligibility",nil,true',step)


    def test_coordinated_role_handover_does_not_recall_movers(self):
        end=source('cortexFlankEnd')
        command=end.split('private _mayCommand =',1)[1].split('private _mayRestoreActor=',1)[0]
        self.assertIn('"ROLE_HANDOVER"',command)
        restoration=end.split('private _mayRestore=',1)[1].split('private _mayCommand',1)[0]
        self.assertNotIn('"ROLE_HANDOVER"',restoration)
        self.assertIn('if ([_unit] call _mayRestoreActor) then {_unit enableAI _feature}',end)
        actor=end.split('private _mayRestoreActor=',1)[1].split('private _groupModeLease',1)[0]
        for guard in ['remoteControlled','CortexExternalOwner','CompatibilityExternalControl','group _actor == _group','isPlayer']:
            self.assertIn(guard,actor)
        for name in ['cortexCoordinatedAssault','cortexSupportApply','cortexSupportMaintain']:
            self.assertIn('["ROLE_HANDOVER"]',source(name).replace('_group,_state,',''))
            self.assertNotIn('["ABORT"] call CBE_fnc_CortexFlankEnd',source(name).replace('_group,_state,',''))


    def test_drill_adoption_reuses_destinations_without_cover_replanning(self):
        step=source('cortexFlankStep')
        branch=step.split('if (_resumeIndex >= 0) then {',1)[1].split('_spots pushBack _spot;',1)[0]
        retained,replan=branch.split('} else {',1)
        self.assertIn('(_resumeSpots select _resumeIndex) select 1',retained)
        self.assertNotIn('CortexFindCover',retained)
        self.assertNotIn('surfaceNormal',retained)
        self.assertIn('CortexFindCover',replan)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        self.assertIn('_helpers select [0,16]',qa)
        self.assertIn('true,8,"VIEW","GEOM"',qa)
        self.assertIn('boundingBoxReal _x',qa)
        self.assertIn('COORD-requester-view-clear',qa)
        self.assertIn('_helperViews findIf {!(_x select 3)} < 0',qa)


    def test_standoff_no_solution_exits_before_releasing_flight(self):
        controller=source('cortexAirAttack')
        failure=controller.split('serverTime > (_job getOrDefault ["attackStartedAt",serverTime])+25}) exitWith {',1)[1].split('if (serverTime > (_job get "deadline"))',1)[0]
        self.assertIn('["EGRESS","NO_FIRE_SOLUTION"]',failure.replace('_group,_job,',''))
        self.assertIn('["EGRESS"] call _setOperationPhase',failure)
        self.assertIn('_job set ["deliveryFailureReason","NO_FIRE_SOLUTION"]',failure)
        self.assertIn('_job set ["deadline",serverTime+75]',failure)
        self.assertNotIn('call _finish',failure)
        self.assertNotIn('setPos',failure)
        self.assertNotIn('fireAtTarget',failure)
        finish=controller.split('private _finish={',1)[1].split('private _finishGroup=',1)[0]
        self.assertIn('_reason=_deliveryFailure',finish)


    def test_tactical_migration_preserves_intent_and_finite_budgets(self):
        checkpoint=source('cortexCheckpoint')
        resume=source('cortexDrillResume')
        locality=source('cortexLocality')
        resumed_roster=resume.split('private _capable=_living select {',1)[1].split('if (count _capable < 2)',1)[0]
        for guard in ('simulationEnabled _x','!isObjectHidden _x','ace_medical_ai_healQueue'):
            self.assertIn(guard,resumed_roster)
        self.assertNotIn('ace_medical_ai_healQueue',resume.split('private _living=',1)[1].split('private _capable=',1)[0])
        for field in ['points','index','teamTurn','boundDeadlineIdentity','resumeSpots','resumeRetries','resumeRecovery','resumeUnavailable','resumeAttempts']:
            self.assertIn('"'+field+'"',checkpoint)
        self.assertIn('migrationClocks',checkpoint)
        support_local=source('cortexSupportLocal')
        support_step=source('cortexSupportStep')
        support_apply=source('cortexSupportApply')
        self.assertIn('[_helper,_lease,true] remoteExecCall ["CBE_fnc_CortexSupportLocal",_owner]',support_step)
        self.assertIn('["ownerChange",_ownerChange],["adopt",_ownerChange]',support_local)
        self.assertLess(support_apply.index('if (!_deliveryReady) exitWith'),support_apply.index('call CBE_fnc_OperationStart'))
        owner_wait=support_apply.split('if (!_deliveryReady) exitWith',1)[1].split('private _directCoordinationPending',1)[0]
        self.assertIn('serverTime < (_job get "waitUntil")',owner_wait)
        self.assertNotIn('CortexLocality',owner_wait)
        self.assertNotIn('OperationStart',owner_wait)
        self.assertNotIn('serverTime+',owner_wait)
        self.assertIn('getOrDefault ["supportOwner",-1]) == clientOwner',support_apply)
        self.assertIn('_operation set ["supportOwner",clientOwner]',support_apply)
        self.assertLess(support_apply.index('if (_ownerDelivery) exitWith'),support_apply.index('call CBE_fnc_OperationStart'))


        hold_checkpoint=checkpoint.split('// Carry passive HOLD provenance only.',1)[1].split('_payload pushBack ["resumeSpots"',1)[0]
        for proof in ('count _nativeCommands <= 64','(_row select 1) == "HOLD"',
                      'currentCommand _actor == "STOP"','formLeader _actor == (_row select 3)',
                      '"resumeNativeHolds"','"resumeHoldIssuer"'):
            self.assertIn(proof,hold_checkpoint)
        hold_resume=resume.split('private _resumeCommands=',1)[1].split('private _operationPhase=',1)[0]
        for proof in ('(_holdIssuer select 0) isEqualTo _sourceToken',
                      '(_holdIssuer select 3) isEqualTo _sourceGeneration','count _holdRows <= 64',
                      '(expectedDestination _heldActor) isEqualTo _heldNative',
                      'formLeader _heldActor == _heldLeader','_heldLeader,-1,[],[]',
                      'currentCommand _x != "STOP" || {netId _x in _resumeCommands}',
                      'CBE_fnc_CortexActorMoveReserved','!(_x in _resumeUnavailable)'):
            self.assertIn(proof,hold_resume)
        self.assertIn('_drill set ["nativeAdmissionChecked",true]',resume)
        self.assertIn('_drill set ["nativeCommands",_resumeCommands]',resume)
        for forbidden in ('doStop','doMove','doFollow','execFSM','serverTime+2'):
            self.assertNotIn(forbidden,hold_resume)

        self.assertIn('"authoredOrder"',checkpoint)
        start=source('cortexDrillStart')
        self.assertIn('if (isNil {_drill get "authoredOrder"})',start)
        self.assertIn('_drill set ["authoredOrder",[_group] call CBE_fnc_NativeOrderReceipt]',start)
        self.assertLess(resume.index('private _authoredOrder='),resume.index('if (_inspectOnly)'))
        self.assertIn('_authoredOrder isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',resume)
        active=source('cortexFlankStep')
        self.assertLess(active.index('private _authoredOrder='),active.index('call CBE_fnc_OperationStep'))
        self.assertIn('exitWith {"REPLACED" call _end}',active)

        restore=source('cortexRestoreCalm')
        self.assertIn('if (!_preservePhase || {_reason != "OWNERSHIP_ADOPTED"})',restore)
        self.assertIn('DRILL_LOCALITY_SETTLING',resume)
        self.assertIn('DRILL_MIGRATION_REFUSED',resume)
        self.assertIn('_operationPhase',resume)
        self.assertIn('count _points <= 64',checkpoint)
        self.assertIn('count (_drill getOrDefault ["units",[]]) <= 64',checkpoint)
        self.assertIn('_sourceGeneration != (_group getVariable ["CBE_OperationGeneration",-1])',resume)
        self.assertIn('time+(_deadline-serverTime)',resume)
        self.assertIn('createHashMapFromArray (_drill getOrDefault ["resumeAttempts",[]])',resume)
        self.assertIn('serverTime+5',resume)
        self.assertIn('_waitUntil >= 0 && {serverTime >= _waitUntil}',resume)
        self.assertIn('_waypoint isEqualTo [] && {currentWaypoint _group < count waypoints _group}',resume)
        self.assertIn('if (_stage != "MOVE")',resume)
        self.assertIn('_drill deleteAt "resumeSpots"',resume)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        continuation=qa.split('if (_case == "ADVANCE-HC-CONTINUATION") then {',1)[1].split('if (_case == "ADVANCE-HC-HANDOVER")',1)[0]
        self.assertIn('tactical-owner-adopted',continuation)
        self.assertIn('committed-route-preserved',continuation)
        self.assertIn('bound-deadline-preserved',continuation)
        self.assertIn('resumed-physical-progress',continuation)
        self.assertNotIn('deleteVehicle',continuation)
        self.assertNotIn('CortexDrillResume',continuation)

        self.assertIn('CortexQueueJob',resume)
        self.assertNotIn('CortexPlanRoute',resume)
        self.assertNotIn('setPos',resume)
        self.assertNotIn('doFollow',resume)
        self.assertLess(locality.index('[_group,_candidate,-1,true]'),locality.index('call CBE_fnc_OperationCancel'))
        self.assertIn('_inheritedDrill isEqualTo []} && {[_x] call _restoreActorEligible}',locality)
        self.assertLess(locality.index('[_group,_inheritedDrill]'),locality.index('call CBE_fnc_CortexSupportApply'))
        step=source('cortexFlankStep')
        self.assertIn('(_resumeSpots select _resumeIndex) select 1',step)
        self.assertIn('(_resumeRetries select _record) select 1',step)


    def test_support_refusal_cannot_fall_through_as_success(self):
        apply=source('cortexSupportApply')
        failed_operation=apply.split('if (count _operation == 0) exitWith {',1)[1].split('private _generation=',1)[0]
        self.assertIn('_okay=false',failed_operation)
        self.assertIn('["SUPPORT",false]',failed_operation.replace('_group,',''))
        self.assertNotIn('CortexSupportAck',failed_operation)
        failed_move=apply.split('if (!_movementReady) exitWith {',1)[1].split('_state set ["supportOperationGeneration"',1)[0]
        self.assertIn('_okay=false',failed_move)
        self.assertIn('MOVEMENT_REJECTED',failed_move)
        self.assertNotIn('_state set',failed_move)
        self.assertIn('[_group,_token,_okay,_lease,clientOwner] remoteExecCall',apply)
        self.assertLess(apply.index('if (!_movementReady) exitWith'),apply.index('_state set ["responding",true]'))

    def test_group_tactics_fsm_owns_the_persistent_ground_brain(self):
        discover=source('cortexDiscover')
        start=source('groupBrainStart')
        queue=source('groupBrainQueue')
        step=source('groupBrainStep')
        fsm=(ROOT/'addons/main/fsm/groupTactics.fsm').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_GroupBrainStart',discover)
        self.assertNotIn('[CBE_fnc_CortexGroupTick,_groupJob',discover)
        self.assertIn('groupTactics.fsm',start)
        admission=start[start.index('private _accepted='):]
        for proof in ('finite _handle','!completedFSM _handle','CBE_AIPass_Epoch',
                      'CBE_GroupBrain_Generation','isEqualTo _brain','FSM_START_FAILED'):
            self.assertIn(proof,admission)
        self.assertIn('if (_accepted) then {',admission)
        self.assertIn('setVariable ["CBE_AIPass_Managed",false]',admission)
        self.assertTrue(start.rstrip().endswith('_accepted'))

        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_fnc_GroupBrainStep',queue)
        self.assertIn('ownerEpoch',step)
        self.assertIn('CBE_GroupBrain_Generation',step)
        self.assertIn('CBE_fnc_CortexZeusHeld',step)
        self.assertIn('CBE_fnc_CortexExternalTakeover',step)
        self.assertIn('CBE_fnc_CortexGroupTick',step)
        executor=step[step.index('private _executor='):step.index('if (!(missionNamespace')]
        for proof in ('CBE_GroupBrain_FSM','finite _executor','completedFSM _executor',
                      '_brain set ["pending",false]','_brain set ["completed",true]'):
            self.assertIn(proof,executor)
        for forbidden in ('call CBE_fnc_', 'execFSM', 'doMove', 'doStop', '"cancelled",true'):
            self.assertNotIn(forbidden,executor)
        self.assertLess(step.index('completedFSM _executor'),step.index('call CBE_fnc_CortexSupportMaintain'))
        self.assertLess(step.index('completedFSM _executor'),step.index('call CBE_fnc_CortexGroupTick'))
        self.assertNotIn('completedFSM',queue)

        for state in ['Calm','Contact','Support','Manoeuvre','Assault','Clear','Security','Withdraw']:
            self.assertIn('class '+state,fsm)
        self.assertIn('CBE_GroupBrain_Generation',fsm)
        self.assertIn('CBE_fnc_CortexZeusHeld',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertIn('class Zeus',waiting)
        self.assertIn('class External',waiting)
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('(_brain getOrDefault [""queuedAt"",time])+15',fsm)
        self.assertIn('CBE_AIPass_NextJobDue',fsm)
        self.assertIn('CBE_AIPass_ResumeGraceUntil',fsm)
        self.assertIn('CBE_fnc_CortexIsPaused',fsm)
        self.assertIn('if (_brain getOrDefault ["cancelled",false]) exitWith',step)
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('schedulerWatchdogs=',diagnostics)
        self.assertIn('only wakes the same keyed shared-scheduler job',diagnostics)

    def test_persistent_fsm_watchdogs_only_recover_real_scheduler_starvation(self):
        for name in [
            "groupTactics.fsm",
            "buildingOperation.fsm",
            "convoyOperation.fsm",
            "supportRequest.fsm",
            "artilleryMission.fsm",
            "airAttackOperation.fsm",
        ]:
            fsm = (ROOT / "addons/main/fsm" / name).read_text(encoding="utf-8")
            with self.subTest(fsm=name):
                self.assertIn('(_brain getOrDefault [""queuedAt"",time])+15', fsm)
                self.assertNotIn('(_brain getOrDefault [""queuedAt"",time])+3', fsm)
                self.assertIn('CBE_AIPass_ResumeGraceUntil', fsm)
                self.assertIn('CBE_fnc_CortexIsPaused', fsm)
    def test_building_operation_fsm_owns_clearance_progression(self):
        clear=source('cortexClearBuilding')
        start=source('buildingOperationStart')
        queue=source('buildingOperationQueue')
        step=source('buildingOperationStep')
        release=source('cortexClearRelease')
        locality=source('cortexLocality')
        stop=source('cortexStop')
        fsm=(ROOT/'addons/main/fsm/buildingOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_BuildingOperationStart',clear)
        self.assertNotIn('}, createHashMapFromArray [',clear)
        self.assertIn('buildingOperation.fsm',start)
        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_fnc_BuildingOperationStep',queue)
        self.assertIn('CBE_AIPass_ClearGeneration',step)
        self.assertIn('CBE_fnc_CortexExternalTakeover',step)
        self.assertIn('CBE_fnc_OperationStep',step)
        self.assertIn('vectorDistance (AGLToASL',step)
        self.assertIn('CBE_fnc_RecoveryStep',step)
        for state in ['Entry','Sweep','Replan','Egress']:
            self.assertIn('class '+state,fsm)
        self.assertIn('CBE_fnc_CortexZeusHeld',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('CBE_fnc_CortexClearRelease',fsm)
        self.assertIn('CBE_BuildingBrain',release)
        self.assertIn('CBE_BuildingBrain',locality)
        self.assertIn('CBE_BuildingBrain',stop)
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('cbe-building-fsm-',diagnostics)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertIn('class Zeus',waiting)
        self.assertIn('class External',waiting)
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {-1}',step)
    def test_convoy_operation_fsm_replaces_persistent_scheduler_job(self):
        sync=source('convoySync');adopt=source('convoyHeadlessAdoptLocal');start=source('convoyOperationStart');queue=source('convoyOperationQueue');step=source('convoyOperationStep');release=source('convoyReleaseLocal')
        fsm=(ROOT/'addons/main/fsm/convoyOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_ConvoyOperationStart',sync+adopt)
        gate=step.split('private _executor=',1)[1].split('private _entry=',1)[0]
        self.assertIn('CBE_Convoy_Brain_FSM',gate)
        self.assertIn('completedFSM _executor',gate)
        self.assertIn('["pending",false]',gate)
        self.assertIn('["completed",true]',gate)
        for mutation in ('["cancelled",true]','["finished",true]','execFSM','ConvoyReleaseLocal','deadline'):
            self.assertNotIn(mutation,gate)
        self.assertNotIn('CBE_fnc_ConvoyJobStep',sync+adopt)
        self.assertIn('convoyOperation.fsm',start)
        reuse=start[start.index('private _current='):start.index('if (count _current > 0) then')]
        self.assertIn('!completedFSM _handle',reuse)
        self.assertIn('"ownerEpoch"',reuse)
        self.assertIn('"executorRestarts",1',reuse)
        self.assertIn('CBE_Convoy_LocalRegistry',reuse)
        self.assertIn('FSM_RESTART_EXHAUSTED',reuse)
        self.assertIn('FSM_START_FAILED',start)
        self.assertIn('CBE_fnc_ConvoyReleaseLocal',start)
        self.assertIn('CBE_CONVOY_EXECUTOR_MAINTENANCE',sync)
        maintenance=sync[sync.index('// One coalesced lifecycle job'):]
        self.assertIn('4 min _count',maintenance)
        self.assertIn('!completedFSM _handle',maintenance)
        self.assertNotIn('createHashMapFromArray [["subsystem","CONVOY"],["cursor",0]]',maintenance)
        self.assertIn('_maintenance set ["cursor",(_cursor+_limit) mod _count]',maintenance)
        self.assertIn('CBE_Convoy_LocalRegistry',maintenance)
        self.assertNotIn('CBE_fnc_ConvoyTick',maintenance)
        self.assertNotIn('CBE_fnc_ConvoyHeadlessAdoptLocal',maintenance)
        self.assertNotIn('CBE_fnc_ConvoyHeadlessAdoptLocal',reuse)
        for reset in ['["nextAt",time]','["pending",false]','["queuedAt",time]','CBE_Convoy_LocalState",nil']:
            self.assertNotIn(reset,reuse)
        self.assertNotEqual(start.rstrip().splitlines()[-1],'true')
        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_fnc_ConvoyOperationStep',queue)
        self.assertIn('CBE_fnc_ConvoyTick',step)
        self.assertIn('CBE_Convoy_ReceivedRevision',step)
        for state in ['Cruise','Spacing','Recovery','ContactHold','OrderedHold','Obstruction','Arrived']: self.assertIn('class '+state,fsm)
        self.assertIn('CBE_fnc_CortexZeusHeld',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('CBE_Convoy_Brain',release)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertIn('class Zeus',waiting)
        self.assertIn('class External',waiting)
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('watchdogCount',start+fsm+source('aiGetDiagnostics'))
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_air_attack_operation_fsm_owns_phase_persistence(self):
        discover=source('cortexDiscover');combined=source('cortexCombinedArmsLocal')
        start=source('airAttackOperationStart');queue=source('airAttackOperationQueue');step=source('airAttackOperationStep')
        attack=source('cortexAirAttack');diagnostics=source('aiGetDiagnostics')
        fsm=(ROOT/'addons/main/fsm/airAttackOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_AirAttackOperationStart',discover+combined)
        self.assertNotIn('[CBE_fnc_CortexAirAttack,',discover+combined)
        self.assertIn('airAttackOperation.fsm',start)
        gate=step.split('private _executor=',1)[1].split('private _job=',1)[0]
        for proof in ('CBE_AirAttack_Brain_FSM','_executor isEqualType 0','finite _executor',
                      '_executor < 0','completedFSM _executor','["pending",false]','["completed",true]'):
            self.assertIn(proof,gate)
        for mutation in ('["cancelled",true]','["finished",true]','execFSM','deadline','remoteExec'):
            self.assertNotIn(mutation,gate)
        reuse=start[start.index('private _current='):start.index('if (count _current > 0) then')]
        self.assertIn('!completedFSM _handle',reuse)
        self.assertIn('"executorRestarts",1',reuse)
        self.assertNotIn('CBE_fnc_FlightLeaseAcquire',reuse)
        self.assertNotIn('["nextAt",time',reuse)
        self.assertNotIn('["pending",false]',reuse)
        self.assertIn('FSM_RESTART_EXHAUSTED',reuse)
        self.assertIn('FSM_START_FAILED',start)
        self.assertIn('CBE_AirAttack_Brain_FSM',discover)
        self.assertIn('private _sameJob=_job isEqualTo _originalJob',reuse)
        self.assertIn('if (!_workerAlive && {_sameJob} && {!_originalContext}) exitWith',reuse)
        self.assertIn('(_sameJob || {!isNull _requestedTarget',reuse)
        self.assertIn('FSM_RESTART_CONTEXT_LOST',reuse)
        self.assertIn('FSM_RESTART_CONTEXT_LOST',attack)
        self.assertIn('if (isNull _group && {!_alive} && {count _current > 0}',reuse)
        self.assertIn('_job isEqualTo (_current getOrDefault ["job",createHashMap])',reuse)
        self.assertLess(reuse.index('FSM_RESTART_CONTEXT_LOST'),reuse.index('if (!_sameRequest'))
        self.assertIn('[_airBrain getOrDefault ["job",createHashMap],0]',discover)
        failure=attack[attack.index('if (_executorFailure != "")'):attack.index('private _pilot=driver')]
        self.assertIn('isNotEqualTo _job',failure)
        self.assertIn('"cancelReason"',failure)
        self.assertIn('[_executorFailure,true] call _finish',failure)
        self.assertIn('getForcedSpeed _aircraft',attack)
        self.assertIn('_aircraft forceSpeed (_restoreSpeed select 1)',attack)
        self.assertIn('"PILOT_CHANGED",true',attack)
        self.assertIn('"NATIVE_SPEED_CHANGED"',attack)
        self.assertIn('if (_resume && {_ownsFlight}',attack)
        speed_cleanup=attack[attack.index('private _restoreSpeed='):attack.index('// Remove exactly the lease-owned waypoint')]
        self.assertIn('if (_ownsFlight',speed_cleanup)
        self.assertIn('getForcedSpeed _aircraft',speed_cleanup)
        self.assertNotIn('driver _aircraft == (_restoreSpeed select 0)',speed_cleanup)
        self.assertIn('_appliedSpeed min _originalSpeed',attack)
        self.assertIn('(_stageSpeeds select _stageIndex)/3.6',attack)
        self.assertNotIn('_aircraft limitSpeed',attack)
        self.assertLess(attack.index('_job set ["forcedSpeedReceipt",'),attack.index('_aircraft forceSpeed _appliedSpeed;'))
        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_fnc_AirAttackOperationStep',queue)
        self.assertIn('call CBE_fnc_CortexAirAttack',step)
        self.assertIn('CBE_AirAttack_BrainGeneration',start+queue+step+fsm)
        self.assertIn('current caller: cbe_fnc_airattackoperationstep',attack.lower())
        for state in ['Plan','Ingress','Attack','Egress']:
            self.assertIn('class '+state,fsm)
        self.assertIn('CBE_fnc_CortexZeusHeld',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('call CBE_fnc_CortexAirAttack',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('CBE_AirAttack_Brain_State',diagnostics)
        stop=source('cortexStop')
        self.assertIn('CBE_AirAttack_Brain',stop)
        self.assertIn('"CORTEX_STOPPED"',stop)
        self.assertIn('call CBE_fnc_CortexAirAttack',stop)
        self.assertIn('CBE_AirAttack_BrainGeneration',stop)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_artillery_mission_fsm_owns_fire_sequence_persistence(self):
        fire=source('cortexArtilleryFire');bounded=source('cortexArtilleryMissionStep')
        start=source('artilleryMissionStart');queue=source('artilleryMissionQueue');step=source('artilleryMissionStep')
        stop=source('cortexStop');diagnostics=source('aiGetDiagnostics')
        fsm=(ROOT/'addons/main/fsm/artilleryMission.fsm').read_text(encoding='utf-8')
        admission=fire.split('// Validate before range/aim planning',1)[1].split('private _missions =',1)[0]
        for proof in ('count _target in [2,3]','!finite _x','!finite _error','!finite _rounds','!finite _scoot'):
            self.assertIn(proof,admission)
        self.assertLess(fire.index('!finite _error'),fire.index('private _serial ='))
        shot=source('cortexArtilleryShot')
        geometry=shot.split('// Malformed geometry',1)[1].split('private _signature=',1)[0]
        for proof in ('_aim isEqualType []','count _aim in [2,3]','!finite _x','exitWith {false}'):
            self.assertIn(proof,geometry)
        self.assertNotIn('setVariable',geometry)
        self.assertIn('CBE_fnc_ArtilleryMissionStart',fire)
        self.assertNotIn('[CBE_fnc_CortexArtilleryMissionStep, _mission, 0]',fire)
        self.assertIn('artilleryMission.fsm',start)
        gate=step.split('private _executor=',1)[1].split('private _semantic=',1)[0]
        for proof in ('CBE_Artillery_Brain_FSM','_executor isEqualType 0','finite _executor',
                      '_executor < 0','completedFSM _executor','["pending",false]','["completed",true]'):
            self.assertIn(proof,gate)
        for mutation in ('["cancelled",true]','["finished",true]','execFSM','deadline','remoteExec'):
            self.assertNotIn(mutation,gate)
        reuse=start[start.index('private _current='):start.index('if (count _current > 0) then')]
        self.assertIn('!completedFSM _handle',reuse)
        self.assertIn('"executorRestarts",1',reuse)
        self.assertIn('FSM_RESTART_EXHAUSTED',reuse)
        self.assertNotIn('["nextAt",time',reuse)
        self.assertNotIn('["pending",false]',reuse)
        self.assertIn('FSM_START_FAILED',start)
        self.assertIn('"executorFailure",_failure',start)
        failed=bounded[bounded.index('if ((_mission getOrDefault ["executorFailure"'):bounded.index('if ((_mission get "phase") in ["PENDING", "UNCERTAIN"]')]
        self.assertIn('["remaining",0]',failed)
        self.assertIn('["burstsLeft",0]',failed)
        self.assertIn('["parked",true]',failed)
        self.assertNotIn('CBE_fnc_CortexArtilleryShot',failed)
        self.assertNotIn('["deadline",',failed)
        self.assertIn('_fireBrain getOrDefault ["mission",createHashMap]',source('cortexDiscover'))

        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_fnc_ArtilleryMissionStep',queue)
        self.assertIn('call CBE_fnc_CortexArtilleryMissionStep',step)
        self.assertIn('CBE_AIPass_FireMissions',start+step)
        self.assertIn('CBE_Artillery_BrainGeneration',start+queue+step+fsm)
        self.assertIn('no fire command is retried',step.lower())
        self.assertIn('current caller: cbe_fnc_artillerymissionstep',bounded.lower())
        for state in ['Requested','Warning','Firing','Relocating']:
            self.assertIn('class '+state,fsm)
        self.assertIn('CBE_Artillery_Brain',stop)
        self.assertIn('wait-artillery-fsm-',diagnostics)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_support_request_fsm_owns_cross_squad_persistence(self):
        server=source('cortexSupportServer');bounded=source('cortexSupportStep')
        start=source('supportRequestStart');queue=source('supportRequestQueue');step=source('supportRequestStep')
        stop=source('cortexStop');diagnostics=source('aiGetDiagnostics')
        fsm=(ROOT/'addons/main/fsm/supportRequest.fsm').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_SupportRequestStart',server)
        self.assertNotIn('[CBE_fnc_CortexSupportStep,_job,1]',server)
        self.assertIn('supportRequest.fsm',start)
        gate=step.split('private _executor=',1)[1].split('private _delay=',1)[0]
        for proof in ('CBE_Support_Brain_FSM','_executor isEqualType 0','finite _executor',
                      '_executor < 0','completedFSM _executor','["pending",false]','["completed",true]'):
            self.assertIn(proof,gate)
        for mutation in ('["cancelled",true]','["finished",true]','execFSM','deadline','remoteExec'):
            self.assertNotIn(mutation,gate)
        reuse=start[start.index('private _current='):start.index('if (count _current > 0) then')]
        self.assertIn('!completedFSM _handle',reuse)
        self.assertIn('"executorRestarts",1',reuse)
        self.assertIn('FSM_RESTART_EXHAUSTED',reuse)
        self.assertNotIn('["nextAt",time',reuse)
        self.assertNotIn('["pending",false]',reuse)
        self.assertIn('FSM_START_FAILED',start)
        self.assertIn('"executorFailure",_failure',start)
        self.assertIn('(_job getOrDefault ["executorFailure",""]) == ""',bounded)
        self.assertIn('_supportBrain getOrDefault ["job",createHashMap]',source('cortexDiscover'))

        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_fnc_SupportRequestStep',queue)
        self.assertIn('call CBE_fnc_CortexSupportStep',step)
        self.assertIn('CBE_AIPass_SupportRequests',start+step)
        self.assertIn('CBE_Support_BrainGeneration',start+queue+step+fsm)
        self.assertIn('current caller: cbe_fnc_supportrequeststep',bounded.lower())
        for state in ['Discover','Reserve','Coordinate']:
            self.assertIn('class '+state,fsm)
        self.assertIn('CBE_Support_Brain',stop)
        self.assertIn('wait-support-fsm-',diagnostics)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('CBE_fnc_CortexZeusHeld',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('call CBE_fnc_CortexSupportStep',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_aircraft_controllers_share_one_generation_owned_flight_lease(self):
        acquire=source('flightLeaseAcquire');valid=source('flightLeaseValid');release=source('flightLeaseRelease')
        attack_start=source('airAttackOperationStart');attack=source('cortexAirAttack')
        expiry=attack.index('if (_stage != "" && {serverTime > (_job getOrDefault ["deadline",-1])}) exitWith')
        for mutation in ('private _mayControlAircraft = {','private _commandedStage=',
                         '_operator doFire _fireTarget','_aircraft fireAtTarget [_fireTarget,_weapon]'):
            self.assertLess(expiry,attack.index(mutation))
        permission=attack.split('private _mayControlAircraft = {',1)[1].split('private _liveSpeedReceipt=',1)[0]
        self.assertIn('_stage == "" || {serverTime <= (_job getOrDefault ["deadline",-1])}',permission)
        landing=source('improvedHelicopterLandingExecuteLocal');landing_release=source('improvedHelicopterLandingRestoreLocal')
        landing_anchor=source('improvedHelicopterLandingAnchorLocal')
        defence=source('cortexMissileDefenceStep');deceleration=source('helicopterDecelerationCorrectLocal')
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('CBE_FlightLease',acquire+valid+release)
        self.assertIn('CBE_fnc_CortexZeusHeld',acquire)
        self.assertIn('CBE_fnc_CortexExternalTakeover',acquire)
        self.assertIn('_priority <= (_lease getOrDefault ["priority",0])',acquire)
        self.assertIn('(_lease getOrDefault ["owner",-1]) != clientOwner',acquire)
        self.assertIn('"AIR_ATTACK",_leaseToken,300',attack_start)
        self.assertIn('"AIR_ATTACK",_flightLeaseToken',attack)
        self.assertIn('"LANDING",_flightLeaseToken,500',landing)
        self.assertIn('"LANDING",str _releasedRevision',landing_release)
        self.assertIn('"LANDING",str _controlRevision',landing_anchor)
        self.assertIn('"MISSILE_DEFENCE",_flightLeaseToken,400',defence)
        self.assertIn('"DECELERATION",_flightLeaseToken,100',deceleration)
        self.assertIn('wait-flight-lease-',diagnostics)

    def test_scheduler_diagnostics_clear_transient_skip_state_after_resumption(self):
        scheduler=source('cortexSchedulerTick')
        self.assertIn('_state set ["skippedReason","PAUSED"]',scheduler)
        self.assertIn('_state deleteAt "skippedReason"',scheduler)
        self.assertLess(scheduler.index('_state set ["skippedReason","PAUSED"]'),scheduler.index('_state deleteAt "skippedReason"'))

    def test_danger_observations_preserve_one_tactical_owner(self):
        engine=source('dangerEngineSubmit')
        engine_act=source('dangerEngineAct')
        engine_continue=source('dangerEngineCanContinue')
        engine_release=source('dangerEngineRelease')
        engine_recycle=source('dangerEngineRecycle')
        vehicle_profile=source('dangerVehicleProfile')
        engine_mode=source('dangerEngineMode')
        engine_select=source('dangerEngineSelect')
        memory=source('dangerStep')
        self.assertIn('_cause == "BODY_FOUND" && {_action == "HIDE"}',memory)
        self.assertIn('_observedServer+20',memory)
        self.assertIn('_observedServer+60',memory)
        self.assertIn('if (!_repeat',memory)
        calm=source('cortexGroupTick').split('case "CALM": {',1)[1].split('case "INVESTIGATE": {',1)[0]
        self.assertGreater(calm.index('CBE_fnc_IndoorObservationDispatch'),calm.index('"KNOWN_CONTACT"'))
        self.assertIn('(_state get "phase") == "CALM"',calm)
        self.assertIn('"CBE_Danger_BuildingClueSeen",nil,true',source('cortexStop'))

        point=source('pointActorOperation')
        start=point.split('if (_mode == "START") exitWith {',1)[1].split('private _current=',1)[0]
        for guard in ('CBE_fnc_CasualtyObservationSelect','currentCommand _actor != ""',
                      'CortexActorMoveReserved','CBE_PointActor_After','_route select 1','serverTime+12'):
            self.assertIn(guard,start)
        identity=source('casualtyObservationSelect')
        for guard in ('select [0,8]','_this distance2D _observed <= 3','group _this == _group || {_this in _known}',
                      'count _candidates == 1','(_x select 2) <= (_x select 1)+300','!alive'):
            self.assertIn(guard,identity)
        for forbidden in ('allDeadMen','nearestObjects','doMove','setVariable'):
            self.assertNotIn(forbidden,identity)
        capture=source('cortexInit').split('addMissionEventHandler ["EntityKilled"',1)[1].split('CBE_fnc_CortexRegroupOnKill',1)[0]
        for guard in ('!local _group','select [0,8]','count _casualties >= 8','serverTime+300','findIf {(_x select 0) == _unit} < 0'):
            self.assertIn(guard,capture)
        self.assertIn('"CBE_Danger_Casualties",nil,true',source('cortexStop'))
        self.assertEqual(point.count('["deadline",_deadline]'),1)
        step=point.split('if (_mode != "STEP") exitWith',1)[1]
        self.assertLess(step.index('completedFSM _handle'),step.index('_actor doMove'))
        self.assertLess(step.index('"requestAt",serverTime'),step.index('_actor doMove'))
        self.assertLess(step.index('_actor doMove'),step.index('_order set [8,true]'))
        for guard in ('serverTime-(_brain get "requestAt") < 2','expectedDestination _actor',
                      'formLeader _actor isEqualTo','vectorDistance (_brain get "goalASL") <= 2',
                      'lineIntersects','"NO_PROGRESS"','"BODY_CHANGED"'):
            self.assertIn(guard,step)
        finish=point.split('if (_mode in ["FINISH","TRANSFER"]) exitWith {',1)[1].split('if (_mode == "START")',1)[0]
        for guard in ('"CANCEL_PENDING"','_reservation isEqualTo _lease','_destination vectorDistance _target <= 0.25',
                      '_route isEqualTo','CortexExternalTakeover','_issued'):
            self.assertIn(guard,finish if guard != 'CortexExternalTakeover' else point)
        self.assertIn('serverTime < _deadline+30',finish)
        self.assertIn('formLeader _actor isEqualTo (_before select 2)',finish)
        self.assertIn('_actor doFollow _returnLeader',finish)
        self.assertNotIn('_actor doFollow leader _group',finish)
        for forbidden in ('allDeadMen','nearestObjects','setPos','addBackpack','rearm','reveal '):
            # Ignore documentation: this task never copies inventory or global discovery shortcuts.
            self.assertNotIn(forbidden,re.sub(r'/\*.*?\*/|//[^\n]*','',point,flags=re.S))
        point_fsm=(ROOT/'addons/main/fsm/pointActor.fsm').read_text()
        pickup=step.split('// Native TakeMagazine',1)[1].split('["VISITED"] call _finish',1)[0]
        for proof in ('CBE_AIPass_AmmoShare_Enable','CortexPrimaryAmmoAvailable',
                      'uniformContainer _body,vestContainer _body,backpackContainer _body',
                      'select [0,128]','_actor canAdd','magazinesAmmoFull _actor',
                      '_gain > 0 && {_gain == _removed}','["UNVERIFIED","VERIFIED"]'):
            self.assertIn(proof,pickup)
        self.assertEqual(pickup.count('action ["TakeMagazine"'),1)
        self.assertIn('count _cargo > 128',pickup)
        self.assertIn('count _rows > 128',pickup)
        self.assertLess(pickup.index('if (_before >= 0)'),pickup.index('action ["TakeMagazine"'))
        self.assertIn('_receiverAfter >= 0 && {_sourceAfter >= 0}',pickup)

        self.assertIn('[_generation,"NOT_ATTEMPTED",_body,"",0,serverTime]',start)
        self.assertLess(pickup.index('(getPosASL _actor) vectorDistance (getPosASL _body) <= 2'),
                        pickup.index('action ["TakeMagazine"'))
        self.assertIn('eyePos _actor,(getPosASL _body) vectorAdd',pickup)

        self.assertLess(step.index('lineIntersects'),step.index('action ["TakeMagazine"'))
        for forbidden in ('addMagazine','removeMagazine','CancelAction','addBackpack','setUnitLoadout'):
            self.assertNotIn(forbidden,pickup)
        def verified(gain,removed,same_weapon=True):
            return gain>0 and gain==removed and same_weapon
        self.assertTrue(verified(7,7))
        for args in ((0,0),(7,0),(7,30),(7,7,False)):
            self.assertFalse(verified(*args))
        equipment=source('casualtyWeaponRecover')
        self.assertEqual(equipment.count('action ["TakeWeapon"'),1)
        self.assertIn('CBE_fnc_CasualtyWeaponRecover',pickup)
        self.assertLess(equipment.index('distance (getPosASL _body) > 2'),equipment.index('action ["TakeWeapon"'))
        for invariant in ('_primary == ""','_secondary == ""','count _row == 7',
                          'count _receiverAfter == count _receiverBefore+1',
                          'count _sourceAfter == count _sourceBefore-1',
                          '[_sourceOthers,_sourceAfter] call _sameRows','[_expectedReceiver,_receiverAfter] call _sameRows',
                          '"weaponRecoveryAttempted",true','"deadline",-1'):
            self.assertIn(invariant,equipment)
        for forbidden in ('addWeapon','removeWeapon','setUnitLoadout','spawn','waitUntil','nearestObjects'):
            self.assertNotIn(forbidden,re.sub(r'/\*.*?\*/|//[^\n]*','',equipment,flags=re.S))
        def same_rows(expected, actual):
            remaining=list(actual)
            for row in expected:
                if row not in remaining:
                    return False
                remaining.remove(row)
            return not remaining
        self.assertTrue(same_rows(['rifle','rifle','launcher'],['launcher','rifle','rifle']))
        self.assertFalse(same_rows(['rifle','rifle','launcher'],['rifle','pistol','launcher']))
        self.assertIn('_remaining deleteAt _index',equipment)
        self.assertIn('CBE_fnc_PointActorOperation',point_fsm)
        self.assertIn('serverTime >=',point_fsm)
        for name in ('cortexLocality','cortexStop','cortexDiscover'):
            self.assertIn('CBE_fnc_PointActorOperation',source(name))
        self.assertIn('_cause == 5',engine_act)
        self.assertIn('CBE_fnc_PointActorOperation',engine_act)

        for intake in (engine_select,engine,source('dangerRequest'),source('dangerSelect')):
            self.assertIn('!finite _x',intake)
        for intake in (engine_select,engine):
            self.assertIn('_cause == floor _cause',intake)
            self.assertLess(intake.index('_cause == floor _cause'),intake.index('select _cause'))
        self.assertIn('finite _expiry',engine_select)
        self.assertIn('finite _expires',engine)
        for guard in ('finite _now','finite _created','finite _expires'):
            self.assertIn(guard,source('dangerSelect'))

        danger_cover=source('dangerCoverStep')
        danger_smoke=source('dangerSmokeStep')
        engine_fsm=(ROOT/'addons/danger/danger.fsm').read_text()
        # fsmDanger is loaded directly by the engine rather than through execFSM. The Arma FSM
        # compiler requires the named scripted-FSM envelope; a bare class parses as config text
        # during packaging but produces "FSM ... cannot be loaded" at runtime.
        self.assertTrue(engine_fsm.startswith('/*%FSM<COMPILE "scriptedFSM.cfg, Danger">*/'))
        self.assertTrue(engine_fsm.rstrip().endswith('/*%FSM</COMPILE>*/'))
        self.assertIn('/*%FSM<HEAD>*/',engine_fsm)
        self.assertRegex(engine_fsm,r'item0\[\]\s*=\s*\{"Start_Danger",0,250')
        self.assertRegex(engine_fsm,r'link44\[\]\s*=\s*\{38,39\};')
        self.assertRegex(engine_fsm,r'link45\[\]\s*=\s*\{41,40\};')
        self.assertIn('/*%FSM<STATE "Start_Danger">*/',engine_fsm)
        self.assertIn('/*%FSM<STATEINIT',engine_fsm)
        self.assertIn('/*%FSM<CONDITION',engine_fsm)
        runtime_fsm=engine_fsm.split('class FSM',1)[1]
        self.assertEqual(43,len(re.findall(r'\bitemno\s*=\s*\d+;',runtime_fsm)))
        self.assertEqual(43,len(re.findall(r'\bprecondition\s*=',runtime_fsm)))
        editor_items=[int(value) for value in re.findall(r'item(\d+)\[\]\s*=',engine_fsm.split('class FSM',1)[0])]
        self.assertEqual(list(range(43)),editor_items)
        editor_link_ids=[int(value) for value in re.findall(r'link(\d+)\[\]\s*=',engine_fsm.split('class FSM',1)[0])]
        self.assertEqual(list(range(48)),editor_link_ids)
        editor_links=[tuple(map(int,values)) for values in re.findall(r'link\d+\[\]\s*=\s*\{(\d+),(\d+)\}',engine_fsm.split('class FSM',1)[0])]
        self.assertTrue(editor_links)
        self.assertTrue(all(source_id in editor_items and target_id in editor_items for source_id,target_id in editor_links))
        launcher=source('dangerRequest')
        current=launcher.split('private _running=',1)[1].split('private _generation=',1)[0]
        for proof in ('_running isEqualType []','isEqualType 0','finite (_running select 2)',
                      '(_running select 2) >= 0','floor (_running select 2)'):
            self.assertLess(current.index(proof),current.index('completedFSM'))
        self.assertLess(launcher.index('CBE_Danger_FSMFailure'),launcher.index('execFSM'))
        start=launcher.split('private _fsm=',1)[1]
        for proof in ('_fsm isEqualType 0','finite _fsm','_fsm < 0','_fsm != floor _fsm'):
            self.assertLess(start.index(proof),start.index('completedFSM'))
        self.assertIn('if (!completedFSM _fsm) then',start)
        self.assertIn('["CBE_Danger_FSMFailure",[_epoch,_generation,serverTime]]',start)
        self.assertIn('["CBE_Danger_FSMFailure",nil]',source('dangerSetup'))
        engine_source=(ROOT/'tools/fsm/danger.bifsm').read_text()
        self.assertIn('InitCode=',engine_source)
        self.assertIn('Condition=',engine_source)
        # Editing/exporting the graph must preserve actual runtime intake and exit code.
        editable={int(m[1]):m[2] for m in re.finditer(
            r'\tclass Item(\d+)\s*\n(.*?)(?=\n\tclass Item\d+|\n};\nclass GraphLinks)',engine_source,re.S)}
        for item in re.finditer(r'itemno\s*=\s*(\d+);(.*?)(?=\bitemno\s*=|\Z)',runtime_fsm,re.S):
            for field,editor_field in [('init','InitCode'),('condition','Condition')]:
                code=re.search(r'\b'+field+r'\s*=\s*/\*.*?\*/\s*("(?:""|[^"])*")\s*/\*',item[2],re.S)
                if code:
                    self.assertIn(editor_field+'='+code[1]+';',editable[int(item[1])])

        request=source('dangerRequest')
        step=source('dangerStep')
        selection=source('dangerSelect')
        action=source('dangerActionSelect')
        setup=source('dangerSetup')
        scheduler=source('cortexSchedulerTick')
        contact_fixture=(Path(__file__).parent/'cortexQA/runContact.sqf').read_text(encoding='utf-8')
        danger_load=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDangerLoad.sqf').read_text(encoding='utf-8')
        server_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('_focus == "dangerload"',server_audit)
        self.assertIn('cortexQADangerLoad.sqf',server_audit)
        self.assertIn('DANGERLOAD-engine-event-accepted',danger_load)
        self.assertIn('DANGERLOAD-physical-reflex',danger_load)
        self.assertIn('DANGERLOAD-finite-exact-release',danger_load)
        self.assertIn('createVehicle ["GrenadeHand"',danger_load)
        self.assertNotIn('CBE_fnc_DangerEngineSubmit',danger_load)
        self.assertIn('_holdUnits findIf {(_x getVariable ["CBE_CortexQA_Shots",0]) > 0} >= 0',contact_fixture)
        self.assertNotIn('{{_x getVariable ["CBE_CortexQA_Shots",0]} count _holdUnits > 0}',contact_fixture)
        self.assertIn('!local _group',request)
        self.assertIn('{local _group}',setup)
        self.assertIn('select [((count _events)-16) max 0,16]',request)
        self.assertIn('_actor getVariable ["CBE_Danger_EventCadence"',request)
        self.assertIn('(_x param [5,objNull,[objNull]]) == _actor',request)
        self.assertIn('select [0,16]',selection)
        self.assertIn('_expires > _now',selection)
        self.assertNotIn(' sort ',selection)
        self.assertIn('CBE_GroupBrain',step)
        self.assertIn('_brain set ["wakeAt",time]',step)
        self.assertIn('_brain set ["nextAt",time]',step)
        self.assertIn('private _effectiveResponse=_group getVariable ["CBE_Danger_Response",[]]',step)
        self.assertIn('_effectiveResponse select 3',step)
        self.assertIn('_brain set ["responsiveUntil",_responsiveUntil max (_brain getOrDefault ["responsiveUntil",0])]',step)
        self.assertNotIn('_brain set ["responsiveUntil",time+_responseLifetime]',step)
        tail=step.split('// A group retains one movement/decision owner.',1)[1]
        self.assertLess(tail.index('_brain set ["responsiveUntil"'),tail.index('if (time >= (_group getVariable ["CBE_Danger_WakeAfter"'))
        self.assertLess(tail.index('if (time >= (_group getVariable ["CBE_Danger_WakeAfter"'),tail.index('_brain set ["wakeAt"'))
        self.assertIn('CBE_fnc_GroupBrainStart',step)
        self.assertIn('[_group,false] call CBE_fnc_GroupBrainStart',step)
        starter=source('groupBrainStart')
        reuse=starter.split('private _existingHandle=',1)[1].split('private _generation=',1)[0]
        for proof in ('CBE_GroupBrain_Generation','_existingHandle isEqualType 0',
                      '_existingHandle >= 0','!completedFSM _existingHandle'):
            self.assertIn(proof,reuse)
        self.assertIn('_state deleteAt "wakeAt"',scheduler)
        self.assertIn('getOrDefault ["wakeAt",_dueAt]',scheduler)
        self.assertIn('getOrDefault ["responsiveUntil",-1]',scheduler)
        for body in [engine,engine_act,engine_continue,engine_mode,engine_select,request,step,selection,setup]:
            body=re.sub(r"/\*.*?\*/|//[^\n]*", "", body, flags=re.DOTALL)
            for forbidden in [' reveal ', ' doMove ', ' doTarget ', 'allUnits', 'allGroups', 'CortexQueueJob']:
                self.assertNotIn(forbidden,body)
        self.assertIn('ownerEpoch',step)
        self.assertIn('CBE_Danger_Generation',step)
        self.assertIn('CBE_Danger_Response',step)
        self.assertIn('CBE_Danger_Action',step)
        self.assertIn('CBE_Danger_VehicleContext',step)
        self.assertIn('CBE_fnc_DangerVehicleProfile',step)
        self.assertIn('CBE_fnc_DangerSmokeStep',source('cortexGroupTick'))
        for marker in ['CBE_AIPass_DangerSmoke_Enable','CBE_Danger_SmokeLease','CBE_Danger_SmokeAfter',
                       'getSuppression _x >= 0.55','["DANGER",_generation,_expires]',
                       'call CBE_fnc_CortexThrowGrenade']:
            self.assertIn(marker,danger_smoke)
        self.assertIn('private _screenThreat=+_contact;',danger_smoke)
        self.assertNotIn('private _screenThreat=+_threat;',danger_smoke)
        self.assertIn('if (!(_state getOrDefault ["contactKnowledge",false]) || {count _contact < 2}) exitWith {false};',danger_smoke)
        self.assertNotIn('sleep ',danger_smoke)
        self.assertNotIn('waitUntil',danger_smoke)
        throw=source('cortexThrowGrenade')
        aim=throw.split('private _alignAdmitted=false;',1)[1].split('private _bearing =',1)[0]
        self.assertIn('["_aimIssued",false,[true]]',throw)
        self.assertLess(aim.index('if (!_aimIssued)'),aim.index('_unit doWatch _towards'))
        self.assertLess(aim.index('_unit doWatch _towards'),aim.index('_this set [16,true]'))
        self.assertIn('[_retry,+_this,0.25]',throw)
        self.assertEqual(throw.count('_unit doWatch _towards'),1)

        queued=throw.split('params ["_unit", "_muzzle", "_magazine"',1)[1]
        for marker in ['CBE_AIPass_DangerSmoke_Enable','CBE_Danger_Generation','CBE_fnc_CortexExternalTakeover']:
            self.assertIn(marker,queued)
        self.assertLess(queued.index('CBE_Danger_Generation'),queued.index('forceWeaponFire'))
        self.assertNotIn('_unit setDir', queued)
        self.assertIn('private _aim = eyeDirection _unit',queued)
        self.assertIn('_bodyError > 30 || {_aimError > 30}', queued)
        self.assertIn('time >= _expires', queued)
        self.assertIn('[_retry,+_this,0.25] call CBA_fnc_waitAndExecute', queued)
        self.assertIn('time+1.5,_release,_throwGeneration', queued)
        self.assertIn('CBE_OperationGeneration',queued)
        drill_reserves=source('cortexFlankStep').split('private _rankCandidates={',1)[1].split('private _anchor=',1)[0]
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',drill_reserves)
        self.assertIn('CBE_fnc_CompatibilityExternalControl',drill_reserves)
        self.assertIn('currentCommand _x',drill_reserves)
        flight_authority=source('flightLeaseValid')
        self.assertIn('[_pilot] call CBE_fnc_CortexCombatEffective',flight_authority)
        release_boundary=source('operationRelease')
        self.assertIn('[_group,_generation,_handoverReason] call CBE_fnc_OperationCancel',release_boundary)
        self.assertLess(release_boundary.index('CBE_fnc_CortexExternalTakeover'),release_boundary.index('CBE_OperationResult'))
        recovery=source('recoveryStep')
        self.assertIn('group _actor != _group',recovery)
        self.assertIn('max (_used getOrDefault [_key,0])',recovery)
        self.assertIn('_currentOperation set ["recoveryAttempts",_used]',recovery)
        self.assertIn('_actor in (_currentOperation getOrDefault ["participants",[]])',recovery)
        self.assertLess(recovery.index('currentCommand _actor'),recovery.index('_recovery set [_key'))
        reposition_retry=source('cortexGroupTick').split('private _stuck=_members findIf {',1)[1].split('if (_stuck >= 0)',1)[0]
        self.assertIn('currentCommand _x in ["","MOVE","ATTACK","FIRE","SUPPRESS"]',reposition_retry)
        self.assertNotIn('"SUPPRESS","STOP"',reposition_retry)
        withdrawal_retry=source('cortexGroupTick').split('private _straggler=(_operation getOrDefault ["participants",[]]) findIf {',1)[1].split('if (_straggler >= 0)',1)[0]
        self.assertIn('toUpperANSI currentCommand _x != "STOP"',withdrawal_retry)
        support_handoff=source('cortexStaticSupport').split('if (count _lease >= 7) exitWith',1)[1].split('if (_leaseEpisode',1)[0]
        self.assertIn('_actor in (_operation getOrDefault ["participants",[]])',support_handoff)
        self.assertIn('[true] call _release',support_handoff)
        building_reserves=source('buildingOperationStep')
        self.assertIn('private _reserves=(units _group) select {[_x] call _reserveReady};',building_reserves)
        self.assertNotIn('&& {_x != _leader}',building_reserves.split('private _reserves=',1)[1].split('// Rotate the bounded service window',1)[0])
        self.assertIn('!(_candidate in _rotatedOut)',building_reserves)
        self.assertIn('[_member] call _actorAvailable',building_reserves)
        self.assertIn('[_actor] call CBE_fnc_CortexCombatEffective',source('buildingOperationStep'))
        roles=source('rebalanceRoles')
        self.assertIn('CBE_fnc_CortexCombatEffective',roles)
        self.assertIn('CBE_fnc_CompatibilityExternalControl',roles)
        self.assertIn('&& {_reservationFree}',roles)
        self.assertNotIn('_x in _existing ||',roles)
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',roles)
        self.assertNotIn('(_reservation param [2,1e12,[0]]) <= time',drill_reserves)
        remnant=source('cortexRegroupStep')
        self.assertIn('count (_group getVariable ["CBE_Operation",createHashMap]) > 0',remnant)
        self.assertIn('!(_x in _participants)',remnant)
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',remnant)
        grenade_diagnostics=source('aiGetDiagnostics')
        self.assertIn('wait-grenade-decisions-%1',grenade_diagnostics)
        self.assertIn('CBE_Cortex_ThrowDecision',grenade_diagnostics)
        self.assertIn('((units _group) select [0,8])',grenade_diagnostics)
        self.assertIn('CBE_AIPass_Epoch',queued)
        self.assertIn('currentCommand _unit in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]',queued)
        self.assertLess(queued.index('["NEW_TASK",'),queued.index('_unit doWatch'))
        for guard in ('simulationEnabled _unit','isObjectHidden _unit','ace_medical_ai_healQueue'):
            self.assertIn(guard,queued)
            self.assertGreaterEqual(throw.count(guard),3)
        self.assertLess(queued.index('["ACTOR_UNAVAILABLE"]'),queued.index('_unit doWatch'))
        self.assertLess(queued.index('["ACTOR_UNAVAILABLE"]'),queued.index('_unit forceWeaponFire'))
        self.assertNotIn('setVariable ["ace_medical_ai_healQueue"',queued)
        smoke=source('dangerSmokeStep')
        for guard in ('simulationEnabled _actor','!isObjectHidden _actor','ace_medical_ai_healQueue'):
            self.assertIn(guard,smoke.split('private _actorAvailable=',1)[1].split('private _members=',1)[0])

        throw_qa=(Path(__file__).parent/'cortexQA/runContact.sqf').read_text(encoding='utf-8')
        self.assertIn('GRENADE-direction-%1-%2-%3',throw_qa)
        self.assertIn('[_throwActor,_destination,_kind] call CBE_fnc_CortexThrowGrenade',throw_qa)
        self.assertIn('_label+"-owner-ready"',throw_qa)
        self.assertIn('vectorDotProduct (vectorNormalized _target)',throw_qa)
        self.assertIn('(_evidence select 0) >= 0.866',throw_qa)
        self.assertLess(queued.index('CBE_Cortex_ThrowGeneration'), queued.index('_unit doWatch'))
        self.assertLess(queued.index('_bodyError > 30'), queued.index('forceWeaponFire'))
        self.assertLess(queued.index('CBE_Danger_Generation'),queued.index('_unit doWatch'))
        self.assertLess(queued.index('CBE_fnc_CortexExternalTakeover'),queued.index('_unit doWatch'))
        self.assertIn('CBE_fnc_DangerActionSelect',step)
        self.assertIn('private _actor=[_group] call CBE_fnc_CortexGroupAnchor;',step)
        self.assertIn('[_observer,_cause,_position,_action,_response select 3] call CBE_fnc_DangerReact',step)
        self.assertIn('time+_responseLifetime',step)
        self.assertIn('time >= (_existing select 3)',step)
        self.assertIn('if (_action == "FORCED") exitWith {',step)
        forced_handoff=step.split('if (_action == "FORCED") exitWith {',1)[1].split('// This is a finite handoff',1)[0]
        self.assertIn('if (_anotherWitness) exitWith {0.25}',forced_handoff)
        self.assertIn('(_retainedAction param [5,objNull,[objNull]]) != _observer',forced_handoff)
        self.assertIn('CBE_Danger_Response",nil,true',forced_handoff)
        self.assertIn('CBE_Danger_Action",nil,true',forced_handoff)
        self.assertIn('deleteAt "responsiveUntil"',forced_handoff)
        self.assertNotIn('CBE_fnc_GroupBrainStart',forced_handoff)
        self.assertNotIn('set ["wakeAt"',forced_handoff)
        self.assertLess(step.index('if (_action == "FORCED") exitWith {'),step.index('private _responseDurations='))
        tick=source('cortexGroupTick')
        self.assertIn('private _dangerTactical=_dangerActive',tick)
        self.assertIn('_responseCause in ["HIT","EXPLOSION","SUPPRESSED"]',tick)
        self.assertIn('_responseCause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {_dangerActionName != "HIDE"}',tick)
        self.assertIn('(_dangerResponse param [0,"",[""]]) in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {_dangerActionName == "HIDE"}',tick)
        self.assertIn('private _selectedIndex=_events findIf {_x isEqualTo _selected};',step)
        self.assertIn('_events deleteAt _selectedIndex',step)
        self.assertIn('_group setVariable ["CBE_Danger_Events",_remaining];',step)
        self.assertLess(step.index('private _selected=[_events] call CBE_fnc_DangerSelect;'),step.index('private _selectedIndex=_events findIf {_x isEqualTo _selected};'))
        self.assertIn('private _activeAction=_group getVariable ["CBE_Danger_Action",[]];',step)
        self.assertIn('(_activeAction param [4,-1,[0]]) == _generation',step)
        self.assertIn('_activeAction param [5,_actor,[objNull]]',step)
        self.assertLess(step.index('private _activeAction=_group getVariable ["CBE_Danger_Action",[]];'),step.index('private _responseCommand=toUpperANSI (currentCommand _responseActor);'))
        self.assertIn('in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"]',tick)
        self.assertIn('_cause in [1,2,4,9]',engine_act)
        self.assertIn('private _dangerAlert=_dangerActive',tick)
        self.assertIn('in ["CASUALTY","BODY_FOUND","SCREAM"]',tick)
        self.assertIn('private _stealthCover=_dangerActionName == "ENGAGE"',tick)
        self.assertIn('unitCombatMode _dangerCoverActor in ["BLUE","GREEN"]',tick)
        self.assertIn('(_dangerActionName == "HIDE" && {_physicalCoverCause}) || {_stealthCover}',tick)
        stealth=tick.split('if (_stealthCover) then {',1)[1].split('} else {',1)[0]
        self.assertIn('[_group,-1,false,""] call CBE_fnc_DangerGroupHideStep',stealth)
        self.assertIn('|| {fleeing _actor}',source('dangerCoverStep'))
        cover=source('dangerCoverStep')
        handoff=cover.index('[_group,-1,false,"",objNull,_actor] call CBE_fnc_DangerGroupHideStep')
        self.assertLess(handoff,cover.index('_actor doMove _spot'))
        self.assertLess(cover.index('[_actor] call CBE_fnc_DangerEngineRelease'),cover.index('_actor doMove _spot'))
        self.assertIn('["POSTURE_HANDOFF"] call _clearLease',cover)

        reflex=source('dangerEngineAct')
        self.assertIn('unitCombatMode _actor in ["BLUE","GREEN"]',reflex)

        self.assertIn('private _dangerVehicleSafety=_dangerActive && {_dangerActionName == "VEHICLE"};',tick)
        self.assertIn('private _dangerContact=_group getVariable ["CBE_Danger_Contact",[]];',tick)
        self.assertIn('private _dangerVehicleContact=_dangerVehicleSafety && {_dangerConfirmed}',tick)
        self.assertIn('_enemies findIf {(_x select 0) == _dangerContactSource} >= 0',tick)
        self.assertIn('[_group,_state,[]] call CBE_fnc_CortexVehicles;',tick)
        self.assertLess(step.index('private _replace='),step.index('CBE_fnc_DangerReact', step.index('if (_replace) then {')))
        self.assertIn('Keep the surviving highest-priority response authoritative',step)
        self.assertIn('CBE_Danger_Response',source('cortexGroupTick'))
        self.assertIn('private _tacticalTier=_nearTier || _dangerTactical',source('cortexGroupTick'))
        self.assertIn('private _nativeCombatResponsive=_seenCount > 0;',source('cortexGroupTick'))
        self.assertIn('_tacticalTier=_tacticalTier || {_nativeCombatResponsive};',source('cortexGroupTick'))
        self.assertIn('_delay=_delay min (["CBE_AIPass_TickContact",2] call _get);',source('cortexGroupTick'))
        self.assertLess(source('cortexGroupTick').index('private _nativeCombatResponsive=_seenCount > 0;'),source('cortexGroupTick').index('private _navalOwnsMovement='))
        self.assertIn('if (_tacticalTier)',source('cortexGroupTick'))
        self.assertIn('_contactDelay=_contactDelay min 0.5',source('cortexGroupTick'))
        self.assertIn('if (_dangerTactical || {_dangerVehicleContact} || {_visible isNotEqualTo []}) exitWith {call _beginContact};',source('cortexGroupTick'))
        calm=source('cortexGroupTick').split('case "CALM": {',1)[1].split('case "INVESTIGATE": {',1)[0]
        self.assertLess(calm.index('_dangerTactical || {_dangerVehicleContact} || {_visible isNotEqualTo []}'),calm.index('CBE_AIPass_AreaReport'))
        self.assertIn('private _contactPosition=if (_visible isNotEqualTo [])',source('cortexGroupTick'))
        self.assertIn('_dangerResponse param [1,getPosATL _leader]',source('cortexGroupTick'))
        self.assertIn('["DANGER_CONTACT","VISIBLE_CONTACT"] select (_visible isNotEqualTo [])',source('cortexGroupTick'))
        begin_contact=source('cortexGroupTick').split('private _beginContact = {',1)[1].split('};\n\nswitch',1)[0]
        self.assertGreaterEqual(begin_contact.count('_visible isNotEqualTo []'),3)
        for dispatch in ['CBE_fnc_CortexContactReport','CBE_fnc_CortexCombinedArmsRequest','CBE_fnc_CortexReinforce']:
            self.assertIn('_visible isNotEqualTo []',begin_contact[max(0,begin_contact.index(dispatch)-500):begin_contact.index(dispatch)])
        contact=source('cortexGroupTick').split('case "CONTACT": {',1)[1].split('case "SECURITY": {',1)[0]
        self.assertIn('if (_hasTargetKnowledge) then {',contact)
        self.assertIn('if (_visible isEqualTo []) then {_state set ["enemyPos",+((_enemies select 0) select 1)]}',contact)
        self.assertIn('!_dangerActive',contact)
        self.assertIn('"DANGER_EXPIRED"',contact)
        self.assertLess(contact.index('!_dangerActive'),contact.index('CBE_AIPass_PostContact_LostSeconds'))
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('private _schedulerQueue=(missionNamespace getVariable ["CBE_AIPass_Jobs", []]) select [0,20];',diagnostics)
        self.assertIn('"cortex-scheduler"',diagnostics)
        self.assertIn('CBE_Danger_ObservedContacts',diagnostics)
        self.assertIn('private _dangerObservedGroups=',diagnostics)
        self.assertIn('local observed contacts=',diagnostics)
        self.assertIn('private _dangerConfirmedGroups=',diagnostics)
        self.assertIn('confirmed handoffs=',diagnostics)
        self.assertIn('removeEventHandler',setup)
        self.assertIn('CBE_Danger_Handlers',setup)
        self.assertNotIn('addEventHandler ["Hit"',setup)
        self.assertNotIn('addEventHandler ["Explosion"',setup)
        self.assertNotIn('addEventHandler ["Suppressed"',setup)
        self.assertNotIn('addEventHandler ["FiredNear"',setup)
        self.assertIn('if (!_enabled) exitWith {',setup)
        self.assertLess(setup.index('if (!_enabled) exitWith {'), setup.index('CBE_Danger_Response",nil,true'))
        self.assertIn('"EnemyDetected"',setup)
        self.assertIn('CBE_Danger_GroupHandlers',setup)
        self.assertIn('_group removeEventHandler _x',setup)
        self.assertIn('(side _observingGroup) getFriend (side _target)',setup)
        self.assertIn('private _sampleCount=_memberCount min 12',setup)
        self.assertIn('for "_sampleIndex" from 0 to (_sampleCount-1)',setup)
        self.assertIn('(_sampleStart+_sampleIndex) mod _memberCount',setup)
        self.assertIn('private _observer=objNull;',setup)
        self.assertNotIn('(units _observingGroup) select',setup)
        self.assertIn('private _knowledge=_x targetKnowledge _target;',setup)
        self.assertIn('_knowledge param [1,false,[true]]',setup)
        self.assertIn('if (isNull _observer) then {_observer=_fallback}',setup)
        self.assertIn('private _contact=[_target,time+10,_observer];',setup)
        self.assertIn('CBE_Danger_ObservedContacts',setup)
        self.assertIn('_observer getHideFrom _target',setup)
        self.assertIn('[_observer,"DETECTED",_dangerPosition,_target] call CBE_fnc_DangerRequest',setup)
        knowledge=source('cortexKnowledge')
        self.assertIn('count _x in [2,3]',knowledge)
        self.assertIn('private _witnesses=[];',knowledge)
        self.assertIn('_witnesses pushBackUnique _witness',knowledge)
        self.assertIn('if (count _members > 8) then {_members resize 8};',knowledge)
        self.assertNotIn('["DETECTED",getPosATL _observer]',setup)
        self.assertIn('time+10',setup)
        self.assertIn('count _contacts > 8',setup)
        self.assertIn('"DETECTED"',request)
        self.assertIn('"DETECTED"',selection)
        self.assertIn('"EXPLOSION"',request)
        self.assertIn('"EXPLOSION"',selection)
        self.assertIn('["HIT",9],["CANFIRE",8],["SUPPRESSED",7],["CASUALTY",6],["SCREAM",5],["PROXIMITY",4],["EXPLOSION",3],["BODY_FOUND",3],["DETECTED",2],["GUNFIRE",1]',selection)
        self.assertIn('"SUPPRESSED","SCREAM","CASUALTY","BODY_FOUND"',action)
        self.assertIn('if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]',action)
        self.assertIn('&& {isNull (_event param [4,objNull,[objNull]])}) exitWith {"HIDE"};',action)
        self.assertLess(action.index('if (_cause in ["DETECTED"'),action.index('exitWith {"MAINTAIN"}'))
        self.assertNotIn('getPosATL _target',setup)
        self.assertIn("_records select [0,12]",engine)
        self.assertIn('private _position=+(_x param [1,[],[[]]]);',engine)
        self.assertLess(engine.index('private _position=+'),engine.index('_position pushBack'))
        event_position=[10,20]
        normalised=list(event_position)
        normalised.append(3)
        self.assertEqual(event_position,[10,20])
        self.assertEqual(normalised,[10,20,3])
        self.assertIn('private _latestExpiry=createHashMap;',engine)
        self.assertIn('private _latestSourceExpiry=createHashMap;',engine)
        self.assertIn("_expires >= (_latestExpiry getOrDefault [_causeName,-1])",engine)
        self.assertIn("_expires >= (_latestSourceExpiry getOrDefault [_causeName,-1])",engine)
        self.assertIn("'CASUALTY'",engine)
        self.assertIn("'BODY_FOUND'",engine)
        self.assertIn("'EXPLOSION','CASUALTY','BODY_FOUND','SCREAM'",engine)
        self.assertIn("'SCREAM'",engine)
        self.assertIn("'PROXIMITY'",engine)
        self.assertIn("'CANFIRE'",engine)
        self.assertIn('CBE_fnc_DangerRequest',engine)
        self.assertIn('_latestSource getOrDefault [_x,objNull]',engine)
        self.assertIn('private _priorSource=_prior param [4,objNull,[objNull]];',request)
        self.assertIn('_sourceUntil=_priorUntil;',request)
        self.assertIn('finite _priorUntil && {_priorUntil > time}',request)
        self.assertIn('time < _sourceUntil',source('dangerStep'))
        self.assertIn('(time+2) min _sourceUntil',source('dangerStep'))
        self.assertIn('time >= _sourceUntil',action)
        identity_expiry=2.0
        for approximate_at in (0.3,0.7,1.1,1.8):
            inherited_until=identity_expiry
            self.assertEqual(inherited_until,2.0)
            self.assertGreater(approximate_at+2,inherited_until)
        self.assertFalse(2.1 < identity_expiry)
        self.assertIn('private _sourceObserver=_actor;',request)
        self.assertIn('private _priorObserver=_prior param [6,_prior param [5,objNull,[objNull]],[objNull]];',request)
        self.assertIn('_priorObserver knowsAbout _priorSource > 0',request)
        self.assertIn('private _event=[_cause,+_position,time,_eventUntil,_hostileSource,_actor,_sourceObserver,_sourceUntil];',request)
        self.assertIn('_latestExpiry get _x,_latestSourceExpiry getOrDefault [_x,-1]',engine)
        self.assertIn('_groupRelevant} && {_expires > time}',engine)
        self.assertIn('if (_eventUntil <= time) exitWith {false}',request)
        self.assertLess(request.index('if (_eventUntil <= time)'),request.index('_cadence set'))
        self.assertIn('_sourceUntil > time && {!isNull _source}',request)
        self.assertIn('_eventUntil min _identityExpiry',request)
        self.assertIn('["_geometryExpiry",-1],["_identityExpiry",-1]',request)
        self.assertIn('findIf {!(_x isEqualType 0) || {!finite _x}',request)
        import math
        def intake(now,geometry=-1,identity=-1):
            if any(type(value) not in (int,float) or not math.isfinite(value) for value in (geometry,identity)):return None
            if geometry<0 and geometry!=-1 or identity<0 and identity!=-1:return None
            until=now+2 if geometry==-1 else min(now+2,geometry)
            if until<=now:return None
            source=until if identity==-1 else min(until,identity)
            return until,source
        self.assertEqual(intake(10,10.05,10.04),(10.05,10.04))
        self.assertEqual(intake(10.02,10.05,10.04),(10.05,10.04))
        self.assertIsNone(intake(10.1,10.05,10.04))
        self.assertEqual(intake(10),(12,12))
        self.assertEqual(intake(10,15,10.5),(12,10.5))
        self.assertLess(intake(10,11,9)[1],10)
        self.assertIsNone(intake(10,-0.5))
        for invalid in ('future',False,None,float('nan'),float('inf')):
            self.assertIsNone(intake(10,invalid))
            self.assertIsNone(intake(10,11,invalid))
        self.assertIn('count _x in [4,5,6,7,8]',selection)
        self.assertIn('private _actor=_event param [5,objNull,[objNull]];',action)
        self.assertIn('group _actor != _group',action)
        self.assertIn('private _observer=_selected param [5,objNull,[objNull]];',source('dangerStep'))
        self.assertIn('private _sourceObserver=_selected param [6,_observer,[objNull]];',source('dangerStep'))
        self.assertIn('private _activeAction=_group getVariable ["CBE_Danger_Action",[]];',source('dangerStep'))
        self.assertIn('_activeAction param [5,_actor,[objNull]]',source('dangerStep'))
        self.assertIn('_responseCommand in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]',source('dangerStep'))
        self.assertLess(source('dangerStep').index('private _activeAction=_group getVariable'),source('dangerStep').index('private _events='))
        self.assertIn('_sourceObserver knowsAbout _source > 0',source('dangerStep'))
        assessment=source('dangerStep')
        self.assertNotIn('then {_sourceObserver=_observer}',assessment)
        self.assertIn('private _sourceObserver=_event param [6,_actor,[objNull]];',action)
        for witness_gate in ('CBE_fnc_CortexCombatEffective','!local _sourceObserver',
                             'group _sourceObserver != _group','_sourceObserver knowsAbout _source <= 0'):
            self.assertIn(witness_gate,action)
        self.assertLess(action.index('_sourceObserver knowsAbout _source <= 0'),action.index('exitWith {"MAINTAIN"}'))
        self.assertIn('private _vehicleSource=if (_sourceKnown) then {_source} else {objNull};',assessment)
        self.assertIn('_generation,_vehicleSource,_sourceUntil,_sourceObserver],true]',assessment)
        self.assertIn('if (_action != "FORCED" && {_sourceKnown})',assessment)
        # An approximate event remains usable, but a substitute observer cannot renew identity.
        def source_authority(witness_alive,witness_local,same_group,knowledge):
            return witness_alive and witness_local and same_group and knowledge>0
        for state in ((False,True,True,1),(True,False,True,1),
                      (True,True,False,1),(True,True,True,0)):
            known=source_authority(*state)
            self.assertFalse(known)
            self.assertEqual('ENGAGE' if known else 'HIDE','HIDE')
            self.assertIsNone('hostile' if known else None)
        self.assertTrue(source_authority(True,True,True,0.1))
        # Native ignore policy must survive every event entry and deferred handoff.
        for name in ('dangerSetup','dangerRequest','dangerEngineSubmit','dangerEngineMode',
                     'dangerEngineRecycle','dangerActionSelect','dangerStep'):
            boundary=source(name)
            self.assertIn('targetKnowledge',boundary,name)
            self.assertIn('param [7,false,[true]]',boundary,name)
            self.assertNotIn(' ignoreTarget [',boundary,name)
        ignore_guard='if (_sourceIgnored && {_cause in ["DETECTED","PROXIMITY","CANFIRE"]})'
        self.assertIn(ignore_guard,request)
        self.assertLess(request.index(ignore_guard),request.index('_cadence set [_cause,time+0.25]'))
        self.assertLess(action.index(ignore_guard),action.index('exitWith {"VEHICLE"}'))
        self.assertIn('_priorObserver targetKnowledge _priorSource',request)
        self.assertIn('_sourceObserver targetKnowledge _source',assessment)
        self.assertLess(setup.index('private _knowledge=_x targetKnowledge _target;'),setup.index('private _contacts='))
        self.assertLess(setup.index('if (_ignored) exitWith {}'),setup.index('private _contacts='))
        self.assertIn("if (count _latest > 0 && {!(_group getVariable ['CBE_AIPass_Managed',false])}",engine)
        self.assertIn('[_group,false,true] call CBE_fnc_CortexIsEligible',engine)
        self.assertIn('[_group] call CBE_fnc_DangerSetup;',engine)
        self.assertIn('[_group,true] call CBE_fnc_GroupBrainStart',engine)
        self.assertLess(engine.index('[_group] call CBE_fnc_DangerSetup;'),engine.index('[_group,true] call CBE_fnc_GroupBrainStart'))
        preflight=engine.split('private _causeNames=',1)[0]
        self.assertNotIn("|| {!(_group getVariable ['CBE_AIPass_Managed',false])}",preflight)
        self.assertIn('CBE_Danger_EngineStats',engine)
        self.assertIn("['bootstraps'",engine)
        self.assertIn("['reflexOnlyRecords'",engine)
        self.assertIn("'ASSESS'",engine)
        self.assertIn("private _groupRelevant=if (_mode in ['FORCED','RELEASE'] || {_cause == 10}) then {false}",engine)
        self.assertIn('if (_cause in [0,3,8]) then {_hostileEngage}',engine)
        self.assertLess(engine.index('private _causeNames='),engine.index('call CBE_fnc_GroupBrainStart'))
        self.assertIn('CBE_Danger_EngineStats',engine_act)
        self.assertIn('CBE_Danger_EngineResponse',engine_act)
        self.assertIn('CBE_Danger_EngineStanceLease',engine_act)
        self.assertIn('_actor setVariable ["CBE_Danger_EngineResponse",nil]',engine_release)
        self.assertIn('CBE_Danger_EngineStanceLease',engine_release)
        self.assertIn('"NEW_OPERATION_OR_OWNER"',engine_release)
        self.assertIn('"NATIVE_TASK_OR_MEDICAL"',engine_release)
        for proof in ['CBE_OperationGeneration','CBE_AIPass_Epoch','(_lease select 5) != _group']:
            self.assertIn(proof,engine_release)
            self.assertIn(proof,engine_act)
        self.assertLess(engine_release.index('"NEW_OPERATION_OR_OWNER"'),engine_release.index('setUnitPosWeak _prior'))
        self.assertIn('[_x] call CBE_fnc_DangerEngineRelease',setup)
        self.assertIn('[_x] call CBE_fnc_DangerEngineRelease',source('cortexReleaseGroup'))
        self.assertIn('DANGER-live-disable-exact-stance-release',contact_fixture)
        self.assertIn('DANGER-live-disable-reenabled',contact_fixture)
        for text in [engine_mode,engine_act,engine_continue]:
            self.assertIn('CBE_fnc_CortexCombatEffective',text)
        self.assertIn('toUpperANSI (unitPos _actor) != _applied',engine_release)
        self.assertIn('CBE_fnc_CortexExternalTakeover',engine_release)
        self.assertIn('CBE_fnc_CortexZeusHeld',engine_release)
        self.assertIn('_actor setUnitPosWeak _prior',engine_release)
        forced_block=engine_act.split('// Forced orders and vehicle crews',1)[1].split('if (_mode == "IMMEDIATE")',1)[0]
        self.assertNotIn('setUnitPos ',forced_block)
        self.assertIn('!(_dangerEnabled isEqualType true)',engine_continue)
        self.assertIn('!(_disabled isEqualType [])',engine_continue)
        self.assertLess(engine_continue.index('!(_dangerEnabled isEqualType true)'),engine_continue.index('!_dangerEnabled'))
        self.assertLess(engine_continue.index('!(_disabled isEqualType [])'),engine_continue.index('"ALL" in _disabled'))
        # Same typed enable/exclusion contract as the shared feature gate; invalid
        # mission data must not reach native FSM Boolean/membership operators.
        def danger_enabled(enabled,disabled):
            return isinstance(enabled,bool) and enabled and isinstance(disabled,list) and 'ALL' not in disabled and 'CBE_AIPass_Danger_Enable' not in disabled
        self.assertTrue(danger_enabled(True,[]))
        for enabled,disabled in ((False,[]),('true',[]),(1,[]),(0,[]),(True,{}),(True,False),(True,['ALL']),(True,['CBE_AIPass_Danger_Enable'])):
            self.assertFalse(danger_enabled(enabled,disabled))
        self.assertIn('_records select [0,48]',engine_select)
        self.assertIn('private _priorities=[2,1,9,4,3,6,3,5,8,7,0]',engine_select)
        self.assertIn('_rank >= 0 && {count _position in [2,3]}',engine_select)
        self.assertIn('_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0',engine_select)
        self.assertIn('_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0',source('dangerEngineSubmit'))
        self.assertIn('_queue=[[_dangerCause,_dangerPos,_dangerUntil,_dangerCausedBy]]+(_queue select [((count _queue)-47) max 0,47])',engine_fsm)
        self.assertLess(engine_select.index('private _priorities='),engine_select.index('forEach (_records select [0,48])'))
        self.assertIn('currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]',engine_mode)
        self.assertNotIn('currentCommand _actor in ["ATTACK"',engine_mode)
        self.assertIn('(_carrierTask select 0) in ["STATIC_DEPLOY","STATIC_PACK","STATIC_SUPPORT"]',engine_mode)
        self.assertIn('time < (_carrierTask select 2)',engine_mode)
        self.assertLess(engine_mode.index('if (!isNull objectParent _actor)'),engine_mode.index('private _carrierTask'))
        self.assertLess(engine_mode.index('if (!isNull objectParent _actor)'),engine_mode.index('private _cause='))
        self.assertNotIn('if !(_actor checkAIFeature "MOVE") exitWith',engine_mode)
        self.assertIn('_actor checkAIFeature "MOVE"',source("dangerCoverStep"))
        self.assertIn('(side _group) getFriend (side _source) < 0.6',engine_mode)
        for danger_source in [engine_mode,engine,request,source('dangerStep'),source('dangerEngineRecycle'),setup,
                              source('cortexGroupTick'),source('cortexVehicles')]:
            self.assertNotIn('getFriend (side group _source)',danger_source)
            self.assertNotIn('getFriend (side group _dangerSource)',danger_source)
            self.assertNotIn('getFriend (side group _dangerContactSource)',danger_source)
            self.assertNotIn('private _targetGroup=group _target',danger_source)
        self.assertIn('else {"ASSESS"}',engine_mode)
        for mode in ['"RELEASE"','"FORCED"','"VEHICLE"','"IMMEDIATE"','"HIDE"','"ENGAGE"','"ASSESS"']:
            self.assertIn(mode,engine_mode+engine_fsm)
        for profile in ['"AIR"','"ARTILLERY"','"STATIC"','"ARMOURED"','"ARMED"','"TRANSPORT"']:
            self.assertIn(profile,vehicle_profile)
        self.assertLess(vehicle_profile.index('artilleryScanner'),vehicle_profile.index('StaticWeapon'))
        self.assertIn('allTurrets [_vehicle,true]',vehicle_profile)
        self.assertNotIn('doMove',vehicle_profile)
        self.assertNotIn('doTarget',vehicle_profile)
        self.assertIn('lastVehicleProfile',engine_act)
        self.assertIn('_actor setUnitPosWeak _desiredStance',engine_act)
        self.assertIn('private _committedMover=',engine_act)
        self.assertIn('_hardCover && {!_committedMover}',engine_act)
        self.assertIn('committed operation movers are never forced prone',diagnostics)
        self.assertIn('finiteCoverMoves=',diagnostics)
        self.assertIn('CBE_fnc_DangerCoverStep',source('cortexGroupTick'))
        cover_combat=source('dangerCoverStep')
        self.assertIn('currentCommand _actor in ["","MOVE","ATTACK","FIRE","SUPPRESS"]',cover_combat)
        self.assertIn('abs speed _actor > 0.5',cover_combat)
        self.assertIn('_responseCause in ["HIT","EXPLOSION","SUPPRESSED"]',source('cortexGroupTick'))
        self.assertIn('_suppression > 0.45',engine_act)
        self.assertIn('private _suppression=getSuppression _actor',engine_act)
        self.assertNotIn('_cause in [5,6]',engine_act)
        reaction=source('dangerReact')
        self.assertIn('if (_cause in ["CASUALTY","BODY_FOUND","SCREAM"]) exitWith {"ASSESS"};',reaction)
        self.assertIn('count (_group getVariable ["CBE_Operation",createHashMap]) > 0',danger_cover)
        self.assertIn('!(currentCommand _actor in ["","ATTACK","FIRE","SUPPRESS"])',danger_cover)
        self.assertIn('CBE_fnc_CortexExternalTakeover',danger_cover)
        self.assertIn('CBE_fnc_CortexZeusHeld',danger_cover)
        self.assertIn('CBE_fnc_CortexFindCover',danger_cover)
        self.assertIn('_actor doMove _spot',danger_cover)
        self.assertNotIn('while {',danger_cover)
        self.assertNotIn('CortexQueueJob',danger_cover)
        self.assertIn('if (count _threat < 2) exitWith',danger_cover)
        self.assertIn('CBE_Danger_CoverLease',source('cortexReleaseGroup'))
        group_hide=source('dangerGroupHideStep')
        for marker in ['CBE_Danger_GroupHideLeases','CBE_Danger_Generation','CBE_Operation',
                       'currentCommand _x in ["","ATTACK","FIRE","SUPPRESS"]', 'abs (speed _x) <= 0.5','CBE_Cortex_ActorMove','setUnitPosWeak',
                       'groupHideResponses','lastGroupHideActors']:
            self.assertIn(marker,group_hide)
        self.assertIn('call CBE_fnc_CortexCapabilities',group_hide)
        self.assertIn('case (_capabilities isNotEqualTo []): {30}',group_hide)
        self.assertIn('case (_role == "LEADER"): {20}',group_hide)
        self.assertIn('_ranked sort true',group_hide)
        for forbidden in [' doMove ', ' commandMove ', ' doTarget ', ' doFire ', 'forceWeaponFire',
                          'allUnits', 'allGroups', 'spawn ', 'waitUntil']:
            self.assertNotIn(forbidden,group_hide)
        self.assertIn('call CBE_fnc_DangerGroupHideStep',source('cortexGroupTick'))
        self.assertIn('call CBE_fnc_DangerGroupHideStep',source('cortexReleaseGroup'))
        self.assertIn('call CBE_fnc_DangerGroupHideStep',source('dangerSetup'))
        self.assertIn('call CBE_fnc_DangerCoverStep',source('cortexReleaseGroup'))
        self.assertIn('CBE_fnc_CortexIsEligible',engine_act)
        self.assertIn('CBE_fnc_CortexZeusHeld',source('cortexExternalTakeover'))
        for forbidden in [' doMove ', ' commandMove ', ' doTarget ', ' doFire ', ' forceWeaponFire ', ' reveal ']:
            self.assertNotIn(forbidden,engine_act)
        self.assertIn('_queue=[[_dangerCause,_dangerPos,_dangerUntil,_dangerCausedBy]]',engine_fsm)
        self.assertIn('_recentLimit=48-([0,1] select (_cbeEntryRecord isNotEqualTo []))',engine_fsm)
        self.assertIn('_window=_queue select [((count _queue)-_recentLimit) max 0,_recentLimit]',engine_fsm)
        self.assertLess(engine_fsm.index('_window pushBackUnique _cbeEntryRecord'),engine_fsm.index('_selected=[_window]'))
        self.assertIn('_records=_window select [((count _window)-10) max 0,10]',engine_fsm)
        self.assertIn('_cbeEntryRecord=[_dangerCause,+_dangerPos,_dangerUntil,_dangerCausedBy]',engine_fsm)
        self.assertIn('_records pushBackUnique _cbeEntryRecord',engine_fsm)
        self.assertIn('_cbeEntryRecord=[]; _queue=[]',engine_fsm)
        # Native queue ordering need not be inferred: the current entry is explicitly
        # prepended by this FSM and could otherwise fall outside the submitted tail.
        current=[0,[10,20,0],30,'contact']
        strongest=[2,[1,2,0],29,'hit']
        window=[current,strongest]+[[1,[i,0,0],28,'fire'] for i in range(46)]
        old=window[-11:]+[strongest]
        self.assertNotIn(current,old)
        def batch(window,entry,selected):
            records=window[-10:]
            for record in (entry,selected):
                if record and record not in records:records.append(record)
            return records
        def select_window(queue,entry):
            limit=47 if entry else 48
            recent=queue[-limit:]
            if entry and entry not in recent:recent.append(entry)
            return recent
        burst=[strongest]+[[1,[i,0,0],28,'fire'] for i in range(80)]
        self.assertNotIn(strongest,burst[-48:])
        for size in (0,1,47,48,49,81,128):
            selected_window=select_window(burst[:size],strongest)
            self.assertIn(strongest,selected_window)
            self.assertLessEqual(len(selected_window),48)
        self.assertEqual(select_window(burst,[]),burst[-48:])
        self.assertIn(strongest,select_window(burst,strongest))
        records=batch(window,current,strongest)
        self.assertIn(current,records);self.assertIn(strongest,records)
        self.assertLessEqual(len(records),12)
        self.assertEqual(current,[0,[10,20,0],30,'contact'])
        for size in range(49):
            self.assertLessEqual(len(batch(window[:size],current,strongest)),12)
        self.assertNotIn(current,batch(window[1:],[],strongest))
        self.assertIn('_records pushBackUnique _selected',engine_fsm)
        self.assertLess(engine_fsm.index('_selected=[_window]'),engine_fsm.index('_queue=[]; _mode='))
        self.assertIn('_queue=[]',engine_fsm)
        self.assertIn('CBE_fnc_DangerEngineSubmit',engine_fsm)
        self.assertIn('[_this,_records,_mode] call CBE_fnc_DangerEngineSubmit',engine_fsm)
        self.assertIn('CBE_fnc_DangerEngineCanContinue',engine_fsm)
        self.assertIn('CBE_fnc_DangerEngineRelease',engine_fsm)
        self.assertIn('CBE_fnc_DangerEngineRecycle',engine_fsm)
        editor_head=engine_fsm.split('class FSM',1)[0]
        editor_items=sorted({int(value) for value in re.findall(r'item(\d+)\[\]',editor_head)})
        self.assertEqual(editor_items,list(range(len(editor_items))))
        for source_item,target_item in re.findall(r'link\d+\[\]=\{(\d+),(\d+)\}',editor_head):
            self.assertIn(int(source_item),editor_items)
            self.assertIn(int(target_item),editor_items)
        self.assertNotIn('select _accepted',engine_fsm)
        self.assertIn('_mode=[_this,_selected] call CBE_fnc_DangerEngineMode',engine_fsm)
        self.assertIn('initState="Start_Danger"',engine_fsm)
        for final_state in ['"End_Danger"','"End_Danger_vehic"','"End_Danger_1"','"End_Forced"']:
            self.assertIn(final_state,engine_fsm)
        self.assertNotRegex(engine_fsm.lower(),r'lambs|upstream|baseline')
        self.assertIn('CBE_AIPass_Danger_Enable',engine_continue)
        self.assertIn('[_this,true] call CBE_fnc_DangerEngineCanContinue',engine_fsm)
        self.assertIn('!_initial && {fleeing _actor',engine_continue)
        # A classified native task waits without action churn; a newly arriving task
        # still interrupts non-FORCED work. Identity validation precedes that exception.
        task_guard=engine_continue.split('if (behaviour _actor == "CARELESS"',1)[1].split('// A carrier reservation',1)[0]
        self.assertIn('(_response param [0,"",[""]]) != "FORCED"',task_guard)
        self.assertLess(engine_continue.index('count _response != 7'),engine_continue.index('if (behaviour _actor == "CARELESS"'))
        released=engine_fsm.split('class Released',1)[1].split('/*%FSM</LINK>*/',1)[0]
        self.assertIn('to="End_Danger_1"',released)
        self.assertIn('_mode == ""RELEASE"" || {!_accepted}',released)
        self.assertGreater(float(re.search(r'priority = ([0-9.]+)',released).group(1)),4)

        self.assertIn('_mode != "FORCED" && {currentCommand _actor',engine_act)
        self.assertIn('behaviour _actor == "CARELESS"}) exitWith {0}',engine_act)
        self.assertLess(engine_act.index('behaviour _actor == "CARELESS"'),engine_act.index('_actor playActionNow'))
        self.assertLess(engine_act.index('behaviour _actor == "CARELESS"'),engine_act.index('_actor glanceAt'))
        self.assertLess(engine_act.index('behaviour _actor == "CARELESS"'),engine_act.index('_actor setUnitPosWeak'))
        self.assertIn('(_carrierTask select 0) in ["STATIC_DEPLOY","STATIC_PACK","STATIC_SUPPORT"]',engine_continue)
        self.assertIn('time < (_carrierTask select 2)',engine_continue)
        self.assertIn('(_response param [0,"",[""]]) != "FORCED"',engine_continue)
        self.assertIn('CBE_AIPass_DisabledFeatures',engine_continue)
        self.assertIn('CBE_fnc_CortexIsPaused',engine_continue)
        self.assertIn('CBE_fnc_CompatibilityExternalControl',engine_continue)
        self.assertIn('remoteControlled _actor',engine_continue)
        self.assertIn('CBE_AIPass_ZeusHold',engine_continue)
        self.assertIn('CBE_AIPass_ZeusWaypoints',engine_continue)
        self.assertIn('behaviour _actor == "CARELESS"',engine_continue)
        self.assertIn('fleeing _actor',engine_continue)
        self.assertIn('toUpperANSI (currentCommand _actor) in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]',engine_continue)
        for expensive in ['units _group','allUnits','allGroups','CortexExternalTakeover','CortexExternalOwner','CortexZeusHeld','nearestObjects','nearEntities']:
            self.assertNotIn(expensive,engine_continue)
        mode_preflight=engine_mode.split('if (fleeing _actor',1)[0]
        self.assertIn('CBE_AIPass_Active',mode_preflight)
        self.assertIn('CBE_AIPass_Danger_Enable',mode_preflight)
        self.assertIn('CortexIsPaused',mode_preflight)
        for state in ['Start_Danger','Init','Evaluate_Vehicle','Reset_vehicle','Evaluate_Infantr',
                      'Roll_dodge','Stay_firm','Attack','Check_self','End_Danger','Reset_foot',
                      'Check_queue','End_Danger_vehic','Check_self_1','Check_self_2','Tactics',
                      'End_Danger_1','End_Forced']:
            self.assertIn('class '+state,engine_fsm)
        self.assertGreaterEqual(engine_fsm.count('time >= _deadline'),4)
        self.assertGreaterEqual(engine_fsm.count('CBE_fnc_DangerEngineCanContinue'),5)
        self.assertIn('effectiveCommander (vehicle _actor) == _actor',engine_recycle)
        self.assertIn("['lastRecycleActor',_actor]",engine_recycle)
        self.assertIn("['vehicleRecycleActors',_actors]",engine_recycle)
        self.assertIn('_actor distance2D _position >= 35',engine_recycle)
        self.assertIn('(side _group) getFriend (side _source) >= 0.6',engine_recycle)
        self.assertIn('[_cause,+_position,time+1.5,_source,_cycle+1]',engine_recycle)
        self.assertIn('private _cycle=_x param [4,0];',engine)
        self.assertIn('_cycle isEqualType 0 && {finite _cycle}',engine)
        self.assertIn('if (_cycle > 0) then {"DETECTED"} else {_causeNames select _cause}',engine)
        def group_cause(cause,cycle):
            return 'DETECTED' if cycle>0 else cause
        for cause in ('HIT','PROXIMITY','CANFIRE','SUPPRESSED'):
            self.assertEqual(group_cause(cause,0),cause)
            self.assertEqual(group_cause(cause,1),'DETECTED')
        # A retained real hit expires at3. Belief samples cannot give it a fresh clock.
        live=('HIT',3)
        priority={'HIT':9,'DETECTED':2}
        for now in (1,2.9,3.1):
            candidate=(group_cause('HIT',1),now+1.5)
            if now>=live[1] or priority[candidate[0]]>=priority[live[0]]:live=candidate
            if now<3:self.assertEqual(live,('HIT',3))
        self.assertEqual(live[0],'DETECTED')
        self.assertNotIn('[0,+_position,time+1.5,_source',engine_recycle)
        self.assertIn("case 'ENGAGE': {2}",engine_recycle)
        self.assertIn("case 'VEHICLE': {3}",engine_recycle)
        self.assertIn('boundedRecycleEnds',engine_recycle)
        self.assertIn("['boundedRecycleEndsByMode',_endsByMode]",engine_recycle)
        self.assertIn("['lastRecycleCyclesByMode',_cyclesByMode]",engine_recycle)
        for forbidden in [' doMove ', ' commandMove ', ' doTarget ', ' doFire ', ' forceWeaponFire ', ' reveal ', 'allUnits', 'allGroups']:
            self.assertNotIn(forbidden,engine_recycle)
        self.assertIn('first-contactBootstraps=',diagnostics)
        self.assertIn('reflexOnlyRecords=',diagnostics)
        self.assertIn('boundedRecycleEnds=%18',diagnostics)
        self.assertIn('lastRecycleCycles=%19',diagnostics)
        self.assertIn('groupHideResponses=%20',diagnostics)
        self.assertIn('activeGroupHideActors=%21',diagnostics)
        self.assertIn('_dangerEngineBoundedEnds',diagnostics)

        contact_audit=(ROOT/'releaseVerificationAndDeployment'/'cortexQA'/'runContact.sqf').read_text(encoding='utf-8')
        self.assertIn('"BODY_FOUND" in (_stats getOrDefault ["lastCauses",[]])',contact_audit)
        self.assertIn('DANGER-other-body-distinct-alert',contact_audit)
        self.assertIn('[_bodyActor] call _killWithRealProjectile',contact_audit)
        self.assertNotIn('call CBE_fnc_DangerEngineSubmit',contact_audit)
        self.assertIn('CBE_Danger_EngineStanceLease',diagnostics)
        self.assertIn('server-local stance leases=',diagnostics)
        vehicle_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        self.assertIn('DANGER-VEHICLE-mixed-observer-domain',vehicle_audit)
        self.assertIn('count _assessment >= 7',vehicle_audit)
        self.assertIn('(_assessment select 5) == effectiveCommander _contactVehicle',vehicle_audit)
        self.assertIn('_action param [0,""] == "VEHICLE"',vehicle_audit)
        self.assertIn('(_vehicleContext select 0) == "ARMOURED"',vehicle_audit)
        self.assertIn('(_vehicleContext select 1) == _contactVehicle',vehicle_audit)
        self.assertIn('dangerVehicleProfile',source('cortexGroupTick'))
        self.assertIn('["TRANSPORT","ARMED","ARMOURED"]',source('cortexVehicles'))
        self.assertIn('CBE_Danger_VehicleContext",nil,true',source('cortexReleaseGroup'))
        self.assertIn('Immediate stances are weak, finite and exact-owned',diagnostics)
        self.assertIn('Friendly near-fire can produce a short local reflex but cannot create group CONTACT',diagnostics)
        self.assertIn('["ERROR","ACTIVE"] select _dangerFsmOwned',diagnostics)
        self.assertIn('Native ATTACK remains eligible',diagnostics)
        self.assertIn("_mode in ['FORCED','RELEASE']",engine)
        self.assertIn("then {false}",engine.split("_mode in ['FORCED','RELEASE']",1)[1].split(';',1)[0])
        self.assertIn('private _dangerFsmPaths=["SoldierWB","SoldierEB","SoldierGB"] apply',diagnostics)
        self.assertIn('CBE must own all west, east and independent soldier danger slots',diagnostics)
        lifecycle=(ROOT/'docs/ADDON-LIFECYCLE.md').read_text(encoding='utf-8')
        for state in ['`ASSESS`','`IMMEDIATE`','`HIDE`','`ENGAGE`','`VEHICLE`','`FORCED`','release']:
            self.assertIn(state,lifecycle)
        self.assertIn('cannot request cover movement from those causes',lifecycle)
        self.assertIn('cannot create a second movement scheduler',lifecycle)
        contact_audit=(Path(__file__).parent/'cortexQA/runContact.sqf').read_text(encoding='utf-8')
        reflex_fixture=contact_audit.split('// Prove the engine-loaded FSM',1)[1].split('deleteGroup _reflexGroup;',1)[0]
        self.assertIn('_reflexUnit setUnitPos "AUTO";',reflex_fixture)
        self.assertNotIn('_reflexUnit setUnitPos "UP";',reflex_fixture)
        self.assertIn('toUpperANSI (unitPos _reflexUnit) == "AUTO"',reflex_fixture)
        self.assertIn('DANGER-committed-mover-not-forced-prone',reflex_fixture)
        self.assertIn('DANGER-committed-route-physical-continuity',reflex_fixture)
        self.assertIn('DANGER-idle-physical-cover',reflex_fixture)
        self.assertIn('DANGER-exact-observer-physical-cover',reflex_fixture)
        self.assertIn('DANGER-finite-group-hide',reflex_fixture)
        self.assertIn('CBE_Danger_GroupHideLeases',reflex_fixture)
        self.assertIn('O_Soldier_LAT_F',reflex_fixture)
        self.assertIn('!(_observerSupportOne in _leasedActors)',reflex_fixture)
        self.assertIn('[_observerSupportTwo,_observerSupportThree,_observerSupportFour,_observerSupportFive]',reflex_fixture)
        self.assertIn('toUpperANSI (unitPos _observerSupportOne) == "AUTO"',reflex_fixture)
        self.assertIn('(_assessment select 5) == _observerWingman',reflex_fixture)
        self.assertIn('(_action select 5) == _observerWingman',reflex_fixture)
        self.assertIn('(_lease select 0) == _observerWingman',reflex_fixture)
        self.assertIn('DANGER-natural-finish-identity-cleared',reflex_fixture)
        self.assertIn('DANGER-close-contact-finite-reflex-handoff',reflex_fixture)
        self.assertIn('getOrDefault ["boundedRecycleEnds",0]',reflex_fixture)
        self.assertIn('getOrDefault ["boundedRecycleEndsByMode",createHashMap]',reflex_fixture)
        self.assertIn('getOrDefault ["lastRecycleCyclesByMode",createHashMap]',reflex_fixture)
        self.assertIn('getOrDefault ["ENGAGE",-1]) == 2',reflex_fixture)
        self.assertIn('CBE_Danger_LastAssessment',reflex_fixture)
        self.assertIn('CBE_Danger_VehicleContext',reflex_fixture)
        self.assertIn('Land_CncWall4_F',reflex_fixture)
        self.assertIn('CBE_Danger_CoverLease',reflex_fixture)
        self.assertIn('CBE_fnc_OperationStart',reflex_fixture)
        self.assertIn('CBE_fnc_CortexGroupMove',reflex_fixture)
        self.assertIn('DANGER-stealth-hold-fire-low-profile',contact_audit)
        self.assertIn('_disciplineGroup setBehaviourStrong "STEALTH"',contact_audit)
        self.assertIn('(_lease select 1) == "DOWN"',contact_audit)
        self.assertIn('behaviour _actor == "STEALTH"',engine_act)
        self.assertIn('unitCombatMode _actor in ["BLUE","GREEN"]',engine_act)
        self.assertIn('!_committedMover',engine_act)
        group_tick=source('cortexGroupTick')
        observer_selection=group_tick.split('private _dangerAction=',1)[1].split('private _dangerActionName=',1)[0]
        self.assertIn('param [5,objNull,[objNull]]',observer_selection)
        self.assertIn('group _observedActor == _group',observer_selection)
        self.assertIn('[_action,_cause,_observedAt,time+_responseLifetime,_generation,_observer]',source('dangerStep'))
        scheduler_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runScheduler.sqf').read_text(encoding='utf-8')
        danger_audit=scheduler_audit.split('// This section diagnoses the real FSM-to-existing-job bridge.',1)[1]
        self.assertIn('CBE_GroupBrain',danger_audit)
        self.assertIn('CBE_Danger_GroupHandlers',danger_audit)
        self.assertNotIn('getVariable ["CBE_Cortex_GroupJob"',danger_audit)
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text()
        self.assertIn('_zeusToken isNotEqualTo',fsm)
        self.assertIn('CBE_AIPass_Epoch',fsm)
        self.assertIn('""RELEASE""',fsm)
        self.assertIn('_brain=_group getVariable [""CBE_GroupBrain"",createHashMap]',fsm)
        self.assertIn('_brain deleteAt ""responsiveUntil""',fsm)
        self.assertNotIn('CBE_Cortex_GroupJob',fsm)
        self.assertIn('CBE_Danger_Action',fsm)
        for contract in ['"RELEASE"','"FORCED"','"MAINTAIN"','"VEHICLE"','"HIDE"','"ENGAGE"']:
            self.assertIn(contract,action)
        self.assertIn('currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]',action)
        self.assertNotIn('currentCommand _actor in ["ATTACK"',action)
        self.assertIn('!isNull objectParent _actor',action)
        self.assertLess(action.index('currentCommand _actor in'),action.index('CBE_Operation'))
        self.assertLess(action.index('!isNull objectParent _actor'),action.index('CBE_Operation'))
        for forbidden in [' doMove ', ' doTarget ', 'reveal', 'allUnits', 'allGroups']:
            self.assertNotIn(forbidden,action)
        compatibility_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCompatibility.sqf').read_text(encoding='utf-8')
        for base in ['SoldierWB','SoldierEB','SoldierGB']:
            self.assertIn(base,compatibility_audit)
        self.assertIn('COMPAT-exclusive-danger-fsm-',compatibility_audit)
        self.assertIn('find "z\\cbe\\addons\\danger\\danger.fsm"',compatibility_audit)
        self.assertNotIn('find "\\\\z\\\\cbe',compatibility_audit)

    def test_danger_static_support_is_one_actor_and_one_attempt_per_contact(self):
        support=source('cortexStaticSupport')
        self.assertNotIn('{canFire _x}',support)
        self.assertIn('_x emptyPositions "gunner" > 0',support)
        group_tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        for marker in [
            'CBE_AIPass_StaticSupport_Enable','nearestObjects [_anchor,["StaticWeapon"],75,true]',
            'crew _x isEqualTo []','damage _x < 0.9','someAmmo _x','_x != leader _group',
            '!isObjectHidden _x','isObjectHidden _weapon','ace_medical_ai_healQueue',
            'assignAsGunner _weapon','orderGetIn true','CBE_Danger_StaticAttempt',
            'CBE_Cortex_ActorMove",["STATIC_SUPPORT"','time+20'
        ]:
            self.assertIn(marker,support)
        self.assertIn('count (_group getVariable ["CBE_Operation",createHashMap]) > 0',support)
        self.assertIn('Failed physical attempts are not retried until a later contact',support)
        self.assertIn('if (_potential) exitWith {',support)
        self.assertIn('[_episode,time+3]',support)
        admission=support.split('private _candidates=',1)[1].split('if (_candidates isEqualTo [])',1)[0]
        active=support.split('if (count _lease >= 7) exitWith',1)[1].split('if (_leaseEpisode',1)[0]
        release=support.split('private _release=',1)[1].split('// Both contact',1)[0]
        for marker in ('simulationEnabled _x','!isObjectHidden _x','!fleeing _x',
                       '!([_x] call CBE_fnc_CortexActorMoveReserved)','currentCommand _x != "MOVE"'):
            self.assertIn(marker,admission)
        for marker in ('fleeing _actor','simulationEnabled _actor','isObjectHidden _actor'):
            self.assertIn(marker,active)
            self.assertIn(marker,release)
        self.assertNotIn('moveInGunner',support)
        self.assertNotIn('setPos',support)
        self.assertNotIn('allowDamage',support)
        self.assertIn('call CBE_fnc_CortexStaticSupport',group_tick)
        self.assertLess(group_tick.index('call CBE_fnc_CortexStaticSupport'),group_tick.index('call CBE_fnc_CortexTacticalStart'))
        self.assertIn('[_group,_state,[],true,_yieldToExternal] call CBE_fnc_CortexStaticSupport', restore)
        for marker in ['CBE_Danger_StaticSupport','orderGetIn false','unassignVehicle']:
            self.assertIn(marker,support)
        audit=(Path(__file__).parent/'cortexQA/runContact.sqf').read_text(encoding='utf-8')
        for marker in [
            'DANGER-static-support-disabled','DANGER-static-support-physical-seat',
            'DANGER-static-support-composable-fire','DANGER-static-support-contact-cleanup',
            'gunner _staticWeapon','CBE_CortexQA_Shots'
        ]:
            self.assertIn(marker,audit)
        for forbidden in ['moveInGunner','call CBE_fnc_CortexStaticSupport','call CBE_fnc_CortexRestoreCalm']:
            self.assertNotIn(forbidden,audit)

    def test_danger_static_deployment_is_finite_physical_and_owned(self):
        deploy=source('cortexStaticDeployStep')
        support=source('cortexStaticSupport')
        self.assertNotIn('{canFire _x}',support)
        self.assertIn('_x emptyPositions "gunner" > 0',support)
        restore=source('cortexRestoreCalm')
        for marker in [
            'CBE_AIPass_StaticDeploy_Enable','assembleInfo','assembleTo','"primary") == 1',
            '["PutBag",_assistant]','["Assemble",_supportBag]',
            'private _assembled=_record param [7,objNull,[objNull]]',
            'assignAsGunner _assembled','orderGetIn true',
            'local _assembled','crew _assembled isEqualTo []',
            'gunner _assembled == _gunner',
            'count _sector >= 2 && {!(_record param [17,false,[false]])}',
            '_assembled setDir (_assembled getDir _sector)',
            '_assistantBag,-1,+_targetPos,-1]',
            'CBE_Danger_StaticDeployment','CBE_Danger_StaticDeployAttempt',
            'lineIntersectsSurfaces','surfaceNormal _x',
            'crew _weapon isEqualTo [] && {vehicle _gunner == _gunner}',
            'WeaponDisassembled','["Disassemble",_weapon]',
            '["TakeBag",_primaryBag]','["TakeBag",_baseBag]',
            '"PACK_MOVING"','"PACKING"','"TAKING"','"PACKED"',
            'removeEventHandler ["WeaponDisassembled",_handler]'
        ]:
            self.assertIn(marker,deploy)
        ready=deploy.split('private _ready=',1)[1].split('// Prefer an actually complete pair',1)[0]
        for marker in ('!([_x] call CBE_fnc_CortexActorMoveReserved)','currentCommand _x != "MOVE"'):
            self.assertIn(marker,ready)
        reservation=source('cortexActorMoveReserved')
        self.assertLess(reservation.index('CBE_Danger_FlightLease'),reservation.index('private _lease='))
        unavailable=deploy.split('private _participantUnavailable=',1)[1].split('if (_participantUnavailable',1)[0]
        recall=deploy.split('private _canReleaseActor=',1)[1].split('private _cleanupAssemblyHolder=',1)[0]
        for marker in ('fleeing _actor','simulationEnabled _actor','isObjectHidden _actor'):
            self.assertIn(marker,unavailable)
            self.assertIn(marker,recall)
        for event in ('WeaponAssembled','WeaponDisassembled'):
            callback=deploy.split('addEventHandler ["'+event+'",',1)[1].split('}];',1)[0]
            for marker in ('!fleeing _actor','simulationEnabled _actor','!isObjectHidden _actor'):
                self.assertIn(marker,callback)
        self.assertIn('call CBE_fnc_CortexStaticDeployStep',support)

        selection=deploy.split('private _firstPrimaryIndex=',1)[1].split('if (_gunnerIndex < 0) exitWith',1)[0]
        self.assertIn('_ready findIf {_x != _primary && {(backpack _x) in _bases}} >= 0',selection)
        self.assertIn('_weaponClass isKindOf "StaticWeapon"',selection)
        self.assertIn('isText _base && {getText _base == ""}',selection)
        approach=deploy.split('if (_status == "MOVING") exitWith',1)[1].split('private _pairTogether=',1)[0]
        self.assertIn('if (time >= _deadline) exitWith',approach)
        solo_fixture=(Path(__file__).parent/'cortexQA/runStaticSolo.sqf').read_text()
        for forbidden in ['call CBE_fnc_CortexStaticDeployStep','moveInGunner','moveOut ',' reveal ']:
            self.assertNotIn(forbidden,solo_fixture)
        for evidence in ['WeaponAssembled','WeaponDisassembled','gunner (_seen select 0) == _actor',
                         'isNull _weapon','backpack _actor == _bagClass']:
            self.assertIn(evidence,solo_fixture)
        self.assertIn('isClass (configFile >> "CfgVehicles" >> _weaponClass)',selection)
        self.assertIn('if (_gunnerIndex < 0) then {_gunnerIndex=_firstPrimaryIndex}',selection)
        self.assertIn('((units _group) select [0,64]) select',deploy)

        self.assertIn('_current set [7,_assembled]',deploy)
        self.assertEqual(deploy.count('(_current param [19,[],[[]]]) isEqualTo [clientOwner,_owner getVariable ["CBE_AIPass_Epoch",0]]'),2)
        callbacks=deploy.split('addEventHandler ["WeaponDisassembled"',1)[1].split('_record set [1,"PACKING"]',1)[0]
        self.assertIn('group _assistant == _owner',callbacks)
        self.assertIn('CBE_fnc_CortexCombatEffective',callbacks)
        self.assertIn('!(_assistant in _newActors)',callbacks)

        self.assertIn('(_current param [10,-1,[0]]) == _thisEventHandler', callbacks)
        for event, boundary in [('WeaponAssembled', '_record set [12,_assemblyHandler]'),
                                ('WeaponDisassembled', '_record set [1,"PACKING"]')]:
            receipt = deploy.split('addEventHandler ["' + event + '"', 1)[1].split(boundary, 1)[0]
            for gate in ['time < (_current param [6,-1,[0]])', 'CBE_AIPass_Active',
                         'CBE_AIPass_StaticSupport_Enable', 'CBE_AIPass_StaticDeploy_Enable',
                         'ace_medical_ai_healQueue']:
                self.assertIn(gate, receipt)
        retirement = deploy.split('private _retire=', 1)[1].split('private _enabled=', 1)[0]
        self.assertLess(retirement.index('ace_medical_ai_healQueue'), retirement.index('orderGetIn false'))
        admission = deploy.split('private _ready=', 1)[1].split('private _gunnerIndex=', 1)[0]
        self.assertIn('ace_medical_ai_healQueue', admission)

        pack_permission=deploy.split('// Permission is live throughout packing',1)[1].split('private _reservedActors=',1)[0]
        self.assertIn('!_allowPack',pack_permission)
        self.assertIn('"PACK_EXITING","PACK_MOVING","PACKING","TAKING"',pack_permission)
        self.assertIn('[true] call _retire',pack_permission)
        self.assertNotIn('doMove',pack_permission)
        self.assertNotIn('doFollow',pack_permission)
        self.assertIn('private _observations=_enemies select [0,8]',deploy)
        self.assertIn('_record set [18,(_enemies select 0) param [0,objNull,[objNull]]]',deploy)
        sector=deploy.split('// Initial recognition can carry',1)[1].split('if (_phase == "CONTACT" && {_status == "PACK_MOVING"}',1)[0]
        self.assertIn('_record set [11,+_observedPosition]',sector)
        self.assertNotIn('_record set [5,',sector)
        self.assertNotIn('getPosATL _sectorTarget',sector)
        self.assertIn('gunner _assembled == _actor',deploy)
        self.assertIn('crew _assembled findIf {_x != _actor} < 0',deploy)
        self.assertIn('_current set [17,true]',deploy)
        self.assertNotIn('nearestObjects [_deployPos,[_expectedClass],8,true]',deploy)
        self.assertNotIn('moveInGunner',deploy)
        self.assertEqual(re.findall(r'createVehicle\s*\["([^"\n]+)"',deploy), ['GroundWeaponHolder_Scripted'])
        solo=deploy.split('if (_singlePart) exitWith',1)[1].split('// Keep the exact support bag',1)[0]
        for native in ['_gunner action ["Assemble",_holder]', '_record set [1,"ASSEMBLING"]',
                       'CBE_StaticAssemblyHolder', '_record set [29,_holder]']:
            self.assertIn(native,solo)
        self.assertNotIn('PutBag',solo)
        self.assertIn('_singlePart=isText _baseConfig && {getText _baseConfig == ""}',deploy)
        self.assertIn('count _bags == ([2,1] select _singlePart)',deploy)
        self.assertIn('if (!_singlePart) then {_assistant action ["TakeBag",_baseBag]}',deploy)
        holder=deploy.split('private _cleanupAssemblyHolder=',1)[1].split('private _retire=',1)[0]
        for guard in ['CBE_StaticAssemblyHolder', 'getWeaponCargo', 'getMagazineCargo',
                      'getItemCargo', 'getBackpackCargo', 'crew _holder isEqualTo []']:
            self.assertIn(guard,holder)
        self.assertEqual(deploy.count('deleteVehicle'),1)

        self.assertNotIn('setPos',deploy)
        self.assertNotIn('while {',deploy)
        self.assertNotIn('CortexQueueJob',deploy)
        self.assertIn('[_group,_state,[],false,true,_yieldToExternal] call CBE_fnc_CortexStaticDeployStep', restore)
        self.assertNotIn('private _staticDeployment=', restore)
        self.assertIn('CBE_Danger_StaticDeployAttempt', restore)
        release_only = deploy.split('if (_releaseOnly) exitWith', 1)[1].split('private _enabled=', 1)[0]
        self.assertIn('call _retire', release_only)
        self.assertNotIn('action [', release_only)
        self.assertLess(deploy.index('private _releaseActors='), deploy.index('[_gunner] call _clearActor'))
        actor_release = deploy.split('private _canReleaseActor=', 1)[1].split('private _retire=', 1)[0]
        for gate in ['_actor in _operationActors', 'CBE_Cortex_ActorMove',
                     'ace_medical_ai_healQueue', 'CortexCombatEffective', 'CompatibilityExternalControl']:
            self.assertIn(gate, actor_release)
        self.assertIn('(_releaseActors select 0)', deploy)
        self.assertIn('(_releaseActors select _forEachIndex)', deploy)
        group_tick=source('cortexGroupTick')
        self.assertIn('[_group,_state,[],!_ordered] call CBE_fnc_CortexStaticDeployStep',group_tick)
        self.assertIn('(_packingRecord param [1,""]) in ["PACK_EXITING","PACK_MOVING","PACKING","TAKING"]',group_tick)
        self.assertIn('(_state get "phase") in ["SEARCH","REGROUP"]',group_tick)
        self.assertNotIn('if (_staticPack in ["PACK_EXITING","PACK_MOVING","PACKING","TAKING"]) exitWith',group_tick)
        audit=(Path(__file__).parent/'cortexQA/runContact.sqf').read_text(encoding='utf-8')
        for marker in [
            'DANGER-static-deploy-config-prerequisite',
            'DANGER-static-deploy-physical-assembly',
            'DANGER-static-deploy-real-fire',
            'DANGER-static-deploy-facing-sector',
            'DANGER-static-deploy-contact-release',
            'DANGER-static-deploy-native-pack',
            'O_HMG_01_weapon_F','O_HMG_01_support_F'
        ]:
            self.assertIn(marker,audit)
        fixture=audit[audit.index('// A carried support team must use'):audit.index('sleep 8;',audit.index('// A carried support team must use'))]
        for forbidden in ['call CBE_fnc_CortexStaticDeployStep','moveInGunner','createVehicle [_deployExpected']:
            self.assertNotIn(forbidden,fixture.split('params [',1)[1])
        for setting in ['CBE_AIPass_PostContact_Enable','CBE_AIPass_PostContact_LostSeconds','CBE_AIPass_PostContact_SecuritySeconds']:
            self.assertIn(setting,fixture)

    def test_danger_action_owns_posture_without_owning_movement(self):
        reaction=source('dangerReact')
        self.assertIn('"MAINTAIN",""]',reaction)
        self.assertNotIn('if (_action == "MAINTAIN") exitWith',reaction)
        self.assertIn('CBE_Operation',reaction)
        self.assertIn('_action == "MAINTAIN" && {count _operation == 0}',reaction)
        self.assertIn('_action == "MAINTAIN" && {_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]}',reaction)
        self.assertIn('MAINTAIN means keep the committed route, not ignore the threat',reaction)
        self.assertIn('_action == "ENGAGE"',reaction)
        self.assertIn('private _desiredCombat',reaction)
        self.assertIn('if (_action in ["FORCED","VEHICLE"]) exitWith {"ASSESS"}',reaction)
        self.assertLess(reaction.index('if (_action in ["FORCED","VEHICLE"]'),reaction.index('setBehaviour "COMBAT"'))
        self.assertIn('combatMode _group in ["BLUE","GREEN"]',reaction)
        self.assertIn('exitWith {"ASSESS"}',reaction)
        self.assertNotIn('_priorCombat in ["BLUE","GREEN"]',reaction)
        self.assertNotIn('doMove',reaction)
        self.assertNotIn('doTarget',reaction)
        self.assertIn('case "EXPLOSION": {2.5}',reaction)
        self.assertNotIn("_responseDurations=createHashMapFromArray",reaction)

        pace=source('dangerAttackPace')
        self.assertIn('CBE_fnc_ActorSettings',pace)
        self.assertIn('_actor getHideFrom _target',pace)
        self.assertIn('leader _group == _actor || {morale _actor < 0}',pace)
        self.assertIn('_pace max 1',pace)
        self.assertNotIn('getPosATL _target',pace)
        self.assertNotIn(' doMove ',pace)
        self.assertIn('(_context select 4)+30',pace)
        self.assertIn('"DANGER_ATTACK"',source('actorSettings'))
        start=source('operationStart')
        self.assertIn('CBE_Danger_AttackPace',start)
        pace_cleanup=start.split('private _paceParticipants=',1)[1].split('// Relinquish finite weapon support',1)[0]
        self.assertIn('_participants select {!isNull _x && {group _x == _group}}',pace_cleanup)
        self.assertIn('forEach _paceParticipants;',pace_cleanup)
        self.assertIn('if (_paceParticipants findIf',pace_cleanup)
        self.assertNotIn('forEach (_participants',pace_cleanup)
        self.assertNotIn('if (_participants findIf',pace_cleanup)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runScheduler.sqf').read_text()
        for check in ('OPERATION-foreign-pace-real-setting-prerequisite',
                      'OPERATION-foreign-pace-preserved','OPERATION-foreign-pace-explicit-owner-release'):
            self.assertIn(check,qa)
        self.assertIn('getForcedSpeed _foreignActor == _foreignBaseline',qa)
        self.assertIn('isEqualTo _foreignReceipt',qa)
        self.assertIn('CBE_fnc_DangerAttackPace',source('dangerPostureStep'))
        retirement=source('dangerPostureStep')
        self.assertNotIn('_proof isEqualTo [] &&',retirement)
        self.assertLess(retirement.index('call CBE_fnc_DangerAttackPace'),retirement.index('if (_proof isEqualType []'))
        pace_retirement=retirement.split('// Speed and stance',1)[1].split('if (_proof isEqualType []',1)[0]
        self.assertIn('!( ["CHECK",_actor] call CBE_fnc_DangerAttackPace)',pace_retirement)
        self.assertLess(pace_retirement.index('["CHECK",_actor]'),pace_retirement.index('["RELEASE",_actor,true]'))
        self.assertIn('_waiting pushBackUnique _actor',retirement)
        self.assertIn('_cleanupRunning',pace)
        settings=source('actorSettings')
        self.assertIn('_mode == "RELEASE" && {_scope == "DANGER_ATTACK"}',settings)
        self.assertIn('(_paceProof select 0) isEqualTo _context',settings)
        self.assertIn('keys _owned findIf {_x != "SPEED"}',settings)
        self.assertIn('[_authorityGroup,_mode == "RELEASE",_actor]',settings)
        self.assertIn('private _paceActors=(units _group) select [0,64]',source('dangerSetup'))
        check=pace.split('if (_mode == "CHECK") exitWith',1)[1].split('if (_mode != "RELEASE"',1)[0]
        self.assertIn('CBE_OperationGeneration',check)
        self.assertIn('CBE_AIPass_Epoch',check)
        self.assertIn('["CHECK",_x] call CBE_fnc_DangerAttackPace',source('dangerSetup'))

    def test_native_group_contacts_survive_a_leader_cover_blind_spot(self):
        knowledge=source('cortexKnowledge')
        setup=source('dangerSetup')
        self.assertIn('CBE_Danger_ObservedContacts',setup)
        self.assertIn('CBE_Danger_ObservedContacts',knowledge)
        self.assertIn('private _candidateTargets=+(_leader targets [true, _range])',knowledge)
        self.assertIn('{_candidateTargets pushBackUnique (_x select 0)} forEach _observed',knowledge)
        self.assertIn('if ((_knowledge select 1) && {_observedAt > _personalSeen})',knowledge)
        self.assertIn('private _personalPosition=_knower getHideFrom _enemy',knowledge)
        self.assertNotIn('getPosATL (_x select 0)',knowledge)

    def test_operations_are_generation_scoped_and_zeus_cancels_before_release(self):
        start=source('operationStart')
        step=source('operationStep')
        cancel=source('operationCancel')
        release=source('operationRelease')
        zeus=source('cortexZeusMark')
        flank=source('cortexFlankStart')
        advance=source('cortexAdvanceStart')
        end=source('cortexFlankEnd')
        for required in ['intent','generation','ownerEpoch','objective','participants','route','lastProgressAt','cancelReason']:
            self.assertIn(required,start)
        self.assertIn('CBE_OperationGeneration',start)
        self.assertIn('private _objectiveSnapshot=if (_objective isEqualType []) then {+_objective} else {_objective};',start)
        self.assertIn('["objective",_objectiveSnapshot]',start)
        self.assertIn('["route",_routeSnapshot]',start)
        self.assertIn('private _routeSnapshot=+_route;',start)
        self.assertIn('count _route > 512',start)
        self.assertIn('count _objective in [0,2,3]',start)
        self.assertLess(start.index('count _route > 512'),start.index('private _routeSnapshot='))
        self.assertLess(start.index('count _route > 512'),start.index('private _objectiveSnapshot='))
        for guard in ('count _participants > 64','_participants findIf {!(_x isEqualType objNull)}',
                      'count (_participants arrayIntersect _participants) != count _participants',
                      '_participants=+_participants;','_pairElements=_pairElements apply {+_x};'):
            self.assertIn(guard,start)
            self.assertLess(start.index(guard),start.index('CBE_fnc_CortexLocality'))
            self.assertLess(start.index(guard),start.index('call CBE_fnc_OperationCancel'))
        self.assertNotIn('["objective",_objective]',start)
        geometry=start.split('// Validate the same private geometry',1)[1].split('// Reject a malformed optional partition',1)[0]
        for guard in ('count _point in [2,3]','!(_x isEqualType 0)','!finite _x',
                      '_objectiveSnapshot isNotEqualTo []','_routeSnapshot findIf {!(_x call _positionValid)} >= 0'):
            self.assertIn(guard,geometry)
        self.assertLess(start.index('private _routeSnapshot='),start.index('CBE_fnc_CortexLocality'))
        self.assertLess(start.index('_routeSnapshot findIf'),start.index('call CBE_fnc_OperationCancel'))
        transaction=start.split('private _cbeStartedOperation=createHashMap;',1)[1]
        self.assertTrue(transaction.startswith('\nisNil {\n_cbeStartedOperation=call {'))
        self.assertTrue(transaction.rstrip().endswith('};\n};\n_cbeStartedOperation'))
        self.assertLess(start.index('CBE_fnc_CortexLocality'),start.index('private _cbeStartedOperation='))
        for shared_step in ('private _previous=','private _generation=',
                            'call CBE_fnc_CortexFlankEnd','call CBE_fnc_OperationCancel',
                            'call CBE_fnc_CombatPairs','CBE_Danger_EngineStanceLease',
                            '_group setVariable ["CBE_OperationGeneration",_generation,true]',
                            '_group setVariable ["CBE_Operation",_operation,true]'):
            self.assertIn(shared_step,transaction)
        for forbidden in ('sleep ','uiSleep ','waitUntil','spawn '):
            self.assertNotIn(forbidden,transaction)
        # This boundary is required by a real scheduled caller, not a presumed PFH suspension.
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runScheduler.sqf').read_text()
        self.assertIn('call CBE_fnc_OperationStart',qa)
        self.assertIn('"OPERATION-objective-input-isolated"',qa)
        self.assertIn('"OPERATION-route-input-isolated"',qa)
        self.assertLess(qa.index('call CBE_fnc_OperationStart'),qa.index('_recoveryTarget set [0,'))
        self.assertLess(qa.index('_recoveryTarget set [0,'),qa.index('"OPERATION-objective-input-isolated"'))
        self.assertIn('(_recoveryRoute select 0) set [1,',qa)
        self.assertIn('"OPERATION-invalid-"+_case+"-preserves-current"',qa)
        self.assertIn('count _refused == 0',qa)
        self.assertIn('getVariable ["CBE_OperationGeneration",-2]) == _recoveryGeneration',qa)
        self.assertIn('isEqualTo _recoveryOperation',qa)
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text()
        self.assertIn('Return: Nothing (scheduled script)',server)
        self.assertIn('call compile preprocessFileLineNumbers "cortexQAScheduler.sqf"',server)
        self.assertIn('CBE_fnc_OperationCancel',start)
        self.assertIn('dangerAtStart',start)
        self.assertIn('private _operationAnchor=[_group] call CBE_fnc_CortexGroupAnchor;',start)
        self.assertIn('private _dangerPosture=(vehicle _operationAnchor) isEqualTo _operationAnchor;',start)
        self.assertIn('["dangerPosture",_dangerPosture]',start)
        self.assertIn('[_dangerObserver,_dangerCause,_dangerPosition,_dangerAction,_liveDanger select 3] call CBE_fnc_DangerReact',start)
        reaction=source('dangerReact')
        self.assertIn('_dangerAction,_liveDanger select 3] call CBE_fnc_DangerReact',start)
        self.assertIn('(time+_duration) min _responseUntil',reaction)
        self.assertLess(reaction.index('if (!(_responseUntil isEqualType 0)'),reaction.index('_group setBehaviour \"COMBAT\"'))
        deadline=13
        for transition in (10,11,12.9):
            self.assertEqual(min(transition+3,deadline),13)

        self.assertIn('[_operationAnchor,"RELEASE"] call CBE_fnc_DangerReact',start)
        self.assertLess(start.index('_group setVariable ["CBE_Operation",_operation,true]'),start.index('_dangerAction,_liveDanger select 3] call CBE_fnc_DangerReact'))
        self.assertIn('CBE_fnc_CortexGroupMoveClear',cancel)
        for native_path in ['dangerEngineMode','dangerEngineRecycle','dangerEngineSubmit']:
            self.assertIn('captive _source',source(native_path))
            self.assertIn('ace_captives_isSurrendering',source(native_path))
        progress=source('operationStep')
        self.assertIn('if (_changed) then {_group setVariable ["CBE_Operation",_operation,true]}',progress)
        self.assertIn('count _unavailable != _unavailableCount',progress)
        self.assertIn('_updated isNotEqualTo _records',progress)
        self.assertIn('if (_key in _recovery) then {_recoveryChanged=true}',progress)
        danger_config=(ROOT/'addons'/'danger'/'config.cpp').read_text(encoding='utf-8')
        self.assertIn('requiredAddons[] = {"cba_main", "A3_Characters_F"}',danger_config)
        end=source('cortexFlankEnd')
        movement=end.split('_members=_members select',1)[1].split('private _stragglers',1)[0]
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',movement)
        self.assertIn('CBE_fnc_CortexCombatEffective',movement)
        self.assertIn('"HEAL SOLDIER"',movement)
        self.assertLess(end.index('_members=_members select'),end.index('doStop _x'))
        ending=source('cortexFlankEnd')
        self.assertIn('private _mayRestore=_sameOperation',ending)
        self.assertIn('if (_mayRestore && {count _groupModeLease == 2}',ending)
        self.assertIn('if (_mayRestore && {count _groupSpeedLease == 2}',ending)
        self.assertIn('_liveDrill getOrDefault ["token",""]',ending)
        deploy=source('cortexStaticDeployStep')
        approach=deploy.split('if (!_atSector && {time >= _deadline-10}',1)[1].split('if (_atSector && {_pairTogether})',1)[0]
        self.assertIn('!(_record param [20,false,[false]])',approach)
        self.assertIn('_proof isEqualTo ["STATIC_DEPLOY",_deployPos,_deadline]',approach)
        self.assertIn('expectedDestination _x',approach)
        self.assertNotIn('_record set [6,',approach)
        self.assertNotIn('disableAI',approach)
        grenade=source('cortexThrowGrenade')
        self.assertEqual(grenade.count('captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}'),2)
        grenade_release=grenade.split('private _release =',1)[1]
        self.assertLess(grenade_release.index('captive _x'),grenade_release.index('forceWeaponFire'))
        manoeuvre=source('cortexFlankStep')
        target_guard=manoeuvre.split('private _intentTarget=',1)[1].split('// A queued drill',1)[0]
        self.assertIn('captive _intentTarget',target_guard)
        self.assertIn('"TARGET_NO_LONGER_HOSTILE" call _end',target_guard)
        self.assertNotIn('!alive _intentTarget',target_guard)
        self.assertLess(manoeuvre.index('"TARGET_NO_LONGER_HOSTILE"'),manoeuvre.index('_group setSpeedMode "FULL"'))
        self.assertIn('(side _group) getFriend (side _enemy) < 0.6',source('cortexKnowledge'))
        self.assertIn('!captive (_x select 0)',source('cortexKnowledge'))
        classifier=source('dangerActionSelect')
        self.assertIn('captive _source',classifier)
        self.assertLess(classifier.index('captive _source'),classifier.index('exitWith {"MAINTAIN"}'))
        knowledge=source('cortexKnowledge')
        self.assertIn('[_witness] call CBE_fnc_CortexCombatEffective',knowledge)
        self.assertIn('private _allMembers = (units _group) select {[_x] call CBE_fnc_CortexCombatEffective}',knowledge)
        self.assertIn('_leader=[_group] call CBE_fnc_CortexGroupAnchor',knowledge)
        self.assertIn('_witness knowsAbout _target >= 1',knowledge)
        danger=source('dangerStep')
        self.assertIn('private _otherWitnesses=',danger)
        self.assertIn('(_x param [5,objNull,[objNull]]) != _retiredWitness',danger)
        self.assertIn('private _retiredWitness=_responseActor;',danger)
        self.assertIn('private _responseUnavailable=count _activeAction >= 6',danger)
        forced=danger.split('if (_action == "FORCED") exitWith',1)[1].split('// This is a finite handoff',1)[0]
        self.assertIn('if (_remaining isNotEqualTo []) then {0.25} else {-1}',forced)
        assessment=source('dangerStep')
        refusal=assessment.split('if (_action == "RELEASE") exitWith',1)[1].split('if (_action != "FORCED"',1)[0]
        self.assertNotIn('setVariable',refusal)
        self.assertNotIn('GroupBrainStart',refusal)
        self.assertIn('_remaining isNotEqualTo []',refusal)
        self.assertLess(assessment.index('if (_action == "RELEASE")'),assessment.index('setVariable ["CBE_Danger_Contact",[_source'))
        classifier=source('dangerActionSelect')
        self.assertIn('if (count _event >= 6 && {!([_actor] call CBE_fnc_CortexCombatEffective)',classifier)
        self.assertIn('if (count _event < 6) then',classifier)
        self.assertLess(classifier.index('if (count _event >= 6'),classifier.index('call CBE_fnc_CortexGroupAnchor'))
        danger_step=source('dangerStep')
        self.assertIn('[_witness] call CBE_fnc_CortexCombatEffective',danger_step)
        self.assertLess(danger_step.index('[_witness] call CBE_fnc_CortexCombatEffective'),danger_step.index('call CBE_fnc_DangerSelect'))
        self.assertIn('[_priorObserver] call CBE_fnc_CortexCombatEffective',source('dangerRequest'))
        for intake in ['dangerRequest','dangerEngineSubmit']:
            self.assertIn('!([_actor] call CBE_fnc_CortexCombatEffective)',source(intake))
        contact=(ROOT/'releaseVerificationAndDeployment'/'cortexQA'/'runContact.sqf').read_text(encoding='utf-8')
        probe=contact.split('private _generationProbe=',1)[1].split('deleteVehicle _generationProbe',1)[0]
        self.assertLess(probe.index('call _phase'),probe.index('private _probeDeadline'))
        self.assertIn('isNil {',probe)
        self.assertLess(probe.index('isNil {'),probe.index('setVariable ["CBE_Danger_CoverPending"'))
        bounds=source('cortexFlankStep')
        self.assertIn('&& {[_x] call _actorTaskFree}',bounds)
        task_free=bounds.split('private _actorTaskFree={',1)[1].split('private _mayIssueMovement',1)[0]
        self.assertIn('!fleeing _actor',task_free)
        native_release=bounds.split('private _nativeTaskDisabled=[];',1)[1].split('private _ownedPathUnits=',1)[0]
        for guard in ('_feature == "PATH"','local _actor','group _actor == _group','CBE_fnc_CortexExternalOwner','CBE_fnc_CompatibilityExternalControl','fleeing _actor','ace_medical_ai_healQueue'):
            self.assertIn(guard,native_release)
        self.assertIn('_actor enableAI "PATH"',native_release)
        self.assertIn('if !(_actor checkAIFeature "PATH") then {_nativeTaskDisabled pushBack _x}',native_release)
        self.assertNotIn('doMove',native_release)
        self.assertNotIn('doFollow',native_release)
        self.assertIn('[_actor] call _mayIssueMovement',bounds)
        self.assertGreaterEqual(bounds.count('[_unit] call _mayIssueMovement'),3)
        restoration=bounds.split('private _restoreFeatures = {',1)[1].split('private _issue = {',1)[0]
        self.assertNotIn('if (local _unit &&',restoration)
        self.assertGreaterEqual(restoration.count('[_unit] call _mayIssueMovement'),5)
        cover=bounds.split('forEach (_fit - _units)',1)[0].rsplit('// Cover is a movement command too.',1)[1]
        self.assertLess(cover.index('[_x] call _mayIssueMovement'),cover.index('doStop _x'))
        self.assertNotIn('{call _mayIssueMovement}',bounds)
        step=source('operationStep')
        task=step.split('private _nativeTask=',1)[1].split('private _suspended=',1)[0]
        self.assertIn('ace_medical_ai_healQueue',task)
        self.assertIn('fleeing _actor',task)
        temporary=step.split('if (_reserved || {_nativeTask} || {_suspended}) then',1)[1].split('if (!_reserved',1)[0]
        self.assertIn('_recovery deleteAt _key',temporary)
        self.assertIn('_temporarilyOwned pushBack _actor',temporary)
        self.assertNotIn('_unavailable pushBack',temporary)
        self.assertNotIn('recoveryAttempts",',temporary)
        self.assertIn('!(_x in _temporarilyOwned)',step)
        recovery=source('recoveryStep')
        self.assertEqual(recovery.count('if (call _reserved) exitWith {"YIELDED"}'),2)
        self.assertEqual(recovery.count('ace_medical_ai_healQueue'),2)
        self.assertEqual(recovery.count('fleeing _actor'),2)
        self.assertLess(recovery.index('fleeing _actor'),recovery.index('if (_attempts >= 1)'))
        self.assertLess(recovery.rindex('fleeing _actor'),recovery.index('_used set [_key,_attempts+1]'))
        self.assertLess(recovery.index('ace_medical_ai_healQueue'),recovery.index('if (_attempts >= 1)'))
        self.assertLess(recovery.rindex('ace_medical_ai_healQueue'),recovery.index('_used set [_key,_attempts+1]'))
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',recovery)
        self.assertLess(recovery.index('if (call _reserved)'),recovery.index('if (_attempts >= 1)'))
        self.assertLess(recovery.rindex('if (call _reserved)'),recovery.index('_used set [_key,_attempts+1]'))
        self.assertIn('[_group,_generation] call CBE_fnc_CortexGroupMoveClear',cancel)
        self.assertIn('[_group,_generation] call CBE_fnc_CortexGroupMoveClear',release)
        for completion in [cancel,release]:
            self.assertIn('_operation getOrDefault ["ownerEpoch",-1]',completion)
            self.assertLess(completion.index('ownerEpoch'),completion.index('call CBE_fnc_CortexGroupMoveClear'))
        self.assertIn('toUpperANSI _reason != "OWNERSHIP_LOST"',cancel)
        self.assertIn('getOrDefault ["dangerPosture",false]',cancel)
        self.assertIn('getOrDefault ["dangerPosture",false]',release)
        self.assertIn('CBE_fnc_CortexGroupMoveClear',release)
        self.assertIn('private _dangerActor=objNull;',release)
        self.assertIn('_dangerActor=[_group] call CBE_fnc_CortexGroupAnchor;',release)
        self.assertIn('[_dangerActor,"RELEASE"] call CBE_fnc_DangerReact',release)
        for completion in [cancel,release]:
            self.assertIn('private _dangerEvent=_group getVariable ["CBE_Danger_ResponseEvent",[]];',completion)
            self.assertIn('_dangerEvent=_dangerResponse select [0,4];',completion)
            self.assertIn('(_dangerEvent param [2,-1,[0]]) != (_dangerResponse select 2)',completion)
            self.assertIn('call CBE_fnc_DangerActionSelect',completion)
            self.assertIn('call CBE_fnc_DangerReact',completion)
            self.assertIn('_dangerAction,_dangerResponse select 3] call CBE_fnc_DangerReact',completion)
            self.assertLess(completion.index('_group setVariable ["CBE_Operation",nil,true]'),completion.index('private _dangerEvent='))
        self.assertIn('CBE_fnc_CortexZeusHeld',step)
        self.assertIn('participantProgress',start)
        self.assertIn('participantProgress',step)
        self.assertIn('private _actorProgressed=simulationEnabled _actor && {!isObjectHidden _actor}',step)
        self.assertIn('&& {_currentPosition vectorDistance _lastPosition >= _minimum}',step)
        self.assertIn('[_lastPosition,_currentPosition] select _actorProgressed',step)
        self.assertNotIn('_updated pushBack [_actor,_currentPosition];',step)
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('CBE_Cortex_ClearStatus',clear)
        self.assertIn('material room/retry progress or egress',clear)
        self.assertIn('if (_entryTarget isEqualTo [] || {_entered}) then {_target}',clear)
        self.assertIn('_entryTarget getPos [3,_outward+60]',clear)
        self.assertIn('lastProgressActor',step)
        self.assertIn('A leader can deliberately provide exterior security during CLEAR',step)
        self.assertIn('if (_participants isEqualTo [] && {!_participantsRequired}) then',step)
        self.assertIn('getOrDefault ["ownerEpoch",-1]',step)
        self.assertIn('CBE_AIPass_Epoch',step)
        self.assertIn('exitWith {"LOST_OWNER"}',step)
        self.assertIn('CBE_fnc_OperationCancel',zeus)
        self.assertIn('CBE_fnc_OperationStart',flank)
        self.assertIn('CBE_fnc_OperationStart',advance)
        retreat=source('cortexRetreat')
        self.assertIn('[_group,"WITHDRAW",_point,_participants,[_point],"MOVING"] call CBE_fnc_OperationStart',retreat)
        self.assertIn('withdrawOperationGeneration',retreat)
        self.assertIn('CBE_fnc_OperationRelease',source('cortexGroupTick'))
        self.assertIn('CBE_fnc_RecoveryStep',source('cortexGroupTick'))
        self.assertIn('operationGeneration',end)
        self.assertIn('CBE_fnc_OperationStep',source('cortexFlankStep'))
        self.assertIn('["LOST_OWNER","ZEUS","EXTERNAL","REPLACED","STALLED"]',source('cortexFlankStep'))
        self.assertIn('CBE_fnc_RebalanceRoles',source('cortexFlankStep'))
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('cortex-clearance-active-',diagnostics)
        self.assertIn('CBE_Cortex_ClearStatus',diagnostics)
        self.assertIn('wait-operation-',diagnostics)
        self.assertIn('lastCallbackMs',source('cortexSchedulerTick'))
        self.assertIn('queueLatency',source('cortexSchedulerTick'))
        for marker in ['maxCallbackMs','maxRecordedQueueLatencySeconds','skippedJobs=',
                       'skipReasons=','recoveryAttempts=','unavailableActors=']:
            self.assertIn(marker,diagnostics)

    def test_manoeuvre_starts_use_a_surviving_local_anchor_instead_of_requiring_the_leader(self):
        for name in ['cortexAdvanceStart','cortexFlankStart','cortexRetreat','cortexCoordinatedAssault']:
            text=source(name)
            if name == 'cortexAdvanceStart':
                self.assertIn('else {[_group] call CBE_fnc_CortexGroupAnchor}',text)
                self.assertIn('if (isNull _leader && {!_elementScoped}) then {_leader=leader _group}',text)
            else:
                self.assertIn('private _leader = [_group] call CBE_fnc_CortexGroupAnchor;',text)
                self.assertIn('if (isNull _leader) then {_leader=leader _group};',text)
            self.assertNotIn('private _leader = leader _group;',text)
    def test_combined_ground_manoeuvre_uses_common_operation_lifecycle(self):
        combined=source('cortexCombinedArmsLocal')
        step=source('cortexCombinedGroundStep')
        self.assertIn('"COMBINED_GROUND",_target,[],[_destination],"MANOEUVRE"',combined)
        self.assertIn('"operationGeneration",_operation get "generation"',combined)
        self.assertIn('CBE_fnc_OperationRelease',step)
        self.assertIn('CBE_fnc_OperationCancel',step)

    def test_missile_defence_uses_the_shared_bounded_scheduler(self):
        discover=source("cortexDiscover")
        defence=source("cortexMissileDefenceStep")
        functions=(ROOT/"addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        handler=discover.split('addEventHandler ["IncomingMissile", {',1)[1].split('}];',1)[0]
        self.assertIn('CBE_fnc_CortexMissileDefenceStep',handler)
        self.assertIn('CBE_fnc_CortexQueueJob',handler)
        self.assertIn('"jobKey",format ["MISSILE_DEFENCE:%1",netId _vehicle]',handler)
        self.assertNotIn(' spawn ',handler)
        self.assertNotIn(' sleep ',handler)
        for marker in ['CBE_Cortex_FlareBurstGeneration','CBE_Cortex_MissileDefenceActive',
                       'CBE_fnc_CortexAircraftEligible','CBE_fnc_CortexFireCountermeasure',
                       '_step in [0,4]','_step >= 12','0.45+random 0.18']:
            self.assertIn(marker,defence)
        self.assertNotIn('spawn',defence)
        self.assertNotIn('sleep',defence)
        self.assertIn('class CortexMissileDefenceStep',functions)
        retarget=defence.split('private _homing=',1)[1].split('private _pilot=',1)[0]
        for proof in ('missileTarget _missile','!isNull _homing','alive _homing',
                      '_homing isKindOf "Air"','_homing isKindOf "LandVehicle"',
                      '_homing isKindOf "Ship"','_homing isKindOf "CAManBase"','vehicle _homing != _aircraft','"RETARGETED"','call _finish'):
            self.assertIn(proof,retarget)
        self.assertLess(defence.index('private _homing='),defence.index('call CBE_fnc_CortexFireCountermeasure'))
        self.assertNotIn('setMissileTarget',defence)
        self.assertIn('_state getOrDefault ["finishReason","THREAT_ENDED"]',defence)

    def test_cleanup_and_regroup_use_surviving_anchors_without_global_group_scans(self):
        """Cleanup and remnant recovery remain viable after leadership loss at large group counts."""
        calm=source('cortexRestoreCalm')
        self.assertIn('private _leader=[_group] call CBE_fnc_CortexGroupAnchor;',calm)
        self.assertIn('_unit doFollow _leader;',calm)
        regroup=source('cortexRegroupStep')
        self.assertIn('_origin nearEntities ["Man",_radius]',regroup)
        self.assertIn('private _leader = [_candidate] call CBE_fnc_CortexGroupAnchor;',regroup)
        self.assertNotIn('} forEach allGroups;',regroup)

    def test_morale_surrender_support_check_is_spatially_bounded_and_leader_resilient(self):
        """Broken squads must not scan every group or lose their surrender context during succession."""
        morale=source('cortexMorale')
        self.assertIn('private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;',morale)
        self.assertIn('_leaderPos nearEntities ["Man",300]',morale)
        self.assertNotIn('private _friendsNear = allGroups',morale)
        self.assertNotIn('allGroups findIf',morale)
        self.assertIn('_side getFriend (side group _x) >= 0.6',morale)
        self.assertNotIn('side group _x == _side',morale)
        surrender=morale.split('private _allOnFoot =',1)[1]
        self.assertIn('(_x select 2) <= 30 && {(_x select 3) < 60}',surrender)
        self.assertIn('["", "RETREAT"] select',surrender)

    def test_fresh_heavy_armour_overmatch_withdraws_without_suicidal_manoeuvre(self):
        """A rifle squad without usable AT must leave close armour to the finite withdrawal owner."""
        morale=source('cortexMorale')
        retreat=source('cortexRetreat')
        for marker in ['private _overmatchIndex=-1;',
                       '(_x select 2) <= 10',
                       '(_x select 3) <= 120',
                       'private _overmatched=!_hasAT && {_overmatchIndex >= 0}',
                       'waypointType [_group,_waypointIndex] in ["HOLD","SENTRY"]',
                       '_state set ["withdrawReason","HEAVY_ARMOUR_NO_AT"]',
                       '"RETREAT"']:
            self.assertIn(marker,morale)
        self.assertLess(morale.index('_state set ["withdrawReason","HEAVY_ARMOUR_NO_AT"]'),
                        morale.index('private _pressure ='))
        self.assertIn('_state getOrDefault ["withdrawReason","MORALE_WITHDRAWAL"]',retreat)
        scan=morale.split('private _armourIndex=-1;',1)[1].split('private _armour =',1)[0]
        self.assertEqual(scan.count('forEach _enemies'),1)
        self.assertIn('_overmatchIndex=_forEachIndex',scan)
        self.assertNotIn('_enemies select _armourIndex',scan)
        # Stale nearest armour must not mask a fresh second contact; pressure still
        # remembers old armour. Usable AT and authored holds keep their own veto.
        def decision(contacts, has_at=False, hold=False):
            pressure=any(armour and age <= 30 and distance <= 400 for armour,age,distance in contacts)
            immediate=any(armour and age <= 10 and distance <= 120 for armour,age,distance in contacts)
            return pressure, immediate and not has_at and not hold
        mixed=[(True,20,40),(False,0,50),(True,2,90)]
        self.assertEqual(decision(mixed),(True,True))
        self.assertEqual(decision(list(reversed(mixed))),(True,True))
        self.assertEqual(decision([(True,20,40)]),(True,False))
        self.assertEqual(decision(mixed,has_at=True),(True,False))
        self.assertEqual(decision(mixed,hold=True),(True,False))

        self.assertIn('[_group,_state,"RETREAT",_withdrawReason',retreat)

    def test_authored_hold_and_sentry_block_autonomous_movement_but_not_combat(self):
        """Stationary mission intent must gate every CBE movement owner without disabling fire control."""
        tick=source('cortexGroupTick')
        for marker in [
            'waypointType [_group,_waypointIndex] in ["HOLD","SENTRY"]',
            'waypointDescription [_group,_waypointIndex] != "CBE AI PASS"',
            '|| {_authoredStationary}',
        ]:
            self.assertIn(marker,tick)
        order_gate=tick.index('private _authoredStationary=')
        self.assertLess(order_gate,tick.index('[_group,_state] call CBE_fnc_CortexCoordinatedAssault'))
        self.assertLess(order_gate,tick.index('call CBE_fnc_CortexTacticalStart'))
        self.assertLess(order_gate,tick.index('case "SECURITY":'))
        self.assertIn('if (_outcome == "RETREAT" && {!_authoredStationary})',tick)
        self.assertIn('if (!_holdFire && {["CBE_AIPass_FireControl_Enable", true] call _get})',tick)

    def test_direct_assault_refuses_vehicle_mounted_and_static_targets(self):
        """Close vehicle contacts must remain with weapon and standoff logic, never infantry clear-through."""
        selector=source('cortexTacticalStart')
        assessment=source('cortexTacticalAssess')
        assault=source('cortexAssaultStart')
        for text in [assessment,assault]:
            self.assertIn('_target isKindOf "CAManBase"',text)
            self.assertIn('isNull objectParent _target',text)
        self.assertIn('"UNSUITABLE_ASSAULT_TARGET"',assault)
        self.assertLess(assessment.index('_target isKindOf "CAManBase"'),
                        assessment.index('_intent="ASSAULT"'))
        self.assertIn('call CBE_fnc_CortexTacticalAssess',selector)
        readiness=assessment.split('private _leaderSuppression=',1)[1].split('_result set ["intent",_intent]',1)[0]
        self.assertIn('getSuppression _leader',readiness)
        self.assertIn('_intent in ["ASSAULT","ADVANCE","FLANK"]',readiness)
        self.assertIn('_leaderSuppression >= 0.2',readiness)
        self.assertIn('"LEADER_SUPPRESSED"',readiness)
        for mutation in ('doMove','doStop','setWaypoint','setCombatMode','CortexFlankEnd'):
            self.assertNotIn(mutation,readiness)
        handoff=selector.split('if (_targetIndex < 0 || {_candidates isEqualTo []}) exitWith',1)[1].split('private _prioritiseContact=',1)[0]
        self.assertNotIn('CortexTacticalReposition',handoff)

    def test_autonomous_foot_manoeuvre_rejects_mobile_platform_contacts(self):
        """Vehicle contact may cause a finite safety reposition, but never a rifle assault route."""
        selector=source('cortexTacticalStart')
        assessment=source('cortexTacticalAssess')
        reposition=source('cortexTacticalReposition')
        for marker in [
            'private _manoeuvre=[];',
            '_target isKindOf "CAManBase" && {isNull objectParent _target}',
            '_platform isKindOf "StaticWeapon"',
            '_result set ["targetIndex",_selected]',
            '"ARMOUR_OVERMATCH"'
        ]:
            self.assertIn(marker,assessment)
        self.assertIn('case "REPOSITION"',selector)
        self.assertIn('if (_started) exitWith {_intent=_x}',selector)
        self.assertEqual(selector.count('setVariable ["CBE_Cortex_TacticalAssessment"'),2)
        self.assertIn('["NATIVE_REASSESS","STARTED"] select _started',selector)
        self.assertIn('_reason == "ARMOUR_OVERMATCH"',reposition)
        self.assertIn('_distance <= 120',reposition)
        self.assertIn('call CBE_fnc_CortexSelectAvenue',reposition)
        self.assertNotIn('setPos',reposition)

    def test_medical_assistance_can_treat_a_wounded_leader_without_self_treatment(self):
        """Leader succession must not make a leader ineligible for aid or select a medic as their own patient."""
        medical=source('cortexMedicalStep')
        self.assertIn('private _casualties=_members select {damage _x >= _threshold};',medical)
        self.assertIn('if (_medic != _x && {_distance < _best}',medical)
        self.assertNotIn('_x != leader _group && {damage _x >= _threshold}',medical)

    def test_medical_assistance_is_bounded_and_yields_to_competing_owners(self):
        medical=source('cortexMedicalStep')
        tick=source('cortexGroupTick')
        self.assertIn('CBE_AIPass_MedicalAssist_Enable',medical)
        self.assertIn('CBE_fnc_CortexZeusHeld',medical)
        self.assertIn('CBE_fnc_CompatibilityExternalControl',medical)
        self.assertNotIn('medicalBackend',medical)
        self.assertIn('_medic action ["HealSoldier",_casualty]',medical)
        self.assertIn('_medic doMove _approach',medical)
        self.assertIn('_medic doMove _approach',medical)
        self.assertNotIn('_medic setDestination',medical)
        self.assertNotIn('doHeal',medical)
        self.assertIn('CBE_fnc_OperationStart',medical)
        self.assertIn('CBE_fnc_OperationStep',medical)
        self.assertIn('CBE_fnc_OperationCancel',medical)
        self.assertIn('CBE_fnc_OperationRelease',medical)
        finish=medical.split('private _finish = {',1)[1].split('private _medicalEnabled=',1)[0]
        for guard in ('count _aid == 9','isNil {','CBE_fnc_NativeOrderReceipt',
                      'CBE_fnc_CortexExternalTakeover','CBE_fnc_CortexActorMoveReserved',
                      'currentCommand _medic == "MOVE"','_destination vectorDistance _approach <= 0.25',
                      'ownerEpoch','"MEDICAL_AID"'):
            self.assertLess(finish.index(guard),finish.index('_medic doFollow leader _group;'))
        self.assertNotIn('CancelAction',finish)
        self.assertLess(finish.index('_medic doFollow leader _group;'),finish.index('CBE_fnc_OperationCancel'))
        self.assertIn('private _mayIssueMedical = {',medical)
        eligible=medical.split('private _actorEligible={',1)[1].split('private _finish = {',1)[0]
        for guard in ('simulationEnabled _actor','!isObjectHidden _actor','!fleeing _actor',
                      '(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []'):
            self.assertIn(guard,eligible)
        self.assertIn('[_medic] call _actorEligible',medical)
        self.assertIn('[_casualty] call _actorEligible',medical)
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',medical)
        self.assertIn('if !([_medic,_casualty] call _mayIssueMedical) exitWith {["CANCELLED","EXTERNAL"] call _finish};',medical)
        self.assertLess(medical.index('private _mayIssueMedical = {'),medical.index('_medic doMove _approach'))
        self.assertLess(medical.rindex('call _mayIssueMedical',0,medical.rindex('_medic action ["HealSoldier",_casualty]')),medical.rindex('_medic action ["HealSoldier",_casualty]'))
        self.assertIn('private _dangerResponse=_group getVariable ["CBE_Danger_Response",[]];',medical)
        self.assertIn('private _dangerActive=count _dangerResponse == 5',medical)
        self.assertIn('if (_dangerActive) exitWith {["CANCELLED","COMBAT_RESUMED"] call _finish};',medical)
        self.assertIn('if (_dangerActive) exitWith {false};',medical)
        self.assertLess(medical.index('if (_dangerActive) exitWith {["CANCELLED","COMBAT_RESUMED"] call _finish};'),medical.index('_aid params'))
        self.assertIn('_phase in ["CALM","SECURITY"]',medical)
        self.assertIn('COMBAT_RESUMED',medical)
        self.assertIn('NO_PROGRESS',medical)
        self.assertIn('if (!_inTreatmentRange) then {',medical)
        self.assertIn('private _distance=(getPosASL _medic) vectorDistance (getPosASL _casualty);',medical)
        self.assertIn('native HealSoldier action can work',medical)
        kits=medical.split('private _hasMedicalKit={',1)[1].split('private _finish = {',1)[0]
        for kit in ('items _medic','isKindOf ["Medikit",configFile >> "CfgWeapons"]',
                    'isKindOf ["FirstAidKit",configFile >> "CfgWeapons"]'):
            self.assertIn(kit,kits)
        self.assertIn('&& {[_x] call _hasMedicalKit}',medical)
        self.assertIn('if ([_medic] call _hasMedicalKit) then {',medical)
        self.assertIn('"NO_MEDICAL_KIT"',medical)
        for forbidden in ('addItem','removeItem','addMagazine','setDamage'):
            self.assertNotIn(forbidden,kits)
        self.assertIn('count _aid != 9 || {(_aid select 7) isNotEqualTo _medicalOrder}',medical)
        self.assertIn('time,time,_best,time,+_medicalOrder,+_approach],true]',medical)
        self.assertIn('if (_authoredOrder && {!_stationaryOrder}) exitWith {false};',medical)
        self.assertIn('!_stationaryOrder || {_distance <= 4',medical)
        self.assertIn('if (_stationaryOrder && {!_inTreatmentRange}) exitWith',medical)
        self.assertIn('private _requestedApproach=_aid select 8;',medical)
        self.assertIn('currentCommand _casualty == "MOVE"',medical)
        self.assertIn('_destination vectorDistance _requestedApproach > 0.25',medical)
        self.assertIn('_aid set [8,+_approach];',medical)
        self.assertIn('currentCommand _x in ["MOVE","ATTACK","FIRE","SUPPRESS"',medical)
        self.assertLess(medical.index('private _requestedApproach='),medical.index('if (damage _casualty <'))
        self.assertLess(medical.index('count _aid != 9'),medical.index('if (damage _casualty <'))
        permission=medical.split('private _mayIssueMedical = {',1)[1].split('private _aid=',1)[0]
        self.assertIn('CBE_fnc_NativeOrderReceipt) isEqualTo _medicalOrder',permission)
        for forbidden in ['setDamage', 'setPos', 'joinSilent', 'addWaypoint']:
            self.assertNotIn(forbidden,medical)
        self.assertIn('CBE_fnc_CortexMedicalStep',tick)

    def test_recovery_quarantines_only_an_exhausted_actor_from_common_operation_progress(self):
        start=source('operationStart')
        step=source('operationStep')
        recovery=source('recoveryStep')
        self.assertIn('["unavailable",[]]',start)
        self.assertIn('private _originalParticipants=',step)
        self.assertIn('private _unavailable=',step)
        self.assertIn('time-_startedAt >= _staleSeconds',step)
        self.assertIn('private _participants=_originalParticipants select {!(_x in _unavailable) && {!(_x in _recovering)} && {!(_x in _temporarilyOwned)}}',step)
        self.assertIn('Recovery actors are intentionally absent from aggregate progress',step)
        self.assertIn('_recovery set [_key,[_attempts,time,+_destination,_currentPosition]]',step)
        self.assertIn('_operation set ["unavailable",_unavailable]',step)
        self.assertIn('_recovery deleteAt (netId _actor)',step)
        rebalance=source('rebalanceRoles')
        self.assertIn('CBE_fnc_CortexExternalTakeover',rebalance)
        self.assertIn('_operation getOrDefault ["ownerEpoch",-1]',rebalance)
        self.assertIn('private _blocked=(_operation getOrDefault ["unavailable",[]])+_excluded',rebalance)
        eligibility=rebalance.split('private _actorEligible=',1)[1].split('private _capable=',1)[0]
        self.assertIn('(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []',eligibility)
        self.assertNotIn('setVariable ["ace_medical_ai_healQueue"',rebalance)

        flank=source('cortexFlankStep')
        self.assertIn('[_group,_operationGeneration,count _units,(units _group)-_units] call CBE_fnc_RebalanceRoles;',flank)
        self.assertNotIn('[_group,_operationGeneration,count _units,_units] call CBE_fnc_RebalanceRoles;',flank)
        self.assertEqual(recovery.count('_actor doMove _destination'),1)
        self.assertNotIn('setDestination [_destination',recovery)
        self.assertNotIn('_actor enableAI "PATH"',recovery)
        self.assertIn('_operation getOrDefault ["ownerEpoch",-1]',recovery)
        self.assertIn('_recovery set [_key,[_attempts+1,time,+_destination,getPosATL _actor]]',recovery)
        self.assertNotIn('setPos',recovery)

    def test_operation_owners_exit_at_function_scope_after_terminal_common_status(self):
        convoy=source('convoyTick')
        clear=source('buildingOperationStep')
        self.assertIn('private _operationEndReason = "";',convoy)
        self.assertIn('if (_operationEndReason != "") exitWith {',convoy)
        convoy_exit=convoy.split('if (_operationEndReason != "") exitWith {',1)[1]
        self.assertIn('CBE_fnc_ConvoyReleaseLocal',convoy_exit)
        self.assertLess(convoy.index('if (_operationEndReason != "") exitWith {'),convoy.index('formation _group != "COLUMN"'))
        self.assertIn('private _operationEndReason="";',clear)
        self.assertIn('if (_operationEndReason != "") exitWith {',clear)
        clear_exit=clear.split('if (_operationEndReason != "") exitWith {',1)[1]
        self.assertIn('[false,_operationEndReason] call _finish',clear_exit)
        self.assertLess(clear.index('if (_operationEndReason != "") exitWith {'),clear.index('private _operation=_group getVariable'))

    def test_stale_combined_ground_callback_cannot_release_replacement_lease(self):
        step=source('cortexCombinedGroundStep')
        self.assertIn('private _operationMatches=count _operation > 0',step)
        self.assertIn('(_operation getOrDefault ["generation",-2]) == _operationGeneration',step)
        self.assertIn('(_operation getOrDefault ["intent",""]) == "COMBINED_GROUND"',step)
        self.assertIn('if (_operationMatches && {(_lease param [0,""]) == "COMBINED_GROUND"}) then {',step)
        self.assertNotIn('if ((_lease param [0,""]) == "COMBINED_GROUND") then {',step)

    def test_danger_reaction_is_scoped_and_never_issues_movement(self):
        reaction=source('dangerReact')
        for forbidden in [' doMove ', ' doFollow ', ' setDestination ', 'addWaypoint']:
            self.assertNotIn(forbidden,reaction)
        self.assertIn('CBE_Danger_ReactionLease',reaction)
        self.assertIn('CBE_Operation',reaction)
        self.assertIn('CBE_fnc_CortexExternalTakeover',reaction)
        self.assertIn('"POSTURE"',reaction)
        self.assertIn('private _leaseIntact',reaction)
        self.assertIn('private _postureActor=[_group] call CBE_fnc_CortexGroupAnchor;',reaction)
        self.assertIn('if (isNull _postureActor) then {_postureActor=leader _group};',reaction)
        self.assertIn('behaviour _postureActor == _ownedBehaviour',reaction)
        self.assertIn('behaviour _postureActor == (_lease select 1)',reaction)
        self.assertNotIn('behaviour leader _group == _ownedBehaviour',reaction)
        self.assertIn('max (if (_leaseIntact) then {_lease select 4} else {-1})',reaction)
        self.assertIn('"RELEASE"',reaction)
        self.assertIn('_cause == "RELEASE"',reaction)
        self.assertNotIn('CBE_Danger_Immediate',reaction)
        step=source('dangerStep')
        self.assertIn('CBE_fnc_DangerReact',step)
        self.assertIn('[_actor,"RELEASE"] call CBE_fnc_DangerReact',step)
        self.assertIn('[_dangerActor,"RELEASE"] call CBE_fnc_DangerReact',source('cortexReleaseGroup'))

    def test_engine_danger_reflex_obeys_runtime_feature_and_pause_gates(self):
        feature=source('cortexFeatureEnabled')
        for guard in ('_setting == ""','_enabled isEqualType true','_disabled isEqualType []'):
            self.assertIn(guard,feature)
        self.assertLess(feature.index('_enabled isEqualType true'),feature.index('isNull _group'))
        self.assertLess(feature.index('_setting in _disabled'),feature.index('CBE_fnc_CompatibilityExternalControl'))
        self.assertIn('CBE_Driving_DisabledFeatures',feature)
        self.assertIn('_vehicleDisabled isEqualType []',feature)
        self.assertIn('_setting in _vehicleDisabled',feature)
        self.assertLess(feature.index('!_enabled'),feature.index('CBE_Driving_DisabledFeatures'))
        convoy=source('convoyTick')
        self.assertIn('"CBE_Convoy_DrivingAssist_Enable",true,_lead] call',convoy)
        self.assertIn('"CBE_Convoy_DrivingAssist_Enable",true,_vehicle] call',convoy)
        follower=convoy.split('private _pathAssistEnabled=',1)[1]
        self.assertIn('private _traffic=if (_pathAssistEnabled)',follower)
        self.assertNotIn('private _traffic=if (_trafficAssistEnabled)',follower)
        for name in ('drivingCrewStep','drivingGateOpenServer','drivingBypassStep',
                     'drivingCorridorStep','drivingPassAdmission','drivingPassCanConsent','drivingQueueProposalCurrent'):
            self.assertRegex(source(name),r'(?:true|false),_vehicle\] call CBE_fnc_CortexFeatureEnabled')
        self.assertIn('[_group,_feature,true,_vehicle]',source('drivingNativePathWatch'))

        ownership=source('compatibilityExternalControl')
        self.assertIn('!(_declared isEqualType true) || {_declared}',ownership)
        self.assertIn('!(_groupDeclared isEqualType true) || {_groupDeclared}',ownership)
        mode=source('dangerEngineMode')
        action=source('dangerEngineAct')
        for text in [mode,action]:
            self.assertIn('CBE_AIPass_Active',text)
            self.assertIn('CBE_AIPass_Danger_Enable',text)
            self.assertIn('CBE_fnc_CortexFeatureEnabled',text)
            self.assertIn('CBE_fnc_CortexIsEligible',text)
            self.assertIn('CBE_fnc_CortexIsPaused',text)
            self.assertIn('[_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible',text)
        self.assertIn('CBE_fnc_CortexExternalTakeover',source('cortexIsEligible'))
        self.assertLess(mode.index('CBE_AIPass_Danger_Enable'),mode.index('ace_medical_ai_healQueue'))
        self.assertLess(action.index('CBE_AIPass_Danger_Enable'),action.index('private _baseDelay='))

    def test_danger_cleanup_never_restores_wait_posture_after_ownership_takeover(self):
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        step=source('dangerStep')
        setup=source('dangerSetup')
        self.assertIn('CBE_fnc_DangerReact',fsm)
        self.assertIn('[_dangerActor,""RELEASE""] call CBE_fnc_DangerReact',fsm)
        self.assertIn('private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;',step)
        self.assertIn('if (!_yieldToOwner) then {[_actor,"RELEASE"] call CBE_fnc_DangerReact}',step)
        self.assertIn('if (!_yieldToOwner) then {[_actor,"RESTORE"] call CBE_fnc_DangerReact}',step)
        self.assertIn('private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;',setup)
        self.assertIn('private _dangerActor=[_group] call CBE_fnc_CortexGroupAnchor;',setup)
        request=source('dangerRequest')
        self.assertIn('CBE_fnc_CortexExternalTakeover',request)
        self.assertIn('CBE_fnc_CortexExternalTakeover',setup)
        self.assertIn('if (_yieldToOwner) exitWith {',step)
        self.assertNotIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',step)
        reaction=source('dangerReact')
        tick=source('cortexGroupTick')
        self.assertIn('private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;',reaction)
        self.assertIn('if (_yieldToOwner) exitWith {',reaction)
        self.assertIn('private _dangerYield=[_group] call CBE_fnc_CortexExternalTakeover;',tick)
        self.assertIn('private _dangerActor=[_group] call CBE_fnc_CortexGroupAnchor;',tick)
        self.assertIn('[_dangerActor,"RESTORE"] call CBE_fnc_DangerReact',tick)

    def test_danger_generation_cleanup_cannot_reuse_an_invalidated_fsm(self):
        request=source('dangerRequest')
        setup=source('dangerSetup')
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        self.assertIn('(_running select 1) isEqualTo (_group getVariable ["CBE_Danger_Generation",0])',request)
        self.assertIn('private _dangerCoverLease=_group getVariable ["CBE_Danger_CoverLease",[]];',setup)
        self.assertIn('call CBE_fnc_DangerCoverStep',setup)
        self.assertIn('_group setVariable ["CBE_Danger_Generation",(_group getVariable ["CBE_Danger_Generation",0])+1];',setup)
        generation=setup.index('_group setVariable ["CBE_Danger_Generation"')
        self.assertGreater(setup.index('_group setVariable ["CBE_Danger_FSM",nil];'),generation)
        for marker in ['CBE_Danger_LastAssessment','CBE_Danger_WakeAfter']:
            self.assertIn(f'_group setVariable ["{marker}",nil];',setup)
        # Natural finite completion must also close generation-scoped identity. Otherwise the next
        # generation can inspect the former observer's native task before selecting its own event.
        self.assertIn('_group setVariable [""CBE_Danger_LastAssessment"",nil]',fsm)
        self.assertIn('_group setVariable [""CBE_Danger_VehicleContext"",nil,true]',fsm)
        self.assertLess(fsm.index('CBE_Danger_LastAssessment'),fsm.index('CBE_Danger_Response'))

    def test_live_danger_setting_reconfigures_owner_local_observers_without_a_second_worker(self):
        callback=source('aiTweaksSettingChanged')
        self.assertIn('if (_name == "CBE_AIPass_Danger_Enable"',callback)
        self.assertIn('{if (local _x) then {[_x] call CBE_fnc_DangerSetup}} forEach allGroups;',callback)
        self.assertNotIn('CBE_fnc_CortexQueueJob',callback)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',callback)

    def test_group_release_yields_cleanup_to_zeus_and_other_active_owners(self):
        release=source('cortexReleaseGroup')
        self.assertIn('private _yieldToZeus=',release)
        self.assertIn('CBE_fnc_CortexExternalTakeover',release)
        self.assertIn('"EXTERNAL_TAKEOVER"',release)
        self.assertIn('_reason in ["ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]',release)

    def test_group_move_commits_equivalent_requests_without_waypoint_churn(self):
        move=source('cortexGroupMove')
        clear=source('cortexGroupMoveClear')
        self.assertIn('CBE_Cortex_GroupMoveIntent',move)
        self.assertIn('private _sameRequest',move)
        self.assertIn('if (_sameRequest) exitWith {',move)
        retreat_scope=source('cortexGroupTick').split('case "RETREAT": {',1)[1]
        self.assertIn('_withdrawKind in ["WITHDRAW","VEHICLE_WITHDRAW"]',retreat_scope)
        self.assertIn('if (_withdrawOwner && {(_shortWithdrawal || {_stalled})}',retreat_scope)
        same_route=source('cortexGroupMove').split('if (_sameRequest) exitWith {',1)[1].split('// A curator',1)[0]
        self.assertIn('_intent set ["operationGeneration",_operationGeneration]',same_route)
        self.assertNotIn('addWaypoint',same_route)
        self.assertNotIn('setCurrentWaypoint',same_route)

        self.assertLess(move.index('if (_sameRequest) exitWith {'),
                        move.index('call CBE_fnc_CortexGroupMoveClear'))
        self.assertIn('if (isNull _group || {!local _group}',move)
        self.assertIn('[_group,false,false,true] call CBE_fnc_CortexIsEligible',move)
        self.assertGreaterEqual(move.count('CBE_fnc_CortexExternalTakeover'),2)
        self.assertLess(move.index('CBE_fnc_CortexExternalTakeover'),move.index('_group addWaypoint'))
        eligible=source('cortexIsEligible')
        self.assertIn('[_group,_ignoreZeusHold,_actorContext] call CBE_fnc_CortexExternalTakeover',eligible)
        self.assertLess(eligible.index('call CBE_fnc_CortexExternalTakeover'),eligible.index('private _alive ='))
        self.assertIn('if (isNull _actorContext) then {(units _group) select {alive _x}} else',eligible)
        self.assertIn('[_actorContext] select {alive _x && {group _x == _group}}',eligible)
        self.assertNotIn('_alive=_alive select',eligible)
        takeover=source('cortexExternalTakeover')
        for veto in ('_members findIf {isPlayer _x}', '_members findIf {!isNull (remoteControlled _x)}',
                     'bis_fnc_moduleRemoteControl_owner'):
            self.assertIn(veto,takeover)

        self.assertIn('Direct remote control and all other',source('cortexExternalTakeover'))
        self.assertIn('if (isNull _group || {!local _group}',clear)
        self.assertIn('_group setVariable ["CBE_Cortex_GroupMoveIntent", nil, true]',clear)
        self.assertIn('private _ownedWaypoint',clear)
        self.assertIn('waypointPosition _previousWaypoint distance2D _previousPosition > 1',move)
        self.assertIn('[_group,true,_previousWaypoint select 1] call CBE_fnc_CortexZeusMark',move)
        self.assertLess(move.index('call CBE_fnc_CortexZeusMark'),move.index('if (_sameRequest)'))
        self.assertIn('CBE_Cortex_ZeusOrderSnapshot',clear)
        self.assertIn('waypointPosition _ownedWaypoint distance2D _position > 1',clear)
        self.assertIn('_ownedWaypoint setWaypointDescription ""',clear)
        self.assertNotIn('for "_index" from (count waypoints',clear)
        self.assertEqual(clear.count('deleteWaypoint _ownedWaypoint'),1)
        self.assertLess(clear.index('if (_curatorClaim || {_edited})'),clear.index('deleteWaypoint _ownedWaypoint'))
        self.assertIn('["_operationGeneration", -1, [0]]',clear)
        self.assertIn('operationGeneration",-1]) != _operationGeneration',clear)
        self.assertIn('operationGeneration", _operationGeneration',move)
        self.assertIn('getOrDefault ["generation",-1]',move)
        self.assertIn('waypointDescription _ownedWaypoint == "CBE AI PASS"',clear)
        legacy_marker='W' + 'MP AI PASS'
        self.assertNotIn(legacy_marker,move)
        self.assertNotIn(legacy_marker,clear)

    def test_building_clearance_uses_the_common_operation_lifecycle(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('[_group,"CLEAR",_building,_team,_positions,"ENTRY"] call CBE_fnc_OperationStart',clear)
        self.assertIn('operationGeneration',clear)
        self.assertIn('CBE_fnc_OperationStep',clear)
        self.assertIn('CBE_fnc_OperationRelease',clear)
        self.assertIn('CBE_fnc_OperationCancel',clear)
        self.assertIn('[false,"EXTERNAL"] call _finish',clear)

    def test_cortex_control_deduplicates_settings_and_diagnostics_explain_once(self):
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('Expected evidence:',diagnostics)
        self.assertIn('not an action trigger or success result',diagnostics)
        self.assertNotIn('Trigger/inspection:',diagnostics)
        self.assertIn('private _seenTuningKeys=createHashMap',diagnostics)
        self.assertIn('_tuningSpec pushBack _x',diagnostics)
        client=(ROOT/'releaseVerificationAndDeployment/cortexQA/runClient.sqf').read_text(encoding='utf-8')
        self.assertIn('UI-01b-canonical-settings',client)
        self.assertIn('UI-registered-',client)
        self.assertIn('arrayIntersect _keys',client)

    def test_current_audits_do_not_set_removed_danger_ownership_mode(self):
        for audit in (ROOT/'releaseVerificationAndDeployment/cortexQA').glob('*.sqf'):
            self.assertNotIn('CBE_AIPass_InfantryOwnership',audit.read_text(),audit.name)

    def test_cfgfunctions_exports_only_wait_api_without_legacy_aipass_aliases(self):
        exports=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertNotIn('class AIPass',exports)
        self.assertNotIn('Legacy mission API aliases',exports)
        self.assertIn('class CortexInit',exports)
        self.assertIn('class OperationStart',exports)
    def test_configuration_has_no_duplicate_zen_panel_or_variable_bridge(self):
        modules=(ROOT/'addons/main/bootstrap/zenRegister.sqf').read_text()
        exports=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        preinit=(ROOT/'addons/main/XEH_preInit.sqf').read_text()
        self.assertNotIn('"AI Control"',modules)
        self.assertIn('CBE_fnc_ZenConvoyModule',modules)
        for obsolete in ['CortexControlOpenLocal','CortexControlPageLocal','AITweaksSettingsRequestServer']:
            self.assertNotIn('class '+obsolete+' ',exports)
        self.assertNotIn('CBE_AITweaks_SettingsRequest',preinit)

    def test_cortex_control_distinguishes_master_gates_from_feature_switches(self):
        spec=source('cortexTuningSpec')
        for label in [
            'Apply CBE skill profiles',
            'Enable Cortex automatic tactics',
            'Enable Cortex vehicle tactics',
            'Enable spotter artillery support',
            'Proactive attack-run countermeasures',
            'Missile-threat countermeasures',
            'Selected CBE skill profile',
        ]:
            self.assertIn(label,spec)
        self.assertIn('"AIR_DEFENCE"',spec)
        self.assertNotIn('"Skill profiles",',spec)
        self.assertNotIn('"Cortex behaviours",',spec)

    def test_cortex_control_spec_has_one_canonical_row_per_setting(self):
        spec=source('cortexTuningSpec')
        keys=re.findall(r'^\s*\["(CBE_[A-Za-z0-9_]+)"\s*,',spec,re.MULTILINE)
        self.assertGreater(len(keys),40)
        duplicates=sorted({key for key in keys if keys.count(key)>1})
        self.assertEqual([],duplicates)

    def test_cba_catalogue_has_registered_sections_and_matching_shipped_defaults(self):
        """Every CBA control must have one section and the same primitive default as aiConfig."""
        spec=source('cortexTuningSpec')
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        sections=source('aiTweaksSettingsSections')
        registration=source('aiTweaksRegisterSettings')
        section_keys=set(re.findall(r'^\s*\["([A-Z_]+)",\s*"\d\d ',sections,re.MULTILINE))
        rows=re.findall(
            r'^\s*\["(CBE_[^"]+)",.*?,\s*"(?:CHECKBOX|SLIDER|COMBO)",\s*.*?,\s*'
            r'(true|false|-?\d+(?:\.\d+)?|"[^"]*"),\s*"([A-Z_]+)",\s*'
            r'"(?:LIVE|NEXT_OPERATION|RESTART_REQUIRED)"\],',
            spec,
            re.MULTILINE,
        )
        shipped=dict(re.findall(r'^\s*\["(CBE_[^"]+)",\s*(.+?)\],(?:\s*//.*)?$',config,re.MULTILINE))
        self.assertGreater(len(rows),100)
        self.assertEqual([],sorted({section for _,_,section in rows}-section_keys))
        self.assertEqual([],sorted(key for key,_,_ in rows if key not in shipped))
        self.assertEqual(
            {},
            {key:(default,shipped[key].strip()) for key,default,_ in rows if shipped[key].strip()!=default},
        )
        self.assertIn('private _rows = _spec select {(_x select 6) == _section};',registration)
        self.assertIn('call CBA_fnc_addSetting;',registration)

    def test_published_cortex_defaults_match_current_core_switches(self):
        import re
        defaults=(ROOT/'cortex_defaults.md').read_text(encoding='utf-8')
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        shipped=dict(re.findall(r'^\s*\["(CBE_[^"]+)",\s*(.+?)\],(?:\s*//.*)?$',config,re.MULTILINE))
        published=dict(re.findall(r'^\| `([^`]+)` \| `([^`]+)` \|',defaults,re.MULTILINE))
        self.assertGreater(len(shipped),100)
        self.assertEqual([],sorted(set(shipped)-set(published)))
        self.assertEqual({}, {key:(value.strip(),published[key]) for key,value in shipped.items() if published[key] != value.strip()})
        for key in ['CBE_AIPass_CounterBattery_Enable','CBE_AIPass_CounterBattery_RadarRange',
                    'CBE_AIPass_CounterBattery_Delay','CBE_AIPass_CounterBattery_RadarDelay',
                    'CBE_AIPass_CounterBattery_Rounds']:
            self.assertIn(key,published)

    def test_counter_battery_diagnostics_report_the_automatic_default(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        expected='missionNamespace getVariable ["CBE_AIPass_CounterBattery_Mode", "AUTO"]'
        self.assertIn('["CBE_AIPass_CounterBattery_Mode", "AUTO"]',config)
        self.assertIn(expected,diagnostics)
        self.assertNotIn('missionNamespace getVariable ["CBE_AIPass_CounterBattery_Mode", "KNOWN"]',diagnostics)

    def test_diagnostics_master_fallbacks_match_enabled_defaults(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for key,default in [('CBE_AIRebalance_Enable','false'),('CBE_AIPass_Enable','true')]:
            self.assertIn(f'["{key}", {default}]',config)
            self.assertIn(f'missionNamespace getVariable ["{key}", {default}]',diagnostics)
            opposite='false' if default == 'true' else 'true'
            self.assertNotIn(f'missionNamespace getVariable ["{key}", {opposite}]',diagnostics)

    def test_replacement_clear_retires_old_movement_after_validation(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        marker='if (!_resume && {_previous isNotEqualTo []}) then {[_group] call CBE_fnc_CortexClearRelease};'
        self.assertIn(marker,text)
        self.assertLess(text.index('if (_positions isEqualTo [])'),text.index(marker))
        self.assertLess(text.index('if (_team isEqualTo [])'),text.index(marker))
        self.assertLess(text.index(marker),text.index('_group setVariable ["CBE_AIPass_ClearOrder", [_building'))

    def test_door_audit_uses_clearance_and_measures_animation_and_entry(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8').split('// Exercise door handling',1)[1]
        self.assertIn('call CBE_fnc_CortexClearBuilding',text)
        self.assertIn('CLEAR-door-lock-preserved',text)
        self.assertIn('CLEAR-door-all-entries-locked',text)
        self.assertIn('for "_doorIndex" from 1 to 64',text)
        self.assertIn('format ["bis_disabled_Door_%1",_doorIndex],1,true',text)
        self.assertIn('_fixtureDoors findIf',text)
        self.assertIn('CLEAR-door-unlocked-physical-entry',text)
        self.assertIn('vectorDistance (AGLToASL _x) <= 1.5',text)
        self.assertNotIn('call CBE_fnc_CortexBuildingDoor',text)
        self.assertNotIn('call BIS_fnc_door',text)
        self.assertNotIn('animateSource [',text)

    def test_garrison_does_not_command_players_or_incapacitated_members(self):
        for name in ['cortexGarrison','cortexGarrisonApplyLocal','cortexGarrisonRelease']:
            text=source(name)
            self.assertIn('!isPlayer',text)
            self.assertTrue('INCAPACITATED' in text or 'CBE_fnc_CortexCombatEffective' in text)
        effective=source('cortexCombatEffective')
        for guard in ['INCAPACITATED','ACE_isUnconscious','captive','ace_captives_isSurrendering','ace_captives_isHandcuffed']:
            self.assertIn(guard,effective)
        release=source('cortexGarrisonRelease')
        self.assertLess(release.index('enableAI "PATH"'),release.index('if ([_x] call CBE_fnc_CortexCombatEffective'))

    def test_building_door_helper_preserves_locks_and_requires_local_proximity(self):
        text=source('cortexBuildingDoor')
        self.assertIn('!local _unit',text)
        self.assertIn('_lock isEqualTo 0',text)
        self.assertIn('vectorDistance _position <= 3',text)
        self.assertIn('serverTime+2',text)
        self.assertIn('isNil {_building getVariable "CBE_Cortex_DoorDefinitions"}',text)
        self.assertLess(text.index('private _requested=false'),text.index('private _lock='))
        self.assertIn('call BIS_fnc_door',text)
        self.assertNotIn('animateSource',text)
        self.assertNotIn('setPos',text)
        self.assertNotIn('setVariable [format ["bis_disabled',text)

    def test_door_opening_requires_unobstructed_nearby_interaction(self):
        text=source('cortexBuildingDoor')
        for marker in ('private _visibilityChecks=0','_visibilityChecks < 4',
                       'lineIntersectsSurfaces [eyePos _unit,_position,_unit,objNull,true,1,"GEOM","NONE"]',
                       '(_hit select 2) == _building','(_hit select 3) == _building',
                       '(_hit select 0) vectorDistance _position <= 0.5','if (_near && {_visible}'):
            self.assertIn(marker,text)
        self.assertLess(text.index('private _near='),text.index('lineIntersectsSurfaces'))
        self.assertLess(text.index('if (_near && {_visible}'),text.index('call BIS_fnc_door'))
        self.assertIn('_lock isEqualTo 0',text)
        self.assertIn('call _orderCurrent',text.split('if (_near && {_visible}',1)[1])

    def test_building_wide_lock_prevents_opening_but_keeps_open_access(self):
        door=source('cortexBuildingDoor');step=source('buildingOperationStep')
        self.assertGreaterEqual(door.count('getVariable ["bis_disabled_Door",0]'),2)
        boundary=door.split('if (_near && {_visible}',1)[1].split('call BIS_fnc_door',1)[0]
        self.assertIn('getVariable ["bis_disabled_Door",0]',boundary)
        self.assertIn('bis_disabled_Door_%1',boundary)
        access=step.split('private _allLocked=',1)[1].split('private _bounds=',1)[0]
        self.assertIn('getVariable ["bis_disabled_Door",0]',access)
        self.assertIn('animationSourcePhase (_x select 1) >= 0.8',access)

    def test_bounded_door_visibility_rotates_without_starving_later_entries(self):
        text=source('cortexBuildingDoor')
        for marker in ('if (_doors isEqualTo []) exitWith {false}',
                       '(_doors select [_cursor])+(_doors select [0,_cursor])',
                       '_nextCursor=(_cursor+_forEachIndex+1) mod _doorCount',
                       'if (_requested || {_visibilityChecks >= 4}) exitWith {}',
                       'setVariable ["CBE_Cortex_DoorVisibilityCursor",_nextCursor]'):
            self.assertIn(marker,text)
        cursor=0;visited=[]
        for _ in range(3):
            batch=[(cursor+i)%9 for i in range(4)]
            self.assertEqual(len(batch),4)
            visited.extend(batch);cursor=(batch[-1]+1)%9
        self.assertEqual(set(visited),set(range(9)))

    def test_internal_door_execution_refuses_nonserver_remote_senders(self):
        text=source('cortexBuildingDoor')
        gate=text.index('if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false}')
        self.assertLess(gate,text.index('configOf _building'))
        self.assertLess(gate,text.index('call BIS_fnc_door'))
        self.assertIn('!local _unit',text)
        self.assertIn('call _orderCurrent',text)

    def test_native_building_operations_have_no_external_delegation_path(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        garrison=source('cortexGarrison')
        for text in [clear,garrison]:
            self.assertNotIn('useBuildingBackend',text)
            self.assertNotIn('BuildingBackend',text)
        comparison=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertNotIn('useBuildingBackend',comparison)
        self.assertNotIn('compatibility-backend',comparison)
    def test_clearance_releases_casualty_and_transferred_member_reservations(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        release=text.split('// Release reservations before selection',1)[1].split('private _now',1)[0]
        self.assertIn('!([_x,true] call _actorAvailable)',release)
        helper=source('buildingOperationStep').split('private _actorAvailable=',1)[1].split('private _finish',1)[0]
        self.assertIn('call CBE_fnc_CortexCombatEffective',helper)
        self.assertIn('group _actor == _group',helper)
        self.assertIn('!isPlayer _actor',helper)
        self.assertIn('lifeState _unit != "INCAPACITATED"',source('cortexCombatEffective'))
        self.assertIn('_assigned set [_forEachIndex,[]]',release)
        self.assertIn('if (_restore && {[_x] call _actorTaskFree}',text)
        release=source('cortexClearRelease')
        self.assertIn('params [["_group", grpNull, [grpNull]],["_restore",true,[true]]]',release)
        tick=source('cortexGroupTick')
        self.assertIn('[_group,false] call CBE_fnc_CortexClearRelease',tick)

    def test_clearance_timeout_cannot_clear_rooms_or_abort_other_workers(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        timeout=text.split('if (_now-_lastProgress > _retryDelay && {[_point] call _actorTaskFree})',1)[1].split('_state set [0,_cursor]',1)[0]
        self.assertNotIn('_cleared pushBack',timeout)
        self.assertNotIn('movementFailed',text)
        self.assertIn('_unreachable pushBackUnique _positionIndex',timeout)
        self.assertIn('_failures pushBackUnique _pairId',timeout)
        self.assertIn('_capablePairIds findIf {!(_x in _failures)} < 0',timeout)
        self.assertIn('_x doMove _unitTarget',timeout)
        self.assertIn('[_x] call _actorTaskFree',timeout)
        self.assertNotIn('_x setDestination',timeout)
        self.assertNotIn('execFSM',timeout)
        self.assertIn('private _moved=(getPosASL _point) vectorDistance (ATLToASL _moverPrevious) >= 1',text)
        self.assertIn('if (_approachingEntry && {!_moved}) then {',text)
        self.assertIn('_retries < 3',timeout)
        self.assertIn('count (_job get "cleared") == count (_job get "positions")',text)

    def test_clearance_handover_requires_physical_travel_and_native_formation_arrival(self):
        comparison=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        handover=comparison.split('private _beforeMove=_members apply',1)[1].split('sleep 8;',1)[0]
        self.assertIn('leader _group distance2D _destination <= 18',handover)
        self.assertIn('formationPosition _x',handover)
        self.assertIn('_beforeMove select _forEachIndex) < 25',handover)
        self.assertIn('_x distance2D _formationPoint > 18',handover)
        self.assertIn('AGLToASL _formationPoint',handover)
        self.assertNotIn('_x distance2D _destination > 18',handover)

    def test_native_building_controls_validate_all_model_door_sources(self):
        comparison=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        matrix=comparison.split('private _heightCases=[];',1)[1].split('if (_nativeOnly) exitWith',1)[0]
        self.assertNotIn('from 1 to 4',matrix)
        self.assertIn('getNumber (configOf _house >> "numberOfDoors")',matrix)
        self.assertIn('forEach ["sound","noSound"]',matrix)
        self.assertIn('BUILD-PLACEMENT-DOORS-',matrix)

    def test_clearance_native_tasks_gate_initial_retry_speed_and_exit_writes(self):
        step=source('buildingOperationStep')
        self.assertIn('private _actorTaskFree=',step)
        self.assertIn('"HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE"',step)
        self.assertIn('_retryDelay && {[_point] call _actorTaskFree}',step)
        self.assertIn('&& {[_x] call _actorTaskFree}',step)
        self.assertGreaterEqual(step.count('[_unit] call _actorTaskFree'),4)

    def test_clearance_cancels_changed_native_order_before_movement_and_preserves_replay_receipt(self):
        receipt=source('nativeOrderReceipt')
        start=source('cortexClearBuilding')
        step=source('buildingOperationStep')
        self.assertIn('_count <= 1 || {_index <= 0}',receipt)
        self.assertNotIn('forEach',receipt)
        self.assertIn('[_count,_index,[_group,"",false,_index] call CBE_fnc_AuthoredRouteReceipt]',receipt)
        metadata=source('authoredRouteReceipt')
        self.assertIn('if (isNull _vehicle && {isNull _object}) then {waypointPosition _waypoint} else {[]}',metadata)
        self.assertIn('_previous param [9,_nativeOrderReceipt,[[]]]',start)
        self.assertIn('["nativeOrderReceipt",_nativeOrderReceipt]',start)
        gate=step.index('([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _nativeOrderReceipt')
        self.assertLess(gate,step.index('if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS")'))
        self.assertIn('[false,"NEW_ORDER"] call _finish',step)
        self.assertIn('([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _nativeOrderReceipt', step)
        self.assertIn('_job getOrDefault ["nativeOrderReceipt",[]],_job getOrDefault ["hardDeadline"',step)

    def test_clearance_attempts_one_isolated_recovery_before_abandoning_a_room(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        recovery=text.split('private _roomRetryBudget=',1)[1].split('private _pairId=format',1)[0]
        self.assertIn('call _recoverClearActor',recovery)
        self.assertIn('_recovery in ["RECOVERING","YIELDED"]',recovery)
        self.assertIn('_retryCounts param [_positionIndex,0]', recovery)
        self.assertIn('_lastPositions=_pair apply {getPosATL _x}',recovery)
        self.assertNotIn('_unreachable pushBack',recovery)

    def test_recovery_rechecks_ownership_before_issuing_its_direct_move(self):
        recovery=source('recoveryStep')
        for requirement in ['CBE_fnc_CortexExternalTakeover','vehicle _actor != _actor',
                            'CBE_fnc_CortexCombatEffective','exitWith {"YIELDED"}']:
            self.assertIn(requirement,recovery)
        self.assertLess(recovery.index('exitWith {"YIELDED"}'),recovery.index('_actor doMove _destination'))
        self.assertGreaterEqual(recovery.count('CBE_fnc_CortexExternalTakeover'),2)
        final_check=recovery.rindex('CBE_fnc_CortexExternalTakeover')
        self.assertLess(final_check,recovery.index('_actor doMove _destination'))
        self.assertIn('private _currentOperation=',recovery[final_check:])
        self.assertIn('_currentOperation set ["recovery",_recovery]',recovery[final_check:])
        self.assertNotIn('_group setVariable ["CBE_Operation",_operation,true]',recovery)

    def test_clearance_release_resumes_formation_after_do_stop(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        release=source('cortexClearRelease')
        self.assertIn('private _leader = [_group] call CBE_fnc_CortexGroupAnchor;',clear)
        self.assertRegex(clear,r'private _leader\s*=\s*\[_group\] call CBE_fnc_CortexGroupAnchor;')
        self.assertIn('if (isNull _leader) then {_leader=leader _group};',clear)
        self.assertIn('private _leader=[_group] call CBE_fnc_CortexGroupAnchor;',release)
        self.assertIn('if (isNull _leader) then {_leader=leader _group};',release)
        self.assertIn('_x doFollow _leader',clear)
        self.assertIn('_x doFollow _leader',release)
        self.assertNotIn('_x commandFollow _leader',clear)
        self.assertNotIn('_x commandFollow _leader',release)
        admission=source('cortexClearBuilding').split('private _actorAdmissible=',1)[1].split('private _available =',1)[0]
        self.assertIn('ace_medical_ai_healQueue',admission)
        task=release.split('private _taskFree=',1)[1].split('if (_ownedActor',1)[0]
        for proof in ('simulationEnabled _x','!isObjectHidden _x','ace_medical_ai_healQueue'):
            self.assertIn(proof,task)
        self.assertLess(release.index('call CBE_fnc_CortexClearSettingsRelease'),release.index('private _taskFree='))
        self.assertIn('["RETIRE",_x,_motionJob] call CBE_fnc_BuildingActorMotion',release)

    def test_explicit_building_and_hold_orders_anchor_on_a_surviving_local_actor(self):
        """Leader loss must not turn an otherwise viable CQB, garrison or defence operation inert."""
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _entryOrigin=getPosATL _leader;',clear)
        for name in ['cortexDefend','cortexGarrison','cortexDefendRelease','cortexGarrisonRelease']:
            text=source(name)
            self.assertIn('CBE_fnc_CortexGroupAnchor',text,name)
            self.assertIn('if (isNull _',text,name)
        flank=source('cortexFlankStep')
        self.assertIn('private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;',flank)
        self.assertIn('private _rallyActor=[_group,_main] call CBE_fnc_CortexGroupAnchor;',flank)
        self.assertIn('if (isNull _rallyActor) exitWith {_recoveryDeferred=true}',flank)
        self.assertIn('private _rally = getPosATL _rallyActor;',flank)
        anchor=source('cortexGroupAnchor')
        for marker in ('private _elementScoped=count _this > 1','_element select [0,64]',
                       '_leader in _members','group _actor == _group','isNull objectParent _actor'):
            self.assertIn(marker,anchor)
        self.assertNotIn('selectLeader',anchor)
        assault=source('cortexAssaultStart')
        self.assertIn('[_group,_onFoot] call CBE_fnc_CortexGroupAnchor',assault)
        self.assertIn('"NO_ELEMENT_ANCHOR"',assault)


    def test_clearance_release_cancels_only_its_matching_common_operation(self):
        release=source('cortexClearRelease')
        self.assertIn('private _operation=_group getVariable ["CBE_Operation",createHashMap];',release)
        self.assertIn('(_operation getOrDefault ["intent",""]) == "CLEAR"',release)
        self.assertIn('"CLEAR_RELEASE"] call CBE_fnc_OperationCancel',release)

    def test_holding_release_restores_leader_but_yields_to_zeus_replacement(self):
        garrison=source('cortexGarrisonRelease')
        defend=source('cortexDefendRelease')
        tick=source('cortexGroupTick')
        for release in [garrison,defend]:
            self.assertIn('["_restore",true,[true]]',release)
            self.assertIn('private _externalTakeover = [_group] call CBE_fnc_CortexExternalTakeover;',release)
            self.assertIn('private _canRestore = _restore && {!_externalTakeover};',release)
            self.assertIn('_canRestore ||',release)
            self.assertIn('!_externalTakeover && {_ownedHold',release)
            self.assertIn('_x doFollow _leader',release)
            self.assertIn('["","STOP","ATTACK","FIRE","SUPPRESS"]',release)
        self.assertIn('[_group,false] call CBE_fnc_CortexGarrisonRelease',tick)
        self.assertIn('[_group,false] call CBE_fnc_CortexDefendRelease',tick)

    def test_clearance_rotates_failed_position_between_workers(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _failedBy',text)
        self.assertIn('private _failureThreshold=(count (_job get "pairs")) max 1',text)
        self.assertIn('(_job get "pending") pushBackUnique _positionIndex',text)
        self.assertIn('private _pairId=format ["PAIR_%1",_pairIndex]',text)
        self.assertIn('for "_exitIndex" from 0 to 15 do',text)
        self.assertIn('private _ranked=_entries apply',text)

    def test_clearance_uses_independent_workers_and_continuous_room_routes(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _allPositions = _building buildingPos -1',text)
        self.assertIn('lineIntersectsSurfaces',text)
        self.assertIn('private _pairs=[];',text)
        self.assertIn('[{_pairs=[_group,_team,true,_pairPreference] call CBE_fnc_CombatPairs}] call _commitPreparation;',text)
        self.assertIn('private _pairs=[];',source('combatPairs'))
        self.assertNotIn('private _pairs=_team apply {[_x]}',text)
        self.assertIn('private _team = +_available',text)
        self.assertIn('private _squadElement = count _available',text)
        self.assertIn('private _topologyElement = ((count _allPositions) max 2) min 8',text)
        self.assertIn('private _entryCapacity = ((2 max _squadElement) min _topologyElement) min 8',text)
        self.assertIn('private _pending=+_routeOrder',text)
        self.assertIn('private _pairRoutes=_pairs apply {[]}',text)
        self.assertIn('_pairStates pushBack [0,false',text)
        self.assertIn('_entries resize ((count _entries) min 4)',text)
        self.assertIn('private _claimedEntryIndices=[]',text)
        self.assertIn('private _unclaimed=_ranked select {!((_x select 1) in _claimedEntryIndices)}',text)
        self.assertIn('_claimedEntryIndices pushBackUnique _entryIndex',text)
        self.assertIn('_approachingEntry=false',text)
        self.assertIn('_approachingEntry=true',text)
        self.assertIn('_approachingEntry=false;',text)
        self.assertNotIn('_unit setDestination',text)
        self.assertIn('_entryIndex >= count (_job get "entries")',text)
        self.assertIn('if (!_recoverAccess && {!(_point in (_job getOrDefault ["enteredActors",[]]))}',text)
        self.assertIn('private _recoverAccess=!_approachingEntry && {count _approach >= 3}',text)
        self.assertIn('&& {(_approach select 0) == _positionIndex}',text)
        self.assertIn('&& {count (_approach select 1) == 3} && {!(_approach select 2)}',text)
        self.assertIn('[["STANCE","UP"],["SPEED",_speed]]',source('cortexClearSettingsApply'))
        self.assertIn('call CBE_fnc_CortexClearSettingsApply',text)
        self.assertIn('CBE_Cortex_ClearAppliedSpeed',source('cortexClearSettingsApply'))
        self.assertIn('private _retryDelay=[12,4] select _commandEnded',text)
        self.assertIn('private _commandEnded=currentCommand _point in ["","STOP"];',text)
        self.assertNotIn('_pair findIf {currentCommand _x in ["","STOP"]}',text)
        self.assertIn('private _moverSlot=_moverIndex mod count _pair',text)
        progress=text.split('// Once inside, only the assigned room mover proves progress toward this room.',1)[1].split('if (_positionIndex in _cleared)',1)[0]
        self.assertIn('(getPosASL _point) vectorDistance (ATLToASL _moverPrevious) >= 1',progress)
        self.assertIn('if (_approachingEntry && {!_moved}) then {',progress)
        self.assertNotIn('} forEach _pair;\n                    if (_moved) then {',progress)
        self.assertNotIn('setVehiclePosition',text)
        self.assertIn('_triedEntries pushBackUnique _entryIndex',text)
        self.assertIn('_cursor=_cursor+1',text)

    def test_clearance_workers_claim_without_node_crowding(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _point=_pair select (_moverIndex mod count _pair)',text)
        self.assertIn('private _supportTarget=[]',text)
        self.assertIn('_previousPositionIndex=_positionIndex',text)
        self.assertIn('private _unitTarget=if (_unit == _point',text)
        self.assertIn('_failureThreshold=(count (_job get "pairs")) max 1',text)
        self.assertNotIn('"ROTATE"',text)

    def test_clearance_reinforces_casualties_from_uncommitted_squad_members(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _reserves=(units _group) select',text)
        self.assertIn('_pair set [_slot,_replacement]',text)
        self.assertIn('CBE_Cortex_ClearReinforcements',text)
        self.assertIn('[_member] call _actorAvailable',text)
        self.assertIn('[_actor] call CBE_fnc_CortexCombatEffective',text)
        self.assertIn('_rotatedOut pushBackUnique _member',text)

    def test_clearance_rotates_operation_quarantined_workers_without_stalling_other_lanes(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _unavailable=if ((_operation getOrDefault ["generation",-1]) == _operationGeneration',text)
        self.assertIn('(_reserved select {_x in _unavailable})',text)
        self.assertIn('|| {_member in _unavailable}) && {_reserves isNotEqualTo []})',text)
        self.assertIn('_active=_active select {[_x] call _actorAvailable && {!(_x in _unavailable)}}',text)
        self.assertIn('private _pair=_laneRoster select {[_x] call _actorAvailable',text)
        self.assertIn('!(_x in _unavailable)',text)

    def test_clear_room_checkpoint_requires_physically_established_floor_and_bounded_shared_access(self):
        step=source('buildingOperationStep')
        branch=step.split('private _approaches=_job',1)[1].split('private _issue=',1)[0]
        self.assertIn('!_approachingEntry && {_entered || {abs',branch)
        self.assertIn('abs (((getPosASL _point) select 2)-((AGLToASL _checkpoint) select 2)) <= 0.75',branch)
        self.assertIn('_positions select _previousPositionIndex',branch)
        self.assertIn('_cleared select [0,24]',branch)
        self.assertIn('(_probes getOrDefault [_probeKey,-1]) != count _cleared',branch)
        self.assertIn('count _checkpoint == 3',branch)
        self.assertIn('abs (((AGLToASL _checkpoint) select 2)-_targetFloor) <= 1.5',branch)
        self.assertIn('(getPosASL _point) vectorDistance (AGLToASL _checkpoint) <= 1.5',branch)
        self.assertIn('_approach set [2,true]',branch)
        self.assertNotIn('setPos',branch)
        self.assertNotIn('_cleared pushBack',branch)

    def test_clearance_preserves_exposed_navigation_without_counting_it_as_covered_room(self):
        admission=source('cortexClearBuilding')
        step=source('buildingOperationStep')
        self.assertIn('["navigationPositions",+_allPositions]',admission)
        self.assertIn('["transitPositions",_allPositions select {!(_x in _positions)}]',admission)
        access=step.split('private _floorKey=str round',1)[1].split('// At most two legs:',1)[0]
        self.assertIn('count _accessCache < 8',access)
        self.assertIn('select [0,32]',access)
        self.assertIn('(_x select 2) == _building || {(_x select 3) == _building}',access)
        self.assertIn('_accessCache set [_floorKey,_access]',access)
        self.assertIn('if (_access isNotEqualTo []) exitWith {}',access)
        self.assertIn('if (_supported) then {_access=+_x}',access)
        self.assertNotIn('_cleared pushBack',access)
        self.assertNotIn('setPos',access)

    def test_clearance_floor_receipts_reject_lower_treads_and_are_shared_with_audit(self):
        step=source('buildingOperationStep')
        collector=step.split('private _actual = getPosASL _visitor',1)[1].split('private _pairRosterChanged',1)[0]
        self.assertIn('abs ((_actual select 2)-(_positionASL select 2)) <= 0.75',collector)
        self.assertIn('if (_atPosition)',collector)
        self.assertIn('_completedRoom in ((_job getOrDefault ["actorVisits",createHashMap])',step)
        self.assertIn('abs (((getPosASL _unit) select 2)-((AGLToASL _speedTarget) select 2)) <= 0.75',step)
        self.assertGreater(step.index('abs (_pointFloor-_targetFloor)'),step.index('private _pointFloor='))
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        observer=audit.split('private _observedRoomVisit={',1)[1].split('private _recordFixture=',1)[0]
        self.assertIn('abs ((_actual select 2)-(_target select 2)) > 0.75',observer)
        self.assertIn('_actual vectorDistance _target > 1.5',observer)
        self.assertIn('_house worldToModel',observer)
        self.assertIn('lineIntersectsSurfaces',observer)
        self.assertNotIn('getVariable',observer)  # No production visit/completion receipts.
        self.assertIn('[_worker,_house,_x] call _observedRoomVisit',audit)
        self.assertIn('[_x,_house,_room] call _observedRoomVisit',audit)

    def test_buddy_separation_cannot_renew_room_mover_progress(self):
        step=source('buildingOperationStep')
        lane=step.split('private _roomRequestChanged=',1)[1].split('// Once inside, only the assigned room mover',1)[0]
        self.assertIn('private _issue=_roomRequestChanged;',lane)
        self.assertIn('if (_partnerCommitted isNotEqualTo _supportTarget) then {_issue=true}',lane)
        self.assertIn('if (_roomRequestChanged && {_roomMoverCommitted}) then {_lastTarget=_positionIndex; _lastProgress=_now;',lane)
        self.assertNotIn('if (_issue) then {_lastTarget=',lane)
        self.assertEqual(lane.count('_roomRequestChanged='),0)
        progress=step.split('// Once inside, only the assigned room mover',1)[1].split('private _commandEnded=',1)[0]
        self.assertIn('_bestDistance-_targetDistance >= 1',progress)

    def test_clearance_preserves_owned_move_even_when_native_actor_is_ready(self):
        step=source('buildingOperationStep')
        same=step.split('private _sameActiveTarget=',1)[1].split('if (!_sameActiveTarget',1)[0]
        self.assertIn('call _ownsCurrentMove',same)
        self.assertNotIn('call _activeOwnMove',same)
        self.assertIn('currentCommand _unit == "" && {count _nativeTarget == 3}',same)
        self.assertIn('_nativeTarget vectorDistance _committedTarget <= 0.25',same)
        owned=step.split('private _ownsCurrentMove={',1)[1].split('// Native task ownership',1)[0]
        self.assertIn('currentCommand _actor == "MOVE"',owned)
        self.assertIn('_live vectorDistance _issued <= 0.25',owned)
        retry=step.split('private _commandEnded=',1)[1].split('_retries=_retries+1',1)[0]
        self.assertIn('_now-_lastProgress > _retryDelay',retry)
        self.assertIn('_x doMove _unitTarget',retry)

    def test_clear_entry_capture_is_opt_in_bounded_and_read_only(self):
        step=source('buildingOperationStep')
        capture=step.split('private _captureEntry={',1)[1].split('private _actorAvailable=',1)[0]
        for marker in ['_count >= 256','count _stamps >= 16','< 2','expectedDestination _actor',
                       'currentCommand _actor','getPosASL _actor','CBE CLEAR ENTRY SAMPLE']:
            self.assertIn(marker,capture)
        for forbidden in ['lineIntersects','nearEntities','nearestObjects','doMove','setDestination','remoteExec','setVariable']:
            self.assertNotIn(forbidden,capture)
        self.assertIn('getVariable ["CBE_Cortex_ClearCaptureEntry",false]',step)
        self.assertIn('if (_captureEntryEnabled &&',step)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertIn('setVariable ["CBE_Cortex_ClearCaptureEntry",true]',audit)

    def test_independent_room_visit_rejects_open_bounds_and_intervening_objects(self):
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        visit=audit.split('private _observedRoomVisit={',1)[1].split('// Independent physical exit observation.',1)[0]
        self.assertIn('if (_roof isEqualTo []) exitWith {false}',visit)
        self.assertIn('(_nearestRoof select 2) != _house && {(_nearestRoof select 3) != _house}',visit)
        self.assertIn('_hits isEqualTo []',visit)
        self.assertNotIn('_hits findIf',visit)
        self.assertNotIn('getVariable',visit)
        self.assertNotIn('CBE_fnc_',visit)

    def test_clearance_mover_handoff_preserves_ordered_actor_specific_room_history(self):
        step=source('buildingOperationStep')
        branch=step.split('private _approaches=_job',1)[1].split('private _issue=',1)[0]
        self.assertIn('format ["%1:%2",_pairIndex,netId _point]',branch)
        self.assertIn('!(_previousPositionIndex in _ownVisits)',branch)
        self.assertLess(branch.index('_chain pushBack (+(_positions select _previousPositionIndex))'),branch.index('_chain pushBackUnique (+_checkpoint)'))
        self.assertLess(branch.index('private _accessNodes=_cleared'),branch.index('private _transit='))
        self.assertIn('_approach=[_positionIndex,+_first,false,_chain]',branch)
        self.assertIn('private _next=_remaining deleteAt 0',branch)
        self.assertIn('_target=+_next',branch)
        self.assertNotIn('_cleared pushBack',branch)

    def test_clearance_does_not_interrupt_owned_native_leg_at_visit_radius(self):
        step=source('buildingOperationStep')
        own=step.split('private _ownsCurrentMove=',1)[1].split('private _roomMovementPoint=',1)[0]
        self.assertIn('_live vectorDistance _issued <= 0.25',own)
        self.assertIn('unitReady _actor',own)
        self.assertIn('vectorDistance (AGLToASL _issued) > 0.4',own)
        self.assertIn('!([_point] call _activeOwnMove)',step)
        self.assertIn('!([_unit] call _activeOwnMove)',step)
        remember=step.split('private _rememberMove=',1)[1].split('private _ownsCurrentMove=',1)[0]
        self.assertIn('deleteAt (netId _actor)',remember)
        self.assertIn('"egressAssignments",[]]) select {_x param [2,false,[true]]}',step)

    def test_clear_egress_preserves_progressing_routes_and_bounds_retries(self):
        step=source('buildingOperationStep')
        egress=step.split('== "EGRESS") exitWith {',1)[1].split('private _positions =',1)[0]
        self.assertNotIn('egressReissue',egress)
        self.assertIn('(_record select 1)-_remaining >= 0.5',egress)
        self.assertIn('serverTime-(_record select 2) >= 8',egress)
        self.assertIn('(_record select 3) < 1',egress)
        self.assertIn('if ([_x] call _outsideExit && {simulationEnabled _unit} && {!isObjectHidden _unit}',egress)
        self.assertIn('&& {!(netId _unit in _earlyExits)}',egress)
        self.assertIn('if (_assignment param [2,false,[true]] && {_stillAtPost}) exitWith {false}', egress)
        self.assertIn('if (_assignment param [2,false,[true]]) then {_assignment set [2,false]}',egress)
        self.assertIn('_assignment set [2,true]', egress)
        arrival=egress.split('if (!_outside) then {',1)[1].split('_outside\n',1)[0]
        self.assertIn('doStop _unit',arrival)
        self.assertIn('[_unit] call _actorAvailable',arrival)
        self.assertIn('[_unit] call _actorTaskFree',arrival)
        self.assertIn('call _mayIssueMovement',arrival)
        self.assertIn('abs (((getPosASL _unit) select 2)', egress)
        self.assertIn('(AGLToASL _target) select 2',egress)

        self.assertIn('[_unit] call _actorAvailable',egress)
        self.assertIn('_record set [3,1]',egress)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        self.assertIn('physical-egress',qa)
        self.assertIn('_actor distance2D _exitTarget > 1.5',qa)
        self.assertIn('[_actor,_house,_exitTarget] call _observedExit',qa)
        self.assertIn('[_house worldToModel _exitTarget] call _outside',qa)
        self.assertIn('abs (((getPosATL _actor) select 2)',qa)
        self.assertIn('egress-retry-budget',qa)

    def test_egress_owner_adoption_preserves_routes_and_consumed_exit_budget(self):
        start=source('cortexClearBuilding')
        replay=start.split('// Adopt a transform/episode-bound exit journal',1)[1].split('// Keep reserve search consumption',1)[0]
        for command in ['doMove','doFollow','doStop','setDestination']:
            self.assertNotIn(command,replay)
        for binding in ['(_egressJournal select 4) == _building',
                        '(_egressJournal select 5) isEqualTo (_job get "buildingTransform")',
                        '(_egressJournal select 6) == _hardDeadline',
                        '_live vectorDistance _leg <= 0.25',
                        '(_retries max 0) min 1',
                        '((_egressJournal select 7)-serverTime) max 0']:
            self.assertIn(binding,replay)
        stage=start.split('private _stageBudget=',1)[1]
        self.assertIn('private _moves=_job getOrDefault ["movementTargets",createHashMap]',stage)
        self.assertNotIn('private _moves=createHashMap',stage)
        publish=source('buildingOperationStep').split('// Publish only material egress changes.',1)[1].split('_brain set ["phase"',1)[0]
        self.assertIn('isNotEqualTo _journal',publish)
        self.assertIn('_record param [3,0]',publish)
        self.assertIn('_job get "egressDeadlineServer"',publish)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        observe=qa.split('private _exit=_group getVariable ["CBE_Cortex_ClearEgress",[]];',1)[1].split('forEach _egressAssignments;',1)[0]
        self.assertIn('count _exit in [4,10,13]',observe)
        self.assertIn('_egressAssignments pushBack +_x',observe)
        self.assertIn('_egressVisits set [_forEachIndex,true]',observe)

    def test_clearance_egresses_before_terminal_handover(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('(_job getOrDefault ["phase","CLEAR"]) == "EGRESS"',text)
        self.assertIn('pushBack [_unit,+_target,false]',text)
        egress=text.split('private _claimedExitPoints=',1)[1].split('_job set ["phase","EGRESS"]',1)[0]
        planner=text.split('private _chooseExteriorExit={',1)[1].split('// Shared room coverage',1)[0]
        self.assertIn('_claimedExitPoints+_securityPoints',egress)
        self.assertIn('call _chooseExteriorExit',egress)
        self.assertIn('call CBE_fnc_BuildingExteriorProposal',planner)
        self.assertIn('call CBE_fnc_BuildingExteriorCandidate',planner)
        self.assertNotIn('from 0 to 11',egress)
        self.assertIn('_claimedExitPoints pushBackUnique +(_x select 1)',egress)
        self.assertIn('_unit distance2D _target > 1',text)
        self.assertIn('_job set ["phase","EGRESS"]',text)
        self.assertIn('_job set ["egressAssignments",_egressAssignments]',text)
        self.assertIn('_job set ["egressFailed",true]',text)
        self.assertIn('!(_job getOrDefault ["egressFailed",false])',text)

    def test_clearance_rechecks_external_ownership_at_each_movement_write(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _mayIssueMovement = {',text)
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',text)
        self.assertIn('&& {call _mayIssueMovement}',text)
        self.assertGreaterEqual(text.count('if (call _mayIssueMovement) then {'),2)
        for command in ['_unit doMove _target;','_unit doMove _unitTarget;','_x doMove _unitTarget;']:
            index=text.index(command)
            self.assertIn('_mayIssueMovement',text[max(0,index-1000):index])
    def test_holding_operations_recheck_external_ownership_before_route_writes(self):
        garrison=source('cortexGarrisonApplyLocal')
        defend=source('cortexDefendApplyLocal')
        reserve=source('cortexDefendStep')
        for text in [garrison,defend]:
            self.assertGreaterEqual(text.count('private _mayIssueMovement = {'),2)
            self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',text)
            self.assertIn('&& {[_x] call _mayIssueMovement}',text)
            self.assertIn('call CBE_fnc_CortexActorMoveReserved',text)
            self.assertIn('currentCommand _actor in [',text)
            self.assertGreaterEqual(text.count('_actor checkAIFeature "MOVE"'),2)
        self.assertIn('if ([_x] call _mayIssueMovement) then {',garrison)
        self.assertIn('private _openedDoor = if ((_assignment param [4,"INTERIOR"]) != "EXTERIOR" && {[_x] call _mayIssueMovement})',garrison)
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',garrison)
        self.assertIn('currentCommand _actor in [',garrison)
        self.assertIn('!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)',garrison)
        self.assertIn('[_group] call CBE_fnc_CortexExternalTakeover',reserve)
        self.assertLess(reserve.index('CortexExternalTakeover'),reserve.index('_actor setVariable ["CBE_AIPass_DefendPos"'))
        self.assertNotIn('_x doMove _position;',reserve)
        self.assertIn('[_group,_reserve,_reserve] call CBE_fnc_CortexDefendApplyLocal',reserve)

    def test_garrison_duck_handlers_yield_to_a_later_external_owner(self):
        """Suppression callbacks must not alter the posture of a Zeus or specialist-owned unit."""
        garrison=source('cortexGarrisonApplyLocal')
        duck=garrison.split('private _duck = {',1)[1].split('_unit setVariable ["CBE_AIPass_GarrisonHandlerIds"',1)[0]
        self.assertGreaterEqual(duck.count('CBE_fnc_CortexExternalTakeover'),2)
        self.assertIn('|| {[group _unit,false,_unit] call CBE_fnc_CortexExternalTakeover}) exitWith {};',duck)
        self.assertIn('&& {!([group _unit,false,_unit] call CBE_fnc_CortexExternalTakeover)}) then {',duck)
        self.assertGreaterEqual(duck.count('CBE_fnc_CortexCombatEffective'),2)

    def test_reactive_direct_commands_recheck_external_ownership(self):
        dismount=source('convoyDismountLocal')
        civilian=source('cortexCivilianReact')
        armour=source('cortexAntiArmour')
        grenade=source('cortexGrenadeCheck')
        self.assertIn('&& {!([group _unit] call CBE_fnc_CortexExternalTakeover)}) then {',dismount)
        self.assertLess(civilian.rindex('CortexExternalTakeover'),civilian.rindex('_unit doMove _destination;'))
        self.assertGreaterEqual(armour.count('CortexExternalTakeover'),2)
        self.assertLess(armour.index('if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {false};', armour.index('if (_blocked) exitWith {')),
                        armour.index('_gunner doMove _spot;'))
        self.assertIn('&& {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {',grenade)
    def test_tactical_drills_recheck_takeover_before_bound_and_retry_commands(self):
        step=source('cortexFlankStep')
        self.assertIn('private _mayIssueMovement = {',step)
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',step)
        self.assertIn('if ([_unit] call _mayIssueMovement) then {',step)
        self.assertIn('&& {[_unit] call _mayIssueMovement}) then {',step)
        for command in ['_actor doMove _rally;','_unit doMove _spot;','_unit doMove (_spots select _slot);']:
            index=step.index(command)
            # Include the bounded retry journal published between admission and native issue.
            self.assertIn('_mayIssueMovement',step[max(0,index-1400):index])
    def test_combined_arms_and_convoy_crew_yield_at_final_command_boundaries(self):
        combined=source('cortexCombinedArmsLocal')
        ground=source('cortexCombinedGroundStep')
        crew=source('convoyCrewLocal')
        self.assertGreaterEqual(combined.count('CortexExternalTakeover'),5)
        ground_fire=combined.split('if (_role == "GROUND_FIRE") exitWith {',1)[1].split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[0]
        self.assertLess(ground_fire.index('CortexExternalTakeover'),ground_fire.index('_gunner doTarget _target'))
        self.assertNotIn('forEach crew _asset',combined)
        self.assertLess(combined.rindex('CortexExternalTakeover'),combined.index('call CBE_fnc_AirAttackOperationStart'))
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover) && {call _routeCurrent}',ground)
        arrival=ground.split('if (_arrivalDistance <= 70)',1)[1].split('if (time >=',1)[0]
        self.assertLess(arrival.index('CortexExternalTakeover'),arrival.index('_gunner doTarget _target'))
        self.assertIn('if (_fireAllowed) then {',arrival)
        self.assertIn('if ([_group] call CBE_fnc_CortexExternalTakeover ||',crew)
        self.assertIn('&& {!([group _unit] call CBE_fnc_CortexExternalTakeover)}) then {',crew)
    def test_driving_recovery_rechecks_takeover_after_sparse_terrain_sampling(self):
        driving=source('drivingAssistStart')
        self.assertIn('private _mayIssueDriving = {',driving)
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',driving)
        cap=driving.split('private _capCommitted=false;',1)[1].split('if (!_capCommitted)',1)[0]
        self.assertLess(cap.index('call _mayIssueDriving'),cap.index('_vehicle forceSpeed'))
        self.assertIn('isNotEqualTo _entryRestore',cap)
        self.assertIn('isNotEqualTo _entryAssistState',cap)
        self.assertIn('_capMps=0;_capReceipt set [0,0];',cap)
        self.assertIn('[_vehicle,_group] call CBE_fnc_DrivingAssistRelease;',driving)
        self.assertLess(driving.index('private _capCommitted=false;'),driving.index('_vehicle forceSpeed _capMps;'))
        recovery=driving.split('if (_hasRoute &&',1)[1].split('switch (_recoveryStage)',1)[0]
        self.assertIn('&& {call _mayIssueDriving}',recovery)
    def test_naval_operations_release_without_overwriting_external_orders(self):
        naval=source('cortexNavalAssault')
        release=source('cortexNavalRelease')
        self.assertIn('if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {',naval)
        self.assertIn('[_group,_state,"EXTERNAL"] call CBE_fnc_CortexNavalRelease',naval)
        self.assertLess(naval.rindex('CortexExternalTakeover'),naval.rindex('CBE_fnc_CortexGroupMove'))
        self.assertIn('private _externalTakeover=[_group] call CBE_fnc_CortexExternalTakeover;',release)
        self.assertIn('if (_saved isNotEqualTo [] && {!_externalTakeover} && {_ownedStop >= 0}',release)
    def test_clearance_preserves_live_behaviour_and_combat_mode(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        release=source('cortexClearRelease')
        self.assertNotIn('_group setBehaviour "COMBAT"',clear)
        self.assertNotIn('_group setBehaviour (_job get "baseBehaviour")',clear)
        self.assertNotIn('_group setBehaviour (_order select 3)',release)
        self.assertNotIn('setCombatMode',clear)
        self.assertNotIn('setCombatMode',release)

    def test_zeus_takeover_cleanup_does_not_replace_curator_movement(self):
        release=source('cortexReleaseGroup')
        restore=source('cortexRestoreCalm')
        flank_end=source('cortexFlankEnd')
        self.assertIn('private _yieldToZeus=local _group && {[_group] call CBE_fnc_CortexZeusHeld}',release)
        self.assertIn('CBE_fnc_CortexExternalTakeover',release)
        self.assertIn('private _externalTakeover=_yieldToZeus || {_yieldToExternal}',release)
        self.assertIn('["RELEASE","ZEUS"] select _externalTakeover',release)
        self.assertIn('[_group, _state, false, _externalTakeover, _reason] call CBE_fnc_CortexRestoreCalm',release)
        self.assertIn('"EXTERNAL_TAKEOVER"',release)
        self.assertIn('["_yieldToExternal",false,[true]]',restore)
        self.assertIn('if (!_yieldToExternal && {_state getOrDefault ["behaviourChanged", false]}',restore)
        self.assertIn('if (!_yieldToExternal && {count _retreatSpeedLease == 2}',restore)
        self.assertIn('speedMode _group == (_retreatSpeedLease select 1)',restore)
        self.assertIn('CBE_fnc_CortexExternalTakeover',restore)
        self.assertIn('!(_reason in ["ZEUS","OWNERSHIP_LOST","ROLE_HANDOVER"])',flank_end)
        self.assertIn('if (_mayCommand) then',flank_end)

    def test_garrison_reassigns_unreachable_positions_without_wall_clock_failure(self):
        order=source('cortexGarrison')
        apply=source('cortexGarrisonApplyLocal')
        release=source('cortexGarrisonRelease')
        self.assertIn('CBE_Cortex_GarrisonCandidates',order)
        self.assertIn('CBE_Cortex_GarrisonCandidates',release)
        self.assertIn('_reassignments < 2',apply)
        self.assertIn('private _retiredPosts=createHashMap',apply)
        self.assertEqual(apply.count('_retiredPosts set [str (_assignment select [0,4]),true]'),2)
        self.assertIn('&& {!(str (_x select [0,4]) in _retiredPosts)}',apply)
        retire=apply.split('// Exhaustion is episode-local',1)[1].split('_group setVariable ["CBE_Cortex_GarrisonPending"',1)[0]
        for proof in ('CBE_AIPass_GarrisonGeneration','CortexExternalTakeover','count _pool <= 512',
                      'in _retiredPosts','setVariable ["CBE_Cortex_GarrisonCandidates",_remaining,true]'):
            self.assertIn(proof,retire)
        for forbidden in ('doMove','disableAI','forceSpeed','GarrisonDeadline'):
            self.assertNotIn(forbidden,retire)

        self.assertIn('_x setVariable ["CBE_AIPass_GarrisonPos",_replacement,true]',apply)
        self.assertIn('!(_key in _attempted)',apply)
        self.assertIn('for "_index" from 0 to 31 do',apply)
        self.assertIn('Garrison trying alternate entrance',apply)
        self.assertIn('private _approach = _entries isNotEqualTo [] && {_unit distance2D _destination > 30}',apply)
        self.assertIn('private _target = if (_approach) then {_entries select 0} else {_destination}',apply)
        self.assertIn('private _replacementApproach=_replacementEntries isNotEqualTo []',apply)
        self.assertIn('private _replacementTarget=if (_replacementApproach)',apply)
        self.assertIn('private _replacementAnchor=if (_replacementApproach)',apply)
        self.assertIn('_entries resize ((count _entries) min 4)',apply)
        self.assertIn('if (_nextEntry < count _entries && {[_x] call _mayIssueMovement}) then',apply)
        self.assertNotIn('doStop _x; _x doMove',apply)
        self.assertIn('if (!_heldInPlace && {_unit in _freshActors} && {[_unit] call _mayIssueMovement}) then {doStop _unit}',apply)
        self.assertIn('["deadline", _deadline]',apply)
        self.assertIn('getVariable ["CBE_Cortex_GarrisonDeadline",-1]',apply)
        self.assertIn('serverTime > (_job get "deadline")',apply)
        self.assertIn('setVariable ["CBE_Cortex_GarrisonDeadline",serverTime+240,true]',source('cortexGarrison'))
        self.assertIn('setVariable ["CBE_Cortex_GarrisonDeadline",nil,true]',source('cortexGarrisonRelease'))
        self.assertNotIn('_job set ["deadline",(_job get "deadline") max (time+60)]',apply)

    def test_defence_recovery_uses_per_unit_physical_progress(self):
        order=source('cortexDefend')
        reserve=source('cortexDefendStep')
        self.assertIn('forEach [0.75,0.5,0.25,0]',order)
        self.assertIn('[_centre,_rearCandidates,_threat] call CBE_fnc_CortexSelectAvenue',order)
        self.assertIn('forEach [0.65,0.35,0]',reserve)
        self.assertIn('surfaceNormal _position',reserve)
        text=source('cortexDefendApplyLocal')
        self.assertIn('private _route=[_x,getPosATL _x,time,0,_routeGeneration,+_assignment,false,',text)
        self.assertIn('CBE_AIPass_DefendRouteGeneration',text)
        self.assertIn('if (_fullApply) then {_actors=+units _group}',text)
        self.assertIn('forEach (_job get "actors")',text)
        self.assertIn('(_lastPosition vectorDistance _destination)-((getPosATL _unit) vectorDistance _destination) >= 1',text)
        self.assertNotIn('_unit distance2D _lastPosition >= 1',text)
        self.assertIn('time-_lastProgress >= 15',text)
        self.assertIn('_retries < 3',text)
        self.assertIn('_unit doMove (_assignment select 0)',text)
        self.assertNotIn('_unit setDestination',text)
        self.assertNotIn('["deadline", time + 90]',text)

    def test_defence_reserve_reinforcement_does_not_replan_the_established_line(self):
        apply=source('cortexDefendApplyLocal')
        reserve=source('cortexDefendStep')
        release=source('cortexDefendRelease')
        self.assertIn('["_actors",[],[[]]]',apply)
        self.assertIn('private _fullApply=_actors isEqualTo []',apply)
        self.assertIn('if (_fullApply || {_generation <= 0}) then {',apply)
        self.assertIn('forEach _actors',apply)
        self.assertNotIn('_group setVariable ["CBE_AIPass_DefendApplied", false]',reserve)
        self.assertNotIn('_x doMove _position',reserve)
        self.assertIn('[_group,_reserve,_reserve] call CBE_fnc_CortexDefendApplyLocal',reserve)
        self.assertIn('CBE_AIPass_DefendRouteGeneration',release)

    def test_clearance_renews_safety_lease_only_on_observed_progress(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _madeProgress=count _cleared != _before',text)
        self.assertIn('_job set ["deadline",(_job get "deadline") max (serverTime+120)]',text)
        self.assertIn('_job set ["lastProgressAt",serverTime]',text)
        self.assertNotIn('_job set ["deadline",serverTime+120]',text)

    def test_clearance_absolute_lifetime_survives_resume_and_cannot_be_renewed_by_progress(self):
        admission=source('cortexClearBuilding')
        step=source('buildingOperationStep')
        self.assertIn('_previous param [10,_deadline,[0]]',admission)
        self.assertIn('(240 max (60*count _positions)) min 900',admission)
        self.assertIn('[_building, _cleared, _deadline',admission)
        self.assertIn('_nativeOrderReceipt, _hardDeadline, _contactBelief, _continueRoute, +_admissionTransform], true]',admission)
        self.assertIn('serverTime > (_job getOrDefault ["hardDeadline",_job get "deadline"])',step)
        self.assertNotIn('_job set ["hardDeadline"',step)
        self.assertIn('|| {!_egressEntered} || {!_egressProgressed}',step)

    def test_clearance_preserves_failure_evidence_after_release(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        release=source('cortexClearRelease')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('_group setVariable ["CBE_Cortex_ClearEvidence",[+(_job get "cleared")',clear)
        self.assertIn('_group setVariable ["CBE_Cortex_ClearEvidence",[+(_order param [1,[]])',release)
        self.assertIn('_group getVariable ["CBE_Cortex_ClearEvidence",[]]',diagnostics)
        self.assertIn('_clearEvidence param [3,[]]',diagnostics)

    def test_building_scale_cases_use_fresh_groups_and_observed_room_visits(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        cases=text.split('// Fresh groups distinguish',1)[1]
        self.assertIn('[2,"Land_i_House_Small_01_V1_F"]',cases)
        self.assertIn('[6,"Land_i_House_Big_01_V1_F"]',cases)
        self.assertIn('[12,"Land_i_House_Big_02_V1_F"]',cases)
        self.assertIn('call CBE_fnc_CortexClearBuilding',cases)
        self.assertIn('vectorDistance (AGLToASL _room) <= 1.5',cases)
        self.assertIn('private _clearingMembers=+_members',cases)
        self.assertNotIn('_members select [1,2]',text)
        self.assertNotIn('_unit setPos', cases)
        self.assertNotIn('_actor setPos', cases)
        self.assertNotIn('setPosATL', cases.split('// Moving the building is the administrative stimulus;',1)[0])
        self.assertLess(cases.index('call _validateNewFixturePlacement'), cases.index('private _members=[]'))
        self.assertNotIn('call CBE_fnc_CortexGarrison',cases)

    def test_cqb_casualty_uses_real_reserve_and_physical_movement(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        case=text.split('// A casualty inside the clearing element',1)[1].split('// Exercise door handling',1)[0]
        self.assertIn('for "_i" from 0 to 9 do',case)
        self.assertIn('_casualty setDamage 1',case)
        self.assertIn('CBE_Cortex_ClearReinforcements',case)
        for proof in ('private _casualtyFixture=', '_casualtyFixture && {!alive _casualty}',
                      '_casualtyLost && {!isNull _reserve}',
                      'getOrDefault ["generation",-2]) == _casualtyGeneration',
                      'getOrDefault ["hardDeadline",-2]) == _casualtyHardDeadline'):
            self.assertIn(proof,case)
        self.assertIn('CLEAR-casualty-reserve-assigned',case)
        self.assertIn('CLEAR-casualty-reserve-physical-movement',case)
        self.assertNotIn('setPos',case)
        self.assertNotIn('moveIn',case)

    def test_building_entry_controls_cover_four_distinct_models(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8').split('missionNamespace setVariable ["CBE_CortexQA_Actors"',1)[0]
        for building in ['Land_i_House_Small_03_V1_F','Land_i_House_Small_01_V1_F','Land_i_House_Big_01_V1_F','Land_i_House_Big_02_V1_F']:
            self.assertIn(building,text)

    def test_remount_retry_preserves_active_boarding_command(self):
        text=source('cortexGroupTick')
        self.assertIn('if (assignedVehicle _unit != _vehicle) then {_unit assignAsCargo _vehicle}',text)
        self.assertIn('if ([] call _mayIssueMovement && {toUpperANSI (currentCommand _unit) != "GET IN"}) then {[_unit] orderGetIn true}',text)

    def test_remount_yields_to_live_danger_and_command_ownership(self):
        text=source('cortexGroupTick')
        remount=text.split('private _remount = _group getVariable ["CBE_Cortex_Remount",[]];',1)[1].split('private _contactDelay',1)[0]
        self.assertIn('_visible isNotEqualTo [] || {_dangerActive} || {_ordered}',remount)
        self.assertIn('if (_visible isNotEqualTo [] || {_dangerActive}) then {_state set ["dismounted",+_pending]};',remount)
        self.assertIn('|| {!([] call _mayIssueMovement)}',remount)
        for command in ['[_unit] orderGetIn false','unassignVehicle _unit','_unit assignAsCargo _vehicle','[_unit] orderGetIn true']:
            self.assertIn(command,remount)
            self.assertIn('_mayIssueMovement',remount[max(0,remount.index(command)-500):remount.index(command)])

    def test_replacement_boarding_audit_requires_owned_exit_and_physical_arrival(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        case=text.split('if (_replacementOrder) then {',1)[1].split('["Vehicle calm remount:',1)[0]
        self.assertIn('assignAsCargo _replacement',case)
        self.assertNotIn('moveInCargo',case)
        self.assertNotIn('call CBE_fnc_CortexRestoreCalm',case)
        self.assertIn('REMOUNT-replacement-assignment-preserved',case)
        self.assertIn('REMOUNT-replacement-physically-boarded',case)
        self.assertIn('_ownedExit && {_replacementBoarded}',case)
        self.assertIn('assignedVehicle _x != _replacement',case)

    def test_remount_preserves_replacement_vehicle_assignment(self):
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        self.assertIn('assignedVehicle (_x select 0) == (_x select 1)',tick)
        for text in [tick,restore]:
            self.assertIn('assignedVehicle _unit == (_x select 1)',text)
        self.assertIn('isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}',restore)

    def test_passenger_exit_records_ownership_before_engine_commands(self):
        text=source('cortexVehicles')
        self.assertLess(text.index('_state set ["dismounted", _dismounted]'),text.index('[_unit] orderGetIn false'))
        self.assertLess(text.index('[_unit] orderGetIn false'),text.index('doGetOut _unit'))

    def test_support_fixture_preserves_occlusion_and_assigned_destination(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runSupport.sqf').read_text(encoding='utf-8')
        self.assertLess(text.index('createVehicle ["Land_CncWall4_F"'),text.index('private _listeners='))
        self.assertIn('HEARING-fixture-no-prior-contact',text)
        self.assertIn('_rally=+(_assignedLease select 3)',text)
        self.assertIn('_x distance2D (_helperStarts select (_helpers find _x)) < 15',text)
        self.assertIn('_x distance2D _rally > 45',text)
        self.assertIn('forEach _soundTrace',text)

    def test_countermeasure_inventory_is_per_vehicle_and_live(self):
        text=source('cortexFireCountermeasure')
        self.assertNotIn('CountermeasureCache',text)
        self.assertIn('_vehicle weaponsTurret _turret',text)
        self.assertIn('toLowerANSI',text)
        self.assertIn('Fired events establish actual fire',text)
        self.assertEqual(text.count('magazinesAllTurrets _vehicle'),1)
        self.assertIn('_magazineSnapshot select',text)
        self.assertLess(text.index('private _magazineSnapshot='),text.index('private _turret = _x;'))
        self.assertIn('private _operator=_vehicle turretUnit _turret;',text)
        self.assertLess(text.index('if (!isNull _operator && {local _operator})'),text.index('_vehicle weaponsTurret _turret'))
        self.assertIn('if (_index >= 0 && {[_operator] call _operatorAvailable})',text)
        for guard in ('local _actor','!isPlayer _actor','vehicle _actor == _vehicle',
                      'CBE_fnc_CortexCombatEffective','CBE_fnc_CortexActorFireTaskAvailable',
                      '[group _actor,false,false,true] call CBE_fnc_CortexIsEligible'):
            self.assertIn(guard,text)
        commit=text.split('private _dispatched=false;',1)[1].split('if (!_dispatched)',1)[0]
        self.assertTrue(commit.startswith('\nisNil {'))
        self.assertIn('(_vehicle turretUnit _turret) != _operator',commit)
        self.assertIn('!([_operator] call _operatorAvailable)',commit)
        self.assertLess(commit.index('(_vehicle turretUnit _turret) != _operator'),commit.index('call BIS_fnc_fire'))
        self.assertIn('"NO_ELIGIBLE_LAUNCHER"',text)
        self.assertIn('"STATION_CHANGED"',text)
        for forbidden in ('moveIn','assignAs','enableAI','setCombatMode','setUnitCombatMode','selectRandom'):
            self.assertNotIn(forbidden,text)

    def test_artillery_baseline_retains_counter_owner(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        for gun in ['_gun','_counterGun','_emitter']:
            self.assertIn('['+gun+'] call _retainServerGun',text)
        self.assertIn('server-owner-retained',text)
        self.assertIn('local gunner _counterGun',text)

    def test_cortex_stop_invalidates_delayed_vehicle_actions(self):
        stop=source('cortexStop')
        self.assertIn('} forEach (vehicles select {local _x});',stop)
        for variable in ['CBE_Cortex_ArtilleryScootToken','CBE_Cortex_ArtilleryScootDeadline','CBE_Cortex_ArtilleryScootPurpose','CBE_Cortex_AttackFlarePhase','CBE_Cortex_AttackFlareCooldown']:
            self.assertIn('setVariable ["'+variable+'",nil,true]',stop)
        self.assertIn('old CBA callback cannot become valid again after a quick restart',stop)

    def test_ai_diagnostics_feature_depth_and_queue_scope(self):
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for feature in ['Regroup','Contact','PostContact','Flank','StreetCrossing','FireControl','Morale','Surrender','GrenadeEvasion','AntiArmour','Vehicles','ContactReports','Reinforce','Artillery','CounterBattery','Airborne','AircraftFlares','Investigate','Assault','Advance','CoordinatedAssault','Stance','AmmoShare','VehicleGunnery','ArtillerySmoke','AircraftBreak','VehicleDismount','VehicleRemount','VehicleWithdraw','CoverValidation','Hearing','MountedFire','Cover','AvoidInfantry','ContactHalt','Unload']:
            self.assertIn('["'+feature+'",',diagnostic)
        self.assertIn('private _parents=+(_dependencies',diagnostic)
        self.assertIn('oldestDueSeconds=',diagnostic)
        self.assertIn('keyedJobs=',diagnostic)
        self.assertIn('private _keyedJobs=0;',diagnostic)
        self.assertIn('staleOwnerJobs=',diagnostic)
        self.assertIn('cachedNextDueSeconds=',diagnostic)
        self.assertIn('earliestQueuedDueSeconds=',diagnostic)
        self.assertIn('deadlineCacheConsistent=',diagnostic)
        self.assertIn('private _queueState=if (_cacheConsistent) then {"LOADED"} else {"ERROR"}',diagnostic)
        self.assertIn('tuning [label,current,default]',diagnostic)
        self.assertNotIn('call CBE_fnc_CortexIsEligible',diagnostic)

    def test_ai_diagnostics_are_bounded_read_only_snapshots(self):
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertNotIn('call CBE_fnc_CortexZeusHeld',diagnostic)
        self.assertNotIn('setVariable',diagnostic)
        self.assertNotIn('smart-ai-pass',diagnostic)
        self.assertIn('call CBE_fnc_CortexTuningSpec',diagnostic)
        self.assertIn('(_localGroups select [0,20])',diagnostic)
        self.assertIn('(units _group) select [0,8]',diagnostic)
        self.assertIn('HC private action/queue state is unavailable here, not zero',diagnostic)
        self.assertIn('confirmedShots=',diagnostic)
        self.assertIn('haltReason=',diagnostic)
        self.assertIn('(_orderedGroups select [0,20])',diagnostic)
        self.assertIn('3D-assignment-distance-or-minus1',diagnostic)
        self.assertIn('cortex-order-snapshot-scope',diagnostic)
        for ownership in ['cortex-remount-ownership-','cortex-transition-ownership-','cortex-support-ownership-','cortex-artillery-scoot-ownership-']:
            self.assertIn(ownership,diagnostic)
        self.assertIn('assignmentConflicts=',diagnostic)
        self.assertIn('intentPhase=',diagnostic)
        self.assertIn('leaseToken=',diagnostic)
        self.assertIn('pending artillery relocations total=',diagnostic)
        self.assertIn('(_scoots select [0,20])',diagnostic)

    def test_full_feature_focus_never_omits_an_all_suite(self):
        import re
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        selections=re.findall(r'if \(_focus in (\[[^\]]+\])\)',runner)
        for selection in selections:
            if '"all"' in selection:
                self.assertIn('"features"',selection)
        self.assertNotIn('if (_focus == "all")',runner)
        self.assertGreater(runner.index('if (_focus in ["all","features","coordinated","supportflows"])'),runner.index('cortexQAFire.sqf'))

    def test_other_feature_batch_and_independent_artillery(self):
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        for focus in ['mechanics','reactions','support','airborne','vehicles','fire','landing','cover','contact','profiles','scheduler','performance','lifecycle','aircraft','deceleration','gunnery','artillerysmoke','crossing','convoyseats','avoidance']:
            import re
            self.assertRegex(runner,r'if \(_focus in \[[^\]]*"features"[^\]]*"'+focus+r'"[^\]]*\]\)')
        artillery=runner.split('if (_focus in ["all","features","artillery"]) then {',1)[1].split('if (_focus in ["all","features","convoyseats"',1)[0]
        self.assertNotIn('_u1',artillery)
        self.assertIn('private _spotter=',artillery)
        self.assertIn('deleteVehicle _spotter',artillery)
        self.assertIn('deleteGroup _gunGroup',artillery)

    def test_failed_coordinated_bound_holds_until_new_sequence(self):
        end=source('cortexFlankEnd')
        self.assertIn('_reason in ["STALLED","TIME_LIMIT","RECOVERY_FAILED"]',end)
        hold=end.split('if (_holdFailedBound || {_holdCompletedSupport}) then {',1)[1].split('} else {',1)[0]
        self.assertIn('doStop _x',hold)
        self.assertNotIn('disableAI "PATH"',hold)
        self.assertNotIn('supportHeld',hold)
        self.assertNotIn('_x doFollow',hold)
        self.assertIn('[_supportToken,_drill get "supportSequence",_reason]',end)
        maintain=source('cortexSupportMaintain')
        self.assertIn('if (_newMove || {!_coordinating})',maintain)
        self.assertIn('private _newMove=_moving && {(_state getOrDefault ["supportBoundSequence",-1]) < (_role select 1)}',maintain)

    def test_coordinated_clean_approach_is_additive(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('[[1408,1410] call _terrainPosition,[1608,1410] call _terrainPosition]',qa)
        self.assertIn('[[1500,1470] call _terrainPosition]',qa)
        self.assertIn('["_localScreens",false,[true]]',qa)
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('if (_focus == "coordinatedbounds")',runner)
        self.assertIn('if (_focus in ["all","features","coordinatedclean"])',runner)
        self.assertIn('[_cleanCheck,_phase,_wait,[],true,true]',runner)
        self.assertIn('["CLEAN-"+_id,_passed,_detail]',runner)

    def test_coordinated_rally_screen_is_removed_before_assault_measurement(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('COORD-assault-corridor-clear',qa)
        self.assertIn('{deleteVehicle _x} forEach _movementScreens;',qa)
        self.assertLess(qa.index('COORD-assault-corridor-clear'),qa.index('Movement diagnostic: concurrent coordinated bounds'))
        self.assertIn('private _allRallied=true;',qa)
        self.assertIn('private _team=_x;',qa)
        self.assertIn('if ((_team findIf {_x distance2D _area > 45}) >= 0)',qa)
        self.assertIn('_allRallied',qa)
        rally=qa.split('private _rallied=[{',1)[1].split('},120] call _wait;',1)[0]
        self.assertNotIn('(_teams findIf {',rally)

    def test_literal_qa_tuning_requests_have_transport_entries(self):
        import re
        spec = set(re.findall(r'\["(CBE_[^"]+)"', source('cortexTuningSpec')))
        for path in (ROOT/'releaseVerificationAndDeployment/cortexQA').glob('*.sqf'):
            text = path.read_text(encoding='utf-8')
            for match in re.finditer(r'\[createHashMapFromArray\s*\[', text):
                depth, quoted, end = 1, False, match.start()+1
                # Match the call's outer array; unrelated HashMaps must not consume
                # later code and falsely treat state/diagnostic keys as settings.
                while end < len(text) and depth:
                    char = text[end]
                    if char == '"':
                        if quoted and end+1 < len(text) and text[end+1] == '"':
                            end += 2
                            continue
                        quoted = not quoted
                    elif not quoted:
                        depth += (char == '[') - (char == ']')
                    end += 1
                if not re.match(r'\s*call\s+CBE_fnc_CortexTuning\b', text[end:]):
                    continue
                requested = set(re.findall(r'\["(CBE_[^"]+)"', text[match.start():end]))
                self.assertFalse(requested-spec, f'{path.name}: unknown runtime settings {requested-spec}')

    def test_advance_contact_delay_is_in_authoritative_transport(self):
        self.assertIn('"CBE_AIPass_Advance_MinContactSeconds"', source('cortexTuningSpec'))
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-requested-contact-delay', qa)

    def test_movement_roe_restores_only_the_owned_value(self):
        step = source('cortexFlankStep')
        self.assertIn('_drill set ["groupCombatMode",["RED","YELLOW"]]', step)
        self.assertIn('_group setCombatMode "YELLOW"', step)
        self.assertIn('combatMode _group != (_groupModeLease select 1)', step)
        self.assertNotIn('_group setCombatMode "BLUE"', step)
        for name in ['cortexFlankEnd', 'cortexLocality']:
            self.assertIn('combatMode _group == (_groupModeLease select 1)', source(name))
            self.assertIn('_group setCombatMode (_groupModeLease select 0)', source(name))
        checkpoint=source('cortexCheckpoint')
        self.assertIn('restoreGroupCombatMode',checkpoint)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-combat-mode-restored', qa)

    def test_tactical_bounds_use_an_owned_full_speed_lease(self):
        step=source('cortexFlankStep')
        self.assertIn('_drill set ["groupSpeedMode",[_priorSpeed,"FULL"]]',step)
        self.assertIn('_group setSpeedMode "FULL"',step)
        self.assertIn('speedMode _group != (_groupSpeedLease select 1)',step)
        self.assertIn('"SPEED_CHANGED" call _end',step)
        for name in ['cortexFlankEnd','cortexLocality']:
            cleanup=source(name)
            self.assertIn('speedMode _group == (_groupSpeedLease select 1)',cleanup)
            self.assertIn('_group setSpeedMode (_groupSpeedLease select 0)',cleanup)
        self.assertIn('restoreGroupSpeedMode',source('cortexCheckpoint'))
        self.assertIn('CBE_fnc_CortexGroupPostureTaskAvailable',step)
        self.assertIn('private _policyReady=true;',step)
        policy=step.split('private _policyReady=true;',1)[1].split('if (!_policyReady || {_modeSettling})',1)[0]
        self.assertIn('if (!([_group] call CBE_fnc_CortexGroupPostureTaskAvailable)) exitWith {};',policy)
        self.assertEqual(policy.count('_policyReady=false'),2)
        self.assertLess(step.index('_group setSpeedMode "FULL"'),step.index('_drill set ["groupSpeedMode",[_priorSpeed,"FULL"]]'))
        self.assertIn('if (speedMode _group == "FULL")',step)
        end=source('cortexFlankEnd')
        self.assertIn('private _policyAvailable=_mayRestore && {[_group] call CBE_fnc_CortexGroupPostureTaskAvailable}',end)
        self.assertIn('CBE_Cortex_DrillPolicyUnresolved',end)

    def test_coordinated_bound_uses_matching_role_objective_before_personal_contact(self):
        text = source('cortexFlankStep')
        self.assertIn('if (_support) then {+(_supportRole select 4)}', text)
        self.assertLess(text.index('!_supportValid'), text.index('private _enemyPos ='))
        self.assertIn('(_supportRole select 0) == _supportToken', text)
        self.assertIn('(_supportRole select 1) == (_drill get "supportSequence")', text)

    def test_tactical_handoffs_use_optional_pause_without_grenade_state_gate(self):
        text = source('cortexFlankStep')
        for stage in ['FINAL','CONSOLIDATE','CLEAR']:
            block = text.split('case "'+stage+'": {')[1].split('case ')[0]
            self.assertIn('CBE_AIPass_Flank_BoundPause', block)
        road = text.split('case "CROSS_NEAR": {')[1].split('case "FINAL":')[0]
        self.assertIn('_drill set ["pauseUntil", _now]', road)
        self.assertNotIn('_now + 3', road)
        self.assertIn('!_support &&', text)
        self.assertIn('(_drill getOrDefault ["stage",""]) in ["PAUSE","HOLD"]', text)
        self.assertIn('_result=0;', text)
        self.assertIn('_drill set ["grenadeActionUntil",_now]', text)
        self.assertNotIn('case "GRENADE": {', text)

    def test_tactical_bounds_use_dynamic_line_defaults(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        route=source('cortexPlanRoute')
        advance=source('cortexAdvanceStart')
        step=source('cortexFlankStep')
        self.assertIn('["CBE_AIPass_Flank_BoundDistance", 55]',config)
        self.assertIn('["CBE_AIPass_Flank_BoundPause", 0]',config)
        self.assertIn('getVariable ["CBE_AIPass_Flank_BoundDistance", 55]',route)
        self.assertIn('getVariable ["CBE_AIPass_Flank_BoundDistance", 55]',advance)
        for proof in ('_info param [6,[],[[]]]','_info param [7,[],[[]]]',
                      'abs _crossRate >= 0.2','_along+(-_halfWidth-_lateral)/_crossRate',
                      '_crossings pushBack [_near,_far]','_far+4 <= _length','(_far + 4) min _length'):
            self.assertIn(proof,route)
        self.assertNotIn('_crossings pushBack [_along, _halfWidth]',route)
        self.assertIn('private _depth = 0;',step)
        self.assertNotIn('formation _group == "WEDGE"',step)
        self.assertNotIn('private _rank = ceil (_forEachIndex / 2)',step)

    def test_support_reserves_separate_rally_areas_in_durable_leases(self):
        server = source('cortexSupportServer')
        step = source('cortexSupportStep')
        self.assertIn('forEach [[80,0],[80,-30],[80,30],[80,-60],[80,60],[60,0],[100,0]]', server)
        self.assertIn('[_requesterPosition,_rallyCandidates,_enemy] call CBE_fnc_CortexSelectAvenue', server)
        self.assertIn('["enemy",+_enemy]', server)
        self.assertIn('for "_slot" from 0 to 5 do', step)
        self.assertIn('(_other select 3) distance2D _centre < 109', step)
        self.assertIn('!surfaceIsWater _centre', step)
        self.assertIn('((surfaceNormal _centre) select 2) >= 0.55', step)
        self.assertIn('getPosATL _helperTransmitter,_rallyCandidates', step)
        self.assertIn('call CBE_fnc_CortexSelectAvenue', step)
        self.assertIn('if (_rally isNotEqualTo []) then {', step)
        self.assertIn('_job get "expiry",_rally,_job get "at"', step)
        self.assertNotIn('_job get "expiry",+(_job get "rally")', step)
        fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        self.assertIn('COORD-distinct-rally-areas', fixture)
        self.assertIn('_x distance2D _area > 45', fixture)

    def test_movement_lease_preserves_fire_and_rejects_competing_roe(self):
        step=source('cortexFlankStep')
        self.assertNotIn('call _clearAttack',step)
        self.assertIn('_group setCombatMode "YELLOW"',step)
        self.assertNotIn('_group setCombatMode "BLUE"',step)
        self.assertIn('"ROE_CHANGED" call _end',step)
        self.assertIn('combatMode _group != (_groupModeLease select 1)',step)
        stance=source('cortexStance')
        self.assertIn('in ["START","MOVE"]',stance)
        self.assertIn('+(_drill getOrDefault ["movers"',stance)
        self.assertIn('grenadeThrower',stance)

    def test_coordinated_moving_fire_is_measured_at_discharge(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        fired=qa.split('addEventHandler ["FiredMan",{')[1].split('    }];')[0]
        self.assertIn('abs speed _unit > 2',fired)
        self.assertIn('CBE_Cortex_SupportTeams',fired)
        self.assertIn('_unit in (_teams select 5)',fired)
        self.assertIn('COORD-moving-roe-fire-at-will-disengaged',qa)
        self.assertIn('combatMode _g != "YELLOW"',qa)
        self.assertIn('_movementRoeSamples',qa)
        self.assertIn('_movementRoeViolations',qa)
        self.assertIn('CBE_CortexQA_MovingShots',fired)
        self.assertIn('COORD-no-prolonged-empty-range-idle',qa)
        self.assertNotIn('"COORD-no-prolonged-empty-range-idle",_advanced &&',qa)
        self.assertIn('COORD-full-fire-team-physical-bounds',qa)
        self.assertIn('COORD-no-engine-attack-overrides',qa)
        self.assertIn('_stage == "MOVE"',qa)
        self.assertIn('_x distance2D _destination > 3',qa)
        self.assertIn('empty-range limit=18 s',qa)
        self.assertIn('currentCommand _x == "ATTACK"',qa)
        self.assertIn('CBE_fnc_CortexQAInstallShotCounter',qa)
        self.assertIn('remoteExecCall ["CBE_fnc_CortexQAInstallShotCounter",_owner]',qa)

    def test_zeus_mark_releases_cortex_immediately_on_group_owner(self):
        mark=(ROOT/'addons/infantry/functions/cortexZeusMark.sqf').read_text()
        executable=mark.split('params [',1)[1]
        self.assertLess(executable.index('setVariable ["CBE_AIPass_ZeusHold"'),executable.index('CBE_fnc_CortexReleaseGroup'))
        self.assertIn('[_group,false,"ZEUS_TAKEOVER"] call CBE_fnc_CortexReleaseGroup',mark)
        self.assertIn('[_group,false,"ZEUS_TAKEOVER"] remoteExecCall ["CBE_fnc_CortexReleaseGroup",groupOwner _group]',mark)
        self.assertIn('CBE_Cortex_CombinedRole',mark)
        self.assertIn('CBE_Cortex_CombinedOpportunity',mark)
        self.assertIn('CBE_Cortex_CombinedApplied',mark)
        self.assertIn('CBE_Cortex_ZeusOrderSnapshot',mark)
        self.assertIn('CBE_AIPass_ZeusControlKind',mark)
        self.assertIn('["DIRECT","WAYPOINT"] select _waypoints',mark)
        self.assertIn('if (!_waypoints && {(_group getVariable ["CBE_AIPass_ZeusControlKind",""]) == "DIRECT"}',mark)
        self.assertIn('setVariable ["CBE_AIPass_ZeusWaypoints",false,true]',mark)
        self.assertIn('_hold select 0',mark)
        self.assertIn('["_waypointIndex",-1,[0]]',mark)
        self.assertLess(executable.index('setVariable ["CBE_Cortex_ZeusOrderSnapshot"'),
                        executable.index('CBE_fnc_CortexReleaseGroup'))
        watch=(ROOT/'addons/core/functions/cortexZeusWatchLocal.sqf').read_text()
        self.assertIn('params ["", "_group", "_waypointID"]',watch)
        self.assertIn('[_group,true,_waypointID] call CBE_fnc_CortexZeusMark',watch)
        self.assertIn('[_waypoint select 0,true,_waypoint select 1] call CBE_fnc_CortexZeusMark',watch)
        held=source('cortexZeusHeld')
        self.assertIn('if (_kind == "WAYPOINT" && {_group getVariable ["CBE_AIPass_ZeusWaypoints",false]}) exitWith {',held)
        self.assertIn('setVariable ["CBE_AIPass_ZeusLocalUntil",-1]',held)
        self.assertLess(held.index('if (_kind == "WAYPOINT"'),
                        held.rindex('time < (_group getVariable ["CBE_AIPass_ZeusLocalUntil"'))

    def test_handover_visuals_do_not_keep_stale_rally_labels(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for description,label in [('QA FRESH ORDINARY ORDER','ORDINARY ORDER'),
                                  ('QA ZEUS REPLACEMENT','ZEUS ORDER'),
                                  ('QA UNOPPOSED HANDOVER DIAGNOSTIC','UNOPPOSED ORDER')]:
            stage=qa.split('setWaypointDescription "'+description+'";')[1].split('} forEach _teams;')[0]
            self.assertIn('CBE_CortexQA_Label',stage)
            self.assertIn(label,stage)

    def test_coordinated_handover_marks_the_exact_replacement_order(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        zeus=qa.split('private _zeusOrigins=',1)[1].split('private _unopposedOrigins=',1)[0]
        self.assertIn('[_g,true,_wp select 1] call CBE_fnc_CortexZeusMark',zeus)
        self.assertLess(zeus.index('_g setCurrentWaypoint _wp'),
                        zeus.index('[_g,true,_wp select 1] call CBE_fnc_CortexZeusMark'))
        self.assertIn('_arrived < _viableMinimum',zeus)
        self.assertIn('_progressed < _viableMinimum',zeus)
        for setting in ['setWaypointBehaviour "AWARE"','setWaypointCombatMode "YELLOW"',
                        'setWaypointSpeed "FULL"']:
            self.assertIn(setting,zeus)

    def test_coordinated_contact_loss_removes_and_restores_engine_knowledge(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        transition=qa.split('// Remove the known target from the requester',1)[1].split('_enemy setUnitPos "AUTO";',1)[0]
        self.assertIn('hideObjectGlobal _enemy',transition)
        self.assertIn('_requester ignoreTarget [_enemy,true]',transition)
        self.assertIn('_requester ignoreTarget [_enemy,false]',transition)
        self.assertIn('_requester reveal [_enemy,4]',transition)
        self.assertIn('_enemy hideObjectGlobal false',transition)
        self.assertNotIn('createVehicle ["Land_CncWall4_F"',transition)

    def test_multi_manoeuvre_keeps_both_squads_in_tactical_range(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        self.assertIn('setVariable ["CBE_AIPass_NearRange",5000]',qa)
        self.assertIn('setVariable ["CBE_AIPass_FarRange",5000]',qa)
        self.assertIn('setVariable ["CBE_AIPass_NearRange",_savedNearRange]',qa)
        self.assertIn('setVariable ["CBE_AIPass_FarRange",_savedFarRange]',qa)
        self.assertIn('CBE_Cortex_FlankRefusal',qa)
        self.assertIn('CBE_Cortex_AdvanceRefusal',qa)

    def test_support_release_retires_owned_hold_after_engine_combat_relabels_it(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]',maintain)
        self.assertNotIn('_x != leader _group',maintain)
        self.assertIn('private _pathOwned=_x getVariable ["CBE_Cortex_SupportPathHold",false]',maintain)
        self.assertIn('if (_pathOwned && {local _x}',maintain)
        self.assertIn('group _x == _group',maintain)
        self.assertIn('CBE_Cortex_SupportPathHold',maintain)
        cover=maintain.split('if (_coordinating) then {',1)[1]
        self.assertNotIn('disableAI "PATH"',cover)
        self.assertNotIn('setVariable ["CBE_Cortex_SupportPathHold",true',cover)
        restore=source('cortexRestoreCalm')
        self.assertIn('group _unit == _group',restore)
        self.assertIn('CBE_Cortex_SupportPathHold',restore)
        for text in [maintain,restore]:
            self.assertNotIn('currentCommand _x == "STOP"',text)

    def test_calm_cleanup_releases_cortex_holds_without_overwriting_new_individual_orders(self):
        restore=source('cortexRestoreCalm')
        release_hold=restore.split('private _releaseOwnedHold={',1)[1].split('};\n{',1)[0]
        self.assertIn('private _pathOwned=_restorePath && {_unit getVariable ["CBE_Cortex_SupportPathHold",false]}',release_hold)
        self.assertIn('if (_pathOwned) then {',release_hold)
        self.assertIn('_unit enableAI "PATH"',release_hold)
        self.assertIn('_unit setVariable ["CBE_Cortex_SupportPathHold",nil,true]',release_hold)
        self.assertIn('_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]',release_hold)
        self.assertIn('CBE_fnc_CortexSearchMoveOwned',release_hold)
        self.assertIn('!_yieldToExternal &&',release_hold)
        self.assertIn('CBE_fnc_CortexZeusHeld',release_hold)
        self.assertIn('"CBE_AIPass_ClearOrder",[]]) isEqualTo []',release_hold)
        self.assertIn('_unit doFollow _leader',release_hold)
        for actor,text in (('_unit',release_hold),('_x',source('cortexReleaseGroup').split('// Full shutdown',1)[1].split('// New curator intent',1)[0])):
            for guard in (f'simulationEnabled {actor}',f'!isObjectHidden {actor}',f'!fleeing {actor}',f'{actor} getVariable ["ace_medical_ai_healQueue",[]]'):
                self.assertIn(guard,text)
        self.assertLess(release_hold.index('_unit enableAI "PATH"'),release_hold.index('!fleeing _unit'))
        drill_recall=source("cortexFlankEnd").split("_members=_members select {",1)[1].split("private _stragglers",1)[0]
        for guard in ("!fleeing _x", 'ace_medical_ai_healQueue', "_ownsNativeMovement"):
            self.assertIn(guard,drill_recall)

        for external in ['GET IN','GET OUT','ACTION','SCRIPTED']:
            self.assertNotIn(f'"{external}"',release_hold)
        self.assertIn('[_x,false,false] call _releaseOwnedHold',restore)
        self.assertIn('[_x,false,true] call _releaseOwnedHold',restore)
        search_release=restore.split('forEach (_state getOrDefault ["searchTeam", []])',1)[0].rsplit('{if (alive _x)',1)[-1]
        self.assertNotIn('enableAI "PATH"',search_release)

    def test_feature_registry_is_packaged_and_dispatched_by_the_standalone_pipeline(self):
        from check_cortex_coverage import audit, render_markdown
        from mod_pipeline import ALIASES
        data, errors, pending = audit(ROOT)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(data['cases']), 65)
        self.assertIn('COMPAT', pending)
        self.assertIn('COORD', pending)
        self.assertIn('COMBINED-ARMS', pending)
        self.assertIn('AIR-ATTACK', pending)
        production = {
            path.relative_to(ROOT).as_posix()
            for path in (ROOT / 'addons').rglob('*.sqf')
        }
        assigned = [path for case in data['cases'] for path in case['production_sources']]
        self.assertEqual(production, set(assigned))
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertTrue(all((ROOT / path).is_file() for path in assigned))
        report = render_markdown(data)
        self.assertEqual(report, (ROOT / 'releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md').read_text(encoding='utf-8'))
        for case in data['cases']:
            self.assertIn(f"| {case['id']} - {case['title']} |", report)
        pipeline = (ROOT / 'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')", pipeline)
        for source in {source for case in data['cases'] for source in case['executable_sources']}:
            if source not in ['runServer.sqf', 'runClient.sqf']:
                suffix = Path(source).stem[3:]
                staged = 'cortexQA' + ALIASES.get(suffix, suffix) + '.sqf'
                self.assertIn(staged, server)
    def test_external_ownership_markers_are_isolated_to_compatibility(self):
        compatibility = ROOT / 'addons/compatibility/functions'
        for name in ['compatibilityExternalControl.sqf', 'compatibilityPrecisionExcluded.sqf']:
            self.assertTrue((compatibility / name).is_file(), name)
        config = (ROOT / 'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CompatibilityExternalControl', config)
        self.assertIn('class CompatibilityPrecisionExcluded', config)
        for path in (ROOT / 'addons').rglob('*.sqf'):
            if 'compatibility' not in path.parts:
                text = path.read_text(encoding='utf-8')
                self.assertNotIn('Waldo_AI_ExternalControl', text, path)
                self.assertNotIn('Waldo_AI_PrecisionExclude', text, path)

    def test_terrain_focus_requires_measured_relief_and_physical_travel(self):
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        terrain=(ROOT/'releaseVerificationAndDeployment/cortexQA/runTerrain.sqf').read_text(encoding='utf-8')
        self.assertIn('[string]$Focus=\'all\'',launcher)
        self.assertIn("mod_pipeline.py') stage $Package $runtime --focus $Focus",launcher)
        pipeline=(ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')",pipeline)
        self.assertIn('if (_focus == "terrain")',server)
        self.assertIn('cortexQATerrain.sqf',server)
        self.assertIn('toLower worldName != "vr"',terrain)
        self.assertIn('_relief >= 7',terrain)
        self.assertIn('_roughness >= 0.025',terrain)
        self.assertIn('surfaceIsWater _x',terrain)
        self.assertIn('"INFANTRY"] call CBE_fnc_CortexSelectAvenue',terrain)
        self.assertIn('"VEHICLE"] call CBE_fnc_CortexSelectAvenue',terrain)
        self.assertIn('TERRAIN-infantry-physical-progress',terrain)
        self.assertIn('TERRAIN-vehicle-physical-progress',terrain)
        self.assertIn('TERRAIN-defence-physical-arrival',terrain)
        for battle_marker in ['TERRAIN-BATTLE-equal-force-prerequisite',
                              'TERRAIN-BATTLE-both-sides-actual-fire',
                              'TERRAIN-BATTLE-real-casualties',
                              'TERRAIN-BATTLE-multi-group-physical-progress',
                              'TERRAIN-BATTLE-production-tactics-observed',
                              'TERRAIN-BATTLE-composite-outcome',
                              'forEach [[east,"O_Soldier_F",180,"East"],[west,"B_Soldier_F",0,"West"]]',
                              '_waypoint setWaypointType "SAD"']:
            self.assertIn(battle_marker,terrain)
        terrain_battle_source=terrain.split('// The flat controller ranges')[1].split('// Find one long inland air corridor')[0]
        self.assertNotIn('allowDamage false',terrain_battle_source)
        for air_marker in ['TERRAIN-air-corridor-found','_laneRelief >= 45',
                           'TERRAIN-AIR-PLANE','TERRAIN-AIR-HELICOPTER',
                           '-terrain-plan','-physical-flight','-real-weapon-release',
                           '-target-damaged','-finite-egress']:
            self.assertIn(air_marker,terrain)
        self.assertNotIn('call CBE_fnc_CortexAirAttackPlan',terrain)
        self.assertNotIn('call CBE_fnc_CortexAirAttack;',terrain)
        coverage=json.loads((ROOT/'releaseVerificationAndDeployment/cortexQA/coverage.json').read_text(encoding='utf-8'))
        terrain_case=next(case for case in coverage['cases'] if case['id']=='TERRAIN')
        self.assertEqual(terrain_case['executable_sources'],['runTerrain.sqf'])
        self.assertEqual(terrain_case['status'],'implemented_partial')
        self.assertEqual(terrain_case['live_evidence'],[])
        terrain_battle=next(case for case in coverage['cases'] if case['id']=='TERRAIN-BATTLE')
        self.assertEqual(terrain_battle['executable_sources'],['runTerrain.sqf'])
        self.assertEqual(terrain_battle['status'],'implemented_partial')
        self.assertEqual(terrain_battle['live_evidence'],[])

    def test_audit_visualisation_has_a_bounded_render_cost(self):
        guide=(ROOT/'releaseVerificationAndDeployment/cortexQA/runGuide.sqf').read_text(encoding='utf-8')
        for marker in ['positionCameraToWorld [0,0,0]','private _renderDistance=2500',
                       'if (count _actors > 12) then {_actors resize 12}',
                       '_position distance (_track select (count _track-1)) > 2',
                       'if (count _track > 48) then {_track deleteRange [0,count _track-48]}',
                       'distance2D _cameraPosition <= _renderDistance']:
            self.assertIn(marker,guide)
        self.assertNotIn('if (count _track > 90) then {_track deleteAt 0}',guide)

    def test_packaged_audit_requests_the_declared_window_resolution_and_observer_zeus(self):
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        for marker in ['[int]$ResolutionWidth=3840','[int]$ResolutionHeight=2160',
                       'winW=$ResolutionWidth;','winH=$ResolutionHeight;',
                       'resolutionW=$ResolutionWidth;','resolutionH=$ResolutionHeight;',
                       '"-x=$ResolutionWidth"','"-y=$ResolutionHeight"',
                       '"-windowWidth=$ResolutionWidth"','"-windowHeight=$ResolutionHeight"',
                       'Show-AuditClientWindow $client $ClientWindowTimeoutSeconds',
                       '[WaitAuditWindow]::IsWindowVisible($client.MainWindowHandle)',
                       "'-noBattlEye'", "'-showScriptErrors'", 'sole observer Zeus slot automatically']:
            self.assertIn(marker,launcher)
        self.assertIn("$auditWindowStyle = if ($Interactive) {'Normal'} else {'Hidden'}",launcher)
        self.assertIn("Start-AuditProcess 'arma3_x64.exe'",launcher)

    def test_coordinated_handoffs_do_not_stack_fixed_tactical_pauses(self):
        text = source('cortexFlankStep')
        self.assertIn('private _teamPause=if (_support) then {0} else', text)
        self.assertIn('private _pause = if (_support) then {0} else', text)
        self.assertIn('if (_arrived) then {', text)
        self.assertNotIn('case "GRENADE": {', text)
        self.assertIn('private _teamPause=if (_support) then {0} else', text)

    def test_successful_manoeuvre_flows_into_assault_without_second_chance_roll(self):
        text=source('cortexFlankStep')
        hold=text.split('case "HOLD":',1)[1]
        assault=hold.split('private _assault =',1)[1].split('private _assaultDirection',1)[0]
        self.assertIn('if (_support) then {_assaultRange = _assaultRange max 100}',hold)
        self.assertNotIn('random 1',assault)
        self.assertIn('_drill set ["assaultGrenade",random 1 <',hold)
        self.assertIn('if (_drill getOrDefault ["assaultGrenade",false])',text)
        self.assertIn('_points pushBack [_approachPoint, "ASSAULT"]',hold)
        self.assertIn('_points pushBack [_clearPoint, "CLEAR"]',hold)

    def test_live_contact_immediately_retires_stale_transition_intent(self):
        tick=source('cortexGroupTick')
        enter=tick.split('private _enterContact = {',1)[1].split('};\nprivate _beginContact',1)[0]
        self.assertIn('setVariable ["CBE_Cortex_TransitionIntent",nil,true]',enter)

    def test_native_waypoint_return_uses_one_bounded_recovery_without_editing_waypoints(self):
        text = source('cortexFlankStep')
        guard = text.split('private _returnedToWaypoint =')[1].split('if (_now-(_last select 3) > _timeout')[0]
        for required in ['currentWaypoint _group ==', 'isEqualTo (_waypoint select 1)',
                         'expectedDestination _unit', '(_retry select 0) < 1',
                         '_now-(_retry select 1) >= 8']:
            self.assertIn(required, guard)
        self.assertNotIn('setWaypoint', text)
        self.assertNotIn('deleteWaypoint', text)
        self.assertLess(text.index('CBE_fnc_CortexIsEligible'), text.index('private _returnedToWaypoint'))

    def test_bound_handoff_does_not_issue_competing_formation_orders(self):
        text = source('cortexFlankStep')
        issue = text.split('private _issue = {')[1].split('private _result =')[0]
        self.assertNotIn('_unit doFollow', issue)
        self.assertNotIn('setUnitCombatMode "BLUE"', issue)
        self.assertIn('_unit doMove _spot', issue)
        self.assertIn('if (unitCombatMode _unit == "RED")', issue)
        self.assertIn('_combatModes pushBack [_unit,"RED","YELLOW"]', issue)
        self.assertIn('unitCombatMode _unit == _ownedMode', text)

    def test_cancelled_throw_does_not_block_assault_progression(self):
        throw = source('cortexThrowGrenade')
        self.assertIn('setVariable ["CBE_Cortex_FragCancelled",_drillToken]', throw)
        self.assertIn('exitWith {[] call _cancel}', throw)
        self.assertIn('if (_thrown) exitWith {};', throw)
        self.assertNotIn('if (_thrown) exitWith {call _cancel}', throw)
        step = source('cortexFlankStep')
        self.assertNotIn('getVariable ["CBE_Cortex_FragCancelled",""]) == _token', step)
        self.assertNotIn('"GRENADE_UNRESOLVED" call _end', step)
        self.assertIn('"ASSAULT_GRENADE_DISPATCHED"] select _queued] call CBE_fnc_CortexDrillSetStage', step)

    def test_flank_routes_avoid_friendly_support_fire_corridors(self):
        start = source('cortexFlankStart')
        selector = source('cortexSelectAvenue')
        for marker in ['private _supportOrigins = []', 'private _supportCandidates = []',
                       'CBE_AIPass_PublicPhase','CBE_Cortex_SupportRole',
                       '(_supportRole select 2) == "COVER"','private _supportSpotters=',
                       '(count _friendlyFoot) min 8','private _supportKnows=',
                       '_supportSpotters findIf {_x knowsAbout _target > 0.5} >= 0',
                       '(count _supportCandidates) min 4',
                       'private _avenueCandidates=[]','[1,110,90]',
                       'call CBE_fnc_CortexSelectAvenue']:
            self.assertIn(marker, start)
        self.assertNotIn('_friendlyLeader knowsAbout _target > 0.5', start)
        for marker in ['_lateral < 30','_pointSide*_startSide < 0',
                       'forEach [0.25,0.5,0.75]',
                       '[_threatASL,_sampleASL,objNull,"COVER",_threatObject] call CBE_fnc_CortexCoverScreened',
                       '[_threatASL,_sampleASL,objNull,"CONCEALMENT",_threatObject] call CBE_fnc_CortexCoverScreened']:
            self.assertIn(marker, selector)
        vehicle=selector.split('if (_vehicleScreening) then {',1)[1].split('} else {',1)[0]
        for marker in ('forEach [-1,0,1]','_platform,"COVER",_threatObject',
                       'if (_screened) then {_hardScreen=_hardScreen+3}'):
            self.assertIn(marker,vehicle)
        self.assertNotIn('CONCEALMENT',vehicle)
        self.assertIn('boundingBoxReal _platform',selector)
        self.assertIn('getObjectScale _platform',selector)
        self.assertIn('_radius <= 30',selector)
        self.assertIn('_height <= 20',selector)
        self.assertIn('_threatObject,"VEHICLE",_vehicle',source('cortexVehicles'))
        self.assertIn('objNull,"VEHICLE",_vehicle',source('cortexAARelocate'))
        self.assertNotIn('selectRandom [',start)
        self.assertNotIn('private _routeProtection = {',start)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        self.assertIn('private _fireLaneCrossings=[0,0]',qa)
        self.assertIn('-no-support-fire-lane-crossing',qa)
        self.assertIn('_lateral < 18',qa)

    def test_avenue_can_leave_own_fire_lane_but_cannot_reenter(self):
        selector=source('cortexSelectAvenue')
        for requirement in ['private _laneStates','starts inside corridor','_sample distance2D _start > 60',
                            '_laneState set [1,true]','if (_insideLiveLane) then {_valid=false}']:
            self.assertIn(requirement,selector)
        self.assertLess(selector.index('_laneState set [1,true]'),
                        selector.rindex('if (_insideLiveLane) then {_valid=false}'))

    def test_tactical_refusals_explain_trigger_failures_without_polling(self):
        flank=source('cortexFlankStart')
        for reason in ['SUPPORT_OWNS_MOVEMENT','MOVEMENT_LEASE','MORALE','INSUFFICIENT_ACTORS',
                       'NO_TARGET_IN_RANGE','NO_MANOEUVRE_ELEMENT','NO_SAFE_AVENUE']:
            self.assertIn(reason,flank)
        self.assertIn('CBE_Cortex_FlankRefusal',flank)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',flank)
        advance=source('cortexAdvanceStart')
        for reason in ['SUPPORT_OWNS_MOVEMENT','MOVEMENT_LEASE','CONTACT_DELAY','NO_TARGET',
                       'TARGET_TOO_CLOSE','AUTHORED_OBJECTIVE_TYPE','STALE_CONTACT','OBJECTIVE_REACHED',
                       'NO_MANOEUVRE_ELEMENT','NO_COVER_ELEMENT','NO_SAFE_AVENUE']:
            self.assertIn(reason,advance)
        self.assertIn('CBE_Cortex_AdvanceRefusal',advance)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',advance)
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('cortex-tactical-refusal-',diagnostic)
        self.assertIn('CBE_Cortex_FlankRefusal',diagnostic)
        self.assertIn('CBE_Cortex_AdvanceRefusal',diagnostic)

    def test_group_phases_change_atomically_and_publish_bounded_history(self):
        setter=source('cortexSetPhase')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('class CortexSetPhase',functions)
        for marker in ['_state set ["phase",_next]','_state set ["phaseStart",_phaseStart]',
                       'setVariable ["CBE_AIPass_PublicPhase",_next,true]',
                       'CBE_Cortex_PhaseTransition','CBE_Cortex_PhaseTransitions',
                       'if (count _history > 32)']:
            self.assertIn(marker,setter)
        self.assertIn('["_force",false,[true]]',setter)
        self.assertIn('getVariable ["CBE_AIPass_PublicPhase",_localPrevious]',setter)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',setter)
        self.assertIn('cortex-phase-transition-',diagnostics)
        self.assertIn('phase state changed outside the atomic transition path',diagnostics)
        for name in ['cortexGroupTick','cortexRestoreCalm','cortexRetreat','cortexVehicles','cortexLocality']:
            self.assertIn('call CBE_fnc_CortexSetPhase',source(name))
            self.assertNotIn('_state set ["phase"',source(name))
        tick=source('cortexGroupTick')
        search=tick.split('case "SEARCH": {',1)[1].split('case "REGROUP": {',1)[0]
        for proof in ('CortexSearchMoveOwned','_searchActor distance2D _goal > 2','(_goal select 2)) > 1.5','SEARCH_TIMEOUT','NO_SEARCH_ACTORS'):
            self.assertIn(proof,search)
        self.assertNotIn('distance2D _searchPos > 15',search)
        self.assertIn('serverTime > _searchDeadline',search)
        locality=source('cortexLocality')
        self.assertIn('_adopted set ["searchMoveReceipts",_resumedSearchReceipts]',locality)
        self.assertIn('_adopted set ["searchDeadline",_deadline]',locality)
        self.assertIn('getOrDefault ["searchDeadline",_startedAt+_duration]',source('cortexCheckpoint'))

        for reason in ['VISIBLE_CONTACT','AREA_REPORT','KNOWN_CONTACT','CONTACT_LOST',
                       'NO_SEARCH_TEAM','SEARCH_TEAM_SENT','SEARCH_COMPLETE',
                       'WITHDRAWAL_COMPLETE','WITHDRAWAL_TIMEOUT']:
            self.assertIn(reason,tick)

    def test_manoeuvres_share_one_bounded_avenue_selector(self):
        selector=source('cortexSelectAvenue')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        advance=source('cortexAdvanceStart')
        flank=source('cortexFlankStart')
        retreat=source('cortexRetreat')
        self.assertIn('class CortexSelectAvenue',functions)
        for marker in ['(count _candidates) min 8','forEach [0.25,0.5,0.75]',
                       '[_threatASL,_sampleASL,objNull,"COVER",_threatObject] call CBE_fnc_CortexCoverScreened',
                       'private _surfaceUp=(surfaceNormal _sample) select 2',
                       'private _terrainASL=getTerrainHeightASL _sample',
                       'if (surfaceIsWater _sample || {_surfaceUp < _sampleMinimumUp} || {_sampleGrade > _sampleMaximumGrade})',
                       '+2*(_terrainPenalty/(_terrainSamples max 1))',
                       '"COVER",_threatObject]','"CONCEALMENT",_threatObject]','_lateral < 30',
                       '_pointSide*_startSide < 0','(ceil (_legLength/20)) max 3',
                       'min 24','private _sampleGrade=abs (_terrainASL-_previousTerrainASL)/_sampleDistance',
                       '-70*(_hardScreen/(_screenSamples max 1))',
                       '-25*(_concealed/(_screenSamples max 1))']:
            self.assertIn(marker,selector)
        self.assertLess(selector.index('private _safetySamples='),selector.index('surfaceIsWater _sample'))
        self.assertLess(selector.index('surfaceIsWater _sample'),selector.index('forEach [0.25,0.5,0.75]'))
        for vehicle_marker in ['"VEHICLE"','private _minimumSurfaceUp=[0.55,0.8]',
                               'private _maximumGrade=[1.25,0.7]',
                               'if (_onRoad) then {0.68}','if (_onRoad) then {0.9}',
                               'isOnRoad _sample','-30*(_roadSamples/(_terrainSamples max 1))']:
            self.assertIn(vehicle_marker,selector)
        self.assertNotIn('nearObjects',selector)
        self.assertNotIn('nearestTerrainObjects',selector)
        self.assertIn('call CBE_fnc_CortexSelectAvenue',advance)
        self.assertIn('forEach [90,-90,55,-55]',advance)
        self.assertIn('call CBE_fnc_CortexSelectAvenue',flank)
        self.assertIn('call CBE_fnc_CortexSelectAvenue',retreat)
        self.assertIn('forEach [0, 30, -30, 60, -60]',retreat)
        flank_step=source('cortexFlankStep')
        self.assertIn('forEach [0.65,0.35,0]',flank_step)
        self.assertIn('forEach [0,-15,15,-30,30]',flank_step)
        self.assertIn('[_centroid,_assaultCandidates,_enemyPos] call CBE_fnc_CortexSelectAvenue',flank_step)

    def test_multi_manoeuvre_audit_requires_real_drills_and_contact(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        for marker in ['private _drillSeen=[false,false]',
                       'private _expectedDrill=["FLANK","ADVANCE"]',
                       '-both-tactical-drills-observed',
                       '([0,180] select _contact)',
                       '_drillSeen select _teamIndex']:
            self.assertIn(marker,qa)
        self.assertIn('_enemyGroup setCombatMode "YELLOW"',qa)
        self.assertIn('_enemy setUnitPos "UP"',qa)
        self.assertIn('for "_index" from 0 to 5 do',qa)
        self.assertIn('private _enemies=[]',qa)

    def test_multi_manoeuvre_audit_uses_real_relief_outside_vr(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        for marker in ['private _terrainOrigin=[2200,1100,0]',
                       'private _terrainHeading=0',
                       'private _terrainScenarioReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-80,0,80,160]',
                       'for "_along" from 0 to 360 step 30',
                       'private _normal=(surfaceNormal _sample) select 2',
                       '_normal < 0.55',
                       '_grade > 0.7',
                       '_relief >= 15 && {_relief <= 120}',
                       '_x-2200,_y-1100] call _terrainWorld',
                       '-terrain-scenario',
                       'call _terrainPosition']:
            self.assertIn(marker,qa)
        self.assertIn('_enemies findIf {_leader knowsAbout _x >= 1}',qa)
        self.assertIn('_actors+_enemies',qa)
        self.assertIn('_x setDir (_x getDir _enemy)',qa)
        self.assertIn('_x setDir (_x getDir _opponent)',qa)
        self.assertIn('if (_contact && {_mode == "BOUND"}) then {',qa)
        self.assertLess(qa.index('[_prefix+"-natural-contact"'),
                        qa.index('private _wp=_x addWaypoint'))

    def test_coordinated_audit_rotates_full_platoon_geometry_onto_real_terrain(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for marker in ['private _terrainHeading=0',
                       'private _terrainScenarioReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-220,-110,0,110,220]',
                       'for "_along" from -120 to 650 step 35',
                       '_normal < 0.55',
                       '_grade > 0.7',
                       '_relief >= 20 && {_relief <= 180}',
                       'COORD-terrain-scenario',
                       '_terrainForward vectorMultiply 100',
                       'vectorDotProduct _terrainRight']:
            self.assertIn(marker,qa)
        for position in ['[1500,1500] call _terrainPosition',
                         '[1500,1600] call _terrainPosition',
                         '[1400+_team*200+_i*3,1400] call _terrainPosition']:
            self.assertIn(position,qa)
        self.assertIn('_wall setDir _terrainHeading',qa)
        self.assertNotIn('vectorAdd [0,100,0]',qa)

    def test_bounding_advance_default_has_no_artificial_contact_wait(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text()
        spec=source('cortexTuningSpec')
        advance=source('cortexAdvanceStart')
        self.assertIn('["CBE_AIPass_Advance_MinContactSeconds", 0]',config)
        self.assertIn('["CBE_AIPass_Advance_Cooldown", 20]',config)
        self.assertIn('"CBE_AIPass_Advance_MinContactSeconds", "Advance contact delay"',spec)
        self.assertIn('"SLIDER", [0,300,0], 0, "MOVEMENT", "NEXT_OPERATION"]',spec)
        self.assertIn('"CBE_AIPass_Advance_Cooldown", "Advance repeat delay"',spec)
        self.assertIn('"SLIDER", [0,180,0], 20, "MOVEMENT", "NEXT_OPERATION"]',spec)
        self.assertIn('getVariable ["CBE_AIPass_Advance_MinContactSeconds", 0]',advance)

    def test_bounding_advance_uses_fresh_contact_when_no_waypoint_remains(self):
        advance=source('cortexAdvanceStart')
        step=source('cortexFlankStep')
        self.assertIn('private _hasAuthoredObjective = _index < count waypoints _group',advance)
        self.assertIn('if (_hasAuthoredObjective && {',advance)
        self.assertIn('!(waypointType [_group, _index] in ["MOVE", "SAD", "DESTROY"])',advance)
        self.assertIn('if (!_hasAuthoredObjective && {((_enemies select 0) select 2) > 10})',advance)
        self.assertIn('(_enemies select 0) select 1',advance)
        self.assertNotIn('if (_index >= count waypoints _group) exitWith {false}',advance)
        self.assertIn('private _waypointSnapshot = []',step)
        self.assertIn('if (_waypointIndex < count waypoints _group) then {',step)
        self.assertIn('["boundWaypoint",_waypointSnapshot]',step)

    def test_advance_uses_its_own_shorter_repeat_cooldown(self):
        end=source('cortexFlankEnd')
        self.assertIn('case "ADVANCE": {"CBE_AIPass_Advance_Cooldown"}',end)
        self.assertIn('case "ADVANCE": {20}',end)
        self.assertIn('default {"CBE_AIPass_Flank_Cooldown"}',end)
        self.assertIn('default {90}',end)
        self.assertIn('getVariable [_cooldownName, _cooldownDefault]',end)

    def test_coordinated_audit_ends_after_terminal_element_failures(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for marker in ['private _movementRoleObserved=false',
                       'private _retiredSince=-1',
                       'in ["STALLED","TIME_LIMIT","NOT_READY","RECOVERY_FAILED"]',
                       'COORD-tactical-role-observed',
                       'COORD-movement-window-terminated']:
            self.assertIn(marker,qa)

    def test_previous_holders_cannot_follow_over_replacement_drill(self):
        text = source('cortexGroupTick')
        self.assertIn('private _holderDrill=_state getOrDefault ["drill",createHashMap]', text)
        self.assertIn('(_holderDrill getOrDefault ["operationGeneration",-1]) == _holderGeneration', text)
        self.assertIn('(_holderDrill getOrDefault ["ownerEpoch",-1]) == _holderEpoch', text)
        self.assertIn('!(_x in _ownedMovers)', text)
        self.assertIn('if (_holders isNotEqualTo [] && {!(_state getOrDefault ["assaulting",false])})', text)
        self.assertLess(text.index('!(_x in _ownedMovers)'), text.index('_recallIssued pushBack _x'))

    def test_coordinated_report_fire_requires_live_matching_lease(self):
        text = source('cortexFireControl')
        for guard in ['(_role select 0) == (_lease select 0)', 'serverTime < (_lease select 2)',
                      '"supportToken"', 'CBE_AIPass_CoordinatedAssault_Enable',
                      '_enemies isEqualTo [] && {_reported isEqualTo []}',
                      'CBE_fnc_CortexLineOfFireClear']:
            self.assertIn(guard, text)
        self.assertNotIn(' reveal ', text)
        self.assertIn('private _suppressPos = +_reported;', text)
        suppress=text.split('private _suppressPos = +_reported;',1)[1]
        self.assertLess(suppress.index('_drill getOrDefault ["enemyPos"'),suppress.index('private _hiddenIndex'))
        self.assertIn('if (_suppressPos isEqualTo []) then {',suppress.split('private _hiddenIndex',1)[0])
        self.assertIn('unitReady _unit && {!(_unit in _closeThreatActors)} && {!(_unit call _held)}',suppress)
        self.assertIn('!isNull _target && {!(_unit in _closeThreatActors)} && {!(_unit call _held)}',text)
        self.assertLess(text.index('_closeThreatActors pushBack _unit'),text.index('if (assignedTarget _unit != _closest'))

    def test_moving_bounds_preserve_native_combat_behaviour(self):
        step = source("cortexFlankStep")
        for capability in ['TARGET','AUTOTARGET','AUTOCOMBAT','PATH']:
            self.assertNotIn(f'_unit disableAI "{capability}"',step)
        self.assertNotIn('_unit setCombatBehaviour "AWARE"',step)
        self.assertNotIn('_unit setDestination',step)
        self.assertIn('"restoreCombatBehaviours"', source("cortexCheckpoint"))
        for name in ["cortexFlankStep", "cortexFlankEnd", "cortexLocality"]:
            self.assertIn('behaviour _unit == _owned', source(name))
            self.assertIn('_unit setCombatBehaviour _previous', source(name))

    def test_native_attack_is_not_fought_before_physical_no_progress(self):
        step = source("cortexFlankStep")
        self.assertNotIn('currentCommand _unit == "ATTACK"', step)
        self.assertEqual(step.count('_unit doTarget objNull'),1)
        self.assertIn('assignedTarget _unit == (_fireTarget select 2)',step)
        self.assertIn('(_fireTarget select 0) == _group',step)
        self.assertIn('(_fireTarget select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])',step)
        retry=step.split('private _retry = _retries select _forEachIndex;',1)[1].split('if (_now-(_last select 3) > _timeout',1)[0]
        self.assertIn('_now-(_last select 3) >= 8',retry)
        self.assertIn('(_retry select 0) < 1',retry)
        self.assertEqual(0,retry.count('_unit doMove'))
        self.assertIn('_moveActions pushBack ["RETRY",_unit,_forEachIndex,+_pose]',retry)
        commit=step.split('private _moveCommitted=false;',1)[1].split('if (!_moveCommitted)',1)[0]
        self.assertEqual(1,commit.count('_unit doMove'))
        self.assertIn('isNotEqualTo _entryMoveRetries',commit)
        self.assertLess(commit.index('_unit doMove'),commit.index('_retry set [0,'))
        self.assertNotIn('setDestination',retry+commit)

    def test_active_support_assignment_is_adopted_by_the_new_local_owner(self):
        locality=source('cortexLocality')
        apply=source('cortexSupportApply')
        for marker in ['CBE_AIPass_SupportLease','CBE_AIPass_SupportStatus',
                       'serverTime < (_supportLease select 2)','["adopt",true]',
                       'call CBE_fnc_CortexSupportApply']:
            self.assertIn(marker,locality)
        self.assertIn('_job getOrDefault ["adopt",false]',apply)
        self.assertIn('_state set ["supportBoundSequence",-1]',apply)
        self.assertIn('_state set ["arrivedAt"',apply)

    def test_tactical_bounds_use_one_native_destination_without_disabling_combat(self):
        step = source("cortexFlankStep")
        body=step.split('*/',1)[1]
        issue=step.split('private _issue = {',1)[1].split('private _result =',1)[0]
        self.assertEqual(1,issue.count('_unit doMove _spot'))
        self.assertNotIn('setDestination [',body)
        self.assertEqual(body.count('doTarget objNull'),1)
        self.assertIn('CBE_Cortex_FireTarget',issue)
        self.assertLess(issue.index('_unit doTarget objNull'),issue.index('_unit doMove _spot'))
        for capability in ['TARGET','AUTOTARGET','AUTOCOMBAT','PATH']:
            self.assertNotIn(f'_unit disableAI "{capability}"',step)

    def test_suppressive_fire_talks_inside_squad_and_desynchronises_squads(self):
        fire = source("cortexFireControl")
        for token in ['CBE_AIPass_NextSuppress', '0.25 + random 2',
                      'CBE_AIPass_SuppressCursor', '_now + 2.5 + random 1.5']:
            self.assertIn(token, fire)
        suppression = fire.split('// Disciplined suppression', 1)[1]
        self.assertIn('if (_issued || {_geometryChecks >= 3}) exitWith {}', suppression)
        self.assertIn('_cursor + 1', suppression)
        active=suppression.split('private _active =',1)[1].split('private _nextWindow =',1)[0]
        self.assertIn('toUpperANSI currentCommand _x == "SUPPRESS"',active)
        self.assertIn('CBE_AIPass_LastSuppress',active)
        self.assertIn('count _members',active)
        candidate=suppression.split('private _unit = _members select',1)[1].split('private _weapon =',1)[0]
        self.assertIn('toUpperANSI currentCommand _unit != "SUPPRESS"',candidate)

        self.assertGreaterEqual(fire.count('_group setVariable ["CBE_AIPass_NextSuppress",nil]'), 2)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runFireControl.sqf').read_text()
        for token in ['FIRE-talking-guns-rotated-suppressors',
                      'FIRE-squads-not-global-volley',
                      'FIRE-multi-squad-actual-suppression',
                      'CBE_CortexQA_SuppressOrders',
                      'CBE_CortexQA_SuppressShots']:
            self.assertIn(token,qa)
        self.assertIn('Land_CncWall4_F',qa)
        self.assertIn('_suppressionEnemy setPosATL [2100,1460,0]',qa)
        self.assertIn('_x doTarget objNull; _x doWatch objNull',qa)
        self.assertNotIn('call CBE_fnc_CortexFireControl',qa)

    def test_queued_danger_smoke_rechecks_strict_reservation_before_release(self):
        grenade=source('cortexThrowGrenade')
        release=grenade.split('private _release = {',1)[1]
        reservation=release.index('_dangerInvalid=[_unit] call CBE_fnc_CortexActorMoveReserved;')
        cancel=release.index('if (_dangerInvalid) exitWith {["ACTOR_RESERVED"] call _cancel};')
        self.assertLess(reservation,cancel)
        self.assertLess(cancel,release.index('_unit doWatch _towards;'))
        self.assertLess(cancel,release.index('forceWeaponFire'))
        self.assertNotIn('_reservation param [2,1e12,[0]]',release)
        self.assertIn('[_retry,+_this,0.25] call CBA_fnc_waitAndExecute;',release)

    def test_suppression_sentinel_does_not_improve_ranking_or_evasion(self):
        self.assertIn('damage _x + ((getSuppression _x) max 0 min 1)',source('cortexAntiArmour'))
        self.assertIn('(1 - 0.5 * ((getSuppression _unit) max 0 min 1))',source('cortexGrenadeCheck'))
        smoke=source('dangerSmokeStep')
        self.assertIn('[-((getSuppression _x) max 0 min 1),random 1,_x]',smoke)
        availability=smoke.split('private _actorAvailable={',1)[1].split('private _members=',1)[0]
        self.assertIn('!([_actor] call CBE_fnc_CortexActorMoveReserved)',availability)
        self.assertNotIn('_reservation param',availability)
        for skill in (0,0.5,1):
            baseline=0.5+0.5*skill
            for suppression in (-1,0,0.5,1,3):
                probability=baseline*(1-0.5*min(1,max(0,suppression)))
                self.assertGreaterEqual(probability,0)
                self.assertLessEqual(probability,baseline)

    def test_morale_suppression_sentinel_cannot_become_negative_pressure(self):
        morale=source('cortexMorale')
        self.assertIn('_suppression + ((getSuppression _x) max 0 min 1)',morale)
        self.assertNotIn('_suppression + getSuppression _x',morale)
        self.assertIn('0.2 * _suppression',morale)
        flank=source('cortexFlankStart')
        self.assertIn('private _onFoot = _strengthFoot select',flank)
        self.assertIn('if (count _strengthFoot /',flank)
        self.assertNotIn('if (count _onFoot /',flank)
        self.assertIn('if (count _onFoot < (missionNamespace getVariable ["CBE_AIPass_Flank_MinGroupSize", 6]))',flank)
        self.assertIn('private _fighters=_alive select {[_x] call CBE_fnc_CortexCombatEffective}',morale)
        self.assertIn('private _count = count _fighters',morale)
        self.assertIn('CBE_AIPass_PeakSize", _livingCount]) max _livingCount',morale)
        self.assertIn('} forEach _fighters;',morale)
        self.assertIn('!([_contactLeader] call CBE_fnc_CortexCombatEffective)',morale)
        self.assertNotIn('healQueue',morale)
        # Native disabled/unavailable is -1; out-of-range scripted pressure must not
        # invert or exceed the existing contribution. This is not an in-engine result.
        for value,expected in [(-1,0),(0,0),(0.5,0.1),(1,0.2),(3,0.2)]:
            self.assertAlmostEqual(0.2*min(1,max(0,value)),expected)

    def test_garrison_posture_recovery_and_repeat_require_distinct_real_bursts(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=qa.split('// Real incoming-fire posture test',1)[1].split('private _origins=_members',1)[0]
        for proof in ['GARRISON-duck-restores-prior-posture','unitPos _defender == _priorPosture',
                      'GARRISON-duck-repeat-real-fire', '> _secondShotBaseline',
                      '> _until', 'if (_secondDuck) then {']:
            self.assertIn(proof,case)
        self.assertLess(case.index('GARRISON-duck-restores-prior-posture'),case.index('_defender setUnitPos "UP";'))
        self.assertEqual(case.count('_attacker doFire _defender;'),2)

    def test_garrison_duck_live_case_uses_real_fire_and_replacement_input(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=qa.split('// Real incoming-fire posture test',1)[1].split('private _origins=_members',1)[0]
        for proof in ['addEventHandler ["FiredMan"','_attacker doFire _defender;',
                      'GARRISON-duck-real-fire','GARRISON-duck-preserves-new-stance',
                      'No real duck reaction; replacement case not exercised',
                      'allowDamage (_damagePolicies select _forEachIndex)']:
            self.assertIn(proof,case)
        self.assertNotIn('setSuppression',case)
        self.assertNotIn('setVariable ["CBE_AIPass_DuckUntil"',case)
        self.assertNotIn('setPosATL',case)
        self.assertLess(case.index('GARRISON-duck-real-fire'),case.index('_defender setUnitPos "UP";'))

    def test_garrison_duck_checks_live_building_transform_at_both_boundaries(self):
        duck=source('cortexGarrisonApplyLocal').split('private _duck = {',1)[1].split('CBE_AIPass_GarrisonHandlerIds',1)[0]
        event, delayed=duck.split('params ["_unit", "_until", "_priorStance",',1)
        self.assertIn('_duckTransform isNotEqualTo [getPosWorld _duckBuilding,vectorDir _duckBuilding,vectorUp _duckBuilding]',event)
        self.assertIn('isNull _duckBuilding',event)
        self.assertLess(event.index('private _duckTransform='),event.index('[["STANCE",_duckStance]]'))
        self.assertIn('_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]',delayed)
        self.assertIn('!isNull _building',delayed)
        self.assertLess(delayed.index('private _transform='),delayed.index('call CBE_fnc_CortexGarrisonSettings'))

    def test_garrison_duck_yields_to_reserved_and_native_tasks_at_both_boundaries(self):
        duck=source('cortexGarrisonApplyLocal').split('private _duck = {',1)[1].split('CBE_AIPass_GarrisonHandlerIds',1)[0]
        event, delayed=duck.split('params ["_unit", "_until", "_priorStance",',1)
        for section in (event,delayed):
            for guard in ('simulationEnabled _unit','isObjectHidden _unit','ace_medical_ai_healQueue','fleeing _unit'):
                self.assertIn(guard,section)
            self.assertIn('CBE_fnc_CortexActorMoveReserved',section)
            self.assertIn('objectParent _unit',section)
            self.assertIn('remoteControlled _unit',section)
            for task in ['"MOVE"','"FOLLOW"','"GET IN"','"HEAL"','"CARRY SOLDIER"','"ASSEMBLE"','"REPAIR"']:
                self.assertIn(task,section)
        self.assertIn('getVariable ["CBE_AIPass_Epoch",0]',event)
        self.assertIn('getVariable ["CBE_AIPass_Epoch",0]',delayed)

        apply=source('cortexGarrisonApplyLocal')
        self.assertEqual(apply.count('simulationEnabled _actor'),2)
        self.assertEqual(apply.count('!fleeing _actor'),2)
        self.assertEqual(apply.count('(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []'),2)
        self.assertNotIn('setVariable ["ace_medical_ai_healQueue"',apply)

    def test_garrison_duck_restores_immediate_stance_only_for_same_assignment(self):
        apply=source('cortexGarrisonApplyLocal')
        duck=apply.split('private _duck = {',1)[1].split('CBE_AIPass_GarrisonHandlerIds',1)[0]
        for proof in ['private _priorStance=unitPos _unit;', 'group _unit == _duckGroup',
                      'local _duckGroup', '== _duckGeneration', '== _duckEpoch',
                      'isEqualTo _duckAssignment', 'group _unit,"RECOVER"]',
                      '[_unit,_until,_priorStance,_duckGroup,_duckGeneration,_duckEpoch,_duckAssignment]']:
            self.assertIn(proof,duck)
        self.assertLess(duck.index('private _priorStance=unitPos _unit;'),duck.index('[["STANCE",_duckStance]]'))
        self.assertLess(duck.index('if (toUpperANSI _priorStance == "DOWN") exitWith {};'),duck.index('[["STANCE",_duckStance]]'))
        self.assertNotIn('_unit setUnitPos (_unit getVariable ["CBE_AIPass_GarrisonStance"',duck)
        adapter=source('cortexGarrisonSettings')
        for proof in ('CBE_Cortex_GarrisonDuckRestore','_duck select 0) != _issuer',
                      '_duck select 1) isNotEqualTo','toUpperANSI (unitPos _actor) != (_duck select 4)',
                      'serverTime >= (_duck select 2)+30','serverTime < (_duck select 2)',
                      '[["STANCE",_duck select 3]]','_transform isNotEqualTo [getPosWorld _building'):
            self.assertIn(proof,adapter)
        self.assertIn('if (!_mayDuck) exitWith {};',duck)
        brain=source('groupBrainStep')
        self.assertIn('_duckPending deleteAt 0',brain)
        self.assertIn('serverTime < (_duckReceipt select 2)+30',brain)
        self.assertIn('serverTime+(_until-time)',duck)
        self.assertIn('_duckQueue deleteAt _duckIndex',adapter)
        self.assertEqual(adapter.count('call _forgetDuckPending;'),3)
        self.assertIn('count _duckQueue <= 64',adapter)


    def test_suppression_reserve_rejection_has_live_positive_peers(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runFireControl.sqf').read_text()
        for proof in ['FIRE-reserve-starved-fixture-', 'count _rifleSpare == 1',
                      'count _grenadeSpare == 4', 'FIRE-launcher-reserves-do-not-qualify-rifle',
                      '_reserveStarved findIf {(_x getVariable ["CBE_AIPass_LastSuppress",-1]) >= 0} < 0']:
            self.assertIn(proof,qa)
        self.assertLess(qa.index('FIRE-multi-squad-actual-suppression'),qa.index('FIRE-launcher-reserves-do-not-qualify-rifle'))
        self.assertNotIn('call CBE_fnc_CortexFireControl',qa)

    def test_individual_hold_fire_is_exercised_beside_firing_peers(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runFireControl.sqf').read_text()
        for proof in ['private _heldShooter=_shooters select 3;',
                      '_heldShooter setUnitCombatMode "BLUE";',
                      'FIRE-individual-hold-fixture','FIRE-individual-hold-no-shots',
                      'FIRE-individual-hold-no-scripted-order',
                      '== _heldShotBaseline']:
            self.assertIn(proof,qa)
        self.assertLess(qa.index('_heldShooter setUnitCombatMode "BLUE";'),qa.index('FIRE-both-targets-actual-fire'))
        self.assertLess(qa.index('FIRE-both-targets-projectile-hits'),qa.index('FIRE-individual-hold-no-shots'))
        fire=source('cortexFireControl')
        self.assertLess(fire.index('unitCombatMode _x in ["YELLOW","RED"]'),fire.index('_unit doFire _closest'))

    def test_fire_audit_requires_projectiles_during_suppression_commands(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runFireControl.sqf').read_text()
        for proof in ['_shots pushBack [time,_weapon,_muzzle,_ammo,_magazine,_orderedAt,',
                      '_orderedAt >= 0', '_shotAt >= _orderedAt', '_shotAt <= _orderedAt+8',
                      '_weapon == primaryWeapon _unit', '_command == "SUPPRESS"',
                      '_readyGroups == 2 && {_groupsWithShots == 2}',
                      '(units _group) findIf {[_x] call _hasSuppressionShot} < 0']:
            self.assertIn(proof,qa)
        self.assertIn('if (count _shots > 200) then {_shots deleteAt 0}',qa)

    def test_fire_audit_releases_individual_never_fire_orders(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runFireControl.sqf').read_text()
        for actors, check in [('_shooters','FIRE-weapons-free-unit-modes'),
                              ('_suppressionShooters','FIRE-suppression-unit-modes')]:
            command='{_x setUnitCombatMode "RED"} forEach '+actors+';'
            self.assertLess(qa.index(command),qa.index(check))
            self.assertIn(actors+' findIf {unitCombatMode _x != "RED"} < 0',qa)
        self.assertLess(qa.index('FIRE-weapons-free-unit-modes'),qa.index('FIRE-both-targets-actual-fire'))
        self.assertLess(qa.index('FIRE-suppression-unit-modes'),qa.index('private _deadline=time+35'))

    def test_suppression_requires_the_loaded_primary_bullet_muzzle(self):
        suppression = source("cortexFireControl").split('// Disciplined suppression', 1)[1]
        boundary = suppression.index('_unit doSuppressiveFire _aimASL')
        for proof in ['currentMuzzle _unit', 'currentMagazine _unit',
                      '_unit ammo _muzzle', 'currentWeapon _unit == _weapon',
                      '_loaded > 0', '== "shotbullet"',
                      'weaponState _unit', '_weaponState param [6,1,[0]]',
                      'count _weaponState >= 7', 'finite _reload', '_reload == 0',
                      '(_weaponState select 0) == _weapon', '(_weaponState select 1) == _muzzle',
                      'compatibleMagazines [_weapon,_magazineMuzzle]',
                      '(magazinesAmmoFull _unit) select',
                      '!(_x select 2) && {(_x select 1) > 0}',
                      'getNumber (_ammo >> "hit") > 0',
                      'if (count _spare >= 2 && {_rounds >= 60}']:
            self.assertLess(suppression.index(proof), boundary)
        self.assertNotIn('selectWeapon', suppression)
        self.assertNotIn('_unit ammo _weapon', suppression)
        self.assertLess(suppression.index('if (_rifleReady) then'),suppression.index('compatibleMagazines [_weapon,_magazineMuzzle]'))
        self.assertLess(suppression.index('if (_rifleReady) then'),suppression.index('magazinesAmmoFull _unit'))
        sharing=source('cortexAmmoShare')
        self.assertIn('"this" in _muzzles',sharing)
        self.assertIn('_muzzles param [0,"this"]',sharing)
        self.assertIn('compatibleMagazines [_weapon,_mainMuzzle]',sharing)
        self.assertNotIn('compatibleMagazines (primaryWeapon _receiver)',sharing)
        self.assertLess(sharing.index('compatibleMagazines [_weapon,_mainMuzzle]'),sharing.index('magazinesAmmo _receiver'))
        self.assertIn('_rounds = _beforeRounds - _afterRounds',sharing)
        self.assertIn('_receiver addMagazine [_magazine, _rounds]',sharing)
        def count_spares(inventory,compatible):
            return sum(1 for name,rounds in inventory if name in compatible and rounds>0)
        rifle={'rifle_mag'}
        self.assertEqual(count_spares([('grenade',1),('grenade',1)],rifle),0)
        self.assertEqual(count_spares([('rifle_mag',7),('grenade',1)],rifle),1)
        self.assertEqual(count_spares([('grenade',1)]*4,rifle),0)
        self.assertEqual(count_spares([('rifle_mag',7)]*4,rifle),4)


    def test_native_canfire_uses_its_own_contact_and_existing_safe_suppression(self):
        fire = source("cortexFireControl")
        selected=fire.split('private _primaryBulletSelected = {',1)[1].split('private _eligible =',1)[0]
        for proof in ('weaponState _fireActor','(_selected select 0) == _primary','(_selected select 3)','"shotbullet"'):
            self.assertIn(proof,selected)
        for forbidden in ('selectWeapon','doTarget','doFire','setVariable'):
            self.assertNotIn(forbidden,selected)
        roster=fire[fire.index('private _eligible ='):fire.index('private _members =')]
        self.assertIn('[_x] call _primaryBulletSelected',roster)
        self.assertIn('!(getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"])',roster)
        self.assertIn('behaviour _x != "STEALTH"',roster)
        self.assertLess(fire.index('!(getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"])'),fire.index('_unit doTarget'))
        self.assertLess(fire.index('unitReady _unit'),fire.index('magazinesAmmoFull _unit'))
        self.assertLess(fire.index('unitReady _unit'),fire.index('_unit doSuppressiveFire'))
        suppression = fire.split('// Disciplined suppression', 1)[1]
        for token in ['getOrDefault ["dangerResponse",[]]',
                      '(_dangerResponse select 0) == "CANFIRE"',
                      'CBE_Danger_Generation',
                      '(_x select 3) > _assaultRange',
                      '(_x select 3) <= 500',
                      'CBE_Danger_ResponseEvent',
                      'count _dangerEvent in [6,7,8]',
                      'finite _eventUntil', '_now < _eventUntil',
                      '[_eventWitness] call CBE_fnc_CortexCombatEffective',
                      'local _eventWitness', 'group _eventWitness == _group',
                      '_eventWitness knowsAbout _eventTarget > 0',
                      '(_eventWitness targetKnowledge _eventTarget) param [7,false,[true]]',
                      '(_dangerEvent select 2) == (_dangerResponse select 2)',
                      '(_dangerEvent select 1) isEqualTo (_dangerResponse select 1)',
                      '(_x select 0) isEqualTo _eventTarget',
                      'getFriend (side _eventTarget) < 0.6']:
            self.assertIn(token,suppression)
        # The parity handoff must still use the existing bounded safety path rather than
        # manufacture target knowledge, direct fire, or a second worker.
        self.assertIn('call CBE_fnc_CortexLineOfFireClear',suppression)
        self.assertIn('_unit doSuppressiveFire _aimASL',suppression)
        self.assertNotIn('doTarget',suppression)
        self.assertNotIn('spawn',suppression)
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        finished=fsm.split('class Finished {',1)[1]
        self.assertIn('CBE_Danger_ResponseEvent"",nil',finished)
        self.assertIn('_generation == (_group getVariable',finished)

    def test_non_infantry_sources_keep_identity_at_observation_boundaries(self):
        for name, expected, rejected in [
            ("cortexSpotterFix", "getFriend (side _enemy)", "getFriend (side group _enemy)"),
            ("cortexHearingLocal", "getFriend (side _firer)", "getFriend (side group _firer)"),
            ("convoyCrewLocal", "getFriend (side _instigator)", "getFriend (side group _instigator)"),
        ]:
            text=source(name)
            self.assertIn(expected,text)
            self.assertNotIn(rejected,text)
        observer=source('cortexSpotterFix')
        body=observer.split('params [[',1)[1]
        for command in ('selectWeapon','doWatch','doMove','doTarget','doFire','setVariable'):
            self.assertNotIn(command,body)
        for gate in ('local _spotter','isPlayer _spotter','CBE_AIPass_Spotter',
                     'simulationEnabled _spotter','isObjectHidden _spotter','binocular _spotter == ""',
                     'CBE_fnc_CortexCanTransmit','_spotter targetKnowledge _enemy',
                     '_spotter knowsAbout _enemy < 1.5','time - (_knowledge select 2) > 5',
                     'checkVisibility','_spotter getHideFrom _enemy'):
            self.assertIn(gate,observer)
        self.assertNotIn(' selectWeapon ',source('cortexGroupTick'))

    def test_danger_recycle_never_substitutes_exact_hostile_position(self):
        recycle=source("dangerEngineRecycle")
        self.assertIn('private _position=_actor getHideFrom _source',recycle)
        self.assertIn('if (_position isEqualTo [0,0,0]) exitWith {[]}',recycle)
        self.assertNotIn('_position=getPosATL _source',recycle)
        self.assertIn('getPosATL _actor',recycle)
        self.assertIn('private _cycle=_record param [4,0,[0]]',recycle)
        self.assertNotIn('distance2D _source',recycle)
        self.assertLess(recycle.index('if (!_follow) exitWith'),recycle.index('private _position=_actor getHideFrom _source'))
        self.assertLess(recycle.index('private _position=_actor getHideFrom _source'),recycle.index('_actor distance2D _position >= 35'))
        for invalid in ('!finite _cause','_cause != floor _cause','!finite _cycle',
                        '_cycle != floor _cycle','_cycle < 0','!finite _x'):
            self.assertIn(invalid,recycle)
        # Hidden movement must not change continuation while the same belief remains.
        def follows(believed_distance,actual_distance,knowledge=True):
            return believed_distance<35 and knowledge
        for belief,expected in ((20,True),(34.9,True),(35,False),(80,False)):
            self.assertEqual(follows(belief,5),expected)
            self.assertEqual(follows(belief,500),expected)
        self.assertFalse(follows(20,5,False))
        self.assertIn('if (_cycle >= _maxCycles) exitWith',recycle)
        self.assertIn('[_cause,+_position,time+1.5,_source,_cycle+1]',recycle)

    def test_group_ticks_use_low_cost_zero_mean_jitter(self):
        tick=source("cortexGroupTick")
        self.assertIn('private _cadence = _delay / _reaction;',tick)
        self.assertIn('(_cadence + random 0.7 - 0.35) max 0.5',tick)
        self.assertIn('adding no scheduler job or polling loop',tick)
        self.assertNotIn('CBE_fnc_CortexQueueJob, createHashMapFromArray [["group", _group]',tick)

    def test_recovery_qa_measures_continuation_after_separation(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        event=qa.split('if (!_observedRecovery && {_blockedActor in _recoveryActors}) then {')[1].split('};')[0]
        self.assertIn('getPosATL _x', event)
        self.assertIn('_restOrigins =', event)
        self.assertIn('-continued-with-blocked-actor', qa)
        self.assertIn('-physical-rejoin', qa)

    def test_rejoining_actors_keep_movement_ownership_during_halts(self):
        for name in ['cortexFireControl', 'cortexAntiArmour']:
            text = source(name)
            self.assertIn('getOrDefault ["recovery",[]]', text)
            self.assertIn('!(_x in _recovering)', text)
        text = source('cortexFireControl')
        self.assertIn('(_drill getOrDefault ["stage",""]) == "START"', text)
        self.assertIn('(_drill get "teams") param [_drill getOrDefault ["teamTurn",0],[]]', text)
        self.assertIn('(_drill getOrDefault ["stage",""]) == "MOVE"', text)
        self.assertIn('CBE_fnc_CortexCombatEffective', text)

    def test_stragglers_remain_tracked_after_live_element_quorum(self):
        step = source('cortexFlankStep')
        self.assertIn('count (_units - _blocked) >= 2', step)
        self.assertIn('ceil (count _originalElement * 0.6)', step)
        self.assertIn('_teams select (_drill getOrDefault ["teamTurn",0])', step)
        self.assertIn('_teams findIf {_actor in _x}', step)
        self.assertIn('(_teams select _teamIndex) select {_x in _main}', step)
        self.assertIn('ceil (count _units * 0.6)', step)
        self.assertIn('_attempts < 1', step)
        self.assertIn('CBE_fnc_RecoveryStep', step)
        self.assertIn('_units = _units - _recovering', step)
        end = source('cortexFlankEnd')
        self.assertIn('_reason = "PARTIAL"', end)
        self.assertIn('forEach (_members-_stragglers)', end)
        self.assertIn('_stragglers call _returnElement', end)
        self.assertIn('!_returnScoped || {_x != _returnLeader}',end)

    def test_manoeuvre_elements_reinforce_and_rebalance_after_casualties(self):
        step=source('cortexFlankStep')
        for marker in ['private _fitSquad=', 'private _rankCandidates=',
                       'CBE_Cortex_DrillReinforcements', 'TEAM_1_REBALANCE',
                       'TEAM_2_REBALANCE', '"START","CASUALTY_REINFORCEMENT"] call CBE_fnc_CortexDrillSetStage',
                       'private _ownedPathUnits=']:
            self.assertIn(marker,step)
        self.assertIn('_x checkAIFeature "PATH" || {_x in _ownedPathUnits}',step)
        self.assertNotIn('addEventHandler ["Killed"',step)
        capture=step.split('private _captureBound={',1)[1].split('private _selectRelief={',1)[0]
        for proof in ('_oldMovers select [0,64]','_savedSpots pushBack [_actor,+_spot]',
                      'serverTime+(_row select 1)-time','serverTime+(_row select 3)-time',
                      '_savedRetries pushBack [_actor,_retry select 0]'):
            self.assertIn(proof,capture)
        for forbidden in ('boundDeadline','boundQuorumUntil','doMove','setPos'):
            self.assertNotIn(forbidden,capture)
        self.assertEqual(step.count('call _captureBound;'),3)
        self.assertIn('(_resumeSpots select {(_x select 0) in _units}) apply',step)
        self.assertIn('forEach [0,1,-1,2,-2]',step)
        self.assertIn('(_spots+_reservedSpots) findIf {_candidate distance2D _x < 2}',step)
        self.assertIn('if (!_slotsAvailable) exitWith {_result="NO_REPLACEMENT_SPACE" call _end}',step)

        continuation=step.split('private _continueNative=',1)[1].split('if (!_continueNative)',1)[0]
        for proof in ('resumeNativeMoves','currentCommand _unit == "MOVE"',
                      '_nativeGoal vectorDistance _spot <= 0.25','call _nativeCommandAvailable'):
            self.assertIn(proof,continuation)

        self.assertIn('["desiredStrength",count _element]',source('cortexFlankStart'))
        self.assertIn('["teamSizes",[count _element,count _coverElement]]',source('cortexAdvanceStart'))
        self.assertIn('["teamSizes",[count _first,count _second]]',source('cortexSupportBoundStart'))
        issue=step.split('private _issue = {',1)[1].split('private _issueEpoch=',1)[0]
        for proof in ('["CROSS_FAR","CONSOLIDATE"]','_armedMovers < _minimumMovers',
                      '_coverCandidates findIf','FIRE_CAPACITY_LOST'):
            self.assertIn(proof,issue)
        self.assertIn('if (_teams isEqualTo []) then {(_fitSquad-_units)-_recovering} else {_fit-_units}',issue)
        pre_issue=step.split('private _issue = {',1)[0]
        pre_relief,relief_tail=pre_issue.split('private _selectRelief={',1)
        relief,rank_tail=relief_tail.split('private _rankCandidates=',1)
        rank,post_rank=rank_tail.split('private _units=[];',1)
        self.assertNotIn('CortexPrimaryAmmoAvailable',pre_relief+post_rank)
        self.assertEqual(rank.count('CortexPrimaryAmmoAvailable'),1)
        self.assertIn('if (count _units < _desiredStrength) then {[_fitSquad-_units] call _rankCandidates} else {[]}',post_rank)
        self.assertIn('if (_needsRefill) then {[_fitSquad-_assigned] call _rankCandidates} else {[]}',post_rank)
        self.assertEqual(relief.count('CortexPrimaryAmmoAvailable'),1)
        self.assertLess(relief.index('count _donors <= _keep'),relief.index('CortexPrimaryAmmoAvailable'))
        self.assertIn('_result="FIRE_CAPACITY_LOST" call _end',issue)
        self.assertNotIn('if (!_support &&',issue)
        support=source('cortexSupportBoundStart')
        self.assertIn('simulationEnabled _x',support)
        self.assertIn('!isObjectHidden _x',support)
        self.assertNotIn('removeMagazine',issue)
        self.assertNotIn('reload ',issue)
        def may_bound(support,kind,movers,minimum,cover):
            return kind in ('CROSS_FAR','CONSOLIDATE') or (movers>=minimum and cover)
        self.assertTrue(may_bound(False,'BOUND',1,1,True))
        self.assertFalse(may_bound(False,'BOUND',1,2,True))
        self.assertFalse(may_bound(False,'ASSAULT',2,2,False))
        self.assertTrue(may_bound(False,'CROSS_FAR',0,2,False))
        self.assertTrue(may_bound(False,'CONSOLIDATE',0,2,False))
        self.assertFalse(may_bound(True,'BOUND',0,2,False))
        self.assertTrue(may_bound(True,'BOUND',2,2,True))
        # A separated but armed actor cannot supply the missing cover role.
        fit_squad={'m1','m2','late','cover'}
        movers={'m1','m2'}
        recovering={'late'}
        cover_candidates=fit_squad-movers-recovering
        self.assertEqual(cover_candidates,{'cover'})
        self.assertFalse(may_bound(False,'BOUND',2,2,bool(cover_candidates & {'late'})))
        self.assertTrue(may_bound(False,'BOUND',2,2,bool(cover_candidates & {'cover'})))


    def test_coordinated_bound_team_contract_matches_server_reservation(self):
        start=source('cortexSupportBoundStart')
        self.assertIn('private _remaining=+_fit;',start)
        self.assertIn('_group getVariable ["CBE_CombatPairs",[]]',start)
        self.assertIn('(_pairs select [0,16])',start)
        self.assertIn('_x findIf {!(_x in _remaining)} < 0',start)
        self.assertIn('(_x select 0) != (_x select 1)',start)
        self.assertIn('_chunks pushBack +_x',start)
        self.assertIn('if (!_reconstructing) then {',start)
        self.assertIn('for "_capacity" from 2 to 0 step -1',start)
        self.assertIn('CortexPrimaryAmmoAvailable',start)
        self.assertIn('_remaining=_remaining-_x;',start)
        self.assertIn('} forEach _remaining;',start)
        self.assertIn('private _swap=_first;_first=_second;_second=_swap;',start)
        self.assertNotIn('(_forEachIndex mod 2)',start)
        self.assertIn('count _first < 2 || {count _second < 1}',start)
        self.assertNotIn('private _riflemen=',start)
        self.assertNotIn('CortexUnitRole',start)
        def allocate(chunks,armed):
            teams=[[],[]]; counts=[0,0]
            ranked=[(chunk,sum(a in armed for a in chunk)) for chunk in chunks]
            for capacity in (2,1,0):
                for chunk,n in ranked:
                    if n != capacity: continue
                    team=int(len(teams[0]) > len(teams[1])) if capacity == 0 else int((counts[0],len(teams[0])) > (counts[1],len(teams[1])))
                    teams[team].extend(chunk); counts[team]+=n
            if len(teams[0]) < len(teams[1]): teams.reverse()
            return teams
        teams=allocate([[0,1],[2,3],[4,5]],{0,1,4,5})
        self.assertEqual(sorted(sum(teams,[])),list(range(6)))
        self.assertTrue(all(sum(a in {0,1,4,5} for a in t)==2 for t in teams))
        for pair in ([0,1],[2,3],[4,5]):
            self.assertTrue(any(set(pair)<=set(t) for t in teams))
        self.assertEqual(allocate([[0,1],[2]],{0,1,2}),[[0,1],[2]])
        dry_heavy=allocate([[0,1],[2]]+[[n] for n in range(3,12)],{0,1,2})
        self.assertEqual(sorted(sum(dry_heavy,[])),list(range(12)))
        self.assertLessEqual(abs(len(dry_heavy[0])-len(dry_heavy[1])),1)
        self.assertTrue(any({0,1}<=set(t) for t in dry_heavy))
        self.assertIn('if (_capacity == 0) then {count _first > count _second}',start)


        maintain=source('cortexSupportMaintain')
        self.assertIn('private _started=[_group,_state,_role] call CBE_fnc_CortexSupportBoundStart',maintain)
        self.assertIn('[_token,_role select 1,"NOT_READY"]',maintain)
        self.assertIn('_state set ["supportBoundSequence",_role select 1]',maintain)

    def test_wait_diagnostics_explain_coordinated_failures_and_flare_modes(self):
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for marker in ['cortex-coordination-health','recordedBoundFailures=',
                       'boundFailuresByToken','CBE_Cortex_SupportBoundResult',
                       'CBE_Cortex_SupportAbort','groupSpeed=%8',
                       'withdrawal=[status,travel,replans]=%16',
                       'reactiveFlares=%8 attackRunFlares=%9',
                       'CBE_Cortex_AttackRunFlares_Enable']:
            self.assertIn(marker,diagnostic)

    def test_bound_retry_is_finite_and_does_not_fabricate_progress(self):
        text = source('cortexFlankStep')
        retry = text.split('private _retry = _retries select _forEachIndex;')[1].split('if (_now-(_last select 3) > _timeout')[0]
        self.assertIn('(_retry select 0) < 1', retry)
        self.assertIn('_now-(_retry select 1) >= 8', retry)
        self.assertIn('checkAIFeature "PATH"', retry)
        self.assertNotIn('_last set', retry)
        self.assertNotIn('setPos', retry)
        self.assertNotIn('_arrived = true', retry)

    def test_anti_armour_respects_movement_and_holding_ownership(self):
        text = source('cortexAntiArmour')
        self.assertIn('!(_x in _moving)', text)
        self.assertIn('getVariable ["CBE_Cortex_ActorMove",[]]',text)
        self.assertIn('!([_actor] call CBE_fnc_CortexActorMoveReserved)',text)
        roster=text.split('private _gunners =',1)[1].split('if (_gunners findIf',1)[0]
        self.assertNotIn('count _actorMove',roster)
        self.assertIn('!(_actor in _protectedParticipants)',text)
        for guard in ('["CLEAR","MEDICAL_AID","WITHDRAW"]','getOrDefault ["ownerEpoch",-1]',
                      '(_drill get "teams") param [_drill getOrDefault ["teamTurn",0],[]]'):
            self.assertIn(guard,text)
        self.assertIn('CBE_fnc_CortexCombatEffective', text)
        available=text.split('private _actorAvailable={',1)[1].split('private _now =',1)[0]
        for guard in ('_actor checkAIFeature "FIREWEAPON"','ace_medical_ai_healQueue',
                      'toUpperANSI currentCommand _actor != "MOVE"','abs (speed _actor) < 0.5',
                      'getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]'):
            self.assertIn(guard,available)
        self.assertGreaterEqual(text.count('[_gunner] call _actorAvailable'),3)
        rear=text.split('private _rearActors=',1)[1].split('// Holding/clearing owns the destination',1)[0]
        for proof in ('count _rearActors > 64','_otherSide == civilian','getFriend _otherSide >= 0.6',
                      'captive _x','ace_captives_isSurrendering','ace_captives_isHandcuffed'):
            self.assertIn(proof,rear)
        self.assertEqual(text.count('nearEntities ["CAManBase",6]'),1)
        # Protect allies across sides and captives, while retaining the rear-half-plane veto.
        def blocked(actor,friendship,civilian,captive,alive,along):
            return not actor and alive and (friendship>=0.6 or civilian or captive) and along<0
        for args,expected in [((False,1,False,False,True,-2),True),
                              ((False,0,True,False,True,-2),True),
                              ((False,0,False,True,True,-2),True),
                              ((False,0,False,False,True,-2),False),
                              ((False,1,False,False,True,2),False),
                              ((True,1,False,False,True,-2),False)]:
            self.assertEqual(blocked(*args),expected)
        blocked = text.split('// Holding/clearing owns the destination')[1]
        for guard in ['checkAIFeature "PATH"', 'checkAIFeature "MOVE"',
                      '_gunner in (_drill getOrDefault ["units",[]])',
                      'CBE_AIPass_Garrison', 'CBE_AIPass_Defend', 'CBE_AIPass_ClearBuilding']:
            self.assertLess(blocked.index(guard), blocked.index('_gunner doMove'))
        self.assertIn('getOrDefault ["antiArmourRelocation",[]]',text)
        self.assertIn('expectedDestination _relocating',text)
        self.assertIn('setVariable ["CBE_Cortex_ActorMove",["ANTI_ARMOUR"',text)
        self.assertIn('_state set ["antiArmourRelocation"',text)
        support=source('cortexSupportBoundStart')
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',support)
        self.assertNotIn('count _actorMove != 3',support)
        for cleanup in [source('cortexRestoreCalm'),source('cortexLocality')]:
            self.assertIn('setVariable ["CBE_Cortex_ActorMove",nil]',cleanup)

    def test_calm_ends_drill_before_discarding_restoration_checkpoint(self):
        text = source('cortexRestoreCalm')
        end = text.index('[_group,_state,"CALM"] call CBE_fnc_CortexFlankEnd')
        self.assertLess(end, text.index('call CBE_fnc_CortexGroupMoveClear'))
        self.assertLess(end, text.index('setVariable ["CBE_AIPass_Checkpoint", [], true]'))
        cleanup = source('cortexFlankEnd')
        self.assertIn('_unit enableAI _feature', cleanup)
        self.assertIn('_state deleteAt "drill"', cleanup)

    def test_cortex_stop_does_not_recall_external_groups_from_delayed_jobs(self):
        stop=source('cortexStop')
        selection=stop.split('[_x,true,\"CORTEX_STOPPED\"] call CBE_fnc_CortexReleaseGroup',1)[0]
        self.assertIn('(_x getVariable [\"CBE_Cortex_ClearHold\",[]]) isNotEqualTo []',selection)
        self.assertIn('private _canRestoreGroup=local _group && {[_group,false,false,true] call CBE_fnc_CortexIsEligible};',stop)
        self.assertIn('if (_canRestoreGroup && {!isNull (_group getVariable ["CBE_AIPass_RegroupHost", grpNull])}',stop)
        self.assertNotIn('private _clearJob = _x select 2;',stop)
        self.assertIn('forEach (_state getOrDefault ["held",[]])',stop)
        self.assertLess(stop.index('private _canRestoreGroup='),stop.index('doFollow leader _group'))

    def test_external_takeover_uses_one_cached_member_scan(self):
        takeover=source('cortexExternalTakeover')
        self.assertIn('private _members=units _group;',takeover)
        self.assertIn('_specialistSubjects findIf {[_x] call CBE_fnc_CortexExternalOwner != ""}',takeover)
        self.assertIn('if (isNull _actorContext) then {_members} else {[_actorContext]}',takeover)
        self.assertNotIn('([leader _group] call CBE_fnc_CortexExternalOwner)',takeover)
        self.assertNotIn('isPlayer leader _group',takeover)

    def test_delayed_vehicle_and_building_release_restore_shutdown_but_yield_to_external_owners(self):
        takeover=source('cortexExternalTakeover')
        for marker in ['_members findIf {isPlayer _x} >= 0','CBE_fnc_CortexZeusHeld',
                       'CBE_fnc_CortexExternalOwner','CBE_fnc_CompatibilityExternalControl']:
            self.assertIn(marker,takeover)
        self.assertIn('if (isNull _group) exitWith {true};',takeover)
        for name in ['convoyReleaseLocal']:
            release=source(name)
            self.assertIn('private _externalTakeover = local _group && {[_group] call CBE_fnc_CortexExternalTakeover};',release)
            expected='private _mayRestoreGroup=local _group && {!_externalTakeover};'
            self.assertIn(expected,release)
            self.assertNotIn('[_group,false,false,true] call CBE_fnc_CortexIsEligible',release)

    def test_all_delayed_danger_and_passenger_commands_share_the_takeover_boundary(self):
        # A player, curator or specialist owner can arrive after an operation was planned. Each
        # remaining direct-command path must consult the common boundary at the point it chooses to
        # classify, restore, retry or release that earlier CBE work.
        for name in ['dangerActionSelect','cortexReleaseGroup','recoveryStep','convoyDismountLocal']:
            self.assertIn('CBE_fnc_CortexExternalTakeover',source(name),name)
        release=source('cortexReleaseGroup')
        self.assertIn('private _yieldToExternal=local _group && {!_yieldToZeus} && {[_group] call CBE_fnc_CortexExternalTakeover};',release)
        recovery=source('recoveryStep')
        self.assertLess(recovery.index('CBE_fnc_CortexExternalTakeover'),recovery.index('_actor doMove _destination'))
        passenger=source('convoyDismountLocal')
        self.assertLess(passenger.index('CBE_fnc_CortexExternalTakeover'),passenger.index('_unit doMove _destination'))

    def test_master_stop_cancels_explicit_orders_on_their_owner(self):
        text = source('cortexStop')
        cleanup = text.split('if (local _x) then {\n')[1].split('};')[0]
        for function in ['CortexDefendRelease', 'CortexGarrisonRelease', 'CortexClearRelease']:
            self.assertIn('call CBE_fnc_' + function, cleanup)
        for name, assignment in [('cortexDefendRelease', 'Defend'), ('cortexGarrisonRelease', 'Garrison')]:
            self.assertIn('setVariable ["CBE_AIPass_' + assignment + '", nil, true]', source(name))
        qa = (ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text(encoding='utf-8')
        self.assertIn('LIFE-no-old-order-resurrection', qa)
        self.assertIn('_drift <= 12', qa)

    def test_refused_headless_migration_preserves_owner_and_registry_contract(self):
        # CBE does not select a headless client or transfer groups itself.  It adopts on the
        # confirmed destination owner, so the packaged audit must delegate to an available
        # migration provider and prove that a provider refusal leaves the actual owner and its
        # published registry untouched.
        adapter = (ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text(encoding='utf-8')
        adopt = source('aiHeadlessAdoptLocal')
        adopt_body = adopt.split('params [', 1)[1]
        lifecycle = (ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text(encoding='utf-8')
        self.assertIn('if !(isNil "Waldo_fnc_HeadlessMigrateGroup") exitWith {[_group,_owner] call Waldo_fnc_HeadlessMigrateGroup};', adapter)
        self.assertIn('_group setGroupOwner _owner;', adapter)
        self.assertIn('Engine-only HC transfer', adapter)
        self.assertNotIn('setGroupOwner', adopt_body)
        self.assertIn('clientOwner != _newOwner', adopt)
        self.assertIn('!local _group', adopt)
        self.assertIn('CBE_AI_LastAdoptionKey', adopt)
        self.assertIn('CBE_fnc_CortexLocality', adopt)
        self.assertIn('CBE_fnc_SchedulerReconcile', adopt)
        for token in [
            'CBE_Headless_ExcludeGroup',
            'Waldo_Headless_ManagedGroups',
            'LIFE-refused-transfer-owner-retained',
            'LIFE-standalone-no-native-registry',
            'groupOwner _group == _targetOwner',
            '_records isEqualTo []',
            'LIFE-refused-transfer-registry-pruned',
        ]:
            self.assertIn(token, lifecycle)

    def test_reinforcement_readiness_requires_physical_squad_arrival(self):
        text=source('cortexSupportMaintain')
        arrival=text.split('// Contact can begin before the rally is reached.')[1]
        self.assertIn('count _fit >= 3', arrival)
        self.assertIn('_fit findIf {_x distance2D (_lease select 3) > 45} < 0', arrival)
        self.assertNotIn('currentWaypoint', arrival)
        self.assertIn('supportToken', arrival)

    def test_contact_does_not_revoke_reserved_rally(self):
        text=source('cortexGroupTick')
        enter=text.split('private _enterContact = {')[1].split('private _beginContact = {')[0]
        self.assertNotIn('CortexGroupMoveClear', enter)
        self.assertNotIn('set ["responding", false]', enter)
        self.assertIn('if (!_groupMovementOwned && {!(_state getOrDefault ["responding", false])} && {!(_state getOrDefault ["assaulting", false])})', text)
        maintain=source('cortexSupportMaintain')
        arrival=maintain.split('// Contact can begin before the rally is reached.')[1]
        self.assertNotIn('"CALM"', arrival)
        self.assertIn('"supportToken"', arrival)

    def test_post_contact_waits_for_bounded_manoeuvre_owner(self):
        text=source('cortexGroupTick')
        transition=text.split('// Smoke, terrain and buildings can briefly hide a target')[1].split('case "SECURITY"')[0]
        self.assertIn('count (_state getOrDefault ["drill",createHashMap]) > 0',transition)
        self.assertIn('_state getOrDefault ["assaulting",false]',transition)
        self.assertIn('_state getOrDefault ["responding",false]',transition)
        self.assertIn('if (!_manoeuvreActive',transition)
        self.assertLess(transition.index('if (!_manoeuvreActive'),transition.index('CBE_AIPass_PostContact_LostSeconds'))

    def test_security_phase_preserves_and_finishes_prepared_coordinated_assault(self):
        tick=source('cortexGroupTick')
        security=tick.split('case "SECURITY": {',1)[1].split('case "SEARCH": {',1)[0]
        coordinated=source('cortexCoordinatedAssault')
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('call CBE_fnc_CortexCoordinatedAssault',security)
        self.assertIn('if (_coordinatedOwnsSecurity) exitWith {_delay = 2}',security)
        self.assertLess(security.index('call CBE_fnc_CortexCoordinatedAssault'),security.index('CBE_AIPass_PostContact_SecuritySeconds'))
        self.assertIn('private _publicResponders = _group getVariable ["CBE_Cortex_SupportResponders",[]]',coordinated)
        self.assertIn('serverTime < (_lease select 2)',coordinated)
        self.assertIn('_status select 3',coordinated)
        self.assertIn('_state deleteAt "coordinated"',coordinated)
        for marker in ['COORD-contact-loss-entered-security','COORD-security-dispatches-prepared-assault']:
            self.assertIn(marker,qa)
        self.assertLess(qa.index('COORD-security-dispatches-prepared-assault'),qa.index('_enemy setUnitPos "AUTO"'))

    def test_checkpoint_repairs_public_phase_through_transition_ledger(self):
        checkpoint=source('cortexCheckpoint')
        repair=checkpoint.split('private _phase = _state getOrDefault ["phase","CALM"]',1)[1].split('// Engine MOVE commands',1)[0]
        self.assertIn('"CHECKPOINT_REPAIR"',repair)
        self.assertIn('call CBE_fnc_CortexSetPhase',repair)
        self.assertNotIn('setVariable ["CBE_AIPass_PublicPhase"',checkpoint)

    def test_empty_coordinated_dispatch_releases_planning_hold_immediately(self):
        server=source('cortexSupportAssaultServer')
        self.assertIn('if (_sent > 0) then {', server)
        self.assertIn('_job set ["assaultIssued",true]', server)
        empty=server.split('// Route geometry is evaluated from live positions.',1)[1]
        self.assertIn('_job set ["expiry",serverTime]',empty)
        self.assertIn('_requests deleteAt (_job get "key")',empty)
        self.assertIn('_requester setVariable ["CBE_Cortex_SupportResponders",nil,true]',empty)
        self.assertIn('_helper setVariable ["CBE_AIPass_SupportLease",nil,true]',empty)
        self.assertNotIn('remains retryable',server)
        requester=source('cortexCoordinatedAssault')
        self.assertIn('if (_executing && {_status select 3}) then {_acknowledged = true}', requester)
        self.assertIn('if (_acknowledged) exitWith {', requester)
        self.assertIn('[_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd', requester)
        self.assertLess(requester.index('call CBE_fnc_CortexFlankEnd'),requester.index('_state set ["coordinated",true]'))
        self.assertIn('if (time < _pendingUntil && {_publicResponders isNotEqualTo []}) exitWith {false}',requester)
        self.assertIn('_pendingUntil > 0 && {_publicResponders isEqualTo []}',requester)
        self.assertIn('[_state,"coordinated",10] call CBE_fnc_CortexCooldown', requester)

    def test_coordinated_assault_dispatches_from_accepted_shared_contact(self):
        requester=source('cortexCoordinatedAssault')
        server=source('cortexSupportAssaultServer')
        self.assertIn('if (_responders isEqualTo []) exitWith {false}',requester)
        self.assertNotIn('serverTime - _first',requester)
        self.assertNotIn('_arrivals',requester)
        self.assertNotIn('(_status select 1) >= 0',server.split('private _rally=')[0])
        self.assertIn('private _routeOrigin=getPosATL _helperTransmitter',server)
        self.assertNotIn('private _rally=+(_lease select 3)',server)
        self.assertNotIn('(_status select 1) >= 0',server)
        self.assertIn('[_routeOrigin,_candidateRoutes,_enemy,[_supportOrigin]]',server)
        self.assertIn('([_helper] call CBE_fnc_CortexGroupTransmitter)',server)
        self.assertIn('[_candidate] call CBE_fnc_CortexGroupTransmitter',source('cortexSupportServer'))
        self.assertIn('private _groupTransmitter = [_group] call CBE_fnc_CortexGroupTransmitter;',source('cortexSupportApply'))
        self.assertIn('private _directCoordinationPending = _attack isEqualTo []',source('cortexSupportApply'))
        self.assertIn('if (_okay && {_directCoordinationPending}) exitWith {',source('cortexSupportApply'))
        self.assertIn('private _dispatched=[]',server)
        self.assertIn('_job set ["leases",_dispatched]',server)
        self.assertIn('_helper setVariable ["CBE_AIPass_SupportLease",nil,true]',server)
        self.assertIn('_requester setVariable ["CBE_Cortex_SupportResponders",_dispatched apply',server)

    def test_coordinated_approaches_do_not_cross_support_fire_lane(self):
        server=source('cortexSupportAssaultServer')
        selector=source('cortexSelectAvenue')
        self.assertNotIn('([90,-90] select (_sent mod 2 == 1))',server)
        self.assertNotIn('private _crossesSupportLane=',server)
        self.assertIn('call CBE_fnc_CortexSelectAvenue',server)
        self.assertIn('[_routeOrigin,_candidateRoutes,_enemy,[_supportOrigin]]',server)
        self.assertIn('_lateral < 30',selector)
        self.assertIn('private _originSide=',server)
        self.assertIn('private _desiredSide=',server)
        self.assertIn('private _candidateSide=',server)
        self.assertIn('private _sameSide=_candidateSide*_desiredSide > 0',server)
        self.assertIn('if (_sameSide && {!surfaceIsWater _candidate}',server)
        self.assertIn('_approaches findIf {_x distance2D _candidate < 60} < 0',server)
        self.assertIn('(_laneLength*0.3)',server)
        self.assertIn('((_routeOrigin distance2D _enemy)*0.2)',server)
        self.assertIn('max 45 min 180',server)
        self.assertIn('private _outerRadius=(_approachRadius+70) min 250',server)
        self.assertIn('forEach [[_approachRadius,90],[_outerRadius,90],[_obliqueRadius,135]',server)
        self.assertIn('[_approachRadius,-90],[_outerRadius,-90],[_obliqueRadius,-135]',server)
        self.assertNotIn('private _approachProtection=',server)
        self.assertIn('forEach [0.25,0.5,0.75]',selector)
        self.assertIn('[_threatASL,_sampleASL,objNull,"COVER",_threatObject] call CBE_fnc_CortexCoverScreened',selector)
        screening=selector.split('if (_vehicleScreening) then {',1)[1]
        vehicle_branch,infantry_branch=screening.split('} else {',1)
        self.assertEqual(vehicle_branch.count('call CBE_fnc_CortexCoverScreened'),1)
        self.assertEqual(infantry_branch.count('call CBE_fnc_CortexCoverScreened'),2)
        self.assertIn('forEach [-1,0,1]',vehicle_branch)
        self.assertIn('forEach [0.25,0.5,0.75]',infantry_branch)
        self.assertNotIn('lineIntersectsSurfaces',selector)
        screen=source('cortexCoverScreened')
        self.assertIn('!(_object isKindOf "CAManBase")',screen)
        self.assertIn('_actor,_source,true,4',screen)

    def test_coordinated_assault_waits_for_ack_before_requester_handover(self):
        tick=source('cortexGroupTick')
        coordinated=source('cortexCoordinatedAssault')
        self.assertLess(tick.index('private _coordinatedOwnsMovement = _vehicleOwnsMovement'),tick.index('call CBE_fnc_CortexTacticalStart'))
        self.assertIn('if (!_holdFire && {_hasTargetKnowledge} && {!_ordered} && {!_coordinatedOwnsMovement})',tick)
        self.assertIn('["CBE_AIPass_Flank_Enable", true] call _get',tick)
        self.assertIn('["CBE_AIPass_Advance_Enable", true] call _get',tick)
        self.assertIn('_state set ["coordinatedPendingUntil",time+15]',coordinated)
        self.assertIn('if (time < _pendingUntil && {_publicResponders isNotEqualTo []}) exitWith {false}',coordinated)
        self.assertIn('false // A request alone owns no movement; acknowledgement performs the handover.',coordinated)
        self.assertIn('[_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd',coordinated)
        self.assertIn('"coordinatedPendingUntil"',source('cortexRestoreCalm'))

    def test_live_context_chooses_action_instead_of_profile_or_idleness(self):
        selector=source('cortexTacticalStart')
        assessment=source('cortexTacticalAssess')
        flank=source('cortexFlankStart')
        advance=source('cortexAdvanceStart')
        assault=source('cortexAssaultStart')
        coordinated=source('cortexCoordinatedAssault')
        self.assertIn('call CBE_fnc_CortexAssaultStart',selector)
        self.assertIn('private _closePosition=_manoeuvre findIf',assessment)
        for constructor in (assault,flank,advance):
            roster=constructor.split('private _onFoot',1)[1].split('};',1)[0]
            if constructor == flank:
                roster=constructor.split('private _strengthFoot=',1)[1].split('if (count _onFoot',1)[0]
            self.assertIn('CortexCombatEffective',roster)
            self.assertIn('CortexActorFireTaskAvailable',roster)
            self.assertIn('CortexHolderRecallOwned',roster)
        task_gate=source('cortexActorFireTaskAvailable')
        for task in ('"HEAL"','"REARM"','"GET IN"','"REPAIR"','CortexActorMoveReserved'):
            self.assertIn(task,task_gate)

        self.assertIn('(_record param [3,1e9,[0]]) >= 12',assessment)
        self.assertIn('(_record param [3,1e9,[0]]) <= _closeRange',assessment)
        self.assertIn('private _freshPosition=_manoeuvre findIf',assessment)
        self.assertIn('(_record param [3,0,[0]]) >= 60',assessment)
        self.assertIn('_selected=_enemies findIf',assessment)
        self.assertIn('Any live contact can provide fire context',assessment)
        self.assertIn('_selected=_manoeuvre select _closePosition',assessment)
        self.assertIn('_assaultEnabled && {_closePosition >= 0} && {count _armedFoot >= 2}',assessment)
        capacity=assessment.split('private _availableFoot=',1)[1].split('private _houses=',1)[0]
        self.assertIn('CBE_fnc_CortexActorFireTaskAvailable',capacity)
        self.assertIn('simulationEnabled _x',capacity)
        self.assertIn('_x checkAIFeature "FIREWEAPON"',capacity)
        self.assertIn('if (_availableFoot isEqualTo []) exitWith',capacity)
        self.assertIn('"ACTOR_TASKS_BUSY"',capacity)
        self.assertIn('private _armedFoot=_availableFoot select',capacity)
        self.assertIn('private _capableAT=_availableFoot findIf',capacity)
        self.assertIn('private _capableAA=_availableFoot findIf',capacity)
        self.assertLess(capacity.index('"ACTOR_TASKS_BUSY"'),capacity.index('if (count _armedFoot < 2)'))
        self.assertIn('case "ACTOR_TASKS_BUSY": {"ACTOR_TASK_HANDOFF"}',selector)

        self.assertIn('if (count _onFoot < 2) exitWith',assault)
        self.assertIn('SMALL_ELEMENT_UNAVAILABLE',assault)
        roster=assault.split('private _onFoot=',1)[1].split('if (count _onFoot < 2)',1)[0]
        self.assertIn('primaryWeapon _x != ""',roster)
        # Unarmed nonparticipants cannot inflate the element-size/cover threshold.
        armed_roster=[weapon for weapon in ('rifle','rifle','','') if weapon]
        self.assertEqual(len(armed_roster),2)

        def close_candidate(armed,distance,age=0,enabled=True):
            return enabled and armed >= 2 and 12 <= distance <= 60 and age <= 10
        for armed in (2,3,4):self.assertTrue(close_candidate(armed,25))
        self.assertFalse(close_candidate(1,25))
        self.assertFalse(close_candidate(2,8))
        self.assertFalse(close_candidate(3,25,11))
        self.assertFalse(close_candidate(3,25,enabled=False))

        self.assertIn('_selected=_manoeuvre select _freshPosition',assessment)
        self.assertIn('_started=_args call CBE_fnc_CortexAssaultStart',selector)
        self.assertIn('if (_elementScoped) then {_args pushBack _element}',selector)
        self.assertIn('!_elementScoped',selector)
        self.assertIn('private _forwardOrder=!_elementScoped && {_waypointIndex < count waypoints _group}',assessment)
        self.assertIn('"FORTIFIED_OR_DISTANT_CONTACT"',assessment)
        self.assertIn('"OPEN_APPROACH"',assessment)
        self.assertIn('"COVERED_APPROACH"',assessment)
        self.assertIn('"MORALE_NOT_STEADY"',assessment)
        self.assertIn('"MORALE_SHAKEN"',assessment)
        self.assertIn('"AIR_OVERMATCH"',assessment)
        self.assertIn('"AA" in ([_x] call CBE_fnc_CortexCapabilities)',assessment)
        self.assertIn('_platform isKindOf "Air"',assessment)
        tactical_qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runTacticalAssessment.sqf').read_text()
        for marker in ['TACTICAL-air-fixture-ready','TACTICAL-air-real-contact',
                       'TACTICAL-air-overmatch-reposition','TACTICAL-air-no-CBE-chase',
                       'B_Heli_Attack_01_F','setVelocityModelSpace','magazinesAllTurrets']:
            self.assertIn(marker,tactical_qa)
        self.assertIn('"INSUFFICIENT_FIREPOWER"',assessment)
        depleted=assessment.split('if (count _armedFoot < 2) exitWith {',1)[1].split('private _capableAT=',1)[0]
        for guard in ('count _armedFoot == 1','count _enemies == 1','isNull objectParent _target',
                      'param [2,1e9,[0]]) <= 5','param [3,1e9,[0]]) <= 20','NATIVE_CLOSE_CONTACT'):
            self.assertIn(guard,depleted)
        self.assertLess(depleted.index('NATIVE_CLOSE_CONTACT'),depleted.index('INSUFFICIENT_FIREPOWER'))
        self.assertNotIn('doMove',depleted)
        self.assertNotIn('doFire',depleted)
        self.assertIn('"ELEVATED_FIRE_POSITION"',assessment)
        self.assertIn('((AGLToASL _position) select 2)',assessment)
        self.assertIn('count _position == 3',assessment)
        self.assertNotIn('getPosASL _target',assessment)
        self.assertIn('"CONCEALED_ELEVATED_APPROACH"',assessment)
        self.assertIn('"REPOSITION"',assessment)
        self.assertIn('"NO_SAFE_MANOEUVRE"',selector)
        self.assertIn('"MORALE_HANDOFF"',selector)
        self.assertIn('"WEAPON_LAYER_HANDOFF"',selector)
        self.assertIn('"NATIVE_CONTACT_HANDOFF"',selector)
        self.assertIn('"NATIVE_REASSESS"',selector)
        combat=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text(encoding='utf-8')
        self.assertIn('CBE_Cortex_TacticalAssessment',combat)
        self.assertIn('-assessment-selected-intent',combat)
        self.assertIn('(_assessment select 0) == _mode',combat)
        self.assertIn('(_assessment select 5) == "STARTED"',combat)
        self.assertNotIn('CortexProfile',selector)
        self.assertNotIn('random',assessment)
        self.assertEqual(1,selector.count('call CBE_fnc_CortexFlankStart'))
        self.assertEqual(1,selector.count('call CBE_fnc_CortexAdvanceStart'))
        self.assertIn('["type","ASSAULT"]',assault)
        self.assertIn('["assaulting",true]',assault)
        self.assertIn('[["_group",grpNull',assault)
        self.assertIn('call CBE_fnc_CortexSelectAvenue',assault)
        self.assertIn('call CBE_fnc_OperationStart',assault)
        self.assertIn('call CBE_fnc_CortexDrillStart',assault)
        self.assertNotIn('spawn',assault)
        self.assertNotIn('addWaypoint',assault)
        self.assertNotIn('random 1 >= ([_group, "flankChance"]',flank)
        self.assertNotIn('random 1 >= ([_group, "advanceChance"]',advance)
        self.assertNotIn('coordinatedChance',coordinated)
        self.assertNotIn('random 1 >= ([_group, "coordinatedChance"]',coordinated)

    def test_reposition_corridor_advances_only_after_owned_physical_arrival(self):
        start=source('cortexTacticalReposition')
        tick=source('cortexGroupTick')
        self.assertIn('_route select 0,6,"MOVE",_generation',start)
        self.assertIn('["tacticalRepositionLeg",0]',start)
        progression=tick.split('// Follow the committed screened corridor',1)[1].split('private _groupMovementOwned',1)[0]
        for marker in ['CBE_OperationGeneration', 'ownerEpoch', '_anchor distance2D _point <= 6',
                       'count _route <= 16', 'time < (_movementLease select 1)']:
            if marker == 'CBE_OperationGeneration':
                self.assertIn('getOrDefault ["generation",-2]) == _generation',progression)
            else:
                self.assertIn(marker,progression)
        self.assertLess(progression.index('_anchor distance2D _point <= 6'),progression.index('call CBE_fnc_CortexGroupMove'))
        self.assertLess(progression.index('(_waypoint param [1,-1,[0]]) >= 0'),progression.index('["tacticalRepositionLeg",_next]'))
        self.assertEqual(progression.count('call CBE_fnc_CortexGroupMove'),1)
        self.assertNotIn('spawn',progression)
        self.assertNotIn('while {',progression)

    def test_tactical_reposition_is_finite_generation_owned_and_yields_to_zeus(self):
        reposition=source('cortexTacticalReposition')
        selector=source('cortexTacticalStart')
        tick=source('cortexGroupTick')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        for marker in [
            'call CBE_fnc_CortexIsEligible',
            'call CBE_fnc_CortexExternalTakeover',
            'CBE_Cortex_TacticalRepositionCooldown',
            'call CBE_fnc_OperationStart',
            'call CBE_fnc_CortexGroupMove',
            '["movementLease",["TACTICAL_REPOSITION",time+30]]',
        ]:
            self.assertIn(marker,reposition)
        self.assertIn('case "TACTICAL_REPOSITION": {"tacticalRepositionOperationGeneration"}',tick)
        self.assertIn('_reposition set [0,_movementResult]',tick)
        self.assertIn('_x distance2D (_record select 5) > 12',tick)
        self.assertIn('count _declared <= 64',tick)
        self.assertIn('_participants isNotEqualTo []',tick)
        self.assertIn('["INCOMPLETE","COMPLETE"] select _arrived',tick)
        self.assertIn('class CortexTacticalReposition',functions)
        self.assertIn('case "REPOSITION"',selector)
        self.assertIn('if (_started) exitWith {_intent=_x}',selector)
        self.assertEqual(selector.count('setVariable ["CBE_Cortex_TacticalAssessment"'),2)
        self.assertIn('["NATIVE_REASSESS","STARTED"] select _started',selector)
        self.assertNotIn('spawn',reposition)
        self.assertNotIn('while {',reposition)
        self.assertNotIn('setPos',reposition)

    def test_direct_assault_uses_its_own_live_gate_and_cleanup_accounting(self):
        start=source('cortexAssaultStart')
        self.assertIn('if (count _onFoot < 2)',start)
        self.assertIn('count _onFoot == 3) then {2}',start)
        self.assertIn('private _minimumMovers=[2,1] select (count _onFoot == 2)',start)
        self.assertIn('private _minimumCover=[2,1] select _smallElement',start)
        self.assertIn('SMALL_ELEMENT_UNAVAILABLE',start)
        self.assertIn('CBE_fnc_CortexActorFireTaskAvailable',start)
        self.assertIn('getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]',start)
        self.assertIn('count _coverElement < _minimumCover',start)
        reposition=source('cortexTacticalReposition')
        self.assertIn('getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]',reposition)
        self.assertIn('CBE_fnc_CortexActorFireTaskAvailable',reposition)
        step=source('cortexFlankStep')
        end=source('cortexFlankEnd')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexAssaultStart',functions)
        self.assertIn('case "ASSAULT": {"CBE_AIPass_Assault_Enable"}',step)
        self.assertIn('case "ASSAULT": {"CBE_AIPass_Assault_Cooldown"}',end)
        self.assertIn('case "ASSAULT": {"CBE_AIPass_AssaultsCompleted"}',end)

    def test_tactical_assessment_audit_uses_real_contacts_and_physical_outcomes(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runTacticalAssessment.sqf').read_text(encoding='utf-8')
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('cortexQATacticalAssessment.sqf',server)
        self.assertIn('"tacticalassessment"',server)
        self.assertGreaterEqual(server.count('"dangerparity"'),3)
        self.assertIn('createVehicle ["B_APC_Wheeled_01_cannon_F"',qa)
        self.assertIn('createVehicle ["Land_Cargo_Tower_V1_F"',qa)
        self.assertIn('call CBE_fnc_CortexKnowledge',qa)
        self.assertGreaterEqual(qa.count('private _knowledge=['),3)
        self.assertGreaterEqual(qa.count('((_knowledge select 0) findIf'),3)
        self.assertNotIn('call CBE_fnc_CortexKnowledge) select 0) findIf',qa)
        self.assertIn('CBE_Cortex_TacticalAssessment',qa)
        self.assertIn('"REPOSITION","ARMOUR_OVERMATCH","STARTED"',qa)
        self.assertIn('"AUTHORED_FORWARD_ORDER"',qa)
        self.assertIn('"REPOSITION","ELEVATED_FIRE_POSITION","STARTED"',qa)
        self.assertIn('TACTICAL-armour-overmatch-reposition',qa)
        self.assertIn('TACTICAL-elevated-reposition',qa)
        self.assertIn('TACTICAL-authored-order-physical-progress',qa)
        self.assertNotIn('call CBE_fnc_CortexTacticalAssess',qa)
        self.assertNotIn(' reveal ',qa)
        self.assertEqual(qa.count('setPos'),1)
        self.assertIn('_aircraft setPosATL [1700,3200,180]',qa)
        self.assertLess(qa.index('_aircraft setPosATL'),qa.index('private _airReady'))
        self.assertIn('_airEnemyGroup addWaypoint [[1700,1800,180],0]',qa)

    def test_shipped_profiles_retain_legacy_movement_keys_for_configuration_compatibility(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        defaults=(ROOT/'cortex_defaults.md').read_text(encoding='utf-8')
        for profile,flank,advance in [
            ('MILITIA','0.3','0.7'),
            ('LINE','0.5','0.6'),
            ('VETERAN','0.7','0.5'),
            ('ELITE','0.9','0.4'),
        ]:
            row=config.split(f'["{profile}", createHashMapFromArray ',1)[1].split(']]]',1)[0]
            self.assertIn(f'["flankChance", {flank}]',row)
            self.assertIn(f'["advanceChance", {advance}]',row)
            documented=defaults.split(f'["{profile}", createHashMapFromArray ',1)[1].split(']]]',1)[0]
            self.assertIn(f'["flankChance", {flank}]',documented)
            self.assertIn(f'["advanceChance", {advance}]',documented)

    def test_coordinated_selection_uses_bounded_server_responder_index(self):
        coordinated=source('cortexCoordinatedAssault')
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        self.assertNotIn('allGroups',coordinated)
        self.assertIn('CBE_Cortex_SupportResponders',coordinated)
        self.assertIn('_requester setVariable ["CBE_Cortex_SupportResponders",[],true]',server)
        self.assertIn('private _responders = _kept apply {[_x select 0,_x select 1]}',step)
        self.assertIn('_requester setVariable ["CBE_Cortex_SupportResponders",_responders,true]',step)
        self.assertIn('_requester setVariable ["CBE_Cortex_SupportResponders",nil,true]',step)

    def test_dormant_group_defers_decisions_without_restarting_operations(self):
        tick=source("cortexGroupTick")
        gate=tick.split("// Dormancy is not loss of ownership.",1)[1].split("// The generic group loop",1)[0]
        self.assertIn("simulationEnabled _x && {!isObjectHidden _x}",gate)
        self.assertIn("exitWith {5}",gate)
        self.assertNotIn("enableSimulation",gate)
        self.assertNotIn("setVariable",gate)
        self.assertNotIn("hardDeadline",gate)
        self.assertLess(tick.index("if (_alive isEqualTo [])"),tick.index("// Dormancy is not loss of ownership."))
        self.assertLess(tick.index("// Dormancy is not loss of ownership."),tick.index("call CBE_fnc_DrivingAssistStart"))

    def test_support_request_failure_has_one_bounded_retry(self):
        reinforce=source('cortexReinforce')
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        assault=source('cortexSupportAssaultServer')
        self.assertIn('CBE_Cortex_SupportRequestState',reinforce)
        self.assertIn('{[_x] call CBE_fnc_CortexCombatEffective} count units _group',reinforce)
        self.assertIn('_effective / _peak >= 0.6',reinforce)
        self.assertNotIn('{alive _x} count units _group',reinforce)
        self.assertIn('_requests == 1',reinforce)
        self.assertIn('time >= _lastDispatch+20',reinforce)
        self.assertIn('_requests >= 2',reinforce)
        self.assertIn('["reinforceDispatchedAt",time]',reinforce)
        self.assertIn('"ACTIVE"',server)
        self.assertIn('"NO_RESPONDER"',step)
        self.assertIn('"NO_SAFE_ROUTE"',assault)
        self.assertIn('_job get "expiry"',assault)
        stop=source('cortexStop')
        self.assertIn('CBE_Cortex_SupportRequestState',stop)
        self.assertIn('CBE_Cortex_SupportResponders',stop)

    def test_infantry_support_never_routes_mounted_vehicle_crews_as_bounders(self):
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        apply=source('cortexSupportApply')
        assault=source('cortexSupportAssaultServer')
        dismount_guard='[_x] call CBE_fnc_CortexCombatEffective && {isNull objectParent _x}'
        self.assertIn(dismount_guard,server)
        self.assertGreaterEqual(step.count(dismount_guard),2)
        self.assertIn('private _footFit = _fit select {isNull objectParent _x}',apply)
        self.assertIn('count _footFit >= 3',apply)
        self.assertIn('_footFit findIf {"AT" in',apply)
        self.assertIn(dismount_guard,assault)

    def test_recurring_cqb_and_support_use_direct_on_foot_checks(self):
        names = [
            'cortexClearBuilding', 'cortexSupportApply', 'cortexSupportBoundStart',
            'cortexSupportMaintain', 'cortexSupportStep', 'cortexSupportCoordinateStep',
            'cortexSupportServer', 'cortexSupportAssaultServer'
        ]
        texts = [source(name) for name in names]
        for text in texts:
            self.assertIn('objectParent', text)
            self.assertNotIn('vehicle _x == _x', text)
            self.assertNotIn('vehicle _x != _x', text)

    def test_recurring_infantry_filters_use_direct_on_foot_checks(self):
        names = [
            'cortexGroupTick', 'cortexStance', 'cortexAntiArmour',
            'cortexFlankStep', 'rebalanceRoles', 'cortexAmmoShare'
        ]
        for text in [source(name) for name in names]:
            self.assertIn('objectParent', text)
            self.assertNotIn('vehicle _x == _x', text)
            self.assertNotIn('vehicle _unit == _unit', text)

    def test_external_takeover_boolean_chain_starts_with_a_boolean(self):
        takeover = source('cortexExternalTakeover')
        self.assertIn('(_members findIf {isPlayer _x} >= 0)\n||', takeover)
        self.assertNotIn('{_members findIf {isPlayer _x} >= 0}\n||', takeover)

    def test_packaged_audit_stops_after_command_boundary_preflight_failure(self):
        addon = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runAddon.sqf').read_text(encoding='utf-8')
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_CortexExternalTakeover', addon)
        self.assertIn('ADDON-command-boundary-boolean', addon)
        self.assertIn('_takeoverResult isEqualType true', addon)
        addon_call = '[_check] call compile preprocessFileLineNumbers "cortexQAAddon.sqf";'
        self.assertIn(addon_call, server)
        preflight = server.index(addon_call)
        abort = server.index('if (_failures isNotEqualTo []) exitWith {', preflight)
        first_fixture = server.index('private _group = grpNull;', preflight)
        self.assertLess(abort, first_fixture)
        early = server[abort:first_fixture]
        self.assertIn('CBE_CortexQA_ServerDone', early)
        self.assertIn('CBE CORTEX QA SERVER COMPLETE', early)

    def test_flank_support_lane_selection_is_spatially_bounded(self):
        flank=source('cortexFlankStart')
        self.assertIn('_enemyPos nearEntities ["Man",500]',flank)
        self.assertIn('} forEach _supportGroups;',flank)
        self.assertNotIn('} forEach allGroups;',flank)

    def test_server_opportunity_discovery_uses_spatial_candidate_sets(self):
        support=source('cortexSupportServer')
        reports=source('cortexReportServer')
        combined=source('cortexCombinedArmsServer')
        for text in [support]:
            self.assertIn('nearEntities ["Man",',text)
        for text in [support,reports,combined]:
            self.assertNotIn('} forEach allGroups;',text)
        self.assertIn('_searchArea nearEntities [["Man"],false,true,true]',combined)
        self.assertIn('} forEach _candidateGroups;',support)
        self.assertIn('_receiverArea nearEntities [["Man"],false,true,true]',reports)
        self.assertIn('} forEach _receiverGroups;',reports)
        self.assertIn('} forEach _candidateGroups;',combined)

    def test_combined_arms_opportunities_are_bounded_and_never_gate_infantry(self):
        request=source('cortexCombinedArmsRequest')
        server=source('cortexCombinedArmsServer')
        local=source('cortexCombinedArmsLocal')
        fallback=source('cortexCombinedAirFallbackServer')
        ground_step=source('cortexCombinedGroundStep')
        tick=source('cortexGroupTick')
        self.assertIn('serverTime+20+random 8',request)
        self.assertIn('remoteExecCall ["CBE_fnc_CortexCombinedArmsServer",2]',request)
        self.assertIn('private _ground=0',server)
        self.assertIn('private _air=0',server)
        self.assertIn('CBE_AIPass_ContactReports_Radius',server)
        self.assertIn('CBE_AIPass_ContactReports_VoiceRange',server)
        self.assertIn('CBE_Cortex_CombinedArms_AirRange',server)
        self.assertIn('private _orderedGroups=[]',server)
        self.assertIn('_orderedGroups sort true',server)
        self.assertIn('magazinesAllTurrets _candidateAsset',server)
        self.assertIn('Armed aircraft rank first',server)
        self.assertIn('CBE_Cortex_CombinedAirFallback',server)
        self.assertIn('_distance <= _airRange',server)
        self.assertIn('_distance <= _groundRange',server)
        self.assertIn('_senderRadio && {_candidateRadio}',server)
        self.assertNotIn('private _range=if (_senderRadio)',server)
        self.assertNotIn('<= 1200',server)
        self.assertNotIn('CortexCanTransmit',request)
        self.assertIn('if (_ground >= 2 && {_air >= 1}) exitWith {}',server)
        self.assertIn('!isTouchingGround _asset',server)
        self.assertIn('{isTouchingGround _asset}',local)
        self.assertNotIn('speed _asset',server+local)
        self.assertNotIn('waitUntil',server+local)
        self.assertNotIn('addWaypoint',server+local)
        self.assertIn('CBA_fnc_waitAndExecute',server)
        self.assertIn('setVariable ["CBE_Cortex_CombinedRole",nil,true]',server)
        self.assertIn('"DISPATCHED"',server)
        self.assertIn('"EXPIRED"',server)
        self.assertIn('["GROUND_FIRE","GROUND_MANOEUVRE"]',server)
        self.assertIn('_role in ["GROUND_FIRE","GROUND_MANOEUVRE","AIR_ATTACK"]',local)
        self.assertIn('CBE_fnc_CortexCombinedGroundStep',local)
        self.assertIn('CBE_fnc_CortexSelectAvenue',local)
        self.assertIn('_target,"VEHICLE"',local)
        self.assertIn('"NO_SAFE_ROUTE"',local)
        self.assertIn('forEach [260,320,380]',local)
        self.assertIn('forEach [180,240]',local)
        self.assertIn('"COMBINED_GROUND"',local+ground_step)
        self.assertIn('CBE_fnc_CortexZeusHeld',ground_step)
        self.assertIn('if (_stalls >= 1)',ground_step)
        self.assertIn('[_group,_operationGeneration] call CBE_fnc_CortexGroupMoveClear;',ground_step)
        self.assertNotIn('setPos',ground_step)
        self.assertNotIn('setVelocity',ground_step)
        self.assertNotIn('CortexCanTransmit',local)
        self.assertGreaterEqual(local.count('"APPLIED"'),2)
        self.assertIn('CBE_Cortex_CombinedApplied',tick)
        self.assertIn('(_combinedApplied param [1,-1]) != clientOwner',tick)
        self.assertIn('_group reveal [_target,_contactReceipt select 2]',local)
        self.assertNotIn('_group reveal [_target,2.5]',local)
        # Shared knowledge must not become an ATTACK/pursuit order for every crew member. Only the
        # stationary fire role may explicitly target its gunner; manoeuvre and air controllers own
        # their later target/release boundary.
        role_preamble=local.split('if (_role == "GROUND_FIRE") exitWith {',1)[0]
        ground_fire=local.split('if (_role == "GROUND_FIRE") exitWith {',1)[1].split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[0]
        self.assertNotIn('doTarget',role_preamble)
        self.assertNotIn('forEach crew _asset',local)
        self.assertIn('_gunner doTarget _target',ground_fire)
        self.assertIn('_gunner doFire _target',ground_fire)
        self.assertIn('CBE_fnc_AirAttackOperationStart',local)
        self.assertIn('private _plan=[_asset,_target] call CBE_fnc_CortexAirAttackPlan',local)
        self.assertIn('"NO_VIABLE_WEAPON"',local)
        self.assertIn('CBE_fnc_CortexCombinedAirFallbackServer',local)
        self.assertIn('remoteExecutedOwner != groupOwner _rejected',fallback)
        self.assertIn('FALLBACK_DISPATCHED',fallback)
        self.assertIn('CBE_Cortex_AirAttackJob',fallback)
        self.assertIn('CBA_fnc_waitAndExecute',fallback)
        self.assertIn('["target",_target]',local)
        self.assertIn(']],0.5] call CBE_fnc_AirAttackOperationStart',local)
        self.assertNotIn('CBE_AIPass_CoordinatedAssault_Enable',server)
        self.assertIn('CBE_fnc_CortexCombinedArmsRequest',tick)
        begin_contact=tick.split('private _beginContact = {',1)[1].split('};\n\nif (_visible',1)[0]
        self.assertIn('CBE_fnc_CortexCombinedArmsRequest',begin_contact)
        first_contact_share=begin_contact.rsplit('// The first fresh contact',1)[1]
        self.assertNotIn('if (_nearTier',first_contact_share.split('CBE_fnc_CortexCombinedArmsRequest',1)[0])
        self.assertNotIn('CBE_AIPass_CoordinatedAssault_Enable',
                         first_contact_share.split('CBE_fnc_CortexCombinedArmsRequest',1)[0])
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('cortex-combined-role-',diagnostics)
        self.assertIn('Combined roles share an opportunity only',diagnostics)

    def test_helicopter_locality_pin_does_not_disable_cortex_flight_behaviour(self):
        eligible=source('cortexIsEligible')
        self.assertIn('CBE_ImprovedHelicopterLanding_Active',eligible)
        self.assertNotIn('_vehicles findIf {_x getVariable ["CBE_Headless_HelicopterPinned"',eligible)
        self.assertIn('The permanent helicopter pin prevents unstable HC transfer',eligible)

    def test_external_ai_owners_are_detected_without_blanket_mod_exclusion(self):
        owner=source('cortexExternalOwner')
        eligible=source('cortexIsEligible')
        for marker in ['WBK_AI_ISZombie','Droid_Health','WBK_Droids_VoiceType','WBK_AI_ZombieMoveSet',
                       'IMS_IsUnitInvicibleScripted','IMS_ISAI','IMS_EventHandler_Hit']:
            self.assertIn(marker,owner)
        self.assertIn('_class find "WBK_" == 0',owner)
        self.assertNotIn('_moves != ""',owner)
        self.assertIn('getText (_config >> "author")',owner)
        self.assertIn('[_unit] call CBE_fnc_CortexExternalOwner != ""',eligible)
        self.assertNotIn('isClass (configFile >> "CfgPatches"',eligible)

    def test_wait_movement_lease_does_not_mutate_broad_external_ai_state(self):
        lease=source('cortexOwnershipLease')
        compat=(ROOT/'addons/compatibility/functions/aiTweaksDetectCompatibility.sqf').read_text(encoding='utf-8')
        self.assertIn('CBE_Cortex_MovementLease',lease)
        self.assertIn('CBE_fnc_CortexExternalTakeover',lease)
        self.assertIn('_live && {(_lease select 0) != _owner}',lease)
        for forbidden in ['AlternativeBackend','Vcm_Disable','VCM_MOVE2SUP','VCM_MBUSY','VCOM_AI']:
            self.assertNotIn(forbidden,lease+compat)
        for capability in ['"meleeBackend"','"specialistBackend"']:
            self.assertIn(capability,compat)

    def test_civilian_reactions_are_event_driven_and_yield_to_wbk_and_zeus(self):
        setup=source('cortexCivilianSetup')
        react=source('cortexCivilianReact')
        init=source('cortexInit')
        stop=source('cortexStop')
        for event in ['"FiredNear"','"Explosion"','"Hit"','"Local"']:
            self.assertIn(event,setup)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',setup+react)
        self.assertNotIn('while {',setup+react)
        self.assertIn('CBE_fnc_CortexExternalTakeover',setup)
        self.assertIn('CBE_fnc_CortexExternalTakeover',react)
        self.assertIn('BIS_fnc_findSafePos',react)
        self.assertIn('forEach [0,-45,45]',react)
        self.assertGreaterEqual(react.count('call CBE_fnc_CortexSelectAvenue'),2)
        self.assertIn('if (_route isEqualTo []) exitWith {false}',react)
        self.assertIn('doMove _destination',react)
        self.assertIn('_priority <= (_active param [1,0,[0]])',react)
        self.assertIn('CBE_Cortex_CivilianGeneration',react)
        self.assertIn('CBE_fnc_CortexCivilianStep',react)
        self.assertIn('_active param [5,',react)
        self.assertNotIn('switchMove',react)
        step=source('cortexCivilianStep')
        self.assertIn('CBE_Cortex_CivilianGeneration',step)
        self.assertIn('CBE_fnc_CortexExternalTakeover',step)
        self.assertEqual(step.count('_unit doMove _destination'),1)
        self.assertNotIn('while {',step)
        self.assertIn('"EntityCreated"',init)
        self.assertIn('CBE_Cortex_CivilianCreatedHandler',stop)
        settings=source('aiTweaksSettingChanged')
        self.assertIn('CBE_AIPass_CivilianReaction_Enable',settings)
        self.assertIn('call CBE_fnc_CortexInit',settings)

    def test_aircraft_occupants_have_one_dedicated_movement_owner(self):
        eligible=source('cortexIsEligible')
        discover=source('cortexDiscover')
        tick=source('cortexGroupTick')
        attack=source('cortexAirAttack')
        self.assertIn('["_groundPass",false,[true]]',eligible)
        self.assertIn('_groundPass && {_alive findIf {',eligible)
        self.assertIn('_vehicle isKindOf "Air"',eligible)
        self.assertIn('[_group,false,true] call CBE_fnc_CortexIsEligible',discover)
        self.assertIn('private _generallyEligible=[_group] call CBE_fnc_CortexIsEligible',tick)
        self.assertIn('private _groundPassEligible=[_group,false,true] call CBE_fnc_CortexIsEligible',tick)
        self.assertIn('[_group,true,"AIRCRAFT_DEDICATED"] call CBE_fnc_CortexReleaseGroup',tick)
        self.assertIn('_stage != "" || {[_group] call CBE_fnc_CortexIsEligible}',attack)
        self.assertIn('private _explicitlyExcluded=',attack)

    def test_partial_final_bound_does_not_complete_the_assault(self):
        coordinator=source('cortexSupportCoordinateStep')
        self.assertIn('_outcome in ["COMPLETE","PARTIAL"]',coordinator)
        self.assertIn('if (_outcome == "COMPLETE" && {_final})',coordinator)
        self.assertNotIn('if (_progressed && {_final})',coordinator)
        self.assertIn('!(_token in _completed)',coordinator)

    def test_combined_roles_use_owned_fire_team_drills_and_restore_holds(self):
        coordinator=source('cortexSupportCoordinateStep')
        self.assertNotIn('allUnits',coordinator)
        self.assertNotIn('allGroups',coordinator)
        self.assertIn('if ((_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _role)',coordinator)
        self.assertIn('(_result select 0) == _token',coordinator)
        self.assertIn('serverTime+8',coordinator)
        self.assertIn('private _failuresByToken=',coordinator)
        self.assertIn('_outcome in ["COMPLETE","PARTIAL"]',coordinator)
        self.assertIn('_retired pushBackUnique _token',coordinator)
        self.assertIn('if (_failures >= 2)',coordinator)
        self.assertNotIn('_job set ["coordinationAborted",true]',coordinator)
        self.assertIn('private _boundLength=(_remaining*0.35) max 45 min 70',coordinator)
        self.assertIn('forEach [0,-18,18]',coordinator)
        self.assertIn('CBE_fnc_CortexSelectAvenue',coordinator)
        self.assertIn('_job get "assaultEnemy",_supportOrigins',coordinator)
        self.assertIn('"INSUFFICIENT_STRENGTH"',coordinator)
        self.assertIn('[_token,serverTime,"BOUND_FAILURES",_failures]',coordinator)
        self.assertIn('[_token,serverTime,"INSUFFICIENT_STRENGTH",count _fit]',coordinator)
        self.assertIn('private _watchdog=(((_boundTimeout max 10)*4)+15) min 180',coordinator)
        self.assertNotIn('serverTime+180',coordinator)
        self.assertIn('private _maxConcurrent=(count _teams) min (_job getOrDefault ["boundMaxConcurrent",2])',coordinator)
        self.assertIn('for "_slot" from count _active to (_maxConcurrent-1)',coordinator)
        self.assertIn('_active pushBack [_group,_sequence,serverTime+_watchdog',coordinator)
        self.assertIn('distance2D _goal < 60',coordinator)
        self.assertIn('if ((_activeRaw select 0) isEqualType grpNull)',coordinator)
        start=source('cortexSupportBoundStart')
        self.assertIn('["teams",[_first,_second]]',start)
        self.assertIn('["SUPPORT_BOUND","FINAL"] select _final',start)
        self.assertIn('CBE_fnc_CortexDrillStart',start)
        self.assertIn('"supportHeld"',source('cortexCheckpoint'))
        for name in ['cortexRetreat','cortexRestoreCalm']:
            self.assertIn('"supportHeld"',source(name))
            self.assertIn('CBE_fnc_CortexSupportAck',source(name))
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _abort = _group getVariable ["CBE_Cortex_SupportAbort",[]]',maintain)
        self.assertIn('count _abort == 4 && {(_abort select 0) == _token}',maintain)
        self.assertIn('call _releaseSupport;',maintain)
        self.assertIn('_helper setVariable ["CBE_Cortex_SupportAbort",nil,true]',source('cortexSupportStep'))

    def test_contacted_peer_can_join_coordinated_assault_without_calm_rally_gate(self):
        apply=source('cortexSupportApply')
        self.assertIn('private _contactPeer = _phase in ["CONTACT","SECURITY"]',apply)
        self.assertIn('_phase == "CALM" || {_contactPeer}',apply)
        self.assertIn('[0.2,0.65] select _contactPeer',apply)
        self.assertNotIn('(_state getOrDefault ["phase","CALM"]) == "CALM"',apply)
        self.assertIn('private _supportEnabled',apply)
        self.assertIn('CBE_AIPass_Reinforce_Enable',apply)
        self.assertIn('CBE_AIPass_CoordinatedAssault_Enable',apply)
        server=source('cortexSupportServer')
        support_step=source('cortexSupportStep')
        maintain=source('cortexSupportMaintain')
        for text in [server,support_step,maintain]:
            self.assertIn('CBE_AIPass_Reinforce_Enable',text)
            self.assertIn('CBE_AIPass_CoordinatedAssault_Enable',text)
        self.assertIn('|| {!_supportEnabled}',maintain)
        tick=source('cortexGroupTick')
        self.assertIn('// Shared support discovery is needed by either ordinary reinforcement or coordinated assault.',tick)
        self.assertIn('if (!_holdFire && {!_nearTier} && {!_ordered}',tick)
        step=source('cortexFlankStep')
        self.assertIn('(_supportRole select 1) == (_drill get "supportSequence")',step)
        self.assertIn('CBE_AIPass_CoordinatedAssault_Enable',step)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        for check in ['COORD-inter-squad-role-exchange','COORD-concurrent-squad-bounds','COORD-concurrent-lanes-separated','COORD-inter-squad-physical-cover','COORD-intra-squad-physical-cover']:
            self.assertIn(check,qa)
        self.assertIn('["CBE_AIPass_PostContact_Enable",true]',qa)
        self.assertIn('_ti*_helperSize+_forEachIndex',qa)
        self.assertNotIn('_teamIndex*6+_forEachIndex',qa)
        self.assertIn('diag_tickTime-_movementAdmissionStarted >= 30',qa)
        self.assertIn('["COORD-movement-admission",!_movementAdmissionFailed',qa)
        self.assertIn('abs speed _x > 2',qa)
        self.assertIn('_shots-(_shotCounts select _i)',qa)
        operation=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombinedOperation.sqf').read_text(encoding='utf-8')
        self.assertIn('["CBE_AIPass_Reinforce_Enable",false]',operation)
        self.assertIn('["CBE_AIPass_Reinforce_MaxResponders",0]',operation)
        self.assertIn('COMBINED-OP-independent-coordination-gate',operation)
        self.assertIn('private _lastInfantryShotCount=0',operation)
        self.assertIn('_movingGroups == 0 && {_infantryShotCount == _lastInfantryShotCount}',operation)
        self.assertIn('longest infantry movement/fire lull=',operation)

    def test_coordinated_terminal_wait_requires_roles_and_leases_to_end(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        retired=text.split('private _allRetired=',1)[1].split('if (_allRetired)',1)[0]
        self.assertIn('serverTime < (_lease select 2)',retired)
        self.assertIn('"NOT_READY","RECOVERY_FAILED"',retired)
        self.assertIn('count _role == 5',retired)
        self.assertIn('COORD-both-teams-physical-advance',text)
    def test_combined_arrival_preserves_fire_permissions_and_reports_order_not_effect(self):
        text=source('cortexCombinedGroundStep')
        arrival=text.split('if (_arrivalDistance <= 70)',1)[1].split('if (time >=',1)[0]
        self.assertIn('unitCombatMode _gunner in ["YELLOW","RED"]',arrival)
        self.assertIn('CBE_fnc_CortexLineOfFireClear',arrival)
        for text in (arrival,source('cortexCombinedArmsLocal')):
            self.assertIn('_gunner getHideFrom _target',text)
            self.assertIn('[_gunner,_firePoint,_ammoObservation getOrDefault ["loadedMagazine",""]] call CBE_fnc_CortexLineOfFireClear',text)
            self.assertNotIn('aimPos _target',text)
            self.assertIn('_believed isNotEqualTo [0,0,0]',text)
        self.assertIn('_believed=+_position',source('cortexCombinedArmsLocal'))
        self.assertIn('_believed=+(_snapshot param [3,[],[[]]])',arrival)


        self.assertIn('CBE_fnc_CortexExternalOwner',arrival)
        self.assertIn('"ORDER_ISSUED"',arrival)
        self.assertIn('"CBE_Cortex_CombinedFireDecision"',arrival)
        self.assertLess(arrival.index('CBE_fnc_CortexLineOfFireClear'),arrival.index('_gunner doFire'))
    def test_combined_runtime_failures_retire_only_the_admitted_opportunity_after_cleanup(self):
        local=source('cortexCombinedArmsLocal')
        step=source('cortexCombinedGroundStep')
        server=source('cortexCombinedRejectServer')
        self.assertIn('["opportunity",+_opportunity]',local)
        finish=step.split('private _finish={',1)[1].split('if (isNull _group ||',1)[0]
        self.assertLess(finish.index('call CBE_fnc_CortexGroupMoveClear'),finish.index('remoteExecCall ["CBE_fnc_CortexCombinedRejectServer",2]'))
        for guard in ('_operationMatches','isEqualTo _snapshot','serverTime < (_snapshot select 5)'):
            self.assertIn(guard,finish)
        for reason in ('ASSET_LOST','ASSET_IMMOBILE','BLOCKED','MOVEMENT_REJECTED','NO_STATION_AMMO','BLOCKED_FIRE_LANE'):
            self.assertIn('"'+reason+'"',finish)
            self.assertIn('"'+reason+'"',server)
        self.assertIn('select (_fireDecision == "ORDER_ISSUED")',step)
        self.assertIn('simulationEnabled _asset && {!isObjectHidden _asset} && {!canMove _asset}',step)

    def test_combined_ground_continuation_and_result_require_complete_admitted_role(self):
        text=source('cortexCombinedGroundStep')
        role=text.split('private _roleCurrent={',1)[1].split('private _finish={',1)[0]
        for guard in ('(_snapshot select 0) isEqualTo _token','(_snapshot select 2) isEqualTo _target',
                      '(_snapshot select 4) == "GROUND_MANOEUVRE"','_job getOrDefault ["expiry",-1]',
                      'isEqualTo _snapshot'):
            self.assertIn(guard,role)
        finish=text.split('private _finish={',1)[1].split('if (isNull _group ||',1)[0]
        self.assertLess(finish.index('if (call _roleCurrent)'),finish.index('"CBE_Cortex_CombinedResult"'))
        self.assertLess(text.index('if !(call _roleCurrent) exitWith'),text.index('if (_arrivalDistance <= 70)'))
        self.assertIn('if (_laneClear && {call _roleCurrent})',text)
        self.assertIn('group _gunner == _group',text)
        self.assertIn('group _gunner != _group',source('cortexCombinedArmsLocal'))

    def test_combined_manoeuvre_checks_real_weapon_station_before_route_commitment(self):
        text=source('cortexCombinedArmsLocal')
        manoeuvre=text.split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[1].split('if (_role == "AIR_ATTACK") exitWith {',1)[0]
        admission=manoeuvre.split('private _start=',1)[0]
        for guard in ('group _gunner != _group','local _gunner','CBE_fnc_CortexCombatEffective',
                      'NO_FIRE_OPERATOR','NO_STATION_AMMO','NO_TARGET_AMMO',
                      '[_asset,_gunner,_target,_ammoObservation] call CBE_fnc_CortexGroundFireReady',
                      'remoteExecCall ["CBE_fnc_CortexCombinedRejectServer",2]'):
            self.assertIn(guard,admission)
        self.assertNotIn('doFire',admission)
        self.assertNotIn('reveal',admission)
        self.assertLess(manoeuvre.index('if (_capabilityRefusal != "") exitWith'),manoeuvre.index('CBE_fnc_CortexSelectAvenue'))
        self.assertLess(manoeuvre.index('NO_TARGET_AMMO'),manoeuvre.index('CBE_fnc_CortexOwnershipLease'))

    def test_combined_executor_suppresses_exact_owner_epoch_duplicates_before_effects(self):
        text=source('cortexCombinedArmsLocal')
        guard=text.index('CBE_Cortex_CombinedApplicationLocal')
        self.assertLess(text.index('isNotEqualTo _opportunity'),guard)
        self.assertLess(guard,text.index('private _asset=objNull'))
        self.assertLess(guard,text.index('_group reveal'))
        self.assertIn('[+_opportunity,clientOwner,_group getVariable ["CBE_AIPass_Epoch",0]]',text)
        self.assertIn('(_application select 0) isEqualTo _applicationIdentity',text)
        self.assertIn('private _applied=[_token,clientOwner,_application select 1]',text)
        self.assertEqual(text.count('setVariable ["CBE_Cortex_CombinedApplied",'),2)
        self.assertEqual(text.count('call _markApplied;'),10)
        fire=text.split('if (_role == "GROUND_FIRE") exitWith {',1)[1].split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[0]
        self.assertLess(fire.index('_gunner doFire'),fire.index('call _markApplied'))

    def test_combined_replay_retains_spent_recovery_and_original_observation_age(self):
        local=source('cortexCombinedArmsLocal')
        step=source('cortexCombinedGroundStep')
        journal=local.split('private _progress=_group getVariable ["CBE_Cortex_CombinedGroundProgress"',1)[1].split('// Route geometry belongs',1)[0]
        for guard in ('isEqualTo _opportunity','isEqualTo _asset','in [0,1]',
                      'finite (_progress select 3)','serverTime >= (_progress select 3)',
                      '_progressAt=time-(serverTime-(_progress select 3))'):
            self.assertIn(guard,journal)
        self.assertIn('["stalls",_stalls]',local)
        self.assertIn('if (_matchingProgress && {!_resumeGround}) exitWith',journal)
        self.assertIn('(_progress select 3) >= 0',journal)
        retry=step.split('// Spend before route reacquisition',1)[1]
        self.assertLess(retry.index('"CBE_Cortex_CombinedGroundProgress"'),retry.index('call CBE_fnc_CortexGroupMove'))
        self.assertIn('serverTime-(time-(_job get "progressAt"))',retry)
        self.assertIn('if (_stalls >= 1)',step)
        self.assertIn('[_group,_destination,55,"MOVE",_operationGeneration,true] call CBE_fnc_CortexGroupMove',retry)
        self.assertIn('_job set ["moveWaypoint",+_waypoint]',retry)
        self.assertIn('_job set ["moveReceipt",[count waypoints _group',retry)
        move=source('cortexGroupMove')
        self.assertIn('["_refreshOwned", false, [true]]',move)
        self.assertIn('if (_refreshOwned) then {_sameRequest=false}',move)
        refresh=move.split('if (_refreshOwned &&',1)[1].split('if (_sameRequest) exitWith',1)[0]
        for proof in ('!_sameRequest','_operationGeneration < 0','operationGeneration','currentWaypoint _group'):
            self.assertIn(proof,refresh)
        boundary=move.split('private _routeUnchanged={',1)[1].split('// Keep an established',1)[0]
        self.assertIn('!_refreshOwned || {currentWaypoint _group',boundary)


    def test_combined_owner_replay_preserves_destination_only_under_native_order_and_crew_receipts(self):
        local=source('cortexCombinedArmsLocal')
        self.assertLess(local.index('call CBE_fnc_CortexLocality'),local.index('private _applicationIdentity='))
        replay=local.split('private _resumeGround=false;',1)[1].split('// Route geometry belongs',1)[0]
        for guard in ('count _progress == 10','(_progress select 6) isEqualTo _nativeOrder',
                      '(_progress select 7) isEqualTo driver _asset','(_progress select 8) isEqualTo _operator'):
            self.assertIn(guard,replay)
        self.assertIn('if (_resumeGround) then {_selected=[+(_progress select 5)]} else {',local)
        self.assertLess(local.index('if (_matchingProgress && {!_resumeGround}) exitWith'),local.index('CBE_fnc_CortexOwnershipLease'))
        step=source('cortexCombinedGroundStep')
        self.assertEqual(step.count('+(_job get "nativeOrder"),_job get "driver",_job get "operator","ACTIVE"'),2)
        active=step.split('private _driver=driver _asset;',1)[1].split('if (isNull _target',1)[0]
        self.assertIn('_driver isNotEqualTo (_job getOrDefault ["driver",objNull])',active)
        self.assertIn('_operator isNotEqualTo (_job getOrDefault ["operator",objNull])',active)
        self.assertIn('group _driver != _group && {group _operator != _group}',active)
        self.assertIn('["OWNER_LOST"] call _finish',active)

    def test_combined_terminal_journal_cannot_restart_movement_or_fire_on_new_owner(self):
        local=source('cortexCombinedArmsLocal')
        ground=local.split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[1]
        terminal=ground.split('// A future firing role',1)[0]
        self.assertIn('in ["COMPLETE","FAILED"]',terminal)
        self.assertIn('isEqualTo _opportunity',terminal)
        self.assertIn('isEqualTo _asset',terminal)
        self.assertNotIn('doFire',terminal)
        self.assertNotIn('CortexGroupMove',terminal)
        self.assertIn('(_progress select 9) == "ACTIVE"',ground)
        step=source('cortexCombinedGroundStep')
        self.assertIn('_progress set [9,["FAILED","COMPLETE"] select (_reason == "POSITION_REACHED")]',step)

    def test_combined_replay_defers_split_crew_locality_and_checks_returning_owner_epoch(self):
        local=source('cortexCombinedArmsLocal')
        defer=local.split('// Group and crew locality can arrive',1)[1].split('if (_role == "AIR_ATTACK"',1)[0]
        self.assertIn('group _x == _group',defer)
        self.assertIn('!local _x',defer)
        self.assertIn('exitWith {false}',defer)
        self.assertNotIn('CortexCombinedRejectServer',defer)
        tick=source('cortexGroupTick')
        replay=tick.split('private _combinedRole=',1)[1].split('private _nearest =',1)[0]
        self.assertIn('CBE_Cortex_CombinedApplicationLocal',replay)
        self.assertIn('CBE_AIPass_Epoch',replay)
        self.assertIn('isNotEqualTo _combinedIdentity',replay)

    def test_combined_active_route_edits_retire_without_recovery_or_fallback(self):
        local=source('cortexCombinedArmsLocal')
        self.assertIn('["moveWaypoint",+_waypoint]',local)
        self.assertIn('["moveReceipt",[count waypoints _group,_waypoint select 1,',local)
        step=source('cortexCombinedGroundStep')
        route=step.split('private _routeCurrent={',1)[1].split('if (isNull _target',1)[0]
        for guard in ('isNotEqualTo _waypoint','_owned isNotEqualTo (_receipt select 2)',
                      'currentWaypoint _group == (_receipt select 1)','currentWaypoint _group != (_waypoint select 1)+1',
                      '_arrivalDistance > 70', 'isEqualTo ((_liveRows select 0) select [1])'):
            self.assertIn(guard,route)
        self.assertIn('["NATIVE_ORDER_CHANGED"] call _finish',route)
        self.assertIn('if !(call _routeCurrent) then {_fireDecision="NATIVE_ORDER_CHANGED"}',step)
        fallback=step.split('_reason in [',1)[1].split(']',1)[0]
        self.assertNotIn('NATIVE_ORDER_CHANGED',fallback)

    def test_combined_audit_requires_local_native_projectile_toward_reported_contact(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombinedArms.sqf').read_text(encoding='utf-8')
        sampler=text.split('private _installStationObserver={',1)[1].split('private _apc=createVehicle',1)[0]
        for guard in ('!local _unit','addEventHandler ["FiredMan"','gunner _vehicle != _unit',
                      'velocity _projectile','getPosASL _projectile','_role param [3',
                      'count _records > 128'):
            self.assertIn(guard,sampler)
        self.assertNotIn('createVehicle',sampler)
        self.assertNotIn('setVelocity',sampler)
        shot=text.split('["COMBINED-ground-actual-fire"',1)[1].split('["COMBINED-ground-manoeuvre-physical-travel"',1)[0]
        self.assertIn('(_x select 1) == _fireOperator',shot)
        self.assertIn('(_x select 6) == _fireToken',shot)
        self.assertIn('vectorMagnitude _course > 1',shot)
        self.assertIn('>= cos 15',shot)

    def test_combined_enroute_capability_reassessment_is_finite_and_dormancy_preserves_expiry(self):
        text=source('cortexCombinedGroundStep')
        block=text.split('// Dormancy/locality convergence',1)[1].split('if (_arrivalDistance > 70',1)[0]
        self.assertIn('exitWith {1}',block)
        self.assertIn('!local _stationOperator',block)
        defer=block.split('private _stationOperator=',1)[1].split('private _capabilityFailure=',1)[0]
        self.assertIn('[_stationOperator] call CBE_fnc_CortexCombatEffective',defer)
        self.assertIn('_job set ["capabilityAt",serverTime+4]',block)
        for reason in ('NO_FIRE_PLATFORM','NO_FIRE_OPERATOR','NO_STATION_AMMO','NO_TARGET_AMMO'):
            self.assertIn(reason,block)
            self.assertIn(reason,source('cortexCombinedRejectServer'))
        self.assertNotIn('reveal',block)
        self.assertNotIn('doFire',block)
        self.assertNotIn('set ["expiry"',block)
        self.assertLess(text.index('serverTime >= (_job getOrDefault ["expiry"'),text.index('// Dormancy/locality convergence'))
        self.assertIn('["capabilityAt",serverTime+4]',source('cortexCombinedArmsLocal'))

    def test_fire_control_uses_strict_movement_reservations_without_disabling_native_fire(self):
        text=source('cortexFireControl')
        self.assertIn('private _reservedActors=_eligible select {[_x] call CBE_fnc_CortexActorMoveReserved};',text)
        self.assertIn('private _members = _eligible - _drillUnits;',text)
        self.assertIn('currentCommand _x in ["MOVE","GET IN","GET OUT"',text)
        self.assertIn('if (_members isEqualTo []) exitWith {0}',text)
        predicate=source('cortexActorMoveReserved')
        for proof in ('_lease isEqualTo []','count _lease == 3','finite _x','finite (_lease select 2)','time >= (_lease select 2)'):
            self.assertIn(proof,predicate)
        self.assertNotIn('disableAI',predicate)

    def test_combined_ground_preserves_protected_individual_tasks(self):
        guard=source('cortexActorFireTaskAvailable')
        self.assertIn('CBE_fnc_CortexActorMoveReserved',guard)
        for command in ('REARM','HEAL','GET IN','GET OUT','SCRIPTED','REPAIR','REFUEL','CARRY SOLDIER'):
            self.assertIn('"'+command+'"',guard)
        self.assertNotIn('doTarget',guard)
        self.assertNotIn('setVariable',guard)
        self.assertIn('fleeing _actor',guard)
        fire=source('cortexFireControl')
        self.assertIn('!fleeing _x',fire)
        self.assertEqual(fire.count('[_unit] call CBE_fnc_CortexActorFireTaskAvailable'),2)
        self.assertLess(fire.index('call CBE_fnc_CortexActorFireTaskAvailable'),fire.index('_unit doTarget _closest'))
        suppress=fire.split('private _aimASL=[_unit,_targetASL,20]',1)[1]
        self.assertLess(suppress.index('call CBE_fnc_CortexActorFireTaskAvailable'),suppress.index('_unit doSuppressiveFire'))
        anti=source('cortexAntiArmour').split('private _actorAvailable={',1)[1].split('private _mayRelocate',1)[0]
        self.assertIn('!fleeing _actor',anti)
        admission=source('cortexCombinedArmsLocal')
        self.assertEqual(admission.count('[_gunner] call CBE_fnc_CortexActorFireTaskAvailable'),2)
        step=source('cortexCombinedGroundStep')
        self.assertIn('[_stationOperator] call CBE_fnc_CortexActorFireTaskAvailable',step)
        self.assertIn('&& {[_gunner] call CBE_fnc_CortexActorFireTaskAvailable}',step)

    def test_combined_ground_refusal_authenticates_without_mutating_movement(self):
        text=source('cortexCombinedRejectServer')
        self.assertIn('CBE_fnc_HeadlessResolveSender',text)
        self.assertIn('_current isNotEqualTo _snapshot',text)
        self.assertIn('!((count _snapshot) in [7,8])',text)
        self.assertNotIn('CBE_fnc_OperationCancel',text)
        self.assertNotIn('doMove',text)
        self.assertNotIn('doFollow',text)
        local=source('cortexCombinedArmsLocal')
        self.assertEqual(local.count('remoteExecCall ["CBE_fnc_CortexCombinedRejectServer",2]'),11)
    def test_combined_ground_native_ignore_prevents_reveal_and_retires_active_route(self):
        local=source('cortexCombinedArmsLocal')
        step=source('cortexCombinedGroundStep')
        server=source('cortexCombinedRejectServer')
        check='(_contactObserver targetKnowledge _target) param [7,false,[true]]'
        self.assertIn(check,local)
        self.assertIn(check,step)
        self.assertLess(local.index(check),local.index('private _applicationIdentity='))
        self.assertLess(step.index('["TARGET_IGNORED"] call _finish'),step.index('private _stationOperator=gunner _asset;'))
        self.assertIn('_reason in ["TARGET_IGNORED",',step)
        self.assertIn('_reason in ["TARGET_IGNORED",',server)
        self.assertIn('local _contactObserver',local)
        self.assertIn('local _contactObserver',step)

    def test_combined_ground_refusal_producer_reasons_reach_server_retirement(self):
        local=source('cortexCombinedArmsLocal')
        server=source('cortexCombinedRejectServer')
        emitted=set(re.findall(r'_(?:fire|capability)Refusal\s*=\s*"([^"\n]+)"',local))
        emitted.update(re.findall(r'\[_group,_opportunity,"([^"\n]+)",clientOwner\] remoteExecCall \["CBE_fnc_CortexCombinedRejectServer",2\]',local))
        accepted=re.search(r'_reason in \[(.*?)\]',server)
        self.assertIsNotNone(accepted)
        allowed=set(re.findall(r'"([^"\n]+)"',accepted.group(1)))
        self.assertIn('NO_STATION_AMMO',emitted)
        self.assertLessEqual(emitted,allowed)

    def test_combined_ground_fallback_consumes_exact_refusal_without_new_lifetime(self):
        reject=source('cortexCombinedRejectServer')
        fallback=source('cortexCombinedGroundFallbackServer')
        self.assertLess(reject.index('CBE_fnc_HeadlessResolveSender'),reject.index('call CBE_fnc_CortexCombinedGroundFallbackServer'))
        self.assertLess(reject.index('_current isNotEqualTo _snapshot'),reject.index('call CBE_fnc_CortexCombinedGroundFallbackServer'))
        self.assertLess(reject.index('"CBE_Cortex_CombinedRole",nil'),reject.index('call CBE_fnc_CortexCombinedGroundFallbackServer'))
        for guard in ('_storedToken != _token','_storedTarget != _target','_storedPosition isNotEqualTo _position',
                      '_storedExpiry != _expiry','CBE_Cortex_CombinedGroundConsumed','count _candidates > 32'):
            self.assertIn(guard,fallback)
        self.assertIn('_cursor=_cursor+1',fallback)
        self.assertIn('_role,_expiry,+_context',fallback)
        self.assertIn('(_expiry-serverTime) max 0',fallback)
        self.assertNotIn('serverTime+',fallback)
        for command in ('doMove','doFollow','forceSpeed','reveal','CortexGroupMove','OperationCancel'):
            self.assertNotIn(command,fallback)

    def test_combined_ground_fallback_pool_is_ready_before_dispatch_and_preserves_live_roles(self):
        server=source('cortexCombinedArmsServer')
        fallback=source('cortexCombinedGroundFallbackServer')
        self.assertLess(server.index('"CBE_Cortex_CombinedGroundFallback"'),server.index('remoteExecCall ["CBE_fnc_CortexCombinedArmsLocal"'))
        self.assertIn('((count _groundCandidates) min 32)',server)
        self.assertIn('["CBE_Cortex_CombinedGroundFallback",_originalGround]',server)
        self.assertIn('_requester setVariable [_variable,nil,true]',server)
        self.assertIn('!((count _live) in [7,8]) || {serverTime >= (_live select 5)}',fallback)
        self.assertNotIn('(_live select 0) == _token',fallback)
        self.assertIn('_target distance2D _position > 75',fallback)
        self.assertIn('group _commander == _candidate',fallback)
        self.assertIn('group _driver == _candidate',fallback)
        self.assertIn('CBE_Convoy_Active',fallback)
        self.assertIn('CBE_fnc_CortexGroupTransmitter',fallback)
        self.assertNotIn('nearEntities',fallback)
        self.assertIn('groupOwner _replacement',fallback)

    def test_combined_ground_admission_preserves_other_live_intents(self):
        text=source('cortexCombinedArmsLocal')
        self.assertIn('_role == "GROUND_MANOEUVRE" && {count _existingOperation > 0}',text)
        self.assertIn('"OTHER_INTENT_ACTIVE"',text)
        self.assertIn('"objective",objNull]) isNotEqualTo _target',text)
        self.assertLess(text.index('"OTHER_INTENT_ACTIVE"'),text.index('_group reveal'))
        self.assertLess(text.index('"OTHER_INTENT_ACTIVE"'),text.index('call CBE_fnc_OperationStart'))
    def test_combined_dispatch_preserves_other_live_contact_reservations(self):
        text=source('cortexCombinedArmsServer')
        self.assertIn('private _existingRole=_candidate getVariable ["CBE_Cortex_CombinedRole",[]]',text)
        self.assertIn('serverTime >= (_existingRole select 5)',text)
        self.assertIn('(_existingRole select 0) == _token',text)
        self.assertLess(text.index('private _existingRole='),text.index('_candidate setVariable ["CBE_Cortex_CombinedRole"'))
    def test_small_coordinated_fixture_uses_size_aware_handover_quorum(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('ceil (_helperSize*0.6)',text)
        self.assertNotIn('count _members != 6',text)
        self.assertNotIn('_arrived < 4',text)
        self.assertNotIn('_progressed < 4',text)
        self.assertIn('count _members != _helperSize',text)
        self.assertIn('COORD-both-teams-physical-advance',text)
    def test_coordinated_bound_uses_existing_operation_generation_and_epoch(self):
        text=source('cortexSupportBoundStart')
        self.assertIn('"supportOperationGeneration",-1',text)
        self.assertIn('"operationGeneration",_generation',text)
        self.assertIn('"ownerEpoch",_ownerEpoch',text)
        self.assertIn('(_operation getOrDefault ["intent",""]) != "COORDINATED_ASSAULT"',text)
        self.assertNotIn('call CBE_fnc_OperationStart',text)
    def test_support_release_retires_only_matching_bound_before_operation_cleanup(self):
        text=source('cortexSupportMaintain')
        release=text.split('private _releaseSupport={',1)[1].split('// The cached operation step',1)[0]
        self.assertIn('(_outgoingDrill getOrDefault ["supportToken",""]) == _token',release)
        self.assertIn('[_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd',release)
        self.assertLess(release.index('CBE_fnc_CortexFlankEnd'),release.index('call _finishOperation'))
    def test_building_replacement_rebases_approach_without_changing_room_sequence(self):
        text=source('buildingOperationStep')
        replacement=text.split('private _replacement=_reserves select _replacementIndex;',1)[1].split('Clear pair %1 reinforced',1)[0]
        self.assertIn('_state set [13,1e12]',replacement)
        self.assertIn('_state set [14,[]]',replacement)
        self.assertNotIn('_state set [0,',replacement)
        self.assertNotIn('recoveryAttempts',replacement)
    def test_building_room_retries_preserve_security_partner_and_committed_path(self):
        text=source('buildingOperationStep')
        self.assertNotIn('_issue || {_openedDoor}',text)
        self.assertIn('if (_unitIssue && {_settingsReady} && {call _mayIssueMovement} && {[_unit] call _actorTaskFree})',text)
        self.assertIn('(_x == _point || {_approachingEntry && {!(_x in (_job getOrDefault ["enteredActors",[]]))}}) && {[_x] call _actorAvailable}',text)
    def test_coordinated_fixture_requester_can_initiate_support(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('_requester setCombatMode "YELLOW";',qa)
        self.assertLess(qa.index('_requester setCombatMode "YELLOW";'),qa.index('COORD-natural-contact'))
        tick=source('cortexGroupTick')
        self.assertIn('private _holdFire=combatMode _group in ["BLUE","GREEN"];',tick)
        self.assertIn('private _nativeHoldFire=_holdFire;',tick)
        self.assertIn('_holdFire=_holdFire || {behaviour _leader == "STEALTH"}',tick)
        self.assertIn('if (!_nativeHoldFire && {["CBE_AIPass_ContactReports_Enable",true]',tick)
        posture=source('dangerReact').split('private _postureResult=',1)[1]
        self.assertLess(posture.index('behaviour _postureActor == "STEALTH"'),posture.index('_group setCombatMode _desiredCombat'))
        self.assertIn('if (!_holdFire && {_visible isNotEqualTo []} && {!_ordered}',tick)
    def test_coordinator_geometry_retry_is_finite_and_element_scoped(self):
        text=source('cortexSupportCoordinateStep')
        self.assertIn('"routeFailuresByToken",createHashMap',text)
        self.assertIn('_routeFailuresByToken deleteAt _token',text)
        self.assertIn('if (_routeFailures >= 2)',text)
        self.assertIn('"NO_SAFE_BOUND",_routeFailures',text)
        self.assertIn('_retired pushBackUnique _token',text)
        self.assertIn('"CBE_Cortex_SupportRetryAfter",serverTime+8',text)
    def test_coordinator_rejected_route_does_not_starve_other_elements(self):
        text=source('cortexSupportCoordinateStep')
        selection=text.split('for "_offset"',1)[1].split('_job set ["boundCursor"',1)[0]
        self.assertIn('if (!isNull _next) exitWith {};',selection)
        self.assertIn('} < 0}) then {',selection)
        self.assertNotIn('} < 0}) exitWith {',selection)
        self.assertLess(selection.index('if (_selected isNotEqualTo [])'),selection.index('_next=_group'))
    def test_support_ack_rejects_expired_exact_reservations(self):
        ack=source('cortexSupportAck')
        self.assertIn('count _lease != 6',ack)
        self.assertIn('_lease isNotEqualTo _snapshot',ack)
        self.assertIn('_accepted=_accepted && {serverTime < (_lease select 2)}',ack)
        self.assertIn('serverTime < (_job get "expiry")',ack)
        self.assertLess(ack.index('_accepted=_accepted'),ack.index('private _prepared='))
    def test_legacy_support_hold_restoration_yields_individual_ownership(self):
        for name in ['cortexSupportMaintain','cortexRetreat','cortexRestoreCalm']:
            text=source(name)
            actor='_unit' if name == 'cortexRestoreCalm' else '_x'
            self.assertIn('remoteControlled '+actor,text)
            self.assertIn('['+actor+'] call CBE_fnc_CortexExternalOwner',text)
            self.assertIn('['+actor+'] call CBE_fnc_CompatibilityExternalControl',text)
            self.assertIn('!isPlayer '+actor,text)
    def test_coordinated_cover_does_not_timeout_or_repeat_stop_commands(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('_operationState == "STALLED" && {!(_state getOrDefault ["assaulting",false])}',maintain)
        self.assertIn('private _coverIdentity=[_token,_role select 1];',maintain)
        self.assertIn('isNotEqualTo _coverIdentity',maintain)
        self.assertIn('_state deleteAt "supportCoverIdentity"',maintain)
        cover=maintain.split('private _coverIdentity=',1)[1]
        self.assertIn('CBE_fnc_CompatibilityExternalControl',cover)
        self.assertIn('remoteControlled _x',cover)
        self.assertIn('CBE_fnc_CortexExternalOwner',cover)
    def test_support_operation_records_position_not_coordinate_scalar(self):
        apply=source('cortexSupportApply')
        self.assertIn('private _objective=if (_attackAllowed) then {+_attack} else {+_rally};',apply)
        self.assertIn('_objective,_footFit,[+_objective],"ACCEPTED"',apply)
        self.assertNotIn('_attack select ((count _attack)-1)',apply)
    def test_assault_preserves_group_attack_setting(self):
        apply=source('cortexSupportApply')
        self.assertNotIn('enableAttack false',apply)
        self.assertNotIn('set ["baseAttack",attackEnabled _group]',apply)
        self.assertNotIn('enableAttack false',source('cortexSupportBoundStart'))
        maintain=source('cortexSupportMaintain')
        self.assertEqual(1, maintain.count('call _restoreAttack;'))
        # Support release has distinct lease, feature and ownership-transition paths.  Do not
        # couple this preservation check to their exact count as finite-operation cleanup adds
        # valid cancellation reasons without changing group attack ownership.
        self.assertGreaterEqual(maintain.count('call _releaseSupport;'),2)
        self.assertIn('enableAttack (_state getOrDefault ["baseAttack",true])', maintain)
        self.assertIn('"baseAttack", "attackChanged"', source('cortexCheckpoint'))
        self.assertIn('enableAttack (_state getOrDefault ["baseAttack",true])', source('cortexRestoreCalm'))

    def test_support_reservation_requires_a_shared_executable_mode(self):
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        apply=source('cortexSupportApply')
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _requesterReinforce',server)
        self.assertIn('private _requesterCoordinated',server)
        self.assertIn('[_configuredMaximum,_configuredMaximum max 2] select _requesterCoordinated',server)
        for text in [step,apply,maintain]:
            self.assertIn('private _sharedReinforce',text)
            self.assertIn('private _sharedCoordinated',text)
            self.assertIn('_sharedReinforce || {_sharedCoordinated}',text)
        self.assertIn('private _directCoordinationPending = _attack isEqualTo [] && {_sharedCoordinated}',apply)
        self.assertIn('private _attackAllowed = _attack isNotEqualTo [] && {_sharedCoordinated}',apply)

    def test_zeus_handover_preserves_replacement_attack_setting(self):
        restore=source('cortexRestoreCalm')
        flank_end=source('cortexFlankEnd')
        self.assertIn('if (!_yieldToExternal && {_state getOrDefault ["attackChanged",false]})',restore)
        self.assertIn('!(_reason in ["ZEUS","OWNERSHIP_LOST","ROLE_HANDOVER"])',flank_end)
        self.assertIn('if (_mayCommand && {_state getOrDefault ["attackChanged",false]})',flank_end)

    def test_zeus_takeover_releases_explicit_orders_without_waypoint(self):
        text=source('cortexGroupTick').split('if (!_generallyEligible)')[1].split('// Survivor regroup')[0]
        self.assertIn('if ([_group] call CBE_fnc_CortexZeusHeld) then', text)
        for name in ['CortexGarrisonRelease','CortexDefendRelease','CortexClearRelease']:
            self.assertIn('call CBE_fnc_'+name, text)
        self.assertNotIn('getVariable ["CBE_AIPass_ZeusWaypoints"', text)

    def test_garrison_duck_cleanup_preserves_later_stance(self):
        apply=source('cortexGarrisonApplyLocal')
        release=source('cortexGarrisonRelease')
        self.assertIn('if (unitPos _unit == (_unit getVariable ["CBE_Cortex_GarrisonDuckStance", ""]))', apply)
        self.assertIn('call CBE_fnc_CortexGarrisonSettings',release)
        self.assertIn('[_key,_native,_pair select 1] call _same',source('actorSettings'))
        self.assertIn('!([group _unit] call CBE_fnc_CortexIsEligible)', apply)
        delayed=apply.split('params ["_unit", "_until", "_priorStance",')[1].split('}, [_unit,_until,_priorStance,')[0]
        self.assertIn('&& {[group _unit] call CBE_fnc_CortexIsEligible}', delayed)
        self.assertIn('setVariable ["CBE_Cortex_GarrisonDuckStance",nil,true]',apply)
        self.assertIn('forEach _mirrors',source('cortexGarrisonSettings'))

    def test_surrender_releases_orders_before_captive_handover(self):
        text=source('cortexSurrender')
        for guard in ['!local _group','CBE_fnc_CortexIsEligible','CBE_AIPass_Surrender_Enable']:
            self.assertLess(text.index(guard),text.index('createVehicle'))
        for release in ['CortexGarrisonRelease','CortexDefendRelease','CortexClearRelease','CortexReleaseGroup']:
            self.assertLess(text.index(release),text.index('call ace_captives_fnc_setSurrendered'))
        self.assertIn('CBE_fnc_CortexCombatEffective',text)
        preflight=text.split('// Release movement and stance ownership',1)[0]
        for marker in ['ace_medical_ai_healQueue','CARRY SOLDIER','SCRIPTED','call _serviceBusy']:
            self.assertIn(marker,preflight)
        self.assertIn('&& {!([_unit] call _serviceBusy)}',text)
        self.assertNotIn('fleeing _',text)

    def test_grenade_evasion_admission_and_cleanup_require_strict_ownership(self):
        text=source('cortexGrenadeCheck')
        admission=text.split('private _grenade =',1)[1]
        self.assertLess(admission.index('call CBE_fnc_CortexActorMoveReserved'),admission.index('_unit doMove _spot'))
        self.assertNotIn('count _actorMove != 3',admission)
        cleanup=text.split('if (_regroup isNotEqualTo []) exitWith {',1)[1].split('private _grenade =',1)[0]
        self.assertIn('_actorMove isEqualTo ["GRENADE_EVASION",_spot,_expires]',cleanup)
        self.assertNotIn('(_actorMove select 1) distance2D',cleanup)
        self.assertLess(cleanup.index('_actorMove isEqualTo'),cleanup.index('if (_ownsEvasion && {local _unit})'))
        self.assertLess(cleanup.index('if (_ownsEvasion && {local _unit})'),cleanup.index('setVariable ["CBE_Cortex_ActorMove",nil]'))

    def test_grenade_evasion_regroup_does_not_overwrite_new_actions(self):
        text=source('cortexGrenadeCheck')
        callback=text.split('if (_regroup isNotEqualTo []) exitWith {')[1].split('private _grenade =',1)[0]
        for guard in ['GRENADE_EVASION','group _unit == _group','vehicle _unit == _unit','CBE_fnc_CortexCombatEffective','CBE_AIPass_ZeusHold','expectedDestination _unit','_unit in (_drill']:
            self.assertLess(callback.index(guard),callback.index('doFollow'))
        self.assertLess(callback.index('doFollow'),callback.index('setVariable ["CBE_Cortex_ActorMove",nil]'))
        self.assertIn('if (_ownsEvasion && {local _unit}) then {',callback)
        for guard in ['_actorMove isEqualTo ["GRENADE_EVASION",_spot,_expires]','CBE_OperationGeneration','CBE_AIPass_Epoch','CortexExternalOwner','remoteControlled','currentCommand']:
            self.assertLess(callback.index(guard),callback.index('doFollow'))
        self.assertIn('setVariable ["CBE_Cortex_ActorMove",["GRENADE_EVASION"',text)
        self.assertIn('!([_unit] call CBE_fnc_CortexActorMoveReserved)',text)
        self.assertIn('setVariable ["CBE_Cortex_ActorMove",nil]',callback)
        self.assertIn('[CBE_fnc_CortexGrenadeCheck,createHashMapFromArray [["regroup",_regroupActors]],6] call CBE_fnc_CortexQueueJob',text)
        self.assertIn('"CBE_AIPass_GrenadeEvasion_Enable",true] call CBE_fnc_CortexFeatureEnabled',text)
        self.assertNotIn('CBA_fnc_waitAndExecute',text)
        for region in (callback,text.split('private _grenade =',1)[1]):
            for proof in ('simulationEnabled _unit','!isObjectHidden _unit','!fleeing _unit','ace_medical_ai_healQueue'):
                self.assertIn(proof,region)
        for proof in ('CBE_AIPass_ClearBuilding','CBE_AIPass_Garrison','CBE_AIPass_Defend',
                      '"responding",false','"assaulting",false','"participants",[]','!_taskOwned'):
            self.assertLess(callback.index(proof),callback.index('doFollow'))
        self.assertLess(callback.index('doFollow'),callback.index('setVariable ["CBE_Cortex_ActorMove",nil]'))

    def test_grenade_evasion_temporarily_outranks_support_cover_hold(self):
        grenade=source('cortexGrenadeCheck')
        self.assertIn('private _supportHeld = _state getOrDefault ["supportHeld",[]]',grenade)
        self.assertIn('_unit checkAIFeature "PATH" || {_supportPathOwned}',grenade)
        self.assertIn('(_unit getVariable ["CBE_Cortex_SupportPathHold",false]) isEqualTo true',grenade)
        self.assertLess(grenade.index('if (_supportPathOwned) then'),grenade.index('_unit enableAI "PATH"'))
        self.assertLess(grenade.index('if (!(_unit checkAIFeature "PATH")) then {continue}'),grenade.index('_unit doMove _spot'))
        self.assertIn('_unit enableAI "PATH"',grenade)
        self.assertIn('_state set ["supportHeld",_supportHeld-[_unit]]',grenade)
        maintain=source('cortexSupportMaintain')
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',maintain)
        self.assertNotIn('count _actorMove != 3',maintain)

    def test_tactical_drills_do_not_consume_reserved_actors(self):
        for name in ['cortexFlankStart','cortexAdvanceStart','cortexAssaultStart']:
            text=source(name)
            self.assertIn('[_x] call CBE_fnc_CortexActorFireTaskAvailable',text)
            self.assertNotIn('count _actorMove != 3 || {time >= (_actorMove select 2)}',text)
        self.assertIn('[_actor] call CBE_fnc_CortexActorMoveReserved',source('cortexActorFireTaskAvailable'))
        guard=source('cortexActorMoveReserved')
        for required in ['!local _actor','_lease isEqualTo []','_lease isEqualType []',
                         'count _lease == 3','(_lease select 0) isEqualType ""',
                         'count (_lease select 1) == 3','finite (_lease select 2)',
                         'findIf {!(_x isEqualType 0) || {!finite _x}} < 0','!_expired']:
            self.assertIn(required,guard)
        self.assertNotIn('setVariable',guard)

    def test_queued_grenade_rechecks_takeover_and_frag_safety(self):
        text=source('cortexThrowGrenade')
        callback=text.split('params ["_unit", "_muzzle", "_magazine"')[1]
        for guard in ['CBE_fnc_CortexCombatEffective','CBE_fnc_CortexIsEligible','CBE_AIPass_ZeusHold','_magazine in magazines _unit','_distance < 8','_distance > 40','nearEntities ["CAManBase",_safetyRadius]']:
            self.assertIn(guard,callback)
        self.assertLess(callback.index('CBE_AIPass_ZeusHold'),callback.index('forceWeaponFire'))
        self.assertLess(callback.index('!= _drillToken'),callback.index('forceWeaponFire'))
        policy=text.split('private _fireAllowed=',1)[1].split('if !([_unit,_kind] call _fireAllowed)',1)[0]
        for guard in ('checkAIFeature "FIREWEAPON"','!fleeing _actor',
                      '_type != "FRAG"','unitCombatMode _actor in ["YELLOW","RED"]',
                      'combatMode group _actor in ["YELLOW","RED"]'):
            self.assertIn(guard,policy)
        self.assertLess(callback.index('FIRE_POLICY_OR_FLIGHT_CHANGED'),callback.index('_unit doWatch _towards'))
        self.assertIn('_ownerEpoch,_contextMatches,_fireAllowed]] call CBA_fnc_execNextFrame',text)
        self.assertIn('"_contextMatches", "_fireAllowed", ["_aimIssued",false,[true]]]',callback)

    def test_retreat_releases_drill_before_capturing_attack_control(self):
        text=source('cortexRetreat')
        self.assertLess(text.index('call CBE_fnc_CortexFlankEnd'),text.index('call CBE_fnc_OperationAttackPolicy'))
        self.assertLess(text.index('call CBE_fnc_OperationAttackPolicy'),text.index('call CBE_fnc_CortexGroupMove;'))
        self.assertIn('ATTACK_POLICY_REFUSED',text)
        self.assertNotIn('_group enableAttack false',text)
        self.assertNotIn('set ["baseAttack"',text)
        self.assertIn('_state set ["behaviourChanged",true]',text)
        self.assertIn('_state set ["baseBehaviour",_priorBehaviour]',text)
        self.assertLess(text.index('private _priorBehaviour=behaviour _leader'),text.index('_group setBehaviour "AWARE"'))
        self.assertLess(text.index('if (behaviour _leader == "AWARE") then'),text.index('_state set ["baseBehaviour",_priorBehaviour]'))

    def test_retreat_keeps_fire_while_leasing_engine_pursuit_mode(self):
        retreat=source('cortexRetreat')
        restore=source('cortexRestoreCalm')
        checkpoint=source('cortexCheckpoint')
        self.assertIn('combatMode _group == "RED"',retreat)
        tick=source('cortexGroupTick').split('case "RETREAT": {',1)[1]
        expiry=tick.index('if (_withdrawOwner && {_now-(_state get "phaseStart") > 120}) exitWith {')
        self.assertLess(expiry,tick.index('call CBE_fnc_CortexMorale'))
        self.assertLess(expiry,tick.index('call CBE_fnc_RecoveryStep'))
        self.assertLess(expiry,tick.index('call CBE_fnc_CortexSelectAvenue'))
        self.assertIn('WITHDRAWAL_ATTACK_POLICY_CHANGED',tick[:expiry])
        self.assertNotIn('enableAttack',tick[:expiry])
        self.assertIn('[_group,_generation] call CBE_fnc_CortexGroupMoveClear',tick)
        self.assertIn('[_timedOut] call _endWithdrawal',tick)
        self.assertNotIn('_generation=_state getOrDefault ["withdrawOperationGeneration",-1]',tick)
        self.assertIn('_state set ["retreatCombatMode",["RED","YELLOW"]]',retreat)
        admission=retreat.split('// Use a local combat-effective anchor',1)[0]
        self.assertIn('fleeing _x',admission)
        self.assertIn('ace_medical_ai_healQueue',admission)
        self.assertNotIn('call CBE_fnc_CortexGroupPostureTaskAvailable',admission)
        self.assertNotIn('CortexCombatEffective',admission)
        policy=retreat.split('// Only current native-confirmed group writes',1)[1].split('if (!_resuming) then',1)[0]
        self.assertIn('isNil {',policy)
        self.assertIn('call CBE_fnc_CortexGroupPostureTaskAvailable',policy)
        self.assertIn('if (combatMode _group == "YELLOW") then',policy)
        self.assertIn('if (speedMode _group == "FULL") then',policy)
        self.assertIn('_group setCombatMode "YELLOW"',retreat)
        self.assertNotIn('_group setCombatMode "BLUE"',retreat)
        self.assertIn('combatMode _group == (_retreatModeLease select 1)',restore)
        self.assertIn('_group setCombatMode (_retreatModeLease select 0)',restore)
        self.assertIn('!_yieldToExternal',restore)
        self.assertIn('"retreatCombatMode"',checkpoint)
        self.assertIn('"retreatCombatMode"',restore.split('{_state deleteAt _x} forEach [',1)[1])

    def test_every_explicit_infantry_order_transitions_into_physical_retreat(self):
        tick=source('cortexGroupTick')
        block=tick.split('private _retreatStarted=false',1)[1].split('_state set ["armourSeen"',1)[0]
        for release in ['CortexGarrisonRelease','CortexDefendRelease','CortexClearRelease']:
            self.assertIn(f'call CBE_fnc_{release}',block)
        self.assertEqual(1,block.count('call CBE_fnc_CortexRetreat'))
        self.assertGreater(block.index('call CBE_fnc_CortexRetreat'),block.index('switch (true)'))
        self.assertIn('if (_retreatStarted) exitWith {}',block)

    def test_infantry_withdrawal_releases_support_holds_and_owns_its_route(self):
        retreat=source('cortexRetreat')
        support=retreat.split('private _supportHeld=',1)[1].split('{_state deleteAt _x}',1)[0]
        self.assertIn('_x enableAI "PATH"',support)
        self.assertIn('_x doFollow _leader',support)
        self.assertIn('if (_pathOwned && {local _x}',support)
        self.assertIn('!fleeing _x',support)
        self.assertIn('CBE_fnc_CortexActorMoveReserved',support)
        self.assertIn('if (_x checkAIFeature "PATH") then',support)
        self.assertIn('CBE_Cortex_SupportPathHold',support)
        self.assertIn('_state set ["movementLease",["INFANTRY_WITHDRAW",time+_remaining]]',retreat)
        self.assertLess(retreat.index('CortexGroupMove'),retreat.index('["INFANTRY_WITHDRAW",time+_remaining]'))

    def test_infantry_withdrawal_requires_progress_and_replans_without_teleport(self):
        retreat=source('cortexRetreat')
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        for marker in ['set ["retreatStart",_origin]',
                       'set ["retreatTarget",_point]',
                       'set ["retreatProgress",[time,_bestTravel,_replans]]']:
            self.assertIn(marker,retreat)
        retreat_case=tick.split('case "RETREAT":')[1]
        for marker in ['_travel < 30','_now-_progressAt >= 15','_travel >= _bestTravel+3','_replans < 4',
                       'forEach [30,-30,60,-60]','_candidate distance2D _target >= 20',
                       'call CBE_fnc_CortexSelectAvenue','CBE_fnc_CortexGroupMove',
                       'CBE_Cortex_Withdrawal']:
            self.assertIn(marker,retreat_case)
        self.assertNotIn('setPos',retreat_case)
        progress=retreat_case.split('private _start =',1)[1].split('private _progress =',1)[0]
        self.assertIn('_withdrawalIntent param [3,[],[[]]]',progress)
        self.assertIn('private _travel=0',progress)
        self.assertIn('*_axisX',progress)
        self.assertIn('*_axisY)/_axisLength) max 0',progress)
        self.assertNotIn('_leader distance2D _start',progress)

        self.assertIn('["INFANTRY","VEHICLE"] select (_withdrawKind == "VEHICLE_WITHDRAW")',retreat_case)
        self.assertIn('[_origin,_candidateRoutes,_enemyPos,[],objNull,_mobility,_screenPlatform] call CBE_fnc_CortexSelectAvenue',retreat_case)
        self.assertIn('if (_mobility == "VEHICLE") then {[]} else {_candidateRoutes param [0,[]]}',retreat_case)

        self.assertIn('"retreatStart", "retreatTarget", "retreatProgress"',restore)
        self.assertIn('setVariable ["CBE_Cortex_Withdrawal",nil,true]',restore)
        self.assertIn('_operationState=[_group,_generation,3,15] call CBE_fnc_OperationStep',retreat_case)
        self.assertIn('_operation=_group getVariable ["CBE_Operation",createHashMap]',retreat_case)
        self.assertIn('private _unavailable=_operation getOrDefault ["unavailable",[]]',retreat_case)
        self.assertIn('private _recoveryRecord=_recovery getOrDefault [netId _x,[]]',retreat_case)
        self.assertIn('if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) exitWith {',retreat_case)

    def test_trapped_withdrawal_uses_bounded_dry_fallback_and_keeps_fighting(self):
        retreat=source('cortexRetreat')
        tick=source('cortexGroupTick')
        self.assertIn('forEach [0.75,0.5,0.25]',retreat)
        self.assertIn('forEach [0,45,-45,90,-90,135,-135,180]',retreat)
        self.assertIn('["BLOCKED",0,0]',retreat)
        contact=tick.split('case "CONTACT": {',1)[1].split('case "SECURITY": {',1)[0]
        self.assertIn('private _retreatStarted=false',contact)
        self.assertIn('_state set ["retreatRetryAt",_now+10]',contact)
        self.assertIn('if (_retreatStarted) exitWith {}',contact)
        self.assertLess(contact.index('if (_retreatStarted) exitWith {}'),contact.index('CortexFireControl'))
        self.assertNotIn('if (_outcome == "RETREAT") exitWith {',contact)

    def test_infantry_withdrawal_resumes_across_locality_without_replaying_effects(self):
        retreat=source('cortexRetreat')
        locality=source('cortexLocality')
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        self.assertIn('CBE_Cortex_WithdrawalIntent',retreat)
        self.assertIn('["INFANTRY",_origin,_point,_enemyPos,_startedAt,_replans,_bestTravel]',retreat)
        self.assertIn('if (!_resuming) then {',retreat)
        effects=retreat.split('if (!_resuming) then {',2)[2]
        self.assertIn('CortexThrowGrenade',effects)
        self.assertIn('CortexArtilleryFire',effects)
        self.assertIn('private _withdrawalIntent',locality)
        self.assertGreater(locality.index('CortexRetreat'),locality.index('CortexRestoreCalm'))
        self.assertIn('[_group,_adopted,_withdrawalIntent] call CBE_fnc_CortexRetreat',locality)
        self.assertIn('time-_elapsed,_resuming] call CBE_fnc_CortexSetPhase',retreat)
        self.assertNotIn('max 3',retreat)
        self.assertIn('private _remaining = 120-_elapsed',retreat)
        self.assertLess(retreat.index('if (_elapsed >= 120) exitWith'),retreat.index('call CBE_fnc_CortexSelectAvenue'))
        self.assertIn('_operation set ["startedAt",time-_elapsed]',retreat)
        self.assertIn('"EPISODE_EXPIRED"',retreat)
        self.assertIn('(_withdrawalIntent select 4) <= serverTime+1',locality)
        self.assertIn('setVariable ["CBE_Cortex_WithdrawalOrder",[_startedAt,',retreat)
        self.assertLess(retreat.index('"MOVEMENT_REJECTED"'),retreat.index('setVariable ["CBE_Cortex_WithdrawalOrder"'))
        self.assertIn('&& {_withdrawalOrderCurrent}',locality)
        self.assertNotIn('!= "VEHICLE" || {_withdrawalOrderCurrent}',locality)
        replan=tick.split('// Refresh only after a successful CBE replan',1)[1].split('_bestTravel = _travel',1)[0]
        self.assertIn('CBE_fnc_NativeOrderReceipt',replan)
        self.assertNotIn('VEHICLE_WITHDRAW',replan)
        withdrawal=tick.split('case "RETREAT": {',1)[1]
        self.assertLess(withdrawal.index('if (_withdrawOwner && {!_routeCurrent}) exitWith'),withdrawal.index('call CBE_fnc_OperationStep'))
        self.assertLess(withdrawal.index('if (_withdrawOwner && {!_routeCurrent}) exitWith'),withdrawal.index('call CBE_fnc_CortexSurrender'))
        self.assertIn('[_group,_state,false,true,"WITHDRAWAL_ROUTE_CHANGED_OR_FINISHED"]',withdrawal)
        self.assertIn('(_routeProof select 0) isEqualTo (_episode select 4)',withdrawal)
        self.assertIn('(_routeProof select 1) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',withdrawal)

        self.assertIn('_intent set [5,_replans]',tick)
        self.assertIn('_intent set [6,_bestTravel]',tick)
        self.assertIn('setVariable ["CBE_Cortex_WithdrawalIntent",nil,true]',restore)

    def test_withdrawal_smoke_cannot_leave_the_route_owner_staring_at_the_screen(self):
        text=source('cortexRetreat')
        self.assertIn('_smokers=(_smokers select {_x != _leader})+(_smokers select {_x == _leader});',text)
        self.assertIn('if ([_x, _enemyPos, "SMOKE"] call CBE_fnc_CortexThrowGrenade) exitWith {};',text)
        self.assertNotIn('CBA_fnc_waitAndExecute',text)
        self.assertNotIn('_smoker doMove',text)
        self.assertNotIn('_smoker doFollow',text)

    def test_clear_release_never_recalls_an_externally_owned_group(self):
        release=source('cortexClearRelease')
        self.assertIn('private _externalTakeover = [_group] call CBE_fnc_CortexExternalTakeover;',release)
        self.assertIn('then {_restore=false}',release)
        self.assertLess(release.index('then {_restore=false}'),release.index('if (_restore && {_taskFree} && {_movementOwned} && {isNull objectParent _x}) then {'))
        self.assertIn('_destination vectorDistance _issued <= 0.25',release)
        self.assertIn('count _issued == 3 && {count _destination == 3}',release)
        self.assertLess(release.index('private _movementTargets='),release.index('_group setVariable ["CBE_BuildingBrain",nil]'))
    def test_building_handover_never_restores_or_locks_wait_state_after_takeover(self):
        clear_release=source('cortexClearRelease')
        clear_job=source('cortexClearBuilding')+source('buildingOperationStep')
        garrison_release=source('cortexGarrisonRelease')
        garrison_apply=source('cortexGarrisonApplyLocal')
        # Replacement orders may set posture and speed independently. Cleanup only restores either
        # after a normal CBE release, never after the shared external-ownership boundary fired.
        clear_settings=source('cortexClearSettingsRelease')
        self.assertIn('call CBE_fnc_CortexClearSettingsRelease',clear_release)
        self.assertIn('call CBE_fnc_CortexClearSettingsRelease',clear_job)
        actor_settings=source('actorSettings')
        self.assertIn('call CBE_fnc_ActorSettings',clear_settings)
        room_speed=source('buildingOperationStep')
        self.assertIn('private _nearArrival=_arrivalPose vectorDistance (AGLToASL _arrivalTarget) < 5',room_speed)
        self.assertIn('[4,3] select (getSuppression _unit >= 0.2)',room_speed)
        self.assertNotIn('_unit distance2D _arrivalTarget < 5',room_speed)
        self.assertIn('[_authorityGroup,_mode == "RELEASE",_actor] call CBE_fnc_CortexExternalTakeover',actor_settings)
        self.assertIn('CortexActorMoveReserved',actor_settings)
        release=actor_settings.split('if (_mode == "RELEASE") exitWith {',1)[1].split('private _operation=',1)[0]
        self.assertIn('[_key,_native,_pair select 1] call _same',release)
        self.assertIn('_remaining set [_key,_pair]',release)
        self.assertLess(actor_settings.index('call CBE_fnc_CortexExternalTakeover'),actor_settings.index('if (_mode == "RELEASE")'))
        self.assertNotIn('doFollow',clear_settings.split('params [[',1)[1])
        self.assertIn('call CBE_fnc_CortexGarrisonSettings',garrison_release)
        self.assertIn('if (!_externalTakeover) then {',garrison_release)
        self.assertIn('&& {_reservationFree} && {!_nativeTask} && {isNull objectParent _unit}',garrison_release)
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',garrison_release)
        self.assertIn('currentCommand _unit in [',garrison_release)
        self.assertNotIn('forceSpeed',garrison_release)
        # The garrison job must release its own PATH lock at loss of eligibility and recheck
        # ownership before its arrival hold or first individual move can mutate a unit.
        self.assertIn('[_group,false] call CBE_fnc_CortexGarrisonRelease;',garrison_apply)
        self.assertIn('if (!_heldInPlace && {_unit in _freshActors} && {[_unit] call _mayIssueMovement}) then {doStop _unit};',garrison_apply)
        arrival=garrison_apply.split('if ([_x,_assignment] call _assignmentArrived) then {',1)[1].split('} else {',1)[0]
        self.assertIn('if ([_x] call _mayIssueMovement) then {',arrival)
        self.assertLess(arrival.index('if ([_x] call _mayIssueMovement) then {'),arrival.index('_x disableAI "PATH"'))
        self.assertIn('["assignmentArrived",_assignmentArrived]',garrison_apply)
        self.assertIn('_assignmentArrived=_job get "assignmentArrived"',garrison_apply)
        self.assertIn('private _assignmentArrived=CBE_fnc_CortexGarrisonArrived;',garrison_apply)
        physical=source('cortexGarrisonArrived')
        for guard in ['vectorDistance _target > _radius','> 0.75','worldToModel',
                      'lineIntersectsSurfaces','(_x select 2) == _building']:
            self.assertIn(guard,physical)
    def test_locality_handover_uses_a_surviving_anchor_for_restoration_and_search(self):
        """A handoff during leader succession must restore only toward a viable local actor."""
        locality=source('cortexLocality')
        self.assertIn('private _restoreAnchor=[_group] call CBE_fnc_CortexGroupAnchor;',locality)
        self.assertIn('_x doFollow _restoreAnchor',locality)
        self.assertIn('private _leader = [_group] call CBE_fnc_CortexGroupAnchor;',locality)
        self.assertIn('if (isNull _leader) then {_leader=leader _group};',locality)

    def test_post_contact_movement_resumes_across_locality_with_original_deadline(self):
        checkpoint=source('cortexCheckpoint')
        locality=source('cortexLocality')
        restore=source('cortexRestoreCalm')
        for marker in ['CBE_Cortex_TransitionIntent','["INVESTIGATE","SEARCH"]','_startedAt+_duration','searchTeam']:
            self.assertIn(marker,checkpoint)
        self.assertIn('serverTime < (_transitionIntent select 3)',locality)
        self.assertIn('_withdrawalIntent isEqualTo []',locality)
        self.assertIn('CortexZeusHeld',locality)
        self.assertIn('private _transitionResumeEligible=',locality)
        self.assertIn('!(_transitionResumeEligible || {_withdrawalResumeEligible})',locality)
        self.assertIn('[_group,_adopted,_transitionPhase,"OWNERSHIP_RESUME",time-((serverTime-_startedAt) max 0),true] call CBE_fnc_CortexSetPhase',locality)
        self.assertIn('CortexGroupMove',locality)
        self.assertIn('doMove',locality)
        self.assertNotIn('CBA_fnc_waitAndExecute',locality)
        self.assertIn('setVariable ["CBE_Cortex_TransitionIntent",nil,true]',restore)

    def test_vehicle_withdrawal_records_and_resumes_physical_progress(self):
        vehicles=source('cortexVehicles')
        locality=source('cortexLocality')
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        for marker in ['_state set ["retreatStart",_origin]',
                       '_state set ["retreatTarget",_away]',
                       '_state set ["retreatProgress",[time,0,0]]',
                       'serverTime-((time-(_operation get "startedAt")) max 0),0,0]']:
            self.assertIn(marker,vehicles)
        for terrain_marker in ['private _selectVehicleEscape = {','forEach [0,-25,25,-45,45]',
                               'CBE_fnc_CortexSelectAvenue','_threatObject,"VEHICLE"']:
            self.assertIn(terrain_marker,vehicles)
        adoption_guard=locality.split('private _withdrawalOrder=',1)[1].split('private _transitionIntent',1)[0]
        self.assertIn('(_withdrawalOrder select 0) isEqualTo (_withdrawalIntent select 4)',adoption_guard)
        self.assertIn('(_withdrawalOrder select 1) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',adoption_guard)
        self.assertLess(locality.index('private _withdrawalOrderCurrent='),locality.index('"OWNERSHIP_LOST"] call CBE_fnc_OperationCancel'))
        self.assertIn('&& {_withdrawalOrderCurrent}',locality)
        vehicle_resume=locality.split('== "VEHICLE"',1)[1]
        self.assertIn('CortexGroupMove',vehicle_resume)
        self.assertIn('["VEHICLE_WITHDRAW",time+_remaining]',vehicle_resume)
        self.assertIn('true,_startedAt+120] call CBE_fnc_CortexOwnershipLease',vehicle_resume)
        self.assertIn('private _remaining=120-_elapsed',vehicle_resume)
        self.assertNotIn('(120-_elapsed) max 3',vehicle_resume)
        self.assertIn('[_group,"VEHICLE_WITHDRAW",_target,[],[_target],"MOVING"] call CBE_fnc_OperationStart',vehicle_resume)
        self.assertIn('_operation set ["startedAt",time-_elapsed]',vehicle_resume)
        self.assertIn('[_group,_target,40,"MOVE",_generation] call CBE_fnc_CortexGroupMove',vehicle_resume)
        self.assertIn('["vehicleOperationGeneration",_generation]',vehicle_resume)
        self.assertLess(vehicle_resume.index('"MOVEMENT_REJECTED"] call CBE_fnc_OperationCancel'),vehicle_resume.index('_adopted set ["movementLease"'))
        self.assertIn('[_group,_adopted,"RETREAT","VEHICLE_OWNERSHIP_RESUME",time-_elapsed,true] call CBE_fnc_CortexSetPhase',vehicle_resume)
        self.assertNotIn('CortexFireCountermeasure',vehicle_resume)
        for marker in [
            'WITHDRAW-MIGRATION-headless-prerequisite',
            'WITHDRAW-MIGRATION-production-start',
            'WITHDRAW-MIGRATION-owner-resume',
            'WITHDRAW-MIGRATION-start-preserved',
            'WITHDRAW-MIGRATION-physical-continuation',
            'WITHDRAW-MIGRATION-no-smoke-replay',
            'WITHDRAW-MIGRATION-crew-retained',
            'WITHDRAW-MIGRATION-zeus-physical-replacement',
            'WITHDRAW-MIGRATION-zeus-no-resurrection',
            'CBE_fnc_HeadlessMigrateGroup',
            'VEHICLE_OWNERSHIP_RESUME',
        ]:
            self.assertIn(marker,audit)
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('[string]$Focus=\'all\'',launcher)
        self.assertIn('mod_pipeline.py\') stage $Package $runtime --focus $Focus',launcher)
        self.assertIn('"stateflows"',server)

    def test_mounted_survivors_withdraw_instead_of_selecting_impossible_surrender(self):
        morale=source('cortexMorale')
        self.assertIn('private _allOnFoot = _alive findIf {vehicle _x != _x} < 0',morale)
        surrender=morale.split('if (_allOnFoot',1)[1]
        self.assertIn('CBE_AIPass_Surrender_Enable',surrender)

    def test_replacement_orders_release_owned_garrison_and_defence_holds(self):
        for name,marker in [
            ('cortexDefendRelease','CBE_AIPass_DefendHolding'),
            ('cortexGarrisonRelease','CBE_AIPass_GarrisonDisabledPath')]:
            code=source(name)
            self.assertIn(marker,code)
            self.assertIn('toUpperANSI currentCommand _x',code)
            self.assertIn('["","STOP","ATTACK","FIRE","SUPPRESS"]',code)
            self.assertIn('private _externalTakeover = [_group] call CBE_fnc_CortexExternalTakeover;',code)
            self.assertIn('private _canRestore = _restore && {!_externalTakeover};',code)
            self.assertIn('_canRestore ||',code)
            self.assertIn('!_externalTakeover && {_ownedHold',code)
            self.assertIn('call CBE_fnc_CortexActorMoveReserved',code)
            self.assertIn('&& {_reservationFree} && {!_nativeTask}',code)
            restore_condition=code.split('_canRestore ||',1)[1].split('then {',1)[0]
            for external in ['GET IN','GET OUT','ACTION','SCRIPTED']:
                self.assertNotIn(f'"{external}"',restore_condition)

    def test_garrison_restores_only_the_speed_lease_it_applied(self):
        apply=source('cortexGarrisonApplyLocal');release=source('cortexGarrisonRelease')
        adapter=source('cortexGarrisonSettings');core=source('actorSettings')
        cap=apply.split('private _applyApproachSpeed = {',1)[1].split('private _rememberMove = {',1)[0]
        self.assertIn('if (_baseline < 0) then {4} else {_baseline min 4}',cap)
        self.assertIn('[["SPEED",_cap]]',cap)
        self.assertIn('[_unit] call _applyApproachSpeed',apply)
        self.assertIn('[_actor] call _applyApproachSpeed',apply)
        self.assertIn('["applyApproachSpeed",_applyApproachSpeed]',apply)
        self.assertNotIn('forceSpeed',apply);self.assertNotIn('setUnitPos',apply)
        self.assertNotIn('forceSpeed',release);self.assertNotIn('setUnitPos',release)
        self.assertIn('call CBE_fnc_ActorSettings',adapter)
        self.assertIn('(_owned get "SPEED") select 0',adapter)
        self.assertIn('(_owned get "SPEED") select 1',adapter)
        self.assertIn('[_key,_native,_pair select 1] call _same',core)
        self.assertLess(adapter.index('_status == "RELEASED"'),adapter.index('forEach _mirrors'))
        self.assertIn('serverTime+30',adapter)
        self.assertIn('_actorIssuer != _issuer || {_retiring}',adapter)
        order=source('cortexGarrison')
        self.assertIn('CBE_Cortex_GarrisonSettingSerial",0])+1',order)
        self.assertIn('netId _group,_settingSerial',order)
        self.assertEqual(apply.count('"CHECK"] call CBE_fnc_CortexGarrisonSettings'),2)
        self.assertLess(adapter.index('_actorIssuer != _issuer || {_retiring}'),adapter.index('_status=[_mode,_actor'))
        self.assertIn('_window isEqualTo [] ||',adapter)
        self.assertIn('if (!_ready) exitWith {};',adapter)
        self.assertIn('(_window select 0) isNotEqualTo _actorIssuer',adapter)
        self.assertNotIn('CBA_fnc_waitAndExecute',adapter)
        cleanup=source('actorSettingsCleanupStep')
        self.assertIn('_pendingGarrison deleteAt 0',cleanup)
        self.assertIn('serverTime < (_window select 1)',cleanup)
        self.assertIn('_actor,_group,"RELEASE",createHashMap,false',cleanup)
        self.assertNotIn('serverTime+30',cleanup)
        self.assertNotIn('setVariable ["CBE_Cortex_GarrisonForcedSpeed",nil',release)

    def test_vehicle_movement_owns_its_waypoint_until_physical_completion(self):
        vehicles=source('cortexVehicles')
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        self.assertIn('getOrDefault ["movementLease",[]]',vehicles)
        self.assertIn('waypointDescription _moveWaypoint == "CBE AI PASS"',vehicles)
        route=vehicles.split('private _moveIntent=',1)[1].split('if (!_activeVehicleMove)',1)[0]
        self.assertNotIn('findIf',route)
        self.assertIn('_moveGeneration == (_moveIntent getOrDefault ["operationGeneration",-2])',route)
        self.assertIn('_moveGeneration == (_moveOperation getOrDefault ["generation",-2])',route)
        self.assertIn('_policy isEqualTo (_moveIntent getOrDefault ["nativePolicy",[]])',route)
        self.assertIn('"VEHICLE_ROUTE_REPLACED"] call CBE_fnc_OperationCancel',vehicles)
        feature=vehicles.split('private _movementFeature=switch',1)[1].split('private _orientControllerExternal=',1)[0]
        for gate in ('"VEHICLE_JINK": {"CBE_AIPass_VehicleJink_Enable"}',
                     '"VEHICLE_WITHDRAW": {"CBE_AIPass_VehicleWithdraw_Enable"}',
                     'default {"CBE_AIPass_VehicleGunnery_Enable"}',
                     '"CBE_AIPass_Vehicles_Enable"','[_group,_movementFeature,true]'):
            self.assertIn(gate,feature)
        self.assertLess(vehicles.index('if (_vehicleFeatureDisabled) then {_activeVehicleMove=false}'),
                        vehicles.index('if (!_activeVehicleMove)'))
        self.assertLess(vehicles.index('"FEATURE_DISABLED"] call CBE_fnc_OperationCancel'),
                        vehicles.index('["VEHICLE_MOVE_NO_ARRIVAL","OBJECTIVE_REACHED"]'))
        self.assertLess(vehicles.index('"FEATURE_DISABLED"] call CBE_fnc_OperationCancel'),
                        vehicles.index('if (_lifecycleOnly) exitWith'))
        self.assertIn('private _movementOwned = _activeVehicleMove',vehicles)
        self.assertIn('if (_enemies isEqualTo []) exitWith {_movementOwned}',vehicles)
        self.assertIn('_state set ["movementLease",["VEHICLE_WITHDRAW",(_operation get "startedAt")+120]]',vehicles)
        self.assertIn('_state set ["movementLease",["VEHICLE_STANDOFF",time+60]]',vehicles)
        self.assertIn('if (!_movementOwned && {_state getOrDefault ["phase",""] == "CONTACT"}',vehicles)
        self.assertIn('private _coordinatedOwnsMovement = _vehicleOwnsMovement',tick)
        self.assertIn('!_vehicleOwnsMovement',tick)
        self.assertIn('(_state getOrDefault ["phase",""]) == "CONTACT"',tick)
        self.assertIn('"movementLease"',restore)
        self.assertIn('private _groupMovementOwned = count _movementLease == 2',tick)
        dispatch=tick.split('private _groupMovementOwned =',1)[1].split('if (!_groupMovementOwned',1)[0]
        self.assertIn('case "VEHICLE_ORIENT": {true}',dispatch)
        self.assertNotIn('CBE_Danger_VehicleOrient',dispatch)
        self.assertNotIn('count _marker == 5',dispatch)
        retirement=tick.split('if (!_groupMovementOwned',1)[1].split('private _now = time',1)[0]
        self.assertNotIn('VEHICLE_ORIENT',retirement)
        self.assertNotIn('CBE_Danger_VehicleJink',retirement)
        self.assertNotIn('STOPTURNING',retirement)
        self.assertLess(tick.index('[_group,_state,[],true] call CBE_fnc_CortexVehicles'),tick.index('private _movementLease ='))
        self.assertLess(vehicles.index('if (_lifecycleOnly) exitWith'),vehicles.index('private _vehicles = []'))
        self.assertIn('if (!_groupMovementOwned && {_movementLease isNotEqualTo []})',tick)

    def test_vehicle_combat_layer_preserves_other_movement_owners(self):
        vehicles=source('cortexVehicles')
        self.assertIn('in ["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"]',vehicles)
        self.assertIn('if (_vehicleOwnsLease) then',vehicles)
        self.assertIn('_activeVehicleMove = count _vehicleMove == 2',vehicles)
        non_vehicle=vehicles.split('} else {',1)[1].split('};',1)[0]
        self.assertNotIn('deleteAt "movementLease"',non_vehicle)

    def test_routine_ground_gunnery_yields_combined_roles_and_checks_operator_station_lane(self):
        text=source('cortexVehicles')
        reservation=text.split('private _combinedGroundRole=',1)[1].split('private _crewActorAvailable=',1)[0]
        self.assertIn('in ["GROUND_FIRE","GROUND_MANOEUVRE"]',reservation)
        self.assertIn('serverTime < (_combinedGroundRole select 5)',reservation)
        self.assertNotIn('setVariable',reservation)
        standoff=text.split('private _standoff =',1)[1]
        for proof in ('vehicleStandoffYield','isEqualTo _combinedGroundRole',
                      '"OTHER_INTENT_ACTIVE",clientOwner','CBE_fnc_CortexCombinedRejectServer',
                      '&& {!_combinedGroundFireOwned}'):
            self.assertIn(proof,standoff)
        self.assertLess(standoff.index('remoteExecCall'),standoff.index('"VEHICLE_STANDOFF",true'))
        commit=standoff.split('// A local synchronous reply',1)[1]
        self.assertIn('isNil {',commit)
        self.assertIn('getVariable ["CBE_Cortex_CombinedRole",[]]) isEqualTo _combinedGroundRole',commit)

        request=standoff.split('// A stationary support gun',1)[1].split('// A local synchronous reply',1)[0]
        for forbidden in ('CortexGroupMove','forceSpeed','doMove','OperationStart'):
            self.assertNotIn(forbidden,request)

        authority=text.split('private _crewActorAvailable=',1)[1].split('if (_externalTakeover)',1)[0]
        for proof in ('group _gunner == _group','CortexCombatEffective','simulationEnabled _gunner','isObjectHidden _gunner','remoteControlled _gunner','CortexExternalOwner','CompatibilityExternalControl','CortexActorFireTaskAvailable'):
            self.assertIn(proof,authority)
        danger=text.split('if (_knownHostile &&',1)[1].split('} forEach _affectedVehicles',1)[0]
        routine=text.split('if (_ranked isNotEqualTo []',1)[1].split('private _standoff',1)[0]
        for block in (danger,routine):
            for proof in ('!_combinedGroundFireOwned','call _crewActorAvailable','canFire _vehicle','CortexGroundFireReady','CortexLineOfFireClear'):
                self.assertIn(proof,block)
        self.assertLess(routine.index('CortexLineOfFireClear'),routine.index('_gunner doFire _target'))
        for proof in ('_vehicle distance2D _believed >= 50','abs speed _vehicle < 30',
                      'currentCommand _gunner != "SUPPRESS"','CBE_AIPass_TargetHold',
                      'isNull _engaging || {_engaging == _dangerSource}',
                      'isNull _assigned || {_assigned == _dangerSource}',
                      '!terrainIntersectASL [eyePos _gunner,_aimPosition]',
                      '[_vehicle,_gunner,_dangerSource,_dangerFireObservation,false,true] call CBE_fnc_CortexGroundFireReady',
                      'call CBE_fnc_CortexGroundSelectMuzzle'):
            self.assertIn(proof,danger)
        self.assertLess(danger.index('CortexGroundFireReady'),danger.index('call CBE_fnc_CortexGroundSelectMuzzle'))
        self.assertLess(danger.index('call CBE_fnc_CortexGroundSelectMuzzle'),danger.index('_gunner doSuppressiveFire'))


    def test_vehicle_gunnery_selects_first_usable_ranked_contact_with_finite_work(self):
        text=source('cortexVehicles')
        selection=text.split('private _target=objNull;',1)[1].split('private _standoff',1)[0]
        self.assertIn('forEach (_ranked select [0,8])',selection)
        self.assertIn('private _airContacts=[];private _airContactsRead=false;',text)
        self.assertIn('if (!_airContactsRead) then {',text)
        self.assertEqual(text.count('[_group,-1,"AIR"] call CBE_fnc_CortexKnowledge'),1)
        query_gate=text.split('if (_airCandidate &&',1)[1].split('if (!_airContactsRead)',1)[0]
        for proof in ('!_combinedGroundFireOwned','canFire _vehicle','combatMode _group',
                      'unitCombatMode _gunner','CBE_AIPass_TargetHold'):
            self.assertIn(proof,query_gate)

        self.assertIn('== "edsubcat_aas"',text)
        self.assertIn('case (_freshAir && {_airDefence}): {-1}',text)
        self.assertIn('private _freshAir=_airPreference &&',text)
        self.assertIn('_vehicleIndex in _airProbeSlots',text)
        self.assertIn('(_airProbeStart+2) mod _airProbeCount',text)
        # The finite roster window cannot starve later custom platforms or grow with the roster.
        for count in range(1,65):
            cursor=0;seen=set()
            for _ in range((count+1)//2):
                slots={cursor,(cursor+1)%count}
                self.assertLessEqual(len(slots),2)
                seen.update(slots);cursor=(cursor+2)%count
            self.assertEqual(seen,set(range(count)))
        self.assertLess(text.index('case (_freshAir && {_airDefence})'),text.index('case (_enemy isKindOf "CAManBase"'))

        preflight=text.split('private _freshAircraft=',1)[1].split('private _ranked =',1)[0]
        self.assertIn('(_freshAircraft select 0) select 0,_stationSelection,true]',preflight)
        self.assertLess(preflight.index('call CBE_fnc_CortexGroundFireReady'),preflight.index('if (_airPreference) then'))
        self.assertEqual(text.count('private _stationSelection=createHashMap;'),1)

        self.assertIn('private _contactRange=[600,_airRange] select _freshAir;',text)
        self.assertIn('_gunneryContacts select (_x select 3)',selection)
        knowledge=source('cortexKnowledge')
        self.assertIn('_domain == "ALL" || {_enemy isKindOf "Air"}',knowledge)
        self.assertLess(knowledge.index('_domain == "ALL"'),knowledge.index('if (count _candidates > 8)'))

        self.assertIn('[_vehicle,_gunner,_candidate,_stationSelection,true,_suppressOnly] call CBE_fnc_CortexGroundFireReady',selection)
        self.assertIn('[_gunner,_reportedASL,_stationSelection getOrDefault ["loadedMagazine",""]] call CBE_fnc_CortexLineOfFireClear',selection)
        self.assertIn('exitWith {\n                    _target=_candidate;_targetLanePoint=+_reportedASL;',selection)
        self.assertLess(selection.index('if (!isNull _target)'),selection.index('_gunner doTarget _target'))
        self.assertNotIn('nearEntities',selection)
        self.assertNotIn('aimPos _candidate',selection)
        self.assertIn('private _freshLaneSafe=',selection)
        self.assertIn('[_gunner,_targetLanePoint,_fireObservation getOrDefault ["loadedMagazine",""]]',selection)
        for proof in ('(_contactRow select 2) > 3','_vehicle distance2D _reported >= 50',
                      'abs speed _vehicle < 30','currentCommand _gunner != "SUPPRESS"',
                      'isNull _engaging || {_engaging == _candidate}',
                      'isNull _assigned || {_assigned == _candidate}',
                      '_suppressionGeometryChecks < 3',
                      '[_gunner,_reportedASL,50] call CBE_fnc_CortexSuppressionAim',
                      '_gunner doSuppressiveFire _suppressionPoint'):
            self.assertIn(proof,selection)

        self.assertNotIn(' reveal ',selection)
        self.assertIn('if (count _candidates > 8) then {_candidates resize 8}',source('cortexKnowledge'))

    def test_convoy_matrix_captures_actual_lead_and_follower_control_boundaries(self):
        text=source('convoyTick')
        matrix=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text(encoding='utf-8')
        self.assertIn('setVariable ["CBE_Convoy_CaptureControl",!_baseline]',matrix)
        self.assertIn('getOrDefault ["controlSamples",createHashMap]',matrix)
        self.assertIn('getOrDefault ["leadControlSample",[]]',matrix)
        self.assertLess(text.index('private _captureControl='),text.index('private _leadLimit ='))
        self.assertIn('_state deleteAt "leadControlSample"',text)
        for cap in ('pacing','corridor','accelerationAndArrival','bypass','trafficGeometry','infantry'):
            self.assertIn('(_leadControl select 4) pushBack ["'+cap+'",_leadLimit]',text)
        write=text.split('_lead forceSpeed _ownedSpeed;',1)[1].split('// Speed limits cannot restart',1)[0]
        self.assertIn('if (_captureControl) then {_leadControl set [5,true]}',write)
        self.assertIn('_state set ["leadControlSample",_leadControl]',write)

    def test_vehicle_gunnery_refreshes_fire_when_contact_was_already_shared(self):
        vehicles=source('cortexVehicles')
        target_change=vehicles.index('if (assignedTarget _gunner != _target) then {_gunner doTarget _target};')
        target_change_end=vehicles.index('};',target_change)
        fire=vehicles.index('_gunner doFire _target;',target_change)
        hold=vehicles.index('_gunner setVariable ["CBE_AIPass_TargetHold", time + 8]',fire)
        self.assertGreater(fire,target_change_end)
        self.assertGreater(hold,fire)

    def test_artillery_scoot_waits_for_and_acquires_shared_movement_ownership(self):
        mission=source('cortexArtilleryMissionStep')
        scoot=source('cortexArtilleryScoot')
        locality=source('cortexLocality')
        tick=source('cortexGroupTick')
        self.assertIn('setVariable ["CBE_Cortex_ArtilleryScootToken",_scootToken,true]',mission)
        self.assertIn('setVariable ["CBE_Cortex_ArtilleryScootDeadline",_scootSession select 3,true]',mission)
        self.assertIn('_mission getOrDefault ["counterGeneration",-1],serverTime+120,_scootPurpose',mission)
        self.assertIn('[_battery,_scootToken,_scootSession] remoteExecCall ["CBE_fnc_CortexArtilleryScoot", owner _battery]',mission)
        self.assertIn('getVariable ["CBE_Cortex_ArtilleryScootToken",""] != _token',scoot)
        self.assertIn('if (_busy) exitWith {',scoot)
        self.assertIn('CBA_fnc_waitAndExecute',scoot)
        self.assertIn('_state set ["movementLease",["ARTILLERY_SCOOT",time+120]]',scoot)
        self.assertIn('CBE_fnc_CortexSelectAvenue',scoot)
        self.assertEqual(scoot.count('call _crewReady'),2)
        self.assertIn('count _session != 7',scoot)
        self.assertIn('(_session select 6) isEqualTo _seats',scoot)
        self.assertIn('movementOrder",[]]),_scootSeats]',mission)
        active=tick.split('private _record=_scootOperation',1)[1].split('// Continue the existing finite AA',1)[0]
        self.assertIn('(_session select 6) isEqualTo _seats',active)
        self.assertIn('(_seats arrayIntersect _seats) findIf',active)
        for guard in ('local _x','isPlayer _x','CortexActorFireTaskAvailable','CortexExternalOwner','CompatibilityExternalControl','checkAIFeature "MOVE"','checkAIFeature "PATH"'):
            self.assertIn(guard,active)
        self.assertIn('RELOCATION_CREW_CHANGED',source('artilleryMissionStep'))

        crew=scoot.split('private _crewReady=',1)[1].split('private _nativeOrder=',1)[0]
        for guard in ('driver _battery == _driver','local _x','CortexActorFireTaskAvailable',
                      'currentCommand _x in ["","MOVE","WAIT"]','NativeOrderReceipt',
                      '_destination vectorDistance (waypointPosition [_group,_index]) > 3'):
            self.assertIn(guard,crew)
        self.assertIn('objNull,"VEHICLE"',scoot)
        self.assertIn('[_vehicle,_scootToken] call CBE_fnc_CortexArtilleryScoot',locality)
        self.assertLess(locality.index('CortexRestoreCalm'),locality.index('CortexArtilleryScoot'))
        self.assertIn('if (!_groupMovementOwned && {!(_state getOrDefault ["responding", false])',tick)
        self.assertGreaterEqual(tick.count('!_groupMovementOwned'),3)

    def test_support_cleanup_does_not_delete_a_newer_shared_movement_route(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _movementLeaseActive = count _movementLease == 2',maintain)
        self.assertIn('private _supportOwnsMovement = _movementLeaseActive',maintain)
        self.assertIn('["SUPPORT_RALLY","COORDINATED_ASSAULT"]',maintain)
        self.assertIn('if (_operationGeneration >= 0',maintain)
        self.assertIn('&& {(_supportOwnsMovement || {!_movementLeaseActive})}',maintain)
        self.assertIn('if (_supportOwnsMovement) then {_state deleteAt "movementLease"}',maintain)
        self.assertIn('private _operationEndReason=""',maintain)
        self.assertIn('if (_operationState == "STALLED" && {!(_state getOrDefault ["assaulting",false])}) then {_operationEndReason="NO_PROGRESS"}',maintain)
        self.assertIn('if (_operationEndReason != "") exitWith {',maintain)
        self.assertNotIn('if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) exitWith {',maintain)

    def test_all_group_manoeuvres_use_one_shared_movement_owner(self):
        tick=source('cortexGroupTick')
        apply=source('cortexSupportApply')
        maintain=source('cortexSupportMaintain')
        end=source('cortexFlankEnd')
        self.assertIn('case "TACTICAL_DRILL"',tick)
        self.assertIn('case "COORDINATED_ASSAULT"',tick)
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            code=source(name)
            self.assertIn('getOrDefault ["movementLease",[]]',code)
            self.assertIn('["lastStep",time]',code)
            self.assertIn('_state set ["movementLease",["TACTICAL_DRILL",time+90]]',code)
        self.assertIn('(_movementLease select 0) == "TACTICAL_DRILL"',end)
        self.assertIn('!_movementLeaseActive || {_supportOwnsMovement} || {_replaceLocalDrill}',apply)
        self.assertIn('_state set ["movementLease",["SUPPORT_RALLY",time+(_expiry-serverTime)]]',apply)
        self.assertIn('_state set ["movementLease",["COORDINATED_ASSAULT",time+(_expiry-serverTime)]]',apply)
        self.assertIn('case "SUPPORT_RALLY"',maintain)

    def test_every_finite_group_move_holds_one_wait_movement_lease(self):
        lease=source('cortexOwnershipLease')
        self.assertIn("CBE_Cortex_MovementLease",lease)
        self.assertIn("exclusive ownership of the group's CBE movement domain",lease)
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            code=source(name)
            self.assertIn('[_group,"TACTICAL_DRILL",true,serverTime+90]',code)
            self.assertIn('EXTERNAL_MOVEMENT_BUSY',code)
        step=source('cortexFlankStep')
        end=source('cortexFlankEnd')
        self.assertIn('[_group,"TACTICAL_DRILL",true,serverTime+90]',step)
        self.assertIn('[_group,"TACTICAL_DRILL",false]',end)
        retreat=source('cortexRetreat')
        tick=source('cortexGroupTick')
        self.assertIn('[_group,"INFANTRY_WITHDRAW",true,_startedAt+120]',retreat)
        self.assertIn('[_group,_withdrawController,false]',tick)
        self.assertIn('["INFANTRY_WITHDRAW","VEHICLE_WITHDRAW"] select',tick)
        vehicles=source('cortexVehicles')
        self.assertIn('[_group,"VEHICLE_WITHDRAW",true,serverTime+120]',vehicles)
        self.assertIn('[_group,"VEHICLE_STANDOFF",true,serverTime+60]',vehicles)
        combined=source('cortexCombinedArmsLocal')
        combined_end=source('cortexCombinedGroundStep')
        self.assertIn('[_group,"COMBINED_GROUND",true,_expiry]',combined)
        self.assertIn('[_group,"COMBINED_GROUND",false]',combined_end)
        scoot=source('cortexArtilleryScoot')
        self.assertIn('[_group,"ARTILLERY_SCOOT",true,serverTime+120]',scoot)
        self.assertIn('[_group,_movementOwner,false]',tick)

    def test_tactical_drill_scheduler_silence_restores_owned_ai_state(self):
        step=source('cortexFlankStep')
        tick=source('cortexGroupTick')
        support=source('cortexSupportBoundStart')
        scheduler=source('cortexSchedulerTick')
        end=source('cortexFlankEnd')
        self.assertIn('_drill set ["lastStep",time]',step)
        self.assertIn('_state set ["movementLease",["TACTICAL_DRILL",time+90]]',step)
        self.assertIn('["lastStep",time]',support)
        self.assertIn('time-_lastDrillStep > _drillWatchdog',tick)
        self.assertIn('[_group,_state,"SCHEDULER_STALLED"] call CBE_fnc_CortexFlankEnd',tick)
        self.assertIn('CBE_AIPass_ResumeGraceUntil',tick)
        self.assertIn('CBE_AIPass_ResumeGraceUntil',scheduler)
        self.assertIn('SCHEDULER_STALLED',end)

    def test_finite_tactical_drills_use_one_owner_local_fsm(self):
        launcher=source('cortexDrillStart')
        self.assertIn('!local _group',launcher)
        self.assertIn('execFSM "\\z\\cbe\\addons\\main\\fsm\\tacticalDrill.fsm"',launcher)
        self.assertIn('completedFSM _existingHandle',launcher)
        self.assertIn('CBE_Cortex_DrillFSM',launcher)
        self.assertIn('finite _existingHandle',launcher)
        self.assertIn('_existingHandle >= 0',launcher)
        self.assertIn('finite _handle',launcher)
        self.assertIn('_handle >= 0',launcher)
        self.assertIn('!completedFSM _handle',launcher)
        self.assertIn('[_group,_state,"FSM_START_FAILED",_token] call CBE_fnc_CortexFlankEnd',launcher)
        self.assertNotIn('call CBE_fnc_CortexQueueJob',launcher)
        self.assertNotIn('_handle <= 0',launcher)
        self.assertLess(launcher.index('"FSM_EXECUTOR_ENDED"'),launcher.index('private _handle='))
        self.assertLess(launcher.index('operationGeneration'),launcher.index('private _existing='))
        for name in ['cortexFlankStart','cortexAdvanceStart','cortexSupportBoundStart']:
            start=source(name)
            self.assertIn('call CBE_fnc_CortexDrillStart',start)
            self.assertNotIn('CBE_fnc_CortexFlankStep,',start)
            if name == 'cortexSupportBoundStart':
                self.assertIn('_accepted=[_group,_token] call CBE_fnc_CortexDrillStart;',start)
            else:
                self.assertIn('if !([_group,_token] call CBE_fnc_CortexDrillStart) exitWith {false};',start)
        for name in ['cortexAssaultStart','cortexDrillResume']:
            self.assertIn('if !([_group,_token] call CBE_fnc_CortexDrillStart) exitWith {false};',source(name))
        fsm=(ROOT/'addons/main/fsm/tacticalDrill.fsm').read_text(encoding='utf-8')
        self.assertIn('fsmName = "CBE finite tactical drill"',fsm)
        self.assertIn('call CBE_fnc_CortexFlankStep',fsm)
        self.assertIn('!local _group',fsm)
        self.assertIn('_thisFSM',fsm)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('""jobKey"",""CBE_DRILL_""',fsm)
        self.assertIn('_job get ""jobKey""] call CBE_fnc_CortexQueueJob',fsm)
        self.assertIn('])+15)',fsm)
        self.assertIn('CBE_Cortex_DrillFSMJob',fsm+source('aiGetDiagnostics'))
        for field in ['ownerEpoch','operationGeneration','fsmHandle']:
            self.assertIn('""'+field+'""',fsm)
        step=source('cortexFlankStep')
        executor=step[step.index('// A surviving callback'):step.index('// The generic lifecycle')]
        for proof in ['"cancelled",false','isNotEqualTo _job','"ownerEpoch",-1','"operationGeneration",-1',
                      'CBE_Cortex_DrillFSM','completedFSM _executor','"FSM_EXECUTOR_ENDED" call _end']:
            self.assertIn(proof,executor)
        self.assertLess(step.index('completedFSM _executor'),step.index('call CBE_fnc_OperationStep'))
        end=source('cortexFlankEnd')
        retirement=end[end.index('// Cancel only this exact queued executor.'):end.index('_state deleteAt "drill";')]
        for proof in ['_endingToken','_endingEpoch','_endingGeneration','"cancelled",true','"done",true','fsmHandle']:
            self.assertIn(proof,retirement)

        self.assertNotIn('allGroups',fsm)
        self.assertNotIn('allUnits',fsm)

    def test_fsm_interrupts_restore_only_the_matching_operation(self):
        fsm=(ROOT/'addons/main/fsm/tacticalDrill.fsm').read_text()
        self.assertIn('class ZeusPriority',fsm)
        self.assertIn('class ExternalOwnership',fsm)
        self.assertIn('CBE_fnc_CortexExternalTakeover',fsm)
        self.assertIn('""RELEASE""] call CBE_fnc_CortexDrillInterrupt',fsm)
        self.assertIn('class Disabled',fsm)
        self.assertIn('isNotEqualTo _zeusToken',fsm)
        self.assertIn('CBE_AIPass_ZeusWaypoints',fsm)
        self.assertIn('_job set [""cancelled"",true]',fsm)
        self.assertIn('call CBE_fnc_CortexDrillInterrupt',fsm)
        interrupt=source('cortexDrillInterrupt')
        for guard in ['!local _group', '!= _epoch', '!= _token', '_reason in ["ZEUS","RELEASE"]']:
            self.assertIn(guard,interrupt)
        self.assertIn('call CBE_fnc_CortexFlankEnd',interrupt)
        self.assertNotIn('doMove',interrupt)
        self.assertNotIn('allGroups',fsm)
        self.assertNotIn('nearEntities',fsm)

    def test_calm_requester_fully_releases_responder_reservation(self):
        tick=source('cortexGroupTick')
        calm=tick.split('case "CALM": {',1)[1].split('if (_visible isNotEqualTo [])',1)[0]
        self.assertIn('remoteExecCall ["CBE_fnc_CortexSupportAck",2]',calm)
        self.assertIn('["SUPPORT_RALLY","COORDINATED_ASSAULT"]',calm)
        self.assertIn('_state deleteAt "movementLease"',calm)
        for key in ['supportToken','responding','respondingTo','respondUntil','arrivedAt','assaulting']:
            self.assertIn(f'"{key}"',calm)

    def test_convoy_native_recovery_uses_recorded_pre_extension_point(self):
        text=source('convoyTick')
        recovery=text.split('private _recoveryTarget=',1)[1].split('_vehicle setConvoySeparation',1)[0]
        self.assertIn('_progress param [12,[],[[]]]',recovery)
        self.assertIn('if (_native)',recovery)
        self.assertIn('_progress set [11,[+_pose,time]]',text)
        self.assertNotIn('_progress set [11,+_recordedDestination]',text)
        self.assertIn('_trail findIf {(_x vectorDistance _recoveryTarget) <= 1}',recovery)
        self.assertLess(recovery.index('if (_recorded >= 0 && {_recorded+_trailBase >= (_progress select 3)})'),recovery.index('_movementOperator doMove _recoveryTarget'))
        after=recovery.split('_movementOperator doMove _recoveryTarget;',1)[1]
        self.assertIn('_progress set [10,[driver _vehicle,_movementOperator',after)
        self.assertIn('setVariable ["CBE_Convoy_MovementReceipt",[_group,_revision',after)
        self.assertIn('+(expectedDestination _movementOperator)',after)
        capture=text.index('private _recordedDestination=+_destination')
        extend=text.index('_destination=_destination getPos [40 min')
        self.assertLess(capture,extend)
        commit=text.split('_movementOperator doMove _destination;',1)[1]
        self.assertIn('_progress set [12,+_recordedDestination]',commit)
        writer=text.index('_movementOperator doMove _destination;')
        admission=text.rfind('isNil {if ([_vehicle,_movementOperator] call _mayIssueDriving) then {',0,writer)
        self.assertGreater(admission,extend)
        self.assertIn('[_vehicle,_movementOperator] call _mayIssueDriving',text[admission:writer])

    def test_convoy_two_point_tail_recomputes_cap_and_first_segment_grade(self):
        text=source('convoyTick')
        start=text.index('if (_pathAssistEnabled && {count _path >= 2}) then {')
        block=text[start:text.index('if (_native && {_path isNotEqualTo []})',start)]
        self.assertIn('for "_j" from 0 to (count _path-2)',block)
        self.assertLess(block.index('if (_j > 0)'),block.index('private _a=_path select (_j-1)'))
        self.assertIn('_pathGrade=_pathGrade max (abs (_heightC-_heightB)/_segment)',block)
        self.assertIn('_progress set [8,_pathCap]',block)
        self.assertIn('_limit=_limit min _pathCap',block)
        self.assertIn('private _closingCap',text)
        self.assertIn('call CBE_fnc_DrivingFollowingCap',text)

    def test_live_actor_escape_survives_contact_transition(self):
        tick=source('cortexGroupTick')
        begin=tick.split('private _beginContact = {',1)[1].split('switch (_state get "phase")',1)[0]
        self.assertIn('!(_x call _hasLiveActorMove)',begin)
        self.assertLess(begin.index('!(_x call _hasLiveActorMove)'),begin.index('_x doFollow _leader'))

    def test_post_contact_transitions_do_not_churn_combat_or_actor_moves(self):
        tick=source('cortexGroupTick')
        self.assertIn('private _hasLiveActorMove = {',tick)
        search=tick.split('case "SEARCH": {',1)[1].split('case "REGROUP": {',1)[0]
        self.assertIn('_team select {!(_x call _hasLiveActorMove)}',search)
        regroup=tick.split('case "REGROUP": {',1)[1].split('case "RETREAT": {',1)[0]
        self.assertIn('private _reserved = _members select {',regroup)
        self.assertIn('(_x call _hasLiveActorMove)',regroup)
        self.assertIn('!([_x] call CBE_fnc_CortexActorFireTaskAvailable)',regroup)
        self.assertIn('_members - _reserved',regroup)
        self.assertIn('_unit distance2D _leader <= 8',regroup)
        self.assertIn('"consolidationRoutes"',regroup)
        self.assertIn('_unit doMove _target',regroup)
        self.assertIn('_unit distance2D _lastPos >= 2',regroup)
        self.assertIn('_now - _lastProgressAt >= 10',regroup)
        self.assertIn('_retries < 1',regroup)
        self.assertNotIn('"consolidateIssued"',regroup)
        self.assertIn('_reserved isEqualTo []',regroup)
        self.assertNotIn('doTarget objNull',regroup)
        self.assertNotIn('doWatch objNull',regroup)

    def test_known_contact_investigation_has_no_random_idle_gate(self):
        tick=source('cortexGroupTick')
        calm=tick.split('case "CALM": {',1)[1].split('case "INVESTIGATE": {',1)[0]
        known=calm.split('&& {_enemies isNotEqualTo []}',1)[1]
        self.assertNotIn('random 1',known)
        self.assertIn('_investigationPreference > 0',known)
        self.assertIn('_investigationRange',known)
        self.assertIn('(0.5 + 0.5 * _investigationPreference)',calm)
        self.assertLess(known.index('_investigationPreference > 0'),known.index('[_state, "investigate", 120]'))

    def test_runtime_phase_gates_release_active_investigation_and_post_contact_work(self):
        tick=source('cortexGroupTick')
        gates=tick.split('// Runtime switches are authoritative permissions',1)[1].split('// Soldiers holding ground',1)[0]
        self.assertIn('_activePhase == "INVESTIGATE"',gates)
        self.assertIn('CBE_AIPass_Investigate_Enable',gates)
        for phase in ['SECURITY','SEARCH','REGROUP']:
            self.assertIn(f'"{phase}"',gates)
        self.assertIn('CBE_AIPass_PostContact_Enable',gates)
        self.assertIn('[_group,_state,true,false,_closedReason] call CBE_fnc_CortexRestoreCalm',gates)
        self.assertIn('["POSTCONTACT_DISABLED","INVESTIGATION_DISABLED"]',gates)
        self.assertIn('_activePhase = "CALM"',gates)
        restore=source('cortexRestoreCalm')
        self.assertIn('_state getOrDefault ["searchTeam", []]',restore)
        self.assertIn('[_group] call CBE_fnc_CortexGroupMoveClear',restore)

    def test_calm_handover_reasons_distinguish_completion_control_and_gate_closure(self):
        tick=source('cortexGroupTick')
        for reason in ['INVESTIGATION_GATE_CLOSED','POSTCONTACT_DISABLED','INVESTIGATION_DISABLED',
                       'INVESTIGATION_COMPLETE','INVESTIGATION_TIMEOUT','CONTACT_ENDED',
                       'AUTHORED_ORDER','REGROUP_TIMEOUT','REGROUP_COHESIVE']:
            self.assertIn(f'"{reason}"',tick)
        self.assertIn('"ONBOARD_REPORT_EXPIRED"',source('cortexOnboardContact'))
        self.assertIn('"OWNERSHIP_ADOPTED"',source('cortexLocality'))
        self.assertIn('"CORTEX_STOPPED"',source('cortexStop'))
        self.assertIn('"SURRENDER"',source('cortexSurrender'))
        self.assertIn('"ZEUS_TAKEOVER"',source('cortexZeusMark'))
        lifecycle=(ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text()
        self.assertIn('LIFE-stop-transition-reason',lifecycle)
        self.assertIn('LIFE-zeus-transition-reason',lifecycle)
        self.assertIn('CBE_Cortex_PhaseTransition',lifecycle)

    def test_lifecycle_audit_migrates_active_semantic_state_and_yields_to_zeus(self):
        lifecycle=(ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text()
        for marker in [
            'LIFE-state-investigation-start',
            'LIFE-state-owner-resume',
            'LIFE-state-deadline-preserved',
            'LIFE-state-physical-continuation',
            'LIFE-state-zeus-replacement-arrival',
            'LIFE-state-zeus-no-resurrection',
            'OWNERSHIP_RESUME',
        ]:
            self.assertIn(marker,lifecycle)
        for marker in [
            'LIFE-search-natural-contact',
            'LIFE-search-production-start',
            'LIFE-search-owner-resume',
            'LIFE-search-deadline-preserved',
            'LIFE-search-physical-continuation',
            'LIFE-search-zeus-release',
            'LIFE-retreat-production-start',
            'LIFE-retreat-initial-smoke',
            'LIFE-retreat-owner-resume',
            'LIFE-retreat-start-preserved',
            'LIFE-retreat-physical-continuation',
            'LIFE-retreat-no-smoke-replay',
            'LIFE-retreat-zeus-no-resurrection',
        ]:
            self.assertIn(marker,lifecycle)
        self.assertIn('call CBE_fnc_CortexRetreat',lifecycle)
        self.assertIn('CBE_AIPass_AreaReport',lifecycle)

    def test_withdrawal_migration_respects_zeus_and_feature_gates(self):
        locality=source('cortexLocality')
        self.assertIn('CBE_AIPass_Morale_Enable',locality)
        self.assertIn('CBE_AIPass_Vehicles_Enable',locality)
        self.assertIn('CBE_AIPass_VehicleWithdraw_Enable',locality)
        self.assertIn('switch (_withdrawalKind)',locality)
        self.assertIn('!([_group] call CBE_fnc_CortexZeusHeld)',locality)
        self.assertIn('(_withdrawalIntent select 0) in ["INFANTRY","VEHICLE"]',locality)

    def test_reaction_audit_requires_terminal_retreat_and_surrender_handoffs(self):
        reactions=(ROOT/'releaseVerificationAndDeployment/cortexQA/runReactions.sqf').read_text()
        self.assertIn('SURRENDER-terminal-transition',reactions)
        self.assertIn('RETREAT-regroup-transition',reactions)
        self.assertIn('(_x param [1,""]) == "CONTACT"',reactions)
        self.assertIn('(_x param [3,""]) == "SURRENDER"',reactions)
        self.assertIn('(_x param [1,""]) == "RETREAT"',reactions)
        self.assertIn('(_x param [2,""]) == "REGROUP"',reactions)
        self.assertIn('(_x param [3,""]) == "WITHDRAWAL_COMPLETE"',reactions)

    def test_support_gate_closure_rejects_server_token_and_clears_local_role(self):
        text=source('cortexSupportMaintain')
        release=text.split('private _releaseSupport={',1)[1].split('if (_lease isEqualTo []',1)[0]
        self.assertIn('count _lease == 6',release)
        self.assertIn('_token == (_lease select 0)',release)
        self.assertIn('remoteExecCall ["CBE_fnc_CortexSupportAck",2]',release)
        for key in ['supportToken','responding','respondingTo','respondUntil','arrivedAt','assaulting']:
            self.assertIn(f'"{key}"',release)
        invalid=text.split('if (_lease isEqualTo []',1)[1].split('if (_state getOrDefault ["assaulting"',1)[0]
        self.assertIn('call _releaseSupport',invalid)
        coordinated=text.split('if (_state getOrDefault ["assaulting"',1)[1].split('// Contact can begin',1)[0]
        self.assertIn('CBE_AIPass_CoordinatedAssault_Enable',coordinated)
        self.assertIn('call _releaseSupport',coordinated)

    def test_pending_remount_survives_locality_change_without_extending_deadline(self):
        text=source('cortexLocality')
        self.assertIn('private _remountIntent = _group getVariable ["CBE_Cortex_Remount",[]]',text)
        resume=text.split('// Restore semantic boarding intent',1)[1].split('// Rebuild semantic post-contact intent',1)[0]
        self.assertIn('serverTime < (_remountIntent select 0)',resume)
        self.assertIn('!([_group] call CBE_fnc_CortexZeusHeld)',resume)
        self.assertIn('assignedVehicle _unit == _vehicle',resume)
        self.assertIn('local _unit',resume)
        self.assertIn('CBE_AIPass_Vehicles_Enable',resume)
        self.assertIn('CBE_AIPass_VehicleRemount_Enable',resume)
        self.assertIn('[_remountIntent select 0,+_pendingRemount]',resume)
        self.assertNotIn('serverTime+',resume)

    def test_locality_adoption_rechecks_transition_feature_gates_before_moving(self):
        text=source('cortexLocality')
        resume=text.split('// Rebuild semantic post-contact intent',1)[1].split('// The old owner',1)[0]
        gate=resume.split('private _transitionGateOpen',1)[1].split('if (_transitionGateOpen',1)[0]
        self.assertIn('CBE_AIPass_Investigate_Enable',gate)
        self.assertIn('CBE_AIPass_ContactReports_Enable',gate)
        self.assertIn('CBE_AIPass_Hearing_Enable',gate)
        self.assertIn('CBE_AIPass_PostContact_Enable',gate)
        self.assertLess(resume.index('if (_transitionGateOpen'),resume.index('doMove'))
        self.assertIn('setVariable ["CBE_Cortex_TransitionIntent",nil,true]',resume)

    def test_delayed_counterbattery_and_scoot_recheck_live_owner_gates(self):
        counter=source('cortexCounterBattery')
        delayed=counter.split('params ["_vehicle", "_side", "_position", "_generation", "_observedAt"]',1)[1]
        self.assertIn('CBE_AIPass_CounterBattery_Enable',delayed)
        mission=source('cortexArtilleryMissionStep')
        self.assertIn('setVariable ["CBE_Cortex_ArtilleryScootPurpose",_mission get "purpose",true]',mission)
        scoot=source('cortexArtilleryScoot')
        for item in ['CBE_Cortex_ArtilleryScootPurpose','CBE_AIPass_Artillery_Enable',
                     'CBE_AIPass_CounterBattery_Enable','CBE_AIPass_Artillery_ShootAndScoot',
                     'CBE_AIPass_CounterBattery_ShootAndScoot','call _clear; false']:
            self.assertIn(item,scoot)
        self.assertLess(scoot.index('missionNamespace getVariable [_scootSetting,true]'),scoot.index('CortexGroupMove'))

    def test_remnant_regroup_releases_only_its_owned_unit_holds(self):
        regroup=source('cortexRegroupStep')
        finish=regroup.split('private _finish = {',1)[1].split('if (isNull _group',1)[0]
        self.assertIn('_state getOrDefault ["held",[]]',finish)
        self.assertIn('currentCommand _x',finish)
        self.assertIn('currentCommand _x == "MOVE"',finish)
        self.assertIn('_destination vectorDistance _target <= 0.25',finish)
        self.assertIn('_x doFollow (leader group _x)',finish)
        self.assertIn('_state set ["held",+_movers]',regroup)
        self.assertIn('_held deleteAt (_held find _x)',regroup)
        self.assertNotIn('_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]',finish)
        self.assertNotIn('"GET IN"',finish)
        self.assertIn('_group selectLeader (_movers select 0)',regroup)
        self.assertIn('_group move _target',regroup)
        self.assertNotIn('{doStop _x; _x doMove _target} forEach _movers',regroup)

        regroup=source('cortexRegroupStep')
        queued=source('cortexRegroupOnKill')
        stop=source('cortexStop')
        self.assertIn('["nativeOrderReceipt",[_group] call CBE_fnc_NativeOrderReceipt]',queued)
        self.assertIn('isNotEqualTo (_state get "nativeOrderReceipt")',regroup)
        finish=regroup.split('private _finish = {',1)[1].split('if (isNull _group',1)[0]
        for token in ('currentCommand _x == "MOVE"','_destination vectorDistance _target <= 0.25',
                      'ace_medical_ai_healQueue','!fleeing _x','CortexActorMoveReserved','operationGeneration'):
            self.assertIn(token,finish if token!='operationGeneration' else regroup.split('private _finish = {',1)[0])
        self.assertNotIn('_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]',finish)
        self.assertNotIn('{_x doFollow leader _group} forEach _remaining',regroup)
        self.assertIn('_state set ["target",+_retryTarget]',regroup)
        deadline='if !("deadline" in _state) then {_state set ["deadline",time+_timeout]};'
        self.assertIn(deadline,regroup)
        self.assertEqual(1,regroup.count('_state set ["deadline",'))
        self.assertLess(regroup.index('if (time >= (_state get "deadline")) exitWith {call _finish};'),
                        regroup.index('if (_phase == "EVALUATE") exitWith'))
        self.assertIn('CBE_AIPass_Epoch',stop)
        self.assertNotIn('"baseBehaviour" in _clearJob',stop)
        def owns(command,destination,original,authored_same=True,medical=False,fleeing=False):
            return command=='MOVE' and destination==original and authored_same and not medical and not fleeing
        self.assertTrue(owns('MOVE',1,1))
        for command in ('STOP','ATTACK','FIRE','FOLLOW','HEAL'):
            self.assertFalse(owns(command,1,1))
        self.assertFalse(owns('MOVE',2,1))
        self.assertFalse(owns('MOVE',1,1,False))
        self.assertFalse(owns('MOVE',1,1,medical=True))
        self.assertFalse(owns('MOVE',1,1,fleeing=True))


    def test_remnant_regroup_never_replaces_an_external_order_during_cleanup(self):
        regroup=source('cortexRegroupStep')
        guard=regroup.split('private _mayRestoreHeld = {',1)[1].split('private _finish = {',1)[0]
        finish=regroup.split('private _finish = {',1)[1].split('if (isNull _group',1)[0]
        self.assertIn('CBE_fnc_CortexExternalTakeover',guard)
        self.assertIn('if ([_group] call _mayRestoreHeld) then {',finish)
        self.assertLess(finish.index('if ([_group] call _mayRestoreHeld) then {'),
                        finish.index('_x doFollow (leader group _x)'))
        stalled=regroup.split('if (time - (_state get "lastProgress")',1)[1]
        self.assertNotIn('doFollow',stalled)
        self.assertIn('call _finish',stalled)

    def test_cover_stance_bounds_rays_and_rotates_units(self):
        text=source('cortexStance')
        self.assertIn('{abs speed _unit < 0.5}',text)
        self.assertIn('if (_sampled >= 2) exitWith {}', text)
        self.assertIn('for "_offset" from 0 to ((_count min 12)-1) do {', text)
        self.assertIn('set ["stanceCursor",(_index+1) mod _count]', text)
        self.assertIn('setVariable ["CBE_AIPass_StanceAt", _now + 10]', text)
        self.assertEqual(3,text.count('call _blocked;'))
        receipt=source('cortexStanceReceipt')
        for field in ('count _proof != 4','(_proof select 0) isNotEqualTo _group','(_proof select 1) > _epoch','(_proof select 2) isNotEqualTo "AUTO"','CBE_Cortex_AppliedStance','CBE_AIPass_StanceSet'):
            self.assertIn(field,receipt)
        self.assertNotIn('setUnitPos',receipt)
        self.assertIn('(_weak select 0) isNotEqualTo (_proof select 3)',receipt)
        self.assertIn('(_weak select 1) isNotEqualTo (toUpperANSI unitPos _actor)',receipt)
        self.assertIn('(_weak select 5) isNotEqualTo _group',receipt)
        release_chain=source('dangerEngineRelease').split('private _routine=',1)[1].split('if (_prior != _applied)',1)[0]
        self.assertIn('_prior == (_routine select 3)',release_chain)
        self.assertIn('setUnitPos "AUTO"',release_chain)
        self.assertIn('exitWith {["RESTORE_PENDING"] call _evidence}',release_chain)
        self.assertIn('CBE_Cortex_StanceReceipt",[_group,',text)
        self.assertIn('toUpperANSI unitPos _unit == _stance',text)
        self.assertIn('!fleeing _unit',text)
        self.assertIn('private _nativePostureTask=_reservationFree',text)
        for cleanup_name in ('cortexStance','cortexFlankStep','cortexGroupTick','cortexRestoreCalm'):
            cleanup_source=source(cleanup_name)
            self.assertIn('CBE_fnc_CortexStanceReceipt',cleanup_source)
            self.assertIn('setVariable ["CBE_Cortex_StanceReceipt",nil,true]',cleanup_source)
        for guard in ('simulationEnabled _unit','!isObjectHidden _unit','ace_medical_ai_healQueue',
                      'getUnitState _unit in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]',
                      'currentCommand _unit in ["MOVE","GET IN"',
                      '(_drill get "teams") param [_drill getOrDefault ["teamTurn",0],[]]'):
            self.assertIn(guard,text)
        concealed=text.split('if (behaviour _unit == "STEALTH") then {',1)[1].split('} else {',1)[0]
        self.assertIn('_currentStance == (_unit getVariable ["CBE_Cortex_AppliedStance",""])',concealed)
        self.assertIn('_unit setUnitPos "AUTO"',concealed)
        for forbidden in ('lineIntersectsSurfaces','_sampled=_sampled+1','setUnitPos "UP"','doMove'):
            self.assertNotIn(forbidden,concealed)


    def test_cover_stance_requires_clearance_above_protection(self):
        text=source('cortexStance')
        self.assertIn('case (_lowBlocked && {!_middleBlocked}): {"MIDDLE"}', text)
        self.assertIn('case ((_lowBlocked || {_middleBlocked}) && {!_highBlocked}): {"UP"}', text)
        self.assertNotIn('case ([0.5] call _blocked): {"DOWN"}', text)
        self.assertIn('default {"AUTO"}', text)

    def test_stance_cleanup_preserves_external_override(self):
        for name in ['cortexRestoreCalm','cortexGroupTick']:
            self.assertIn('if (toUpperANSI (unitPos _x) == (_x getVariable ["CBE_Cortex_AppliedStance",""])) then {_x setUnitPos "AUTO"}', source(name))
        stance=source('cortexStance')
        self.assertIn('_currentStance != (_unit getVariable ["CBE_Cortex_AppliedStance",""])', stance)
        self.assertIn('setVariable ["CBE_Cortex_AppliedStance",_stance,true]', stance)

    def test_support_movement_has_priority_over_new_drills(self):
        for name in ['cortexFlankStart', 'cortexAdvanceStart']:
            text = source(name)
            guard = 'if (_state getOrDefault ["responding", false] || {_state getOrDefault ["assaulting", false]}) exitWith {'
            self.assertIn(guard, text)
            if name == 'cortexFlankStart':
                self.assertIn('SUPPORT_OWNS_MOVEMENT', text)
            self.assertNotIn('_group enableAttack false',text)

    def test_assault_contact_does_not_force_combat_mode(self):
        text = source('cortexGroupTick').split('private _beginContact = {')[1].split('switch (_state get "phase")')[0]
        guard = 'if (!_nativeTaskActive && {!(_state getOrDefault ["assaulting", false])}'
        self.assertIn(guard, text)
        self.assertLess(text.index(guard), text.index('_group setBehaviour "COMBAT"'))
        self.assertNotIn('disableAI "AUTOCOMBAT"', text)

        self.assertIn('private _nativeTaskActive = !([_group] call CBE_fnc_CortexGroupPostureTaskAvailable)',text)
        restore=source('cortexRestoreCalm')
        commit=restore.split('private _unresolvedPolicies=[];',1)[1].split('_x params ["_unit", "_vehicle"]',1)[0]
        self.assertIn('isNil {',commit)
        self.assertEqual(commit.count('call CBE_fnc_CortexGroupPostureTaskAvailable'),1)
        for command in ('_group setCombatMode (_retreatModeLease select 0)',
                        '_group setBehaviour _base','_group setSpeedMode (_retreatSpeedLease select 0)'):
            self.assertIn('if (_policyAvailable) then {'+command,commit)
        self.assertIn('CBE_Cortex_CalmPolicyUnresolved',commit)
        for component in ('"COMBAT_MODE"','"BEHAVIOUR"','"SPEED_MODE"'):
            self.assertIn(component,commit)
        self.assertNotIn('CortexQueueJob',commit)
        locality=source('cortexLocality')
        self.assertIn('private _groupPolicyFree=[_group] call CBE_fnc_CortexGroupPostureTaskAvailable',locality)
        policy=locality.split('// OperationStart can invoke locality adoption',1)[1].split('_x params ["_unit", "_feature"]',1)[0]
        self.assertIn('isNil {',policy)
        self.assertIn('CBE_fnc_CortexIsEligible',policy)
        self.assertIn('CBE_fnc_CortexZeusHeld',policy)
        for lease in ('_groupModeLease','_groupSpeedLease'):
            self.assertIn('if (_groupPolicyFree && {count '+lease+' == 2}',locality)
        self.assertIn('behaviour _leader == "SAFE" && {[_group] call CBE_fnc_CortexGroupPostureTaskAvailable}',locality)
        self.assertIn('if (behaviour _leader == "AWARE") then {_adopted set ["behaviourChanged",true]}',locality)

        footprint=source('cortexGroupPostureTaskAvailable')
        for protected in ('fleeing _x','unitCombatMode _x in ["BLUE","GREEN"]',
                          '!isNull objectParent _x','ace_medical_ai_healQueue','count _members > 64'):
            self.assertIn(protected,footprint)

    def test_stalled_bounds_cannot_complete_or_advance(self):
        text = source('cortexFlankStep')
        move = text.split('case "MOVE":')[1].split('case "PAUSE":')[0]
        self.assertIn('["TIME_LIMIT","STALLED"] select (_stalled && {_now <= _moveDeadline})', move)
        self.assertIn('_result = _reason call _end', move)
        self.assertIn('if (_arrived) then', move)
        self.assertNotIn('if (_arrived ||', move)
        end = source('cortexFlankEnd')
        self.assertIn('if (_reason == "COMPLETE") then', end)
        self.assertIn('CBE_Cortex_DrillResult', end)

    def test_recovery_retains_a_coverer_for_a_survivor_pair(self):
        text = source('cortexFlankStep')
        self.assertIn('private _movingAvailable=(_teams select _turn) select {_x in _available};', text)
        self.assertIn('count _movingAvailable < _minimumMovers && {count _coverAvailable > 1}', text)
        self.assertIn('count (_roster select 1) >= 1', text)
        self.assertIn('_pendingRecovery isEqualTo []', text)
        self.assertIn('RECOVERY_REINFORCEMENT', text)
        self.assertIn('TEAM_%1_RECOVERY', text)
        self.assertIn('if (_waitForTeam) exitWith {1.5};', text)
        self.assertIn('(_x select 1) >= 1', text)
        self.assertIn('if (_teamRecoveryFailed) exitWith {"RECOVERY_FAILED" call _end};', text)

    def test_manoeuvres_preserve_covering_element_attack_assignment(self):
        for name in ['cortexFlankStart','cortexAdvanceStart','cortexSupportApply','cortexSupportBoundStart']:
            self.assertNotIn('_group enableAttack false',source(name))
        step=source('cortexFlankStep')
        for feature in ['TARGET','AUTOTARGET']:
            self.assertNotIn(f'_unit disableAI "{feature}"',step)
        self.assertNotIn('_unit disableAI "AUTOCOMBAT"',step)
        self.assertNotIn('_unit setCombatBehaviour "AWARE"',step)

    def test_every_ai_setting_has_an_acceptance_case(self):
        import re, json
        data=json.loads((ROOT/'releaseVerificationAndDeployment/cortexQA/coverage.json').read_text(encoding='utf-8'))
        actual=set(re.findall(r'^\s*\["(CBE_[^"]+)"\s*,',(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8'),re.M))
        declared=[key for case in data['cases'] for key in case['settings']]
        self.assertEqual(actual,set(declared))
        self.assertEqual(len(declared),len(set(declared)))
        controls=[key for case in data['cases'] for key in case.get('controls',[])]
        self.assertEqual({
            'CBE_AIPass_Exclude',
            'CBE_AIPass_Profile',
            'CBE_HelicopterDeceleration_Exclude',
        },set(controls))
        self.assertEqual(len(controls),len(set(controls)))
        self.assertEqual(len(data['cases']),len({case['id'] for case in data['cases']}))
        for case in data['cases']:
            self.assertTrue(case['setup'] and case['expected'])
            self.assertIn('production_sources',case)
            self.assertNotEqual(case['status'],'passed')

    def test_preflight_runs_before_order_state_changes(self):
        text = source('cortexOrderLocal')
        self.assertLess(text.index('call CBE_fnc_CortexOrderReason'),text.index('setVariable ["CBE_AIPass_ZeusWaypoints"'))
        self.assertIn('_oldHold',text)
        self.assertIn('false, clientOwner, "The squad changed owner',text)
    def test_exclude_cleans_all_posted_orders_immediately(self):
        text=source('cortexOrderLocal').split('case "EXCLUDE":')[1].split('case "RETURN":')[0]
        for name in ['ClearRelease','GarrisonRelease','DefendRelease','ReleaseGroup']:
            self.assertIn('CBE_fnc_Cortex'+name,text)
    def test_no_building_garrison_cannot_report_success(self):
        text=source('cortexGarrison')
        self.assertLess(text.index('_candidateAssignments isEqualTo []'),text.index('call CBE_fnc_CortexClearRelease'))
    def test_explicit_native_order_dispatch_has_no_distance_or_module_selection_gate(self):
        dispatch = source('cortexOrderDispatch')
        local = source('cortexOrderLocal')
        self.assertIn('private _group = _settings getOrDefault ["group", grpNull];', dispatch)
        self.assertIn('remoteExecCall ["CBE_fnc_CortexOrderLocal", groupOwner _group];', dispatch)
        self.assertNotIn('distance2D', dispatch)
        self.assertNotIn('nearestObjects', dispatch)
        self.assertIn('[_group,_order,_building] call CBE_fnc_CortexOrderReason', local)
        self.assertIn('if (isNull _group || {!local _group}', local)
        self.assertIn('(units _group) findIf {isPlayer _x}', local)

    def test_cba_is_the_single_authoritative_setting_store(self):
        register = source('aiTweaksRegisterSettings')
        changed = source('aiTweaksSettingChanged')
        tuning = source('cortexTuning')
        self.assertIn('call CBA_fnc_addSetting', register)
        self.assertIn('true, _callback, _activation == "RESTART_REQUIRED"', register)
        self.assertIn('missionNamespace setVariable [_name, _value];', changed)
        self.assertIn('CBA handles callback/JIP replay.', tuning)
        self.assertIn('call CBA_settings_fnc_set', tuning)
        self.assertIn('private _revision = (missionNamespace getVariable ["CBE_AIPass_SettingsRevision",0])+1;', tuning)
        self.assertNotIn('publicVariable "CBE_AIPass_Settings', tuning)

    def test_tuning_is_server_validated_and_does_not_accept_client_snapshot_rollback(self):
        tuning = source('cortexTuning')
        self.assertIn('if (!isServer) exitWith {', tuning)
        self.assertIn('remoteExecCall ["CBE_fnc_CortexTuning", 2];', tuning)
        self.assertIn('only the server or an assigned curator may change it.', tuning)
        self.assertIn('private _spec = [] call CBE_fnc_CortexTuningSpec;', tuning)
        self.assertIn('_updates pushBack [_variable, _value];', tuning)
        self.assertIn('CBA is the sole effective configuration store.', tuning)
        self.assertNotIn('CBE_AIPass_SettingsApplied', tuning)
    def test_engine_suite_uses_real_commands_and_ui_handlers(self):
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        client=(ROOT/'releaseVerificationAndDeployment/cortexQA/runClient.sqf').read_text(encoding='utf-8')
        audit_init=(ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text(encoding='utf-8')
        for function in ['CortexOrderDispatch','HeadlessMigrateGroup','SimpleAiConvoy','CortexArtilleryFire']:
            self.assertIn('call CBE_fnc_'+function,server)
        self.assertIn('addEventHandler ["Fired"',server)
        self.assertIn('CBA_settings_fnc_get',client)
        self.assertNotIn('setVariable ["CBE_AIPass_Aggression"',client)
        self.assertIn('Waldo_fnc_HeadlessMigrateGroup',audit_init)
        self.assertIn('Engine-only HC transfer',audit_init)

    def test_cortex_exports_have_no_legacy_forwarding_aliases(self):
        import re
        text=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        exports=dict(re.findall(r'class (\w+) \{file = "([^"]+)";',text))
        self.assertFalse([name for name in exports if name.startswith('AIPass')])
        self.assertNotIn('CBE_fnc_AIPass',text)
        for path in (ROOT/'addons').rglob('*.sqf'):
            self.assertNotIn('CBE_fnc_AIPass',path.read_text(encoding='utf-8'),path)
    def test_headless_diagnostics_are_read_only_and_bound_their_snapshot(self):
        diagnostics = source('aiGetDiagnostics')
        self.assertIn('if !(isServer) exitWith', diagnostics)
        self.assertIn('private _hcOwners = (entities "HeadlessClient_F") apply {owner _x};', diagnostics)
        self.assertIn('CBE_AI_LastHeadlessAdoption', diagnostics)
        self.assertIn('CBE_fnc_CompatibilityHeadlessRecord', diagnostics)
        self.assertIn('select [0,20]', diagnostics)
        self.assertNotIn('setGroupOwner', diagnostics)
        self.assertNotIn('doMove', diagnostics)

    def test_focused_convoy_keeps_contact_scenarios(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertNotIn('if (_focus != "convoy")',text)
        for case in ['AMB-01-real-enemy-fire','AMB-04-pinned-halt','AMB-07-operating-crew']:
            self.assertIn(case,text)
        for suite in ['cortexQACombat.sqf','cortexQAMechanics.sqf']:
            self.assertIn(suite,text)

    def test_garrison_recovery_does_not_require_finished_move(self):
        text=source('cortexGarrisonApplyLocal')
        self.assertIn('time-_lastProgress >= 12',text)
        self.assertIn('_retries < 2',text)
        self.assertIn('_x doMove _target',text)
        self.assertNotIn('_x setDestination',text)
        self.assertIn('private _nextEntry=if (_approach || {_crossing}) then {_entryIndex+1} else {count _entries}',text)
        self.assertIn('private _target = if (_approach) then {_entries select 0} else {_destination}',text)
        self.assertIn('[_unit] call _applyApproachSpeed',text)
        self.assertIn('[["STANCE","UP"]]',text)
        self.assertIn('_entries resize ((count _entries) min 4)',text)
        self.assertIn('private _replacementEntries=',text)
        self.assertNotIn('_job set ["deadline",(_job get "deadline") max (time+60)]',text)

    def test_garrison_reuses_and_invalidates_its_local_building_topology(self):
        """Entry anchors should not re-enumerate every room once per defender."""
        text=source('cortexGarrisonApplyLocal')
        self.assertIn('CBE_Cortex_GarrisonTopology',text)
        self.assertIn('private _buildingTopologyCache=',text)
        self.assertIn('private _cached=_buildingTopologyCache getOrDefault',text)
        self.assertIn('abs ((_cached select 0)-_damage) > 0.05',text)
        self.assertIn('_cached=[_damage,+(_building buildingPos -1),_transform]',text)
        self.assertIn('private _positions=+(_cached select 1)',text)
        self.assertNotIn('if (_openedDoor) then {_route set [3,time]',text)
        self.assertNotIn('unitReady _x',text)

    def test_building_comparison_is_additive_and_measures_arrival(self):
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('ORD-04b-garrison-arrival',server)
        self.assertIn('DIAG-open-door-garrison',server)
        self.assertIn('cortexQABuildings.sqf',server)
        comparison=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertIn('_unit distance _target <= 2',comparison)
        for case in ['format ["CLEAR-fresh-%1-accepted"','CLEAR-casualty-order-accepted','CLEAR-door-order-accepted']:
            self.assertIn(case,comparison)
        self.assertNotIn('useBuildingBackend',comparison)
        self.assertNotIn('_unit setPos',comparison)
        self.assertNotIn('_actor setPos',comparison)
        self.assertEqual(comparison.count('setPosATL'), 3)
        self.assertIn('_highestAccess >= -0.35', comparison)
        self.assertIn('CLEAR-"+_label+"-placement-access', comparison)
        for fixture in ('_casualtyHouse', '_doorHouse', '_contactHouse'):
            self.assertIn('['+fixture+',', comparison)
        self.assertIn('_house setPosATL', comparison)
        self.assertIn('if (_nativeOnly && {worldName == "VR"}) then', comparison)

    def test_consolidation_orders_follow_and_does_not_call_timeout_arrival(self):
        text=source('cortexGroupTick')
        self.assertIn('_x doFollow _leader',text)
        self.assertIn('_state getOrDefault ["consolidationRoutes", createHashMap]',text)
        self.assertIn('_routes set [_key, [_target, getPosATL _unit, _now, 0,',text)
        self.assertIn('_record set [3, _retries + 1]',text)
        self.assertNotIn('_state set ["consolidateIssued", _now]',text)
        self.assertIn('"consolidationRoutes"',source('cortexRestoreCalm'))
        self.assertIn('["CONSOLIDATING", "INCOMPLETE"] select _expired',text)
        self.assertIn('_gathered == count _members',text)
        self.assertIn('call CBE_fnc_CortexClearRelease',text)
        self.assertNotIn('distance2D _leader > 60',text)

    def test_bound_progress_uses_its_own_explicit_index(self):
        text=source('cortexFlankStep')
        self.assertNotIn('_units apply {[_x distance2D (_spots select _forEachIndex)',text)
        progress=text.split('private _progress = [];',1)[1].split('_drill set ["progress",_progress]',1)[0]
        self.assertIn('(getPosASL _actor) vectorDistance (ATLToASL (_spots select _forEachIndex))',progress)
        self.assertIn('_progress pushBack [_distance,_distanceClock,_lastPose,_motionClock]',progress)
        self.assertIn('} forEach _units',progress)

    def test_visual_audit_suites_are_staged_and_dispatched_by_the_standalone_pipeline(self):
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        pipeline = (ROOT / 'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')", pipeline)
        for suite in ['Reactions', 'Support', 'Airborne']:
            self.assertIn('cortexQA' + suite + '.sqf', server)
        for case in ['ORD-04b-garrison-arrival', 'CNV-08-destination-halt', 'AMB-04-pinned-halt', 'ART-04-finite-burst']:
            self.assertIn(case, server)

    def test_convoy_resume_keeps_local_trails_and_does_not_project_recovery(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('["frontTrails", _resumeTrails]',text)
        self.assertIn('["followers", _resumeFollowers]',text)
        self.assertNotIn('_front getPos [_desiredGap',text)
        self.assertNotIn('if (!_contact && {_stretch > 3}) then {_leadLimit = 0}',text)
        matrix=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        for case in ['BASELINE-WHEELED','BASELINE-TRACKED','BASELINE-MIXED','-resume-forward-progress','-resume-no-turnaround','-stop-fraction']:
            self.assertIn(case,matrix)

    def test_infantry_explicit_fire_respects_group_and_unit_roe(self):
        for name in ('cortexTacticalAssess','cortexAssaultStart','cortexFlankStart',
                     'cortexAdvanceStart','cortexSupportBoundStart','cortexSupportMaintain','cortexFlankStep'):
            text=source(name)
            self.assertIn('unitCombatMode _x in ["YELLOW","RED"]',text)
            self.assertIn('_x checkAIFeature "FIREWEAPON"',text)
        self.assertNotIn('unitCombatMode',source('cortexPrimaryAmmoAvailable'))
        assessment=source('cortexTacticalAssess')
        available=assessment.split('private _availableFoot=',1)[1].split('if (_availableFoot isEqualTo [])',1)[0]
        for guard in ('simulationEnabled _x','!isObjectHidden _x','_x checkAIFeature "FIREWEAPON"',
                      'CortexActorFireTaskAvailable'):
            self.assertIn(guard,available)
        physical=assessment.split('private _foot=',1)[1].split('private _availableFoot=',1)[0]
        self.assertNotIn('FIREWEAPON',physical)
        suppression=source('cortexFireControl').split('// Disciplined suppression',1)[1]
        for marker in ('_geometryChecks >= 3','CortexSuppressionAim',
                       '[_unit, _aimASL] call CBE_fnc_CortexLineOfFireClear',
                       '_unit doSuppressiveFire _aimASL','_cursor+(_geometryChecks max 1)'):
            self.assertIn(marker,suppression)
        self.assertNotIn('doMove',suppression)
        geometry=source('cortexSuppressionAim')
        for marker in ('terrainIntersectASL','true,1,"FIRE","GEOM"',
                       '_surface vectorDistance _targetASL <= 3',
                       '_from vectorDistance _aimASL < _minimum','_platform=vehicle _shooter'):
            self.assertIn(marker,geometry)
        self.assertLess(geometry.index('(_from vectorDistance _targetASL) < _minimum'),
                        geometry.index('lineIntersectsSurfaces'))
        self.assertEqual(geometry.count('lineIntersectsSurfaces'),1)
        for belief,face,allowed in ((30,29,True),(30,19,False),(19,19,False),(20,20,True)):
            self.assertEqual(belief>=20 and face>=20,allowed)

        fire=source('cortexFireControl')
        eligible=fire.split('private _eligible =',1)[1].split('private _reservedActors=',1)[0]
        for guard in ('simulationEnabled _x','!isObjectHidden _x','_x checkAIFeature "FIREWEAPON"'):
            self.assertIn(guard,eligible)
        self.assertLess(fire.index('simulationEnabled _x'),fire.index('_unit doTarget'))
        self.assertNotIn('enableAI "FIREWEAPON"',fire)
        for name in ['cortexFireControl','cortexAntiArmour']:
            text=source(name)
            self.assertIn('combatMode _group in ["YELLOW","RED"]',text)
            self.assertIn('unitCombatMode _x in ["YELLOW","RED"]',text)

    def test_convoy_spacing_does_not_trim_navigation_to_a_short_stop(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('private _bodyGap=_nose+_tail+5;',text)
        self.assertIn('private _bodyGap = _bodyGaps select _i;',text)
        self.assertIn('_frontExtent,_rearExtent',text)
        def facing_gap(follower_bounds, front_bounds):
            return max(follower_bounds[1],0)+max(-front_bounds[0],0)+5
        self.assertEqual(facing_gap((-4,4),(-3,3)),12)
        self.assertEqual(facing_gap((-2,6),(-5,1)),16)
        self.assertEqual(facing_gap((-6,2),(-1,5)),8)

        self.assertNotIn('_frontDistance > _desiredGap * 0.7',text)
        self.assertNotIn('_frontDistance < _gap',text)
        self.assertIn('private _limit = (_frontSpeed + (_controlGap-_desiredGap)*0.4) max 0;',text)

    def test_native_convoy_follower_commits_a_trail_destination_between_refreshes(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        native=text.split('if (_native && {_path isNotEqualTo []}) then {',1)[1].split('_progress set [2, time + 1];',1)[0]
        self.assertIn('private _committedDestination=_progress param [5,[]];',native)
        self.assertIn('private _refreshNative=_goalAdvance > 8;',native)
        self.assertIn('_remainingNative > _refreshRoom',native)
        self.assertIn('(_progress param [13,[],[[]]]) isEqualTo _nativeRoute',native)
        self.assertNotIn('currentCommand driver _vehicle in ["","STOP"]',native)
        self.assertIn('_progress set [5,+_destination];',native)
        self.assertEqual(native.count('_movementOperator doMove _destination;'),1)

    def test_steering_convoy_follower_keeps_one_committed_path_between_trail_samples(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        steering=text.split('} else {\n                if (count _path >= 2) then {',1)[1].split('\n            };\n        } else {',1)[0]
        self.assertIn('private _committedPathDestination=_progress param [6,[]];',steering)
        self.assertIn('_committedPathDestination distance2D _pathDestination > 8',steering)
        self.assertIn('_vehicle setDriveOnPath _path;',steering)
        self.assertIn('_progress set [6,+_pathDestination];',steering)
        self.assertNotIn('_path apply {_x + [_limit / 3.6]}',steering)
        self.assertIn('[getPosATL _vehicle, time, -1, _trailBase, 0, [], []]',text)
        self.assertNotIn('_progress = [getPosATL _vehicle, time, _progress select 2, _progress select 3]',text)

    def test_convoy_spacing_cannot_stabilize_a_lateral_wedge(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('private _pairMeasurement=',text)
        self.assertIn('private _projected=(_longitudinal max 0) min _gap;',text)
        self.assertIn('_rawLateral*_weight',text)
        self.assertIn('_lateralOffset > _tolerance',text)
        recovery=text.split('if (_lateralOffset > _tolerance',1)[1].split('// Reverse yield',1)[0]
        self.assertIn('(_limit max 5) min _closingCap',recovery)
        self.assertNotIn('then {_limit=_limit max 5}',recovery)
        self.assertIn('_pairGap=([_follower,_front,_gaps select _i,_pairGap] call _measurePairGap) select 0;',text)
        self.assertIn('_state deleteAt "spacingObservation"',text)
        self.assertIn('["spacingObservation",[time,_revision,_spacingPairCount]]',text)
        phase=source('convoyOperationStep')
        observation=phase.split('private _spacingObservation=',1)[1].split('if (_recoveryActors > 0)',1)[0]
        self.assertIn('(_spacingObservation select 0) == time',observation)
        self.assertIn('(_spacingObservation select 1) == (_configuration param [0,-1])',observation)
        self.assertIn('_spacingPairs=_spacingObservation select 2',observation)
        self.assertNotIn('getPosATL',observation)
        self.assertNotIn('getDir',observation)

        measure=text.split('private _measurePairGap={',1)[1].split('private _stretch =',1)[0]
        for proof in ('35-_heading','2-_gap/(_desired max 1)','3-2*_angleWeight',
                      '3-2*_rangeWeight','_gap+(_projected-_gap)*_weight'):
            self.assertIn(proof,measure)
        for forbidden in ('forceSpeed','doMove','nearestObjects','lineIntersects'):
            self.assertNotIn(forbidden,measure)

    def test_convoy_snapshot_preserves_navigation_before_release(self):
        text=(ROOT/'addons/vehicles/functions/convoySync.sqf').read_text()
        self.assertLess(text.index('private _navigation ='),text.index('[_group, true, _configuration select 7'))
        self.assertIn('_keepCrew isEqualTo (_configuration select 4)',text)
        self.assertIn('setVariable ["CBE_Convoy_LocalState",_navigation]',text)

    def test_artillery_shot_requires_same_combat_effective_operator(self):
        shot=source("cortexArtilleryShot")
        self.assertEqual(shot.count("[_operator] call CBE_fnc_CortexCombatEffective"),2)
        boundary=shot.split("// Safety/munition checks",1)[1].split("_battery doArtilleryFire",1)[0]
        self.assertIn("gunner _battery != _operator",boundary)
        self.assertIn("!local _battery",boundary)
        self.assertIn("CBE_AIPass_FireToken",boundary)
        self.assertIn("CortexIsEligible",boundary)

    def test_committed_support_adoption_does_not_reauthorize_contact(self):
        apply=source("cortexSupportApply")
        receipt=apply.split("private _committedAttack=",1)[1].split("if (_attackAllowed",1)[0]
        self.assertIn("_attackAllowed && {_same}",receipt)
        self.assertIn("(_publicStatus select 0) == _token",receipt)
        self.assertIn("{_publicStatus select 2} && {_publicStatus select 3}",receipt)
        self.assertIn('_adopting || {_state getOrDefault ["assaulting",false]}',receipt)
        self.assertNotIn("setVariable",receipt)
        self.assertNotIn("serverTime+",receipt)

    def test_coordination_confirmed_contact_age_survives_dispatch(self):
        caller=source("cortexCoordinatedAssault");server=source("cortexSupportAssaultServer");apply=source("cortexSupportApply")
        self.assertIn("clientOwner,_contactConfirmedAt] remoteExecCall",caller)
        self.assertIn("serverTime-_confirmedAt > 60",server)
        self.assertIn('[_token,+_enemy,_confirmedAt],true',server)
        self.assertIn('_contactReceipt param [2,-1,[0]]',apply)
        self.assertIn("serverTime-_contactConfirmedAt <= 60",apply)
        self.assertIn("!_attackAllowed || {_committedAttack} || {_contactFresh}",apply)
        self.assertIn("count _requestContact == 3 && {count _contactReceipt == 3}",apply)
        wait=apply.split("if (_attackAllowed && {!_committedAttack} && {count _requestContact != 3",1)[1].split("// Public contact",1)[0]
        self.assertIn('serverTime < (_job get "waitUntil")',wait)
        self.assertIn("exitWith {0.25}",wait)

    def test_support_drill_handover_uses_believed_contact_geometry(self):
        apply=source("cortexSupportApply")
        match=apply.split("private _localBelief=",1)[1].split("private _replaceLocalDrill",1)[0]
        self.assertIn('getOrDefault ["enemyPos",[]]',match)
        self.assertIn("_localBelief isEqualType []",match)
        self.assertIn("count _localBelief in [2,3]",match)
        self.assertIn("_localBelief findIf {!(_x isEqualType 0)} < 0",match)
        self.assertIn("{_beliefValid} && {_localBelief distance2D _requestContact <= 75}",match)
        self.assertNotIn("_localTarget distance2D",apply)

    def test_garrison_native_task_handover_uses_no_replacement_commands(self):
        tick=source("cortexGroupTick")
        handover=tick.split("// A held garrison arrival job",1)[1].split("// A group tick can complete",1)[0]
        for task in ["GET IN","HEAL","REARM","REPAIR","SCRIPTED","CARRY SOLDIER","ASSEMBLE"]:
            self.assertIn(f'"{task}"',handover)
        self.assertIn("_nativeTask ||",handover)
        self.assertIn('[_group,false,_diverted]',handover)
        for command in ["doMove","doFollow","doStop","setUnitPos","forceSpeed"]:
            self.assertNotIn(command,handover)
        diverted=source("cortexGroupTick").split("private _diverted=_alive select {",1)[1].split("if (_diverted isNotEqualTo [])",1)[0]
        for proof in ("fleeing _actor", "ace_medical_ai_healQueue"):
            self.assertIn(proof,diverted)
        admission=source("cortexGarrison")
        for actor in ("_x", "_actor", "_unit"):
            self.assertIn(f"fleeing {actor}",admission)
            self.assertIn(f'{actor} getVariable ["ace_medical_ai_healQueue",[]]',admission)
        refill=source("cortexGarrisonRefill")
        for actor in ("_x", "_actor"):
            for proof in (f"!fleeing {actor}", f"simulationEnabled {actor}",f"!isObjectHidden {actor}",f'{actor} getVariable ["ace_medical_ai_healQueue",[]]'):
                self.assertIn(proof,refill)

    def test_partial_garrison_release_preserves_other_assignments(self):
        release=source("cortexGarrisonRelease");tick=source("cortexGroupTick")
        self.assertIn('["_actors",[],[[]]]',release)
        self.assertIn("} forEach _actors;",release)
        self.assertIn('if (!_partial || {!_hasAssignments}) then {\n    _group setVariable ["CBE_AIPass_Garrison", nil, true]',release)
        self.assertLess(release.index('} forEach _actors;'),release.index('private _hasAssignments='))
        self.assertIn('findIf {(_x getVariable ["CBE_AIPass_GarrisonPos",[]]) isNotEqualTo []} >= 0',release)
        self.assertIn('[_group,_restore,_actors,_recall] remoteExecCall',release)
        self.assertIn('[_group,false,_diverted] call CBE_fnc_CortexGarrisonRelease',tick)
        self.assertIn('_live vectorDistance (_receipt select 3) <= 0.25',tick)

    def test_garrison_continuation_requires_exact_owned_move(self):
        apply=source("cortexGarrisonApplyLocal")
        callback=apply.split('params ["_job"];',1)[1]
        gate=callback.split("private _mayIssueMovement = {",1)[1].split("private _pending =",1)[0]
        self.assertIn('_command in ["","STOP"]',gate)
        self.assertNotIn('!(_command in ["MOVE","FOLLOW"])',gate)
        self.assertIn('_command == "MOVE" && {count _receipt == 5}',gate)
        self.assertIn('_live vectorDistance (_receipt select 3) <= 0.25',gate)
        self.assertIn('(_receipt select 1) == (_job get "generation")',gate)
        self.assertIn("&& {_commandOwned}",gate)

    def test_garrison_release_preserves_replacement_move_and_follow(self):
        apply=source("cortexGarrisonApplyLocal"); release=source("cortexGarrisonRelease")
        self.assertEqual(apply.count("call _rememberMove;"),9)
        self.assertIn('[_unit,_holdReceiptTarget] call _rememberMove;',apply)
        self.assertIn('(expectedDestination _unit) param [0,_destination]',apply)
        self.assertIn('["rememberMove",_rememberMove]',apply)
        self.assertIn('_live vectorDistance (_move select 3) <= 0.25',release)
        self.assertIn('_command == "MOVE" && {_ownedMove}',release)
        self.assertIn('if (_recallCommand &&',release)
        self.assertIn('setVariable ["CBE_Cortex_GarrisonMove",nil,true]',release)
        for name, actor in (("cortexGarrisonRelease", "_unit"), ("cortexDefendRelease", "_x")):
            text=source(name)
            gate=text.split("private _nativeTask=",1)[1].split("if ([_x] call",1)[0]
            for condition in (f"!simulationEnabled {actor}", f"isObjectHidden {actor}", f"fleeing {actor}", "ace_medical_ai_healQueue", "GET IN", "HEAL", "REARM"):
                self.assertIn(condition,gate)
            self.assertIn("{!_nativeTask}",text)
        # Releasing our own PATH restriction is still necessary for native flight/care.
        self.assertLess(release.index('enableAI "PATH"'),release.index("private _nativeTask="))

    def test_defence_arrival_requires_destination_floor(self):
        defend=source("cortexDefendApplyLocal")
        self.assertIn("(getPosATL _x) vectorDistance (_assignment select 0) > 2",defend)
        self.assertIn("(getPosATL _unit) vectorDistance (_assignment select 0) <= 3",defend)
        self.assertIn("abs (((getPosATL _unit) select 2)-((_assignment select 0) select 2)) <= 1.5",defend)
        self.assertNotIn("if (_unit distance2D (_assignment select 0) <= 3",defend)

    def test_operation_progress_requires_active_observer_and_preserves_baseline(self):
        step=source("operationStep")
        actor=step.split("private _actorProgressed=",1)[1].split("if (_actorProgressed)",1)[0]
        self.assertIn("simulationEnabled _actor",actor)
        self.assertIn("!isObjectHidden _actor",actor)
        self.assertIn("[_lastPosition,_currentPosition] select _actorProgressed",step)
        leader=step.split("if (_participants isEqualTo [] && {!_participantsRequired})",1)[1].split("if (_progressed)",1)[0]
        self.assertIn("simulationEnabled _leader",leader)
        self.assertIn("isObjectHidden _leader",leader)
        self.assertIn("fleeing _leader",leader)
        self.assertIn("ace_medical_ai_healQueue",leader)
        self.assertIn('fallbackProgressSuspended',leader)
        resume=leader.split('if (_wasSuspended) then {',1)[1].split('} else {',1)[0]
        self.assertIn('set ["lastProgressPosition",_position]',resume)
        self.assertNotIn('lastProgressAt',resume)
        self.assertNotIn('_progressed=true',resume)
        self.assertIn('_changed=_fallbackChanged || {_recoveryChanged}',step)


    def test_recovery_dormancy_yields_before_retry_commit(self):
        recovery=source("recoveryStep")
        guard='|| {isObjectHidden _actor}) exitWith {"YIELDED"};'
        self.assertEqual(recovery.count(guard),2)
        self.assertEqual(recovery.count('!(simulationEnabled _actor)'),2)
        self.assertLess(recovery.index(guard),recovery.index("private _recovery="))
        self.assertLess(recovery.rindex(guard),recovery.index("_used set [_key,_attempts+1]"))
        self.assertLess(recovery.rindex(guard),recovery.index("_actor doMove _destination"))
        self.assertNotIn("enableSimulation",recovery)

    def test_clearance_dormant_exit_remains_unresolved_without_retry_consumption(self):
        step=source("buildingOperationStep")
        exit_check=step.split("private _outsideExit={",1)[1].split("// Matching a ground exit",1)[0]
        self.assertLess(exit_check.index("_assignment param [2"),exit_check.index("simulationEnabled _unit"))
        self.assertLess(exit_check.index("simulationEnabled _unit"),exit_check.index("private _outside="))
        self.assertIn("isObjectHidden _unit}) exitWith {true}",exit_check)
        retry=step.split("if ([_x] call _outsideExit &&",1)[1].split("private _records=",1)[0]
        self.assertIn("simulationEnabled _unit",retry)
        self.assertIn("!isObjectHidden _unit",retry)

    def test_clearance_dormancy_blocks_commands_without_erasing_owned_roster(self):
        step=source("buildingOperationStep")
        owned=step.split("private _actorAvailable={",1)[1].split("private _actorTaskFree={",1)[0]
        command=step.split("private _actorTaskFree={",1)[1].split("private _rememberMove=",1)[0]
        reserve=step.split("private _reserveReady={",1)[1].split("private _reserves=",1)[0]
        self.assertNotIn("simulationEnabled",owned)
        self.assertNotIn("isObjectHidden",owned)
        self.assertIn("simulationEnabled _actor",command)
        self.assertIn("!isObjectHidden _actor",command)
        self.assertIn('if !([_candidate] call _actorTaskFree) exitWith {false}',reserve)
        task_free=step.split('private _actorTaskFree={',1)[1].split('// Record only stops',1)[0]
        for guard in ('simulationEnabled _actor','!isObjectHidden _actor','ace_medical_ai_healQueue'):
            self.assertIn(guard,task_free)

    def test_clearance_visit_evidence_requires_visible_simulated_actor(self):
        step=source("buildingOperationStep")
        observer=step.split("private _visitor = _x;",1)[1].split("private _actual = getPosASL _visitor;",1)[0]
        self.assertIn("simulationEnabled _visitor",observer)
        self.assertIn("!isObjectHidden _visitor",observer)
        self.assertIn("CBE_fnc_CortexCombatEffective",observer)
        self.assertNotIn("enableSimulation",observer)

    def test_building_clearance_bounds_topology_arrival_checks(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _visitBudget=(count _positions) min 24;',clear)
        self.assertIn('private _visitCursor=(_job getOrDefault ["visitCursor",0]) mod (count _positions);',clear)
        self.assertIn('_visitIndices pushBackUnique _claimed',clear)
        self.assertIn('} forEach _visitIndices;',clear)
        self.assertIn('} forEach _activeWorkers;',clear)
        self.assertIn('["visitCursor",0]',clear)

    def test_building_clearance_replays_after_a_group_returns_to_a_previous_owner(self):
        discovery=source('cortexDiscover')
        lost_owner=discovery.split('if (!local _group) then {',1)[1].split('};',1)[0]
        self.assertIn('CBE_AIPass_GarrisonApplied',lost_owner)
        self.assertIn('CBE_AIPass_DefendApplied',lost_owner)
        self.assertIn('CBE_AIPass_ClearApplied',lost_owner)
        self.assertIn('CBE_fnc_CortexClearBuilding',discovery)

    def test_locality_handoff_retires_old_operation_before_semantic_resume(self):
        locality=source('cortexLocality')
        cancellation=locality.split('private _navalIntent',1)[1].split('call CBE_fnc_CortexHearingLocal',1)[0]
        self.assertIn('private _previousOperation=_group getVariable ["CBE_Operation",createHashMap];',cancellation)
        self.assertIn('"OWNERSHIP_LOST"] call CBE_fnc_OperationCancel',cancellation)
        self.assertLess(locality.index('"OWNERSHIP_LOST"] call CBE_fnc_OperationCancel'),
                        locality.index('[_group,true] call CBE_fnc_CortexHearingLocal'))

    def test_convoy_uses_the_shared_budgeted_scheduler(self):
        sync=source('convoySync')
        queue=source('convoyOperationQueue')
        step=source('convoyOperationStep')
        scheduler=source('cortexSchedulerTick')
        reconcile=source('schedulerReconcile')
        self.assertNotIn('CBA_fnc_addPerFrameHandler',sync)
        self.assertIn('CBE_fnc_ConvoyOperationStart',sync)
        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_Convoy_SchedulerActive',sync)
        self.assertIn('CBE_fnc_ConvoyTick',step)
        self.assertIn('registryRevision',step)
        self.assertRegex(step, r'(?m)^-1\s*$')
        self.assertIn('case "CONVOY"',scheduler)
        self.assertIn('case "CONVOY"',reconcile)

    def test_convoy_travel_has_one_matching_operation_and_terminal_halt(self):
        tick=source('convoyTick')
        release=source('convoyReleaseLocal')
        eligible=source('cortexIsEligible')
        operation_step=source('operationStep')
        self.assertIn('[_group,"CONVOY",_objective,[],[_objective],"TRAVEL"] call CBE_fnc_OperationStart',tick)
        self.assertIn('if !([_group,false,false,true] call CBE_fnc_CortexIsEligible) exitWith',tick)
        self.assertIn('_state set ["ownerSuspended",true]',tick)
        self.assertIn('_group setVariable ["CBE_Operation",nil,true]',tick)
        self.assertIn('["operationGeneration",_operation getOrDefault ["generation",-1]]',tick)
        self.assertIn('[_group,_operationGeneration,3,120,true] call CBE_fnc_OperationStep',tick)
        self.assertIn('[_group,_generation,"COMPLETE","ARRIVED"] call CBE_fnc_OperationRelease',tick)
        self.assertIn('[_group,_generation,_reason] call CBE_fnc_OperationCancel',tick)
        self.assertIn('[_group,_generation,toUpperANSI _reason] call CBE_fnc_OperationCancel',release)
        self.assertIn('_allowFeatureOwner',eligible)
        self.assertIn('_allowFeatureOwner',operation_step)
        operation_start=source('operationStart')
        self.assertIn('!([_group,false,false,true] call CBE_fnc_CortexIsEligible)',operation_start)
        self.assertLess(operation_start.index('CortexIsEligible'),operation_start.index('private _previous'))

    def test_operation_callers_handle_an_unavailable_owner_before_they_issue_work(self):
        callers={
            'cortexAirAttack': 'if (count _operation == 0)',
            'cortexAdvanceStart': 'if (count _operation == 0) exitWith',
            'cortexClearBuilding': 'if (count _operation == 0) exitWith {',
            'cortexCombinedArmsLocal': 'if (count _operation == 0) exitWith',
            'cortexFlankStart': 'if (count _operation == 0) exitWith',
            'cortexMedicalStep': 'if (count _operation == 0) exitWith {false}',
            'cortexRetreat': 'if (count _operation == 0) exitWith',
            'cortexSupportApply': 'if (count _operation == 0) exitWith',
            'cortexArtilleryScoot': 'if (count _operation == 0) exitWith',
            'cortexVehicles': 'if (count _operation == 0)',
            'cortexNavalAssault': 'if (count _crewOperationRecord == 0) exitWith {',
        }
        for name,guard in callers.items():
            self.assertIn(guard,source(name),name)
        refused=source('cortexClearBuilding').split('if (count _operation == 0) exitWith {',1)[1].split('// Initial owner adoption',1)[0]
        self.assertIn('== _generation',refused)
        self.assertIn('"CBE_AIPass_ClearOrder",nil,true',refused)
        self.assertIn('false',refused)
        convoy=source('convoyTick')
        self.assertIn('ownerSuspended',convoy)
        self.assertLess(convoy.index('ownerSuspended'),convoy.index('call CBE_fnc_OperationStart'))
    def test_vehicle_withdraw_and_standoff_use_finite_operation_generations(self):
        vehicles=source('cortexVehicles')
        self.assertIn('[_group,"VEHICLE_WITHDRAW",_threat,[],[_away],"MOVING"] call CBE_fnc_OperationStart',vehicles)
        self.assertIn('[_group,"VEHICLE_STANDOFF",_atThreat,[],[_away],"MOVING"] call CBE_fnc_OperationStart',vehicles)
        self.assertIn('["vehicleOperationGeneration",_operation get "generation"]',vehicles)
        self.assertIn('["VEHICLE_MOVE_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived',vehicles)
        self.assertIn('vehicle _anchor distance2D _position',vehicles)
        self.assertIn('["MOVEMENT_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived',source('cortexGroupTick'))
        self.assertIn('_state deleteAt "vehicleOperationGeneration"',vehicles)

    def test_artillery_scoot_uses_a_finite_operation_and_group_cleanup(self):
        scoot=source('cortexArtilleryScoot')
        tick=source('cortexGroupTick')
        self.assertIn('[_group,"ARTILLERY_SCOOT",_spot,[],[_spot],"MOVING"] call CBE_fnc_OperationStart',scoot)
        self.assertIn('["artilleryScootOperationGeneration",_operation get "generation"]',scoot)
        self.assertIn('case "ARTILLERY_SCOOT": {"artilleryScootOperationGeneration"};',tick)
        self.assertIn('[_group,_generation,_movementResult,_movementReason] call CBE_fnc_OperationRelease',tick)

    def test_convoy_recovers_only_the_same_unchanged_final_route(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        for marker in ['CBE_Convoy_RouteRecovery_Enable','["routeWatch",',
                       'currentWaypoint _group >= count waypoints _group',
                       'waypointPosition _watchedWaypoint distance2D _watchedPosition < 2',
                       '_watchedRadius max 20)+75','_group setCurrentWaypoint _watchedWaypoint',
                       'CBE_Convoy_RouteRecoveries']:
            self.assertIn(marker,tick)
        recovery=tick.split('private _routeWatch=',1)[1].split('private _routeDone',1)[0]
        for forbidden in ['addWaypoint','deleteWaypoint','setPos','setVelocity','setDamage','setFuel']:
            self.assertNotIn(forbidden,recovery)

    def test_convoy_classifies_a_confirmed_physical_block_without_bypassing_it(self):
        tick=source('convoyTick')
        halt=source('convoyHaltServer')
        registration=source('simpleAiConvoy')
        classifier=tick.split('private _classifyStall = {',1)[1].split('private _vehicles =',1)[0]
        self.assertIn('nearestObjects [_vehicle, ["LandVehicle", "Static"], 20, true]',classifier)
        self.assertIn('!(_candidate in _registered)',classifier)
        self.assertIn('["STALLED", "OBSTRUCTION"] select',classifier)
        for forbidden in ['doMove','doFollow','setDriveOnPath','setPos','setVelocity','setDamage','setFuel']:
            self.assertNotIn(forbidden,classifier)
        self.assertIn('([_lead] call _classifyStall)',tick)
        self.assertIn('([_vehicle] call _classifyStall)',tick)
        self.assertIn('"OBSTRUCTION"',halt)
        self.assertIn('"OBSTRUCTION"',registration)
        self.assertIn('_reason in ["STALLED", "OBSTRUCTION"]',registration)

    def test_convoy_owns_eligible_driving_and_releases_for_real_takeover(self):
        start=(ROOT/'addons/vehicles/functions/simpleAiConvoy.sqf').read_text(encoding='utf-8')
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text(encoding='utf-8')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for forbidden in ['drivingBackend','HBQAD_Pause','HBQAD_PreventDisembark','CompatibilityState']:
            self.assertNotIn(forbidden,start+release+diagnostics)
        self.assertIn('General Driving and Convoy are separate CBE use cases',start)
        self.assertIn('drivingAssist=%3 routeRecoveryEnabled=%4',diagnostics)
        self.assertIn('CBE owns eligible convoy movement',diagnostics)
        self.assertIn('never teleports, repairs or ignores a physical roadblock',diagnostics)
        self.assertIn('private _externalCrew',release)
        self.assertIn('[_crewGroup] call CBE_fnc_CortexExternalTakeover',release)
        self.assertIn('{!_externalCrew}',release)

    def test_convoy_release_does_not_restore_over_an_external_group_owner(self):
        release=source('convoyReleaseLocal')
        self.assertIn('private _externalTakeover = local _group && {',release)
        self.assertIn('private _mayRestoreGroup=local _group && {!_externalTakeover};',release)
        self.assertIn('if (_mayRestoreGroup && {!_preserveMoves}) then {',release)
        self.assertIn('if (_mayRestoreGroup && {!isNull _driver}',release)
        self.assertLess(release.index('private _mayRestoreGroup='),release.index('setFormation _formation'))

    def test_convoy_speed_restore_is_a_vehicle_scoped_lease(self):
        tick=source('convoyTick')
        crew=source('convoyCrewLocal')
        release=source('convoyReleaseLocal')
        self.assertGreaterEqual(tick.count('setVariable ["CBE_Convoy_OwnedSpeed",[_group,_revision,_ownedSpeed]]'),3)
        self.assertIn('setVariable ["CBE_Convoy_OwnedSpeed",[_group,_revision,0]]',crew)
        self.assertIn('private _ownsCurrentSpeed=count _ownedSpeed == 3',release)
        self.assertIn('abs ((getForcedSpeed _vehicle)-(_ownedSpeed select 2)) <= 0.1',release)
        self.assertIn('if (!_externalTakeover && {!_externalCrew} && {!_externalVehicle} && {_ownsCurrentSpeed}) then {',release)
        self.assertIn('if !(_vehicle in _keepCrew) then {',release)
        restore=release.split('if !(_vehicle in _keepCrew) then {',1)[1].split('_vehicle setUnloadInCombat _unload;',1)[0]
        self.assertIn('_vehicle forceSpeed _speed;',restore)
        self.assertNotIn('_vehicle forceSpeed _speed;',release.split('if !(_vehicle in _keepCrew) then {',1)[0])

    def test_convoy_tick_does_not_issue_late_driver_commands_after_external_takeover(self):
        tick=source('convoyTick')
        self.assertIn('private _mayIssueDriving = {',tick)
        self.assertIn('if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {false}',tick)
        self.assertIn('[_group,false,_restore,_registered,"EXTERNAL"] call CBE_fnc_ConvoyReleaseLocal;',tick)
        for command in ['_lead forceSpeed _ownedSpeed',
                        '_leadOperator doMove _watchedPosition',
                        '_movementOperator doMove _destination',
                        '_vehicle setDriveOnPath _path']:
            self.assertLess(tick.rindex('call _mayIssueDriving',0,tick.index(command)+len(command)),tick.index(command))

    def test_group_tick_does_not_rejoin_or_search_over_a_new_external_owner(self):
        tick=source('cortexGroupTick')
        self.assertIn('private _mayIssueMovement = {',tick)
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',tick)
        for command in ['_recallIssued pushBack _x',
                        '_searchActor doMove _searchDestination',
                        '_unit doMove _target']:
            self.assertLess(tick.rindex('[] call _mayIssueMovement',0,tick.index(command)+len(command)),tick.index(command))

    def test_vehicle_contact_commands_yield_to_external_owner_at_issue_time(self):
        vehicles=source('cortexVehicles')
        self.assertIn('private _mayIssueVehicle = {',vehicles)
        self.assertIn('!([_group] call CBE_fnc_CortexExternalTakeover)',vehicles)
        self.assertIn('if !([] call _mayIssueVehicle) exitWith {_movementOwned};',vehicles)
        for command in ['doGetOut _unit',
                        '_gunner doTarget _target',
                        '_gunner doFire _target',
                        '[_group,"VEHICLE_WITHDRAW",true,serverTime+120] call CBE_fnc_CortexOwnershipLease']:
            self.assertLess(vehicles.rindex('[] call _mayIssueVehicle',0,vehicles.index(command)+len(command)),vehicles.index(command))

        stop=source('cortexDismountStop')
        self.assertLess(stop.index('CBE_fnc_CortexExternalTakeover'),stop.index('_vehicle forceSpeed 0'))
        self.assertIn('isNil {',stop)

    def test_ordinary_vehicle_unload_policy_is_exact_owned_and_restorable(self):
        policy=source('cortexVehicleUnloadPolicy')
        convoy_policy=source('convoyUnloadPolicy')
        convoy_tick=source('convoyTick')
        for retention in (policy,convoy_policy):
            disabled=retention.split('if (!canMove _vehicle || {_nativeCrewFlight}) exitWith {',1)[1].split('// First acquisition alone',1)[0]
            self.assertIn('if (count _lease == 5)',disabled)
            self.assertIn('"RELEASE"',disabled)
            self.assertNotIn('moveOut',disabled)
            flight=retention.split('private _nativeCrewFlight=',1)[1].split('// First acquisition alone',1)[0]
            self.assertIn('[driver _vehicle,effectiveCommander _vehicle] findIf',flight)
            self.assertIn('!isNull _x && {fleeing _x}',flight)
            for forbidden in ('forEach crew','orderGetIn','doGetOut','setSuppression','forceSpeed','setFuel'):
                self.assertNotIn(forbidden,flight)

        self.assertLess(convoy_tick.index('// Reconcile retention before mobility filtering'),
                        convoy_tick.index('private _mobile ='))
        vehicles=source('cortexVehicles')
        release=source('cortexReleaseGroup')
        stop=source('cortexStop')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexVehicleUnloadPolicy',functions)
        self.assertIn('effectiveCommander _vehicle) in units _group',policy)
        self.assertIn('CBE_Convoy_Active',policy)
        self.assertIn('CBE_fnc_CortexExternalTakeover',policy)
        self.assertIn('getUnloadInCombat _vehicle isEqualTo _applied',policy)
        adoption=policy.split('if (count _lease == 5) then {',1)[1].split('} else {',1)[0]
        self.assertIn('(_lease select 1) != _epoch || {(_lease select 4) != clientOwner}',adoption)
        self.assertIn('_lease=+_lease',adoption)
        self.assertNotIn('setUnloadInCombat',adoption)
        self.assertIn('if !(_vehicle in _tracked) then {',policy)
        removal=policy.split('private _removeTracked={',1)[1].split('if (_action == "RELEASE")',1)[0]
        self.assertIn('if (_tracked isNotEqualTo _previousTracked) then {',removal)

        self.assertIn('_vehicle setUnloadInCombat _previous;',policy)
        self.assertIn('getUnloadInCombat _vehicle isEqualTo _applied} && {_previous isNotEqualTo _applied}',policy)
        self.assertIn('if (_previous isNotEqualTo _applied) then {_vehicle setUnloadInCombat _applied}',policy)
        self.assertIn('CBE_Cortex_UnloadPolicyBlocked',policy)
        initial=policy.split('// First acquisition alone',1)[1].split('if (count _lease == 5) then',1)[0]
        for guard in ('count _lease != 5 && {getUnloadInCombat _vehicle isNotEqualTo [false,false]}','count _seats > 64','fullCrew [_vehicle,"",true]',
                      'assignedVehicle _incoming == _vehicle','objectParent _incoming != _vehicle',
                      '!local _incoming','== "GET IN"','if (_incomingBoarding) exitWith {false}'):
            self.assertIn(guard,initial)
        self.assertNotIn('setVariable',initial)
        self.assertNotIn('orderGetIn',policy)

        self.assertNotIn('while {',policy)
        self.assertNotIn('spawn',policy)
        self.assertIn('CBE_AIPass_VehicleDismount_Enable',vehicles)
        self.assertIn('fullCrew [_vehicle,"",false]',vehicles)
        self.assertIn('[_x,_group,"ACQUIRE"] call CBE_fnc_CortexVehicleUnloadPolicy;',vehicles)
        self.assertIn('[_x,_group,"RELEASE",!_externalTakeover] call CBE_fnc_CortexVehicleUnloadPolicy;',vehicles)
        self.assertIn('CBE_Cortex_UnloadPolicyVehicles',release)
        self.assertIn('"RELEASE",!_externalTakeover',release)
        self.assertIn('CBE_Cortex_UnloadPolicyLease',stop)
        self.assertIn('vehicle-passenger-ownership',diagnostics)
        self.assertIn('blockedExternalMutations=',diagnostics)
        self.assertIn('invalidLeases=',diagnostics)

    def test_ordinary_vehicle_unload_policy_preserves_external_mutation(self):
        policy=source('cortexVehicleUnloadPolicy')
        mutation=policy.split('if (count _lease == 5 && {getUnloadInCombat _vehicle isNotEqualTo (_lease select 3)})',1)[1]
        mutation=mutation.split('if (count _lease == 5) then {',1)[0]
        self.assertIn('CBE_Cortex_UnloadPolicyLease",nil,true',mutation)
        self.assertIn('CBE_Cortex_UnloadPolicyBlocked",[_group,_epoch],true',mutation)
        self.assertNotIn('setUnloadInCombat',mutation)

    def test_expired_support_reservation_does_not_restore_attack_over_a_new_owner(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _externalTakeover = [_group] call CBE_fnc_CortexExternalTakeover;',maintain)
        self.assertIn('private _mayRestoreGroup=!_externalTakeover && {!_authoredReplaced};',maintain)
        self.assertIn('if (_mayRestoreGroup && {_state getOrDefault ["attackChanged",false]})',maintain)
        self.assertLess(maintain.index('private _mayRestoreGroup='),maintain.index('private _restoreAttack='))

    def test_coordinated_support_exits_before_a_late_external_owner_can_start_or_hold(self):
        """A support callback must retire before allocating a bound or taking PATH from a new owner."""
        maintain=source('cortexSupportMaintain')
        bound=source('cortexSupportBoundStart')
        release=maintain.split('private _releaseSupport={',1)[1].split('private _abort =',1)[0]
        self.assertIn('if (_externalTakeover) exitWith {',release)
        self.assertIn('["EXTERNAL"] call _releaseSupport;',release)
        self.assertLess(release.index('if (_externalTakeover) exitWith {'),maintain.index('doStop _x;'))
        self.assertIn('if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {false};',bound)
        self.assertLess(bound.index('CortexExternalTakeover'),bound.index('_state set ["drill",'))

    def test_convoy_driving_assist_is_bounded_and_does_not_take_route_ownership(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        for marker in ['CBE_Convoy_DrivingAssist_Enable','["roadLookAt",time+3]',
                       'CBE_fnc_DrivingRoadCap','["roadAssist",',
                       '["leadSpeedLimit",[_leadLimit,time]]','private _pathTurn=0;',
                       'private _pathGrade=0;']:
            self.assertIn(marker,tick)
        assist=tick.split('// One bounded road walk per convoy',1)[1].split('// During contact',1)[0]
        for forbidden in ['addWaypoint','deleteWaypoint','setCurrentWaypoint','setDriveOnPath',
                          'setPos','setVelocity','setDamage','setFuel']:
            self.assertNotIn(forbidden,assist)
        self.assertLessEqual(assist.count('nearRoads'),1)


    def test_convoy_grade_uses_absolute_elevation_for_roads_and_trails(self):
        tick=source('convoyTick')
        road=source('drivingRoadCap')
        self.assertIn('CBE_fnc_DrivingRoadCap',tick)
        self.assertIn('getRoadInfo _piece',road)
        self.assertIn('_info param [6,[],[[]]]',road)
        self.assertIn('_info param [7,[],[[]]]',road)
        self.assertIn('getPosASL _piece',road)
        self.assertNotIn('getPosATL',road)
        trail=tick.split('private _pathGrade=0;',1)[1].split('private _pathCap=',1)[0]
        self.assertIn('(ATLToASL _b) select 2',trail)
        self.assertIn('(ATLToASL _c) select 2',trail)
        self.assertIn('abs (_heightC-_heightB)/_segment',trail)

    def test_convoy_matrix_checks_physical_column_and_halt_notifies_curators(self):
        matrix=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        for marker in ['CNVM-terrain-scenario','for "_heading" from 0 to 315 step 45',
                       'for "_along" from -180 to 1000 step 50',
                       '_normal < 0.65','_grade > 0.8','_relief >= 30',
                       'vectorDotProduct _terrainForward','vectorDotProduct _terrainRight',
                       '-single-file']:
            self.assertIn(marker,matrix)
        self.assertIn('_maxLateral <= 8',matrix)
        text=(ROOT/'addons/vehicles/functions/simpleAiConvoy.sqf').read_text()
        self.assertIn('getAssignedCuratorUnit',text)
        self.assertIn('pushBackUnique owner _curator',text)
        self.assertIn('CORTEX CONVOY STOPPED',text)
        self.assertLess(text.index('== "HALT"}) exitWith {true}'),text.index('CORTEX CONVOY STOPPED'))

    def test_convoy_avoidance_audit_uses_route_relative_real_terrain_checks(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyAvoidance.sqf').read_text()
        for marker in ['private _terrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-20,0,20]',
                       'for "_along" from -110 to 650 step 25',
                       '((surfaceNormal _sample) select 2) < 0.65',
                       '_grade > 0.8',
                       '_relief >= 15',
                       'CNV-AVOID-terrain-scenario',
                       'call _terrainPosition',
                       'vectorDotProduct _terrainRight > 15',
                       'vectorDotProduct _terrainForward > _pedestrianAlong+30']:
            self.assertIn(marker,qa)
        self.assertIn('No dry three-lane vehicle corridor',qa)
        self.assertNotIn('getPosATL _man select 0 > 4215',qa)
        self.assertNotIn('getPosATL _lead select 1 > _pedestrianY+30',qa)

    def test_convoy_seat_audit_runs_wheeled_and_tracked_cases_over_real_relief(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoySeats.sqf').read_text()
        for marker in ['private _terrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-20,0,20]',
                       'for "_along" from -80 to 2500 step 50',
                       '((surfaceNormal _sample) select 2) < 0.65',
                       '_grade > 0.8',
                       '_relief >= 40',
                       'SEATS-terrain-scenario',
                       'call _terrainPosition',
                       '_v setDir _terrainHeading']:
            self.assertIn(marker,qa)
        self.assertIn('No dry three-lane 2.5 km corridor',qa)
        self.assertIn('["TRACKED-","O_APC_Tracked_02_cannon_F"]',qa)

    def test_remount_retries_physical_boarding_and_cancels_on_contact(self):
        restore=source('cortexRestoreCalm')
        tick=source('cortexGroupTick')
        self.assertIn('[serverTime+60,+_boarding]',restore)
        self.assertIn('serverTime >= _deadline',tick)
        self.assertIn('vehicle (_x select 0) != (_x select 1)',tick)
        self.assertIn('_visible isNotEqualTo [] || {_dangerActive} || {_ordered}',tick)
        self.assertIn('[_unit] orderGetIn false;',tick)
        self.assertIn('unassignVehicle _unit;',tick)
        self.assertNotIn('moveInCargo',tick)

    def test_recovery_halts_preserve_passengers_and_validate_vehicle(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        halt=(ROOT/'addons/vehicles/functions/convoyHaltServer.sqf').read_text(encoding='utf-8')
        api=(ROOT/'addons/vehicles/functions/simpleAiConvoy.sqf').read_text(encoding='utf-8')
        self.assertEqual(tick.count('if (_attempts > 3)'),2)
        self.assertNotIn('doFollow driver _front',tick)
        self.assertIn('_blockedVehicle in (_configuration select 4)',halt)
        self.assertIn('if !(_reason in ["STALLED", "OBSTRUCTION"]) then',api)
        self.assertIn('"OBSTRUCTION"',halt)
        self.assertNotIn('setPos',tick)
        self.assertNotIn('disableCollisionWith',tick)

    def test_convoy_can_acquire_forward_trail_beyond_initial_capture_radius(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('if (_nearest < 0)',text)
        self.assertIn('(_delta vectorDotProduct _heading) > _length*0.5',text)
        self.assertIn('_nearest + ([1,0] select _joining)',text)
        self.assertIn('if (count _state > 0 && {!_sameLine})',text)
        self.assertNotIn('driver _lead doMove (waypointPosition',text)

    def test_convoy_retains_actual_seat_for_crew_and_both_cargo_group_layouts(self):
        text=(ROOT/'addons/vehicles/functions/convoyCrewLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('_assignedOccupant != _unit',text)
        for role in ['assignAsDriver','assignAsCommander','assignAsGunner','assignAsCargoIndex','assignAsTurret']:
            self.assertIn(role,text)
        self.assertNotIn('moveIn',text)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoySeats.sqf').read_text(encoding='utf-8')
        self.assertIn('forEach [_convoy,_cargoGroup]',qa)
        self.assertIn('addEventHandler ["GetOutMan"',qa)
        self.assertIn('SEATS-travel-no-exits',qa)
        self.assertIn('SEATS-halt-operating-crew-retained',qa)
        self.assertIn('{deleteVehicle _x} forEach _actors',qa)

    def test_deceleration_old_owner_cannot_clear_new_worker(self):
        base=ROOT/'addons/aircraft/functions'
        init=(base/'helicopterDecelerationInit.sqf').read_text(encoding='utf-8')
        self.assertIn('GenerationLocal",0])+1',init)
        self.assertIn('CBE_fnc_HelicopterDecelerationStep',init)
        self.assertIn('["subsystem", "AIRCRAFT"]',init)
        self.assertIn('CBE_Aircraft_DecelerationSchedulerActive',init)
        step=(base/'helicopterDecelerationStep.sqf').read_text(encoding='utf-8')
        self.assertIn("getOrDefault ['generation',-1]",step)
        self.assertIn('CBE_Cortex_AirAttackJob',step)
        self.assertIn('CBE_fnc_CortexExternalTakeover',step)
        self.assertNotIn('while {',step)
        self.assertNotIn('uiSleep',step)
        correction=(base/'helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('["_generation",-1,[0]]',correction)
        self.assertIn('CBE_Cortex_AirAttackJob',correction)
        cleanup=correction[correction.rindex('if (!isNull _aircraft'):]
        self.assertIn('local _aircraft',cleanup)
        self.assertIn('CBE_fnc_FlightLeaseRelease',cleanup)
        self.assertIn('CBE_HelicopterDeceleration_GenerationLocal',correction)
        self.assertIn('== _generation',correction)
        self.assertFalse((base/'helicopterDecelerationTrackLocal.sqf').exists())

    def test_aircraft_scheduler_is_independent_from_tactical_master_gate(self):
        scheduler=source('cortexSchedulerTick')
        reconcile=source('schedulerReconcile')
        callback=source('aiTweaksSettingChanged')
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('CBE_Aircraft_SchedulerActive',scheduler)
        self.assertIn('case "AIRCRAFT": {"CBE_Aircraft_SchedulerActive"}',scheduler)
        self.assertIn('case "AIRCRAFT": {_aircraft};',reconcile)
        self.assertIn('if (_subsystem in ["CONVOY", "AIRCRAFT"]) then {_jobPaused=false};',scheduler)
        self.assertIn('!(_subsystem in ["CONVOY", "AIRCRAFT"])',scheduler)
        self.assertIn('find "CBE_DECEL_" == 0',scheduler)
        self.assertIn('find "CBE_LANDING_" == 0',scheduler)
        self.assertIn('CBE_HelicopterDeceleration_GenerationLocal", (_x getVariable',callback)
        self.assertIn('CBE_Aircraft_DecelerationSchedulerActive", false',callback)
        self.assertIn('CBE_fnc_SchedulerReconcile',callback)
        self.assertIn('"aircraft-scheduler-health"',diagnostics)
        self.assertIn('serverLocalJobs=%1 landingObservers=%2 decelerationObservers=%3',diagnostics)
        self.assertIn('This owner-local snapshot excludes aircraft currently owned by clients or headless clients',diagnostics)

    def test_landing_tracker_generation_prevents_stale_owner_cleanup(self):
        base=ROOT/'addons/aircraft/functions'
        init=(base/'improvedHelicopterLandingInit.sqf').read_text(encoding='utf-8')
        step=(base/'improvedHelicopterLandingStep.sqf').read_text(encoding='utf-8')
        self.assertIn('TrackerGenerationLocal", 0]) + 1',init)
        self.assertIn('CBE_fnc_ImprovedHelicopterLandingStep',init)
        self.assertIn('["subsystem", "AIRCRAFT"]',init)
        self.assertIn('CBE_Aircraft_LandingSchedulerActive',init)
        self.assertIn('getOrDefault ["generation", -1]',step)
        self.assertIn('TrackerGenerationLocal", 0]) != _generation',step)
        self.assertIn('TrackerGenerationLocal", 0]) == _generation',step)
        self.assertNotIn('while {',step)
        self.assertNotIn('uiSleep',step)
        self.assertFalse((base/'improvedHelicopterLandingTrackLocal.sqf').exists())

    def test_air_attack_reads_driver_weapons_outside_turret_inventory(self):
        text=(ROOT/'addons/aircraft/functions/cortexAirAttackPlan.sqf').read_text(encoding='utf-8')
        self.assertIn('(weapons _aircraft)+(_aircraft weaponsTurret [-1])',text)
        self.assertIn('_driverWeapons arrayIntersect _driverWeapons',text)
        self.assertIn('private _loadedMagazines=[];private _nativeQueries=0',text)
        self.assertIn('getText (_magazineConfig >> "pylonWeapon")',text)
        self.assertIn('weaponState [_aircraft,_turret,_weapon]',text)
        self.assertIn('forEach _stationMagazines',text)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text(encoding='utf-8')
        self.assertIn('private _ended=if (!_started) then {false}',qa)
        self.assertNotIn('moveInTurret',qa)
        self.assertNotIn('_airGroup createUnit',qa)

    def test_deceleration_releases_changed_order_before_impulse(self):
        text=(ROOT/'addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        for marker in ['waypointPosition _wp','waypointType _wp','waypointScript _wp','waypointSpeed _wp',
                       'currentPilot _aircraft == _entryPilot','CBE_fnc_CortexExternalTakeover','ORDER_CHANGED']:
            self.assertIn(marker,text)
        self.assertIn('&& {call _ownsOrder}',text)
        self.assertLess(text.index('&& {call _ownsOrder}'),text.index('_aircraft addForce'))

    def test_aircraft_controllers_yield_to_full_takeover_before_flight_writes(self):
        helper=source('cortexExternalTakeover')
        for marker in ['remoteControlled _x','bis_fnc_moduleRemoteControl_owner']:
            self.assertIn(marker,helper)
        deceleration=(ROOT/'addons/aircraft/functions/helicopterDecelerationStep.sqf').read_text(encoding='utf-8')
        correction=(ROOT/'addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        landing=(ROOT/'addons/aircraft/functions/improvedHelicopterLandingExecuteLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('CBE_fnc_CortexExternalTakeover',deceleration)
        self.assertIn('CBE_fnc_CortexExternalTakeover',correction)
        self.assertGreaterEqual(landing.count('CBE_fnc_CortexExternalTakeover'),2)
        final=landing.split('// This controller is scheduled:',1)[1]
        self.assertLess(final.index('CBE_fnc_CortexExternalTakeover'),final.index('setVectorDirAndUp'))
        anchor=(ROOT/'addons/aircraft/functions/improvedHelicopterLandingAnchorLocal.sqf').read_text(encoding='utf-8')
        self.assertGreaterEqual(anchor.count('CBE_fnc_CortexExternalTakeover'),2)
        self.assertLess(anchor.index('CBE_fnc_CortexExternalTakeover', anchor.index('EXTERNAL_REPOSITION')),anchor.index('_helicopter addForce'))
        airborne=source('cortexAirborneCheck')
        self.assertLess(airborne.index('CBE_fnc_CortexExternalTakeover'),airborne.index('_aircraft flyInHeight'))
        eligible=source('cortexAircraftEligible')
        self.assertIn('CBE_fnc_CortexExternalTakeover',eligible)

    def test_deceleration_impulse_uses_elapsed_simulation_time(self):
        text=(ROOT/'addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('time - _lastImpulseTime',text)
        self.assertIn('min 0.1',text)
        self.assertIn('min ((_climbRate - _maximumClimbRate) max 0)',text)
        self.assertNotIn('_acceleration * _interval',text)

    def test_deceleration_observes_before_braking_order(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDeceleration.sqf').read_text(encoding='utf-8')
        self.assertLess(text.index('private _startSpeed=abs speed'), text.index('_wp setWaypointPosition'))
        self.assertLess(text.index('_id+": braking"'), text.index('private _startSpeed=abs speed'))
        for name in ['helicopterDecelerationStep','helicopterDecelerationCorrectLocal']:
            code=next((ROOT/'addons').rglob(name+'.sqf')).read_text(encoding='utf-8')
            self.assertIn('CBE_HelicopterDeceleration_IncludeVTOL',code)

    def test_deceleration_exclusion_uses_a_live_braking_envelope(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDeceleration.sqf').read_text(encoding='utf-8')
        exclusion=text.split('// A per-aircraft opt-out',1)[1]
        self.assertIn('CBE_HelicopterDeceleration_Exclude",true,true',exclusion)
        self.assertIn('speed _excludedAircraft >= 120',exclusion)
        self.assertIn('_excludedWp setWaypointSpeed "LIMITED"',exclusion)
        self.assertIn('CBE_HelicopterDeceleration_Active',exclusion)
        self.assertIn('DECEL-aircraft-exclusion-live-envelope',exclusion)
        self.assertIn('DECEL-aircraft-exclusion-route-preserved',exclusion)

    def test_qa_suites_are_additive_and_staged_by_the_standalone_pipeline(self):
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        pipeline = (ROOT / 'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')", pipeline)
        for name in ['Deceleration', 'Aircraft', 'Lifecycle', 'Coordinated', 'Profiles', 'Scheduler', 'ArtillerySmoke', 'Contact', 'Avoidance', 'Landing', 'Cover', 'Gates', 'Gunnery', 'Seats', 'Buildings', 'ConvoyMatrix', 'Combat', 'Mechanics', 'Reactions', 'Support', 'Airborne', 'Vehicles', 'Fire']:
            self.assertIn('cortexQA' + name + '.sqf', server)
        matrix = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text(encoding='utf-8')
        self.assertIn('{deleteVehicle (_x select 0)} forEach _fixtureCrew', matrix)
        self.assertIn('-operating-crew-retained', matrix)

    def test_support_owner_move_and_cover_preserve_strict_actor_reservations(self):
        start=source('cortexSupportBoundStart')
        fit=start.split('private _fit=',1)[1].split('if (count _fit < 3)',1)[0]
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',fit)
        self.assertIn('ace_medical_ai_healQueue',fit)
        maintain=source('cortexSupportMaintain')
        cover=maintain.split('private _coverIdentity=',1)[1]
        self.assertLess(cover.index('!([_x] call CBE_fnc_CortexActorMoveReserved)'),cover.index('doStop _x'))
        for guard in ('simulationEnabled _x','!isObjectHidden _x','ace_medical_ai_healQueue'):
            self.assertLess(cover.index(guard),cover.index('doStop _x'))
        self.assertIn('(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []',maintain)
        for code in [start,cover]:
            self.assertNotIn('count _actorMove != 3',code)
            self.assertIn('CBE_fnc_CompatibilityExternalControl',code)
            self.assertIn('"CARRY SOLDIER"',code)

    def test_drill_refill_checks_strict_actor_ownership_before_roster_mutation(self):
        step=source('cortexFlankStep')
        rank=step.split('private _rankCandidates={',1)[1].split('private _units=[];',1)[0]
        self.assertIn('private _reservationFree=!([_x] call CBE_fnc_CortexActorMoveReserved);',rank)
        self.assertNotIn('_reservation param [2,1e12,[0]]',rank)
        self.assertIn('CBE_fnc_CompatibilityExternalControl',rank)
        self.assertIn('"CARRY SOLDIER"',rank)
        refill=step.split('private _units=[];',1)[1]
        self.assertLess(refill.index('call _rankCandidates'),refill.index('_units pushBack _x'))

    def test_drill_steps_cannot_adopt_a_replacement_action(self):
        step=source('cortexFlankStep')
        self.assertLess(step.index('private _token ='),step.index('private _end ='))
        self.assertIn('_token != (_drill getOrDefault ["token",""])',step)
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            code=source(name)
            self.assertIn('["token",_token]',code)
            self.assertIn('[_group,_token] call CBE_fnc_CortexDrillStart',code)
            self.assertIn('CBE_Cortex_DrillSerial',code)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-stale-step-no-mutation',qa)
        self.assertIn('_before isEqualTo _after',qa)

    def test_drill_failure_distinguishes_progress_timeout_and_qa_expiry(self):
        step=source('cortexFlankStep')
        self.assertIn('["TIME_LIMIT","STALLED"] select (_stalled && {_now <= _moveDeadline})',step)
        self.assertIn('(_last select 0)-_remaining >= 0.5',step)
        self.assertIn('CBE_Cortex_DrillFailure',step)
        self.assertIn('currentCommand _unit,expectedDestination _unit',step)
        self.assertIn('_now-(_last select 3) > _timeout',step)
        self.assertIn('_pose vectorDistance (_last select 2) >= 0.5',step)
        self.assertNotIn('_combatModes pushBack [_unit,"RED","BLUE"]',step)
        self.assertIn('_group setCombatMode "YELLOW"',step)
        self.assertNotIn('_group setCombatMode "BLUE"',step)
        self.assertNotIn('_unit disableAI "AUTOTARGET"',step)
        self.assertNotIn('_disabled pushBack [_unit,"AUTOTARGET"]',step)
        fire=source('cortexFireControl')
        self.assertIn('currentCommand _x in ["MOVE","GET IN","GET OUT"',fire)
        roster=fire[fire.index('private _eligible ='):fire.index('private _members =')]
        self.assertIn('abs (speed _x) < 0.5',roster)
        self.assertEqual(fire.count('speed _x'),1)
        self.assertLess(fire.index('abs (speed _x) < 0.5'),fire.index('_unit doTarget'))
        self.assertNotIn('disableAI',fire)
        self.assertIn('} forEach _members;',fire)
        self.assertNotIn('} forEach (_members + _movingMembers);',fire)
        self.assertIn('replace their owned LEADER PLANNED destination with native ATTACK pursuit',fire)
        self.assertNotIn('_disabled pushBack [_unit,"TARGET"]',step)
        for capability in ['WEAPONAIM', 'FIREWEAPON']:
            self.assertNotIn(f'_unit disableAI "{capability}"',step)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-observation-completed',qa)
        coordinated=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for marker in ['COORD-base-actual-supporting-fire','COORD-team-%1-actual-fire','from 0 to (_helperSize-1)','from 1 to 5']:
            self.assertIn(marker,coordinated)
        for marker in ['CBE_fnc_CortexQASetCombatMode','CBE_CortexQA_CombatModeReceipt',
                       'CBE_CortexQA_FiredManOwner','COORD-shot-sampler-',
                       'CBE_Cortex_DrillTransition']:
            self.assertIn(marker,coordinated)
        self.assertNotIn('{_x setCombatMode "RED"} forEach',coordinated)
        self.assertNotIn('private _state=_g getVariable ["CBE_AIPass_State"',coordinated)

    def test_successive_advance_exchanges_only_after_arrival(self):
        start=source('cortexAdvanceStart')
        step=source('cortexFlankStep')
        self.assertIn('["teams",[_element,_coverElement]]',start)
        self.assertIn('["units", _onFoot]',start)
        self.assertIn('_drill set ["teamTurn",1]',step)
        self.assertIn('if (_arrived) then',step)
        self.assertIn('forEach (_fit - _units)',step)
        self.assertIn('[-8,8] select',step)
        fire=source('cortexFireControl')
        self.assertIn('_drill getOrDefault ["movers",_drill getOrDefault ["units",[]]]',fire)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        for marker in ['-both-elements-bounded','-cover-held-during-bounds','-actual-covering-fire']:
            self.assertIn(marker,qa)

    def test_assault_transition_covers_advance_and_crosses_fixed_objective(self):
        step=source('cortexFlankStep')
        hold=step[step.index('    case "HOLD":'):]
        self.assertNotIn('== "FLANK"',hold.split('private _assault =')[1].split('private _assaultDirection')[0])
        self.assertIn('_enemyPos getPos [20,_crossingDirection]',hold)
        self.assertIn('forEach [0,-15,15,-30,30]',hold)
        self.assertIn('[_centroid,_assaultCandidates,_enemyPos] call CBE_fnc_CortexSelectAvenue',hold)
        self.assertIn('["assaultObjective",+_enemyPos]',hold)
        self.assertIn('_drill get "assaultDirection"',step)
        self.assertIn('if (_assaulting && {!_assaultEnabled})',step)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-physical-clear-through',qa)
        self.assertIn('vectorDotProduct _forward) < 10',qa)
        self.assertIn('count _clearThroughTeams >= ([1,2] select _advance)',qa)

    def test_assault_frag_is_opportunistic_and_never_blocks_movement(self):
        step=source('cortexFlankStep')
        hold=step[step.index('    case "HOLD":'):]
        self.assertNotIn('"FRAG"',hold)
        self.assertIn('case "ASSAULT": {',step)
        self.assertNotIn('case "GRENADE": {',step)
        self.assertNotIn('"GRENADE_UNRESOLVED" call _end',step)
        self.assertIn('"START","ASSAULT_COMMITTED"] call CBE_fnc_CortexDrillSetStage',step)
        self.assertNotIn('_drill set ["pauseUntil", _now + 1]',step)
        self.assertIn('_drill set ["pauseUntil",_now]',step)
        self.assertIn('_drill set ["grenadeActionUntil",_now]',step)
        grenade=source('cortexThrowGrenade')
        self.assertIn('addEventHandler ["FiredMan"',grenade)
        self.assertIn('removeEventHandler ["FiredMan",_thisEventHandler]',grenade)
        self.assertIn('[_unit,_handler],10',grenade)

    def test_assault_handoffs_issue_movement_without_an_extra_scheduler_turn(self):
        step=source('cortexFlankStep')
        commitment=step.split('"START","ASSAULT_COMMITTED"]')[1].split('} else {')[0]
        self.assertIn('_drill set ["index",count _points-2]',commitment)
        self.assertIn('_drill set ["teamTurn",0]',commitment)
        self.assertIn('_holdIssue=true',commitment)
        self.assertIn('if (_holdIssue) then {call _issue}',step)
        self.assertLess(step.index('if (!_holdCommitted) exitWith'),step.index('if (_holdIssue) then {call _issue}'))
        self.assertNotIn('pauseUntil',commitment)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-transition-assault-no-idle-turn',qa)
        self.assertIn('_commitIndex+1 < count _caseTransitions',qa)
        approach=step.split('if (_arrivalAssault) then {',1)[1].split('    case "PAUSE": {',1)[0]
        crossing=approach
        self.assertNotIn('if (!_queued) then {',approach)
        self.assertIn('_drill set ["index",(_drill get "index")+1]',crossing)
        self.assertIn('call _issue',crossing)
        self.assertIn('"FRAG",["DRILL",_group,_token,_operationGeneration,_rosterEpoch]] call CBE_fnc_CortexThrowGrenade',approach)

    def test_combat_grenade_qa_measures_projectile_and_hold(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        for marker in ['FLANK-GRENADE','-actual-frag-deployed','-grenade-dispatch-observed','-grenade-clear-through',
                       '-transition-grenade-dispatch-no-idle-turn', '_records pushBack [_projectile,time,getPosATL _unit]',
                       'ASSAULT_GRENADE_DISPATCHED']:
            self.assertIn(marker,qa)
        self.assertIn('["CBE_AIPass_Assault_Enable",_case != "ADVANCE-CLOSE"]',qa)

    def test_manoeuvre_transitions_are_public_bounded_and_audited(self):
        helper=source('cortexDrillSetStage')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text(encoding='utf-8')
        self.assertIn('class CortexDrillSetStage',functions)
        for marker in ['CBE_Cortex_DrillTransition','CBE_Cortex_DrillTransitions',
                       'count _history > 64','setVariable ["CBE_Cortex_DrillTransitions",_history,true]']:
            self.assertIn(marker,helper)
        for name,reason in [('cortexFlankStart','FLANK_ACCEPTED'),
                            ('cortexAdvanceStart','ADVANCE_ACCEPTED'),
                            ('cortexSupportBoundStart','COORDINATED_BOUND_ACCEPTED')]:
            text=source(name)
            self.assertIn('["stage",""]',text.replace(' ',''))
            self.assertIn(reason,text)
            self.assertIn('call CBE_fnc_CortexDrillSetStage',text)
        self.assertIn('"ENDED",_reason] call CBE_fnc_CortexDrillSetStage',source('cortexFlankEnd'))
        self.assertNotIn('_drill set ["stage"',source('cortexFlankStep'))
        for marker in ['-transition-start','-transition-move','-transition-ended','-transition-order',
                       '-transition-assault-committed','-transition-clear-through','-transition-grenade-dispatch-no-idle-turn']:
            self.assertIn(marker,qa)

    def test_grenade_dispatch_keeps_listener_cleanup_owned(self):
        self.assertIn('_flight set [4,time]',source('cortexThrowGrenade'))
        self.assertNotIn('((_flight select 4)+8)',source('cortexFlankStep'))
        end=source('cortexFlankEnd')
        self.assertIn('(_flight select 0) == (_drill getOrDefault ["token",""])',end)
        self.assertIn('removeEventHandler ["FiredMan",_handler]',end)

    def test_pending_assault_frag_rechecks_gate_and_migration_retires_listener(self):
        grenade=source('cortexThrowGrenade')
        callback=grenade[grenade.index('params ["_unit", "_muzzle"'):]
        self.assertIn('CBE_AIPass_Assault_Enable',callback)
        self.assertLess(callback.index('CBE_AIPass_Assault_Enable'),callback.index('forceWeaponFire'))
        locality=source('cortexLocality')
        self.assertIn('removeEventHandler ["FiredMan",_fragHandler]',locality)
        self.assertLess(locality.index('CBE_Cortex_FragHandler'),locality.index('if (!_gained'))

    def test_reaction_qa_keeps_previous_cancellations_and_adds_assault_disable(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runReactions.sqf').read_text()
        self.assertIn('["CAPTIVE","ZEUS","DRILL-REPLACED","ASSAULT-DISABLED"]',qa)
        self.assertIn('_shots == 0',qa)
        self.assertIn('_after == _before',qa)
        self.assertIn('["CBE_AIPass_Assault_Enable",false]',qa)

    def test_multi_withdrawal_audit_uses_separate_measured_terrain_lanes(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runReactions.sqf').read_text()
        for marker in ['private _withdrawTerrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-45,0,45]',
                       'for "_along" from -180 to 100 step 20',
                       '_normal < 0.55',
                       '_grade > 0.75',
                       '_relief >= 12',
                       'MULTI-WITHDRAW-terrain-scenario',
                       'call _withdrawPosition',
                       'vectorDotProduct (_withdrawForward vectorMultiply -1)',
                       'MULTI-WITHDRAW-distinct-terrain-lanes']:
            self.assertIn(marker,qa)
        self.assertIn('if (!_withdrawTerrainReady) then {',qa)
        self.assertIn('No dry three-lane corridor',qa)

    def test_support_audit_rotates_hearing_reports_and_reinforcement_over_terrain(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runSupport.sqf').read_text()
        for marker in ['private _terrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-100,0,100]',
                       'for "_along" from -80 to 220 step 20',
                       '((surfaceNormal _sample) select 2) < 0.55',
                       '_grade > 0.75',
                       '_relief >= 12',
                       'SUPPORT-terrain-scenario',
                       'call _terrainPosition',
                       '_wall setDir _terrainHeading']:
            self.assertIn(marker,qa)
        for local in ['[1600,1070,0]','[1600,1190,0]','[1450,1100,0]',
                      '[1500+_i*3,1050,0]','[1600,1290,0]','[1600,1120,0]']:
            self.assertIn('['+local+'] call _terrainPosition',qa)
        self.assertIn('No dry three-lane sector',qa)

    def test_assault_qa_requires_cover_element_to_consolidate_physically(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-physical-consolidation',qa)
        self.assertIn('(_members - _element) apply {[_x,getPosATL _x]}',qa)
        self.assertIn('_x distance2D _clearedObjective > 35',qa)
        self.assertIn('_x distance2D leader _group > 35',qa)
        self.assertIn('(_x select 0) distance2D (_x select 1) < 30',qa)

    def test_flank_consolidates_support_through_existing_movement_job(self):
        step=source('cortexFlankStep')
        self.assertIn('private _allUnits = +_units;',step)
        self.assertIn('private _fit = +_allUnits;',step)
        self.assertLess(step.index('private _allUnits = +_units;'),step.index('private _fit = +_allUnits;'))
        self.assertNotIn('private _fit = +_units;',step)
        self.assertIn('_points pushBack [_rally,"CONSOLIDATE"]',step)
        self.assertIn('_drill set ["units",_allUnits + _consolidationActors]',step)
        self.assertIn('_teams = [+_allUnits,+_consolidationActors]',step)
        self.assertIn('_drill set ["teamTurn",1]',step)
        self.assertIn('case "CONSOLIDATE": {',step)
        self.assertIn('_drill set ["finishFlank",true]',step)
        self.assertIn('else {+_centroid}',step)
        self.assertIn('getOrDefault ["consolidating",false]) exitWith {_result = "COMPLETE" call _end}',step)
        self.assertIn('getPos [12,_drill get "assaultDirection"]',step)

    def test_bound_progresses_on_physical_role_quorum_and_recovers_laggards(self):
        step=source('cortexFlankStep')
        self.assertIn('private _minimumArrivals = ((ceil (count _units * 0.6)) max 2) min count _units;',step)
        self.assertIn('private _boundAge = _now - (_drill get "boundStart");',step)
        self.assertIn('private _lateMoverProgressing = _lateMovers findIf',step)
        self.assertIn('_now - ((_progress select _progressIndex) select 3) <= 3',step)
        self.assertIn('_boundAge >= 6',step)
        self.assertIn('!_lateMoverProgressing || {_quorumUntil >= 0 && {serverTime >= _quorumUntil}}',step)
        self.assertIn('_quorumUntil=(serverTime+6) min (serverTime+((_moveDeadline-_now) max 0))',step)
        self.assertIn('_lateMoverProgressing} && {_quorumUntil == -1}',step)
        identity=step.split('if (_boundIdentity isNotEqualTo',1)[1].split('// Replacing casualties',1)[0]
        self.assertIn('_drill deleteAt "boundQuorumUntil"',identity)
        self.assertIn('"boundQuorumUntil"',source('cortexCheckpoint'))
        # A majority arriving late still grants six seconds, never beyond the
        # original hard expiry; a later observation retains the first expiry.
        for first,hard,expected in ((8,100,14),(30,100,36),(30,34,34)):
            expiry=min(first+6,hard)
            self.assertEqual(expiry,expected)
            self.assertLessEqual(expiry,hard)
            later=first+3
            self.assertEqual(expiry,expected)
            self.assertLess(later,expiry)

        self.assertIn('count _arrivedUnits >= _minimumArrivals',step)
        self.assertIn('private _stragglers = _units - _arrivedUnits;',step)
        self.assertIn('_recovery pushBack [_straggler,0,_now]',step)
        self.assertIn('Bound role complete',step)
        self.assertNotIn('setPos',step)
        self.assertIn('_drill set ["arrivedUnits",[]]',step)
        self.assertIn('if !(_unit in _previousArrivals) then {',step)

    def test_frontage_audit_measures_only_physical_halts_with_two_actor_tolerance(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        measurement=qa.split('// Recovery movement across the scene is not the halt',1)[1].split('if (diag_tickTime >= _nextLog)',1)[0]
        self.assertIn('if (_physicalArrival) then {',measurement)
        self.assertIn('private _minimumWidth = [2.25,3] select (count _moving > 2)',measurement)
        self.assertIn('_width >= _minimumWidth',measurement)

    def test_bound_recovery_preserves_combat_targeting(self):
        step=source('cortexFlankStep')
        recovery=step.split('// Recovery stays in this existing bounded group job',1)[1].split('private _recoverySnapshot',1)[0]
        self.assertIn('_actor doMove _rally',recovery)
        self.assertNotIn('_actor doTarget objNull',recovery)
        self.assertNotIn('_actor doWatch objNull',recovery)

    def test_late_combat_result_preserves_deadline_and_measures_consolidation(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-late-physical-consolidation',qa)
        self.assertIn('_ending = +_lateResult',qa)
        self.assertIn('["LATE: STILL RUNNING","LATE: ENDED"] select _lateEnded',qa)
        self.assertLess(qa.index('-observation-completed'),qa.index('_ending = +_lateResult'))

    def test_grenade_thrower_is_not_retasked_by_fire_or_antiarmour(self):
        for name in ['cortexFireControl','cortexAntiArmour']:
            code=source(name)
            self.assertIn('getOrDefault ["grenadeActionUntil",-1]',code)
            self.assertIn('pushBackUnique (_drill getOrDefault ["grenadeThrower",objNull])',code)

    def test_packaged_audit_skips_lobby_and_assigns_the_observer(self):
        description=(ROOT/'releaseVerificationAndDeployment/auditMission/description.ext').read_text(encoding='utf-8')
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        mission=(ROOT/'releaseVerificationAndDeployment/auditMission/mission.sqm').read_text(encoding='utf-8')
        serverAudit=(ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text(encoding='utf-8')
        self.assertIn('skipLobby=1;',description)
        self.assertIn('player="PLAYER COMMANDER"',mission)
        self.assertIn('addOns[]={"A3_Characters_F","A3_Characters_F_BLUFOR","A3_Map_VR"}',mission)
        self.assertIn('addOnsAuto[]={"A3_Characters_F","A3_Characters_F_BLUFOR","A3_Map_VR"}',mission)
        self.assertIn('_observer assignCurator _curator;',serverAudit)
        self.assertIn('CBE AUDIT OBSERVER ZEUS READY',serverAudit)
        self.assertIn('skips role selection and assigns the sole observer Zeus slot automatically',launcher)


    def test_combat_mode_fixture_waits_and_reports_expected_and_actual_modes(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-fixture-combat-mode',qa)
        self.assertLess(qa.index('private _modeReady'),qa.index('private _originalModes'))
        self.assertIn('_members findIf {unitCombatMode _x != _fixtureCombatMode}',qa)
        self.assertIn('_originalModes apply {[netId (_x select 0),_x select 1]}',qa)

    def test_consolidation_handover_requires_support_movement(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('FLANK-ZEUS-CONSOLIDATE',qa)
        self.assertIn('_interruptionActors = +(_live getOrDefault ["movers",[]])',qa)
        self.assertIn('_x in _interruptionActors && {_x distance2D (_origins select _forEachIndex) >= 8}',qa)
        self.assertIn('_stageReady && {_travel}',qa)

    def test_assault_approach_leaves_margin_for_frag_exclusion(self):
        step=source('cortexFlankStep')
        self.assertIn('_enemyPos getPos [20,_crossingDirection+180]',step)
        grenade=source('cortexThrowGrenade')
        self.assertIn('nearEntities ["CAManBase",_safetyRadius]',grenade)

    def test_assault_checks_carriers_across_both_arrived_elements(self):
        step=source('cortexFlankStep')
        assault=step.split('if (_arrivalAssault) then {',1)[1].split('    case "PAUSE": {',1)[0]
        self.assertIn('private _throwers = _fit select',assault)
        self.assertIn('call CBE_fnc_CortexThrowGrenade) exitWith',assault)
        self.assertNotIn('selectRandom',assault)

    def test_advance_grenade_case_requires_first_element_actual_throw(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('ADVANCE-GRENADE',qa)
        self.assertIn('_singleCarrier = (_teams select 0) select 0',qa)
        self.assertIn('_unit removeMagazine _x',qa)
        self.assertIn('-first-element-carrier-fired',qa)
        self.assertIn('count (_singleCarrier getVariable ["CBE_CortexQA_FragShots",[]]) > 0',qa)

    def test_event_jobs_adopt_before_reserving_and_queuing(self):
        for name, reservation in [
            ('cortexRegroupOnKill', '_group setVariable ["CBE_AIPass_RegroupQueued", true]'),
            ('cortexAirborneCheck', '_aircraft setVariable ["CBE_AIPass_DropUntil", time + 30')]:
            text = source(name)
            adoption = text.index('[_group,true] call CBE_fnc_CortexLocality')
            self.assertLess(adoption, text.index(reservation))
            self.assertLess(adoption, text.index('] call CBE_fnc_CortexQueueJob'))

    def test_airborne_drop_yields_before_each_jump_and_before_post_landing_orders(self):
        step=source('cortexAirborneDropStep')
        self.assertGreaterEqual(step.count('CBE_fnc_CortexExternalTakeover'),2)
        drop=step.split('if ((_job get "phase") == "DROP") exitWith {',1)[1].split('// LAND',1)[0]
        landing=step.split('// LAND',1)[1]
        self.assertLess(drop.index('CBE_fnc_CortexExternalTakeover'),drop.index('CBE_fnc_CortexParachuteJump'))
        self.assertLess(landing.index('CBE_fnc_CortexExternalTakeover'),landing.index('_group addWaypoint'))

    def test_infantry_illumination_uses_finite_native_inventory_and_release_evidence(self):
        text=source('cortexIlluminationStep')
        for proof in ('serverTime+25','serverTime+60','select [0,16]','count _muzzles > 8',
                      'count _inventory > 128','compatibleMagazines [_weapon,_muzzle]',
                      '"shotilluminating"','_actor reload [_muzzle,_magazine]',
                      'param [6,1]) != 0','_direction select 2','vectorDotProduct',
                      'addEventHandler ["FiredMan"','removeEventHandler ["FiredMan"',
                      '_thisEventHandler','"AWAIT_RELEASE"','!isNull _projectile',
                      'CBE_AIPass_Epoch','CBE_OperationGeneration','NativeOrderReceipt',
                      'ace_medical_ai_healQueue','_actor selectWeapon (_work get "before")'):
            self.assertIn(proof,text)
        for forbidden in ('addMagazine','removeMagazine','addWeaponItem','createVehicle','reveal ',
                          'setVelocity','setPos','spawn','sleep','execFSM','setUnitPos'):
            self.assertNotIn(forbidden,text)
        self.assertIn('!fleeing _actor',text)
        finish=text.split('private _finish={',1)[1].split('if (_release) exitWith',1)[0]
        self.assertIn('if (local _actor)',finish)
        self.assertLess(finish.index('_actor selectWeapon (_work get "before")'),finish.index('_weaponHandback="RESTORED"'))
        self.assertIn('weaponState _actor select [0,3]',finish)
        self.assertIn('CBE_Illumination_WeaponUnresolved',finish)
        self.assertIn('_weaponHandback]',finish)
        unresolved=text.split('private _unresolved=',1)[1].split('private _weapon=primaryWeapon',1)[0]
        self.assertIn('count _unresolved == 3',unresolved)
        self.assertIn('then {continue}',unresolved)
        self.assertNotIn('selectWeapon',unresolved)
        self.assertNotIn('serverTime+',unresolved)
        self.assertEqual(text.count('forceWeaponFire'),1)
        self.assertLess(text.index('if (count _work == 0 &&'),text.index('call CBE_fnc_NativeOrderReceipt'))
        start=source('operationStart')
        self.assertLess(start.index('call CBE_fnc_CortexIlluminationStep'),start.index('private _generation='))

        self.assertIn('if (_migration) exitWith {["OWNER_CHANGED"] call _finish}',text)
        self.assertIn('(_work getOrDefault ["ownerId",-1]) == clientOwner',text)
        self.assertIn('_migration && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []}',text)
        self.assertIn('CBE_Illumination_Work",_work,true]',text)

        self.assertLess(text.index('_work set ["phase","AWAIT_RELEASE"]'),text.index('forceWeaponFire'))
        self.assertNotIn('released",true',text.split('if (_phase == "AIM")',1)[1])
        for name in ('operationStart','cortexReleaseGroup','cortexLocality'):
            self.assertIn('[_group,true] call CBE_fnc_CortexIlluminationStep',source(name))
        brain=source('groupBrainStep')
        self.assertIn('if ([_group] call CBE_fnc_CortexIlluminationStep) then {_delay=_delay min 1}',brain)
        self.assertIn('["CBE_AIPass_Illumination_Enable", false]',source('aiConfig'))
        fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIllumination.sqf').read_text()
        for proof in ('_leader knowsAbout _enemy >= 1','addEventHandler ["FiredMan"',
                      'velocity _projectile','_start+3','_beforeRounds-1','_beforeWeapon',
                      '"DISABLED","RELEASE","INTERRUPT"','normal-batch-required'):
            self.assertIn(proof,fixture)
        for forbidden in ('reveal ','setVariable ["phase","CONTACT"]',
                          'set ["released",true]','["LOAD"','["AIM"','forceWeaponFire'):
            self.assertNotIn(forbidden,fixture.split('params [',1)[1])
        self.assertIn('if (_focus == "illumination") exitWith',(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text())


    def test_attack_run_flares_are_separate_gated_owner_job(self):
        text=source('cortexAttackRunFlares')
        for requirement in ['local _aircraft','CortexIsEligible','CortexAircraftEligible','CBE_Cortex_AttackRunFlares_Enable','isTouchingGround','vectorDotProduct','closest','APPROACH','DEPARTURE','serverTime+30','CortexFireCountermeasure','effectiveCommander _aircraft','gunner _aircraft','commander _aircraft','crew _aircraft','assignedTarget _x']:
            self.assertIn(requirement,text)
        self.assertNotIn('reveal ',text)
        self.assertNotIn('setVelocity',text)
        self.assertNotIn('addWaypoint',text)
        self.assertIn('burstExpires',text)
        self.assertIn('burstNext',text)
        self.assertIn('if ([_aircraft] call CBE_fnc_CortexFireCountermeasure)',text)
        for proof in ('_x knowsAbout _candidate >= 1','_x getHideFrom _candidate',
                      '_targetOwners select [0,16]','(crew _aircraft) select [0,12]',
                      '["targetPoint",+_point]','_point vectorDiff (getPosASL _aircraft)',
                      'captive _candidate','ace_captives_isSurrendering','ace_captives_isHandcuffed'):
            self.assertIn(proof,text)
        self.assertNotIn('getPosASL _target',text)
        self.assertNotIn('distance _target',text)
        self.assertIn('if ("target" in _job && {!([_target] call _targetValid)',text)
        self.assertIn('if (_belief call _vectorValid && {_belief isNotEqualTo [0,0,0]}) exitWith',text)

        takeover=text.split('if !((_aircraft getVariable',1)[1].split('if (isTouchingGround',1)[0]
        self.assertIn('_job deleteAt "burst"',takeover)

        spec=source('cortexTuningSpec')
        settings=source('aiConfig')
        discover=source('cortexDiscover')
        controller=source('cortexAirAttack')
        self.assertIn('CBE_Cortex_AttackRunFlares_Enable',spec)
        self.assertIn('CBE_Cortex_AttackRunFlares_Enable',settings)
        self.assertIn('CBE_Cortex_AttackRunFlares_Enable',discover)
        self.assertIn('CBE_Cortex_AttackRunFlares_Enable',controller)
        self.assertIn('CortexFeatureEnabled',discover)
        self.assertIn('CortexFireCountermeasure',controller)

    def test_standoff_release_remains_on_the_inbound_side_of_the_target(self):
        planner=source('cortexAirAttackPlan')
        standoff=planner.split('case "STANDOFF": {',1)[1].split('case "STRAFE": {',1)[0]
        self.assertIn('_attack=[-1800,0] call _point;',standoff)
        self.assertIn('_attack=[-650,0] call _point;',standoff)
        self.assertNotIn('_attack=[1800,0] call _point;',standoff)
        self.assertNotIn('_attack=[650,0] call _point;',standoff)

    def test_fixed_wing_standoff_preserves_its_inbound_release_leg(self):
        controller=source('cortexAirAttack')
        self.assertIn('(_job getOrDefault ["pattern",""]) != "STANDOFF"',controller)
        self.assertIn('Guided stand-off weapons instead retain their',controller)

    def test_standoff_uses_one_guided_release_then_closes_before_overflight(self):
        controller=source('cortexAirAttack')
        self.assertIn('private _standoffPass=(_job getOrDefault ["pattern",""]) == "STANDOFF"',controller)
        self.assertIn('private _desiredShots=if (_standoffPass) then {1}',controller)
        self.assertIn('private _standoffWindowClosed=_standoffPass',controller)
        self.assertIn('private _standoffRange=_aircraft distance _target',controller)
        self.assertIn('_standoffRange <= _standoffMinimumRange+150',controller)
        self.assertIn('_standoffForwardAlignment > 0.75',controller)

    def test_air_attack_counts_only_the_planned_weapon_and_magazine(self):
        controller=source('cortexAirAttack')
        self.assertIn('CBE_Cortex_AirAttackSelectedWeapon',controller)
        self.assertIn('CBE_Cortex_AirAttackSelectedMagazine',controller)
        self.assertIn('private _selectedRelease=_weapon == _selectedWeapon',controller)
        self.assertIn('&& {_selectedMagazine != ""} && {_magazine == _selectedMagazine};',controller)
        self.assertIn('if (_selectedRelease && {_ownsRelease}) then {',controller)
        self.assertIn('== _thisEventHandler',controller)
        self.assertIn('call CBE_fnc_FlightLeaseValid',controller)
        self.assertIn('&& {(_stationState select 3) == _selectedMagazine}',controller)
        self.assertNotIn('(_x select 0) == _selectedMagazine || {(_x select 0) in compatibleMagazines _weapon}',controller)

    def test_adaptive_air_attack_is_bounded_physical_and_zeus_safe(self):
        planner=source('cortexAirAttackPlan')
        for requirement in ['nearTargets ([8000,5000]','select [0,16]','CBE_Cortex_AirAmmoFacts',
                            '_vehicleAAFacts','CBE_Cortex_AirVehicleAAFacts','airLock','aiAmmoUsageFlags','STANDOFF','OFFSET','HOOK','STRAFE','BOMB','LATERAL',
                            'INTERCEPT','_airToAir','airWeapon','airWeaponTurret','pylonWeapon','hardpoints','indirectHit']:
            self.assertIn(requirement,planner)
        for requirement in ['groundWeapon','groundTurret','_groundCandidates','_hasGun=_groundCandidates findIf {(_x select 4) == "GUN"}','shotbullet','shotshell',
                            'shotrocket','shotmissile','shotbomb','_rocketHint','selectedWeapon','selectedSimulation','selectedWeaponClass',
                            '_simulation in ["shotbullet","shotshell"]',
                            '_simulation in ["shotbullet","shotshell","shotrocket","shotbomb"]']:
            self.assertIn(requirement,planner)
        self.assertIn('private _standoff=_simulation == "shotmissile"',planner)
        self.assertIn('&& {_guidedGround} && {!_antiAir} && {!_bombHint}',planner)
        self.assertIn('_bombHint || {_rocketHint || {_simulation in ["shotbullet","shotshell","shotrocket","shotbomb"]',planner)
        self.assertIn('private _armouredTarget=_targetArmour >= 180',planner)
        self.assertIn('if (_standoffAvailable) then {"STANDOFF"} else {if (_hasRocket) then {"OFFSET"} else {""}}',planner)
        self.assertIn('if (_hasRocket) then {_choices append ["OFFSET",0.18,"HOOK",0.22]}',planner)
        self.assertNotIn('private _hasRunWeapon=_hasGun || {_hasRocket}',planner)
        self.assertNotIn('allUnits',planner)

        self.assertNotIn('nearEntities',planner)
        for requirement in ['fullCrew _aircraft','_aircraft weaponsTurret _turret','_personTurret',
                            'CBE_Cortex_AirAttackPattern','_lateralTurret','_lateralTurretPath',
                            'toLowerANSI _role in ["gunner","commander","turret"]',
                            'standoffWeapon','CBE_Cortex_AirStandoffBlockedUntil',
                            '[-1200,750]','[900,750]','[2200,1100]','[-8500,-4500]',
                            '["BOMB",[0.08,0.22] select _armouredTarget]',
                            'private _forwardIngress=(_toIngress vectorDotProduct _deliveryAxis) >= 100',
                            'private _bearingAngle=[22,38] select (_pattern == "HOOK")',
                            'vectorNormalized _toAttack']:
            self.assertIn(requirement,planner)
        self.assertNotIn('private _choices=["STRAFE",0.3,"LATERAL"',planner)
        controller=source('cortexAirAttack')
        for requirement in ['local _aircraft','CBE_Cortex_AirAttack_Enable','CortexExternalTakeover','CortexZeusHeld',
                            'addEventHandler ["Fired"','ownedWaypointName','setWaypointPosition',
                            'forceSpeed','INGRESS','ATTACK','EGRESS','GROUND_CLEARANCE','EGRESS_NONPROGRESS',
                            'routeSignature','AUTHORED_ROUTE_CHANGED','CortexFireCountermeasure','CBE_Cortex_AirAttackOutcome',
                            'aimedAtTarget','fireAtTarget','NO_FIRE_SOLUTION','attackStartedAt',
                            'stageBestDistance','stageProgressAt','INGRESS_NONPROGRESS','ATTACK_NONPROGRESS',
                            'weaponDirection _weapon','CBE_Cortex_AirFireSolution','private _validSolution=',
                            '_range >= _minimumRange','private _nativeFixedBasket=']:
            self.assertIn(requirement,controller)
        self.assertNotIn('_pilot doMove _destination',controller)
        self.assertNotIn('_pilot commandMove _destination',controller)
        self.assertNotIn('_pilot setDestination [_destination',controller)
        self.assertIn('private _routeSignature=[_group] call CBE_fnc_AuthoredRouteReceipt;',controller)
        self.assertNotIn('[count waypoints _group,_waypointIndex,_resumePosition',controller)
        self.assertIn('private _target=_job getOrDefault ["target",objNull]',controller)
        self.assertIn('private _leadSeconds=[16,5] select (_stage == "ATTACK")',controller)
        self.assertIn('private _nativeAttackWaypoint=_isPlane && {_stage == "ATTACK"}',controller)
        self.assertIn('_job getOrDefault ["selectedWeapon",""]',controller)
        self.assertIn('format ["CBE_AIR_%1",_plan get "token"]',controller)
        self.assertNotIn('CBE_CORTEX_AIR_',controller)
        self.assertIn('_job set ["groundWeapon",_plan getOrDefault ["groundWeapon",""]]',controller)
        self.assertIn('_job set ["groundTurret",_plan getOrDefault ["groundTurret",[]]]',controller)
        self.assertIn('_isPlane && {speed _aircraft < 40}',controller)
        self.assertIn('serverTime+0.8+random 0.8',controller)
        self.assertIn('flareINGRESS',controller)
        self.assertIn('flareEGRESS',controller)
        self.assertIn('private _captureRadii=_job getOrDefault',controller)
        self.assertIn('private _captureRadius=_captureRadii select _stageIndex',controller)
        for profile in ['stageAltitudes','stageSpeeds','captureRadii','attackMinimum']:
            self.assertIn(profile,planner)
            self.assertIn(profile,controller)
        self.assertIn('private _deliveryAltitude=600+random 100',planner)
        self.assertIn('private _deliveryAltitude=620+random 80',planner)
        self.assertIn('private _deliveryAltitude=650+random 90',planner)
        self.assertIn('private _approachAltitude=_deliveryAltitude+550',planner)
        self.assertIn('vectorAdd (velocity _aircraft)',controller)
        self.assertIn('private _launchAlignment=',controller)
        self.assertIn('private _bombImpactError=',controller)
        self.assertIn('_bombImpactError <= 55',controller)
        self.assertIn('private _deliveryTerrainClear=_job getOrDefault ["terrainViable",true]',controller)
        self.assertNotIn('private _terminalAssist=',controller)
        self.assertNotIn('_aircraft setVectorDirAndUp',controller)
        self.assertIn('configFile >> "CfgAmmo" >> _ammoClass >> "airFriction"',controller)
        self.assertIn('for "_integrationIndex" from 0 to 119',controller)
        self.assertIn('private _integrationPosition=getPosASL _aircraft',controller)
        self.assertIn('private _targetAltitude=aimPos _target select 2',controller)
        self.assertNotIn('private _integrationPosition=getPosATL _aircraft',controller)
        self.assertIn('_job getOrDefault ["deliveryAssistSamples",[]]',controller)
        self.assertIn('_job getOrDefault ["deliveryAssistActive",false],_deliveryTerrainClear',controller)
        self.assertNotIn('_aircraft setVelocity ',controller)
        self.assertNotIn('_aircraft setPos',controller)
        self.assertIn('private _minimumTerrainClearance=[45,300] select _isPlane',planner)
        self.assertIn('for "_legIndex" from 0 to 2',planner)
        self.assertIn('private _sampleSteps=((ceil (_legLength/300)) max 6) min 36',planner)
        self.assertIn('for "_sampleIndex" from ([1,0] select !_joinLeg) to _sampleSteps',planner)
        self.assertIn('forEach [-_terrainCorridor,0,_terrainCorridor]',planner)
        self.assertIn('private _terrainASL=getTerrainHeightASL _samplePoint',planner)
        self.assertIn('private _terrainRequiredLift=0;',planner)
        self.assertIn('_terrainViable=_terrainViable && {_terrainRequiredLift <= _terrainLiftLimit}',planner)
        self.assertIn('if (!_terrainViable) exitWith {createHashMap}',planner)
        self.assertIn('private _routePoints=[_airPos,_ingress,_attack,_egress]',planner)
        self.assertIn('private _joinLeg=_legIndex == 0',planner)
        self.assertIn('_joinLeg && {_fraction <= 0.2}',planner)
        self.assertIn('_clearanceDeficit/_fraction',planner)
        self.assertIn('_terrainClearanceSamples pushBack',planner)
        self.assertIn('_terrainLift*(_x select 1)',planner)
        self.assertIn('_stageAltitudes=_stageAltitudes apply {_x+_terrainLift}',planner)
        self.assertIn('["terrainLift",_terrainLift]',planner)
        self.assertIn('["terrainClearanceMinimum",_terrainClearanceMinimum]',planner)
        self.assertIn('["terrainSampleCount",_terrainSampleCount]',planner)
        self.assertIn('["terrainCorridor",_terrainCorridor]',planner)
        self.assertIn('["terrainRequiredLift",_terrainRequiredLift]',planner)
        self.assertIn('["terrainViable",_terrainViable]',planner)
        self.assertIn('_job set ["terrainRequiredLift",_plan getOrDefault',controller)
        self.assertIn('_job getOrDefault ["terrainRequiredLift",0]',controller)
        self.assertIn('["targetPosition",+_targetPos]',planner)
        self.assertIn('private _stagePassed=',controller)
        self.assertIn('private _ingressBehind=',controller)
        self.assertIn('vectorDotProduct ((ATLToASL _destination) vectorDiff getPosASL _aircraft)',controller)
        self.assertIn('vectorDotProduct ((getPosASL _target) vectorDiff getPosASL _aircraft)',controller)
        self.assertNotIn('vectorDotProduct (_destination vectorDiff getPosATL _aircraft)',controller)
        self.assertIn('_aircraft distance2D _target <= 9500',controller)
        self.assertIn('_ownedWaypoint setWaypointPosition [getPosATL _target,0]',controller)
        self.assertIn('private _nativeAttackWaypoint=_isPlane && {_stage == "ATTACK"}',controller)
        self.assertIn('setWaypointType "DESTROY"',controller)
        self.assertIn('setWaypointCombatMode "RED"',controller)
        self.assertIn('_ownedWaypoint waypointAttachVehicle _target',controller)
        self.assertIn('_ownedWaypoint waypointAttachVehicle objNull',controller)
        self.assertIn('_job getOrDefault ["airToAir",false]',controller)
        self.assertIn('native attached DESTROY order',controller)
        self.assertNotIn('deliveryCommitted',controller)
        self.assertIn('attackShotBaseline',controller)
        self.assertIn('if (_turret isEqualTo [-1]) then {_pilot}',controller)
        self.assertIn('assignedTarget _x isEqualTo _ownedTarget',controller)
        self.assertIn('_x doTarget objNull',controller)
        self.assertIn('_x doWatch objNull',controller)
        self.assertNotIn('_group reveal [_fireTarget,4]',controller)
        handover_cleanup=controller.split('if (_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"]) then {',1)[1].split('if (!_preserveEditedLeg && {!(_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED","OWNED_ROUTE_CHANGED"])}) then {',1)[0]
        self.assertNotIn('doTarget objNull',handover_cleanup)
        self.assertNotIn('doWatch objNull',handover_cleanup)
        self.assertIn('_operator doFire _fireTarget',controller)
        self.assertNotIn('_operator doFire _target',controller)
        self.assertNotIn('_operator commandTarget _target',controller)
        self.assertLess(
            controller.index('_operator doTarget _fireTarget'),
            controller.index('private _fixedUnguided=_turret isEqualTo [-1]'),
        )
        self.assertIn('_job getOrDefault ["releaseDetail",[]]',controller)
        self.assertIn('getPosATL _aircraft,velocity _aircraft',controller)
        self.assertIn('"vehicleOwner",owner _aircraft,"groupOwner",groupOwner _group',controller)
        self.assertIn('private _effectiveCapture=_captureRadius+([0,150] select !_isPlane)',controller)
        self.assertIn('private _lateralWeaponEntry=!_isPlane',controller)
        self.assertIn('_pattern == "LATERAL" || {_forwardAlignment > 0.35}',controller)
        self.assertIn('_stage != "" || {[_group] call CBE_fnc_CortexIsEligible}',controller)
        self.assertIn('_aircraft selectWeaponTurret [_weapon,_turret]',controller)
        self.assertIn('!(_job getOrDefault ["weaponSelected",false])',controller)
        self.assertIn('_job set ["weaponSelected",true]',controller)
        self.assertIn('_operator doWatch _fireTarget',controller)
        self.assertIn('private _pilotSurfaceStation=_isPlane && {!_airContact} && {_turret isEqualTo [-1]}',controller)
        target_block=controller.split('if ([_aircraft,_group,_operator] call CBE_fnc_CortexAirWeaponOperatorAvailable\n        && {!(_job getOrDefault ["targetCommanded",false])}) then {',1)[1].split('private _range=',1)[0]
        self.assertIn('if (!_pilotSurfaceStation) then {',target_block)
        self.assertNotIn('_aircraft doTarget',target_block)
        self.assertNotIn('_aircraft doWatch',target_block)
        self.assertIn('private _nativeFixedBasket=',controller)
        self.assertIn('private _minimumAim=0;',controller)
        self.assertNotIn('&& {_aimed >= _minimumAim}',controller)
        self.assertIn('_fired=_aircraft fireAtTarget [_fireTarget,_weapon]',controller)
        self.assertIn('private _pilotSurfaceRelease=_pilotSurfaceStation',controller)
        self.assertIn('"NATIVE_PILOT_REQUEST"',controller)
        self.assertNotIn('_operator forceWeaponFire [_weapon,_mode]',controller)
        self.assertIn('private _deliveryPassed=false;',controller)
        self.assertIn('_deliveryAlong >= 350',controller)
        self.assertIn('[_group,_job,"EGRESS","DELIVERY_WINDOW_PASSED"]',controller)
        self.assertIn('_reason="DELIVERY_MISSED"',controller)
        self.assertNotIn('private _nativePlaneDelivery=',controller)
        self.assertIn('if (_validSolution && {!_pilotSurfaceRelease} && {_requestAvailable}',controller)
        self.assertIn('serverTime < _requestAt+3',controller)
        self.assertIn('_requestAttempts < 2',controller)
        self.assertIn('_job set ["fireRequestAttempts",0]',controller)
        self.assertIn('_projectile setMissileTarget _guidedTarget',controller)
        self.assertNotIn('setMissileTarget [_guidedTarget,true]',controller)
        self.assertIn('_projectile setMissileTargetPos (ASLToATL (aimPos _guidedTarget))',controller)
        self.assertIn('[1100,9000,0.97]',controller)
        self.assertIn('selectedWeaponClass",""]) == "GUIDED"',controller)
        self.assertNotIn('selectedSimulation",""]) == "shotmissile"',controller)
        self.assertIn('case "GUN": {0.15+random 0.25}',controller)
        self.assertIn('case "ROCKET": {0.45+random 0.55}',controller)
        self.assertIn('(_stationState select 3) == _selectedMagazine',controller)
        self.assertIn('_job set ["lateralPilotFeatures",_lateralPilotFeatures]',controller)
        self.assertNotIn('_group enableAttack false',controller)
        self.assertNotIn('_finishGroup enableAttack (_job getOrDefault ["previousAttackEnabled",true])',controller)
        self.assertIn('case "BOMB"',controller)
        self.assertIn('case "GUN": {120}',controller)
        self.assertIn('case "BOMB": {2}',controller)
        self.assertIn('private _deliveryWindow=switch _weaponClass do',controller)
        self.assertIn('_reason == "DELIVERY_SAFETY_FLOOR") then {120}',controller)
        self.assertIn('private _currentAGL=(getPosATL _aircraft) select 2;',controller)
        self.assertIn('private _verticalSpeed=(velocity _aircraft) select 2;',controller)
        self.assertIn('_lookaheadClearances=[1.5,3] apply',controller)
        self.assertIn('getTerrainHeightASL _futurePosition',controller)
        self.assertIn('selectMin _lookaheadClearances < 120',controller)
        self.assertIn('_aircraft flyInHeight _safeRecoveryHeight',controller)
        self.assertIn('"agl",_currentAGL,"verticalSpeed",_verticalSpeed',controller)
        self.assertIn('"lookaheadClearances",_lookaheadClearances',controller)
        self.assertIn('_job set ["terrainLift",_plan getOrDefault ["terrainLift",0]]',controller)
        self.assertIn('"TARGET_DESTROYED"',controller)
        self.assertIn('_job set ["targetDestroyed",true]',controller)
        self.assertIn('private _liveShots=_aircraft getVariable ["CBE_Cortex_AirAttackShots",0]',controller)
        self.assertIn('(!isNull _target && {!alive _target}) || {_liveShots > 0}',controller)
        self.assertIn('[_group,_job,"EGRESS","TARGET_DESTROYED"]',controller)
        self.assertIn('if (_reason == "COMPLETE") then {',controller)
        self.assertIn('if (_job getOrDefault ["targetDestroyed",false]) then {',controller)
        discovery=source('cortexDiscover')
        self.assertIn('_pilot nearTargets ([8000,5000] select !(_vehicle isKindOf "Plane"))',discovery)
        self.assertIn('_knownTargets select _knownIndex) param [4,objNull]',discovery)
        self.assertNotIn('_pilot targets [true,[8000,5000]',discovery)
        self.assertNotIn('ACTUAL_FIRE_NONPROGRESS',controller)
        aircraft_qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        self.assertIn('private _fixtureStationWeapons={',aircraft_qa)
        self.assertIn('(weapons _aircraft)+(_aircraft weaponsTurret [-1])',aircraft_qa)
        self.assertIn('_pylonWeapon in _stationWeapons',aircraft_qa)
        self.assertIn('"DELIVERY_MISSED"',aircraft_qa)
        self.assertIn('-missed-pass-egresses-without-circle',aircraft_qa)
        self.assertIn('_postPassNet/_postPassTravel >= 0.5',aircraft_qa)
        self.assertIn('private _physicalTransitions=',aircraft_qa)
        self.assertIn('count (_physicalTransitions arrayIntersect _physicalTransitions) >= 2',aircraft_qa)
        self.assertIn('private _releaseWait=[4,20] select',aircraft_qa)
        self.assertIn('_selectedWeaponClass in ["ROCKET","BOMB","GUIDED"]',aircraft_qa)
        self.assertIn('private _selectedMagazine=_initialPlan param [26,""];',aircraft_qa)
        self.assertIn('_id+"-selected-station-loaded"',aircraft_qa)
        self.assertIn('(_x select 0) == _selectedMagazine',aircraft_qa)
        self.assertIn('private _physicalImpact=damage _plannedTargetObject > 0',aircraft_qa)
        self.assertIn('private _plannedTargetObject=_initialPlan param [3,_target]',aircraft_qa)
        self.assertIn('private _terrainLift=_initialPlan param [27,0]',aircraft_qa)
        self.assertIn('private _terrainClearanceMinimum=_initialPlan param [28,0]',aircraft_qa)
        self.assertIn('private _terrainSampleCount=_initialPlan param [29,0]',aircraft_qa)
        self.assertIn('private _terrainCorridor=_initialPlan param [30,0]',aircraft_qa)
        self.assertIn('private _plannedTargetPosition=_initialPlan param [31,getPosATL _target]',aircraft_qa)
        self.assertIn('private _terrainRequiredLift=_initialPlan param [32,0]',aircraft_qa)
        self.assertIn('private _terrainViable=_initialPlan param [33,false]',aircraft_qa)
        self.assertIn('_id+"-ground-target-stationary"',aircraft_qa)
        self.assertIn('_target setPosATL _targetPosition',aircraft_qa)
        self.assertIn('_id+"-terrain-envelope"',aircraft_qa)
        self.assertIn('_id+"-terrain-scenario-relief"',aircraft_qa)
        self.assertIn('worldName == "VR" || {_terrainRelief >= 30}',aircraft_qa)
        self.assertIn('_id+"-terrain-aware-terminal-delivery"',aircraft_qa)
        self.assertIn('_sampleAircraft getVariable ["CBE_Cortex_AirFireSolution",[]]',aircraft_qa)
        self.assertIn('count _x >= 23 && {_x param [21,false]}',aircraft_qa)
        self.assertNotIn('_solution >= 0.35',controller)
        self.assertIn('CBE_Cortex_ZeusOrderSnapshot',controller)
        self.assertIn('private _snapshot=',controller)
        self.assertIn('private _handoverWaypoints=waypoints _handoverGroup',controller)
        self.assertIn('{local _finishGroup} && {_ownedWaypointName != ""}',controller)
        self.assertIn('if (_replayZeus) then {',controller)
        self.assertIn('(_snapshot select 0) isEqualTo (_handoverHold select 0)',controller)
        self.assertIn('{local _handoverGroup}',controller)
        self.assertNotIn('[_handoverGroup,_snapshot param [5,currentWaypoint _handoverGroup]]',controller)
        self.assertIn('_handoverGroup setCurrentWaypoint _authoredWaypoint',controller)
        self.assertNotIn('_handoverGroup setCurrentWaypoint [_handoverGroup,_authoredWaypointOffset]',controller)
        self.assertNotIn('(crew _aircraft) doFollow leader _handoverGroup',controller)
        self.assertNotIn('_handoverPilot commandMove _handoverPosition',controller)
        self.assertNotIn('_handoverPilot setDestination [_handoverPosition',controller)
        self.assertIn('assignedTarget _x isEqualTo _ownedTarget',controller)
        self.assertNotIn('_x commandTarget objNull',controller)
        self.assertNotIn('_handoverPilot doFollow leader _handoverGroup',controller)
        self.assertNotIn('(driver _aircraft) doMove _handoverPosition',controller)
        self.assertNotIn('(crew _aircraft) doFollow leader _group',controller)
        self.assertIn('CBE_Cortex_AirHandoverLease',controller)
        self.assertIn('private _resumeExternal',controller)
        self.assertIn('[group _x] call CBE_fnc_CortexExternalTakeover',controller)
        self.assertIn('{!_resumeExternal}',controller)
        self.assertNotIn('private _deadline=serverTime+90',controller)
        self.assertNotIn('_handoverPilot setUnitCombatMode "BLUE"',controller)
        self.assertNotIn('_handoverGroup setBehaviourStrong "CARELESS"',controller)
        self.assertNotIn('_handoverPilot setCombatBehaviour "CARELESS"',controller)
        self.assertIn('_handoverGroup setBehaviourStrong _authoredBehaviour',controller)
        self.assertIn('_handoverGroup setSpeedMode _authoredSpeed',controller)
        self.assertIn('_handoverGroup setCombatMode _authoredCombatMode',controller)
        self.assertIn('(_snapshot param [4,waypointType _authoredWaypoint]) == "MOVE"',controller)
        self.assertIn('_handoverGroup move _handoverPosition',controller)
        self.assertNotIn('_handoverGroup setCombatMode "BLUE"',controller)
        # One native height hint at a real stage transition is permitted because Arma does not use
        # MOVE point Z as a dependable flight profile. Direct handover may clear that persistent
        # hint once from Zeus' selected destination, but must never become a polling controller.
        self.assertEqual(controller.count('_aircraft flyInHeight (_stageAltitudes select _stageIndex)'),1)
        handover=controller.split('if (_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"]) then {',1)[1].split('// On an ordinary finite end',1)[0]
        self.assertEqual(handover.count('_aircraft flyInHeight'),1)
        self.assertIn('private _handoverHeight=if (count _handoverPosition >= 3',handover)
        self.assertIn('_aircraft flyInHeight [_handoverHeight,false]',handover)
        self.assertNotIn('_aircraft flyInHeight [_handoverHeight,true]',handover)
        self.assertIn('"ZEUS_IMMEDIATE_HANDOVER"',controller)
        self.assertNotIn('_handoverPilot doMove _handoverPosition',controller)
        self.assertNotIn('"FORCE_REPLAN"',controller)
        self.assertNotIn('"FORWARD_IMPULSE"',controller)
        self.assertNotIn('_handoverAircraft setVelocity [',controller)
        self.assertIn('CBE_Cortex_AirHandoverRecovery',controller)
        self.assertIn('CBE_Cortex_AirHandoverResult',controller)
        self.assertIn('expectedDestination _handoverPilot',controller)
        self.assertNotIn('"ZEUS_TRANSIT_GUARD"',controller)
        self.assertIn('egressStartPosition',controller)
        self.assertIn('private _egressTravel=',controller)
        self.assertIn('private _awayFromTarget=',controller)
        self.assertIn('CBE_Cortex_AirAttackBlockedUntil',controller)
        self.assertNotIn('createVehicle [_laserClass,getPosATL _target,[],0,"CAN_COLLIDE"]',controller)
        self.assertNotIn('_guidanceTarget attachTo [_target,[0,0,0]]',controller)
        self.assertIn('_job set ["fireTarget",_target]',controller)
        self.assertIn('CBE_Cortex_AirAttackGuidanceTarget',controller)
        self.assertIn('private _requestPending=',controller)
        self.assertEqual(controller.count('fireAtTarget [_fireTarget,_weapon]'),1)
        self.assertEqual(controller.count('forceWeaponFire [_weapon,_mode]'),0)
        discover=source('cortexDiscover')
        self.assertIn('!(_vehicle isKindOf "Plane") || {speed _vehicle >= 40}',discover)
        self.assertEqual(controller.count('addWaypoint [_destination,0]'),1)
        self.assertEqual(controller.count('deleteWaypoint'),1)
        self.assertIn('setWaypointName _ownedWaypointName',controller)
        self.assertIn('private _currentRoute=[_group,_ownedWaypointName] call CBE_fnc_AuthoredRouteReceipt;',controller)
        self.assertIn('format ["AIR_%1",_plan get "pattern"]',controller)
        self.assertIn('call CBE_fnc_OperationStart',controller)
        self.assertIn('operationGeneration',controller)
        self.assertIn('["ATTACK"] call _setOperationPhase',controller)
        self.assertIn('["EGRESS"] call _setOperationPhase',controller)
        self.assertIn('call CBE_fnc_OperationRelease',controller)
        self.assertIn('call CBE_fnc_OperationCancel',controller)
        self.assertNotIn('call CBE_fnc_OperationStep',controller)
        self.assertIn('CBE_Cortex_AirAttackJob',discover)
        self.assertIn('CBE_fnc_AirAttackOperationStart',discover)
        self.assertIn('_pilot nearTargets ([8000,5000] select !(_vehicle isKindOf "Plane"))',discover)
        self.assertIn('["target",_airAttackTarget]',discover)
        self.assertIn('serverTime >= (_vehicle getVariable ["CBE_Cortex_AirAttackBlockedUntil",0])',discover)
        stop=source('cortexStop')
        for requirement in ['CBE_Cortex_AirAttackPlan','CBE_Cortex_AirAttackJob','CBE_Cortex_AirFireSolution',
                            'CBE_Cortex_AirAttackTarget','CBE_Cortex_AirAttackGuidedWeapon',
                            'removeEventHandler ["Fired"','limitSpeed (2 * getNumber (configOf _flareAircraft >> "maxSpeed"))','previousAttackEnabled']:
            self.assertIn(requirement,stop)
        spec=source('cortexTuningSpec')
        settings=source('aiConfig')
        self.assertIn('CBE_Cortex_AirAttack_Enable',spec)
        self.assertIn('CBE_Cortex_AirAttack_Enable',settings)
        self.assertIn('CBE_Cortex_AirAttack_Enable',discover)
        self.assertIn('CBE_Cortex_AirAttack_Enable',controller)
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        for requirement in ['adaptiveAirAttacks','activeAirAttacks','cortex-air-attack-',
                            'lastCountermeasureRequest','actualShots','observedAA']:
            self.assertIn(requirement,diagnostics)

        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        for requirement in ['AIR-HANDOVER-NATIVE-CONTROL-started',
                            'AIR-HANDOVER-NATIVE-CONTROL-replacement-travel',
                            'AIR-HANDOVER-NATIVE-CONTROL-no-cortex-owner',
                            '-immediate-zeus-handover',
                            '-dedicated-aircraft-owner','CBE_AIPass_Managed',
                            'CBE_AIPass_State']:
            self.assertIn(requirement,audit)
        native=audit.split('// Paired native waypoint-replacement control.',1)[1].split(
            '// Adaptive attacks remain separate',1)[0]
        self.assertIn('["CBE_Cortex_AirAttack_Enable",false]',native)
        self.assertIn('["CBE_AIPass_Exclude",true,true]',native)
        self.assertIn('distance2D _nativeReplacement <= 350',native)

    def test_air_attack_rechecks_authority_at_native_command_boundaries(self):
        """Planning must not leak one late flight, targeting or fire command after a takeover."""
        controller=source('cortexAirAttack')
        self.assertIn('private _mayControlAircraft = {',controller)
        for boundary in ['_startFailure="CONTROL_RELEASED"',
                         'if (_unsafeDelivery && {!([] call _mayControlAircraft)}) exitWith',
                         'if (_commandedStage != _stage && {!([] call _mayControlAircraft)}) exitWith',
                         'if (_stage == "ATTACK" && {!([] call _mayControlAircraft)}) exitWith']:
            self.assertIn(boundary,controller)
        self.assertLess(controller.index('private _mayControlAircraft = {'),controller.index('_aircraft forceSpeed _appliedSpeed;'))
        self.assertLess(controller.index('if (_commandedStage != _stage && {!([] call _mayControlAircraft)}) exitWith'),controller.index('_aircraft forceSpeed _appliedSpeed;'))
        self.assertLess(controller.index('if (_stage == "ATTACK" && {!([] call _mayControlAircraft)}) exitWith'),controller.index('_aircraft fireAtTarget'))

    def test_aircraft_crew_never_acquire_generic_group_ownership(self):
        eligibility=source('cortexIsEligible')
        self.assertIn('["_allowFeatureOwner",false,[true]]',eligibility)
        self.assertIn('_groundPass && {_alive findIf',eligibility)
        self.assertIn('_vehicle isKindOf "Air"',eligibility)
        discover=source('cortexDiscover')
        self.assertIn('private _groundEligible = [_group,false,true] call CBE_fnc_CortexIsEligible',discover)
        self.assertIn('[_group,true,"AIRCRAFT_DEDICATED"] call CBE_fnc_CortexReleaseGroup',discover)
        self.assertIn('private _eligible = _groundEligible',discover)
        tick=source('cortexGroupTick')
        self.assertIn('private _groundPassEligible=[_group,false,true] call CBE_fnc_CortexIsEligible',tick)
        self.assertIn('[_group,true,"AIRCRAFT_DEDICATED"] call CBE_fnc_CortexReleaseGroup',tick)
        locality=source('cortexLocality')
        air_guard=locality.split('call CBE_fnc_CortexRestoreCalm;',1)[1].split('// A delegated building task',1)[0]
        self.assertIn('vehicle _x isKindOf "Air"',air_guard)
        self.assertIn('exitWith {}',air_guard)

    def test_cortex_air_leases_exclude_other_flight_controllers(self):
        for name in ['helicopterDecelerationCorrectLocal','improvedHelicopterLandingExecuteLocal']:
            path = next((ROOT/'addons').rglob(name+'.sqf'))
            text=path.read_text(encoding='utf-8')
            self.assertIn('CBE_fnc_FlightLeaseAcquire',text,name)
            self.assertIn('CBE_fnc_FlightLeaseValid',text,name)

    def test_direct_zeus_aircraft_orders_exclude_auxiliary_flight_controllers(self):
        for name in ['helicopterDecelerationStep','helicopterDecelerationCorrectLocal',
                     'improvedHelicopterLandingStep','improvedHelicopterLandingExecuteLocal']:
            path = next((ROOT/'addons').rglob(name+'.sqf'))
            text=path.read_text(encoding='utf-8')
            self.assertTrue(
                'CBE_fnc_CortexZeusHeld' in text or 'CBE_fnc_CortexExternalTakeover' in text,
                name
            )

    def test_attack_run_flare_jobs_are_not_queued_for_ineligible_aircraft(self):
        discover=source('cortexDiscover')
        block=discover.split('private _attackFlareEligible',1)[1].split('if (_attackFlareEligible',1)[0]
        for requirement in ['!isNull _pilot','alive _pilot','!isPlayer _pilot','!unitIsUAV _vehicle',
                            'CBE_Cortex_AttackRunFlares_Enable','CortexFeatureEnabled',
                            'CortexIsEligible','CortexAircraftEligible']:
            self.assertIn(requirement,block)

    def test_delayed_missile_flare_bursts_are_generation_owned(self):
        discover=source('cortexDiscover')
        defence=source('cortexMissileDefenceStep')
        for requirement in ['CBE_Cortex_FlareBurstGeneration',
                            'CBE_Cortex_MissileDefenceActive',
                            'CBE_Cortex_LastIncomingMissile',
                            'CBE_fnc_CortexMissileDefenceStep',
                            'CBE_fnc_CortexQueueJob']:
            self.assertIn(requirement,discover)
        for requirement in ['params [["_state",createHashMap,[createHashMap]]]',
                            '!= _generation',
                            '_step in [0,4]',
                            '_projectileKnown && {isNull _missile || {!alive _missile}}',
                            '_step >= 12',
                            '_aircraft setVelocityModelSpace _candidate']:
            self.assertIn(requirement,defence)
        self.assertIn('["expiresAt",serverTime+(12*(0.45+0.18))]',discover)
        expiry=defence.index('private _expiresAt=_state getOrDefault ["expiresAt",-1];')
        for effect in ('call CBE_fnc_FlightLeaseAcquire','call CBE_fnc_CortexFireCountermeasure',
                       '_aircraft setVelocityModelSpace _candidate'):
            self.assertLess(expiry,defence.index(effect))
        self.assertIn('serverTime >= _expiresAt',defence)
        self.assertIn('!finite _expiresAt',defence)
        self.assertIn('"WARNING_EXPIRED"',defence)
        self.assertNotIn('_state set ["expiresAt"',defence)
        self.assertNotIn(' spawn ',discover)
        self.assertNotIn(' sleep ',discover)
        stop=source('cortexStop')
        self.assertIn('CBE_Cortex_FlareBurstGeneration',stop)
        self.assertIn('CBE_Cortex_MissileDefenceActive',stop)
        replacement=discover.split('private _generation=(_vehicle getVariable ["CBE_Cortex_FlareBurstGeneration",0])+1;',1)[1]
        self.assertLess(replacement.index('"WARNING_REPLACED"] call CBE_fnc_FlightLeaseRelease'),
                        replacement.index('setVariable ["CBE_Cortex_FlareBurstGeneration",_generation]'))
        self.assertIn('"MISSILE_DEFENCE",str (_generation-1)',replacement)
        shutdown=stop.split('private _oldFlareGeneration=',1)[1]
        self.assertLess(shutdown.index('"CORTEX_STOPPED"] call CBE_fnc_FlightLeaseRelease'),
                        shutdown.index('setVariable ["CBE_Cortex_FlareBurstGeneration",_oldFlareGeneration+1]'))
        installer=discover.split('private _oldFlareGeneration=',1)[1].split('private _handler =',1)[0]
        self.assertLess(installer.index('"HANDLER_REPLACED"] call CBE_fnc_FlightLeaseRelease'),
                        installer.index('setVariable ["CBE_Cortex_FlareBurstGeneration",_oldFlareGeneration+1]'))
        release=source('flightLeaseRelease')
        for field in ('"controller"','"token"','"owner"'):
            self.assertIn(field,release)
        self.assertLess(stop.index('CBE_Cortex_FlareBurstGeneration'),
                        stop.index('CBE_AIPass_FlaresHandler", nil'))

    def test_keyed_scheduler_jobs_coalesce_only_when_the_caller_requests_it(self):
        queue=source('cortexQueueJob')
        self.assertIn('["_jobKey", "", [""]]',queue)
        self.assertIn('if (_jobKey == "") then {_jobKey = _state getOrDefault ["jobKey", ""]}',queue)
        self.assertIn('if (_jobKey != "") then {',queue)
        self.assertIn('CBE_AIPass_Jobs',queue)
        self.assertIn('CBE_AIPass_PendingJobs',queue)
        self.assertIn('_dueAt min (_existingState getOrDefault ["wakeAt",_dueAt])',queue)
        self.assertIn('_existingState set ["wakeAt", _wakeAt]',queue)
        self.assertIn('_pending pushBack [_dueAt, _job, _state]',queue)
        self.assertIn('forEach ["CBE_AIPass_Jobs", "CBE_AIPass_PendingJobs"]',queue)
        self.assertIn('if (_found) exitWith {};',queue)
        self.assertNotIn('forEach ((missionNamespace',queue)

    def test_attack_flare_audit_preserves_missile_cases_and_uses_real_flight(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        for item in ['AIR-paired-real-threats','AIR-real-firing-solution','AIR-real-missile-fired',
                     'AIR-real-missile-warning','AIR-cortex-defeats-guided-threat',
                     'O_Heli_Attack_02_dynamicLoadout_F','O_Plane_CAS_02_dynamicLoadout_F',
                     '-moving-airborne-precondition','setVelocityModelSpace','-physical-flight',
                     '-approach-release','-departure-release','-ammunition-consumed','-no-cortex-release',
                     'addEventHandler ["Fired"','_group reveal [_target,4]']:
            self.assertIn(item,text)
        self.assertIn('["CBE_Cortex_AirAttack_Enable",false]',text)
        self.assertNotIn('call CBE_fnc_CortexAttackRunFlares',text)
        self.assertNotIn('call CBE_fnc_CortexFireCountermeasure',text)
        stop=source('cortexStop')
        self.assertLess(stop.index('CBE_Cortex_AttackFlareJob'),stop.index('if (!isNull _group) then',stop.index('private _jobs')))

    def test_air_attack_audit_proves_patterns_fire_flares_and_handover(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        for item in ['AIR-ATTACK-HELI-LATERAL','AIR-ATTACK-PLANE-STRAFE','AIR-ATTACK-PLANE-OFFSET',
                     'AIR-ATTACK-PLANE-HOOK','AIR-ATTACK-PLANE-AA','AIR-ATTACK-PLANE-INTERCEPT',
                     'AIR-ATTACK-PLANE-BOMB','AIR-ATTACK-PLANE-GUIDED','-target-destroyed',
                     '-armed-live-operator','-damageable-target-prerequisite',
                     '-fixture-armed-preflight','private _loadedStations=','private _fixtureArmed=',
                     'AIR-ATTACK-ZEUS-HANDOVER','AIR-ATTACK-DISABLED','-air-contact-intercept-plan',
                     '-physical-plan-start','-aa-aware-pattern','-actual-weapon-fire',
                      '-pattern-specific-flight-profile','-delivery-axis-crosses-target',
                      '-safe-flight-envelope','-weapon-matches-manoeuvre','-effective-release',
                      '-physical-profile-change','AIR-ATTACK-distinct-fixed-wing-profiles',
                     '-continuous-useful-flight',
                     '-visible-countermeasures','-safe-crew-egress','CortexZeusMark',
                     'CBE_CortexQA_AttackStageShots','CBE_CortexQA_AdaptiveShots",0]) > 0',
                     'CBE_Cortex_AirAttackBlockedUntil",serverTime+300',
                     '-zeus-snapshot-exact','-zeus-replacement-travel','-no-old-plan-resurrection','-explicit-state-flow',
                     '-explicit-interruption-transition','-pilot-features-restored','-lateral-capable-turret','setVelocityModelSpace']:
            self.assertIn(item,text)
        for item in ['CBE_Cortex_AirHandoverRecovery','CBE_ImprovedHelicopterLanding_Active',
                     'CBE_ImprovedHelicopterLanding_LastResult','CBE_HelicopterDeceleration_Active',
                     'CBE_HelicopterDeceleration_LastResult','checkAIFeature _x','unitReady _handoverPilot',
                     'canMove _aircraft','isEngineOn _aircraft','fuel _aircraft','damage _aircraft']:
            self.assertIn(item,text)
        self.assertIn('CBE_CortexQA_ReleaseSamplesStarted',text)
        self.assertIn('if (!_fixtureArmed) then {_group setVariable ["CBE_AIPass_Exclude",true,true]}',text)
        self.assertIn('"O_Truck_03_transport_F"',text)
        self.assertNotIn('"O_Quadbike_01_F"',text)
        self.assertIn('[_group,true,_replacementWaypoint select 1] call CBE_fnc_CortexZeusMark',text)
        self.assertIn('private _replacementWaypoint=_group addWaypoint [_replacement,0]',text)
        self.assertIn('_group setCurrentWaypoint _replacementWaypoint',text)
        self.assertLess(text.index('_group setCurrentWaypoint _replacementWaypoint'),
                        text.index('[_group,true,_replacementWaypoint select 1] call CBE_fnc_CortexZeusMark'))
        self.assertIn('setWaypointSpeed "FULL"',text)
        self.assertIn('findIf {(_x select 1) == "DEPARTURE"}',text)
        self.assertNotIn('missionNamespace getVariable ["CBE_AIPass_ZeusHoldSeconds",120]',text)
        positive,negative_tail=text.split('// Negative execution boundary, separate from physical attack acceptance.',1)
        negative,disabled=negative_tail.split('// The adaptive controller',1)
        self.assertNotIn('call CBE_fnc_CortexAirAttack;',positive+disabled)
        self.assertEqual(negative.count('call CBE_fnc_CortexAirAttack;'),1)
        self.assertIn('forgetTarget _unknownTarget',negative)
        self.assertIn('NO_KNOWN_TARGET',negative)
        self.assertNotIn('call CBE_fnc_CortexAirAttackPlan;',positive+disabled)
        self.assertEqual(negative.count('call CBE_fnc_CortexAirAttackPlan;'),1)
        guide=(ROOT/'releaseVerificationAndDeployment/cortexQA/runGuide.sqf').read_text()
        for item in ['CBE_Cortex_AirAttackPlan','actual shots','observed AA','CountermeasureLastRequest']:
            self.assertIn(item,guide)
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('cortex-air-attack-snapshot-limits',diagnostic)

    def test_onboard_reports_are_expiring_owner_validated_cargo_only(self):
        text=source('cortexOnboardContact')
        for item in ['groupOwner _reporter == _owner','group effectiveCommander _vehicle == _reporter','serverTime < _expiry','serverTime+35','CortexPassengerReady','CortexIsEligible','CortexRestoreCalm','CBE_Cortex_DismountStopRequest']:
            self.assertIn(item,text)
        self.assertLess(text.index('_state set ["dismounted"'),text.index('doGetOut'))
        self.assertNotIn(' reveal ',text)
        self.assertNotIn('doMove',text)
        tick=source('cortexGroupTick')
        self.assertIn('if (!_ordered && {_visible isEqualTo []}',tick)

    def test_danger_only_contact_does_not_authorise_target_dependent_tactics(self):
        tick=source('cortexGroupTick')
        self.assertIn('private _hasTargetKnowledge = _enemies isNotEqualTo [];',tick)
        self.assertIn('Danger geometry is deliberately approximate',tick)
        for dispatch in [
            'CBE_fnc_CortexAntiArmour',
            'CBE_fnc_CortexArtilleryRequest',
            'CBE_fnc_CortexReinforce',
            'CBE_fnc_CortexCoordinatedAssault',
            'CBE_fnc_IndoorActorDispatch',
            'CBE_fnc_CortexTacticalStart'
        ]:
            contact=tick.split('case "CONTACT": {',1)[1]
            call=contact.index(dispatch)
            guard=contact.rfind('_hasTargetKnowledge',0,call)
            self.assertGreaterEqual(guard,0,dispatch)
            self.assertLess(call-guard,500,dispatch)
        # Local immediate response and vehicle stop restoration still run without target identity.
        contact=tick.split('case "CONTACT": {',1)[1]
        self.assertIn('CBE_fnc_CortexMorale',contact)
        self.assertIn('CBE_fnc_CortexStance',contact)
        self.assertIn('CBE_fnc_CortexVehicles',contact)
        self.assertIn('_state set ["contactKnowledge",(_state getOrDefault ["contactKnowledge",false]) || {_hasTargetKnowledge}];',tick)
        self.assertIn('_state set ["contactKnowledge",true];',contact)
        self.assertIn('if (!_manoeuvreActive && {!_dangerActive}',contact)
        self.assertIn('&& {!(_state getOrDefault ["contactKnowledge",false])}) exitWith {',contact)
        self.assertIn('"DANGER_EXPIRED"',contact)
        self.assertIn('"contactKnowledge"',source('cortexRestoreCalm'))

    def test_cross_group_dismount_safe_stop_is_owner_validated_and_reversible(self):
        vehicles=source('cortexVehicles')
        for item in ['CBE_Cortex_DismountStopRequest','groupOwner _passengerGroup == _passengerOwner',
                     'effectiveCommander _vehicle in units _group','CBE_fnc_CortexDismountStop',
                     '[_group,groupOwner _group,serverTime+30]']:
            self.assertIn(item,vehicles)
        tick=source('cortexGroupTick')
        onboard=source('cortexOnboardContact')
        cap=source('cortexDismountStop')
        self.assertIn('(_continuation select 3) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',tick)
        self.assertIn('(_continuation select 3) isEqualTo ([_passengerGroup] call CBE_fnc_NativeOrderReceipt)',vehicles)
        for producer,marker in ((vehicles,'+_dismounted,'),(onboard,'+_owned,')):
            receipt=producer.split(marker,1)[1].split('],true]',1)[0]
            self.assertIn('[_group] call CBE_fnc_NativeOrderReceipt',receipt)
        self.assertIn('[_group getVariable ["CBE_OperationGeneration",0],\n            +_native]',cap)
        crew=vehicles.split('&& {_crewProof isEqualTo',1)[1].split('&& {!_movementOwned}',1)[0]
        self.assertIn('CBE_fnc_NativeOrderReceipt',crew)
        release=source('cortexReleaseGroup')
        stop=source('cortexStop')
        for text in [release,stop]:
            self.assertIn('CBE_fnc_CortexDismountStop',text)
            self.assertIn('CBE_Cortex_DismountStopRequest',text)

    def test_danger_only_vehicle_response_uses_safe_dismount_without_target_work(self):
        tick=source('cortexGroupTick')
        vehicles=source('cortexVehicles')
        restore=source('cortexRestoreCalm')
        self.assertIn('_state set ["dangerDismount",[+_dangerPosition,time+30,_vehicleProfile,_dangerCause,_dangerVehicle,_dangerSource,_dangerGeneration,_dangerSourceUntil,_dangerWitness]];',tick)
        self.assertIn('if (count _dangerDismount == 9) then {',vehicles)
        self.assertIn('private _affectedVehicles=[_dangerVehicle];',vehicles)
        self.assertIn('{_dangerVehicle in _vehicles}',vehicles)
        self.assertNotIn('else {_vehicles}',vehicles)
        self.assertIn('if (_vehicleProfile != "") then {',tick)
        self.assertIn('_dangerCause in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"] || {_dangerHostile}',vehicles)
        self.assertIn('_dangerProfile in ["TRANSPORT","ARMED","ARMOURED"]',vehicles)
        self.assertIn('CBE_Danger_VehicleContext',tick)
        self.assertLess(vehicles.index('private _dangerDismount='),vehicles.index('if (_enemies isEqualTo []) exitWith'))
        danger_segment=vehicles.split('private _dangerDismount=',1)[1].split('if (_enemies isEqualTo []) exitWith',1)[0]
        self.assertIn('time < _dangerSourceUntil',danger_segment)
        self.assertIn('_dangerWitness knowsAbout _dangerSource > 0',danger_segment)
        self.assertIn('_dangerWitness targetKnowledge _dangerSource',danger_segment)
        self.assertIn('_dangerWitness getHideFrom _dangerSource',danger_segment)
        self.assertNotIn('_vehicle distance2D _dangerSource',danger_segment)
        self.assertIn('_vehicle distance2D _dangerBelief < 25',danger_segment)
        self.assertNotIn('(units _group) findIf {_x knowsAbout _dangerSource',danger_segment)
        for token in ['_knownCloseThreat','_emplacementUnsafe','_disabledUnsafe','CBE_Danger_AbandonReason']:
            self.assertIn(token,danger_segment)
        self.assertIn('call _dismountAtThreat',danger_segment)
        abandonment=danger_segment.split('if ((_emplacementUnsafe || {_disabledUnsafe})',1)[1].split('// An intact armed platform',1)[0]
        self.assertLess(abandonment.index('call _crewActorAvailable'),abandonment.index('orderGetIn false'))
        self.assertLess(abandonment.index('currentCommand _x != "STOP"'),abandonment.index('orderGetIn false'))
        crew_authority=vehicles.split('private _crewActorAvailable=',1)[1].split('if (_externalTakeover)',1)[0]
        for proof in ('CortexCombatEffective','remoteControlled','CortexExternalOwner','CompatibilityExternalControl','CortexActorFireTaskAvailable'):
            self.assertIn(proof,crew_authority)

        helper=vehicles.split('private _dismountAtThreat = {',1)[1].split('// Cross-group safe-stop handshake',1)[0]
        for marker in ['CBE_Cortex_DismountStopRequest','CBE_fnc_CortexDismountStop',
                       'CBE_Cortex_OnboardDanger','CBE_fnc_CortexPassengerReady',
                       'orderGetIn false','unassignVehicle','doGetOut']:
            self.assertIn(marker,helper)
        for forbidden in ['doTarget','doFire','CBE_fnc_CortexGroupMove','CBE_fnc_OperationStart']:
            self.assertNotIn(forbidden,helper)
            self.assertNotIn(forbidden,danger_segment)
        self.assertIn('"dangerDismount"',restore)
        onboard=source('cortexOnboardContact')
        self.assertIn('CBE_Cortex_OnboardDanger',onboard)
        self.assertNotIn(' reveal ',onboard)
        for cleanup in [source('cortexReleaseGroup'),source('cortexStop')]:
            self.assertIn('CBE_Cortex_OnboardDanger',cleanup)

    def test_contact_dismount_speed_restore_requires_the_owned_zero_cap(self):
        vehicles=source('cortexVehicles')
        release=source('cortexReleaseGroup')
        stop=source('cortexStop')
        helper=source('cortexDismountStop')
        for text in [vehicles,release,stop]:
            self.assertIn('call CBE_fnc_CortexDismountStop',text)
            self.assertNotIn('_vehicle forceSpeed (_saved',text)
        for proof in ['expectedDestination _driver isEqualTo (_proof select 5)',
                      'expectedDestination _commander isEqualTo (_proof select 7)',
                      '_native isEqualTo (_proof select 3)',
                      '_driver == (_proof select 1)', '_commander == (_proof select 2)',
                      'CBE_fnc_CortexActorFireTaskAvailable', 'CBE_ExternalDrivingOwner',
                      'getForcedSpeed _vehicle == (_saved select 1)',
                      'getForcedSpeed _vehicle == (_saved select 0)',
                      'CBE_Cortex_DismountStopUnresolved']:
            self.assertIn(proof,helper)
        self.assertIn('[_vehicle,_group,"RELEASE",!_externalTakeover]',release)
        self.assertLess(helper.index('isNil {'),helper.index('_vehicle forceSpeed 0'))
        self.assertNotIn('remoteExec',helper)
        self.assertNotIn('CBA_fnc_add',helper)

    def test_countermeasure_inventory_includes_modded_person_turrets(self):
        for name in ['cortexFireCountermeasure','cortexVehicles']:
            text=source(name)
            self.assertIn('allTurrets [_vehicle, true]',text)
            self.assertNotIn('allTurrets [_vehicle, false]',text)

    def test_passenger_migration_retains_intent_without_immediate_boarding(self):
        text=source('cortexLocality')
        self.assertIn('_adopted set ["dismounted",_passengers]',text)
        self.assertIn('assignedVehicle _unit == _vehicle',text)
        self.assertIn('_adopted set ["onboardContactUntil",serverTime+30]',text)
        self.assertNotIn('orderGetIn true',text)

    def test_passenger_audit_checks_readiness_and_fixture_motion(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text()
        self.assertLess(text.index('DISMOUNT-fixture-controller-ready'),text.index('private _enemyGroup=createGroup'))
        for item in ['DISMOUNT-fixture-stationary-held','DISMOUNT-fixture-safe-stop-observed','REMOUNT-group-membership-independent','REMOUNT-original-groups-retained']:
            self.assertIn(item,text)
        for item in ['DANGER-VEHICLE-fixture-moving','DANGER-VEHICLE-native-explosion',
                     'DANGER-VEHICLE-bounded-safety-lease','DANGER-VEHICLE-safe-stop',
                     'DANGER-VEHICLE-passengers-physically-exit','DANGER-VEHICLE-operating-crew-retained',
                     'DANGER-VEHICLE-no-invented-combat','DANGER-VEHICLE-contact-fixture-ready',
                     'DANGER-VEHICLE-effective-commander-persistence',
                     'DANGER-VEHICLE-known-hostile-finite-reaction',
                     'DANGER-VEHICLE-finite-countermeasure',
                     'DANGER-STATIC-empty-crew-released','DANGER-STATIC-useful-crew-retained',
                     'DANGER-STATIC-no-invented-combat']:
            self.assertIn(item,text)
        self.assertIn('private _spawnRealGrenade={',text)
        self.assertIn('addEventHandler ["FiredMan"',text)
        self.assertIn('forceWeaponFire ["HandGrenadeMuzzle","HandGrenadeMuzzle"]',text)
        self.assertIn('CBE CORTEX QA FIXTURE ERROR: native grenade firing produced no projectile',text)
        self.assertIn('private _sourceGroup=createGroup [west,true]',text)
        self.assertIn('_source hideObjectGlobal true',text)
        self.assertIn('_grenade setVelocity [0,0,-4]',text)
        self.assertGreaterEqual(text.count('call _spawnRealGrenade'),6)
        self.assertNotIn('attackTarget',text)
        self.assertIn('abs speed _dangerTruck > 5',text)
        self.assertIn('O_APC_Tracked_02_cannon_F',text)
        self.assertIn('effectiveCommander _contactVehicle',text)
        self.assertIn('count _actors == 1',text)
        self.assertIn('CBE_Danger_VehicleReaction',text)
        mounted=text.split('// A three-person armoured crew',1)[1].split('deleteGroup _contactCrewGroup;',1)[0]
        for forbidden in [' reveal ', ' doTarget ', ' doFire ', ' forceWeaponFire ', ' call CBE_fnc_DangerEngineSubmit']:
            self.assertNotIn(forbidden,mounted)
        dismount=text[text.index('private _dismounted=[{'):text.index('},35] call _wait;',text.index('private _dismounted=[{'))]
        self.assertIn('vehicle _x != _x',dismount)
        self.assertNotIn('vehicle _x != _truck',dismount)

    def test_mounted_danger_reacts_once_without_taking_route_ownership(self):
        text=source('cortexVehicles')
        danger=text.split('private _dangerDismount=',1)[1].split('if (_enemies isEqualTo []) exitWith',1)[0]
        for marker in ['vehicleDangerReaction','_dangerGeneration','CBE_Danger_VehicleReaction',
                       'call CBE_fnc_CortexLineOfFireClear','doSuppressiveFire _aimPosition']:
            self.assertIn(marker,danger)
        self.assertIn('_gunner doWatch (ASLToAGL _aimPosition)',danger)
        self.assertNotIn('_gunner doWatch _aimPosition;',danger)
        suppression=danger.split('// An intact armed platform',1)[1].split('// Defensive smoke is independent',1)[0]
        for forbidden in ['CortexGroupMove','addWaypoint','forceSpeed','setVelocity']:
            self.assertNotIn(forbidden,suppression)

    def test_vehicle_danger_jink_is_short_generation_owned_and_subordinate(self):
        registry=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        vehicles=source('cortexVehicles')
        jink=source('cortexVehicleJink')
        self.assertIn('_candidates pushBack [_origin getPos [_x select 0,_awayBearing+(_x select 1)]]',jink)
        avenue=source('cortexSelectAvenue')
        self.assertIn('_route isEqualType []',avenue)
        self.assertIn('!(_x isEqualType [])',avenue)
        self.assertIn('class CortexVehicleJink',registry)
        for marker in [
            'CBE_AIPass_VehicleJink_Enable','CBE_Convoy_Active','CortexExternalTakeover',
            'count (_group getVariable ["CBE_Operation",createHashMap]) > 0',
            '(_state getOrDefault ["movementLease",[]]) isNotEqualTo []',
            'fullCrew [_vehicle,"",false]','vehicle _x == _x','abs speed _vehicle > 25',
            'CBE_fnc_CortexSelectAvenue','["VEHICLE_JINK",time+25]',
            'CBE_fnc_OperationStart','CBE_fnc_CortexGroupMove','CBE_Danger_VehicleJink'
        ]:
            self.assertIn(marker,jink)
        for forbidden in ['setPos','setVelocity','moveIn','allowDamage','disableCollisionWith','while {']:
            self.assertNotIn(forbidden,jink)
        self.assertIn('vehicleDangerJink',vehicles)
        crew=source('cortexVehicleCrewAvailable')
        for gate in ('effectiveCommander _crewVehicle','driver _crewVehicle','_expectedSeats isNotEqualTo _seats',
                     'CortexActorFireTaskAvailable','fleeing _x','simulationEnabled _x','CortexExternalOwner','CBE_ExternalDrivingOwner'):
            self.assertIn(gate,crew)
        self.assertIn('_seats arrayIntersect _seats',crew)
        self.assertIn('if (_expectedSeats isNotEqualTo _seats) exitWith {false}',crew)
        current=['driver','commander']
        for malformed in ([],['driver'],['driver','replacement'],['commander','driver']):
            self.assertNotEqual(malformed,current)
        self.assertEqual(list(dict.fromkeys(['driver','driver'])),['driver'])
        self.assertEqual(jink.count('call CBE_fnc_CortexVehicleCrewAvailable'),3)
        self.assertLess(jink.rindex('call CBE_fnc_CortexVehicleCrewAvailable'),jink.index('call CBE_fnc_CortexGroupMove'))
        self.assertIn('_operation set ["vehicleJinkCrew",[_vehicle,+_jinkSeats]]',jink)
        self.assertIn('getOrDefault ["vehicleJinkCrew",[]]',vehicles)
        self.assertIn('"VEHICLE_CREW_CHANGED"] call CBE_fnc_OperationCancel',vehicles)
        for command in ('doMove','doFollow','doStop','setVariable','sendSimpleCommand'):
            self.assertNotIn(command,crew)
        for name in ('dangerVehicleProfile','cortexVehicleJink','cortexVehicles'):
            classifier=source(name)
            self.assertIn('isKindOf ["CarHorn",configFile >> "CfgWeapons"]',classifier)
            self.assertIn('["carhorn","cmlauncher"]',classifier)
            self.assertNotIn('>> "displayName")) != "horn"',classifier)
            self.assertNotIn('>> "displayName") != "horn"',classifier)
        # Labels are presentation, not combat capability: translated horns remain utility.
        def combat(horn_family,simulation,label):
            return not horn_family and simulation.lower() not in ('carhorn','cmlauncher')
        for label in ('Horn','Hupe','Custom siren',''):
            self.assertFalse(combat(True,'Weapon',label))
            self.assertFalse(combat(False,'CarHorn',label))
        self.assertFalse(combat(False,'CMLauncher','Launcher'))
        self.assertTrue(combat(False,'Weapon','Horn'))
        self.assertIn('serverTime+25,_generation],true]',jink)
        cleanup=vehicles.split('if (_finishedOwner == "VEHICLE_JINK")',1)[1].split('if (_finishedOwner == "VEHICLE_ORIENT")',1)[0]
        self.assertIn('(_marker param [4,-1,[0]]) == _generation',cleanup)
        calm=source('cortexRestoreCalm')
        jink_cleanup=calm.split('private _vehicleJink=',1)[1].split('private _vehicleOrient=',1)[0]
        self.assertIn('(_jinkMarker param [4,-1,[0]]) == (_state getOrDefault ["vehicleOperationGeneration",-2])',jink_cleanup)
        self.assertIn('_dangerCause in ["HIT","EXPLOSION"] || {_knownCloseThreat}',vehicles)
        self.assertIn('["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"]',vehicles)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        for marker in ['DANGER-VEHICLE-jink-disabled','DANGER-VEHICLE-jink-operation-owned',
                       'DANGER-VEHICLE-jink-physical-travel','DANGER-VEHICLE-jink-crew-retained']:
            self.assertIn(marker,audit)

    def test_tracked_vehicle_danger_orientation_is_finite_generation_owned_and_route_safe(self):
        registry=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        orient=source('cortexVehicleOrient')
        vehicles=source('cortexVehicles')
        self.assertIn('class CortexVehicleOrient',registry)
        for marker in [
            'CBE_AIPass_VehicleGunnery_Enable','CBE_Convoy_Active','CortexExternalTakeover',
            'isKindOf "Tank"','abs speed _vehicle > 5',
            'count (_group getVariable ["CBE_Operation",createHashMap]) > 0',
            '(_state getOrDefault ["movementLease",[]]) isNotEqualTo []',
            'CBE_fnc_CortexOwnershipLease','CBE_fnc_OperationStart',
            '["VEHICLE_ORIENT",time+8]','sendSimpleCommand _turnDirection',
            'CBE_Danger_VehicleOrient'
        ]:
            self.assertIn(marker,orient)
        for forbidden in ['setDir','setVectorDir','setVelocity','setPos','doMove','commandMove','addWaypoint','while {']:
            self.assertNotIn(forbidden,orient)
        self.assertIn('vehicleDangerOrient',vehicles)

        self.assertIn('CBE_ExternalDrivingOwner',orient)

        jink=source('cortexVehicleJink')
        for starter in [orient,jink]:
            for guard in ['CortexActorFireTaskAvailable','CortexCombatEffective','checkAIFeature "MOVE"','checkAIFeature "PATH"']:
                self.assertIn(guard,starter)
            self.assertLess(starter.index('CortexActorFireTaskAvailable'),starter.index('call CBE_fnc_OperationStart'))
        self.assertIn('_operationGeneration,_driver',orient)
        self.assertIn('driver _orientVehicle != _turnDriver',vehicles)
        self.assertIn('!_orientDriverProtected',vehicles)
        self.assertIn('DRIVER_TASK_OR_SEAT',vehicles)
        self.assertIn('CortexActorFireTaskAvailable',orient.split('if (!([_commander]',1)[1])
        self.assertIn('_nativeOrder,_commander',orient)
        for guard in ('effectiveCommander _orientVehicle != _turnCommander','!_orientCommanderProtected',
                      'COMMANDER_TASK_OR_SEAT','count _marker == 9'):
            self.assertIn(guard,vehicles)
        self.assertIn('private _nativeOrder=[_group] call CBE_fnc_NativeOrderReceipt',orient)
        self.assertIn('_operationGeneration,_driver,_nativeOrder',orient)
        self.assertIn('_orientOrderChanged=(_marker param [6,[],[[]]]) isNotEqualTo',vehicles)
        self.assertIn('!_orientOrderChanged',vehicles)
        self.assertIn('NATIVE_ORDER_CHANGED',vehicles)
        self.assertIn('_commander == _driver',orient)
        self.assertIn('vehicleMoveInfo _vehicle',orient)
        self.assertIn('["BACK","DIRECTBYCOMANDER"]',orient)
        self.assertIn('_commander,_turnDirection',orient)
        self.assertIn('NATIVE_INPUT_CHANGED',vehicles)
        self.assertIn('_observedTurn in ["NONE",_turnDirection]',vehicles)
        self.assertIn('!_orientInputChanged',vehicles)
        for guard in ('captive _threat','ace_captives_isSurrendering','ace_captives_isHandcuffed',
                      '(side _group) getFriend (side _threat) >= 0.6'):
            self.assertIn(guard,orient)
        for guard in ('_orientThreatInvalid','getOrDefault ["objective",objNull]',
                      'captive _turnThreat','(side _group) getFriend (side _turnThreat) >= 0.6',
                      '!_orientThreatInvalid','CONTACT_INVALID'):
            self.assertIn(guard,vehicles)
        threat_check=vehicles.split('private _turnThreat=',1)[1].split('private _turnGeneration=',1)[0]
        self.assertNotIn('getPos',threat_check)
        self.assertNotIn('nearEntities',threat_check)
        for guard in ['_orientOperationChanged','_turnGeneration != (_orientOperation getOrDefault ["generation",-2])',
                      '(_orientOperation getOrDefault ["intent",""]) != "VEHICLE_ORIENT"',
                      '(_orientOperation getOrDefault ["phase",""]) == "CANCELLED"',
                      '(_marker param [4,-1,[0]]) == _generation']:
            self.assertIn(guard,vehicles)

        self.assertLess(orient.index('CBE_ExternalDrivingOwner'),orient.index('call CBE_fnc_OperationStart'))
        active=vehicles.split('private _orientControllerExternal=',1)[1].split('private _reverse=',1)[0]
        self.assertIn('CBE_ExternalDrivingOwner',active)
        self.assertIn('_activeVehicleMove=!_orientControllerExternal',active)
        self.assertIn('if (_orientControllerExternal ||',vehicles)
        self.assertIn('if (!_orientControllerExternal &&',vehicles)
        calm=source('cortexRestoreCalm').split('private _vehicleOrient=',1)[1].split('if (!_yieldToExternal && {_state',1)[0]
        self.assertLess(calm.index('CBE_ExternalDrivingOwner'),calm.index('sendSimpleCommand "STOPTURNING"'))
        self.assertIn('CompatibilityExternalControl',calm)
        self.assertIn('driver _orientVehicle == _turnDriver',calm)
        self.assertIn('effectiveCommander _orientVehicle == _turnCommander',calm)
        self.assertIn('count _orientMarker == 9',calm)
        self.assertIn('vehicleMoveInfo _orientVehicle',calm)
        self.assertIn('== (_orientMarker select 8)',calm)
        self.assertIn('CortexActorFireTaskAvailable',calm)
        self.assertIn('(_orientMarker param [6,[],[[]]]) isEqualTo',calm)
        self.assertIn('NativeOrderReceipt',calm)

        self.assertIn('_dangerProfile == "ARMOURED"',vehicles)
        self.assertIn('sendSimpleCommand "STOPTURNING"',vehicles)
        for marker in ['CBE_fnc_OperationCancel','VEHICLE_ORIENT_TIMEOUT','VEHICLE_ORIENT_ALIGNED',
                       '["INCOMPLETE","COMPLETE"] select _aligned']:
            self.assertIn(marker,vehicles)
        self.assertIn('["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"]',vehicles)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        self.assertIn('driver _orientVehicle == _orientOriginalDriver',audit)
        self.assertIn('param [5,objNull,[objNull]]) == _orientOriginalDriver',audit)
        for marker in ['DANGER-VEHICLE-orient-disabled','DANGER-VEHICLE-orient-operation-owned',
                       'DANGER-VEHICLE-orient-physical-alignment','DANGER-VEHICLE-orient-no-travel',
                       'DANGER-VEHICLE-orient-crew-retained']:
            self.assertIn(marker,audit)

    def test_airborne_held_first_fixture_requires_another_physical_exit(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAirborne.sqf').read_text(encoding='utf-8')
        for marker in ['AIRBORNE-held-first-stays-aboard','AIRBORNE-unheld-passenger-exits',
                       'vehicle _unheld isKindOf "ParachuteBase"','vehicle _heldActor == _aircraft',
                       'isEqualTo _holdLease','CBE_CortexQA_HeadlessBatch',
                       '"CBE_AIPass_Airborne_JumpInterval",_savedJumpInterval,true']:
            self.assertIn(marker,qa)
        self.assertNotIn('call CBE_fnc_CortexParachuteJump',qa)
        self.assertNotIn('CBE_fnc_CortexAirborneDropStep',qa)
        self.assertIn('AIRBORNE-physical-landing',qa)
        self.assertIn('AIRBORNE-post-landing-movement',qa)

    def test_airborne_episode_rejects_stale_execution_and_cleanup(self):
        start=source('cortexAirborneCheck')
        climb=start.split('private _climbToken=',1)[1].split('private _height =',1)[0]
        for marker in ('"AIRBORNE_CLIMB",_climbToken,50','call CBE_fnc_FlightLeaseAcquire',
                       'call CBE_fnc_FlightLeaseValid','call CBE_fnc_FlightLeaseRelease'):
            self.assertIn(marker,climb)
        self.assertLess(climb.index('FlightLeaseValid'),climb.index('flyInHeight'))
        self.assertLess(climb.index('flyInHeight'),climb.index('_state set ["airborneClimb"'))
        self.assertLess(climb.index('_state set ["airborneClimb"'),climb.index('FlightLeaseRelease'))
        finish=source('cortexAirborneDropStep').split('private _finish =',1)[1].split('if (isNull _group',1)[0]
        self.assertLess(finish.index('_episode isEqualTo (_group'),finish.index('deleteAt "airborneClimb"'))
        self.assertIn('deleteAt "airborneClimb"',finish)
        context=start.split('private _climbContext=',1)[1].split('private _climbToken=',1)[0]
        for marker in ('_aircraft,_pilot,effectiveCommander _aircraft,clientOwner',
                       'CBE_AIPass_Epoch','_pilotRoute,_requestedHeight',
                       'getOrDefault ["airborneClimb",[]]) isNotEqualTo _climbContext'):
            self.assertIn(marker,context)
        self.assertNotIn('_target',context)
        self.assertIn('waypointPosition [_pilotGroup,_pilotWaypoint]',start)
        self.assertIn('waypointType [_pilotGroup,_pilotWaypoint]',start)
        self.assertIn('if (_riding isEqualTo []) exitWith {_state deleteAt "airborneClimb";',start)
        self.assertNotIn('CBE_AIPass_AirborneClimb',start)

        shutdown=source('cortexStop').split('private _airborneStopEpisode=',1)[1]
        self.assertIn('local _aircraft',shutdown)
        self.assertIn('deleteAt "airborneClimb"',source('cortexStop'))


        step=source('cortexAirborneDropStep')
        self.assertIn('["episode",_episode]',start)
        self.assertIn('CBE_AIPass_DropSerial',start)
        for owner in ['_group','_aircraft']:
            self.assertIn(owner+' setVariable ["CBE_AIPass_DropEpisode",_episode,true]',start)
        entry=step.split('private _finish =',1)[0]
        for guard in ['_episode isEqualTo []','CBE_AIPass_Epoch','CBE_AIPass_DropEpisode','exitWith {-1}']:
            self.assertIn(guard,entry)
        finish=step.split('private _finish = {',1)[1].split('if (isNull _group',1)[0]
        self.assertLess(finish.index('_episode isEqualTo (_group getVariable'),finish.index('setVariable ["CBE_AIPass_Dropping",nil]'))
        self.assertLess(finish.index('_episode isEqualTo (_aircraft getVariable'),finish.index('setVariable ["CBE_AIPass_DropUntil",nil]'))

    def test_airborne_drop_rechecks_live_aircraft_control_before_each_exit(self):
        drop=source('cortexAirborneDropStep')
        phase=drop.split('if ((_job get "phase") == "DROP") exitWith {',1)[1].split('// LAND',1)[0]
        selection=phase.split('private _jumpers =',1)[1].split('if (_jumpers isEqualTo []',1)[0]
        for guard in ['CBE_fnc_CortexActorMoveReserved','CBE_fnc_CortexCombatEffective',
                      'remoteControlled _x','CBE_fnc_CompatibilityExternalControl']:
            self.assertIn(guard,selection)
        for guard in ['private _pilot=driver _aircraft','isPlayer _commander','remoteControlled _pilot',
                      'remoteControlled _commander','bis_fnc_moduleRemoteControl_owner',
                      '[group _pilot] call CBE_fnc_CortexExternalTakeover',
                      '[group _commander] call CBE_fnc_CortexExternalTakeover']:
            self.assertLess(phase.index(guard),phase.index('call CBE_fnc_CortexParachuteJump'))

    def test_parachute_exit_preserves_actor_tasks_before_mutation(self):
        jump=source('cortexParachuteJump')
        for guard in ['call CBE_fnc_CortexCombatEffective','call CBE_fnc_CortexActorMoveReserved',
                      'remoteControlled _unit','bis_fnc_moduleRemoteControl_owner',
                      'call CBE_fnc_CortexExternalOwner','call CBE_fnc_CompatibilityExternalControl']:
            self.assertLess(jump.index(guard),jump.index('_unit allowDamage false'))
            self.assertLess(jump.index(guard),jump.index('moveOut _unit'))

    def test_combined_ammo_diagnostic_requires_native_empty_state_with_positive_stock(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombinedArms.sqf').read_text(encoding='utf-8')
        diagnostic=qa.split('// Isolated capability diagnostic',1)[1].split('[createHashMapFromArray [',1)[0]
        for marker in ['COMBINED-ammo-loaded-native-fixture','COMBINED-ammo-loaded-ready',
                       'COMBINED-ammo-reserve-only-native-fixture','COMBINED-ammo-reserve-only-rejected',
                       'weaponState [_ammoTruck,_ammoStation,_x]','magazinesAllTurrets _ammoTruck',
                       '_reserveFixture && {!([_ammoTruck,_ammoGunner]',
                       'deleteVehicle _ammoTruck','deleteGroup _ammoGroup']:
            self.assertIn(marker,diagnostic)
        self.assertIn('(_x select 4) > 0',diagnostic)
        self.assertIn('(_x select 2) > 0',diagnostic)
        self.assertNotIn('CortexCombinedArmsLocal',diagnostic)
        self.assertNotIn('doFire',diagnostic)
        self.assertIn('count _ammoWeapons == 1',diagnostic)
        self.assertIn('in [[],["this"]]',diagnostic)
        self.assertIn('_ammoWeapon="";_ammoMagazine="";_loadedState=[];',diagnostic)

    def test_air_init_adoption_cannot_age_active_issuer_release_window(self):
        adopt=source('cortexAirPilotFeatureAdopt')
        guard=adopt.split('// Init/late lookup on the original owner',1)[1].split('// The immutable issuer',1)[0]
        self.assertIn('(_receipt select 5) isEqualTo clientOwner',guard)
        self.assertIn('(_receipt select 7) isEqualTo -1',guard)
        self.assertIn('exitWith {false}',guard)
        self.assertLess(adopt.index('// Init/late lookup'),adopt.index('call CBE_fnc_CortexAirPilotFeatureRelease'))

    def test_air_feature_release_deadline_survives_adoption_without_renewal(self):
        release=source('cortexAirPilotFeatureRelease')
        self.assertIn('if (_releaseUntil == -1) then {',release)
        self.assertEqual(release.count('serverTime+60'),1)
        self.assertIn('_receipt set [7,_releaseUntil]',release)
        self.assertIn('serverTime >= _releaseUntil',release)
        self.assertLess(release.index('serverTime >= _releaseUntil'),release.index('_actor enableAI'))
        self.assertNotIn('CBE_AirPilotFeatureReleaseWindow',release)
        self.assertNotIn('MISSING_RELEASE_WINDOW',release)
        adopt=source('cortexAirPilotFeatureAdopt')
        self.assertIn('_attempt < 5',adopt)
        self.assertIn('(vehicle _actor) isKindOf "Air"',adopt)
        self.assertIn('[_actor,true,_attempt+1,_epoch]',adopt)
        self.assertNotIn('serverTime+60',adopt)

    def test_air_migration_can_start_release_before_original_issuer_window(self):
        release=source('cortexAirPilotFeatureRelease')
        start=release.split('if (_releaseUntil == -1) then {',1)[1].split('if (_attempt == 0',1)[0]
        self.assertNotIn('_issuer == clientOwner',start)
        self.assertIn('CBE_AirPilotFeatureAdoption",+_receipt',start)
        self.assertIn('_actor setVariable ["CBE_AirPilotFeatureReceipt",_receipt,true]',start)
        self.assertLess(release.index('isNotEqualTo _receipt'),release.index('_receipt set [7,_releaseUntil]'))
        self.assertIn('_releaseUntil != -1 && {_releaseUntil < 0}',release)
        self.assertIn('!finite _releaseUntil',release)

    def test_air_feature_adoption_uses_actual_actor_locality_without_flight_replay(self):
        adopt=source('cortexAirPilotFeatureAdopt')
        self.assertIn('!_gained || {!local _actor}',adopt)
        self.assertIn('CBE_AirPilotFeatureLocalEpoch',adopt)
        self.assertIn('CBE_AirPilotFeatureAdoption",nil',adopt)
        self.assertIn('(_receipt select 1) isNotEqualTo _actor',adopt)
        self.assertIn('CBE_AirPilotFeatureAdoption",+_receipt',adopt)
        self.assertNotIn('set [5,',adopt)
        self.assertNotIn('doMove',adopt)
        release=source('cortexAirPilotFeatureRelease')
        self.assertIn('_issuer isNotEqualTo clientOwner && {(_actor getVariable ["CBE_AirPilotFeatureAdoption",[]]) isNotEqualTo _receipt}',release)
        init=(ROOT/'addons/main/XEH_postInit.sqf').read_text(encoding='utf-8')
        hook=init.split('["CAManBase","init",{',1)[1].split('call CBA_fnc_addClassEventHandler',1)[0]
        self.assertIn('addEventHandler ["Local"',hook)
        self.assertIn('isNil {_actor getVariable "CBE_AirPilotFeatureLocalEH"}',hook)
        self.assertIn('},true,[],true]',hook)

    def test_air_fsm_terminal_path_releases_original_receipt_without_replaying_executor(self):
        fsm=(ROOT/'addons/main/fsm/airAttackOperation.fsm').read_text(encoding='utf-8').replace('""','"')
        finished=fsm.split('class Finished {',1)[1]
        self.assertIn('_releaseJob=_brain getOrDefault ["job",createHashMap]',finished)
        self.assertIn('_releaseJob getOrDefault ["lateralPilotReceipt",[]]',finished)
        self.assertLess(finished.index('call CBE_fnc_FlightLeaseRelease'),finished.index('call CBE_fnc_CortexAirPilotFeatureRelease'))
        self.assertLess(finished.index('call CBE_fnc_CortexAirPilotFeatureRelease'),finished.index('setVariable ["CBE_AirAttack_Brain",nil]'))
        self.assertNotIn('call CBE_fnc_CortexAirAttack;',finished)

    def test_air_pilot_feature_release_is_exact_owner_finite_and_task_safe(self):
        helper=source('cortexAirPilotFeatureRelease')
        for guard in ['!local _actor','count _receipt != 8','_issuer isNotEqualTo clientOwner',
                      '_attempt >= 60','_attempt+1','count _lease == 0','CortexActorFireTaskAvailable',
                      'CortexExternalTakeover','CortexExternalOwner','CompatibilityExternalControl',
                      'CBE_AirPilotFeatureReleaseStarted','UNRESOLVED','isNotEqualTo _receipt']:
            self.assertIn(guard,helper)
        self.assertIn('call CBA_fnc_waitAndExecute',helper)
        self.assertIn('_epoch != _liveEpoch',helper)
        self.assertIn('[_actor,+_receipt,_attempt+1,_epoch]',helper)
        self.assertNotIn('CortexQueueJob',helper)
        self.assertNotIn('allUnits',helper)
        self.assertNotIn('doMove',helper)
        self.assertLess(helper.index('_actor enableAI'),helper.index('_actor setVariable ["CBE_AirPilotFeatureReceipt",nil,true]'))
        self.assertIn('call CBE_fnc_CortexAirPilotFeatureRelease',source('cortexAirAttack'))

    def test_air_pilot_feature_receipt_is_durable_before_mutation_and_not_overwritten(self):
        job=source('cortexAirAttack')
        admission=job.split('private _startFailure="";',1)[1].split('private _waypointIndex=',1)[0]
        self.assertIn('PILOT_FEATURE_HANDOVER_PENDING',admission)
        self.assertIn('_pilot getVariable ["CBE_AirPilotFeatureReceipt",[]]',admission)
        mutation=job.split('private _lateralPilotFeatures=',1)[1].split('_pilot doTarget objNull',1)[0]
        self.assertIn('[2,_pilot,_aircraft,_group,_flightLeaseToken,clientOwner,+_lateralPilotFeatures,-1]',mutation)
        self.assertLess(mutation.index('_pilot setVariable ["CBE_AirPilotFeatureReceipt",_receipt,true]'),mutation.index('_pilot disableAI'))
        cleanup=job.split('private _finishPilot=',1)[1].split('// Direct Zeus input',1)[0]
        self.assertIn('isEqualTo (_job get "lateralPilotReceipt")',cleanup)
        self.assertLess(cleanup.index('_finishPilot enableAI'),cleanup.index('_finishPilot setVariable ["CBE_AirPilotFeatureReceipt",nil,true]'))

    def test_air_lateral_feature_cleanup_retains_exact_changed_pilot(self):
        job=source('cortexAirAttack')
        mutation=job.split('_job set ["lateralPilotFeatures",_lateralPilotFeatures];',1)[1].split('_pilot doTarget objNull',1)[0]
        self.assertLess(mutation.index('_job set ["lateralPilot",_pilot]'),mutation.index('_pilot disableAI'))
        cleanup=job.split('private _finishPilot=',1)[1].split('// Direct Zeus input',1)[0]
        self.assertIn('_job getOrDefault ["lateralPilot",objNull]',cleanup)
        self.assertNotIn('driver _aircraft',cleanup)
        self.assertIn('group _finishPilot == _finishGroup',cleanup)
        self.assertIn('vehicle _finishPilot == _aircraft',cleanup)
        self.assertIn('CortexActorFireTaskAvailable',cleanup)

    def test_air_pilot_task_authority_precedes_admission_flight_and_feature_cleanup(self):
        job=source('cortexAirAttack')
        admission=job.split('private _allowed=',1)[1].split('if (!_allowed)',1)[0]
        self.assertIn('local _pilot',admission)
        self.assertIn('[_pilot] call CBE_fnc_CortexActorFireTaskAvailable',admission)
        boundary=job.split('private _mayControlAircraft = {',1)[1].split('private _liveSpeedReceipt=',1)[0]
        self.assertIn('local _livePilot',boundary)
        self.assertIn('(_speedReceipt select 0) == _livePilot',boundary)
        self.assertIn('getForcedSpeed _aircraft',boundary)
        self.assertIn('[_livePilot] call CBE_fnc_CortexActorFireTaskAvailable',boundary)
        cleanup=job.split('private _finishPilot=_job getOrDefault ["lateralPilot",objNull];',1)[1].split('_finishPilot enableAI',1)[0]
        self.assertIn('[_finishPilot] call CBE_fnc_CortexActorFireTaskAvailable',cleanup)

    def test_air_target_cleanup_only_retires_recorded_actor_assignment(self):
        job=source('cortexAirAttack')
        cleanup=job.split('private _assignment=_job getOrDefault ["targetAssignment"',1)[1].split('} forEach crew _aircraft',1)[0]
        self.assertIn('_x == _ownedOperator',cleanup)
        self.assertIn('assignedTarget _x isEqualTo _ownedTarget',cleanup)
        self.assertNotIn('getOrDefault ["fireTarget"',cleanup)
        assignment=job.split('if (!_pilotSurfaceStation) then {',1)[1].split('};',1)[0]
        self.assertLess(assignment.index('_operator doTarget _fireTarget'),assignment.index('_job set ["targetAssignment",[_operator,_fireTarget]]'))

    def test_air_attack_operator_replacement_cannot_inherit_release_state(self):
        job=source('cortexAirAttack')
        self.assertIn('_job set ["selectedOperator",if (_plannedStation',job)
        self.assertIn('_currentOperator != (_job getOrDefault ["selectedOperator",objNull])',job)
        cancel=job.index('["WEAPON_OPERATOR_CHANGED"] call _finish')
        self.assertLess(cancel,job.index('_aircraft selectWeaponTurret'))
        self.assertLess(cancel,job.index('_operator doFire _fireTarget'))
        fired=job.split('private _ownsRelease=',1)[1].split('if (_selectedRelease',1)[0]
        self.assertIn('_operator == (_liveJob getOrDefault ["selectedOperator",objNull])',fired)
        changed=job.split('// Retained selection, targeting',1)[1].split('WEAPON_OPERATOR_UNAVAILABLE',1)[0]
        self.assertNotIn('fireRequestAttempts",0',changed)

    def test_air_weapon_operator_authority_covers_planning_mutations_and_shot_credit(self):
        helper=source('cortexAirWeaponOperatorAvailable')
        for guard in ['!local _aircraft','!local _group','!local _operator',
                      'vehicle _operator == _aircraft','group _operator == _group',
                      'CortexCombatEffective','CortexActorFireTaskAvailable','remoteControlled',
                      'bis_fnc_moduleRemoteControl_owner','CortexExternalTakeover','unitCombatMode']:
            self.assertIn(guard,helper)
        plan=source('cortexAirAttackPlan')
        self.assertLess(plan.index('call CBE_fnc_CortexAirWeaponOperatorAvailable'),plan.index('weaponState [_aircraft'))
        job=source('cortexAirAttack')
        self.assertIn('WEAPON_OPERATOR_UNAVAILABLE',job)
        for branch in ['if (_weapon != ""','if (_validSolution && {_pilotSurfaceRelease}',
                       'if (_validSolution && {!_pilotSurfaceRelease}']:
            block=job.split(branch,1)[1].split('then {',1)[0]
            self.assertIn('CortexAirWeaponOperatorAvailable',block)
        self.assertIn('_operator == _expectedOperator',job)
        self.assertIn('[_aircraft,_fireGroup,_operator] call CBE_fnc_CortexAirWeaponOperatorAvailable',job)
        cleanup=job.split('if (_ownsFlight && {!_cleanupExternal}',1)[1].split('} forEach crew _aircraft',1)[0]
        self.assertIn('CortexActorFireTaskAvailable',cleanup)

    def test_air_plan_candidates_and_lateral_station_share_actual_loaded_state(self):
        plan=source('cortexAirAttackPlan')
        candidates=plan.split('private _loadedMagazines=[];',1)[1].split('private _aaPositions=',1)[0]
        self.assertNotIn('magazinesAllTurrets',candidates)
        self.assertNotIn('compatibleMagazines',candidates)
        for guard in ['_nativeQueries >= 64','_stationWeapons select [0,16]',
                      'allTurrets [_aircraft,true]) select [0,16]',
                      '(_native select 0) == _weapon','finite (_native select 4)',
                      '(_native select 4) > 0','(_x select 3) == _weapon']:
            self.assertIn(guard,candidates)
        self.assertIn('_loadedMagazines append _stationMagazines',candidates)
        self.assertIn('(_loadedMagazines select _loaded) select 0',candidates)

    def test_air_release_requires_exact_native_loaded_weapon_not_reserve_inventory(self):
        controller=source('cortexAirAttack')
        release=controller.split('private _stationState=weaponState',1)[1].split('private _envelope=',1)[0]
        for proof in ['[_aircraft,_turret,_weapon]','count _stationState >= 5',
                      '(_stationState select 0) == _weapon','(_stationState select 3) == _selectedMagazine',
                      'finite (_stationState select 4)','(_stationState select 4) > 0']:
            self.assertIn(proof,release)
        self.assertNotIn('magazinesAllTurrets',release)
        self.assertIn('private _validSolution=_loaded',controller)
        self.assertNotIn('setVehicleAmmo',release)

    def test_station_selection_reuse_requires_complete_same_frame_scan_and_fresh_fire_check(self):
        ready=source('cortexGroundFireReady')
        selector=source('cortexGroundSelectMuzzle')
        for proof in ('weaponState [_asset,_turret,_weapon,_muzzle]',
                      '(_loaded select 3) != _magazine','finite (_loaded select 4)',
                      '(_loaded select 4) <= 0','(_selected param [3,"",[""]]) == _magazine',
                      'finite _rounds && {_rounds > 0}'):
            self.assertIn(proof,selector)
        self.assertLess(selector.index('(_loaded select 3) != _magazine'),selector.index('selectWeaponTurret'))
        self.assertIn('_loadedPhase != 0',selector)
        self.assertIn('finite _phase && {_phase == 0}',selector)
        self.assertLess(selector.index('_loadedPhase != 0'),selector.index('selectWeaponTurret'))
        for proof in ('_asset turretLocal _turret','fullCrew [_asset','weaponState [_asset,_turret]',
                      '_asset selectWeaponTurret [_weapon,_turret,_muzzle]',
                      '(_selected param [0,""]) == _weapon','(_selected param [1,""]) == _muzzle'):
            self.assertIn(proof,selector)
        self.assertNotIn('doFire',selector)
        self.assertNotIn('forceWeaponFire',selector)
        for guard in ['(_cached select 0) == _asset','(_cached select 1) == _gunner',
                      '(_cached select 2) == clientOwner','(_cached select 3) == diag_frameNo',
                      '(_cached select 4) isEqualTo _station','count (_cached select 5) <= 32',
                      '_selectionPass && {!_ready} && {diag_frameNo == _frame}']:
            self.assertIn(guard,ready)
        self.assertIn('if (_selectionPass) then {_rows pushBack',ready)
        vehicles=source('cortexVehicles')
        fire=vehicles.split('private _target=objNull;',1)[1].split('private _standoff',1)[0]
        self.assertIn('private _stationSelection=createHashMap',vehicles)
        self.assertLess(vehicles.index('private _stationSelection=createHashMap'),vehicles.index('private _target=objNull;'))
        self.assertIn('[_vehicle,_gunner,_target,_fireObservation,false,_suppressionPoint isNotEqualTo []] call CBE_fnc_CortexGroundFireReady',fire)
        self.assertIn('call CBE_fnc_CortexGroundSelectMuzzle',fire)
        self.assertLess(fire.index('call CBE_fnc_CortexGroundSelectMuzzle'),fire.index('_gunner doFire'))
        combined=source('cortexCombinedGroundStep')
        self.assertLess(combined.index('call CBE_fnc_CortexGroundSelectMuzzle'),combined.index('_gunner doFire _target'))
        self.assertIn('if (_fireDecision == "MUZZLE_SELECTION_PENDING") exitWith {1}',combined)
        self.assertNotIn('forceWeaponFire',combined)
        for output in ('loadedWeapon','loadedMuzzle','loadedMagazine','loadedTurret'):
            self.assertIn(f'_observation set ["{output}"',ready)
        self.assertLess(fire.index('private _freshStationReady='),fire.index('_gunner doTarget'))
        self.assertIn('private _freshLaneSafe=_freshStationReady && {',fire)
        self.assertIn('if (_freshLaneSafe && {[] call _mayIssueVehicle}) then {',fire)

    def test_ground_reload_admission_reuses_tick_and_preserves_route_and_report_age(self):
        local=source('cortexCombinedArmsLocal')
        wait=local.split('private _waitForReload={',1)[1].split('if (_role in',1)[0]
        self.assertIn('WAITING_FOR_RELOAD',wait)
        self.assertIn('MUZZLE_SELECTION_PENDING',wait)
        immediate=local.split('if (_role == "GROUND_FIRE") exitWith {',1)[1].split('if (_role == "GROUND_MANOEUVRE")',1)[0]
        self.assertIn('[_gunner,"MUZZLE_SELECTION_PENDING"] call _waitForReload',immediate)
        self.assertLess(immediate.index('call CBE_fnc_CortexGroundSelectMuzzle'),immediate.index('_gunner doFire _target'))
        self.assertLess(immediate.index('_gunner doFire _target'),immediate.index('call _markApplied'))

        self.assertNotIn('call _markApplied',wait)
        self.assertNotIn('CortexQueueJob',wait)
        self.assertNotIn('waitAndExecute',wait)
        self.assertIn('(_reloadReceipt select 3) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',local)
        self.assertIn('(_reloadReceipt select 2) != gunner _asset',local)
        self.assertIn('CBE_Cortex_CombinedReportLocal',local)
        self.assertEqual(local.count('_group reveal [_target'),1)
        for name in ['cortexCombinedArmsServer','cortexCombinedGroundFallbackServer']:
            self.assertIn('"WAITING_FOR_RELOAD"',source(name))
            self.assertIn('"MUZZLE_SELECTION_PENDING"',source(name))
        self.assertIn('[_group,_combinedRole] call CBE_fnc_CortexCombinedArmsLocal',source('cortexGroupTick'))

    def test_combined_ground_reload_wait_keeps_original_deadline_and_never_grants_fire(self):
        ready=source('cortexGroundFireReady')
        self.assertIn('_observation set ["reloadInProgress",false]',ready)
        usable=ready.split('private _usable=',1)[1].split('private _score=',1)[0]
        for guard in ['count _state >= 7','finite _reload','_reload == 0']:
            self.assertIn(guard,usable)
        self.assertIn('if (_bestScore < 0 && {_reloading})',ready)
        self.assertIn('_observation set ["reloadInProgress",_reloading]',ready)
        reload=ready.split('private _reload=',1)[1].split('private _usable=',1)[0]
        for guard in ['_suitable','finite _reload','_reload > 0','_reload <= 1']:
            self.assertIn(guard,reload)
        step=source('cortexCombinedGroundStep')
        self.assertEqual(step.count('&& {_ammoObservation getOrDefault ["reloadInProgress",false]}) exitWith {1}'),2)
        self.assertLess(step.index('serverTime >= (_job getOrDefault ["expiry"'),step.index('private _ammoObservation='))
        for actor in ['_stationOperator','_gunner']:
            self.assertIn(f'private _targetReady=[_asset,{actor},_target,_ammoObservation] call CBE_fnc_CortexGroundFireReady',step)
        self.assertNotIn('objNull,_ammoObservation',step)
        self.assertNotIn('_job set ["expiry"',step)
        self.assertNotIn('_job set ["deadline"',step)
        arrival=step.split('if (_arrivalDistance <= 70) exitWith {',1)[1]
        self.assertLess(arrival.index('reloadInProgress'),arrival.index('_gunner doFire'))

    def test_ground_fire_readiness_uses_loaded_station_muzzle_not_inventory(self):
        text=source('cortexGroundFireReady')
        self.assertNotIn('magazinesAllTurrets',text)
        self.assertNotIn('compatibleMagazines',text)
        for proof in ['weaponState [_asset,_station,_weapon,_muzzle]',
                      '(_state select 0) == _weapon','(_state select 1) == _muzzle',
                      '_magazine != ""','finite _rounds','_rounds > 0',
                      '_weapons select [0,16]','_muzzles select [0,8]','_queries >= 32']:
            self.assertIn(proof,text)
        self.assertIn('[_ammo] call _targetSuitable',text)
        policy=text.split('private _targetSuitable={',1)[1].split('private _bestScore=',1)[0]
        self.assertIn('_targetFlag != 256 && {_airLock == 2}',policy)
        self.assertLess(policy.index('_airLock == 2'),policy.index('private _flags='))
        self.assertNotIn('getNumber (_ammo >> "airLock") <= 0',policy)

        for proof in ('_bulletSuppression','"shotbullet"','_rounds >= 20',
                      'getNumber (_ammo >> "indirectHit") <= 0','getNumber (_ammo >> "explosive") <= 0'):
            self.assertIn(proof,text)

        for proof in ('_bestScore=-1','warheadName','["AP","TANDEMHEAT"]','case 128:',
                      '_score > _bestScore','_preferredFound || {_bestScore >= 0}',
                      '_preferred || {_bestScore >= 0}','_observation set ["reloadInProgress",_reloading]'):
            self.assertIn(proof,text)
        self.assertLess(text.index('_score > _bestScore'),text.index('set ["loadedWeapon"'))
        self.assertNotIn('selectWeapon',text)
        self.assertNotIn('loadMagazine',text)

    def test_ground_reserve_load_is_finite_native_request_not_delayed_fire(self):
        text=source('cortexGroundReload')
        for proof in ('magazinesAllTurrets [_asset,true]','count _inventory > 128',
                      '(_x select 1) isEqualTo _turret','(_x select 2) > 0',
                      'count _muzzles <= 8','_queries >= 32','_asset turretLocal _turret','_asset turretUnit _turret',
                      'CortexActorFireTaskAvailable','CBE_Cortex_CombinedRole','NativeOrderReceipt',
                      'CBE_GroundReloadAfter','serverTime+15','serverTime >= _until',
                      '(_native select 3) == _magazine','(_native select 4) > 0',
                      'isEqualTo _before','_rank > _bestRank','CortexIsEligible',
                      '_asset loadMagazine [_turret,_weapon,_magazine]'):
            self.assertIn(proof,text)
        issue=text.split('private _result="REFUSED";',1)[1]
        self.assertIn('isNil {',issue)
        self.assertLess(issue.index('call _available'),issue.index('loadMagazine'))
        self.assertLess(issue.index('CBE_GroundReloadPending'),issue.index('loadMagazine'))
        acknowledgement=text.split('private _native=weaponState',1)[1].split('// A different native magazine',1)[0]
        self.assertIn('finite _reloadPhase',acknowledgement)
        self.assertIn('_reloadPhase == 0',acknowledgement)
        proposal=text.split('private _state=weaponState [_asset,_turret,_weapon,_muzzle];',1)[1].split('forEach (_magazines arrayIntersect',1)[0]
        for proof in ('_state param [6,-1,[0]]','count _state >= 7',
                      'finite _reloadPhase','_reloadPhase == 0'):
            self.assertIn(proof,proposal)
        self.assertNotIn('_state param [6,0]',proposal)
        self.assertNotIn('setWeaponReloadingTime',text)
        self.assertIn('_magazines arrayIntersect _compatible',text)
        self.assertIn('getNumber (_ammo >> "airLock") != 2',text)
        self.assertIn('getNumber (_ammo >> "laserLock") <= 0',text)

        self.assertIn('(_x select 0) != _muzzle && {_magazine in (_x select 1)}',text)
        self.assertIn('count _compatible > 128',text)
        self.assertLess(text.index('_configurationValid=true'),text.index('private _state=weaponState'))
        self.assertIn('_weaponConfig >> _muzzle >> "magazineReloadTime"',text)
        for forbidden in (' doFire ', ' doTarget ', 'waitAndExecute','setVehicleAmmo','setAmmo ', 'doMove'):
            self.assertNotIn(forbidden,text)
        role=text.split('private _roleCurrent={',1)[1].split('private _available={',1)[0]
        for proof in ('_liveRole isEqualTo _opportunity','GROUND_MANOEUVRE','serverTime < (_opportunity select 5)',
                      'isEqualTo _observedAt'):
            self.assertIn(proof,role)
        self.assertIn('_oldOpportunity isNotEqualTo _opportunity',text)
        self.assertIn('_until min (_opportunity select 5)',text)
        combined=source('cortexCombinedArmsLocal')
        self.assertEqual(combined.count('call CBE_fnc_CortexGroundReload'),2)
        self.assertIn('_contactReceipt param [1,-1,[0]],_opportunity',combined)
        step=source('cortexCombinedGroundStep')
        self.assertIn('_report param [1,-1,[0]],_snapshot',step)
        self.assertLess(step.index('call CBE_fnc_CortexGroundReload'),step.index('private _capabilityFailure='))
        caller=source('cortexVehicles')
        self.assertIn('!(_reloadStatus in ["REQUESTED","PENDING"])',caller)
        self.assertLess(caller.index('call CBE_fnc_CortexGroundReload'),caller.index('private _fireObservation=createHashMap;'))

    def test_direct_door_calls_cannot_borrow_reserved_or_service_actors(self):
        text=source('cortexBuildingDoor')
        direct=text.split('if (_context isEqualTo []) exitWith {',1)[1].split('};',1)[0]
        self.assertIn('!([_unit] call CBE_fnc_CortexActorMoveReserved)',direct)
        self.assertIn('currentCommand _unit in ["","MOVE"]',direct)
        self.assertNotIn('_combatCommand',direct)
        self.assertGreaterEqual(text.count('call _orderCurrent'),2)
        indoor=text.split('if ((_context select 0) == "INDOOR") exitWith {',1)[1].split('private _key=switch',1)[0]
        self.assertIn('currentCommand _unit in ["","MOVE"] || {_combatCommand}',indoor)
        self.assertIn('CBE_Cortex_ActorMove',indoor)

    def test_cqb_replacement_invalidates_only_lane_entry_proposal(self):
        step=source('buildingOperationStep')
        replacement=step.split('if (_laneRosterChanged) then {',1)[1].split('private _enteredActors=',1)[0]
        self.assertIn('_entryTargets deleteAt (str _pairIndex)',replacement)
        self.assertIn('_job set ["pairEntryTargets",_entryTargets]',replacement)
        for protected in ['"cleared"','"hardDeadline"','"failedBy"','"recoveryBudget"']:
            self.assertNotIn(f'set [{protected}',replacement)
        self.assertNotIn('doMove',replacement)
        self.assertNotIn('doStop',replacement)

    def test_parachute_exit_requires_real_airframe_and_rechecks_before_mutation(self):
        jump=source('cortexParachuteJump')
        for guard in ('isNull _aircraft','_unit == _aircraft','_aircraft isKindOf "Air"',
                      '_aircraft isKindOf "ParachuteBase"'):
            self.assertLess(jump.index(guard),jump.index('private _chuteClass'))
        gate=jump.split('private _mayExit={',1)[1].split('private _chuteClass',1)[0]
        for guard in ('vehicle _unit == _aircraft','local _unit','simulationEnabled _unit',
                      '!isObjectHidden _unit','simulationEnabled _aircraft','!isObjectHidden _aircraft',
                      'CortexActorMoveReserved','remoteControlled','CortexExternalOwner',
                      'CompatibilityExternalControl'):
            self.assertIn(guard,gate)
        mutation=jump.split('private _exited=false;',1)[1].split('if (!_exited)',1)[0]
        self.assertIn('isNil {',mutation)
        self.assertLess(mutation.index('call _mayExit'),mutation.index('isDamageAllowed _unit'))
        self.assertLess(mutation.index('call _mayExit'),mutation.index('_unit allowDamage false'))
        self.assertLess(jump.index('if (!_exited) exitWith {false}'),jump.index('[_unit] call CBE_fnc_CortexParachuteDeploy'))

    def test_parachute_failed_boarding_cleans_only_empty_owned_chute(self):
        jump=source('cortexParachuteJump')
        boarding=source('cortexParachuteDeploy').split('_unit moveInDriver _chute;',1)[1]
        self.assertLess(boarding.index('if (vehicle _unit == _chute)'),boarding.index('_chute setVelocity'))
        cleanup=boarding.split('} else {',1)[1].split('deleteVehicle _chute',1)[0]
        for guard in ['!isNull _chute','local _chute','crew _chute isEqualTo []']:
            self.assertIn(guard,cleanup)
        self.assertIn('_due-serverTime',source('cortexParachuteDeploy'))
        self.assertNotIn('remoteExecCall ["allowDamage"',jump)

    def test_combat_gunner_replacement_preserves_actor_controller_ownership(self):
        text=source('cortexVehicleCrewRecover')
        ownership=text.split('if ([_candidate] call CBE_fnc_CortexActorMoveReserved',1)[1].split('private _command=',1)[0]
        for guard in ['remoteControlled _candidate','bis_fnc_moduleRemoteControl_owner',
                      'CBE_fnc_CortexExternalOwner','CBE_fnc_CompatibilityExternalControl','ACTOR_OWNERSHIP']:
            self.assertIn(guard,ownership)
        self.assertLess(text.index('ACTOR_OWNERSHIP'),text.index('_candidate assignAsGunner'))
        self.assertLess(text.index('ACTOR_OWNERSHIP'),text.index('_candidate action'))
        self.assertNotIn('setVariable ["CBE_Cortex_ActorMove",nil]',text)
        for guard in ['_command == "STOP"','simulationEnabled _candidate','checkAIFeature "MOVE"',
                      'checkAIFeature "PATH"','fullCrew [_vehicle,"gunner",true]',
                      '_gunnerSeat param [5,objNull]','alive _assignedGunner','GUNNER_ASSIGNED']:
            self.assertIn(guard,text)
        self.assertLess(text.index('GUNNER_ASSIGNED'),text.index('_candidate assignAsGunner'))
        for guard in ('fullCrew [_vehicle,"commander",false]','assignedVehicleRole _candidate',
                      'assignedVehicle _candidate != _vehicle','(_commanderSeat select 5) != _candidate',
                      '(_assignment select 1) isNotEqualTo (_commanderSeat select 3)',
                      'COMMANDER_ASSIGNMENT_CHANGED'):
            self.assertIn(guard,text)
        self.assertLess(text.index('COMMANDER_ASSIGNMENT_CHANGED'),text.index('_candidate assignAsGunner'))
        self.assertLess(text.index('COMMANDER_ASSIGNMENT_CHANGED'),text.index('_candidate action'))
        def seat_intent(same_vehicle,assignment,actual_path,assigned_self):
            return same_vehicle and assigned_self and assignment==['turret',actual_path]
        self.assertTrue(seat_intent(True,['turret',[2,1]],[2,1],True))
        self.assertFalse(seat_intent(False,[],[2,1],True))
        self.assertFalse(seat_intent(True,['driver'],[2,1],True))
        self.assertFalse(seat_intent(True,['cargo'],[2,1],True))
        self.assertFalse(seat_intent(True,['turret',[0]],[2,1],True))
        self.assertFalse(seat_intent(True,['turret',[2,1]],[2,1],False))


    def test_mounted_danger_recovers_a_lost_gunner_without_sacrificing_the_driver(self):
        registry=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        recovery=source('cortexVehicleCrewRecover')
        vehicles=source('cortexVehicles')
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        self.assertIn('class CortexVehicleCrewRecover',registry)
        for marker in ['!(_cause in ["DETECTED","HIT","EXPLOSION","SUPPRESSED","GUNFIRE"])','abs speed _vehicle >= 20','CBE_Convoy_Active',
                       'CBE_AIPass_VehicleGunnery_Enable','CortexExternalTakeover','CortexZeusHeld']:
            self.assertIn(marker,recovery)
        self.assertNotIn('!canMove _vehicle',recovery)
        self.assertLess(recovery.index('ace_medical_ai_healQueue'),recovery.index('_candidate assignAsGunner'))
        invocation=vehicles.split('if (_freshCrewRecovery',1)[1].split('private _freshGeneration=',1)[0]
        self.assertIn('_dangerHostile',invocation)
        self.assertIn('!(_emplacementUnsafe || {_disabledUnsafe})',invocation)
        self.assertIn('_candidate=commander _vehicle',recovery)
        self.assertIn('_candidate == driver _vehicle',recovery)
        self.assertIn('_candidate assignAsGunner _vehicle',recovery)
        self.assertIn('_candidate action ["MoveToGunner",_vehicle]',recovery)
        for forbidden in ['moveInGunner','createUnit','commandMove','doMove','forceSpeed','setVelocity']:
            self.assertNotIn(forbidden,recovery)
        self.assertIn('vehicleDangerCrewRecovery',vehicles)
        self.assertIn('DANGER-VEHICLE-gunner-loss-recovered',audit)
        self.assertIn('DANGER-VEHICLE-driver-role-preserved',audit)
        acknowledgement=audit.split('private _gunnerRecovered=[{',1)[1].split('},30] call _wait;',1)[0]
        self.assertIn('_issuedRecovery isNotEqualTo _recoveryIssuedBefore',acknowledgement)
        self.assertIn('>= _recoveryStartedAt',acknowledgement)
        self.assertIn('gunner _contactVehicle == _recoveryCommander',acknowledgement)
        self.assertIn('alive _recoveryCommander',acknowledgement)
        self.assertNotIn('vehicleDangerCrewRecovery',acknowledgement)


    def test_armoured_danger_countermeasure_is_generation_owned_and_route_neutral(self):
        text=source('cortexVehicles')
        danger=text.split('// Defensive smoke is independent',1)[1].split('// A useful static mortar',1)[0]
        for marker in ['vehicleDangerCountermeasure','_dangerGeneration','["ARMED","ARMOURED"]',
                       '["HIT","EXPLOSION","SUPPRESSED"]','combatMode _group in ["YELLOW","RED"]',
                       'CBE_Convoy_Active','CBE_fnc_CortexFireCountermeasure',
                       'CBE_Danger_VehicleCountermeasure']:
            self.assertIn(marker,danger)
        self.assertLess(danger.index('_state set ["vehicleDangerCountermeasure"'),
                        danger.index('CBE_Danger_VehicleCountermeasure'))
        for forbidden in ['CortexGroupMove','addWaypoint','forceSpeed','setVelocity','doMove','commandMove']:
            self.assertNotIn(forbidden,danger)

    def test_danger_mortar_uses_the_finite_artillery_owner_and_live_gates(self):
        vehicles=source('cortexVehicles')
        fire=source('cortexArtilleryFire')
        step=source('cortexArtilleryMissionStep')
        shot=source('cortexArtilleryShot')
        danger=vehicles.split('// A useful static mortar',1)[1].split('// An intact armed platform',1)[0]
        for marker in ['_dangerProfile == "ARTILLERY"','_vehicle isKindOf "StaticMortar"',
                       '"DANGER",objNull,_dangerSource','CBE_fnc_CortexArtilleryFire']:
            self.assertIn(marker,danger)
        for forbidden in ['doArtilleryFire','commandArtilleryFire','createVehicle']:
            self.assertNotIn(forbidden,danger)
        for text in [fire,step,shot]:
            self.assertIn('CBE_AIPass_Danger_Enable',text)
            self.assertIn('CBE_AIPass_Vehicles_Enable',text)
            self.assertIn('CBE_AIPass_VehicleGunnery_Enable',text)
            self.assertIn('CortexExternalTakeover',text)
        self.assertIn('["SUPPORT", "COUNTER", "DANGER"]',fire)
        self.assertIn('_battery isKindOf "StaticMortar"',fire)
        self.assertIn('_commander knowsAbout _enemy <= 0',fire)
        self.assertNotIn('getPosATL _enemy',fire)
        self.assertIn('+_dangerBelief,25',danger)
        self.assertIn('_dangerSource,grpNull,serverTime',danger)
        self.assertIn('serverTime >= _observedAt+10',fire)
        self.assertIn('["dangerUntil",if (_danger) then {_observedAt+10} else {-1}]',fire)
        self.assertIn('serverTime >= (_mission getOrDefault ["dangerUntil",-1])',step)
        self.assertIn('_mission getOrDefault ["dangerUntil",-1]] remoteExecCall',step)
        self.assertIn('finite _dangerUntil && {serverTime < _dangerUntil}',shot)
        self.assertIn('_smokeGeneration,_dangerUntil];',shot)
        self.assertIn('["burstsLeft", if (_mode == "SMOKE" || {_danger}) then {1}',fire)
        self.assertIn('["opening", !_danger]',fire)
        self.assertIn('CBE_AIPass_NextDangerFire',fire+step)
        self.assertIn('if ((_mission get "phase") == "READY" && {(_mission get "mode") == "HE"}) exitWith',step)
        self.assertIn('_battery doArtilleryFire [_aim, _magazine, 1]',shot)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        for case in ['DANGER-MORTAR-real-hostile-fire','DANGER-MORTAR-natural-knowledge',
                     'DANGER-MORTAR-finite-owner','DANGER-MORTAR-lethal-warning',
                     'DANGER-MORTAR-one-real-round','DANGER-MORTAR-finite-release',
                     'DANGER-MORTAR-crew-retained','DANGER-MORTAR-support-remained-disabled']:
            self.assertIn(case,audit)
        mortar=audit.split('// A useful static mortar',1)[1].split('// Real enemy artillery events',1)[0]
        self.assertIn('_dangerEnemy doFire _gun',mortar)
        self.assertIn('DANGER-MORTAR-contact-fixture',mortar)
        self.assertIn('inRangeOfArtillery [[_gun],_dangerHE]',mortar)
        self.assertNotIn(' reveal ',mortar)
        self.assertNotIn('call CBE_fnc_CortexArtilleryFire',mortar)

    def test_stationary_passenger_comparison_is_explicit_and_additive(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text()
        self.assertIn('if (_stationary) then {(driver _truck) disableAI "PATH"}',text)
        self.assertIn('DISMOUNT-crew-report-physical-exit',text)
        self.assertIn('_driverDetected && {_enabledStartedMounted} && {_dismounted} && {_ownedExit}',text)
        self.assertNotIn('_crewSees && {!_separate || {_passengersSee}}',text)
        self.assertIn('_crewSees},30] call _wait;',text)
        self.assertIn('CBE_CortexQA_PhysicalExit',text)
        self.assertIn('[_vehicle,abs speed _vehicle,_issued,serverTime]',text)
        self.assertIn('(_x select 1) >= 1',text)
        passenger_setup=text[text.index('[["CBE_AIPass_Enable",!_nativeBaseline]'):text.index('private _truck=createVehicle',text.index('[["CBE_AIPass_Enable",!_nativeBaseline]'))]
        self.assertIn('["CBE_AIPass_VehicleRemount_Enable",true]',passenger_setup)
        self.assertIn('DISMOUNT-contact-physical-exit',text)
        self.assertIn('[false,true],[true,true],[false,true,false,true]',text)

    def test_contact_transition_audit_requires_physical_search_and_resumption(self):
        text=(Path(__file__).parent/'cortexQA/runContact.sqf').read_text()
        for case in ['DANGER-disabled-real-stimulus-inert','DANGER-live-gate-reenabled','DANGER-authored-hold-fire-preserved','DANGER-casualty-alert-no-contact','DANGER-release-mode-no-tactical-handoff','DANGER-active-zeus-replacement','DANGER-leader-loss-physical-continuation','DANGER-forced-order-no-tactical-handoff','DANGER-active-response-native-order-interrupt']:
            self.assertIn(case,text)
        self.assertIn('[_reflexGroup,true,_zeusWaypoint select 1] call CBE_fnc_CortexZeusMark',text)
        self.assertIn('private _spawnRealGrenade={',text)
        self.assertIn('addEventHandler ["FiredMan"',text)
        self.assertIn('forceWeaponFire ["HandGrenadeMuzzle","HandGrenadeMuzzle"]',text)
        self.assertIn('CBE CORTEX QA FIXTURE ERROR: native grenade firing produced no projectile',text)
        self.assertIn('private _sourceGroup=createGroup [east,true]',text)
        self.assertIn('_source hideObjectGlobal true',text)
        self.assertIn('_source setAmmo [_rifle,30]',text)
        self.assertIn('_spawn set [2,(_spawn param [2,0]) + 2]',text)
        self.assertIn('_grenade setVelocity [0,0,-4]',text)
        disabled=text.split('// The configured engine FSM remains installed',1)[1].split('// Prove the engine-loaded FSM',1)[0]
        self.assertIn('call _spawnRealGrenade',disabled)
        self.assertIn('["CBE_AIPass_Danger_Enable",false]',disabled)
        self.assertIn('["CBE_AIPass_Danger_Enable",true]',disabled)
        self.assertNotIn('call CBE_fnc_DangerEngineSubmit',disabled)
        casualty=text.split('// A real same-group death',1)[1].split('// Prove the engine-loaded FSM',1)[0]
        self.assertIn('[_casualtyActor] call _killWithRealProjectile',casualty)
        self.assertIn('private _bodyGroup=createGroup [east,true]',casualty)
        self.assertIn('[_bodyActor] call _killWithRealProjectile',casualty)
        self.assertIn('getOrDefault ["HIDE",0]',casualty)
        self.assertIn('== "CALM"',casualty)
        self.assertIn('combatMode _casualtyGroup == "BLUE"',casualty)
        released=text.split('// CARELESS is an authored mission state',1)[1].split('// Prove the engine-loaded FSM',1)[0]
        self.assertIn('_releaseGroup setBehaviourStrong "CARELESS"',released)
        self.assertIn('"acceptedRecords",0',released)
        self.assertIn('== _releaseAcceptedBefore',released)
        self.assertIn('behaviour _releaseUnit == "CARELESS"',released)
        forced=text.split('// A concrete native boarding task',1)[1].split('deleteGroup _forcedGroup;',1)[0]
        self.assertIn('"acceptedRecords",0',forced)
        self.assertIn('!= _forcedAcceptedBefore',forced)
        for case in ['CONTACT-natural-reacquisition','TRANS-contact-postcontact-sequence','TRANS-search-contact-interruption','TRANS-search-physical-approach','TRANS-regroup-physical-cohesion','TRANS-calm-new-orders-physical-arrival','TRANS-no-old-search-order-resurrection']:
            self.assertIn(case,text)
        self.assertIn('_searchTravel >= 15 && {_searchApproach}',text)
        self.assertIn('(_state getOrDefault ["searchTeam",[]]) isEqualTo []',text)
        self.assertIn('"SEARCH INTERRUPTION: NATURAL CONTACT"',text)
        self.assertIn('(_x param [1,""]) == "SEARCH"',text)
        self.assertIn('(_x param [2,""]) == "CONTACT"',text)
        self.assertNotIn('_state set ["phase"',text)
        self.assertIn('TRANS-published-phase-ledger',text)
        self.assertIn('CBE_Cortex_PhaseTransitions',text)
        self.assertIn('private _publishedSecurity=_publishedPhases find "SECURITY"',text)
        self.assertIn('private _findPublishedAfter={',text)
        self.assertIn('[_publishedPhases,"CALM",_publishedRegroup] call _findPublishedAfter',text)
        self.assertNotIn('_forEachIndex > _publishedRegroup',text)
        self.assertIn('count _phaseHistory <= 32',text)
        self.assertNotIn('call CBE_fnc_CortexRestoreCalm',text)

    def test_combat_start_failure_reports_independent_tactical_refusals(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('CBE_Cortex_FlankRefusal',text)
        self.assertIn('CBE_Cortex_AdvanceRefusal',text)
        self.assertIn('getOrDefault ["movementLease",[]]',text)
        self.assertIn('[_prefix+"-started",_started,str _startRefusal]',text)

    def test_combat_audit_proves_action_specific_contact_selection(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('"ASSAULT-MULTI-CONTACT"',text)
        self.assertIn('[_group] call CBE_fnc_CortexKnowledge',text)
        self.assertIn('_nearestDistance < 12 && {_viableIndex > 0}',text)
        self.assertIn('-viable-contact-selected',text)
        self.assertIn('(_drill getOrDefault ["target",objNull]) == (_enemies select 1)',text)
        self.assertNotIn('reveal [',text)

    def test_calm_cleanup_retires_onboard_contact_deadline(self):
        text=source('cortexRestoreCalm')
        cleanup=text[text.index('{_state deleteAt _x} forEach [',text.index('private _boarding')):]
        self.assertIn('"onboardContactUntil"',cleanup)

    def test_attack_flare_ammo_check_counts_only_actual_countermeasure_magazines(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        self.assertIn('_firedMagazines pushBackUnique (_x select 4)',text)
        self.assertIn('if ((_x select 0) in _firedMagazines)',text)
        self.assertIn('_magazinesBefore getOrDefault [_x,0]',text)

    def test_naval_assault_uses_existing_scheduler_and_finite_external_ownership(self):
        naval=source('cortexNavalAssault')
        release=source('cortexNavalRelease')
        tick=source('cortexGroupTick')
        vehicles=source('cortexVehicles')
        compat=(ROOT/'addons/compatibility/functions/aiTweaksDetectCompatibility.sqf').read_text(encoding='utf-8')
        self.assertIn('CBE_AIPass_NavalAssault_Enable',naval)
        self.assertIn('CBE_fnc_CortexExternalTakeover',naval)
        self.assertNotIn('navalBackend',compat)
        self.assertIn('CBE_Cortex_NavalOperation',naval)
        self.assertIn('CBE_Cortex_NavalOperation',source('cortexLocality'))
        for marker in ['surfaceIsWater _landing','surfaceIsWater _approach',
                       'surfaceNormal _shore','CortexOwnershipLease','NAVAL_ASSAULT',
                       'CBE_Cortex_NavalPlan','doGetOut _unit','NAVAL_LANDING']:
            self.assertIn(marker,naval)
        implementation=naval.split('*/',1)[1]
        for forbidden in ['allGroups','allUnits','while {','waitUntil','setPos','setVelocity','setDamage','setFuel','setDriveOnPath']:
            self.assertNotIn(forbidden,implementation)
        self.assertIn('call CBE_fnc_CortexNavalAssault',tick)
        self.assertIn('call CBE_fnc_CortexNavalRelease',source('cortexReleaseGroup'))
        self.assertIn('CBE_Cortex_NavalForcedSpeed',release)
        self.assertIn('CBE_Cortex_NavalOperation',release)
        self.assertIn('_vehicle isKindOf "LandVehicle"',vehicles)

    def test_support_acceptance_uses_a_surviving_anchor_but_keeps_radio_qualification(self):
        """A dead or pinned formal leader cannot reject a viable local support element."""
        apply=source('cortexSupportApply')
        self.assertIn('private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;',apply)
        self.assertIn('!isNull _anchor',apply)
        self.assertIn('behaviour _anchor != "CARELESS"',apply)
        self.assertIn('getSuppression _anchor',apply)
        self.assertIn('CBE_fnc_CortexGroupTransmitter',apply)

    def test_pending_coordination_acknowledges_without_idling_the_responder(self):
        apply=source('cortexSupportApply')
        pending=apply.split('if (_okay && {_directCoordinationPending}) exitWith {',1)[1].split('};',1)[0]
        self.assertIn('CBE_fnc_CortexSupportAck',pending)
        for forbidden in ['CBE_fnc_CortexOwnershipLease','CBE_fnc_OperationStart','movementLease','set ["responding"']:
            self.assertNotIn(forbidden,pending)
        self.assertLess(apply.index('if (_okay && {_directCoordinationPending}) exitWith {'),apply.index('call CBE_fnc_CortexOwnershipLease'))
        self.assertIn('private _replaceLocalDrill = _attackAllowed && {_sharedDrillContact} && {_movementOwner == "TACTICAL_DRILL"}',apply)
        self.assertIn('[_group,_state,"ROLE_HANDOVER"] call CBE_fnc_CortexFlankEnd',apply)
        self.assertLess(apply.index('call CBE_fnc_CortexFlankEnd'),apply.index('call CBE_fnc_CortexOwnershipLease'))
    def test_support_reservations_use_the_common_generation_lifecycle(self):
        apply=source('cortexSupportApply')
        maintain=source('cortexSupportMaintain')
        tick=source('cortexGroupTick')
        for marker in ['CBE_fnc_OperationStart','"SUPPORT_RALLY"','"COORDINATED_ASSAULT"',
                       'supportOperationGeneration','"ACCEPTED"']:
            self.assertIn(marker,apply)
        for marker in ['CBE_fnc_OperationStep','CBE_fnc_OperationCancel',
                       'supportOperationGeneration','"LEASE_EXPIRED"','"SERVER_RETIREMENT"',
                       '"FEATURE_DISABLED"','"ZEUS"','"EXTERNAL"']:
            self.assertIn(marker,maintain)
        self.assertIn('case "SUPPORT_RALLY": {"supportOperationGeneration"};',tick)
        self.assertNotIn('[_group] call CBE_fnc_CortexGroupMoveClear;',apply)
        self.assertIn('[_group,_operationGeneration] call CBE_fnc_CortexGroupMoveClear;',maintain)
        self.assertIn('if (_operationGeneration >= 0',maintain)

    def test_naval_release_is_token_scoped_and_never_forces_boarding(self):
        release=source('cortexNavalRelease')
        for marker in ['(_plan select 0) == _token','(_plan select 1) == _group',
                       'forceSpeed (_saved param [0,-1])','CortexGroupMoveClear',
                       'NAVAL_ASSAULT','NAVAL_LANDING']:
            self.assertIn(marker,release)
        self.assertIn('abs ((getForcedSpeed _boat)-_ownedStop) <= 0.1',release)
        self.assertIn('[_group,_operationGeneration] call CBE_fnc_CortexGroupMoveClear;',release)
        self.assertNotIn('[_group] call CBE_fnc_CortexGroupMoveClear;',release)
        self.assertIn('if (_operationGeneration >= 0 &&',release)
        self.assertIn('CBE_Cortex_NavalForcedSpeed",[getForcedSpeed _boat,0]',source('cortexNavalAssault'))
        for forbidden in ['moveIn','orderGetIn true','assignAs','setPos','deleteVehicle']:
            self.assertNotIn(forbidden,release)

    def test_confirmed_building_contact_enters_single_clearance_owner(self):
        """Fresh native indoor contact must select CQB without a second tactical controller."""
        contact=source('cortexBuildingContact')
        clear=source('cortexClearBuilding')
        tick=source('cortexGroupTick')
        spec=source('cortexTuningSpec')
        sections=source('aiTweaksSettingsSections')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        for marker in ['CBE_AIPass_BuildingCombat_Enable','CBE_AIPass_BuildingCombat_Range']:
            self.assertIn(marker,spec)
            self.assertIn(marker,contact)
        self.assertIn('["BUILDINGS", "03 Infantry", "07 Buildings and CQB"]',sections)
        self.assertIn('class CortexBuildingContact',functions)
        for marker in ['count _capable < 4','["preserveBrain",true]',
                       'CBE_fnc_BuildingContactSelect','CBE_fnc_CortexClearBuilding']:
            self.assertIn(marker,contact)
        selector=source('buildingContactSelect')
        for marker in ['_age <= 5','isNull objectParent _enemy','boundingBoxReal _building',
                       'worldToModel _belief','lineIntersectsSurfaces','_nearest select 2']:
            self.assertIn(marker,selector)
        for forbidden in [' setPos ',' moveIn ',' allowDamage ',' disableAI ']:
            self.assertNotIn(forbidden,contact)
        self.assertIn('private _preserveBrain=_options getOrDefault ["preserveBrain",false];',clear)
        preserved=clear.split('if (_preserveBrain) then {',1)[1].split('} else {',1)[0]
        self.assertNotIn('CBE_fnc_CortexReleaseGroup',preserved)
        self.assertIn('CBE_fnc_CortexGroupMoveClear',preserved)
        self.assertIn('CBE_fnc_CortexBuildingContact',tick)
        self.assertLess(tick.index('CBE_fnc_CortexCoordinatedAssault'),tick.index('CBE_fnc_CortexBuildingContact'))
        self.assertLess(tick.index('CBE_fnc_CortexBuildingContact'),tick.index('CBE_fnc_CortexTacticalStart'))

    def test_natural_building_admission_uses_belief_not_unseen_enemy_transform(self):
        text=source('buildingContactSelect')
        for marker in ('_x param [1,[],[[]]]','count _belief == 3','!finite _x',
                       'finite _age','_age >= 0','private _belief=+(_x select 1)',
                       'private _building=_nearest select 3','_building worldToModel _belief','AGLToASL _belief'):
            self.assertIn(marker,text)
        for forbidden in ('getPosATL _enemy','getPosWorld _enemy','getPosASL _enemy'):
            self.assertNotIn(forbidden,text)
        self.assertIn('if (count _records > 3) then {_records resize 3}',text)
        self.assertIn('_age <= 5',text)

    def test_natural_building_contact_has_physical_audit(self):
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        for marker in ['BUILD-CONTACT-native-knowledge','BUILD-CONTACT-natural-clear-started',
                       'BUILD-CONTACT-physical-entry','CBE_AIPass_BuildingCombat_Enable',
                       'CBE_AIPass_BuildingCombat_Range','knowsAbout _contactEnemy']:
            self.assertIn(marker,audit)
        natural=audit.split('// Natural building contact acceptance.',1)[1].split('// Independent natural-contact continuation case;',1)[0]
        for forbidden in [' reveal ','CBE_fnc_CortexClearBuilding','setPos','moveIn']:
            self.assertNotIn(forbidden,natural)
        self.assertEqual(natural.count('disableAI "PATH"'),1)
        self.assertIn('_contactEnemy disableAI "PATH";',natural)
        self.assertIn('BUILD-CONTACT-interior-defender-retained',natural)

    def test_naval_delivery_tracks_crew_and_passenger_generations_separately(self):
        naval=source('cortexNavalAssault')
        release=source('cortexNavalRelease')
        for marker in ['CBE_fnc_OperationStart','"NAVAL_ASSAULT"','"NAVAL_LANDING"',
                       'navalOperationGeneration','"APPROACH"','"EGRESS"']:
            self.assertIn(marker,naval)
        crew=naval.split('private _crewWaypoint=',1)[1]
        self.assertLess(crew.index('"MOVEMENT_REJECTED"'),crew.index('_state set ["movementLease"'))
        self.assertIn('[_group,_crewGeneration,"INCOMPLETE","MOVEMENT_REJECTED"]',crew)
        passenger=naval.split('// Passenger egress is a separate operation',1)[1].split('private _ships=',1)[0]
        waiting=naval.split('if (_aboard isNotEqualTo []) exitWith {',1)[1].split('// Passenger egress is a separate operation',1)[0]
        for marker in ('(_currentPlan select 0) == _token','(_currentPlan select 7) == _expires',
                       '(_currentPlan select 8) == "DISEMBARK"','[_boat] call _boatStopped',
                       '[_unit,_boat] call _cargoAvailable','select [0,64]','doGetOut _unit',
                       '_seat == "cargo"','_personTurret','_unit in _aboard'):
            self.assertIn(marker,waiting)
        for forbidden in ('moveOut','serverTime+','CBE_fnc_OperationStart',' doMove '):
            self.assertNotIn(forbidden,waiting)
        self.assertIn('if (_landingGeneration < 0) exitWith',passenger)
        self.assertIn('"PLATFORM_CHANGED"] call CBE_fnc_CortexNavalRelease',naval)
        self.assertIn('objectParent _x != _boat',naval)
        self.assertIn('private _elementArrived=_survivors findIf',passenger)
        self.assertIn('surfaceIsWater (getPosATL _x)',passenger)
        self.assertIn('(getPosASL _x) vectorDistance (AGLToASL _egress) > 30',passenger)
        self.assertNotIn('leader _group distance2D _egress',passenger)
        self.assertIn('if (!_egressReady) exitWith',passenger)
        self.assertIn('[_group,_egress,25,"MOVE",_landingGeneration]',passenger)
        self.assertNotIn('if (count _landingOperation == 0) exitWith',passenger)
        resumed=naval.split('// Boat crew: adopt or create',1)[1].split('private _remaining=',1)[0]
        self.assertIn('if (_crewGeneration < 0) exitWith',resumed)
        expiry=naval.split('if (count _operation == 5 && {serverTime >= (_operation select 4)}) exitWith',1)[1].split('// A passenger landing',1)[0]
        self.assertIn('"EXPIRED"] call CBE_fnc_CortexNavalRelease',expiry)
        self.assertNotIn('CortexGroupMove',expiry)
        self.assertNotIn('if (count _durable == 5 && {serverTime >=',naval)
        self.assertIn('if ((_plan select 8) == "DISEMBARK" && {_remaining < 0} && {!_egressPending})',naval)
        self.assertNotIn('if (_remaining < 0 || {serverTime >= _expires})',naval)
        self.assertNotIn('_unit doMove (_egress',naval)
        self.assertIn('CBE_Cortex_NavalEgress',naval)
        self.assertIn('CBE_Cortex_NavalGroundElement',source('cortexReleaseGroup'))
        self.assertIn('CBE_Cortex_NavalGroundElement',release)
        ground=naval.split('private _groundStarted=false;',1)[1].split('// Continue a passenger landing',1)[0]
        for marker in ('CBE_Cortex_NavalGroundElement','_groundEpoch','_groundRoute',
                       '"LANDED"','CBE_fnc_CortexTacticalStart','_groundActors','if (_groundStarted) exitWith {true}'):
            self.assertIn(marker,ground)
        followup=ground.split('if (!_groundCurrent)',1)[1].split('if (_groundStarted)',1)[0]
        committed=followup.split('// A committed child',1)[1]
        self.assertNotIn('setVariable ["CBE_Cortex_NavalGroundElement",nil',committed)
        self.assertIn('count (_group getVariable ["CBE_Operation",createHashMap]) == 0',followup)
        for guard in ('[_state,"advance"] call CBE_fnc_CortexCooldown',
                      '[_state,"assault"] call CBE_fnc_CortexCooldown',
                      '_groundAdvance || {_groundAssault}'):
            self.assertLess(followup.index(guard),followup.index('call CBE_fnc_CortexTacticalStart'))
        self.assertNotIn('serverTime+',ground)
        self.assertNotIn('CBE_fnc_CortexGroupMove',ground)
        self.assertIn('["elementScoped",_elementScoped]',source('cortexAssaultStart'))
        self.assertIn('["elementRoster",if (_elementScoped) then {+_element} else {[]}]',source('cortexAssaultStart'))
        advance=source('cortexAdvanceStart')
        for marker in ('["elementScoped",_elementScoped]','["elementRoster",if (_elementScoped) then {+_element} else {[]}]',
                       '[_group,_element] call CBE_fnc_CortexGroupAnchor',
                       'if (_elementScoped) then {_hasAuthoredObjective=false}', '_x in _element'):
            self.assertIn(marker,advance)
        self.assertNotIn('call CBE_fnc_CortexGroupMove',advance)
        self.assertIn('_started=_args call CBE_fnc_CortexAdvanceStart',source('cortexTacticalStart'))

        checkpoint=source('cortexCheckpoint')
        self.assertIn('"elementScoped","elementRoster"',checkpoint)
        resume=source('cortexDrillResume')
        for marker in ('_elementScoped isEqualType true','count _elementRoster > 64',
                       '_units findIf {!(_x in _elementRoster)}'):
            self.assertIn(marker,resume)
        self.assertLess(resume.index('private _elementScoped='),resume.index('call CBE_fnc_CortexOwnershipLease'))

        self.assertIn('_fitSquad=_fitSquad select {_x in _elementRoster}',source('cortexFlankStep'))
        self.assertIn('[_group,_members] call CBE_fnc_CortexGroupAnchor',source('cortexFlankEnd'))

        self.assertIn('_admissions < 2',naval)
        self.assertIn('_admissions=_admissions+1',naval)
        self.assertIn('[_landingGeneration,"NAVAL_LANDING"] call _operationCurrent',naval)
        self.assertIn('[_crewGeneration,"NAVAL_ASSAULT"] call _operationCurrent',naval)
        owner=naval.split('private _operationCurrent={',1)[1].split('private _boatStopped=',1)[0]
        for proof in ('"generation"','"intent"','"CANCELLED"','"ownerEpoch"'):
            self.assertIn(proof,owner)


        self.assertIn('if (objectParent _unit == _boat)',naval)
        self.assertIn('"STEP",_unit,[_token,_boat,_goal,_expires,_crewGeneration,_route]',naval)
        self.assertIn('"EGRESS_INCOMPLETE"] call CBE_fnc_CortexNavalRelease',naval)
        actor=source('cortexNavalEgressActor')
        self.assertIn('isNull objectParent _actor',actor)
        self.assertIn('[_group,_generation,_actor,_goal] call CBE_fnc_RecoveryStep',actor)
        self.assertNotIn('_actor doMove',actor)
        self.assertIn('"STOP_PENDING"',actor)
        self.assertIn('doStop _actor',actor)
        self.assertIn('serverTime >= _expires+30',actor)
        self.assertNotIn('serverTime+30',actor)
        self.assertIn('(_plan select 7) != _expires',actor)
        self.assertIn('"CBE_Cortex_NavalEgressMove"',source('cortexActorMoveReserved'))
        self.assertIn('["REAP",_x] call CBE_fnc_CortexNavalEgressActor',source('dangerSetup'))
        self.assertLess(release.index('call CBE_fnc_CortexNavalEgressActor'),release.index('call CBE_fnc_OperationCancel'))

        admission=naval.split('private _landingCrew=',1)[1].split('private _contact=',1)[0]
        self.assertIn('count _landingCrew > 64',admission)
        self.assertIn('alive _passenger',admission)

        self.assertNotIn('if (count _crewOperationRecord == 0) exitWith',resumed)
        vehicles=source('cortexVehicles')
        standoff=vehicles.split('private _operation=[_group,"VEHICLE_STANDOFF"',1)[1]
        self.assertLess(standoff.index('"MOVEMENT_REJECTED"'),standoff.index('_movementOwned = true'))
        self.assertIn('[_group,"VEHICLE_STANDOFF",false]',standoff)
        self.assertIn('[_state,"standoff",8]',standoff)
        for marker in ['navalOperationGeneration','CBE_fnc_OperationRelease',
                       'CBE_fnc_OperationCancel','NAVAL_']:
            self.assertIn(marker,release)

    def test_naval_audit_requires_real_coast_travel_dismount_and_cleanup(self):
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runNaval.sqf').read_text(encoding='utf-8')
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        for marker in ['for "_bearing" from 0 to 350 step 10','surfaceIsWater _water',
                       'NAVAL-terrain-coast','forEach [false,true]',
                       'NAVAL-"+_suffix+"-physical-water-travel',
                       'NAVAL-"+_suffix+"-physical-dismount',
                       'NAVAL-"+_suffix+"-dry-egress',
                       'NAVAL-"+_suffix+"-crew-retained',
                       'NAVAL-"+_suffix+"-finite-cleanup']:
            self.assertIn(marker,audit)
        post_setup=audit.split('} forEach [false,true];',1)[0].split('private _start=getPosATL _boat;',1)[1]
        for forbidden in ['setPos','moveInCargo','addWaypoint','setVariable ["CBE_Cortex_NavalPlan"']:
            self.assertNotIn(forbidden,post_setup)
        self.assertIn('cortexQANaval.sqf',runner)
        self.assertIn("mod_pipeline.py') stage $Package $runtime --focus $Focus",launcher)
        self.assertIn("glob('run*.sqf')", (ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8'))



    def test_tactical_movement_hands_back_ordinary_driving_before_acquisition(self):
        lease=source('cortexOwnershipLease')
        available=(ROOT/'addons/vehicles/functions/drivingMovementAvailable.sqf').read_text(encoding='utf-8')
        self.assertLess(lease.index('CBE_fnc_DrivingOperationFinish'),lease.index('_group setVariable ["CBE_Cortex_MovementLease"'))
        pending=lease.split('private _drivingPending=',1)[1].split('if (_drivingPending)',1)[0]
        for receipt in ('CBE_DrivingQueue_Consent','CBE_DrivingPass_Consent','CBE_DrivingPass_Agreement'):
            self.assertIn(receipt,pending)
        self.assertIn('count _pending > 0',pending)
        self.assertIn('!(_pending isEqualType [] || {_pending isEqualType createHashMap})',pending)
        self.assertLess(lease.index('if (_drivingPending) exitWith {false}'),
                        lease.index('_group setVariable ["CBE_Cortex_MovementLease"'))

        self.assertIn('serverTime < (_lease select 1)',available)
        self.assertIn('CBE_VehicleReverse',available)
        self.assertIn('CBE_AIPass_Epoch',available)
        for name in ['drivingAssistStart','drivingAssistRelease','drivingOperationStart','drivingOperationStep']:
            self.assertIn('CBE_fnc_DrivingMovementAvailable',(ROOT/('addons/vehicles/functions/'+name+'.sqf')).read_text(encoding='utf-8'))
        self.assertNotIn('setVariable',available)

    def test_reverse_clearance_is_shared_body_sized_and_read_only(self):
        """Both native recovery paths must use fresh hull-width actor and geometry evidence."""
        observer=(ROOT/'addons/vehicles/functions/drivingRearClear.sqf').read_text(encoding='utf-8')
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        tracked=source('cortexVehicleReverseStep')
        self.assertIn('boundingBoxReal _vehicle',observer)
        self.assertIn('boundingBoxReal _thisActor',observer)
        self.assertIn('count _actors > 64',observer)
        self.assertIn('forEach _heights',observer)
        self.assertIn('[0.45,0.9,(_bodyHeight+0.45)*0.5,_bodyHeight]',observer)
        self.assertIn('forEach [_left,(_left+_right)*0.5,_right]',observer)
        self.assertIn('_maxX >= _actorLeft',observer)
        self.assertIn('private _actorLeft=_left;private _actorRight=_right;',observer)
        self.assertIn('_minY <= _actorFront',observer)
        self.assertIn('private _actorRear=_rear-_distance;private _actorFront=_rear+0.5;',observer)
        self.assertIn('"GEOM","NONE"',observer)
        self.assertIn('call CBE_fnc_DrivingRearClear',ordinary)
        self.assertIn('call CBE_fnc_DrivingRearClear',tracked)
        self.assertLess(ordinary.index('call CBE_fnc_DrivingRearClear'),ordinary.index('_movementOperator doMove _rear'))
        self.assertLess(tracked.index('call CBE_fnc_DrivingRearClear'),tracked.index('_vehicle sendSimpleCommand "BACK"'))
        for write in ['forceSpeed','sendSimpleCommand','doMove','setPos','setVelocity','disableCollisionWith']:
            self.assertNotIn(write,observer)
        self.assertNotIn('allVehicles',observer)
        self.assertNotIn('allUnits',observer)

    def test_reverse_clearance_uses_full_vertical_hulls_not_actor_centres(self):
        text=(ROOT/'addons/vehicles/functions/drivingRearClear.sqf').read_text(encoding='utf-8')
        for proof in ['private _thisActor=_x','_thisActor modelToWorld _otherLow',
                      '_projectedLow set [_axis','_projectedHigh set [_axis',
                      '_maxZ >= (_low select 2)-0.3','_minZ <= (_high select 2)+0.3']:
            self.assertIn(proof,text)
        self.assertNotIn('abs _vertical < 4',text)
        # A tall hull can overlap while its centre lies outside the former four-metre band.
        overlap=lambda low,high,other_low,other_high:other_high>=low-0.3 and other_low<=high+0.3
        self.assertTrue(overlap(-1,2,1.9,7))
        # Nearby centres on stacked surfaces do not justify occupying the reverse corridor.
        self.assertFalse(overlap(-1,1,2,3.5))
        self.assertTrue(overlap(-1,1,1.2,2))

    def test_ordinary_driving_fsm_owns_queued_execution_and_terminal_receipts(self):
        """Old/replaced/retired driving work cannot enter the movement executor."""
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text(encoding='utf-8')
        start=(ROOT/'addons/vehicles/functions/drivingOperationStart.sqf').read_text(encoding='utf-8')
        queue=(ROOT/'addons/vehicles/functions/drivingOperationQueue.sqf').read_text(encoding='utf-8')
        step=(ROOT/'addons/vehicles/functions/drivingOperationStep.sqf').read_text(encoding='utf-8')
        finish=(ROOT/'addons/vehicles/functions/drivingOperationFinish.sqf').read_text(encoding='utf-8')
        execute=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        for phase in ['Cruise','IntentionalWait','Recovery','Finished','SchedulerWatchdog']:
            self.assertIn('class '+phase,fsm)
        self.assertIn('drivingOperation.fsm',start)
        self.assertIn('CBE_fnc_CortexQueueJob',queue)
        self.assertIn('CBE_DRIVING_%1_%2_%3',queue)
        self.assertIn('if (count _brain == 0) exitWith {[_group] call CBE_fnc_DrivingOperationStart}',execute)
        self.assertIn('[_group,_brain] call CBE_fnc_DrivingAssistStart',step)
        for text in [queue,step,finish,execute]:
            self.assertIn('CBE_Driving_Brain',text)
            self.assertIn('ownerEpoch',text)
        self.assertIn('EXHAUSTED',start+step+finish)
        self.assertIn('if !(_reason in ["EXHAUSTED","FSM_START_FAILED","FSM_RESTART_EXHAUSTED"])',finish)
        self.assertIn('CBE_fnc_DrivingOperationFinish',source('cortexReleaseGroup'))
        self.assertNotIn('sleep',step)
        self.assertNotIn('forceSpeed',queue)
        self.assertNotIn('doMove',fsm)
        locality=source('cortexLocality')
        self.assertLess(locality.index('CBE_fnc_DrivingOperationFinish'),locality.index('_group setVariable ["CBE_AIPass_Epoch"'))
        self.assertIn('CBE_fnc_DrivingOperationFinish',source('cortexStop'))
        self.assertLess(start.index('call CBE_fnc_CortexLocality'),start.index('private _epoch='))


    def test_driving_native_wait_never_executes_condition_or_starts_recovery(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        wait=text.split('private _nativeWaiting = {',1)[1].split('private _mayRecoverRoute',1)[0]
        for proof in ['!unitReady _vehicle','waypointCompletionRadius','triggerActivated',
                      'waypointTimeout','waypointStatements','"HOLD"']:
            self.assertIn(proof,wait)
        self.assertNotIn('compile',wait)
        self.assertNotIn('call _condition',wait)
        self.assertIn('&& {!(call _nativeWaiting)}',text)
        self.assertIn('_state set [8,"INTENTIONAL_WAIT"]',text)

    def test_driving_recovery_cannot_bypass_a_distant_authored_gate(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        policy=text.split('private _recoveryOrderFree = {',1)[1].split('private _mayRecoverRoute',1)[0]
        self.assertIn('call CBE_fnc_DrivingRouteGoal',policy)
        policy=source('drivingRouteGoal')
        for proof in ['_goalIndex <= 0','waypointType _goalWaypoint != "MOVE"',
                      '_goalCondition != "true"','_goalStatements param [1,""]',
                      'waypointScript','waypointTimeout','waypointAttachedVehicle',
                      'waypointAttachedObject','synchronizedWaypoints','synchronizedTriggers',
                      '!finite _x']:
            self.assertIn(proof,policy)
        self.assertNotIn('distance2D',policy)
        self.assertNotIn('compile',policy)
        self.assertIn('&& {call _recoveryOrderFree}',text)

    def test_driving_same_index_order_edits_invalidate_recovery_before_every_write(self):
        """A condition/trigger/speed edit must fence a stale reverse, even with unchanged position."""
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        receipt=(ROOT/'addons/vehicles/functions/drivingRouteReceipt.sqf').read_text(encoding='utf-8')
        metadata=(ROOT/'addons/core/functions/authoredRouteReceipt.sqf').read_text(encoding='utf-8')
        self.assertIn('[_group,"",false,_index] call CBE_fnc_AuthoredRouteReceipt',receipt)
        for command in ['waypointStatements','waypointTimeout','synchronizedTriggers',
                        'waypointSpeed','waypointCombatMode','waypointFormation',
                        'waypointScript','waypointAttachedVehicle','waypointAttachedObject',
                        'synchronizedWaypoints','waypointHousePosition','waypointLoiterAltitude']:
            self.assertIn(command,metadata)
        self.assertIn('if (isNull _vehicle && {isNull _object}) then {waypointPosition _waypoint} else {[]}',metadata)
        self.assertIn('_index <= 0',receipt)
        guard=start.split('private _mayIssueDriving = {',1)[1].split('};',1)[0]
        self.assertIn('(call _readRouteIdentity) isEqualTo _routeIdentity',guard)
        self.assertIn('(_state param [9,[]]) isNotEqualTo _routeIdentity',start)
        self.assertIn('_state set [6,0]',start)
        writes=re.findall(r'([^;{}]*)(?:_vehicle forceSpeed|_movementOperator doMove)',start)
        self.assertEqual(len(writes),6)
        jam=start.split('// Bounded traffic replan:',1)[1].split('// Waiting behind traffic',1)[0]
        self.assertIn('&& {call _mayRecoverOrdinaryRoute}) then {',jam)
        self.assertIn('private _requestGoal=[_group] call CBE_fnc_DrivingRouteGoal;',jam)
        self.assertIn('_movementOperator doMove _requestGoal;',jam)
        self.assertGreaterEqual(start.count('call _mayIssueDriving'),3)
        self.assertIn('if (!_capCommitted) then {',start)
        cap=start.split('private _capCommitted=false;',1)[1].split('if (!_capCommitted)',1)[0]
        self.assertIn('isNotEqualTo _entryRestore',cap)
        self.assertIn('isNotEqualTo _entryAssistState',cap)

    def test_driving_followers_cannot_recover_the_leaders_shared_route(self):
        """Stationary formation followers must never become independent reverse controllers."""
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        for check in ['local _group && {local _vehicle}',
                      'driver _vehicle isEqualTo _driver',
                      '(effectiveCommander _vehicle) in [_movementOperator,objNull]',
                      'vehicle _movementOperator isEqualTo _vehicle',
                      'local _driver', 'group _driver == _group']:
            self.assertIn(check,start)
        guard=start.split('private _mayRecoverRoute = {',1)[1].split('};',1)[0]
        self.assertIn('call _mayIssueDriving',guard)
        self.assertIn('vehicle leader _group isEqualTo _vehicle',guard)
        self.assertGreaterEqual(start.count('{call _mayRecoverRoute}'),2)
        follower=start.split('if (_state isNotEqualTo [] && {vehicle leader _group isNotEqualTo _vehicle}) then {',1)[1].split('private _origin=',1)[0]
        self.assertIn('_state set [5,time]',follower)
        self.assertIn('_state set [6,0]',follower)
        self.assertIn('if ((_state param [6,0]) != 4) then {_state set [6,0];_state set [7,-1]}',follower)
        self.assertIn('"NATIVE_FOLLOWER"',follower)
        self.assertLess(start.index('"NATIVE_FOLLOWER"'),start.index('private _cap='))

    def test_general_driving_assist_is_separate_from_convoys_and_preserves_native_routes(self):
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text(encoding='utf-8')
        spec=source('cortexTuningSpec')
        group_tick=source('cortexGroupTick')
        self.assertIn('CBE_AIPass_DrivingAssist_Enable',spec)
        self.assertIn('Convoy driving is configured separately',spec)
        sections=source('aiTweaksSettingsSections')
        self.assertIn('["DRIVING", "05 Vehicles", "01 General driving and route safety"]',sections)
        self.assertIn('true, "DRIVING", "NEXT_OPERATION"',spec)
        self.assertIn('["CONVOY_DRIVING", "06 Convoys", "02 Driving and route safety"]',sections)
        self.assertIn('CBE_Convoy_Active',start)
        self.assertIn('CBE_fnc_DrivingAssistRelease',start)
        self.assertIn('private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;',start)
        self.assertIn('getTerrainHeightASL _sample',start)
        self.assertIn('time+([4,1] select (_trafficLimited || {_trafficWatch} || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))',start)
        self.assertIn('private _capMps=_cap/3.6;',start)
        self.assertIn('if (_saved > 0) then {_capMps=_capMps min _saved};',start)
        self.assertIn('forceSpeed _capMps',start)
        self.assertIn('["CBE_DrivingAssist_State",[_capMps,',start)
        self.assertIn('CBE_fnc_DrivingAssistStart',group_tick)
        self.assertIn('CBE_DrivingAssist_Restore',release)
        self.assertIn('CBE_DrivingAssist_State',release)
        self.assertIn('abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1',release)
        self.assertIn('abs ((getForcedSpeed _vehicle)-_ownedCap) > 0.1',start)
        self.assertIn('forceSpeed (_restore param [0,-1])',release)
        self.assertIn('CBE_DrivingAssist_Vehicles',source('cortexReleaseGroup'))
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('general-driving',diagnostics)
        self.assertIn('capKmh=%2',diagnostics)
        self.assertIn('_capMps*3.6',diagnostics)

    def test_danger_lifecycle_uses_a_live_group_actor_for_leader_loss_cleanup(self):
        """A dead original leader cannot strand a short danger posture or operation record."""
        setup=source('dangerSetup')
        start=source('operationStart')
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        for text in [setup,start,fsm]:
            self.assertIn('CBE_fnc_CortexGroupAnchor',text)
        self.assertIn('getPosATL _operationAnchor',start)
        self.assertIn('[_dangerActor,""RELEASE""] call CBE_fnc_DangerReact',fsm)

    def test_tracked_reverse_is_bounded_and_uses_existing_operation_authority(self):
        reverse=source('cortexVehicleReverseStep')
        vehicles=source('cortexVehicles')
        tick=source('cortexGroupTick')
        self.assertIn('_vehicle isKindOf "Tank"',reverse)
        self.assertIn('_driver == _commander',reverse)
        self.assertIn('CBE_AIPass_VehicleWithdraw_Enable',reverse)
        self.assertIn('ownerEpoch',reverse)
        self.assertIn('CortexExternalTakeover',reverse)
        self.assertIn('CortexSelectAvenue',reverse)
        self.assertIn('lineIntersectsSurfaces',reverse)
        self.assertIn('time-(_record select 6) > 6',reverse)
        self.assertIn('sendSimpleCommand "BACK"',reverse)
        self.assertIn('vehicleMoveInfo',reverse)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        self.assertIn('WITHDRAW-tracked-physical-reverse',audit)
        self.assertIn('(velocityModelSpace _armour select 1) < -0.5',audit)
        self.assertIn('WITHDRAW-tracked-threat-facing',audit)
        for forbidden in ['setDir','setVelocity','setPos','while {','spawn {']:
            self.assertNotIn(forbidden,reverse)
        self.assertIn('if (_reverse == "FALLBACK")',vehicles)
        self.assertIn('_reverseResult in ["COMPLETE","FALLBACK"]',tick)
        for helper in ['operationCancel','operationRelease','cortexRestoreCalm','cortexLocality']:
            self.assertIn('CBE_fnc_CortexVehicleReverseStep',source(helper))

    def test_group_and_actor_danger_stance_owners_transfer_original_baseline(self):
        group_hide=source('dangerGroupHideStep')
        actor=source('dangerEngineAct')
        self.assertIn('CBE_Danger_EngineStanceLease',group_hide)
        for marker in ['CBE_OperationGeneration','CBE_AIPass_Epoch','private _mayRestore','[_x] call _mayRestore']:
            self.assertIn(marker,group_hide)
        release=group_hide.split('private _mayRestore=',1)[1].split('private _release=',1)[0]
        self.assertIn('!([_unit] call CBE_fnc_CortexActorMoveReserved)',release)
        for proof in ('CBE_Danger_FlightLease','CBE_Cortex_NavalEgressMove',
                      '(_move select 0) isEqualTo "DANGER_COVER"',
                      'count (_move select 1) == 3','!finite _x','finite (_move select 2)'):
            self.assertIn(proof,release)
        candidates=group_hide.split('private _candidates=',1)[1].split('// Preserve the squad',1)[0]
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',candidates)
        self.assertIn('CBE_Cortex_ActorMove',release)
        self.assertIn('CBE_fnc_CortexCombatEffective',release)
        self.assertIn('CBE_Danger_EngineStanceLease',release)
        self.assertIn('_groupLeaseIndex=_groupLeases findIf',actor)
        self.assertIn('_priorStance=_groupLease param [1,_currentStance',actor)
        self.assertIn('_groupLeases deleteAt _groupLeaseIndex',actor)
        self.assertLess(actor.index('_actor setUnitPosWeak'),actor.index('_groupLeases deleteAt'))
        acquisition=actor.split('if (_mayApply) then {',1)[1].split('private _stats=',1)[0]
        confirm=acquisition.index('if (toUpperANSI unitPos _actor == _desiredStance) then {')
        self.assertLess(confirm,acquisition.index('_actor setVariable ["CBE_Danger_EngineStanceLease"'))
        self.assertLess(acquisition.index('_actor setVariable ["CBE_Danger_EngineStanceLease"'),acquisition.index('_groupLeases deleteAt'))
        for proof in ('_groupTransfer isNotEqualTo []','_priorStance == (_groupTransfer select 1)',
                      'isEqualTo _groupLeases','isEqualTo _groupTransfer'):
            self.assertIn(proof,acquisition)
        group_apply=group_hide.split('private _newLeases=[];',1)[1]
        self.assertLess(group_apply.index('if (toUpperANSI unitPos _x == _applied) then {'),group_apply.index('_newLeases pushBack'))

    def test_actor_reservations_keep_mobile_danger_posture_including_indoor(self):
        actor=source('dangerEngineAct')
        self.assertIn('private _nativeRouteTask=currentCommand _actor == "MOVE"',actor)
        self.assertIn('getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]',actor)
        self.assertIn('private _actorSpeed=abs (speed _actor)',actor)
        self.assertIn('|| {_actorSpeed >= 0.5}',actor)
        self.assertEqual(actor.count('speed _actor'),1)
        self.assertIn('&& {_actorSpeed < 0.5}',actor)
        native=actor.index('if (_nativeRouteTask) then {_committedMover=true}')
        self.assertLess(native,actor.index('playActionNow'))
        self.assertLess(native,actor.index('if (_mode == "IMMEDIATE")'))
        self.assertIn('_hardCover && {!_committedMover}',actor)
        engage=actor.split('if (_mode == "ENGAGE") then {',1)[1].split('if (_desiredStance != "")',1)[0]
        self.assertIn('_suppression > 0.9 && {!_committedMover}',engage)
        self.assertIn('_desiredStance="DOWN"',engage)
        self.assertIn('_suppression > 0.2 && {stance _actor == "STAND"}',engage)
        self.assertEqual(actor.count('getSuppression _actor'),1)

        self.assertIn('stance _actor == "PRONE"',actor)
        reload_guard=actor.split('private _evasionWeaponReady={',1)[1].split('private _lateralEvasion=false;',1)[0]
        for proof in ('weaponState _actor','count _evasionWeapon >= 7','[5,6] findIf','!finite _phase','_phase != 0'):
            self.assertIn(proof,reload_guard)
        self.assertEqual(actor.count('call _evasionWeaponReady'),2)
        self.assertNotIn('reload ',reload_guard)
        self.assertNotIn('setWeaponReloadingTime',reload_guard)
        evasion=actor.split('if (_mode == "IMMEDIATE" && {_cause in [2,9]}',1)[1].split('// Body and scream observations',1)[0]
        self.assertEqual(evasion.count('lineIntersects ['),1)
        self.assertLess(evasion.index('CBE_Danger_EvasionAfter'),evasion.index('lineIntersects ['))
        self.assertLess(evasion.index('lineIntersects ['),evasion.index('playActionNow'))
        self.assertIn('_evasionEye vectorAdd [0,0,7],_actor',evasion)
        lateral=evasion.split('// Retain the source intent of a short upright dodge',1)[1]
        for guard in ('!_committedMover','["STAND","CROUCH"]','CBE_AIPass_DangerEvasion_Enable',
                      'CBE_Danger_EvasionAfter','["TactR","TactL"]','[_low,_eye] findIf',
                      'if (!_blocked)','_lateralEvasion=true'):
            self.assertIn(guard,lateral)
        self.assertLess(lateral.index('setVariable ["CBE_Danger_EvasionAfter"'),lateral.index('lineIntersectsSurfaces'))
        self.assertLess(lateral.index('if (!_blocked)'),lateral.index('playActionNow'))
        for forbidden in ('doMove','setDestination','forceSpeed','setVelocity','spawn','waitAndExecute'):
            self.assertNotIn(forbidden,lateral)
        self.assertIn('_hardCover && {!_committedMover} && {!_lateralEvasion}',actor)

        cover=source('dangerCoverStep')
        self.assertEqual(cover.count('getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]'),2)
        admission=source('dangerGroupHideStep').split('private _candidates=',1)[1]
        self.assertIn('!(getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"])',admission)
        self.assertLess(admission.index('getUnitState _x'),admission.index('_x setUnitPosWeak'))

        self.assertIn('if ([_actor] call CBE_fnc_CortexActorMoveReserved) then {_committedMover=true;}',actor)
        self.assertLess(actor.index('_committedMover=true'),actor.index('if (_mode == "IMMEDIATE")'))
        indoor=source('indoorActorOperation')
        start=indoor.split('if (_mode == "START") exitWith {',1)[1]
        self.assertLess(start.index('call CBE_fnc_DangerEngineRelease'),start.index('_actor setVariable ["CBE_Cortex_ActorMove"'))
        self.assertLess(start.index('call CBE_fnc_DangerGroupHideStep'),start.index('_actor setVariable ["CBE_IndoorActor_Brain"'))
        hide=source('dangerGroupHideStep')
        handover=hide.split('if (!isNull _releaseActor) exitWith {',1)[1].split('private _release={',1)[0]
        for guard in ('_remaining deleteAt _index','call _mayRestore','unitPos _releaseActor == _applied','exitWith {false}'):
            self.assertIn(guard,handover)
        self.assertNotIn('doMove',handover)

    def test_infantry_assessment_does_not_take_mounted_vehicle_destinations(self):
        assess=source('cortexTacticalAssess')
        start=source('cortexTacticalStart')
        self.assertIn('if (!_hasFoot || {_hasCrew && {!_elementScoped}}) exitWith',assess)
        self.assertIn('_x in ["ASSAULT","ADVANCE"]',assess)
        self.assertIn('private _forwardOrder=!_elementScoped',assess)
        self.assertIn('_x in _element',assess)
        self.assertLess(assess.index('"VEHICLE_DOMAIN"'),assess.index('"INSUFFICIENT_FIREPOWER"'))
        self.assertLess(assess.index('"VEHICLE_DOMAIN"'),assess.index('"MORALE_SHAKEN"'))
        self.assertIn('"VEHICLE_LAYER_HANDOFF"',start)

    def test_static_assembly_preserves_bag_before_observing_native_drop(self):
        deploy=source('cortexStaticDeployStep')
        ownership=deploy.split('private _participantUnavailable=',1)[1].split('if (_phase == "CONTACT" && {_status == "PACK_MOVING"}',1)[0]
        self.assertIn('CBE_fnc_CortexCombatEffective',ownership)
        self.assertIn('assignedVehicle _actor == _weapon',ownership)
        self.assertIn('!_ownedAction',ownership)
        self.assertIn('[true] call _retire',ownership)
        self.assertIn('"HEAL SOLDIER"',ownership)
        self.assertLess(deploy.index('_record set [13,unitBackpack _assistant]'),deploy.index('action ["PutBag",_assistant]'))
        drop=deploy.split('if (_status == "DROPPING") exitWith',1)[1].split('if (_status == "ASSEMBLING")',1)[0]
        self.assertIn('isNull unitBackpack _assistant',drop)
        self.assertIn('_gunner distance _supportAnchor <= 3.5',drop)
        self.assertIn('_dropPosition distance ([_x] call _bagAnchor) <= 5',drop)
        self.assertIn('!(_record param [16,false,[false]])',drop)
        self.assertIn('_actorMove isEqualTo ["STATIC_DEPLOY",_deployPos,_deadline]',drop)
        self.assertIn('time < _deadline',drop)
        self.assertIn('_gunner doMove _bagPosition',drop)
        self.assertNotIn('_record set [6,time+',drop.split('// Native combat can separate',1)[1].split('// Observe completed',1)[0])
        self.assertIn('private _container=objectParent _bag',deploy)
        self.assertIn('action ["Assemble",_supportBag]',drop)
        self.assertIn('everyBackpack _x',drop)
        deployment_move=deploy.split('if (_status == "MOVING") exitWith',1)[1].split('if (_status == "DROPPING")',1)[0]
        self.assertLess(deployment_move.index('if (time >= _deadline)'),deployment_move.index('action ["PutBag",_assistant]'))
        self.assertLess(deployment_move.index('if (time >= _deadline)'),deployment_move.index('action ["Assemble",_holder]'))
        pack_exit=deploy.split('if (_status == "PACK_EXITING") exitWith',1)[1].split('if (_status == "PACK_MOVING")',1)[0]
        self.assertIn('vehicle _gunner == _gunner',pack_exit)
        self.assertIn('currentCommand _gunner != "GET OUT"',pack_exit)
        self.assertIn('time >= _deadline',pack_exit)
        self.assertIn('_record set [1,"PACK_MOVING"]',pack_exit)
        pack_move=deploy.split('if (_status == "PACK_MOVING") exitWith',1)[1].split('if (_status == "PACKING")',1)[0]
        self.assertLess(pack_move.index('_record set [1,"PACKING"]'),pack_move.index('if (time >= _deadline)'))
        self.assertIn('!(_x in _existingBags)',drop)
        self.assertLess(drop.index('_record set [1,"ASSEMBLING"]'),drop.index('if (time >= _deadline)'))
        self.assertIn('time >= _deadline',drop)
        self.assertIn('action ["Assemble",_supportBag]',drop)

    def test_group_release_cannot_retain_cover_or_issue_recovery_movement(self):
        cover=source('dangerCoverStep')
        release=source('cortexReleaseGroup')
        self.assertIn('_dangerCoverLease select 1,true] call CBE_fnc_DangerCoverStep',release)
        self.assertIn('if (!_releaseOnly && {_leaseContextCurrent} && {count _lease >= 4}',cover)
        self.assertIn('if (!_releaseOnly && {_leaseContextCurrent} && {_entryContext isEqualTo (call _readOrderContext)}',cover)
        self.assertLess(cover.index('if (_releaseOnly) exitWith'),cover.index('call CBE_fnc_CortexFindCover'))
        recovery=cover.split('if (!_releaseOnly && {_leaseContextCurrent} && {_entryContext isEqualTo (call _readOrderContext)}',1)[1].split('_leasedActor doFollow',1)[0]
        self.assertIn('_leasedActor checkAIFeature "MOVE"',recovery)
        self.assertIn('_leasedActor checkAIFeature "PATH"',recovery)
        self.assertIn('[_leasedActor] call CBE_fnc_CortexCombatEffective',recovery)
        self.assertIn('!fleeing _leasedActor',recovery)

    def test_nearby_valid_cover_is_not_misclassified_as_failed_screening(self):
        text=source('dangerCoverStep')
        self.assertIn('if (_found && {count _spot >= 2}',text)
        self.assertIn('"NO_DISPLACEMENT"',text)
        self.assertNotIn('_spot distance2D _origin < 2',text)
        self.assertLess(text.index('"NO_DISPLACEMENT"] call'),text.index('if (!_found'))

    def test_concealment_is_explicit_and_separate_from_ballistic_cover(self):
        cover=source('cortexFindCover')
        self.assertIn('["_mode","COVER",[""]]',cover)
        screen=source('cortexCoverScreened')
        self.assertIn('["FIRE","VIEW"] select (_mode == "CONCEALMENT")',screen)
        self.assertIn('["GEOM","NONE"] select (_mode == "CONCEALMENT")',screen)
        self.assertIn('CBE_fnc_CortexCoverScreened',cover)
        danger=source('dangerCoverStep')
        self.assertEqual(danger.count('call CBE_fnc_CortexFindCover'),1)
        self.assertIn('"NO_VALID_COVER"',danger)
        self.assertIn('"NO_SCREEN"',danger)
        self.assertIn('CBE_AIPass_DangerConcealment_Enable',danger)
        self.assertIn('+_spot,_screenMode',danger)
        adoption=danger.split('// A fresh observation is not automatically',1)[1].split('_lease set [1,_generation]',1)[0]
        self.assertIn('_generation == (_group getVariable ["CBE_Danger_Generation",0])',adoption)
        self.assertIn('_screening in ["COVER","CONCEALMENT"]',adoption)
        self.assertIn('[_screenStart,_screenEnd,_actor,_screening] call CBE_fnc_CortexCoverScreened',adoption)
        self.assertIn('terrainIntersectASL [_start,_end]',screen)
        self.assertIn('!(_object isKindOf "CAManBase")',screen)
        self.assertNotIn('doMove',adoption.replace('// deadline, repeat doMove','// deadline, repeat command'))

    def test_alert_observation_is_finite_and_preserves_committed_movement(self):
        text=source('dangerEngineAct')
        observation=text.split('// Body and scream observations deserve',1)[1].split('// Forced orders',1)[0]
        self.assertIn('_cause in [5,6,7]',observation)
        self.assertIn('!_committedMover',observation)
        self.assertIn('currentCommand _actor == ""',observation)
        self.assertIn('glanceAt',observation)
        self.assertNotIn('glanceAt _observed',observation)
        self.assertIn('glanceAt _position',observation)
        for forbidden in ['doMove','doTarget','doWatch','_actor reveal','setCombatMode']:
            self.assertNotIn(forbidden,observation.replace('reveals',''))

    def test_rejected_vehicle_escape_does_not_consume_withdrawal_or_smoke(self):
        text=source('cortexVehicles')
        section=text.split('// A rejected route is not a completed withdrawal.',1)[1].split('// Gunner priorities',1)[0]
        self.assertIn('serverTime+8,true',section)
        self.assertLess(section.index('if (count _operation == 0)'),section.index('_withdrawn pushBackUnique'))
        self.assertLess(section.index('if (count _operation == 0)'),section.index('CBE_fnc_CortexFireCountermeasure'))

    def test_passenger_stop_saved_speed_survives_owner_migration(self):
        text=source('cortexDismountStop')
        self.assertIn('setVariable ["CBE_Cortex_DismountForcedSpeed",_saved,true]',text)
        self.assertIn('setVariable ["CBE_Cortex_DismountStopReceipt",_proof,true]',text)
        self.assertIn('setVariable ["CBE_Cortex_DismountForcedSpeed",nil,true]',text)
        self.assertIn('local _vehicle',text)
        self.assertIn('local _group',text)
        self.assertIn('(_blocked select 1) == _epoch',text)
        self.assertIn('_result=_blocked isEqualTo [] ||',text)
        self.assertLess(text.index('call CBE_fnc_DrivingAssistRelease'),text.index('_vehicle forceSpeed 0'))
        self.assertIn('CBE_DrivingCapRelease_Work',text)
        self.assertIn('CBE_DrivingQueue_Consent',text)
        self.assertIn('CBE_DrivingPass_Consent',text)
        self.assertIn('private _available=_protocolFree',text)
        self.assertIn('CBE_DrivingPass_Agreement',text)
        self.assertIn('_dismountAgreement isEqualType []',text)
        self.assertIn('_dismountAgreement isEqualTo []',text)
        release=text.split('if (_mode == "RELEASE" && {_restore}',1)[1].split('if (!_result)',1)[0]
        self.assertIn('&& {_crewMatches}',release)
        self.assertNotIn('&& {_matches}',release)
        self.assertIn('getForcedSpeed _vehicle == (_saved select 1)',release)
        crew=text.split('private _crewMatches=',1)[1].split('private _matches=',1)[0]
        for guard in ('_typed','_available','_driver == (_proof select 1)','_commander == (_proof select 2)'):
            self.assertIn(guard,crew)
        self.assertNotIn('_native',crew)
        for command in ('doMove','doFollow','setDestination','setCurrentWaypoint'):
            self.assertNotIn(command,release)
        consent=source('drivingPassCanConsent')
        self.assertLess(consent.index('CBE_Cortex_DismountStopReceipt'),consent.index('vehicleMoveInfo _vehicle'))
        for name in ['drivingAssistStart','drivingAssistRelease']:
            self.assertIn('CBE_Cortex_DismountStopReceipt',source(name))
        self.assertNotIn('(_proof select 0) == (_group getVariable ["CBE_OperationGeneration"',text)

    def test_group_hide_release_respects_actor_transfer_and_vehicle_domain(self):
        text=source('dangerGroupHideStep')
        release=text.split('private _release={',1)[1].split('if (!_active',1)[0]
        for gate in ['group _unit == _group','isNull objectParent _unit','!isPlayer _unit',
                     'CBE_fnc_CompatibilityExternalControl']:
            self.assertIn(gate,release)
        self.assertLess(release.index('group _unit == _group'),release.index('setUnitPosWeak'))

    def test_cover_retention_requires_exact_actor_marker_and_native_destination(self):
        text=source('dangerCoverStep')
        retention=text.split('private _moveProof=',1)[1].split('exitWith {true};',1)[0]
        self.assertIn('(_moveProof select 2) == (_lease select 2)',retention)
        self.assertIn('expectedDestination _actor',retention)
        self.assertIn('(_moveProof select 0) == "DANGER_COVER"',retention)

    def test_committed_cover_outlives_expired_observation_with_bounded_travel(self):
        text=source('dangerCoverStep')
        retention=text.split('if (!_releaseOnly && {_leaseContextCurrent} && {count _lease >= 4}',1)[1].split('exitWith {true};',1)[0]
        self.assertNotIn('count _threat',retention)
        self.assertIn('max 4 min 12',text)
        self.assertIn('["DANGER_COVER",+_spot,_deadline]',text)
        self.assertIn('[_actor,_generation,_deadline,+_spot,+_threat,+_entryContext]',text)
        adoption=text.split('// A fresh observation',1)[1].split('if (!_releaseOnly && {_leaseContextCurrent} && {count _lease >= 4}',1)[0]
        self.assertIn('_lease set [1,_generation]',adoption)
        self.assertIn('if (!_releaseOnly && {_leaseContextCurrent} && {count _lease >= 5}',adoption)
        self.assertIn('CBE_fnc_CortexCombatEffective',text)
        self.assertNotIn('_lease set [2',adoption)
        self.assertNotIn('doMove _',adoption)

    def test_cover_budget_ranks_placed_and_terrain_objects_together(self):
        text=source('cortexFindCover')
        self.assertIn('private _ranked=[];',text)
        self.assertIn('{_ranked pushBack [_x distance2D _position,_forEachIndex,_x]} forEach _objects;',text)
        self.assertIn('_ranked sort true',text)
        self.assertIn('_objects=(_ranked select [0,10])',text)
        self.assertLess(text.index('forEach _placed'),text.index('_ranked sort true'))

    def test_danger_release_retains_blocked_original_and_confirms_restore(self):
        for name in ('cortexActorFireTaskAvailable','cortexFireControl','indoorActorNativeContext','pointActorOperation','indoorActorOperation','dangerCoverStep','dangerGroupHideStep','cortexSearchMoveOwned','cortexFlankStep','cortexFlankEnd'):
            self.assertIn('ace_medical_ai_healQueue',source(name))
        building=source('buildingOperationStep')
        available=building.split('private _actorAvailable=',1)[1].split('private _actorTaskFree=',1)[0]
        task_free=building.split('private _actorTaskFree=',1)[1].split('// Record only stops',1)[0]
        self.assertNotIn('ace_medical_ai_healQueue',available)
        self.assertIn('ace_medical_ai_healQueue',task_free)

        for name in ('dangerEngineMode','dangerEngineCanContinue','dangerEngineAct','dangerEngineRelease','dangerActionSelect','dangerReact'):
            queued=source(name)
            self.assertIn('getVariable ["ace_medical_ai_healQueue",[]]',queued)
            self.assertNotIn('setVariable ["ace_medical_ai_healQueue"',queued)

        for name in ('dangerEngineCanContinue','dangerEngineMode','dangerEngineAct','dangerEngineRelease'):
            actor_gate=source(name)
            self.assertIn('simulationEnabled _actor',actor_gate)
            self.assertIn('isObjectHidden _actor',actor_gate)
        release=source('dangerEngineRelease')
        self.assertIn('["ACTOR_DORMANT"] call _evidence',release)
        self.assertLess(release.index('["ACTOR_DORMANT"] call _evidence'),release.index('_actor setUnitPosWeak _prior'))

        release=source('dangerEngineRelease')
        guard=release.index('["ACTOR_RESERVATION"] call _evidence')
        self.assertLess(release.index('setVariable ["CBE_Danger_EngineResponse",nil]'),guard)
        self.assertIn('params ["_reason",["_retire",false]]',release)
        self.assertIn('if (_retire) then',release)
        self.assertNotIn('["ACTOR_RESERVATION",true]',release)
        self.assertNotIn('["NATIVE_TASK_OR_MEDICAL",true]',release)
        native=release.split('if ((_actor getVariable ["ace_medical_ai_healQueue",[]])',1)[1].split('private _prior=',1)[0]
        self.assertIn('fleeing _actor',native)
        act=source('dangerEngineAct')
        action_guard=act.split('// Recheck actor-level authority',1)[1].split('private _baseDelay=',1)[0]
        self.assertIn('_mode != "FORCED" && {fleeing _actor}',action_guard)
        self.assertLess(act.index('fleeing _actor'),act.index('playActionNow'))
        self.assertLess(act.index('fleeing _actor'),act.index('setUnitPosWeak'))
        self.assertIn('["STANCE_CHANGED",true]',release)
        self.assertIn('["RESTORED",true]',release)
        self.assertIn('!= _prior) exitWith {["RESTORE_PENDING"]',release)
        self.assertNotIn('_prior="AUTO"',release)
        brain=source('groupBrainStep')
        cleanup=source('dangerPostureStep')
        self.assertNotIn('private _pendingPosture=',brain)
        self.assertIn('count _pendingPosture > 64',cleanup)
        self.assertNotIn('units _group',cleanup)
        self.assertIn('CBE_Danger_StancePendingActors',release)
        self.assertIn('time >= (_proof select 2)',cleanup)
        self.assertEqual(cleanup.count('call CBE_fnc_DangerEngineRelease'),1)
        self.assertIn('_pendingPosture deleteAt 0',cleanup)
        self.assertLess(cleanup.index('setVariable ["CBE_Danger_StancePendingActors",_pendingPosture]'),cleanup.index('call CBE_fnc_DangerEngineRelease'))
        self.assertIn('CBE_Danger_EngineResponse',cleanup)
        self.assertNotIn('CortexQueueJob',cleanup)
        self.assertIn('CBE_fnc_DangerPostureStep',release)
        self.assertIn('"DANGER_POSTURE"] call CBE_fnc_CortexQueueJob',release)
        self.assertNotIn('format ["DANGER_POSTURE',release)
        self.assertIn('call CBE_fnc_SchedulerReconcile',release)
        self.assertIn('_actor in _pending || {count _pending < 64}',release)
        reconcile=source('schedulerReconcile')
        self.assertIn('case "POSTURE_CLEANUP"',reconcile)
        self.assertIn('CBE_Danger_PostureSchedulerActive',reconcile)
        scheduler=source('cortexSchedulerTick')
        self.assertIn('case "POSTURE_CLEANUP": {"CBE_Danger_PostureSchedulerActive"}',scheduler)
        self.assertIn('if (!_postureLeft) then {[] call CBE_fnc_SchedulerReconcile}',scheduler)
        stop=source('cortexStop')
        adoption=stop.split('private _postureOldEpoch=',1)[1].split('// Master stop owns this exact epoch edge.',1)[0]
        for proof in ('_postureProof select 4) isEqualTo _postureOldEpoch','toUpperANSI unitPos _postureActor',
                      'time < (_postureProof select 2)+30','CortexExternalTakeover','CortexZeusHeld'):
            self.assertIn(proof,adoption)
        self.assertIn('_postureRebound set [4,',adoption)
        self.assertNotIn('_postureRebound set [2,',adoption)

        queue=source('cortexQueueJob')
        self.assertIn('(_candidateState getOrDefault ["group",grpNull]) == _group',queue)
        self.assertIn('(_candidateState getOrDefault ["ownerEpoch",-1]) == (_state get "ownerEpoch")',queue)
        retirement=release.split('if (_retire) then {',1)[1].split('if (!_retire',1)[0]
        self.assertIn('private _receiptGroup=_lease select 5',retirement)
        self.assertIn('local _receiptGroup',retirement)
        self.assertIn('count _pendingRetirement <= 64',retirement)
        self.assertIn('_pendingRetirement deleteAt _retirementIndex',retirement)
        self.assertNotIn('setUnitPos',retirement)
        self.assertIn('call CBE_fnc_CortexQueueJob',release)
        self.assertIn('["subsystem","POSTURE_CLEANUP"]',release)
        scheduler=source('cortexSchedulerTick')
        self.assertIn('if (_subsystem in ["POSTURE_CLEANUP","SETTINGS_CLEANUP","HOLD_CLEANUP"]) then {_jobPaused=false}',scheduler)
        self.assertIn('private _jobPaused = _paused && {!_skillsJob}',scheduler)
        self.assertIn('private _stale = !_enabled',scheduler)
        self.assertIn('(_state getOrDefault ["ownerEpoch", -1]) !=',scheduler)
        self.assertNotIn('time+',cleanup)
        self.assertIn('time >= (_proof select 2)+30',cleanup)
        self.assertIn('RESTORE_WINDOW_EXPIRED',cleanup)
        self.assertIn('time < (_lease select 2)+30',release)
        self.assertLess(release.index('if (time >= (_lease select 2)+30) exitWith'),release.index('_actor setUnitPos "AUTO"'))
        self.assertLess(release.index('if (time >= (_lease select 2)+30) exitWith'),release.index('_actor setUnitPosWeak _prior'))
        self.assertIn('!finite (_lease select 2)',release)
        self.assertLess(guard,release.index('_actor setUnitPosWeak _prior'))
        self.assertIn('if ([_actor] call CBE_fnc_CortexActorMoveReserved) exitWith {',release)
        self.assertNotIn('enableAI',release)
        self.assertNotIn('doMove',release)

    def test_coordinated_locality_settling_is_finite_and_cannot_consume_sequence_early(self):
        text=source('cortexSupportMaintain')
        boundary=text.split('private _settling=',1)[1].split('} else {',1)[0]
        self.assertIn('serverTime+5',boundary)
        self.assertIn('CBE_AIPass_Epoch',boundary)
        gate='if (!_localityPending || {serverTime >= (_settling select 1)}) then {'
        self.assertLess(boundary.index(gate),boundary.index('CBE_fnc_CortexSupportBoundStart'))
        self.assertLess(boundary.index(gate),boundary.index('_state set ["supportBoundSequence"'))
        self.assertIn('"assaulting","supportBoundSettling","supportHoldAdoption","supportNativeMoves","supportCapacityRole","supportCapacityNextAt"]',text)
        self.assertGreaterEqual(text.count('deleteAt "supportBoundSettling"'),2)

    def test_cba_feedback_uses_separate_content_rows_for_title_and_body(self):
        text=source('aiTweaksNotifyLocal')
        self.assertIn('[[format ["%1 | %2", _title, _prefix]], [_message]] call CBA_fnc_notify;',text)
        self.assertNotIn('[format ["%1 | %2", _title, _prefix], _message] call CBA_fnc_notify',text)
        self.assertIn('if (!hasInterface) exitWith {false}',text)

    def test_engine_wait_and_recycle_share_operation_identity_without_squad_scan(self):
        act=source('dangerEngineAct')
        gate=source('dangerEngineCanContinue')
        recycle=source('dangerEngineRecycle')
        record=act.split('setVariable ["CBE_Danger_EngineResponse",',1)[1]
        self.assertIn('CBE_OperationGeneration',record)
        self.assertIn('CBE_AIPass_Epoch',record)
        self.assertIn('_group]]',record)
        identity=gate.split('private _response=',1)[1].split('// The full Zeus helper',1)[0]
        self.assertIn('if (!_initial && {count _response != 7',identity)
        self.assertIn('_response param [4,-1,[0]]',identity)
        self.assertIn('_response param [5,-1,[0]]',identity)
        self.assertIn('_response param [6,grpNull,[grpNull]]',identity)
        self.assertLess(identity.index('CBE_OperationGeneration'),identity.index('_response param [0'))
        self.assertIn('CBE_fnc_DangerEngineCanContinue',recycle.split('private _group=',1)[0])
        self.assertNotIn('units ',gate)
        self.assertNotIn('configOf',gate)
        self.assertNotIn('nearestObjects',gate)

    def test_cheap_specialist_wait_gate_recognises_runtime_and_animation_ownership(self):
        text=source('compatibilityExternalControl')
        self.assertIn('IMS_IsUnitInvicibleScripted',text)
        self.assertIn('IMS_ISAI',text)
        self.assertIn('animationState _subject',text)
        self.assertIn('_animation find "ims_" == 0',text)
        self.assertNotIn('configOf',text)
        self.assertNotIn('units ',text)
        gate=source('dangerEngineCanContinue')
        self.assertIn('private _parent=objectParent _actor;',gate)
        self.assertIn('!isNull _parent && {[_parent] call CBE_fnc_CompatibilityExternalControl}',gate)
        self.assertLess(gate.index('[_parent] call CBE_fnc_CompatibilityExternalControl'),
                        gate.index('private _response='))

    def test_reverse_cleanup_sends_no_stop_into_external_control(self):
        text=source('cortexVehicleReverseStep')
        release=text.split('private _release={',1)[1].split('if (toUpperANSI _mode',1)[0]
        self.assertIn('if (!([_group] call CBE_fnc_CortexExternalTakeover)',release)
        self.assertIn('isNil {_ownedVehicle getVariable "CBE_ExternalDrivingOwner"}',release)
        self.assertLess(release.index('CBE_ExternalDrivingOwner'),release.index('sendSimpleCommand'))
        self.assertLess(release.index('CBE_fnc_CortexExternalTakeover'),release.index('sendSimpleCommand'))
        self.assertIn('setVariable ["CBE_VehicleReverseOwner",nil,true]',release)

    def test_launcher_relocation_remains_mobile_under_immediate_danger(self):
        text=source('dangerEngineAct')
        guard=text.index('call CBE_fnc_CortexActorMoveReserved')
        self.assertLess(guard,text.index('if (_mode == "IMMEDIATE")'))
        self.assertIn('_committedMover=true',text)
        shared=source('cortexActorMoveReserved')
        self.assertIn('time >= (_lease select 2)',shared)
        self.assertNotIn('STATIC_SUPPORT',shared)
        self.assertNotIn('ANTI_ARMOUR',shared)

    def test_cover_arrival_does_not_force_return_into_exposure(self):
        text=source('dangerCoverStep')
        cleanup=text.split('if (count _lease >= 4) then {',1)[1].split('_group setVariable ["CBE_Danger_CoverLease",nil];',1)[0]
        self.assertIn('_distance > 2 || {_height > 1.5}',cleanup)
        self.assertIn('abs ((((expectedDestination _leasedActor) select 0) param [2,0])-(_leasedSpot param [2,0])) <= 1.5',cleanup)
        self.assertLess(cleanup.index('_distance > 2 || {_height > 1.5}'),cleanup.index('doFollow'))

    def test_remount_progress_removes_completed_passengers_without_extending_deadline(self):
        text=source('cortexGroupTick')
        self.assertIn('if (_pending isNotEqualTo _passengers)',text)
        self.assertIn('setVariable ["CBE_Cortex_Remount",[_deadline,+_pending],true]',text)

    def test_cross_group_boarding_hold_is_bounded_and_preserves_vehicle_ownership(self):
        vehicles=source('cortexVehicles')
        boarding=vehicles.split('private _boarding=_passengerGroup getVariable',1)[1].split('if (_valid)',1)[0]
        for required in ['isEqualType []','serverTime+60','!_movementOwned','_enemies isEqualTo []',
                         'CBE_fnc_CortexExternalTakeover','select [0,8]','_unit distance2D _vehicle <= 100',
                         'assignedVehicle _unit == _vehicle']:
            self.assertIn(required,boarding)
        tick=source('cortexGroupTick')
        self.assertIn('(serverTime+30) min _deadline',tick)

    def test_carried_static_retirement_yields_to_successor_operation(self):
        text=source('cortexStaticDeployStep')
        retirement=text.split('private _retire={',1)[1].split('private _enabled=',1)[0]
        self.assertIn('_commandFree=_commandFree ||',retirement)
        self.assertIn('CBE_fnc_CortexExternalTakeover',retirement)
        actor_gate=text.split('private _canReleaseActor=',1)[1].split('private _retire=',1)[0]
        self.assertIn('_actor in _operationActors',actor_gate)
        self.assertIn('[[_gunner] call _canReleaseActor,[_assistant] call _canReleaseActor]',retirement)
        self.assertLess(retirement.index('private _releaseActors='),retirement.index('[_gunner] call _clearActor'))
        self.assertIn('(_releaseActors select 0)',retirement)
        self.assertIn('(_releaseActors select _forEachIndex)',retirement)

        ownership=text.split('private _ownsActorMove=',1)[1].split('private _rememberActorMove=',1)[0]
        for proof in ['CBE_Danger_StaticMoveReceipt', '_record select 27', '_move',
                      '_record param [19,[],[[]]]']:
            self.assertIn(proof,ownership)
        self.assertIn('!([_actor] call _ownsActorMove)',actor_gate)
        admission=text.rsplit('private _deadline=time+18;',1)[1]
        self.assertLess(admission.index('_record set [27,_sequence]'),admission.index('_x doMove _deployPos'))
        marker_writes = re.findall(r'(?m)^\s*(_x|_gunner) setVariable \["CBE_Cortex_ActorMove",[^\n]+\];',text)
        self.assertEqual(len(marker_writes), text.count('call _rememberActorMove;'))

        self.assertIn('(_record param [19,[],[[]]]) isNotEqualTo [clientOwner,_group getVariable ["CBE_AIPass_Epoch",0]]',retirement)
        self.assertIn('((_record param [19,[],[[]]]) param [0,-1,[0]]) == clientOwner',retirement)
        self.assertLess(retirement.index('_commandFree=_commandFree'),retirement.index('if (!_commandFree)'))

    def test_anti_armour_cleanup_does_not_erase_another_actor_move(self):
        text=source('cortexAntiArmour')
        section=text.split('private _relocation =',1)[1].split('if (_relocationBlocks',1)[0]
        self.assertIn('(_actorMove select 0) == "ANTI_ARMOUR"',section)
        self.assertIn('(_actorMove select 1) distance2D _relocationSpot < 1',section)
        self.assertIn('(_actorMove select 2) == _relocationUntil',section)
        for guard in ('_actorMove isEqualType []','(_actorMove select 1) isEqualType []',
                      'count (_actorMove select 1) == 3','finite (_actorMove select 2)'):
            self.assertIn(guard,section)
        self.assertLess(section.index('(_actorMove select 1) isEqualType []'),section.index('(_actorMove select 1) distance2D'))


    def test_cover_cleanup_preserves_replaced_native_destination(self):
        text=source('dangerCoverStep')
        cleanup=text.split('if (count _lease >= 4) then {',1)[1].split('_group setVariable ["CBE_Danger_CoverLease",nil];',1)[0]
        self.assertIn('(_actorMove select 2) == _expires',cleanup)
        self.assertIn('((expectedDestination _leasedActor) select 0) distance2D _leasedSpot <= 1',cleanup)
        self.assertIn('group _leasedActor == _group',cleanup)
        self.assertLess(cleanup.index('expectedDestination'),cleanup.index('doFollow'))

    def test_cover_retention_rechecks_live_authority_before_returning_active(self):
        text=source('dangerCoverStep')
        retention=text.split('if (!_releaseOnly && {_leaseContextCurrent} && {count _lease >= 4}',1)[1].split('exitWith {true};',1)[0]
        for gate in ['CBE_Danger_Generation','CBE_AIPass_Active','CBE_AIPass_Danger_Enable',
                     'CBE_fnc_CortexExternalTakeover','CBE_Operation','objectParent _actor']:
            self.assertIn(gate,retention)

    def test_group_hide_retires_old_generation_without_leaving_owned_stance(self):
        text=source('dangerGroupHideStep')
        section=text.split('if (_leases isNotEqualTo []) exitWith {',1)[1].split('private _valid=',1)[0]
        self.assertIn('_leaseGeneration != _generation',section)
        self.assertIn('_unit setUnitPosWeak _prior',section)
        self.assertIn('[_x] call _mayRestore',section)
        restore=text.split('private _mayRestore={',1)[1].split('private _release={',1)[0]
        self.assertIn('CBE_Danger_EngineStanceLease',restore)
        self.assertIn('CBE_Cortex_ActorMove',restore)
        self.assertIn('!fleeing _unit',restore)
        admission=text.split('private _candidates=',1)[1]
        self.assertIn('!fleeing _x',admission)
        self.assertIn('"DANGER_COVER"',restore)
        self.assertIn('currentCommand _unit in ["","MOVE","ATTACK","FIRE","SUPPRESS"]',restore)
        self.assertIn('isNull objectParent _unit',section)
        self.assertIn('CBE_fnc_CompatibilityExternalControl',section)
        self.assertIn('!isPlayer _unit',section)
        deferred=text.split('private _deferRestore={',1)[1].split('// Individual handover',1)[0]
        self.assertIn('[_proof] call _sameOwner',deferred)
        self.assertIn('CBE_Danger_EngineStanceLease",[]]) isEqualTo []',deferred)
        self.assertIn('[_prior,_applied,time,',deferred)
        self.assertIn('call CBE_fnc_DangerEngineRelease',deferred)
        self.assertNotIn('waitAndExecute',deferred)
        self.assertNotIn('doMove',deferred)
        self.assertIn('call _deferRestore',section)


    def test_cover_candidate_uses_rotated_bounds_and_stays_in_search_radius(self):
        text=source('cortexFindCover')
        self.assertIn('_object worldToModel _threat',text)
        self.assertIn('_object modelToWorld',text)
        self.assertIn('_edge min ((_half select _axis)/_component)',text)
        self.assertIn('_candidate distance2D _position <= _radius',text)
        self.assertNotIn('min 8) + 0.8',text)

    def test_gunner_recovery_fixture_requires_a_dedicated_commander(self):
        text=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text()
        self.assertIn('private _contactVehicle=createVehicle ["O_APC_Tracked_02_cannon_F"',text)
        self.assertIn('DANGER-VEHICLE-recovery-crew-prerequisite',text)
        self.assertIn('_lostGunner != _recoveryCommander',text)

    def test_withdrawal_audit_snapshots_the_existing_replacement_waypoint(self):
        text=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text()
        self.assertIn('[_migrateGroup,false] call CBE_fnc_CortexZeusMark;',text)
        self.assertLess(text.index('_migrateGroup setCurrentWaypoint _replacementWP;'),
                        text.index('[_migrateGroup,true,_replacementWP select 1]'))
        self.assertIn('WITHDRAW-MIGRATION-zeus-exact-order',text)

    def test_tracked_reverse_lease_survives_without_a_forward_waypoint(self):
        text=source('cortexVehicles')
        self.assertIn('private _reverseActive=_movementOwner == "VEHICLE_WITHDRAW"',text)
        self.assertIn('_activeVehicleMove = _reverseActive ||',text)
        self.assertIn('(_reverse select 2) == (_group getVariable ["CBE_AIPass_Epoch",0])',text)
        self.assertIn('CBE_VehicleReverseOwner',text)

    def test_support_rally_does_not_capture_operating_vehicle_crews(self):
        text=source('cortexSupportApply')
        self.assertIn('private _operatingCrew = (units _group) findIf',text)
        self.assertIn('_x in [driver _platform,gunner _platform,commander _platform]',text)
        self.assertIn('&& {!_operatingCrew} && {count _footFit >= 3}',text)
        self.assertLess(text.index('&& {!_operatingCrew}'),text.index('call CBE_fnc_OperationStart'))

    def test_mounted_crews_do_not_receive_infantry_morale_or_reposition_orders(self):
        morale=source('cortexMorale')
        reposition=source('cortexTacticalReposition')
        self.assertIn('if (_alive findIf {!isNull objectParent _x} >= 0) exitWith',morale)
        self.assertLess(morale.index('!isNull objectParent'),morale.index('private _hasAT'))
        self.assertIn('alive _x && {!isNull objectParent _x}',reposition)
        self.assertLess(reposition.index('!isNull objectParent'),reposition.index('CBE_fnc_OperationStart'))

    def test_unlocked_door_audit_observes_entry_concurrently(self):
        text=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        self.assertIn('if (!_entered) then',text)
        self.assertNotIn('if (_doorOpened && {!_entered}) then',text)
        self.assertIn('_entryEvidence pushBack [netId _actor,_node,getPosASL _actor,time,_doorHouse animationSourcePhase _doorSource]',text)
        self.assertIn('(getPosASL _actor) vectorDistance (AGLToASL _x) <= 1.5',text)
        self.assertNotIn('private _doorOpened=[{_doorHouse animationSourcePhase',text)
        self.assertLess(text.index('["Clearance: entry unlocked"'),text.index('_doorHouse setVariable ["bis_disabled_Door_1",0,true]'))

    def test_clearance_terminal_recall_yields_native_actor_tasks(self):
        text=source('buildingOperationStep')
        self.assertIn('if (_restore && {[_x] call _actorTaskFree}',text)
        self.assertLess(text.index('if (_restore && {[_x] call _actorTaskFree}'),text.index('_x doFollow _leader;'))

    def test_clearance_route_trace_reports_actual_terminal_outcome(self):
        text=source('buildingOperationStep')
        self.assertIn('private _routeEvidence=[serverTime,_result,_routeStates',text)
        self.assertLess(text.index('private _result = ["INCOMPLETE","COMPLETE"]'),text.index('private _routeEvidence='))
        self.assertIn('},_reason,_stageEvidence,(keys (_job getOrDefault ["earlyExits",createHashMap])) apply {',text)
        self.assertIn('+((_job get "earlyExits") get _x)',text)
        self.assertIn('keys _stageRecords select [0,16]',text)
        self.assertIn('_stageCounts getOrDefault [_x,0]',text)

    def test_native_room_revisit_preserves_first_pass_and_requires_arrival(self):
        text=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        start=text.index('private _revisitCases=[];')
        end=text.index('forEach _revisitCases;',start)+len('forEach _revisitCases;')
        revisit=text[start:end]
        self.assertLess(text.index('["BUILD-PLACEMENT-"+_label'),start)
        self.assertIn('private _revisitDeadline=time+180;',revisit)
        self.assertIn('if (_arrived) then {_seen set [_cursor,true]}',revisit)
        self.assertIn('vectorDistance (AGLToASL (_nodes select _cursor)) <= 1.5',revisit)
        self.assertNotIn('setPos',revisit)

    def test_clearance_does_not_abandon_rooms_before_every_lane_attempts(self):
        text=source('buildingOperationStep')
        self.assertIn('private _failureThreshold=(count (_job get "pairs")) max 1;',text)
        self.assertNotIn('private _failureThreshold=(count (_job get "pairs")) min 2',text)
        self.assertIn('private _roomRetryBudget=3*_failureThreshold;',text)
        self.assertIn('serverTime > (_job get "deadline")',text)
        self.assertIn('private _capablePairIds=[]',text)
        self.assertIn('!(netId _x in _earlyExits)',text)
        self.assertIn('if (_failureRosterChanged && {call _mayIssueMovement})',text)
        self.assertIn('forEach (+_pendingFailures)',text)
        self.assertIn('_capablePairIds isNotEqualTo []',text)
        self.assertIn('_capablePairIds findIf {!(_x in _failures)} < 0',text)
        # Only failures of remaining capable lanes count; no lanes is not exhaustion proof.
        capable={'PAIR_1','PAIR_3'}
        self.assertFalse(bool(capable) and capable <= {'PAIR_0','PAIR_1'})
        self.assertTrue(bool(capable) and capable <= {'PAIR_1','PAIR_3'})
        self.assertFalse(bool(set()) and set() <= {'PAIR_0'})


    def test_garrison_world_position_cache_invalidates_building_transforms(self):
        text=source('cortexGarrisonApplyLocal')
        self.assertIn('private _transform=[getPosWorld _building,vectorDir _building,vectorUp _building]',text)
        self.assertIn('(_cached select 2) isNotEqualTo _transform',text)
        self.assertIn('_cached=[_damage,+(_building buildingPos -1),_transform]',text)
        self.assertIn('count _cached < 3',text)

    def test_clearance_transform_changes_retire_before_room_or_egress_commands(self):
        text=source('buildingOperationStep')
        self.assertLess(text.index('private _actorTaskFree={'),text.index('private _finish = {'))
        self.assertLess(text.index('[true,"BUILDING_MOVED"] call _finish'),text.index('== "EGRESS"'))
        self.assertIn('_buildingTransform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]',text)
        self.assertIn('["buildingTransform",+_admissionTransform]',source('cortexClearBuilding'))

    def test_clearance_building_transform_audit_requires_real_cancel_and_entry(self):
        text=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=text.split('// Moving the building is the administrative stimulus;',1)[1].split('// A casualty inside',1)[0]
        self.assertIn('_movedHouse setDir 90;',case)
        self.assertIn('== "BUILDING_MOVED"',case)
        self.assertIn('[_actor,_movedHouse,_x] call _observedRoomVisit',case)
        self.assertIn('_transformEntries findIf {!_x} < 0',case)
        self.assertEqual(case.count('call CBE_fnc_CortexClearBuilding'),4)
        self.assertNotIn('_actor setPos',case)

    def test_clearance_entry_timing_comes_from_independent_physical_visits(self):
        case=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        observed=case.split('private _workerIndex=_forEachIndex;',1)[1].split('} forEach _clearingMembers;',1)[0]
        self.assertLess(observed.index('call _observedRoomVisit'),observed.index('_memberFirstVisit set'))
        self.assertIn('_seen isNotEqualTo []',observed)
        self.assertIn('(_memberFirstVisit select _workerIndex) < 0',observed)
        self.assertIn('CBE CLEAR FIRST PHYSICAL ENTRY',observed)
        self.assertIn('CBE CLEAR PHYSICAL ENTRY TIMING',case)
        self.assertIn('_admissionPairs findIf {_worker in _x}',case)
        self.assertNotIn('lineIntersectsSurfaces',observed)
        self.assertNotIn('setVariable',observed)

    def test_clearance_partner_entry_is_committed_and_doors_require_proximity(self):
        step=source('buildingOperationStep')
        self.assertIn('pairEntryTargets',step)
        self.assertIn('count _pair > 1 && {!_partnerEntered} && {!_approachingEntry}',step)
        self.assertIn('lineIntersectsSurfaces [_origin',step)
        self.assertIn('_ranked resize ((count _ranked) min 24)',step)
        self.assertIn('_allWorkersEntered',step)
        self.assertIn('_enteredActors pushBackUnique _visitor',step)
        door=source('cortexBuildingDoor')
        self.assertIn('vectorDistance _position <= 3',door)
        self.assertIn('(_position select 2)) <= 1.5',door)

    def test_clearance_deadline_cannot_fabricate_partner_entry_success(self):
        text=source('buildingOperationStep')
        expiry=text.index('if (serverTime > ((_job get "deadline") min (_job getOrDefault ["hardDeadline",_job get "deadline"]))) exitWith {',text.index('private _beginEgress='))
        self.assertLess(expiry,text.index('// Refill casualties'))
        self.assertLess(expiry,text.index('private _visitIndices='))
        self.assertLess(expiry,text.index('_job set ["deadline",(_job get "deadline") max (serverTime+120)]'))
        self.assertIn('] call _beginEgress',text[expiry:text.index('// Refill casualties')])
        self.assertIn('[_activeWorkers,_allWorkersEntered,_allWorkersProgressed] call _beginEgress',text)
        self.assertEqual(text.count('_job set ["egressDeadlineServer",serverTime+45]'),1)
        self.assertIn('|| {!_egressEntered} || {!_egressProgressed}',text)
        self.assertIn('(_job getOrDefault ["entryFailed",false])',text)
        result=text.split('private _result =',1)[1].split('_group setVariable ["CBE_Cortex_ClearResult"',1)[0]
        self.assertIn('!(_job getOrDefault ["entryFailed",false])',result)

    def test_clearance_partner_recovery_is_independent_and_generation_bounded(self):
        text=source('buildingOperationStep')
        block=text.split('// Partner entry recovery is independent',1)[1].split('// Persist retirement',1)[0]
        self.assertIn('[_partner,_entryTarget] call _recoverClearActor',block)
        self.assertIn('call _recoverClearActor',block)
        self.assertIn('_receipt set [2,true]',block)
        self.assertNotIn('_lastProgress=',block)
        self.assertNotIn('_cursor=',block)

    def test_new_buddy_selection_is_nearest_without_breaking_intact_pairs(self):
        pairs=source('combatPairs')
        self.assertLess(pairs.index('} forEach (_previous select [0,16])'),pairs.index('private _takeNearest='))
        nearest=pairs.split('private _takeNearest={',1)[1].split('} forEach _orphans',1)[0]
        self.assertIn('(getPosASL _x) vectorDistance _origin',nearest)
        self.assertIn('if (_distance < _bestDistance)',nearest)
        self.assertIn('_remaining deleteAt _bestIndex',nearest)
        self.assertEqual(pairs.count('call _takeNearest'),2)
        for forbidden in ('allUnits','nearEntities','doMove','doFollow','getPosATL _enemy'):
            self.assertNotIn(forbidden,pairs)
        # Selection model checks 3D proximity and stable roster ties, not native movement.
        from math import dist
        def partner(anchor,remaining,positions):
            return min(enumerate(remaining),key=lambda row:(dist(positions[anchor],positions[row[1]]),row[0]))[1]
        positions={'a':(0,0,0),'far':(30,0,0),'near':(2,0,0),'upper':(0,0,8),'tie':(-2,0,0)}
        self.assertEqual(partner('a',['far','near'],positions),'near')
        self.assertEqual(partner('a',['upper','near'],positions),'near')
        self.assertEqual(partner('a',['tie','near'],positions),'tie')

    def test_shared_infantry_pairs_are_owner_local_and_used_by_clearance(self):
        pairs=source('combatPairs')
        self.assertIn('!local _group',pairs)
        self.assertIn('count _actors > 16',pairs)
        self.assertIn('call CBE_fnc_CombatPairsPublish',pairs)
        self.assertNotIn('doMove',pairs)
        element=source('combatElementSelect')
        for guard in ('count _ranked > 16','_registry select [0,16]','count _selected+2 <= _maximum',
                      'count _selected >= _minimum','_candidates-_selected'):
            self.assertIn(guard,element)
        self.assertIn('count _incumbents > 16',element)
        self.assertIn('_ranked findIf {_x in _incumbents}',element)
        self.assertLess(element.index('private _selected=[];'),element.index('private _intact=[];'))
        self.assertIn('_x findIf {_x in _incumbents} >= 0',element)
        step=source('cortexFlankStep')
        layout=step.split('// Slot ordering is not a new roster/role assignment.',1)[1].split('_point=+_point;',1)[0]
        for proof in ('count _units <= 16','_slotPairs select [0,16]',
                      '_x findIf {!(_x in _units)} < 0','pushBackUnique (_partners select 0)',
                      'count _orderedMovers == count _units'):
            self.assertIn(proof,layout)
        for forbidden in ('doMove','setVariable','set ["teams"','CombatPairsPublish','getPos','lineIntersects'):
            self.assertNotIn(forbidden,layout)
        self.assertLess(step.index('_units=_orderedMovers'),step.index('private _issueNative='))
        self.assertIn('_drill set ["movers", +_units]',step)
        # Slot adjacency preserves the exact eligible roster and never imports a missing buddy.
        def ordered(roster,pairs):
            result=[]
            for actor in roster:
                if actor in result: continue
                result.append(actor)
                for row in pairs[:16]:
                    if not isinstance(row,list) or len(row)!=2 or row[0]==row[1]: continue
                    if actor in row and all(member in roster for member in row):
                        partner=next(member for member in row if member!=actor)
                        if partner not in result: result.append(partner)
                        break
            return result if len(result)==len(roster) else roster
        layout_pairs=[['a','b'],['c','d']]
        for roster,expected in [(['a','c','d','b'],['a','b','c','d']),
                                (['b','a','d','c'],['b','a','d','c']),
                                (['a','c','b','e','d'],['a','b','c','d','e']),
                                (['a','c','d'],['a','c','d'])]:
            result=ordered(roster,layout_pairs)
            self.assertEqual(result,expected)
            self.assertCountEqual(result,roster)
            self.assertEqual(len(result),len(set(result)))
        self.assertEqual(ordered(['a','c','d'],[['a'],'bad',['a','x'],['c','c']]),['a','c','d'])
        self.assertIn('_candidates=_candidates-_selected',element)
        for mutation in ('doMove','doSuppressiveFire','setVariable','enableAI','disableAI'):
            self.assertNotIn(mutation,element)
        for caller in ('cortexAdvanceStart','cortexFlankStart','cortexAssaultStart'):
            self.assertIn('call CBE_fnc_CombatElementSelect',source(caller))
            self.assertIn('select [0,16]) apply',source(caller))

        roles=source('combatPairElements')
        for marker in ('count _actors > 16','_pairs select [0,16]','_a in _priorFirst',
                       '_b in _priorFirst','_actors-_assigned','[_first,_second]'):
            self.assertIn(marker,roles)
        for forbidden in ('doMove','doSuppressiveFire','setVariable','enableAI','disableAI'):
            self.assertNotIn(forbidden,roles)
        advance=source('cortexAdvanceStart')
        self.assertIn('count _armedFoot == count _onFoot',advance)
        self.assertIn('call CBE_fnc_CombatPairElements',advance)
        self.assertIn('_buddyPair || {_buddyBounds}',advance)
        self.assertIn('_bound=_bound min 25',advance)
        self.assertIn('["buddyBounds",_buddyBounds]',advance)
        self.assertIn('"buddyBounds"',source('cortexCheckpoint'))
        self.assertIn('(_drill getOrDefault ["buddyBounds",false]) isEqualTo true',source('rebalanceRoles'))
        self.assertIn('(_operation getOrDefault ["intent",""]) == "ADVANCE" && {count _current == 2}',source('rebalanceRoles'))

        self.assertIn('_drill get "teamTurn",_fit,true',source('cortexFlankStep'))
        def partition(actors,pairs,previous=((),())):
            first=[];second=[];assigned=[]
            for pair in pairs[:16]:
                if len(pair)!=2 or pair[0]==pair[1] or any(x not in actors or x in assigned for x in pair):continue
                a,b=pair
                if a in previous[0] and b in previous[1]:swap=False
                elif b in previous[0] and a in previous[1]:swap=True
                else:swap=actors.index(b)<actors.index(a)
                first.append(b if swap else a);second.append(a if swap else b);assigned.extend(pair)
            for actor in actors:
                if actor not in assigned:(first if len(first)<=len(second) else second).append(actor)
            return first,second
        for count in range(2,17):
            actors=list(range(count));model_pairs=[actors[i:i+2] for i in range(0,count,2)]
            first,second=partition(actors,model_pairs)
            self.assertCountEqual(first+second,actors)
            self.assertEqual(len(set(first+second)),count)
            self.assertLessEqual(abs(len(first)-len(second)),1)
            for pair in model_pairs:
                if len(pair)==2:self.assertEqual(sum(x in first for x in pair),1)
            self.assertEqual(partition(list(reversed(actors)),model_pairs,(first,second)),(first,second))
        self.assertEqual(partition(['a','b','c'],[['a','b']]),(['a','c'],['b']))
        self.assertEqual(partition(['a','b','c','d'],[['a','b'],['a','c'],['c','d']]),(['a','c'],['b','d']))
        self.assertIn('call CBE_fnc_CombatPairs',source('cortexClearBuilding'))
        self.assertIn('["pairs",_pairs]',source('operationStart'))
        start=source('operationStart')
        self.assertIn('[_group,_element,false] call CBE_fnc_CombatPairs',start)
        self.assertIn('[_group,_pairs] call CBE_fnc_CombatPairsPublish',start)
        self.assertLess(start.index('private _partitionValid='),start.index('call CBE_fnc_OperationCancel'))
        self.assertIn('count (_partitioned arrayIntersect _partitioned) != count _partitioned',start)
        partition_gate=start.split('private _partitionValid=',1)[1].split('_pairElements=_pairElements apply',1)[0]
        self.assertIn('count _x > count _participants',partition_gate)
        self.assertLess(partition_gate.index('count _x > count _participants'),partition_gate.index('_x findIf'))
        self.assertLess(partition_gate.index('count _x > count _participants'),partition_gate.index('_partitioned append'))
        self.assertIn('_participants findIf {!(_x in _partitioned)}',start)
        self.assertIn('if (_publish) then',pairs)
        advance=source('cortexAdvanceStart')
        self.assertIn('"MANOEUVRE",_pairElements]',advance)
        self.assertIn('if (_buddyPair || {_buddyBounds}) then {[]} else {[_element,_coverElement]}',advance)
        self.assertIn('count _onFoot == 2 && {count _armedFoot == 2}',advance)
        self.assertIn('if (_smallElement) then {_bound=_bound min 20}',advance)
        self.assertIn('_group,if (_smallElement) then {20} else {[0,25] select _buddyBounds}] call CBE_fnc_CortexPlanRoute',advance)
        self.assertIn('_bound=_bound min (_maximumBound max 15)',source('cortexPlanRoute'))
        self.assertIn('if (count _coverRifles < _minimumCover)',advance)
        self.assertIn('count _onFoot in [2,3] && {count _armedFoot == count _onFoot}',advance)
        self.assertIn('if (_smallElement && {!_buddyPair}) then {_size=2 min count _candidates}',advance)
        self.assertIn('if (_type == "ADVANCE" && {count _capable == 2 || {(_drill getOrDefault ["buddyBounds",false]) isEqualTo true}}) then {_pairElements=[]}',source('cortexDrillResume'))
        self.assertIn('"ASSAULT",[_assaultElement,_coverElement]',source('cortexAssaultStart'))

        rebalance=source('rebalanceRoles')
        for proof in ('_pairs=[_group,_current] call CBE_fnc_CombatPairs',
                      '[_group,_x,false] call CBE_fnc_CombatPairs',
                      '[_group,_pairs] call CBE_fnc_CombatPairsPublish',
                      '_pairElements isNotEqualTo (_operation getOrDefault ["pairElements",[]])',
                      'getOrDefault ["operationGeneration",-1]) == _generation',
                      'getOrDefault ["ownerEpoch",-1]) == _entryEpoch'):
            self.assertIn(proof,rebalance)
        self.assertIn('_operationPhase,_pairElements] call CBE_fnc_OperationStart',source('cortexDrillResume'))
        publisher=source('combatPairsPublish')
        for gate in ('count _active > 16','count _merged >= 16','_x in _seen',
                     '_merged isNotEqualTo _previous','remoteExecutedOwner != 2'):
            self.assertIn(gate,publisher)
        for forbidden in ('doMove','CortexCombatEffective','simulationEnabled','checkAIFeature','waitAndExecute'):
            self.assertNotIn(forbidden,publisher)
        def publish(active,previous):
            result=[list(row) for row in active];seen={actor for row in result for actor in row}
            for row in previous[:16]:
                if len(result)>=16:break
                if row and len(row)<=2:
                    retained=list(dict.fromkeys(actor for actor in row if actor not in seen))
                    if retained:
                        result.append(retained);seen.update(retained)
            return result
        self.assertIn('&& {!(_x in _seen)}',publisher)
        self.assertEqual(publish([['a','b']],[['a','b'],['c','d']]),[['a','b'],['c','d']])
        self.assertEqual(publish([['a']],[['a','b']]),[['a'],['b']])
        self.assertEqual(publish([['a','c']],[['a','b'],['c','d'],['e','f']]),[['a','c'],['b'],['d'],['e','f']])
        self.assertEqual(publish([['a']],[['x','y'],['x','z']]),[['a'],['x','y'],['z']])
        self.assertLessEqual(len(publish([['active']],[[str(i)] for i in range(20)])),16)


    def test_clearance_replacement_updates_shared_pairs_without_restarting_routes(self):
        text=source('buildingOperationStep')
        retention=text.split('private _retainedEvasion={',1)[1].split('private _actorAvailable=',1)[0]
        for proof in ('(_lease select 2)-time <= 4','(_return select 2) isEqualTo (_lease select 2)',
                      '_native isEqualTo (_receipt select 3)','(_return select 5) == clientOwner'):
            self.assertIn(proof,retention)
        for forbidden in ('doMove','setVariable','deadline",'):
            self.assertNotIn(forbidden,retention.split('// This is not escape progress',1)[-1])
        handback=text.split('private _evasionReturnOwned={',1)[1].split('// Preserve native replacement tasks',1)[0]
        for proof in ('_issuer == clientOwner','_epoch == (_job get "ownerEpoch")',
                      '_operationId == (_job get "operationGeneration")','time >= _expiry',
                      '_live vectorDistance _escape <= 0.25','CBE_Cortex_ClearMotion',
                      '_reservation isEqualTo [] ||'):
            self.assertIn(proof,handback)
        self.assertIn('private _unitIssue=_issue || {[_unit] call _evasionReturnOwned}',text)
        for proof in ('private _evadingWorkers=', '[_x,true] call _actorAvailable',
                      'if (_pair findIf {_x in _evadingWorkers} >= 0) then {continue}',
                      'if (_laneRoster findIf {_x in _evadingWorkers} >= 0) then {continue}',
                      '_activeWorkers isEqualTo [] && {_evadingWorkers isEqualTo []}',
                      '_native vectorDistance (_lease select 1) <= 0.25',
                      '(_lease select 2)-time <= 6'):
            self.assertIn(proof,text)
        update=text.split('if (_pairRosterChanged) then {',1)[1].split('// Release reservations before selection',1)[0]
        self.assertIn('[_group,_pairSnapshot] call CBE_fnc_CombatPairsPublish',update)
        self.assertIn('_liveOperation set ["pairs",_pairSnapshot]',update)
        self.assertNotIn('_pairRoutes=',update)
        self.assertNotIn('_state set [0',update)

    def test_clearance_resume_refusals_precede_other_task_handoff(self):
        text=source('cortexClearBuilding')
        deadline=text.index('if (serverTime >= (_deadline min _hardDeadline)) exitWith')
        changed_order=text.index('if (_resume && {(_previous param [9,_nativeOrderReceipt')
        for cleanup in ('call CBE_fnc_CortexReleaseGroup',
                        'call CBE_fnc_CortexGarrisonRelease','call CBE_fnc_CortexDefendRelease'):
            self.assertLess(deadline,text.index(cleanup))
            self.assertLess(changed_order,text.index(cleanup))
        handoff=text.index('private _preserveBrain=_options')
        capture=text.index('_nativeOrderReceipt=[_group] call CBE_fnc_NativeOrderReceipt;',handoff)
        self.assertLess(text.index('call CBE_fnc_CortexDefendRelease'),capture)
        self.assertLess(capture,text.index('setVariable ["CBE_AIPass_ClearOrder"'))
        baseline=text.index('if (!_resume) then {_baseAttack=attackEnabled _leader}')
        self.assertLess(capture,baseline)
        self.assertLess(baseline,text.index('setVariable ["CBE_AIPass_ClearOrder"'))

    def test_clearance_refusal_identifies_bounded_actor_admission_evidence(self):
        text=source('cortexClearBuilding')
        self.assertIn('(units _group) select [0,16]',text)
        self.assertIn('["NO_ELIGIBLE_ACTORS"] call _refuse',text)
        self.assertIn('["GROUP_INELIGIBLE"] call _refuse',text)
        self.assertIn('_handoffFailure="OPERATION_REFUSED";',text)
        self.assertIn('if (!_handoffAccepted) exitWith {[_handoffFailure] call _refuse}',text)
        self.assertIn('currentCommand _x,getUnitState _x',text)

    def test_moved_building_focus_uses_the_shared_physical_case(self):
        server=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text()
        self.assertIn('[_check,_phase,_wait,false,true,true]',server)
        comparison=(ROOT / 'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        self.assertIn('if (!_transformOnly) then {',comparison)
        self.assertLess(comparison.index('CLEAR-transform-reorder-physical-entry'),comparison.index('if (_transformOnly) exitWith {}'))

    def test_clearance_replaces_only_its_recent_owned_native_recall(self):
        start=source('cortexClearBuilding')
        recall=start.split('private _ownedRecall={',1)[1].split('private _admissionGeneration',1)[0]
        for guard in ['currentCommand _actor == "JOIN"','_clearGeneration','CBE_AIPass_Epoch','== _leader','time < (_recall select 3)']:
            self.assertIn(guard,recall)
        self.assertLess(start.index('if (count _operation == 0) exitWith'),start.index('[_x,_generation-1] call _ownedRecall'))
        self.assertIn('CBE_Cortex_ClearRecall',source('buildingOperationStep'))
        self.assertIn('CBE_Cortex_ClearRecall',source('cortexClearRelease'))

    def test_shared_room_coverage_does_not_retire_unentered_lane(self):
        text=source('buildingOperationStep')
        self.assertIn('private _laneEntered=_entered || {_pair findIf {_x in (_job getOrDefault ["enteredActors",[]])} >= 0}',text)
        self.assertIn('in _cleared && {_laneEntered}',text)
        self.assertIn('if (_positionIndex in _cleared && {_laneEntered} && {!([_point] call _activeOwnMove)}) then {',text)
    def test_casualty_pair_snapshot_follows_replacement_loop(self):
        text=source('buildingOperationStep')
        self.assertLess(text.index('private _pairRosterChanged=false'),text.index('if (_pairRosterChanged) then'))
        self.assertLess(text.index('_pair set [_slot,_replacement]'),text.index('if (_pairRosterChanged) then'))
    def test_clearance_reserves_stage_once_and_release_owned_marker(self):
        step=source('buildingOperationStep')
        for marker in ['reserveStageAttempts','_stageReserves select [0,8]','_stageAttempts pushBackUnique _key','doStop _reserve','CBE_Cortex_ClearReserve']:
            self.assertIn(marker,step)
        self.assertIn('private _stageSearchBudget=1',step)
        self.assertIn('{_stageSearchBudget > 0}',step)
        self.assertLess(step.index('_stageSearchBudget=_stageSearchBudget-1'),step.index('_stageAttempts pushBackUnique _key'))
        release=source('cortexClearRelease')
        self.assertIn('CBE_Cortex_ClearReserve',release)
        self.assertIn('(_stage select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])',release)
    def test_reserve_budget_replay_is_episode_scoped_and_bounded(self):
        start=source('cortexClearBuilding')
        replay=start.split('// Keep reserve search consumption',1)[1].split('call CBE_fnc_BuildingOperationStart',1)[0]
        for guard in ['_resume','(_stageBudget select 0) == _building','(_stageBudget select 1) == _hardDeadline','(_stageBudget select 2) isEqualTo (_job get "buildingTransform")']:
            self.assertIn(guard,replay)
        self.assertIn('select [0,64]',replay)
        self.assertIn('(_count max 0) min 3',replay)
        history=replay.split('// A known casualty',1)[1].split('if (count _stage in [4,7]',1)[0]
        for gate in ('count _stage == 7','"ARRIVED"','!isNull _historicGuard',
                     '!alive _historicGuard','"INCAPACITATED"','"ACE_isUnconscious"',
                     '_stage select 0,_stage select 4,_stage select 5','!finite _x',
                     '"securityEntries"','if (_historicPost) then {_stages set [_key,+_stage]}'):
            self.assertIn(gate,history)
        for forbidden in ('setVariable','doMove','doStop','doWatch','_moves set','SettingsApply',
                          '_counts set','_job set','enableSimulation'):
            self.assertNotIn(forbidden,history)

        for command in [' doMove ', ' doFollow ', 'doStop ', ' setDestination ']:
            self.assertNotIn(command,replay)
        self.assertIn('_live vectorDistance _target <= 0.25',replay)
        self.assertIn('currentCommand _actor == "STOP"',replay)
        self.assertIn('vectorDistance (AGLToASL (_stage select 0)) <= 2',replay)
        self.assertIn('<= 0.75',replay)

        self.assertLess(start.index('_previous param [9,_nativeOrderReceipt'),start.index('// Keep reserve search consumption'))
        step=source('buildingOperationStep')
        publish=step.split('private _budgetRows=',1)[1].split('// Release reservations before selection',1)[0]
        self.assertIn('select [0,64]',publish)
        stage=step.split('private _stageSearchBudget=1;',1)[1].split('// Release reservations before selection',1)[0]
        self.assertLess(stage.index('if (_stageJournalChanged && {call _mayIssueMovement})'),stage.index('private _budgetRows='))
        original,rebalance=stage.split('// Rebalance one duplicated live post',1)
        self.assertEqual(original.count('_stageJournalChanged=true;'),5)
        # A new security allocation must consume and journal its attempt before geometry,
        # even if no safe endpoint is found. Migration must not replenish that search.
        admission=rebalance.split('if (_searchAdmitted) then {',1)[0]
        self.assertIn('_stageSearchCounts set [_candidateKey,_searchCount+1]',admission)
        self.assertIn('_stageJournalChanged=true;',admission)
        self.assertLess(rebalance.index('_stageJournalChanged=true;'),rebalance.index('call CBE_fnc_BuildingExteriorProposal'))
        self.assertIn('isNotEqualTo _stageBudget',publish)
        self.assertIn('setVariable ["CBE_Cortex_ClearStageBudget",_stageBudget,true]',publish)

    def test_reserve_recovery_preserves_successor_and_clearance_lifetime(self):
        step=source('buildingOperationStep')
        stage=step.split('private _reserveStages=',1)[1].split('private _pairRosterChanged=',1)[0]
        self.assertLess(stage.index('_stage set [2,"ARRIVED"]'),stage.index('// A deadline may retire only'))
        recovery=stage.split('// A deadline may retire only',1)[1].split('} forEach _stageReserves',1)[0]
        for guard in ['[_reserve,_stage select 0] call _reserveLegOwned','[_reserve] call _reserveReady','call _mayIssueMovement']:
            self.assertLess(recovery.index(guard),recovery.index('doStop _reserve'))
        self.assertIn('_stageSearchCounts getOrDefault [_key,0]',recovery)
        self.assertIn('"EXHAUSTED"',recovery)
        self.assertNotIn('doMove',recovery)
        self.assertNotIn('doFollow',recovery)
        self.assertNotIn('_job set ["deadline"',stage)
        self.assertNotIn('_job set ["hardDeadline"',stage)
        self.assertIn('_searchCount < 3',stage)
        self.assertIn('reserveStageTriedTargets',stage)
        self.assertIn('_stage set [3,serverTime+60]',stage)
        self.assertIn('serverTime >= (_stage param [3,1e12])',stage)
        self.assertNotIn('_stage set [3,time+',stage)


    def test_terminal_clearance_preserves_positions_even_when_result_is_incomplete(self):
        text=source('buildingOperationStep')
        branch=text.split('if (_reason == "COMPLETE") then {',1)[1].split('} else {',1)[0]
        self.assertIn('doStop _x',branch)
        self.assertNotIn('doFollow',branch)
        self.assertNotIn('setPos',branch)
    def test_post_clear_hold_handover_requires_changed_order_and_owner_receipt(self):
        text=source('groupBrainStep')
        branch=text.split('private _clearHold=',1)[1].split('private _legacyJob=',1)[0]
        for guard in ['CBE_AIPass_ClearGeneration','(_clearHold select 1) == _epoch','CBE_fnc_NativeOrderReceipt','currentCommand _x == "STOP"','CBE_fnc_CortexExternalTakeover','CBE_fnc_CompatibilityExternalControl','CBE_fnc_CortexActorMoveReserved','count (_group getVariable ["CBE_Operation",createHashMap]) == 0']:
            self.assertIn(guard,branch)
        self.assertLess(branch.index('CBE_Cortex_ClearHold",nil'),branch.index('_x doFollow _leader'))
        self.assertIn('[_x,_holdJob] call CBE_fnc_BuildingActorHoldOwned',branch)
        self.assertIn('createHashMapFromArray (_clearHold select 4)',branch)
    def test_post_clear_hold_defers_temporary_motion_loss_without_stale_recall(self):
        branch=source('groupBrainStep').split('private _clearHold=',1)[1].split('private _legacyJob=',1)[0]
        issue=branch.split('// A newer individual order retires',1)[0]
        for guard in ('simulationEnabled _x','!isObjectHidden _x','!fleeing _x','ace_medical_ai_healQueue'):
            self.assertLess(issue.index(guard),issue.index('_x doFollow'))
        self.assertNotIn('_x doMove',issue)
        defer=branch.split('// A newer individual order retires',1)[1]
        for guard in ('alive _x','isNull objectParent _x','currentCommand _x == "STOP"',
                      'CortexActorMoveReserved','!simulationEnabled _x','isObjectHidden _x',
                      '!(_x checkAIFeature "MOVE")','!(_x checkAIFeature "PATH")',
                      '!([_x] call CBE_fnc_CortexCombatEffective)',
                      'CortexExternalTakeover','CompatibilityExternalControl'):
            self.assertIn(guard,defer)
        self.assertIn('fleeing _x',defer)
        self.assertIn('ace_medical_ai_healQueue',defer)
        # An unchanged exact hold survives temporary treatment/flight; replacement commands do not.
        for medical,fleeing in ((True,False),(False,True),(True,True)):
            may_follow=not medical and not fleeing
            retain_exact_stop=medical or fleeing
            self.assertFalse(may_follow)
            self.assertTrue(retain_exact_stop)
        self.assertIn('_deferred pushBackUnique _x',defer)
        self.assertIn('_clearHold select 2,_deferred',defer)
        split=defer.split('if (!local _x',1)[1].split('if (local _x',1)[0]
        for proof in ('group _x == _group','alive _x','!isPlayer _x',
                      'isNull objectParent _x','currentCommand _x == "STOP"','_deferred pushBackUnique _x'):
            self.assertIn(proof,split)
        for forbidden in ('getPos','doMove','doFollow','setVariable','CortexClearSettingsApply'):
            self.assertNotIn(forbidden,split)

        for forbidden in ('doMove','doFollow','waitAndExecute','execFSM','enableAI'):
            self.assertNotIn(forbidden,defer)

    def test_post_clear_new_order_returns_leader_to_native_waypoint_semantics(self):
        branch=source('groupBrainStep').split('private _clearHold=',1)[1].split('private _legacyJob=',1)[0]
        self.assertEqual(branch.count('_x doFollow _leader'),1)
        self.assertIn('private _leader=leader _group',branch)
        # No leader-only MOVE shortcut: HOLD, scripted and attached tasks retain native ownership.
        for forbidden in ('_x == _leader','doMove','waypointPosition','setCurrentWaypoint',
                          'setWaypoint','deleteWaypoint','addWaypoint','call compile','enableAI'):
            self.assertNotIn(forbidden,branch)
        self.assertLess(branch.index('currentCommand _x == "STOP"'),branch.index('_x doFollow _leader'))
        self.assertLess(branch.index('CortexActorMoveReserved'),branch.index('_x doFollow _leader'))
        self.assertLess(branch.index('CBE_Cortex_ClearHold",nil'),branch.index('_x doFollow _leader'))

    def test_post_clear_hold_shutdown_releases_only_owned_stop(self):
        text=source('cortexReleaseGroup')
        branch=text.split('private _clearHold=',1)[1].split('// New curator intent',1)[0]
        for guard in ['CORTEX_STOPPED','!_externalTakeover','CBE_AIPass_ClearGeneration','CBE_AIPass_Epoch','currentCommand _x == "STOP"','CBE_fnc_CompatibilityExternalControl','CBE_Cortex_ActorMove']:
            self.assertIn(guard,branch)
        self.assertLess(branch.index('CBE_Cortex_ClearHold",nil'),branch.index('_x doFollow _anchor'))
    def test_shutdown_hold_retirement_is_finite_and_not_tactical(self):
        cleanup=source('clearHoldCleanupStep')
        stop=source('cortexStop')
        scheduler=source('cortexSchedulerTick')
        reconcile=source('schedulerReconcile')
        for token in ('serverTime >= (_window select 2)','CBE_Cortex_ClearHoldRetire','CBE_fnc_BuildingActorHoldOwned',
                      'CBE_fnc_CortexExternalTakeover','ace_medical_ai_healQueue','!fleeing _actor',
                      'CBE_fnc_CortexActorMoveReserved','!(_actor in _attempted)','_actors deleteAt 0'):
            self.assertIn(token,cleanup)
        self.assertEqual(cleanup.count('_actor doFollow _leader'),1)
        self.assertNotIn('doMove',cleanup)
        self.assertNotIn('serverTime+30',cleanup)
        self.assertIn('_retireWindow set [1,_retireHold select 1]',stop)
        self.assertIn('_retireUntil=_retireUntil min (_window select 2)',source('cortexReleaseGroup'))
        self.assertIn('CBE_Cortex_ClearHoldRetireAttempts',source('cortexReleaseGroup'))
        self.assertIn('CBE_fnc_ClearHoldCleanupStep',stop)
        self.assertIn('case "HOLD_CLEANUP"',scheduler)
        self.assertIn('case "HOLD_CLEANUP"',reconcile)
        self.assertIn('if (_holdsRetired)',scheduler)
        enable_gate=scheduler.split('private _jobs =',1)[0]
        self.assertIn('CBE_ClearHold_SchedulerActive',enable_gate)
        deadline=30
        attempted=set()
        for now,medical in ((1,True),(2,False),(3,False),(29,False),(30,False)):
            issue=now<deadline and not medical and 'actor' not in attempted
            if issue:attempted.add('actor')
            if now==1:self.assertFalse(issue)
            if now==2:self.assertTrue(issue)
            if now>=3:self.assertFalse(issue)
        self.assertEqual(len(attempted),1)

    def test_completed_clear_hold_adoption_changes_receipt_without_replaying_movement(self):
        text=source('cortexLocality')
        branch=text.split('private _clearHold=',1)[1].split('// Retire inherited simple driving',1)[0]
        for guard in ['count _actors <= 16','CBE_Operation','CBE_AIPass_ClearOrder','CBE_fnc_CortexExternalTakeover','_adoptedHold set [1','group _x == _group','_adoptedHold set [4']:
            self.assertIn(guard,branch)
        self.assertNotIn('doMove',branch)
        self.assertNotIn('doStop',branch)
        self.assertNotIn('doFollow',branch)
        self.assertLess(text.index('if (!_gained || {!local _group}) exitWith'),text.index('private _clearHold='))
    def test_locked_door_audit_observes_physical_entry_separately_from_animation(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        self.assertIn('CLEAR-door-locked-no-physical-entry',text)
        self.assertIn('_lockedEntryEvidence pushBack [netId _actor,_node,getPosASL _actor,time]',text)
        self.assertLess(text.index('CLEAR-door-locked-no-physical-entry'),text.index('_doorHouse setVariable ["bis_disabled_Door_1",0,true]'))

    def test_clearance_followthrough_requires_actual_per_actor_visits_and_finite_recovery(self):
        text=source('buildingOperationStep')
        self.assertIn('_visited pushBackUnique _positionIndex',text)
        follow=text.split('private _requiredVisits=',1)[1].split('private _active=[]',1)[0]
        self.assertIn('count _cleared == count _positions && {!_allWorkersProgressed}',follow)
        self.assertNotIn('&& {_allWorkersEntered}',follow)
        self.assertIn('_unit in (_job getOrDefault ["enteredActors",[]])',follow)
        self.assertIn('select [0,24]',follow)
        self.assertIn('_unit doMove _target',follow)
        self.assertIn('call _recoverClearActor',follow)
        self.assertIn('!(_record select 3)',follow)
        self.assertNotIn('_cleared pushBack',follow)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        self.assertIn('all-admitted-progress-through-interior',qa)
        self.assertIn('count (_memberVisits select _index) < (2 min count _rooms)',qa)

    def test_clearance_retired_workers_and_rejected_stages_do_not_recall_formation(self):
        text=source('buildingOperationStep')
        hold=text.split('private _quarantineHeld=',1)[1].split('private _reserveReady=',1)[0]
        self.assertIn('!(_x in _quarantineHeld)',hold)
        self.assertIn('[_x] call _actorAvailable',hold)
        self.assertIn('[_x] call _actorTaskFree',hold)
        self.assertIn('call _mayIssueMovement',hold)
        self.assertIn('doStop _x',hold)
        stage=text.split('private _reserveStages=',1)[1].split('private _pairRosterChanged=',1)[0]
        self.assertLess(stage.index('doStop _reserve'),stage.index('call CBE_fnc_BuildingExteriorCandidate'))
        geometry=source('buildingExteriorCandidate')
        self.assertIn('lineIntersectsSurfaces',geometry)
        reject=geometry[geometry.index('private _exitDistance='):geometry.index('// Prospective posts')]
        for proof in ('!_diagnostics','!_exterior','_blocksExit','_exitDistance < 3','_exitDistance > 18','exitWith {false}'):
            self.assertIn(proof,reject)
        self.assertLess(geometry.index('exitWith {false}',geometry.index('private _exitDistance=')),geometry.index('nearEntities'))
        self.assertIn('if (!_diagnostics && {_laneBlocked || {!_separated}}) exitWith {false}',geometry)
        step=source('buildingOperationStep')
        self.assertIn('_captureEntryEnabled || {missionNamespace getVariable ["CBE_AIPass_Debug",false]}',step)
        reserve=step.split('private _assessment=[_reserve',1)[1].split('// Two proposals per search',1)[0]
        self.assertEqual(reserve.count('_taken,_observerLanes,_proposalDiagnostics]'),2)
        self.assertIn('private _valid=if (_proposalDiagnostics) then {_assessment select 0} else {_assessment}',reserve)
        self.assertIn('private _emptyValid=if (_proposalDiagnostics) then {_emptyAssessment select 0} else {_emptyAssessment}',reserve)
        for line in reserve.splitlines():
            if 'diag_log format' in line:
                self.assertIn('if (_proposalDiagnostics) then',line)
        self.assertLess(geometry.index('private _separated='),geometry.index('private _observationClear='))


        self.assertNotIn('doMove',geometry)
        self.assertIn('_stage=[+_hold,true,"REJECTED"]',stage)
        self.assertIn('_stage=[+_target,false,"APPROACH"]',stage)
        self.assertIn('_stage set [2,"ARRIVED"]',stage)
        self.assertNotIn('doFollow',hold+stage)

    def test_clearance_wholly_locked_exterior_admission_waits_without_unlock_or_room_credit(self):
        text=source('buildingOperationStep')
        gate=text.split('// Before exterior actors commit',1)[1].split('== "EGRESS") exitWith',1)[0]
        self.assertIn('boundingBoxReal _building',gate)
        self.assertIn('_allLocked && {!_inside}',gate)
        self.assertIn('(_job get "deadline") min (_job getOrDefault ["hardDeadline"',gate)
        self.assertIn('!(_x in _held)',gate)
        self.assertIn('[_x] call _actorAvailable',gate)
        self.assertIn('call _mayIssueMovement',gate)
        self.assertNotIn('setVariable [format ["bis_disabled',gate)
        self.assertNotIn('_cleared pushBack',gate)
        self.assertNotIn('doMove',gate.replace('// Native doMove','// Native movement'))

    def test_clearance_new_native_order_releases_precompletion_holds_through_receipt(self):
        text=source('buildingOperationStep')
        branch=text.split('if (_reason == "NEW_ORDER"',1)[1].split('_group setVariable ["CBE_Cortex_ClearResult"',1)[0]
        for marker in ['accessHeld','quarantineHeld','securityActors','currentCommand _x == "STOP"','[_x] call _actorAvailable','CortexExternalTakeover','nativeOrderReceipt']:
            self.assertIn(marker,branch)
        self.assertNotIn('doMove',branch)
        self.assertIn('_destination vectorDistance _target <= 0.25',branch)
        self.assertIn('call CBE_fnc_NativeOrderReceipt) isNotEqualTo',branch)
        finish=text.split('private _finish =',1)[1].split('if (isNull _group || {!local _group} || {!(_group getVariable',1)[0]
        self.assertLess(finish.index('call CBE_fnc_OperationCancel'),finish.index('_actor doFollow leader _group'))
        self.assertLess(finish.index('CBE_Cortex_ClearHold",nil'),finish.index('_actor doFollow leader _group'))
        self.assertIn('CBE_Cortex_ClearRecall',finish)
        self.assertIn('leader _group,time+5',finish)
        active=finish.split('if (_reason == "NEW_ORDER" && {local _group}',1)[1].split('diag_log format ["[CBE]',1)[0]
        self.assertIn('_actor doFollow leader _group',active)
        for forbidden in ('doMove','waypointPosition','setCurrentWaypoint','setWaypoint','if (_actor == leader _group)'):
            self.assertNotIn(forbidden,active)

    def test_clearance_new_actor_order_audit_requires_ready_route_actual_travel_and_retirement(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=text.split('// A newer actor destination',1)[1]
        self.assertIn('movementTargets',case)
        self.assertIn('currentCommand _overrideActor == "MOVE"',case)
        self.assertIn('_destination vectorDistance _actorDestination <= 0.25',case)
        self.assertIn('_overrideActor distance2D _overrideStart >= 8',case)
        self.assertIn('== "NEW_ORDER"',case)
        self.assertLess(case.index('CLEAR-native-actor-order-preserved-physical'),case.index('call CBE_fnc_CortexClearRelease'))
        self.assertNotIn('setPos',case)

    def test_clearance_room_arrival_holds_preserve_stranded_worker_failure(self):
        text=source('buildingOperationStep')
        retired=text.split('private _quarantineHeld=',1)[1].split('private _reserveReady=',1)[0]
        self.assertIn('_job set ["entryFailed",true]',retired)
        arrival=text.split('// Native formation must not reclaim',1)[1].split('_assigned set',1)[0]
        self.assertIn('isNotEqualTo _speedTarget',arrival)
        self.assertIn('(getPosASL _unit) vectorDistance (AGLToASL _speedTarget) <= 1.5',arrival)
        self.assertIn('doStop _unit',arrival)
        self.assertIn('_roomHolds set [_holdKey,+_speedTarget]',arrival)
        handover=text.split('if (_reason == "NEW_ORDER"',1)[1].split('_group setVariable ["CBE_Cortex_ClearResult"',1)[0]
        self.assertIn('netId _x in _roomHolds',handover)

    def test_clearance_native_path_observer_is_bounded_and_removed_before_actor_cleanup(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        branch=text.split('private _pathHandlers=[]',1)[1].split('private _accepted=',1)[0]
        self.assertIn('addEventHandler ["PathCalculated"',branch)
        self.assertIn('>= 24',branch)
        self.assertIn('time+8',branch)
        self.assertIn('_path select [0,24]',branch)
        self.assertNotIn('doMove',branch)
        self.assertNotIn('calculatePath',branch)
        remove=text.index('removeEventHandler ["PathCalculated"')
        self.assertLess(remove,text.index('{deleteVehicle _x} forEach _members',remove))

    def test_clearance_keeps_native_room_destinations_without_geometry_offset_cache(self):
        text=source('buildingOperationStep')
        self.assertNotIn('floorTargets',text)
        self.assertNotIn('floorProbed',text)
        movement=text.split('private _roomMovementPoint={',1)[1].split('};',1)[0]
        self.assertIn('(_job get "positions") select _index',movement)
        self.assertNotIn('getPos',movement)
        self.assertIn('[_index] call _roomMovementPoint',text)
        self.assertIn('[_record select 0] call _roomMovementPoint',text)

    def test_clearance_active_handover_does_not_depend_on_live_group_brain(self):
        text=source('buildingOperationStep')
        release=text.split('if (_reason == "NEW_ORDER" && {local _group}',1)[1].split('diag_log format ["[CBE]',1)[0]
        for guard in ['CBE_AIPass_Epoch','CBE_AIPass_ClearGeneration','isEqualTo _brain',
                      'currentCommand _actor == _command','_command == "STOP"',
                      '_destination vectorDistance _target <= 0.25','CortexExternalTakeover','NativeOrderReceipt']:
            self.assertIn(guard,release)
        self.assertNotIn('CBE_GroupBrain',release)
