"""Completed hold ownership contracts; runtime STOP/flow remains an engine gate."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class HolderRecallReceiptTests(unittest.TestCase):
    def test_receipt_is_captured_at_actual_stop_and_checkpointed(self):
        end=source('cortexFlankEnd')
        block=end.split('private _holdRows=',1)[1].split('_state set ["holders", _holders]',1)[0]
        self.assertLess(block.index('doStop _actor'),block.index('private _row='))
        for field in ('_endingToken','clientOwner','_endingEpoch','_endingGeneration','expectedDestination _actor','_holdOrder'):
            self.assertIn(field,block)
        self.assertIn('"holderRecallReceipts"',source('cortexCheckpoint'))
        self.assertIn('CBE_Cortex_HolderToken",_row select [1,5],true',block)
    def test_read_only_match_requires_actor_route_and_native_destination(self):
        helper=source('cortexHolderRecallOwned').split('params [[',1)[1]
        for guard in ('local _group','local _actor','group _actor != _group','remoteControlled _actor',
                      'CortexActorMoveReserved','currentCommand _actor','CortexExternalTakeover',
                      'count _rows > 64','count _x == 8','_native vectorDistance _target <= 0.25',
                      'CBE_Cortex_HolderToken','isNotEqualTo (_row select [1,5])','simulationEnabled _actor',
                      '_actor checkAIFeature "MOVE"','_actor checkAIFeature "PATH"',
                      'CBE_fnc_NativeOrderReceipt'):
            self.assertIn(guard,helper)
        for forbidden in ('setVariable','doStop','doFollow','doMove','spawn','waitUntil','setPos','setVelocity'):
            self.assertNotIn(forbidden,helper)
    def test_normal_recall_consumers_check_receipt_before_native_follow(self):
        tick=source('cortexGroupTick').split('// Admission refusal',1)[1].split('// A reported coordinated',1)[0]
        self.assertLess(tick.index('CortexHolderRecallOwned'),tick.index('_x doFollow _leader'))
        calm=source('cortexRestoreCalm')
        self.assertIn('[_group,_state,_unit] call CBE_fnc_CortexHolderRecallOwned',calm)
        self.assertLess(calm.index('forEach (_state getOrDefault ["holders", []])'),calm.index('call CBE_fnc_CortexGroupMoveClear'))
        retreat=source('cortexRetreat')
        self.assertLess(retreat.index('CortexHolderRecallOwned'),retreat.index('call CBE_fnc_CortexGroupMove'))
        self.assertIn('(_live getOrDefault ["generation",-2]) == _generation',retreat)
        self.assertNotIn('_state set ["holders", []]',retreat)
        for name in ('cortexAdvanceStart','cortexAssaultStart','cortexFlankStart'):
            admission=source(name)
            self.assertIn('currentCommand _x != "STOP" || {[_group,_state,_x] call CBE_fnc_CortexHolderRecallOwned}',admission)
            self.assertIn('set ["nativeAdmissionChecked",true]',admission)
        start=source('cortexDrillStart')
        transfer=start.split('if (_drill getOrDefault ["nativeAdmissionChecked",false]) then {',1)[1].split('private _handle=',1)[0]
        for proof in ('isNil {','_liveState isNotEqualTo _state','_liveDrill isNotEqualTo _drill',
                      'CBE_AIPass_Epoch','CBE_OperationGeneration','select [0,64]',
                      'CortexHolderRecallOwned','CBE_Cortex_HolderToken",nil,true','"nativeCommands"'):
            self.assertIn(proof,transfer)
        self.assertLess(transfer.index('CortexHolderRecallOwned'),transfer.index('CBE_Cortex_HolderToken",nil,true'))
        for forbidden in (' doMove ','doStop','doFollow','serverTime+'):
            self.assertNotIn(forbidden,transfer)

    def test_pending_locality_recall_is_finite_and_keeps_original_native_proof(self):
        worker=source('cortexHolderRecallPending')
        for guard in ('serverTime+30','serverTime >= _until','_attempt >= 30',
                      '_callbackEpoch != _epoch','_key isNotEqualTo _identity',
                      'CortexHolderRecallOwned','count (_record select 3) > 64',
                      'UNRESOLVED_DEADLINE','SUPERSEDED','FOLLOW_ISSUED'):
            self.assertIn(guard,worker)
        self.assertLess(worker.index('CortexHolderRecallOwned'),worker.index('_actor doFollow _leader'))
        self.assertIn('(_x select 7) isEqualTo _order',worker)
        self.assertIn('[_group,[],_identity,_attempt+1,_epoch],1]',worker)
        self.assertNotIn('enableAI',worker)
        self.assertNotIn('setPos',worker)
        self.assertNotIn('setVelocity',worker)
        calm=source('cortexRestoreCalm')
        self.assertIn('!local (_x select 0)',calm)
        self.assertLess(calm.index('CortexGroupMoveClear'),calm.index('CortexHolderRecallPending'))
        locality=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text(encoding='utf-8')
        self.assertIn('[_group] call CBE_fnc_CortexHolderRecallPending',locality)

    def test_regroup_transfers_only_issued_actor_and_yields_retries_to_new_intent(self):
        regroup=source('cortexGroupTick').split('case "REGROUP": {',1)[1].split('case "RETREAT": {',1)[0]
        self.assertNotIn('_state set ["holders", []]',regroup)
        self.assertIn('(_state getOrDefault ["holders",[]])-[_unit]',regroup)
        self.assertIn('(_x select 0) isNotEqualTo _unit',regroup)
        for guard in ('CortexActorFireTaskAvailable','CortexHolderRecallOwned',
                      '_regroupGeneration','_regroupEpoch','_regroupCanMove',
                      'count _proof != 6','_destination vectorDistance _issued <= 0.25',
                      '(_proof select 4) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)'):
            self.assertIn(guard,regroup)
        self.assertLess(regroup.index('[_unit,[]] call _regroupCanMove'),regroup.index('_unit doMove _target'))
        retry=regroup.split('_now - _lastProgressAt >= 10',1)[1]
        self.assertLess(retry.index('[_unit,_record] call _regroupCanMove'),retry.index('_unit doMove _target'))

    def test_task_takeover_retires_only_matching_local_old_hold_token(self):
        tick=source('cortexGroupTick')
        block=tick.split('private _transferred=_holderRows',1)[1].split('_state set ["holders",_holders]',1)[0]
        for guard in ('_x in _ownedMovers','(_x select 0) in _transferred',
                      'local _actor','group _actor == _group',
                      'isEqualTo (_x select [1,5])','CBE_Cortex_HolderToken",nil,true',
                      '!((_x select 0) in _transferred)'):
            self.assertIn(guard,block)
        for forbidden in ('doFollow','doMove','doStop','enableAI','setPos','setVelocity'):
            self.assertNotIn(forbidden,block)
        boundary=tick.split('// Admission refusal',1)[1].split('private _transferred=',1)[0]
        self.assertIn('CBE_OperationGeneration',boundary)
        self.assertIn('CBE_AIPass_Epoch',boundary)
