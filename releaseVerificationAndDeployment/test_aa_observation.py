"""AA shot observation must remain owner-local, bounded and separate from behaviour proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AAObservation(unittest.TestCase):
    def test_native_receipt_lifecycle_does_not_claim_fire_or_move_authority(self):
        source=(ROOT/'addons/vehicles/functions/cortexAAObserve.sqf').read_text()
        for guard in ('!local _vehicle','isNull _projectile','!local _gunner',
                      'CortexActorFireTaskAvailable','CortexIsEligible','serverTime+1',
                      'CBE_AIPass_Epoch','removeEventHandler ["Fired"','"edsubcat_aas"'):
            self.assertIn(guard,source)
        for command in ('doMove','doFire','reveal','setVehicleRadar','setVelocity','spawn','waitUntil'):
            self.assertNotIn(command,source)
        discover=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        self.assertIn('[_x] call CBE_fnc_CortexAAObserve;',discover)
        relocate=(ROOT/'addons/vehicles/functions/cortexAARelocate.sqf').read_text()
        for guard in ('count _shot != 11','_shot select 3)+120','aaRelocationConsumedAt',
                      'ENGAGEMENT_RENEWED','ORDER_REPLACED','CortexOwnershipLease',
                      'CortexGroupMove','CortexIsEligible','CortexActorFireTaskAvailable'):
            self.assertIn(guard,relocate)
        for command in ('doFire','reveal','setVehicleRadar','setVelocity','spawn','waitUntil'):
            self.assertNotIn(command,relocate)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        self.assertIn('[_group,_state,false] call CBE_fnc_CortexAARelocate',tick)
        self.assertIn('then {_groupMovementOwned=true}',tick)
        self.assertIn('serverTime+5',relocate)
        self.assertLess(relocate.index('_known findIf'),relocate.index('_state set ["aaRelocationConsumedAt"'))
        self.assertIn('THREAT_RENEWED',relocate)
        self.assertEqual(relocate.count('call _currentThreat'),2)
        self.assertIn('CBE_OperationGeneration',relocate)
        self.assertIn('CBE_AIPass_Contact_Enable',relocate)
        self.assertIn('if (!_eligible && {_record isEqualTo []}',source)
        self.assertIn('(_knowledge select 1)',source)
        self.assertIn('if (_contact isEqualTo []) exitWith {}',source)
        self.assertIn('private _current=count _record == 4 && {(_record select 0) == 2}',source)
        self.assertIn('count _record in [3,4]',source)
        self.assertIn('removeEventHandler ["IncomingMissile",_record select 3]',source)
        warning=source.split('private _warningHandler=',1)[1].split('_tracked pushBackUnique',1)[0]
        for proof in ('addEventHandler ["IncomingMissile"','_thisEventHandler','!local _group',
                      'CBE_AIPass_VehicleGunnery_Enable','serverTime+15',
                      '"CBE_AA_Observer",[2,clientOwner,_handler,_warningHandler]'):
            self.assertIn(proof,warning)
        self.assertIn('"CBE_AA_MissileWarning",nil',source)
        gunnery=(ROOT/'addons/vehicles/functions/cortexVehicles.sqf').read_text()
        receipt=gunnery.split('private _warnedBy=',1)[1].split('private _airPreference=',1)[0]
        for proof in ('_warning isEqualType []','count _warning == 6','== clientOwner',
                      '== _group','CBE_AIPass_Epoch','finite _until','serverTime < _until'):
            self.assertIn(proof,receipt)
        priority=gunnery.split('private _warningPriority=',1)[1].split('_ranked pushBack',1)[0]
        for proof in ('_enemy == _warnedBy','_gunner targetKnowledge _enemy',
                      '_warningKnowledge param [7,false,[true]]','_warningAge >= 0','_warningAge <= 3'):
            self.assertIn(proof,priority)
        self.assertLess(priority.index('case (_warningPriority)'),priority.index('case (_freshAir'))
        for forbidden in ('getPos','reveal','setMissileTarget','triggerAmmo','doMove'):
            self.assertNotIn(forbidden,priority+receipt+warning)


        self.assertIn('"AA_RELOCATE",time+((_until-serverTime) max 0)',relocate)
        self.assertIn('[_group,_state,_ordered,_enemies] call CBE_fnc_CortexAARelocate',tick)


        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertLess(stop.index('[_x,true] call CBE_fnc_CortexAAObserve'),
                        stop.index('if (hasInterface && {!isServer}) exitWith'))
if __name__=='__main__':unittest.main()
