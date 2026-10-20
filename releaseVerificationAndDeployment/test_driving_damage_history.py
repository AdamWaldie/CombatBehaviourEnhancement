"""Rear recovery keeps observed repair minima; offline contracts are not collision evidence."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingDamageHistoryTests(unittest.TestCase):
    def test_original_receipts_and_minima_are_captured_without_damage_suppression(self):
        source=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        for marker in ('_work set ["rearMinimumDamage",_work get "rearDamage"]',
                       '_work set ["rearMinimumHitpoints",_rearHitpointReceipt apply {+_x}]',
                       '_minimum min _observed','_observed > _minimum+0.01',
                       '_liveDamage > _minimumDamage+0.01','_minimumDamage <= _rearDamage',
                       '_minimum > ((_rearHitpoints select 2) select _hitIndex)'):
            self.assertIn(marker,source)
        update=source.split('// Repairs lower observation minima;',1)[1].split('} else {_rearPathRejected=true}',1)[0]
        for guard in ('CBE_Driving_Brain','CBE_DrivingRecovery_Work','ownerEpoch','_routeIdentity',
                      'isEqualTo _minimumHitpoints','== _minimumDamage','expectedDestination _driver',
                      'expectedDestination _movementOperator','getOrDefault ["deadline",-1]'):
            self.assertIn(guard,update)
        for forbidden in ('setDamage','setHitPointDamage','allowDamage','set ["started"','set ["deadline"','set ["hardDeadline"'):
            self.assertNotIn(forbidden,update)
    def test_shared_reader_is_owner_local_and_bounded(self):
        source=(ROOT/'addons/vehicles/functions/drivingDamageReceipt.sqf').read_text(encoding='utf-8')
        for marker in ('!local _damageVehicle','getAllHitPointsDamage','_count > 128','finite _x','_table apply {+_x}'):
            self.assertIn(marker,source)
        for forbidden in ('setVariable','setDamage','allowDamage','doMove','setVelocity'):
            self.assertNotIn(forbidden,source)
