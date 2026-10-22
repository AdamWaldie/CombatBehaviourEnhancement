"""Native shot request idempotence contracts; no physical firing acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ArtilleryShotSerial(unittest.TestCase):
    def test_server_assigns_request_serial_only_at_native_dispatch(self):
        fire=(ROOT/'addons/support/functions/cortexArtilleryFire.sqf').read_text(encoding='utf-8')
        step=(ROOT/'addons/support/functions/cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('["shotSerial",0]',fire)
        self.assertEqual(step.count('_mission set ["shotSerial",'),1)
        self.assertIn('(_mission getOrDefault ["shotSerial",0])+1',step)
        self.assertIn('_mission get "shotSerial",_mission getOrDefault ["fireGeneration",-1],_mission getOrDefault ["smokeGeneration",-1],_mission getOrDefault ["dangerUntil",-1]] remoteExecCall ["CBE_fnc_CortexArtilleryShot"',step)
        self.assertLess(step.index('_mission set ["shotSerial",'),step.index('_mission set ["phase", "PENDING"]'))
    def test_duplicate_conflict_and_old_requests_do_not_reject_or_fire_again(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        state=s.split('private _requestState={',1)[1].split('private _reject =',1)[0]
        for marker in ('_shotSerial < (_receipt select 1)','_shotSerial == (_receipt select 1)',
                       '["CONFLICT","DUPLICATE"]','["DUPLICATE","STALE"]'):
            self.assertIn(marker,state)
        self.assertNotIn('remoteExecCall',state)
        commit=s.split('private _issued=false;',1)[1]
        self.assertLess(commit.index('call _requestState'),commit.index('call _fireSessionCurrent'))
        self.assertLess(commit.index('CBE_AIPass_ShotReceipt",[_token,_shotSerial,_signature,serverTime],true'),commit.index('doArtilleryFire'))
        self.assertEqual(s.count('_battery doArtilleryFire'),1)
        self.assertNotIn('CBE_AIPass_ShotReceipt",nil',s)
if __name__=='__main__': unittest.main()
