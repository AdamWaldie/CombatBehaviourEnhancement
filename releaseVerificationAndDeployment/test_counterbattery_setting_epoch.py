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
        self.assertIn('[_vehicle, _side, +_position, _counterGeneration, _observedAt], _delay]',s)
        self.assertIn('[_vehicle,_counterGeneration],',s)
        self.assertEqual(s.count('_generation != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration"'),2)
        self.assertNotIn('setVariable ["CBE_AIPass_CounterGeneration"',s)
        self.assertIn('[_vehicle,_generation,serverTime+15] remoteExecCall',s)
        observe=(ROOT/"addons/infantry/functions/cortexCounterObserve.sqf").read_text(encoding="utf-8")
        self.assertIn('["deadline", _deadline], ["generation", _generation]',observe)
        self.assertIn('(_job get "generation") != (missionNamespace getVariable',observe)
        self.assertIn('serverTime >= (_job get "deadline")',observe)
        self.assertNotIn('["deadline", serverTime + 15]',observe)
        self.assertIn('_observedAt, _job get "generation"] call CBE_fnc_CortexArtilleryFire',observe)
    def test_accepted_counter_missions_and_owner_requests_keep_original_generation(self):
        fire=(ROOT/'addons/support/functions/cortexArtilleryFire.sqf').read_text(encoding='utf-8')
        step=(ROOT/'addons/support/functions/cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('["counterGeneration",_fireEpochs select 3]',fire)
        self.assertIn('_counterObservationGeneration == -1 && {!isRemoteExecuted}',fire)
        refusal=fire.index('_counterObservationGeneration != (_fireEpochs select 3)')
        self.assertLess(refusal,fire.index('private _missions ='))
        self.assertIn('!finite _counterObservationGeneration',fire)
        self.assertIn('_mission getOrDefault ["counterGeneration",-1]',step)
        self.assertIn('private _blocked = _counterExpired',step)
        self.assertIn('_mission get "token",_mission getOrDefault ["counterGeneration",-1],_mission get "shotSerial",_mission getOrDefault ["fireGeneration",-1],_mission getOrDefault ["smokeGeneration",-1],_mission getOrDefault ["dangerUntil",-1]] remoteExecCall',step)
        self.assertIn('if (alive _battery && {(_mission get "phase") in ["PENDING", "UNCERTAIN"]})',step)
        self.assertIn('_mission set ["phase", "UNCERTAIN"]',step)
    def test_owner_shot_rechecks_generation_and_live_gates_at_atomic_native_issue(self):
        shot=(ROOT/'addons/support/functions/cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        self.assertIn('["_counterGeneration",-1,[0]]',shot)
        self.assertIn('_counterGeneration == (missionNamespace getVariable',shot)
        commit=shot.split('private _issued=false;',1)[1]
        self.assertLess(commit.index('isNil {'),commit.index('doArtilleryFire'))
        for guard in ('call _fireSessionCurrent','CBE_AIPass_Active','CortexIsPaused',
                      'CortexFeatureEnabled','CBE_AIPass_FireToken','unitCombatMode _operator == "BLUE"'):
            self.assertIn(guard,commit.split('_battery doArtilleryFire',1)[0])
        self.assertTrue(shot.rstrip().endswith('_issued'))
if __name__=='__main__': unittest.main()
