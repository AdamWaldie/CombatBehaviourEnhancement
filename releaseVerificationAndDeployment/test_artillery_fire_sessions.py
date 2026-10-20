"""Independent purpose/mode cancellation source contracts; not live-fire acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ArtilleryFireSessions(unittest.TestCase):
    def test_each_disable_uses_its_own_fire_generation(self):
        s=(ROOT/'addons/core/functions/aiTweaksSettingChanged.sqf').read_text(encoding='utf-8')
        block=s.split('private _fireGeneration=switch',1)[1].split('private _scootGeneration=',1)[0]
        for setting,key in (('Artillery_Enable','SupportFireGeneration'),
                            ('VehicleGunnery_Enable','DangerFireGeneration'),
                            ('ArtillerySmoke_Enable','SmokeFireGeneration')):
            self.assertIn('CBE_AIPass_'+setting,block)
            self.assertIn('CBE_Artillery_'+key,block)
        self.assertNotIn('CounterGeneration',block)
        self.assertNotIn('ShootAndScoot',block)
    def test_admission_captures_original_epochs_and_mission_checks_mode_separately(self):
        fire=(ROOT/'addons/support/functions/cortexArtilleryFire.sqf').read_text(encoding='utf-8')
        self.assertLess(fire.index('private _fireEpochs='),fire.index('private _retreatSmoke'))
        self.assertIn('[_x] call _batteryCrewUsable',fire)
        self.assertIn('!([_battery] call _batteryCrewUsable)',fire)
        crew=fire.split('private _batteryCrewUsable=',1)[1].split('if (isNull _battery)',1)[0]
        for guard in ('CortexCombatEffective','isPlayer _gunner','simulationEnabled _asset'):
            self.assertIn(guard,crew)
        self.assertIn('["fireGeneration",_fireEpochs select',fire)
        self.assertIn('["smokeGeneration",_fireEpochs select 2]',fire)
        step=(ROOT/'addons/support/functions/cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _smokeExpired=(_mission get "mode") == "SMOKE"',step)
        self.assertIn('_counterExpired || {_fireExpired} || {_smokeExpired}',step)
    def test_owner_request_signature_and_native_gate_include_original_generations(self):
        shot=(ROOT/'addons/support/functions/cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        self.assertIn('_counterGeneration,_fireGeneration,_smokeGeneration]',shot)
        gate=shot.split('private _fireSessionCurrent={',1)[1].split('private _danger=',1)[0]
        self.assertIn('_fireGeneration == (missionNamespace getVariable',gate)
        self.assertIn('_mode != "SMOKE"',gate)
        self.assertIn('_smokeGeneration == (missionNamespace getVariable',gate)
        self.assertEqual(shot.count('call _fireSessionCurrent'),2)
        self.assertEqual(shot.count('call _operatorAvailable'),2)
        available=shot.split('private _operatorAvailable=',1)[1].split('if (!(call _fireSessionCurrent)',1)[0]
        for guard in ('local _operator','isPlayer _operator','gunner _battery == _operator',
                      'CortexActorFireTaskAvailable','CortexExternalTakeover','FIREWEAPON'):
            self.assertIn(guard,available)

    def test_prefire_positioning_uses_existing_fsm_and_authenticated_physical_handoff(self):
        base=ROOT/'addons/support/functions'
        fire=(base/'cortexArtilleryFire.sqf').read_text()
        owner=(base/'cortexArtilleryPosition.sqf').read_text()
        report=(base/'cortexArtilleryPositionReport.sqf').read_text()
        step=(base/'cortexArtilleryMissionStep.sqf').read_text()
        self.assertIn('["phase", ["WAIT","POSITIONING"] select _positioning]',fire)
        self.assertIn('_fixAt+_positionFixLifetime',fire)
        self.assertIn('[10,120] select isNull _spotter',fire)
        phase=step.split('if (_phase == "POSITIONING") exitWith {',1)[1].split('if (time <',1)[0]
        self.assertNotIn('doArtilleryFire',phase)
        self.assertIn('positionResult',phase)
        self.assertNotIn('call _retirePosition',phase)
        self.assertIn('{_status != "READY"}',owner)
        self.assertIn('vectorMagnitude velocity _battery < 0.278',report)
        self.assertIn('{_positionLost}',step)
        for body in (owner,report,step,(base/'cortexArtilleryShot.sqf').read_text()):
            self.assertIn('call CBE_fnc_NativeOrderReceipt)',body)
            self.assertIn('getOrDefault ["artilleryPositionOrder",[]]',body)
        self.assertLess(owner.index('private _waypoint='),owner.index('_operation set ["artilleryPositionOrder"'))

        shot=(base/'cortexArtilleryShot.sqf').read_text()
        self.assertEqual(shot.count('call _positionCurrent'),2)
        self.assertIn('(_work getOrDefault ["status",""]) != "READY"',shot)
        scoot=(base/'cortexArtilleryScoot.sqf').read_text()
        self.assertLess(scoot.index('call CBE_fnc_CortexArtilleryPosition;'),
                        scoot.index('if !(call _sessionCurrent)'))
        self.assertIn('(_positionWork getOrDefault ["token",""]) == _token',scoot)

        for proof in ('HeadlessResolveSender','_replyOwner != owner _battery','distance2D _spot <= 25',
                      'inRangeOfArtillery','waypointType [_group,currentWaypoint _group] == "HOLD"'):
            self.assertIn(proof,report)
        for forbidden in ('spawn','waitUntil','setPos','setVelocity','doArtilleryFire'):
            self.assertNotIn(forbidden,owner)
        self.assertIn('CBE_ArtilleryPosition_Attempt',owner)
        self.assertNotIn('_session set',owner)
        self.assertIn('CBE_Artillery_SmokeFireGeneration',owner)

if __name__=='__main__': unittest.main()
