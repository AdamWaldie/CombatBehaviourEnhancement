"""Mission skill ownership source contracts; runtime values/migration still need engine evidence."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(path):return (ROOT/path).read_text(encoding="utf-8")
class SkillAuthorityTests(unittest.TestCase):
    def test_default_is_opt_in_and_behaviour_start_remains_independent(self):
        spec=src('addons/core/functions/cortexTuningSpec.sqf')
        row=next(line for line in spec.splitlines() if '["CBE_AIRebalance_Enable",' in line)
        self.assertIn('[], false, "SKILLS", "LIVE"',row)
        config=src('addons/main/settings/aiConfig.sqf')
        self.assertIn('["CBE_AIRebalance_Enable", false]',config)
        post=src('addons/main/XEH_postInit.sqf')
        self.assertIn('getVariable ["CBE_AIRebalance_Enable", false]',post)
        self.assertIn('getVariable ["CBE_AIPass_Enable", true]',post)
        self.assertIn('ace_headless_groupTransferPost',src('addons/core/functions/cortexInit.sqf'))
    def test_yield_is_actual_owner_bounded_and_validated_before_restore(self):
        text=src('addons/core/functions/aiProfileYield.sqf')
        for proof in ('!local _unit','isNil {','count _receipt in [0,9]','finite (_receipt get _x)',
                      'keys _applied findIf','finite _originalAim','finite _appliedAim'):
            self.assertLess(text.index(proof),text.index('call CBE_fnc_AIRestoreProfile'))
        for forbidden in ('allUnits','spawn {','waitUntil','addPerFrameHandler','doMove','setSkill'):
            self.assertNotIn(forbidden,text)
    def test_later_skill_or_aim_changes_yield_without_provider_detection(self):
        text=src('addons/core/functions/aiProfileYield.sqf')
        self.assertIn('(_unit skill _x)-(_expected get _x)',text)
        self.assertIn('getCustomAimCoef _unit-_expectedAim',text)
        self.assertIn('"CBE_AI_SkillOwner","OBSERVED_EXTERNAL_CHANGE",true',text)
        self.assertIn('if (count _applied > 0) then {_applied} else {_original}',text)
        self.assertNotIn('Waldo_AI_RebalanceActive',text)
        restore=src('addons/core/functions/aiRestoreProfile.sqf')
        self.assertIn('(_unit skill _x)-(_applied get _x)',restore)
        self.assertNotIn('CBE_AI_SkillOwner',restore)
        self.assertNotIn('CBE_AI_SkillOwner',src('addons/core/functions/aiRebalanceStop.sqf'))
    def test_partial_profile_refresh_plans_from_original_not_native_previous_result(self):
        text=src('addons/core/functions/aiApplyProfile.sqf')
        plan,commit=text.split('private _profileCommitted=false;',1)
        self.assertIn('createHashMapFromArray (_skillNames apply {[_x,_originalSkills get _x]})',plan)
        self.assertIn('(_profileSkills get _x) * _factor',plan)
        self.assertIn('private _current = _profileSkills get _x',plan)
        self.assertIn('(_profileSkills get _x) * _crewMultiplier',plan)
        self.assertNotIn('setSkill',plan)
        self.assertNotIn('setCustomAimCoef',plan)
        for proof in ('isNil {','!local _unit','CBE_AI_RebalanceActive','_profileGeneration !=',
                      '_profileKey !=','_mode !=','CBE_fnc_CortexExternalOwner','CBE_fnc_AIProfileYield'):
            self.assertLess(commit.index(proof),commit.index('_unit setSkill'))
        self.assertEqual(text.count('_unit setSkill'),1)
        self.assertEqual(text.count('_unit setCustomAimCoef'),1)
    def test_yield_does_not_disable_tactics_or_own_a_whole_group(self):
        text=src('addons/core/functions/aiProfileYield.sqf')
        for forbidden in ('CBE_AI_Exclude','Waldo_AI_ExternalControl','CBE_AIPass_Enable','CBE_Operation'):
            self.assertNotIn(forbidden,text)
        self.assertIn('class AIProfileYield',src('addons/main/CfgFunctions.hpp'))
if __name__=='__main__':unittest.main()
