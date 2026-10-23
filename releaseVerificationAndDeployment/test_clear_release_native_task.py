"""Clear-release authority regressions; not physical handover acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ClearReleaseNativeTaskTests(unittest.TestCase):
    def test_new_nonmovement_tasks_cannot_grant_formation_recall(self):
        def owned(command,matching_destination,matching_hold=False):
            return command == "" or (command == "STOP" and matching_hold) or (command=="MOVE" and matching_destination)
        for command in ("FOLLOW","ATTACK","WAIT","FIRE","SUPPRESS","HIDE","EXPECT","JOIN","SCRIPTED"):
            self.assertFalse(owned(command,True),command)
        self.assertTrue(owned("MOVE",True))
        self.assertFalse(owned("MOVE",False))
        self.assertFalse(owned("STOP",False))
        self.assertTrue(owned("STOP",False,True))
        self.assertTrue(owned("",False))
        # A settings lease or a previous stop elsewhere is not a current spatial hold.
        def same_hold(pose,post):
            return sum((a-b)**2 for a,b in zip(pose,post)) <= 1.5**2 and abs(pose[2]-post[2]) <= .75
        self.assertTrue(same_hold((0,0,0),(1,0,0)))
        self.assertFalse(same_hold((0,0,0),(2,0,0)))
        self.assertFalse(same_hold((0,0,0),(0,0,1)))
        helper=(ROOT/'addons/infantry/functions/buildingActorHoldOwned.sqf').read_text()
        self.assertIn('vectorDistance (AGLToASL _x) <= 1.5',helper)
        self.assertIn('<= 0.75',helper)
        self.assertIn('(_receipt select 1) isEqualTo _context',helper)
        for command in ('doMove','doStop','doFollow'):
            self.assertNotIn(command,helper)

    def test_recall_boundary_requires_allowed_command_and_move_receipt(self):
        s=(ROOT/'addons/infantry/functions/cortexClearRelease.sqf').read_text()
        self.assertIn('private _taskFree=!fleeing _x',s)
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        available=step.split('private _actorAvailable={',1)[1].split('private _actorTaskFree={',1)[0]
        task=step.split('private _actorTaskFree={',1)[1].split('// Record only stops',1)[0]
        reserve=step.split('private _reserveReady={',1)[1].split('private _reserveCommitReady={',1)[0]
        self.assertIn('!fleeing _actor',available)
        self.assertIn('!fleeing _actor',task)
        self.assertIn('!fleeing _candidate',reserve)
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        self.assertIn('&& {!isPlayer _actor} && {!fleeing _actor}',admission)
        recognition=s.split('private _ownedMove=',1)[1].split('call CBE_fnc_CortexClearSettingsRelease',1)[0]
        self.assertIn('currentCommand _x == "MOVE"',recognition)
        self.assertIn('_releaseMoveDestination vectorDistance _releaseMoveTarget <= 0.25',recognition)
        self.assertIn('private _ownedActor=_heldByJob || {_ownedMove}',recognition)
        self.assertIn('!finite _x',recognition)
        start=s.index('private _movementOwned=')
        end=s.index('if (_restore && {_taskFree} && {_movementOwned} && {isNull objectParent _x})',start)
        guard=s[start:end]
        self.assertIn('currentCommand _x == ""',guard)
        self.assertIn('[_x,_releaseJob] call CBE_fnc_BuildingActorHoldOwned',guard)
        self.assertIn('currentCommand _x == "MOVE"',guard)
        self.assertIn('_destination vectorDistance _issued <= 0.25',guard)
        self.assertNotIn('!= "MOVE"',guard)
        self.assertLess(end,s.index('_x doFollow _leader',end))


class ClearFinishNativeTaskTests(unittest.TestCase):
    def test_egress_and_finish_share_the_native_task_guard(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        start=s.index('private _exitMovementOwned=')
        end=s.index('private _activeOwnMove=',start)
        self.assertIn('currentCommand _actor == ""',s[start:end])
        self.assertIn('[_actor,_job] call CBE_fnc_BuildingActorHoldOwned',s[start:end])
        self.assertIn('[_actor] call _ownsCurrentMove',s[start:end])
        self.assertIn('&& {[_x] call _exitMovementOwned}) then {',s)
        self.assertIn('if !([_unit] call _exitMovementOwned) then {',s)
        self.assertIn('if !([_actor] call _exitMovementOwned) then {',s)
        self.assertIn('_diverted pushBackUnique _unit;',s)
        self.assertIn('_diverted pushBackUnique _actor;',s)
        self.assertIn('_job set ["egressFailed",true]',s)


class EarlyExitNativeTaskTests(unittest.TestCase):
    def test_early_exit_arrival_and_recovery_preserve_native_tasks(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        service=s.split('private _earlyExits=_job getOrDefault ["earlyExits",createHashMap];',1)[1].split('// An early arrival supports ongoing clearance',1)[0]
        self.assertIn('|| {!([_actor] call _exitMovementOwned)}',service)
        self.assertLess(service.index('call _exitMovementOwned'),service.index('doStop _actor'))
        self.assertIn('_record set [3,"DIVERTED"]',service)
        self.assertIn('_job set ["egressFailed",true]',service)
        recovery=service.split('serverTime-(_motion select 1) >= 8',1)[1]
        self.assertLess(recovery.index('call _exitMovementOwned'),recovery.index('call _recoverClearActor'))


class DoorObservationAuthorityTests(unittest.TestCase):
    def test_metadata_discovery_cannot_open_or_consume_cooldown(self):
        s=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        cutoff=s.index('if (_metadataOnly) exitWith {false};')
        self.assertLess(s.index('CBE_Cortex_DoorDefinitions'),cutoff)
        self.assertLess(cutoff,s.index('call BIS_fnc_door'))
        self.assertLess(cutoff,s.index('setVariable ["CBE_Cortex_DoorRequestUntil"'))
        final=s.split('if (_near && {_visible}',1)[1].split('call BIS_fnc_door',1)[0]
        for gate in ('currentCommand _unit != "STOP"','local _unit','simulationEnabled _unit',
                     '!isObjectHidden _unit','checkAIFeature "MOVE"','checkAIFeature "PATH"',
                     'vectorDistance _position <= 3','isNull objectParent _unit'):
            self.assertIn(gate,final)
        caller=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        discovery=caller.split('// Before exterior actors commit',1)[1].split('private _allLocked=',1)[0]
        self.assertIn('["CLEAR",_job get "generation"],true] call CBE_fnc_CortexBuildingDoor',discovery)

    def test_context_binds_actual_building_assignment_and_native_task(self):
        s=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        context=s.split('private _key=switch',1)[1].split('if (isNull _unit',1)[0]
        for guard in ('call CBE_fnc_CortexActorMoveReserved','currentCommand _unit in ["","MOVE"]',
                      'getOrDefault ["building",objNull]) == _building','CBE_AIPass_GarrisonPos',
                      '(_assignment select 2) == _building','(_assignment select 3) isEqualTo',
                      'CBE_Cortex_GarrisonMove','_live vectorDistance (_receipt select 3) <= 0.25',
                      'call CBE_fnc_NativeOrderReceipt','getOrDefault ["team",[]]'):
            self.assertIn(guard,context)
        garrison=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        delayed=garrison.split('private _commandOwned=',1)[1].split('private _pending =',1)[0]
        self.assertIn('_command in ["","STOP"]',delayed)
        self.assertIn('_command == "MOVE"',delayed)
        self.assertNotIn('!(_command in',delayed)

    def test_garrison_reapplication_distinguishes_fresh_actors_from_adoption(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        admission=s.split('private _mayIssueMovement = {',1)[1].split('private _rememberMove =',1)[0]
        for guard in ('_actor in _freshActors','count _receipt == 5',
                      '(_receipt select 4) isEqualTo _assignment','_live vectorDistance (_receipt select 3) <= 0.25',
                      'call CBE_fnc_CortexGarrisonArrived'):
            self.assertIn(guard,admission)
        self.assertIn('!_heldInPlace && {_unit in _freshActors}',s)
        self.assertIn('private _atPost=[_unit,_assignment] call _assignmentArrived;',s)
        hold=s.split('if (_atPost &&',1)[1].split('if (!_atPost',1)[0]
        self.assertIn('call _rememberMove',hold)
        self.assertNotIn('doMove',hold)
        self.assertIn('currentCommand _unit == "MOVE"',hold)
        self.assertIn('(expectedDestination _unit) param [0,_destination]',hold)
        explicit=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        self.assertIn('[_group,_units] call CBE_fnc_CortexGarrisonApplyLocal',explicit)
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',explicit.split('private _units =',1)[1].split('if (_units isEqualTo',1)[0])
        refill=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        self.assertIn('[_group,[_actor]] call CBE_fnc_CortexGarrisonApplyLocal',refill)
        self.assertIn('currentCommand _actor in ["","STOP"]',refill)
        discover=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        self.assertIn('[_group] call CBE_fnc_CortexGarrisonApplyLocal',discover)


class DoorCommitBoundaryTests(unittest.TestCase):
    def test_door_effect_rechecks_fresh_geometry_locks_and_order_atomically(self):
        text=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        commit=text.split('if (_near && {_visible}) then {',1)[1].split('call BIS_fnc_door',1)[0]
        for proof in ('isNil {','count _visibilityProof == 5','time-(_visibilityProof select 4) <= 0.5',
                      'getPosWorld _building','eyePos _unit','animationSourcePhase _source',
                      'CBE_Cortex_DoorRequestUntil','bis_disabled_Door','call _orderCurrent',
                      'CBE_fnc_CortexExternalTakeover'):
            self.assertIn(proof,commit)
        self.assertNotIn('lineIntersectsSurfaces',commit)
        self.assertLess(commit.index('isNil {'),commit.index('setVariable ["CBE_Cortex_DoorRequestUntil"'))


class ClearReleaseEpisodeTests(unittest.TestCase):
    def test_group_and_actor_release_preserve_successor_episode(self):
        text=(ROOT/'addons/infantry/functions/cortexClearRelease.sqf').read_text()
        admission=text.split('private _releaseAdmitted=false;',1)[1].split('// A release often',1)[0]
        self.assertIn('isNil {',admission)
        self.assertIn('isEqualTo _order',admission)
        self.assertIn('isEqualTo _buildingBrain',admission)
        self.assertIn('if (!_releaseAdmitted) exitWith {false}',admission)
        retirement=text.split('private _groupRetired=false;',1)[1].split('private _leader=',1)[0]
        self.assertLess(retirement.index('_releaseGeneration =='),retirement.index('setVariable ["CBE_AIPass_ClearOrder", nil'))
        self.assertIn('if (!_groupRetired) exitWith {false}',retirement)
        actors=text.split('private _leader=',1)[1]
        for proof in ('isNil {','_releaseGeneration ==','_entryEpoch ==','group _x == _group'):
            self.assertLess(actors.index(proof),actors.index('_x doFollow _leader'))
        self.assertIn('== _entryOperationGeneration',text)


class NaturalFinishEpisodeTests(unittest.TestCase):
    def test_natural_finish_rechecks_brain_before_actor_and_terminal_writes(self):
        text=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        finish=text.split('private _finish = {',1)[1].split('private _mayIssueMovement',1)[0]
        self.assertIn('private _finishCurrent=',finish)
        self.assertIn('CBE_BuildingBrain",createHashMap]) isEqualTo _brain',finish)
        self.assertIn('if (call _finishCurrent && {local _x}',finish)
        commit=finish.split('private _terminalPublished=false;',1)[1]
        self.assertLess(commit.index('isNil {'),commit.index('setVariable ["CBE_Cortex_ClearResult"'))
        self.assertLess(commit.index('call _finishCurrent'),commit.index('setVariable ["CBE_Cortex_ClearResult"'))
        self.assertIn('if (!_terminalPublished) exitWith {-1}',commit)
        explicit=(ROOT/'addons/infantry/functions/cortexClearRelease.sqf').read_text()
        actors=explicit.split('if (local _group && {local _x}',1)[1]
        self.assertLess(actors.index('_leader=[_group] call'),actors.index('_x doFollow _leader'))
