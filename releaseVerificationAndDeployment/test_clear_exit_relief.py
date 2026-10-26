"""Finite relief handover source contracts; physical arrival/view remains required."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearExitRelief(unittest.TestCase):
    def test_finite_attempts_are_published_before_planning_and_not_renewed(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        r=s.split('private _requestExitRelief={',1)[1].split('// End finite exit relief;',1)[0]
        for guard in ('_reliefConsidered','count _tried >= 8','(_x select 0) == netId _worker','(_x select 1) == netId _postActor',
                      '(serverTime+45) min (_job get "deadline") min (_job get "hardDeadline")'):
            self.assertIn(guard,r)
        self.assertLess(r.index('setVariable ["CBE_Cortex_ClearRelief"'),r.index('call _chooseExteriorExit'))
        self.assertIn('(_group getVariable ["CBE_Cortex_ClearRelief",[]]) isEqualTo [_context,_tried]',r)
    def test_relief_never_spends_existing_exit_security_or_unfinished_interior_work(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        r=s.split('private _requestExitRelief={',1)[1].split('// End finite exit relief;',1)[0]
        for guard in ('!(_worker in _reserves)','!(netId _worker in _earlyExits)',
                      'call _actorTaskFree','call _roomCommandOwned','call _observerInside',
                      '_claim isEqualTo []','(_claim param [0,-1]) in (_cleared+_unreachable)',
                      'currentCommand _worker in ["","STOP"]'):
            self.assertIn(guard,r)
        commit=r.split('private _issued=false;',1)[1]
        self.assertLess(commit.index('isNil {'),commit.index('_worker doMove _target'))
        self.assertLess(commit.index('isEqualTo _workerNative'),commit.index('_worker doMove _target'))
        self.assertIn('_until,"MOVING",false,+_exit',commit)
        for forbidden in ('doMove _observer','_reserves deleteAt','_cleared pushBack','set ["deadline"','setPos','setVelocity'):
            self.assertNotIn(forbidden,r)
    def test_original_observation_and_promotion_proof_still_require_physical_substitute(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        p=s.split('private _mayPromoteReserve={',1)[1].split('// Callback-local proof',1)[0]
        for guard in ('"ARRIVED"','lineIntersectsSurfaces','eyePos _observer','CBE_Cortex_ClearExitWatchLocal'):
            self.assertIn(guard,p)
        self.assertIn('[_pairIndex,_slot,_member] call _requestExitRelief',s)
        self.assertIn('[_replacement,_promotionProof] call _promotionProofCurrent',s)
        rebalance=s.split('// Rebalance one duplicated live post',1)[1].split('// Build the migration journal',1)[0]
        for gate in ('_stageSearchBudget <= 0','_promotionViewBudget <= 0','_lostKeys select [0,16]',
                     '[_lostGuard,_lostKey] call _securityCasualtyKnown',
                     '_lostExit in _securityEntries','call _exitAssigned','_searchCount < 3',
                     'call _mayPromoteReserve','call _promotionProofCurrent',
                     'call CBE_fnc_BuildingExteriorProposal','call CBE_fnc_BuildingExteriorCandidate',
                     '(_job get "deadline") min (_job get "hardDeadline")'):
            self.assertIn(gate,rebalance)
        dispatch=rebalance.split('if (_valid) then {',1)[1]
        for proof in ('isNil {','call _promotionProofCurrent','isEqualTo _lostStage','call _exitAssigned'):
            self.assertLess(dispatch.index(proof),dispatch.index('_candidate doMove _target'))
        for forbidden in ('lineIntersectsSurfaces','spawn','waitAndExecute','setPos','enableSimulation',
                          '_job set ["hardDeadline"','_reserves deleteAt','_cleared pushBack'):
            self.assertNotIn(forbidden,rebalance)
        self.assertLess(rebalance.index('_stageSearchCounts set'),rebalance.index('call CBE_fnc_BuildingExteriorProposal'))
        self.assertIn('_reserveStages set [_candidateKey,[+_target,false,"APPROACH"',dispatch)
        reservations=rebalance.split('// Include every admitted reserve destination',1)[1].split('private _searchAdmitted=',1)[0]
        self.assertIn('forEach _reserves;',reservations)
        self.assertNotIn('_reserves select [0,16]',reservations)
        self.assertIn('_post isNotEqualTo []',reservations)
        self.assertIn('count _reserves > 64',rebalance)
        self.assertLess(rebalance.index('count _taken <= 128 && {count _lanes <= 64}'),
                        rebalance.index('_stageSearchCounts set'))


    def test_unrun_fixture_requires_natural_readiness_and_physical_overlap(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        r=s.split('// Exit-relief acceptance uses only ordinary clearance',1)[1].split('// Whole-lane loss',1)[0]
        for required in ('_reliefCasualty setDamage 1','call CBE_fnc_CortexClearBuilding',
                         '_uniquePosts','call _observeReliefVisits','lineIntersectsSurfaces',
                         '_originalStillHere && {_substituteHere}','call _observedRoomVisit',
                         '_reliefPrefix+"-physical-observation-overlap"','_reliefPrefix+"-reserve-physical-entry"'):
            self.assertIn(required,r)
        for forbidden in ('setVariable ["CBE_Cortex_ClearRelief"','_job set','_stages set',
                          'doMove','setDestination','doWatch','set ["cleared"','set ["actorVisits"'):
            self.assertNotIn(forbidden,r)
        self.assertLess(r.index('_reliefPrefix+"-natural-fixture-ready"'),r.index('_reliefCasualty setDamage 1'))
    def test_fixture_is_explicitly_normal_owner_and_never_claims_hc_coverage(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        r=s.split('// Exit-relief acceptance uses only ordinary clearance',1)[1].split('// Whole-lane loss',1)[0]
        self.assertIn('"CBE_Headless_ExcludeGroup",true,true',r)
        self.assertIn('"acex_headless_blacklist",true,true',r)
        self.assertIn('Normal owner only.',r)
        self.assertIn('call CBE_fnc_CortexClearRelease',r)
    def test_pending_relief_retires_only_owned_leg_when_demand_changes(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        r=s.split('// Relief is tied to the original casualty vacancy',1)[1].split('if ((getPosASL _actor) vectorDistance',1)[0]
        for requirement in ('count _binding != 5','(_pair param [_slot,objNull]) == _missing',
                            '_stage isEqualTo _originalStage','isEqualTo _originalNative',
                            'call _exitMovementOwned','isEqualTo _native','call _reliefNeeded',
                            'CBE_fnc_CortexIsPaused','CBE_fnc_CortexZeusHeld'):
            self.assertIn(requirement,r)
        self.assertLess(r.index('isNil {'),r.index('doStop _actor'))
        self.assertLess(r.index('isEqualTo _reliefJournal'),r.index('doStop _actor'))
        self.assertIn('_earlyExits deleteAt (netId _actor)',r)
        self.assertIn('_earlyMotion deleteAt (netId _actor)',r)
        self.assertIn('"roomHolds",createHashMap',r)
        self.assertNotIn('doMove _guard',r)
        self.assertNotIn('_reserves deleteAt',r)
    def test_last_retired_relief_publishes_empty_current_context_for_adoption(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        p=s.split('private _publishEarlyExits={',1)[1].split('private _record=_earlyExits get',1)[0]
        self.assertIn('count _previous == 2',p)
        self.assertIn('(_previous select 0) isEqualTo _currentContext',p)
        self.assertIn('["PUBLIC",_job] call CBE_fnc_BuildingEarlyExitJournal',p)
        self.assertIn('count _receipt == 2',p)
        journal=(ROOT/'addons/infantry/functions/buildingEarlyExitJournal.sqf').read_text(encoding='utf-8')
        self.assertIn('if (_mode == "PUBLIC") exitWith {[_contextCopy,_rows]}',journal)
        self.assertIn('forEach keys _exits',journal)
        self.assertIn('isNotEqualTo _receipt',p)
        self.assertIn('call _mayIssueMovement',p)
    def test_lost_observer_keeps_same_bounded_exit_leg_without_fake_coverage(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        g=s.split('private _reliefNeeded={',1)[1].split('if (!(call _reliefNeeded))',1)[0]
        self.assertLess(g.index('serverTime >= (_reliefRow select 3)'),g.index('private _securityLost='))
        branch=g.split('private _securityLost=',1)[1].split('private _stage=',1)[0]
        known=s.split('private _securityCasualtyKnown={',1)[1].split('// Record only stops',1)[0]
        for guard in ('!isNull _guard','!alive _guard','"INCAPACITATED"','"ACE_isUnconscious"',
                      'CBE_Cortex_ClearLosses','count _losses == 2',
                      '(_losses select 0) isEqualTo _context','serverTime < (_context select 2)',
                      'count (_losses select 1) <= 64','_key in (_losses select 1)'):
            self.assertIn(guard,known)
        self.assertNotIn('doMove',known)
        capture=(ROOT/'addons/core/functions/cortexInit.sqf').read_text().split('addMissionEventHandler ["EntityKilled"',1)[1].split('CBE_fnc_CortexRegroupOnKill',1)[0]
        self.assertIn('serverTime+300,netId _unit,+_clearContext',capture)
        self.assertIn('"intent",""]) != "CLEAR"',capture)
        self.assertIn('count _casualties >= 8',capture) # general body list stays bounded
        self.assertIn('count _ids < 64',capture)
        self.assertIn('serverTime < (_clearContext select 2)',capture)
        self.assertIn('["CBE_Cortex_ClearLosses",[+_clearContext,_ids],true]',capture)
        # First guard loss must survive ninth/later deaths and the general
        # five-minute body lifetime while the original clearance is still active.
        context=('building','transform',900,'episode')
        deaths=['guard']+['other-'+str(i) for i in range(9)]
        rolling=deaths[-8:]
        self.assertNotIn('guard',rolling) # previous evidence path loses the real event
        receipt=(context,list(dict.fromkeys(deaths)))
        def known_loss(present,dead=False,receipt=None,key='guard',context=context,now=500):
            if present:return dead
            return receipt is not None and receipt[0]==context and now<context[2] and key in receipt[1]
        self.assertTrue(known_loss(False,receipt=receipt))
        self.assertFalse(known_loss(False))
        self.assertFalse(known_loss(False,receipt=receipt,context=('building','transform',900,'new-episode')))
        self.assertFalse(known_loss(False,receipt=receipt,key='missing-guard'))
        self.assertFalse(known_loss(False,receipt=receipt,now=900))
        self.assertFalse(known_loss(True,receipt=receipt))
        self.assertTrue(known_loss(True,dead=True))
        for cleanup in (s,(ROOT/'addons/infantry/functions/cortexClearRelease.sqf').read_text()):
            retirement=cleanup.split('private _retiredLosses=',1)[1].split('};',1)[0]
            self.assertLess(retirement.index('isEqualTo'),retirement.index('CBE_Cortex_ClearLosses",nil'))
        for guard in ('[_guard,_reliefRow select 1] call _securityCasualtyKnown',
                      'count _originalStage >= 6','"ARRIVED"','"securityEntries"',
                      '(_record param [5,[]]) isEqualTo (_reliefRow select 2)',
                      '(_record select 2) == (_reliefRow select 3)'):
            self.assertIn(guard,branch)
        for forbidden in ('doMove','doWatch','doStop','setVariable','set [','enableSimulation','hideObject'):
            self.assertNotIn(forbidden,branch)
        self.assertNotIn('simulationEnabled',branch)
        self.assertNotIn('isObjectHidden',branch)
        self.assertNotIn('currentCommand',branch)
        self.assertIn('private _visible=(getPosASL _actor) vectorDistance',s)
    def test_observer_loss_fixture_requires_real_travel_and_actual_replacement_observation(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        r=s.split('// Exit-relief acceptance uses only ordinary clearance',1)[1].split('// Whole-lane loss',1)[0]
        for requirement in ('"CLEAR-relief-observer-loss"','} forEach [false,true]',
                            '_reliefWorker distance2D _reliefStart > 1',
                            '_reliefWorker distance2D (_row select 1) > 3',
                            '_reliefObserver setDamage 1',
                            '(_row select 2) == (_reliefRequest select 3)',
                            'serverTime-_replacementSeenAt >= 3',
                            '"-replacement-exit-observed"'):
            self.assertIn(requirement,r)
        self.assertLess(r.index('_reliefWorker distance2D _reliefStart > 1'),r.index('_reliefObserver setDamage 1'))
        self.assertIn('alive _reliefObserver} && {_originalStillHere}',r)
        self.assertIn('if (!_substituteHere) then {_replacementSeenAt=-1}',r)
        security=s.split('// Proactive exit-security case:',1)[1].split('// Whole-lane loss',1)[0]
        for required in ('CBE_fnc_CortexClearBuilding','call _observedSecurityPost',
                         'count _posts == count _reserves','count _reserves',
                         '_x setDamage 1','_securityCasualties',
                         '(getPosASL _actor) vectorDistance (_x select 5) > 1',
                         'serverTime-_securityObservedAt >= 3',
                         'if (!_securityHere) then {_securityObservedAt=-1}',
                         '"CLEAR-security-source-cover-retained"',
                         '"CLEAR-security-original-budget-retained"',
                         '_securityBaseline=[_job get "generation",_job get "hardDeadline"]'):
            self.assertIn(required,security)
        self.assertLess(security.index('"CLEAR-security-natural-fixture-ready"'),security.index('_x setDamage 1'))
        for forbidden in ('doMove','setDestination','doWatch','_job set','_stages set',
                          'setVariable ["CBE_Cortex_ClearRelief"','set ["cleared"','set ["actorVisits"'):
            self.assertNotIn(forbidden,security)

if __name__=='__main__': unittest.main()
