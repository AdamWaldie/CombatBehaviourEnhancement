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
