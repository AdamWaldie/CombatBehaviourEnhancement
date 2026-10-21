"""Shutdown-cleanup authority and scheduling contracts, not engine acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class RecoveryCleanupTests(unittest.TestCase):
    def test_observation_cannot_issue_or_extend_a_reverse(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text()
        for forbidden in (' doMove ', ' forceSpeed ', 'setDriveOnPath', 'sendSimpleCommand',
                          'setVelocity', 'setPos', 'allVehicles', 'vehicles near',
                          'set ["deadline"', 'set ["hardDeadline"'):
            self.assertNotIn(forbidden,text)
        self.assertIn('call CBE_fnc_DrivingAssistRelease',text)
        self.assertIn('"simpleBefore","request","nativeReturn","queueBinding","rearEnvelope"] apply',text)
        self.assertIn('([_current] call _signature) isEqualTo _proof',text)
        self.assertIn('local _target',text)
        native=(ROOT/'addons/vehicles/functions/drivingQueueReverseCommit.sqf').read_text()
        issue=native.index('_vehicle sendSimpleCommand "BACK"')
        for proof in ('executionGranted','CBE_Driving_Brain','executionPreparation','motionBinding',
                      'serverTime >= _expires','CBE_fnc_DrivingRearPlan','CBE_fnc_DrivingDamageReceipt',
                      'CBE_fnc_DrivingQueueReverseCurrent','_linear >= 0.1','_angular >= 0.01'):
            self.assertLess(native.index(proof),issue)
        stop=native.split('// STOP is permitted only',1)[1]
        for proof in ('_cap > 0.001','"driverTask","__MISSING__"','"operatorTask","__MISSING__"',
                      'simpleStopIssued','_linear < 0.1','_angular < 0.01','serverTime-_since >= 1'):
            self.assertIn(proof,stop)
        for forbidden in (' forceSpeed ','setVelocity','setPos','doMove','waitAndExecute','addPerFrameHandler'):
            self.assertNotIn(forbidden,native)
        self.assertIn('["deadline",_expires],["hardDeadline",_expires]',native)
        self.assertIn('["ackUntil",(serverTime+2) min _expires]',native)
        self.assertIn('_next set ["queueStopAcknowledged",true]',native)
        observer=(ROOT/'addons/vehicles/functions/drivingQueueReverseCurrent.sqf').read_text()
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text()
        for guard in (observer,release):
            self.assertIn('queueStopAcknowledged',guard)
        settling=release.split('private _stopAcknowledged=',1)[1].split('[_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt',1)[0]
        for proof in ('queueStopAcknowledged','vectorMagnitude velocity _vehicle',
                      'vectorMagnitude angularVelocity _vehicle','!finite _stopLinear',
                      '!finite _stopAngular','_stopLinear >= 0.1','_stopAngular >= 0.01',
                      'if (_nativeStopPending) exitWith {}'):
            self.assertIn(proof,settling)
        pending_stop=release.split('if (_nativeStopPending) exitWith {\n    _work',1)[1].split('if ((_vehicle getVariable',1)[0]
        self.assertIn('call _holdOwnedRearCap',pending_stop)
        for forbidden in ('doMove','doFollow','sendSimpleCommand','serverTime+','set ["hardDeadline"'):
            self.assertNotIn(forbidden,pending_stop)
        self.assertIn('== "BACK" && {!_queueStopped}',release)
        # Acknowledged STOP retires old BACK authority even if destinations are unchanged.
        def owned_input(native_input,stop_acknowledged):
            return native_input == 'STOP' or (native_input == 'BACK' and not stop_acknowledged)
        self.assertTrue(owned_input('BACK',False))
        self.assertTrue(owned_input('STOP',True))
        self.assertFalse(owned_input('BACK',True))

        integration=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        for proof in ('["ADMIT",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueReverseCommit',
                      '[_nativeQueueMode,_group,_vehicle,_brain] call CBE_fnc_DrivingQueueReverseCommit',
                      '_queueHold=!_queueNativeActive', '_queueJournal getOrDefault ["ackUntil",-1]',
                      '_queueStarted', '_capMps=0;_capReceipt set [0,0];'):
            self.assertIn(proof,integration)


        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        gate=assist.split('private _mayRecoverOrdinaryRoute=',1)[1].split('private _priorOwner=',1)[0]
        self.assertIn('!("queueBinding" in',gate)
        record=assist.split('private _recordRecovery={',1)[1].split('private _reverseIssued=',1)[0]
        for proof in ('_sameEpisode && {"queueBinding" in _old}',
                      '_hard min (_queueBinding select 1)','else {serverTime}',
                      '_work set ["queueBinding",_queueBinding]','if (_queueBound) then {_deadline=_hard}'):
            self.assertIn(proof,record)
        # Original queue expiry narrows an existing recovery lifetime, never renews it.
        for original,expires in ((96,30),(20,30),(30,30)):
            self.assertLessEqual(min(original,expires),original)
            self.assertLessEqual(min(original,expires),expires)

        for identity in ('"route"','"driver"','"operator"','"driverCommand"','"command"',
                         '"started"','"deadline"','"hardDeadline"','"cap"','"baseline"'):
            self.assertIn(identity,text)
    def test_service_is_bounded_and_independent_of_tactical_workers(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text()
        self.assertIn('(_head+4) min count _queue',text)
        self.assertIn('[],0.25] call CBA_fnc_waitAndExecute',text)
        self.assertIn('count _registry > 0 && {!_scheduled}',text)
        self.assertIn('count _registry == 0',text)
        self.assertIn('_registry deleteAt _id',text)
        self.assertIn('_queue=_queue select [_head]',text)
        self.assertNotIn('CortexQueueJob',text)
        self.assertNotIn('addPerFrameHandler',text)

    def test_adoption_is_local_epoch_scoped_and_never_cancels_active_work(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryAdopt.sqf').read_text()
        self.assertIn('remoteExecutedOwner > 0',text)
        self.assertIn('_epoch == (_vehicle getVariable ["CBE_DrivingRecovery_LocalEpoch",0])',text)
        self.assertIn('&& {_gained} && {local _vehicle} && {alive _vehicle}',text)
        self.assertIn('private _lookup=count _work == 0 || {(_work getOrDefault ["kind",""]) == "REVERSE"',text)
        self.assertIn('(_work getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]',text)
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        self.assertLess(release.index('getOrDefault ["commandMode","DESTINATION"]'),release.index('private _retainAcrossLocality='))
        self.assertIn('if (_lookup && {_attempt < 5}',text)
        self.assertIn('[_vehicle,true,_attempt+1,_epoch],1]',text)
        edge=text.split('if (_nativeEdge) then {',1)[1].split('if (_epoch ==',1)[0]
        self.assertIn('serverTime+5',edge)
        self.assertIn('(_status select 4) != clientOwner',edge)
        reuse=text.split('private _edge=_vehicle getVariable',1)[1].split('private _transfer=',1)[0]
        self.assertIn('_edge select 2',reuse)
        self.assertNotIn('serverTime+',reuse)
        self.assertIn('CBE_AIPass_LocalHandler',reuse)
        self.assertNotIn('addEventHandler',text)
        xeh=(ROOT/'addons/main/XEH_postInit.sqf').read_text()
        self.assertIn('[_this select 0,_this select 1,0,-1,true] call CBE_fnc_DrivingRecoveryAdopt',xeh)

        self.assertIn('getOrDefault ["releasePending",false]',text)
        self.assertNotIn('call CBE_fnc_DrivingAssistRelease',text)
        self.assertNotIn('forceSpeed',text)
        self.assertNotIn('doMove',text)
        self.assertNotIn('set ["releasePending"',text)
        init=(ROOT/'addons/main/XEH_postInit.sqf').read_text()
        self.assertIn('["LandVehicle","init"',init)
        self.assertIn('addEventHandler ["Local"',init)
        self.assertLess(init.index('["LandVehicle","init"'),init.index('call CBE_fnc_CortexInit'))

    def test_each_deferred_return_registers_observation_before_returning(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        locality=text.split('if (_retainAcrossLocality && {!local',1)[1].split('private _handback=',1)[0]
        mobility=text.split('if (_owned && {!_executable}) exitWith {',1)[1].split('if (_owned) then {',1)[0]
        for branch in (locality,mobility):
            self.assertIn('[_vehicle] call CBE_fnc_DrivingRecoveryCleanup;',branch)
            self.assertLess(branch.index('set ["releasePending",true]'),branch.index('call CBE_fnc_DrivingRecoveryCleanup'))
            # Already-pending receipts also register; registration is outside first-publication guard.
            self.assertIn('};\n    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;\n    false',branch)
            for command in ('doMove','doStop','doFollow','forceSpeed','remoteExec','serverTime+'):
                self.assertNotIn(command,branch)

    def test_expired_pending_handback_keeps_proof_and_owned_zero_cap_without_replay_or_renewal(self):
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        gate=release.split('private _releaseExpired={',1)[1].split('private _driver=',1)[0]
        for marker in ('releasePending','hardDeadline','serverTime < _until','releaseUnresolved',
                       'UNRESOLVED_DEADLINE','UNRESOLVED_INVALID_DEADLINE'):
            self.assertIn(marker,gate)
        for forbidden in (' doMove ', 'doStop','forceSpeed','nil,true','serverTime+','set ["hardDeadline"'):
            self.assertNotIn(forbidden,gate)
        self.assertEqual(release.count('call _releaseExpired'),3)
        self.assertLess(release.index('if (_owned && {call _releaseExpired})'),release.index('if (_owned) then {'))
        self.assertIn('if (!_resume || {!(_work getOrDefault ["releasePending",false])}) exitWith {false}',gate)
        classify=(ROOT/'addons/vehicles/functions/drivingRecoveryCommandState.sqf').read_text()
        body=classify.split('params [[',1)[1]
        for forbidden in ('setVariable','doMove','doStop','forceSpeed','spawn','waitAndExecute'):
            self.assertNotIn(forbidden,body)
        for marker in ('"OWNED"','"PENDING"','"EXPIRED"','"LOST"','serverTime > _until',
                       '_position vectorDistance _goal <= 0.25','group _driver != _group'):
            self.assertIn(marker,classify)
        pending=release.split('// Pending/expired unchanged destination requests',1)[1].split('if (_retainAcrossLocality && {!local',1)[0]
        for marker in ('["PENDING","EXPIRED"]','call _releaseExpired','DEFERRED_NATIVE_ACK',
                       'call CBE_fnc_DrivingRecoveryCleanup'):
            self.assertIn(marker,pending)
        for forbidden in ('doMove','doStop','sendSimpleCommand','serverTime+','set ["hardDeadline"'):
            self.assertNotIn(forbidden,'\n'.join(line.split('//',1)[0] for line in pending.splitlines()))
        held=release.split('private _holdOwnedRearCap={',1)[1].split('// Pending/expired unchanged destination requests',1)[0]
        self.assertEqual(held.count('forceSpeed'),1)
        self.assertIn('_vehicle forceSpeed 0',held)
        self.assertIn('if (_commandState == "EXPIRED") then {call _holdOwnedRearCap}',pending)
        for proof in ('_expiredCap > 0','local _group',
                      'local _driver','local _operator','CortexZeusHeld','DrivingMovementAvailable',
                      'CortexCombatEffective','checkAIFeature "MOVE"','checkAIFeature "PATH"',
                      '(_assistState param [3,grpNull]) == _group',
                      '(_assistState param [0,-2]) == _expiredCap',
                      'isEqualTo (_work get "baseline")','isEqualTo _work'):
            self.assertLess(held.index(proof),held.index('_vehicle forceSpeed 0'))
        self.assertIn('_heldWork set ["cap",0];_assistState set [0,0]',held)
        self.assertIn('_work=_heldWork',held)
        self.assertNotIn('deleteAt "request"',held)
        self.assertLess(pending.index('call _holdOwnedRearCap'),pending.index('call _releaseExpired'))
        terminal=release.split('private _hardUntil=',1)[1].split('private _executable=',1)[0]
        for proof in ('_owned','releasePending','finite _hardUntil','serverTime >= _hardUntil'):
            self.assertLess(terminal.index(proof),terminal.index('call _holdOwnedRearCap'))
        self.assertLess(terminal.index('call _holdOwnedRearCap'),terminal.index('call _releaseExpired'))
        for forbidden in ('sendSimpleCommand','doMove','doStop','serverTime+','set ["hardDeadline"'):
            self.assertNotIn(forbidden,terminal)
        self.assertIn('_commandState == "OWNED"',release.split('private _owned=',1)[1])
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('!_queueCrossing && {!_queueNativeActive} && {!_recoveryRequestPending} && {call _mayRecoverRoute}',start)
        self.assertIn('"NATIVE_ACK_UNRESOLVED"] call CBE_fnc_DrivingRecoveryRelease',start)
        for goal, receipt in (('_destination','_forwardCommands'),('_rear','_rearCommands')):
            self.assertIn('[+'+goal+',serverTime+2,'+receipt+']',start)

    def test_unresolved_tickets_retire_and_do_not_reenter_fresh_assistance(self):
        cleanup=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text(encoding='utf-8')
        self.assertEqual(cleanup.count('getOrDefault ["releaseUnresolved",false]'),3)
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('|| {_recoveryWork getOrDefault ["releaseUnresolved",false]}',start)
        self.assertIn('"ORDER_OR_SEATS_CHANGED",false] call CBE_fnc_DrivingRecoveryRelease',start)
