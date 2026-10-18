"""Generic calm cleanup must not erase or recall another finite actor task."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CalmActorReservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s=(ROOT/'addons/infantry/functions/cortexRestoreCalm.sqf').read_text()
    def test_only_valid_expired_or_absent_move_is_free(self):
        helper=self.s.split('private _actorMoveFree={',1)[1].split('private _releaseOwnedHold=',1)[0]
        for guard in ('_move isEqualTo []','count _move == 3','(_move select 0) isEqualType ""',
                      'count (_move select 1) == 3','!finite _x','finite (_move select 2)',
                      '(_move select 2) <= time'):
            self.assertIn(guard,helper)
        for forbidden in ('doFollow','doMove','setVariable','lineIntersects','nearEntities'):
            self.assertNotIn(forbidden,helper)
    def test_old_hold_cannot_recall_a_live_successor(self):
        hold=self.s.split('private _releaseOwnedHold={',1)[1].split('private _supportHeld=',1)[0]
        self.assertIn('&& {[_unit] call _actorMoveFree}',hold)
        self.assertLess(hold.index('call _actorMoveFree'),hold.index('_unit doFollow _leader'))
        self.assertIn('!_yieldToExternal',hold)
    def test_generic_loop_preserves_live_proof_and_leaves_owned_release_to_features(self):
        generic=self.s.split('private _target = _x getVariable',1)[1].split('private _staticSupport=',1)[0]
        self.assertIn('if ([_x] call _actorMoveFree) then {_x setVariable ["CBE_Cortex_ActorMove",nil]}',generic)
        # Existing deployment cleanup must still remove its own tag, independently.
        self.assertIn('(_deployMove param [0,""]) in ["STATIC_DEPLOY","STATIC_PACK"]',self.s)
        self.assertIn('(_assistantMove param [0,""]) in ["STATIC_DEPLOY","STATIC_PACK"]',self.s)

class OperationReservationTests(unittest.TestCase):
    def test_shared_progress_and_recovery_use_strict_actor_reservation(self):
        for relative in ('addons/core/functions/operationStep.sqf','addons/infantry/functions/recoveryStep.sqf'):
            source=(ROOT/relative).read_text()
            self.assertIn('call CBE_fnc_CortexActorMoveReserved',source)
            self.assertNotIn('_move select 2',source)

    def test_suspended_recovery_retires_observation_without_spending_or_quarantine(self):
        source=(ROOT/'addons/core/functions/operationStep.sqf').read_text()
        suspended=source.split('private _suspended=',1)[1].split('if (_reserved',1)[0]
        for guard in ('simulationEnabled _actor','isObjectHidden _actor','checkAIFeature "MOVE"','checkAIFeature "PATH"'):
            self.assertIn(guard,suspended)
        retire=source.split('if (_reserved || {_nativeTask} || {_suspended}) then {',1)[1].split('if (!_reserved',1)[0]
        self.assertIn('_recovery deleteAt _key',retire)
        self.assertIn('_temporarilyOwned pushBack _actor',retire)
        self.assertNotIn('_unavailable pushBack',retire)
        self.assertNotIn('set ["recoveryAttempts"',retire)
        self.assertIn('!_suspended',source)

    def test_recovery_rechecks_live_budget_and_authority_in_command_transaction(self):
        source=(ROOT/'addons/infantry/functions/recoveryStep.sqf').read_text()
        self.assertIn('!finite _x',source.split('// This is the final direct movement',1)[0])
        boundary=source.split('isNil {',1)[1]
        for guard in ('!local _group','!local _actor','checkAIFeature "MOVE"','checkAIFeature "PATH"',
                      'call CBE_fnc_CortexExternalTakeover','if (call _reserved)',
                      'simulationEnabled _actor','getOrDefault ["generation",-2]',
                      '_used=_currentOperation getOrDefault ["recoveryAttempts",createHashMap]'):
            self.assertLess(boundary.index(guard),boundary.index('_used set [_key,_attempts+1]'))
        self.assertLess(boundary.index('if (_attempts >= 1)'),boundary.index('_actor doMove _destination'))
        self.assertEqual(boundary.count('_actor doMove _destination'),1)
        self.assertNotIn('setDestination',boundary)
        suspended=boundary.split('if (!(_actor checkAIFeature "MOVE")',1)[1].split('// Another callback',1)[0]
        self.assertIn('exitWith {"YIELDED"}',suspended)
        self.assertNotIn('exitWith {"INVALID"}',suspended)

class OperationIncapacitationTests(unittest.TestCase):
    def test_ineligible_recovery_observations_retire_before_timeout_without_new_budget(self):
        source=(ROOT/'addons/core/functions/operationStep.sqf').read_text()
        prune=source.split('// An actor excluded before the recovery loop',1)[1].split('private _actor=_x;',1)[0]
        self.assertIn('if (count _recovery > 0)',prune)
        self.assertIn('_originalParticipants apply {[netId _x,true]}',prune)
        self.assertIn('!(_x in _eligibleRecoveryKeys)',prune)
        self.assertIn('_recovery deleteAt _x',prune)
        self.assertIn('_recoveryChanged=true',prune)
        for forbidden in ('setVariable','set ["recoveryAttempts"','_unavailable pushBack',
                          'lastProgressAt','deadline','doMove','doFollow','nearEntities','allUnits'):
            self.assertNotIn(forbidden,prune)
        self.assertLess(source.index('private _eligibleRecoveryKeys='),source.index('time-_startedAt >= _staleSeconds'))
        self.assertIn('_updated pushBack [_participant,getPosATL _participant]',source)

class OperationProgressDomainTests(unittest.TestCase):
    def test_foot_and_mounted_progress_are_bound_at_commitment(self):
        start=(ROOT/'addons/core/functions/operationStart.sqf').read_text()
        self.assertIn('"participantPlatforms",createHashMapFromArray (_capable apply {[netId _x,vehicle _x]})',start)
        self.assertIn('"progressPlatform",vehicle _operationAnchor',start)
        self.assertIn('"progressOnFoot",_dangerPosture',start)
        step=(ROOT/'addons/core/functions/operationStep.sqf').read_text()
        eligible=step.split('private _originalParticipants=',1)[1].split('// A recovery order',1)[0]
        self.assertIn('_platforms getOrDefault [netId _x,[objNull,_x] select _legacyFoot]',eligible)
        self.assertIn('!isNull _platform',eligible)
        self.assertIn('vehicle _x == _platform',eligible)
        fallback=step.split('if (_participants isEqualTo [] && {!_participantsRequired})',1)[1].split('if (_progressed)',1)[0]
        self.assertIn('vehicle _leader == _leader',fallback)
        self.assertIn('vehicle _leader == _platform',fallback)
        self.assertIn('if (_sameDomain',fallback)
        self.assertNotIn('set ["progressPlatform"',step)
        self.assertNotIn('set ["participantPlatforms"',step)

    def test_all_roster_mutations_enroll_platforms_without_forgiving_existing_ones(self):
        for name in ('buildingOperationStep.sqf','cortexClearBuilding.sqf','rebalanceRoles.sqf'):
            source=(ROOT/'addons/infantry/functions'/name).read_text()
            self.assertIn('set ["participantPlatforms"',source)
        rebalance=(ROOT/'addons/infantry/functions/rebalanceRoles.sqf').read_text()
        self.assertIn('call CBE_fnc_CortexActorMoveReserved',rebalance)
        self.assertIn('_platforms getOrDefault [netId _x,_x]',rebalance)
        self.assertNotIn('_reservation param [2',rebalance)


class CoordinationReservationTests(unittest.TestCase):
    def test_server_does_not_expire_remote_or_malformed_actor_reservations(self):
        source=(ROOT/'addons/support/functions/cortexSupportCoordinateStep.sqf').read_text()
        admission=source.split('_fit=_fit select {',1)[1].split('if (count _fit >= 3',1)[0]
        self.assertIn('private _free=if (local _x) then {',admission)
        self.assertIn('!([_x] call CBE_fnc_CortexActorMoveReserved)',admission)
        remote=admission.split('} else {',1)[1].split('};',1)[0]
        self.assertEqual(remote.strip(),'_reservation isEqualTo []')
        self.assertNotIn('<= time',admission)
        self.assertNotIn('setVariable',admission)
        self.assertIn('currentCommand _x',admission)


class ManoeuvreBuddyReliefTests(unittest.TestCase):
    def test_relief_keeps_pairs_only_when_donor_cover_survives(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        helper=source.split('private _selectRelief={',1)[1].split('private _rankCandidates=',1)[0]
        self.assertIn('count _donors <= _keep',helper)
        self.assertIn('!(_x in _donors) || {_x in _paired}',helper)
        self.assertIn('(_x select 0) != (_x select 1)',helper)
        self.assertLess(helper.index('if (_orphan >= 0)'),helper.index('count _donors-_keep >= 2'))
        self.assertIn('+(_intact select 0)',helper)
        for forbidden in ['doMove','doFollow','setVariable','nearEntities']:
            self.assertNotIn(forbidden,helper)
        self.assertIn('forEach ([_second,2] call _selectRelief)',source)
        self.assertIn('forEach ([_first,2] call _selectRelief)',source)
        self.assertIn('private _relief=[_coverAvailable,1] call _selectRelief;',source)
        self.assertIn('_relief apply {[format ["TEAM_%1_RECOVERY",_turn+1],netId _x]}',source)
        self.assertIn('"RECOVERY_REINFORCEMENT"',source)


class SupportBoundCommitTests(unittest.TestCase):
    def test_current_role_owner_and_actor_checks_share_allocation_transaction(self):
        source=(ROOT/'addons/support/functions/cortexSupportBoundStart.sqf').read_text()
        boundary=source.split('isNil {',1)[1].rsplit('};',1)[0]
        allocation=boundary.index('_state set ["drill",')
        for guard in ['_state isNotEqualTo (_group getVariable ["CBE_AIPass_State",createHashMap])',
                      'CBE_AIPass_Enable','CBE_AIPass_Active','CBE_fnc_CortexIsPaused',
                      'CBE_AIPass_CoordinatedAssault_Enable','!local _group',
                      'CBE_fnc_CortexExternalTakeover','_role isNotEqualTo',
                      'serverTime >= (_lease select 2)','"ownerEpoch",-1',
                      '"phase",""]) == "CANCELLED"','CBE_fnc_CortexActorMoveReserved']:
            self.assertLess(boundary.index(guard),allocation)
        self.assertIn('CBE_fnc_CortexDrillStart',boundary)
        self.assertLess(boundary.index('CBE_fnc_CortexDrillStart'),boundary.index('_accepted=true;'))
        self.assertTrue(source.rstrip().endswith('_accepted'))
        self.assertNotIn('sleep ',boundary)
        self.assertNotIn('nearEntities',boundary)


class CoordinationLeaseReplacementTests(unittest.TestCase):
    def test_old_group_token_cannot_delay_or_publish_over_successor(self):
        source=(ROOT/'addons/support/functions/cortexSupportCoordinateStep.sqf').read_text()
        active=source.split('private _stillActive=[];',1)[1].split('} forEach _active;',1)[0]
        self.assertIn('isNil {',active)
        exact='_teams findIf {(_x select 0) == _group && {(_x select 1) == _token}} < 0'
        self.assertLess(active.index(exact),active.index('CBE_Cortex_SupportBoundResult'))
        self.assertLess(active.index('call _sameLease'),active.index('CBE_Cortex_SupportRetryAfter'))
        self.assertLess(active.index('call _sameLease'),active.index('_stillActive pushBack _x'))
        helper=source.split('private _sameLease={',1)[1].split('private _teams=[];',1)[0]
        for guard in ['isNull _group','count _lease == 6','(_lease select 0) == _token','serverTime < (_lease select 2)']:
            self.assertIn(guard,helper)
        publication=source.split('// Compare the live role here:',1)[1].split('} forEach _teams;',1)[0]
        self.assertIn('(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _role',publication)
        self.assertEqual(source.count('if !([_group,_token] call _sameLease) exitWith {};'),3)


class SharedRoutineReservationTests(unittest.TestCase):
    def test_manoeuvre_cleanup_and_medical_use_strict_owner_predicate(self):
        for name in ['cortexFlankStep','cortexFlankEnd','cortexMedicalStep','cortexStance']:
            with self.subTest(name=name):
                source=(ROOT/f'addons/infantry/functions/{name}.sqf').read_text()
                self.assertIn('call CBE_fnc_CortexActorMoveReserved',source)
                self.assertNotIn('_reservation param [2,1e12',source)
        medical=(ROOT/'addons/infantry/functions/cortexMedicalStep.sqf').read_text()
        self.assertEqual(medical.count('call CBE_fnc_CortexActorMoveReserved'),2)
        self.assertIn('"ACTOR_TASK_CHANGED"',medical)
        self.assertIn('"CARRY SOLDIER"',medical)

    def test_stance_known_task_release_refuses_unknown_shapes_before_token_read(self):
        source=(ROOT/'addons/infantry/functions/cortexStance.sqf').read_text()
        shape=source.split('private _knownReservation=',1)[1].split('if (!_reservationFree',1)[0]
        for guard in ['_reservation isEqualType []','count _reservation == 3',
                      '(_reservation select 0) isEqualType ""','count (_reservation select 1) == 3',
                      '!finite _x','finite (_reservation select 2)']:
            self.assertIn(guard,shape)
        release=source.split('if (!_reservationFree',1)[1].split('_changed=_changed+1;',1)[0]
        self.assertLess(release.index('_knownReservation'),release.index('_reservation select 0'))
        self.assertIn('_currentStance ==',release)
        self.assertIn('CBE_fnc_CortexExternalTakeover',release)


class ManoeuvreRosterCommitTests(unittest.TestCase):
    def test_refill_proposals_publish_only_in_current_snapshot_boundary(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        proposal=source.split('private _entryTeams=',1)[1].split('private _rosterCommitted=false;',1)[0]
        self.assertNotIn('_drill set ["teams",',proposal)
        self.assertNotIn('_drill set ["units",',proposal)
        self.assertIn('private _teams=_entryTeams apply {+_x}',proposal)
        commit=source.split('private _rosterCommitted=false;',1)[1].split('if (!_rosterCommitted)',1)[0]
        allocation=commit.index('_drill set ["teams",')
        for guard in ['isNil {','!local _group','_rosterEpoch !=','_liveState isNotEqualTo _state',
                      '"token",""]) != _token','isNotEqualTo _entryTeams','isNotEqualTo _entryUnits',
                      'isNotEqualTo _entryPhase','CBE_fnc_CortexIsPaused','CBE_fnc_CortexExternalTakeover',
                      '_liveState getOrDefault ["assaulting",false]','_liveState getOrDefault ["phase",""]) != "CONTACT"',
                      'isNotEqualTo _supportRole','"generation",-2','"ownerEpoch",-1',
                      '"phase",""]) == "CANCELLED"','isNotEqualTo _unavailable',
                      'call _actorTaskFree','currentCommand _actor != _command',
                      'isNotEqualTo _destination','formLeader _actor != _leader']:
            self.assertLess(commit.index(guard),allocation)
        self.assertIn('CBE_fnc_RebalanceRoles',commit)
        self.assertIn('CBE_Cortex_DrillReinforcements',commit)
        self.assertIn('"CASUALTY_REINFORCEMENT"',commit)
        self.assertIn('if (!_rosterCommitted) exitWith {0.25}',source)
        refusal=source.split('if (!_rosterCommitted)',1)[1].split('// Two ordinary survivors',1)[0]
        self.assertNotIn('call _end',refusal)
        self.assertNotIn('setVariable',refusal)


class ManoeuvreMovementCommitTests(unittest.TestCase):
    def test_bound_geometry_precedes_atomic_native_writes_and_journals(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        issue=source.split('private _issue = {',1)[1].split('private _result = 1.5;',1)[0]
        planning,commit=issue.split('private _issued=false;',1)
        self.assertIn('CBE_fnc_CortexFindCover',planning)
        self.assertLess(planning.index('_point=+_point;'),planning.index('CBE_fnc_CortexFindCover'))
        self.assertNotIn('doMove',planning)
        self.assertNotIn('doStop',planning)
        self.assertNotIn('setUnitPos',planning)
        writer=commit.index('_unit doMove _spot;')
        for guard in ['isNil {','!local _group','_issueEpoch !=','_liveState isNotEqualTo _state',
                      '"token",""]) != _token','isNotEqualTo _issuePhase','isNotEqualTo _issueTeams',
                      'isNotEqualTo _issueUnits','isNotEqualTo [_point,_kind]',
                      'CBE_fnc_CortexIsPaused','isNotEqualTo _supportRole','CBE_fnc_CortexExternalTakeover',
                      '"generation",-2','"ownerEpoch",-1','"phase",""]) == "CANCELLED"',
                      'currentCommand _actor != _command','isNotEqualTo _destination',
                      'formLeader _actor != _leader']:
            self.assertLess(commit.index(guard),writer)
        for journal in ['_drill set ["spots", _spots]','_drill set ["movers", +_units]',
                        'CBE_Cortex_DrillMovementHandoffs','"BOUND_%1_ISSUED"']:
            self.assertLess(commit.index(journal),commit.index('_issued=true;'))
        self.assertNotIn('CBE_fnc_CortexFindCover',commit)
        self.assertIn('if (!_issued) then {_result=0.25}',commit)


class DrillChildIdentityTests(unittest.TestCase):
    def test_old_finite_callback_carries_immutable_cleanup_token(self):
        step=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        self.assertIn('[_group, _state, _this, _token] call CBE_fnc_CortexFlankEnd',step)
        interrupt=(ROOT/'addons/infantry/functions/cortexDrillInterrupt.sqf').read_text()
        self.assertTrue(interrupt.rstrip().endswith('[_group,_state,_reason,_token] call CBE_fnc_CortexFlankEnd'))
        end=(ROOT/'addons/infantry/functions/cortexFlankEnd.sqf').read_text()
        self.assertIn('["_expectedToken","",[""]]',end)
        firstwrite=end.index('_group setCombatMode')
        self.assertLess(end.index('(_drill getOrDefault ["token",""]) != _expectedToken'),firstwrite)
        self.assertLess(end.index('(_liveDrill getOrDefault ["token",""]) != _expectedToken'),firstwrite)
        self.assertTrue(end.rstrip().endswith('_retired'))
        terminal=end.split('private _retired=false;',1)[1]
        self.assertIn('isNil {',terminal)
        self.assertLess(terminal.index('call _stillEnding'),terminal.index('_state deleteAt "drill"'))
        self.assertLess(terminal.index('call _stillEnding'),terminal.index('CBE_Cortex_DrillResult'))
        self.assertIn('_retired=true;',terminal)
        feedback=end.split('if (_supportToken != "") then {',1)[0]
        self.assertIn('if !(call _stillEnding) exitWith {};',feedback)

    def test_stage_and_history_require_current_child_inside_one_transaction(self):
        source=(ROOT/'addons/infantry/functions/cortexDrillSetStage.sqf').read_text()
        commit=source.split('isNil {',1)[1].rsplit('};',1)[0]
        write=commit.index('_drill set ["stage",_next]')
        for guard in ['!local _group','(_currentDrill getOrDefault ["token",""]) != _token',
                      'CBE_OperationGeneration','CBE_AIPass_Epoch']:
            self.assertLess(commit.index(guard),write)
        self.assertIn('CBE_Cortex_DrillTransitions',commit)
        self.assertLess(commit.index('CBE_Cortex_DrillTransitions'),commit.index('_changed=true;'))
        self.assertTrue(source.rstrip().endswith('_changed'))


class DrillRestorationCommitTests(unittest.TestCase):
    def test_restoration_and_formation_writes_share_exact_current_context(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankEnd.sqf').read_text()
        helper=source.split('private _stillEnding={',1)[1].split('private _supportToken=',1)[0]
        for guard in ['local _group','_currentState isEqualTo _state','_endingEpoch ==',
                      '_endingGeneration ==','"token",""]) == _endingToken']:
            self.assertIn(guard,helper)
        block=source.split('private _restorationDone=false;',1)[1].split('if (!_restorationDone)',1)[0]
        admission=block.index('if !(call _stillEnding) exitWith {};')
        for write in ['_group setCombatMode','_group setSpeedMode','_unit enableAI _feature',
                      '_unit setUnitCombatMode','removeEventHandler','doStop _x',
                      '_x doFollow','CBE_Cortex_SupportBoundResult']:
            self.assertLess(admission,block.index(write))
            self.assertLess(block.index(write),block.index('_restorationDone=true;'))
        for forbidden in ['CBE_fnc_OperationCancel','CBE_fnc_OperationRelease','nearEntities','lineIntersects','sleep ']:
            self.assertNotIn(forbidden,block)
        self.assertIn('if (!_restorationDone) exitWith {false};',source)


class ManoeuvreFloorProgressTests(unittest.TestCase):
    def test_arrival_and_motion_keep_vertical_domain(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        self.assertIn('private _remaining = _pose vectorDistance _targetASL;',source)
        self.assertIn('abs ((_pose select 2)-(_targetASL select 2)) <= 1.5',source)
        self.assertIn('_pose vectorDistance (_last select 2) >= 0.5',source)
        upgrade=source.split('// Legacy live records used ATL',1)[1].split('private _retries =',1)[0]
        self.assertIn('ATLToASL (_x select 2)',upgrade)
        self.assertIn('_x set [0,_pose vectorDistance',upgrade)
        for forbidden in ['set [1,','set [3,','boundDeadline','doMove','setPos']:
            self.assertNotIn(forbidden,upgrade)

    def test_recovery_chooses_actual_peer_not_between_floor_centroid(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        recovery=source.split("// Rejoin this actor's element",1)[1].split('private _recoveryResult=',1)[0]
        self.assertIn('_x != _actor && {_x in _peers}',recovery)
        self.assertIn('forEach _buddyPairs',recovery)
        self.assertIn('_rally=getPosATL _buddy;',recovery)
        self.assertIn('(getPosASL _actor) vectorDistance (getPosASL _x)',recovery)
        self.assertIn('(_rallyASL select 2)) <= 1.5',recovery)
        self.assertNotIn('vectorMultiply (1/count _peers)',recovery)
