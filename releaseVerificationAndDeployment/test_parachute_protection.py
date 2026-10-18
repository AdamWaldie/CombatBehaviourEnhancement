"""Exact protection receipt contracts; physical exit/migration is not simulated here."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class ParachuteProtectionTests(unittest.TestCase):
    def test_receipt_precedes_mutation_and_refuses_overlapping_exit(self):
        jump=source('cortexParachuteJump')
        self.assertIn('getVariable ["CBE_ParachuteProtection",[]]) isEqualTo []',jump)
        self.assertLess(jump.index('setVariable ["CBE_ParachuteProtection",+_receipt,true]'),jump.index('_unit allowDamage false'))
        self.assertIn('serverTime+3.8',jump)
        self.assertNotIn('remoteExecCall ["allowDamage"',jump)
        self.assertLess(jump.index('[_unit,_receipt] call CBE_fnc_CortexParachuteProtectionRelease'),jump.index('params ["_unit", "_chuteClass"'))
        callback=jump.split('params ["_unit", "_chuteClass"',1)[1]
        self.assertLess(callback.index('isNotEqualTo (_receipt select 3)'),callback.index('createVehicle'))
        self.assertIn('CBE_ParachuteExitToken',callback)
        self.assertNotIn('serverTime >= (_receipt select 5)',callback)
    def test_release_authenticates_exact_receipt_and_actual_locality(self):
        release=source('cortexParachuteProtectionRelease')
        for guard in ('count _receipt != 6','_originalActor isNotEqualTo _actor',
                      'remoteExecutedOwner > 0',
                      'isNotEqualTo _receipt','serverTime < _until','local _actor'):
            self.assertIn(guard,release)
        self.assertNotRegex(release,r'\bremoteExec(?:Call)?\s*\[')
        mutation=release.split('private _restored=false;',1)[1]
        self.assertIn('isNil {',mutation)
        self.assertLess(mutation.index('isEqualTo _receipt'),mutation.index('allowDamage _baseline'))
        self.assertIn('if (!_changed)',mutation)
        self.assertIn('"SUPERSEDED"',mutation)
        for forbidden in ('setPos','moveIn','setVelocity','allUnits','serverTime+'):
            self.assertNotIn(forbidden,release)
    def test_locality_adoption_reuses_handler_and_does_not_replay_exit(self):
        post=(ROOT/'addons/main/XEH_postInit.sqf').read_text()
        self.assertIn('[_this select 0] call CBE_fnc_CortexParachuteProtectionRelease',post)
        self.assertIn('[_actor] call CBE_fnc_CortexParachuteProtectionRelease',post)
        self.assertEqual(post.count('addEventHandler ["Local"'),1)
        release=source('cortexParachuteProtectionRelease')
        self.assertIn('getVariable ["CBE_ParachuteProtectionQueued",[]]) isNotEqualTo _receipt',release)
        self.assertIn('_until-serverTime',release)
        self.assertIn('setVariable ["CBE_ParachuteProtectionQueued",nil]',release)
        # Exact identity preserves replacement protection and preexisting invulnerability.
        def restore(current,expected,baseline,allowed):
            return allowed if current!=expected or allowed else baseline
        self.assertFalse(restore('new','old',True,False))
        self.assertFalse(restore('old','old',False,False))
        self.assertTrue(restore('old','old',True,False))
        self.assertTrue(restore('old','old',False,True))
