"""Bound the native rear destination; a U-turn must never masquerade as reversing."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class RearMotionTests(unittest.TestCase):
    def test_rear_pose_is_captured_only_with_issued_recovery_journal(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        record=text.split('private _recordRecovery={',1)[1].split('private _reverseIssued=',1)[0]
        self.assertIn('if (_kind == "REVERSE") then',record)
        self.assertIn('"rearOriginASL",getPosASL _vehicle',record)
        self.assertIn('"rearDirection",vectorDir _vehicle',record)
        self.assertIn('"rearDamage",damage _vehicle',record)
        self.assertNotIn('serverTime+96',record.split('if (_kind == "REVERSE") then',1)[1])
    def test_divergence_expires_owned_leg_without_new_reverse_command(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        block=text.split('private _rearPathRejected=false;',1)[1].split('private _retryAllowed=',1)[0]
        for proof in ('finite _rearDamage','_rearDamage >= 0','damage _vehicle > _rearDamage+0.01','cos 20','_along > 1','_along < -10','_lateral > 2.5',
                      '_rearPathRejected=true','_state set [7,time]','"REAR_PATH_DIVERGED"'):
            self.assertIn(proof,block)
        self.assertNotIn('doMove',block)
        self.assertNotIn('setPos',block)
        self.assertIn('if (_rearPathRejected) then {_traffic=[0,_vehicle,-1,time,0]}',text)
        self.assertIn('private _reverseHandback=_reverseComplete && {_reverseIssued}',text)
if __name__=='__main__': unittest.main()
