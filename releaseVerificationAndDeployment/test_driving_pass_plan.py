"""Pass planning safety contracts; no runtime geometry or execution acceptance is implied."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingPassPlanTests(unittest.TestCase):
    def test_proposal_cannot_acquire_movement_or_claim_clearance(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassPlan.sqf').read_text()
        code=s.split('params [["_vehicle"',1)[1]
        for forbidden in ('setVariable','doMove','doFollow','setDriveOnPath','forceSpeed','setPos','setVelocity','remoteExec'):
            self.assertNotIn(forbidden,code)
        self.assertIn('["status","PROPOSAL"]',code)
        self.assertIn('GEOMETRY_AND_AGREEMENT_REQUIRED',code)
    def test_entry_offset_is_applied_once_and_return_is_bounded(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassPlan.sqf').read_text()
        for guard in ('vectorDiff (_left vectorMultiply _entryLateral)',
                      'private _remaining=_needed-_travel','_segment=_remaining',
                      'count _guide+_steps <= 128','_passingLateral-_entryLateral',
                      '(_along-_passTravel)/30','_out*(1-_back)'):
            self.assertIn(guard,s)
        for position in ('_base','_centre','_position','_begin','_end','_frontBegin','_frontEnd'):
            self.assertNotIn(position+' set [2,0]',s)
    def test_geometry_slice_is_bounded_fresh_and_never_whole_pass_clearance(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassGeometry.sqf').read_text()
        code=s.split('params [["_proposal"',1)[1]
        self.assertEqual(code.count('call CBE_fnc_DrivingPathGeometry'),1)
        self.assertIn('_guide select [_cursor,12]',code)
        self.assertIn('_cursor+count _slice-1',code)
        self.assertEqual(code.count('call _fresh'),2)
        self.assertIn('SLICE_PROPOSAL',code)
        for forbidden in ('setVariable','doMove','setDriveOnPath','forceSpeed','setPos','setVelocity','remoteExec'):
            self.assertNotIn(forbidden,code)
    def test_deferred_scan_is_bound_to_both_crews_and_authored_orders(self):
        context=(ROOT/'addons/vehicles/functions/drivingPassContext.sqf').read_text()
        for guard in ('owner _x','driver _x','effectiveCommander _x','call CBE_fnc_DrivingOwnerReceipt',
                      'if (!_receiptsReady) exitWith {[]}','remoteControlled _actor','currentCommand _actor',
                      'expectedDestination _actor','call CBE_fnc_NativeOrderReceipt'):
            self.assertIn(guard,context)
        planner=(ROOT/'addons/vehicles/functions/drivingPassPlan.sqf').read_text()
        geometry=(ROOT/'addons/vehicles/functions/drivingPassGeometry.sqf').read_text()
        self.assertEqual(planner.count('call CBE_fnc_DrivingPassContext'),2)
        self.assertEqual(geometry.count('call _sameContext'),2)
        self.assertIn('["context",_context]',geometry)
    def test_pass_traffic_observation_refuses_dense_or_stale_sets_without_authority(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassTraffic.sqf').read_text()
        code=s.split('params [["_proposal"',1)[1]
        self.assertIn('nearEntities [["LandVehicle","CAManBase"],false,false,false]',code)
        self.assertLess(code.index('count _candidates > 64'),code.index('forEach _candidates'))
        self.assertEqual(code.count('call _current'),2)
        self.assertIn('TRAFFIC_OBSERVATION',code)
        self.assertIn('OCCUPIED_CORRIDOR',code)
        self.assertIn('APPROACHING_TRAFFIC',code)
        self.assertIn('_offset vectorDotProduct _right',code)
        self.assertIn('_enter=_enter max (_first min _last)',code)
        self.assertIn('_leave=_leave min (_first max _last)',code)
        self.assertNotIn('private _closing=-',code)
        # Only live monitoring may shorten the observation, and only behind the full hull.
        self.assertIn('getOrDefault ["monitorRemaining",false]',code)
        for guard in ('_nearRuns == 1','_distance <= 3','<= 2','>= cos 35',
                      'sqrt (_halfLength^2+_width^2)+2','_back >= _rearBuffer',
                      '_monitorPose isNotEqualTo'):
            self.assertIn(guard,code)
        self.assertIn('_guide=_guide select [_start]',code)
        step=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text()
        self.assertEqual(step.count('["monitorRemaining",true]'),3)
        issue=step.split('private _issue={',1)[1].split('if (!(_work get "issued")',1)[0]
        self.assertNotIn('monitorRemaining',issue)

        for forbidden in ('setVariable','doMove','setDriveOnPath','forceSpeed','setVelocity','remoteExec'):
            self.assertNotIn(forbidden,code)
    def test_query_envelope_covers_fast_road_approach_for_entire_proposal(self):
        import re
        text=(ROOT/'addons/vehicles/functions/drivingPassTraffic.sqf').read_text(encoding='utf-8')
        match=re.search(r'_travel\+(\d+)\*_duration\+(\d+)\) max (\d+)\) min (\d+)',text)
        self.assertIsNotNone(match)
        approach,margin,minimum,maximum=map(float,match.groups())
        for travel,duration in ((350,24),(120,12),(60,5)):
            radius=min(max(travel+approach*duration+margin,minimum),maximum)
            for oncoming in (60/3.6,90/3.6,120/3.6):
                self.assertGreaterEqual(radius,travel+oncoming*duration+20)
        self.assertLessEqual(maximum,1250)
        self.assertIn('count _candidates > 64',text)

    def test_preparation_never_renews_or_treats_partial_scan_as_ready(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassPrepare.sqf').read_text()
        self.assertEqual(s.count('set ["deadline",'),1)
        self.assertIn('set ["deadline",_at+2]',s)
        self.assertIn('_guide apply {+_x}',s)
        scan=s.split('if (_phase == "SCANNING") exitWith {',1)[1].split('if (_phase == "TRAFFIC")',1)[0]
        self.assertNotIn('READY_PROPOSAL',scan)
        self.assertIn('set ["phase","TRAFFIC"]',scan)
        self.assertEqual(s.count('call CBE_fnc_DrivingPassGeometry'),1)
        self.assertEqual(s.count('call CBE_fnc_DrivingPassTraffic'),1)
        self.assertIn('isRemoteExecuted',s)
        for forbidden in ('setVariable','doMove','setDriveOnPath','forceSpeed','remoteExec'):
            self.assertNotIn(forbidden,s)
    def test_preparation_refuses_changed_estimate_and_travel_budget(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassPrepare.sqf').read_text()
        for field in ('estimatedSeconds','requiredTravel','maximumSeconds'):
            self.assertGreaterEqual(s.count('getOrDefault ["'+field+'",-1]'),2)
        self.assertIn('set ["budget",+_budget]',s)
        self.assertIn('_budget isNotEqualTo (_work getOrDefault ["budget",[]])',s)
        admission=s.split('if (count _work == 0)',1)[1].split('private _phase=',1)[0]
        self.assertIn('!finite _x',admission)
        self.assertIn('(_budget select 2) < (_budget select 0)',admission)
        self.assertEqual(s.count('set ["budget",'),1)
    def test_local_consent_cannot_be_inferred_for_remote_participant(self):
        consent=(ROOT/'addons/vehicles/functions/drivingPassCanConsent.sqf').read_text()
        for guard in ('!local _vehicle','!local _group','!local _x','isPlayer _x',
                      'remoteControlled _x','ace_medical_ai_healQueue','CBE_Convoy_Active','CBE_ExternalDrivingOwner',
                      'CBE_DrivingRecovery_Work','CBE_DrivingBypass_Work','CBE_DrivingCorridor_Work',
                      'call CBE_fnc_CortexActorMoveReserved','call CBE_fnc_DrivingGateIntent',
                      'waypointTimeout','synchronizedTriggers'):
            self.assertIn(guard,consent)
        executor=consent[consent.index('private _brain='):consent.index('if !([_group,_vehicle,_route]')]
        for proof in ('CBE_Driving_FSM','CBE_Driving_Generation','CBE_AIPass_Epoch',
                      'finite _executor','completedFSM _executor','isNotEqualTo _route'):
            self.assertIn(proof,executor)
        for forbidden in ('execFSM','setVariable','forceSpeed','doMove'):
            self.assertNotIn(forbidden,executor)
        prepare=(ROOT/'addons/vehicles/functions/drivingPassPrepare.sqf').read_text()
        gate=prepare.split('private _remoteOwners=',1)[1].split('if (_phase == "SCANNING")',1)[0]
        self.assertIn('if (local _x) exitWith',gate)
        self.assertIn('requiredRemoteOwners',gate)
        self.assertNotIn('AGREED',gate)
    def test_agreement_requires_authenticated_distinct_owner_replies(self):
        server=(ROOT/'addons/vehicles/functions/drivingPassAgreementServer.sqf').read_text()
        owner=(ROOT/'addons/vehicles/functions/drivingPassAgreementOwner.sqf').read_text()
        for guard in ('!isServer','remoteExecutedOwner','owner _vehicle != _sender',
                      '_sender in (_record get "owners")','_acks pushBackUnique _sender',
                      'count _acks == count (_record get "owners")','count _registry >= 32',
                      'CBE_DrivingPass_ServerSequence'):
            self.assertIn(guard,server)
        self.assertLess(server.index('count _admissions >= 64'),server.index('_registry set [_token,_record]'))
        self.assertLess(server.index('_admissions set [_admissionKey,serverTime+50]'),server.index('["VERIFY",[_token'))
        release=server.split('if (_mode == "RELEASE") exitWith {',1)[1].split('if (_mode == "ACK")',1)[0]
        self.assertNotIn('_admissions',release)
        self.assertIn('remoteExecutedOwner != 2',owner)
        self.assertIn('call CBE_fnc_DrivingPassCanConsent',owner)
        for text in (server,owner):
            for command in ('doMove','setDriveOnPath','forceSpeed','setVelocity','setPosATL'):
                self.assertNotIn(command,text)
    def test_pending_consent_expires_at_handshake_and_release_is_token_bound(self):
        owner=(ROOT/'addons/vehicles/functions/drivingPassAgreementOwner.sqf').read_text()
        self.assertIn('[_old select 2,_old select 3] select ((_old select 4) == "AGREED")',owner)
        self.assertIn('if (!_valid) then {_accepted=false}',owner)
        self.assertLess(owner.index('if ([_token] call CBE_fnc_DrivingPassTokenClosed)'),owner.index('private _live='))
        self.assertIn('[_token,_expires] call CBE_fnc_DrivingPassTokenClosed',owner)
        closed=(ROOT/'addons/vehicles/functions/drivingPassTokenClosed.sqf').read_text(encoding='utf-8')
        for guard in ('count _closed > 64','count _closed < 64','_live >= 64','min _closeUntil','serverTime+50','_blockedUntil max _closeUntil','serverTime < _blockedUntil'):
            self.assertIn(guard,closed)
        retire=(ROOT/'addons/vehicles/functions/drivingPassAgreementRelease.sqf').read_text(encoding='utf-8')
        self.assertLess(retire.index('call CBE_fnc_DrivingPassTokenClosed'),retire.index('"CBE_DrivingPass_Consent",nil'))

        self.assertIn('(_agreement select 0) == _token',owner)
        server=(ROOT/'addons/vehicles/functions/drivingPassAgreementServer.sqf').read_text()
        release=server.split('if (_mode == "RELEASE") exitWith {',1)[1].split('if (_mode == "ACK")',1)[0]
        self.assertIn('_sender in (_record get "owners")',release)
        self.assertIn('_registry deleteAt _token',release)
    def test_driving_shutdown_retires_only_recorded_group_and_exact_consent(self):
        release=(ROOT/'addons/vehicles/functions/drivingPassAgreementRelease.sqf').read_text()
        for guard in ('select 1) != clientOwner','remoteExecutedOwner != 2','(_driverReceipt select 2) != _expectedGroup',
                      '(_agreement select 0) isEqualTo _token','isEqualTo _consent','isEqualTo _agreement',
                      '(_request select 0) isEqualTo _context','["RELEASE",[_token]] remoteExecCall'):
            self.assertIn(guard,release)
        for command in ('doMove','doFollow','setDriveOnPath','forceSpeed','setVelocity','setPosATL'):
            self.assertNotIn(command,release)
        self.assertNotIn('local _vehicle',release.split('params [[',1)[1])
        self.assertIn('isNil {',release)
        finish=(ROOT/'addons/vehicles/functions/drivingOperationFinish.sqf').read_text()
        boundary=finish.index('if (isNull _group || {!local _group}')
        self.assertLess(finish.index('["CANCEL",_group,_x,_brain]'),boundary)
        self.assertLess(finish.index('call CBE_fnc_DrivingPassAgreementRelease'),boundary)
        self.assertIn('[_x,_group,"",_retireEpoch,_retireGeneration]',finish)
        self.assertIn('(_actorReceipt select 4) isNotEqualTo _expectedEpoch',release)
        self.assertIn('(_actorReceipt select 10) isNotEqualTo _expectedGeneration',release)
        context=(ROOT/'addons/vehicles/functions/drivingPassContext.sqf').read_text()
        self.assertIn('call CBE_fnc_DrivingOwnerReceipt',context)
        owner=(ROOT/'addons/vehicles/functions/drivingOwnerReceipt.sqf').read_text()
        self.assertIn('if (local _group)',owner)
        self.assertIn('"CBE_Driving_Generation",-1',owner)
        self.assertIn('count _status == 6',owner)
        self.assertIn('(_status select 4) isEqualTo _owner',owner)
        self.assertIn('_epoch=_status select 5;_generation=_status select 1',owner)
        server=(ROOT/'addons/vehicles/functions/drivingPassAgreementServer.sqf').read_text()
        self.assertIn('count _ar != 11',server)
        self.assertIn('(_ar select 10) isNotEqualTo (_er select 10)',server)
        admission=(ROOT/'addons/vehicles/functions/drivingPassAdmission.sqf').read_text()
        cancel=admission.split('if (_mode == "CANCEL") exitWith {',1)[1].split('if !(_mode in',1)[0]
        for proof in ('isNil {','isNotEqualTo _brain','"generation",-2','"ownerEpoch",-2',
                      '[_group,_generation,_epoch]','[_group,_epoch,_generation]'):
            self.assertIn(proof,cancel)
        self.assertLess(cancel.index('isNotEqualTo _brain'),cancel.index('["CANCELLED"] call _finish'))
        driving=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertLess(driving.index('call CBE_fnc_DrivingPassAgreementRelease'),driving.index('private _recovery='))
    def test_broker_ack_does_not_rescan_registry_and_private_state_cannot_replay(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassAgreementServer.sqf').read_text()
        prefix,begin=s.split('if (_mode == "BEGIN") exitWith {',1)
        self.assertNotIn('forEach keys _registry',prefix)
        admission=begin.split('if (_mode == "RELEASE")',1)[0]
        self.assertLess(admission.index('owner _vehicle != _sender'),admission.index('forEach keys _registry'))
        ack=s.split('if (_mode == "ACK") exitWith {',1)[1]
        self.assertNotIn('forEach keys _registry',ack)
        self.assertEqual(ack.count('call _topologyCurrent'),1)
        self.assertNotIn('missionNamespace',s)
        self.assertIn('localNamespace getVariable ["CBE_DrivingPass_Agreements"',s)
        self.assertIn('localNamespace getVariable ["CBE_DrivingPass_ServerSequence"',s)
    def test_pass_geometry_uses_oriented_footprint_without_ignoring_peer(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassGeometry.sqf').read_text()
        code=s.split('params [["_proposal"',1)[1]
        self.assertNotIn('sqrt (_halfWidth^2+_halfLength^2)',code)
        self.assertIn('[_vehicle,_slice,_width,_height]',code)
        self.assertIn('_halfLength > 20',code)
        self.assertIn('forEach [-_width,0,_width]',code)
        self.assertIn('forEach _heights',code)
        self.assertIn('vectorMultiply (_halfLength+0.5)',code)
        self.assertIn('[_a,_b,_vehicle,objNull,true,1,"GEOM","NONE",true]',code)
        self.assertIn('BODY_FOOTPRINT_OBSTRUCTION',code)
    def test_pass_lane_offsets_follow_each_road_and_require_pullout_room(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassPlan.sqf').read_text()
        for guard in ('getRoadInfo _frontRoad','_frontEnd vectorDiff _frontBegin',
                      '_frontLateral+_offset','_gap-_ownHalfLength-_frontHalfLength-3',
                      '_available < _minimumPullout','INSUFFICIENT_PULL_OUT_ROOM',
                      '_frontRoad in _visited','_out*_out*(3-2*_out)'):
            self.assertIn(guard,s)
        self.assertNotIn('((getPosASL _front) vectorDiff _centre) vectorDotProduct _left',s)
    def test_explicit_begin_needs_live_preparation_agreement_and_existing_brain(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassBegin.sqf').read_text()
        for guard in ('READY_PROPOSAL','AGREED','CBE_Driving_Brain','vehicle leader _group',
                      'call CBE_fnc_DrivingPassCanConsent','call CBE_fnc_DrivingPassTraffic',
                      'serverTime >= (_prepared get "deadline")','["deadline",_agreement select 3]'):
            self.assertIn(guard,s)
        self.assertNotIn('setDriveOnPath',s.split('params [[',1)[1])
        self.assertNotIn('forceSpeed',s)
    def test_pass_step_retains_single_speed_writer_and_measured_return(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text()
        self.assertNotIn('forceSpeed',s)
        self.assertEqual(s.split('params [[',1)[1].count('setDriveOnPath'),1)
        self.assertIn('call _current',s)
        self.assertIn('_phase == "OUT" && {_ahead} && {_atReturnEntry}',s)
        self.assertIn('(_ownSpan select 0) > (_peerSpan select 1)+6',s)
        self.assertIn('(_ownSpan select 1) < (_peerSpan select 0)-3',s)
        span=(ROOT/'addons/vehicles/functions/drivingHullInterval.sqf').read_text()
        self.assertEqual(s.count('call CBE_fnc_DrivingHullInterval'),2)
        self.assertEqual(span.count('modelToWorldWorld'),2)  # one corner + three loop edges
        for endpoint in ('[_high select 0,_low select 1,_low select 2]',
                         '[_low select 0,_high select 1,_low select 2]',
                         '[_low select 0,_low select 1,_high select 2]'):
            self.assertIn(endpoint,span)
        self.assertIn('[_minimum-0.05,_maximum+0.05]',span)
        self.assertIn('_span append [_secondMinimum-0.05,_secondMaximum+0.05]',span)
        self.assertIn('vectorMagnitude _secondAxis',span)
        # Compare the affine projection with an independent exhaustive eight-corner oracle.
        from itertools import product
        low=(-2,-5,-1); high=(4,1,3); origin=(7,-3,2)
        matrices=(((1,0,0),(0,1,0),(0,0,1)),
                  ((0,-1,0),(1,0,0),(0,0,1)),
                  ((1,0,0),(0,.8,-.6),(0,.6,.8)),
                  ((2,0,0),(0,1,0),(0,0,.5)))
        axes=((1,0,0),(.6,.8,0),(0,.6,.8))
        def dot(a,b): return sum(x*y for x,y in zip(a,b))
        for matrix in matrices:
            def transform(point):
                return tuple(dot(row,point)+shift for row,shift in zip(matrix,(11,4,-2)))
            corners=[transform(point) for point in product(*zip(low,high))]
            corner=transform(low)
            edges=[tuple(b-a for a,b in zip(corner,transform(point))) for point in
                   ((high[0],low[1],low[2]),(low[0],high[1],low[2]),(low[0],low[1],high[2]))]
            for axis in axes:
                start=dot(tuple(a-b for a,b in zip(corner,origin)),axis)
                projected=(start+sum(min(dot(edge,axis),0) for edge in edges)-.05,
                           start+sum(max(dot(edge,axis),0) for edge in edges)+.05)
                exhaustive=[dot(tuple(a-b for a,b in zip(point,origin)),axis) for point in corners]
                self.assertAlmostEqual(projected[0],min(exhaustive)-.05)
                self.assertAlmostEqual(projected[1],max(exhaustive)+.05)
        gate=(ROOT/'addons/vehicles/functions/drivingGateCloseServer.sqf').read_text()
        self.assertIn('[_x,_origin,_axis,_side] call CBE_fnc_DrivingHullInterval',gate)
        self.assertNotIn('private _sideHull=',gate)

        self.assertIn('RETURN_SCAN',s)
        self.assertIn('DROP_BACK',s)
        # A forward path remains active while losing longitudinal ground to the peer.
        # Abort speed reduction must not bypass fresh corridor traffic refusal.
        drop=s.split('if (_phase == "DROP_BACK") exitWith {',1)[1].split('if (_phase == "RETURN_SCAN")',1)[0]
        self.assertEqual(drop.count('call CBE_fnc_DrivingPassTraffic'),1)
        self.assertIn('["guideASL",(_work get "activePath")',drop)
        self.assertIn('getOrDefault ["blocked",true]',drop)
        self.assertIn('exitWith {[true,0,"DROP_BACK_TRAFFIC_HELD"]}',drop)
        self.assertLess(drop.index('DROP_BACK_TRAFFIC_HELD'),drop.index('velocityModelSpace _peer'))
        self.assertNotIn('setDriveOnPath',drop)
        self.assertIn('if (_trafficUnsafe) then {0}',s)

        self.assertNotIn('set ["deadline",',s)
        self.assertIn('call CBE_fnc_DrivingPassGeometry',s)
    def test_automatic_admission_is_bounded_opt_in_and_uses_real_consent(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassAdmission.sqf').read_text(encoding='utf-8')
        for guard in ('DrivingAssist_Passing_Enable",false','serverTime-_since < 8',
                      'serverTime+60','(_proposal get "observedAt")+2','CBE_DrivingPass_Preparing',
                      'call CBE_fnc_DrivingPassPrepare','call CBE_fnc_DrivingPassAgreementRequest',
                      'call CBE_fnc_DrivingPassBegin','call CBE_fnc_CortexQueueJob',
                      'else {0.1}','call CBE_fnc_DrivingPassCanConsent'):
            self.assertIn(guard,s)
        for forbidden in ('forceSpeed','doMove','doStop','setDriveOnPath','addMissionEventHandler','spawn','waitUntil'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        owner=(ROOT/'addons/vehicles/functions/drivingPassAgreementOwner.sqf').read_text(encoding='utf-8')
        self.assertLess(owner.index('in ["REFUSED","RELEASED"]'),owner.index('call CBE_fnc_DrivingPassContext'))
        self.assertIn('isEqualTo _receipt',owner)
        self.assertIn('[_install,_pending] call _scheduleExpiry',owner)
        self.assertIn('_old isEqualTo _pending || {_old isEqualTo _agreed}',owner)
        self.assertIn('[_owned,[_token,_context,_deadline,_expires,"AGREED"]] call _scheduleExpiry',owner)
        self.assertIn('(_request select 2) != _serial',owner)
        self.assertIn('(_request select 0) isNotEqualTo _context',owner)
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('["OBSERVE",_group,_vehicle,_brain,_traffic,_capMps]',ordinary)
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('["CANCEL",_expectedGroup,_vehicle]',release)
        finish=s.split('private _finish={',1)[1].split('if (_mode == "CANCEL")',1)[0]
        self.assertLess(finish.index('if (_requestOwned)'),finish.index('call CBE_fnc_DrivingPassAgreementRelease'))
        self.assertIn('REQUEST_REPLACED',s)
        for guard in ('speedMode _group == "LIMITED"','serverTime-(_cruise select 2) <= 30','0.65/3.6','group driver _peer != _group'):
            self.assertIn(guard,s)
        for name in ('drivingPassPlan','drivingPassPrepare'):
            self.assertIn('SAME_GROUP',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8'))
        self.assertIn('(_request select 2) != (_job get "serial")',s)

    def test_automatic_qualification_retains_pullout_room_through_existing_writer(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassAdmission.sqf').read_text(encoding='utf-8')
        for guard in ('_pullOut+6','_peerForward+(_gap-_desired)/4','["headwayCap",_headwayCap]',
                      'if (serverTime-_since < 8) exitWith {_headwayCap}',
                      'OBSERVATION_CHANGED','_speed min'):
            self.assertIn(guard,s)
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('_capMps=_capMps min _passingHeadway',ordinary)
        self.assertLess(ordinary.index('_capMps=_capMps min _passingHeadway'),ordinary.index('_vehicle forceSpeed _capMps'))
        self.assertNotIn('forceSpeed',s.split('params [[',1)[1])
        self.assertIn('serverTime-(_priorSeen select 2) <= 6',s)
        self.assertIn('isNull _peer && {count _priorSeen == 3}',s)
        self.assertIn('isEqualTo _oldContext',s)
        self.assertIn('_gap <= 0 || {_lateral > _ownHalfWidth+_peerHalfWidth+1}',s)

    def test_real_road_fixture_observes_natural_admission_and_physical_return(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runRoadPassing.sqf').read_text(encoding='utf-8')
        for marker in ('worldName == "Altis"','from 0 to 63','_searchUntil=diag_tickTime+90',
                       '_travel >= 650','["PASS","REPLACE"]','_ownSpan select 0','_frontSpan select 1',
                       '_excursion >= 3','"RETURN_COMPLETE"','_vehicle distance2D _replacement < 20',
                       'vectorDistance _replaceStart >= 100'):
            self.assertIn(marker,s)
        for forbidden in ('call CBE_fnc_DrivingPassAdmission','call CBE_fnc_DrivingPassBegin',
                          'call CBE_fnc_DrivingPassPrepare','setDriveOnPath','_vehicle forceSpeed',
                          'setVariable ["CBE_DrivingPass_Result"','setVariable ["CBE_DrivingPass_Work"','setPos'):
            self.assertNotIn(forbidden,s)
        self.assertIn('_front forceSpeed (12/3.6)',s)

    def test_new_route_prevents_pass_cleanup_commands_and_consent_is_immutable(self):
        finish=(ROOT/'addons/vehicles/functions/drivingPassFinish.sqf').read_text(encoding='utf-8')
        owned=finish.split('private _owned={',1)[1].split('\nisNil {',1)[0]
        self.assertIn('call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")',owned)
        for guard in ('CortexZeusHeld','CBE_ExternalDrivingOwner','CBE_Convoy_Active','simulationEnabled _vehicle'):
            self.assertIn(guard,owned)
        actor=finish.split('private _actorFree=',1)[1].split('private _owned=',1)[0]
        for guard in ('CortexExternalOwner','bis_fnc_moduleRemoteControl_owner','vehicle _actor == _vehicle'):
            self.assertIn(guard,actor)
        self.assertLess(finish.index('call _owned &&'),finish.index('doStop _driver'))
        self.assertNotIn('_operator doFollow leader _group',finish)
        self.assertIn('if (_driver != _operator) then {_driver doFollow _operator}',finish)
        step=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        for guard in ('(_consent select 1) isNotEqualTo (_work get "context")',
                      '!finite (_consent select 3)','(_consent select 3) != (_work get "deadline")'):
            self.assertIn(guard,step)
        self.assertNotIn('set ["deadline",',step)

    def test_pass_finish_is_generation_and_exact_token_bound(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassFinish.sqf').read_text()
        for guard in ('get "epoch"','get "generation"','driverCommand','expectedDestination _operator',
                      'call CBE_fnc_DrivingMovementAvailable','_work get "token"','isNil {'):
            self.assertIn(guard,s)
        self.assertNotIn('forceSpeed',s)
        self.assertNotIn('setVelocity',s)
    def test_passing_uses_existing_fsm_and_suppresses_other_recovery(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('call CBE_fnc_DrivingPassStep',assist)
        self.assertIn('_capMps=_capMps min (_pass select 1)',assist)
        self.assertIn('&& {!_passActive} && {!_hadPass}',assist)
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text()
        self.assertIn('class Passing {name="Passing"',fsm)
        self.assertIn('to="Passing"',fsm)
        finish=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertLess(finish.index('call CBE_fnc_DrivingPassFinish'),finish.index('call CBE_fnc_DrivingPassAgreementRelease'))
    def test_duplicate_agreed_result_does_not_reinterpret_issued_path(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassAgreementOwner.sqf').read_text()
        duplicate=s.split('if (_mode == "RESULT"',1)[1].split('private _owned=',1)[0]
        self.assertIn('(_old select 0) isNotEqualTo _token',duplicate)
        self.assertIn('if (_mode == "DUPLICATE") exitWith {true}',duplicate)
        self.assertNotIn('setVariable',duplicate)
    def test_inherited_pass_leg_is_cleanup_only_and_waits_for_split_locality(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassRetireInherited.sqf').read_text()
        code=s.split('params [["_vehicle"',1)[1]
        for forbidden in ('setDriveOnPath','forceSpeed','execFSM','spawn','remoteExecCall'):
            self.assertNotIn(forbidden,code)
        for guard in ('!local _group','!local _driver','!local _operator','_driverCommand',
                      '_command','call CBE_fnc_DrivingRouteReceipt','CortexActorMoveReserved',
                      'ace_medical_ai_healQueue',
                      'CortexZeusHeld','CBE_ExternalDrivingOwner','!_successor'):
            self.assertIn(guard,code)
        self.assertIn('if (_sameSeats && {!isNull _group}',code)
        self.assertIn('private _brain=createHashMap;',code)
        self.assertLess(code.index('if (_live) exitWith'),code.index('doStop _driver'))
        self.assertLess(code.index('!local _driver'),code.index('CBE_DrivingPass_Leg",nil,true'))
        self.assertIn('(_work getOrDefault ["epoch",-1]) == _epoch',code)
        self.assertNotIn('set ["deadline",',code)
        self.assertEqual(code.count('getVariable ["CBE_DrivingPass_Work",createHashMap]) isEqualTo _work'),2)

    def test_pass_leg_publication_and_finish_are_exact_generation_bound(self):
        step=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text()
        self.assertLess(step.index('_vehicle setDriveOnPath _path'),step.index('"PASS_LEG_V1",clientOwner'))
        finish=(ROOT/'addons/vehicles/functions/drivingPassFinish.sqf').read_text()
        actor_free=finish.split('private _actorFree=',1)[1].split('private _owned=',1)[0]
        self.assertIn('(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []',actor_free)
        self.assertNotIn('setVariable',actor_free)
        for guard in ('(_leg select 1) == clientOwner','(_leg select 3) == (_work get "epoch")',
                      '(_leg select 4) == (_work get "generation")','(_leg select 5) == (_work get "token")'):
            self.assertIn(guard,finish)
        consent=(ROOT/'addons/vehicles/functions/drivingPassCanConsent.sqf').read_text()
        self.assertIn('!isNil {_vehicle getVariable "CBE_DrivingPass_Leg"}',consent)

    def test_inherited_cleanup_uses_existing_bounded_discovery_and_locality_paths(self):
        discover=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        cleanup=discover.split('// Cleanup uses the existing bounded vehicle slice',1)[1].split('private _wantFlares',1)[0]
        self.assertIn('(_scanVehicles select [_vehicleCursor,16])',cleanup)
        self.assertNotIn('nearEntities',cleanup)
        self.assertNotIn('allVehicles',cleanup)
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text()
        self.assertLess(locality.index('if (!_gained || {!local _group}) exitWith'),locality.index('call CBE_fnc_DrivingPassRetireInherited'))
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertIn('[_vehicle,_expectedGroup] call CBE_fnc_DrivingPassRetireInherited',release)

    def test_pass_stop_observer_never_issues_commands_and_is_exactly_bound(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassCommandWatch.sqf').read_text()
        handler=s.split('addEventHandler ["CommandChanged",{',1)[1].split('if (_id < 0)',1)[0]
        for forbidden in ('doStop','doMove','doFollow','forceSpeed','setDriveOnPath','execFSM','spawn','remoteExecCall'):
            self.assertNotIn(forbidden,handler)
        for guard in ('_thisEventHandler','serverTime >= _deadline','!local _group','!local _vehicle',
                      'toUpperANSI _command != "STOP"','CBE_DrivingPass_CommandWriting',
                      '(_work getOrDefault ["token",""]) != _token',
                      '(_work getOrDefault ["epoch",-1]) != _epoch',
                      '(_work getOrDefault ["generation",-1]) != _generation'):
            self.assertIn(guard,handler)
        self.assertIn('_work set ["interrupted",true]',handler)
        self.assertIn('removeEventHandler ["CommandChanged",_thisEventHandler]',handler)

    def test_observed_stop_prevents_finish_and_inherited_native_recall(self):
        finish=(ROOT/'addons/vehicles/functions/drivingPassFinish.sqf').read_text()
        owned=finish.split('private _owned={',1)[1].split('\nisNil {',1)[0]
        self.assertIn('!(_work getOrDefault ["interrupted",false])',owned)
        self.assertIn('!_interrupted',owned)
        boundary=finish.split('isNil {',1)[1]
        self.assertLess(boundary.index('DrivingPassCommandWatch'),boundary.index('if (call _owned'))
        self.assertLess(boundary.index('if (call _owned'),boundary.index('doStop _driver'))
        inherited=(ROOT/'addons/vehicles/functions/drivingPassRetireInherited.sqf').read_text()
        self.assertIn('!_observedStop',inherited)
        self.assertIn('(_event select [0,3]) isEqualTo [_token,_epoch,_generation]',inherited)
        step=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text()
        self.assertLess(step.index('"NATIVE_STOP_EVENT"'),step.index('private _issue='))
        boundary=step.split('private _issue=',1)[1].split('if (!(_work get "issued")',1)[0]
        self.assertLess(boundary.index('CommandWriting",_writing'),boundary.index('doStop _driver'))
        self.assertLess(boundary.index('setDriveOnPath _path'),boundary.index('CommandWriting",nil'))

    def test_pass_watch_cleanup_does_not_remove_successor_generation(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassCommandWatch.sqf').read_text()
        release=s.split('if (_release) exitWith {',1)[1].split('if (isNull _vehicle',1)[0]
        for guard in ('(_old select 0) != _vehicle','(_old select 1) != _token',
                      '(_old select 2) != _epoch','(_old select 3) != _generation'):
            self.assertIn(guard,release)
        finish=(ROOT/'addons/vehicles/functions/drivingOperationFinish.sqf').read_text()
        self.assertIn('(_watch select 2) == (_brain getOrDefault ["ownerEpoch",-1])',finish)
        self.assertIn('(_watch select 3) == (_brain getOrDefault ["generation",-1])',finish)

    def test_issue_rejoins_forward_path_before_any_native_write(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        issue=s.split('private _issue={',1)[1].split('if (!(_work get "issued")',1)[0]
        for guard in ('_distance >= 6','_distance <= 35','_height <= 2','>= cos 20',
                      'count _path <= 128','count _joined > 128','_travel > 350',
                      '_path select [_join+1]','_path=_joined',
                      '_pose isEqualTo [getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle]',
                      'serverTime < (_work get "deadline")','_pairContext isEqualTo',
                      '["outPath",_path apply {+_x}]'):
            self.assertIn(guard,issue)
        for check in ('call CBE_fnc_DrivingPassGeometry','call CBE_fnc_DrivingPassTraffic',
                      'getOrDefault ["blocked",true]','call _current'):
            self.assertLess(issue.index(check),issue.index('doStop _driver'))
        self.assertNotIn('set ["deadline",',issue)

    def test_join_sampling_respects_real_geometry_station_budget(self):
        import math
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        self.assertIn('ceil ((_originASL distance2D _joinASL)/5)',s)
        self.assertIn('vectorMultiply (_i/_segments)',s)
        # Independent envelope: 6..35m connector, <=5m segments, <=8 stations.
        for tenths in range(60,351):
            length=tenths/10
            segments=math.ceil(length/5)
            self.assertLessEqual(length/segments,5)
            self.assertLessEqual(segments+1,8)
            rays=3*(segments+1)+9*segments+9*(segments+1)
            self.assertLessEqual(rays,159)
        geometry=(ROOT/'addons/vehicles/functions/drivingPathGeometry.sqf').read_text(encoding='utf-8')
        self.assertIn('_length > 8.01',geometry)

    def test_return_scan_never_issues_path_on_same_callback(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        scan=s.split('if (_phase == "RETURN_SCAN") exitWith {',1)[1].split('if (_phase == "RETURN_READY")',1)[0]
        self.assertIn('_phase="RETURN_READY"',scan)
        self.assertNotIn('call _issue',scan)
        ready=s.split('if (_phase == "RETURN_READY") exitWith {',1)[1].split('if (_phase == "RETURN")',1)[0]
        self.assertIn('RETURN_JOIN_EXPIRED',ready)
        self.assertIn('RETURN_JOIN_REFUSED',ready)
        self.assertIn('call _issue',ready)
        initial=s.split('if !(_work get "issued") exitWith {',1)[1].split('if (_phase == "OUT"',1)[0]
        self.assertIn('[true,_work get "cap","OUT"]',initial)
        self.assertNotIn('call CBE_fnc_DrivingPassTraffic',initial)

    def test_return_leg_observes_live_traffic_before_reporting_arrival(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        merge=s.split('if (_phase == "RETURN") exitWith {',1)[1].split('// OUT retains',1)[0]
        self.assertEqual(merge.count('call CBE_fnc_DrivingPassTraffic'),1)
        for check in ('RETURN_TRAFFIC_REFUSED','RETURN_COMBAT','RETURN_STALLED'):
            self.assertLess(merge.index(check),merge.index('RETURN_COMPLETE'))
            self.assertIn('["'+check+'",false] call _finish',merge)
        self.assertIn('(_work get "activePath") apply {ATLToASL _x}',merge)
        self.assertIn('["requiredTravel",_work get "legTravel"]',merge)
        self.assertIn('serverTime-(_work get "lastAt") >= 15',merge)
        self.assertIn('(_work get "lastDistance")-_distance >= 1',merge)
        self.assertNotIn('set ["deadline",',merge)

    def test_return_context_loss_cannot_continue_or_infer_abort_clearance(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        guard=s.split('if (_phase == "RETURN" &&',1)[1].split('private _issue=',1)[0]
        for check in ('!_peerCurrent','!alive _peer','!_aligned'):
            self.assertIn(check,guard)
        self.assertIn('["RETURN_CONTEXT_CHANGED",false] call _finish',guard)
        issue=s.split('private _issue=',1)[1].split('if (!(_work get "issued")',1)[0]
        self.assertIn('["activePath",_path apply {+_x}]',issue)
        self.assertIn('["legTravel",_travel]',issue)

    def test_early_hull_clearance_keeps_out_leg_until_return_corridor_entry(self):
        s=(ROOT/'addons/vehicles/functions/drivingPassStep.sqf').read_text(encoding='utf-8')
        transition=s.split('private _outTarget=',1)[1].split('if (_phase == "DROP_BACK")',1)[0]
        for check in ('_vehicle distance2D _outTarget <= 8',
                      '(_outTarget select 2)) <= 2',
                      '_phase == "OUT" && {_ahead} && {_atReturnEntry}'):
            self.assertIn(check,transition)
        self.assertEqual(transition.count('set ["scanAt",serverTime]'),1)
        self.assertNotIn('doStop',transition)
        self.assertNotIn('set ["deadline",',transition)
        begin=(ROOT/'addons/vehicles/functions/drivingPassBegin.sqf').read_text(encoding='utf-8')
        self.assertIn('["outPath",_path select [0,_split]]',begin)
        self.assertIn('["returnASL",_pathASL select [_split-1]]',begin)
