"""Source contracts for delayed emission cancellation; not live fire acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CounterBatterySettingEpoch(unittest.TestCase):
    def test_disable_advances_only_server_delayed_response_generation(self):
        s=(ROOT/'addons/core/functions/aiTweaksSettingChanged.sqf').read_text(encoding='utf-8')
        block=s.split('if (_name == "CBE_AIPass_CounterBattery_Enable"',1)[1].split('// These optional handlers',1)[0]
        self.assertIn('isServer',block)
        self.assertIn('_value isEqualTo false',block)
        self.assertIn('isNil {',block)
        self.assertIn('CBE_AIPass_CounterGeneration",0])+1',block)
        for forbidden in ('doArtilleryFire','CortexArtilleryFire','allVehicles','forEach vehicles'):
            self.assertNotIn(forbidden,block)
    def test_pending_cooldown_and_both_delayed_callbacks_bind_original_generation(self):
        s=(ROOT/'addons/support/functions/cortexCounterBattery.sqf').read_text(encoding='utf-8')
        self.assertIn('[_pendingKey,[_counterGeneration,time+_delay+1]]',s)
        self.assertIn('(_pending select 0) != _counterGeneration',s)
        self.assertIn('time >= (_pending select 1)',s)
        self.assertIn('[_vehicle, _side, +_position, _counterGeneration], _delay]',s)
        self.assertIn('[_vehicle,_counterGeneration],',s)
        self.assertEqual(s.count('_generation != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration"'),2)
        self.assertNotIn('setVariable ["CBE_AIPass_CounterGeneration"',s)
if __name__=='__main__': unittest.main()
