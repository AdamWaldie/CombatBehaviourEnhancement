"""Split-owner retention must preserve proof without granting remote movement authority."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source():return (ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
class RecoveryLocalityRetentionTests(unittest.TestCase):
    def test_retention_requires_exact_issued_context_and_rejects_other_tasks(self):
        text=source()
        gate=text.split('private _retainAcrossLocality=',1)[1].split('if (_retainAcrossLocality',1)[0]
        for proof in ('_resume','"REVERSE"','alive _vehicle','driver _vehicle == _driver',
                      '_liveOperator == _operator','getForcedSpeed _vehicle','driverCommand',
                      'expectedDestination _operator','DrivingRouteReceipt','CBE_Convoy_Active',
                      'CBE_ExternalDrivingOwner','CortexExternalTakeover','group _x != _group',
                      'vehicle _x != _vehicle','remoteControlled','CBE_Cortex_ActorMove',
                      'toUpperANSI currentCommand _x in ["","MOVE","WAIT"]'):
            self.assertIn(proof,gate)
        # Nonlocal actor reservation expiry is not inferred on this machine's clock.
        self.assertNotIn('CortexActorMoveReserved',gate)
        self.assertNotIn('serverTime+',gate)
    def test_split_owner_path_retains_original_journal_without_native_write_or_clock_renewal(self):
        text=source()
        branch=text.split('// expectedDestination is local-argument.',1)[1].split('// A native-route return',1)[0]
        for proof in ('!local _group','!local _splitDriver','!local _splitOperator','releasePending',
                      '"DEFERRED_LOCALITY"','"UNRESOLVED_LOCALITY"','"LOCALITY_PROOF_LOST"',
                      'getOrDefault ["hardDeadline",-1]','serverTime >= _splitUntil','false'):
            self.assertIn(proof,branch)
        for forbidden in ('doStop','doMove','doFollow','forceSpeed','remoteExec',
                          'serverTime+','waitAndExecute','addPerFrameHandler','expectedDestination _',
                          'currentCommand','DrivingRecoveryCommandState'):
            self.assertNotIn(forbidden,branch)
        self.assertLess(text.index('private _splitDriver='),text.index('call CBE_fnc_DrivingRecoveryCommandState'))
        self.assertIn('if (!_splitExpired) then',branch)
    def test_retention_is_distinct_from_full_owner_command_authority(self):
        text=source()
        owned=text.split('private _owned=',1)[1].split('private _executable=',1)[0]
        self.assertIn('local _group',owned)
        self.assertIn('local _x',owned)
        self.assertIn('CortexActorMoveReserved',owned)
        self.assertIn('DrivingMovementAvailable',owned)
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        pending=assist.split('_recoveryWork getOrDefault ["releasePending",false]',1)[1].split('private _recoveryOwned=',1)[0]
        self.assertIn('"DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease',pending)
