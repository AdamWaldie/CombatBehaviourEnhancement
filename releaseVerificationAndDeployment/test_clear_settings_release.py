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
        core=read("addons/core/functions/actorSettings.sqf")
        self.assertNotIn('forceSpeed',body)
        self.assertNotIn('setUnitPos',body)
        self.assertLess(body.index('CBE_AIPass_ClearGeneration'),body.index('call CBE_fnc_ActorSettings'))
        self.assertLess(body.index('CBE_AIPass_Epoch'),body.index('call CBE_fnc_ActorSettings'))
        self.assertLess(body.index('_status == "RELEASED"'),body.index('"CBE_Cortex_ClearForcedSpeed",'))
        release=core.split('if (_mode == "RELEASE") exitWith {',1)[1].split('private _operation=',1)[0]
        self.assertIn('_pair select 1',release)
        self.assertIn('_remaining set [_key,_pair]',release)
        for guard in ('local _actor','CortexActorMoveReserved','CortexExternalTakeover'):
            self.assertLess(core.index(guard),core.index('if (_mode == "RELEASE")'))

    def test_finish_and_explicit_release_share_settings_retirement(self):
        for file in ('buildingOperationStep','cortexClearRelease'):
            s=read('addons/infantry/functions/'+file+'.sqf')
            self.assertIn('call CBE_fnc_CortexClearSettingsRelease',s)
            self.assertNotIn('setVariable ["CBE_Cortex_ClearForcedSpeed",nil',s)
            self.assertNotIn('setVariable ["CBE_Cortex_ClearStance",nil',s)
        step=read('addons/infantry/functions/buildingOperationStep.sqf')
        self.assertLess(step.index('call CBE_fnc_CortexClearSettingsRelease'),step.index('// Native tasks keep movement ownership'))

    def test_pending_window_has_one_actor_per_existing_callback_without_renewal(self):
        block=read('addons/infantry/functions/cortexClearSettingsStep.sqf')
        self.assertEqual(block.count('call CBE_fnc_CortexClearSettingsRelease'),1)
        self.assertIn('count _members > 64',block)
        self.assertIn('_pending select 0,_pending select 1,false',block)
        self.assertIn('serverTime >= (_pending select 2)',block)
        self.assertNotIn('serverTime+30',block)
        self.assertNotIn('CBE_AIPass_Active',block)
        self.assertNotIn('CortexIsPaused',block)
        for command in ('doMove','doFollow','doStop','forceSpeed','setUnitPos'):
            self.assertNotIn(command,block)
        reconcile=read('addons/core/functions/schedulerReconcile.sqf')
        scheduler=read('addons/core/functions/cortexSchedulerTick.sqf')
        self.assertIn('case "SETTINGS_CLEANUP"',reconcile)
        self.assertIn('CBE_ActorSettings_SchedulerActive',scheduler)
        self.assertIn('_settingsRetired',scheduler)
        stop=read('addons/core/functions/cortexStop.sqf')
        carry=stop.split('private _clearPending=',1)[1].split('private _posturePending=',1)[0]
        self.assertIn('(_clearPending select 1) == _postureOldEpoch',carry)
        self.assertIn('_carriedClear set [1,',carry)
        self.assertNotIn('set [2,',carry)
        self.assertIn('CBE_fnc_CortexClearSettingsStep',carry)
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
