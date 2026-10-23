"""Gate approach uses live body geometry under the existing single speed writer."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingGateCapTests(unittest.TestCase):
    def test_locked_gate_can_retry_once_only_after_owner_and_server_observe_unlock(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        self.assertIn('["unlockReceipt",_unlockReceipt]',owner)
        self.assertIn('getOrDefault ["unlockReceipt",-1]',server)
        self.assertIn('_context pushBack ["UNLOCK_RETRY",_unlockReceipt]',owner)
        self.assertIn('(_previous select 2) == "LOCKED"',server)
        self.assertIn('(_previous select 3) == _unlockReceipt',server)
        self.assertIn('(_previous param [4,0]) == 0',server)
        self.assertIn('"VALIDATING",serverTime+5,1,_passageCycle]',server)
        self.assertLess(server.index('private _retryUnlock=false'),server.index('call CBE_fnc_DrivingGateCap'))
        for code in (owner,server):
            self.assertIn('bis_disabled_Door_%1',code)
            self.assertIn('for "_index" from 1 to 8',code)
        self.assertIn('_attempts >= 2',owner)

    def test_gate_detection_and_opening_share_aliases_without_reading_discarded_phases(self):
        geometry=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        barrier=geometry.split('private _sourceConfig=configOf _object >> "AnimationSources";',1)[1].split('_gateClasses set',1)[0]
        for alias in ('Door_%1_sound_source','Gate_%1_sound_source','Door_%1_source','Gate_%1_source'):
            self.assertIn(alias,barrier)
        self.assertIn('exitWith {_isGate=true}',barrier)
        self.assertIn('private _classKey=typeOf _object',geometry)
        ranking=server.split('private _preferredSources=createHashMap;',1)[1].split('for "_index" from 1 to 8 do',1)[0]
        self.assertNotIn('animationSourcePhase',ranking)
        selected=server.split('for "_index" from 1 to 8 do',1)[1].split('private _locked={',1)[0]
        self.assertEqual(selected.count('animationSourcePhase'),1)

    def test_indexed_gate_aliases_choose_one_sound_preferred_source_per_leaf(self):
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        metadata=server.split('private _sources=[];',1)[1].split('private _locked={',1)[0]
        for alias in ('door_%1_sound_source','gate_%1_sound_source','door_%1_source','gate_%1_source'):
            self.assertIn(alias,metadata)
        self.assertIn('_aliases find _lowerName',metadata)
        self.assertIn('_priority < (_previous select 0)',metadata)
        self.assertIn('_preferredSources set [_key,',metadata)
        self.assertIn('for "_index" from 1 to 8',metadata)
        self.assertIn('count _definitions <= 64',metadata)
        self.assertEqual(metadata.count('_sources pushBack'),1)
        self.assertNotIn('compile',metadata)
        self.assertNotIn('getText',metadata)

    def test_observation_is_bounded_live_and_has_no_world_mutation(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        for gate in ['modelToWorldWorld', 'true,4,"GEOM","NONE"',
                     '[_left,(_left+_right)*0.5,_right]', 'forEach _heights',
                     'max 25 min 600', '_gap-6', '_deceleration=4/_massFactor']:
            self.assertIn(gate,s)
        for command in ['animateSource','animateDoor','forceSpeed','setVelocity','doMove','remoteExec','animationSourcePhase']:
            self.assertNotIn(command,s)
        self.assertNotIn('alive _object',s)
        self.assertNotIn('damage _object',s)
        self.assertIn('[_bottom,(_bottom+_top)*0.5,_top]',s)
        self.assertIn('(_high select 2)-0.2',s)
    def test_existing_executors_combine_gate_before_speed_and_recovery(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertLess(ordinary.index('call CBE_fnc_DrivingGeometryCap'),ordinary.index('_vehicle forceSpeed _capMps'))
        self.assertIn('private _geometry=if (!_reverseLeg && {!_forwardHeld}) then {',ordinary)
        self.assertEqual(convoy.count('call CBE_fnc_DrivingGeometryCap'),2)
        self.assertIn('then {_leadTraffic=_leadGate}',convoy)
        self.assertIn('then {_traffic=_vehicleGate}',convoy)
        self.assertIn('!_leadTrafficBlocked',convoy)
        self.assertIn('!_trafficBlocked',convoy)
    def test_opening_request_has_server_authority_and_complete_named_payload(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        for key in ['group','vehicle','gate','route','transform','driver','commander','convoyRevision','expires']:
            self.assertIn('["'+key+'",',owner)
            self.assertIn('getOrDefault ["'+key+'",',server)
        for guard in ['!isServer', 'remoteExecutedOwner', 'groupOwner _group', 'owner _vehicle',
                      'owner driver _vehicle', 'call CBE_fnc_CortexIsEligible', 'call CBE_fnc_CortexIsPaused',
                      '_expires <= serverTime', '_expires > serverTime+5',
                      'call CBE_fnc_DrivingGateRouteMatches', '_transform isNotEqualTo',
                      'call CBE_fnc_DrivingGateCap', '(_observed select 1) != _gate',
                      '(_observed select 2) > 12', 'abs speed _vehicle > 8',
                      'CBE_AIPass_Active', '!simulationEnabled _vehicle', 'isObjectHidden _vehicle']:
            self.assertIn(guard,server)
        mutation=server.split('// Final mutation boundary:',1)[1]
        self.assertLess(mutation.index('call _locked'),mutation.index('animateSource'))
        self.assertLess(mutation.index('driver _vehicle != _driver'),mutation.index('animateSource'))
        self.assertNotIn('animateSource',owner)
        self.assertIn('remoteExecCall ["CBE_fnc_DrivingGateOpenServer",2]',owner)

    def test_gate_attempts_are_finite_and_do_not_create_passage_or_closure(self):
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        for guard in ['(_receipt select 0) == _group', '(_receipt select 1) isEqualTo _route',
                      '_attemptIndex >= 0', 'count _attempts >= 16', 'count _definitions <= 64',
                      '_index <= 8', 'bis_disabled_Door', 'SHARED_OPENING',
                      'ALREADY_OPEN_OR_MOVING', '[_x select 1,1]']:
            self.assertIn(guard,server)
        for command in ['doMove','forceSpeed','setVelocity','setDir','setPos','spawn','execFSM','CBA_fnc_waitAndExecute']:
            self.assertNotIn(command,server)
        self.assertNotIn('animateSource [_x select 1,0]',server)
        self.assertNotIn('setVariable ["bis_disabled',server)

    def test_delivery_is_bounded_and_duplicate_server_work_returns_before_geometry(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        for guard in ['_attempts >= 2', 'serverTime < (_pending select 1)',
                      '(_ack select 4) isEqualTo _route', '(_ack select 6) isEqualTo _transform',
                      'OPEN_WINDOW_EXPIRED', 'REQUEST_TIMEOUT',
                      'CBE_DrivingGate_Pending",[_context,serverTime+5,_attempts+1],true', '["driver",_driver]', '["commander",_commander]']:
            self.assertIn(guard,owner)
        self.assertLess(server.index('if (_attemptIndex >= 0 && {!_retryUnlock} && {!_retryPassage}) exitWith'),server.index('call CBE_fnc_DrivingGateCap'))
        self.assertIn('_driver != _requestedDriver',server)
        self.assertIn('_commander != _requestedCommander',server)
        self.assertIn('[_gate,_reason,_until,_group,+_route,_revision,+_transform,_passageCycle]',server)
        self.assertNotIn('animateSource',owner)

class DrivingGateIntentTests(unittest.TestCase):
    def test_gate_intent_is_checked_before_request_and_authoritative_mutation(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        self.assertLess(owner.index('call CBE_fnc_DrivingGateIntent'),owner.index('CBE_DrivingGate_Pending'))
        self.assertEqual(server.count('call _gateIntentCurrent'),2)
        self.assertIn('call CBE_fnc_DrivingGateOwnerCheck',server)
        mutation=server.split('// Final mutation boundary:',1)[1]
        self.assertLess(mutation.index('call _gateIntentCurrent'),mutation.index('animateSource'))
        self.assertIn('_revision < 0',mutation)

    def test_plain_and_owned_alternate_intent_have_distinct_stop_contracts(self):
        s=(ROOT/'addons/vehicles/functions/drivingGateIntent.sqf').read_text()
        native_reads=s.index('if (isNull _driver')
        for guard in ('!local _group','!local _vehicle','!local _driver','!local _operator'):
            self.assertIn(guard,s[native_reads:s.index('private _destination=')])
        self.assertLess(s.index('!local _operator'),s.index('(expectedDestination _driver)'))

        for marker in ('call CBE_fnc_DrivingRouteGoal',
                       'CBE_DrivingBypass_Work","FOLLOW"','CBE_DrivingCorridor_Work","CROSS"',
                       'expectedDestination _driver','expectedDestination _operator',
                       'serverTime <','"controller",[]','"phase",""]) == "APPROACH"',
                       '_driverTarget vectorDistance _destination <= 3'):
            self.assertIn(marker,s)
        # Plain route action requires idle or the original MOVE, not a later task.
        def plain(command, target_matches=True):
            return command=='' or command=='MOVE' and target_matches
        for command in ('STOP','WAIT','ATTACK','FOLLOW','FIRE','REARM'):
            self.assertFalse(plain(command))
        self.assertFalse(plain('MOVE',False))
        self.assertTrue(plain('MOVE'))
        self.assertTrue(plain(''))
        body=s.split('params [[',1)[1]
        for forbidden in ('setVariable','animateSource','doMove','doStop','forceSpeed','spawn','nearEntities'):
            self.assertNotIn(forbidden,body)

class DrivingGateMutationTests(unittest.TestCase):
    def test_final_opening_commits_live_authority_and_phase_together(self):
        text=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text(encoding='utf-8')
        body=text.split('// Final mutation boundary:',1)[1]
        self.assertLess(body.index('isNil {'),body.index('animateSource'))
        for guard in ('serverTime >= _expires','_convoyCurrent','_liveConfig select 0',
                      '_liveConfig select 5','_liveCommander != _requestedCommander',
                      'owner _driver','owner _liveCommander','call _locked',
                      'CBE_ExternalDrivingOwner','CortexIsPaused','DrivingGateRouteMatches',
                      'animationSourcePhase','isObjectHidden _vehicle'):
            self.assertLess(body.index(guard),body.index('animateSource'))
        self.assertIn('private _currentOpening=',body)
        self.assertIn('"SHARED_OPENING",_currentOpening select 2',body)
        self.assertNotIn('lineIntersects',body)
        self.assertNotIn('nearestObjects',body)
class DrivingGateOwnerEvidenceTests(unittest.TestCase):
    def test_owner_evidence_is_local_authenticated_single_use_and_bounded(self):
        broker=(ROOT/'addons/vehicles/functions/drivingGateOwnerEvidence.sqf').read_text()
        check=(ROOT/'addons/vehicles/functions/drivingGateOwnerCheck.sqf').read_text()
        opening=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        close=(ROOT/'addons/vehicles/functions/drivingGateCloseServer.sqf').read_text()
        self.assertIn('remoteExecutedOwner != 2',broker)
        self.assertIn('["CBE_Convoy_LocalRegistry","CBE_Convoy_Registry"] select isServer',check)
        self.assertIn('remoteExecutedOwner != (_evidenceContext get "owner")',broker)
        self.assertIn('count _evidenceRegistry >= 16',broker)
        self.assertIn('_evidenceRegistry deleteAt _evidenceToken',broker)
        self.assertLess(broker.index('_evidenceRegistry deleteAt _evidenceToken'),broker.index('CBE_DrivingGate_OpenWitness'))
        self.assertIn('serverTime >= (_evidenceContext get "until")',broker)
        self.assertIn('(_context get "payload") isEqualTo _payload',opening)
        self.assertIn('_vehicle setVariable ["CBE_DrivingGate_OpenWitness",nil]',opening)
        self.assertIn('(serverTime+3) min (_job get "until")',close)
        self.assertIn('OWNER_INTENT_UNCONFIRMED',close)
        for source in (opening,close):
            self.assertNotIn('+(expectedDestination',source)
        self.assertLess(check.index('!local _gateDriver') if '!local _gateDriver' in check else check.index('!local _x'),check.index('expectedDestination _gateDriver'))
        for forbidden in ('animateSource','doMove','forceSpeed','waitUntil','spawn'):
            self.assertNotIn(forbidden,broker.split('params [[',1)[1])
        # A recorded ticket is consumed by its owner once, only before the original expiry.
        tickets={'one':(7,10)}
        def reply(token,owner,now):
            row=tickets.get(token)
            if row is None or row[0]!=owner:return False
            del tickets[token]
            return now<row[1]
        self.assertFalse(reply('one',8,9))
        self.assertTrue(reply('one',7,9))
        self.assertFalse(reply('one',7,9))
        tickets['late']=(7,10)
        self.assertFalse(reply('late',7,10))
        self.assertNotIn('late',tickets)

class DrivingGateClosureTests(unittest.TestCase):
    def test_finite_closure_retains_authority_and_never_infers_passage_from_time(self):
        close=(ROOT/'addons/vehicles/functions/drivingGateCloseServer.sqf').read_text()
        opening=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertIn('count _closeJobs < 8',opening)
        self.assertIn('["until",serverTime+120]',opening)
        # Outstanding callbacks occupy slots until they retire, even when overdue.
        admission=opening.split('private _closeJobs=',1)[1].split('private _existingClose=',1)[0]
        self.assertNotIn('serverTime <',admission)
        self.assertIn('CBE_fnc_DrivingGateCloseServer,_job,1',opening)
        for token in ('canSuspend','remoteExecutedOwner','groupOwner _taskGroup',
                      'owner _driver','owner _commander','DrivingGateRouteMatches',
                      'OPERATION_CHANGED','NATIVE_ORDER_CHANGED','bis_disabled_Door',
                      'ANIMATION_CHANGED','OTHER_LEAF_CHANGED','PASSAGE_SAMPLE_LOST',
                      'CortexExternalTakeover','count _near > 16','false,false,false'):
            self.assertIn(token,close)
        self.assertIn('CBE_DrivingGate_CloseJobs',stop)
        self.assertIn('_x set ["done",true]',stop)
        self.assertIn('CBE_DrivingGate_StopSerial',stop)
        self.assertIn('CBE_DrivingGate_AttemptStopSerial',opening)
        self.assertIn('CBE_DrivingGate_Result",nil,true',stop)
        completion=close.split('if ((_job get "phase") == "CLOSING") exitWith {',1)[1].split('if (isNull _vehicle',1)[0]
        self.assertNotIn('animateSource',completion)
        self.assertIn('CLOSED_OBSERVED',completion)

        self.assertNotIn('["group",_group]',opening.split('private _job=createHashMapFromArray',1)[1])
        mutation=close.index('_gate animateSource')
        self.assertLess(close.index('if (!_clear)'),mutation)
        self.assertLess(close.index('if (!_open'),mutation)
        self.assertEqual(close.count('_gate animateSource'),1)
        self.assertIn('CLOSE_REQUESTED',close)
        self.assertIn('CLOSED_OBSERVED',close)
        self.assertIn('CBE_DrivingGate_ClosedProof',close)
        self.assertIn('CBE_DrivingGate_ClosedProof',opening)
        self.assertNotIn('getVariable ["CBE_DrivingGate_ClosedCycle"',opening)
        self.assertIn('_passageCycle > (_previous param [5,0,[0]])',opening)
        self.assertIn('if (_retryPassage) then',opening)
        def new_passage(previous_reason, accepted_cycle, closed_cycle, pose_matches=True):
            return pose_matches and previous_reason in ('OPEN_REQUESTED','SHARED_OPENING','OPEN_WINDOW_EXPIRED','ALREADY_OPEN_OR_MOVING') and closed_cycle>accepted_cycle
        self.assertTrue(new_passage('OPEN_REQUESTED',0,12))
        self.assertTrue(new_passage('SHARED_OPENING',2,12))
        self.assertTrue(new_passage('OPEN_WINDOW_EXPIRED',2,12))
        self.assertFalse(new_passage('OPEN_REQUESTED',30,12))
        self.assertFalse(new_passage('LOCKED',12,12))
        self.assertFalse(new_passage('OPEN_REQUESTED',12,12,False))

        for command in ('doMove','forceSpeed','setVelocity','setPos','spawn','waitUntil'):
            self.assertNotIn(command,close)

    def test_aperture_crossing_and_tail_clearance_are_distinct(self):
        def crossing(before, after, half_width, dt=2):
            if dt<=0 or dt>6 or sum((b-a)**2 for a,b in zip(before,after))>25**2:
                return False
            if not before[0]<0<=after[0]:
                return False
            fraction=-before[0]/(after[0]-before[0])
            lateral=before[1]+fraction*(after[1]-before[1])
            return lateral-half_width>-3 and lateral+half_width<3
        self.assertTrue(crossing((-4,0),(4,0),1))
        self.assertFalse(crossing((-4,5),(4,5),1))
        self.assertFalse(crossing((4,0),(8,0),1))
        self.assertFalse(crossing((4,0),(-4,0),1))
        self.assertFalse(crossing((-4,0),(4,0),4))
        self.assertFalse(crossing((-40,0),(40,0),1))
        self.assertFalse(crossing((-4,0),(4,0),1,7))
        def cleared(minimum, gate_maximum=0.5):
            return minimum>gate_maximum+3
        self.assertFalse(cleared(2))  # nose crossed, tail still near gate
        self.assertTrue(cleared(4))
        close=(ROOT/'addons/vehicles/functions/drivingGateCloseServer.sqf').read_text()
        self.assertIn('_crossSide+(_lateral select 0)',close)
        self.assertIn('(_span select 0) <= ((_job get "gateSpan") select 1)+3',close)

if __name__=='__main__': unittest.main()
