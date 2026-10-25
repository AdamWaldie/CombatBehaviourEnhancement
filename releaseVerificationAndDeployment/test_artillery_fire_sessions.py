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
        self.assertIn('_counterGeneration,_fireGeneration,_smokeGeneration,_dangerUntil]',shot)
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
        # Mixed-group readiness must follow exact crew proof at every firing boundary;
        # the dedicated branch cannot insert a whole-group waypoint or split membership.
        mixed=owner.split('if (_crewOnly) exitWith {',2)[2].split('private _started=false;',1)[0]
        self.assertIn('CBE_fnc_ArtilleryCrewMoveStart',mixed)
        starter=(base/'artilleryCrewMoveStart.sqf').read_text(encoding='utf-8')
        handover=starter.split('private _driving=',1)[1].split('call CBE_fnc_CortexOwnershipLease',1)[0]
        # Authored route rows are not the native receipt's vehicle slot. Current live
        # seats and all tracked cleanup vehicles must be gun-only before group finish.
        self.assertIn('CBE_DrivingAssist_Vehicles',handover)
        self.assertIn('count _controlled <= 64',handover)
        self.assertIn('count _members <= 64',handover)
        self.assertIn('_controlled findIf',handover)
        self.assertIn('_members findIf',handover)
        self.assertIn('CBE_fnc_DrivingRouteReceipt',handover)
        self.assertIn('count _route == 9 && {(_route select 2) isEqualTo _battery}',handover)
        self.assertNotIn('param [2,objNull]',handover)
        self.assertNotIn('DrivingOperationFinish',handover)

        for forbidden in ('CortexGroupMove','OperationStart','joinSilent','addWaypoint'):
            self.assertNotIn(forbidden,mixed)
        for body in (owner,report,step,shot):
            self.assertIn('CBE_fnc_ArtilleryCrewMoveCurrent',body)
        hold=(base/'artilleryCrewMoveCurrent.sqf').read_text(encoding='utf-8')
        server_return='if (_serverCheck && {isServer} && {!local _battery}) exitWith {true};'
        shared,local_hold=hold.split(server_return,1)
        # A remote owner's old HOLD packet must not bypass current replicated
        # crew readiness. Native destination/task and FSM proof remain owner-only.
        for check in ('CBE_fnc_CortexCombatEffective','group _x != _group',
                      'objectParent _x != _battery','isPlayer _x','remoteControlled _x',
                      'CBE_ExternalDrivingOwner','CBE_Convoy_Active'):
            self.assertIn(check,shared)
        self.assertNotIn('expectedDestination',shared.split('params [[',1)[1])
        for marker in ('CBE_ExternalDrivingOwner','CBE_Convoy_Active'):
            self.assertNotIn(marker,local_hold)
            self.assertEqual(hold.count(marker),1)

        for check in ('expectedDestination','CBE_fnc_CortexActorFireTaskAvailable','completedFSM'):
            self.assertIn(check,local_hold)
        worker=(base/'artilleryCrewMoveStep.sqf').read_text(encoding='utf-8')
        fsm=(ROOT/'addons/main/fsm/artilleryCrewMove.fsm').read_text(encoding='utf-8')
        self.assertIn('(_executor select 4) != _executorSerial',worker)
        casualty=worker.split('// Losing an original operating actor',1)[1].split('private _control=',1)[0]
        for check in ('_phase != "ISSUE"','alive _driver','_driver isEqualTo (_live select 0)',
                      '!(_x in _seats)','"retirementOnly",true'):
            self.assertIn(check,casualty)
        self.assertIn('private _sourceCurrent=!_retirementOnly',worker)
        deadline=worker.split('// A delayed callback cannot mint',1)[1].split('if (_phase == "REQUESTED") exitWith {',1)[0]
        self.assertLess(deadline.index('["RETIREMENT_TIMEOUT"] call _finish'),deadline.index('_x doMove _hold'))
        self.assertIn('getOrDefault ["cleanupUntil",(serverTime+30) min ((_work get "holdUntil")+30)]',deadline)
        self.assertIn('if (isNull _actor || {!alive _actor}) exitWith {false}',worker)

        self.assertIn('forEach _activeSeats;',worker)
        self.assertIn('private _observedOperator=if (_retirementOnly) then {_retirementActor}',worker)
        self.assertIn('private _observedDriver=if (_retirementOnly) then {_retirementActor}',worker)
        observation=(ROOT/'addons/vehicles/functions/vehicleCrewNativeObservation.sqf').read_text(encoding='utf-8')
        self.assertIn('[_observedDriver,_observedOperator] call CBE_fnc_VehicleCrewNativeObservation',worker)
        self.assertIn('count _observations != 4',worker)
        admission=(base/'artilleryCrewMoveStart.sqf').read_text(encoding='utf-8')
        self.assertIn('[_driver,_operator] call CBE_fnc_VehicleCrewNativeObservation',admission)
        self.assertIn('count _baseline != 4',admission)
        sample=observation.split('isNil {',1)[1]
        for guard in ('isNull _first','isNull _second','!local _first','!local _second'):
            self.assertLess(sample.index(guard),sample.index('currentCommand _first'))
        self.assertIn('if (_second != _first) then',sample)
        self.assertIn('_firstDestination apply {if (_x isEqualType []) then {+_x}',sample)
        self.assertIn('[_firstCommand,_firstDestination,_secondCommand,_secondDestination]',sample)
        for forbidden in ('doMove','doStop','doFollow','setVariable','spawn','CortexQueueJob'):
            self.assertNotIn(forbidden,sample)

        self.assertIn('_work set ["retirementActor",_retirementActor]',worker)
        self.assertIn('private _offset=[2,0] select _driverOnly',worker)
        self.assertIn('!isNull _x && {alive _x} && {_x in _activeSeats} && {(_baseline select _index) == "MOVE"}',worker)
        # The admitted original driver may retire after its separate commander dies.
        # Either original seated survivor can retire only; no replacement seat or
        # pre-issue casualty can gain an outward movement admission.
        def casualty_retirement(phase, driver_alive, commander_alive, current_driver_original, all_seats_original):
            return phase!='ISSUE' and driver_alive and not commander_alive and current_driver_original and all_seats_original
        self.assertTrue(casualty_retirement('MOVING',True,False,True,True))
        for args in (('ISSUE',True,False,True,True),('MOVING',False,False,False,True),
                     ('MOVING',True,False,True,False),('MOVING',True,True,True,True)):
            self.assertFalse(casualty_retirement(*args))
        def operator_only(phase,driver_alive,operator_alive,driver_vacant_or_original_dead,operator_original):
            return phase!='ISSUE' and not driver_alive and operator_alive and driver_vacant_or_original_dead and operator_original
        self.assertTrue(operator_only('MOVING',False,True,True,True))
        for args in (('ISSUE',False,True,True,True),('MOVING',True,True,True,True),
                     ('MOVING',False,False,True,True),('MOVING',False,True,False,True),
                     ('MOVING',False,True,True,False)):
            self.assertFalse(operator_only(*args))
        self.assertIn('(_live select 1) isEqualTo _operator',casualty)
        self.assertIn('(_live select 0) isEqualTo _driver && {!alive _driver}',casualty)
        self.assertIn('[_retirementActor] select',casualty)
        # Keep baseline slots0/2 in the original crew order even after one actor dies.
        baseline=['MOVE',['driver-goal'],'MOVE',['operator-goal']]
        for survivor,offset in (('driver',0),('operator',2)):
            before=[baseline[offset],baseline[offset+1]]*2
            self.assertEqual(before[1],[survivor+'-goal'])
            self.assertEqual(before[3],before[1])
        returning=worker.split('if (_phase == "RETURNING") exitWith {',1)[1]
        self.assertIn('_command in ["","WAIT"] && {_rest}',returning)
        self.assertIn('(getPosATL _battery) vectorDistance _point <= 2',returning)
        self.assertIn('_native vectorDistance _point > 0.25',returning)
        self.assertNotIn('doMove',returning)
        # A short native return can complete before the first callback. Idle alone,
        # a replaced destination, motion or a remote endpoint cannot prove return.
        def returned(command, destination_error, endpoint_distance, at_rest):
            return destination_error<=0.25 and (command=='MOVE' or
                command in ('','WAIT') and at_rest and endpoint_distance<=2)
        self.assertTrue(returned('MOVE',0,100,False))
        self.assertTrue(returned('WAIT',0,1,True))
        self.assertTrue(returned('',0.25,2,True))
        self.assertFalse(returned('WAIT',0,2.01,True))
        self.assertFalse(returned('WAIT',0,1,False))
        self.assertFalse(returned('WAIT',0.26,1,True))
        self.assertFalse(returned('STOP',0,1,True))

        self.assertIn('[_battery,_token,_serial,_executorSerial] call',fsm)
        retire=(base/'artilleryCrewMoveRetire.sqf').read_text(encoding='utf-8')
        self.assertNotIn('doMove',retire)
        casualty=retire.split('if (_phase == "UNRESOLVED" && {!_retryRefused}) exitWith {',1)[1].split('private _journal=+_work;',1)[0]
        self.assertIn('"ORIGINAL_CREW_LOST_AT_REST"',casualty)
        self.assertIn('alive _x',casualty)
        self.assertIn('!finite _linear',casualty)
        self.assertIn('!finite _angular',casualty)
        self.assertIn('_localLease isNotEqualTo (_work get "localLease")',casualty)
        self.assertLess(casualty.index('call CBE_fnc_CortexOwnershipLease'),casualty.index('"phase","RETIRED"'))
        for forbidden in ('doMove','joinSilent','moveIn','execFSM','setVelocity','cleanupUntil'):
            self.assertNotIn(forbidden,casualty)
        # Dead/deleted original actors plus measured rest, never one casualty or a timer.
        def released(living, linear, angular, other_lease=False, worker_live=False):
            import math
            return not living and math.isfinite(linear) and math.isfinite(angular) and linear<0.278 and angular<0.01 and not other_lease and not worker_live
        self.assertTrue(released(0,0,0))
        for args in ((1,0,0),(0,1,0),(0,0,0.02),(0,float('nan'),0),(0,0,float('nan')),(0,0,0,True),(0,0,0,False,True)):
            self.assertFalse(released(*args))
        retry=retire.split('private _resumePhase=',1)[1].split('// No living original actor',1)[0]
        for proof in ('!_live','"RETIREMENT_FSM_REFUSED"','"retirementFsmRetries",0','isEqualTo 0',
                      'serverTime < _retryUntil','finite _retryUntil','"release",false',
                      '_retryCrew findIf {!isNull _x && {alive _x}} >= 0'):
            self.assertIn(proof,retry)
        self.assertNotIn('serverTime+',retry)
        self.assertNotIn('execFSM',retry)
        self.assertIn('_journal set ["retirementResumePhase",_retirementPhase]',retire)
        self.assertLess(retire.index('_journal set ["retirementFsmRetries",1]'),retire.index('execFSM'))
        # Only one allocation refusal can reopen, inside the unchanged cleanup window.
        def may_retry(reason='RETIREMENT_FSM_REFUSED',phase='STOPPING',now=10,until=20,
                      retries=0,live=False,releasing=True,living_original=True):
            import math
            return (reason=='RETIREMENT_FSM_REFUSED' and phase in ('ISSUE','REQUESTED','MOVING','HOLD','STOPPING','RETURNING')
                    and math.isfinite(until) and now<until and retries==0 and not live and releasing and living_original)
        self.assertTrue(may_retry())
        for changed in ({'reason':'ACTOR_ORDER_REPLACED'},{'phase':'UNKNOWN'},{'now':20},
                        {'until':float('nan')},{'retries':1},{'live':True},{'releasing':False},
                        {'living_original':False}):
            self.assertFalse(may_retry(**changed),changed)
        self.assertIn('if !("cleanupUntil" in _journal)',retire)
        self.assertIn('"release",true',retire)
        self.assertIn('CBE_ArtilleryPosition_Attempt',owner)
        self.assertNotIn('_session set',owner)
        self.assertIn('CBE_Artillery_SmokeFireGeneration',owner)
        self.assertIn('["crew",[_driver,_operator]]',owner)
        self.assertLess(owner.index('["CREW_CHANGED"] call _finish'),owner.index('if (_ours) exitWith'))
        self.assertIn('clientOwner,[_driver,_operator]',owner)
        self.assertIn('count _issued == 8',report)
        self.assertIn('(_issued select 7) isEqualTo _seats',report)
        self.assertIn('(_issued select 7) isNotEqualTo _seats',step)
        shot=(base/'cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        gate=shot.split('private _positionCurrent={',1)[1].split('private _operatorAvailable=',1)[0]
        self.assertIn('(_work getOrDefault ["crew",[]]) isEqualTo _seats',gate)
        self.assertEqual(shot.count('call _positionCurrent'),2)
        ready=owner.split('if (_ours && {_status == "READY"}) then {',1)[1].split('if (_ours && {!_crewOnly}',1)[0]
        self.assertLess(ready.index('if (_readyBefore isEqualTo [])'),ready.index('_work set ["readyGoals",_readyNow]'))
        self.assertIn('_readyBefore isNotEqualTo _readyNow',ready)
        self.assertIn('_status="MOVEMENT_REPLACED"',ready)
        self.assertIn('getOrDefault ["readyGoals",[]]) isEqualTo',gate)
        self.assertIn('_seats apply {+((expectedDestination _x) param [0,[],[[]]])}',gate)
        self.assertIn('toUpperANSI currentCommand _x == "STOP"',gate)
        self.assertIn('_readyValid',ready)
        self.assertIn('_status="NATIVE_STATE_UNKNOWN"',ready)
        for guard in ('!local _x','CortexActorFireTaskAvailable','checkAIFeature "MOVE"',
                      'checkAIFeature "PATH"','CompatibilityExternalControl'):
            self.assertIn(guard,gate)
        self.assertLess(gate.index('!local _x'),gate.index('getOrDefault ["readyGoals",[]]'))
        for text in (report,step,gate):
            self.assertIn('if (isNull (_seats select 1)) then {_seats set [1,_seats select 0]}',text)


if __name__=='__main__': unittest.main()
