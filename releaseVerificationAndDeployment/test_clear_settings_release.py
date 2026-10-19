"""Clear settings ownership contracts; no physical cleanup acceptance."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT/path).read_text(encoding="utf-8")

class ClearSettingsRelease(unittest.TestCase):
    def test_restore_has_no_movement_or_native_task_cancellation(self):
        s=read("addons/infantry/functions/cortexClearSettingsRelease.sqf")
        body=s.split('params [[',1)[1]
        for command in ('doMove','doFollow','doStop','doWatch','doTarget','currentCommand'):
            self.assertNotIn(command,body)
        self.assertIn('abs ((getForcedSpeed _actor)-_applied) <= 0.1',body)
        self.assertIn('unitPos _actor == "UP"',body)
        self.assertLess(body.index('if (!_safe || {!_typed}) exitWith'),body.index('_actor forceSpeed'))
        self.assertLess(body.index('_actor forceSpeed'),body.index('ClearForcedSpeed",nil'))
        for guard in ('local _actor','CortexActorMoveReserved','CortexExternalTakeover',
                      'CBE_AIPass_ClearGeneration','CBE_AIPass_Epoch','finite _applied'):
            self.assertIn(guard,body)

    def test_finish_and_explicit_release_share_settings_retirement(self):
        for file in ('buildingOperationStep','cortexClearRelease'):
            s=read('addons/infantry/functions/'+file+'.sqf')
            self.assertIn('call CBE_fnc_CortexClearSettingsRelease',s)
            self.assertNotIn('setVariable ["CBE_Cortex_ClearForcedSpeed",nil',s)
            self.assertNotIn('setVariable ["CBE_Cortex_ClearStance",nil',s)
        step=read('addons/infantry/functions/buildingOperationStep.sqf')
        self.assertLess(step.index('call CBE_fnc_CortexClearSettingsRelease'),step.index('// Native tasks keep movement ownership'))

    def test_pending_window_has_one_actor_per_existing_callback_without_renewal(self):
        s=read('addons/infantry/functions/groupBrainStep.sqf')
        block=s.split('// Finite post-clear settings retirement',1)[1].split('// A native STOP survives',1)[0]
        self.assertEqual(block.count('call CBE_fnc_CortexClearSettingsRelease'),1)
        self.assertIn('count _settingsMembers <= 64',block)
        self.assertIn('_clearSettings select 0,_epoch,false',block)
        self.assertIn('serverTime >= (_clearSettings select 2)',block)
        self.assertNotIn('serverTime+30',block)
        helper=read('addons/infantry/functions/cortexClearSettingsRelease.sqf')
        self.assertIn('if (_pending isEqualTo [] || {_retiredEpisode}) then',helper)
        self.assertNotIn('waitAndExecute',helper.split('params [[',1)[1])

    def test_locality_adopts_original_deadline_without_commands(self):
        s=read('addons/core/functions/cortexLocality.sqf')
        block=s.split('// Adopt only the original finite settings-cleanup window',1)[1].split('// Retire inherited simple driving',1)[0]
        self.assertIn('_settingsGenerationBeforeAdopt',block)
        self.assertIn('_adoptedSettings set [0,',block)
        self.assertIn('_adoptedSettings set [1,',block)
        for forbidden in ('set [2,','serverTime+30','forceSpeed','setUnitPos','doFollow'):
            self.assertNotIn(forbidden,block)

if __name__ == '__main__':
    unittest.main()
