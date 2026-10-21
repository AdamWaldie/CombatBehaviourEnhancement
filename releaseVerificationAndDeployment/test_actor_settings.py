"""Source ownership/command contracts for temporary actor settings; no live acknowledgement proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(path):return (ROOT/path).read_text(encoding='utf-8')
def core():return src('addons/core/functions/actorSettings.sqf')
class ActorSettingsTests(unittest.TestCase):
    def test_lease_and_requested_shapes_are_bounded_and_typed(self):
        s=core()
        for required in ('count _requested > 2','count _lease in [0,3]','count _owned > 2',
                         'count _pair != 2','finite (_row select _x)','_value == -1 || {_value >= 0}',
                         '["AUTO","UP","MIDDLE","DOWN"]','count (_row select 1) <= 256'):
            self.assertIn(required,s)
        for forbidden in ('allUnits','allGroups','nearestObjects','lineIntersects','spawn {','waitUntil',
                          'addPerFrameHandler','doMove','doFollow','doStop','doWatch','doTarget'):
            self.assertNotIn(forbidden,s)
    def test_actual_owner_and_live_operation_before_application(self):
        s=core();apply=s.split('private _nextOwned=',1)[1]
        for required in ('isNil {','!local _actor','!local _group','group _actor != _group',
                         'CBE_AIPass_Epoch','CortexActorMoveReserved','CortexExternalTakeover',
                         'CBE_OperationGeneration','"ownerEpoch"','== "CANCELLED"','serverTime >= _deadline'):
            self.assertLess(s.index(required),s.index('private _nextOwned='))
        self.assertLess(s.index('count units _group > 64'),s.index('call CBE_fnc_CortexExternalTakeover'))
        self.assertIn('call _write',apply)
        task_gate=s.split('if (_releaseAt > 0',1)[1].split('private _operation=',1)[0]
        self.assertIn('fleeing _actor',task_gate)
        self.assertIn('ace_medical_ai_healQueue',task_gate)
        self.assertLess(s.index('if (_mode == "RELEASE") exitWith'),s.index('if (_releaseAt > 0'))
        self.assertLess(s.index('if (_releaseAt > 0'),s.index('if (_mode == "ADOPT") exitWith'))
        self.assertIn('then {toUpperANSI (unitPos _actor)} else {getForcedSpeed _actor}',s)
    def test_preserve_baseline_and_refuse_changed_or_replaced_context(self):
        s=core()
        self.assertIn('(_oldContext select 1) != _issuer',s)
        self.assertIn('(_oldContext select 4) != _deadline',s)
        self.assertIn('_oldContext isNotEqualTo _context',s)
        self.assertLess(s.index('exitWith {"CHANGED"}'),s.index('private _nextOwned='))
        update=s.split('private _nextOwned=',1)[1]
        self.assertIn('_pair set [1,_requested get _x]',update)
        self.assertNotIn('_pair set [0,',update)
        self.assertNotIn('_deadline=serverTime',s)
        self.assertEqual(s.count('serverTime+1'),1)
        self.assertIn('serverTime < _releaseAt',s)
        self.assertIn('if (_releaseAt > 0 || {fleeing _actor}',s)
    def test_adoption_changes_only_metadata_and_keeps_original_deadline(self):
        s=core();adopt=s.split('if (_mode == "ADOPT") exitWith {',1)[1].split('if (_lease isNotEqualTo [] && {_oldContext',1)[0]
        self.assertIn('setVariable ["CBE_ActorSettings",_next,true]',adopt)
        self.assertNotIn('call _write',adopt)
        self.assertNotIn('serverTime',adopt)
        start=src('addons/infantry/functions/cortexClearBuilding.sqf')
        self.assertLess(start.index('[_motionActor,_job,4,if (_resume)'),start.index('["ADOPT",_motionActor,_job]'))
        motion=src('addons/infantry/functions/buildingActorMotion.sqf')
        self.assertEqual(motion.count('call CBE_fnc_CortexClearSettingsApply'),2)
    def test_release_retains_unconfirmed_pairs_and_does_not_cancel_native_tasks(self):
        s=core();release=s.split('if (_mode == "RELEASE") exitWith {',1)[1].split('private _operation=',1)[0]
        for required in ('_pair select 1','_pair select 0','_remaining set [_key,_pair]',
                         '[_key] call _read','"PENDING"','"RELEASED"'):
            self.assertIn(required,release)
        self.assertNotIn('currentCommand',release)
        self.assertIn('"RELEASE",_actor',src('addons/infantry/functions/cortexClearSettingsRelease.sqf'))
    def test_room_movement_and_commit_require_acknowledged_settings(self):
        step=src('addons/infantry/functions/buildingOperationStep.sqf')
        block=step.split('private _clearStepSpeed=',1)[1].split('} forEach _pair;',1)[0]
        self.assertIn('_settingsStatus in ["APPLIED","OWNED"]',block)
        self.assertLess(block.index('{_settingsReady}'),block.index('doStop _unit'))
        self.assertLess(block.index('{_settingsReady}'),block.index('_unit doMove'))
        self.assertLess(block.index('if (_settingsReady) then'),block.index('_roomMoverCommitted=true'))
        self.assertNotIn('forceSpeed',block)
        self.assertNotIn('setUnitPos',block)
        self.assertNotIn('_priorSpeed=',step)
        self.assertNotIn('_priorStance=',step)
        owned=step.split('private _roomCommandOwned={',1)[1].split('// Native task ownership also applies',1)[0]
        self.assertLess(owned.index('call CBE_fnc_CortexClearSettingsApply'),owned.index('call _ownsCurrentMove'))
        self.assertIn('!= "OWNED"',owned)
    def test_native_setting_observation_separates_pending_from_acknowledgement(self):
        s=core();apply=s.split('private _nextOwned=',1)[1]
        self.assertLess(apply.index('call _write'),apply.index('if (keys _nextOwned findIf'))
        self.assertIn('exitWith {"PENDING"}',apply)
        adapter=src('addons/infantry/functions/cortexClearSettingsApply.sqf')
        self.assertIn('"PENDING"',adapter)
        self.assertIn('"CBE_Cortex_ClearSettingToken",_issuer',adapter)
    def test_partial_mirrors_never_become_capture_or_cleanup_authority(self):
        s=src('addons/infantry/functions/cortexClearSettingsApply.sqf')
        self.assertLess(s.index('_canonical isEqualTo [] &&'),s.index('call CBE_fnc_ActorSettings'))
        self.assertIn('_brain getOrDefault ["job",createHashMap]) isNotEqualTo _job',s)
        self.assertIn('CBE_AIPass_Active',s)
        release=src('addons/infantry/functions/cortexClearSettingsRelease.sqf')
        self.assertLess(release.index('_status == "RELEASED"'),release.index('"CBE_Cortex_ClearForcedSpeed",'))
        self.assertNotIn('forceSpeed',release.split('params [[',1)[1])
    def test_fresh_task_handover_releases_known_predecessor_before_new_capture(self):
        adapter=src('addons/infantry/functions/cortexClearSettingsApply.sqf')
        prepare=adapter.split('if (_mode == "PREPARE") exitWith {',1)[1].split('_result=[_mode,',1)[0]
        for proof in ('_previous select 1) isNotEqualTo _clearIssuer','_previous select 0) isNotEqualTo _group',
                      '_previous select 2) isEqualTo _generation','["RELEASE",_actor,_previous]'):
            self.assertIn(proof,prepare)
        self.assertLess(prepare.index('_result == "RELEASED"'),prepare.index('"CBE_Cortex_ClearForcedSpeed",'))
        step=src('addons/infantry/functions/buildingOperationStep.sqf')
        body=step.split('// Native mutation commit:',1)[1].split('} forEach _pair;',1)[0]
        self.assertIn('[_unit,true] call _roomCommandOwned',body)
        self.assertLess(body.index('"PREPARE"] call'),body.index('private _settingsStatus='))
        self.assertLess(body.index('private _settingsStatus='),body.index('_unit doMove'))
        self.assertIn('_actor in (_job get "started")',step.split('private _roomCommandOwned={',1)[1])
    def test_unchanged_room_settings_skip_copy_and_mutation_after_owner_checks(self):
        s=core()
        fast=s.split('// The usual room tick',1)[1].split('private _nextOwned=',1)[0]
        self.assertIn('(_owned get _x) select 1,_requested get _x',fast)
        self.assertIn('exitWith {"APPLIED"}',fast)
        self.assertNotIn('setVariable',fast)
        self.assertNotIn('call _write',fast)
        self.assertLess(s.index('exitWith {"CHANGED"}'),s.index('// The usual room tick'))
        self.assertLess(s.index('_oldContext isNotEqualTo _context'),s.index('// The usual room tick'))
if __name__=='__main__':unittest.main()
