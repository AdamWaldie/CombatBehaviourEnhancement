"""AA route knowledge boundary; static contracts are not physical acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AirContactGeometryTests(unittest.TestCase):
    def test_aa_geometry_keeps_native_report_instead_of_live_object_pose(self):
        source=(ROOT/'addons/aircraft/functions/cortexAirAttackPlan.sqf').read_text(encoding='utf-8')
        block=source.split('private _aaPositions=[];',1)[1].split('private _airPos=',1)[0]
        self.assertIn('select [0,16]',block)
        self.assertIn('_x param [0,[],[[]]]',block)
        self.assertIn('count _reportedPosition == 3',block)
        self.assertIn('!(_x isEqualType 0) || {!(finite _x)}',block)
        self.assertIn('if (_validReport &&',block)
        self.assertIn('_aaPositions pushBack (+_reportedPosition)',block)
        self.assertNotIn('getPos',block)
        self.assertNotIn('getHideFrom',block)
        self.assertEqual(block.count('nearTargets'),1)
    def test_native_ignored_targets_refuse_planning_active_run_and_guidance(self):
        plan=(ROOT/'addons/aircraft/functions/cortexAirAttackPlan.sqf').read_text()
        attack=(ROOT/'addons/aircraft/functions/cortexAirAttack.sqf').read_text()
        local=(ROOT/'addons/infantry/functions/cortexCombinedArmsLocal.sqf').read_text()
        self.assertIn('(_pilot targetKnowledge _target) param [7,false,[true]]',plan)
        self.assertIn('!local _pilot',plan)
        self.assertLess(plan.index('targetKnowledge _target'),plan.index('private _ammoCache='))
        self.assertIn('_startFailure="TARGET_IGNORED"',attack)
        self.assertIn('["TARGET_IGNORED",true] call _finish',attack)
        self.assertLess(attack.index('["TARGET_IGNORED",true] call _finish'),attack.index('_job set ["lastTargetPositionASL",getPosASL _target]'))
        self.assertIn('!((_operator targetKnowledge _guidedTarget) param [7,false,[true]])',attack)
        refused=local.split('// Native ignoreTarget belongs to this group;',1)[1].split('// The caller',1)[0]
        self.assertIn('if (_role == "AIR_ATTACK")',refused)
        self.assertIn('CBE_fnc_CortexCombinedAirFallbackServer',refused)
        self.assertNotIn('reveal',refused.split('private _contactObserver',1)[1])

if __name__=='__main__': unittest.main()
