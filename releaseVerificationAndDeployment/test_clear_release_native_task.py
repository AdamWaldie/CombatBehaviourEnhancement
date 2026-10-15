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
