"""Source contracts for the common operation permission write boundary, not live acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(path):return (ROOT/path).read_text(encoding="utf-8")
class OperationAttackPolicyTests(unittest.TestCase):
    def test_acquisition_has_current_authority_before_receipt_and_write(self):
        text=source("addons/core/functions/operationAttackPolicy.sqf")
        for proof in ('isNil {','_current isNotEqualTo _operation','finite _generation','finite _epoch',
                      'CBE_OperationGeneration','CBE_AIPass_Epoch','== "CANCELLED"',
                      'CBE_fnc_CortexExternalTakeover','count _members > 64','!local _anchor',
                      '!local _x','isPlayer _x','remoteControlled','bis_fnc_moduleRemoteControl_owner',
                      'CBE_fnc_CortexExternalOwner','CBE_fnc_CompatibilityExternalControl'):
            self.assertLess(text.index(proof),text.index('_restore set ["groupAttack"'))
            self.assertLess(text.index(proof),text.index('_group enableAttack'))

        confirmation='if (attackEnabled _anchor != _applied) exitWith {"REFUSED"};'
        self.assertLess(text.index('_group enableAttack _applied'),text.index(confirmation))
        self.assertLess(text.index(confirmation),text.index('_restore set ["groupAttack"'))
        self.assertLess(text.index(confirmation),text.index('"ACQUIRED"',text.index('private _baseline=')))
        self.assertIn('class OperationAttackPolicy',source('addons/main/CfgFunctions.hpp'))
        self.assertLess(text.index('count _members > 64'),text.index('call CBE_fnc_CortexExternalTakeover'))
    def test_existing_receipt_is_typed_read_only_and_does_not_reapply(self):
        text=source('addons/core/functions/operationAttackPolicy.sqf')
        existing=text.split('if (_lease isNotEqualTo []) exitWith {',1)[1].split('private _baseline=',1)[0]
        for proof in ('count _lease != 2','isEqualType true','attackEnabled _anchor != (_lease select 1)',
                      '"POLICY_CHANGED"','_applied != (_lease select 1)','"OWNED"'):
            self.assertIn(proof,existing)
        for forbidden in ('enableAttack','setVariable','_restore set'):
            self.assertNotIn(forbidden,existing)
        self.assertLess(text.index('if (_lease isNotEqualTo [])'),text.index('private _baseline='))
        self.assertIn('count _original > 1',text)
        self.assertIn('_original findIf {!(_x isEqualType true)}',text)
    def test_helper_is_setting_only_with_no_worker_or_geometry(self):
        text=source('addons/core/functions/operationAttackPolicy.sqf')
        for forbidden in ('doMove','doStop','doFollow','setCombatMode','setBehaviour','setUnitPos',
                          'forceSpeed','waitUntil','spawn {','nearestObjects','lineIntersects','addPerFrameHandler'):
            self.assertNotIn(forbidden,text)
        self.assertEqual(text.count('_group enableAttack'),1)
        self.assertIn('OperationRestore',text)
    def test_both_production_callers_use_shared_acquisition_and_refuse(self):
        flank=source('addons/infantry/functions/cortexFlankStep.sqf')
        clear=source('addons/infantry/functions/cortexClearBuilding.sqf')
        for text in (flank,clear):
            self.assertIn('call CBE_fnc_OperationAttackPolicy',text)
            self.assertNotIn('_group enableAttack false',text)
            self.assertNotIn('set ["groupAttack",',text)
            self.assertIn('ATTACK_POLICY_REFUSED',text)
        self.assertIn('ATTACK_POLICY_CHANGED',flank)
        acquisition=clear.split('private _attackPolicyReady=false;',1)[1].split('private _entries=[];',1)[0]
        self.assertIn('}] call _commitPreparation;',acquisition)
        self.assertIn('if (!_attackPolicyReady) exitWith',acquisition)
        self.assertLess(acquisition.index('CBE_fnc_OperationAttackPolicy'),acquisition.index('CBE_fnc_CortexClearRelease'))
    def test_durable_clear_baseline_follows_actual_acquisition_after_retirement(self):
        text=source('addons/infantry/functions/cortexClearBuilding.sqf')
        self.assertLess(text.index('call CBE_fnc_OperationStart'),text.index('call CBE_fnc_OperationAttackPolicy'))
        acquisition=text.split('private _attackPolicyReady=false;',1)[1].split('private _entries=[];',1)[0]
        self.assertIn('if (_resume) then {[_baseAttack]} else {[]}',acquisition)
        self.assertLess(acquisition.index('if (_attackPolicyReady)'),acquisition.index('_ownedClearOrder set [8,_baseAttack]'))
        self.assertIn('get "groupAttack") select 0',acquisition)
        self.assertIn('count _ownedClearOrder == 14',acquisition)
if __name__=='__main__':unittest.main()
