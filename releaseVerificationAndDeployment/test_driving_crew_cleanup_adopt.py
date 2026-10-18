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
    def test_vehicle_seat_events_offer_only_actual_crew_without_new_polls(self):
        text=(ROOT/'addons/main/XEH_postInit.sqf').read_text(encoding='utf-8')
        vehicle=text.split('["LandVehicle","init",{',1)[1].split('},true,[],true] call CBA_fnc_addClassEventHandler;',1)[0]
        for event,key in (('GetIn','CBE_DrivingRecovery_GetInEH'),('SeatSwitched','CBE_DrivingRecovery_SeatEH')):
            self.assertEqual(vehicle.count('addEventHandler ["'+event+'"'),1)
            self.assertIn('if (isNil {_vehicle getVariable "'+key+'"})',vehicle)
        for actor in ('_actor','_first','_second'):
            self.assertIn('['+actor+',true] call CBE_fnc_DrivingRecoveryCrewAdopt',vehicle)
        self.assertLess(text.index('CBE_DrivingRecovery_GetInEH'),text.index('if (missionNamespace getVariable ["CBE_AIRebalance_Enable"'))
        for forbidden in ('doMove','doStop','forceSpeed','waitAndExecute','addPerFrameHandler'):
            self.assertNotIn(forbidden,vehicle)
if __name__=='__main__': unittest.main()
