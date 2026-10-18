"""Late native crew locality must offer existing cleanup without replaying movement."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CrewCleanupAdopt(unittest.TestCase):
    def test_actual_local_driver_or_commander_only_registers_existing_adoption(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryCrewAdopt.sqf').read_text(encoding='utf-8')
        for guard in ('remoteExecutedOwner > 0','!_gained','!local _actor','!local _vehicle',
                      '_vehicle == _actor','isKindOf "LandVehicle"','isKindOf "StaticWeapon"',
                      '_actor in [driver _vehicle,effectiveCommander _vehicle]'):
            self.assertIn(guard,text)
        self.assertIn('[_vehicle,true] call CBE_fnc_DrivingRecoveryAdopt',text)
        for forbidden in ('doMove','doFollow','doStop','forceSpeed','serverTime+','waitAndExecute','allVehicles'):
            self.assertNotIn(forbidden,text)
    def test_existing_actor_handler_and_init_offer_crew_edges(self):
        text=(ROOT/'addons/main/XEH_postInit.sqf').read_text(encoding='utf-8')
        self.assertIn('_this call CBE_fnc_DrivingRecoveryCrewAdopt',text)
        self.assertIn('[_actor,local _actor] call CBE_fnc_DrivingRecoveryCrewAdopt',text)
        self.assertEqual(text.count('_actor addEventHandler ["Local"'),1)
if __name__=='__main__': unittest.main()
