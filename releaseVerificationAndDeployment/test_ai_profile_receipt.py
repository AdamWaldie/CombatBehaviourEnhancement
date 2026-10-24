"""Ownership contracts for typed, partial skill/aim receipts; not engine/migration acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name):return (ROOT/'addons/core/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class ProfileReceiptTests(unittest.TestCase):
    def test_reader_is_detached_bounded_and_read_only(self):
        text=src('aiProfileReceipt')
        for required in ('count _receipt in [0,9]','_x in _names','finite (_receipt get _x)',
                         '(_receipt get _x) < 0','(_receipt get _x) > 1',
                         '_value == -1 || {_value >= 0}',
                         'createHashMapFromArray (keys _original apply','createHashMapFromArray (keys _applied apply'):
            self.assertIn(required,text)
        for forbidden in ('setVariable','setSkill','setCustomAimCoef','allUnits','spawn {','waitUntil'):
            self.assertNotIn(forbidden,text)
    def test_pairs_are_ready_independently_and_missing_original_blocks_application(self):
        text=src('aiProfileReceipt')
        self.assertIn('count _original == 9 && {count _applied == 9}',text)
        self.assertIn('_originalAim >= 0 && {_appliedAim >= 0}',text)
        self.assertIn('count _applied > 0 && {count _original == 0}',text)
        self.assertIn('_appliedAim >= 0 && {_originalAim < 0}',text)
        self.assertIn('"skillsPending",!_skillsReady',text)
        self.assertIn('"aimPending",!_aimReady',text)
    def test_direct_restore_validates_at_same_owner_boundary_and_retires_only_complete_pairs(self):
        text=src('aiRestoreProfile')
        for proof in ('isNil {','!local _unit','call CBE_fnc_AIProfileReceipt','getOrDefault ["valid",false]'):
            self.assertLess(text.index(proof),text.index('_unit setSkill'))
            self.assertLess(text.index(proof),text.index('_unit setCustomAimCoef'))
        skills=text.split('if (_receipt get "skillsReady") then {',1)[1].split('private _originalAim=',1)[0]
        self.assertIn('(_unit skill _x)-(_applied get _x)',skills)
        self.assertIn('["CBE_AI_OriginalSkills",nil,true]',skills)
        self.assertIn('["CBE_AI_AppliedSkills",nil,true]',skills)
        aim=text.split('if (_receipt get "aimReady") then {',1)[1].split('if (_retired)',1)[0]
        self.assertIn('getCustomAimCoef _unit-_appliedAim',aim)
        self.assertIn('["CBE_AI_OriginalAimCoef",nil,true]',aim)
        self.assertIn('["CBE_AI_AppliedAimCoef",nil,true]',aim)
        cleanup=text.split('if (_retired) then {',1)[1]
        self.assertLess(cleanup.index('"skillsPending"'),cleanup.index('CBE_AI_SkillVarianceOffsets'))
        self.assertLess(cleanup.index('"aimPending"'),cleanup.index('CBE_AI_SkillVarianceOffsets'))
        self.assertIn('if (_observedExternal) then {',text)
        self.assertNotIn('["CBE_AI_SkillOwner",nil',text)
    def test_application_and_cleanup_use_same_reader_and_exclusion_observes_native_restore(self):
        self.assertIn('call CBE_fnc_AIProfileReceipt',src('aiProfileYield'))
        self.assertIn('call CBE_fnc_AIProfileReceipt',src('aiRestoreProfile'))
        text=src('aiApplyProfile')
        self.assertIn('if (!_precisionExcluded && {isNil {_unit getVariable "CBE_AI_OriginalAimCoef"}})',text)
        final=text.split('private _profileCommitted=false;',1)[1]
        self.assertLess(final.index('abs (_appliedAim-_originalAim) < 0.00001'),final.index('["CBE_AI_OriginalAimCoef",nil,true]'))
        self.assertIn('_entryAppliedAim >= 0',final)
        self.assertIn('class AIProfileReceipt',(ROOT/'addons/main/CfgFunctions.hpp').read_text())
if __name__=='__main__':unittest.main()
