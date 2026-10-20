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

        self.assertIn('"AA_RELOCATE",time+((_until-serverTime) max 0)',relocate)
        self.assertIn('[_group,_state,_ordered,_enemies] call CBE_fnc_CortexAARelocate',tick)


        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertLess(stop.index('[_x,true] call CBE_fnc_CortexAAObserve'),
                        stop.index('if (hasInterface && {!isServer}) exitWith'))
if __name__=='__main__':unittest.main()
