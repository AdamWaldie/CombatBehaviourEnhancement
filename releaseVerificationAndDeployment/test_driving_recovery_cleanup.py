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
