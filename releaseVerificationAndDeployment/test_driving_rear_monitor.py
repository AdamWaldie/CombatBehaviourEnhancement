"""Finite rear-leg safety and scheduler contracts, not native braking acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(n):return (ROOT/'addons/vehicles/functions'/f'{n}.sqf').read_text(encoding='utf-8')
class DrivingRearMonitorTests(unittest.TestCase):
    def test_exhaustion_cannot_create_or_replace_a_recovery_episode(self):
        text=src('drivingAssistStart')
        commit=text.split('private _exhaustedJournal=',1)[1].split('// Scheduled observations',1)[0]
        for proof in ('isNil {','call _mayIssueDriving','call _mayRecoverOrdinaryRoute',
                      'ownerEpoch','cancelled','finished','count _exhaustedJournal == 0',
                      'releasePending','isNotEqualTo _exhaustedJournal'):
            self.assertLess(commit.index(proof),commit.index('call _recordRecovery'))
        self.assertNotIn('doMove',commit)
        record=text.split('private _recordRecovery={',1)[1].split('private _reverseIssued=',1)[0]
        self.assertIn('private _sameEpisode=',record)
        self.assertIn('private _progressAnchor=if (_sameEpisode)',record)
        self.assertIn('_old getOrDefault ["progressAnchor",[]]',record)
        self.assertIn('["progressAnchor",_progressAnchor]',record)
        progress=text.split('private _routeProgress=true;',1)[1].split('// Reversing is a recovery leg',1)[0]
        self.assertIn('_progressAnchor distance2D _progressDestination',progress)
        self.assertNotIn('_progressPosition distance2D _progressDestination',progress)
        for proof in ('getOrDefault ["group",grpNull]','getOrDefault ["route",[]]',
                      '_progressAnchor isEqualType []','count _progressAnchor == 3','finite _x'):
            self.assertIn(proof,progress)
        # An ordinary forward return from either reverse cannot buy another
        # episode. Three metres beyond the original stalled point can.
        goal=100
        for rear in (-8,-3.5):
            for current in (rear,rear+3,0,2.9):
                self.assertFalse(abs(goal)-abs(goal-current)>=3)
            self.assertTrue(abs(goal)-abs(goal-3)>=3)
        self.assertTrue(abs(goal+8)-abs(goal+5)>=3)  # old rear-relative false credit


    def test_cap_and_restore_receipt_commit_together(self):
        text=src('drivingAssistStart')
        commit=text.split('private _capCommitted=false;',1)[1].split('if (!_capCommitted)',1)[0]
        for proof in ('isNil {','call _mayIssueDriving','ownerEpoch','cancelled','finished',
                      'isNotEqualTo _entryAssistState','isNotEqualTo _entryRestore','_entryForcedSpeed'):
            self.assertLess(commit.index(proof),commit.index('_vehicle forceSpeed _capMps'))
        self.assertIn('setVariable ["CBE_DrivingAssist_Restore",_previous]',commit)
        self.assertIn('setVariable ["CBE_DrivingAssist_State",_capReceipt]',commit)
        # Native failure must not fabricate a cap lease or discard its original baseline.
        confirmation='if (abs ((getForcedSpeed _vehicle)-_capMps) > 0.1) exitWith {false};'
        self.assertLess(commit.index('_vehicle forceSpeed _capMps;'),commit.index(confirmation))
        self.assertLess(commit.index(confirmation),commit.index('setVariable ["CBE_DrivingAssist_Restore",_previous]'))
        self.assertLess(commit.index(confirmation),commit.index('setVariable ["CBE_DrivingAssist_State",_capReceipt]'))
        self.assertLess(commit.index(confirmation),commit.index('setVariable ["CBE_DrivingCap_Issuer"'))
        self.assertIn('[clientOwner,_brain get "ownerEpoch",_brain get "generation"],_driver,effectiveCommander _vehicle',commit)
        fallback=commit.split('if (!_queueCommitted) then {',1)[1].split('private _issuedQueue=',1)[0]
        self.assertLess(fallback.index('_vehicle forceSpeed 0;'),fallback.index('abs (getForcedSpeed _vehicle) > 0.1'))
        failed,confirmed=fallback.split('} else {',1)
        self.assertIn('_capIssueComplete=false;',failed)
        self.assertNotIn('_capReceipt set [0,0]',failed)
        self.assertNotIn('setVariable ["CBE_DrivingAssist_State"',failed)
        self.assertIn('_capReceipt set [0,0]',confirmed)
        self.assertIn('_capCommitted=_capIssueComplete;',commit)
        self.assertIn('_entryAssistState=+_capReceipt',commit)
        self.assertNotIn('CBE_fnc_DrivingAssistRelease',text.split('if (!_capCommitted) then {',1)[1].split('} else {',1)[0])


    def test_final_state_publication_cannot_revive_retired_assistance(self):
        text=src('drivingAssistStart')
        self.assertIn('private _state=+_entryAssistState',text)
        commit=text.split('// Scheduled observations and cleanup above',1)[1]
        for proof in ('isNil {','call _mayIssueDriving','ownerEpoch','cancelled','finished',
                      'isNotEqualTo _entryAssistState','isNotEqualTo _previous','getForcedSpeed _vehicle'):
            self.assertLess(commit.index(proof),commit.index('setVariable ["CBE_DrivingAssist_State"'))
        self.assertIn('_updatedRecovery set ["cap",_capMps]',commit)
        self.assertIn('releasePending',commit)
        self.assertIn('driverCommand',commit)
        self.assertNotIn('_liveRecovery set ["cap"',commit)


    def test_forward_retries_commit_commands_and_preserve_deadline(self):
        text=src('drivingAssistStart')
        for stage,end,kind in ((0,'case 1:','REFRESH'),(2,'default {','FINAL')):
            case=text.split(f'case {stage}: {{',1)[1].split(end,1)[0]
            for guard in ('isNil {','call _mayIssueDriving','call _mayRecoverOrdinaryRoute',
                          'ownerEpoch','cancelled','finished','CBE_fnc_CortexFeatureEnabled',
                          'isNotEqualTo _forwardJournal','isNotEqualTo _forwardCommands','hardDeadline'):
                self.assertLess(case.index(guard),case.index('_movementOperator doMove _destination'))
            self.assertIn('_recoveryStage=4',case)
            self.assertIn(f'_recoveryUntil=["{kind}",[],"DESTINATION",[],[+_destination,serverTime+2,_forwardCommands]] call _recordRecovery',case)


    def test_rear_issue_and_journal_have_fresh_atomic_authority(self):
        text=src('drivingAssistStart')
        case=text.split('private _rearPose=',1)[1].split('case 2:',1)[0]
        self.assertLess(case.index('call CBE_fnc_DrivingRearPlan'),case.index('isNil {'))
        commit=case.split('isNil {',1)[1]
        for guard in ('call _mayIssueDriving','call _mayRecoverOrdinaryRoute','ownerEpoch',
                      'isNotEqualTo _rearJournal','hardDeadline','_rearPose select 2','cos 5','isNotEqualTo _rearCommands'):
            self.assertLess(commit.index(guard),commit.index('_movementOperator doMove _rear'))
        self.assertLess(commit.index('_movementOperator doMove _rear'),commit.index('call _recordRecovery'))
        self.assertIn('_driver != _movementOperator',commit)
        self.assertIn('(_rearSimpleBefore param [1,""]) == "NONE"',commit)
        self.assertEqual(commit.count('sendSimpleCommand "BACK"'),1)
        self.assertIn('_rearCommandMode="SIMPLE_BACK"',commit)
        self.assertLess(commit.index('sendSimpleCommand "BACK"'),commit.index('call _recordRecovery'))
        final=text.split('case 2: {',1)[1].split('default {',1)[0]
        self.assertLess(final.index('"SIMPLE_BACK") exitWith {false}'),final.index('_movementOperator doMove _destination'))

        self.assertIn('if (_recoveryTransitioned) then {',text)

    def test_reverse_requires_sampled_physical_support_not_terrain_water_only(self):
        text=src('drivingRearClear')
        support=text.split('private _supported=true;',1)[1].split('if (!_supported) exitWith {[false,"REAR_SUPPORT"',1)[0]
        self.assertIn('lineIntersectsSurfaces',support)
        self.assertIn('"GEOM","NONE"',support)
        self.assertIn('_hits isEqualTo []',support)
        self.assertIn('select 2) < 0.7',support)
        self.assertIn('_distance*0.5',support)
        self.assertNotIn('surfaceIsWater',support)
        self.assertNotIn('nearEntities',support)
        stable=text.split('private _stableSupport={',1)[1].split('private _supported=true;',1)[0]
        self.assertIn('if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2}',stable)
        self.assertIn('isNull _support ||',stable)
        self.assertIn('!(_support isKindOf "AllVehicles")',stable)
        self.assertIn('vectorMagnitude velocity _support <= 0.1',stable)
        self.assertNotIn('lineIntersectsSurfaces',stable)
        self.assertIn('[_hits select 0] call _stableSupport',support)
        target=text.split('private _targetHit=',1)[1].split('forEach _heights;',1)[0]
        self.assertIn('[_targetHit] call _stableSupport',target)
        self.assertLess(text.index('"REAR_SUPPORT"'),text.index('// Retain knee') if '// Retain knee' in text and text.index('// Retain knee') > text.index('"REAR_SUPPORT"') else text.index('forEach _heights;'))

    def test_nonfinite_rear_distance_refuses_before_queries_and_hull_work(self):
        text=src('drivingRearClear')
        guard='if (!finite _distance) exitWith {[false,"INVALID_REAR_DISTANCE",time,0]}'
        self.assertIn(guard,text)
        for operation in ['_distance=(_distance max 1) min 60','boundingBoxReal _vehicle','nearEntities','lineIntersectsSurfaces']:
            self.assertLess(text.index(guard),text.index(operation))

    def test_rear_observation_applies_before_speed_write_without_extending_deadline(self):
        s=src('drivingAssistStart')
        sample=s.split('if (_rearSafetyRequired) then {',1)[1].split('private _trafficLimited=',1)[0]
        self.assertIn('[_vehicle,_rearClearDistance] call CBE_fnc_DrivingRearClear',sample)
        self.assertIn('_traffic=[0,_vehicle,-1,time,0]',sample)
        self.assertNotIn('_recoveryUntil=',sample)
        self.assertLess(s.index('private _rearObservation='),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('private _pendingRear=_recoveryRequestPending && {_recoveryOwned} && {_reverseIssued}',s)
        self.assertIn('(_recoveryWork getOrDefault ["kind",""]) == "REVERSE"',s)
        self.assertIn('private _rearSafetyRequired=_reverseLeg || {_pendingRear}',s)
        plan=src('drivingRearPlan')
        self.assertIn('private _cbeRearPlanEnvelope=[8,6]',plan)
        self.assertIn('then {[8,6]} else {[3.5,2]}',plan)
        self.assertEqual(plan.count('call CBE_fnc_DrivingRearClear'),2)
        self.assertIn('call CBE_fnc_DrivingBypassApproach',plan)
        self.assertIn('== "BACKOFF"',plan)
        self.assertIn('_approach get "requiredBack"',plan)
        self.assertIn('_maximumTravel > 24',plan)
        self.assertIn('_cbeRearPlanEnvelope=[_travel+2,_travel]',plan)
        self.assertIn('CORNER_CONTEXT_CHANGED',plan)
        self.assertIn('(_hard-40) min (serverTime+_reverseSeconds)',s)
        self.assertIn('_cornerTravel=(floor (12*_cornerRate)) min 24',s)
        # Parent total remains fixed; longer reverse borrows time from final travel.
        for stop in (7,12,24):
            for now in (30,35.9):
                hard=96
                deadline=min(hard-40,now+min(16,max(6,stop/(10/3.6)+4)))
                self.assertGreater(deadline,now)
                self.assertLessEqual(deadline,hard-40)
                self.assertGreaterEqual(deadline-now,stop/(10/3.6))

        self.assertIn('} else {[]},_rearEnvelope] call _recordRecovery',s)
        short=plan.split('if (!(_cbeRearPlanClearance select 0)',1)[1]
        for failure in ('REAR_SCAN_BUDGET','DENSE_REAR_TRAFFIC','OWNER_UNAVAILABLE','REAR_TURN_ENVELOPE'):
            self.assertNotIn(failure,short)
        self.assertNotIn('while',short)
        self.assertNotIn('serverTime+',short)
        self.assertIn('&& {!_pendingRear || {_rearPathRejected}}',s)
        self.assertIn('private _mayRecoverOrdinaryRoute={!_queueCrossing && {!_queueNativeActive} && {!_recoveryRequestPending}',s)
        self.assertIn('if (_reverseExpired && {!_retryAllowed}) then {_traffic=[0,_vehicle,-1,time,0]}',s)
    def test_direction_and_issued_receipt_survive_stop_and_expire(self):
        s=src('drivingAssistStart')
        self.assertIn('_state param [10,',s)
        self.assertIn('_recoveryResult="CAUTIOUS_REVERSE";_reverseIssued=true',s)
        self.assertIn('_recoveryResult="REAR_BLOCKED";_reverseIssued=false',s)
        self.assertIn('_recoveryResult="FINAL_ROUTE_RETRY";_reverseIssued=false',s)
        self.assertIn('if (_rearSafetyRequired || {_queueNativeActive}) then {-1}',s)
        self.assertIn('_routeIdentity,_reverseIssued',s)
        observer=(ROOT/'addons/infantry/functions/cortexInfantrySpeed.sqf').read_text(encoding='utf-8')
        self.assertIn('["_travelIntent",0,[0]]',observer)
        self.assertIn('if (_travelIntent == 0)',observer)
    def test_existing_scheduler_samples_active_rear_stage_faster(self):
        self.assertIn('time+([4,1] select (_trafficLimited || {_trafficWatch} || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))',src('drivingAssistStart'))
        self.assertIn('_rearLeg=_rearLeg || {(_state param [6,0]) == 2}',src('drivingOperationStep'))
        self.assertIn('time+([4,1] select (_crewPending || {_traffic} || {_watchTraffic} || {_obstacle} || {_rearLeg} || {_corridor != ""} || {_bypass != ""} || {_passing}))',src('drivingOperationStep'))


    def test_rear_prediction_uses_simultaneous_intervals_and_finite_scan_budget(self):
        s=src('drivingRearClear')
        for marker in ('private _predictionSeconds=2','35*_predictionSeconds',
                       '_radius > 250','"REAR_SCAN_BUDGET"','"REAR_APPROACHING"',
                       'vectorDiff _ownVelocity','for "_axis" from 0 to 2',
                       '_entry=_entry max','_exit=_exit min','_entry <= _exit'):
            self.assertIn(marker,s)
        self.assertLess(s.index('if (_current) exitWith {true}'),s.index('private _relative='))
        self.assertEqual(s.count('nearEntities'),2)
        for forbidden in ('setVariable','sendSimpleCommand','forceSpeed','doMove','setVelocity'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])



    def test_tracked_reverse_commands_bind_seats_destinations_and_route(self):
        s=src('cortexVehicleReverseStep')
        for marker in ('CBE_VehicleReverse_Command','driver _ownedVehicle == (_commandReceipt select 1)',
                       'effectiveCommander _ownedVehicle == (_commandReceipt select 2)',
                       'expectedDestination (_commandReceipt select 1)',
                       'expectedDestination (_commandReceipt select 2)',
                       'CBE_fnc_DrivingRouteReceipt','COMMAND_OR_SEATS_CHANGED',
                       '"RELEASED"','bis_fnc_moduleRemoteControl_owner'):
            self.assertIn(marker,s)
        release=s.split('private _release={',1)[1].split('if (toUpperANSI _mode',1)[0]
        self.assertLess(release.index('call _commandsUnchanged'),release.index('sendSimpleCommand'))
        self.assertNotIn('(_record select 2) == (_group getVariable',release)
        self.assertIn('getVariable ["CBE_VehicleReverse",[]]) isEqualTo _entryRecord',release)
        vehicle=src('cortexVehicles')
        self.assertIn('if (_reverse == "FALLBACK") then',vehicle)
        self.assertIn('["RELEASED","FALLBACK"] select _fallbackAuthority',s)
        self.assertLess(s.index('COMMAND_OR_SEATS_CHANGED'),s.index('if (!_eligible) exitWith'))
        self.assertIn('_fallbackAuthority && {!_handover}',s)
        fallback=s.split('private _fallbackAuthority=',1)[1].split('private _eligible=',1)[0]
        for gate in ('ownerEpoch','CBE_AIPass_Epoch','CortexExternalTakeover','CBE_ExternalDrivingOwner'):
            self.assertIn(gate,fallback)
        group=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text(encoding='utf-8')
        self.assertIn('_reverseResult in ["COMPLETE","FALLBACK"]',group)



    def test_ordinary_recovery_has_owned_cleanup_and_original_stage_schedule(self):
        s=src('drivingAssistStart')
        for marker in ('CBE_DrivingRecovery_Work','CBE_DrivingRecovery_Yield',
                       'serverTime+96','_hard-66','_hard-60','["REFRESH",[],"DESTINATION",[],[+_destination,serverTime+2,_forwardCommands]] call _recordRecovery',
                       '["FINAL",[],"DESTINATION",[],[+_destination,serverTime+2,_forwardCommands]] call _recordRecovery','ADOPTED_RECOVERY','{_recoveryStage != 2} &&'):
            self.assertIn(marker,s)
        release=src('drivingRecoveryRelease')
        for marker in ('expectedDestination _driver','expectedDestination _operator',
                       'DrivingRouteReceipt','DrivingMovementAvailable','CortexExternalTakeover',
                       'isEqualTo _work','(_work get "kind") == "REVERSE"'):
            self.assertIn(marker,release)
        for forbidden in ('addWaypoint','deleteWaypoint','enableAI','setVelocity','setPos','spawn','waitUntil'):
            self.assertNotIn(forbidden,release.split('params [[',1)[1])
        self.assertIn('call CBE_fnc_DrivingRecoveryRelease',src('drivingAssistRelease'))
        self.assertIn('CBE_DrivingRecovery_Yield',src('drivingOperationStart'))


    def test_close_static_blockage_uses_fresh_dwell_and_existing_rear_executor(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        contact=s.split('private _solidCandidate=',1)[1].split('_capMps=_capMps min (_traffic select 0);',1)[0]
        for guard in ('_obstacleLimited','count _obstacleObservation == 9','== "STATIC"','<= 8',
                      '(_withoutObstacle select 0) > 0','_pedestrianCap > 0',
                      'serverTime-(_solidSeen select 2) <= 6','serverTime-_since >= 3',
                      'ownerEpoch','_routeIdentity','_obstacleObservation select 8'):
            self.assertIn(guard,contact)
        self.assertNotIn('lineIntersectsSurfaces',contact)
        self.assertNotIn('nearEntities',contact)
        self.assertNotIn(',true]',next(line for line in contact.splitlines() if 'setVariable ["CBE_DrivingSolidSeen",[' in line))
        self.assertIn('_trafficLimited && {!_solidCandidate}',s)
        self.assertIn('!_trafficLimited || {_solidReady} || {_reverseHandback}',s)
        self.assertIn('private _reverseHandback=_reverseComplete && {_reverseIssued}',s)
        self.assertIn('[_vehicle] call CBE_fnc_DrivingRearPlan',s)
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('setVariable ["CBE_DrivingSolidSeen",nil]',release)

    def test_rear_solid_beams_include_tall_hull_height_with_fixed_bound(self):
        s=src('drivingRearClear')
        self.assertIn('(_high select 2)-(_low select 2)',s)
        self.assertIn('_heights=_heights arrayIntersect _heights',s)
        self.assertIn('forEach _heights',s)
        # A beam at the3m hull top is not observed by the old knee/bumper rows.
        height=3
        old=[0.45,0.9]
        new=list(dict.fromkeys(old+[(height+0.45)*0.5,height]))
        self.assertNotIn(height,old)
        self.assertIn(height,new)
        self.assertLessEqual(len(new)*3,12)
        self.assertIn('ceil (_distance/4)',s)
        self.assertIn('(_station*4) min _distance',s)
        import math
        for quarter in range(4,241):
            distance=quarter/4
            depths=sorted(set([min(1,distance),distance/2,distance] if distance<=8
                             else [1]+[min(4*i,distance) for i in range(1,math.ceil(distance/4)+1)]))
            self.assertEqual(depths[-1],distance)
            self.assertLessEqual(len(depths),16)
            self.assertTrue(all(b-a<=4 for a,b in zip(depths,depths[1:])))
            self.assertLessEqual(3*len(depths)+1+60,109)
            if distance<=26:self.assertLessEqual(3*len(depths)+1+60,85)
            if distance<=8:self.assertLessEqual(3*len(depths)+1+60,70)

        self.assertTrue(all(h<=height for h in new))

if __name__=='__main__':unittest.main()
