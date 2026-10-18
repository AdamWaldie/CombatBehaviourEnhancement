"""Search issue/handback contracts: newer tasks must not inherit predecessor ownership."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name): return (ROOT/'addons/infantry/functions'/name).read_text(encoding='utf-8')
class SearchMoveOwnership(unittest.TestCase):
    def test_owned_move_requires_actual_destination_and_authored_route(self):
        text=source('cortexSearchMoveOwned.sqf')
        for proof in ('currentCommand _actor in ["MOVE",""]','_native vectorDistance _target <= 0.25',
                      'CBE_fnc_NativeOrderReceipt','CortexActorMoveReserved','CortexZeusHeld',
                      'CortexExternalTakeover','CBE_AIPass_ClearOrder','select [0,16]'):
            self.assertIn(proof,text)
        for forbidden in ('doMove','doFollow','doStop','setVariable','serverTime+'):
            self.assertNotIn(forbidden,text)
    def test_receipts_follow_actual_atomic_issue_and_remain_bounded(self):
        text=source('cortexGroupTick.sqf')
        self.assertEqual(text.count('private _issuedSearch=[];'),2)
        for body in text.split('private _issuedSearch=[];')[1:]:
            body=body.split('forEach (_team select [0,16]);',1)[0]
            for proof in ('isNil {','_searchEpoch ==','_searchRoute isEqualTo',
                          'CortexActorMoveReserved','currentCommand _searchActor in ["","STOP","FOLLOW"]'):
                self.assertLess(body.index(proof),body.index('_searchActor doMove'))
            self.assertLess(body.index('_searchActor doMove'),body.index('_issuedSearch pushBack'))
        self.assertIn('CBE_fnc_CortexSearchMoveOwned',text)
    def test_checkpoint_carries_receipts_and_calm_consumes_only_exact_search_move(self):
        self.assertIn('"searchMoveReceipts"',source('cortexCheckpoint.sqf'))
        text=source('cortexRestoreCalm.sqf')
        self.assertIn('private _recallOwned=if (_returnSearchTeam) then',text)
        self.assertIn('[_group,_state,_unit] call CBE_fnc_CortexSearchMoveOwned',text)
        self.assertIn('!_yieldToExternal && {_recallOwned}',text)
        self.assertIn('"searchTeam", "searchMoveReceipts",',text)
    def test_handback_checks_and_native_recall_share_atomic_scope(self):
        calm=source('cortexRestoreCalm.sqf').split('private _releaseOwnedHold={',1)[1].split('private _supportHeld=',1)[0]
        self.assertLess(calm.index('isNil {'),calm.index('CBE_fnc_CortexSearchMoveOwned'))
        self.assertLess(calm.index('CBE_fnc_CortexSearchMoveOwned'),calm.index('_unit doFollow _leader'))
        self.assertIn('private _leader=[_group] call CBE_fnc_CortexGroupAnchor',calm)
        self.assertIn('!isNull _leader',calm)
        tick=source('cortexGroupTick.sqf')
        contact=tick.split('private _beginContact = {',1)[1].split('call _enterContact;',1)[0]
        self.assertLess(contact.index('isNil {'),contact.index('CBE_fnc_CortexSearchMoveOwned'))
        self.assertIn('_leader == leader _group',contact)
        self.assertIn('isEqualTo _state',contact)
if __name__=='__main__': unittest.main()
