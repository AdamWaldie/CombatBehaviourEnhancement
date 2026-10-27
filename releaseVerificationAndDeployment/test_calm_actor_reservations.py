"""Generic calm cleanup must not erase or recall another finite actor task."""
from pathlib import Path
import unittest
import re
ROOT=Path(__file__).resolve().parents[1]
class CalmActorReservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s=(ROOT/'addons/infantry/functions/cortexRestoreCalm.sqf').read_text()
    def test_only_valid_expired_or_absent_move_is_free(self):
        helper=self.s.split('private _actorMoveFree={',1)[1].split('private _releaseOwnedHold=',1)[0]
        self.assertIn('!([_actor] call CBE_fnc_CortexActorMoveReserved)',helper)
        shared=(ROOT/'addons/infantry/functions/cortexActorMoveReserved.sqf').read_text()
        for guard in ('CBE_Danger_FlightLease','CBE_Cortex_NavalEgressMove',
                      'count _lease == 3','count (_lease select 1) == 3',
                      '!finite _x','finite (_lease select 2)'):
            self.assertIn(guard,shared)
        # Pending native cleanup is checked before the empty ordinary-marker shortcut.
        for journal in ('CBE_Danger_FlightLease','CBE_Cortex_NavalEgressMove'):
            self.assertLess(shared.index(journal),shared.index('if (_lease isEqualTo [])'))
        for forbidden in ('doFollow','doMove','setVariable','lineIntersects','nearEntities'):
            self.assertNotIn(forbidden,helper)
    def test_old_hold_cannot_recall_a_live_successor(self):
        hold=self.s.split('private _releaseOwnedHold={',1)[1].split('private _supportHeld=',1)[0]
        self.assertIn('&& {[_unit] call _actorMoveFree}',hold)
        self.assertLess(hold.index('call _actorMoveFree'),hold.index('_unit doFollow _leader'))
        self.assertIn('!_yieldToExternal',hold)
    def test_generic_loop_preserves_live_proof_and_leaves_owned_release_to_features(self):
        generic=self.s.split('private _target = _x getVariable',1)[1].split('// Use the same exact-assignment release',1)[0]
        self.assertIn('if ([_x] call _actorMoveFree) then {_x setVariable ["CBE_Cortex_ActorMove",nil]}',generic)
        # CALM delegates to the feature; its shared retirement still clears only static tags.
        self.assertIn('[_group,_state,[],false,true,_yieldToExternal] call CBE_fnc_CortexStaticDeployStep',self.s)
        deploy=(ROOT/'addons/infantry/functions/cortexStaticDeployStep.sqf').read_text()
        clear=deploy.split('private _clearActor=',1)[1].split('private _canReleaseActor=',1)[0]
        self.assertIn('call _ownsActorMove',clear)
        self.assertIn('(_receipt select 2) == (_record param [27,-1,[0]])',clear)
        self.assertIn('[_gunner] call _clearActor',deploy)
        self.assertIn('[_assistant] call _clearActor',deploy)

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
        self.assertIn('currentCommand _actor != "STOP" || {_actor in _entryParticipants}',rebalance)
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
        for gate in ('count _fireReady < 2','CBE_fnc_CortexPrimaryAmmoAvailable',
                     'unitCombatMode _x in ["YELLOW","RED"]','checkAIFeature "FIREWEAPON"',
                     '(_fireReady-_x) isNotEqualTo []','_x in _fireReady'):
            self.assertIn(gate,helper)
        # Dry headcount cannot replace the donor's last rifle, nor reinforce a mover.
        donors={'a','b','dry1','dry2'};armed={'a','b'}
        def feasible(relief):
            return len(donors-set(relief))>=2 and bool(armed&set(relief)) and bool(armed-set(relief))
        self.assertIn('in ["CROSS_FAR","CONSOLIDATE"]',helper)
        self.assertIn('if (_exitLeg) then {+_donors} else',helper)
        self.assertFalse(feasible({'a','b'}))
        self.assertFalse(feasible({'dry1'}))
        self.assertTrue(feasible({'a','dry1'}))
        self.assertTrue(feasible({'b'}))
        for forbidden in ['doMove','doFollow','setVariable','nearEntities']:
            self.assertNotIn(forbidden,helper)
        candidates=source.split('private _rankCandidates={',1)[1].split('private _units=[];',1)[0]
        self.assertIn('currentCommand _x != "STOP"',candidates)
        for gate in ('CortexPrimaryAmmoAvailable','unitCombatMode _x in ["YELLOW","RED"]',
                     'checkAIFeature "FIREWEAPON"','["CROSS_FAR","CONSOLIDATE"]'):
            self.assertIn(gate,candidates)
        self.assertIn('private _needsRefill=false',source)
        self.assertIn('if (_needsRefill) then',source)
        refill=source.split('private _units=[];',1)[1].split('// Candidate selection prepares',1)[0]
        self.assertEqual(refill.count('call CBE_fnc_CombatElementSelect'),2)
        self.assertEqual(refill.count('_candidates=_candidates-_relief'),2)
        self.assertIn('_vacancies,1,_team select [0,16]',refill)
        self.assertIn('_vacancies,1,_units select [0,16]',refill)
        self.assertIn('private _teamIndex=_forEachIndex',refill)
        self.assertNotIn('_candidates deleteAt 0',refill)
        self.assertIn('forEach ([_second,2] call _selectRelief)',source)
        self.assertIn('forEach ([_first,2] call _selectRelief)',source)
        self.assertIn('private _relief=[_coverAvailable,1] call _selectRelief;',source)
        transfer=source.split('private _relief=[_coverAvailable,1] call _selectRelief;',1)[1]
        self.assertLess(transfer.index('if (_relief isEqualTo []) exitWith {}'),
                        transfer.index('_coverAvailable deleteAt'))
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
        self.assertIn('CBE_Cortex_SupportRoleDeadline',boundary)
        self.assertIn('serverTime >= (_deadlineReceipt select 2)',boundary)
        self.assertIn('["supportDeadline",_deadlineReceipt select 2],["supportClock",+_deadlineReceipt]',boundary)
        coordinate=(ROOT/'addons/support/functions/cortexSupportCoordinateStep.sqf').read_text()
        self.assertIn('(_record select 2) min (_leaseNow select 2)',coordinate)
        self.assertLess(coordinate.index('setVariable ["CBE_Cortex_SupportRoleDeadline",_roleDeadline,true]'),
                        coordinate.index('setVariable ["CBE_Cortex_SupportRole",_role,true]'))
        active=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        self.assertLess(active.index('call CBE_fnc_OperationStep'),active.index('private _supportExpired='))
        self.assertLess(active.index('private _supportExpired='),active.index('call CBE_fnc_OperationAttackPolicy'))
        self.assertIn('if (_supportExpired) exitWith {"TIME_LIMIT" call _end}',active)
        self.assertIn('if (_supportAwaitClock) exitWith {_drill set ["lastStep",time];0.25}',active)

        self.assertIn('_accepted=[_group,_token] call CBE_fnc_CortexDrillStart;',boundary)
        completed=boundary.split('if (_completedTurns == 2) exitWith {',1)[1].split('};',1)[0]
        self.assertIn('_accepted=true;',completed)
        self.assertNotIn('doMove',completed)
        self.assertNotIn('CortexDrillStart',completed)
        self.assertEqual(boundary.count('_accepted=true;'),1)
        self.assertIn('CBE_fnc_CortexSupportStopOwned',boundary)
        self.assertIn('["nativeAdmissionChecked",true],["nativeCommands",_nativeCommands]',boundary)
        self.assertIn('[_x,"HOLD",+(expectedDestination _x),formLeader _x,-1,[],[]]',boundary)
        self.assertLess(boundary.index('_transferredHolds deleteAt'),boundary.index('_accepted=[_group,_token]'))
        owned=(ROOT/'addons/support/functions/cortexSupportStopOwned.sqf').read_text()
        for proof in ('!local _holdGroup','!local _holdActor','CBE_OperationGeneration',
                      'CBE_AIPass_Epoch','serverTime >= _holdExpiry','count _holds > 64',
                      'isEqualTo [','expectedDestination _holdActor,formLeader _holdActor,_holdExpiry'):
            self.assertIn(proof,owned)
        for forbidden in ('doMove','doStop','doFollow','setVariable','spawn','waitAndExecute'):
            self.assertNotIn(forbidden,owned)

        self.assertTrue(source.rstrip().endswith('_accepted'))
        maintain=(ROOT/'addons/support/functions/cortexSupportMaintain.sqf').read_text()
        cover=maintain.split('private _coverIdentity=',1)[1]
        self.assertLess(cover.index('call CBE_fnc_CortexSupportStopOwned'),cover.index('doStop _x'))
        apply=(ROOT/'addons/support/functions/cortexSupportApply.sqf').read_text()
        self.assertIn('_adoptedOrder isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',apply)
        self.assertLess(apply.index('&& {_adoptOrderCurrent}'),apply.index('call CBE_fnc_OperationStart'))
        self.assertIn('if (_adopting) then {+_adoptedOrder}',apply)
        checkpoint=(ROOT/'addons/infantry/functions/cortexCheckpoint.sqf').read_text()
        self.assertIn('"supportHoldProof"',checkpoint)
        self.assertIn('if (!_proofOverflow)',checkpoint)
        self.assertIn('(_row select 1) == "HOLD"',checkpoint)
        self.assertIn('(_holdProof select 1) isEqualTo (_group getVariable ["CBE_OperationGeneration",-1])',apply)
        self.assertIn('if (_recoveryValid && {_adoptionUntil == -1}) then {_adoptionUntil=(serverTime+5) min _expiry}',apply)
        duplicate=apply.split('// Repeated adoption delivery',1)[1].split('if (_okay && {_replaceLocalDrill})',1)[0]
        self.assertNotIn('OperationStart',duplicate)
        self.assertNotIn('serverTime+',duplicate)
        adoption=maintain.split('// Consume passive holds',1)[1].split('// Contact can begin',1)[0]
        for proof in ('count _adoption == 5','serverTime < (_adoption select 2)',
                      '(_adoption select 3) == (_lease select 2)','_remainingHolds pushBack _x',
                      'currentCommand _heldActor == (["STOP","MOVE"] select _isMove)','CortexActorMoveReserved',
                      '(expectedDestination _heldActor) isEqualTo _heldNative',
                      'formLeader _heldActor == _heldLeader','_pendingHolds set [4,_remainingHolds]'):
            self.assertIn(proof,adoption)
        for forbidden in ('doStop','doMove','doFollow','serverTime+','spawn','waitAndExecute'):
            self.assertNotIn(forbidden,adoption)

        self.assertIn('_state set ["supportAuthoredRevoked",true]',maintain)
        self.assertIn('_state set ["supportAuthoredRevokedToken",_revokedToken]',maintain)
        self.assertIn('getOrDefault ["supportAuthoredRevokedToken",""]) != _token',apply)
        self.assertIn('!(_job getOrDefault ["adopt",false]) || {_adopting}',apply)

        self.assertIn('getOrDefault ["authoredRevoked",false]',apply)
        self.assertIn('_state set ["supportAuthoredRevoked",false]',apply)
        self.assertLess(apply.index('if (!_recoveryValid) exitWith'),apply.index('call CBE_fnc_OperationStart'))
        self.assertIn('_operation set ["supportToken",_token]',apply)
        self.assertIn('_operation set ["unavailable",+(_sourceRecovery select 4)]',apply)
        self.assertIn('_operation set ["recoveryAttempts",_sourceAttempts]',apply)
        self.assertIn('count _sourceAttempts == count (_sourceRecovery select 5)',apply)
        self.assertIn('_operation set ["supportExpiry",_expiry]',apply)
        self.assertIn('_operation set ["boundRetryAttempts",_sourceBoundAttempts]',apply)
        self.assertIn('_operation set ["boundProgress",_sourceBoundProgress]',apply)
        self.assertIn('_adoptionUntil=_sourceRecovery select 8',apply)
        self.assertIn('_adoptionUntil,_expiry,_sourceHoldRows',apply)
        carry=checkpoint.split('private _carryNative=',1)[1].split('private _childHolds=',1)[0]
        self.assertIn('serverTime < _adoptionUntil',carry)
        self.assertIn('_pending select [0,4]',carry)
        self.assertNotIn('serverTime+',carry)
        self.assertNotIn('doMove',carry)

        self.assertIn('["teamTurn",_completedTurns]',source)
        self.assertIn('(_progress select 0) > _sequence',source)
        self.assertIn('_second append _newcomers',source)
        self.assertIn('currentCommand _x != "MOVE"} || {[_x] call _moveOwned}',source)
        self.assertIn('(_row select 4) == _sequence',source)
        self.assertIn('(_row select 5) == _completedTurns',source)
        self.assertIn('["resumeNativeMoves",_resumeMoves]',source)
        inherited=active.split('if (!_continueNative) then {',1)[1].split('};',1)[0]
        keep=active.split('private _continueNative=',1)[1].split('if (!_continueNative)',1)[0]
        for proof in ('resumeNativeMoves','currentCommand _unit == "MOVE"',
                      '_nativeGoal vectorDistance _spot <= 0.25','call _nativeCommandAvailable'):
            self.assertIn(proof,keep)
        self.assertIn('_unit doMove _spot',inherited)
        self.assertIn('_distanceClock=time+((_savedProgress select 0) select 1)-serverTime',active)
        self.assertIn('_motionClock=time+((_savedProgress select 0) select 2)-serverTime',active)
        self.assertIn('count _x in [3,10]',adoption)
        self.assertIn('(_nativeProof select 5) in [0,1]',adoption)
        self.assertIn('(_nativeProof select 6) <= serverTime',adoption)
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text()
        self.assertIn('if (!_coordinatedMove && {_inheritedDrill isEqualTo []}',locality)
        self.assertIn('(_supportProof select 1) == (_inheritedSupportRecovery select 1)',locality)
        self.assertIn('(expectedDestination _unit) isEqualTo (_x select 1)',locality)


        stages=(ROOT/'addons/infantry/functions/cortexDrillSetStage.sqf').read_text()
        self.assertIn('_reason in ["FIRE_TEAM_ARRIVED","BOUND_ARRIVED"]',stages)
        self.assertIn('(_progress select 3) max ((_drill get "teamTurn")+1)',stages)
        self.assertIn('count _sourceRecovery == 9',apply)
        self.assertIn('count _sourceBoundAttempts == count (_sourceRecovery select 6)',apply)
        retry=active.split('private _supportRetryAvailable=',1)[1].split('private _nativeCommandAvailable=',1)[0]
        self.assertIn('count _budget > 64',retry)
        self.assertIn('(_used select 0) < (_drill get "supportSequence")',retry)
        self.assertIn('(_used select 0) == (_drill get "supportSequence")',retry)
        issue=active.split('_x params ["_action","_unit","_slot"];',1)[1].split('} forEach _moveActions',1)[0]
        self.assertLess(issue.index('_liveOperation set ["boundRetryAttempts",_budget]'),issue.index('_unit doMove'))
        self.assertIn('_budget set [netId _unit,[_drill get "supportSequence",1]]',issue)

        self.assertIn('count (_sourceRecovery select 5) <= 64',apply)


        self.assertIn('private _mayRestoreGroup=!_externalTakeover && {!_authoredReplaced}',maintain)
        self.assertLess(maintain.index('if (_authoredReplaced) exitWith'),maintain.index('private _role='))
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text()
        self.assertIn('["authoredOrder",_restore getOrDefault ["supportAuthoredOrder",[]]]',locality)
        self.assertIn('getOrDefault ["supportAuthoredRevokedToken",""]',locality)
        self.assertLess(locality.index('_inheritedSupportRecovery=['),locality.index('call CBE_fnc_OperationCancel'))
        self.assertIn('["recoveryProof",_inheritedSupportRecovery]',locality)
        self.assertIn('(_previousOperation getOrDefault ["supportToken",""]) == (_supportLease select 0)',locality)

        self.assertLess(locality.index('set ["supportAuthoredRevokedToken",_revokedSupportToken]'),
                        locality.index('call CBE_fnc_CortexSupportApply'))


        cleanup=maintain.split('private _releaseStopHolds={',1)[1].split('private _releaseSupport={',1)[0]
        for proof in ('isNil {','supportStopHolds','count _holds > 64','(_row select 1) == _token',
                      'CBE_OperationGeneration','CBE_AIPass_Epoch','CortexExternalTakeover',
                      'CortexActorMoveReserved','expectedDestination _actor','formLeader _actor'):
            self.assertLess(cleanup.index(proof),cleanup.index('_actor doFollow _returnLeader'))
        for proof in ('private _returnLeader=leader _group','!isNull _returnLeader','group _returnLeader == _group',
                      '[_returnLeader] call CBE_fnc_CortexCombatEffective','if (_leaderReady &&'):
            self.assertLess(cleanup.index(proof),cleanup.index('_actor doFollow _returnLeader'))
        self.assertLess(cleanup.index('_actor doFollow _returnLeader'),cleanup.index('_holds deleteAt _x'))
        self.assertNotIn('enableAI',cleanup)
        for proof in ('(_expiry+30)','serverTime >= (_cleanup select 3)','(_cleanup select 4) >= 64',
                      '_dueKeys=[_keys select','_deadline min (_previous select 3)',
                      'UNRESOLVED_OR_SUPERSEDED','NO_MATCHING_HOLDS'):
            self.assertIn(proof,cleanup)
        brain=(ROOT/'addons/infantry/functions/groupBrainStep.sqf').read_text()
        self.assertIn('[_group,_supportCleanupState,"PENDING"] call CBE_fnc_CortexSupportMaintain',brain)
        self.assertIn('supportStopCleanup',brain)
        self.assertIn('_mode in ["MAINTAIN","PENDING","RELEASE"]',maintain)
        release_only=maintain.index('if (_mode == "RELEASE") exitWith')
        self.assertLess(release_only,maintain.index('// The cached operation step'))
        calm=(ROOT/'addons/infantry/functions/cortexRestoreCalm.sqf').read_text()
        handback=calm.split('// Finish exact coordinated native holds',1)[1].split('// Generic engagement cleanup',1)[0]
        for proof in ('!_yieldToExternal','isEqualTo _state','supportToken','"RELEASE"'):
            self.assertIn(proof,handback)
        self.assertLess(calm.index('[_group,_state,"RELEASE"]'),calm.index('_state deleteAt "supportHeld"'))
        release=maintain.split('private _releaseSupport={',1)[1].split('// The cached operation step',1)[0]
        self.assertLess(release.index('call _releaseStopHolds'),release.index('CortexGroupMoveClear'))
        cover=maintain.split('private _stopHolds=',1)[1]
        self.assertLess(cover.index('doStop _x'),cover.index('_stopHolds set [netId _x'))
        self.assertIn('count _stopHolds < 64',cover)
        end=(ROOT/'addons/infantry/functions/cortexFlankEnd.sqf').read_text()
        failed=end.split('if (_holdFailedBound || {_holdCompletedSupport}) then {',1)[1].split('} else {',1)[0]
        self.assertIn('supportStopHolds',failed)
        self.assertIn('private _holdCompletedSupport=_hold && {_supportLeaseCurrent}',end)
        self.assertIn('_endingAuthored isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)',end)
        self.assertIn('&& {_authoredCurrent} && {[_group] call CBE_fnc_CortexIsEligible}',end)
        self.assertIn('private _holdOrder=+_endingAuthored;',end)

        self.assertIn('_members-_stragglers',failed)
        handover=end.split('// A role handover issues no native command.',1)[1].split('private _holdFailedBound=',1)[0]
        for proof in ('_reason == "ROLE_HANDOVER"','_supportLeaseCurrent','(_nextRole select 2) == "COVER"',
                      'currentCommand _x == "STOP"','_lease select 2','supportStopHolds'):
            self.assertIn(proof,handover)
        for forbidden in ('doStop','doMove','doFollow','serverTime+'):
            self.assertNotIn(forbidden,handover)

        self.assertLess(failed.index('doStop _x'),failed.index('_supportHolds set [netId _x'))
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
        drill=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        stop=drill.split('private _nativeCommandAvailable={',1)[1].split('private _actorTaskFree={',1)[0]
        for proof in ('_command in ["STOP","MOVE"]','count _row != 7','(_row select 0) != _actor',
                      'serverTime <= (_row select 4)','expectedDestination _actor','formLeader _actor'):
            self.assertIn(proof,stop)
        self.assertIn('[_actor] call _nativeCommandAvailable',drill)
        self.assertEqual(drill.count(',"HOLD"] call _recordNativeCommand'),2)
        self.assertIn('[_actor,"MOVE",_rally] call _recordNativeCommand',drill)
        self.assertIn('[_unit,"MOVE",_spot] call _recordNativeCommand',drill)
        self.assertIn('[_unit,"MOVE",_spots select _slot] call _recordNativeCommand',drill)
        self.assertIn('_position vectorDistance _goal <= 0.25',stop)
        recording=drill.split('private _recordNativeCommand={',1)[1].split('private _stopAvailable={',1)[0]
        self.assertIn('count _commands >= 64',recording)
        self.assertIn('serverTime+2',recording)
        medical=(ROOT/'addons/infantry/functions/cortexMedicalStep.sqf').read_text()
        self.assertEqual(medical.count('call CBE_fnc_CortexActorMoveReserved'),3)
        self.assertIn('"ACTOR_TASK_CHANGED"',medical)
        self.assertIn('"CARRY SOLDIER"',medical)

    def test_stance_known_task_release_refuses_unknown_shapes_before_token_read(self):
        source=(ROOT/'addons/infantry/functions/cortexStance.sqf').read_text()
        shape=source.split('private _knownReservation=',1)[1].split('private _nativePostureTask=',1)[0]
        for guard in ['_reservation isEqualType []','count _reservation == 3',
                      '(_reservation select 0) isEqualType ""','count (_reservation select 1) == 3',
                      '!finite _x','finite (_reservation select 2)']:
            self.assertIn(guard,shape)
        release=source.split('if ((_nativePostureTask',1)[1].split('_changed=_changed+1;',1)[0]
        self.assertIn('private _nativePostureTask=_reservationFree',source)
        self.assertIn('count _stanceReceipt == 4',release)
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
        stopped=source.split('private _ownsNativeMovement={',1)[1].split('// Listener cleanup above',1)[0]
        for proof in ('count _row != 7','(_row select 0) != _actor','(_row select 1) == "HOLD"',
                      'expectedDestination _actor','formLeader _actor'):
            self.assertIn(proof,stopped)
        self.assertIn('[_x] call _ownsNativeMovement',source)
        self.assertIn('_position vectorDistance _goal <= 0.25',stopped)
        self.assertNotIn('serverTime+',stopped)


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


