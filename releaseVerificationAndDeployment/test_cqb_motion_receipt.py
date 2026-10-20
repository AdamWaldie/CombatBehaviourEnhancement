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
        self.assertIn('if !([_unit] call _ownsCurrentMove) then {doStop _unit; [_unit] call _rememberHold}',step)
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
    def test_promotion_records_owned_work_before_leaving_transaction(self):
        text=read('buildingOperationStep.sqf')
        body=text.split('// Preserve the already-owned reserve leg/hold',1)[1].split('(_job get "assigned")',1)[0]
        self.assertIn('call _ownsCurrentMove',body)
        self.assertIn('["MOVE",_replacement,_job',body)
        self.assertIn('currentCommand _replacement == "STOP"',body)
        self.assertIn('["HOLD",_replacement,_job',body)
        self.assertNotIn('doStop',body)
        self.assertNotIn('doMove',body)
    def test_resume_roster_prefers_committed_participants_and_rechecks_changes(self):
        text=read('cortexClearBuilding.sqf')
        for proof in ('private _useResumeRoster=_resume',
                      '[_building,_admissionTransform,_previous param [10,-1]]',
                      '_x in _resumeParticipants && {!(_x in _resumeUnavailable)}',
                      '"RESUME_ROSTER_CHANGED"'):
            self.assertIn(proof,text)
        commit=text.split('private _liveOperation=_group getVariable',1)[1].split('call CBE_fnc_OperationStart',1)[0]
        for snapshot in ('isNotEqualTo _resumeParticipants','isNotEqualTo _resumePairs',
                         'isNotEqualTo _resumeUnavailable','isNotEqualTo _resumeRosterContext'):
            self.assertIn(snapshot,commit)
        self.assertLess(text.index('"RESUME_ROSTER_CHANGED"'),text.index('call CBE_fnc_OperationStart'))
    def test_durable_roster_survives_common_operation_cancel_and_is_episode_bound(self):
        text=read('cortexClearBuilding.sqf')
        for proof in ('private _useRosterJournal=_resume',
                      '(_resumeRosterJournal select 0) isEqualTo _resumeRosterContext',
                      'isNotEqualTo _resumeRosterJournal',
                      'if (_useRosterJournal) then',
                      '_group setVariable ["CBE_Cortex_ClearRoster",[+_visitContext'):
            self.assertIn(proof,text)
        cancel=(ROOT/'addons/core/functions/operationCancel.sqf').read_text(encoding='utf-8')
        self.assertIn('_group setVariable ["CBE_Operation",nil,true]',cancel)
        self.assertNotIn('CBE_Cortex_ClearRoster',cancel)
        step=read('buildingOperationStep.sqf')
        self.assertIn('+_participants,(_job get "pairs") apply {+_x}',step)
        self.assertLess(step.index('"OWNERSHIP_LOST"'),step.index('private _retiredRoster='))
        self.assertIn('(_retiredRoster select 0) isEqualTo (_job getOrDefault ["visitContext",[]])',step)
        self.assertIn('(_retiredRoster select 0) isEqualTo (_motionJob get "visitContext")',read('cortexClearRelease.sqf'))
    def test_locality_checkpoint_cannot_recall_new_stop_or_clearance(self):
        text=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text(encoding='utf-8')
        body=text.split('private _moveProof=_restore getOrDefault',1)[1].split('forEach (_restore getOrDefault ["restoreMovers", []])',1)[0]
        self.assertNotIn('currentCommand _unit != "MOVE"',body)
        for proof in ('private _ownedMove=false','currentCommand _unit == "MOVE"',
                      '_destination vectorDistance _spot <= 0.25',
                      '("CBE_AIPass_ClearOrder"', 'CortexActorMoveReserved'):
            if proof.startswith('('):
                self.assertIn('"CBE_AIPass_ClearOrder",[]]) isEqualTo []',body)
            else:
                self.assertIn(proof,body)
        self.assertNotIn('"STOP","ATTACK","FIRE","SUPPRESS"',body)
    def test_calm_cleanup_requires_path_lease_and_protects_new_tasks(self):
        text=read('cortexRestoreCalm.sqf')
        hold=text.split('private _releaseOwnedHold={',1)[1].split('private _supportHeld=',1)[0]
        self.assertIn('private _pathOwned=_restorePath && {_unit getVariable ["CBE_Cortex_SupportPathHold",false]}',hold)
        self.assertLess(hold.index('if (_pathOwned) then'),hold.index('enableAI "PATH"'))
        for proof in ('CBE_fnc_CortexSearchMoveOwned',
                      '"CBE_AIPass_ClearOrder",[]]) isEqualTo []',
                      'CortexZeusHeld','CortexExternalTakeover','call _actorMoveFree'):
            self.assertLess(hold.index(proof),hold.index('doFollow _leader'))
        self.assertIn('[_x,false,false] call _releaseOwnedHold',text)
if __name__=='__main__': unittest.main()
