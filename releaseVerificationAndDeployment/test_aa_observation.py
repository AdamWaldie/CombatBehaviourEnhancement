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
        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertLess(stop.index('[_x,true] call CBE_fnc_CortexAAObserve'),
                        stop.index('if (hasInterface && {!isServer}) exitWith'))
if __name__=='__main__':unittest.main()
