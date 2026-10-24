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
        self.assertIn('group driver _battery == (_movementOrder select 0)',s)
        self.assertIn('isEqualTo (_movementOrder select 1)',s)
        self.assertNotIn('private _nativeOrder=[_group] call',s)
        for marker in ('count _session != 7','serverTime < (_session select 3)',
                       '(_session select 1) == (missionNamespace getVariable [_scootGenerationName,0])',
                       '(_session select 2) == (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])'):
            self.assertIn(marker,s)
        self.assertEqual(s.count('[_battery,_token,+_session],5]'),2)
        self.assertIn('count (_session select 6) != 2',s)
        self.assertIn('(_session select 6) isEqualTo _seats',s)
        self.assertNotIn('_session set [6,',s)
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
        # Group waypoint scope must be refused before planning and rechecked at commit.
        ready=s.split('private _crewReady={',1)[1].split('private _nativeOrder=',1)[0]
        for guard in ('vehicle leader _group == _battery','count units _group <= 64',
                      '(units _group) findIf {alive _x && {vehicle _x != _battery}} < 0'):
            self.assertIn(guard,ready)
        self.assertLess(s.index('if !(call _crewReady)'),s.index('private _origin='))
        self.assertLess(commit.index('call _crewReady'),commit.index('call CBE_fnc_CortexGroupMove'))
        mission=(ROOT/'addons/support/functions/cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('[_battery,_scootToken,_scootSession] remoteExecCall',mission)
    def test_active_relocation_keeps_session_and_cancels_only_current_generation(self):
        scoot=(ROOT/'addons/support/functions/cortexArtilleryScoot.sqf').read_text(encoding='utf-8')
        self.assertIn('_operation set ["artilleryScootSession",[_battery,+_session]]',scoot)
        observe=(ROOT/'addons/support/functions/artilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('isEqualTo [_battery,_session]',observe)
        self.assertIn('RELOCATION_OBSERVER_EXPIRED',observe)
        self.assertIn('RELOCATION_ENDED',observe)
        self.assertNotIn('_activeToken == _token ||',observe)
        self.assertNotIn('remoteExecCall',observe)
        start=(ROOT/'addons/support/functions/artilleryMissionStart.sqf').read_text(encoding='utf-8')
        self.assertIn('count _registered == 0',start)
        self.assertIn('if (_relocationObserver) exitWith {false}',start)
        self.assertIn('if (!_relocationObserver) then',start)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text(encoding='utf-8')
        active=tick.split('private _scootLease=',1)[1].split('private _movementLease =',1)[0]
        for marker in ('"artilleryScootSession"','"ownerEpoch"','CBE_ArtilleryScoot_SupportGeneration',
                       'CBE_ArtilleryScoot_CounterGeneration','CBE_AIPass_CounterGeneration',
                       'CBE_fnc_CortexFeatureEnabled','SCOOT_SESSION_ENDED'):
            self.assertIn(marker,active)
        for guard in ('vehicle leader _group == _battery','count units _group <= 64',
                      '(units _group) findIf {alive _x && {vehicle _x != _battery}} < 0'):
            self.assertIn(guard,active)
        cleanup=active.split('// Cleanup can call other lifecycle helpers.',1)[1]
        for guard in ('CBE_OperationGeneration','count (_group getVariable ["CBE_Operation"',
                      'isEqualTo _scootLease','isEqualTo _scootAuthority','== _scootGeneration'):
            self.assertIn(guard,cleanup)
        self.assertNotIn('deleteWaypoint',active)
        self.assertNotIn('serverTime < (_session select 3)',active)
if __name__=='__main__': unittest.main()
