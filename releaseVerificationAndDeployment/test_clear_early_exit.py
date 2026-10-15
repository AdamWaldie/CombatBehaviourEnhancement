"""Early exits share one movement owner and retain finite physical evidence across phases."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class ClearEarlyExitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.step = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        cls.start = (ROOT / 'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')

    def test_early_dispatch_preserves_geometry_reservations_and_deadline(self):
        s = self.step
        block = s.split('// One exterior selection per completed worker per episode.',1)[1].split('continue;',1)[0]
        for required in ['call _reserveReady', 'call _chooseExteriorExit', '_yielded pushBackUnique _blockerKey',
                         '_earlyExits set [_blockerKey,[_blocker,+_exitTarget,serverTime+45,"MOVING"]]',
                         'call _actorAvailable', 'call _actorTaskFree', 'call _mayIssueMovement',
                         '_follow deleteAt _blockerKey', 'call _rememberMove', 'call _publishEarlyExits']:
            self.assertIn(required,block)
        planner = s.split('private _chooseExteriorExit={',1)[1].split('// Shared room coverage',1)[0]
        self.assertIn('from 0 to 2',planner)
        self.assertIn('_entries select [0,4]',planner)
        self.assertIn('call WAIT_fnc_BuildingExteriorCandidate',planner)
        self.assertNotIn('doMove',planner)

    def test_phase_writers_do_not_restart_early_leg(self):
        s = self.step
        self.assertIn('!(netId _x in _earlyExits)',s)
        self.assertIn('if (_key in _earlyExits) then {continue}',s)
        final = s.split('private _egressAssignments=_active apply',1)[1]
        self.assertIn('if (_early isNotEqualTo []) exitWith',final)
        self.assertIn('if (!(netId _unit in _earlyExits)',final)
        service = s.split('private _earlyExits=',1)[1].split('if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS")',1)[0]
        self.assertIn('serverTime >= _deadline',service)
        self.assertIn('_record set [3,"FAILED"]',service)
        self.assertIn('_record set [3,"DIVERTED"]',service)
        self.assertIn('vectorDistance (AGLToASL _target) <= 1',service)
        self.assertNotIn('doMove',service)
        self.assertNotIn('serverTime+45',service)

    def test_owner_adoption_retains_context_deadline_and_actual_authority(self):
        block = self.start.split('private _earlyReceipt=',1)[1].split('// Adopt a transform/episode-bound exit journal',1)[0]
        for required in ['isEqualTo _visitContext', 'count (_earlyReceipt select 1) <= 8',
                         '_live vectorDistance _target <= 0.25', 'vectorDistance (AGLToASL _target) <= 1',
                         '_state="DIVERTED"', '[_actor,+_target,_until,_state]',
                         '_state == "ARRIVED" && {!_held}']:
            self.assertIn(required,block)
        self.assertNotIn('doMove',block)
        self.assertNotIn('serverTime+',block)

if __name__ == '__main__':
    unittest.main()
