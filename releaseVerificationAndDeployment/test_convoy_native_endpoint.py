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
        self.assertIn('distance2D _destination > 8} || {_finishedLeg}',text)
        branch=text.split('distance2D _destination > 8} || {_finishedLeg}',1)[1].split('_progress set [2, time + 1]',1)[0]
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
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text(encoding='utf-8')
        self.assertIn('count _event == 14',qa)
        self.assertIn('(vectorMagnitude _velocityAt)*3.6 < 1',qa)
        self.assertIn('vectorMagnitude _angularAt < 0.01',qa)

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
