"""Independent purpose/mode cancellation source contracts; not live-fire acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ArtilleryFireSessions(unittest.TestCase):
    def test_each_disable_uses_its_own_fire_generation(self):
        s=(ROOT/'addons/core/functions/aiTweaksSettingChanged.sqf').read_text(encoding='utf-8')
        block=s.split('private _fireGeneration=switch',1)[1].split('private _scootGeneration=',1)[0]
        for setting,key in (('Artillery_Enable','SupportFireGeneration'),
                            ('VehicleGunnery_Enable','DangerFireGeneration'),
                            ('ArtillerySmoke_Enable','SmokeFireGeneration')):
            self.assertIn('CBE_AIPass_'+setting,block)
            self.assertIn('CBE_Artillery_'+key,block)
        self.assertNotIn('CounterGeneration',block)
        self.assertNotIn('ShootAndScoot',block)
    def test_admission_captures_original_epochs_and_mission_checks_mode_separately(self):
        fire=(ROOT/'addons/support/functions/cortexArtilleryFire.sqf').read_text(encoding='utf-8')
        self.assertLess(fire.index('private _fireEpochs='),fire.index('private _retreatSmoke'))
        self.assertIn('[_x] call _batteryCrewUsable',fire)
        self.assertIn('!([_battery] call _batteryCrewUsable)',fire)
        crew=fire.split('private _batteryCrewUsable=',1)[1].split('if (isNull _battery)',1)[0]
        for guard in ('CortexCombatEffective','isPlayer _gunner','simulationEnabled _asset'):
            self.assertIn(guard,crew)
        self.assertIn('["fireGeneration",_fireEpochs select',fire)
        self.assertIn('["smokeGeneration",_fireEpochs select 2]',fire)
        step=(ROOT/'addons/support/functions/cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _smokeExpired=(_mission get "mode") == "SMOKE"',step)
        self.assertIn('_counterExpired || {_fireExpired} || {_smokeExpired}',step)
    def test_owner_request_signature_and_native_gate_include_original_generations(self):
        shot=(ROOT/'addons/support/functions/cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        self.assertIn('_counterGeneration,_fireGeneration,_smokeGeneration]',shot)
        gate=shot.split('private _fireSessionCurrent={',1)[1].split('private _danger=',1)[0]
        self.assertIn('_fireGeneration == (missionNamespace getVariable',gate)
        self.assertIn('_mode != "SMOKE"',gate)
        self.assertIn('_smokeGeneration == (missionNamespace getVariable',gate)
        self.assertEqual(shot.count('call _fireSessionCurrent'),2)
        self.assertEqual(shot.count('call _operatorAvailable'),2)
        available=shot.split('private _operatorAvailable=',1)[1].split('if (!(call _fireSessionCurrent)',1)[0]
        for guard in ('local _operator','isPlayer _operator','gunner _battery == _operator',
                      'CortexActorFireTaskAvailable','CortexExternalTakeover','FIREWEAPON'):
            self.assertIn(guard,available)
if __name__=='__main__': unittest.main()
