"""Guard durable CQB ownership adoption against replay and cross-episode reuse."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def read(name):
    return (ROOT/'addons/infantry/functions'/name).read_text(encoding='utf-8')
class MotionReceiptTests(unittest.TestCase):
    def test_adoption_never_issues_native_work_or_credits_visits(self):
        text=read('buildingActorMotion.sqf')
        for forbidden in ('doMove','doStop','doFollow','forceSpeed ','setUnitPos ','pushBack _positionIndex'):
            self.assertNotIn(forbidden,text)
        for proof in ('CBE_Cortex_ClearVisitContext','operationGeneration','ownerEpoch','objective',
                      'CortexActorMoveReserved','CortexZeusHeld','NativeOrderReceipt',
                      '_native vectorDistance _target <= 0.25','vectorDistance (AGLToASL _target) <= 1.5'):
            self.assertIn(proof,text)
        self.assertIn('(_receipt select 1) isEqualTo _context',text)
        self.assertIn('(_context select 3) == ""',text)
    def test_publishing_is_live_job_bound_and_coalesced(self):
        text=read('buildingActorMotion.sqf')
        store=text.split('if (_mode != "ADOPT") exitWith {',1)[1].split('if (_kind == "MOVE") then',1)[0]
        for guard in ('isNotEqualTo _job','"cancelled"','"finished"','"deadline"','"hardDeadline"'):
            self.assertLess(store.index(guard),store.index('private _next='))
        self.assertIn('if (_receipt isNotEqualTo _next)',store)
    def test_resume_adopts_before_start_without_stopping_owned_move(self):
        text=read('cortexClearBuilding.sqf')
        adopt=text.index('["ADOPT",_motionActor,_job]')
        self.assertLess(adopt,text.index('call CBE_fnc_BuildingOperationStart'))
        self.assertIn('if (_resume) then {',text[:adopt][-220:])
        step=read('buildingOperationStep.sqf')
        self.assertIn('if !([_unit] call _ownsCurrentMove) then {doStop _unit}',step)
        self.assertIn('// Synchronise only already-owned native work.',step)
    def test_retirement_does_not_require_current_operation_or_erase_other_context(self):
        text=read('buildingActorMotion.sqf')
        retire=text.split('if (_mode == "RETIRE") exitWith {',1)[1].split('private _building=',1)[0]
        self.assertIn('(_receipt select 0) isEqualTo _group',retire)
        self.assertIn('(_receipt select 1) isEqualTo _context',retire)
        self.assertNotIn('doStop',retire)
        step=read('buildingOperationStep.sqf')
        self.assertLess(step.index('_job set ["finishReason","OWNERSHIP_LOST"]'),step.index('["RETIRE",_x,_job]'))
        release=read('cortexClearRelease.sqf')
        self.assertLess(release.index('private _motionJob='),release.index('_buildingBrain set ["cancelled",true]'))
        self.assertIn('["RETIRE",_x,_motionJob]',release)
if __name__=='__main__': unittest.main()
