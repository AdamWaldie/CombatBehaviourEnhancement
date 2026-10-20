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
        self.assertLess(jump.index('[_unit,_receipt] call CBE_fnc_CortexParachuteProtectionRelease'),jump.index('[_unit] call CBE_fnc_CortexParachuteDeploy'))
        self.assertIn('CBE_ParachuteExitToken',source('cortexParachuteDeploy'))
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
        actor_init=post.split('["CAManBase","init",',1)[1].split('call CBA_fnc_addClassEventHandler;',1)[0]
        self.assertEqual(actor_init.count('addEventHandler ["Local"'),1)
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

    def test_failed_dismount_never_repositions_boarded_actor(self):
        jump=source('cortexParachuteJump')
        exit_leg=jump.split('moveOut _unit;',1)[1].split('// Even a failed dismount',1)[0]
        self.assertLess(exit_leg.index('vehicle _unit == _unit'),exit_leg.index('_unit setPosATL'))
        self.assertLess(exit_leg.index('local _unit'),exit_leg.index('_unit setVelocity'))
        self.assertLess(jump.index('call CBE_fnc_CortexParachuteProtectionRelease;'),jump.index('if (!_exited) exitWith'))

    def test_boarding_rechecks_takeover_at_unscheduled_mutation(self):
        callback=source('cortexParachuteDeploy').split('private _boarded=false;',1)[1]
        self.assertLess(callback.index('isNil {'),callback.index('createVehicle'))
        for guard in ('local _unit','vehicle _unit == _unit','simulationEnabled _unit',
                      'isObjectHidden _unit','isPlayer _unit','CortexCombatEffective',
                      'CortexActorMoveReserved','remoteControlled _unit',
                      'bis_fnc_moduleRemoteControl_owner','CortexExternalOwner',
                      'CompatibilityExternalControl','CBE_ParachuteExitToken',
                      'group _unit == _group','isTouchingGround _unit','serverTime < _until'):
            self.assertLess(callback.index(guard),callback.index('createVehicle'))

    def test_deployment_is_durable_exact_and_never_replays_exit(self):
        deploy=source('cortexParachuteDeploy')
        jump=source('cortexParachuteJump')
        post=(ROOT/'addons/main/XEH_postInit.sqf').read_text()
        self.assertIn('[_this select 0] call CBE_fnc_CortexParachuteDeploy',post)
        self.assertIn('[_actor] call CBE_fnc_CortexParachuteDeploy',post)
        actor_init=post.split('["CAManBase","init",',1)[1].split('call CBA_fnc_addClassEventHandler;',1)[0]
        self.assertEqual(actor_init.count('addEventHandler ["Local"'),1)
        for forbidden in ('moveOut','setPosATL','_unit setVelocity','remoteExecCall','allUnits'):
            self.assertNotIn(forbidden,deploy)
        self.assertLess(jump.index('setVariable ["CBE_ParachuteDeploy",['),jump.index('_exited=true'))
        self.assertIn('serverTime+0.8,_receipt select 5',jump)
        mutation=deploy.split('private _boarded=false;',1)[1]
        self.assertLess(mutation.index('isNotEqualTo _receipt'),mutation.index('setVariable ["CBE_ParachuteDeploy",nil,true]'))
        self.assertLess(mutation.index('setVariable ["CBE_ParachuteDeploy",nil,true]'),mutation.index('createVehicle'))
        self.assertIn('_due-serverTime',deploy)
        self.assertNotIn('serverTime+',deploy)
        # Selection model: receipt consumption prevents duplicate callbacks; late/landed
        # or replacement receipts never acquire the deployment phase.
        def consume(live,expected,local,now,due,deadline,landed):
            if not local or live!=expected or now<due:return live,False
            return None,now<deadline and not landed
        self.assertEqual(consume('new','old',True,1,0.8,3.8,False),('new',False))
        self.assertEqual(consume('old','old',False,1,0.8,3.8,False),('old',False))
        live,board=consume('old','old',True,1,0.8,3.8,False)
        self.assertTrue(board)
        self.assertEqual(consume(live,'old',True,1,0.8,3.8,False),(None,False))
        self.assertEqual(consume('old','old',True,4,0.8,3.8,False),(None,False))
        self.assertEqual(consume('old','old',True,1,0.8,3.8,True),(None,False))

    def test_malformed_public_receipts_refuse_before_array_parsing(self):
        observe=source('cortexParachuteObserve')
        jump=source('cortexParachuteJump')
        self.assertIn('call CBA_fnc_globalEvent',jump)
        self.assertIn('CBE_fnc_CortexParachuteObserve',(ROOT/'addons/main/XEH_preInit.sqf').read_text())
        self.assertIn('_stopAt=_until+1',observe)
        self.assertIn('_until > serverTime+4',observe)
        self.assertIn('0.1] call CBA_fnc_waitAndExecute',observe)
        self.assertIn('CBE_ParachuteObservationSerial',observe)
        self.assertIn('isNotEqualTo _queueToken',observe)
        callback=observe.split('params ["_actor","_proposal","_stopAt","_queueToken"];',1)[1]
        self.assertLess(callback.index('!local _actor'),callback.index('call CBE_fnc_CortexParachuteDeploy'))
        self.assertLess(callback.index('isEqualTo _deploy'),callback.index('call CBE_fnc_CortexParachuteDeploy'))
        for forbidden in ('allUnits','moveOut','setPosATL','allowDamage','createVehicle'):
            self.assertNotIn(forbidden,observe)
        # An old callback cannot consume a new queue after loss/gain on the same episode.
        old=('exit',1); new=('exit',2)
        self.assertNotEqual(old,new)
        def observation(local,now,deadline,live,expected):
            return local and now<deadline+1 and live==expected
        self.assertFalse(observation(True,0.2,3.8,None,'exit'))
        self.assertTrue(observation(True,0.3,3.8,'exit','exit'))
        self.assertFalse(observation(False,0.3,3.8,'exit','exit'))
        self.assertFalse(observation(True,4.8,3.8,'exit','exit'))
        self.assertFalse(observation(True,0.3,3.8,'new','exit'))
        for name in ('cortexParachuteDeploy','cortexParachuteProtectionRelease'):
            text=source(name)
            self.assertLess(text.index('!(_receipt isEqualType [])'),text.index('_receipt params'))
