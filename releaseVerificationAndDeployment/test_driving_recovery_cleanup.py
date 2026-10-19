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
        self.assertIn('([_current] call _signature) isEqualTo _proof',text)
        self.assertIn('local _target',text)
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
        locality=text.split('if (_retainAcrossLocality &&',1)[1].split('private _handback=',1)[0]
        mobility=text.split('if (_owned && {!_executable}) exitWith {',1)[1].split('if (_owned) then {',1)[0]
        for branch in (locality,mobility):
            self.assertIn('[_vehicle] call CBE_fnc_DrivingRecoveryCleanup;',branch)
            self.assertLess(branch.index('set ["releasePending",true]'),branch.index('call CBE_fnc_DrivingRecoveryCleanup'))
            # Already-pending receipts also register; registration is outside first-publication guard.
            self.assertIn('};\n    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;\n    false',branch)
            for command in ('doMove','doStop','doFollow','forceSpeed','remoteExec','serverTime+'):
                self.assertNotIn(command,branch)

    def test_expired_pending_handback_keeps_proof_without_commands_or_renewal(self):
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        gate=release.split('private _releaseExpired={',1)[1].split('private _driver=',1)[0]
        for marker in ('releasePending','hardDeadline','serverTime < _until','releaseUnresolved',
                       'UNRESOLVED_DEADLINE','UNRESOLVED_INVALID_DEADLINE'):
            self.assertIn(marker,gate)
        for forbidden in (' doMove ', 'doStop','forceSpeed','nil,true','serverTime+','set ["hardDeadline"'):
            self.assertNotIn(forbidden,gate)
        self.assertEqual(release.count('call _releaseExpired'),2)
        self.assertLess(release.index('if (_owned && {call _releaseExpired})'),release.index('if (_owned) then {'))
        self.assertIn('if (!_resume || {!(_work getOrDefault ["releasePending",false])}) exitWith {false}',gate)
    def test_unresolved_tickets_retire_and_do_not_reenter_fresh_assistance(self):
        cleanup=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text(encoding='utf-8')
        self.assertEqual(cleanup.count('getOrDefault ["releaseUnresolved",false]'),3)
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('|| {_recoveryWork getOrDefault ["releaseUnresolved",false]}',start)
        self.assertIn('"ORDER_OR_SEATS_CHANGED",false] call CBE_fnc_DrivingRecoveryRelease',start)