class ManoeuvreArrivalRetryCommitTests(unittest.TestCase):
    def test_observations_and_retry_credit_commit_with_current_bound(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        move=source.split('case "MOVE": {',1)[1]
        observations,commit=move.split('private _moveCommitted=false;',1)
        self.assertIn('_entryMoveProgress apply',observations)
        self.assertIn('_entryMoveRetries apply',observations)
        for forbidden in ['doStop _unit','_unit doMove','_retry set [0,','_drill set ["progressCoordinates"']:
            self.assertNotIn(forbidden,observations)
        commit=commit.split('if (!_moveCommitted)',1)[0]
        writer=commit.index('doStop _unit')
        for guard in ['isNil {','_rosterEpoch !=','"token",""]) != _token',
                      '"stage",""]) != "MOVE"','isNotEqualTo _moveIdentity','isNotEqualTo _spots',
                      'isNotEqualTo _movers','isNotEqualTo _entryMoveProgress','isNotEqualTo _entryMoveRetries',
                      'isNotEqualTo _previousArrivals','isNotEqualTo _moveRoute',
                      'isNotEqualTo _supportRole','CBE_fnc_CortexExternalTakeover',
                      'currentCommand _actor != _command','isNotEqualTo _destination','!_atTarget',
                      '_arrivedUnits findIf','_pose vectorDistance _target > 3']:
            self.assertLess(commit.index(guard),writer)
        self.assertLess(commit.index('_unit doMove (_spots select _slot)'),commit.index('_retry set [0,'))
        for journal in ['_drill set ["progress",_progress]','_drill set ["retries",_retries]',
                        '_drill set ["arrivedUnits",_arrivedUnits]']:
            self.assertLess(commit.index(journal),commit.index('_moveCommitted=true;'))
        self.assertIn('if (!_moveCommitted) exitWith {_result=0.25}',move)


class ManoeuvreHelperCommitTests(unittest.TestCase):
    def test_helpers_share_current_context_and_refusal_defers_without_losses(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        helper=source.split('private _helperCurrent={',1)[1].split('// Two ordinary survivors',1)[0]
        for guard in ['local _group','_rosterEpoch ==','_currentState isEqualTo _state',
                      '"token",""]) == _token','CBE_fnc_CortexIsPaused','CBE_fnc_CortexFeatureEnabled',
                      'CBE_fnc_CortexExternalTakeover','isEqualTo _supportRole',
                      '"generation",-2','"ownerEpoch",-1','"phase",""]) != "CANCELLED"']:
            self.assertIn(guard,helper)
        team=source.split('private _ensureMovingTeam={',1)[1].split('if (_teams isNotEqualTo []) then {',1)[0]
        self.assertIn('isNil {',team)
        self.assertLess(team.index('call _helperCurrent'),team.index('_drill set ["teams",_teams]'))
        self.assertIn('_available findIf {!([_x] call _actorTaskFree)',team)
        self.assertIn('_turn != (_drill getOrDefault ["teamTurn",0])',team)
        self.assertIn('if (!_committed) then {_teamDeferred=true}',team)
        self.assertLess(source.index('if (_teamDeferred) exitWith {0.25}'),source.index('if (_teamRecoveryFailed)'))
        restore=source.split('private _restoreFeatures = {',1)[1].split('private _issue = {',1)[0]
        self.assertIn('isNil {',restore)
        for write in ['setCombatBehaviour','setUnitCombatMode','enableAI _feature','_drill set ["disabled"']:
            self.assertLess(restore.index('call _helperCurrent'),restore.index(write))
            self.assertLess(restore.index(write),restore.index('_restored=true;'))
        self.assertIn('if !([] call _restoreFeatures) exitWith {_result=0.25}',source)
        self.assertIn('if !(call _restoreFeatures) exitWith {_result=0.25}',source)
        self.assertIn('if (_teamDeferred) exitWith {_result=0.25}',source)


class ManoeuvreRetryObservationTests(unittest.TestCase):
    def test_admitted_retry_gets_observation_time_but_cannot_extend_deadline(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        planning=source.split('private _retry = _retries select _forEachIndex;',1)[1].split('private _moveCommitted=false;',1)[0]
        for guard in ['(_retry select 0) < 1','_now <= _moveDeadline','_retryPending=true;',
                      '_now-(_last select 3) > _timeout && {!_retryPending}',
                      '(_retry select 0) == 0 || {_now-(_retry select 1) >= 8}']:
            self.assertIn(guard,planning)
        self.assertNotIn('_last set [3,',planning)
        commit=source.split('private _moveCommitted=false;',1)[1].split('if (!_moveCommitted)',1)[0]
        self.assertLess(commit.index('time > _moveDeadline'),commit.index('_unit doMove'))
        self.assertIn('!= _moveDeadline',commit)
        self.assertLess(commit.index('_unit doMove'),commit.index('_retry set [1,time]'))
        self.assertNotIn('set ["boundDeadline"',planning+commit)
        self.assertIn('["TIME_LIMIT","STALLED"] select (_stalled && {_now <= _moveDeadline})',source)


class ManoeuvreDecisionCommitTests(unittest.TestCase):
    def test_recovery_and_failure_publish_only_for_current_measured_bound(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        helper=source.split('private _decisionCurrent={',1)[1].split('private _decisionDeferred=',1)[0]
        for guard in ['call _helperCurrent','isEqualTo _moveIdentity','isEqualTo _spots',
                      'isEqualTo _movers','isEqualTo _decisionProgress','isEqualTo _decisionRetries',
                      'isEqualTo _arrivedUnits','isEqualTo _decisionRecovery','== _moveDeadline',
                      'isEqualTo _moveRoute','call _actorTaskFree','currentCommand _actor != _command',
                      'isNotEqualTo _destination','vectorDistance _pose >= 0.5',
                      '_arrivedUnits findIf','_pose vectorDistance _target > 3']:
            self.assertIn(guard,helper)
        phase=source.split('if (_quorumReady) then {',1)[1].split('if (_arrived) then {',1)[0]
        self.assertEqual(phase.count('if !(call _decisionCurrent)'),4)
        self.assertIn('if (_decisionDeferred) exitWith {_result=0.25}',phase)
        failure=phase.split('private _failureCommitted=false;',1)[1]
        self.assertLess(failure.index('call _decisionCurrent'),failure.index('CBE_Cortex_DrillFailure'))
        self.assertIn('if (_failureCommitted) then {_result = _reason call _end} else {_result=0.25}',failure)
        self.assertNotIn('set ["boundDeadline"',phase)


class DrillThrowContextTests(unittest.TestCase):
    def test_throw_cannot_adopt_successor_drill_from_stale_caller(self):
        source=(ROOT/'addons/infantry/functions/cortexThrowGrenade.sqf').read_text()
        helper=source.split('private _contextMatches={',1)[1].split('private _simulations =',1)[0]
        for guard in ['count _required != 5','group _actor != _group','CBE_OperationGeneration',
                      'CBE_AIPass_Epoch','"token",""]) == _token','"operationGeneration",-2',
                      '"ownerEpoch",-2','"generation",-2','"phase",""]) != "CANCELLED"']:
            self.assertIn(guard,helper)
        admission=source.split('if (_muzzleIndex >= 0) then {',1)[1]
        self.assertLess(admission.index('isNil {'),admission.index('CBE_Cortex_ThrowGeneration'))
        self.assertLess(admission.index('call _contextMatches'),admission.index('private _throwGeneration='))
        self.assertIn('_ownerEpoch,_contextMatches,_fireAllowed,false,+_nativeOrder]] call CBA_fnc_execNextFrame',source)
        self.assertEqual(source.count('if (time > _expires) exitWith {["AIM_WINDOW_EXPIRED"] call _cancel};'),2)
        self.assertIn('CBE_AIPass_CoordinatedAssault_Enable',helper)
        self.assertIn('CBE_fnc_CortexFeatureEnabled',helper)
        self.assertLess(source.index('if !([_unit,_context] call _contextMatches) exitWith {["DRILL_REPLACED"] call _cancel}'),source.index('_unit doWatch _towards'))
        release=source.split('// After safety geometry,',1)[1]
        self.assertLess(release.index('isNil {'),release.index('addEventHandler'))
        self.assertLess(release.index('call _contextMatches'),release.index('forceWeaponFire'))
        self.assertNotIn('nearEntities',release.split('[_release,',1)[0])
        caller=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        self.assertEqual(caller.count('["DRILL",_group,_token,_operationGeneration,_rosterEpoch]'),2)


class ManoeuvreDynamicScopeTests(unittest.TestCase):
    def test_support_mode_is_not_shadowed_by_actor_lists_at_helper_calls(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        self.assertEqual(len(re.findall(r'\bprivate\s+_support\b',source)),1)
        self.assertIn('private _support=_supportToken != "";',source)
        consolidation=source.split('private _consolidationActors =',1)[1].split('if (_drill getOrDefault ["consolidating",false])',1)[0]
        self.assertIn('_teams = [+_allUnits,+_consolidationActors]',consolidation)
        self.assertIn('_drill set ["units",_allUnits + _consolidationActors]',consolidation)
        self.assertIn('_fit append _consolidationActors',consolidation)
        self.assertIn('call _issue;',consolidation)
        self.assertNotRegex(consolidation,r'\b_support\b')
        self.assertIn('private _supportRoles=_candidates select',source)


class ManoeuvrePauseAdmissionTests(unittest.TestCase):
    def test_pause_advances_once_before_retryable_start(self):
        source = (ROOT / "addons/infantry/functions/cortexFlankStep.sqf").read_text(encoding="utf-8")
        pause = source.split('    case "PAUSE": {', 1)[1].split('    case "HOLD": {', 1)[0]
        self.assertIn('isNil {', pause)
        self.assertIn('call _helperCurrent', pause)
        self.assertIn('isEqualTo _pauseIdentity', pause)
        self.assertIn('time < (_drill get "pauseUntil")', pause)
        self.assertLess(pause.index('"START","PAUSE_ELAPSED"'), pause.index('else {call _issue}'))
        self.assertIn('if (!_pauseCommitted) exitWith {_result=0.25}', pause)
        self.assertIn('case "START": {call _issue}', source)


class ManoeuvreConsolidationAdmissionTests(unittest.TestCase):
    def test_consolidation_retains_start_until_real_movement_issue(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        body=source.split('private _consolidationIdentity=',1)[1].split('call _issue;',1)[0]
        for guard in ('call _helperCurrent', 'isEqualTo _consolidationIdentity', 'isNotEqualTo _consolidationRoster',
                      'isNotEqualTo _consolidationPoints', 'call _actorTaskFree', 'expectedDestination _actor',
                      'currentCommand _actor', 'formLeader _actor', 'CortexCombatEffective', '"unavailable"'):
            self.assertIn(guard,body)
        self.assertLess(body.index('isNil {'),body.index('_drill set ["consolidating",true]'))
        self.assertIn('"START","CONSOLIDATION_PENDING"',body)
        self.assertIn('if (!_consolidationCommitted) exitWith {_result=0.25}',body)
        self.assertNotIn('"COMPLETE" call _end',body)


class ManoeuvreHoldPublicationTests(unittest.TestCase):
    def test_hold_geometry_cannot_publish_into_a_changed_task(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        body=source.split('private _holdIdentity=',1)[1]
        self.assertLess(body.index('call CBE_fnc_CortexSelectAvenue'),body.index('isNil {'))
        for guard in ('call _helperCurrent','isEqualTo _holdIdentity','isNotEqualTo _holdPoints',
                      'isNotEqualTo _holdRoster','isNotEqualTo _holdTeams','call _mayIssueMovement',
                      'expectedDestination _actor','CBE_AIPass_Assault_Enable'):
            self.assertIn(guard,body)
        self.assertLess(body.index('isNil {'),body.index('_drill set ["assaulting", true]'))
        self.assertIn('if (!_holdCommitted) exitWith {_result=0.25}',body)
        self.assertIn('if (_holdIssue) then {call _issue}',body)
        self.assertIn('_result != 0.25',body)


class AssaultClearThroughAdmissionTests(unittest.TestCase):
    def test_grenade_preparation_cannot_advance_a_replaced_assault(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        body=source.split('private _clearIdentity=',1)[1].split('case "CONSOLIDATE":',1)[0]
        self.assertLess(body.index('call CBE_fnc_CortexThrowGrenade'),body.index('private _clearCommitted=false'))
        for guard in ('call _helperCurrent','isEqualTo _clearIdentity','isNotEqualTo _clearRoster',
                      'isNotEqualTo _clearTeams','isNotEqualTo _clearPoints','isNotEqualTo _objective',
                      'CBE_AIPass_Assault_Enable'):
            self.assertIn(guard,body)
        self.assertLess(body.index('isNil {'),body.index('_drill set ["index",(_drill get "index")+1]'))
        self.assertLess(body.index('if (!_clearCommitted) exitWith'),body.index('call _issue;'))
        self.assertNotIn('CortexThrowGrenade',body.split('isNil {',1)[1])


class BoundArrivalStageCommitTests(unittest.TestCase):
    def test_arrival_stages_and_pause_deadlines_share_admission(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        body=source.split('private _arrivalRoster=',1)[1].split('if (!_arrivalCommitted)',1)[0]
        for guard in ('call _helperCurrent','isEqualTo _moveIdentity','isNotEqualTo _arrivalRoster',
                      'isNotEqualTo _arrivalTeams','isNotEqualTo _spots'):
            self.assertIn(guard,body)
        for reason in ('FIRE_TEAM_ARRIVED','ROAD_EDGE_ARRIVED','FINAL_BOUND_ARRIVED',
                       'CONSOLIDATION_ARRIVED','CLEAR_THROUGH_ARRIVED','BOUND_ARRIVED'):
            self.assertIn(reason,body)
            self.assertLess(body.index('isNil {'),body.index(reason))
        self.assertNotIn('call CBE_fnc_CortexThrowGrenade',body)
        self.assertIn('if (!_arrivalCommitted) exitWith {_result=0.25}',source)


class ArrivalPhysicalWitnessTests(unittest.TestCase):
    def test_stage_and_clear_through_require_fresh_floor_aware_quorum(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        helper=source.split('private _arrivalPresent={',1)[1].split('if !(call _restoreFeatures)',1)[0]
        for check in ('count _arrivalWitnesses >= _minimumArrivals','getPosASL _actor',
                      'CortexCombatEffective','call _actorTaskFree','group _actor != _group',
                      'objectParent _actor','vectorDistance _targetASL > 3',
                      'abs ((_pose select 2)-(_targetASL select 2)) > 1.5'):
            self.assertIn(check,helper)
        body=source.split('private _arrivalRoster=',1)[1].split('    case "PAUSE": {',1)[0]
        self.assertEqual(body.count('call _arrivalPresent'),2)
        self.assertNotIn('nearEntities',helper)
        self.assertNotIn('setPos',helper)


class ManoeuvreRecoveryPublicationTests(unittest.TestCase):
    def test_recovery_commands_and_private_journals_retain_current_child(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        body=source.split('private _recoveryEntry=',1)[1].split('private _waitForTeam=',1)[0]
        self.assertIn('apply {+_x}',body)
        for guard in ('call _helperCurrent','isEqualTo _recoveryEntry','isEqualTo _recoveryIdentity',
                      'call _mayIssueMovement','isNotEqualTo _recoveryNative'):
            self.assertIn(guard,body)
        issue=body.split('private _recoveryNative=',1)[1]
        self.assertLess(issue.index('isNil {'),issue.index('call CBE_fnc_RecoveryStep'))
        self.assertLess(issue.index('isNil {'),issue.index('_actor doMove _rally'))
        self.assertIn('if (!_recoveryPublished) exitWith {0.25}',body)
        self.assertIn('_recoveryDeferred || {!(call _recoveryCurrent)}',body)
        self.assertIn('_recoveryEntry set [_retryIndex,_retryRecord]',issue)
        self.assertIn('_drill set ["recovery",_recoveryEntry apply {+_x}]',issue)


class RecoveryLivePeerTests(unittest.TestCase):
    def test_rejoin_publication_uses_a_current_live_peer(self):
        source=(ROOT/'addons/infantry/functions/cortexFlankStep.sqf').read_text()
        self.assertIn('_rejoinWitnesses pushBack [_actor,_rallyActor]',source)
        body=source.split('// A moving/dead/transferred peer',1)[1].split('_recoveryPublished=true;',1)[0]
        for guard in ('getPosASL _peer','_peer in _main','local _peer','group _peer == _group',
                      'objectParent _peer','[_peer] call CBE_fnc_CortexCombatEffective',
                      '[_peer] call _actorTaskFree','vectorDistance _peerPose <= 12',
                      'abs ((_pose select 2)-(_peerPose select 2)) <= 1.5'):
            self.assertIn(guard,body)
        self.assertLess(body.index('_rejoined='),body.index('_drill set ["recovery",_recovery]'))
        self.assertNotIn('setPos',body)


class DrivingQueueDiscoveryAuthorityTests(unittest.TestCase):
    def test_queue_request_retains_owner_admission_while_automatic_hook_is_inactive(self):
        source=(ROOT/'addons/vehicles/functions/drivingQueueAgreementRequest.sqf').read_text()
        self.assertIn('isRemoteExecuted',source)
        self.assertIn('call CBE_fnc_DrivingQueueProposalCurrent',source)
        self.assertLess(source.index('call CBE_fnc_DrivingQueueProposalCurrent'),source.index('"BEGIN"'))
        driving=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertNotIn('call CBE_fnc_DrivingQueueAgreementRequest',driving)


class ConvoyCapCommitIdentityTests(unittest.TestCase):
    def test_convoy_native_boundaries_bind_original_brain_and_configuration(self):
        source=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        helper=source.split('private _mayIssueDriving = {',1)[1].split('// Recovery must not replay',1)[0]
        for guard in ('isNotEqualTo _tickBrain','CBE_Convoy_LocalJobToken','CBE_Convoy_ReceivedRevision',
                      'CBE_AIPass_Epoch','"cancelled"','"finished"','isNotEqualTo _configuration',
                      'param [_tickRegistryIndex,[]]'):
            self.assertIn(guard,helper)
        self.assertNotIn('findIf',helper.split('if (isNull _taskVehicle)',1)[0])
        self.assertEqual(source.count('forceSpeed _ownedSpeed;'),3)
        self.assertEqual(source.count('_speedLimits set [_key,[_limit,time]];'),2)
        for actor,flag in (('_lead','lead'),('_vehicle','pace'),('_vehicle','trail')):
            block=source.split('private _'+flag+'CapConfirmed=false;',1)[1]
            confirmation=block.index('abs (getForcedSpeed '+actor+'-_ownedSpeed) > 0.001')
            self.assertLess(confirmation,block.index('CBE_Convoy_OwnedSpeed'))
            self.assertLess(confirmation,block.index('_'+flag+'CapConfirmed=true'))
        self.assertIn('if (!_leadCapConfirmed) exitWith {};',source)
        self.assertIn('if (!_paceCapConfirmed) then {continue};',source)
        self.assertIn('if (!_trailCapConfirmed) then {continue};',source)



class ConvoySemanticPublicationTests(unittest.TestCase):
    def test_tick_results_cannot_publish_for_a_replacement_convoy(self):
        source=(ROOT/'addons/vehicles/functions/convoyOperationStep.sqf').read_text()
        helper=source.split('private _stepCurrent={',1)[1].split('};',1)[0]
        for guard in ('CBE_AIPass_Epoch','CBE_Convoy_ReceivedRevision','CBE_Convoy_LocalJobToken',
                      'isEqualTo _brain','"cancelled"','"finished"','isEqualTo _configuration',
                      'param [_entry,[]]','CortexZeusHeld','CortexExternalTakeover'):
            self.assertIn(guard,helper)
        self.assertIn('call CBE_fnc_ConvoyTick;\nif !(call _stepCurrent)',source)
        publication=source.split('private _stepPublished=false;',1)[1]
        self.assertLess(publication.index('isNil {'),publication.index('_brain set ["phase",_phase]'))
        self.assertLess(publication.index('call _stepCurrent'),publication.index('setVariable ["CBE_Convoy_Brain_State"'))
        self.assertIn('if (!_stepPublished) exitWith',publication)
        self.assertIn('[_phase,_configuration param [0,-1],_registryRevision,_spacingPairs,_recoveryActors]',publication)
        self.assertIn('serverTime-_lastStatusAt >= 10',publication)
        self.assertIn('serverTime < _lastStatusAt',publication)
        self.assertLess(publication.index('_brain set ["completed",true]'),publication.index('private _statusKey='))


class ConvoyTerminalRetirementTests(unittest.TestCase):
    def test_final_slots_are_rechecked_after_potentially_yielding_cleanup(self):
        source=(ROOT/'addons/main/fsm/convoyOperation.fsm').read_text().replace('""','"')
        finished=source.split('class Finished {',1)[1]
        cleanup=finished.index('call CBE_fnc_ConvoyReleaseLocal')
        tail=finished[cleanup:]
        self.assertLess(tail.index('isNil {'),tail.index('setVariable ["CBE_Convoy_Brain",nil]'))
        for proof in ('isEqualTo _brain','CBE_Convoy_LocalJobToken','CBE_Convoy_ReceivedRevision'):
            self.assertIn(proof,tail)
        self.assertEqual(tail.count('setVariable ["CBE_Convoy_Brain",nil]'),1)
        self.assertEqual(tail.count('setVariable ["CBE_Convoy_Brain_FSM",nil]'),1)


class ConvoyCleanupContextTests(unittest.TestCase):
    def test_cleanup_retains_original_context_and_transaction_boundaries(self):
        source=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        self.assertIn('["_expectedToken", "", [""]]',source)
        capture=source.index('private _brain=_group getVariable')
        self.assertLess(capture,source.index('call CBE_fnc_ConvoyCorridorStep'))
        self.assertEqual(source.count('private _brain=_group getVariable'),1)
        self.assertIn('private _state = _navigation;',source)
        for proof in ('_releaseEpoch','_releaseToken','_releaseRegistry','isEqualTo _navigation','_brainRetired'):
            self.assertIn(proof,source.split('private _releaseCurrent={',1)[1].split('};',1)[0])
        self.assertGreaterEqual(source.count('call _releaseCurrent'),5)
        self.assertIn('isNil {\n        if !(call _releaseCurrent) exitWith {};',source)
        final=source.rsplit('\nisNil {',1)[1]
        self.assertTrue(final.lstrip().startswith('if !(call _releaseCurrent) exitWith {};'))
        self.assertIn('_group setVariable ["CBE_Convoy_LocalState", nil]',final)
        self.assertIn('isEqualTo _releaseLeaderLease',final)
        self.assertLess(final.index('call _releaseCurrent'),final.index('CBE_Convoy_LeaderLease'))
        fsm=(ROOT/'addons/main/fsm/convoyOperation.fsm').read_text().replace('""','"')
        self.assertIn('_reason,_brain getOrDefault ["jobToken",""]] call CBE_fnc_ConvoyReleaseLocal',fsm)


class ConvoyPassageRetirementTests(unittest.TestCase):
    def test_captured_passage_receipts_cannot_retire_successor_episodes(self):
        for stem,kind in [('convoyCorridorStep','Corridor'),('convoyBypassStep','Bypass')]:
            source=(ROOT/'addons/vehicles/functions'/f'{stem}.sqf').read_text()
            self.assertIn('["_expectedEpisode",[],[[]]]',source)
            self.assertIn('_entryEpisodeKey isNotEqualTo _expectedEpisode',source)
            self.assertIn('_entryOwnerContext isNotEqualTo _expectedContext',source)
            self.assertIn('(call _ownerContext) isNotEqualTo _entryOwnerContext',source)
            retire=source.split('private _retire={',1)[1].split('if (_cancel != "")',1)[0]
            for proof in ('isNil {','local _group','isNotEqualTo _retireBrain','isNotEqualTo _episode',
                          'isNotEqualTo _entryEpisodeKey'):
                self.assertIn(proof,retire)
            self.assertLess(retire.index('isNil {'),retire.index(f'setVariable ["CBE_Convoy_{kind}Result"'))
            self.assertIn('_entryEpisodeKey=[_episode] call _episodeKey;',source)
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        self.assertIn('"CONVOY_RELEASED",_releaseCorridor,_releaseContext] call CBE_fnc_ConvoyCorridorStep',release)
        self.assertIn('"CONVOY_RELEASED",_releaseBypass,_releaseContext] call CBE_fnc_ConvoyBypassStep',release)


class ConvoyPassageProgressTests(unittest.TestCase):
    def test_rows_are_private_until_current_episode_publication(self):
        for stem,kind in [('convoyCorridorStep','Corridor'),('convoyBypassStep','Bypass')]:
            source=(ROOT/'addons/vehicles/functions'/f'{stem}.sqf').read_text()
            self.assertIn('private _entryRows=(_episode get "rows") apply {+_x};',source)
            self.assertIn('private _rows=_entryRows apply {+_x};',source)
            body=source.split('private _rowsPublished=false;',1)[1]
            for proof in ('isNil {','isNotEqualTo _entryOwnerContext','isNotEqualTo _entryEpisodeKey',
                          'isNotEqualTo _entryRows','if (!_rowsPublished) exitWith {_deferred}'):
                self.assertIn(proof,body)
            self.assertLess(body.index('isNil {'),body.index('_episode set ["rows",_rows]'))
            self.assertLess(body.index('_rowsPublished=true'),body.index('call _retire'))
            if kind=='Bypass':
                self.assertIn('isNotEqualTo _captureState',body)
                self.assertIn('setVariable ["CBE_Convoy_BypassCapture",[_captureIdentity,_nextCaptures]]',body)


class ConvoyPassageCreationTests(unittest.TestCase):
    def test_passage_creation_requires_original_lead_work_and_empty_slot(self):
        for stem,kind in [('convoyCorridorStep','Corridor'),('convoyBypassStep','Bypass')]:
            source=(ROOT/'addons/vehicles/functions'/f'{stem}.sqf').read_text()
            self.assertLess(source.index('private _creationWorkKey='),source.index('private _proposedEpisode='))
            creation=source.split('private _proposedEpisode=createHashMapFromArray',1)[1].split('if (count _episode == 0) exitWith',1)[0]
            for guard in ('isNil {','isNotEqualTo _entryOwnerContext','"cancelled"','"finished"',
                          'isNotEqualTo _configuration','isNotEqualTo _terminal','isNotEqualTo _creationWorkKey',
                          'serverTime >= (_proposedEpisode get "deadline")','CortexZeusHeld','AuthoredRouteReceipt'):
                self.assertIn(guard,creation)
            self.assertIn(f'count (_group getVariable ["CBE_Convoy_{kind}Passage",createHashMap]) != 0',creation)
            self.assertLess(creation.index('isNil {'),creation.index('_episode=_proposedEpisode;'))
            self.assertNotIn('nearEntities',creation)


class ConvoyPassageReversalTests(unittest.TestCase):
    def test_previous_passage_rechecks_current_hull_and_owner(self):
        for stem in ['convoyCorridorStep','convoyBypassStep']:
            source=(ROOT/'addons/vehicles/functions'/f'{stem}.sqf').read_text()
            body=source.split('// Historical passage is not current exit clearance',1)[1]
            recheck=body.split('if (!_stillBeyond) then',1)[0]
            for proof in ('local _vehicle','driver _vehicle == _driver','effectiveCommander _vehicle == _operator',
                          'CortexCombatEffective','CortexExternalOwner','boundingBoxReal','modelToWorldWorld',
                          'vectorDotProduct','< 5'):
                self.assertIn(proof,recheck)
            self.assertIn('_row set [4,false];_passed=false;_changed=true',body)
            self.assertNotIn('setPos',recheck)
            self.assertNotIn('nearEntities',recheck)


class ConvoyPassageDeferralTests(unittest.TestCase):
    def test_rejected_observation_does_not_mean_constraints_disappeared(self):
        for stem in ['convoyCorridorStep','convoyBypassStep']:
            source=(ROOT/'addons/vehicles/functions'/f'{stem}.sqf').read_text()
            self.assertIn('private _deferred=[false,createHashMap,0,0,"DEFERRED"]',source)
            self.assertIn('if (!_retired) exitWith {_deferred}',source)
            self.assertIn('if (_creationDeferred) exitWith {_deferred}',source)
            self.assertIn('if (!_rowsPublished) exitWith {_deferred}',source)
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertEqual(tick.count('== "DEFERRED") exitWith {}'),3)
        first=tick.split('private _bypassPassage=',1)[1]
        self.assertLess(first.index('== "DEFERRED") exitWith {}'),first.index('private _bypassPassageActive='))
        corridor=tick.split('private _passage=[_group,_configuration]',1)[1]
        self.assertLess(corridor.index('== "DEFERRED") exitWith {}'),corridor.index('private _passageActive='))


class ConvoyReplacementFixtureTests(unittest.TestCase):
    def test_replacement_fixture_uses_public_orders_and_physical_continuation(self):
        source=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        body=source.split('rapid replacement",',1)[1].split('private _reverseLead=',1)[0]
        for proof in ('call CBE_fnc_SimpleAiConvoy','completedFSM _oldFSM','CBE_Convoy_OwnedSpeed',
                      'isNotEqualTo _oldBrain','_replacementOrigins','vectorDotProduct _replacementAxis < 25',
                      '(velocityModelSpace _x select 1) <= 1','-replacement-physical-travel'):
            self.assertIn(proof,body)
        for shortcut in ('call CBE_fnc_ConvoyReleaseLocal','forceSpeed','setPos','setVelocity','setDriveOnPath'):
            self.assertNotIn(shortcut,body)


    def test_holder_recall_retains_refused_actors_and_binds_metadata_to_issue(self):
        text=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text(encoding='utf-8')
        block=text.split('// Admission refusal must not erase an unissued recall',1)[1].split('// A reported coordinated objective',1)[0]
        for guard in ('isNil {','CBE_AIPass_State','_holderGeneration','_holderEpoch',
                      '[] call _mayIssueMovement','CortexActorFireTaskAvailable','isNull objectParent _x'):
            self.assertIn(guard,block)
        self.assertLess(block.index('_x doFollow _leader'),block.index('_recallIssued pushBack _x'))
        self.assertLess(block.index('_recallIssued pushBack _x'),block.index('_holders - _recallIssued'))
        self.assertNotIn('_holders - _rejoin',block)
        roster=text.split('private _holders = _holderRows select',1)[1].split('// Admission refusal',1)[0]
        self.assertNotIn('local _x',roster)
        self.assertIn('local _x',block)
        self.assertIn('isEqualTo _holderRows',block)
        self.assertNotIn('addPerFrameHandler',block)
