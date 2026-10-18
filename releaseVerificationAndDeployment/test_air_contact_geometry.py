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

    def test_combined_air_retirement_carries_original_snapshot_after_cleanup(self):
        local=(ROOT/'addons/infantry/functions/cortexCombinedArmsLocal.sqf').read_text()
        start=(ROOT/'addons/aircraft/functions/airAttackOperationStart.sqf').read_text()
        attack=(ROOT/'addons/aircraft/functions/cortexAirAttack.sqf').read_text()
        server=(ROOT/'addons/infantry/functions/cortexCombinedAirFallbackServer.sqf').read_text()
        self.assertIn('["combinedOpportunity",+_opportunity]',local)
        self.assertEqual(local.count('[_requester,_group,_token,+_opportunity] remoteExecCall'),3)
        self.assertIn('_requestedOpportunity isEqualTo _currentOpportunity',start)
        finish=attack.split('private _finish={',1)[1].split('private _pilot=driver _aircraft;',1)[0]
        self.assertLess(finish.index('call CBE_fnc_OperationCancel'),finish.index('private _supportSnapshot='))
        self.assertIn('isEqualTo _supportSnapshot',finish)
        self.assertIn('_reason == "TARGET_IGNORED"',finish)
        self.assertIn('_rejectedRole isNotEqualTo _snapshot',server)
        self.assertLess(server.index('_rejectedRole isNotEqualTo _snapshot'),server.index('_rejected setVariable ["CBE_Cortex_CombinedRole",nil,true]'))

    def test_combined_expiry_preserves_edited_roles_and_fallback_contact(self):
        fallback=(ROOT/'addons/infantry/functions/cortexCombinedAirFallbackServer.sqf').read_text()
        server=(ROOT/'addons/infantry/functions/cortexCombinedArmsServer.sqf').read_text()
        for guard in ('(_rejectedRole select 2) != _target','(_rejectedRole select 3) isNotEqualTo _position','(_rejectedRole select 5) != _expiry'):
            self.assertLess(fallback.index(guard),fallback.index('_rejected setVariable ["CBE_Cortex_CombinedRole",nil,true]'))
        self.assertIn('isEqualTo _originalRole',fallback)
        self.assertIn('[_replacement,_token,_target,+_opportunity]',fallback)
        self.assertIn('_roleGroups pushBack [_candidate,+_opportunity]',server)
        expiry=server.split('params ["_requester","_token","_roleGroups",',1)[1]
        self.assertIn('_x params ["_roleGroup","_originalRole"]',expiry)
        self.assertIn('isEqualTo _originalRole',expiry)
        self.assertNotIn('_x setVariable',expiry)

    def test_requester_and_ground_fallback_expiry_keep_changed_work(self):
        server=(ROOT/'addons/infantry/functions/cortexCombinedArmsServer.sqf').read_text()
        ground=(ROOT/'addons/infantry/functions/cortexCombinedGroundFallbackServer.sqf').read_text()
        self.assertIn('isEqualTo _requesterSnapshot',server)
        self.assertIn('(_liveFallback select [0,5]) isEqualTo (_originalFallback select [0,5])',server)
        self.assertIn('(_liveFallback select 6) isEqualTo (_originalFallback select 6)',server)
        self.assertIn('count _originalFallback == 7',server)
        self.assertIn('isEqualTo _originalRole',ground)
        self.assertIn('[_replacement,_token,_role,_target,+_opportunity]',ground)

if __name__=='__main__': unittest.main()
