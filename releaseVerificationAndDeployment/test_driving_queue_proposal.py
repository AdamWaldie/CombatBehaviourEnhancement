"""Queue proposal contracts; no owner consent, movement or physical acceptance implied."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class QueueProposalTests(unittest.TestCase):
    def test_native_capability_fixture_separates_crew_setup_and_turning_support_rays(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        diagnostic=s.split('// Sensor diagnostic only:',1)[1]
        for marker in ('["_separateCommander",false]','-SEPARATE-COMMANDER',
                       '_vehicle setEffectiveCommander _helper','effectiveCommander _vehicle == _helper',
                       'driver _vehicle != _helper','_commandCrewReady && {_samples >= 3}',
                       '(_observation select 3) > 21','_maxRays > 21','_maxRays <= 69'):
            self.assertIn(marker,diagnostic)
        for family in ('WHEELED','TRUCK'):
            for turn in ('LEFT','RIGHT'):
                self.assertIn('"'+turn+'","'+family+'",true]',diagnostic)
        for forbidden in ('CBE_DrivingQueue_Consent','CBE_DrivingQueue_Ready','CBE_DrivingQueue_Result'):
            self.assertNotIn(forbidden,diagnostic)
    def test_receipt_is_canonical_bounded_and_observational(self):
        s=(ROOT/'addons/vehicles/functions/drivingQueueContext.sqf').read_text(encoding='utf-8')
        body=s.split('params [["_vehicles"',1)[1]
        self.assertIn('count _vehicles > 4',body)
        self.assertIn('arrayIntersect _vehicles',body)
        self.assertNotIn('clientOwner',body)
        self.assertIn('expectedDestination _actor',body)
        self.assertIn('CBE_Driving_State',body)
        self.assertIn('call CBE_fnc_DrivingRouteReceipt',body)
        self.assertIn('getPosWorld _x,vectorDir _x,vectorUp _x',body)
        for command in ('setVariable','doMove','forceSpeed','remoteExec'):
            self.assertNotIn(command,body)
    def test_discovery_has_one_bounded_query_and_no_movement_or_consent(self):
        s=(ROOT/'addons/vehicles/functions/drivingQueueProposal.sqf').read_text(encoding='utf-8')
        body=s.split('params [["_vehicle"',1)[1]
        self.assertEqual(body.count('nearEntities'),1)
        for proof in ('120,120,0,false,120','count _candidates > 64','from 1 to 3',
                      'count _vehicles >= 4','DEPENDENCY_CYCLE','CHAIN_PARTICIPANT_BUDGET',
                      'OWNER_CONSENT_AND_NATIVE_EXECUTION_REQUIRED','(_at+2) min _until'):
            self.assertIn(proof,body)
        for command in ('setVariable','doMove','doStop','setDriveOnPath','forceSpeed',
                        'setPos','setVelocity','remoteExec','spawn','waitUntil'):
            self.assertNotIn(command,body)
    def test_natural_discovery_follows_dwell_and_stays_outside_atomic_retry(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        block=s.split('// Queue proposal discovery',1)[1].split('// Waiting behind traffic',1)[0]
        self.assertIn('serverTime-(_queueRetry get "since") >= 5',block)
        self.assertIn('serverTime-_queuePrior >= 30',block)
        self.assertIn('serverTime-(_queueSeen select 2) <= 1.5',block)
        self.assertEqual(block.count('call CBE_fnc_DrivingQueueProposal'),1)
        claim=block.index('_queueClaimed=true;')
        query=block.index('call CBE_fnc_DrivingQueueProposal;')
        self.assertIn('};\n                if (_queueClaimed) then {',block[claim:query])
        self.assertTrue(block[query:].startswith('call CBE_fnc_DrivingQueueProposal;\n                    isNil {'))
        self.assertIn('call CBE_fnc_DrivingQueueAgreementRequest',block)
        self.assertNotIn('remoteExec',block)
        self.assertNotIn('forceSpeed',block)
        self.assertIn('serverTime < (_queueRetry get "deadline")',block)

    def test_queue_broker_authenticates_each_owner_with_distinct_role_contract(self):
        server=(ROOT/'addons/vehicles/functions/drivingQueueAgreementServer.sqf').read_text(encoding='utf-8')
        owner=(ROOT/'addons/vehicles/functions/drivingQueueAgreementOwner.sqf').read_text(encoding='utf-8')
        for proof in ('!isServer','remoteExecutedOwner <= 0','owner _vehicle != _sender',
                      '_sender in (_record get "owners")','count _registry >= 32',
                      '_acks pushBackUnique _sender','count _acks == count (_record get "owners")',
                      '_expires > serverTime+30','_deadline > serverTime+2'):
            self.assertIn(proof,server)
        self.assertIn('remoteExecutedOwner != 2',owner)
        self.assertIn('call CBE_fnc_DrivingQueueProposalCurrent',owner)
        for text in (server,owner):
            self.assertNotIn('DrivingPassAgreement',text)
            for command in ('doMove','doStop','setDriveOnPath','forceSpeed','setVelocity'):
                self.assertNotIn(command,text)
    def test_actual_owner_checks_orders_brain_and_snapshot_before_ack(self):
        s=(ROOT/'addons/vehicles/functions/drivingQueueProposalCurrent.sqf').read_text(encoding='utf-8')
        for proof in ('_roles isNotEqualTo _expectedRoles','_dependencies isNotEqualTo _expectedDependencies',
                      '_localRows && {local (_vehicles select _i)}','_ar isNotEqualTo _er',
                      'CBE_Driving_Brain','CBE_DrivingPass_Consent','CortexZeusHeld',
                      '!alive (_ar select 0)','!canMove _vehicle','CBE_ExternalDrivingOwner',
                      'vectorMagnitude (_ep select 1)','_localCount == 0','CBE_AIPass_DrivingAssist_Recovery_Enable'):
            self.assertIn(proof,s)
        self.assertNotIn('setVariable',s)
    def test_stale_cancel_and_late_results_cannot_clear_successor_consent(self):
        request=(ROOT/'addons/vehicles/functions/drivingQueueAgreementRequest.sqf').read_text(encoding='utf-8')
        cancel=request.split('if (_cancel) exitWith {',1)[1].split('private _roles=',1)[0]
        self.assertLess(cancel.index('(_request select 0) != _serial'),cancel.index('CBE_DrivingQueue_Request",nil'))
        self.assertIn('(_request select 1) isNotEqualTo _context',cancel)
        self.assertIn('_old isEqualTo _key',request)
        self.assertIn('(_at+30) min _retryDeadline',request)
        owner=(ROOT/'addons/vehicles/functions/drivingQueueAgreementOwner.sqf').read_text(encoding='utf-8')
        terminal=owner.split('// Terminal token cleanup',1)[1].split('private _duplicate=',1)[0]
        self.assertIn('(_old getOrDefault ["token",""]) == _token',terminal)
        self.assertNotIn('call CBE_fnc_DrivingQueueProposalCurrent',terminal)
        self.assertLess(owner.index('private _accepted='),owner.index('if (_duplicate) exitWith'))
        self.assertIn('(_mode == "RESULT" || {_duplicate})',owner)

    def test_request_is_atomic_and_expired_passing_receipt_does_not_hold_queue_consent(self):
        request=(ROOT/'addons/vehicles/functions/drivingQueueAgreementRequest.sqf').read_text(encoding='utf-8')
        self.assertLess(request.index('isNil {'),request.index('CBE_DrivingQueue_Attempt'))
        self.assertTrue(request.rstrip().endswith('_submitted'))
        current=(ROOT/'addons/vehicles/functions/drivingQueueProposalCurrent.sqf').read_text(encoding='utf-8')
        self.assertIn('_passBusy=!_typed || {serverTime <',current)
        self.assertIn('(_pass select 4) == "AGREED"',current)
