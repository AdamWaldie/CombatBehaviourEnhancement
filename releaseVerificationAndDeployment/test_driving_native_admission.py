"""Alternate-path native task ownership gates; not engine movement acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class NativeAdmissionTests(unittest.TestCase):
    def test_direct_native_intent_keeps_original_goal_and_observes_return_without_replay(self):
        def read(name):return (ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
        native=read('drivingNativeRouteReceipt')
        for proof in ('count waypoints _nativeGroup > 1','!local _nativeGroup','!local _nativeVehicle',
                      '_nativePrior select 7','_nativePrior select 8','_nativeDriverGoal vectorDistance _nativeGoal > 3',
                      'CBE_fnc_DrivingRecoveryCommandState','"NATIVE_MOVE",_nativeGroup'):
            self.assertIn(proof,native)
        body=native.split('params [[',1)[1]
        for forbidden in ('doMove','setVariable','getForcedSpeed','execFSM','addWaypoint','DrivingRouteReceipt'):
            self.assertNotIn(forbidden,body)
        self.assertIn('call CBE_fnc_DrivingNativeRouteReceipt',read('drivingRouteReceipt'))
        self.assertIn('+(_nativeGoalReceipt select 6)',read('drivingRouteGoal'))
        release=read('drivingRecoveryRelease')
        observation=release.split('// A native-route return was already issued.',1)[1].split('// This executor restores',1)[0]
        cleanup=(ROOT/'addons/vehicles/functions/drivingRecoveryCleanup.sqf').read_text(encoding='utf-8')
        self.assertIn('"request","nativeReturn","queueBinding"',cleanup)
        observer=cleanup.split('private _returnRetired=',1)[1].split('_current=_target getVariable',1)[0]
        self.assertIn('"DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease',observer)
        self.assertIn('if (_returnRetired) then',observer)

        self.assertIn('NATIVE_ROUTE_OBSERVED',observation)
        self.assertIn('releaseUnresolved',observation)
        self.assertNotIn('doMove',observation.split('if ((_work',1)[1])
        resumed=observation.split('private _returnBrain=',1)[1].split('if ((_vehicle getVariable',1)[0]
        self.assertIn('_work set ["deadline",_work get "hardDeadline"]',resumed)
        self.assertNotIn('set ["hardDeadline"',resumed)
        self.assertNotIn('doMove',resumed)
        self.assertIn('_admitted select 6) isEqualTo _nativeGoal',native)
        self.assertIn('serverTime >= (_work get "hardDeadline")',release)
        self.assertIn('["nativeReturn",[+_originalGoal,(serverTime+2) min (_work get "hardDeadline")',release)
        self.assertIn('if (!_nativeHandback) then {doStop _driver',release)
        self.assertIn('"NATIVE_MOVE") exitWith {false}',read('drivingGateIntent'))
        self.assertIn('"NATIVE_MOVE") exitWith {[false,false]}',read('drivingQueueAutoStep'))
        for name in ('drivingCorridorStep','drivingBypassStep'):
            self.assertIn('"NATIVE_MOVE") exitWith {_inactive}',read(name))


    def test_both_seats_require_idle_or_route_matching_move_before_acquisition(self):
        for name in ('drivingBypassStep','drivingCorridorStep'):
            source=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            helper=source.split('private _nativeAdmissionReady={',1)[1].split('\n};',1)[0]
            for marker in ('[_driver,_operator] findIf','toUpperANSI currentCommand _x','_command != ""',
                           '_command != "MOVE"','expectedDestination _x','vectorDistance _destination > 3'):
                self.assertIn(marker,helper)
            self.assertGreaterEqual(source.count('call _nativeAdmissionReady'),2)
            self.assertEqual(source.count('setDriveOnPath'),1)
    def test_ordinary_recovery_preserves_individual_seat_reservations(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        helper=assist.split('private _nativeTaskFree={',1)[1].split('private _routeIdentity=',1)[0]
        self.assertIn('!([_actor] call CBE_fnc_CortexActorMoveReserved)',helper)
        for seat in ['_driver','_movementOperator']:
            self.assertGreaterEqual(assist.count(f'[{seat}] call _nativeTaskFree'),2)
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        guard=release.split('} forEach [_driver,_operator];',1)[0]
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',guard)
        self.assertLess(release.index('CBE_fnc_CortexActorMoveReserved'),release.index('doStop _driver'))
        self.assertNotIn('setVariable ["CBE_Cortex_ActorMove",nil]',release)

    def test_alternate_paths_preserve_seat_reservations_during_execution_and_cleanup(self):
        for name,helper in [('drivingBypassStep','_seatsAvailable'),('drivingCorridorStep','_crewReady')]:
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            readiness=text.split(f'private {helper}={{',1)[1].split('} < 0',1)[0]
            self.assertIn('[_driver,_operator] findIf',readiness)
            self.assertIn('[_x] call CBE_fnc_CortexActorMoveReserved',readiness)
            writer=text.split('private _mayWrite={',1)[1].split('};',1)[0]
            self.assertIn(f'call {helper}',writer)
        for name,actor in [('drivingBypassRelease','_x'),('drivingCorridorRelease','_actor')]:
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertLess(text.index(f'!([{actor}] call CBE_fnc_CortexActorMoveReserved)'),text.index('doStop _driver'))
            self.assertNotIn('setVariable ["CBE_Cortex_ActorMove",nil]',text)

    def test_recovery_release_validates_route_and_mobility_before_any_stop(self):
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        transaction=release.split('private _released=false;',1)[1]
        self.assertIn('isNil {',transaction)
        self.assertLess(transaction.index('isNil {'),transaction.index('CBE_DrivingRecovery_Work'))
        for check in ('alive _vehicle','canMove _vehicle','simulationEnabled _vehicle',
                      '!isObjectHidden _vehicle','call CBE_fnc_DrivingRouteGoal',
                      'if (_originalGoal isNotEqualTo []) then {'):
            self.assertLess(transaction.index(check),transaction.index('doStop _driver'))
        self.assertLess(transaction.index('doStop _driver'),transaction.index('_operator doMove'))
        self.assertIn('if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work)',transaction)
        for forbidden in ('sleep ', 'waitUntil', 'spawn ', 'setCurrentWaypoint', 'deleteWaypoint', 'enableAI'):
            self.assertNotIn(forbidden,transaction)

    def test_recovery_holds_without_dismounted_or_disabled_follow_target(self):
        text=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        target=text.split('private _mountedTarget=',1)[1].split('doStop _driver',1)[0]
        for check in ('CortexCombatEffective','_leaderVehicle != _leader',
                      '_leaderVehicle isKindOf "LandVehicle"','alive _leaderVehicle',
                      'canMove _leaderVehicle','simulationEnabled _leaderVehicle',
                      '!isObjectHidden _leaderVehicle'):
            self.assertIn(check,target)
        handback=text.split('_handback="STOP_ONLY";',1)[1].split('if ((_vehicle getVariable',1)[0]
        gate='if (_leaderVehicle == _vehicle || {_mountedTarget}) then {'
        for command in ('_driver doFollow _operator','_operator doFollow _leader','_operator doMove'):
            self.assertLess(handback.index(gate),handback.index(command))
        for outcome in ('METADATA_ONLY','STOP_ONLY','AUTHORED_ROUTE','MOUNTED_LEADER'):
            self.assertIn(f'"{outcome}"',text)
        self.assertIn('_work get "hardDeadline",_handback],true]',text)
        self.assertNotIn('getIn',handback)
        self.assertNotIn('moveIn',handback)

    def test_unavailable_reverse_handback_retains_proof_and_retries_before_acquisition(self):
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        defer=release.split('if (_owned && {!_executable}) exitWith {',1)[1].split('if (_owned) then {',1)[0]
        self.assertIn('_work set ["releasePending",true]',defer)
        self.assertIn('"DEFERRED"',defer)
        self.assertLess(defer.index('if !(_work getOrDefault ["releasePending",false])'),defer.index('_vehicle setVariable'))
        for forbidden in ('nil,true','doMove','doStop','forceSpeed','serverTime+','waitAndExecute','spawn'):
            self.assertNotIn(forbidden,defer)
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        pending=assist.split('_recoveryWork getOrDefault ["releasePending",false]',1)[1].split('private _recoveryOwned=',1)[0]
        self.assertIn('"DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease',pending)
        self.assertIn('_recoveryWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]',pending)
        self.assertLess(assist.index('"DEFERRED_HANDBACK"'),assist.index('private _mayIssueDriving'))
        self.assertLess(release.index('if (_owned && {!_executable}) exitWith'),release.index('doStop _driver'))

    def test_recovery_admission_and_handback_both_preserve_all_trigger_links(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        admission=assist.split('private _recoveryOrderFree = {',1)[1].split('private _mayRecoverRoute',1)[0]
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        for text in [admission,release]:
            self.assertIn('call CBE_fnc_DrivingRouteGoal',text)
        goal=(ROOT/'addons/vehicles/functions/drivingRouteGoal.sqf').read_text(encoding='utf-8')
        self.assertIn('synchronizedTriggers _goalWaypoint isNotEqualTo []',goal)
        self.assertIn('synchronizedWaypoints _goalWaypoint isNotEqualTo []',goal)
        self.assertNotIn('triggerActivated',admission)

    def test_pre_path_rechecks_do_not_reject_fixed_path_owned_stop(self):
        bypass=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text(encoding='utf-8')
        self.assertIn('(_work get "phase") == "PLAN"} && {!(call _nativeAdmissionReady)',bypass)
        corridor=(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text(encoding='utf-8')
        self.assertIn('(_work getOrDefault ["phase",""]) == "APPROACH"',corridor)
        self.assertIn('call _mayWrite} && {call _approachTasksReady}',corridor)
        for name in ('drivingBypassRelease','drivingCorridorRelease'):
            source=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertNotIn('call _nativeAdmissionReady',source)
if __name__=='__main__': unittest.main()
