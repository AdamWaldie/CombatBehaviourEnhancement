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
        for required in ('isNil {','!local _actor','!local _authorityGroup','_actualGroup != _authorityGroup',
                         'CBE_AIPass_Epoch','CortexActorMoveReserved','CortexExternalTakeover',
                         'CBE_OperationGeneration','"ownerEpoch"','!= "CANCELLED"','serverTime < _deadline'):
            self.assertLess(s.index(required),s.index('private _nextOwned='))
        self.assertLess(s.index('count units _authorityGroup > 64'),s.index('call CBE_fnc_CortexExternalTakeover'))
        self.assertIn('call _write',apply)
        self.assertIn('if (_crossGroupRelease) then {_actualGroup} else {_group}',s)
        self.assertIn('_mode == "RELEASE" && {_scope == "DANGER_ATTACK"}',s)
        self.assertIn('(_paceProof select 0) isEqualTo _context',s)
        self.assertLess(s.index('keys _owned findIf {_x != "SPEED"}'),s.index('if (_mode == "RELEASE") exitWith'))
        garrison=s.split('if (_scope == "GARRISON") then {',1)[1].split('} else {',1)[0]
        for proof in ('_deadline == 0','CBE_Cortex_GarrisonSettingIssuer','CBE_AIPass_GarrisonGeneration','CBE_AIPass_GarrisonPos','CBE_AIPass_Garrison'):
            self.assertIn(proof,garrison)
        self.assertIn('if (_scope == "OPERATION")',s)
        self.assertIn('if (!_taskOwned) exitWith',s)
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
        speed=s.split('if ("SPEED" in _requested) then {',1)[1].split('// The usual room tick',1)[0]
        self.assertIn('(_owned get "SPEED") select 0',speed)
        self.assertIn('_baselineSpeed >= 0 && {_wantedSpeed == -1 || {_wantedSpeed > _baselineSpeed}}',speed)
        self.assertLess(speed.index('_requested=createHashMapFromArray'),speed.index('_requested set ["SPEED",_baselineSpeed]'))
        self.assertLess(s.index('exitWith {"CHANGED"}'),s.index('private _baselineSpeed='))
        self.assertNotIn('_deadline=serverTime',s)
        self.assertEqual(s.count('serverTime+1'),1)
        self.assertIn('serverTime < _releaseAt',s)
        self.assertIn('if (_releaseAt > 0 || {fleeing _actor}',s)
        handover=s.split('private _dangerHandover=[];',1)[1].split('private _nextOwned=',1)[0]
        for guard in ('CBE_Danger_EngineStanceLease','count _dangerHandover != 6','CBE_OperationGeneration','isNotEqualTo _epoch','isNotEqualTo _group'):
            self.assertIn(guard,handover)
        self.assertIn('_dangerBaseline=_dangerHandover select 0',handover)
        self.assertIn('if (_x == "STANCE" && {_dangerBaseline != ""}) then {_native=_dangerBaseline}',update)
        self.assertLess(update.index('setVariable ["CBE_ActorSettings",_next,true]'),update.index('setVariable ["CBE_Danger_EngineStanceLease",nil]'))
        self.assertIn('(["STANCE"] call _read) isEqualTo (_requested get "STANCE")',update)
        start=(ROOT/'addons/core/functions/operationStart.sqf').read_text(encoding='utf-8')
        transfer=start.split('private _postureReceipt=',1)[1].split('_group setVariable ["CBE_OperationGeneration",_generation,true]',1)[0]
        self.assertIn('(_postureReceipt select 3) isEqualTo (_generation-1)',transfer)
        self.assertIn('_successorPosture set [3,_generation]',transfer)
        self.assertNotIn('_successorPosture set [2,',transfer)
        self.assertNotIn('setUnitPos',transfer)
        routine=s.split('private _routineHandover=[];',1)[1].split('private _nextOwned=',1)[0]
        self.assertIn('call CBE_fnc_CortexStanceReceipt',routine)
        self.assertIn('_routinePresent && {_routineHandover isEqualTo []}',routine)
        self.assertIn('getVariable ["CBE_AIPass_StanceSet",false]) isNotEqualTo false',routine)
        self.assertIn('_dangerBaseline == _routineApplied',routine)
        self.assertIn('_routineBaseline="REFUSED"',routine)
        self.assertIn('_routineBaseline=_routineHandover select 2',routine)
        self.assertIn('_native=_routineBaseline',update)
        self.assertLess(update.index('setVariable ["CBE_ActorSettings",_next,true]'),update.index('forEach ["CBE_Cortex_StanceReceipt"'))
    def test_adoption_changes_only_metadata_and_keeps_original_deadline(self):
        s=core();adopt=s.split('if (_mode == "ADOPT") exitWith {',1)[1].split('if (_lease isNotEqualTo [] && {_oldContext',1)[0]
        self.assertIn('setVariable ["CBE_ActorSettings",_next,true]',adopt)
        self.assertNotIn('call _write',adopt)
        self.assertNotIn('serverTime',adopt)
        self.assertIn('keys _requested findIf {!(_x in _owned)}',adopt)
        inspect=s.split('if (_mode == "INSPECT") exitWith {',1)[1].split('private _taskOwned=false;',1)[0]
        for proof in ('_scope != "OPERATION"','serverTime >= _deadline',
                      '(_oldContext select 2) != _generation','keys _requested findIf {!(_x in _owned)}',
                      'call _same','"ADOPTABLE"','"ABSENT"','"CHANGED"'):
            self.assertIn(proof,inspect)
        for forbidden in ('setVariable','call _write','serverTime+','CortexQueueJob'):
            self.assertNotIn(forbidden,inspect)
        self.assertLess(s.index('if (_releaseAt > 0'),s.index('if (_mode == "INSPECT")'))
        self.assertLess(s.index('currentCommand _actor in ['),s.index('if (_mode == "INSPECT")'))
        # Missing properties and native edits cannot become successor baselines.
        def inspect_model(owned,requested,native,pending=0):
            if pending or not set(requested)<=set(owned):return False
            return all(native[k]==v[1] for k,v in owned.items())
        full={"STANCE":("AUTO","UP"),"SPEED":(-1,2)}
        requested={"STANCE":"UP","SPEED":4}
        self.assertTrue(inspect_model(full,requested,{"STANCE":"UP","SPEED":2}))
        self.assertFalse(inspect_model({"SPEED":(-1,2)},requested,{"SPEED":2}))
        self.assertFalse(inspect_model(full,requested,{"STANCE":"DOWN","SPEED":2}))
        self.assertFalse(inspect_model(full,requested,{"STANCE":"UP","SPEED":2},1))
        start=src('addons/infantry/functions/cortexClearBuilding.sqf')
        self.assertLess(start.index('[_motionActor,_job,4,if (_resume)'),start.index('["ADOPT",_motionActor,_job]'))
        motion=src('addons/infantry/functions/buildingActorMotion.sqf')
        self.assertEqual(motion.count('call CBE_fnc_CortexClearSettingsApply'),2)
        observe=motion.split('if (_mode == "OBSERVE") then {',1)[1].split('} else {',1)[0]
        for proof in ('"participants"','count _proposal > 8','_actor in _proposal',
                      '"unavailable"','serverTime >=','"deadline"','"hardDeadline"'):
            self.assertIn(proof,observe)
        self.assertIn('if (_mode in ["CHECK","OBSERVE"]) exitWith {',motion)
        early=motion.split('private _result=false;',1)[1].split('if (_mode != "ADOPT") exitWith {',1)[0]
        after_retire=early.split('private _kind=_mode;',1)[1]
        for forbidden in ('setVariable','_job set',' doMove ','doStop ','forceSpeed'):
            self.assertNotIn(forbidden,after_retire)
    def test_release_retains_unconfirmed_pairs_and_does_not_cancel_native_tasks(self):
        s=core();release=s.split('if (_mode == "RELEASE") exitWith {',1)[1].split('// Native flight',1)[0]
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
        preflight=s.split('if (_mode == "PREFLIGHT") exitWith {',1)[1].split('// Preserve the task',1)[0]
        for proof in ('"INSPECT"','_originalGeneration','"STANCE","UP"','"SPEED",_speed',
                      '"ADOPTABLE"','"CBE_Cortex_ClearSettingToken"','"CBE_Cortex_ClearStance"',
                      '"CBE_Cortex_ClearForcedSpeed"','"CBE_Cortex_ClearAppliedSpeed"'):
            self.assertIn(proof,preflight)
        for forbidden in ('setVariable','forceSpeed','setUnitPos','"RELEASE"','"APPLY"'):
            self.assertNotIn(forbidden,preflight)
        pace=s.split('// Preserve the task',1)[1].split('_result=[_mode,_actor,',1)[0]
        for rule in ('_mode == "APPLY"','behaviour _actor == "STEALTH"','finite _speed',
                     '_speed == -1 || {_speed > 1}','_speed=1'):
            self.assertIn(rule,pace)
        for command in ('forceSpeed','setBehaviour','setCombatMode','setVariable'):
            self.assertNotIn(command,pace)
        # Canonical settings retain the lower original mission cap after tactical pacing.
        self.assertIn('_wantedSpeed > _baselineSpeed',core())
        self.assertIn('_requested set ["SPEED",_baselineSpeed]',core())

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
