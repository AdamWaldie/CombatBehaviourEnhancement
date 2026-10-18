"""Pending relocation lifetime and successor protection; not native route acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ArtilleryScootSession(unittest.TestCase):
    def test_per_purpose_disable_invalidates_relocation_without_coupling_firing(self):
        s=(ROOT/'addons/core/functions/aiTweaksSettingChanged.sqf').read_text(encoding='utf-8')
        block=s.split('// Relocation has its own per-purpose lifetime:',1)[1].split('// These optional handlers',1)[0]
        for marker in ('isServer','_value isEqualTo false','CBE_ArtilleryScoot_SupportGeneration',
                       'CBE_ArtilleryScoot_CounterGeneration','CBE_AIPass_Artillery_ShootAndScoot',
                       'CBE_AIPass_CounterBattery_ShootAndScoot'):
            self.assertIn(marker,block)
        self.assertNotIn('CBE_AIPass_CounterGeneration',block)
        self.assertNotIn('CortexStop',block)
    def test_pending_session_carries_original_expiry_and_generation_through_retries(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryScoot.sqf').read_text(encoding='utf-8')
        for marker in ('count _session != 5','serverTime < (_session select 3)',
                       '(_session select 1) == (missionNamespace getVariable [_scootGenerationName,0])',
                       '(_session select 2) == (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])'):
            self.assertIn(marker,s)
        self.assertEqual(s.count('[_battery,_token,+_session],5]'),2)
        self.assertNotIn('_session set [3,',s)
        self.assertLess(s.index('if !(call _sessionCurrent)'),s.index('if (_busy) exitWith'))
    def test_cleanup_and_post_geometry_move_admission_preserve_current_session(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryScoot.sqf').read_text(encoding='utf-8')
        clear=s.split('private _clear = {',1)[1].split('private _purpose=',1)[0]
        self.assertLess(clear.index('isEqualTo _session'),clear.index('ArtilleryScootToken",nil'))
        commit=s.split('private _started=false;',1)[1]
        self.assertLess(commit.index('isNil {'),commit.index('call _sessionCurrent'))
        self.assertLess(commit.index('call _sessionCurrent'),commit.index('call CBE_fnc_CortexOwnershipLease'))
        self.assertLess(commit.index('call _sessionCurrent'),commit.index('call CBE_fnc_CortexGroupMove'))
        self.assertTrue(s.rstrip().endswith('_started'))
        mission=(ROOT/'addons/support/functions/cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('[_battery,_scootToken,_scootSession] remoteExecCall',mission)
if __name__=='__main__': unittest.main()
