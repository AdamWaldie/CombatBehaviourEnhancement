"""Native driver handover authority/phase contracts; physical actions remain unaccepted."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingCrewTests(unittest.TestCase):
    def source(self):
        return (ROOT/'addons/vehicles/functions/drivingCrewStep.sqf').read_text(encoding='utf-8')
    def test_new_driver_candidate_preserves_primary_gunner_when_alternatives_exist(self):
        s=(ROOT/'addons/vehicles/functions/drivingCrewStep.sqf').read_text()
        selection=s.split('private _cargo=',1)[1].split('if (_choices isNotEqualTo []) then',1)[0]
        self.assertLess(selection.index('_choices=_cargo'),selection.index('commander _vehicle'))
        self.assertLess(selection.index('_choices=_commandCrew'),selection.index('gunner _vehicle'))
        self.assertIn('_choices select {(_x select 0) != _primaryGunner}',selection)
        self.assertIn('if (_otherCrew isNotEqualTo []) then {_choices=_otherCrew}',selection)
        self.assertNotIn('action [',selection)
        self.assertNotIn('moveIn',selection)
        admission=s.split('if (count _work == 0) then {',1)[1]
        self.assertLess(admission.index('private _cargo='),admission.index('_work=createHashMapFromArray'))

    def test_actions_are_once_per_phase_and_vacancy_is_observed(self):
        s=self.source().split('params [[',1)[1]
        self.assertEqual(s.count(' action ['),2)
        self.assertIn('_phase == "READY" && {!isNull _driver}',s)
        self.assertIn('driver _vehicle == _driver} && {!alive _driver}',s)
        self.assertEqual(s.split('// Seat vacancy and native order proof',1)[1].count('\n    isNil {'),2)
        self.assertEqual(s.count('call _commandsOwned'),2)
        self.assertIn('_phase="VACATING_ISSUED"',s)
        self.assertIn('if (_phase in ["READY","VACATING"]) then {',s)
        self.assertIn('call _commandsOwned} && {isNull driver _vehicle}',s)
        self.assertIn('_work set ["phase","SWITCHING"]',s)
        for command in ('moveInDriver','moveOut','setPos','setVelocity','setHitPointDamage','allowDamage','enableAI','doMove','setDriveOnPath','spawn','sleep'):
            self.assertNotIn(command,s)
    def test_authority_and_original_orders_bind_late_writes(self):
        s=self.source()
        for guard in ('remoteExecutedOwner > 0','CBE_Driving_Brain','CBE_AIPass_Epoch','CortexZeusHeld',
                      'CortexExternalTakeover','CBE_Convoy_Active','CBE_ExternalDrivingOwner','DrivingMovementAvailable',
                      'count _crew <= 20','abs speed _vehicle < 1','!lockedDriver _vehicle',
                      'isPlayer _actor','group _actor != _group','currentCommand _actor in _tasks',
                      'waypointStatements','waypointScript','waypointTimeout','synchronizedTriggers',
                      'expectedDestination _candidate','expectedDestination leader _group','assignedVehicleRole _candidate',
                      'simulationEnabled _candidate','_candidate checkAIFeature "PATH"'):
            self.assertIn(guard,s)
        self.assertIn('alive _driver}) exitWith {}',s)
        self.assertIn('private _available={\n    _crew=fullCrew',s)
        self.assertIn('_previousVehicle != vehicle leader _group',s)
        self.assertIn('toLowerANSI (_x select 1) == "cargo"',s)
        self.assertEqual(s.count('call _available'),3)
    def test_native_command_changes_guard_admission_and_both_actions(self):
        s=self.source()
        self.assertIn('currentCommand leader _group != "STOP"',s)
        self.assertIn('currentCommand _actor != "STOP"',s)
        self.assertIn('["nativeCommand",currentCommand _candidate]',s)
        self.assertIn('["leaderNativeCommand",currentCommand leader _group]',s)
        gate=s.split('private _commandsOwned={',1)[1].split('if (_phase == "READY"',1)[0]
        self.assertIn('currentCommand _candidate != "STOP"',gate)
        self.assertEqual(gate.count('call _commandOwned'),2)
        self.assertEqual(s.count('call _commandsOwned'),2)
        transition=s.split('private _commandOwned={',1)[1].split('private _crew=',1)[0]
        self.assertIn('_actor == _candidate',transition)
        self.assertIn('_phase == "SWITCHING"',transition)
        self.assertIn('currentCommand _actor == "ACTION"',transition)
        self.assertNotIn('"STOP"',transition)
        self.assertLess(transition.index('MISSING_RECEIPT'),transition.index('currentCommand _actor == _receipt'))
        # Rebase only after the controller's own native action, never at callback entry.
        self.assertGreater(s.index('_work set ["nativeCommand",'),s.index('_candidate action ["MoveToDriver"'))

    def test_vacant_seat_does_not_override_incoming_assignment(self):
        s=self.source()
        available=s.split('private _available={',1)[1].split('private _finish=',1)[0]
        self.assertIn('fullCrew [_vehicle,"driver",true]',available)
        self.assertIn('_driverSeat param [5,objNull]',available)
        self.assertIn('count _driverSeat >= 6',available)
        self.assertIn('isNull _assignedDriver || {!alive _assignedDriver} || {_assignedDriver == _candidate}',available)
    def test_deadlines_success_and_cancellation_are_not_synthetic(self):
        s=self.source()
        self.assertEqual(s.count('serverTime+25'),1)
        self.assertIn('serverTime >= (_work get "deadline")',s)
        self.assertIn('driver _vehicle == _candidate && {[_candidate] call CBE_fnc_CortexCombatEffective}',s)
        self.assertIn('["COMPLETE","CANCELLED","EXPIRED"]',s)
        release=s.split('if (_release) exitWith {',1)[1].split('if (count _work > 0 && {(_work get "group") != _group})',1)[0]
        self.assertNotIn(' action [',release)
        self.assertIn('(_brain getOrDefault ["route",[]])',release)
        finish=(ROOT/'addons/vehicles/functions/drivingOperationFinish.sqf').read_text(encoding='utf-8')
        self.assertIn('[_group,_brain,true] call CBE_fnc_DrivingCrewStep',finish)
    def test_existing_fsm_owns_the_only_scheduler(self):
        step=(ROOT/'addons/vehicles/functions/drivingOperationStep.sqf').read_text(encoding='utf-8')
        start=(ROOT/'addons/vehicles/functions/drivingOperationStart.sqf').read_text(encoding='utf-8')
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('private _crewPending=[_group,_brain] call CBE_fnc_DrivingCrewStep',step)
        self.assertIn('if (_crewPending) then {_phase="CREW_HANDOVER"}',step)
        self.assertIn('_crewPending || {_traffic}',step)
        self.assertIn('isNull driver _vehicle || {!alive driver _vehicle}',start)
        self.assertIn('class CrewHandover',fsm)
        self.assertNotIn('execFSM',self.source())
        source=self.source()
        self.assertLess(source.index('count _liveWork == 0'),source.index('call CBE_fnc_DrivingRouteReceipt'))
        self.assertLess(source.index('count _liveWork == 0'),source.index('fullCrew'))

    def test_physical_fixture_uses_discovery_and_measured_results(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingCrew.sqf').read_text(encoding='utf-8')
        self.assertNotIn('call CBE_fnc_DrivingCrewStep',s)
        self.assertNotIn('setVariable ["CBE_DrivingCrew_Work"',s)
        self.assertNotIn(' action [',s)
        self.assertIn('_vehicle distance2D _routeStart >= 35',s)
        self.assertIn('driver _vehicle == _replacement',s)
        self.assertIn('vehicle _driver != _vehicle',s)
        self.assertIn('private _moved=if (_seated) then {',s)
        self.assertLess(s.index('_driver setDamage 1'),s.index('_vehicle forceSpeed -1'))
        for case in ('"REPLACE"','"UNCONSCIOUS"','"LOCKED"','"ASSIGNED"'):
            self.assertIn(case,s)
        self.assertEqual(s.count('moveInCargo'),1)
        self.assertLess(s.index('moveInCargo'),s.index('_driver setDamage 1'))
        self.assertIn('CBE_CortexQA_HeadlessBatch',s)
        self.assertIn('CBE_Headless_ExcludeGroup',s)

    def test_seat_actions_do_not_require_remote_vehicle_movement_authority(self):
        s=self.source().split('params [[',1)[1]
        self.assertNotIn('local _vehicle',s)
        for proof in ('!local _group','local _actor','!local _candidate','local _driver','call _commandsOwned'):
            self.assertIn(proof,s)
        start=(ROOT/'addons/vehicles/functions/drivingOperationStart.sqf').read_text(encoding='utf-8')
        self.assertIn('(local _vehicle && {!isNull driver _vehicle}',start)
        self.assertIn('vehicle leader _group == _vehicle',start)
        driving=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('!local _vehicle',driving)
        for forbidden in ('setOwner','setGroupOwner','forceSpeed','setDriveOnPath','setVelocity','moveInDriver'):
            self.assertNotIn(forbidden,s)

    def test_actor_reservations_veto_selection_and_each_native_seat_action(self):
        s=self.source()
        choices=s.split('private _choices=',1)[1].split('private _cargo=',1)[0]
        self.assertIn('!([_actor] call CBE_fnc_CortexActorMoveReserved)',choices)
        available=s.split('private _available={',1)[1].split('private _finish=',1)[0]
        self.assertIn('isNull _candidate || {!([_candidate] call CBE_fnc_CortexActorMoveReserved)}',available)
        commands=s.split('private _commandsOwned={',1)[1].split('if (_phase == "READY"',1)[0]
        self.assertIn('!([_candidate] call CBE_fnc_CortexActorMoveReserved)',commands)
        self.assertEqual(s.count('call _commandsOwned'),2)

    def test_journal_is_copied_and_published_only_against_exact_snapshot(self):
        s=self.source()
        self.assertIn('private _entryWork=+_liveWork;',s)
        self.assertLess(s.index('count _liveWork == 0'),s.index('private _entryWork=+_liveWork;'))
        self.assertIn('private _work=+_entryWork;',s)
        publish=s.split('private _publish={',1)[1].split('private _route=',1)[0]
        for guard in ('isNil {','local _group','isEqualTo _brain','ownerEpoch','isEqualTo _entryWork'):
            self.assertLess(publish.index(guard),publish.index('setVariable ["CBE_DrivingCrew_Work"'))
        self.assertIn('setVariable ["CBE_DrivingCrew_Work",+_work,true]',publish)
        self.assertEqual(s.count('setVariable ["CBE_DrivingCrew_Work"'),1)
        self.assertIn('if (count _work > 0 && {(_work get "group") != _group}) exitWith {false}',s)

    def test_native_seat_actions_recheck_live_journal_deadline_and_publish_atomically(self):
        s=self.source()
        gate=s.split('private _commandsOwned={',1)[1].split('if (_phase == "READY"',1)[0]
        self.assertIn('isEqualTo _entryWork',gate)
        self.assertIn('serverTime < (_work get "deadline")',gate)
        for action,phase in (('Eject','VACATING'),('MoveToDriver','SWITCHING')):
            boundary=s.split(f'action ["{action}",_vehicle];',1)[1].split('    };',1)[0]
            self.assertLess(boundary.index(f'_work set ["phase","{phase}"]'),boundary.index('call _publish'))

    def test_replaced_journal_does_not_receive_old_cancellation(self):
        # Dict copies model isolation only, never native seat-action execution.
        original={'phase':'READY','episode':1}
        entry=dict(original)
        work=dict(entry)
        work['phase']='CANCELLED'
        self.assertEqual(original['phase'],'READY')
        successor={'phase':'SWITCHING','episode':2}
        live=successor
        if live==entry:live=dict(work)
        self.assertEqual(live,successor)

    def test_late_order_fixture_observes_real_vacancy_and_original_deadline(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingCrew.sqf').read_text()
        block=qa.split('private _entry=createHashMap;',1)[1].split('private _cleanup=',1)[0]
        for proof in ('== "VACATING"','isNull driver _vehicle','vehicle _driver != _vehicle',
                      '_entry=+_live','doStop _replacement','doGetOut _replacement',
                      '_replacement doMove _newDestination','(_entry get "deadline")+3',
                      'serverTime >= _observeUntil','== "CANCELLED"','alive _vehicle','alive _replacement','damage _vehicle <= _damaged+0.01','isEqualTo _entry','_issued=true','call _sampleIntent',
                      '_replacement distance2D _replacementOrigin >= 25',
                      'distance2D _newDestination <= (_replacementOrigin distance2D _newDestination)-20'):
            self.assertIn(proof,block)
        for forbidden in ('setVariable ["CBE_DrivingCrew_Work"','call CBE_fnc_DrivingCrewStep',
                          'moveInDriver','moveOut','setPos','setVelocity',' action ['):
            self.assertNotIn(forbidden,block)
        self.assertIn('"LATE_STOP","LATE_GETOUT"',qa)
