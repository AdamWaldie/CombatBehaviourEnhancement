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
    def test_unrun_fixture_requires_natural_readiness_and_physical_overlap(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        r=s.split('// Exit-relief acceptance uses only ordinary clearance',1)[1].split('// Whole-lane loss',1)[0]
        for required in ('_reliefCasualty setDamage 1','call CBE_fnc_CortexClearBuilding',
                         '_uniquePosts','call _observeReliefVisits','lineIntersectsSurfaces',
                         '_originalStillHere && {_substituteHere}','call _observedRoomVisit',
                         '"CLEAR-relief-physical-observation-overlap"','"CLEAR-relief-reserve-physical-entry"'):
            self.assertIn(required,r)
        for forbidden in ('setVariable ["CBE_Cortex_ClearRelief"','_job set','_stages set',
                          'doMove','setDestination','doWatch','set ["cleared"','set ["actorVisits"'):
            self.assertNotIn(forbidden,r)
        self.assertLess(r.index('CLEAR-relief-natural-fixture-ready'),r.index('_reliefCasualty setDamage 1'))
    def test_fixture_is_explicitly_normal_owner_and_never_claims_hc_coverage(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        r=s.split('// Exit-relief acceptance uses only ordinary clearance',1)[1].split('// Whole-lane loss',1)[0]
        self.assertIn('"CBE_Headless_ExcludeGroup",true,true',r)
        self.assertIn('"acex_headless_blacklist",true,true',r)
        self.assertIn('Normal owner only.',r)
        self.assertIn('call CBE_fnc_CortexClearRelease',r)
if __name__=='__main__': unittest.main()
