"""Finished native convoy leg guards; models are not physical steering evidence."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyNativeEndpointTests(unittest.TestCase):
    def test_finished_leg_requires_physical_endpoint_and_exact_ownership(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        block=text.split('private _finishedLeg=',1)[1].split('if (count _committedDestination < 2',1)[0]
        for guard in ('count _committedDestination == 3','count _nativeReceipt == 4',
                      'local _vehicle','local _movementOperator','[_vehicle] call _convoyStopped',
                      'unitReady _movementOperator','currentCommand _movementOperator in ["","MOVE"]',
                      '_vehicle distance2D _committedDestination <= 3','ATLToASL _committedDestination',
                      '_committedDestination distance2D _destination > 3',
                      '(_nativeReceipt select 0) == driver _vehicle',
                      '(_nativeReceipt select 1) == _movementOperator',
                      '(expectedDestination driver _vehicle) isEqualTo (_nativeReceipt select 2)',
                      '(expectedDestination _movementOperator) isEqualTo (_nativeReceipt select 3)'):
            self.assertIn(guard,block)
        self.assertIn('count _committedDestination < 2 || {_refreshNative} || {_finishedLeg}',text)
        branch=text.split('count _committedDestination < 2 || {_refreshNative} || {_finishedLeg}',1)[1].split('_progress set [2, time + 1]',1)[0]
        self.assertLess(branch.index('call _mayIssueDriving'),branch.index('_movementOperator doMove'))
        self.assertIn('_progress set [10,[driver _vehicle,_movementOperator',branch)

    def test_native_retry_and_endpoint_share_finite_total_motion_gate(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=text.split('private _convoyStopped={',1)[1].split('private _leadProgress',1)[0]
        for guard in ('vectorMagnitude velocity _candidate','vectorMagnitude angularVelocity _candidate',
                      'finite _linear','finite _angular','_linear*3.6 < 1','_angular < 0.01'):
            self.assertIn(guard,gate)
        self.assertIn('[_lead] call _convoyStopped',text)
        self.assertIn('[_vehicle] call _convoyStopped',text)
        self.assertNotIn('setVelocity',gate)
        steering=text.split('private _finishedSteering=',1)[1].split('if (count _committedPathDestination < 2',1)[0]
        for guard in ('call _convoyStopped','_limit > 0','distance2D _committedPathDestination <= 3',
                      'ATLToASL _committedPathDestination','<= 1.5',
                      '_committedPathDestination distance2D _pathDestination > 3',
                      'CBE_AIPass_Epoch','_steeringLease select 3','_steeringLease select 4',
                      '_steeringLease select 6','_steeringLease select 7','_steeringReceipt select 2','_steeringReceipt select 3'):
            self.assertIn(guard,steering)
        self.assertIn('> 8} || {_finishedSteering}',text)
        # 4m of new trail is enough only for an owned, stopped endpoint; a moving
        # leg or a stalled vehicle far from that endpoint retains its current path.
        def continue_leg(owned,stopped,distance,height,advance,cap):
            return owned and stopped and distance<=3 and abs(height)<=1.5 and advance>3 and cap>0
        self.assertTrue(continue_leg(True,True,1,0,4,12))
        for args in ((False,True,1,0,4,12),(True,False,1,0,4,12),
                     (True,True,10,0,4,12),(True,True,1,3,4,12),(True,True,1,0,4,0)):
            self.assertFalse(continue_leg(*args))

        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text(encoding='utf-8')
        self.assertIn('count _event == 14',qa)
        self.assertIn('(vectorMagnitude _velocityAt)*3.6 < 1',qa)
        self.assertIn('vectorMagnitude _angularAt < 0.01',qa)
        self.assertIn('(_movementReceipt select 5) == "NATIVE"',qa)

    def test_normal_fixture_requires_real_trigger_and_physical_continuation(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        self.assertIn('CBE_CortexQA_HeadlessBatch',qa)
        block=qa.split('if (_endpointDiagnostic && {_timingOwnerLocal}) then {',1)[1].split('private _timingLimits=',1)[0]
        for marker in ('_advance > 3','_advance <= 8','_readyAt','abs _speedAt < 1',
                       'CBE_AIPass_Epoch','_eventRevision','getPosASL _vehicle',
                       'vectorNormalized _axis','_originDistance-2','CBE_Convoy_MovementReceipt',
                       'expectedDestination _operator','CBE_Convoy_CommandYield','CBE_Convoy_Active','_stillOwned'):
            self.assertIn(marker,block)
        for forbidden in ('doMove','doFollow','doStop','setPos','setVelocity','setDriveOnPath',
                          'setVariable ["CBE_Convoy_LocalState"'):
            self.assertNotIn(forbidden,block)
        self.assertIn('count _endpointObserved > 0 && {_endpointTravelled}',qa)
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('_state deleteAt "nativeEndpointAdvances"',tick)
        event=tick.split('private _endpointEvent=[];',1)[1].split('_progress set [5,+_destination]',1)[0]
        self.assertLess(event.index('getPosASL _vehicle'),event.index('_movementOperator doMove'))
        self.assertLess(event.index('_movementOperator doMove'),event.index('_endpointAdvances set'))


class ConvoyNativeIssueEvidenceTests(unittest.TestCase):
    def test_issue_history_is_capture_only_bounded_and_records_actual_issue(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('_state deleteAt "nativeIssueHistory";_state deleteAt "nativeIssueSerial"',text)
        self.assertIn('if !(_x in _registeredKeys) then {_nativeIssueHistory deleteAt _x}',text)
        issue=text.split('private _issueEvent=[];',1)[1].split('if (_endpointEvent isNotEqualTo [])',1)[0]
        self.assertLess(issue.index('getPosASL _vehicle'),issue.index('_movementOperator doMove'))
        self.assertLess(issue.index('_movementOperator doMove'),issue.index('_issueHistory pushBack _issueEvent'))
        self.assertIn('if (_captureControl) then {',issue)
        self.assertIn('count _issueHistory > 32',issue)
        self.assertIn('diag_tickTime-(_last select 1)',issue)
        self.assertNotIn('diag_log',issue)
        fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        self.assertIn('UNAVAILABLE_REMOTE_OWNER',fixture)
        self.assertIn('CBE CORTEX QA CONVOY NATIVE ISSUES:',fixture)
        self.assertIn('_nativeIssueSeen set [_key,[_last select 1,_last select 0]]',fixture)

    def test_straight_native_goal_keeps_planner_until_existing_approach_envelope(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=text.split('private _nativeRoute=[_group]',1)[1].split('if (!(_vehicle in _nativePendingVehicles)',1)[0]
        for guard in ('_straightPath','!_bypassPassageActive','_frontSpeed > 2',
                      '(_progress param [13,[],[[]]]) isEqualTo _nativeRoute',
                      'expectedDestination driver _vehicle','expectedDestination _movementOperator',
                      '_advanceAngle <= 5','finite _motion','finite _issuedMotion',
                      '_motion max _issuedMotion','2*_deceleration','_remainingNative > _refreshRoom'):
            self.assertIn(guard,gate)
        self.assertIn('_refreshNative=false',gate)
        self.assertIn('_progress set [14,_approachSpeed]',gate)
        for forbidden in ('doMove','setDriveOnPath','forceSpeed','setVelocity'):
            self.assertNotIn(forbidden,gate)
        recovery=text.split('_movementOperator doMove _recoveryTarget;',1)[1].split('// This is our own successor MOVE',1)[0]
        self.assertIn('_progress set [5,+_recoveryTarget]',recovery)
        self.assertIn('_progress set [13,[_group] call CBE_fnc_NativeOrderReceipt]',recovery)
        self.assertIn('_progress set [14,vectorMagnitude velocity _vehicle]',recovery)

    def test_native_stop_yields_but_owned_fixed_path_stop_does_not(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=text.split('private _commandYield=',1)[1].split('call CBE_fnc_ConvoyCrewLocal',1)[0]
        for guard in ('count _receipt == 8','(_receipt select 5) == "NATIVE"',
                      'toUpperANSI currentCommand _operator == "STOP"','_phase != "HALT"',
                      '"NEW_NATIVE_ORDER"','(_commandYield param [0,-1]) == _revision'):
            self.assertIn(guard,gate)
        self.assertEqual(text.count('serverTime+2,_nativeTaskBefore]'),2)
        self.assertIn('!_pendingNative && {isNull _diverted}',gate)
        self.assertNotIn('serverTime+2',gate)
        self.assertEqual(text.count('+(expectedDestination _movementOperator),"STEERING",[],'),1)
        helper=(ROOT/'addons/vehicles/functions/convoyRetireMoveReceipt.sqf').read_text(encoding='utf-8').split('params [[',1)[1]
        for guard in ('local _group','local _vehicle','local _driver','local _operator',
                      'count _receipt == 8','(_receipt select 5) == "NATIVE"',
                      'getOrDefault ["revision",-1]','(expectedDestination _operator) isEqualTo (_receipt select 4)'):
            self.assertIn(guard,helper)
        for forbidden in ('doStop','doMove','doFollow','setDriveOnPath','forceSpeed','enableAI','waitAndExecute'):
            self.assertNotIn(forbidden,helper)

    def test_internal_driving_stops_retire_old_native_move_at_the_write_boundary(self):
        names=('drivingBypassRelease','drivingBypassStep','drivingCorridorRelease','drivingCorridorStep',
               'drivingPassFinish','drivingPassStep','drivingPassRetireInherited','drivingRecoveryRelease',
               'convoyCrewLocal','convoyReleaseLocal')
        for name in names:
            text=(ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            body=text.split('params ',1)[1]
            body='\n'.join(line for line in body.splitlines() if not line.lstrip().startswith('//'))
            self.assertIn('call CBE_fnc_ConvoyRetireMoveReceipt',body,name)
            self.assertLess(body.index('call CBE_fnc_ConvoyRetireMoveReceipt'),body.index('doStop '),name)

    def test_stop_handover_fixture_requires_real_travel_and_preserves_owner_intent(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyNativeStop.sqf').read_text(encoding='utf-8')
        for marker in ('CBE_CortexQA_HeadlessBatch','local _group','local _driver','local _operator',
                       'real-native-travel-prerequisite','vectorDistance _nativeTravelOrigin >= 15','doStop _operator',
                       'CBE_Convoy_CommandYield','physical-stop','angularVelocity _vehicle',
                       'serverTime+5','_stopIntentUntilServerTime','sampled-stop-intent-stable','_operator doMove _target',
                       'vectorDistance _resumeOrigin >= 25','fresh-native-move-physical'):
            self.assertIn(marker,qa)
        outcomes=qa.split('// Assertions are finished.',1)[0]
        for forbidden in ('forceSpeed','setDriveOnPath','setVelocity','setPosATL','setGroupOwner',
                          'call CBE_fnc_ConvoyReleaseLocal','setVariable ["CBE_Convoy_CommandYield"',
                          'setVariable ["CBE_Convoy_MovementReceipt"','setVariable ["CBE_Convoy_LocalState"'):
            self.assertNotIn(forbidden,outcomes)
        self.assertLess(qa.index('real-native-travel-prerequisite'),qa.index('doStop _operator'))
        self.assertLess(qa.index('fresh-native-move-physical'),qa.index('// Assertions are finished.'))
        matrix=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text(encoding='utf-8')
        self.assertIn('cortexQAConvoyNativeStop.sqf',matrix)
        self.assertIn('|| {_nativeStopFocus}',matrix)
        self.assertIn('_observedNativeReceipt=+_receipt',qa)
        self.assertIn('private _travelled=_resumeObserved',qa)
        self.assertIn('(AGLToASL _point) vectorDistance (ATLToASL _target) <= 3',qa)
        self.assertIn('fresh-native-command-observed',qa)
        self.assertLess(matrix.index('cortexQAConvoyNativeStop.sqf'),matrix.index('private _types ='))
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        self.assertIn("$Focus -eq 'convoynativestop'",launcher)
