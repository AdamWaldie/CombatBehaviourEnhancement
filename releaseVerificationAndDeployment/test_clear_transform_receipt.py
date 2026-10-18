"""Durable clearance transform contracts; geometry/access remains physically unaccepted."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearTransformReceiptTests(unittest.TestCase):
    def test_geometry_and_worker_use_original_admission_transform(self):
        text=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        self.assertLess(text.index('private _admissionTransform='),text.index('_building buildingPos -1'))
        self.assertIn('["buildingTransform",+_admissionTransform]',text)
        guards=[i for i in range(len(text)) if text.startswith('if !(call _admissionStable)',i)]
        self.assertEqual(len(guards),2)
        self.assertLess(guards[0],text.index('if (!_resume && {_previous isNotEqualTo []})'))
        self.assertLess(guards[1],text.index('setVariable ["CBE_AIPass_ClearOrder", ['))

    def test_resume_pose_check_precedes_shared_coverage_and_handoff(self):
        text=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        guard=text.split('if (_resume && {(_previous param [13,[],[[]]])',1)[1].split('// An explicit new CLEAR',1)[0]
        for proof in ('isNotEqualTo _admissionTransform','RESUME_TRANSFORM_MISMATCH',
                      'isEqualTo _previous','== _admissionGeneration'):
            self.assertIn(proof,guard)
        self.assertLess(text.index('RESUME_TRANSFORM_MISMATCH'),text.index('private _cleared ='))
        self.assertIn('_continueRoute, +_admissionTransform], true]',text)
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        self.assertIn('_job getOrDefault ["continueRoute",false],+(_job get "buildingTransform")], true]',step)

    def test_only_same_proven_pose_can_reuse_visit_indices(self):
        def visits(resume,previous_pose,current_pose,previous_visits):
            if resume and previous_pose!=current_pose:return None
            return list(previous_visits) if resume else []
        old=((0,0,0),(0,1,0),(0,0,1))
        moved=((30,0,0),(1,0,0),(0,0,1))
        self.assertEqual(visits(True,old,old,[0,2]),[0,2])
        self.assertIsNone(visits(True,old,moved,[0,2]))
        self.assertIsNone(visits(True,None,old,[0,2]))
        self.assertEqual(visits(False,old,moved,[0,2]),[])

    def test_transform_fixture_requires_old_real_visit_fresh_zero_coverage_and_both_new_entries(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        block=qa.split('private _originalRooms=',1)[1].split('deleteVehicle _movedHouse;',1)[0]
        for proof in ('call _observedRoomVisit','count (_order param [1,[]]) > 0',
                      '_transformOriginalGeneration','_moveApplied=true','isNil {',
                      'CBE_Cortex_ClearAdmissionFailure','(_freshOrder param [1,[]]) isEqualTo []',
                      '_freshOrder param [13,[]]','_transformEntries findIf {!_x} < 0'):
            self.assertIn(proof,block)
        for forbidden in ('_actor setPos','_actor setVelocity','setVariable ["CBE_AIPass_ClearOrder"',
                          'setVariable ["CBE_Cortex_ClearVisits"'):
            self.assertNotIn(forbidden,block)

    def test_resume_never_promotes_missing_or_different_order_to_fresh_task(self):
        text=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        guard=text.split('private _resumeCurrent={',1)[1].split('private _building =',1)[0]
        for proof in ('local _group','_previous isNotEqualTo []','_expectedOrder isEqualTo _previous',
                      '_expectedGeneration isEqualTo _admissionGeneration','isEqualTo _previous',
                      '== _admissionGeneration','RESUME_ORDER_CHANGED'):
            self.assertIn(proof,guard)
        target=text.split('private _building =',1)[1].split('if (isNull _building)',1)[0]
        self.assertIn('RESUME_TARGET_CHANGED',target)
        self.assertNotIn('CortexClearRelease',target)
        self.assertIn('private _resume = _resumeRequested;',text)
        self.assertNotIn('private _resume = _options getOrDefault',text)
        self.assertEqual(text.count('if (_resume && {!(call _resumeCurrent)}) exitWith'),2)
        self.assertLess(text.index('RESUME_ORDER_CHANGED'),text.index('_building buildingPos -1'))

    def test_discovery_passes_exact_snapshot_and_target_retirement_is_scoped(self):
        discovery=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text(encoding='utf-8')
        self.assertIn('["resumeOrder",+_clear]',discovery)
        self.assertIn('["resumeGeneration",_group getVariable ["CBE_AIPass_ClearGeneration",0]]',discovery)
        text=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        early=text.split('if (isNull _building) exitWith {',1)[1].split('if !(missionNamespace',1)[0]
        self.assertEqual(early.count('_resumeRequested && {call _resumeCurrent}'),2)
        self.assertIn('TARGET_ABSENT',early)
        self.assertIn('TARGET_DESTROYED',early)

    def test_stale_resume_fixture_uses_real_snapshot_and_preserves_live_successor(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        block=qa.split('private _originalResumeOrder=',1)[1].split('deleteVehicle _movedHouse;',1)[0]
        for proof in ('CLEAR-transform-cancelled-resume-refused','CLEAR-transform-replaced-resume-refused',
                      '["resumeOrder",_originalResumeOrder]','["resumeGeneration",_transformOriginalGeneration]',
                      '_cancelledResumeStayedRetired','_liveOrder','isEqualTo _liveOrder',
                      '== _liveGeneration','_replacementPreserved} && {_transformEntry}'):
            self.assertIn(proof,block)
        self.assertEqual(block.count('["resumeOrder",_originalResumeOrder]'),2)
        self.assertNotIn('setVariable ["CBE_AIPass_ClearOrder"',block)
        text=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        self.assertLess(text.index('if (_resume && {!(call _resumeCurrent)}) exitWith'),
                        text.index('if (serverTime >= (_deadline min _hardDeadline))'))
