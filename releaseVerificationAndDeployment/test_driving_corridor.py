"""Corridor authority and proposal budgets; no physical steering acceptance."""
from pathlib import Path
import math
import unittest
ROOT = Path(__file__).resolve().parents[1]
class CorridorFoundationTests(unittest.TestCase):
    def test_server_area_and_request_registry_mutations_are_serialized(self):
        for filename,result,read,effects in (
            ('drivingCorridorRegister.sqf','_registration','private _snapshot=',
             ('_area setVariable','CBE_DrivingCorridor_Snapshot",[_revision,_records],true')),
            ('drivingCorridorDispatch.sqf','_applied','private _receipts=',
             ('createGroup [sideLogic,true]','call CBE_fnc_DrivingCorridorRegister',
              '_receipts set [_key,[_serial,_answer]]'))):
            s=(ROOT/'addons/vehicles/functions'/filename).read_text(encoding='utf-8')
            transaction=s.split('isNil {',1)[1]
            self.assertLess(transaction.index(result+'=call {'),transaction.index(read))
            for effect in effects:self.assertIn(effect,transaction)
            self.assertTrue(s.rstrip().endswith(result))
            for forbidden in ('sleep ','waitUntil','spawn {'):
                self.assertNotIn(forbidden,transaction)
    def test_release_reads_and_retires_one_episode_without_a_scheduled_gap(self):
        s=(ROOT/'addons/vehicles/functions/drivingCorridorRelease.sqf').read_text(encoding='utf-8')
        transaction=s.split('isNil {',1)[1]
        self.assertLess(transaction.index('_retired=call {'),transaction.index('private _work='))
        for effect in ('doStop _driver','_operator doMove waypointPosition',
                       'CBE_DrivingCorridor_Cooldown",_cooldown,true',
                       'CBE_DrivingCorridor_Result",','CBE_DrivingCorridor_Work",nil,true'):
            self.assertIn(effect,transaction)
        self.assertTrue(s.rstrip().endswith('_retired'))
        owned=transaction.split('private _owned=',1)[1].split('// The owned doStop',1)[0]
        self.assertIn('["","MOVE","WAIT"]+',owned)
        self.assertIn('[[],["STOP"]]',owned)
        self.assertIn('== "CROSS"',owned)
        for forbidden in ('sleep ','waitUntil','lineIntersectsSurfaces','nearestObjects'):
            self.assertNotIn(forbidden,transaction)
    def test_approach_cross_transition_commits_only_under_live_work_and_area(self):
        s=(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text(encoding='utf-8')
        transition=s.split('// Admission and the exact command/receipt transition',1)[1].split('if (_phase == "CROSS")',1)[0]
        self.assertLess(transition.index('isNil {'),transition.index('doStop _operator'))
        guards=transition.split('doStop _operator',1)[0]
        for guard in ('call _mayWrite','call _approachTasksReady','isNotEqualTo _work',
                      '!= "APPROACH"','serverTime >= (_work get "deadline")',
                      'isNotEqualTo (_work get "command")','isNotEqualTo _definition',
                      'isNotEqualTo (_work get "transform")','_now distance2D _entry > 8',
                      'vectorNormalized _direction'):
            self.assertIn(guard,guards)
        for write in ('doStop _driver','_vehicle setDriveOnPath _points',
                      '_work set ["phase","CROSS"]','_work set ["driverCommand",',
                      '_vehicle setVariable ["CBE_DrivingCorridor_Work",_work,true]'):
            self.assertIn(write,transition)
        self.assertNotIn('lineIntersectsSurfaces',transition)
    def test_convoy_tail_uses_interpolated_support_before_passage_credit(self):
        s=(ROOT/'addons/vehicles/functions/convoyCorridorStep.sqf').read_text(encoding='utf-8')
        floor=s.split('private _expectedFloor=[];',1)[1].split('if (abs _projection',1)[0]
        for marker in ('count _asl <= 20','_projection >= _pa','_projection <= _pb',
                       '_fraction=(_projection-_pa)/(_pb-_pa)',
                       '_expectedFloor isNotEqualTo []',
                       'abs ((_origin select 2)-(_expectedFloor select 0)) <= 2'):
            self.assertIn(marker,floor)
        self.assertNotIn('private _nearest=',s)
        entered=s.split('if (!_entered',1)[1].split('if (_entered',1)[0]
        self.assertIn('{_level}',entered)
        self.assertLess(s.index('private _level='),s.index('_row set [4,true]'))
        for command in ('lineIntersectsSurfaces','nearestObjects','setDriveOnPath','forceSpeed'):
            self.assertNotIn(command,floor)
    def test_crossing_rejects_underpass_height_before_entry_or_exit_credit(self):
        s=(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text(encoding='utf-8')
        crossing=s.split('if (_phase == "CROSS") then {',1)[1].split('// An unfinished column passage',1)[0]
        floor=crossing.split('private _expectedFloor=[];',1)[1].split('// An exit pose alone',1)[0]
        for marker in ('count _asl <= 20','_pa=(_a vectorDiff _centre) vectorDotProduct _travel',
                       '_pb=(_b vectorDiff _centre) vectorDotProduct _travel',
                       '_fraction=(_projection-_pa)/(_pb-_pa)',
                       '(_origin select 2)-(_expectedFloor select 0)',
                       'CORRIDOR_FLOOR_DEPARTED','isNil {_vehicle getVariable "CBE_DrivingCorridor_Work"}'):
            self.assertIn(marker,floor)
        self.assertLess(crossing.index('CORRIDOR_FLOOR_DEPARTED'),crossing.index('_work set ["entered",true]'))
        self.assertLess(crossing.index('CORRIDOR_FLOOR_DEPARTED'),crossing.index('"PHYSICALLY_CROSSED"'))
        for forbidden in ('lineIntersectsSurfaces','nearestObjects','getTerrainHeightASL','setPos','setVelocity'):
            self.assertNotIn(forbidden,floor)
    def test_registration_authenticates_remote_curators_and_has_no_movement_authority(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorRegister.sqf').read_text()
        body = source.split('params [[', 1)[1]
        self.assertIn('if (!isServer)', body)
        self.assertIn('getAssignedCuratorLogic', body)
        self.assertIn('CBE_DrivingCorridorArea', body)
        self.assertIn('curatorEditableObjects _curator', body)
        self.assertIn('count _records >= 32', body)
        self.assertLess(body.index('_area setVariable'), body.index('missionNamespace setVariable'))
        for command in ('doMove', 'setDriveOnPath', 'forceSpeed', 'remoteExecCall [', 'remoteExec [', 'spawn', 'waitUntil'):
            self.assertNotIn(command, body)
    def test_geometry_cannot_move_or_flatten_the_vehicle(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        body = source.split('params [[', 1)[1] + (ROOT / 'addons/vehicles/functions/drivingPathGeometry.sqf').read_text().split('params [[', 1)[1]
        for command in ('doMove', 'setDriveOnPath', 'forceSpeed', 'setPos', 'getTerrainHeightASL', 'spawn', 'waitUntil'):
            self.assertNotIn(command, body)
        self.assertIn('ASLToATL _x', body)
        self.assertIn('"MISSING_SUPPORT"', body)
        self.assertIn('"WET_SUPPORT"', body)
        self.assertIn('surfaceIsWater _sample', body)
        self.assertIn('isNull _supportObject', body)
        self.assertIn('if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2}', body)
        self.assertIn('"AREA_CHANGED"', body)
        self.assertIn('"HULL_TOO_WIDE"', body)
    def test_declared_sampling_bound_holds_across_allowed_lengths(self):
        for half_length in range(5, 46):
            segments = math.ceil(2 * (half_length + 30) / 8)
            stations = segments + 1
            self.assertLessEqual(stations, 20)
            self.assertLessEqual(3 * stations + 9 * segments, 231)
            self.assertLessEqual(2 * (half_length + 30) / segments, 8)

    def test_executor_is_finite_and_uses_physical_hull_completion(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        for required in ('serverTime >= (_work get "deadline")', '"hardDeadline"',
                         '"COMMAND_CHANGED"', '"AREA_CHANGED"', 'modelToWorldWorld',
                         'vectorDotProduct _travel < 5', '"PHYSICALLY_CROSSED"',
                         '"CORRIDOR_DEPARTED"', '_work getOrDefault ["entered",false]'):
            self.assertIn(required, source)
        self.assertNotIn('unitReady', source)
        self.assertEqual(source.count('setDriveOnPath'), 1)
        self.assertIn('_best=_via',source)
        self.assertIn('_via < 1.5*(_origin distance2D _destination)+100',source)
        self.assertEqual(source.count('call CBE_fnc_DrivingCorridorGeometry'),1)
        # Both areas are eligible shortcuts. The nearer entrance has a longer onward
        # leg; selecting it loses the useful route-choice intent of navigation areas.
        origin=(0,0);destination=(200,0)
        areas={'near':((10,100),(50,100)), 'direct':((110,0),(150,0))}
        costs={name:math.dist(origin,entry)+math.dist(entry,exit)+math.dist(exit,destination)
               for name,(entry,exit) in areas.items()}
        self.assertEqual(min(areas,key=lambda name:math.dist(origin,areas[name][0])),'near')
        self.assertEqual(min(costs,key=costs.get),'direct')
        self.assertTrue(all(cost < 1.5*math.dist(origin,destination)+100 for cost in costs.values()))

        for forbidden in ('addWaypoint', 'deleteWaypoint', 'enableAI', 'setPos', 'spawn', 'waitUntil'):
            self.assertNotIn(forbidden, source)
    def test_controller_owns_one_writer_and_suppresses_route_recovery(self):
        source = (ROOT / 'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('call CBE_fnc_DrivingCorridorStep', source)
        self.assertIn('[_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call CBE_fnc_DrivingCorridorRelease', source)
        self.assertIn('_capMps=_capMps min (_corridor select 1)', source)
        self.assertIn('&& {!_corridorActive} && {!_hadCorridor}', source)
        fsm = (ROOT / 'addons/main/fsm/drivingOperation.fsm').read_text()
        for phase in ('CORRIDOR_APPROACH', 'CORRIDOR_CROSS'):
            self.assertIn(phase, fsm)
        release = (ROOT / 'addons/vehicles/functions/drivingCorridorRelease.sqf').read_text()
        self.assertLess(release.index('expectedDestination _operator'), release.index('doStop _driver;'))
        self.assertIn('call CBE_fnc_CortexExternalTakeover', release)
    def test_full_hull_completion_does_not_accept_centre_only_crossing(self):
        # A centre ten metres past the plane still leaves a 16-metre half-length hull behind it.
        for half_length in (2, 8, 16, 23):
            extension = max(10, math.hypot(half_length, 2) + 6)
            self.assertGreaterEqual(extension - half_length, 5)
        self.assertLess(10 - 16, 5)

    def test_convoy_lead_keeps_one_executor_and_predecessor_followers(self):
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        call = '[_group,_lead,_group getVariable ["CBE_Convoy_Brain",createHashMap],"CONVOY"]'
        self.assertEqual(tick.count(call), 1)
        self.assertLess(tick.index(call), tick.index('private _routeWatch='))
        self.assertIn('if (!_corridorActive && {!_hadCorridor}', tick)
        self.assertIn('if (!_routeDone && {!_corridorActive} && {!_hadCorridor}', tick)
        self.assertIn('_leadLimit=_leadLimit min ((_corridor select 1)*3.6)', tick)
        for guard in ('CBE_Convoy_LocalRegistry', 'CBE_Convoy_LocalJobToken',
                      'CBE_Convoy_ReceivedRevision', '(_mobile select 0) isEqualTo _vehicle',
                      'CBE_Convoy_DrivingAssist_Enable'):
            self.assertIn(guard, step)
        self.assertIn('_convoy || {missionNamespace getVariable ["CBE_AIPass_Active",false]}', step)
    def test_convoy_halt_release_and_lead_replacement_retire_only_matching_work(self):
        crew = (ROOT / 'addons/vehicles/functions/convoyCrewLocal.sqf').read_text()
        release = (ROOT / 'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        halt = crew.split('if (_phase == "HALT"', 1)[1]
        self.assertLess(halt.index('doStop driver _vehicle;'), halt.index('"CONVOY_HALT",false'))
        self.assertIn('if (!(_vehicle in _keepCrew)', release)
        self.assertIn('"CONVOY_RELEASED",!_preserveMoves,_preserveMoves] call CBE_fnc_DrivingCorridorRelease', release)
        self.assertIn('"CONVOY_LEAD_CHANGED",false,true', tick)
        fsm = (ROOT / 'addons/main/fsm/convoyOperation.fsm').read_text()
        for phase in ('CORRIDOR_APPROACH', 'CORRIDOR_CROSS'):
            self.assertIn(phase, fsm)

    def test_ordinary_cleanup_cannot_retire_a_convoy_corridor(self):
        release = (ROOT / 'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        guard = release.split('private _corridor=', 1)[1].split('private _restore=', 1)[0]
        self.assertIn('param [0,""]) == "ORDINARY"', guard)
        self.assertLess(guard.index('== "ORDINARY"'), guard.index('call CBE_fnc_DrivingCorridorRelease'))

    def test_convoy_uses_worst_hull_without_multiplying_geometry_probes(self):
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        geometry = (ROOT / 'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        self.assertEqual(step.count('call CBE_fnc_DrivingCorridorGeometry'), 1)
        self.assertIn('count (_configuration param [4,[]]) <= 20', step)
        for dimension in range(3):
            self.assertIn(f'_envelope set [{dimension}', step)
            self.assertIn(f'_envelope param [{dimension},0]', geometry)
        self.assertIn('"INVALID_ENVELOPE"', geometry)

    def test_module_payload_values_are_parsed_and_authoritative(self):
        dialog = (ROOT / 'addons/vehicles/functions/zenDrivingCorridorModule.sqf').read_text()
        dispatch = (ROOT / 'addons/vehicles/functions/drivingCorridorDispatch.sqf').read_text()
        for key in ('mode', 'area', 'position', 'transform', 'facing', 'halfLength', 'halfWidth', 'speed', 'serial', 'expires'):
            self.assertIn(f'["{key}",', dialog)
            self.assertIn(f'getOrDefault ["{key}"', dispatch)
        self.assertLess(dispatch.index('isNull _curator'), dispatch.index('createUnit ['))
        self.assertLess(dispatch.index('_expires <= serverTime'), dispatch.index('createUnit ['))
        self.assertLess(dispatch.index('isNotEqualTo _transform'), dispatch.index('createUnit ['))
        self.assertIn('_serial == (_previous select 0)', dispatch)
        self.assertIn('count _receipts >= 64', dispatch)
        self.assertLess(dispatch.index('Corridor area budget reached'), dispatch.index('createGroup [sideLogic,true]'))
        self.assertIn('CBE_DrivingCorridor_LocalSerial', dispatch)
        self.assertIn('addCuratorEditableObjects', dispatch)
        self.assertIn('createGroup [sideLogic,true]', dispatch)
        self.assertIn('setGroupOwner _replyOwner', dispatch)
        self.assertNotIn('createVehicle [', dispatch)
        self.assertIn('"CBE_DrivingCorridorArea"', dispatch)
        self.assertNotIn('setDriveOnPath', dispatch)
    def test_native_module_is_disposable_and_persistent_area_has_no_recursive_module_function(self):
        config = (ROOT / 'addons/main/config.cpp').read_text()
        area = config.split('class CBE_DrivingCorridorArea: Logic {', 1)[1].split('};', 1)[0]
        self.assertNotIn('function =', area)
        module = (ROOT / 'addons/vehicles/functions/moduleDrivingCorridor.sqf').read_text()
        self.assertIn('!_activated', module)
        self.assertIn('CBE_processed', module)
        self.assertIn('deleteVehicle _logic;', module)
        mission=(ROOT/'addons/vehicles/functions/moduleDrivingCorridorMission.sqf').read_text()
        for guard in ('!isServer','is3DEN','remoteExecutedOwner','if (!_activated)',
                      '[_logic,[]] call CBE_fnc_DrivingCorridorRegister',
                      '[_area select 1,_area select 0,_speed]','CBE_DrivingCorridor_MissionResult'):
            self.assertIn(guard,mission)
        for forbidden in ('deleteVehicle','createUnit','setPos','hasInterface','doMove','forceSpeed','setDriveOnPath'):
            self.assertNotIn(forbidden,mission)
        eden=config.split('class CBE_ModuleDrivingCorridorMission:',1)[1].split('class CBE_ModuleGarrison:',1)[0]
        for field in ('scope = 2','scopeCurator = 0','isGlobal = 0','isDisposable = 0',
                      'isTriggerActivated = 1','canSetArea = 1','size3[] = {5, 25, -1}',
                      'class Speed: Combo','CBE_DrivingCorridor_EdenSpeed'):
            self.assertIn(field,eden)
        for name in ('drivingCorridorDispatch','drivingCorridorRegister','zenDrivingCorridorModule'):
            text=(ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text()
            self.assertIn('isKindOf "CBE_ModuleDrivingCorridorMission"',text)
        register=(ROOT/'addons/vehicles/functions/drivingCorridorRegister.sqf').read_text()
        self.assertIn('_dimensions isEqualTo [] && {_index < 0}',register)

        self.assertIn('[_position,_target,_facing] call CBE_fnc_ZenDrivingCorridorModule', module)

    def test_tail_passage_has_no_second_movement_or_speed_writer(self):
        source = (ROOT / 'addons/vehicles/functions/convoyCorridorStep.sqf').read_text().split('params [[',1)[1]
        for command in ('doMove', 'doFollow', 'doStop', 'forceSpeed', 'setDriveOnPath', 'addWaypoint',
                        'deleteWaypoint', 'setCurrentWaypoint', 'lineIntersects', 'nearEntities', 'spawn', 'waitUntil'):
            self.assertNotIn(command, source)
        self.assertIn('count _rows > 20', source)
        self.assertIn('modelToWorldWorld', source)
        self.assertIn('_crossed == count _rows && {count _rows > 0}', source)
        self.assertIn('"ALL_VEHICLES_PHYSICALLY_CROSSED","COMPLETE"', source)
        self.assertIn('"TAIL_TIMEOUT"', source)
        self.assertIn('_terminal param [6,[]]', source)
        self.assertIn('isNotEqualTo _identity', source)
        self.assertIn('["LEAD_"+(_leadResult', source)
    def test_tail_deadline_is_frozen_at_admission_and_not_renewed_by_owner(self):
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        passage = (ROOT / 'addons/vehicles/functions/convoyCorridorStep.sqf').read_text()
        self.assertIn('min 1800', step)
        self.assertIn('["tailDeadline",_tailDeadline]', step)
        self.assertIn('["deadline",_work get "tailDeadline"]', passage)
        self.assertNotIn('set ["deadline"', passage)
        self.assertIn('"DESTINATION_CLEARANCE"', step)
        self.assertIn('waypointCompletionRadius _waypoint max 20', step)
    def test_tail_caps_and_settlement_use_existing_convoy_callback(self):
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertEqual(tick.count('call CBE_fnc_ConvoyCorridorStep'), 1)
        self.assertIn('private _settled = !_passageActive && {!_bypassPassageActive} && {_routeDone}', tick)
        self.assertLess(tick.index('_limit=_limit min ((_passageCaps'), tick.index('_vehicle forceSpeed _ownedSpeed'))
        self.assertIn('"CORRIDOR_TAIL"', (ROOT / 'addons/main/fsm/convoyOperation.fsm').read_text())
    def test_tail_cleanup_matches_original_revision_and_preserves_authored_progression(self):
        passage = (ROOT / 'addons/vehicles/functions/convoyCorridorStep.sqf').read_text()
        self.assertIn('(_episode get "revision") == _revision', passage)
        self.assertIn('currentWaypoint _group < _index', passage)
        self.assertIn('CBE_AIPass_ZeusHold', passage)
        self.assertIn('CBE_fnc_AuthoredRouteReceipt', passage)
        crew = (ROOT / 'addons/vehicles/functions/convoyCrewLocal.sqf').read_text()
        self.assertIn('_revision >= (_passage get "revision")', crew)

    def test_separate_commander_and_driver_have_symmetric_authority_checks(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        crew = source.split('private _crewReady={',1)[1].split('private _controllerCurrent=',1)[0]
        for guard in ('[_driver,_operator] findIf', 'local _x', 'group _x != _group',
                      'vehicle _x != _vehicle', 'isPlayer _x', 'remoteControlled _x',
                      'CortexCombatEffective', 'CortexExternalOwner', 'checkAIFeature "MOVE"',
                      'checkAIFeature "PATH"', 'currentCommand _x'):
            self.assertIn(guard, crew)
        self.assertNotIn('_driver isEqualTo _operator', source)
        crossing = source.split('if (_phase == "APPROACH")',1)[1].split('if (_phase == "CROSS")',1)[0]
        self.assertLess(crossing.index('doStop _operator'), crossing.index('setDriveOnPath'))
        self.assertLess(crossing.index('doStop _driver'), crossing.index('setDriveOnPath'))
        self.assertIn('["driverCommand",+(expectedDestination _driver)]', crossing)
    def test_crossing_and_handback_preserve_both_seat_commands(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        release = (ROOT / 'addons/vehicles/functions/drivingCorridorRelease.sqf').read_text()
        for text in (source, release):
            self.assertIn('expectedDestination _driver', text)
            self.assertIn('getOrDefault ["driverCommand",[]]', text)
            self.assertNotIn('enableAI', text.split('params [[',1)[1])
            self.assertNotIn('disableAI', text.split('params [[',1)[1])
        self.assertIn('vehicle _operator == _vehicle', release)
        self.assertLess(release.index('_driver doFollow _operator'), release.index('_operator doMove waypointPosition'))

    def test_initial_corridor_commit_uses_defined_symmetric_native_receipts(self):
        source=(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _admissionNative=[_driver,_operator] apply',source)
        self.assertLess(source.index('private _admissionNative='),source.index('call CBE_fnc_DrivingCorridorGeometry'))
        self.assertNotRegex(source,r'\b_native\b')
        mutation=source.split('private _admitted=false;',1)[1]
        self.assertLess(mutation.index('isNil {'),mutation.index('_operator doMove'))
        for guard in ('call _mayWrite','call _nativeAdmissionReady','call _admissionCurrent',
                      'isNil {_vehicle getVariable "CBE_DrivingCorridor_Work"}',
                      'isEqualTo _definition','isEqualTo _transform'):
            self.assertLess(mutation.index(guard),mutation.index('_operator doMove'))
        self.assertLess(mutation.index('_operator doMove'),mutation.index('setVariable ["CBE_DrivingCorridor_Work"'))
        self.assertIn('if (!_admitted) exitWith {_inactive}',mutation)
    def test_undefined_local_lint_is_a_build_error(self):
        import tomllib
        config=tomllib.loads((ROOT/'.hemtt/project.toml').read_text(encoding='utf-8'))
        self.assertEqual(config['lints']['sqf']['undefined'],'Error')
