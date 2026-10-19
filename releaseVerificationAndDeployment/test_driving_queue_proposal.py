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
                       '(_observation select 3) > 22','_maxRays > 22','_maxRays <= 70'):
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
        self.assertIn('call CBE_fnc_DrivingOwnerReceipt',body)
        self.assertIn('if (!_receiptsReady) exitWith {[]}',body)
        self.assertIn('call CBE_fnc_DrivingRouteReceipt',body)
        self.assertIn('getPosWorld _x,vectorDir _x,vectorUp _x',body)
        self.assertIn('+(vehicleMoveInfo _x)',body)
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
        current=(ROOT/'addons/vehicles/functions/drivingQueueProposalCurrent.sqf').read_text(encoding='utf-8')
        self.assertIn('_gap <= 25',body)
        self.assertIn('OVERLAPPING_OR_UNKNOWN_REAR_HULL',body)
        self.assertIn('forEach _candidateSpans',body)
        self.assertIn('_gap < 0',current)
        self.assertIn('_gap > 25',current)
        self.assertNotIn('_rear > 25',current)
        # A long aligned pair can have 35m centre spacing but only 15m body clearance.
        # Two overlapping 20m bodies can have distinct, correctly ordered centres.
        for front,back,expected in (([-10,10],[-45,-25],15),([-10,10],[-25,-5],-5)):
            self.assertEqual(front[0]-back[1],expected)

    def test_unconsumed_queue_consent_is_not_requested_by_ordinary_driving(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertNotIn('call CBE_fnc_DrivingQueueProposal',s)
        self.assertNotIn('call CBE_fnc_DrivingQueueAgreementRequest',s)
        self.assertNotIn('CBE_DrivingQueue_ProposalAt',s)
        # Ordinary finite traffic retries remain available; this is not disabling recovery.
        self.assertIn('private _jamEligible=',s)
        self.assertIn('_jam set ["attempts",(_jam get "attempts")+1]',s)

    def test_queue_broker_authenticates_each_owner_with_distinct_role_contract(self):
        server=(ROOT/'addons/vehicles/functions/drivingQueueAgreementServer.sqf').read_text(encoding='utf-8')
        owner=(ROOT/'addons/vehicles/functions/drivingQueueAgreementOwner.sqf').read_text(encoding='utf-8')
        for proof in ('!isServer','remoteExecutedOwner <= 0','owner _vehicle != _sender',
                      '_sender in (_record get "owners")','count _registry >= 32',
                      '_acks pushBackUnique _sender','count _acks == count (_record get "owners")',
                      '_expires > serverTime+30','_deadline > serverTime+2'):
            self.assertIn(proof,server)
        self.assertIn('remoteExecutedOwner != 2',owner)
        room=(ROOT/'addons/vehicles/functions/drivingQueueParentRoom.sqf').read_text()
        for proof in ('count _vehicles < 3','!local _parent','_parentIndex < 1',
                      '"queuePhase",""','queueStopAcknowledged','NO_MEASURED_REAR_ROOM',
                      'CBE_fnc_DrivingHullInterval','CBE_fnc_DrivingRearPlan','ROOM_OBSERVATION_STALE'):
            self.assertIn(proof,room)
        for forbidden in (' doMove ',' forceSpeed ','sendSimpleCommand','setVariable','waitAndExecute'):
            self.assertNotIn(forbidden,room)
        self.assertIn('_roomSerial <= (_record getOrDefault ["parentRoomReply",0])',server)
        self.assertIn('_reports >= 2',server)
        self.assertIn('["CHECK_ROOM",_message]',server)
        # Every dependency leg retains the original context/expiry, and needs all
        # owner acknowledgements for its own phase before the selected mover executes.
        for proof in ('_roomPhase != (_record getOrDefault ["phaseSerial",0])',
                      '_movingIndex <= 1', '_record set ["armedOwners",[]]',
                      '_record set ["executeSent",false]',
                      '[_next,false] call CBE_fnc_DrivingQueueReverseCurrent',
                      '(_payload select 1) != (_record getOrDefault ["phaseSerial",0])'):
            self.assertIn(proof,server)
        for proof in ('_requestedPhase < _currentPhase',
                      '_requestedPhase != _currentPhase',
                      '_next set ["executionGranted",false]',
                      '["ARMED",[_token,_requestedPhase]]'):
            self.assertIn(proof,owner)
        commit=(ROOT/'addons/vehicles/functions/drivingQueueReverseCommit.sqf').read_text()
        self.assertIn('call CBE_fnc_DrivingQueueParentRoom',commit)
        for count in (2,3,4):
            phases=[(count-1-i,i,list(range(i+1,count))) for i in range(count-1,0,-1)]
            self.assertEqual([row[0] for row in phases],list(range(count-1)))
            self.assertEqual(phases[-1][1],1)  # Crossing holder never reverses.
            self.assertTrue(all(0 not in held for _,_,held in phases))
        # Ten metres between centres still overlaps two twelve-metre hulls.
        parent_rear=-6
        dependency_front=-10+6
        self.assertLess(parent_rear-dependency_front,0)

        motion=(ROOT/'addons/vehicles/functions/drivingQueueReverseCurrent.sqf').read_text()
        for proof in ('count _vehicles > 4','count _vehicles-1','serverTime >= _expires',
                      '_actor isNotEqualTo _original','_rear < -0.25','(_binding select 3)+0.5',
                      '"queueBinding",[]','simpleAcknowledged','completedFSM','CortexActorMoveReserved'):
            self.assertIn(proof,motion)
        for forbidden in (' doMove ',' forceSpeed ','sendSimpleCommand','setVelocity','waitAndExecute'):
            self.assertNotIn(forbidden,motion)

        self.assertIn('call CBE_fnc_DrivingQueueProposalCurrent',owner)
        self.assertIn('if (_mode in ["COMMIT","READY"]) exitWith',server)
        self.assertIn('_sender != owner _root',server)
        self.assertIn('_record getOrDefault ["committed",false]',server)
        self.assertIn('_record set ["holdReadyVehicles",_ready]',server)
        self.assertIn('private _allSettled=(_record get "vehicles") findIf',server)
        self.assertIn('&& {_allSettled}',server)
        self.assertIn('_deliveries >= 2',server)
        preparation=owner.split('if (_mode == "PREPARE") exitWith {',1)[1].split('if (_mode == "COMMIT") exitWith',1)[0]
        for proof in ('_duplicate','_accepted','holdReadySent','holdApplied','CBE_AIPass_Epoch',
                      'getForcedSpeed _heldVehicle','_linear >= 0.1','_angular >= 0.01',
                      '[_token,_expires,_applied select 1,_applied select 2]',
                      '"executionPreparation",_binding','_before isNotEqualTo []'):
            self.assertIn(proof,preparation)
        for forbidden in ('doMove','doStop','forceSpeed','sendSimpleCommand','waitAndExecute','set ["expires"'):
            self.assertNotIn(forbidden,preparation)
        self.assertIn('"PREPARE",_message',server)
        self.assertIn('forEach (_record get "owners")',server)
        self.assertIn('"PREPARED",[_token]',preparation)
        self.assertIn('_prepared pushBackUnique _sender',server)
        self.assertIn('_armed pushBackUnique _sender',server)
        self.assertIn('count _armed == count (_record get "owners")',server)
        self.assertIn('["EXECUTE",_message]',server)
        self.assertIn('owner _leaf',server)
        duplicate=owner.split('// Repeated authenticated ARM/EXECUTE',1)[1].split('private _accepted=',1)[0]
        self.assertIn('!_tokenClosed && {_duplicate}',duplicate)
        for forbidden in ('setVariable','doMove','sendSimpleCommand','set ["expires"'):
            self.assertNotIn(forbidden,duplicate)

        prepared=server.split('if (_mode == "PREPARED") exitWith {',1)[1].split('// COMMIT is separate',1)[0]
        for guard in ('serverTime >=','_linear >= 0.1','_angular >= 0.01','call _current'):
            self.assertLess(prepared.index(guard),prepared.index('_prepared pushBackUnique _sender'))
        owners={2,10,20}
        acknowledgements=set()
        for sender,expected in ((2,False),(2,False),(20,False),(10,True)):
            acknowledgements.add(sender)
            self.assertEqual(acknowledgements==owners,expected)

        self.assertIn('count _prepared == count (_record get "owners")',server)
        self.assertLess(preparation.index('forEach _preparedRows'),preparation.index('"PREPARED",[_token]'))
        self.assertIn('!(_record getOrDefault ["executionPrepared",false])',server)

        self.assertIn('if (_mode == "COMMIT") exitWith',owner)
        preflight=owner.split('if (_accepted && {_mode in ["VERIFY","COMMIT"]})',1)[1].split('if (_mode in ["ARM","EXECUTE"]) exitWith',1)[0]
        for proof in ('count _vehicles-1','_leaf in _owned','call CBE_fnc_DrivingRearPlan',
                      '_leafObservation select 0','serverTime <','call CBE_fnc_DrivingQueueProposalCurrent'):
            self.assertIn(proof,preflight)
        for forbidden in ('setVariable','forceSpeed','doMove','sendSimpleCommand','waitAndExecute'):
            self.assertNotIn(forbidden,preflight)

        self.assertIn('if (!_duplicate || {!_accepted}) exitWith',owner)
        hold=(ROOT/'addons/vehicles/functions/drivingQueueHold.sqf').read_text(encoding='utf-8')
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        body='\n'.join(line.split('//',1)[0] for line in hold.split('params [[',1)[1].splitlines())
        for proof in ('CBE_Driving_Brain','CBE_AIPass_Epoch','serverTime >= _expires',
                      'CBE_fnc_DrivingQueueTokenClosed','_mode == "APPLIED"',
                      'holdApplied','holdStillSince','holdReadySent','serverTime-_since >= 1',
                      '_linear < 0.1','_angular < 0.01','CBE_fnc_DrivingQueueAgreementRelease'):
            self.assertIn(proof,body)
        self.assertNotIn('set ["expires",',body)
        for proof in ('holdReadyReports','holdReadyReportedAt','_reports < 2',
                      'serverTime-_reportedAt >= 2','_reports+1'):
            self.assertIn(proof,body)
        self.assertLess(body.index('if (!_settled && {_ready})'),body.index('private _reports='))
        self.assertNotIn('CBA_fnc_waitAndExecute',body)

        self.assertLess(body.index('if (_updated isNotEqualTo _consent)'),body.index('if (_reportReady) then'))
        for command in ('forceSpeed','doMove','doStop','setDriveOnPath','sendSimpleCommand','spawn','sleep'):
            self.assertNotIn(command,body)
        self.assertEqual(assist.count('call CBE_fnc_DrivingQueueHold'),3)
        self.assertLess(assist.index('_vehicle forceSpeed _capMps'),assist.index('["APPLIED",_group,_vehicle,_brain]'))
        self.assertIn('&& {!_queueHold}',assist)
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
        self.assertIn('count _e != 6',s)
        self.assertIn('call CBE_fnc_DrivingQueueCrossingVehicle',s)
        selector=(ROOT/'addons/vehicles/functions/drivingQueueCrossingVehicle.sqf').read_text(encoding='utf-8')
        body=selector.split('params [[',1)[1]
        for forbidden in ('setVariable','remoteExec','waitAndExecute','nearEntities','lineIntersectsSurfaces',
                          'doMove','forceSpeed','sendSimpleCommand','setEffectiveCommander'):
            self.assertNotIn(forbidden,body)
        proposal=(ROOT/'addons/vehicles/functions/drivingQueueProposal.sqf').read_text(encoding='utf-8')
        self.assertLess(proposal.index('call CBE_fnc_DrivingQueueCrossingVehicle'),proposal.index('nearEntities'))
        self.assertIn('class DrivingQueueCrossingVehicle', (ROOT/'addons/main/CfgFunctions.hpp').read_text())
        self.assertIn('if (_i > 0 && {((_a select 2) select 0) == ((_a select 3) select 0)',s)
        self.assertIn('toUpperANSI (_nativeReceipt select 1) != "NONE"',s)
        self.assertIn('toUpperANSI ((_a select 5) param [1,""]) != "NONE"',s)
        proposal=(ROOT/'addons/vehicles/functions/drivingQueueProposal.sqf').read_text(encoding='utf-8')
        self.assertIn('from 1 to ((count _context)-1)',proposal)
        self.assertLess(proposal.index('"NATIVE_REVERSE_UNAVAILABLE"'),proposal.index('["status","PROPOSAL"]'))
        for forbidden in ('setEffectiveCommander','moveInDriver','sendSimpleCommand'):
            self.assertNotIn(forbidden,s)
            self.assertNotIn(forbidden,proposal)
        self.assertIn('(_a select 5) isNotEqualTo _nativeReceipt',s)
        admission=(ROOT/'addons/vehicles/functions/drivingPassCanConsent.sqf').read_text(encoding='utf-8')
        self.assertIn('private _nativeDriveInfo=vehicleMoveInfo _vehicle',admission)
        self.assertIn('["BACK","FORWARD","FAST","SLOW","DIRECTBYCOMANDER","SIMPLE","CONVOY"]',admission)
        self.assertIn('in ["LEFT","RIGHT"]',admission)
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

    def test_stationarity_uses_total_finite_velocity_in_proposal_and_deferred_validation(self):
        for name,actor in (('drivingQueueProposal','_object'),('drivingQueueProposalCurrent','_vehicle')):
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertIn(f'private _queueLinearSpeed=vectorMagnitude velocity {actor}',text)
            self.assertIn('!finite _queueLinearSpeed',text)
            self.assertIn('_queueLinearSpeed >= (1/3.6)',text)
            self.assertIn(f'private _queueAngularSpeed=vectorMagnitude angularVelocity {actor}',text)
            self.assertIn('!finite _queueAngularSpeed',text)
            self.assertIn('_queueAngularSpeed >= 0.01',text)
            self.assertNotIn(f'abs speed {actor}',text)
        # Forward-axis speed can be zero during fast translation in either other axis.
        # The norm keeps the original1km/h threshold independent of vehicle orientation.
        import math
        threshold=1/3.6
        for velocity in ((2,0,0),(0,0,-2),(0,-0.5,0),(0.2,0.2,0)):
            self.assertGreaterEqual(math.hypot(*velocity),threshold)
        for velocity in ((0,0,0),(0.2,0,0),(0,0.2,0),(0,0,-0.2)):
            self.assertLess(math.hypot(*velocity),threshold)
        self.assertEqual(math.hypot(0.3,0.4,0),math.hypot(0,0,0.5))
