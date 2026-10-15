"""Clear-release authority regressions; not physical handover acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ClearReleaseNativeTaskTests(unittest.TestCase):
    def test_new_nonmovement_tasks_cannot_grant_formation_recall(self):
        def owned(command,matching_destination):
            return command in ("","STOP") or (command=="MOVE" and matching_destination)
        for command in ("FOLLOW","ATTACK","WAIT","FIRE","SUPPRESS","HIDE","EXPECT","JOIN","SCRIPTED"):
            self.assertFalse(owned(command,True),command)
        self.assertTrue(owned("MOVE",True))
        self.assertFalse(owned("MOVE",False))
        self.assertTrue(owned("STOP",False))
        self.assertTrue(owned("",False))

    def test_recall_boundary_requires_allowed_command_and_move_receipt(self):
        s=(ROOT/'addons/infantry/functions/cortexClearRelease.sqf').read_text()
        start=s.index('private _movementOwned=')
        end=s.index('if (_restore && {_taskFree} && {_movementOwned})',start)
        guard=s[start:end]
        self.assertIn('currentCommand _x in ["","STOP"]',guard)
        self.assertIn('currentCommand _x == "MOVE"',guard)
        self.assertIn('_destination vectorDistance _issued <= 0.25',guard)
        self.assertNotIn('!= "MOVE"',guard)
        self.assertLess(end,s.index('_x doFollow _leader',end))


class ClearFinishNativeTaskTests(unittest.TestCase):
    def test_egress_and_finish_share_the_native_task_guard(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        start=s.index('private _exitMovementOwned=')
        end=s.index('private _activeOwnMove=',start)
        self.assertIn('currentCommand _actor in ["","STOP"] || {[_actor] call _ownsCurrentMove}',s[start:end])
        self.assertIn('&& {[_x] call _exitMovementOwned}) then {',s)
        self.assertIn('if !([_unit] call _exitMovementOwned) then {',s)
        self.assertIn('if !([_actor] call _exitMovementOwned) then {',s)
        self.assertIn('_diverted pushBackUnique _unit;',s)
        self.assertIn('_diverted pushBackUnique _actor;',s)
        self.assertIn('_job set ["egressFailed",true]',s)
