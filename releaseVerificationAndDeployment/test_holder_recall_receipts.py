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
