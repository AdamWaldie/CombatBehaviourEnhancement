"""Alternate-path native task ownership gates; not engine movement acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class NativeAdmissionTests(unittest.TestCase):
    def test_direct_native_intent_keeps_original_goal_and_observes_return_without_replay(self):
        def read(name):return (ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
        native=read('drivingNativeRouteReceipt')
        for proof in ('count waypoints _nativeGroup > 1','!local _nativeGroup','!local _nativeVehicle',
                      '_nativePrior select 7','_nativePrior select 8','_nativeDriverGoal vectorDistance _nativeGoal > 3',
                      'CBE_fnc_DrivingRecoveryCommandState','"NATIVE_MOVE",_nativeGroup'):
            self.assertIn(proof,native)
        body=native.split('params [[',1)[1]
        for forbidden in ('doMove','setVariable','getForcedSpeed','execFSM','addWaypoint','DrivingRouteReceipt'):
            self.assertNotIn(forbidden,body)
        self.assertIn('call CBE_fnc_DrivingNativeRouteReceipt',read('drivingRouteReceipt'))
        self.assertIn('+(_nativeGoalReceipt select 6)',read('drivingRouteGoal'))
        release=read('drivingRecoveryRelease')
        observation=release.split('// A native-route return was already issued.',1)[1].split('// This executor restores',1)[0]
        cleanup=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text(encoding='utf-8')
        self.assertIn('"request","nativeReturn","queueBinding"',cleanup)
        observer=cleanup.split('private _returnRetired=',1)[1].split('_current=_target getVariable',1)[0]
        self.assertIn('"DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease',observer)
        self.assertIn('if (_returnRetired) then',observer)
        promotion=release.split('// Shutdown can follow an already-issued',1)[1].split('// A native-route return',1)[0]
        self.assertIn('_work set ["nativeReturn",+(_work get "request")]',promotion)
        self.assertNotIn('serverTime+',promotion)
        self.assertNotIn('doMove',promotion)
        self.assertIn('== "REVERSE" || {(_work getOrDefault ["nativeReturn",[]]) isNotEqualTo []}',cleanup)
        self.assertIn('"bypassReturn"',cleanup.split('private _signature=',1)[1].split('private _abortSignature=',1)[0])
        self.assertIn('[_returnGoal,_returnUntil,_returnBefore] call _temporaryReturnState',read('drivingRecoveryCommandState'))

        self.assertIn('NATIVE_ROUTE_OBSERVED',observation)
        self.assertIn('releaseUnresolved',observation)
        self.assertNotIn('doMove',observation.split('if ((_work',1)[1])
        resumed=observation.split('private _returnBrain=',1)[1].split('if ((_vehicle getVariable',1)[0]
        self.assertIn('_work set ["deadline",_work get "hardDeadline"]',resumed)
        self.assertNotIn('set ["hardDeadline"',resumed)
        self.assertNotIn('doMove',resumed)
        self.assertIn('_admitted select 6) isEqualTo _nativeGoal',native)
        self.assertIn('serverTime >= (_work get "hardDeadline")',release)
        self.assertIn('["nativeReturn",[+_originalGoal,(serverTime+2) min (_work get "hardDeadline")',release)
        self.assertIn('if (!_nativeHandback) then {doStop _driver',release)
        consent=read('drivingPassCanConsent')
        self.assertNotIn('if (_nativeRoute && {_protocol != "QUEUE"}) exitWith {false}',consent)
        self.assertIn('if (_nativeRoute) exitWith {count _route == 9}',consent)
        self.assertLess(consent.index('call CBE_fnc_DrivingGateIntent'),consent.index('if (_nativeRoute) exitWith'))
        gate_route=read('drivingGateRouteMatches')
        for proof in ('count _gateRoute != 9','_gateRouteOwner != groupOwner _gateRouteGroup',
                      '_gateRouteOwner != owner _gateRouteVehicle','_gateRoute select 6','isServer'):
            self.assertIn(proof,gate_route)
        self.assertNotIn('expectedDestination',gate_route.split('params [[',1)[1])
        self.assertNotIn('"NATIVE_MOVE") exitWith {false}',read('drivingGateIntent'))
        for name in ('drivingGateOpenServer','drivingGateCloseServer'):
            self.assertIn('call CBE_fnc_DrivingGateRouteMatches',read(name))
        queue_auto=read('drivingQueueAutoStep')
        self.assertNotIn('"NATIVE_MOVE") exitWith {[false,false]}',queue_auto)
        self.assertIn('"CBE_AIPass_DrivingAssist_Queue_Enable",false',queue_auto)
        corridor=read('drivingCorridorStep')
        self.assertIn('if (_nativeRoute && {_convoy})',corridor)
        self.assertIn('call _corridorParentCurrent',corridor)
        self.assertIn('_work set ["hardDeadline",_corridorHard]',corridor)
        self.assertIn('_work set ["recoveryParent",+_corridorBinding]',corridor)
        self.assertIn('_spent set ["bypassSpent",true]',corridor)
        self.assertIn('then {+(_route select 6)}',corridor)
        corridor_release=read('drivingCorridorRelease')
        for proof in ('serverTime < _nativeHard','currentCommand _driver == "STOP"',
                      'currentCommand _operator == "STOP"','isEqualTo _nativeParent',
                      '(serverTime+2) min _nativeHard','["bypassReturn",["CORRIDOR"',
                      'private _returnGoal=+(_route select 6)'):
            self.assertIn(proof,corridor_release)
        shutdown=read('drivingAssistRelease')
        self.assertLess(shutdown.index('_nativeCorridorGroup,"DRIVING_RELEASED"'),
                        shutdown.index('_recovery get "group","DRIVING_RELEASED"'))
        bypass=read('drivingBypassStep')
        self.assertIn('if (_nativeRoute && {!(_controller in ["ORDINARY","QUEUE"])})',bypass)
        self.assertIn('(!_nativeRoute || {_parentBound} || {_queueNativeBound})',bypass)
        self.assertIn('(_queueAgreement getOrDefault ["ownerRoute",[]]) isEqualTo _route',bypass)
        self.assertIn('!_parentBound || {_parentBinding isNotEqualTo []',bypass)
        self.assertIn('then {+(_route select 6)}',bypass)
        handback=read('drivingBypassRelease')
        self.assertIn('currentCommand _driver == "STOP"',handback)
        self.assertIn('currentCommand _operator == "STOP"',handback)
        self.assertIn('isEqualTo _nativeParent',handback)
        self.assertIn('then {+(_route select 6)}',handback)
        self.assertIn('(serverTime+2) min _hard',handback)
        self.assertIn('_nativeState in ["OWNED","PENDING","EXPIRED","BYPASS","CORRIDOR"]',native)
        self.assertIn('_nativeState == "BYPASS"',native)
        self.assertIn('"recoveryParent"',native)
        self.assertIn('"bypassReturn" in _nativeWork',native)
        classifier=read('drivingRecoveryCommandState')
        child=classifier.split('private _child=',1)[1].split('private _request=',1)[0]
        self.assertIn('_childDeadline <= _hard',child)
        self.assertNotIn('serverTime <',child)
        for proof in ('_until <= _hard','_phase in ["APPROACH","CROSS"]',
                      'count _child == 0','_driverGoal vectorDistance _entry <= 0.25',
                      '"CORRIDOR"} else {"LOST"}'):
            self.assertIn(proof,child)
        self.assertIn('_nativeState == "CORRIDOR"',native)
        self.assertIn('serverTime < _nativeHard',handback)
        shutdown=read('drivingAssistRelease')
        self.assertLess(shutdown.index('_nativeBypassGroup,"DRIVING_RELEASED"'),
                        shutdown.index('_recovery get "group","DRIVING_RELEASED"'))
        self.assertIn('_nativeRoute && {_reason == "RECOVERY_PARENT_CHANGED"}',bypass)
        native_ack=classifier.split('// A native bypass returns both',1)[1].split('private _position=',1)[0]
        self.assertIn('if (_driverAck && {_operatorAck})',native_ack)
        self.assertIn('serverTime > _until',native_ack)
        # Partial acknowledgement remains pending, never grants a fresh clock or success.
        def state(driver_ack,operator_ack,driver_same,operator_same,now,until):
            if driver_ack and operator_ack:return 'OWNED'
            if not (driver_ack or driver_same) or not (operator_ack or operator_same):return 'LOST'
            return 'EXPIRED' if now>until else 'PENDING'
        self.assertEqual(state(False,True,True,False,1,2),'PENDING')
        self.assertEqual(state(True,True,False,False,1,2),'OWNED')
        self.assertEqual(state(False,True,True,False,3,2),'EXPIRED')
        self.assertEqual(state(False,True,False,False,1,2),'LOST')


    def test_native_recovery_adoption_requires_real_edge_and_preserves_spent_episode(self):
        adopt=(ROOT/'addons/vehicles/functions/drivingNativeRecoveryAdopt.sqf').read_text(encoding='utf-8')
        edge=(ROOT/'addons/vehicles/functions/drivingRecoveryAdopt.sqf').read_text(encoding='utf-8')
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text(encoding='utf-8')
        for proof in ('CBE_DrivingNative_Transfer','CBE_DrivingNative_LocalEdge',
                      '_adoptRoute select 7','_adoptRoute select 8','serverTime >= (_adoptWork get "hardDeadline")',
                      'getForcedSpeed _adoptVehicle','CBE_fnc_DrivingRecoveryCommandState',
                      '"SIMPLE_BACK"','CBE_DrivingAbort_Hold','"queueBinding" in _adoptWork','CortexActorMoveReserved','CortexZeusHeld','nativeAdoptedFrom',
                      '_adoptWork getOrDefault ["baseline",[]]','_adoptNextRoute set [7,_adoptEpoch]',
                      '"ADOPTED_NATIVE_RECOVERY"','CBE_fnc_DrivingOperationStart'):
            self.assertIn(proof,adopt)
        dispatch=adopt.split('if (_adoptAccepted) then {',1)[1]
        self.assertLess(dispatch.index('if (_adoptResume) then'),dispatch.index('CBE_fnc_DrivingOperationStart'))
        cleanup=dispatch.split('} else {',1)[1]
        self.assertIn('CBE_fnc_DrivingAssistRelease',cleanup)
        self.assertNotIn('DrivingOperationStart',cleanup)
        self.assertIn('if (!_adoptResume && {_adoptChildKey == ""}) then {_adoptNext set ["releasePending",true]}',adopt)
        for forbidden in ('doMove','doStop','doFollow','forceSpeed','sendSimpleCommand',
                          'set ["hardDeadline"','set ["deadline"','serverTime+','waitAndExecute','execFSM'):
            self.assertNotIn(forbidden,adopt.split('params [[',1)[1])
        native_edge=edge.split('if (_nativeEdge) then {',1)[1].split('if (_epoch ==',1)[0]
        self.assertIn('CBE_DrivingNative_LocalEdge',native_edge)
        self.assertIn('if (isNull _nativeEdgeGroup) then',native_edge)
        self.assertIn('(_nativeEdgeRoute select 2) isEqualTo _vehicle',native_edge)
        self.assertIn('serverTime+5',native_edge)
        self.assertIn('CBE_DrivingNative_Transfer',locality)
        self.assertLess(locality.index('private _abortSource=[]'),locality.index('CBE_fnc_DrivingOperationFinish'))
        # Metadata transfer must leave every clock/budget and the original goal intact.
        journal={'route':['NATIVE_MOVE',1,2,3,4,[],[10,20,0],7,8],
                 'hardDeadline':96,'deadline':42,'started':12,'progressAnchor':[0,0,0],
                 'kind':'REVERSE','baseline':[-1],'bypassSpent':True}
        original=dict(journal)
        next_journal=dict(journal);next_journal['route']=list(journal['route'])
        next_journal['route'][7:]=[9,10]
        for key in ('hardDeadline','deadline','started','progressAnchor','kind','baseline','bypassSpent'):
            self.assertEqual(next_journal[key],original[key])
        self.assertEqual(next_journal['route'][:7],original['route'][:7])
        for proof in ('_adoptChildKey != ""','_adoptChildState in ["BYPASS","CORRIDOR"]',
                      '_childUntil > (_adoptWork get "hardDeadline")','count _childPoints > 24',
                      '_adoptNextChild set ["route",_adoptNextRoute]',
                      '_adoptNextChild set ["recoveryParent"','_adoptNextChild deleteAt "capture"',
                      '(_adoptVehicle getVariable [_adoptChildKey,createHashMap]) isNotEqualTo _adoptChild',
                      '["CBE_DrivingPass_Work","CBE_DrivingAbort_Hold"]'):
            self.assertIn(proof,adopt)
        child={'phase':'FOLLOW','deadline':80,'points':[[0,0,0],[10,0,0]],'index':1,
               'route':original['route'],'capture':[[1,0,0],20,[8,7]],'recoveryParent':['old']}
        carried=dict(child);carried['route']=next_journal['route'];carried.pop('capture')
        for key in ('phase','deadline','points','index'):self.assertEqual(carried[key],child[key])
        self.assertNotIn('capture',carried)
        for proof in ('_adoptParentExpired && {_adoptChildKey == ""}',
                      '_childUntil < 0','_adoptExpiredChild=_adoptParentExpired || {serverTime >= _childUntil}',
                      'if (_adoptExpiredChild) then {_adoptResume=false}'):
            self.assertIn(proof,adopt)
        self.assertIn('serverTime >= (_adoptWork get "hardDeadline")+5',adopt)
        def custody(edge_live,parent_until,child_until,now):
            if not edge_live or child_until<0 or child_until>parent_until or now>=parent_until+5:return 'REFUSED'
            return 'CLEANUP_ONLY' if now>=min(parent_until,child_until) else 'RESUME'
        self.assertEqual(custody(True,96,80,50),'RESUME')
        self.assertEqual(custody(True,96,80,81),'CLEANUP_ONLY')
        self.assertEqual(custody(True,96,80,100),'CLEANUP_ONLY')
        self.assertEqual(custody(False,96,80,100),'REFUSED')
        self.assertEqual(custody(True,96,80,102),'REFUSED')
        self.assertEqual(custody(True,96,-1,50),'REFUSED')
        return_proof=adopt.split('private _adoptReturnProof=',1)[1].split('private _adoptState=',1)[0]
        for proof in ('_adoptChildKey == ""','_adoptCommandState in ["OWNED","PENDING","EXPIRED"]',
                      '"nativeReturn"','"bypassReturn"','"request"','currentCommand _x in ["STOP","FOLLOW"]'):
            self.assertIn(proof,return_proof)
        for forbidden in ('serverTime+','doMove','set ["nativeReturn"','set ["request"'):
            self.assertNotIn(forbidden,return_proof)
        def task_allowed(command,return_state,issued_return):
            return command in ('','MOVE','WAIT') or (issued_return and return_state in ('OWNED','PENDING','EXPIRED') and command in ('STOP','FOLLOW'))
        self.assertTrue(task_allowed('FOLLOW','PENDING',True))
        self.assertTrue(task_allowed('STOP','PENDING',True))
        self.assertFalse(task_allowed('FOLLOW','LOST',True))
        self.assertFalse(task_allowed('FOLLOW','PENDING',False))
        self.assertFalse(task_allowed('ACTION','PENDING',True))

    def test_both_seats_require_idle_or_route_matching_move_before_acquisition(self):
        for name in ('drivingBypassStep','drivingCorridorStep'):
            source=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            helper=source.split('private _nativeAdmissionReady={',1)[1].split('\n};',1)[0]
            for marker in ('[_driver,_operator] findIf','toUpperANSI currentCommand _x','_command != ""',
                           '_command != "MOVE"','expectedDestination _x','vectorDistance _destination > 3'):
                self.assertIn(marker,helper)
            self.assertGreaterEqual(source.count('call _nativeAdmissionReady'),2)
            self.assertEqual(source.count('setDriveOnPath'),1)
    def test_ordinary_recovery_preserves_individual_seat_reservations(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        helper=assist.split('private _nativeTaskFree={',1)[1].split('private _routeIdentity=',1)[0]
        self.assertIn('!([_actor] call CBE_fnc_CortexActorMoveReserved)',helper)
        for seat in ['_driver','_movementOperator']:
            self.assertGreaterEqual(assist.count(f'[{seat}] call _nativeTaskFree'),2)
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        guard=release.split('} forEach [_driver,_operator];',1)[0]
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',guard)
        self.assertLess(release.index('CBE_fnc_CortexActorMoveReserved'),release.index('doStop _driver'))
        self.assertNotIn('setVariable ["CBE_Cortex_ActorMove",nil]',release)

    def test_alternate_paths_preserve_seat_reservations_during_execution_and_cleanup(self):
        for name,helper in [('drivingBypassStep','_seatsAvailable'),('drivingCorridorStep','_crewReady')]:
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            readiness=text.split(f'private {helper}={{',1)[1].split('} < 0',1)[0]
            self.assertIn('[_driver,_operator] findIf',readiness)
            self.assertIn('[_x] call CBE_fnc_CortexActorMoveReserved',readiness)
            writer=text.split('private _mayWrite={',1)[1].split('};',1)[0]
            self.assertIn(f'call {helper}',writer)
        for name,actor in [('drivingBypassRelease','_x'),('drivingCorridorRelease','_actor')]:
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertLess(text.index(f'!([{actor}] call CBE_fnc_CortexActorMoveReserved)'),text.index('doStop _driver'))
            self.assertNotIn('setVariable ["CBE_Cortex_ActorMove",nil]',text)

    def test_recovery_release_validates_route_and_mobility_before_any_stop(self):
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        transaction=release.split('private _released=false;',1)[1]
        self.assertIn('isNil {',transaction)
        self.assertLess(transaction.index('isNil {'),transaction.index('CBE_DrivingRecovery_Work'))
        for check in ('alive _vehicle','canMove _vehicle','simulationEnabled _vehicle',
                      '!isObjectHidden _vehicle','call CBE_fnc_DrivingRouteGoal',
                      'if (_originalGoal isNotEqualTo []) then {'):
            self.assertLess(transaction.index(check),transaction.index('doStop _driver'))
        self.assertLess(transaction.index('doStop _driver'),transaction.index('_operator doMove'))
        self.assertIn('if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work)',transaction)
        for forbidden in ('sleep ', 'waitUntil', 'spawn ', 'setCurrentWaypoint', 'deleteWaypoint', 'enableAI'):
            self.assertNotIn(forbidden,transaction)

    def test_recovery_holds_without_dismounted_or_disabled_follow_target(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        target=text.split('private _mountedTarget=',1)[1].split('doStop _driver',1)[0]
        for check in ('CortexCombatEffective','_leaderVehicle != _leader',
                      '_leaderVehicle isKindOf "LandVehicle"','alive _leaderVehicle',
                      'canMove _leaderVehicle','simulationEnabled _leaderVehicle',
                      '!isObjectHidden _leaderVehicle'):
            self.assertIn(check,target)
        handback=text.split('_handback="STOP_ONLY";',1)[1].split('if ((_vehicle getVariable',1)[0]
        gate='if (_leaderVehicle == _vehicle || {_mountedTarget}) then {'
        for command in ('_driver doFollow _operator','_operator doFollow _leader','_operator doMove'):
            self.assertLess(handback.index(gate),handback.index(command))
        for outcome in ('METADATA_ONLY','STOP_ONLY','AUTHORED_ROUTE','MOUNTED_LEADER'):
            self.assertIn(f'"{outcome}"',text)
        self.assertIn('_work get "hardDeadline",_handback],true]',text)
        self.assertNotIn('getIn',handback)
        self.assertNotIn('moveIn',handback)

    def test_unavailable_reverse_handback_retains_proof_and_retries_before_acquisition(self):
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        defer=release.split('if (_owned && {!_executable}) exitWith {',1)[1].split('if (_owned) then {',1)[0]
        self.assertIn('_work set ["releasePending",true]',defer)
        self.assertIn('"DEFERRED"',defer)
        self.assertLess(defer.index('if !(_work getOrDefault ["releasePending",false])'),defer.index('_vehicle setVariable'))
        for forbidden in ('nil,true','doMove','doStop','forceSpeed','serverTime+','waitAndExecute','spawn'):
            self.assertNotIn(forbidden,defer)
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        pending=assist.split('_recoveryWork getOrDefault ["releasePending",false]',1)[1].split('private _recoveryOwned=',1)[0]
        self.assertIn('"DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease',pending)
        self.assertIn('_recoveryWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]',pending)
        self.assertLess(assist.index('"DEFERRED_HANDBACK"'),assist.index('private _mayIssueDriving'))
        self.assertLess(release.index('if (_owned && {!_executable}) exitWith'),release.index('doStop _driver'))

    def test_recovery_admission_and_handback_both_preserve_all_trigger_links(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        admission=assist.split('private _recoveryOrderFree = {',1)[1].split('private _mayRecoverRoute',1)[0]
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        for text in [admission,release]:
            self.assertIn('call CBE_fnc_DrivingRouteGoal',text)
        goal=(ROOT/'addons/vehicles/functions/drivingRouteGoal.sqf').read_text(encoding='utf-8')
        self.assertIn('synchronizedTriggers _goalWaypoint isNotEqualTo []',goal)
        self.assertIn('synchronizedWaypoints _goalWaypoint isNotEqualTo []',goal)
        self.assertNotIn('triggerActivated',admission)

    def test_pre_path_rechecks_do_not_reject_fixed_path_owned_stop(self):
        bypass=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text(encoding='utf-8')
        self.assertIn('(_work get "phase") == "PLAN"} && {!(call _nativeAdmissionReady)',bypass)
        corridor=(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text(encoding='utf-8')
        self.assertIn('(_work getOrDefault ["phase",""]) == "APPROACH"',corridor)
        self.assertIn('call _mayWrite} && {call _approachTasksReady}',corridor)
        for name in ('drivingBypassRelease','drivingCorridorRelease'):
            source=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertNotIn('call _nativeAdmissionReady',source)
if __name__=='__main__': unittest.main()
