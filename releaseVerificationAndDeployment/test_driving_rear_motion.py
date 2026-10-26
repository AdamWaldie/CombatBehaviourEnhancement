"""Bound the native rear destination; a U-turn must never masquerade as reversing."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class RearMotionTests(unittest.TestCase):
    def test_rear_pose_is_captured_only_with_issued_recovery_journal(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        record=text.split('private _recordRecovery={',1)[1].split('private _reverseIssued=',1)[0]
        self.assertIn('if (_kind == "REVERSE") then',record)
        self.assertIn('"rearEnvelope",+_rearEnvelope',record)
        self.assertIn('"rearOriginASL",getPosASL _vehicle',record)
        self.assertIn('"rearDirection",vectorDir _vehicle',record)
        self.assertIn('"rearDamage",damage _vehicle',record)
        self.assertNotIn('serverTime+96',record.split('if (_kind == "REVERSE") then',1)[1])
    def test_divergence_expires_owned_leg_without_new_reverse_command(self):
        text=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        block=text.split('private _rearPathRejected=false;',1)[1].split('private _retryAllowed=',1)[0]
        for proof in ('finite _rearDamage','_rearDamage >= 0','_liveDamage > _minimumDamage+0.01','cos 20','_along > 1','_along < -((_rearEnvelope select 0)+2)','_lateral > 2.5',
                      '_rearPathRejected=true','_state set [7,time]','"REAR_PATH_DIVERGED"'):
            self.assertIn(proof,block)
        self.assertNotIn('doMove',block)
        self.assertNotIn('setPos',block)
        self.assertIn('if (_rearPathRejected) then {_traffic=[0,_vehicle,-1,time,0]}',text)
        self.assertIn('private _reverseHandback=_reverseComplete && {_reverseIssued}',text)
        self.assertIn('_along <= -(_rearEnvelope select 1)',block)
        self.assertIn('"REAR_ROOM_OBSERVED"',block)
        self.assertIn('_rearEnvelope in [[8,6],[3.5,2]] || {_extendedEnvelope}',block)
        for guard in ('count _rearEnvelope == 2','(_rearEnvelope select 1) <= 24',
                      '(_rearEnvelope select 0) == (_rearEnvelope select 1)+2','!("queueBinding" in _rearWork)'):
            self.assertIn(guard,block)
        self.assertIn('getOrDefault ["rearEnvelope",[8,6]]',block)
        # During the intended BACK travel, remaining observation plus actual
        # travel must retain the original far boundary and positive end buffer.
        for distance,stop in ((8,6),(3.5,2),(14,12),(26,24)):
            for step in range(21):
                travelled=stop*step/20
                remaining=min(distance,max(distance-travelled,distance-stop))
                self.assertAlmostEqual(travelled+remaining,distance)
                self.assertGreaterEqual(remaining,distance-stop)
                self.assertGreater(remaining,0)
        ending=text.split('if (_reverseExpired && {!("queueBinding" in',1)[1].split('private _retryAllowed=',1)[0]
        self.assertIn('sendSimpleCommand "STOP"',ending)
        # Ordinary expiry and cleanup share one STOP request. Waiting for the
        # native reply must not reissue it on every controller observation.
        stop_issue=ending.split('_vehicle sendSimpleCommand "STOP"',1)[0]
        self.assertIn('&& {!(_endingRear getOrDefault ["simpleStopIssued",false])}',stop_issue)
        self.assertIn('_stoppedRear set ["simpleStopIssued",true]',ending)
        self.assertIn('"kind","REAR_STOP_ACKNOWLEDGED"',ending)
        self.assertIn('"commandMode","DESTINATION"',ending)
        self.assertNotIn('doMove',ending)
        self.assertNotIn('serverTime+',ending)

if __name__=='__main__': unittest.main()
